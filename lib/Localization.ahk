global ActiveLocale := "en"
global PreferredLocale := "auto"
global UseSystemLocale := false
global ActiveTranslations := Map()
global LocalizationNames := Map("English", "en")
global LocalizationFiles := Map()
global LocalizationControlSources := Map()
global LocalizationGuis := Map()

LocalizationInit(settingsFile, languageDir) {
    global ActiveLocale, PreferredLocale, UseSystemLocale, ActiveTranslations, LocalizationNames, LocalizationFiles
    LocalizationNames := Map("English", "en")
    LocalizationFiles := Map()
    if !DirExist(languageDir)
        return

    Loop Files, languageDir "\ru-RU.json", "F" {
        try catalog := JSON.Parse(FileRead(A_LoopFileFullPath, "UTF-8"))
        catch
            continue
        if !catalog.Has("Locale") || !catalog.Has("Name")
            continue
        locale := Trim(catalog["Locale"] "")
        name := Trim(catalog["Name"] "")
        if locale != "ru-RU" || name = "" || !catalog.Has("Strings") || !(catalog["Strings"] is Map)
            continue
        LocalizationFiles[locale] := A_LoopFileFullPath
        LocalizationNames[name] := locale
    }

    UseSystemLocale := false
    requestedLocale := IniRead(settingsFile, "Localization", "Locale", "en")
    ActiveLocale := LocalizationFiles.Has(requestedLocale) ? requestedLocale : "en"
    PreferredLocale := ActiveLocale
    LocalizationLoad(ActiveLocale)
}

LocalizationDetectLocale() {
    global LocalizationFiles
    localeBuffer := Buffer(85 * 2, 0)
    if !DllCall("Kernel32\GetUserDefaultLocaleName", "Ptr", localeBuffer, "Int", 85, "Int")
        return "en"
    windowsLocale := StrGet(localeBuffer, "UTF-16")
    wanted := StrLower(windowsLocale)
    for locale, file in LocalizationFiles {
        if StrLower(locale) = wanted
            return locale
    }
    parts := StrSplit(windowsLocale, "-")
    language := StrLower(parts[1])
    region := parts.Length > 1 ? StrUpper(parts[2]) : ""
    if language = "pt"
        return region = "BR" && LocalizationFiles.Has("pt-BR") ? "pt-BR" : (LocalizationFiles.Has("pt-PT") ? "pt-PT" : "en")
    if language = "zh" && LocalizationFiles.Has("zh-CN")
        return "zh-CN"
    for locale, file in LocalizationFiles {
        if StrLower(StrSplit(locale, "-")[1]) = language
            return locale
    }
    return "en"
}

LocalizationLoad(locale) {
    global ActiveTranslations, LocalizationFiles
    ActiveTranslations := Map()
    if locale = "en" || !LocalizationFiles.Has(locale)
        return
    try catalog := JSON.Parse(FileRead(LocalizationFiles[locale], "UTF-8"))
    catch
        return
    if !catalog.Has("Strings")
        return
    for source, translated in catalog["Strings"] {
        if Type(source) = "String" && Type(translated) = "String" && Trim(translated) != ""
            ActiveTranslations[source] := translated
    }
}

TranslateText(source) {
    global ActiveTranslations
    if Type(source) != "String" || !ActiveTranslations.Has(source)
        return source
    translated := ActiveTranslations[source]
    ; Keep the product name exact even if a translation file changes it.
    if InStr(source, "Ultimate Macro") && !InStr(translated, "Ultimate Macro")
        return source
    return translated
}

TF(source, values) {
    translated := TranslateText(source)
    for name, value in values
        translated := StrReplace(translated, "{" name "}", value "")
    return translated
}

LocalizationTimeScaleIndex(value) => value = "1.5x" ? 2 : value = "2x" ? 3 : 1
LocalizationTimeScaleValue(index) => index = 2 ? "1.5x" : index = 3 ? "2x" : "OFF"
LocalizationSwapUnitValue(index) => index = 2 ? "Minutes" : "Runs"
LocalizationCurrencyValue(index) => index = 2 ? "Coins" : "Gems"

