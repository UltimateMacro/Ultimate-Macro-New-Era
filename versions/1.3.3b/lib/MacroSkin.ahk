MacroStyleWindow(gui) {
    global MacroComboLists := Map()
    flag := Buffer(4, 0)
    NumPut("Int", 1, flag)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", gui.Hwnd, "UInt", 20, "Ptr", flag, "UInt", 4)
    for hwnd, ctrl in gui {
        if InStr("|Edit|Hotkey|ListBox|ComboBox|DropDownList|", "|" ctrl.Type "|") {
            ctrl.SetFont("cE7EDF8")
            if ctrl.Type = "Edit" {
                ctrl.Opt("-E0x200 -Border")
                SendMessage(0xD3, 3, 5 | (5 << 16), ctrl)
            }
            if ctrl.Type ~= "^(ComboBox|DropDownList|ListBox)$"
                DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)
            if ctrl.Type ~= "^(ComboBox|DropDownList)$" {
                info := Buffer(40 + 3 * A_PtrSize, 0)
                NumPut("UInt", info.Size, info)
                if DllCall("GetComboBoxInfo", "Ptr", hwnd, "Ptr", info) {
                    popup := NumGet(info, 40 + 2 * A_PtrSize, "Ptr")
                    if popup
                        MacroComboLists[popup] := true
                }
            }
            MacroRound(ctrl, 8)
        }
    }
    for ctrl in GradientButtons {
        MacroRound(ctrl.PicControl, 12)
        MacroRound(ctrl, 12)
    }
    for ctrl in [Auto_COA, Auto_Spin, Auto_Consum]
        MacroRound(ctrl, 12)
    for ctrl in HoverEffect {
        ctrl.GetPos(,, &w, &h)
        if (w >= 54 && h >= 20 && !(ctrl.Name ~= "i)title"))
            MacroRound(ctrl, 10)
    }
    OnMessage(0x133, MacroFieldColor)
    OnMessage(0x134, MacroFieldColor)
    OnMessage(0x135, MacroFieldColor)
    OnMessage(0x138, MacroFieldColor)
    OnMessage(0x4E, MacroToggleDraw)
    OnMessage(0x111, MacroDropdownOpened)
}

MacroRound(ctrl, radius) {
    MacroRoundWindow(ctrl.Hwnd, radius)
}

MacroRoundWindow(hwnd, radius) {
    if !DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect := Buffer(16))
        return
    w := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int")
    h := NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int")
    if (w <= 0 || h <= 0)
        return
    region := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", w + 1, "Int", h + 1, "Int", radius, "Int", radius, "Ptr")
    if !DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", region, "Int", 1)
        DllCall("DeleteObject", "Ptr", region)
}

MacroDropdownOpened(wParam, child, msg, hwnd) {
    if hwnd != MainGui.Hwnd || ((wParam >> 16) & 0xFFFF) != 7 || !child
        return
    info := Buffer(40 + 3 * A_PtrSize, 0)
    NumPut("UInt", info.Size, info)
    if DllCall("GetComboBoxInfo", "Ptr", child, "Ptr", info) {
        popup := NumGet(info, 40 + 2 * A_PtrSize, "Ptr")
        if popup
            SetTimer(MacroRoundWindow.Bind(popup, 10), -10)
    }
}

MacroFieldColor(hdc, child, *) {
    static brush := DllCall("CreateSolidBrush", "UInt", 0x2C2430, "Ptr")
    known := MacroComboLists.Has(child)
    if !known {
        try ctrl := GuiCtrlFromHwnd(child)
        catch
            return
        if !ctrl || !(ctrl.Type ~= "^(Edit|Hotkey|ListBox|ComboBox|DropDownList)$")
            return
    }
    DllCall("SetTextColor", "Ptr", hdc, "UInt", 0xF8EDE7)
    DllCall("SetBkColor", "Ptr", hdc, "UInt", 0x2C2430)
    return brush
}

