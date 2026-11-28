FarmingBuild(gui) {
    global FarmPicker, FarmPickerHandle, FarmPanels := Map(), FarmRows := [], FarmInputs := Map(), FarmSectionIds
    sections := ["Tower XP", "Auto Equip Loadout", "Timescale Budget", "Goals", "Tools", "Presets", "Earnings"]
    global FarmStyle := Map()
    AppearanceFont(gui, "s10 Norm cE0E5EF", "Segoe UI")
    FarmSectionIds := sections
    localizedSections := []
    for section in sections
        localizedSections.Push(section = "Earnings"
            ? MacroAppearance.Text("farming.earnings", TranslateText(section))
            : TranslateText(section))
    FarmPicker := AppearanceAdd(gui, "DropDownList", "Hidden +0x210 x420 y97 w210 Choose1", localizedSections)
    FarmPickerHandle := FarmPicker.Hwnd
    FarmStyleControl(FarmPicker)
    FarmPicker.OnEvent("Change", FarmingQueueShow)
    for section in sections {
        AppearanceFont(gui, "s12 Norm w600 cA9C9F3")
        FarmPanels[section] := [AppearanceAdd(gui, "Text", "Hidden x70 y98 w320 h24", section)]
        FarmAdd(gui, section, "Progress", "x70 y132 w560 h1 Background333333", 0)
    }
    OnMessage(0x100, FarmNumberKey)
    for msg in [0x133, 0x134, 0x135, 0x138]
        OnMessage(msg, FarmFieldColor)
    s := "Tower XP"
    FarmInputs["cycle"] := FarmAdd(gui, s, "Checkbox", "x70 y151 w310 h24", "Cycle selected towers")
    FarmAdd(gui, s, "Text", "x70 y181 w560 h43", "Use default skins. Replace one requiredTowers entry with Abstract and turn off strategy rotation. Selected towers are farmed in the order shown.")
    for index, definition in TowerXPDefinitions() {
        x := index <= 4 ? 70 : 365
        y := 239 + Mod(index - 1, 4) * 61
        tracked := FarmAdd(gui, s, "Checkbox", "x" x " y" y " w200 h22", definition.name)
        fields := []
        for n, label in ["Level", "XP", "Target"] {
            col := x + (n - 1) * 90
            FarmAdd(gui, s, "Text", "x" col " y" (y+30) " w43 h20", label)
            fields.Push(FarmNumber(gui, s, col+44, y+26, 43, n = 3 ? 1 : 0, n = 2 ? 999 : definition.maxLevel))
        }
        FarmRows.Push({definition: definition, tracked: tracked, level: fields[1], xp: fields[2], target: fields[3]})
    }
    FarmSaveButton(gui, s)
    s := "Auto Equip Loadout"
    FarmAdd(gui, s, "Text", "x70 y158 w560 h28", "Equip towers faster with a saved loadout. Enter its exact name.")
    FarmInputs["loadoutOn"] := FarmAdd(gui, s, "Checkbox", "x70 y199 w310 h24", "Use a saved loadout")
    FarmAdd(gui, s, "Text", "x70 y244 w240 h20", "Loadout name")
    FarmInputs["loadout"] := FarmAdd(gui, s, "Edit", "x70 y270 w560 h30 Limit80", "")
    FarmAdd(gui, s, "Text", "x70 y314 w560 h42", "A loadout= value in the strategy takes priority over this name.")
    FarmSaveButton(gui, s)
    s := "Timescale Budget"
    FarmAdd(gui, s, "Text", "x70 y163 w320 h24", "Match speed")
    FarmInputs["speed"] := FarmAdd(gui, s, "DropDownList", "x490 y159 w140 Choose1", [TranslateText("OFF"), "1.5x", "2x"])
    FarmAdd(gui, s, "Text", "x70 y209 w380 h24", "Timescale ticket budget")
    FarmInputs["budget"] := FarmAdd(gui, s, "Checkbox", "x70 y241 w330 h24", "Limit Timescale ticket use")
    for index, field in [["Balance", "Tickets on hand"], ["Reserve", "Tickets to keep"], ["Cap", "Maximum per session"]] {
        y := 277 + (index-1)*36
        FarmAdd(gui, s, "Text", "x70 y" (y+3) " w360 h23", field[2])
        FarmInputs[field[1]] := FarmNumber(gui, s, 490, y, 140, 0, 1000000)
    }
    FarmAdd(gui, s, "Text", "x70 y393 w560 h54", "Enter your ticket balance manually. A session cap of 0 means unlimited. The macro uses normal speed when it reaches a limit.")
    FarmSaveButton(gui, s)
    s := "Goals"
    FarmInputs["goalOn"] := FarmAdd(gui, s, "Checkbox", "x70 y159 w410 h24", "Stop when target is reached")
    FarmAdd(gui, s, "Text", "x70 y223 w86 h22", "Target")
    FarmInputs["goal"] := FarmNumber(gui, s, 164, 218, 155, 1, 1000000000)
    FarmInputs["currency"] := FarmAdd(gui, s, "DropDownList", "x339 y218 w145 Choose1", [TranslateText("Gems"), TranslateText("Coins")])
    FarmInputs["goalStatus"] := FarmAdd(gui, s, "Text", "x70 y269 w560 h25", "")
    FarmAdd(gui, s, "Text", "x70 y304 w560 h48", "Counts Coins or Gems from match results while Roblox is in front. Stops at or above your target.")
    FarmSaveButton(gui, s)
    s := "Tools"
    FarmAdd(gui, s, "Text", "x70 y149 w560 h24", "Click a tool to open it.")
    tools := [["Auto Abilities", "auto_ability_preview.png", RunAutoAbTool],
        ["Auto Spin", "auto_spin_preview.png", RunAutoSpinTool],
        ["Auto Consumables", "auto_open_consumable_preview.png", RunAutoConsumableTool]]
    for index, tool in tools {
        x := 70 + (index-1)*190
        image := FarmAdd(gui, s, "Picture", "x" x " y186 w180 h-1", A_ScriptDir "\Resources\Gui\v135_" tool[2])
        image.OnEvent("Click", tool[3])
        FarmRound(image.Hwnd)
        label := FarmAdd(gui, s, "Text", "x" x " y376 w180 h26 Center 0x200", tool[1])
        label.OnEvent("Click", tool[3])
    }
    FarmingPresetsBuild(gui)
    FarmingEarningsBuild(gui)
}

