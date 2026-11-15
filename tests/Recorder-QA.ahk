; Only used inside the hidden, isolated complete-UI fixture.
global QaInputs := [], QaFocus := true, QaMouseX := 100, QaMouseY := 200
global QaActions := [], QaRecorderChecks := 0, QaInputStarts := 0, QaInputStops := 0

QaNeed(ok, label) {
    global QaRecorderChecks
    if !ok
        throw Error(label)
    QaRecorderChecks++
    FileAppend("PASS: " label "`n", "*")
}
QaInputBox(*) {
    if !QaInputs.Length
        throw Error("Unexpected recorder prompt")
    answer := QaInputs.RemoveAt(1)
    return IsObject(answer) ? answer : {Result: "OK", Value: answer}
}
QaModernMsgBox(*) => "YES"
QaMsgBox(*) => "Yes"
QaActivateRoblox(*) => 0
QaMouseGetPos(&x := 0, &y := 0, &hwnd := 0, &ctrl := 0) {
    x := QaMouseX, y := QaMouseY, hwnd := 423, ctrl := ""
}
QaGetRobloxHWND(*) => 423
QagetRobloxPos(&x := 0, &y := 0, &w := 0, &h := 0) {
    x := 0, y := 0, w := 1920, h := 1009
}
QaMouseMove(*) => 0
QaClick(args*) => QaActions.Push({action: "click", args: args})
QaSend(args*) => QaActions.Push({action: "send", args: args})
QaSendEvent(args*) => QaActions.Push({action: "send", args: args})
QaSleep(args*) => QaActions.Push({action: "sleep", args: args})
QaHyperSleep(args*) => QaActions.Push({action: "hold", args: args})
QaScaleX(value, *) => Integer(value)
QaScaleY(value, *) => Integer(value)
QaAdvancedImageSearch(path, *) => {status: "success", score: InStr(path, "fully_upgraded") ? 0 : 0.99, x: 200, y: 500}
QawaitForTowerUI(&one, &two, *) {
    one := {score: 0.99, x: 200, y: 500}, two := ""
    return true
}
QaUpdateTowerIndicator(id) {
    if Towers.Has(id)
        Towers[id].hwnd := 0
}
QaDeleteAllIndicators(*) => 0
QaShowTowerPathDialog(*) => 0
QaWinClose(*) => 0
QaPixelSearch(&x, &y, *) {
    x := 0, y := 0
    return true
}
QaSellTower(args*) => QaActions.Push({action: "sell", args: args})
QaSpawnTower(args*) => QaActions.Push({action: "spawn", args: args})
QaUpgradeTower(args*) => QaActions.Push({action: "upgrade", args: args})
QaCloneTower(args*) => QaActions.Push({action: "clone", args: args})
QaBrawlerReposition(args*) => QaActions.Push({action: "reposition", args: args})
QaActivateRaiseTheDead(args*) => QaActions.Push({action: "raise", args: args})
QaChangeTargets(args*) => QaActions.Push({action: "target", args: args})
QaSetDJTrack(args*) => QaActions.Push({action: "dj", args: args})
QaAlignCamera(*) => 0
QaToggleAutoskip(*) => QaActions.Push({action: "autoskip", args: []})
class QaInputHook {
    __New(*) {
    }
    KeyOpt(*) => 0
    Start(*) {
        global QaInputStarts
        QaInputStarts++
    }
    Stop(*) {
        global QaInputStops
        QaInputStops++
    }
}
QaHasAction(name) {
    for action in QaActions
        if action.action = name
            return true
    return false
}

