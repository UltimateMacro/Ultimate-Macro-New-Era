; Reviewed compatibility additions from IlMlN's modified 1.3.3a source.
; Original GPLv3/contributor notices continue to apply. No fork updater is used.
UM14_InputRootMatches(actual, expected) => IsInteger(actual) && actual != 0 && actual = expected

UM14_RecordedStepLine(line) {
    quoted := false
    Loop Parse line {
        if A_LoopField = '"'
            quoted := !quoted
        else if (A_LoopField = ";" && !quoted)
            return Trim(SubStr(line,1,A_Index-1))
    }
    return Trim(line)
}

UM14_UpgradeStep(line) {
    if !RegExMatch(line,"i)^UpgradeTower\s*\(\s*([^,]+?)\s*(?:,\s*(false|true)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?\s*\)$",&m)
        return false
    return {id:Trim(m[1]), skip:m[2] = "true", count:m[3] = "" ? 1 : Integer(m[3]),
        path:m[4] = "" ? 0 : Integer(m[4]), level:m[5] = "" ? 4 : Integer(m[5])}
}

UM14_UpgradeBatch(steps, index) {
    first := UM14_UpgradeStep(steps[index])
    if !IsObject(first)
        return false
    next := index+1
    while (next <= steps.Length) {
        upgrade := UM14_UpgradeStep(steps[next])
        if (!IsObject(upgrade) || upgrade.id !== first.id || upgrade.path != first.path
            || upgrade.level != first.level || upgrade.skip != first.skip || first.count+upgrade.count > 999)
            break
        first.count += upgrade.count
        next++
    }
    first.next := next
    return first
}

UM14_InventoryImageFact(value) {
    fact := {status:"missing",score:"unknown"}
    if (!IsObject(value))
        return fact
    fact.status := "unknown"
    if (value.HasOwnProp("status") && Type(value.status) = "String") {
        switch value.status {
            case "success":
                fact.status := "success"
            case "error", "failed":
                fact.status := "failed"
        }
    }
    if (value.HasOwnProp("score") && (Type(value.score) = "Integer" || Type(value.score) = "Float") && value.score >= 0 && value.score <= 1)
        fact.score := Round(value.score,3)
    return fact
}

UM14_InventoryMenuFailure(attempts, items, close, itemsOcrTried := false) {
    itemsFact := UM14_InventoryImageFact(items), closeFact := UM14_InventoryImageFact(close)
    attempts := Type(attempts) = "Integer" && attempts >= 1 && attempts <= 3 ? attempts : 0
    context := 0
    try context := IsObject(UM14_ConnectionSnapshot()) ? 1 : 0
    LogToConsole("Inventory menu failed: attempts=" attempts
        " itemsStatus=" itemsFact.status " itemsScore=" itemsFact.score
        " closeStatus=" closeFact.status " closeScore=" closeFact.score
        " context=" context " capture=" (itemsOcrTried ? "items-label-attempted" : "not-requested"))
    UM14_Fatal("Inventory menu could not be confirmed after the bounded attempts. Open the inventory and retry. No later tower or match was started.")
}

UM14_ExtraUiWait() {
    global SettingsFile
    extra := IniRead(SettingsFile, "Options", "ExtraUiWait", "0")
    return RegExMatch(extra,"^\d{1,2}$") ? Min(90,Integer(extra))*1000 : 0
}

UM14_WaitSetupLobby(timeout := 12000, allowResultsRelaunch := false) {
    start := A_TickCount
    deadline := start+timeout+UM14_ExtraUiWait(), transitionUntil := start
    nextOverlayCheck := start, attempts := Map(), blocking := false, evidence := "context"
    rewardSince := 0, rewardDismissed := false
    Loop {
        UM14_RequireReadyFocus()
        if UM14_LobbyOrInventory()
            return true
        if A_TickCount >= nextOverlayCheck {
            identity := UM14_ConnectionSnapshot()
            blocking := UM14_StartupOverlay(identity,&evidence)
            if IsObject(blocking) {
                previous := attempts.Get(blocking.kind, false)
                reward := blocking.kind = "reward"
                if (reward && !rewardSince)
                    rewardSince := A_TickCount
                if ((!reward || !rewardDismissed) && UM14_StartupRetryAllowed(identity,blocking,previous,A_TickCount)
                    && UM14_ClickStartupOverlay(identity,blocking)) {
                    attempts[blocking.kind] := {count:IsObject(previous) ? previous.count+1 : 1,
                        at:A_TickCount, key:identity.key, button:blocking.button}
                    transitionUntil := A_TickCount+2200
                    LogToConsole("Pressed verified " blocking.action "; waiting for the lobby.")
                }
                if (reward && !rewardDismissed && ((IsObject(previous) && previous.count >= 2 && A_TickCount-previous.at >= 1250)
                    || (!IsObject(blocking.button) && A_TickCount-rewardSince >= 1600))) {
                    rewardDismissed := UM14_DismissStalledReward(identity)
                    if rewardDismissed {
                        transitionUntil := A_TickCount+2200
                        LogToConsole("Login Rewards stayed open. Pressed verified Login to dismiss it; no reward was confirmed.")
                    }
                }
                if (!rewardDismissed && !IsObject(blocking.button))
                    UM14_ClearStartupHover(identity,blocking.region)
            }
            nextOverlayCheck := A_TickCount+500
        }
        if (allowResultsRelaunch && !IsObject(blocking) && UM14_VerifiedResults()) {
            LogToConsole("Rejoining TDS from the confirmed match-results screen.")
            return RunRoblox()
        }
        ; Even a verified press near the normal deadline must get a chance to
        ; finish animating. The one-retry and one-dismiss caps bound the grace.
        if A_TickCount >= Max(deadline,transitionUntil) {
            LogToConsole("Lobby startup check: " evidence)
            if IsObject(blocking)
                UM14_Fatal(blocking.name " is still open. Close it in Roblox and press Start again. No match was started.")
            UM14_LobbyFailure("the TDS lobby (Play button or the open inventory with Auto Equip on)")
        }
        Sleep(250)
    }
}

UM14_LoginRewardsHeading(text) {
    return Type(text) = "String" && StrLen(text) <= 4096
        && (RegExMatch(text,"im)^\s*(?:31\s+)?Login\s+Rewards\b")
            || RegExMatch(text,"i)\bRewards\s+scale\s+with\s+your\s+login\s+streak\b"))
}

UM14_LoginRewardsVisible(identity) {
    title := UM14_StartupRegion(identity,.18,.19,.82,.55)
    return IsObject(title) && UM14_LoginRewardsHeading(UM14_ConnectionOCR(identity,title))
}

UM14_LoginToggle(identity) {
    if !UM14_LoginRewardsVisible(identity)
        return false
    region := UM14_StartupRegion(identity,.71,.003,.963,.155)
    label := IsObject(region) ? UM14_MenuWordPair(identity,region,"LOGIN",false,false,3.0) : false
    if !IsObject(label)
        return false
    y := Round(label.y-Max(12,Min(30,label.height*1.9)))
    return UM14_StartupPointIn(region,label.x,y) && UM14_ConnectionSame(identity) ? {x:label.x,y:y} : false
}

UM14_DismissStalledReward(identity) {
    toggle := UM14_LoginToggle(identity)
    return IsObject(toggle) && UM14_HeldClick(identity,toggle.x,toggle.y,"Dismiss Login Rewards",160,
        () => UM14_ButtonStillAt(toggle,UM14_LoginToggle(identity)))
}