FarmingRefreshThemeWording() {
    global FarmPicker, FarmSectionIds
    if !IsSet(FarmPicker) || !IsSet(FarmSectionIds)
        return
    selected := FarmPicker.Value
    labels := []
    for section in FarmSectionIds
        labels.Push(section = "Earnings"
            ? MacroAppearance.Text("farming.earnings", TranslateText(section))
            : TranslateText(section))
    FarmPicker.Delete()
    FarmPicker.Add(labels)
    FarmPicker.Choose(selected >= 1 && selected <= labels.Length ? selected : 1)
}

FarmAdd(gui, section, type, options, value) {
    if type ~= "^(Edit|DropDownList)$"
        AppearanceFont(gui, "s10 Norm cE0E5EF")
    else
        AppearanceFont(gui, "s10 Norm cC0CAD9")
    if type = "Button" {
        type := "Text"
        options .= " Center 0x200 Background1B1B1B cE2E4E7"
    }
    if type = "DropDownList"
        options .= " +0x210"
    ctrl := AppearanceAdd(gui, type, "Hidden " options, value)
    FarmStyleControl(ctrl)
    FarmPanels[section].Push(ctrl)
    return ctrl
}

FarmNumber(gui, section, x, y, width, min, max) {
    ctrl := FarmAdd(gui, section, "Edit", "Number x" x " y" y " w" width " h23", "")
    FarmStyle[ctrl.Hwnd].range := [min, max]
    return ctrl
}

FarmSaveButton(gui, section) {
    global FarmAutosaveStatus
    if !IsSet(FarmAutosaveStatus)
        FarmAutosaveStatus := Map()
    FarmAutosaveStatus[section] := FarmAdd(gui, section, "Text", "x70 y540 w560 h18 BackgroundTrans", "")
    for ctrl in FarmPanels[section] {
        if ctrl.Type = "CheckBox" || ctrl.Type = "DDL"
            ctrl.OnEvent(ctrl.Type = "CheckBox" ? "Click" : "Change", FarmingAutosave.Bind(section, true))
        else if ctrl.Type = "Edit"
            ctrl.OnEvent("Change", FarmingAutosave.Bind(section, false))
    }
}

FarmingAutosave(section, immediate, *) {
    if immediate {
        if SettingsPending.Has("farming." section)
            SettingsPending.Delete("farming." section)
        SettingsFlush()
        FarmingCommit(section)
    } else
        SettingsQueueAction("farming." section, FarmingCommit.Bind(section))
}