MacroToggleDraw(wParam, info, msg, hwnd) {
    if hwnd != MainGui.Hwnd || !info || NumGet(info, A_PtrSize * 2, "Int") != -12
        return
    ctrl := GuiCtrlFromHwnd(NumGet(info, 0, "Ptr"))
    if !ctrl || !(ctrl.Type ~= "^(Checkbox|Radio)$")
        return
    if NumGet(info, A_PtrSize * 3, "UInt") != 1
        return
    dc := NumGet(info, A_PtrSize * 4, "Ptr")
    rect := Buffer(16, 0)
    DllCall("GetClientRect", "Ptr", ctrl.Hwnd, "Ptr", rect)
    w := NumGet(rect, 8, "Int"), h := NumGet(rect, 12, "Int")
    graphics := Gdip_GraphicsFromHDC(dc)
    if !graphics
        return
    Gdip_SetSmoothingMode(graphics, 4)
    background := Gdip_BrushCreateSolid(MacroFarmInput["xp"][5].Hwnd = ctrl.Hwnd ? 0xFF1C1823 : 0xFF18151D)
    track := Gdip_BrushCreateSolid(ctrl.Value ? 0xFFA88DDE : 0xFF453A50)
    knob := Gdip_BrushCreateSolid(0xFFF2F6FF)
    size := Max(10, Min(h - 4, 14)), y := (h - size) / 2
    Gdip_FillRectangle(graphics, background, 0, 0, w, h)
    Gdip_FillRoundedRectangle(graphics, track, 1, y, size + 8, size, size / 2)
    Gdip_FillEllipse(graphics, knob, ctrl.Value ? 11 : 3, y + 2, size - 4, size - 4)
    Gdip_TextToGraphics(graphics, ctrl.Text, "x" (size + 12) " y0 w" Max(1, w-size-12) " h" h " vCenter cFFE7EDF8 s" Round(h * 0.60), "Segoe UI")
    if DllCall("GetFocus", "Ptr") = ctrl.Hwnd
        DllCall("DrawFocusRect", "Ptr", dc, "Ptr", rect)
    for brush in [background, track, knob]
        Gdip_DeleteBrush(brush)
    Gdip_DeleteGraphics(graphics)
    return 4
}

MacroBuildPages(gui) {
    global MacroSettingsNav := [], MacroFarm := [], MacroRunSummary, MacroAbout
    gui.SetFont("s9 cD9D0EB", "Segoe UI")
    selector := gui.Add("DropDownList", "Hidden x485 y70 w185 Choose1", ["Gameplay", "Party", "Discord"])
    selector.OnEvent("Change", (ctrl, *) => MacroNavigate("Tab5", ctrl.Text))
    MacroSettingsNav.Push(selector)
    MacroBuildFarming(gui)
    MacroRunSummary := gui.Add("Text", "Hidden x30 y478 w640 h19 c92BDF1", "")
    MacroAbout := gui.Add("Text", "Hidden x30 y500 w140 h34 Center 0x200 Background24364C cE7EDF8", "About")
    MacroAbout.OnEvent("Click", (button, *) => MacroNavigate("Tab6", button.Text = "About" ? "About" : ""))
    MacroRound(MacroAbout, 12)
}

MacroRefreshFarm() {
    global MacroFarm, MacroRunSummary, SettingsFile, MacroFarmStatus
    if !IsSet(MacroFarmStatus)
        return
    name := IniRead(SettingsFile, "Loadouts", "Selected", "")
    goal := BatchGoalStatus()
    MacroFarmStatus["Auto Equip Loadout"].Text := name = "" ? "No default preset selected." : "Selected: " name
    MacroFarmStatus["Goals"].Text := goal
    MacroFarmStatus["Tower XP"].Text := BatchXPCommand("status", "", "!")
    MacroRunSummary.Text := goal "  |  Loadout: " (name = "" ? "Off" : name)
}

