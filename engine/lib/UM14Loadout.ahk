; Owned-loadout confirmation guards. Part of the GPLv3 legacy engine bridge.
; Only existing EQUIP/UNEQUIP controls are accepted. No purchase action exists.
UM14_LoadoutOCR(x, y, width, height, scale := 0, band := "") {
    UM14_LoadoutOCRState("context")
    UM14_RequireReadyFocus()
    expected := UM14_ConnectionSnapshot()
    if (!IsObject(expected))
        return ""
    region := UM14_Region(x, y, width, height, expected.w, expected.h)
    if (!IsObject(region) || region.x != x || region.y != y || region.w != width || region.h != height) {
        UM14_LoadoutOCRState("region")
        return ""
    }
    ; Shared read-only OCR pins HWND, PID, creation time, thread, client origin
    ; and dimensions before/after capture, and refuses overlapping windows.
    text := IsObject(band) ? UM14_ConnectionOCR(expected,region,scale,band)
        : (scale > 0 ? UM14_ConnectionOCR(expected,region,scale) : UM14_ConnectionOCR(expected,region))
    UM14_LoadoutOCRState(UM14_ConnectionOCRStage())
    return text
}

UM14_LoadoutName(value) {
    normalized := StrUpper(RegExReplace(value,"[^A-Za-z0-9]",""))
    return normalized = "DJ" ? "DJBOOTH" : normalized
}

UM14_LoadoutOCRState(value := "") {
    static stage := "context"
    if (value != "")
        stage := RegExMatch(value,"^(context|region|overlap|bitmap|resize|hbitmap|ocr|window|success)$") ? value : "context"
    return stage
}

UM14_LoadoutTitle(tower, &observation := "") {
    observation := {length:0, stage:"context", overlap:"none"}
    getRobloxPos(,, &width, &height)
    if (!UM14_Viewport(width,height))
        return false
    ; Keep context for OCR, but read ONLY full word boxes inside the title band.
    ; WinRT joins Scout+Offense into one line in the supplied real frames; a
    ; narrow isolated crop can instead lose Scout entirely at some scales.
    ; Spatial word selection excludes the role row without fuzzy name matching.
    band := {x:Round(width*.56),y:Round(height*.13),w:Round(width*.32),h:Round(height*.15),minH:Max(8,Floor(height*.028))}
    ; Font rasterization changes with resolution/DPI. A small, fixed scale
    ; set can recover a real WHOLE title without accepting spelling edits,
    ; substrings or role captions. Every read still pins the selected client;
    ; the action guard requires two independent full observations afterward.
    for factor in [Min(4.0,2160/height),1.0,1.5] {
        text := UM14_LoadoutOCR(Round(width*.52),Round(height*.12),Round(width*.40),Round(height*.20),factor,band)
        observation := {length:Min(StrLen(text),4096), stage:UM14_LoadoutOCRState(),
            overlap:UM14_LoadoutOverlap(UM14_ConnectionOCROverlap())}
        matches := 0
        for line in StrSplit(text,"`n","`r")
            if (UM14_LoadoutName(line) = UM14_LoadoutName(tower))
                matches += 1
        if (matches = 1)
            return true
        if (observation.stage != "success")
            break ; Re-scaling cannot fix a blocked/failed capture.
    }
    return false
}

UM14_LoadoutTextFacts(text) {
    text := SubStr(text,1,4096)
    ; Only fixed-vocabulary booleans leave this scope, never recognized text.
    return {length:StrLen(text),
        equip:!!RegExMatch(text,"i)(?<![A-Za-z])EQUIP(?![A-Za-z])"),
        unequip:!!RegExMatch(text,"i)(?<![A-Za-z])UNEQUIP(?![A-Za-z])"),
        skins:!!RegExMatch(text,"i)(?<![A-Za-z])SKINS(?![A-Za-z])"),
        stage:UM14_LoadoutOCRState(), overlap:UM14_LoadoutOverlap(UM14_ConnectionOCROverlap())}
}

