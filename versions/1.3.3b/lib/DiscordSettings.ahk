BatchConfigCommand(command, args, prefix) {
    global
    local value, mode, lines, key, spec, part, settingName
    if command = "timescale" {
        value := StrLower(args)
        if value = ""
            return "Match speed: **" (TimeScaleMode = "OFF" ? "1x" : TimeScaleMode) "**. Try " BatchCode(prefix "timescale 1.5x") "."
        if !(value ~= "^(off|1x|1\.5x|2x)$")
            return "Choose 1x, 1.5x, or 2x."
        if RunningStrategy || Recording || MacroRecording
            return "Stop the macro before changing match speed."
        mode := value = "1x" || value = "off" ? "OFF" : value
        IniWrite(mode, SettingsFile, "Options", "TimeScaleMode")
        TimeScaleMode := mode
        UseTimeScale := mode != "OFF"
        TimeScaleMultiplier := mode = "2x" ? 2 : mode = "1.5x" ? 1.5 : 1
        TimeScaleModeCtrl.Choose(LocalizationTimeScaleIndex(mode))
        return "Match speed set to **" (mode = "OFF" ? "1x" : mode) "**."
    }
    if command = "party"
        return BatchPartyConfig(args, prefix)
    if command = "vip" {
        if args = "" || args = "status"
            return "VIP server: **" (UseVipServer ? "On" : "Off") "** · link " (BatchHasVipLink(VipLink) ? "configured" : "missing") "."
        if !(args ~= "i)^(on|off)$")
            return "Use " BatchCode(prefix "vip on") " or " BatchCode(prefix "vip off") ". Set the private link in the macro window."
        if args = "on" && !BatchHasVipLink(VipLink)
            return "Set a valid private server link in the macro window first."
        return BatchConfigSet("vip", args, prefix)
    }
    if args = "" || args = "list" || args = "status" {
        lines := ""
        for key, spec in BatchOptionSpec() {
            settingName := spec[1]
            lines .= "**" key "** " BatchOptionValue(%settingName%, spec.Length = 5) "`n"
        }
        return lines "`nChange a setting with " BatchCode(prefix "settings mouse-speed 2") "."
    }
    if !RegExMatch(args, "i)^(?:set\s+)?([a-z-]+)(?:\s+(.+))?$", &part)
        return "Try " BatchCode(prefix "settings") "."
    return BatchConfigSet(StrLower(part[1]), Trim(part[2]), prefix)
}

BatchOptionSpec() {
    return Map(
        "auto-equip", ["AutoEquip", "AutoEquip", "AutoEquipCtrl"],
        "rotation", ["RotateStrategies", "RotateStrategies", "RotateStrategiesCtrl"],
        "restart", ["UseRestartBtn", "UseRestartBtn", "UseRestartBtnCtrl"],
        "play-again", ["UsePlayAgainBtn", "UsePlayAgainBtn", "UsePlayAgainBtnCtrl"],
        "check-map", ["CheckTheMap", "CheckTheMap", "CheckTheMapCtrl"],
        "numbers", ["UseNumbersForHotbar", "UseNumbers", "UseNumbersForHotbarCtrl"],
        "upgrade-key", ["UseHForUpgrade", "UseHotkeyForUpgrade", "UseUpgradeHCtrl"],
        "rewards", ["CollectPlaytimeRewards", "CollectPlaytimeRewards", "CollectPlaytimeRewardsCtrl"],
        "close-chat", ["AutoCloseChat", "AutoCloseChat", "AutoCloseChatCtrl"],
        "potato-mode", ["PotatoMode", "PotatoMode", "PotatoModeCtrl"],
        "always-on-top", ["AlwaysOnTop", "AlwaysOnTop", "AlwaysOnTopCtrl"],
        "vip", ["UseVipServer", "UseVipServer", "UseVipServerCtrl"],
        "mouse-speed", ["DefaultMouseSpeed", "DefaultMouseSpeed", "MouseSpeedUpDown", 1, 3],
        "mouse-delay", ["MouseDelay", "MouseDelay", "MouseDelayUpDown", -1, 75],
        "key-delay", ["KeyDelay", "KeyDelay", "KeyDelayUpDown", -1, 100],
        "upgrade-delay", ["UpgradeDelay", "UpgradeDelay", "UpgradeDelayCtrl", 0, 999])
}

BatchOptionValue(value, numeric) => numeric ? value : (value ? "On" : "Off")

BatchHasVipLink(url) => url ~= "i)^https://(?:www\.)?roblox\.com/\S*[?&](?:privateServerLinkCode|code)=[a-f0-9]+(?:&|$)"