LocalizationApplyGui(gui) {
    global LocalizationControlSources, LocalizationGuis
    if !LocalizationGuis.Has(gui.Hwnd)
        LocalizationGuis[gui.Hwnd] := gui
    for ctrl in gui {
        try {
            if !(ctrl.Type = "Text" || ctrl.Type = "Button" || ctrl.Type = "Checkbox"
                || ctrl.Type = "Radio" || ctrl.Type = "Link")
                continue
            if !LocalizationControlSources.Has(ctrl.Hwnd)
                LocalizationControlSources[ctrl.Hwnd] := {source: ctrl.Text, applied: ctrl.Text, initialized: false}
            state := LocalizationControlSources[ctrl.Hwnd]
            if state.initialized && ctrl.Text != state.applied
                state.source := ctrl.Text
            original := state.source
            translated := TranslateText(original)
            if translated != original
                ctrl.Text := translated
            state.applied := translated
            state.initialized := true
        }
    }
}

LocalizationLanguageOptions() {
    global LocalizationNames
    options := []
    for name, locale in LocalizationNames
        options.Push(name)
    return options
}

LocalizationNameForLocale(locale) {
    global LocalizationNames
    for name, storedLocale in LocalizationNames {
        if storedLocale = locale
            return name
    }
    return "English"
}

LocalizationPreferenceName() {
    global PreferredLocale, UseSystemLocale
    return UseSystemLocale ? "System default" : LocalizationNameForLocale(PreferredLocale)
}

LocalizationReplaceChoices(ctrl, choices, selected) {
    ctrl.Delete()
    ctrl.Add(choices)
    ctrl.Choose(selected > 0 ? selected : 1)
}

LocalizationRefreshLists() {
    global SwapUnitCtrl, TimeScaleModeCtrl, FarmPicker, FarmSectionIds, FarmInputs
    LocalizationReplaceChoices(SwapUnitCtrl, [TranslateText("Runs"), TranslateText("Minutes")], SwapUnitCtrl.Value)
    LocalizationReplaceChoices(TimeScaleModeCtrl, [TranslateText("OFF"), "1.5x", "2x"], TimeScaleModeCtrl.Value)
    if IsSet(FarmPicker) {
        selected := FarmPicker.Value
        sections := []
        for section in FarmSectionIds
            sections.Push(TranslateText(section))
        LocalizationReplaceChoices(FarmPicker, sections, selected)
    }
    if IsSet(FarmInputs) {
        LocalizationReplaceChoices(FarmInputs["speed"], [TranslateText("OFF"), "1.5x", "2x"], FarmInputs["speed"].Value)
        LocalizationReplaceChoices(FarmInputs["currency"], [TranslateText("Gems"), TranslateText("Coins")], FarmInputs["currency"].Value)
    }
}

LocalizationRefreshDynamicControls() {
    global DiscordSecrets, LanguageCtrl, CurrentTab
    if IsSet(DiscordSecrets) {
        for field, reveal in DiscordSecrets
            reveal.Text := TranslateText(SendMessage(0xD2, 0, 0, field.Hwnd) ? "Show" : "Hide")
    }
    if IsSet(LanguageCtrl)
        LanguageCtrl.Text := LocalizationPreferenceName()
    if IsSet(CurrentTab) && CurrentTab = "Tab7"
        CreditsRender()
}

LocalizationSaveChoice(ctrl, *) {
    global LocalizationAppearanceRefresh
    global SettingsFile, ActiveLocale, PreferredLocale, UseSystemLocale, LocalizationNames, LocalizationFiles, LocalizationGuis
    preference := LocalizationNames.Get(ctrl.Text, "en")
    UseSystemLocale := preference = "auto"
    PreferredLocale := preference
    ActiveLocale := UseSystemLocale ? LocalizationDetectLocale() : preference
    if ActiveLocale != "en" && !LocalizationFiles.Has(ActiveLocale)
        ActiveLocale := "en"
    IniWrite(UseSystemLocale ? 1 : 0, SettingsFile, "Localization", "UseSystem")
    IniWrite(PreferredLocale, SettingsFile, "Localization", "Locale")
    LocalizationLoad(ActiveLocale)
    for hwnd, gui in LocalizationGuis {
        try LocalizationApplyGui(gui)
    }
    LocalizationRefreshLists()
    LocalizationRefreshDynamicControls()
    if IsSet(LocalizationAppearanceRefresh)
        LocalizationAppearanceRefresh.Call()
}

LocalizationMsgBox(text, title := "", options := "") {
    text := TranslateText(text)
    title := title = "" ? "" : TranslateText(title)
    if options != ""
        return MsgBox(text, title, options)
    if title != ""
        return MsgBox(text, title)
    return MsgBox(text)
}

LocalizationInputBox(prompt, title := "", options := "", default := "") {
    prompt := TranslateText(prompt)
    title := title = "" ? "" : TranslateText(title)
    if options != "" || title != ""
        return InputBox(prompt, title, options, default)
    return InputBox(prompt)
}