UM14_LoadoutOverlap(value) {
    if (Type(value) != "String" || StrLen(value) > 180)
        return "none"
    if (value = "none")
        return value
    if (!RegExMatch(value,"^kind=(?:engine|game|other) owner=(?:macro-gui|legacy-host|python-worker|other) cloakKnown=[01] cloaked=[0-7] layered=[01] transparent=[01] alphaKnown=[01] alpha=([0-9]{1,3}) flags=[0-3] x=([0-9]{1,4}) y=([0-9]{1,4}) w=([0-9]{1,4}) h=([0-9]{1,4})$",&match))
        return "none"
    if (Integer(match[1]) > 255)
        return "none"
    Loop 4
        if (Integer(match[A_Index+1]) > 8192)
            return "none"
    return value
}

UM14_LoadoutGeometry(x, y, width, height) {
    valid := true
    for value in [x,y,width,height]
        if (Type(value) != "Integer" || value < 0 || value > 8192)
            valid := false
    ; Client-local geometry only. An invalid tuple emits fixed zeroes plus
    ; valid=0, never arbitrary strings or absolute desktop/window coordinates.
    return {valid:valid, x:valid ? x : 0, y:valid ? y : 0,
        w:valid ? width : 0, h:valid ? height : 0}
}

UM14_LoadoutControl(result, action, tower := "", &capture := "") {
    capture := {kind:"none",key:""}
    candidate := false, labelOk := false, titleOk := false, contextOk := false, score := "unknown"
    labelInfo := {length:0,equip:false,unequip:false,skins:false,stage:"context",overlap:"none"}
    titleInfo := {length:0,stage:"context",overlap:"none"}, titleRead := false
    candidateBox := UM14_LoadoutGeometry(-1,-1,-1,-1), cropBox := UM14_LoadoutGeometry(-1,-1,-1,-1)
    try {
        if (IsObject(result) && result.HasOwnProp("score") && IsNumber(result.score) && result.score >= 0 && result.score <= 1)
            score := Round(result.score,3)
        ; The legacy-font image supplies a candidate location, NOT ownership or
        ; permission to click. Exact whole-label OCR, title and identity below
        ; remain authoritative even when the newer font has a lower match score.
        candidate := IsObject(result) && result.status = "success" && result.score >= .4
            && result.HasOwnProp("w") && result.HasOwnProp("h") && result.w >= 10 && result.h >= 8
        if (candidate) {
            UM14_RequireReadyFocus()
            expected := UM14_ConnectionSnapshot()
            if (IsObject(expected)) {
                candidateBox := UM14_LoadoutGeometry(result.x,result.y,result.w,result.h)
                ; Keep LEFT prefix space so EQUIP inside UNEQUIP cannot pass.
                ; Do not extend past the candidate's RIGHT edge: the adjacent
                ; SKINS caption was entering the old symmetric crop (e.g.
                ; EQUIP + partial SK), preventing an otherwise exact label.
                padX := Max(20,Ceil(result.w*.5)), padY := Max(8,Ceil(result.h*.4))
                x := Floor(result.x-result.w/2)-padX, y := Floor(result.y-result.h/2)-padY
                cropBox := UM14_LoadoutGeometry(x,y,result.w+padX,result.h+2*padY)
                text := UM14_LoadoutOCR(x,y,result.w+padX,result.h+2*padY)
                labelInfo := UM14_LoadoutTextFacts(text)
                labelOk := UM14_LoadoutName(text) = action
                if (labelOk) {
                    titleRead := tower != ""
                    titleOk := tower = "" || UM14_LoadoutTitle(tower,&titleInfo)
                }
                contextOk := UM14_ConnectionSame(expected)
            }
        }
    } catch {
        candidate := labelOk := titleOk := contextOk := false
    }
    if (candidate && contextOk) {
        capture := {kind:"other",key:expected.key}
        if (labelInfo.stage = "overlap" || (titleRead && titleInfo.stage = "overlap"))
            capture.kind := "overlap"
    }
    UM14_LoadoutDiagnostic(action,score,candidate,labelOk,titleOk,contextOk,labelInfo,titleRead,titleInfo,candidateBox,cropBox)
    return candidate && labelOk && titleOk && contextOk
}

UM14_LoadoutCaptureStreak(state, capture) {
    current := UM14_ConnectionSnapshot()
    if (capture.kind = "overlap" && IsObject(current) && current.key = capture.key) {
        state.frames := state.key = capture.key ? Min(2,state.frames+1) : 1
        state.key := capture.key
    } else {
        state.frames := 0, state.key := ""
    }
}

