AppearanceOpen(*) {
    global MainGui
    static panel := 0
    if panel {
        try {
            panel.Show()
            return
        }
    }
    panel := Gui("+Owner" MainGui.Hwnd " +ToolWindow", TranslateText("Appearance"))
    panel.MarginX := 16, panel.MarginY := 14
    AppearanceDarkCaption(panel)
    panel.BackColor := MacroAppearance.Color("background", "121212")
    panel.SetFont("s10 c" MacroAppearance.Color("text", "FFFFFF"), "Segoe UI")
    picker := panel.AddDropDownList("w458 +0x210", [])
    info := panel.AddText("w458 h18", "")
    preview := AppearanceDarkButton(panel, "xm w112 h30", TranslateText("Preview"))
    apply := AppearanceDarkButton(panel, "x+8 yp w112 h30", TranslateText("Apply"), true)
    manage := AppearanceDarkButton(panel, "x+8 yp w142 h30", TranslateText("Manage themes"))
    walls := panel.AddCheckbox("xm y+16", TranslateText("Use theme wallpapers"))
    words := panel.AddCheckbox("xm y+6", TranslateText("Use theme wording"))
    eggs := panel.AddCheckbox("xm y+6", TranslateText("Enable theme Easter eggs"))
    words.Value := IniRead(MacroAppearance.settings, "Appearance", "Wording", 1)
    walls.Value := IniRead(MacroAppearance.settings, "Appearance", "Wallpapers", 1)
    eggs.Value := MacroAppearance.eggsEnabled
    before := {id: MacroAppearance.id, theme: MacroAppearance.theme, root: MacroAppearance.customRoot,
        words: words.Value, walls: walls.Value, eggs: eggs.Value}
    view := {panel: panel, picker: picker, info: info, ids: [], words: words, walls: walls, eggs: eggs, before: before, previewed: false}
    picker.OnEvent("Change", (*) => AppearanceDescribe(view))
    walls.OnEvent("Click", (*) => AppearanceSavePreference(view, "Wallpapers", "walls", "wallpapersEnabled"))
    words.OnEvent("Click", (*) => AppearanceSavePreference(view, "Wording", "words", "wordingEnabled"))
    eggs.OnEvent("Click", (*) => AppearanceSavePreference(view, "EasterEggs", "eggs", "eggsEnabled"))
    preview.OnEvent("Click", (*) => AppearanceChoose(view, false))
    apply.OnEvent("Click", (*) => AppearanceChoose(view, true))
    manage.OnEvent("Click", (*) => AppearanceManage(view))
    panel.OnEvent("Close", (*) => AppearanceClose(view))
    panel.OnEvent("Escape", (*) => AppearanceClose(view))
    AppearanceRefresh(view, MacroAppearance.id)
    ApplyMacroDarkControls(panel)
    panel.Show()
}

AppearanceSavePreference(view, key, field, property) {
    ctrl := view.%field%
    try {
        IniWrite(ctrl.Value, MacroAppearance.settings, "Appearance", key)
        view.before.%field% := ctrl.Value
        MacroAppearance.%property% := ctrl.Value
        MacroAppearance.Wording()
        MacroAppearance.QueuePaint()
        if property = "eggsEnabled"
            MacroAppearance.ScheduleEasterEgg()
    } catch {
        ctrl.Value := view.before.%field%
        view.info.Text := TranslateText("Couldn't save settings.")
    }
}

AppearanceManage(view) {
    id := view.ids[view.picker.Value]
    actions := Menu()
    if id != "default" && id != "violet"
        actions.Add(TranslateText("Edit JSON"), (*) => AppearanceEdit(view, false))
    actions.Add(TranslateText(id = "default" ? "Create theme" : "Duplicate theme"), (*) => AppearanceEdit(view, true))
    actions.Add(TranslateText("Import theme"), (*) => AppearanceTransfer(view, "import"))
    if id != "default"
        actions.Add(TranslateText("Export theme"), (*) => AppearanceTransfer(view, "export"))
    if id != "default" && id != "violet"
        actions.Add(TranslateText("Remove theme"), (*) => AppearanceRemove(view))
    actions.Add()
    actions.Add(TranslateText("Open themes folder"), (*) => AppearanceOpenFolder())
    actions.Show()
}

AppearanceDarkCaption(gui) {
    flag := Buffer(4, 0)
    NumPut("Int", 1, flag)
    try {
        if DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", gui.Hwnd, "UInt", 20, "Ptr", flag, "UInt", 4)
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", gui.Hwnd, "UInt", 19, "Ptr", flag, "UInt", 4)
    }
}

