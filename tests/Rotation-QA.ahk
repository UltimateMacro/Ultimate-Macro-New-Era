; The real forms, parser, slot switch, persistence and snapshot. No game input or HTTP.
global QaRotationChecks := 0, QaRotationCalls := [], QaRotationLobby := false
QaRotationNeed(ok, label) {
    global QaRotationChecks
    if !ok
        throw Error(label)
    QaRotationChecks++
}
QaRotationTest() {
    global RunningStrategy, Strategy1Path, Strategy2Path, SwapAmount, SwapUnit
        , RotateStrategies, CurrentRotationIndex, CurrentRunCount, CurrentStratStartTime, QaRotationCalls, QaRotationLobby, QaRotationChecks
    ProcessSetPriority("BelowNormal")
    QaRotationChecks := 0, QaRotationCalls := [], QaRotationLobby := false
    QaRotationNeed(!RotateStrategies && !RotateStrategiesCtrl.Value, "Default off")
    MW.Sync(true)
    QaRotationNeed(!Strategy2Ctrl.Enabled && AutoEquipCtrl.Enabled, "Off controls")
    one := A_ScriptDir "\fixture-data\one.strat", two := A_ScriptDir "\fixture-data\two.strat"
    for slot, path in [one, two] {
        IniWrite("Strategy " slot, path, "Settings", "title")
        IniWrite("Map " slot, path, "Settings", "map")
        IniWrite(slot = 1 ? "Easy" : "Fallen", path, "Settings", "difficulty")
        IniWrite(slot = 1 ? "Scout" : "Commander", path, "Settings", "requiredTowers")
        IniWrite(slot = 1 ? "Gla" : "Hid", path, "Settings", "modifiers")
    }
    MW.Assign(Strategy1Ctrl, one)
    MW.Assign(RotateStrategiesCtrl, 1, "Click")
    MW.Assign(Strategy2Ctrl, two)
    QaRotationNeed(AutoEquip = 1 && AutoEquipCtrl.Value = 1 && !AutoEquipCtrl.Enabled, "Original forced equip")
    QaRotationNeed(StrategyRotationValid(), "Valid two-slot setup")
    QaRotationNeed(IniRead(SettingsFile, "Options", "Strategy2", "") = two, "Second path persists")
    originalOne := FileRead(one), originalTwo := FileRead(two)
    for amount in [1, 4, 25, 100] {
        RunningStrategy := false
        MW.Assign(SwapAmountCtrl, String(amount))
        MW.Assign(SwapUnitCtrl, 1)
        QaRotationNeed(SwapAmount = amount && SwapUnit = "Runs", "Run interval model")
        QaRotationNeed(IniRead(SettingsFile, "Options", "SwapAmount", 0) = amount, "No twenty-run cap")
        ResetStrategyRotation(true)
        RunningStrategy := true
        LoadStrategyFile(one)
        Loop amount * 2 + 1 {
            expectedSlot := Mod((A_Index - 1) // amount, 2) + 1
            switched := StrategyRotationBeforeRun()
            QaRotationNeed(switched >= 0 && CurrentRotationIndex = expectedSlot, "Original run boundary")
            QaRotationNeed(gamemap = "Map " expectedSlot, "Correct loaded map")
            QaRotationNeed(requiredTowers = (expectedSlot = 1 ? "Scout" : "Commander"), "Correct loaded towers")
            QaRotationNeed(modifiers = (expectedSlot = 1 ? "Gla" : "Hid"), "Per-slot modifiers")
            QaRotationNeed(IniRead(StateFile, "State", "CurrentRunCount", -1) = CurrentRunCount, "Count persists")
        }
        InitializeStrategyRotation()
        QaRotationNeed(CurrentRotationIndex = 1 && CurrentRunCount = 1, "Reload restores rotation state")
    }
    RunningStrategy := false
    MW.Sync(true)
    MW.Assign(SwapAmountCtrl, "3")
    MW.Assign(SwapUnitCtrl, 2)
    ResetStrategyRotation(true)
    RunningStrategy := true
    CurrentStratStartTime := A_TickCount - 179000
    QaRotationNeed(!StrategyRotationBeforeRun() && CurrentRotationIndex = 1, "Minutes not early")
    CurrentStratStartTime := A_TickCount - 181000
    QaRotationNeed(StrategyRotationBeforeRun() && CurrentRotationIndex = 2 && CurrentRunCount = 1, "Minutes switches after elapsed boundary")
    snapshot := Dashboard.Snapshot()
    QaRotationNeed(snapshot["rotationEnabled"] = JSON.true && snapshot["activeSlot"] = 2, "Dashboard active slot")
    QaRotationNeed(snapshot["activeStrategy"] = "Strategy 2" && snapshot["strategySlots"].Length = 2, "Dashboard shows both slots")
    for lobby in [false, true] {
        QaRotationLobby := lobby, QaRotationCalls := []
        StrategyRotationJoinGame()
        calls := ""
        for call in QaRotationCalls
            calls .= call "|"
        QaRotationNeed(InStr(calls, "equip:Commander|join|"), "Switch equips before joining")
        QaRotationNeed(!!InStr(calls, "close|open|") = !lobby, "Original lobby reuse/relaunch decision")
    }
    MW.Sync(true)
    QaRotationNeed(!RotateStrategiesCtrl.Enabled && !Strategy1Ctrl.Enabled && !Strategy2Ctrl.Enabled, "No editing active slots")
    oldAmount := SwapAmount
    MW.Assign(SwapAmountCtrl, "1")
    QaRotationNeed(SwapAmount = oldAmount, "Active interval cannot change")
    DirCreate(DashboardMatch.root)
    FileAppend("inert fixture token, not a credential", DashboardMatch.tokenFile)
    QaRotationNeed(DashboardMatch.SetStop(true), "Explicit stop configured")
    oldSlot := CurrentRotationIndex
    QaRotationNeed(StrategyRotationBeforeRun() = -1 && !RunningStrategy && CurrentRotationIndex = oldSlot, "Stop beats cycling")
    DashboardMatch.SetStop(false)
    FileDelete(DashboardMatch.tokenFile)
    RunningStrategy := false
    MW.Sync(true)
    MW.Assign(Strategy2Ctrl, A_ScriptDir "\fixture-data\missing.strat")
    QaRotationNeed(!StrategyRotationValid() && !DashboardRemote.QueueRunAction("start"), "Missing second strategy rejected for remote start")
    MW.Assign(Strategy2Ctrl, two)
    MW.Assign(SwapAmountCtrl, "0")
    QaRotationNeed(!StrategyRotationValid(), "Zero interval rejected")
    MW.Assign(SwapAmountCtrl, "")
    QaRotationNeed(!StrategyRotationValid(), "Empty interval rejected")
    MW.Assign(SwapAmountCtrl, "25")
    MW.Assign(SwapUnitCtrl, 1)
    MW.Assign(RotateStrategiesCtrl, 0, "Click")
    RunningStrategy := true
    ResetStrategyRotation(true)
    Loop 61
        QaRotationNeed(!StrategyRotationBeforeRun() && CurrentRotationIndex = 1, "Disabled retains single strategy beyond twenty runs")
    RunningStrategy := false
    ResetStrategyRotation()
    QaRotationNeed(IniRead(StateFile, "State", "CurrentRunCount", "missing") = "missing", "Fresh stop clears cycle state")
    QaRotationNeed(FileRead(one) = originalOne && FileRead(two) = originalTwo, "Cycling never rewrites either strategy")
    FileAppend("SUCCESS: " QaRotationChecks " rotation regression assertions; actual original switch/parser, hidden UI, dashboard snapshot, persistence, explicit stop, inert lobby ports.`n", "*")
    ExitApp(0)
}
QaRotationGetRobloxHWND() => 123
QaRotationActivateRoblox() => QaRotationCalls.Push("activate")
QaRotationgetRobloxPos(&x := 0, &y := 0, &w := 0, &h := 0) => (x:=0,y:=0,w:=1920,h:=1080)
QaRotationAdvancedImageSearch(*) => {status: QaRotationLobby ? "success" : "failed", score: QaRotationLobby ? 1 : 0}
QaRotationCloseRoblox() => QaRotationCalls.Push("close")
QaRotationRunRoblox() => QaRotationCalls.Push("open")
QaRotationEquipTowers(towers) => QaRotationCalls.Push("equip:" towers)
QaRotationJoinGame() => QaRotationCalls.Push("join")
QaRotationSendToWebhookInstant(*) => 0
QaRotationSleep(*) => 0
