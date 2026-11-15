; Hidden fixture only. Never activates a window or sends game input.
QaNeed(ok, label) {
    global QaResidentChecks
    if !IsSet(QaResidentChecks)
        QaResidentChecks := 0
    if !ok
        throw Error(label)
    QaResidentChecks++
    FileAppend("PASS: " label "`n", "*")
}
QaHiddenShow() {
    QaNeed(IsObject(MW.gui) && DllCall("IsWindow", "Ptr", MW.gui.Hwnd), "Open callback targets a valid resident view")
}
class QaResidentCounters {
    static beatCount := 0, remoteCount := 0, botCount := 0
    static Beat(*) => QaResidentCounters.beatCount++
    static Poll(*) => QaResidentCounters.remoteCount++
    static Bot(*) => QaResidentCounters.botCount++
}
QaFindCheck(box, text) {
    if box is Check
        return box.text = text ? box : ""
    if box.HasOwnProp("items")
        for item in box.items {
            found := QaFindCheck(item.widget, text)
            if IsObject(found)
                return found
        }
    return ""
}
QaResidentTest() {
    global QaResidentChecks, QaExitCalled, RunningStrategy
    ProcessSetPriority("BelowNormal")
    try {
        InstallResidentTrayMenu()
        QaNeed(A_TrayMenu.Default = "Open Ultimate Macro" && A_TrayMenu.ClickCount = 2, "Tray default reopens; explicit Exit remains available")
        Dashboard.beatTimer := ObjBindMethod(QaResidentCounters, "Beat")
        DashboardRemote.pollTimer := ObjBindMethod(QaResidentCounters, "Poll")
        UltBot.timer := ObjBindMethod(QaResidentCounters, "Bot")
        for timer in [Dashboard.beatTimer, DashboardRemote.pollTimer, UltBot.timer]
            SetTimer(timer, 30)
        models := MW.events.Count, mirrors := MW.mirrors.Length, files := MW.files.Length
        exitHandler := MW.exitHandler
        Strategy1Ctrl.Value := "QA selected strategy"
        RecTowersCtrl.Value := "Scout, DJ"
        modName := RecorderItems(RecModifiersCtrl, true)[1]
        SendMessage(0x185, 1, 0, RecModifiersCtrl)
        Loop 8 {
            cycle := A_Index
            for size in [[1100, 800], [720, 540], [1366, 768], [900, 680]] {
                MW.OnSize(0, size[1], size[2])
                MW.FlushResize()
                Loop 7
                    MW.SelectPage(A_Index, false)
            }
            old := MW.surface, child := MW.pages[2].surface
            child.RequestLayout()
            child.Invalidate()
            before := [QaResidentCounters.beatCount, QaResidentCounters.remoteCount, QaResidentCounters.botCount]
            MW.Invoke(BtnClose)
            Sleep(65)
            QaNeed(!MW.gui && !MW.closing && !MW.ready && Surface.all.Count = 0, "Close-to-tray fully releases painted view cycle " cycle)
            QaNeed(!MW.syncTimer && !MW.fadeTimer && !MW.pageTimer && !MW.eventsInstalled, "Resident mode stops UI timers/hooks cycle " cycle)
            QaNeed(old.disposed && child.disposed && old.dc = 0 && child.dc = 0, "Back buffers disposed cycle " cycle)
            old.Invalidate(), child.RequestLayout()
            Sleep(25)
            QaNeed(!old.pending && !child.layoutPending, "Stale callbacks cannot schedule disposed UI cycle " cycle)
            QaNeed(QaResidentCounters.beatCount > before[1] && QaResidentCounters.remoteCount > before[2] && QaResidentCounters.botCount > before[3], "Heartbeat/dashboard/UltBot timer ownership survives hide cycle " cycle)
            ShowResidentMacro()
            QaNeed(MW.LayoutReady() && MW.pages.Length = 7 && MW.tabs.Length = 7 && Surface.all.Count = 8, "Reopen builds all seven tabs once cycle " cycle)
            QaNeed(MW.events.Count = models && MW.mirrors.Length = mirrors && MW.files.Length = files && MW.exitHandler = exitHandler, "No duplicated bindings/files/exit hooks cycle " cycle)
            QaNeed(Strategy1Ctrl.Value = "QA selected strategy" && RecTowersCtrl.Value = "Scout, DJ", "Original form state survives cycle " cycle)
            checkbox := QaFindCheck(MW.pages[2].root, modName)
            QaNeed(IsObject(checkbox) && checkbox.checked, "Recording modifier selection survives cycle " cycle)
        }
        ShowResidentMacro()
        MW.Invoke(BtnClose)
        ShowResidentMacro()
        Sleep(65)
        QaNeed(MW.LayoutReady(), "Immediate reopen cancels pending hide")
        MW.Sync(true)
        QaNeed(MW.tabs[2].text = "Record" && MW.recordStart.IsEnabled(), "Restored recorder remains wired after tray cycles")
        threw := false
        try DashboardRemote.StartFromRemote()
        catch
            threw := true
        QaNeed(threw && !DashboardRemote.remoteStartPrompt, "Remote-start prompt flag clears even when handler throws")
        RunningStrategy := true
        DashboardRemote.remoteStartPrompt := true
        UnusedLegacyStart()
        QaNeed(!DashboardRemote.remoteStartPrompt, "Busy original start consumes remote flag without running gameplay")
        RunningStrategy := false
        QaNeed(QaRealPromptOptions(true) = "0x1040 T3" && QaRealPromptOptions(false) = "0x1040 T60", "Only remote required-towers prompt changes to three seconds")
        IniWrite(1, StateFile, "State", "Running")
        IniWrite("test.strat", StateFile, "State", "Strategy")
        IniWrite("123", StateFile, "State", "StartTime")
        RunningStrategy := true
        QaExitCalled := false
        ExitResidentMacro()
        QaNeed(QaExitCalled && !RunningStrategy && IniRead(StateFile, "State", "Running", "missing") = "0", "Explicit tray exit clears autorun state before exit")
        QaNeed(IniRead(StateFile, "State", "Strategy", "missing") = "missing" && IniRead(StateFile, "State", "StartTime", "missing") = "missing", "Explicit exit cannot resume old run on relaunch")
        FileAppend("SUCCESS: " QaResidentChecks " resident lifecycle assertions.`n", "*")
        ExitApp(0)
    } catch as err
        QaUiError(err)
}