UM14_StartupRegion(identity, left, top, right, bottom) {
    w := identity.w, h := identity.h
    x := Round(w*left), y := Round(h*top)
    return UM14_Region(x,y,Round(w*right)-x,Round(h*bottom)-y,w,h)
}

UM14_UpdateNotesHeading(text, heading) {
    ; WinRT's Text joins lines into one paragraph, including article titles
    ; above Update Log. Match both whole headings in their own bounded crops.
    return Type(text) = "String" && StrLen(text) <= 4096 && RegExMatch(text,"i)\b" heading "\b")
}

UM14_StartupOverlay(identity, &evidence := "", underPointer := false) {
    evidence := "context"
    if (!IsObject(identity) || !UM14_ConnectionSame(identity))
        return false
    ; The notes can sit above Login Rewards. Require both fixed headers before
    ; looking for the red close button; there are other red X controls in TDS.
    list := UM14_StartupRegion(identity,.015,.075,.44,.34)
    listFound := IsObject(list) && UM14_UpdateNotesHeading(UM14_ConnectionOCR(identity,list),"All\s+Updates")
    evidence := "viewport=" identity.w "x" identity.h " notes-list=" (listFound ? "found" : UM14_ConnectionOCRStage())
    if listFound {
        detail := UM14_StartupRegion(identity,.29,.22,.71,.52)
        detailFound := IsObject(detail) && UM14_UpdateNotesHeading(UM14_ConnectionOCR(identity,detail),"Update\s+Log")
        evidence .= " notes-detail=" (detailFound ? "found" : UM14_ConnectionOCRStage())
        if detailFound {
            region := UM14_StartupRegion(identity,.66,.065,.99,.34)
            close := UM14_StartupHoveredButton(identity,underPointer,"notes",region,"red")
            closeStatus := IsObject(close) ? "verified" : "template-missing"
            for name in (IsObject(close) ? [] : ["close.png","close_items.png","close_freerewards.png"]) {
                match := UM14_MenuImagePair(identity,region,name,.78)
                if !IsObject(match)
                    continue
                closeStatus := "color-unverified"
                if UM14_StartupButtonColor(identity,match,"red") {
                    close := match, closeStatus := "verified"
                    break
                }
            }
            evidence .= " close=" closeStatus
            return UM14_ConnectionSame(identity) ? {kind:"notes", name:"TDS Update Log",
                action:"TDS Update Log close button", button:close, region:region} : false
        }
    }
    titleFound := UM14_LoginRewardsVisible(identity)
    evidence .= " reward-title=" (titleFound ? "found" : UM14_ConnectionOCRStage())
    if !titleFound
        return false
    ; Compact and docked layouts can push Claim below 91% of the client.
    region := UM14_StartupRegion(identity,.33,.53,.67,.995)
    claim := UM14_StartupHoveredButton(identity,underPointer,"reward",region,"green")
    if (!IsObject(claim) && IsObject(region))
        claim := UM14_MenuWordPair(identity,region,"CLAIM")
    if !UM14_StartupButtonColor(identity,claim,"green")
        claim := UM14_MenuImagePair(identity,region,"Claim.png",.85)
    if !UM14_StartupButtonColor(identity,claim,"green")
        claim := false
    evidence .= " claim=" (IsObject(claim) ? "verified" : "unverified")
    return UM14_ConnectionSame(identity) ? {kind:"reward", name:"Login Rewards",
        action:"Login Rewards Claim", button:claim, region:region} : false
}

UM14_StartupPointIn(region, x, y) => IsObject(region)
    && x >= region.x && y >= region.y && x < region.x+region.w && y < region.y+region.h

UM14_StartupHoveredButton(identity, previous, kind, region, color) {
    ; Roblox draws its cursor over the icon/text and tints the hovered button.
    ; Only an already verified button can use the surrounding color here, and
    ; only after the same overlay's heading(s) have been verified again.
    if (!IsObject(previous) || previous.kind != kind || !IsObject(previous.button))
        return false
    button := previous.button
    return UM14_StartupPointIn(region,button.x,button.y) && UM14_StartupButtonColor(identity,button,color) ? button : false
}

UM14_ClearStartupHover(identity, region) {
    MouseGetPos(&x,&y)
    if !UM14_StartupPointIn(region,x,y)
        return
    ; Uncover the label before the next independent observation. No click.
    x := Round(identity.w*.50), y := Round(identity.h*.045)
    UM14_RequireInputPoint(identity,x,y,"Read TDS startup panel")
    MouseMove(x,y,0)
}

UM14_StartupButtonColor(identity, button, color) {
    if !IsObject(button)
        return false
    hits := 0, dx := Max(10,Min(18,Round(identity.h*.018))), dy := Max(6,Min(11,Round(identity.h*.011)))
    ; A white diagonal X covers the corner samples at some viewport scales.
    offsets := color = "red" ? [[-dx,0],[dx,0],[0,-dx],[0,dx]] : [[-dx,-dy],[dx,-dy],[-dx,dy],[dx,dy]]
    for delta in offsets {
        x := button.x+delta[1], y := button.y+delta[2]
        if (x < 0 || x >= identity.w || y < 0 || y >= identity.h)
            continue
        try {
            rgb := PixelGetColor(x,y), r := (rgb>>16)&255, g := (rgb>>8)&255, b := rgb&255
            if (color = "green" ? g >= 130 && g-r >= 42 && g-b >= 42 : r >= 150 && r-g >= 58 && r-b >= 45)
                hits++
        }
    }
    return hits >= 2 && UM14_ConnectionSame(identity)
}

UM14_StartupRetryAllowed(identity, overlay, previous, now) {
    ; A second press is safe only for the same positively recognized control,
    ; in the same unchanged Roblox client, after the transition had time to run.
    return IsObject(overlay.button) && (!IsObject(previous) || (previous.count = 1
        && previous.key == identity.key && now-previous.at >= 1250
        && UM14_ButtonStillAt(previous.button,overlay.button)))
}

UM14_StartupButtonStillAt(identity, overlay) {
    current := UM14_StartupOverlay(identity,&evidence,overlay)
    return IsObject(current) && current.kind = overlay.kind && UM14_ButtonStillAt(overlay.button,current.button)
}

UM14_ClickStartupOverlay(identity, overlay) {
    if !IsObject(overlay.button)
        return false
    return UM14_HeldClick(identity,overlay.button.x,overlay.button.y,overlay.action,180,
        () => UM14_StartupButtonStillAt(identity,overlay))
}

UM14_VerifiedResults() {
    identity := UM14_ConnectionSnapshot()
    if !IsObject(identity)
        return false
    for result in ["Triumph", "Loss"] {
        if !UM14_MatchScreenEvidence(result,identity.w,identity.h)
            continue
        Sleep(400)
        if (UM14_ConnectionSame(identity) && UM14_MatchScreenEvidence(result,identity.w,identity.h))
            return UM14_ConnectionSame(identity)
    }
    return false
}

UM14_BestRestart(normal, alternate) {
    a := normal.status = "success" && normal.score > .64
    b := alternate.status = "success" && alternate.score > .64
    return b && (!a || alternate.score > normal.score) ? "Restart2.png" : a ? "Restart.png" : ""
}

