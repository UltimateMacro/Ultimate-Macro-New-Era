; Two-strategy rotation restored from the owner's original TDS_Macro/Main.ahk
; in 1.3.3a.zip (SHA256 ac3e74c944bc22a9185fb8a93532f09ffe1a93d1d2eaebc7f8bd3f8813316ca4).
; The supplied modified 1.3.3.10 intentionally removed this feature. Its replay,
; placement, equip, map, restart and ability implementations remain unchanged.
InitializeStrategyRotation() {
    global RotateStrategies, Strategy2Path, SwapAmount, SwapUnit, CurrentRotationIndex
        , CurrentStratStartTime, CurrentRunCount, AutoEquip
    RotateStrategies := IniRead(SettingsFile, "Options", "RotateStrategies", 0) = 1
    Strategy2Path := Trim(IniRead(SettingsFile, "Options", "Strategy2", ""))
    SwapAmount := IniRead(SettingsFile, "Options", "SwapAmount", "4")
    if !RegExMatch(SwapAmount, "^\d+$") || SwapAmount < 1 || SwapAmount > 2147483647
        SwapAmount := "4"
    SwapUnit := IniRead(SettingsFile, "Options", "SwapUnit", "Runs") = "Minutes" ? "Minutes" : "Runs"
    CurrentRotationIndex := IniRead(StateFile, "State", "CurrentRotationIndex", "1") = 2 ? 2 : 1
    CurrentStratStartTime := Integer(IniRead(StateFile, "State", "CurrentStratStartTime", "0"))
    CurrentRunCount := Integer(IniRead(StateFile, "State", "CurrentRunCount", "0"))
    if RotateStrategies {
        AutoEquip := 1
        IniWrite(1, SettingsFile, "Options", "AutoEquip")
    }
}

CreateStrategyRotationControls() {
    global Strategy2Ctrl, Tab1_Btn3, Tab1_Btn4, RotateStrategiesCtrl, SwapAmountCtrl, SwapUnitCtrl
    Strategy2Ctrl := MainGui.Add("Edit", "x110 y180 w400 h22 vStrategy2", Strategy2Path)
    MW.Bind(Strategy2Ctrl, "Change", SaveStrat2)
    Tab1_Btn3 := MainGui.Add("Text", "x515 y180 w70 h22", "Browse strategy 2")
    MW.Bind(Tab1_Btn3, "Click", SelectStrat2)
    Tab1_Btn4 := MainGui.Add("Text", "x590 y180 w70 h22", "Clear strategy 2")
    MW.Bind(Tab1_Btn4, "Click", ClearStrat2)
    RotateStrategiesCtrl := MainGui.Add("Checkbox", "x30 y180 vRotateStrategies Checked" RotateStrategies, "Strategy rotation")
    MW.Bind(RotateStrategiesCtrl, "Click", EnableStratRotation)
    SwapAmountCtrl := MainGui.Add("Edit", "x217 y180 w60 h22 Number vSwapAmount", SwapAmount)
    MW.Bind(SwapAmountCtrl, "Change", SaveStrategyRotationInterval)
    SwapUnitCtrl := MainGui.Add("DropDownList", "x280 y180 w90 vSwapUnit Choose" (SwapUnit = "Minutes" ? 2 : 1), ["Runs", "Minutes"])
    MW.Bind(SwapUnitCtrl, "Change", SaveStrategyRotationInterval)
}

StrategyRotationValid() {
    if !RotateStrategies
        return true
    for path in [Strategy1Path, Strategy2Path]
        if (Trim(path) = "" || !FileExist(path) || InStr(FileExist(path), "D"))
            return false
    return RegExMatch(SwapAmount, "^\d+$") && SwapAmount >= 1 && SwapAmount <= 2147483647
}

EnableStratRotation(*) {
    global RotateStrategies, AutoEquip
    if (RunningStrategy || Recording)
        return
    RotateStrategies := RotateStrategiesCtrl.Value
    IniWrite(RotateStrategies, SettingsFile, "Options", "RotateStrategies")
    ; The original rotation mode requires automatic loadout changes.
    if RotateStrategies {
        AutoEquipCtrl.Value := 1
        AutoEquip := 1
        IniWrite(1, SettingsFile, "Options", "AutoEquip")
    }
    UpdateStrategyRotationControls()
}

UpdateStrategyRotationControls() {
    idle := !RunningStrategy && !Recording
    RotateStrategiesCtrl.Enabled := idle
    for ctrl in [Strategy2Ctrl, Tab1_Btn3, Tab1_Btn4, SwapAmountCtrl, SwapUnitCtrl]
        ctrl.Enabled := idle && RotateStrategies
    AutoEquipCtrl.Enabled := !RotateStrategies
    for ctrl in [Strategy1Ctrl, Tab1_Btn1, Tab1_Btn2]
        ctrl.Enabled := idle
}

SaveStrategyRotationInterval(*) {
    global SwapAmount, SwapUnit
    if (RunningStrategy || Recording)
        return
    SwapAmount := Trim(SwapAmountCtrl.Text)
    SwapUnit := SwapUnitCtrl.Text
    if RegExMatch(SwapAmount, "^\d+$") && SwapAmount >= 1 && SwapAmount <= 2147483647
        IniWrite(SwapAmount, SettingsFile, "Options", "SwapAmount")
    IniWrite(SwapUnit, SettingsFile, "Options", "SwapUnit")
}

