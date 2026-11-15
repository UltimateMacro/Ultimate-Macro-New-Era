; Original 1.3.3a recorder, ported with owner approval; 1.3.3.10 replay remains in the engine.
; UI, focus/lifecycle guards and the selected-file handoff are the only integration changes.
RegisterRecordingHotkeys(oldKeys := "") {
    global PlaceTowerKey, UpgradeTowerKey, ChangeDJTrackKey, DeleteTowerRecordingKey, IsRecordingActive
    global SellTowerKey, AlignCameraKey, RecordInputsKey, HoloKey, ChangeTargetsKey, RepoKey, UpgradeTowerGKey, RaiseDeadKey

    HotIf(IsRecordingActive)

    if IsObject(oldKeys) {
        for old in oldKeys {
            if (old != "") {
                try Hotkey(old, "Off")
            }
        }
    }

    Hotkey(PlaceTowerKey, PlaceTowerHK, "On")
    Hotkey(UpgradeTowerKey, UpgradeTowerHK, "On")
    Hotkey(ChangeDJTrackKey, ChangeDJTrackHK, "On")
    Hotkey(DeleteTowerRecordingKey, DeleteTowerRecordingHK, "On")
    Hotkey(SellTowerKey, SellTowerHK, "On")
    Hotkey(AlignCameraKey, AlignCameraHK, "On")
    Hotkey(RecordInputsKey, RecordInputsHK, "On")
    Hotkey(HoloKey, CloneTowerHK, "On")
    Hotkey(ChangeTargetsKey, ChangeTargetsHK, "On")
    Hotkey("~^" RepoKey, BrawlerRepositionHK, "On")
    Hotkey("~^" RaiseDeadKey, ActivateRaiseTheDeadHK, "On")
    Hotkey("~LButton", DetectTowerForUpgrading, "On")
    Hotkey("~LButton Up", DetectUpgrade, "On")

    HotIf()
}

DetectTowerForUpgrading(*) {
    global MacroRecording, MacroSteps, MacroStartTime, Recording, Towers, RecordedSteps, Commander, ActiveRTowerID, CachedMenuUI, isUiPositionSaved, isUpgradeAuthorized, activeUpgradeRegions, CachedResV2, CachedResV1

    if !RecorderGameFocused()
        return
    if (IsSet(MacroRecording) && MacroRecording) {
        MouseGetPos(&mx, &my)
        elapsed := A_TickCount - MacroStartTime
        MacroStartTime := A_TickCount
        MacroSteps.Push("Sleep(" elapsed ")")
        MacroSteps.Push("Click(" mx ", " my ")")
        return
    }

    if (!Recording)
        return

    MouseGetPos(&mx, &my, &clickWindow)
    robloxHwnd := GetRobloxHWND()
    
    if (clickWindow != robloxHwnd)
        return

    currentTowerID := ""
    for id, t in Towers {
        ix1 := t.x - 16
        iy1 := t.y - 16
        ix2 := ix1 + 32
        iy2 := iy1 + 32
        
        if (mx >= ix1 && mx <= ix2 && my >= iy1 && my <= iy2) {
            currentTowerID := id
            break
        }
    }

    if (currentTowerID != "") {
        ActiveRTowerID := currentTowerID
        isUpgradeAuthorized := false
        
        openedSuccessfully := waitForTowerUI(&resv2, &resv1)
        
        if (!openedSuccessfully) {
            ActiveRTowerID := ""
        } else {
            CachedResV2 := IsSet(resv2) ? resv2 : ""
            CachedResV1 := IsSet(resv1) ? resv1 : ""
        }
        return
    } else {
        if (ActiveRTowerID != "") {
            openedSuccessfully := waitForTowerUI(&resv2, &resv1, 120)
            
            if (!openedSuccessfully) {
                ActiveRTowerID := ""
            }
        }
    }
}