UM14_LoadoutBlocked(state) {
    current := UM14_ConnectionSnapshot()
    return state.frames >= 2 && IsObject(current) && current.key = state.key
}

UM14_LoadoutOverlayFailure() {
    UM14_Fatal("An overlay is covering the inventory controls, so the required loadout could not be verified. Hide the covering overlay and retry. No later tower or match was started.")
}

UM14_LoadoutDiagnostic(action,score,candidate,labelOk,titleOk,contextOk,labelInfo,titleRead,titleInfo,candidateBox,cropBox) {
    static last := 0
    if (A_TickCount-last < 1500)
        return
    last := A_TickCount
    ; Fixed action and bounded numeric/boolean fields only. Never OCR text,
    ; screenshots, usernames, private links, tokens or protocol/session data.
    LogToConsole("Loadout readiness: action=" action " score=" score " candidate=" (candidate ? 1 : 0)
        " label=" (labelOk ? 1 : 0) " title=" (titleOk ? 1 : 0) " context=" (contextOk ? 1 : 0)
        " textlen=" labelInfo.length " equip=" (labelInfo.equip ? 1 : 0) " unequip=" (labelInfo.unequip ? 1 : 0)
        " skins=" (labelInfo.skins ? 1 : 0) " capture=" labelInfo.stage
        " overlap=" labelInfo.overlap
        " titleRead=" (titleRead ? 1 : 0) " titlelen=" titleInfo.length " titleCapture=" titleInfo.stage
        " titleOverlap=" titleInfo.overlap
        " candidateBox=" (candidateBox.valid ? 1 : 0) " cx=" candidateBox.x " cy=" candidateBox.y " cw=" candidateBox.w " ch=" candidateBox.h
        " cropBox=" (cropBox.valid ? 1 : 0) " cropx=" cropBox.x " cropy=" cropBox.y " cropw=" cropBox.w " croph=" cropBox.h)
}

UM14_RequireOwnedLoadoutTower(tower) {
    return UM14_WaitLoadoutAction(tower,"",5000)
}

UM14_OCRWords(result, region, factor) {
    words := []
    if (!IsObject(result) || !IsNumber(factor) || factor <= 0)
        return words
    try {
        for word in result.Words {
            if (words.Length >= 512 || Type(word.Text) != "String" || StrLen(word.Text) > 128)
                return []
            box := word.BoundingRect
            for field in ["x","y","w","h"]
                if (!IsNumber(box.%field%) || box.%field% < 0 || box.%field% > 8192)
                    return []
            if (!box.w || !box.h || box.x+box.w > region.w*factor+1 || box.y+box.h > region.h*factor+1)
                return [] ; A clipped/invalid word is never a control.
            words.Push({text:StrUpper(Trim(word.Text)),raw:Trim(word.Text),x:region.x+box.x/factor,y:region.y+box.y/factor,
                w:box.w/factor,h:box.h/factor})
        }
    } catch {
        return []
    }
    return words
}

UM14_LoadoutButton(result, region, factor, clientHeight, research := false) {
    words := UM14_OCRWords(result,region,factor), found := ""
    scale := clientHeight/1009
    for word in words {
        ; Do not match EQUIP inside UNEQUIP, descriptions, prices or locks.
        if ((word.text != "EQUIP" && word.text != "UNEQUIP")
            || word.h < 7*scale || word.h > 26*scale)
            continue
        neighbors := 0
        for neighbor in words {
            if (neighbor.text = "SKINS" && neighbor.x > word.x+word.w
                && neighbor.x-word.x < 200*scale
                && Abs((neighbor.y+neighbor.h/2)-(word.y+word.h/2)) <= Max(word.h,neighbor.h)*.65)
                neighbors += 1
        }
        if (neighbors != 1)
            continue
        if (research) {
            labels := 0
            for neighbor in words {
                if (neighbor.text = "RESEARCH" && neighbor.x-word.x > 80*scale
                    && neighbor.x-word.x < 320*scale
                    && Abs((neighbor.y+neighbor.h/2)-(word.y+word.h/2)) <= Max(word.h,neighbor.h)*.65)
                    labels += 1
            }
            if (labels != 1)
                continue
        }
        if (IsObject(found))
            return false ; Ambiguous duplicate action rows fail closed.
        found := {x:Round(word.x+word.w/2),y:Round(word.y+word.h/2),
            w:Round(word.w),h:Round(word.h),action:word.text,status:"success",score:1.0}
    }
    return found
}

