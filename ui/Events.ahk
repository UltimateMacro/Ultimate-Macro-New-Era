; Window-message routing for painted surfaces and the frameless main window.

UI_Install() {
    OnMessage(0x000F, UI_Paint)
    OnMessage(0x0014, UI_EraseBkgnd)
    OnMessage(0x0200, UI_MouseMove)
    OnMessage(0x0201, UI_LButtonDown)
    OnMessage(0x0203, UI_LButtonDblClk)
    OnMessage(0x0202, UI_LButtonUp)
    OnMessage(0x020A, UI_MouseWheel)
    OnMessage(0x02A3, UI_MouseLeave)
    OnMessage(0x0020, UI_SetCursor)
    OnMessage(0x0100, UI_KeyDown)
    OnMessage(0x0104, UI_SysKeyDown)
    OnMessage(0x0102, UI_Char)
    OnMessage(0x0083, UI_NcCalcSize)
    OnMessage(0x0084, UI_NcHitTest)
    OnMessage(0x0024, UI_GetMinMaxInfo)
    OnMessage(0x0138, UI_CtlColorStatic)
    OnMessage(0x0133, UI_CtlColorStatic)
}

UI_Uninstall() {
    for binding in [[0x000F,UI_Paint], [0x0014,UI_EraseBkgnd], [0x0200,UI_MouseMove],
        [0x0201,UI_LButtonDown], [0x0203,UI_LButtonDblClk], [0x0202,UI_LButtonUp],
        [0x020A,UI_MouseWheel], [0x02A3,UI_MouseLeave], [0x0020,UI_SetCursor],
        [0x0100,UI_KeyDown], [0x0104,UI_SysKeyDown], [0x0102,UI_Char],
        [0x0083,UI_NcCalcSize], [0x0084,UI_NcHitTest], [0x0024,UI_GetMinMaxInfo],
        [0x0138,UI_CtlColorStatic], [0x0133,UI_CtlColorStatic]]
        OnMessage(binding[1], binding[2], 0)
}

UI_Logical(lParam, &x, &y) {
    x := ((lParam & 0xFFFF) << 48 >> 48) / Gfx.S
    y := ((lParam >> 16 & 0xFFFF) << 48 >> 48) / Gfx.S
}

UI_Paint(wParam, lParam, msg, hwnd) {
    if Surface.all.Has(hwnd) {
        Surface.all[hwnd].OnPaint()
        return 0
    }
}

UI_EraseBkgnd(wParam, lParam, msg, hwnd) {
    if Surface.all.Has(hwnd)
        return 1
}

UI_MouseMove(wParam, lParam, msg, hwnd) {
    if Surface.all.Has(hwnd) {
        UI_Logical(lParam, &x, &y)
        Surface.all[hwnd].OnMouseMove(x, y)
        return 0
    }
}

UI_MouseLeave(wParam, lParam, msg, hwnd) {
    if Surface.all.Has(hwnd) {
        Surface.all[hwnd].OnMouseLeave()
        return 0
    }
}

UI_LButtonDown(wParam, lParam, msg, hwnd) {
    if Surface.all.Has(hwnd) {
        UI_Logical(lParam, &x, &y)
        Surface.all[hwnd].OnButtonDown(x, y)
        return 0
    }
}

UI_LButtonDblClk(wParam, lParam, msg, hwnd) {
    if Surface.all.Has(hwnd) {
        UI_Logical(lParam, &x, &y)
        Surface.all[hwnd].OnButtonDown(x, y, true)
        return 0
    }
}

UI_LButtonUp(wParam, lParam, msg, hwnd) {
    if Surface.all.Has(hwnd) {
        UI_Logical(lParam, &x, &y)
        Surface.all[hwnd].OnButtonUp(x, y)
        return 0
    }
}

; Route the wheel to whatever surface is under the pointer, not the focused edit.
UI_MouseWheel(wParam, lParam, msg, hwnd) {
    sx := (lParam & 0xFFFF) << 48 >> 48, sy := (lParam >> 16 & 0xFFFF) << 48 >> 48
    target := DllCall("WindowFromPoint", "Int64", (sx & 0xFFFFFFFF) | (sy << 32), "Ptr")
    while (target && !Surface.all.Has(target))
        target := DllCall("GetParent", "Ptr", target, "Ptr")
    if !target
        return
    pt := Buffer(8, 0)
    NumPut("Int", sx, "Int", sy, pt)
    DllCall("ScreenToClient", "Ptr", target, "Ptr", pt)
    delta := (wParam >> 16 & 0xFFFF) << 48 >> 48
    Surface.all[target].OnWheel(NumGet(pt, 0, "Int") / Gfx.S, NumGet(pt, 4, "Int") / Gfx.S, delta)
    return 0
}

UI_SetCursor(wParam, lParam, msg, hwnd) {
    if !Surface.all.Has(hwnd) || (lParam & 0xFFFF) != 1
        return
    w := Surface.all[hwnd].hover
    id := 32512
    if IsObject(w) && w.IsEnabled() {
        switch w.cursor {
            case "hand": id := 32649
            case "ibeam": id := 32513
            case "size": id := 32642
        }
    }
    DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", id, "Ptr"))
    return 1
}

