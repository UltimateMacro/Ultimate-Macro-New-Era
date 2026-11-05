; Reviewed compatibility additions from IlMlN's modified 1.3.3a source.
; Original GPLv3/contributor notices continue to apply. No fork updater is used.
UM14_ApplyGameInput() {
    global DefaultMouseSpeed, MouseDelay, KeyDelay
    ; Launcher starts execute on a timer thread, not the old GUI's click thread.
    ; Explicitly keep legacy Event mouse movement and the user's original values.
    SendMode("Event")
    SetDefaultMouseSpeed(Integer(DefaultMouseSpeed))
    SetMouseDelay(Integer(MouseDelay))
    SetKeyDelay(Integer(KeyDelay))
}

UM14_SearchText(value, minimumDelay := 60, direct := false) {
    if (StrLen(value) < 1 || StrLen(value) > 128 || RegExMatch(value, "[\x00-\x1f\x7f]"))
        UM14_Fatal("Invalid game search text.")
    if (Type(minimumDelay) != "Integer" || minimumDelay < 60 || minimumDelay > 250)
        UM14_Fatal("Invalid search pacing.")
    previousMode := A_SendMode, previousDelay := A_KeyDelay, previousDuration := A_KeyDuration
    try {
        SendMode("Event")
        ; Lower-frame-rate game clients need both a press duration and an
        ; inter-key delay. Preserve caller values that are already slower.
        SetKeyDelay(Max(minimumDelay, previousDelay), Max(minimumDelay, previousDuration))
        UM14_RequireReadyFocus()
        SendEvent("^a")
        Sleep(60)
        UM14_RequireReadyFocus()
        SendEvent("{Backspace}")
        Sleep(60)
        if (direct) {
            ; Match the modified fork's fast literal entry on the first pass.
            UM14_RequireReadyFocus()
            SendText(value)
        } else Loop Parse, value {
            UM14_RequireReadyFocus()
            ; Keep the original ordinary-keyboard translation for game searches.
            ; Text mode forces Unicode fallback and ignores PressDuration. Raw
            ; stays literal without interpreting tower/map names as shortcuts.
            ; Explicit Space also avoids an isolated leading/trailing space.
            SendEvent(A_LoopField = " " ? "{Space}" : "{Raw}" A_LoopField)
            Sleep(minimumDelay)
        }
        Sleep(250)
        UM14_RequireReadyFocus()
    } finally {
        SetKeyDelay(previousDelay, previousDuration)
        SendMode(previousMode)
    }
}

UM14_ClearPlacementPanel() {
    global LastOpenedTowerID, unfocusX, unfocusY
    UM14_RequireReadyFocus()
    ; A visible DJ/previous-tower menu is not evidence that the NEXT tower was
    ; placed. Establish a closed-menu boundary before selecting the next slot.
    if (waitForTowerUI(&oldV2, &oldV1, 120)) {
        Loop 2 {
            UM14_RequireReadyFocus()
            Click(ScaleX(unfocusX), ScaleY(unfocusY))
            Sleep(120)
            if (!waitForTowerUI(&oldV2, &oldV1, 120)) {
                LastOpenedTowerID := ""
                return
            }
        }
        UM14_Fatal("The previous tower menu would not close. No new placement was accepted; send the Output log and a screenshot.")
    }
    LastOpenedTowerID := ""
}

UM14_ModifierButton(result, region, factor) {
    words := UM14_OCRWords(result,region,factor), found := false
    for left in words {
        if (left.text != "ADD" || left.h < 4)
            continue
        for right in words {
            if (right.text != "MODIFIER" || right.h < 4 || right.x < left.x+left.w-1
                || right.x-left.x-left.w > Max(left.h,right.h)*1.5
                || Abs((left.y+left.h/2)-(right.y+right.h/2)) > Max(left.h,right.h)*.5)
                continue
            if (IsObject(found))
                return false
            found := {x:Round((left.x+right.x+right.w)/2),y:Round(right.y+right.h/2)}
        }
    }
    return found
}