FarmingCommit(section) {
    try {
        FarmingSave(section)
    } catch {
        FarmingFeedback(section, "Couldn't save settings.")
    }
}

FarmingFeedback(section, message := "") {
    FarmAutosaveStatus[section].Text := TranslateText(message)
}

FarmingQueueShow(*) {
    if !MacroClosing
        SetTimer(FarmingShow, -1)
}

FarmingShow(redraw := true) {
    global FarmPicker, FarmPanels, FarmSectionIds
    if MacroClosing || !IsSet(CurrentTab) || CurrentTab != "Farming"
        return
    if !FarmSectionIds.Has(FarmPicker.Value)
        return
    selectedSection := FarmSectionIds[FarmPicker.Value]
    for section, controls in FarmPanels {
        for ctrl in controls
            ctrl.Visible := false
    }
    FarmPicker.Visible := true
    for ctrl in FarmPanels[selectedSection]
        ctrl.Visible := true
    if selectedSection = "Earnings"
        FarmingEarningsRender()
    if redraw
        FarmRedraw()
}

FarmingLoad() {
    global SettingsFile, FarmInputs, FarmRows, TimeScaleMode
    f := FarmInputs
    f["cycle"].Value := IniRead(SettingsFile, "TowerXP", "Enabled", 0) = 1
    selected := BatchXPSelection(SettingsFile)
    for row in FarmRows {
        def := row.definition, key := TowerXPSectionName(def.name)
        progress := TowerXPSavedProgress(SettingsFile, def)
        row.tracked.Value := IniRead(SettingsFile, key, "Tracked", selected && selected.name = def.name ? 1 : 0) = 1
        row.level.Value := progress.level
        row.xp.Value := progress.xp
        row.target.Value := TowerXPNumber(SettingsFile, key, "Target", def.maxLevel, def.maxLevel)
    }
    f["loadout"].Value := IniRead(SettingsFile, "Loadouts", "Name", IniRead(SettingsFile, "Loadouts", "Selected", ""))
    f["loadoutOn"].Value := IniRead(SettingsFile, "Loadouts", "Selected", "") != ""
    f["speed"].Choose(LocalizationTimeScaleIndex(TimeScaleMode))
    f["budget"].Value := IniRead(SettingsFile, "TicketBudget", "Enabled", 0) = 1
    for key in ["Balance", "Reserve", "Cap"]
        f[key].Value := TowerXPNumber(SettingsFile, "TicketBudget", key)
    currency := IniRead(SettingsFile, "FarmingGoal", "Currency", "Gems")
    f["goalOn"].Value := IniRead(SettingsFile, "FarmingGoal", "Enabled", IniRead(SettingsFile, "FarmingGoal", "Currency", "") != "") = 1
    f["goal"].Value := IniRead(SettingsFile, "FarmingGoal", "Target", 5000)
    f["currency"].Choose(currency = "Coins" ? 2 : 1)
    f["goalStatus"].Text := BatchGoalStatus()
}