MacroBuildFarming(gui) {
    global MacroFarm, MacroFarmPanels := Map(), MacroFarmStatus := Map()
    global MacroFarmPicker, MacroFarmSearch, MacroFarmList, MacroFarmPaths := []
    global MacroFarmInput := Map()
    gui.SetFont("s10 cE5DEF0", "Segoe UI")
    side := gui.Add("Text", "Hidden x12 y84 w181 h454 Background19161F", "")
    MacroRound(side, 14)
    MacroFarm.Push(side)
    MacroFarm.Push(gui.Add("Text", "Hidden x25 y96 w150 h20 Background19161F", "Strategies"))
    MacroFarmSearch := gui.Add("Edit", "Hidden x25 y123 w154 h28", "")
    DllCall("SendMessageW", "Ptr", MacroFarmSearch.Hwnd, "UInt", 0x1501, "Ptr", 1, "WStr", "Search strategies")
    MacroFarmSearch.OnEvent("Change", MacroFilterStrategies)
    MacroFarm.Push(MacroFarmSearch)
    MacroFarmList := gui.Add("ListBox", "Hidden x25 y161 w154 h340", [])
    MacroFarmList.OnEvent("DoubleClick", MacroSelectFarmStrategy)
    MacroFarm.Push(MacroFarmList)
    MacroFarm.Push(gui.Add("Text", "Hidden x25 y510 w156 h17 cA398B3 Background19161F", "Double-click to select"))
    gui.SetFont("s15 Bold cF2EAF9", "Segoe UI")
    MacroFarm.Push(gui.Add("Text", "Hidden x214 y84 w170 h34", "Farming"))
    gui.SetFont("s10 Norm cE5DEF0", "Segoe UI")
    sections := ["Goals", "Tower XP", "Auto Equip Loadout"]
    MacroFarmPicker := gui.Add("DropDownList", "Hidden x475 y88 w195 Choose1", sections)
    MacroFarmPicker.OnEvent("Change", MacroShowFarmPanel)
    MacroFarm.Push(MacroFarmPicker)
    for section in sections {
        card := gui.Add("Text", "Hidden x210 y132 w460 h346 Background1C1823", "")
        MacroRound(card, 16)
        header := gui.Add("Text", "Hidden x228 y150 w420 h23 Background1C1823 cF2EAF9", section)
        MacroFarmPanels[section] := [card, header]
    }
    g := MacroFarmPanels["Goals"]
    g.Push(gui.Add("Text", "Hidden x228 y185 w416 h41 Background1C1823 cC4B7D1", "Count Coins or Gems earned this run. The macro stops after the match that reaches the target."))
    g.Push(gui.Add("Text", "Hidden x228 y237 w100 h19 Background1C1823", "Target amount"))
    amount := gui.Add("Edit", "Hidden Number x228 y261 w180 h31 Limit10")
    currency := gui.Add("DropDownList", "Hidden x420 y261 w142 Choose1", ["Coins", "Gems"])
    g.Push(amount, currency)
    MacroFarmInput["goal"] := [amount, currency]
    xp := MacroFarmPanels["Tower XP"]
    xp.Push(gui.Add("Text", "Hidden x228 y185 w416 h43 Background1C1823 cC4B7D1", "Use one Abstract slot in the strategy and turn off rotation. Set your current level and XP before farming."))
    names := []
    for tower in TowerXPDefinitions()
        names.Push(tower.name)
    tower := gui.Add("DropDownList", "Hidden x228 y234 w278 Choose1", names)
    tower.OnEvent("Change", MacroLoadTowerFields)
    xp.Push(tower)
    for index, label in ["Current level", "Current XP", "Target level"]
        xp.Push(gui.Add("Text", "Hidden x" (228+(index-1)*119) " y270 w110 h19 Background1C1823", label))
    level := gui.Add("Edit", "Hidden Number x228 y294 w108 h28 Limit2")
    progress := gui.Add("Edit", "Hidden Number x347 y294 w108 h28 Limit5")
    target := gui.Add("Edit", "Hidden Number x466 y294 w108 h28 Limit2")
    enabled := gui.Add("Checkbox", "Hidden x228 y334 w230 h23", "Enable Tower XP farming")
    xp.Push(level, progress, target, enabled)
    MacroFarmInput["xp"] := [tower, level, progress, target, enabled]
    lo := MacroFarmPanels["Auto Equip Loadout"]
    lo.Push(gui.Add("Text", "Hidden x228 y185 w416 h42 Background1C1823 cC4B7D1", "Enter the exact saved Roblox loadout name. A preset specified by the strategy takes priority."))
    lo.Push(gui.Add("Text", "Hidden x228 y237 w130 h18 Background1C1823", "Loadout name"))
    preset := gui.Add("Edit", "Hidden x228 y261 w412 h31 Limit80")
    lo.Push(preset)
    MacroFarmInput["loadout"] := preset
    for section in sections {
        status := gui.Add("Text", "Hidden x228 y369 w420 h34 Background1C1823 cC3AEF3", "")
        save := gui.Add("Text", "Hidden x228 y417 w121 h32 Center 0x200 BackgroundB9A4ED c1A1421", "Save")
        save.OnEvent("Click", MacroSaveFarming.Bind(section, false))
        MacroRound(save, 12)
        MacroFarmPanels[section].Push(status, save)
        MacroFarmStatus[section] := status
        if section != "Tower XP" {
            clear := gui.Add("Text", "Hidden x360 y417 w121 h32 Center 0x200 Background31273D cE7DDF5", "Clear")
            clear.OnEvent("Click", MacroSaveFarming.Bind(section, true))
            MacroRound(clear, 12)
            MacroFarmPanels[section].Push(clear)
        }
    }
}