UM14_OpenModifierMenu() {
    UM14_RequireReadyFocus()
    identity := UM14_ConnectionSnapshot()
    if (!IsObject(identity))
        UM14_Fatal("Modifier setup lost its game client.")
    region := UM14_Region(0,Round(identity.h*.82),Round(identity.w*.16),
        Round(identity.h*.16),identity.w,identity.h)
    if (!IsObject(region))
        UM14_Fatal("Modifier control region was not verified.")
    factor := Min(3.0,2500/Max(region.w,region.h))
    started := A_TickCount, previous := false
    Loop {
        UM14_RequireReadyFocus()
        if (!UM14_ConnectionSame(identity))
            UM14_Fatal("Modifier setup lost its game client.")
        button := UM14_ModifierButton(UM14_ConnectionOCR(identity,region,factor,"",true),region,factor)
        if (IsObject(button) && IsObject(previous)
            && Abs(button.x-previous.x) <= 4 && Abs(button.y-previous.y) <= 4) {
            UM14_RequireReadyFocus()
            if (!UM14_ConnectionSame(identity))
                UM14_Fatal("Modifier setup lost its game client.")
            Click(button.x,button.y)
            return
        }
        if (A_TickCount-started >= 4500)
            UM14_Fatal("Add Modifier could not be verified. No modifier click was sent.")
        previous := button
        Sleep(120)
    }
}

UM14_WaitModifierSearch() {
    started := A_TickCount
    Loop {
        UM14_RequireReadyFocus()
        getRobloxPos(,, &width, &height)
        if (!UM14_Viewport(width, height))
            UM14_Fatal("Modifier setup lost its game client.")
        res := AdvancedImageSearch("Resources/searchbar_modifiers.png", Round(width*.1), 0,
            Round(width*.7), Round(height*.6), 0.5, 1.5)
        if (res.status = "success" && res.score >= 0.7)
            return res
        if (A_TickCount-started >= 6000)
            UM14_Fatal("Modifier search field was not found after 6 seconds. Leave the menu open and send the Output error with a screenshot.")
        Sleep(150)
    }
}

UM14_LobbyFailure(stage) {
    global RunningStrategy, StateFile
    ; End this run before exiting so the guard cannot resume it in a loop.
    RunningStrategy := false
    IniWrite(0, StateFile, "State", "Running")
    KillSubmacros()
    UM14_Fatal("Could not recognize " stage ". Macro stopped; Roblox was left open. Check the game UI and press Start to retry.")
}

UM14_ModeScroll() {
    global SettingsFile
    if (!Integer(IniRead(SettingsFile, "Options", "ScrollDownForMap", "0")))
        return
    count := Integer(IniRead(SettingsFile, "Options", "ScrollDownAmount", "5"))
    delay := Integer(IniRead(SettingsFile, "Options", "ScrollDelay", "1000"))
    if (count < 5 || count > 20 || delay < 0 || delay > 5000)
        UM14_Fatal("Invalid mode-list scroll settings.")
    UM14_RequireReadyFocus()
    getRobloxPos(,, &width, &height)
    MouseMove(Round(width*0.5), Round(height*0.5))
    Sleep(delay)
    UM14_RequireReadyFocus()
    SendEvent("{WheelDown " count "}")
    Sleep(300)
}

UM14_MenuWord(identity, region, expected, caption := false) {
    factor := Min(region.w < identity.w*.12 ? 3.0 : 2.0,2500/Max(region.w,region.h))
    words := UM14_OCRWords(UM14_ConnectionOCR(identity,region,factor,"",true),region,factor)
    match := ""
    for word in words {
        minimumHeight := region.w < identity.w*.12 ? Max(4,identity.h*.005) : Max(6,identity.h*.007)
        if (word.text != StrUpper(expected) || word.h < minimumHeight)
            continue
        ; Difficulty cards repeat the name in lowercase in their descriptions.
        if (caption && word.raw == StrLower(word.raw))
            continue
        if (IsObject(match))
            return false
        match := {x:Round(word.x+word.w/2),y:Round(word.y+word.h/2)}
    }
    return UM14_ConnectionSame(identity) ? match : false
}