AppearanceDarkButton(gui, options, label, primary := false) {
    static paint := CallbackCreate(AppearanceButtonProc, , 6)
    ctrl := gui.AddButton(options, label)
    DllCall("comctl32\SetWindowSubclass", "Ptr", ctrl.Hwnd, "Ptr", paint, "UPtr", 3, "UPtr", primary, "Int")
    return ctrl
}

AppearanceButtonProc(hwnd, msg, wp, lp, id, primary) {
    if msg = 0x14 && !MacroClosing
        return 1
    if msg = 0xF && !MacroClosing {
        paint := Buffer(A_PtrSize = 8 ? 72 : 64, 0)
        dc := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", paint, "Ptr")
        try AppearanceDrawButton(hwnd, dc, primary)
        finally DllCall("EndPaint", "Ptr", hwnd, "Ptr", paint)
        return 0
    }
    result := DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wp, "Ptr", lp, "Ptr")
    if !MacroClosing && (msg = 0xF3 || msg = 0x7 || msg = 0x8 || msg = 0xA)
        DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 0)
    return result
}

AppearanceDrawButton(hwnd, dc, primary) {
    rect := Buffer(16)
    DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rect)
    state := DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0xF2, "Ptr", 0, "Ptr", 0, "Ptr")
    pressed := state & 4
    disabled := !DllCall("IsWindowEnabled", "Ptr", hwnd)
    role := pressed ? "hover" : primary ? "selected" : "button"
    fill := pressed ? "303030" : primary ? "24415D" : "202020"
    tab := primary >= 2
    selected := tab && ((primary = 3) = DiscordBotSettingsOpen)
    height := NumGet(rect, 12, "Int"), width := NumGet(rect, 8, "Int")
    DllCall("FillRect", "Ptr", dc, "Ptr", rect, "Ptr", MacroAppearance.Brush("background", "121212"))
    if !tab || selected {
        diameter := tab ? height : Round(12 * A_ScreenDPI / 96)
        region := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", width, "Int", height, "Int", diameter, "Int", diameter, "Ptr")
        try {
            DllCall("FillRgn", "Ptr", dc, "Ptr", region, "Ptr", MacroAppearance.Brush(tab ? "selected" : role, tab ? "303030" : fill))
            if !tab
                DllCall("FrameRgn", "Ptr", dc, "Ptr", region, "Ptr", MacroAppearance.Brush("border", "555555"), "Int", 1, "Int", 1)
        } finally DeleteObject(region)
    }
    disabled := disabled || (tab && !selected)
    prevMode := DllCall("SetBkMode", "Ptr", dc, "Int", 1)
    prevColor := DllCall("SetTextColor", "Ptr", dc, "UInt", MacroAppearance.ColorRef(disabled ? "muted" : "text", disabled ? "909090" : "FFFFFF"), "UInt")
    font := DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
    oldFont := font ? DllCall("SelectObject", "Ptr", dc, "Ptr", font, "Ptr") : 0
    caption := Buffer(512, 0)
    DllCall("GetWindowTextW", "Ptr", hwnd, "Ptr", caption, "Int", 256)
    DllCall("DrawTextW", "Ptr", dc, "Ptr", caption, "Int", -1, "Ptr", rect, "UInt", 0x8825)
    if oldFont
        DllCall("SelectObject", "Ptr", dc, "Ptr", oldFont)
    DllCall("SetTextColor", "Ptr", dc, "UInt", prevColor)
    DllCall("SetBkMode", "Ptr", dc, "Int", prevMode)
    if DllCall("GetFocus", "Ptr") = hwnd {
        focus := Buffer(16)
        DllCall("RtlMoveMemory", "Ptr", focus, "Ptr", rect, "UPtr", 16)
        DllCall("InflateRect", "Ptr", focus, "Int", -3, "Int", -3)
        DllCall("DrawFocusRect", "Ptr", dc, "Ptr", focus)
    }
    return true
}

AppearanceRoot() {
    root := MacroAppearance.root "\Themes"
    DirCreate(root)
    for directory in [MacroAppearance.root, root] {
        if InStr(FileGetAttrib(directory), "L")
            throw Error("Linked theme storage is unsupported.")
    }
    return root
}

AppearanceOpenFolder() {
    try Run('explorer.exe "' AppearanceRoot() '"')
    catch as err
        MsgBox(TranslateText(err.Message), TranslateText("Appearance"))
}

