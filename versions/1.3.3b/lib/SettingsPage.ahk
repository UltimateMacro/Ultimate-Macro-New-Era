SettingsPageInit() {
    global SettingsPending := Map()
    global SettingsStatus := AppearanceAdd(MainGui, "Text", "x24 y534 w652 h18 Hidden BackgroundTrans", "")
    global SettingsAppHeading := AppearanceAdd(MainGui, "Text", "x332 y428 w344 h20 Hidden BackgroundTrans", "Application Settings")
    AppearanceFont(SettingsAppHeading, "s10 Norm c3A86FF")
    AppearanceFont(Tab5_Lbl4, "s10 Norm c3A86FF")
    for row in [
        [UseUpgradeHCtrl, "UseHForUpgrade", "UseHotkeyForUpgrade"],
        [UseRestartBtnCtrl, "UseRestartBtn"], [UsePlayAgainBtnCtrl, "UsePlayAgainBtn"], [CheckTheMapCtrl, "CheckTheMap"],
        [UseNumbersForHotbarCtrl, "UseNumbersForHotbar", "UseNumbers"], [AutoCloseChatCtrl, "AutoCloseChat"],
        [DebugConsoleCtrl, "DebugConsole"], [PotatoModeCtrl, "PotatoMode"], [CollectPlaytimeRewardsCtrl, "CollectPlaytimeRewards"],
        [AlwaysOnTopCtrl, "AlwaysOnTop"], [UseVipServerCtrl, "UseVipServer"], [LegacyModeCtrl, "LegacyMode"]
    ] {
        spec := {name: row[2], key: row.Has(3) ? row[3] : row[2], section: "Options", kind: "toggle"}
        row[1].OnEvent("Click", SettingsCommit.Bind(spec))
    }
    TimeScaleModeCtrl.OnEvent("Change", SettingsCommit.Bind({name: "TimeScaleMode", key: "TimeScaleMode", section: "Options", kind: "speed"}))
    for row in [[MouseSpeedUpDown, "DefaultMouseSpeed", 1, 3], [MouseDelayUpDown, "MouseDelay", -1, 75],
        [KeyDelayUpDown, "KeyDelay", -1, 100], [UpgradeDelayCtrl, "UpgradeDelay", 0, 999]] {
        row[1].OnEvent("Change", SettingsQueue.Bind({name: row[2], key: row[2], section: "Options", kind: "number", min: row[3], max: row[4]}))
    }
    VipLinkCtrl.OnEvent("Change", SettingsQueue.Bind({name: "VipLink", key: "VipLink", section: "Options", kind: "vip"}))
    for row in [[ChainKeyCtrl,"ChainKey","Chain"], [BeatKeyCtrl,"BeatKey","Beat"], [CaravanKeyCtrl,"CaravanKey","Caravan"],
        [RaiseDeadKeyCtrl,"RaiseDeadKey","RaiseTheDead"], [HologramKeyCtrl,"HologramKey","Hologram"], [RepoKeyCtrl,"RepoKey","Repo"],
        [UpgradeTowerGCtrl,"UpgradeTowerGKey","UpgradeTower"], [UpgradeTowerGBCtrl,"UpgradeTowerGBKey","UpgradeBottom"],
        [CancelPlacementKeyCtrl,"CancelPlacementKey","CancelPlacement"]] {
        row[1].OnEvent("Change", SettingsQueue.Bind({name: row[2], key: row[3], section: "Hotkeys", kind: "key"}))
    }
    for row in [[PlaceTowerKeyCtrl,"PlaceTowerKey"], [UpgradeTowerKeyCtrl,"UpgradeTowerKey"], [AlignCameraKeyCtrl,"AlignCameraKey"],
        [ChangeDJTrackKeyCtrl,"ChangeDJTrackKey"], [SellTowerKeyCtrl,"SellTowerKey"], [DeleteTowerRecordingKeyCtrl,"DeleteTowerRecordingKey"],
        [RecordInputsKeyCtrl,"RecordInputsKey"], [HoloKeyCtrl,"HoloKey"], [ChangeTargetsCTRL,"ChangeTargetsKey"]] {
        row[1].OnEvent("Change", SettingsQueue.Bind({name: row[2], key: row[2], section: "RecordingHotkeys", kind: "record"}))
    }
}