SelectStrat2(ctrl, *) {
    targDir := Strategy2Path != "" ? Strategy2Path : A_ScriptDir "\Strategies"
    f := FileSelect("3", targDir, "Select strategy file 2", "Strategy (*.strat)")
    if (f != "") {
        Strategy2Ctrl.Value := f
        SaveStrat2()
    }
}

ClearStrat2(*) {
    Strategy2Ctrl.Value := ""
    SaveStrat2()
}

SaveStrat2(*) {
    global Strategy2Path
    if (RunningStrategy || Recording)
        return
    Strategy2Path := Trim(Strategy2Ctrl.Text)
    IniWrite(Strategy2Path, SettingsFile, "Options", "Strategy2")
}

ResetStrategyRotation(starting := false) {
    global CurrentRotationIndex, CurrentStratStartTime, CurrentRunCount
    for key in ["CurrentRotationIndex", "CurrentStratStartTime", "CurrentRunCount"]
        try IniDelete(StateFile, "State", key)
    CurrentRotationIndex := 1, CurrentRunCount := 0
    CurrentStratStartTime := starting ? A_TickCount : 0
    if starting {
        IniWrite(CurrentStratStartTime, StateFile, "State", "CurrentStratStartTime")
        IniWrite(0, StateFile, "State", "CurrentRunCount")
    }
}

StrategyRotationBeforeRun() {
    global CurrentRunCount, RunningStrategy
    ; Removed files and explicit dashboard stops cannot lead to game input.
    if (!RunningStrategy || !StrategyRotationValid() || DashboardMatch.StopPending()) {
        RunningStrategy := false
        IniWrite(0, StateFile, "State", "Running")
        LogToConsole("Run stopped: rotation files/interval are invalid or a dashboard stop is pending.")
        return -1
    }
    ; Original 1.3.3a decision/count semantics: switch between matches, never mid-match.
    switched := false
    if (RotateStrategies) {
        SwapAmount := Integer(IniRead(SettingsFile, "Options", "SwapAmount", 4))
        SwapUnit := IniRead(SettingsFile, "Options", "SwapUnit", "Runs")
        timeToSwitch := false
        if (SwapUnit = "Minutes") {
            if (A_TickCount - CurrentStratStartTime > SwapAmount * 60000)
                timeToSwitch := true
        } else {
            if (CurrentRunCount >= SwapAmount)
                timeToSwitch := true
        }
        if (timeToSwitch) {
            SwitchToNextStrategy(&stratName)
            switched := true
            Sleep(100)
        }
    }
    CurrentRunCount++
    IniWrite(CurrentRunCount, StateFile, "State", "CurrentRunCount")
    if switched {
        IniWrite(gamemap, StateFile, "State", "Map")
        time := FormatTime(, "HH:mm:ss")
        SplitPath(stratName, &fileName)
        startInfo := "[" time "] Switched strategy to: " fileName "`n"
        startInfo .= "Map = " gamemap "`nMode = " difficulty "`nTimescale = " TimeScaleMode "`nRequired Towers: " requiredTowers
        if (modifiers != "")
            startInfo .= "`nModifiers: " modifiers
        SendToWebhookInstant(startInfo,, flush := false)
    }
    return switched
}

; Original 1.3.3a switching function, unchanged apart from trailing whitespace.
SwitchToNextStrategy(&stratName) {
    global CurrentRotationIndex, Strategy1Path, Strategy2Path, requiredTowers
    global CurrentStratStartTime, CurrentRunCount, StateFile, RunningStrategy, difficulty

    if (CurrentRotationIndex = 1) {
        LoadStrategyFile(Strategy2Path)
        CurrentRotationIndex := 2
        IniWrite(2, StateFile, "State", "CurrentRotationIndex")
        stratName := Strategy2Path
    } else {
        LoadStrategyFile(Strategy1Path)
        CurrentRotationIndex := 1
        IniWrite(1, StateFile, "State", "CurrentRotationIndex")
        stratName := Strategy1Path
    }

    CurrentStratStartTime := A_TickCount
    CurrentRunCount := 0
    IniWrite(A_TickCount, StateFile, "State", "CurrentStratStartTime")
    IniWrite(0, StateFile, "State", "CurrentRunCount")

    IniWrite(1, StateFile, "State", "Running")
    IniWrite(stratName, StateFile, "State", "Strategy")

    return true
}

; Original rotation re-entry branch: the new slot needs its own lobby/loadout.
StrategyRotationJoinGame() {
    closeRoblox_ := true
    if (GetRobloxHWND()) {
        ActivateRoblox()
        Loop 2 {
            getRobloxPos(,,&w,&h)
            play_btn := AdvancedImageSearch("Resources/Play.png", Round(w * 0.25), Round(h * 0.66), Round(w * 0.75), Round(h * 0.34))
            if (play_btn.status = "success" && play_btn.score > 0.65) {
                closeRoblox_ := false
                break
            }
            Sleep 150
        }
    }
    if (closeRoblox_) {
        CloseRoblox()
        RunRoblox()
    }
    EquipTowers(RequiredTowers)
    JoinGame()
}