UM14_MenuWordPair(identity, region, expected, caption := false) {
    UM14_RequireReadyFocus()
    first := UM14_MenuWord(identity,region,expected,caption)
    if (!IsObject(first))
        return false
    Sleep(100)
    UM14_RequireReadyFocus()
    second := UM14_MenuWord(identity,region,expected,caption)
    if (!IsObject(second) || !UM14_ConnectionSame(identity)
        || Abs(first.x-second.x) > 4 || Abs(first.y-second.y) > 4)
        return false
    return second
}

UM14_MenuImagePair(identity, region, filename, score := .78) {
    if (!IsObject(region))
        return false
    previous := false
    Loop 2 {
        UM14_RequireReadyFocus()
        if (!UM14_ConnectionSame(identity))
            return false
        found := AdvancedImageSearch("Resources/" filename, region.x, region.y, region.w, region.h, .45, 1.7)
        if (found.status != "success" || found.score < score || !UM14_ConnectionSame(identity)
            || found.x < region.x || found.x >= region.x+region.w
            || found.y < region.y || found.y >= region.y+region.h)
            return false
        if (IsObject(previous) && (Abs(previous.x-found.x) > 5 || Abs(previous.y-found.y) > 5))
            return false
        previous := found
        if (A_Index = 1)
            Sleep(100)
    }
    return previous
}

UM14_ReferenceVoteModifiers(identity) {
    UM14_RequireReadyFocus()
    if !UM14_ConnectionSame(identity)
        UM14_Fatal("Roblox moved before the modifier vote.")
    ; 1.3.3.10 votes once after selecting all modifiers. The docked
    ; panel is shorter than the reference widescreen layout.
    narrow := identity.w < identity.h*1.3
    x := Round(identity.w*(narrow ? .59 : 1122/1920))
    y := Round(identity.h*(narrow ? .74 : 853/1009))
    Click(x,y)
}