UM14_ResultButton(identity, image) {
    region := UM14_Region(0,Round(identity.h*.5),identity.w,
        identity.h-Round(identity.h*.5),identity.w,identity.h)
    button := UM14_MenuImagePair(identity,region,image,.65)
    if (!IsObject(button) && (image = "Restart.png" || image = "Restart2.png"))
        button := UM14_MenuImagePair(identity,region,image = "Restart.png" ? "Restart2.png" : "Restart.png",.65)
    return button
}

UM14_ClickResult(image, label) {
    UM14_RequireReadyFocus()
    identity := UM14_ConnectionSnapshot()
    if !IsObject(identity)
        UM14_LobbyFailure(label " on the match-results screen")
    button := UM14_ResultButton(identity,image)
    if !IsObject(button)
        UM14_LobbyFailure(label " on the match-results screen")
    region := UM14_StartupRegion(identity,.17,.50,.83,.94)
    Loop 2 {
        ; The current Restart Match image is just the caption. In compact
        ; mode the hand covers its letters, so use the verified green margin.
        ; Keep the exact Restart/Play Again template; never match Restart Wave.
        point := IsObject(region) ? UM14_ReadyPressPoint(identity,button,region) : false
        if !IsObject(point)
            point := button
        if !UM14_HeldClick(identity,point.x,point.y,label,150,
            () => UM14_ButtonStillAt(button,UM14_ResultButton(identity,image)))
            UM14_LobbyFailure(label " after moving the pointer")
        Sleep(500)
        fresh := UM14_ResultButton(identity,image)
        if !UM14_ConnectionSame(identity)
            UM14_Fatal(label " input ended because Roblox changed or lost focus.")
        if !IsObject(fresh) {
            Sleep(250)
            fresh := UM14_ResultButton(identity,image)
            if !UM14_ConnectionSame(identity)
                UM14_Fatal(label " input ended because Roblox changed or lost focus.")
            if !IsObject(fresh)
                return true
        }
        if !UM14_ButtonStillAt(button,fresh)
            break
    }
    UM14_LobbyFailure(label " transition after clicking")
}

UM14_ApplyGameInput() {
    global DefaultMouseSpeed, MouseDelay, KeyDelay
    ; Launcher starts execute on a timer thread, not the old GUI's click thread.
    ; Explicitly keep legacy Event mouse movement and the user's original values.
    SendMode("Event")
    CoordMode("Mouse","Client")
    CoordMode("Pixel","Client")
    SetDefaultMouseSpeed(Integer(DefaultMouseSpeed))
    SetMouseDelay(Max(10,Integer(MouseDelay)))
    SetKeyDelay(Max(20,Integer(KeyDelay)))
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
    global LastOpenedTowerID, unfocusX, unfocusY, CancelPlacementKey
    UM14_RequireReadyFocus()
    ; A visible DJ/previous-tower menu is not evidence that the NEXT tower was
    ; placed. Establish a closed-menu boundary before selecting the next slot.
    if (waitForTowerUI(&oldV2, &oldV1, 120)) {
        identity := UM14_ConnectionSnapshot()
        if !IsObject(identity)
            UM14_Fatal("Roblox changed before clearing the previous tower menu.")
        Loop 3 {
            UM14_RequireReadyFocus()
            if (A_Index = 1) {
                SendEvent("{" CancelPlacementKey "}")
            } else {
                UM14_HeldClick(identity, ScaleX(unfocusX), ScaleY(unfocusY), "Close tower menu")
            }
            Sleep(180)
            clear := 0
            start := A_TickCount
            Loop {
                if !UM14_ConnectionSame(identity)
                    UM14_Fatal("Roblox changed while clearing the previous tower menu.")
                clear := waitForTowerUI(,,120) ? 0 : clear+1
                if (clear >= 2) {
                    LastOpenedTowerID := ""
                    return
                }
                if (A_TickCount-start >= 750)
                    break
                Sleep(90)
            }
        }
        UM14_Fatal("The previous tower menu would not close. No new placement was accepted; send the Output log and a screenshot.")
    }
    LastOpenedTowerID := ""
}

UM14_PlacementCounter(identity) {
    ; The unit counter sits just past the last hotbar slot. Its horizontal
    ; distance from center scales with height, even when Roblox is docked.
    x := Round(identity.w*.5 + identity.h*.20), y := Round(identity.h*.935)
    region := UM14_Region(x,y,Min(identity.w-x,Round(identity.h*.18)),identity.h-y-1,identity.w,identity.h)
    if !IsObject(region)
        return false
    for scale in [3.0,3.8] {
        text := UM14_ConnectionOCR(identity,region,scale)
        if (Type(text) != "String" || StrLen(text) > 128
            || !RegExMatch(text,"(?<![\d/])(\d{1,3})\s*/\s*(\d{1,3})(?![\d/])",&count)
            || RegExMatch(text,"\d\s*/\s*\d",,count.Pos(0)+count.Len(0)))
            continue
        used := Integer(count[1]), cap := Integer(count[2])
        if (cap >= 10 && cap <= 500 && used <= cap && UM14_ConnectionSame(identity))
            return {used:used,cap:cap}
    }
    return false
}

UM14_OwnedNewTower(identity, x, y) {
    h := identity.h, left := Max(0,x-Round(h*.25)), top := Max(0,y-Round(h*.14))
    right := Min(identity.w,x+Round(h*.30)), bottom := Min(h,y+Round(h*.035))
    region := UM14_Region(left,top,right-left,bottom-top,identity.w,h)
    if !IsObject(region)
        return false
    text := UM14_ConnectionOCR(identity,region,3.2)
    return Type(text) = "String" && StrLen(text) <= 512 && UM14_MapCaption(text,"Your Tower")
        && RegExMatch(text,"i)\b(?:lvl?|level)\s*[.:-]*\s*0\b") && UM14_ConnectionSame(identity)
}

UM14_NewPlacementProof(identity, x, y, before) {
    if !IsObject(before)
        return false
    after := UM14_PlacementCounter(identity)
    return IsObject(after) && after.cap = before.cap && after.used = before.used+1
        && UM14_OwnedNewTower(identity,x,y)
}

