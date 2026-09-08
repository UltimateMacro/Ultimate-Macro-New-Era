#Requires AutoHotkey v2.0

global ToolWindowGui := 0
global ToolWindowCloseCtrl := 0
global ToolWindowStatusCtrl := 0
global ToolWindowOwnerHwnd := 0

ToolWindowUxProc(ordinal) {
    static handle := 0
    if (!handle)
        handle := DllCall("kernel32\GetModuleHandleW", "Str", "uxtheme", "Ptr")
    if (!handle)
        handle := DllCall("kernel32\LoadLibraryW", "Str", "uxtheme.dll", "Ptr")
    if (!handle)
        return 0
    return DllCall("kernel32\GetProcAddress", "Ptr", handle, "Ptr", ordinal, "Ptr")
}

ToolWindowEnableDarkMode() {
    static applied := false
    if (applied)
        return
    applied := true
    proc := ToolWindowUxProc(135)
    if (proc)
        try DllCall(proc, "Int", 2, "Int")
}

ToolWindowDarkFrame(hwnd, keepScrollbarTheme := false) {
    if (!hwnd)
        return
    ToolWindowEnableDarkMode()
    proc := ToolWindowUxProc(133)
    if (proc)
        try DllCall(proc, "Ptr", hwnd, "Int", 1, "Int")
    theme := keepScrollbarTheme ? "DarkMode_Explorer" : "DarkMode_CFD"
    try DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", theme, "Ptr", 0)
}

ApplyToolWindowInputTheme(guiObj) {
    for hwnd, ctrl in guiObj {
        try {
            switch ctrl.Type {
                case "Edit":
                    try ctrl.Opt("Background181818")
                    try ctrl.SetFont("cE2E4E7")
                    ToolWindowDarkFrame(ctrl.Hwnd, false)
                case "ListBox":
                    try ctrl.Opt("Background181818")
                    try ctrl.SetFont("cE2E4E7")
                    ToolWindowDarkFrame(ctrl.Hwnd, true)
                case "ComboBox", "DDL":
                    try ctrl.Opt("Background181818")
                    try ctrl.SetFont("cE2E4E7")
                    ToolWindowDarkFrame(ctrl.Hwnd, false)
                case "CheckBox", "Radio":
                    ToolWindowDarkFrame(ctrl.Hwnd, true)
            }
        }
    }
}

NotifyToolWindowClosing() {
    global ToolWindowOwnerHwnd
    static WM_APP_TOOL_CLOSED := 0x8001

    if (!ToolWindowOwnerHwnd)
        return
    try DllCall("user32\PostMessageW", "Ptr", ToolWindowOwnerHwnd, "UInt", WM_APP_TOOL_CLOSED,
        "Ptr", DllCall("GetCurrentProcessId"), "Ptr", 0)
}

CloseToolWindow(*) {
    NotifyToolWindowClosing()
    ExitApp()
}

ToolWindowFont() {
    return "Segoe UI"
}

CreateToolWindow(title, width) {
    global ToolWindowGui, ToolWindowCloseCtrl

    g := Gui("-Caption +Border +ToolWindow +AlwaysOnTop +LastFound")
    g.BackColor := "121212"
    g.MarginX := 0
    g.MarginY := 0

    g.Add("Progress", "x0 y0 w" width " h34 Disabled Background0A0A0A", 0)

    g.SetFont("s9 w400 cFFFFFF", ToolWindowFont())
    titleCtrl := g.Add("Text", "x12 y6 w" (width - 60) " h22 0x200 BackgroundTrans", title)
    titleCtrl.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , g))

    g.SetFont("s10 w400 cFFFFFF", "Marlett")
    ToolWindowCloseCtrl := g.Add("Text", "x" (width - 36) " y6 w30 h22 Center 0x200 BackgroundTrans", "r")
    ToolWindowCloseCtrl.OnEvent("Click", CloseToolWindow)

    g.Add("Progress", "x0 y34 w" width " h1 Disabled Background222222", 0)

    g.SetFont("s9 w400 cFFFFFF", ToolWindowFont())
    ToolWindowGui := g

    SetTimer(ToolWindowHoverWatch, 60)
    return g
}

ShowToolWindow(g, width, height) {
    global ToolWindowOwnerHwnd

    ApplyToolWindowInputTheme(g)

    if (A_Args.Length >= 3 && IsNumber(A_Args[3]))
        ToolWindowOwnerHwnd := Integer(A_Args[3])

    if (A_Args.Length >= 2 && IsNumber(A_Args[1]) && IsNumber(A_Args[2])) {
        x := Integer(A_Args[1])
        y := Integer(A_Args[2])
        x := Max(0, Min(x, A_ScreenWidth - width))
        y := Max(0, Min(y, A_ScreenHeight - height))
        g.Show("x" x " y" y " w" width " h" height)
        return
    }
    g.Show("w" width " h" height)
}

AddToolWindowButton(g, x, y, w, h, label, handler) {
    g.SetFont("s9 w400 cFFFFFF", ToolWindowFont())
    btn := g.Add("Text", "x" x " y" y " w" w " h" h " Center 0x200 +Border Background1B1B1B", label)
    btn.OnEvent("Click", handler)
    return btn
}

AddToolWindowStatus(g, x, y, w) {
    global ToolWindowStatusCtrl
    g.SetFont("s8 w400 c7E848E", ToolWindowFont())
    ToolWindowStatusCtrl := g.Add("Text", "x" x " y" y " w" w " h20 0x200 BackgroundTrans", "Idle")
    g.SetFont("s9 w400 cFFFFFF", ToolWindowFont())
    return ToolWindowStatusCtrl
}

SetToolWindowStatus(text, isError := false) {
    global ToolWindowStatusCtrl
    if (!ToolWindowStatusCtrl)
        return
    ToolWindowStatusCtrl.SetFont(isError ? "cFF6B6B" : "c7E848E")
    ToolWindowStatusCtrl.Text := text
}

ToolWindowHoverWatch() {
    global ToolWindowGui, ToolWindowCloseCtrl
    static hovering := false

    if (!ToolWindowGui || !ToolWindowCloseCtrl)
        return

    MouseGetPos(, , &win, &ctrl, 2)
    isOver := (ctrl = ToolWindowCloseCtrl.Hwnd)
    if (isOver = hovering)
        return

    hovering := isOver
    ToolWindowCloseCtrl.SetFont(isOver ? "cFF4D4D" : "cFFFFFF")
    ToolWindowCloseCtrl.Redraw()
}