UI_KeyDown(wParam, lParam, msg, hwnd) {
    if (SelectPopup.gui && hwnd = SelectPopup.gui.Hwnd)
        return SelectPopup.Key(wParam) ? 0 : ""
    if (Dialog.gui && hwnd = Dialog.gui.Hwnd)
        return Dialog.Key(wParam) ? 0 : ""
    if (MW.gui && MW.KeyboardKey(wParam, hwnd))
        return 0
    ; Enter in a single-line field commits it (QLineEdit.editingFinished).
    if (wParam = 0x0D) {
        for h, s in Surface.all
            for n in s.natives
                if (n.ctrl && n.ctrl.Hwnd = hwnd && n.onCommit) {
                    n.onCommit.Call(n)
                    return 0
                }
    }
}

UI_SysKeyDown(wParam, lParam, msg, hwnd) {
    if (wParam = 40 && MW.gui && MW.KeyboardKey(wParam, hwnd))
        return 0
}

UI_Char(wParam, lParam, msg, hwnd) {
    if (SelectPopup.gui && hwnd = SelectPopup.gui.Hwnd) {
        SelectPopup.Char(Chr(wParam))
        return 0
    }
}

; Frameless main window: no non-client area, native drag/snap/resize zones.
UI_NcCalcSize(wParam, lParam, msg, hwnd) {
    if (MW.gui && hwnd = MW.gui.Hwnd && wParam)
        return 0
}

UI_NcHitTest(wParam, lParam, msg, hwnd) {
    if !MW.gui
        return
    sx := (lParam & 0xFFFF) << 48 >> 48, sy := (lParam >> 16 & 0xFFFF) << 48 >> 48
    if (hwnd != MW.gui.Hwnd) {
        ; Let the main window's right edge resize even over a page surface.
        if Surface.all.Has(hwnd) && WinGetMinMax(MW.gui) = 0 && MW.ResizeEditable() {
            WinGetPos(&wx, &wy, &ww, &wh, MW.gui)
            if (sx >= wx + ww - Round(6 * Gfx.S))
                return -1
        }
        return
    }
    WinGetPos(&wx, &wy, &ww, &wh, MW.gui)
    x := sx - wx, y := sy - wy, e := Round(6 * Gfx.S)
    if (WinGetMinMax(MW.gui) = 0 && MW.ResizeEditable()) {
        l := x < e, r := x >= ww - e, t := y < e, b := y >= wh - e
        if (t && l)
            return 13
        if (t && r)
            return 14
        if (b && l)
            return 16
        if (b && r)
            return 17
        if l
            return 10
        if r
            return 11
        if t
            return 12
        if b
            return 15
    }
    lx := x / Gfx.S, ly := y / Gfx.S
    if (ly < 46) {
        hit := MW.surface.HitTest(lx, ly)
        if !IsObject(hit)
            return 2
    }
    return 1
}

UI_GetMinMaxInfo(wParam, lParam, msg, hwnd) {
    if !(MW.gui && hwnd = MW.gui.Hwnd)
        return
    mon := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr")
    mi := Buffer(40, 0)
    NumPut("UInt", 40, mi)
    DllCall("GetMonitorInfo", "Ptr", mon, "Ptr", mi)
    ml := NumGet(mi, 4, "Int"), mt := NumGet(mi, 8, "Int")
    wl := NumGet(mi, 20, "Int"), wt := NumGet(mi, 24, "Int"), wr := NumGet(mi, 28, "Int"), wb := NumGet(mi, 32, "Int")
    NumPut("Int", wl - ml, "Int", wt - mt, lParam, 16)
    NumPut("Int", wr - wl, "Int", wb - wt, lParam, 8)
    NumPut("Int", Min(Round(480 * Gfx.S), wr - wl), "Int", Min(Round(320 * Gfx.S), wb - wt), lParam, 24)
    return 0
}

; Read-only/disabled edits paint through WM_CTLCOLORSTATIC; keep them dark.
UI_CtlColorStatic(wParam, lParam, msg, hwnd) {
    static brushes := Map()
    ToBgr(argb) => ((argb & 0xFF) << 16) | (argb & 0xFF00) | ((argb >> 16) & 0xFF)
    if (MW.HasOwnProp("outputEdit") && MW.outputEdit && lParam = MW.outputEdit.Hwnd) {
        bg := ToBgr(Theme.C("panel"))
        DllCall("SetTextColor", "Ptr", wParam, "UInt", ToBgr(Theme.C("muted")))
        DllCall("SetBkColor", "Ptr", wParam, "UInt", bg)
        if !brushes.Has(bg)
            brushes[bg] := DllCall("CreateSolidBrush", "UInt", bg, "Ptr")
        return brushes[bg]
    }
    for h, s in Surface.all
        for n in s.natives
            if (n.ctrl && n.ctrl.Hwnd = lParam) {
                col := Theme.C("field") & 0xFFFFFF
                bgr := ((col & 0xFF) << 16) | (col & 0xFF00) | ((col >> 16) & 0xFF)
                txt := (n.IsEnabled() ? Theme.C("text") : Theme.C("dimText")) & 0xFFFFFF
                DllCall("SetTextColor", "Ptr", wParam, "UInt", ((txt & 0xFF) << 16) | (txt & 0xFF00) | ((txt >> 16) & 0xFF))
                DllCall("SetBkColor", "Ptr", wParam, "UInt", bgr)
                if !brushes.Has(bgr)
                    brushes[bgr] := DllCall("CreateSolidBrush", "UInt", bgr, "Ptr")
                return brushes[bgr]
            }
}