UM14_ReadLoadoutAction(tower, &capture := "") {
    capture := {kind:"none",key:""}
    UM14_RequireReadyFocus()
    identity := UM14_ConnectionSnapshot()
    if (!IsObject(identity))
        return false
    ; Read the complete button row with context. Legacy image matches could
    ; crop the prefix or border of UNEQUIP, or find EQUIP inside that word.
    ; Whole-word geometry plus its independent SKINS neighbor locate it now.
    region := UM14_Region(Round(identity.w*.54),Round(identity.h*.60),
        Round(identity.w*.30),Round(identity.h*.19),identity.w,identity.h)
    if (!IsObject(region))
        return false
    factor := Min(2.0,2500/Max(region.w,region.h))
    result := UM14_ConnectionOCR(identity,region,factor,"",true)
    stage := UM14_ConnectionOCRStage()
    capture := {kind:stage = "overlap" ? "overlap" : "other",key:identity.key}
    button := UM14_LoadoutButton(result,region,factor,identity.h)
    if (!IsObject(button) && stage = "success" && tower = "Juggernaut" && UM14_ConnectionSame(identity)) {
        ; The evolved tower's three-button strip benefits from a tighter OCR crop.
        strip := UM14_Region(Round(identity.w*.58),Round(identity.h*.665),
            Round(identity.w*.22),Round(identity.h*.095),identity.w,identity.h)
        if (IsObject(strip)) {
            factor := Min(3.5,2500/Max(strip.w,strip.h))
            button := UM14_LoadoutButton(UM14_ConnectionOCR(identity,strip,factor,"",true),strip,factor,identity.h,true)
        }
    }
    if (!IsObject(button) || (tower != "" && !UM14_LoadoutTitle(tower))
        || !UM14_ConnectionSame(identity))
        return false
    button.identity := identity
    return button
}

UM14_WaitLoadoutAction(tower, action, timeout := 5000, fatal := true) {
    started := A_TickCount, candidate := "", candidateAction := "", candidateKey := ""
    overlapFrames := 0, overlapKey := ""
    Loop {
        UM14_RequireReadyFocus()
        getRobloxPos(,, &width, &height)
        if (!UM14_Viewport(width,height))
            UM14_Fatal("The game client changed while checking the owned loadout.")
        identity := UM14_ConnectionSnapshot()
        if (!IsObject(identity))
            UM14_Fatal("The game identity changed while checking the owned loadout.")
        capture := {kind:"none",key:""}
        found := UM14_ReadLoadoutAction(tower,&capture)
        if (IsObject(found) && action != "" && found.action != action)
            found := ""
        foundAction := IsObject(found) ? found.action : ""
        observedOverlap := capture.kind = "overlap" && capture.key = identity.key
        observedOther := capture.kind != "none" && !observedOverlap
        sameClient := UM14_ConnectionSame(identity)
        if (!sameClient)
            found := "", foundAction := ""
        ; This changes only the failure explanation, never input permission.
        ; Blame an overlay only when current capture attempts on the same
        ; pinned client are blocked on two consecutive observations.
        if (!IsObject(found) && sameClient && observedOverlap && !observedOther) {
            overlapFrames := overlapKey = identity.key ? Min(2,overlapFrames+1) : 1
            overlapKey := identity.key
        } else {
            overlapFrames := 0, overlapKey := ""
        }
        if (IsObject(found) && IsObject(candidate) && foundAction = candidateAction && identity.key = candidateKey
            && Abs(found.x-candidate.x) <= 4 && Abs(found.y-candidate.y) <= 4)
            return found
        candidate := found, candidateAction := foundAction, candidateKey := IsObject(found) ? identity.key : ""
        if (A_TickCount-started >= timeout) {
            if (!fatal)
                return false ; Non-mutating selection probe; caller may retype, never equip blindly.
            if (UM14_LoadoutBlocked({frames:overlapFrames,key:overlapKey}))
                UM14_LoadoutOverlayFailure()
            if (tower = "")
                UM14_Fatal("Could not confirm the inventory action while clearing the old loadout. No further equipment action was sent.")
            UM14_Fatal("Could not verify required owned tower " tower " / " (action = "" ? "EQUIP or UNEQUIP" : action) ". It may be locked, unowned or unreadable. No later tower or match was started; check inventory and retry.")
        }
        Sleep(IsObject(candidate) ? 90 : 150)
    }
}