SettingsLayout() {
    left := 24, right := 332, full := 652, leftW := 284, rightW := 344
    for row in [[Tab5_Section1,left,94,leftW,20], [Tab5_Line1,left,116,leftW,1],
        [Tab5_Section2,right,94,rightW,20], [Tab5_Line2,right,116,rightW,1],
        [Tab5_Section3,left,292,full,20], [Tab5_Line3,left,319,full,1], [Tab5_Line4,left,426,full,1]] {
        row[1].Move(row[2], row[3], row[4], row[5])
    }
    keys := [[Tab5_Lbl1,ChainKeyCtrl], [Tab5_Lbl2,BeatKeyCtrl], [Tab5_Lbl3,CaravanKeyCtrl], [Tab5_Lbl44,RaiseDeadKeyCtrl,Tab5_Help12],
        [Tab5_Lbl55,HologramKeyCtrl], [Tab5_Lbl56,RepoKeyCtrl,Tab5_Help11], [Tab5_LblUPG,UpgradeTowerGCtrl],
        [Tab5_LblUPGBTM,UpgradeTowerGBCtrl], [Tab5_Lbl99,CancelPlacementKeyCtrl]]
    for index, row in keys {
        x := left + Mod(index - 1, 2) * 148
        y := 126 + Floor((index - 1) / 2) * 31
        row[1].Move(x, y + 1, 88, 24)
        row[2].Move(x + 90, y, 28, 26)
        if row.Has(3)
            row[3].Move(x + 119, y + 3, 16, 20)
    }
    for index, row in [[UseUpgradeHCtrl,Tab5_Help6], [UseRestartBtnCtrl,Tab5_Help4], [UsePlayAgainBtnCtrl,Tab5_Help5],
        [CheckTheMapCtrl,Tab5_Help7], [UseNumbersForHotbarCtrl]] {
        y := 122 + (index - 1) * 27
        row[1].Opt("+0x2000")
        row[1].Move(right, y, 171, 28)
        if row.Has(2)
            row[2].Move(504, y + 3, 16, 20)
    }
    for index, ctrl in [AutoCloseChatCtrl, DebugConsoleCtrl, PotatoModeCtrl, CollectPlaytimeRewardsCtrl] {
        ctrl.Opt("+0x2000")
        ctrl.Move(523, 122 + (index - 1) * 27, 153, 28)
    }
    MouseSpeedLbl.Move(332, 259, 75, 28)
    MouseSpeedTxt.Move(408, 260, 22, 26)
    MouseSpeedUpDown.Move(430, 260, 14, 26)
    MouseDelayLbl.Move(450, 259, 76, 28)
    MouseDelayTxt.Move(526, 260, 22, 26)
    MouseDelayUpDown.Move(548, 260, 14, 26)
    KeyDelayLbl.Move(565, 259, 70, 28)
    KeyDelayTxt.Move(636, 260, 25, 26)
    KeyDelayUpDown.Move(661, 260, 14, 26)
    Tab1_Lbl4.Move(332, 288, 111, 29)
    UpgradeDelayCtrl.Move(445, 290, 50, 26)
    ; The timing controls sit above the recording grid.
    Tab1_Lbl3.Move(502, 290, 105, 26)
    TimeScaleModeCtrl.Move(609, 290, 67, 26)
    for index, row in [[PlcTowerTEXT,PlaceTowerKeyCtrl], [UpgTowerTEXT,UpgradeTowerKeyCtrl], [AlignCamTEXT,AlignCameraKeyCtrl],
        [DjTrackTEXT,ChangeDJTrackKeyCtrl], [SellTowTEXT,SellTowerKeyCtrl], [DelRecTEXT,DeleteTowerRecordingKeyCtrl],
        [RecInputsTEXT,RecordInputsKeyCtrl], [HoloTEXT,HoloKeyCtrl], [RaiseDeadTEXT,ChangeTargetsCTRL]] {
        x := left + Floor((index - 1) / 3) * 222
        y := 326 + Mod(index - 1, 3) * 32
        row[1].Move(x, y, 112, 28)
        row[2].Move(x + 114, y, 94, 26)
    }
    Tab5_Lbl4.Move(left, 435, leftW, 20)
    SettingsAppHeading.Move(right, 435, rightW, 20)
    UseVipServerCtrl.Move(left, 459, leftW, 24)
    VipLinkCtrl.Move(left, 489, leftW, 28)
    VipLinkCtrl.Enabled := !!UseVipServerCtrl.Value
    LanguageLbl.Move(right, 461, 80, 24)
    LanguageCtrl.Move(414, 457, 126, 27)
    AppearanceLink.Move(548, 457, 128, 28)
    AlwaysOnTopCtrl.Opt("+0x2000")
    LegacyModeCtrl.Opt("+0x2000")
    AlwaysOnTopCtrl.Move(right, 489, 166, 29)
    LegacyModeCtrl.Move(508, 489, 168, 29)
}

SettingsFeedback(message := "") {
    if IsSet(SettingsStatus)
        SettingsStatus.Text := TranslateText(message)
}

SettingsQueue(spec, ctrl, *) {
    SettingsQueueAction(spec.name, SettingsCommit.Bind(spec, ctrl))
}

SettingsQueueAction(key, action) {
    global SettingsPending
    SettingsPending[key] := action
    SetTimer(SettingsFlush, -400)
}

SettingsFlush(*) {
    global SettingsPending
    if !IsSet(SettingsPending) || !SettingsPending.Count
        return
    pending := SettingsPending
    SettingsPending := Map()
    SetTimer(SettingsFlush, 0)
    for _, action in pending
        try action.Call()
}