FarmingSave(section, *) {
    global SettingsFile, RunningStrategy, RotateStrategies, FarmInputs, FarmRows
    global TimeScaleMode, TimeScaleModeCtrl, UseTimeScale, TimeScaleMultiplier
    if RunningStrategy {
        FarmingFeedback(section, "Stop the macro before changing Farming settings.")
        return
    }
    f := FarmInputs
    switch section {
        case "Tower XP":
            tracked := 0
            for row in FarmRows {
                def := row.definition, level := row.level.Value, xp := row.xp.Value, target := row.target.Value
                if !FarmInRange(level, 0, def.maxLevel) || !FarmInRange(target, 1, def.maxLevel)
                    || !FarmInRange(xp, 0, Min(999, Max(0, TowerXPNextRequired(def, level)-1))) {
                    FarmingFeedback(section, "Check the selected tower level, XP and target.")
                    return
                }
                tracked += row.tracked.Value
            }
            if f["cycle"].Value && (!tracked || RotateStrategies) {
                FarmingFeedback(section, "Select at least one tower and turn off strategy rotation.")
                return
            }
            for row in FarmRows {
                def := row.definition, key := TowerXPSectionName(def.name)
                saved := TowerXPSavedProgress(SettingsFile, def)
                IniWrite(row.level.Value "," row.xp.Value "," saved.matchId, SettingsFile, key, "Progress")
                IniWrite(row.target.Value, SettingsFile, key, "Target")
                IniWrite(row.tracked.Value, SettingsFile, key, "Tracked")
            }
            IniWrite(1, SettingsFile, "TowerXP", "Cycle")
            IniWrite(f["cycle"].Value, SettingsFile, "TowerXP", "Enabled")
        case "Auto Equip Loadout":
            name := Trim(f["loadout"].Value)
            result := BatchDispatch("loadout select " (f["loadoutOn"].Value ? name : "off"), "", "!")
            if result ~= "^(Enter|Try)" {
                FarmingFeedback(section, result)
                return
            }
            IniWrite(name, SettingsFile, "Loadouts", "Name")
        case "Timescale Budget":
            for key in ["Balance", "Reserve", "Cap"] {
                if !FarmInRange(f[key].Value, 0, 1000000) {
                    FarmingFeedback(section, "Enter a number between 0 and 1,000,000 for each ticket field.")
                    return
                }
            }
            for key in ["Balance", "Reserve", "Cap"]
                IniWrite(f[key].Value, SettingsFile, "TicketBudget", key)
            IniWrite(f["budget"].Value, SettingsFile, "TicketBudget", "Enabled")
            TimeScaleMode := LocalizationTimeScaleValue(f["speed"].Value)
            UseTimeScale := TimeScaleMode != "OFF"
            TimeScaleMultiplier := TimeScaleMode = "2x" ? 2 : TimeScaleMode = "1.5x" ? 1.5 : 1
            TimeScaleModeCtrl.Choose(LocalizationTimeScaleIndex(TimeScaleMode))
            IniWrite(TimeScaleMode, SettingsFile, "Options", "TimeScaleMode")
        case "Goals":
            if !FarmInRange(f["goal"].Value, 1, 1000000000) {
                FarmingFeedback(section, "Enter a goal between 1 and 1,000,000,000.")
                return
            }
            IniWrite(f["goal"].Value, SettingsFile, "FarmingGoal", "Target")
            IniWrite(LocalizationCurrencyValue(f["currency"].Value), SettingsFile, "FarmingGoal", "Currency")
            IniWrite(f["goalOn"].Value, SettingsFile, "FarmingGoal", "Enabled")
            f["goalStatus"].Text := BatchGoalStatus()
    }
    FarmingFeedback(section)
}

FarmInRange(value, min, max) => IsInteger(value) && value >= min && value <= max


FarmStyleControl(ctrl, farming := true) {
    hwnd := ctrl.Hwnd
    if ctrl.Type = "Edit" {
        FarmStyle[hwnd] := {kind: "field"}
        AppearanceOpt(ctrl, "Background181818")
        AppearanceFont(ctrl, "cE2E4E7")
        if !(DllCall("GetWindowLongW", "Ptr", hwnd, "Int", -16, "UInt") & 0x4)
            ctrl.Opt("Center")
        FarmDarkFrame(hwnd)
        FarmRound(hwnd)
        if farming {
            ctrl.Opt("-E0x200 -Border")
            SendMessage(0xD3, 3, 5 | (5 << 16), ctrl)
        }
    } else if ctrl.Type = "CheckBox" {
        FarmDarkFrame(hwnd, true)
    } else if ctrl.Type = "DDL" || ctrl.Type = "DropDownList" {
        FarmStyle[hwnd] := {kind: "field", combo: true}
        FarmDarkFrame(hwnd)
        FarmRound(hwnd)
        info := Buffer(40 + 3 * A_PtrSize, 0)
        NumPut("UInt", info.Size, info)
        if DllCall("user32\GetComboBoxInfo", "Ptr", hwnd, "Ptr", info) {
            list := NumGet(info, 40 + 2 * A_PtrSize, "Ptr")
            if list {
                FarmDarkFrame(list, true)
                FarmStyle[list] := {kind: "field"}
            }
        }
    } else if ctrl.Type = "Text" && ctrl.Text ~= "^(Save |Open )"
        FarmRound(hwnd)
}

FarmRound(hwnd, radius := 5) {
    if !DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rect := Buffer(16))
        return
    w := NumGet(rect, 8, "Int"), h := NumGet(rect, 12, "Int")
    r := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", w, "Int", h, "Int", Round(2 * radius * A_ScreenDPI / 96), "Int", Round(2 * radius * A_ScreenDPI / 96), "Ptr")
    if !DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", r, "Int", 1)
        DllCall("DeleteObject", "Ptr", r)
}