UM14_ClearLoadout(anchor) {
    identity := UM14_ConnectionSnapshot()
    if (!IsObject(identity) || !IsObject(anchor))
        UM14_Fatal("Inventory loadout anchor was not verified.")
    scale := identity.h/1009, center := identity.w/2+370*scale
    y := Round(anchor.y+110*scale), removed := 0, started := A_TickCount
    ; The footer recenters as cards disappear. Half-card spacing covers the
    ; centers for 1,2,3,4 AND 5 cards, including the rightmost fifth card.
    ; Restart after each acknowledged removal; never infer 'empty' from a
    ; failed image/OCR read, a pixel color, or three misses at the first slot.
    Loop {
        changed := false
        for offset in [0,1,-1,2,-2,3,-3,4,-4] {
            if (A_TickCount-started >= 60000 || !UM14_ConnectionSame(identity))
                UM14_Fatal("The loadout could not be cleared on a stable game client. No required tower was equipped.")
            x := Round(center+offset*42.5*scale)
            UM14_SelectLoadoutSlot(x,y)
            Sleep(120)
            control := UM14_WaitLoadoutAction("","",900,false)
            if (!IsObject(control)) {
                if (!UM14_ConnectionSame(identity))
                    UM14_Fatal("Inventory changed while selecting the old loadout.")
                UM14_SelectLoadoutSlot(x,y)
                control := UM14_WaitLoadoutAction("","",2500)
            }
            if (!UM14_ConnectionSame(identity))
                UM14_Fatal("Inventory changed before removing a loadout tower.")
            if (control.action = "UNEQUIP") {
                if (removed >= 5)
                    UM14_Fatal("More than five loadout removals were requested. No later equipment action was sent.")
                UM14_RequireReadyFocus()
                if (!UM14_ConnectionSame(identity))
                    UM14_Fatal("Inventory changed before removing a loadout tower.")
                Click(control.x,control.y)
                UM14_WaitLoadoutAction("","EQUIP")
                removed += 1, changed := true
                LogToConsole("Loadout clearing: removed=" removed " confirmed=1")
                if (removed = 5) {
                    LogToConsole("Loadout clearing: complete=1 removed=5")
                    return
                }
                break
            }
        }
        if (!changed) {
            LogToConsole("Loadout clearing: complete=1 removed=" removed " positionsChecked=9")
            return
        }
    }
}

UM14_SelectLoadoutSlot(x,y) {
    UM14_RequireReadyFocus()
    getRobloxPos(,, &width, &height)
    ; Preserve the original known hotbar-card selection, never spray the action
    ; panel. Selection alone removes/equips nothing; a proved button must follow.
    if (!UM14_Viewport(width,height) || x < width*.4 || x > width*.85 || y < height*.72 || y >= height*.98)
        UM14_Fatal("The inventory hotbar location was not verified. No equipment action was sent.")
    Click(x,y)
}

; The 1.3.3.10 path selects the first filtered card and finds the action
; by image and button color. It does not read the tower name or button label.
UM14_ReferenceInventoryClick(identity, x, y) {
    UM14_RequireReadyFocus()
    if (!UM14_ConnectionSame(identity) || x < 0 || y < 0 || x >= identity.w || y >= identity.h)
        UM14_Fatal("Roblox moved or lost focus during inventory setup.")
    ; Roblox can dispatch a click against the previous hovered control.
    MouseMove(x,y,0)
    Sleep(75)
    if !UM14_ConnectionSame(identity)
        UM14_Fatal("Roblox moved or lost focus during inventory setup.")
    Click(x,y)
}