SettingsCommit(spec, ctrl, *) {
    global
    local value := ctrl.Value, name := spec.name, previous, oldKeys, peer, other, keyNames, err
    try {
        if name = "UseVipServer"
            VipLinkCtrl.Enabled := !!value
        if spec.kind = "number" {
            if !IsInteger(value) || Integer(value) < spec.min || Integer(value) > spec.max {
                SettingsFeedback("Enter a valid number.")
                return
            }
            value := Integer(value)
        } else if spec.kind = "speed" {
            if !value
                return
            value := LocalizationTimeScaleValue(value)
        } else if spec.kind = "vip" {
            value := Trim(value)
            if value != "" && !SettingsValidVip(value) {
                SettingsFeedback("Enter a valid Roblox private server link.")
                return
            }
            if value = "" && UseVipServer {
                SettingsFeedback("Turn off VIP Server before clearing its link.")
                return
            }
        } else if spec.kind = "key" || spec.kind = "record" {
            if Recording || MacroRecording {
                SettingsFeedback("Stop recording before changing a keybind.")
                return
            }
            value := Trim(value)
            if value = "" || (spec.kind = "key" && !GetKeyVK(value)) {
                SettingsFeedback("Enter a valid keybind.")
                return
            }
            keyNames := ["ChainKey","BeatKey","CaravanKey","RaiseDeadKey","HologramKey","RepoKey","UpgradeTowerGKey","UpgradeTowerGBKey",
                "CancelPlacementKey","PlaceTowerKey","UpgradeTowerKey","AlignCameraKey","ChangeDJTrackKey","SellTowerKey",
                "DeleteTowerRecordingKey","RecordInputsKey","HoloKey","ChangeTargetsKey"]
            for peer in keyNames {
                if peer = name
                    continue
                other := %peer%
                if StrLower(NormalizeKey(other)) = StrLower(NormalizeKey(value)) {
                    SettingsFeedback("That keybind is already in use.")
                    return
                }
            }
        }
        if name = "UseVipServer" && value && SettingsPending.Has("VipLink")
            SettingsFlush()
        if name = "UseVipServer" && value && !SettingsValidVip(VipLink) {
            ; Keep the field available for setup. Runtime remains off until the link is valid.
            VipLinkCtrl.Enabled := true
            SettingsFeedback("Enter a valid Roblox private server link.")
            return
        }
        if name = "LegacyMode" {
            if IniRead(SettingsFile, "Options", "LegacyMode", 0) != value
                IniWrite(value, SettingsFile, "Options", "LegacyMode")
            SettingsFeedback(value != LegacyMode ? "Legacy Mode changes take effect the next time you open Ultimate Macro." : "")
            return
        }
        previous := %name%
        if previous = value
            return
        oldKeys := spec.kind = "record" ? [previous] : name = "RepoKey" || name = "RaiseDeadKey" ? ["~^" previous] : false
        if oldKeys {
            %name% := value
            try {
                RegisterRecordingHotkeys(oldKeys)
                IniWrite(value, SettingsFile, spec.section, spec.key)
            } catch as err {
                %name% := previous
                try RegisterRecordingHotkeys([spec.kind = "record" ? value : "~^" value])
                throw err
            } finally HotIf()
        } else {
            IniWrite(value, SettingsFile, spec.section, spec.key)
            %name% := value
        }
        if name = "UseVipServer"
            VipLinkCtrl.Enabled := !!value
        else if name = "VipLink" && UseVipServerCtrl.Value && !UseVipServer && SettingsValidVip(value)
            SettingsCommit({name: "UseVipServer", key: "UseVipServer", section: "Options", kind: "toggle"}, UseVipServerCtrl)
        else if name = "TimeScaleMode" {
            TimeScaleMultiplier := value = "2x" ? 2 : value = "1.5x" ? 1.5 : 1
            UseTimeScale := TimeScaleMultiplier != 1
        } else if name = "AlwaysOnTop"
            MainGui.Opt(value ? "+AlwaysOnTop" : "-AlwaysOnTop")
        else if !MacroClosing && name = "DebugConsole" {
            if value
                ShowDebugConsole()
            else
                HideDebugConsole()
        } else if name = "DefaultMouseSpeed"
            SetDefaultMouseSpeed(value)
        else if name = "MouseDelay"
            SetMouseDelay(value)
        else if name = "KeyDelay"
            SetKeyDelay(value)
        SettingsFeedback()
    } catch {
        if spec.kind = "toggle"
            ctrl.Value := name = "LegacyMode" ? IniRead(SettingsFile, "Options", "LegacyMode", 0) : %name%
        else if spec.kind = "speed"
            ctrl.Choose(LocalizationTimeScaleIndex(TimeScaleMode))
        SettingsFeedback("Couldn't save settings.")
    }
}

SettingsValidVip(url) {
    return url ~= "i)^https://(?:www\.)?roblox\.com/(?:(?:[a-z]{2}/)?games/3260590327/[^?\s]*\?privateServerLinkCode=|share\?code=)[a-f0-9]{32}(?:&[^\s]*)?$"
}