AppearanceRefresh(view, selected := "default") {
    view.ids := ["default"]
    labels := [TranslateText("Default")]
    index := 1
    for themeDirectory in [A_ScriptDir "\Resources\Themes", AppearanceRoot()] {
        Loop Files, themeDirectory "\*", "D" {
            try {
                theme := MacroAppearance.Read(A_LoopFileFullPath)
                if theme["id"] != A_LoopFileName || InArray(view.ids, theme["id"])
                    continue
                view.ids.Push(theme["id"])
                labels.Push(theme["name"])
                if theme["id"] = selected
                    index := labels.Length
            }
        }
    }
    view.picker.Delete()
    view.picker.Add(labels)
    view.picker.Choose(index)
    AppearanceDescribe(view)
}

AppearanceDescribe(view) {
    id := view.ids[view.picker.Value]
    if id = "default" {
        view.info.Text := ""
        return
    }
    try {
        theme := MacroAppearance.Read(MacroAppearance.ThemeRoot(id))
        view.info.Text := theme.Get("author", "")
    } catch as err {
        view.info.Text := TranslateText(err.Message)
    }
}

AppearanceChoose(view, save) {
    id := view.ids[view.picker.Value]
    try {
        root := id = "default" ? "" : MacroAppearance.ThemeRoot(id)
        theme := root = "" ? Map() : MacroAppearance.Read(root)
        view.previewed := true
        MacroAppearance.wallpapersEnabled := view.walls.Value
        MacroAppearance.wordingEnabled := view.words.Value
        MacroAppearance.eggsEnabled := view.eggs.Value
        MacroAppearance.Apply(theme, root)
        AppearanceRefreshPanelColors(view.panel)
        ApplyMacroDarkControls(view.panel)
        if save {
            IniWrite(id, MacroAppearance.settings, "Appearance", "Theme")
            IniWrite(view.words.Value, MacroAppearance.settings, "Appearance", "Wording")
            IniWrite(view.walls.Value, MacroAppearance.settings, "Appearance", "Wallpapers")
            IniWrite(view.eggs.Value, MacroAppearance.settings, "Appearance", "EasterEggs")
            MacroAppearance.id := id
            view.before := {id: id, theme: theme, root: root, words: view.words.Value, walls: view.walls.Value, eggs: view.eggs.Value}
            view.previewed := false
        }
        view.info.Text := TranslateText(save ? "Applied" : "Previewing")
    } catch as err {
        AppearanceRestore(view)
        MsgBox(TranslateText(err.Message), TranslateText("Appearance"))
    }
}

AppearanceRestore(view) {
    was := view.before
    MacroAppearance.wallpapersEnabled := was.walls
    MacroAppearance.wordingEnabled := was.words
    MacroAppearance.eggsEnabled := was.eggs
    MacroAppearance.Apply(was.theme, was.root)
    AppearanceRefreshPanelColors(view.panel)
    view.previewed := false
}

AppearanceRefreshPanelColors(panel) {
    panel.BackColor := MacroAppearance.Color("background", "121212")
    for ctrl in panel {
        if ctrl.Type = "Text" || ctrl.Type = "CheckBox"
            ctrl.SetFont("c" MacroAppearance.Color("text", "FFFFFF"))
    }
    DllCall("RedrawWindow", "Ptr", panel.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x185)
}

AppearanceClose(view) {
    view.panel.Hide()
    if view.previewed
        try AppearanceRestore(view)
    view.words.Value := view.before.words
    view.walls.Value := view.before.walls
    view.eggs.Value := view.before.eggs
    for index, id in view.ids {
        if id = view.before.id {
            view.picker.Choose(index)
            break
        }
    }
    AppearanceDescribe(view)
}

AppearanceTransfer(view, action) {
    id := view.ids[view.picker.Value]
    if action = "export" && id = "default"
        return
    try {
        if action = "import" {
            source := DirSelect(, 0, TranslateText("Select a folder containing theme.json"))
            if source = ""
                return
            theme := MacroAppearance.Read(source)
            destination := AppearanceRoot() "\" theme["id"]
        } else {
            source := MacroAppearance.ThemeRoot(id)
            theme := MacroAppearance.Read(source)
            target := DirSelect(, 0, TranslateText("Select an export destination"))
            if target = ""
                return
            destination := target "\" id
        }
        AppearanceCopy(theme, source, destination)
        AppearanceRefresh(view, action = "import" ? theme["id"] : id)
    } catch as err {
        MsgBox(TranslateText(err.Message), TranslateText("Appearance"))
    }
}