DetectUpgrade(*) {
    global Recording, ActiveRTowerID, Towers, RecordedSteps, Commander, isUpgradeAuthorized, activeUpgradeRegions, CachedResV2, CachedResV1
    
    if (!Recording || !IsSet(ActiveRTowerID) || ActiveRTowerID == "")
        return

    towerID := ActiveRTowerID
    
    if (!Towers.Has(towerID)) {
        ActiveRTowerID := ""
        return
    }

    MouseGetPos(&mx, &my, &clickWindow)
    robloxHwnd := GetRobloxHWND()
    
    if (clickWindow != robloxHwnd)
        return

    if (!IsSet(CachedResV2) || !IsSet(CachedResV1) || (CachedResV2 == "" && CachedResV1 == "")) {
        resv2 := ""
        resv1 := ""
        openedSuccessfully := waitForTowerUI(&resv2, &resv1)
        if (!openedSuccessfully) {
            ActiveRTowerID := ""
            return
        }
        CachedResV2 := IsSet(resv2) ? resv2 : ""
        CachedResV1 := IsSet(resv1) ? resv1 : ""
    } else {
        resv2 := CachedResV2
        resv1 := CachedResV1
    }

    path := Towers[towerID].path
    pathLevel := Towers[towerID].pathLevel
    nextLevel := Towers[towerID].level + 1

    doResV2 := (IsObject(resv2) && resv2.HasProp("score") && resv2.score > 0.55)

    if (doResV2) {
        upgAX := resv2.x - ScaleX(100)
        upgAY := resv2.y - ScaleY(260)
        upgAW := ScaleX(300)
        upgAH := ScaleY(110)
    } else if (IsObject(resv1)) {
        upgAX := resv1.x - ScaleX(344)
        upgAY := resv1.y + ScaleY(343)
        upgAW := ScaleX(300)
        upgAH := ScaleY(110)
    } else {
        return
    }

    region := [upgAX, upgAY, upgAW, upgAH]

    if (path != 0 && nextLevel > pathLevel && pathLevel != 0) {
        if (path = 2 && IsObject(resv1)) { 
            region := [resv1.x - ScaleX(344), resv1.y + ScaleY(488), ScaleX(300), ScaleY(110)]
        }
    }

    x1 := region[1]
    y1 := region[2]
    x2 := region[1] + region[3]
    y2 := region[2] + region[4]

    if (mx >= x1 && mx <= x2 && my >= y1 && my <= y2) {
        if PixelSearch(&gx, &gy, x1, y1, x2, y2, 0x206435, 7) {
            if (AdvancedImageSearch("Resources/fully_upgraded.png", x1, y1, region[3], region[4]).score >= 0.69) {
                return
            }

            Towers[towerID].level += 1
            LogToConsole("Upgraded tower " towerID " to level " Towers[towerID].level ".")
            UpdateTowerIndicator(towerID)
            
            if (Towers[towerID].path != 0 && Towers[towerID].path != "") {
                RecordedSteps.Push("UpgradeTower(" towerID ", false, 1, " Towers[towerID].path ", " Towers[towerID].pathLevel ")")
            } else {
                RecordedSteps.Push("UpgradeTower(" towerID ")")
            }
            
            if (Towers[towerID].level >= 2 && RegExMatch(towerID, "i)^Commander\d*$") && !Commander) {
                Commander := true
                if (!HasStep("Commander := true"))
                    RecordedSteps.Push("Commander := true")
            }
        }
    }
}