BatchConfigSet(key, value, prefix) {
    global
    local options, spec, varName, ctrlName, numeric, selected
    options := BatchOptionSpec()
    if !options.Has(key)
        return "Unknown setting. See " BatchCode(prefix "settings") "."
    spec := options[key]
    varName := spec[1], ctrlName := spec[3]
    numeric := spec.Length = 5
    if value = ""
        return "**" key "** " BatchOptionValue(%varName%, numeric) "."
    if RunningStrategy || Recording || MacroRecording
        return "Stop the macro before changing settings."
    if numeric {
        if !(value ~= "^-?\d{1,4}$") || !FarmInRange(value, spec[4], spec[5])
            return "Choose a value from " spec[4] " to " spec[5] "."
        selected := Integer(value)
    } else {
        if !(value ~= "i)^(on|off)$")
            return "Use " BatchCode(prefix "settings " key " on") " or " BatchCode(prefix "settings " key " off") "."
        selected := value = "on" ? 1 : 0
        if key = "vip" && selected && !BatchHasVipLink(VipLink)
            return "Set a valid private server link in the macro window first."
        if key = "rotation" && selected && IniRead(SettingsFile, "TowerXP", "Enabled", 0) = 1
            return "Turn off Tower XP farming before enabling rotation."
    }
    IniWrite(selected, SettingsFile, "Options", spec[2])
    %varName% := selected
    %ctrlName%.Value := selected
    switch key {
        case "mouse-speed": MouseSpeedTxt.Value := selected
        case "mouse-delay": MouseDelayTxt.Value := selected
        case "key-delay": KeyDelayTxt.Value := selected
        case "always-on-top": MainGui.Opt(selected ? "+AlwaysOnTop" : "-AlwaysOnTop")
        case "rotation": EnableStratRotation()
    }
    return "**" key "** set to " BatchOptionValue(selected, numeric) "."
}

BatchPartyConfig(args, prefix) {
    global MultiplayerEnabled, PlayerRole, HostName, PartyMembers, LeaveCondition, SettingsFile
    global MultiplayerEnabledTGL, Tab3_HostNm_EDIT, Tab3_PartyMemb_Edit, Tab3_Role_Host, Tab3_Role_Member
    global Tab3_LCondition_All, Tab3_LCondition_Any, RunningStrategy, Recording, MacroRecording
    if args = "" || args = "status"
        return "**" (MultiplayerEnabled ? "On" : "Off") "** · " PlayerRole "`nHost: " BatchCode(HostName)
            . "`nMembers: " BatchCode(SubStr(PartyMembers, 1, 240)) "`nReturn to lobby when " StrLower(LeaveCondition) " members leave."
            . "`nSee " BatchCode(prefix "help settings") " for examples."
    if RunningStrategy || Recording || MacroRecording
        return "Stop the macro before changing party settings."
    if args = "on" || args = "off" {
        MultiplayerEnabled := args = "on" ? 1 : 0
        MultiplayerEnabledTGL.Value := MultiplayerEnabled
        IniWrite(MultiplayerEnabled, SettingsFile, "Multiplayer", "MultiplayerEnabled")
        return "Party mode is **" (MultiplayerEnabled ? "on" : "off") "**."
    }
    if RegExMatch(args, "i)^role\s+(host|member)$", &m) {
        PlayerRole := m[1] = "host" ? "Host" : "Member"
        Tab3_Role_Host.Value := PlayerRole = "Host"
        Tab3_Role_Member.Value := PlayerRole = "Member"
        IniWrite(PlayerRole, SettingsFile, "Multiplayer", "PlayerRole")
        return "Party role set to **" PlayerRole "**."
    }
    if RegExMatch(args, "i)^leave\s+(all|any)$", &m) {
        LeaveCondition := m[1] = "all" ? "All" : "Any"
        Tab3_LCondition_All.Value := LeaveCondition = "All"
        Tab3_LCondition_Any.Value := LeaveCondition = "Any"
        IniWrite(LeaveCondition, SettingsFile, "Multiplayer", "LeaveCondition")
        return "Return to the lobby when " StrLower(LeaveCondition) " members leave."
    }
    if RegExMatch(args, "i)^host\s+([\pL\pN_ -]{1,40})$", &m) {
        HostName := Trim(m[1])
        Tab3_HostNm_EDIT.Value := HostName
        IniWrite(HostName, SettingsFile, "Multiplayer", "HostName")
        return "Party host set to " BatchCode(HostName) "."
    }
    if RegExMatch(args, "i)^members\s+([\pL\pN_, -]{1,200})$", &m) {
        names := []
        for raw in StrSplit(m[1], ",") {
            if Trim(raw) = ""
                return "Use comma-separated names, or " BatchCode(prefix "party members clear") "."
            names.Push(Trim(raw))
        }
        PartyMembers := m[1] = "clear" ? "" : Join(names, ",")
        Tab3_PartyMemb_Edit.Value := PartyMembers
        IniWrite(PartyMembers, SettingsFile, "Multiplayer", "PartyMembers")
        return PartyMembers = "" ? "Party member list cleared." : "Party members: " BatchCode(PartyMembers) "."
    }
    return "See " BatchCode(prefix "help settings") " for party commands."
}