AppearanceCopy(theme, source, destination) {
    if FileExist(destination)
        throw Error("A theme folder with that ID already exists.")
    if theme["id"] = "violet" && InStr(destination, AppearanceRoot() "\") = 1
        throw Error("That ID is reserved for a bundled theme.")
    DirCreate(destination)
    ; Copy only referenced, validated images. No archive extraction or executable files.
    for _, config in theme.Get("wallpapers", Map()) {
        asset := MacroAppearance.ValidateWallpaper(config, source)
        DirCreate(destination "\Assets")
        FileCopy(asset, destination "\Assets\" config["asset"], 1)
    }
    AppearanceWrite(theme, destination)
}

AppearanceWrite(theme, root) {
    path := root "\theme.json"
    tmp := root "\theme.pending-" DllCall("GetCurrentProcessId", "UInt") "-" A_TickCount
    handle := FileOpen(tmp, "w", "UTF-8-RAW")
    try handle.Write(JSON.Stringify(theme))
    finally handle.Close()
    FileMove(tmp, path, 1)
}

AppearanceRemove(view) {
    id := view.ids[view.picker.Value]
    if id = "default" || id = "violet"
        return
    try {
        if MsgBox(TranslateText("Move this custom theme and its assets to the Recycle Bin?"), TranslateText("Remove theme"), "YesNo") != "Yes"
            return
        destination := AppearanceRoot() "\" id
        if InStr(FileGetAttrib(destination), "L")
            throw Error("Linked theme folders are unsupported.")
        FileRecycle(destination)
        if view.before.id = id {
            AppearanceRefresh(view, "default")
            AppearanceChoose(view, true)
        } else if view.previewed {
            AppearanceRestore(view)
        }
        AppearanceRefresh(view, view.before.id)
    } catch as err {
        MsgBox(TranslateText(err.Message), TranslateText("Appearance"))
    }
}

AppearanceEdit(view, duplicate) {
    id := view.ids[view.picker.Value]
    if (id = "default" || id = "violet") && !duplicate
        return
    try {
        source := id = "default" ? "" : MacroAppearance.ThemeRoot(id)
        theme := source = "" ? Map("schemaVersion", 1, "id", "my-theme", "name", "My theme", "author", "", "colors", Map()) : MacroAppearance.Read(source)
        if duplicate && id != "default" {
            theme["id"] := SubStr(id, 1, 35) "-copy"
            theme["name"] := SubStr(theme["name"], 1, 73) " (copy)"
        }
        editor := Gui("+Owner" view.panel.Hwnd, TranslateText("Theme editor"))
        editor.MarginX := 14, editor.MarginY := 12
        AppearanceDarkCaption(editor)
        editor.BackColor := MacroAppearance.Color("background", "121212")
        editor.SetFont("s10 c" MacroAppearance.Color("text", "FFFFFF"), "Segoe UI")
        editor.AddText("w550", TranslateText("Edit the theme JSON. For wallpapers, put image files in the theme's Assets folder."))
        json := editor.AddEdit("w550 r17 WantTab", JSON.Stringify(theme))
        preview := AppearanceDarkButton(editor, "w112 h30", TranslateText("Preview"))
        save := AppearanceDarkButton(editor, "x+8 yp w112 h30", TranslateText("Save"), true)
        cancel := AppearanceDarkButton(editor, "x+8 yp w112 h30", TranslateText("Cancel"))
        preview.OnEvent("Click", (*) => AppearanceEditorAction(view, editor, json.Value, source, id, duplicate, false))
        save.OnEvent("Click", (*) => AppearanceEditorAction(view, editor, json.Value, source, id, duplicate, true))
        cancel.OnEvent("Click", (*) => AppearanceEditorClose(view, editor))
        editor.OnEvent("Close", (*) => AppearanceEditorClose(view, editor))
        editor.OnEvent("Escape", (*) => AppearanceEditorClose(view, editor))
        ApplyMacroDarkControls(editor)
        editor.Show()
    } catch as err {
        MsgBox(TranslateText(err.Message), TranslateText("Appearance"))
    }
}

AppearanceEditorClose(view, editor) {
    if view.previewed
        AppearanceRestore(view)
    editor.Destroy()
}

AppearanceEditorAction(view, editor, text, source, originalId, duplicate, save) {
    try {
        if StrLen(text) > 16000
            throw Error("The theme file is too large.")
        theme := MacroAppearance.Validate(JSON.Parse(text), source)
        if !save {
            view.previewed := true
            MacroAppearance.Apply(theme, source)
            return
        }
        if duplicate {
            destination := AppearanceRoot() "\" theme["id"]
            AppearanceCopy(theme, source, destination)
        } else {
            if originalId != theme["id"]
                throw Error("Duplicate the theme to give it a new ID.")
            AppearanceWrite(theme, source)
        }
        AppearanceEditorClose(view, editor)
        AppearanceRefresh(view, theme["id"])
    } catch as err {
        MsgBox(TranslateText(err.Message), TranslateText("Appearance"))
    }
}
