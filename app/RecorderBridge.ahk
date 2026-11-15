; Recorder integration only. Original captured actions live in LegacyRecorder.
global PlaceTowerKey := IniRead(SettingsFile, "RecordingHotkeys", "PlaceTowerKey", "f")
global UpgradeTowerKey := IniRead(SettingsFile, "RecordingHotkeys", "UpgradeTowerKey", "^u")
global AlignCameraKey := IniRead(SettingsFile, "RecordingHotkeys", "AlignCameraKey", "^t")
global ChangeDJTrackKey := IniRead(SettingsFile, "RecordingHotkeys", "ChangeDJTrackKey", "^d")
global SellTowerKey := IniRead(SettingsFile, "RecordingHotkeys", "SellTowerKey", "^x")
global DeleteTowerRecordingKey := IniRead(SettingsFile, "RecordingHotkeys", "DeleteTowerRecordingKey", "^b")
global RecordInputsKey := IniRead(SettingsFile, "RecordingHotkeys", "RecordInputsKey", "^+e")
global HoloKey := IniRead(SettingsFile, "RecordingHotkeys", "HoloKey", "^!h")
global ChangeTargetsKey := IniRead(SettingsFile, "RecordingHotkeys", "ChangeTargetsKey", "^vkC0")
global CachedResV2 := "", CachedResV1 := ""
global RecordingsDir := A_AppData "\Ultimate_Macro\Recordings"

RecorderGameFocused() {
    hwnd := GetRobloxHWND()
    return hwnd && WinActive("ahk_id " hwnd)
}

IsRecordingActive(*) => Recording && RecorderGameFocused()

RecorderStart(ctrl := "", *) {
    if RunningStrategy || Recording
        return
    if !GetRobloxHWND() {
        ModernMsgBox("Recording", "Open Roblox and join the match you want to record first.", "OK")
        return
    }
    DirCreate(RecordingsDir)
    RegisterRecordingHotkeys()
    StartRecording(ctrl)
    MW.Sync(true)
}

RecorderStopOnExit(*) {
    if IsObject(InputHookObj)
        try InputHookObj.Stop()
}
OnExit(RecorderStopOnExit)

RecorderItems(ctrl, listBox := false) {
    ; Read only our own hidden form controls, never another application's UI.
    count := SendMessage(listBox ? 0x18B : 0x146, 0, 0, ctrl)
    items := []
    Loop count {
        index := A_Index - 1
        length := SendMessage(listBox ? 0x18A : 0x149, index, 0, ctrl)
        text := Buffer((length + 1) * 2, 0)
        SendMessage(listBox ? 0x189 : 0x148, index, text.Ptr, ctrl)
        items.Push(StrGet(text))
    }
    return items
}

RecorderModifier(index, widget, value) {
    SendMessage(0x185, value ? 1 : 0, index - 1, RecModifiersCtrl)
}

RecorderShortcutDisplay(hotkey) {
    if !RegExMatch(hotkey, "\A([<>\^+!#~*$]*)(.+)\z", &part)
        return hotkey
    key := GetKeyName(part[2])
    if key = ""
        return hotkey
    text := ""
    for spec in [["^", "Ctrl"], ["!", "Alt"], ["+", "Shift"], ["#", "Win"]] {
        side := InStr(part[1], "<" spec[1]) ? "Left " : InStr(part[1], ">" spec[1]) ? "Right " : ""
        if InStr(part[1], spec[1])
            text .= side spec[2] "+"
    }
    return text (key = "``" ? "Backtick" : StrLen(key) = 1 ? StrUpper(key) : key)
}