StartRecording(ctrl, *) {
    global Recording, gamemap, difficulty, requiredTowers, modifiers, autoChain, autoCaravan
    global autoDropTheBeat, AutoSkip, AbilitySpam, MoveEnabled, MoveDirection, MoveDuration
    global Commander, RecordedSteps, Towers, MacroRecording, GuiTitleCtrl
    global Tab2_Btn1, Tab2_Btn2, HoverEffect

    if (Recording || RunningStrategy)
        return

    v := MainGui.Submit(false)

    if (!v.RecMaps or !v.RecDifficulty or !v.RecRequiredTowers) {
        MsgBox("Failed to start recording!`nMake sure you have entered the towers, the map, and the difficulty, then try again.", "Error", 0x1010)
        return
    }

    if (A_ScreenWidth != 1920 || A_ScreenHeight != 1080) {
        if (MsgBox("Your screen resolution is not 1920x1080.`nThe recording system is highly recommended for 1920x1080. Do you want to continue?", "Warning", 0x1034) = "No") {
            return
        }
    }

    if (IsSet(GuiTitleCtrl) && GuiTitleCtrl) {
        GuiTitleCtrl.SetFont("cff6b6b")
    }

    if (IsSet(Tab2_Btn1) && Tab2_Btn1) {
        Tab2_Btn1.SetFont("c808080 norm")
        Tab2_Btn1.Opt("Background0e0e0f")
        if (IsSet(HoverEffect) && IsObject(HoverEffect)) {
            for index, element in HoverEffect {
                if (element = Tab2_Btn1) {
                    HoverEffect.RemoveAt(index)
                    break
                }
            }
        }
    }

    if (IsSet(Tab2_Btn2) && Tab2_Btn2) {
        Tab2_Btn2.SetFont("cWhite norm")
        if (IsSet(HoverEffect) && IsObject(HoverEffect)) {
            hasElement := false
            for element in HoverEffect {
                if (element = Tab2_Btn2) {
                    hasElement := true
                    break
                }
            }
            if (!hasElement) {
                HoverEffect.Push(Tab2_Btn2)
            }
        }
    }

    gamemap := v.RecMaps
    difficulty := v.RecDifficulty
    requiredTowers := v.RecRequiredTowers
    modifiers := v.RecModifiers
    autoChain := v.RecAutoChain ? "ON" : "OFF"
    autoCaravan := v.RecAutoCaravan ? "ON" : "OFF"
    autoDropTheBeat := v.RecAutoDropTheBeat ? "ON" : "OFF"
    AutoSkip := v.RecAutoSkip ? "ON" : "OFF"
    AbilitySpam := v.RecAbilitySpam ? "ON" : "OFF"
    MoveEnabled := v.RecMoveEnabled ? true : false
    MoveDirection := v.RecMoveDirection
    MoveDuration := IsNumber(v.RecMoveDuration) ? Integer(v.RecMoveDuration) : 750

    Commander := false
    Recording := true
    RecordedSteps := []
    Towers := Map()
    DeleteAllIndicators()

    LogToConsole("Recording started.")
    
    ActivateRoblox()
}