UM14_ReferenceInventorySearch(value, bar, identity, retry := false) {
    if !RegExMatch(value,"^[A-Za-z][A-Za-z0-9 ]{0,47}$")
        UM14_Fatal("Invalid inventory search query.")
    x := Round(bar.x+30*identity.h/1009), y := bar.y
    ; Keep the reference offset first; on retry focus further into the field.
    textbox := retry ? Round(bar.x+95*identity.h/1009) : x
    UM14_ReferenceInventoryClick(identity,textbox,y)
    Sleep(150)
    UM14_RequireReadyFocus()
    if !UM14_ConnectionSame(identity)
        UM14_Fatal("Roblox moved during inventory search.")
    ; Some clients lose letters from a single SendText burst (Militant → Miltan).
    UM14_SearchText(value,retry ? 100 : 70)
    Sleep(500)
    UM14_ReferenceInventoryClick(identity,x+10,Round(identity.h*409/1009))
    Sleep(500)
}

UM14_ReferenceVisibleTower(identity, tower) {
    ; An already-visible card avoids opening the search box. Multi-word names
    ; still use the filter; a word that is only part of a name is not enough.
    if !RegExMatch(tower,"^[A-Za-z]+$")
        return false
    w := identity.w, h := identity.h
    cards := UM14_Region(Round(w*.015),Round(h*.27),Round(w*.50),Round(h*.64),w,h)
    if !IsObject(cards)
        return false
    card := UM14_MenuWordPair(identity,cards,tower,true)
    if !IsObject(card)
        return false
    UM14_ReferenceInventoryClick(identity,card.x,card.y)
    Sleep(300)
    return UM14_ConnectionSame(identity) && UM14_LoadoutTitle(tower)
}

UM14_ReferenceInventoryAction(identity, action, prior := 0) {
    UM14_RequireReadyFocus()
    if !UM14_ConnectionSame(identity)
        UM14_Fatal("Roblox moved during inventory setup.")
    w := identity.w, h := identity.h, scale := h/1009
    equip := action = "EQUIP"
    if (!equip && action != "UNEQUIP")
        UM14_Fatal("Unknown equipment action.")
    x0 := Round(w*.40), y0 := Round(h*.49), x1 := Round(w*.91), y1 := h
    if IsObject(prior) {
        dx := Round(115*scale), dy := Round(48*scale)
        x0 := Max(x0,prior.x-dx), x1 := Min(x1,prior.x+dx+1)
        y0 := Max(y0,prior.y-dy), y1 := Min(y1,prior.y+dy+1)
    }
    if (x1 <= x0 || y1 <= y0)
        return false
    result := AdvancedImageSearch(equip ? "Resources\equip.png" : "Resources\unequip.png"
        , x0,y0,x1-x0,y1-y0,(equip ? .5 : .3)*scale,1.4,.025)
    if (result.status != "success" || result.score <= (equip ? .4 : .63)
        || result.x < x0 || result.x >= x1 || result.y < y0 || result.y >= y1)
        return false
    UM14_RequireReadyFocus()
    if !UM14_ConnectionSame(identity)
        UM14_Fatal("Roblox moved before checking the equipment button.")
    dx := Max(16,Round(40*scale)), dy := Max(10,Round(25*scale))
    if !PixelSearch(&px,&py,Max(0,result.x-dx),Max(0,result.y-dy),Min(w-1,result.x+dx),Min(h-1,result.y+dy)
        , equip ? 0x45DC4A : 0x7A797A, equip ? 7 : 5)
        return false
    return {x:result.x,y:result.y}
}

UM14_ReferenceWaitAction(identity, action, milliseconds) {
    started := A_TickCount
    Loop {
        button := UM14_ReferenceInventoryAction(identity,action)
        if (IsObject(button) || A_TickCount-started >= milliseconds)
            return button
        Sleep(150)
    }
}

UM14_ReferenceChangeAction(identity, button, fromAction, toAction) {
    UM14_ReferenceInventoryClick(identity,button.x,button.y)
    if !UM14_ConnectionSame(identity)
        UM14_Fatal("Roblox moved before confirming the equipment action.")
    ; Hover changes the button color, so verify it after moving off the control.
    MouseMove(button.x,Max(0,button.y-Round(identity.h*.13)),0)
    Sleep(300)
    ; A different match elsewhere in the panel is not a receipt.
    started := A_TickCount
    Loop {
        if IsObject(UM14_ReferenceInventoryAction(identity,toAction,button))
            && !UM14_ReferenceInventoryAction(identity,fromAction,button)
            return true
        if (A_TickCount-started >= 1700) {
            ; The opposite label must be stable in the same button row.
            ; This is a receipt only, never a second click or a wider search.
            dx := Round(90*identity.h/1009), dy := Round(34*identity.h/1009)
            region := UM14_Region(button.x-dx,button.y-dy,2*dx+1,2*dy+1,identity.w,identity.h)
            return IsObject(region) && IsObject(UM14_MenuWordPair(identity,region,toAction))
                && !IsObject(UM14_MenuWordPair(identity,region,fromAction))
        }
        Sleep(150)
    }
}