MacroFilterStrategies(*) {
    global MacroFarmSearch, MacroFarmList, MacroFarmPaths
    query := Trim(MacroFarmSearch.Value), names := []
    MacroFarmPaths := []
    for name, path in BatchStrategies() {
        if path = "" || (query != "" && !InStr(name, query))
            continue
        names.Push(RegExReplace(name, "i)\.strat$"))
        MacroFarmPaths.Push(name)
    }
    MacroFarmList.Delete()
    if names.Length
        MacroFarmList.Add(names)
}

MacroSelectFarmStrategy(*) {
    global MacroFarmList, MacroFarmPaths, RunningStrategy, Recording, MacroRecording
    index := MacroFarmList.Value
    if index && !RunningStrategy && !Recording && !MacroRecording && BatchSelectStrategy(MacroFarmPaths[index])
        MacroNavigate("Tab1")
}

MacroShowFarmPanel(*) {
    global MacroFarmPanels, MacroFarmPicker, MacroFarmInput, SettingsFile, StateFile
    for section, controls in MacroFarmPanels {
        for ctrl in controls
            ctrl.Visible := section = MacroFarmPicker.Text
    }
    goal := BatchGoal(SettingsFile, StateFile)
    MacroFarmInput["goal"][1].Value := goal ? goal.target : ""
    MacroFarmInput["goal"][2].Choose(goal && goal.currency = "Gems" ? 2 : 1)
    MacroFarmInput["loadout"].Value := IniRead(SettingsFile, "Loadouts", "Selected", "")
    definition := BatchXPSelection(SettingsFile)
    if definition
        MacroFarmInput["xp"][1].Choose(definition.name)
    MacroLoadTowerFields()
    MacroRefreshFarm()
}

MacroLoadTowerFields(*) {
    global MacroFarmInput, SettingsFile
    fields := MacroFarmInput["xp"], definition := TowerXPDefinitions()[fields[1].Value]
    saved := TowerXPSavedProgress(SettingsFile, definition)
    fields[2].Value := saved.level
    fields[3].Value := saved.xp
    fields[4].Value := IniRead(SettingsFile, TowerXPSectionName(definition.name), "Target", 20)
    fields[5].Value := IniRead(SettingsFile, "TowerXP", "Enabled", 0) = 1
}