StopRecord(ctrl, *) {
    global Recording, MacroRecording, InputHookObj, MacroSteps, RecordedSteps
    global gamemap, difficulty, requiredTowers, modifiers
    global autoChain, autoCaravan, autoDropTheBeat, AutoSkip, AbilitySpam, MoveEnabled, MoveDirection, MoveDuration
    global GuiTitleCtrl, Strategy1Ctrl, RecordingsDir
    global Tab2_Btn1, Tab2_Btn2, HoverEffect

    if (MacroRecording) {
        MacroRecording := false
        if (InputHookObj != "")
            InputHookObj.Stop()
        LogToConsole("Macro recording auto-stopped")
        if (ModernMsgBox("Add to Strategy?", "Add recorded actions to current strategy?", "YES|NO") = "YES") {
            for i, step in MacroSteps
                RecordedSteps.Push(step)
            LogToConsole("Added " MacroSteps.Length " macro steps to strategy")
        }
    }

    if (!Recording)
        return
    Recording := false
    DeleteAllIndicators()
    try MW.Sync(true)

    if (IsSet(GuiTitleCtrl) && GuiTitleCtrl) {
        GuiTitleCtrl.SetFont("cWhite")
    }

    if (IsSet(Tab2_Btn1) && Tab2_Btn1) {
        Tab2_Btn1.SetFont("cWhite norm")
        if (IsSet(HoverEffect) && IsObject(HoverEffect)) {
            hasElement := false
            for element in HoverEffect {
                if (element = Tab2_Btn1) {
                    hasElement := true
                    break
                }
            }
            if (!hasElement) {
                HoverEffect.Push(Tab2_Btn1)
            }
        }
    }

    if (IsSet(Tab2_Btn2) && Tab2_Btn2) {
        Tab2_Btn2.SetFont("c808080 norm")
        Tab2_Btn2.Opt("Background0e0e0f")
        if (IsSet(HoverEffect) && IsObject(HoverEffect)) {
            for index, element in HoverEffect {
                if (element = Tab2_Btn2) {
                    HoverEffect.RemoveAt(index)
                    break
                }
            }
        }
    }

    if (ModernMsgBox("Save", "Save the recorded strategy?", "YES|NO") = "YES") {
        box := InputBox("File name (without .strat):", "Save", "w300 h130", "MyStrategy")
        if (box.Result = "Cancel")
            return
        filePath := RecordingsDir "\" box.Value ".strat"
        if (Trim(box.Value) = "" || RegExMatch(box.Value, "[<>:`"/\\|?*\x00-\x1f]") || RegExMatch(box.Value, "i)\A(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|\z)")) {
            ModernMsgBox("Save", "Enter a file name without folders or reserved characters.", "OK")
            return
        }
        getRobloxPos(&pX, &pY, &currentWidth, &currentHeight)

        strategyText := "[Settings]`nmap=" gamemap "`ndifficulty=" difficulty "`nrequiredTowers=" requiredTowers
            . "`nmodifiers=" Join(modifiers)
            . "`nautoChain=" autoChain "`nautoCaravan=" autoCaravan "`nautoDropTheBeat=" autoDropTheBeat
            . "`nautoSkip=" AutoSkip "`nabilitySpam=" AbilitySpam "`nmoveEnabled=" MoveEnabled "`nmoveDirection=" MoveDirection
            . "`nmoveDuration=" MoveDuration "`n`n[DO NOT EDIT]`nwidth=" currentWidth "`nheight=" currentHeight "`n`n[Steps]`n"
        for i, step in RecordedSteps
            strategyText .= step "`n"
        AtomicWrite(filePath, strategyText)
        LogToConsole("Strategy saved: " filePath)
        MW.Assign(Strategy1Ctrl, filePath)
    } else {
        LogToConsole("Recording cancelled, strategy not saved")
    }
}

