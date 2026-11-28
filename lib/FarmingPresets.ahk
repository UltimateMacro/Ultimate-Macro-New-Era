FarmingPresetsBuild(gui) {
    global FarmPresetPicker, FarmPresetSummary, FarmPresetApply
    FarmAdd(gui, "Presets", "Text", "x70 y154 w560 h42", "Save your current farming settings. Ticket balance and earned Tower XP stay up to date when you switch presets.")
    FarmPresetPicker := FarmAdd(gui, "Presets", "DropDownList", "x70 y201 w560", [])
    FarmPresetPicker.OnEvent("Change", FarmingPresetPreview)
    FarmPresetSummary := FarmAdd(gui, "Presets", "Text", "x70 y245 w560 h162 Background202020", "")
    FarmPresetApply := FarmAdd(gui, "Presets", "Button", "x70 y423 w175 h36", "Apply preset")
    FarmPresetApply.OnEvent("Click", FarmingPresetApply)
    save := FarmAdd(gui, "Presets", "Button", "x255 y423 w175 h36", "Save current setup")
    save.OnEvent("Click", FarmingPresetSave)
    FarmingPresetRefresh()
}

FarmingPresetDir() {
    global AppDataOpt
    return AppDataOpt "\FarmingPresets"
}

FarmingPresetFields() {
    fields := Map(
        "Options", ["Strategy1", "Strategy2", "RotateStrategies", "SwapAmount", "SwapUnit", "AutoEquip", "TimeScaleMode"],
        "Loadouts", ["Name", "Selected"],
        "TicketBudget", ["Enabled", "Reserve", "Cap"],
        "FarmingGoal", ["Enabled", "Target", "Currency"],
        "TowerXP", ["Enabled", "Selected", "Cycle"])
    for tower in TowerXPDefinitions()
        fields[TowerXPSectionName(tower.name)] := ["Tracked", "Target"]
    return fields
}

FarmingPresetRefresh(selected := "") {
    global FarmPresetPicker
    names := []
    selectedIndex := 1
    Loop Files, FarmingPresetDir() "\preset-*.json", "F" {
        name := SubStr(A_LoopFileName, 8, -5)
        if FarmingPresetValidName(name) {
            names.Push(name)
            if name = selected
                selectedIndex := names.Length
        }
    }
    FarmPresetPicker.Delete()
    FarmPresetPicker.Add(names.Length ? names : [TranslateText("No presets yet")])
    FarmPresetPicker.Choose(selectedIndex)
    FarmingPresetPreview()
}

FarmingPresetValidName(name) => name ~= "^[\pL\pN][\pL\pN _-]{0,39}$"

FarmingPresetPath(name) => FarmingPresetDir() "\preset-" name ".json"

FarmingPresetRead(name) {
    if !FarmingPresetValidName(name)
        return false
    path := FarmingPresetPath(name)
    if !FileExist(path)
        return false
    data := JSON.Parse(FileRead(path, "UTF-8"))
    if !(data is Map) || data.Get("version", 0) != 1 || !(data.Get("settings", false) is Map)
        throw Error("Invalid preset format.")
    settings := data["settings"]
    for section, keys in FarmingPresetFields() {
        if !(settings.Get(section, false) is Map)
            throw Error("Preset is missing a settings section.")
        for key in keys {
            if settings[section].Has(key) {
                value := settings[section][key]
                if Type(value) != "String" || RegExMatch(value, "[\r\n\x00]")
                    throw Error("Preset contains an invalid setting.")
            }
        }
    }
    return settings
}

FarmingPresetPreview(*) {
    global FarmPresetPicker, FarmPresetSummary, FarmPresetApply
    FarmPresetApply.Enabled := false
    try {
        settings := FarmingPresetRead(FarmPresetPicker.Text)
        if !settings {
            FarmPresetSummary.Text := TranslateText("Save your current setup to create your first preset.")
            return
        }
        options := settings["Options"]
        SplitPath(options.Get("Strategy1", ""), &first)
        SplitPath(options.Get("Strategy2", ""), &second)
        none := TranslateText("None")
        summary := TF("Strategy 1: {strategy}", Map("strategy", first != "" ? first : none))
        if options.Get("RotateStrategies", 0) = 1
            summary .= Chr(10) TF("Strategy 2: {strategy}", Map("strategy", second != "" ? second : none))
        loadout := settings["Loadouts"].Get("Selected", "")
        summary .= Chr(10) TF("Saved loadout: {loadout}", Map("loadout", loadout != "" ? loadout : none))
        summary .= Chr(10) TF("Timescale: {speed}", Map("speed", TranslateText(options.Get("TimeScaleMode", "OFF"))))
        budget := settings["TicketBudget"]
        if budget.Get("Enabled", 0) = 1
            summary .= Chr(10) TF("Ticket reserve: {reserve} | Session cap: {cap}", Map("reserve", budget.Get("Reserve", "0"), "cap", budget.Get("Cap", "0")))
        goal := settings["FarmingGoal"]
        if goal.Get("Enabled", goal.Has("Currency")) = 1
            summary .= Chr(10) TF("Goal: {amount} {currency}", Map("amount", goal.Get("Target", ""), "currency", TranslateText(goal.Get("Currency", ""))))
        if settings["TowerXP"].Get("Enabled", 0) = 1
            summary .= Chr(10) TranslateText("Tower XP farming enabled")
        FarmPresetSummary.Text := summary
        FarmPresetApply.Enabled := true
    } catch {
        FarmPresetSummary.Text := TranslateText("This preset could not be read.")
    }
}