UM14_ReferenceUnequip(identity, button) {
    if !UM14_ReferenceChangeAction(identity,button,"UNEQUIP","EQUIP")
        UM14_Fatal("Roblox did not confirm an Unequip click. Check the current loadout and retry.")
    Sleep(100)
}

UM14_ReferenceClear(identity, anchor) {
    scale := identity.h/1009
    wide := identity.w >= identity.h*1.3
    ; 1.3.3.10 probes vertically at 61% width and aligns off the action.
    ; Docking compresses that column, so narrow windows use the card strip.
    center := wide ? identity.w*.61 : anchor.x+64*scale
    y := Round(anchor.y+(wide ? 110 : 100)*scale)
    if (y < identity.h*.67 || y >= identity.h*.98)
        UM14_Fatal("Inventory cards were outside the loadout strip.")
    Loop 5 {
        removed := false
        if wide {
            x := Round(center)
            Loop 13 {
                row := y+Round((5*(A_Index-1)-30)*scale)
                if (row >= identity.h*.67 && row < identity.h*.98) {
                    UM14_ReferenceInventoryClick(identity,x,row)
                    Sleep(5)
                }
            }
            Sleep(600)
            button := UM14_ReferenceInventoryAction(identity,"UNEQUIP")
            if IsObject(button) {
                UM14_ReferenceUnequip(identity,button)
                continue
            }
        }
        for slot in [-4,-3,-2,-1,0,1,2,3,4] {
            x := Round(center+slot*37*scale)
            if (x < identity.w*.48 || x >= identity.w*.96 || y < identity.h*.72)
                continue
            UM14_ReferenceInventoryClick(identity,x,y)
            Sleep(150)
            button := UM14_ReferenceInventoryAction(identity,"UNEQUIP")
            if IsObject(button) {
                UM14_ReferenceUnequip(identity,button)
                removed := true
                break
            }
        }
        if !removed
            return
    }
}

; Verified inventory text entry. OCR is evidence, never a guarantee of game
; behavior; exact owned-tower/action confirmation still gates every mutation.
UM14_SearchQuery(value) {
    return StrUpper(RegExReplace(value,"\s+",""))
}

UM14_InventorySearchRegion(bar, identity) {
    if (!IsObject(identity) || !identity.HasOwnProp("w") || !identity.HasOwnProp("h")
        || !UM14_Viewport(identity.w,identity.h) || !IsObject(bar)
        || !bar.HasOwnProp("status") || !bar.HasOwnProp("score")
        || bar.status != "success" || !IsNumber(bar.score) || bar.score <= .67 || bar.score > 1)
        return false
    for key in ["x","y","w","h"]
        if (!bar.HasOwnProp(key) || Type(bar.%key%) != "Integer" || bar.%key% < 0 || bar.%key% > 8192)
            return false
    if (bar.w < 15 || bar.h < 8 || Abs(bar.w/bar.h-49/29) > .3
        || bar.x >= identity.w*.5 || bar.y >= identity.h*.5)
        return false
    ; The 49x29 template is the magnifier, not the full textbox. Capture only
    ; the adjacent query viewport, excluding the filters/loadout buttons.
    x := Floor(bar.x+bar.w*.35), y := Floor(bar.y-bar.h*.8)
    w := Ceil(bar.w*6), h := Ceil(bar.h*1.6)
    region := UM14_Region(x,y,w,h,identity.w,identity.h)
    return IsObject(region) && region.x = x && region.y = y && region.w = w && region.h = h ? region : false
}