PlaceTowerHK(*) {
    global Recording, Towers, RecordedSteps, ActiveRTowerID, CachedMenuUI, isUiPositionSaved, UseNumbersForHotbar, Slots

    if (!Recording) {
        pureKey := RegExReplace(PlaceTowerKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(PlaceTowerKey, "^([\^+!#]+)", &match) ? match[1] : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }
    
    towersStringBackup := Towers 

    MouseGetPos(&mx, &my)
    loop {
        slotBox := InputBox("Enter the tower slot number (1-5):", "Slot (1-5)", "w300 h130", "1")

        if (slotBox.Result = "Cancel")
            return

        try {
            sllot := Integer(slotBox.Value)
            
            if (sllot >= 1 && sllot <= 5) {
                break
            } else {
                continue
            }
        } 
        catch Error {
            continue
        }
    }
    slot := slotBox.Value
    
    suggestedID := GetNextTowerID(slot)
    
    idBox := InputBox("Enter a specific tower id:", "Tower ID", "w300 h130", suggestedID)
    if (idBox.Result = "Cancel")
        return
    towerID := idBox.Value
    ActivateRoblox()

    LogToConsole("Recording: placing tower " towerID " (slot " slot ") at x:" mx " y:" my "...")

    getRobloxPos(,,&w,&h)

    ActivateRoblox()
    
    if UseNumbersForHotbar {
        Send("{" slot "}")
    } else {
        Click(Slots[slot])
    }

    Sleep(30)
    

    MouseMove(mx, my, A_DefaultMouseSpeed)
    Sleep((PotatoMode = 1) ? 100 : 40)
    Click()
    Sleep(100)
    SendEvent("{" CancelPlacementKey "}")

    Towers[towerID] := {x: mx, y: my, slot: slot, level: 0, path: 0, pathLevel: 0, target: "First Enemy"}
    UpdateTowerIndicator(towerID)
    LogToConsole("Recorded tower " towerID " (slot " slot ")")

    RecordedSteps.Push("SpawnTower(" mx ", " my ", " slot ", " towerID ")")

    if (towerID = "" || RegExMatch(towerID, "i)(Juggernaut|Hacker|Pursuit|Kingpin)")) {
        ShowTowerPathDialog(towerID)
    }

    ActiveRTowerID := towerID
    
    openedSuccessfully := false
    Loop 10 {
        getRobloxPos(,,&w,&h)
        resV2 := AdvancedImageSearch("Resources\TowerUI\Variant2.png", 0, Round(h / 2), Round(w * 0.3), Round(h * 0.9) - Round(h / 2), 0.5, 1.5)
        
        if (resV2.status == "success" && resV2.score > 0.6) {
            
            if (!isUiPositionSaved) {
                Sleep(300) 
                
                getRobloxPos(,,&w,&h)
                resV2Final := AdvancedImageSearch("Resources\TowerUI\Variant2.png", 0, Round(h / 2), Round(w * 0.3), Round(h * 0.9) - Round(h / 2), 0.5, 1.5)
                
                if (resV2Final.status == "success") {
                    CachedMenuUI := {x: resV2Final.x, y: resV2Final.y}
                    isUiPositionSaved := true 
                    openedSuccessfully := true
                } else {
                    CachedMenuUI := {x: resV2.x, y: resV2.y}
                    isUiPositionSaved := true
                    openedSuccessfully := true
                }
            } 
            else {
                openedSuccessfully := true
            }
            break
        }
        Sleep(150)
    }
    
    if (!openedSuccessfully) {
        ActiveRTowerID := ""
    }
}

UpgradeTowerHK(*) {
    global Recording, Towers, RecordedSteps, Commander
    if (!Recording) {
        pureKey := RegExReplace(UpgradeTowerKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(UpgradeTowerKey, "^([\^+!#]+)", &match) ? match[1] : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }

    MouseGetPos(&mx, &my)

    closestID := ""
    for id, t in Towers {
        ix1 := t.x - 12
        iy1 := t.y - 12
        ix2 := ix1 + 24
        iy2 := iy1 + 24
        
        if (mx >= ix1 && mx <= ix2 && my >= iy1 && my <= iy2) {
            closestID := id
            break
        }
    }

    if (closestID != "") {
        Towers[closestID].level += 1
        UpdateTowerIndicator(closestID)
        if (Towers[closestID].path != 0 && Towers[closestID].path != "") {
            RecordedSteps.Push("UpgradeTower(" closestID ", false, 1, " Towers[closestID].path ", " Towers[closestID].pathLevel ")")
        } else {
            RecordedSteps.Push("UpgradeTower(" closestID ")")
        }
        if (Towers[closestID].level >= 2 && RegExMatch(closestID, "i)^Commander\d*$") && !Commander) {
            Commander := true
            if (!HasStep("Commander := true"))
                RecordedSteps.Push("Commander := true")
        }
    }
}

ChangeDJTrackHK(*) {
    global Recording, RecordedSteps
    if (!Recording) {
        pureKey := RegExReplace(ChangeDJTrackKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(ChangeDJTrackKey, "^([\^+!#]+)", &match) ? match[1] : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }
    box := InputBox("Enter Track Color (Purple/Red/Green):", "DJ Track", "w300 h130", "Green")
    if (box.Result != "Cancel") {
        RecordedSteps.Push('SetDJTrack("' box.Value '")')
        LogToConsole("Recorded DJ-track " box.Value)
    }
}

DeleteTowerRecordingHK(*) {
    global Recording, Towers, RecordedSteps
    if (!Recording) {
        pureKey := RegExReplace(DeleteTowerRecordingKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(DeleteTowerRecordingKey, "^([\^+!#]+)", &match) ? match[1] : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }

    MouseGetPos(&mx, &my)

    closestID := ""
    for id, t in Towers {
        if (!HasProp(t, "x") || !HasProp(t, "y"))
            continue

        ix1 := t.x - 12
        iy1 := t.y - 12
        ix2 := ix1 + 24
        iy2 := iy1 + 24
        
        if (mx >= ix1 && mx <= ix2 && my >= iy1 && my <= iy2) {
            closestID := id
            break
        }
    }

    if (closestID != "") {
        if (HasProp(Towers[closestID], "hwnd") && Towers[closestID].hwnd) {
            try WinClose("ahk_id " Towers[closestID].hwnd)
        }

        newSteps := []
        
        escapedID := RegExReplace(closestID, "([\.\ \+\*\?\^\$\(\)\[\]\{\}\|])", "\$1")

        for i, step in RecordedSteps {
            if (RegExMatch(step, "i)^SpawnTower\s*\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*" escapedID "\s*\)$"))
                continue
            if (RegExMatch(step, "i)^UpgradeTower\s*\(\s*" escapedID "\s*(?:,.*)?\s*\)$"))
                continue
            if (RegExMatch(step, "i)^SellTower\s*\(\s*" escapedID "\s*\)$"))
                continue
            newSteps.Push(step)
        }
        RecordedSteps := newSteps

        try {
            if Towers.Has(closestID) {
                Towers.Delete(closestID)
            }
        } catch {
        }

        LogToConsole("Recorded sell tower " closestID)
    }
}


SellTowerHK(*) {
    global Recording, Towers, RecordedSteps
    if (!Recording) {
        pureKey := RegExReplace(SellTowerKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(SellTowerKey, "^([\^+!#]+)", &match) ? match[1] : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }

    MouseGetPos(&mx, &my)

    closestID := ""
    for id, t in Towers {
        ix1 := t.x - 12
        iy1 := t.y - 12
        ix2 := ix1 + 24
        iy2 := iy1 + 24
        
        if (mx >= ix1 && mx <= ix2 && my >= iy1 && my <= iy2) {
            closestID := id
            break
        }
    }
    if (closestID != "") {
        if (Towers[closestID].hwnd) {
            WinClose("ahk_id " Towers[closestID].hwnd)
            Towers[closestID].hwnd := ""
        }
        RecordedSteps.Push("SellTower(" closestID ")")
        SellTower(closestID)
        ; Selling is a recorded action, not Delete Record. Retain the earlier
        ; spawn/upgrades so replay has a tower to sell at this step.
        if Towers.Has(closestID)
            Towers.Delete(closestID)
        LogToConsole("Recorded sell tower " closestID)
    }
}

AlignCameraHK(*) {
    if (!Recording) {
        pureKey := RegExReplace(AlignCameraKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(AlignCameraKey, "^([\^+!#]+)", &match) ? match[1] : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }

    if (InArray(SpecialMaps, gamemap)) {
        functionName := gamemap . "Path"

        %functionName%() 
    } else {
        AlignCamera()
    }
}

RecordInputsHK(*) {
    global MacroRecording, InputHookObj, MacroSteps, MacroStartTime, RecordedSteps, Recording, KeyDownTimes
    if (!Recording) {
        pureKey := RegExReplace(RecordInputsKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(RecordInputsKey, "^([\^+!#]+)", &match) ? match[1] : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }
    if (MacroRecording) {
        MacroRecording := false
        if (InputHookObj != "")
            InputHookObj.Stop()
        LogToConsole("Recording ALL clicks and keys STOPPED. Steps: " MacroSteps.Length)
        if (ModernMsgBox("Add to Strategy?", "Add recorded actions to current strategy?", "YES|NO") = "YES") {
            for i, step in MacroSteps
                RecordedSteps.Push(step)
            LogToConsole("Added " MacroSteps.Length " steps to strategy")
        }
    } else {
        LogToConsole("Recording ALL clicks and keys...!")
        MacroRecording := true
        MacroSteps     := []
        KeyDownTimes   := Map() 
        MacroStartTime := A_TickCount
        InputHookObj := InputHook("V")
        InputHookObj.KeyOpt("{All}", "N")
        InputHookObj.OnKeyDown := OnKeyDown
        InputHookObj.OnKeyUp := OnKeyUp 
        InputHookObj.Start()
    }
}

CloneTowerHK(*) {
    global Recording, RecordedSteps
    static LastCallTime := 0

    if (!Recording) {
        pureKey := RegExReplace(HoloKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(HoloKey, "^([\^+!#]+)", &match) ? match : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }

    CoordMode("Mouse", "Client")
    ActivateRoblox()
    MouseGetPos(&mx, &my)

    idBox := InputBox("Enter the tower ID to clone:", "Clone Tower", "w300 h130", "")
    if (idBox.Result = "Cancel")
        return

    towerID := Trim(idBox.Value)
    if (towerID = "") {
        return
    }

    CloneTower(towerID, mx, my)

    RecordedSteps.Push("CloneTower(" towerID ", " mx ", " my ")")
}

BrawlerRepositionHK(*) {
    global Recording, RecordedSteps, ActiveRTowerID

    if (!Recording) {
        pureKey := RegExReplace(HoloKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(HoloKey, "^([\^+!#]+)", &match) ? match : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }

    CoordMode("Mouse", "Client")
    MouseGetPos(&mx, &my)

    if (ActiveRTowerID = "") {
        idBox := InputBox("Enter the tower ID to reposition:", "Repo Brawler", "w300 h130", "")
        if (idBox.Result = "Cancel")
            return

        towerID := Trim(idBox.Value)
        if (towerID = "") {
            return
        }
        BrawlerReposition(towerID, mx, my)
    } else {
        towerID := ActiveRTowerID

        Hotkey("~LButton", "Off")
        g := KeyWait("LButton", "D")
        Hotkey("~LButton", "On")

        MouseGetPos(&mx, &my)

        Towers[towerId].x := mx
        Towers[towerId].y := my
        UpdateTowerIndicator(towerId)
    }

    RecordedSteps.Push("BrawlerReposition(" towerID ", " mx ", " my ")")
    LogToConsole("Recorded BrawlerReposition(" towerID ", " mx ", " my ")")
}

ActivateRaiseTheDeadHK(*) {
    global Recording, RecordedSteps
    static LastCallTime := 0

    waitTime := 0
    currentTime := A_TickCount

    if (RecordedSteps.Length > 0) {
        lastStep := RecordedSteps[RecordedSteps.Length]
        
        if (InStr(lastStep, "ActivateRaiseTheDead") && LastCallTime > 0) {
            waitTime := currentTime - LastCallTime
        }
    }

    LastCallTime := currentTime
    ActivateRaiseTheDead(waitTime)

    RecordedSteps.Push("ActivateRaiseTheDead(" waitTime ")")
}

RecordToggleAutoskip(*) {
    global Recording, AutoSkip
    if !Recording {
        return
    }

    v := MainGui.Submit(false)
    at := v.RecAutoSkip ? "ON" : "OFF"

    RecordedSteps.Push("ToggleAutoskip()")

    if at = "ON" {
        LogToConsole("Toggled auto-skip: ON")
    } else {
        LogToConsole("Toggled auto-skip: OFF")
    }
}

ChangeTargetsHK(*) {
    global Recording, RecordedSteps, ActiveRTowerID, LastOpenedTowerID

    CoordMode("Mouse", "Client")
    MouseGetPos(&mx, &my)

    if (ActiveRTowerID = "") {
        idBox := InputBox("Enter the tower ID:", "Change Targets", "w300 h100", "")
        if (idBox.Result = "Cancel")
            return

        towerID := Trim(idBox.Value)
        if (towerID = "") {
            return
        }
    } else {
        towerID := ActiveRTowerID
        LastOpenedTowerID := towerID
    }

    targetBox := InputBox("Enter the target:", "Change Targets", "w300 h100", "")
    if (targetBox.Result = "Cancel")
        return

    target := Trim(targetBox.Value)
    if (target = "") {
        return
    }

    ChangeTargets(towerID, target)

    RecordedSteps.Push("ChangeTargets(" towerID ", " target ")")
    LogToConsole("Recorded ChangeTargets(" towerID ", " target ")")
}