MacroSaveFarming(section, clear, *) {
    global MacroFarmInput, SettingsFile, RunningStrategy, RotateStrategies
    switch section {
        case "Goals":
            fields := MacroFarmInput["goal"]
            reply := BatchDispatch(clear ? "goal clear" : "goal set " fields[2].Text " " fields[1].Value, "", "!")
        case "Auto Equip Loadout":
            reply := BatchDispatch("loadout select " (clear ? "off" : Trim(MacroFarmInput["loadout"].Value)), "", "!")
        case "Tower XP":
            fields := MacroFarmInput["xp"]
            definition := TowerXPDefinitions()[fields[1].Value]
            level := fields[2].Value, xp := fields[3].Value, target := fields[4].Value
            if RunningStrategy || (fields[5].Value && RotateStrategies) {
                MsgBox("Stop the macro and turn off rotation before enabling Tower XP.")
                return
            }
            if !IsInteger(level) || !IsInteger(xp) || !IsInteger(target) || level < 0
                || level > definition.maxLevel || target < 1 || target > definition.maxLevel
                || xp < 0 || xp >= Max(1, TowerXPNextRequired(definition, level)) {
                MsgBox("Enter a valid level, XP within that level, and target.")
                return
            }
            key := TowerXPSectionName(definition.name)
            saved := TowerXPSavedProgress(SettingsFile, definition)
            IniWrite(level "," xp "," saved.matchId, SettingsFile, key, "Progress")
            IniWrite(target, SettingsFile, key, "Target")
            IniWrite(definition.name, SettingsFile, "TowerXP", "Selected")
            IniWrite(fields[5].Value, SettingsFile, "TowerXP", "Enabled")
    }
    if IsSet(reply) && (reply ~= "^(Use |Enter )") {
        MsgBox(reply)
        return
    }
    MacroShowFarmPanel()
}
MacroNavigate(tab, section := "") {
    global CurrentTab, TabCtrl, TabLine, MacroTabPages, MacroSettingsNav, MacroFarm, MacroRunSummary, MacroAbout
    HideAllTabContent()
    CurrentTab := tab
    for index, ctrl in TabCtrl {
        active := MacroTabPages[index] = tab
        ctrl.SetFont(active ? "cE7EDF8" : "c8F9FB5")
        if active
            TabLine.Move(20 + (index-1)*89)
    }
    if tab = "Farming" {
        for ctrl in MacroFarm
            ctrl.Visible := true
        MacroFilterStrategies()
        MacroShowFarmPanel()
    } else if tab = "Tab5" {
        page := section = "Party" ? "Tab3" : section = "Discord" ? "Tab4" : "Tab5"
        ShowTabContent(page)
        MacroShowSettingsNav(section)
    } else if tab = "Tab6" && section = "About" {
        ShowTabContent("Tab7")
        MacroAbout.Visible := true
        MacroAbout.Text := "Back to tools"

    } else {
        ShowTabContent(tab)
        MacroRunSummary.Visible := tab = "Tab1"
        MacroAbout.Visible := tab = "Tab6"
        MacroAbout.Text := "About"
    }
    MacroRefreshFarm()
}


MacroShowSettingsNav(section := "") {
    for ctrl in MacroSettingsNav {
        ctrl.Visible := true
        ctrl.Choose(section = "" ? "Gameplay" : section)
    }
}

MacroScrollBy(delta) {
    global ContentH, FrameH, CurrentScrollPos, ChildGui
    global MacroScrollTarget
    if !IsSet(MacroScrollTarget)
        MacroScrollTarget := CurrentScrollPos
    MacroScrollTarget := Max(0, Min(MacroScrollTarget + delta, ContentH - FrameH))
    SetTimer(MacroScrollTick, 15)
}

MacroScrollTick() {
    global MacroScrollTarget, CurrentScrollPos, ChildGui, ContentH, FrameH, SliderH, Slider
    distance := MacroScrollTarget - CurrentScrollPos
    if !distance || !WinExist("ahk_id " ChildGui.Hwnd) {
        SetTimer(MacroScrollTick, 0)
        return
    }
    move := (distance > 0 ? 1 : -1) * Max(1, Ceil(Abs(distance) * 0.27))
    DllCall("ScrollWindow", "Ptr", ChildGui.Hwnd, "Int", 0, "Int", -move, "Ptr", 0, "Ptr", 0)
    CurrentScrollPos += move
    if ContentH > FrameH
        Slider.Move(, Round(CurrentScrollPos / (ContentH - FrameH) * (FrameH - SliderH)))
    DllCall("UpdateWindow", "Ptr", ChildGui.Hwnd)
}



