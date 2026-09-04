; Portable, safe profile import/export.
; Profile files intentionally contain an allowlist of settings only.

global ProfileDialogGui := 0
global ProfileDialogResult := 0

ExportProfile(*) {
    global SettingsFile, RecordingsDir, ProfilesDir, ver
    global Strategy1Path, Strategy2Path
    global TimeScaleMode, UseRestartBtn, UsePlayAgainBtn, CheckTheMap
    global UseNumbersForHotbar, CollectPlaytimeRewards, UseHForUpgrade
    global PotatoMode, DefaultMouseSpeed, MouseDelay, KeyDelay, UpgradeDelay
    global RotateStrategies, SwapAmount, SwapUnit, AutoEquip, LegacyMode
    global ChainKey, BeatKey, CaravanKey, RaiseDeadKey, HologramKey, RepoKey
    global CancelPlacementKey, UpgradeTowerGKey, UpgradeTowerGBKey
    global PlaceTowerKey, UpgradeTowerKey, AlignCameraKey, ChangeDJTrackKey
    global SellTowerKey, DeleteTowerRecordingKey, RecordInputsKey, HoloKey, ChangeTargetsKey

    choices := ShowProfileExportOptions()
    if !IsObject(choices)
        return
    includeOptions := choices["options"]
    includeHotkeys := choices["hotkeys"]
    includeStrategies := choices["strategies"]

    defaultName := SafeProfileName(choices["name"]) ".ump"
    output := FileSelect("S", ProfilesDir "\" defaultName, "Export Ultimate Macro profile", "Ultimate Macro profile (*.ump)")
    if (output = "")
        return
    if !RegExMatch(output, "i)\.ump$")
        output .= ".ump"

    profile := Map()
    profile["formatVersion"] := 1
    profile["application"] := "Ultimate Macro"
    profile["macroVersion"] := ver
    profile["createdAt"] := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    SplitPath(output, &fileName)
    profile["name"] := choices["name"]
    profile["description"] := choices["description"]
    profile["settings"] := Map()
    s := profile["settings"]
    s["Options"] := Map(
        "TimeScaleMode", TimeScaleMode,
        "UseRestartBtn", UseRestartBtn,
        "UsePlayAgainBtn", UsePlayAgainBtn,
        "CheckTheMap", CheckTheMap,
        "UseNumbers", UseNumbersForHotbar,
        "CollectPlaytimeRewards", CollectPlaytimeRewards,
        "UseHotkeyForUpgrade", UseHForUpgrade,
        "PotatoMode", PotatoMode,
        "DefaultMouseSpeed", DefaultMouseSpeed,
        "MouseDelay", MouseDelay,
        "KeyDelay", KeyDelay,
        "UpgradeDelay", UpgradeDelay,
        "RotateStrategies", RotateStrategies,
        "SwapAmount", SwapAmount,
        "SwapUnit", SwapUnit,
        "AutoEquip", AutoEquip,
        "LegacyMode", LegacyMode
    )
    s["Hotkeys"] := Map(
        "Chain", ChainKey, "Beat", BeatKey, "Caravan", CaravanKey,
        "RaiseTheDead", RaiseDeadKey, "Hologram", HologramKey, "Repo", RepoKey,
        "CancelPlacement", CancelPlacementKey, "UpgradeTower", UpgradeTowerGKey,
        "UpgradeBottom", UpgradeTowerGBKey
    )
    s["RecordingHotkeys"] := Map(
        "PlaceTowerKey", PlaceTowerKey, "UpgradeTowerKey", UpgradeTowerKey,
        "AlignCameraKey", AlignCameraKey, "ChangeDJTrackKey", ChangeDJTrackKey,
        "SellTowerKey", SellTowerKey, "DeleteTowerRecordingKey", DeleteTowerRecordingKey,
        "RecordInputsKey", RecordInputsKey, "HoloKey", HoloKey,
        "ChangeTargetsKey", ChangeTargetsKey
    )

    profile["strategies"] := []
    seenStrategies := Map()
    if includeStrategies {
        for path in [Strategy1Path, Strategy2Path] {
            if (path = "" || !FileExist(path))
                continue
            SplitPath(path, &strategyName)
            if seenStrategies.Has(StrLower(strategyName))
                continue
            seenStrategies[StrLower(strategyName)] := true
            profile["strategies"].Push(Map("fileName", strategyName, "content", FileRead(path, "UTF-8")))
        }
    }
    if !includeOptions
        profile["settings"].Delete("Options")
    if !includeHotkeys {
        profile["settings"].Delete("Hotkeys")
        profile["settings"].Delete("RecordingHotkeys")
    }

    preview := "Profile: " profile["name"] "`n`n" ProfileSummary(profile)
    if (ModernMsgBox("Export preview", preview "`nExport this profile?", "YES|NO", "QUESTION") != "YES")
        return

    try {
        outputFile := FileOpen(output, "w", "UTF-8")
        outputFile.Write(JSON.stringify(profile))
        outputFile.Close()
        ModernMsgBox("Profile exported", "Your safe profile was exported successfully.`n`n" output, "OK")
    } catch Error as err {
        ModernMsgBox("Export failed", "The profile could not be exported.`n`n" err.Message, "OK", "WARNING")
    }
}

ImportProfile(*) {
    global ProfilesDir

    input := FileSelect("3", ProfilesDir, "Import Ultimate Macro profile", "Ultimate Macro profile (*.ump)")
    if (input = "")
        return
    ImportProfileFile(input)
}

ImportProfileFile(input) {
    global SettingsFile, RecordingsDir

    try {
        profile := JSON.parse(FileRead(input, "UTF-8"))
        if (!profile.Has("formatVersion") || profile["formatVersion"] != 1)
            throw Error("Unsupported profile format.")
        if (!profile.Has("settings"))
            throw Error("The profile does not contain valid settings.")
        if (profile["settings"].Count = 0 && (!profile.Has("strategies") || profile["strategies"].Length = 0))
            throw Error("The profile does not contain any importable content.")

        uniqueStrategies := []
        duplicateStrategies := 0
        seenStrategies := Map()
        if profile.Has("strategies") {
            for item in profile["strategies"] {
                if (!item.Has("fileName") || !item.Has("content"))
                    continue
                strategyKey := StrLower(SafeProfileName(item["fileName"]))
                if seenStrategies.Has(strategyKey) {
                    duplicateStrategies++
                    continue
                }
                seenStrategies[strategyKey] := true
                uniqueStrategies.Push(item)
            }
        }
        strategyCount := uniqueStrategies.Length
        name := profile.Has("name") ? profile["name"] : "Unnamed profile"
        message := "Profile: " name "`n"
        if profile.Has("macroVersion")
            message .= "Created with macro version: " profile["macroVersion"] "`n"
        if profile.Has("description") && profile["description"] != ""
            message .= "Description: " profile["description"] "`n"
        message .= "`n"
        previewProfile := Map("settings", profile["settings"], "strategies", uniqueStrategies)
        message .= ProfileSummary(previewProfile)
        if (duplicateStrategies > 0)
            message .= "`nDuplicates removed automatically: " duplicateStrategies
        message .= "`nPrivate settings such as webhooks, bot tokens, VIP links, usernames, and paths are not included.`n`n"
        if (ModernMsgBox("Import preview", message, "YES|NO", "QUESTION") != "YES")
            return

        importOptions := profile["settings"].Has("Options") && ModernMsgBox("Import profile", "Import macro settings?", "YES|NO", "QUESTION") = "YES"
        importHotkeys := (profile["settings"].Has("Hotkeys") || profile["settings"].Has("RecordingHotkeys")) && ModernMsgBox("Import profile", "Import hotkeys? This may replace your current keybinds.", "YES|NO", "QUESTION") = "YES"
        importStrategies := strategyCount > 0 && ModernMsgBox("Import profile", "Import the embedded strategy files?", "YES|NO", "QUESTION") = "YES"

        SplitPath(input, , &profileDir, , &profileFile)
        profileDir := RecordingsDir "\Imported Profiles\" SafeProfileName(name)
        DirCreate(profileDir)
        backup := SettingsFile ".profile-backup-" FormatTime(, "yyyyMMdd-HHmmss")
        if FileExist(SettingsFile)
            FileCopy(SettingsFile, backup)

        for sectionName, section in profile["settings"] {
            if (sectionName = "Options" && !importOptions)
                continue
            if ((sectionName = "Hotkeys" || sectionName = "RecordingHotkeys") && !importHotkeys)
                continue
            for key, value in section {
                if ProfileSettingAllowed(sectionName, key)
                    IniWrite(value, SettingsFile, sectionName, key)
            }
        }

        imported := []
        if (importStrategies && strategyCount > 0) {
            for item in uniqueStrategies {
                strategyName := SafeProfileName(item["fileName"])
                if !RegExMatch(strategyName, "i)\.strat$")
                    strategyName .= ".strat"
                destination := profileDir "\" strategyName
                strategyFile := FileOpen(destination, "w", "UTF-8")
                strategyFile.Write(item["content"])
                strategyFile.Close()
                imported.Push(destination)
            }
        }
        if imported.Length > 0 {
            IniWrite(imported[1], SettingsFile, "Options", "Strategy1")
            if (imported.Length > 1)
                IniWrite(imported[2], SettingsFile, "Options", "Strategy2")
        }

        ModernMsgBox("Profile imported", "Profile imported successfully.`n`nA backup was created at:`n" backup "`n`nThe macro will restart to apply the profile.", "OK")
        Reload()
    } catch Error as err {
        ModernMsgBox("Import failed", "This profile could not be imported safely.`n`n" err.Message, "OK", "WARNING")
    }
}

ProfileSummary(profile) {
    summary := "Included content:`n"
    if (profile["settings"].Count = 0)
        summary .= "  - No settings`n"
    else {
        for sectionName, section in profile["settings"]
            summary .= "  - " ProfileSectionLabel(sectionName) ": " section.Count " settings`n"
    }
    summary .= "  - Strategy files: "
    if (!profile.Has("strategies") || profile["strategies"].Length = 0) {
        summary .= "none`n"
    } else {
        summary .= profile["strategies"].Length "`n"
        for item in profile["strategies"]
            summary .= "      " item["fileName"] "`n"
    }
    return summary
}

ProfileSectionLabel(sectionName) {
    switch sectionName {
        case "Options": return "Macro settings"
        case "Hotkeys": return "TDS hotkeys"
        case "RecordingHotkeys": return "Recording hotkeys"
        default: return sectionName
    }
}

SafeProfileName(value) {
    value := RegExReplace(value, "[<>:" Chr(34) "/|?*]", "_")
    value := RegExReplace(value, "[. ]+$", "")
    return (value = "" ? "Imported Profile" : SubStr(value, 1, 80))
}

ProfileManager(*) {
    global ProfilesDir, ProfileManagerGui, ProfileListCtrl, MainGui
    if IsSet(ProfileManagerGui) && IsObject(ProfileManagerGui) {
        try ProfileManagerGui.Destroy()
    }

    ProfileManagerGui := Gui("+Owner" MainGui.Hwnd, "Ultimate Macro Profiles")
    ProfileManagerGui.SetFont("s10", "Segoe UI")
    ProfileManagerGui.Add("Text", "x20 y18 w450", "Saved profiles")
    ProfileManagerGui.Add("Text", "x20 y42 w450 c777777", "Import a saved profile, export your current setup, or roll back the last import.")
    ProfileListCtrl := ProfileManagerGui.Add("ListBox", "x20 y75 w450 h190")
    ProfileManagerGui.Add("Text", "x20 y278 w450 h55 c777777", "Profiles don’t include personal or private information like webhooks, tokens, server links, run history, logs, or anything confidential. You can always review your `.ump` file before sharing it.")
    exportBtn := ProfileManagerGui.Add("Button", "x20 y335 w140 h30", "Export current")
    importBtn := ProfileManagerGui.Add("Button", "x175 y335 w140 h30", "Import selected")
    rollbackBtn := ProfileManagerGui.Add("Button", "x330 y335 w140 h30", "Rollback last")
    refreshBtn := ProfileManagerGui.Add("Button", "x20 y375 w140 h28", "Refresh")
    closeBtn := ProfileManagerGui.Add("Button", "x330 y375 w140 h28", "Close")
    exportBtn.OnEvent("Click", ExportProfile)
    importBtn.OnEvent("Click", ProfileManagerImport)
    rollbackBtn.OnEvent("Click", ProfileManagerRollback)
    refreshBtn.OnEvent("Click", ProfileManagerRefresh)
    closeBtn.OnEvent("Click", (*) => ProfileManagerGui.Destroy())
    ProfileManagerRefresh()
    ProfileManagerGui.Show("w490 h425")
}

ProfileManagerRefresh(*) {
    global ProfilesDir, ProfileListCtrl
    if !IsSet(ProfileListCtrl)
        return
    ProfileListCtrl.Delete()
    profileCount := 0
    Loop Files, ProfilesDir "\*.ump", "F" {
        ProfileListCtrl.Add([A_LoopFileName])
        profileCount++
    }
    if (profileCount = 0)
        ProfileListCtrl.Add(["No saved profiles found"])
}

ProfileManagerImport(*) {
    global ProfilesDir, ProfileListCtrl, ProfileManagerGui
    selected := ProfileListCtrl.Text
    if (selected = "" || selected = "No saved profiles found")
        return
    if (ModernMsgBox("Import profile", "Import '" selected "'? Your current settings will be backed up first.", "YES|NO", "QUESTION") = "YES") {
        ProfileManagerGui.Destroy()
        ImportProfileFile(ProfilesDir "\" selected)
    }
}

ProfileManagerRollback(*) {
    global SettingsFile, ProfileManagerGui
    latest := ""
    latestTime := ""
    Loop Files, SettingsFile ".profile-backup-*", "F" {
        if (latest = "" || A_LoopFileTimeModified > latestTime) {
            latest := A_LoopFileFullPath
            latestTime := A_LoopFileTimeModified
        }
    }
    if (latest = "") {
        ModernMsgBox("Rollback unavailable", "No automatic profile backup exists yet.", "OK", "WARNING")
        return
    }
    if (ModernMsgBox("Rollback profile", "Restore the previous settings backup? The macro will restart.", "YES|NO", "QUESTION") = "YES") {
        FileCopy(latest, SettingsFile, 1)
        ProfileManagerGui.Destroy()
        Reload()
    }
}

ShowProfileExportOptions() {
    global ProfileDialogGui, ProfileDialogResult, MainGui
    ProfileDialogResult := 0
    ProfileDialogGui := Gui("+Owner" MainGui.Hwnd, "Export Ultimate Macro Profile")
    ProfileDialogGui.SetFont("s10", "Segoe UI")
    ProfileDialogGui.Add("Text", "x20 y18 w430", "Choose what this profile will contain")
    ProfileDialogGui.Add("Text", "x20 y45 w110", "Profile name:")
    nameCtrl := ProfileDialogGui.Add("Edit", "x130 y42 w320 vProfileName", "TDS Profile " FormatTime(, "yyyy-MM-dd"))
    ProfileDialogGui.Add("Text", "x20 y80 w110", "Description:")
    ProfileDialogGui.Add("Edit", "x130 y77 w320 h45 vProfileDescription", "Shared TDS Macro setup")
    ProfileDialogGui.Add("Checkbox", "x20 y140 vExportOptions Checked", "Macro settings")
    ProfileDialogGui.Add("Text", "x40 y162 w410 c777777", "Delays, timescale, performance, restart, and safe preferences")
    ProfileDialogGui.Add("Checkbox", "x20 y188 vExportHotkeys Checked", "Hotkeys")
    ProfileDialogGui.Add("Text", "x40 y210 w410 c777777", "TDS ability keys and recording hotkeys")
    ProfileDialogGui.Add("Checkbox", "x20 y236 vExportStrategies Checked", "Selected strategies")
    ProfileDialogGui.Add("Text", "x40 y258 w410 c777777", "Embeds strategy contents instead of personal file paths")
    ProfileDialogGui.Add("Text", "x20 y292 w430 h65 c777777", "Profiles don’t include personal or private information like webhooks, tokens, server links, run history, logs, or anything confidential. You can always review your `.ump` file before sharing it.")
    ok := ProfileDialogGui.Add("Button", "x250 y355 w95 h30", "Continue")
    cancel := ProfileDialogGui.Add("Button", "x355 y355 w95 h30", "Cancel")
    ok.OnEvent("Click", ProfileExportConfirm)
    cancel.OnEvent("Click", ProfileDialogCancel)
    ProfileDialogGui.OnEvent("Close", ProfileDialogCancel)
    ProfileDialogGui.Show("w470 h405")
    WinWaitClose("ahk_id " ProfileDialogGui.Hwnd)
    return ProfileDialogResult
}

ProfileExportConfirm(*) {
    global ProfileDialogGui, ProfileDialogResult
    values := ProfileDialogGui.Submit()
    name := Trim(values.ProfileName)
    if (name = "") {
        ModernMsgBox("Missing name", "Enter a profile name first.", "OK", "WARNING")
        return
    }
    ProfileDialogResult := Map(
        "name", SubStr(name, 1, 80),
        "description", SubStr(Trim(values.ProfileDescription), 1, 300),
        "options", values.ExportOptions = 1,
        "hotkeys", values.ExportHotkeys = 1,
        "strategies", values.ExportStrategies = 1
    )
    if (!ProfileDialogResult["options"] && !ProfileDialogResult["hotkeys"] && !ProfileDialogResult["strategies"]) {
        ModernMsgBox("Nothing selected", "Select at least one category to export.", "OK", "WARNING")
        ProfileDialogResult := 0
        return
    }
    ProfileDialogGui.Destroy()
}

ProfileDialogCancel(*) {
    global ProfileDialogGui, ProfileDialogResult
    ProfileDialogResult := 0
    try ProfileDialogGui.Destroy()
}

ProfileSettingAllowed(section, key) {
    allowed := Map(
        "Options", ["TimeScaleMode", "UseRestartBtn", "UsePlayAgainBtn", "CheckTheMap", "UseNumbers", "CollectPlaytimeRewards", "UseHotkeyForUpgrade", "PotatoMode", "DefaultMouseSpeed", "MouseDelay", "KeyDelay", "UpgradeDelay", "RotateStrategies", "SwapAmount", "SwapUnit", "AutoEquip", "LegacyMode"],
        "Hotkeys", ["Chain", "Beat", "Caravan", "RaiseTheDead", "Hologram", "Repo", "CancelPlacement", "UpgradeTower", "UpgradeBottom"],
        "RecordingHotkeys", ["PlaceTowerKey", "UpgradeTowerKey", "AlignCameraKey", "ChangeDJTrackKey", "SellTowerKey", "DeleteTowerRecordingKey", "RecordInputsKey", "HoloKey", "ChangeTargetsKey"]
    )
    return allowed.Has(section) && HasValue(allowed[section], key)
}

HasValue(values, wanted) {
    for value in values {
        if (value = wanted)
            return true
    }
    return false
}