FarmFieldColor(dc, child, *) {
    if MacroClosing || !FarmStyle.Has(child)
        return
    if FarmStyle[child].kind = "check" {
        DllCall("SetTextColor", "Ptr", dc, "UInt", MacroAppearance.ColorRef("text", "FFFFFF"))
        DllCall("SetBkMode", "Ptr", dc, "Int", 1)
        return MacroAppearance.Brush("background", "121212")
    }
    if FarmStyle[child].kind != "field"
        return
    DllCall("SetTextColor", "Ptr", dc, "UInt", MacroAppearance.ColorRef("inputText", "E2E4E7"))
    DllCall("SetBkColor", "Ptr", dc, "UInt", MacroAppearance.ColorRef("input", "181818"))
    return MacroAppearance.Brush("input", "181818")
}

FarmNumberKey(key, lParam, msg, hwnd) {
    if (key != 38 && key != 40) || !FarmStyle.Has(hwnd) || !FarmStyle[hwnd].HasOwnProp("range")
        return
    limits := FarmStyle[hwnd].range
    edit := GuiCtrlFromHwnd(hwnd)
    value := IsInteger(edit.Value) ? Integer(edit.Value) : limits[1]
    edit.Value := Max(limits[1], Min(limits[2], value + (key = 38 ? 1 : -1)))
    return 0
}


FarmRedraw() {
    DllCall("RedrawWindow", "Ptr", MainGui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x185)
}


; Native control theme adapted from TDS Macro v1.3.5.
FarmDarkFrame(hwnd, explorer := false) {
    light := MacroAppearance.Luminance(MacroAppearance.Color("background", "121212")) > 0.42
    static enabled := false
    if !enabled {
        enabled := true
        mode := FarmUxThemeProc(135)
        if mode
            try DllCall(mode, "Int", 2, "Int")
    }
    allow := FarmUxThemeProc(133)
    if allow
        try DllCall(allow, "Ptr", hwnd, "Int", light ? 0 : 1, "Int")
    theme := light ? "" : (explorer ? "DarkMode_Explorer" : "DarkMode_CFD")
    try DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", theme, "Ptr", 0)
}

FarmUxThemeProc(ordinal) {
    static module := DllCall("kernel32\LoadLibraryW", "Str", "uxtheme.dll", "Ptr")
    return module ? DllCall("kernel32\GetProcAddress", "Ptr", module, "Ptr", ordinal, "Ptr") : 0
}

ApplyMacroDarkControls(gui) {
    static hotkeyPaint := CallbackCreate(MacroHotkeyPaint, , 6)
    for hwnd, ctrl in gui {
        if ctrl.Type ~= "i)^(Checkbox|Radio)$" {
            FarmStyle[hwnd] := {kind: "check"}
            FarmDarkFrame(hwnd, true)
        } else if ctrl.Type ~= "i)^(Edit|DDL|DropDownList)$" && !FarmStyle.Has(hwnd)
            FarmStyleControl(ctrl, false)
        else if ctrl.Type = "ListBox" {
            FarmStyle[hwnd] := {kind: "field", list: true}
            AppearanceOpt(ctrl, "Background181818")
            AppearanceFont(ctrl, "cE2E4E7")
            FarmDarkFrame(hwnd, true)
        } else if ctrl.Type = "Hotkey" {
            ctrl.Opt("-Border -E0x200")
            FarmRound(hwnd)
            FarmStyle[hwnd] := {kind: "field"}
            AppearanceFont(ctrl, "cE2E4E7")
            FarmDarkFrame(hwnd)
            DllCall("comctl32\SetWindowSubclass", "Ptr", hwnd, "Ptr", hotkeyPaint, "UPtr", 2, "UPtr", 0, "Int")
        }
    }
    ; AutoHotkey handles owner-draw messages itself before OnMessage sees them.
    static callback := CallbackCreate(MacroDrawControl, , 6)
    if !DllCall("comctl32\SetWindowSubclass", "Ptr", gui.Hwnd, "Ptr", callback, "UPtr", 1, "UPtr", 0, "Int")
        throw OSError()
}

MacroDrawControl(hwnd, msg, wParam, info, id, data) {
    if MacroClosing
        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", info, "Ptr")
    ; Read the committed selection after the Farming dropdown closes.
    if msg = 0x111 && ((wParam >> 16) & 0xFFFF) = 8 && info = FarmPickerHandle
        FarmingQueueShow()
    if msg = 0x2B && info && NumGet(info, 0, "UInt") ~= "^[23]$" {
        try {
            offset := A_PtrSize = 8 ? 24 : 20
            combo := NumGet(info, offset, "Ptr")
            if FarmStyle.Has(combo) && (FarmStyle[combo].HasOwnProp("combo") || FarmStyle[combo].HasOwnProp("list")) {
                MacroPaintCombo(combo, info, offset)
                return 1
            }
        }
    }
    return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", info, "Ptr")
}