UM14_ConfirmPlacementPanel(identity, cancelKey, x := 0, y := 0, before := false, &panelOpen := false) {
    ; A successful click can open the new tower panel immediately. The
    ; legacy cancel key can also close that panel, losing the only placement
    ; receipt and causing a second purchase. Look for it before cancelling.
    UM14_RequireReadyFocus()
    if !UM14_ConnectionSame(identity)
        UM14_Fatal("Roblox changed while confirming tower placement.")
    panelOpen := false
    if waitForTowerUI(,,650) {
        if !UM14_ConnectionSame(identity)
            UM14_Fatal("Roblox changed while confirming tower placement.")
        return panelOpen := true
    }
    UM14_RequireReadyFocus()
    if !UM14_ConnectionSame(identity)
        UM14_Fatal("Roblox changed while confirming tower placement.")
    SendEvent("{" cancelKey "}")
    ; Older clients can reveal the panel only after clearing the ghost.
    panelOpen := waitForTowerUI()
    if !UM14_ConnectionSame(identity)
        UM14_Fatal("Roblox changed while confirming tower placement.")
    if panelOpen
        return true
    ; Newer TDS can place the tower without opening its upgrade panel.
    ; Only a fresh +1 counter and the owned Lv.0 tooltip at that same point
    ; distinguish this from a failed click. No second slot key is sent.
    if !UM14_NewPlacementProof(identity,x,y,before)
        return false
    if UM14_HeldClick(identity,x,y,"Select placed tower",150,() => UM14_OwnedNewTower(identity,x,y))
        panelOpen := waitForTowerUI(,,1300)
    if !UM14_ConnectionSame(identity)
        UM14_Fatal("Roblox changed while confirming tower placement.")
    return true ; the purchase was confirmed, even if its panel still isn't open
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
    region := UM14_Region(0,Round(identity.h*.77),Max(Round(identity.w*.19),Round(identity.h*.38)),
        identity.h-Round(identity.h*.77),identity.w,identity.h)
    if (!IsObject(region))
        UM14_Fatal("Modifier control region was not verified.")
    vote := UM14_Region(Round(identity.w*.25),Round(identity.h*.66),
        Round(identity.w*.5),Round(identity.h*.34),identity.w,identity.h)
    if (!IsObject(UM14_MenuImagePair(identity,vote,"Ready.png",.7)))
        UM14_Fatal("Map vote screen could not be verified. No modifier click was sent.")
    factor := Min(3.0,2500/Max(region.w,region.h))
    ; 1.3.3.10 starts at the bottom-left icon. Its label is a hover
    ; tooltip, so click the confirmed hover point, not the tooltip text.
    x := Round(Max(18,Min(56,identity.w*56/1920)))
    for fraction in [930/1009,.945,.965,.98] {
        UM14_RequireReadyFocus()
        if (!UM14_ConnectionSame(identity))
            UM14_Fatal("Modifier setup lost its game client.")
        y := Min(identity.h-2,Round(identity.h*fraction))
        MouseMove(x,y)
        Sleep(260)
        UM14_RequireReadyFocus()
        if (!UM14_ConnectionSame(identity))
            UM14_Fatal("Modifier setup lost its game client.")
        button := UM14_ModifierButton(UM14_ConnectionOCR(identity,region,factor,"",true),region,factor)
        if (!IsObject(button) || button.y >= y || Abs(button.x-x) > Max(identity.w*.07,identity.h*.14))
            continue
        Sleep(100)
        UM14_RequireReadyFocus()
        if (!UM14_ConnectionSame(identity))
            UM14_Fatal("Modifier setup lost its game client.")
        again := UM14_ModifierButton(UM14_ConnectionOCR(identity,region,factor,"",true),region,factor)
        if (!IsObject(again) || Abs(button.x-again.x) > 4 || Abs(button.y-again.y) > 4)
            continue
        UM14_RequireReadyFocus()
        if (!UM14_ConnectionSame(identity))
            UM14_Fatal("Modifier setup lost its game client.")
        MouseGetPos(&hoverX,&hoverY)
        if (Abs(hoverX-x) > 2 || Abs(hoverY-y) > 2)
            UM14_Fatal("The mouse moved while verifying Add Modifier. No modifier click was sent.")
        Click(x,y)
        return
    }
    UM14_Fatal("Add Modifier could not be verified. No modifier click was sent.")
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

UM14_MenuWord(identity, region, expected, caption := false, ellipsis := false, requestedScale := 0, titleAboveSubtitle := false) {
    if (requestedScale != 0 && (!IsNumber(requestedScale) || requestedScale < .125 || requestedScale > 4))
        return false
    factor := Min(requestedScale ? requestedScale : (region.w < identity.w*.12 ? 3.0 : 2.0),2500/Max(region.w,region.h))
    words := UM14_OCRWords(UM14_ConnectionOCR(identity,region,factor,"",true),region,factor)
    match := ""
    for word in words {
        minimumHeight := region.w < identity.w*.12 ? Max(4,identity.h*.005) : Max(6,identity.h*.007)
        label := ellipsis ? RegExReplace(word.text,"[.…]+$") : word.text
        if (label != StrUpper(expected) || word.h < minimumHeight)
            continue
        ; Difficulty cards repeat the name in lowercase in their descriptions.
        if (caption && word.raw == StrLower(word.raw))
            continue
        candidate := {x:Round(word.x+word.w/2),y:Round(word.y+word.h/2),left:word.x,height:word.h}
        if (IsObject(match)) {
            ; "Hardcore" is repeated in the smaller "Hardcore mode"
            ; subtitle on the same card. Other duplicates are ambiguous.
            if !titleAboveSubtitle
                return false
            top := match.y < candidate.y ? match : candidate
            bottom := match.y < candidate.y ? candidate : match
            if (Abs(top.left-bottom.left) > 6 || bottom.y-top.y > Max(38,top.height*2.3)
                || top.height < bottom.height*1.13 || top.height-bottom.height < 2)
                return false
            candidate := top
        }
        match := candidate
    }
    return UM14_ConnectionSame(identity) ? match : false
}

UM14_MenuWordPair(identity, region, expected, caption := false, ellipsis := false, requestedScale := 0, titleAboveSubtitle := false) {
    UM14_RequireReadyFocus()
    first := UM14_MenuWord(identity,region,expected,caption,ellipsis,requestedScale,titleAboveSubtitle)
    if (!IsObject(first))
        return false
    Sleep(100)
    UM14_RequireReadyFocus()
    second := UM14_MenuWord(identity,region,expected,caption,ellipsis,requestedScale,titleAboveSubtitle)
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

UM14_LobbyPlay() {
    UM14_RequireReadyFocus()
    identity := UM14_ConnectionSnapshot()
    if !IsObject(identity)
        return false
    region := UM14_Region(Round(identity.w*.25), Round(identity.h*.66),
        Round(identity.w*.5), identity.h-Round(identity.h*.66), identity.w, identity.h)
    if !IsObject(region)
        return false
    play := UM14_MenuImagePair(identity, region, "Play.png", .65)
    if !IsObject(play)
        play := UM14_MenuWordPair(identity, region, "PLAY", true)
    return UM14_ConnectionSame(identity) ? play : false
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
    seenMenu := false
    ; Current TDS menu is a scrollable card list with a persistent sidebar.
    ; Old builds searched only the first screen for a retired font template.
    static modes := Map("Easy","Easy","Casual","Casual","Intermediate","Intermediate",
        "Molten","Molten","Fallen","Fallen","Hardcore","Hardcore","Voidcore","Voidcore","Frost","Frost")
    if (!modes.Has(difficulty))
        return false ; Preserve existing special-mode compatibility.
    UM14_RequireReadyFocus()
    identity := UM14_ConnectionSnapshot()
    if (!IsObject(identity))
        return false
    ; In a docked/narrow client the menu fills the viewport and moves the
    ; sidebar against the left edge instead of centering it with the cards.
    verticalEdge := identity.w < identity.h*1.3
    fullWidth := identity.w <= identity.h*1.4
    sidebar := UM14_Region(Round(identity.w*(verticalEdge ? .01 : .12)),Round(identity.h*.09),
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
            if (fullWidth && !IsObject(story)) {
                ; At 800x600, the tiny labels blend into the tab art. Crop and
                ; upscale each one independently before trusting either tab.
                tabY := Round(identity.h*.055), tabH := Round(identity.h*.075)
                survivalTab := UM14_Region(Round(identity.w*.33),tabY,Round(identity.w*.085),tabH,identity.w,identity.h)
                storyTab := UM14_Region(Round(identity.w*.415),tabY,Round(identity.w*.085),tabH,identity.w,identity.h)
                if (IsObject(survivalTab) && IsObject(storyTab)) {
                    survival := UM14_MenuWordPair(identity,survivalTab,"Survival")
                    story := IsObject(survival) ? UM14_MenuWordPair(identity,storyTab,"Story") : false
                }
            }
            if (IsObject(story) && story.x > survival.x && Abs(story.y-survival.y) <= 5)
                navigation := survival
        }
    }
    menuClose := UM14_Region(Round(identity.w*(fullWidth ? .91 : .68)),0,
        Round(identity.w*(fullWidth ? .09 : .20)),Round(identity.h*(fullWidth ? .26 : .15)),identity.w,identity.h)
    cardX := Round(identity.w*(fullWidth ? .10 : .21))
    cardWidth := Round(identity.w*(fullWidth ? .875 : .62))
    cardBottom := Floor(identity.h*(fullWidth ? .98 : .94))
    if (IsObject(navigation)) {
        UM14_RequireReadyFocus()
        if (!UM14_ConnectionSame(identity))
            return false
        if !UM14_HeldClick(identity,navigation.x,navigation.y,"Survival tab")
            return false
        Sleep(450)
    }
    ; The Event and Survival cards can both be visible in the same viewport.
    ; The sidebar proves the Play menu, not which section is under the pointer.
    headingRegion := UM14_Region(cardX,0,Round(identity.w*(fullWidth ? .40 : .27)),
        Round(identity.h*.90),identity.w,identity.h)
    heading := UM14_MenuWordPair(identity,headingRegion,"Survival")
    if (!IsObject(heading) || heading.y >= cardBottom-20)
        return false
    seenMenu := true
    started := A_TickCount
    Loop 9 {
        if (!UM14_ConnectionSame(identity) || A_TickCount-started >= 16000)
            return false
        if (A_Index > 1)
            heading := UM14_MenuWordPair(identity,headingRegion,"Survival")
        storyHeading := UM14_MenuWordPair(identity,headingRegion,"Story")
        top := IsObject(heading) ? Max(Round(identity.h*.08),heading.y+1) : Round(identity.h*.08)
        bottom := IsObject(storyHeading) ? Min(storyHeading.y-1,cardBottom) : cardBottom
        cardRegion := UM14_Region(cardX,top,cardWidth,bottom-top,identity.w,identity.h)
        if (!IsObject(cardRegion))
            return false
        card := UM14_ModeCard(identity,cardRegion,difficulty)
        if (IsObject(card)) {
            UM14_RequireReadyFocus()
            if (!UM14_ConnectionSame(identity))
                return false
            point := UM14_ModeClickPoint(card,cardRegion)
            if !UM14_HeldClick(identity,point.x,point.y,"Difficulty selection",180,
                () => UM14_ButtonStillAt(card,UM14_ModeCard(identity,cardRegion,difficulty)))
                return false
            LogToConsole("Mode selection: currentMenu=1 confirmed=1")
            return true
        }
        ; Re-prove the navigation before every bounded scroll. Capture failure
        ; or an unexpected menu never becomes permission to send wheel input.
        if (A_Index = 9 || IsObject(storyHeading) || (!IsObject(UM14_MenuImagePair(identity,sidebar,"Survival.png"))
            && !IsObject(UM14_MenuImagePair(identity,menuClose,"close.png",.86))
            && !IsObject(UM14_MenuWordPair(identity,sidebar,"Survival"))
            && (!IsSet(tabs) || !IsObject(tabs) || !IsObject(UM14_MenuWordPair(identity,tabs,"Survival")))
            && (!IsSet(survivalTab) || !IsObject(survivalTab)
                || !IsObject(UM14_MenuWordPair(identity,survivalTab,"Survival")))))
            return false
        UM14_RequireReadyFocus()
        x := Round(identity.w*.5), y := Round(identity.h*.5)
        UM14_RequireInputPoint(identity,x,y,"Difficulty list")
        MouseMove(x,y)
        UM14_RequireReadyFocus()
        if (!UM14_ConnectionSame(identity))
            return false
        notches := A_Index = 1 ? UM14_InitialScrollNotches() : 2
        UM14_RequireInputPoint(identity,x,y,"Difficulty list")
        SendEvent("{WheelDown " notches "}")
        Sleep(240)
    }
    return false
}

UM14_ModeClickPoint(card, region) {
    ; A Roblox hand cursor covers short card captions (especially Easy).
    ; Press the adjoining interior on the same row so the exact caption can
    ; still be read again after the mouse moves. Image matches retain center.
    if (card.HasOwnProp("left") && card.HasOwnProp("height")) {
        x := Round(2*card.x-card.left+Max(12,Min(24,card.height)))
        if UM14_StartupPointIn(region,x,card.y)
            return {x:x,y:card.y}
    }
    return {x:card.x,y:card.y}
}

UM14_ModeCard(identity, region, difficulty) {
    ; Artwork is not an identifier: Easy and Casual share scenery and the
    ; Hardcore / Voidcore art can share effects. Prefer the actual label.
    twoCards := difficulty = "Hardcore" || difficulty = "Voidcore"
    if twoCards {
        ; Hardcore and Voidcore are side by side. The Voidcore unlock text
        ; itself says Hardcore; never treat that right-hand text as a card.
        half := Floor(region.w/2)
        region := UM14_Region(region.x+(difficulty = "Voidcore" ? half : 0),region.y,
            half,region.h,identity.w,identity.h)
        if !IsObject(region)
            return false
        if (difficulty = "Voidcore" && UM14_MapCaption(UM14_ConnectionOCR(identity,region,2.4),"Complete Hardcore to unlock"))
            UM14_Fatal("Voidcore is locked on this Roblox account. Complete Hardcore in TDS before running a Voidcore strategy.")
    }
    card := UM14_MenuWordPair(identity,region,difficulty,true,false,0,difficulty = "Hardcore")
    if (!IsObject(card) && (difficulty = "Easy" || difficulty = "Casual" || twoCards))
        card := UM14_MenuWordPair(identity,region,difficulty,true,false,2.8,difficulty = "Hardcore")
    if (!IsObject(card) && difficulty != "Easy" && difficulty != "Casual"
        && difficulty != "Hardcore" && difficulty != "Voidcore")
        card := UM14_MenuImagePair(identity,region,difficulty ".png")
    return card
}

UM14_InitialScrollNotches() {
    global SettingsFile
    if (IniRead(SettingsFile,"Options","ScrollDownForMap","0") != "1")
        return 2
    ; Small steps keep Fallen/Frost and Hardcore in view; allow slower clients
    ; more time to settle without skipping whole rows in one wheel burst.
    delay := IniRead(SettingsFile,"Options","ScrollDelay","0")
    if RegExMatch(delay,"^\d{1,4}$")
        Sleep(Min(Integer(delay),5000))
    UM14_RequireReadyFocus()
    notches := IniRead(SettingsFile,"Options","ScrollDownAmount","5")
    return RegExMatch(notches,"^\d{1,2}$") ? Max(2,Min(4,Integer(notches))) : 2
}

UM14_SquadCard(name) {
    UM14_RequireReadyFocus()
    identity := UM14_ConnectionSnapshot()
    if (!IsObject(identity))
        return false
    w := identity.w, h := identity.h
    title := UM14_Region(Round(w*.28),Round(h*.025),Round(w*.44),Round(h*.205),w,h)
    if (!IsObject(title))
        return false
    ; The compact title can be read as a line even when the OCR result has
    ; no usable word boxes. Require the complete dialog title in that case.
    if (!IsObject(UM14_MenuWordPair(identity,title,"Squad",false,true))
        && !UM14_MenuTextPair(identity,title,"Choose a Squad",true))
        return false
    right := name = "Duo" || name = "Quad"
    bottom := name = "Trio" || name = "Quad"
    card := UM14_Region(Round(w*(right ? .49 : .19)),Round(h*(bottom ? .53 : .34)),
        Round(w*.32),Round(h*.23),w,h)
    match := IsObject(card) ? UM14_MenuWordPair(identity,card,name,true) : false
    if (!IsObject(match)) {
        label := UM14_Region(Round(w*(right ? .50 : .22)),Round(h*(bottom ? .57 : .39)),
            Round(w*.19),Round(h*.13),w,h)
        if (IsObject(label) && UM14_MenuTextPair(identity,label,name))
            match := {x:Round(label.x+label.w/2),y:Round(label.y+label.h/2)}
    }
    if (IsObject(match))
        match.identity := identity
    return match
}

UM14_MenuTextPair(identity, region, expected, ellipsis := false) {
    Loop 2 {
        UM14_RequireReadyFocus()
        if !UM14_ConnectionSame(identity)
            return false
        factor := Min(3.0,2200/Max(region.w,region.h))
        text := UM14_ConnectionOCR(identity,region,factor)
        if (Type(text) != "String")
            return false
        matches := 0
        for line in StrSplit(text,"`n","`r") {
            line := Trim(line)
            if (ellipsis)
                line := RegExReplace(line,"[.…]+$")
            if (StrLower(line) = StrLower(expected))
                matches++
        }
        if (matches != 1 || !UM14_ConnectionSame(identity))
            return false
        if (A_Index = 1)
            Sleep(100)
    }
    return true
}

UM14_MapOverridePrompt() {
    UM14_RequireReadyFocus()
    identity := UM14_ConnectionSnapshot()
    if (!IsObject(identity))
        return false
    w := identity.w, h := identity.h
    ready := UM14_Region(Round(w*.32),Round(h*.55),Round(w*.36),Round(h*.37),w,h)
    if !UM14_MapVoteHeading(identity) && !IsObject(UM14_MenuImagePair(identity,ready,"Ready.png",.76))
        return false
    ; Roblox keeps a near-fixed caption size on compact clients. The old
    ; percentage crop cut both ends off "Override Map" at 800 pixels wide.
    prompt := UM14_StartupRegion(identity,.19,.39,.81,.76)
    if !IsObject(prompt)
        return false
    Loop 2 {
        text := UM14_ConnectionOCR(identity,prompt,2.8)
        ; WinRT can flatten the separate E glyph and the caption. Match the
        ; complete label in this bounded vote crop, not an entire OCR line.
        if (!UM14_MapCaption(text,"Override Map") || !UM14_ConnectionSame(identity))
            return false
        if (A_Index = 1)
            Sleep(100)
    }
    return UM14_ConnectionSame(identity) ? identity : false
}

UM14_MapPurchaseText(text) {
    return Type(text) = "String" && StrLen(text) <= 4096
        && RegExMatch(text,"i)\b(?:Buy\s+Robux|Buy\s+Item|Purchase\s+Item|Not\s+Enough\s+Robux|Insufficient\s+Robux)\b")
}

UM14_RejectMapPurchase(identity) {
    if !UM14_ConnectionSame(identity)
        UM14_Fatal("Roblox changed during map override. No more input was sent.")
    region := UM14_Region(Round(identity.w*.22),Round(identity.h*.22),Round(identity.w*.56),
        Round(identity.h*.52),identity.w,identity.h)
    if !IsObject(region)
        UM14_Fatal("Could not verify the map-override window. No more input was sent.")
    text := UM14_ConnectionOCR(identity,region,1.5)
    if UM14_MapPurchaseText(text)
        UM14_Fatal("Roblox opened a purchase prompt while overriding the map. No purchase was made. Close the prompt and vote for the map normally, or use an account that already has map override access.")
    if (UM14_ConnectionOCRStage() != "success" || !UM14_ConnectionSame(identity))
        UM14_Fatal("Could not verify the map-override window. No more input was sent.")
}

UM14_MapVoteHeading(identity) {
    ; The large title is adjacent to Roblox's top bar and a second flashing
    ; prompt. Read its own line instead of mixing both with clipped HUD icons.
    region := UM14_StartupRegion(identity,.29,.014,.75,.105)
    if !IsObject(region)
        return false
    for scale in [1.7,2.6] {
        text := UM14_ConnectionOCR(identity,region,scale)
        if (Type(text) = "String" && RegExMatch(text,"i)\bVote\s+for\s+a\s*Map\b"))
            return true
    }
    return false
}

UM14_MapSearchTabs(identity, field) {
    ; If the title's outlined font is unreadable, these adjacent map-filter
    ; labels still identify the picker independently from its textbox.
    x := Max(0,Round(field.left-field.height*3)), y := Round(field.y+field.height*.85)
    region := UM14_Region(x,y,Round(identity.w*.49),Max(27,Round(field.height*3.2)),identity.w,identity.h)
    if !IsObject(region)
        return false
    text := UM14_ConnectionOCR(identity,region,3.2)
    return UM14_MapCaption(text,"All Maps") && (UM14_MapCaption(text,"Normal")
        || UM14_MapCaption(text,"Insane") || UM14_MapCaption(text,"Hard"))
}

UM14_MapSearchWords(words, phrase) {
    want := StrSplit(StrUpper(Trim(phrase))," ")
    if (!want.Length || want.Length > 10)
        return false
    found := false
    for first in words {
        if (first.text != want[1] || first.h < 5)
            continue
        left := first.x, right := first.x+first.w, center := first.y+first.h/2, height := first.h
        complete := true
        Loop want.Length-1 {
            next := false, target := want[A_Index+1]
            for word in words {
                if (word.x < right-1 || word.x-right > height*1.7 || Abs((word.y+word.h/2)-center) > height*.55)
                    continue
                if (!IsObject(next) || word.x < next.x)
                    next := word
            }
            if (!IsObject(next) || next.text != target || next.h < 5) {
                complete := false
                break
            }
            right := next.x+next.w
        }
        if !complete
            continue
        for word in words {
            if (word.x >= right-1 && word.x-right <= height*1.7 && Abs((word.y+word.h/2)-center) <= height*.55) {
                complete := false
                break
            }
        }
        if !complete
            continue
        if IsObject(found)
            return false ; two matching labels cannot identify one textbox
        found := {left:left, right:right, y:Round(center), height:height}
    }
    return found
}

UM14_MapSearchField(identity, &evidence := "") {
    region := UM14_StartupRegion(identity,.12,.155,.76,.51)
    if !IsObject(region)
        return false
    factor := Min(3.0,2500/Max(region.w,region.h))
    words := UM14_OCRWords(UM14_ConnectionOCR(identity,region,factor,"",true),region,factor)
    label := UM14_MapSearchWords(words,"Search for Maps")
    evidence := "label=" (IsObject(label) ? "found" : UM14_ConnectionOCRStage())
    if !IsObject(label) {
        ; The compact placeholder is gray on a translucent background. Reuse
        ; its two-frame image match, but keep the pointer off the label itself.
        image := UM14_MenuImagePair(identity,region,"searchbar.png",.72)
        if (IsObject(image) && image.HasOwnProp("w") && image.w >= 40 && image.h >= 8) {
            label := {left:image.x-image.w*.36,right:image.x+image.w*.5,y:image.y,height:Max(8,image.h*.63)}
            evidence .= " template=found"
        } else {
            evidence .= " template=unverified"
        }
    }
    if !IsObject(label)
        return false
    ; Enter in the empty part of the same row, where Roblox's I-beam will
    ; not cover the placeholder during the post-hover verification.
    x := Round(label.right+Max(14,label.height*1.25))
    if !UM14_StartupPointIn(region,x,label.y)
        return false
    darker := 0
    ; Roblox draws a light I-beam and hover glow exactly at the pointer.
    ; Sample the continuation of the same textbox past the caret, not the
    ; pointer pixels that otherwise invalidate a correct field on hover.
    for across in [14,24,34] {
        for down in [-5,5] {
            if !UM14_StartupPointIn(region,x+across,label.y+down)
                continue
            try {
                rgb := PixelGetColor(x+across,label.y+down)
                if Max((rgb>>16)&255,(rgb>>8)&255,rgb&255) <= 140
                    darker++
            }
        }
    }
    evidence .= " field=" (darker >= 3 ? "dark" : "unverified")
    if (darker < 3 || !UM14_ConnectionSame(identity))
        return false
    return {x:x,y:label.y,left:label.left,height:label.height}
}

UM14_MapOverrideSearch(identity, &evidence := "") {
    UM14_RejectMapPurchase(identity)
    first := UM14_MapSearchField(identity,&evidence)
    if !IsObject(first)
        return false
    if !UM14_MapVoteHeading(identity) && !UM14_MapSearchTabs(identity,first) {
        evidence .= " vote-context=unverified"
        return false
    }
    Sleep(100)
    second := UM14_MapSearchField(identity,&evidence)
    return UM14_ButtonStillAt(first,second,5) ? second : false
}

UM14_MapQueryAt(identity, anchor, name) {
    x := Max(0,Round(anchor.left-10)), y := Max(0,anchor.y-13)
    width := Min(Round(identity.w*.49),Max(120,Round((StrLen(name)+4)*Max(9,anchor.height*.9))))
    region := UM14_Region(x,y,width,26,identity.w,identity.h)
    if !IsObject(region)
        return false
    name := StrLower(Trim(RegExReplace(name,"\s+"," ")))
    for scale in [2.6,3.5] {
        readback := UM14_ConnectionOCR(identity,region,scale)
        if (Type(readback) != "String" || StrLen(readback) > 160)
            continue
        line := StrLower(Trim(RegExReplace(readback,"\s+"," ")))
        ; At the far left, WinRT sometimes includes the small translate icon.
        if (line = name || line = "a " name)
            return UM14_ConnectionSame(identity)
    }
    return false
}

UM14_MapOverrideCard(identity, anchor, name, &evidence := "", samples := 2) {
    UM14_RejectMapPurchase(identity)
    confirmed := 0
    Loop samples+1 {
        if !UM14_ConnectionSame(identity)
            return false
        if UM14_MapQueryAt(identity,anchor,name)
            confirmed++
        if (confirmed >= samples)
            break
        Sleep(100)
    }
    if (confirmed < samples) {
        evidence := "query=" (confirmed ? "unstable" : UM14_ConnectionOCRStage())
        return false
    }
    ; With the exact typed query confirmed in the field, the first filtered
    ; tile is below its left edge. Only continue after the exact map receipt.
    x := Round(anchor.left+Max(17,anchor.height*1.55))
    y := anchor.y+Max(73,Min(155,Round(anchor.height*6.5)))
    tiles := UM14_StartupRegion(identity,.10,.27,.75,.76)
    evidence := "query=verified"
    return UM14_StartupPointIn(tiles,x,y) ? {x:x,y:y} : false
}

UM14_MapHoveredCardName(identity, card, field, name) {
    ; The tile shows its map title only on hover. Match that title in a crop
    ; below the pointer, independently of the text in the search field.
    UM14_RejectMapPurchase(identity)
    half := Max(58,Min(122,Round(field.height*4.6)))
    height := Max(34,Round(field.height*3.3))
    ; The hover caption can shift vertically as the tile scales. Inspect
    ; both halves of this same tile, never the query field or its neighbors.
    for top in [card.y+2, Max(field.y+30,card.y-Round(height*.6))] {
        region := UM14_Region(Max(0,card.x-half),top,half*2,height,identity.w,identity.h)
        if !IsObject(region)
            continue
        text := UM14_ConnectionOCR(identity,region,3.2)
        if (Type(text) = "String" && StrLen(text) <= 160
            && Trim(RegExReplace(text,"\s+"," ")) = name && UM14_ConnectionSame(identity))
            return true
    }
    return false
}

UM14_MapReceiptGreen(identity) {
    region := UM14_StartupRegion(identity,.25,.23,.75,.315)
    if (!IsObject(region) || !UM14_ConnectionSame(identity) || !UM14_ConnectionCaptureClear(identity,region))
        return -1 ; capture unavailable is not a verified clear baseline
    try {
        ; The legacy map-change toast is bright pure green. Find more than
        ; one glyph-sized patch in its narrow central band, not green terrain.
        right := region.x+region.w-1, bottom := region.y+region.h-1
        if !PixelSearch(&x,&y,region.x,region.y,right,bottom,0x00EC00,12)
            return false
        if (x+8 > right || !PixelSearch(&x2,&y2,x+8,Max(region.y,y-5),right,Min(bottom,y+8),0x00EC00,12))
            return false
        return UM14_ConnectionSame(identity) && UM14_ConnectionCaptureClear(identity,region) ? 1 : -1
    } catch {
        return -1
    }
}

UM14_MapReceiptText(recognized, region, factor, name, &other) {
    other := "", text := "", lines := []
    if IsObject(recognized) {
        try {
            text := recognized.Text
            for line in recognized.Lines {
                if (lines.Length >= 24)
                    break
                lines.Push(line.Text)
            }
        }
    } else if (Type(recognized) = "String") {
        text := recognized, lines := StrSplit(text,"`n","`r")
    }
    if UM14_MapPurchaseText(text)
        return "purchase"
    if (UM14_MapCaption(text,"already in the current rotation") || UM14_MapCaption(text,"already in current rotation"))
        return "rotation"
    expected := Trim(RegExReplace(StrLower(name),"[^a-z0-9']+"," "))
    for line in lines {
        if (Type(line) != "String" || StrLen(line) > 160)
            continue
        clean := Trim(RegExReplace(StrLower(line),"[^a-z0-9']+"," "))
        if RegExMatch(clean,"^map changed to (.+)$",&receipt) {
            if (receipt[1] = expected)
                return "changed"
            other := receipt[1]
        }
    }
    ; Whole-frame Text can join adjacent HUD text to a short green toast.
    ; Verify that the exact words are on the same line with no extra word
    ; attached; a longer map name sharing the same prefix isn't accepted.
    if IsObject(UM14_MapSearchWords(UM14_OCRWords(recognized,region,factor),"Map changed to " name))
        return "changed"
    return ""
}

UM14_MapOverrideReceipt(identity, name, field := false, titleVerified := false, beforeGreen := false, timeout := 4100, &evidence := "") {
    region := UM14_StartupRegion(identity,.23,.21,.77,.34)
    toast := UM14_StartupRegion(identity,.28,.22,.72,.315)
    if (!IsObject(region) || !IsObject(toast))
        return ""
    start := A_TickCount
    observedGreen := false, observedText := false, lastOther := "", sightings := 0, scaleIndex := 0
    while (A_TickCount-start < timeout && UM14_ConnectionSame(identity)) {
        ; Capture the short green line first. The selected-window path works
        ; even when a click-through overlay would invalidate desktop pixels.
        toastFactor := Min(3.3,2500/Max(toast.w,toast.h))
        masked := UM14_ConnectionOCR(identity,toast,toastFactor,"",true,true)
        if (UM14_MapReceiptText(masked,toast,toastFactor,name,&maskedOther) = "changed") {
            UM14_RejectMapPurchase(identity)
            return "changed"
        }
        green := UM14_MapReceiptGreen(identity) = 1
        observedGreen := observedGreen || green
        appeared := titleVerified && beforeGreen = 0 && IsObject(field) && green
        factor := Min(Mod(scaleIndex++,2) ? 2.8 : 3.5,2500/Max(region.w,region.h))
        recognized := UM14_ConnectionOCR(identity,region,factor,"",true)
        observedText := observedText || UM14_ConnectionOCRStage() = "success"
        receipt := UM14_MapReceiptText(recognized,region,factor,name,&other)
        if (receipt = "purchase")
            UM14_RejectMapPurchase(identity)
        if (receipt = "changed" || receipt = "rotation")
            return receipt
        if (maskedOther != "")
            other := maskedOther
        if (other != "") {
            sightings := other = lastOther ? sightings+1 : 1
            lastOther := other
            if (sightings >= 2)
                return "different"
        }
        ; Accept the visual toast only after pressing the exact hovered tile,
        ; and only if the search UI is no longer present in a readable frame.
        if (appeared && lastOther = "" && !UM14_MapQueryAt(identity,field,name)
            && UM14_ConnectionOCRStage() = "success" && UM14_ConnectionSame(identity))
            return "changed"
        Sleep(140)
    }
    evidence := "hover-title=" (titleVerified ? "exact" : "unverified")
        . " toast-before=" beforeGreen " toast-after=" Integer(observedGreen) " readable=" Integer(observedText)
    return ""
}

UM14_MapCardBeforePress(identity, card, field, name, &evidence, &titleVerified, &beforeGreen) {
    titleVerified := UM14_MapHoveredCardName(identity,card,field,name)
    if (!titleVerified && !UM14_ButtonStillAt(card,UM14_MapOverrideCard(identity,field,name,&evidence,1)))
        return false
    beforeGreen := UM14_MapReceiptGreen(identity)
    return UM14_ConnectionSame(identity)
}

UM14_ReadyButton(identity, &readable := false) {
    readable := false
    w := identity.w, h := identity.h
    region := UM14_Region(Round(w*.29),Round(h*.035),Round(w*.42),Round(h*.38),w,h)
    if !IsObject(region)
        return false
    image := UM14_MenuImagePair(identity,region,"ready_gs.png",.76)
    if IsObject(image) {
        readable := true
        return image
    }
    ; Revalidate a current label against the button background. Green map
    ; terrain or HUD text on its own is never a Ready coordinate.
    label := UM14_MenuWordPair(identity,region,"READY")
    readable := UM14_ConnectionOCRStage() = "success" && UM14_ConnectionSame(identity)
    return readable && IsObject(label) && UM14_ReadyBackground(identity,label) ? label : false
}

UM14_ReadyBackground(identity, label) {
    matches := 0
    for dy in [-1,1] {
        for dx in [-1,1] {
            x := label.x+dx*Max(7,Round(identity.h*.012))
            y := label.y+dy*Max(5,Round(identity.h*.009))
            if (x < 0 || x >= identity.w || y < 0 || y >= identity.h)
                continue
            try {
                rgb := PixelGetColor(x,y)
                r := (rgb>>16)&255, g := (rgb>>8)&255, b := rgb&255
                if (g >= 130 && g-r >= 42 && g-b >= 42)
                    matches++
            }
        }
    }
    return matches >= 2 && UM14_ConnectionSame(identity)
}

UM14_ClickMatchReady(identity, button) {
    region := UM14_StartupRegion(identity,.29,.035,.71,.415)
    if !IsObject(region)
        return false
    Loop 3 {
        ; The hand cursor overlaps the short Ready caption if placed at its
        ; center. Press an adjacent point inside the same verified button.
        point := UM14_ReadyPressPoint(identity,button,region)
        if (!IsObject(point)
            || !UM14_HeldClick(identity,point.x,point.y,"In-match Ready",180,
            () => UM14_ButtonStillAt(button,UM14_ReadyButton(identity)))
        )
            return false
        gone := 0
        Loop 4 {
            Sleep(250)
            fresh := UM14_ReadyButton(identity,&readable)
            if !UM14_ConnectionSame(identity)
                return false
            gone := readable && !IsObject(fresh) ? gone+1 : 0
            if (gone >= 2)
                return true
        }
        if !UM14_ButtonStillAt(button,fresh)
            return false
    }
    return false
}

UM14_ReadyPressPoint(identity, button, region) {
    point := UM14_ModeClickPoint(button,region)
    ; The legacy image is a crop of the *label*, not the button. Step past
    ; the label and require green button pixels at the new press location.
    dx := button.HasOwnProp("w") && button.w >= 20 ? Floor(button.w/2)+8 : Max(20,point.x-button.x)
    for x in [button.x+dx,button.x-dx,button.x+dx-4] {
        for y in [button.y,button.y-5] {
            if UM14_StartupPointIn(region,x,y) && UM14_ReadyBackground(identity,{x:x,y:y})
                return {x:x,y:y}
        }
    }
    return false
}

UM14_MapCaption(text, expected) {
    if (Type(text) != "String" || StrLen(text) > 16384)
        return false
    clean := " " Trim(RegExReplace(StrLower(text), "[^a-z0-9']+", " ")) " "
    name := " " Trim(RegExReplace(StrLower(expected), "[^a-z0-9']+", " ")) " "
    return StrLen(name) > 2 && InStr(clean, name)
}

UM14_HardcoreMapSlot(expected) {
    UM14_RequireReadyFocus()
    identity := UM14_ConnectionSnapshot()
    if !IsObject(identity)
        return 0
    boundaries := [0, Floor(identity.w*.3307), Floor(identity.w*.5036), Floor(identity.w*.6765), identity.w]
    Loop 4 {
        slot := A_Index
        region := UM14_Region(boundaries[slot], 0, boundaries[slot+1]-boundaries[slot],
            Floor(identity.h*.6), identity.w, identity.h)
        good := true
        Loop 2 {
            if (!UM14_ConnectionSame(identity)
                || !UM14_MapCaption(UM14_ConnectionOCR(identity,region,1.5), expected)) {
                good := false
                break
            }
            if (A_Index = 1)
                Sleep(100)
        }
        if (good && UM14_ConnectionSame(identity))
            return slot
    }
    return 0
}

UM14_MapImageVerified(result, mode) {
    return IsObject(result) && result.status = "success"
        && result.score >= (mode = "Hardcore" || mode = "Voidcore" ? .82 : .62)
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