UM14_SelectCurrentMode(difficulty, &seenMenu := false) {
    ; Current TDS menu is a scrollable card list with a persistent sidebar.
    ; Old builds searched only the first screen for a retired font template.
    static modes := Map("Easy","Casual","Casual","Casual","Intermediate","Intermediate",
        "Molten","Molten","Fallen","Fallen","Hardcore","Hardcore","Voidcore","Voidcore","Frost","Frost")
    if (!modes.Has(difficulty))
        return false ; Preserve existing special-mode compatibility.
    UM14_RequireReadyFocus()
    identity := UM14_ConnectionSnapshot()
    if (!IsObject(identity))
        return false
    sidebar := UM14_Region(Round(identity.w*.12),Round(identity.h*.09),
        Round(identity.w*.09),Round(identity.h*.69),identity.w,identity.h)
    if (!IsObject(sidebar))
        return false
    navigation := UM14_MenuImagePair(identity,sidebar,"Survival.png")
    if (!IsObject(navigation))
        navigation := UM14_MenuWordPair(identity,sidebar,"Survival")
    if (!IsObject(navigation)) {
        ; Current TDS also puts the category tabs in a horizontal strip.
        ; Require the neighboring Story tab, not the Survival section title.
        tabs := UM14_Region(Round(identity.w*.20),0,Round(identity.w*.38),
            Round(identity.h*.29),identity.w,identity.h)
        if (IsObject(tabs)) {
            survival := UM14_MenuWordPair(identity,tabs,"Survival")
            story := IsObject(survival) ? UM14_MenuWordPair(identity,tabs,"Story") : false
            if (IsObject(story) && story.x > survival.x && Abs(story.y-survival.y) <= 5)
                navigation := survival
        }
    }
    menuClose := UM14_Region(Round(identity.w*.68),0,Round(identity.w*.20),
        Round(identity.h*.15),identity.w,identity.h)
    heading := false
    if (!IsObject(navigation)) {
        ; The first row may be visible with Fallen and Frost below the fold.
        ; Keep searching after a confirmed heading, even without sidebar OCR.
        headingRegion := UM14_Region(Round(identity.w*.21),Round(identity.h*.10),
            Round(identity.w*.27),Round(identity.h*.80),identity.w,identity.h)
        heading := UM14_MenuWordPair(identity,headingRegion,"Survival")
        if (!IsObject(heading) || heading.y >= identity.h*.86)
            return false
    }
    seenMenu := true
    if (IsObject(navigation)) {
        UM14_RequireReadyFocus()
        if (!UM14_ConnectionSame(identity))
            return false
        Click(navigation.x,navigation.y)
        Sleep(300)
    }
    region := UM14_Region(Round(identity.w*.21),Round(identity.h*.10),
        Round(identity.w*.62),Round(identity.h*.80),identity.w,identity.h)
    started := A_TickCount
    Loop 9 {
        if (!UM14_ConnectionSame(identity) || A_TickCount-started >= 16000)
            return false
        cardRegion := A_Index = 1 && IsObject(heading) ? UM14_Region(Round(identity.w*.21),
            heading.y+1,Round(identity.w*.62),Floor(identity.h*.94)-heading.y-1,identity.w,identity.h) : region
        if (!IsObject(cardRegion))
            return false
        card := UM14_MenuImagePair(identity,cardRegion,difficulty ".png")
        if (!IsObject(card))
            card := UM14_MenuWordPair(identity,cardRegion,modes[difficulty],true)
        if (IsObject(card)) {
            UM14_RequireReadyFocus()
            if (!UM14_ConnectionSame(identity))
                return false
            Click(card.x,card.y)
            LogToConsole("Mode selection: currentMenu=1 confirmed=1")
            return true
        }
        ; Re-prove the navigation before every bounded scroll. Capture failure
        ; or an unexpected menu never becomes permission to send wheel input.
        if (A_Index = 9 || (!IsObject(UM14_MenuImagePair(identity,sidebar,"Survival.png"))
            && !IsObject(UM14_MenuImagePair(identity,menuClose,"close.png",.86))
            && !IsObject(UM14_MenuWordPair(identity,sidebar,"Survival"))
            && (!IsSet(tabs) || !IsObject(tabs) || !IsObject(UM14_MenuWordPair(identity,tabs,"Survival")))))
            return false
        UM14_RequireReadyFocus()
        MouseMove(Round(identity.w*.5),Round(identity.h*.5))
        UM14_RequireReadyFocus()
        if (!UM14_ConnectionSame(identity))
            return false
        SendEvent("{WheelDown}")
        Sleep(200)
    }
    return false
}

UM14_ModifierName(value) {
    ; Exact aliases only; never the fork's arbitrary prefix/substring matches.
    static names := ["Broke","Exploding","Flying","Foggy","Glass","Healthy","Hidden",
        "Inflation","Jailed","Limitation","Committed","Quarantine","Speedy",
        "Armored","Regeneration","Slow","Strong"]
    static aliases := Map("fog","Foggy","fo","Foggy","gla","Glass","gl","Glass",
        "hid","Hidden","hi","Hidden","hidd","Hidden","exp","Exploding","ex","Exploding","explo","Exploding",
        "lim","Limitation","li","Limitation","limit","Limitation","com","Committed","co","Committed",
        "fly","Flying","fl","Flying","arm","Armored","ar","Armored",
        "reg","Regeneration","re","Regeneration","slo","Slow","sl","Slow",
        "spe","Speedy","sp","Speedy","str","Strong","st","Strong","commited","Committed",
        "bro","Broke","br","Broke","hea","Healthy","he","Healthy",
        "inf","Inflation","in","Inflation","qua","Quarantine","qu","Quarantine")
    token := StrLower(Trim(value))
    if aliases.Has(token)
        return aliases[token]
    for name in names {
        if (StrLower(name) = token)
            return name
    }
    UM14_Fatal("Unknown or ambiguous modifier name.")
}