FarmingPresetSave(*) {
    global SettingsFile, RunningStrategy, Recording, MacroRecording
    SettingsFlush()
    if RunningStrategy || Recording || MacroRecording {
        LocalizationMsgBox("Stop the macro before saving a preset.")
        return
    }
    choice := LocalizationInputBox("Name this farming preset:", "Save preset", "w360")
    if choice.Result != "OK"
        return
    name := Trim(choice.Value)
    if !FarmingPresetValidName(name) {
        LocalizationMsgBox("Use 1–40 letters, numbers, spaces, hyphens, or underscores. Start with a letter or number.")
        return
    }
    path := FarmingPresetPath(name)
    if FileExist(path) && LocalizationMsgBox("Replace the saved preset?", "Save preset", "YesNo") != "Yes"
        return

    settings := Map()
    for section, keys in FarmingPresetFields() {
        values := Map()
        for key in keys {
            try values[key] := IniRead(SettingsFile, section, key) ""
        }
        settings[section] := values
    }
    temp := path ".tmp"
    try {
        DirCreate(FarmingPresetDir())
        presetFile := FileOpen(temp, "w", "UTF-8-RAW")
        try presetFile.Write(JSON.Stringify(Map("version", 1, "settings", settings)))
        finally presetFile.Close()
        FileMove(temp, path, 1)
    } catch {
        LocalizationMsgBox("Could not save the preset.", "Save preset")
        return
    } finally {
        if FileExist(temp)
            try FileDelete(temp)
    }
    FarmingPresetRefresh(name)
}

FarmingPresetApply(*) {
    global FarmPresetPicker, SettingsFile, RunningStrategy, Recording, MacroRecording
    SettingsFlush()
    if RunningStrategy || Recording || MacroRecording {
        LocalizationMsgBox("Stop the macro before applying a preset.")
        return
    }
    temp := SettingsFile ".preset.tmp"
    try {
        settings := FarmingPresetRead(FarmPresetPicker.Text)
        if !settings
            return
        options := settings["Options"]
        for slot in ["Strategy1", "Strategy2"] {
            path := options.Get(slot, "")
            if path != "" && (!FileExist(path) || DirExist(path)) {
                LocalizationMsgBox(TF("Strategy file is missing: {path}", Map("path", path)), "Apply preset")
                return
            }
        }
        if FileExist(SettingsFile)
            FileCopy(SettingsFile, temp, 1)
        else {
            presetFile := FileOpen(temp, "w", "UTF-16")
            presetFile.Close()
        }
        for section, keys in FarmingPresetFields() {
            values := settings[section]
            for key in keys {
                if values.Has(key)
                    IniWrite(values[key], temp, section, key)
                else if IniRead(temp, section, key, Chr(1)) != Chr(1)
                    IniDelete(temp, section, key)
            }
        }
        IniWrite(FarmPresetPicker.Text, temp, "Earnings", "Preset")
        FileMove(temp, SettingsFile, 1)
    } catch {
        LocalizationMsgBox("Could not apply the preset.", "Apply preset")
        return
    } finally {
        if FileExist(temp)
            try FileDelete(temp)
    }
    FarmingPresetSyncControls()
    LocalizationMsgBox("Preset applied.", "Farming Presets")
}

FarmingPresetSyncControls() {
    global SettingsFile, Strategy1Path, Strategy2Path, Strategy1Ctrl, Strategy2Ctrl
    global RotateStrategiesCtrl, AutoEquipCtrl, AutoEquip, SwapAmount, SwapUnit, SwapAmountCtrl, SwapUnitCtrl
    global RotateStrategies
    global TimeScaleMode, TimeScaleModeCtrl, UseTimeScale, TimeScaleMultiplier
    Strategy1Path := IniRead(SettingsFile, "Options", "Strategy1", "")
    Strategy2Path := IniRead(SettingsFile, "Options", "Strategy2", "")
    Strategy1Ctrl.Text := Strategy1Path
    Strategy2Ctrl.Text := Strategy2Path
    RotateStrategiesCtrl.Value := IniRead(SettingsFile, "Options", "RotateStrategies", 0)
    AutoEquip := IniRead(SettingsFile, "Options", "AutoEquip", 0)
    AutoEquipCtrl.Value := AutoEquip
    SwapAmount := IniRead(SettingsFile, "Options", "SwapAmount", 4)
    SwapUnit := IniRead(SettingsFile, "Options", "SwapUnit", "Runs")
    SwapAmountCtrl.Text := SwapAmount
    SwapUnitCtrl.Choose(SwapUnit = "Minutes" ? 2 : 1)
    ; Main updates the rotation controls when opened.
    RotateStrategies := RotateStrategiesCtrl.Value
    TimeScaleMode := IniRead(SettingsFile, "Options", "TimeScaleMode", "OFF")
    TimeScaleModeCtrl.Choose(LocalizationTimeScaleIndex(TimeScaleMode))
    TimeScaleMultiplier := TimeScaleMode = "2x" ? 2 : TimeScaleMode = "1.5x" ? 1.5 : 1
    UseTimeScale := TimeScaleMultiplier != 1
    FarmingLoad()
}