UM14_TypeInventoryQuery(value, anchor, pace) {
    if (Type(value) != "String" || !RegExMatch(value,"^[A-Za-z][A-Za-z0-9 ]{0,47}$"))
        UM14_Fatal("Invalid inventory search query.")
    UM14_RequireReadyFocus()
    identity := UM14_ConnectionSnapshot()
    if (!IsObject(identity) || !IsObject(UM14_InventorySearchRegion(anchor,identity)))
        UM14_Fatal("Inventory search geometry could not be verified. No tower was selected.")
    UM14_RequireReadyFocus()
    if (!UM14_ConnectionSame(identity))
        UM14_Fatal("Inventory client changed before search entry. No tower was selected.")
    bar := AdvancedImageSearch("Resources\searchbar_items.png",0,0,Round(identity.w*.5),Round(identity.h*.5))
    region := UM14_InventorySearchRegion(bar,identity)
    if (!IsObject(region) || Abs(bar.x-anchor.x) > 4 || Abs(bar.y-anchor.y) > 4
        || Abs(bar.w-anchor.w) > 4 || Abs(bar.h-anchor.h) > 4 || !UM14_ConnectionSame(identity))
        UM14_Fatal("Inventory search control changed. No tower was selected.")
    UM14_RequireReadyFocus()
    Click(Round(bar.x+bar.w*.8),bar.y)
    Sleep(150)
    if (!UM14_ConnectionSame(identity))
        UM14_Fatal("Inventory client changed during search entry. No tower was selected.")
    UM14_SearchText(value,pace,pace = 80)
    ; Let filtering settle, then select the result once. The detail title
    ; and owned action confirm the selection; the blinking textbox does not.
    Sleep(150)
    return region
}

UM14_SearchInventory(value, anchor) {
    UM14_RequireReadyFocus()
    identity := UM14_ConnectionSnapshot()
    if (!IsObject(identity) || !IsObject(UM14_InventorySearchRegion(anchor,identity)))
        UM14_Fatal("Inventory search geometry could not be verified. No tower was selected.")
    for attempt, pace in [80,120,180] {
        region := UM14_TypeInventoryQuery(value,anchor,pace)
        ; Selecting the existing inventory result is non-mutating. The SAME
        ; strict full title + whole EQUIP/UNEQUIP label + two stable identity
        ; observations used for mutation gates acknowledge actual selection.
        UM14_RequireReadyFocus()
        if (!UM14_ConnectionSame(identity))
            UM14_Fatal("Inventory client changed before result selection. No equipment action was sent.")
        cardX := Round(anchor.x+anchor.w*.8)+10
        cardY := Round(identity.h*409/1009)
        if (cardX < 0 || cardX >= identity.w*.5 || cardY < identity.h*.2 || cardY >= identity.h*.7)
            UM14_Fatal("Inventory result geometry could not be verified. No equipment action was sent.")
        UM14_RequireReadyFocus()
        Click(cardX,cardY)
        Sleep(250)
        selected := UM14_WaitLoadoutAction(value,"",1800,false)
        if (!UM14_ConnectionSame(identity))
            UM14_Fatal("Inventory client changed while checking selection. No equipment action was sent.")
        if (IsObject(selected)) {
            LogToConsole("Inventory selection: attempt=" attempt " ownedTitleConfirmed=1")
            return selected
        }
        if (UM14_LoadoutTitle(value))
            UM14_Fatal("The exact requested tower is selected, but its owned action could not be verified. Search was left intact; no repeated typing or equipment action was sent.")
        UM14_RequireReadyFocus()
        if (!UM14_ConnectionSame(identity))
            UM14_Fatal("Inventory client changed before checking a failed search.")
        UM14_ConnectionOCR(identity,region)
        queryStage := UM14_ConnectionOCRStage()
        if (UM14_ConnectionSame(identity) && queryStage = "overlap")
            UM14_Fatal("Auto equip could not read Roblox because another window covers the inventory (" UM14_ConnectionOCROverlap() "). Move the macro or other windows off the Roblox window, or turn on Dock Roblox beside the macro, then press Start again. No equipment action was sent.")
        if (!UM14_ConnectionSame(identity) || queryStage != "success")
            UM14_Fatal("The selected game could not be read for inventory verification (capture stage: " queryStage "). Retyping cannot repair a failed capture, so search was stopped without an equipment action. Check the Output capture diagnostics.")
        LogToConsole("Required owned tower was not selected; retry=" attempt)
    }
    UM14_Fatal("Inventory selection could not verify required owned tower " value " after 3 attempts. No equipment action was sent. Check the loadout readiness diagnostics in Output.")
}