MacroPaintCombo(combo, info, offset) {
    item := NumGet(info, 8, "Int")
    flags := NumGet(info, 16, "UInt")
    dc := NumGet(info, offset + A_PtrSize, "Ptr")
    rect := info + offset + 2*A_PtrSize
    brush := flags & 1 ? MacroAppearance.Brush("selected", "314662") : MacroAppearance.Brush("input", "1F2024")
    DllCall("FillRect", "Ptr", dc, "Ptr", rect, "Ptr", brush)
    if item < 0
        return
    isList := NumGet(info, 0, "UInt") = 2
    length := DllCall("SendMessageW", "Ptr", combo, "UInt", isList ? 0x18A : 0x149, "Ptr", item, "Ptr", 0, "Ptr")
    if length < 1 || length > 1024
        return
    label := Buffer((length+1)*2, 0)
    DllCall("SendMessageW", "Ptr", combo, "UInt", isList ? 0x189 : 0x148, "Ptr", item, "Ptr", label, "Ptr")
    area := Buffer(16)
    DllCall("RtlMoveMemory", "Ptr", area, "Ptr", rect, "UPtr", 16)
    NumPut("Int", NumGet(area, 0, "Int")+5, area)
    font := DllCall("SendMessageW", "Ptr", combo, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
    oldFont := font ? DllCall("SelectObject", "Ptr", dc, "Ptr", font, "Ptr") : 0
    prevMode := DllCall("SetBkMode", "Ptr", dc, "Int", 1)
    prevColor := DllCall("SetTextColor", "Ptr", dc, "UInt", MacroAppearance.ColorRef("inputText", "E1E7EF"), "UInt")
    DllCall("DrawTextW", "Ptr", dc, "Ptr", label, "Int", length, "Ptr", area, "UInt", 0x8824)
    DllCall("SetTextColor", "Ptr", dc, "UInt", prevColor)
    DllCall("SetBkMode", "Ptr", dc, "Int", prevMode)
    if oldFont
        DllCall("SelectObject", "Ptr", dc, "Ptr", oldFont)
}

MacroHotkeyPaint(hwnd, msg, wParam, lParam, id, data) {
    if MacroClosing
        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    if msg = 0x14
        return 1
    if msg = 0xF {
        rect := Buffer(16)
        paint := Buffer(A_PtrSize = 8 ? 72 : 64, 0)
        dc := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", paint, "Ptr")
        try {
            DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rect)
            DllCall("FillRect", "Ptr", dc, "Ptr", rect, "Ptr", MacroAppearance.Brush("input", "181818"))
            hotkey := MacroHotkeyLabel(GuiCtrlFromHwnd(hwnd).Value)
            font := DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
            prior := font ? DllCall("SelectObject", "Ptr", dc, "Ptr", font, "Ptr") : 0
            DllCall("SetBkMode", "Ptr", dc, "Int", 1)
            DllCall("SetTextColor", "Ptr", dc, "UInt", MacroAppearance.ColorRef("inputText", "E2E4E7"))
            DllCall("DrawTextW", "Ptr", dc, "Str", hotkey, "Int", -1, "Ptr", rect, "UInt", 0x825)
            if (DllCall("GetFocus", "Ptr") = hwnd)
                DllCall("DrawFocusRect", "Ptr", dc, "Ptr", rect)
            if prior
                DllCall("SelectObject", "Ptr", dc, "Ptr", prior)
        } finally DllCall("EndPaint", "Ptr", hwnd, "Ptr", paint)
        return 0
    }
    result := DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    if msg ~= "^(7|8|256|257|260|261|1025)$"
        DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 0)
    return result
}

MacroHotkeyLabel(value) {
    if value = ""
        return "Unassigned"
    modifiers := Map("^", "Ctrl", "!", "Alt", "+", "Shift", "#", "Win")
    held := Map()
    while StrLen(value) > 1 && modifiers.Has(SubStr(value, 1, 1)) {
        held[modifiers[SubStr(value, 1, 1)]] := true
        value := SubStr(value, 2)
    }
    label := ""
    for name in ["Ctrl", "Alt", "Shift", "Win"] {
        if held.Has(name)
            label .= name " + "
    }
    key := GetKeyName(value)
    if key = ""
        key := value
    return label (StrLen(key) = 1 ? StrUpper(key) : key)
}