QaRecorderTest() {
    global QaInputs, QaFocus, QaActions, QaMouseX, QaMouseY, Recording, MacroRecording
    global QaRecorderChecks, QaInputStarts, QaInputStops
    QaInputs := [], QaFocus := true, QaMouseX := 100, QaMouseY := 200
    QaActions := [], QaRecorderChecks := 0, QaInputStarts := 0, QaInputStops := 0
    DirCreate(RecordingsDir)
    ProcessSetPriority("BelowNormal")
    try {
        MW.SelectPage(2, false)
        QaNeed(MW.tabs[2].text = "Record" && MW.pages.Length = 7, "Restored visible Record tab")
        RecMapsD.Choose("Dead Ahead")
        RecDiffCtrl.Choose("Easy")
        RecTowersCtrl.Value := "Scout, Farm, DJ"
        RecAutoChainCtrl.Value := 1
        RecMoveCtrl.Value := 1
        RecMoveDirCtrl.Choose("W")
        RecMoveDurCtrl.Value := "1000"
        RecorderModifier(2, "", true)
        StartRecording(0)
        MW.Sync(true)
        QaNeed(Recording && !MacroRecording, "Original start handler initializes recording")
        QaNeed(!MW.recordStart.IsEnabled() && MW.recordStop.IsEnabled(), "Recording button states update")
        QaNeed(gamemap = "Dead Ahead" && difficulty = "Easy" && requiredTowers = "Scout, Farm, DJ", "Original map/mode/loadout submission retained")
        QaNeed(autoChain = "ON" && MoveEnabled && MoveDuration = 1000, "Original strategy options retained")
        QaInputs := ["1", "Scout1"]
        PlaceTowerHK()
        QaNeed(Towers.Has("Scout1") && RecordedSteps[-1] = "SpawnTower(100, 200, 1, Scout1)", "Original placement emits replay-compatible coordinates, slot and ID")
        UpgradeTowerHK()
        QaNeed(Towers["Scout1"].level = 1 && RecordedSteps[-1] = "UpgradeTower(Scout1)", "Original upgrade recording retained")
        DetectTowerForUpgrading()
        QaMouseX := 150, QaMouseY := 260
        DetectUpgrade()
        QaNeed(Towers["Scout1"].level = 2 && RecordedSteps[-1] = "UpgradeTower(Scout1)", "Original upgrade-click recognition emits a step")
        QaMouseX := 100, QaMouseY := 200
        QaInputs := ["Green"]
        ChangeDJTrackHK()
        QaNeed(RecordedSteps[-1] = 'SetDJTrack("Green")', "DJ track recording retained")
        QaInputs := ["Strongest"]
        ChangeTargetsHK()
        QaNeed(RecordedSteps[-1] = "ChangeTargets(Scout1, Strongest)", "Target recording retained")
        RecAutoSkipCtrl.Value := 1
        RecordToggleAutoskip()
        QaNeed(RecordedSteps[-1] = "ToggleAutoskip()", "Autoskip recording retained")
        QaInputs := ["Scout1"]
        CloneTowerHK()
        QaNeed(RecordedSteps[-1] = "CloneTower(Scout1, 100, 200)", "Clone recording retained")
        RecordInputsHK()
        QaNeed(MacroRecording && QaInputStarts = 1, "Original raw-input toggle creates an input hook")
        OnKeyDown("", 0x45, 0x12)
        Sleep(15)
        OnKeyUp("", 0x45, 0x12)
        DetectTowerForUpgrading()
        QaRightButton()
        rawCount := MacroSteps.Length
        QaNeed(rawCount >= 6 && InStr(MacroSteps[2], 'Send("e", hold:='), "Raw key holds and clicks retain original format")
        QaFocus := false
        OnKeyDown("", 0x4B, 0x25)
        OnKeyUp("", 0x4B, 0x25)
        DetectTowerForUpgrading()
        QaRightButton()
        QaNeed(MacroSteps.Length = rawCount, "Keys and clicks in other apps are never recorded")
        QaFocus := true
        RecordInputsHK()
        QaNeed(!MacroRecording && QaInputStops = 1 && RecordedSteps.Length > 7, "Raw-input stop stops hook and appends approved steps")
        QaInputs := ["qa-roundtrip"]
        StopRecord(0)
        QaNeed(!Recording && !MacroRecording && FileExist(RecordingsDir "\qa-roundtrip.strat"), "Original stop/save writes a strategy")
        saved := RecordingsDir "\qa-roundtrip.strat"
        QaNeed(Strategy1Ctrl.Value = saved && Strategy1Path = saved, "Saved recording becomes the selected replay strategy")
        QaNeed(IniRead(saved, "Settings", "map") = "Dead Ahead" && IniRead(saved, "Settings", "autoChain") = "ON", "Saved recording preserves metadata")
        QaNeed(IniRead(saved, "DO NOT EDIT", "width") = "1920" && IniRead(saved, "DO NOT EDIT", "height") = "1009", "Saved recording preserves original coordinate dimensions")
        LoadStrategyFile(saved)
        QaNeed(RecordedSteps.Length > 7, "Unchanged 1.3.3.10 loader accepts recording")
        QaActions := []
        for step in RecordedSteps
            ExecuteStep(step)
        for name in ["spawn", "upgrade", "dj", "target", "autoskip", "clone", "click", "send", "sleep"]
            QaNeed(QaHasAction(name), "Unchanged replay parser dispatches " name)
        QaNeed(QaActions[1].args[1] = 100 && QaActions[1].args[2] = 200 && QaActions[1].args[4] = "Scout1", "Replay receives original tower arguments")
        MW.Sync(true)
        QaNeed(MW.recordStart.IsEnabled() && !MW.recordStop.IsEnabled(), "Stop restores idle Record controls")
        QaNeed(QaInputs.Length = 0, "Every expected original prompt consumed, no extra dialogs")
        ; A second capture covers sell-vs-delete semantics and the actual F2
        ; StopStrategy branch (renamed by the fixture, not reimplemented).
        StartRecording(0)
        QaInputs := ["1", "Scout1"]
        PlaceTowerHK()
        UpgradeTowerHK()
        SellTowerHK()
        QaNeed(RecordedSteps.Length = 3 && InStr(RecordedSteps[1], "SpawnTower(") && RecordedSteps[3] = "SellTower(Scout1)", "Selling preserves the spawn/upgrade history needed by replay")
        QaMouseX := 300, QaMouseY := 400
        QaInputs := ["2", "Farm2"]
        PlaceTowerHK()
        DeleteTowerRecordingHK()
        QaNeed(!Towers.Has("Farm2") && RecordedSteps.Length = 3, "Delete Record removes only that tower's recorded actions")
        QaInputs := ["qa-sell-roundtrip"]
        UnusedLegacyStop()
        QaNeed(!Recording && FileExist(RecordingsDir "\qa-sell-roundtrip.strat"), "F2's original stop handler stops and saves recording")
        LoadStrategyFile(RecordingsDir "\qa-sell-roundtrip.strat")
        QaActions := []
        for step in RecordedSteps
            ExecuteStep(step)
        QaNeed(QaActions.Length = 3 && QaActions[1].action = "spawn" && QaActions[2].action = "upgrade" && QaActions[3].action = "sell", "Recorded sell strategy replays in valid order")
        candidate := {Text: "^p"}
        RecorderShortcut("PlaceTowerKey", {Value: PlaceTowerKey}, candidate)
        QaNeed(PlaceTowerKey = "^p" && IniRead(SettingsFile, "RecordingHotkeys", "PlaceTowerKey") = "^p", "Recording shortcut edits persist and rebind")
        candidate.Text := "F2"
        RecorderShortcut("PlaceTowerKey", {Value: PlaceTowerKey}, candidate)
        QaNeed(PlaceTowerKey = "^p" && candidate.Text = "^p", "Reserved stop shortcut cannot be overridden")
        candidate.Text := "^u"
        RecorderShortcut("PlaceTowerKey", {Value: PlaceTowerKey}, candidate)
        QaNeed(PlaceTowerKey = "^p", "Duplicate recording shortcut is rejected")
        candidate.Text := "f"
        RecorderShortcut("PlaceTowerKey", {Value: PlaceTowerKey}, candidate)
        priorSave := FileRead(saved)
        StartRecording(0)
        QaInputs := [{Result: "Cancel", Value: ""}]
        StopRecord(0)
        QaNeed(FileRead(saved) = priorSave, "Cancel save leaves existing strategy untouched")
        StartRecording(0)
        QaInputs := ["..\must-not-exist"]
        StopRecord(0)
        QaNeed(!FileExist(A_ScriptDir "\fixture-data\must-not-exist.strat"), "Save names cannot escape the recordings directory")
        FileAppend("SUCCESS: " QaRecorderChecks " recorder round-trip assertions; game input and OCR mocked.`n", "*")
        ExitApp(0)
    } catch as err
        QaUiError(err)
}