RecorderShortcutParse(text) {
    text := Trim(text)
    if !InStr(text, "+") || RegExMatch(text, "\A[<>\^+!#~*$]")
        return text ; existing AHK notation remains accepted
    parts := StrSplit(text, "+"), prefix := ""
    if parts.Length < 2
        return ""
    Loop parts.Length - 1 {
        switch StrLower(Trim(parts[A_Index])) {
            case "ctrl", "control": prefix .= "^"
            case "alt": prefix .= "!"
            case "shift": prefix .= "+"
            case "win": prefix .= "#"
            case "left ctrl", "left control": prefix .= "<^"
            case "right ctrl", "right control": prefix .= ">^"
            case "left alt": prefix .= "<!"
            case "right alt": prefix .= ">!"
            case "left shift": prefix .= "<+"
            case "right shift": prefix .= ">+"
            case "left win": prefix .= "<#"
            case "right win": prefix .= ">#"
            default: return ""
        }
    }
    key := Trim(parts[-1])
    if StrLower(key) = "backtick"
        key := "vkC0"
    return key != "" ? prefix key : ""
}

RecorderShortcutIdentity(hotkey) {
    if !RegExMatch(hotkey, "\A([<>\^+!#~*$]*)(.+)\z", &part)
        return ""
    key := GetKeyName(part[2])
    if key = ""
        return ""
    prefix := ""
    for modifier in ["^", "!", "+", "#"]
        if InStr(part[1], modifier)
            prefix .= (InStr(part[1], "<" modifier) ? "<" : InStr(part[1], ">" modifier) ? ">" : "") modifier
    return prefix "|" StrLower(key)
}

RecorderShortcutCommit(name, widget) {
    global PlaceTowerKey, UpgradeTowerKey, AlignCameraKey, ChangeDJTrackKey, SellTowerKey
        , DeleteTowerRecordingKey, RecordInputsKey, HoloKey, ChangeTargetsKey
    ; Repainting, tabbing or reopening must never convert an unchanged physical
    ; scan-code binding into a different virtual-key binding.
    if Trim(widget.Text) = RecorderShortcutDisplay(%name%)
        return
    candidate := {Text: RecorderShortcutParse(widget.Text)}
    RecorderShortcut(name, {Value: %name%}, candidate)
    widget.Text := RecorderShortcutDisplay(%name%)
}

RecorderShortcut(name, model, widget) {
    global PlaceTowerKey, UpgradeTowerKey, AlignCameraKey, ChangeDJTrackKey, SellTowerKey
        , DeleteTowerRecordingKey, RecordInputsKey, HoloKey, ChangeTargetsKey
    previous := %name%
    candidate := Trim(widget.Text)
    identity := RecorderShortcutIdentity(candidate)
    if (identity = "" || identity = "|f1" || identity = "|f2") {
        widget.Text := previous
        return false
    }
    old := [PlaceTowerKey, UpgradeTowerKey, AlignCameraKey, ChangeDJTrackKey, SellTowerKey
        , DeleteTowerRecordingKey, RecordInputsKey, HoloKey, ChangeTargetsKey, "~^" RepoKey, "~^" RaiseDeadKey, "~LButton", "~LButton Up"]
    for other in ["PlaceTowerKey", "UpgradeTowerKey", "AlignCameraKey", "ChangeDJTrackKey", "SellTowerKey", "DeleteTowerRecordingKey", "RecordInputsKey", "HoloKey", "ChangeTargetsKey"]
        if (other != name && RecorderShortcutIdentity(%other%) = identity) {
            widget.Text := previous
            return false
        }
    ; These original recorder actions must not be shadowed by an edited slot.
    for reserved in ["^" RepoKey, "^" RaiseDeadKey, "^sc02C", "LButton", "LButton Up", "RButton"]
        if identity = RecorderShortcutIdentity(reserved) {
            widget.Text := previous
            return false
        }
    if candidate = previous
        return true
    %name% := candidate
    try {
        RegisterRecordingHotkeys(old)
        IniWrite(candidate, SettingsFile, "RecordingHotkeys", name)
        model.Value := candidate
        return true
    } catch {
        %name% := previous
        widget.Text := previous
        try RegisterRecordingHotkeys(old)
        return false
    }
}
