; Hidden regression for the exact scan-code values in the reported screenshot.
QaShortcutNeed(ok, label) {
    global QaShortcutChecks
    if !IsSet(QaShortcutChecks)
        QaShortcutChecks := 0
    if !ok
        throw Error(label)
    QaShortcutChecks++
    FileAppend("PASS: " label "`n", "*")
}
QaShortcutSpecs() => [["PlaceTowerKey", "^sc021", "Ctrl+F"], ["UpgradeTowerKey", "^sc016", "Ctrl+U"]
    , ["AlignCameraKey", "^sc014", "Ctrl+T"], ["ChangeDJTrackKey", "^sc020", "Ctrl+D"]
    , ["SellTowerKey", "^sc02D", "Ctrl+X"], ["DeleteTowerRecordingKey", "^sc030", "Ctrl+B"]
    , ["RecordInputsKey", "+^sc012", "Ctrl+Shift+E"], ["HoloKey", "^!sc023", "Ctrl+Alt+H"]
    , ["ChangeTargetsKey", "^sc029", "Ctrl+Backtick"]]
QaShortcutSeed() {
    global PlaceTowerKey, UpgradeTowerKey, AlignCameraKey, ChangeDJTrackKey, SellTowerKey
        , DeleteTowerRecordingKey, RecordInputsKey, HoloKey, ChangeTargetsKey
    for spec in QaShortcutSpecs() {
        name := spec[1]
        %name% := spec[2]
        IniWrite(spec[2], SettingsFile, "RecordingHotkeys", name)
    }
}
QaShortcutTest() {
    global QaShortcutChecks, PlaceTowerKey, UpgradeTowerKey, AlignCameraKey, ChangeDJTrackKey, SellTowerKey
        , DeleteTowerRecordingKey, RecordInputsKey, HoloKey, ChangeTargetsKey
    ProcessSetPriority("BelowNormal")
    try {
        MW.SelectPage(2, false)
        QaShortcutNeed(MW.recordShortcuts.Count = 9, "All nine recording shortcut fields exist")
        for spec in QaShortcutSpecs() {
            name := spec[1], field := MW.recordShortcuts[name]
            QaShortcutNeed(field.Text = spec[3], name " displays readable key names")
            field.onCommit.Call(field)
            QaShortcutNeed(%name% = spec[2] && IniRead(SettingsFile, "RecordingHotkeys", name) = spec[2], name " preserves exact saved scan code on unchanged commit")
            QaShortcutNeed(!(WinGetStyle(field.ctrl) & 4) && SendMessage(0x00BA, 0, 0, field.ctrl) = 1, name " is a non-wrapping single-line control")
        }
        field := MW.recordShortcuts["PlaceTowerKey"]
        field.Text := "Ctrl+U"
        field.onCommit.Call(field)
        QaShortcutNeed(PlaceTowerKey = "^sc021" && field.Text = "Ctrl+F", "Readable duplicate cannot shadow a saved scan-code action")
        for value in ["sc03B", "sc03C", "vk70", "vk71", "F1", "F2", "Ctrl+", "Ctrl+NoSuchKey", "Ctrl+Z", "Ctrl+L", "Ctrl+V"] {
            field.Text := value
            field.onCommit.Call(field)
            QaShortcutNeed(PlaceTowerKey = "^sc021" && field.Text = "Ctrl+F", "Invalid/reserved/conflicting edit rejected: " value)
        }
        field.Text := " Ctrl + P "
        UI_KeyDown(13, 0, 0x100, field.ctrl.Hwnd)
        QaShortcutNeed(StrLower(PlaceTowerKey) = "^p" && field.Text = "Ctrl+P", "Enter commits readable shortcut through the real UI route")
        QaShortcutNeed(StrLower(IniRead(SettingsFile, "RecordingHotkeys", "PlaceTowerKey")) = "^p", "Readable edit persists in the original settings section")
        field.Text := "^sc021"
        field.onCommit.Call(field)
        QaShortcutNeed(PlaceTowerKey = "^sc021" && field.Text = "Ctrl+F", "Raw AHK syntax remains compatible without leaking into display")
        QaShortcutNeed(RecorderShortcutDisplay("<^sc021") = "Left Ctrl+F" && RecorderShortcutParse("Left Ctrl+F") = "<^F", "Left/right modifier semantics are retained")
        QaShortcutNeed(RecorderShortcutDisplay("#^sc021") = "Ctrl+Win+F" && RecorderShortcutParse("Ctrl+Win+F") = "^#F", "Windows-modifier bindings remain representable")
        QaShortcutNeed(RecorderShortcutIdentity("+^sc012") = RecorderShortcutIdentity("^+e"), "Modifier order and scan/VK aliases identify the same combination")
        for size in [[1100, 800], [720, 540], [1366, 768], [900, 680]] {
            MW.OnSize(0, size[1], size[2])
            previousBottom := -100000
            for spec in QaShortcutSpecs() {
                field := MW.recordShortcuts[spec[1]]
                QaShortcutNeed(field.y >= previousBottom && field.h = 34 && field.w >= 160, "Shortcut rows do not overlap at " size[1] "x" size[2])
                previousBottom := field.y + field.h
            }
        }
        for spec in QaShortcutSpecs() {
            name := spec[1], field := MW.recordShortcuts[name]
            field.Text := "Ctrl+Alt+Shift+F" (A_Index + 2)
            field.onCommit.Call(field)
            QaShortcutNeed(RecorderShortcutIdentity(%name%) = RecorderShortcutIdentity("^!+F" (A_Index + 2)), name " edits and registers successfully")
        }
        MW.Hide()
        MW.Open(false)
        for spec in QaShortcutSpecs() {
            name := spec[1]
            QaShortcutNeed(MW.recordShortcuts[name].Text = RecorderShortcutDisplay(IniRead(SettingsFile, "RecordingHotkeys", name)), name " retains its readable saved value after tray reopen")
        }
        MW.Hide()
        for spec in QaShortcutSpecs() {
            name := spec[1]
            %name% := IniRead(SettingsFile, "RecordingHotkeys", name)
        }
        MW.Open(false)
        QaShortcutNeed(MW.recordShortcuts.Count = 9 && MW.LayoutReady(), "Saved values reconstruct without duplicate fields on relaunch")
        FileAppend("SUCCESS: " QaShortcutChecks " shortcut regression assertions.`n", "*")
        ExitApp(0)
    } catch as err
        QaUiError(err)
}
