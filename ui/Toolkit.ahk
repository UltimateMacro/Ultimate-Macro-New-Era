; Ultimate Macro 1.4 (AutoHotkey edition) - retained-mode widget toolkit.
; Part of a modified version of "Ultimate Macro" by Darksen, licensed GNU GPLv3.
;
; A Surface owns one window, a back buffer and a tree of widgets painted with
; GDI+. Text entry uses real Edit controls placed over the painted fields, so
; IME, clipboard, caret and screen readers keep working.

class Surface {
    static all := Map()

    __New(gui, root, scrollable := false) {
        this.gui := gui, this.hwnd := gui.Hwnd, this.root := root, this.scrollable := scrollable
        this.scrollY := 0, this.contentH := 0, this.contentW := 0
        this.pw := 0, this.ph := 0, this.lw := 0, this.lh := 0
        this.dc := 0, this.hbm := 0, this.obm := 0, this.cw := 0, this.ch := 0
        this.hover := "", this.pressed := "", this.capture := "", this.focusWidget := ""
        this.natives := [], this.pending := false, this.layoutPending := false
        this.rendering := false, this.deferredSize := "", this.layouting := false
        this.background := "", this.overlay := "", this.originX := 0, this.originY := 0
        this.dragScroll := false, this.dragStart := 0, this.dragScroll0 := 0
        this.tipWidget := "", this.tipShown := false
        this.renderFn := ObjBindMethod(this, "DoRender")
        this.layoutFn := ObjBindMethod(this, "Relayout")
        this.tipFn := ObjBindMethod(this, "ShowTip")
        Surface.all[this.hwnd] := this
        root.Attach(this)
    }

    Destroy() {
        SetTimer(this.renderFn, 0)
        SetTimer(this.layoutFn, 0)
        SetTimer(this.tipFn, 0)
        this.pending := this.layoutPending := false
        if Surface.all.Has(this.hwnd)
            Surface.all.Delete(this.hwnd)
        this.FreeBuffer()
    }

    FreeBuffer() {
        if (this.dc) {
            DllCall("SelectObject", "Ptr", this.dc, "Ptr", this.obm)
            DllCall("DeleteObject", "Ptr", this.hbm)
            DllCall("DeleteDC", "Ptr", this.dc)
        }
        this.dc := 0, this.hbm := 0, this.obm := 0, this.cw := 0, this.ch := 0
    }

    Resize(pw, ph) {
        pw := Max(1, pw), ph := Max(1, ph)
        if this.rendering {
            this.deferredSize := [pw,ph]
            return
        }
        ; The back buffer keeps some slack so a live resize reuses it instead of
        ; reallocating a DIB section for every pixel the window edge moves.
        if (!this.dc || pw > this.cw || ph > this.ch || this.cw > pw + 512 || this.ch > ph + 512) {
            previous := A_IsCritical
            Critical("On")
            try {
                cw := Ceil(pw / 128) * 128, ch := Ceil(ph / 128) * 128
                ; Publish only a complete buffer; queued paints must never see a freed DC.
                bi := Buffer(40, 0)
                NumPut("UInt", 40, "Int", cw, "Int", -ch, "UShort", 1, "UShort", 32, bi)
                hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
                if !hdc
                    return
                dc := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
                bitmap := dc ? DllCall("CreateDIBSection", "Ptr", hdc, "Ptr", bi, "UInt", 0, "Ptr*", 0, "Ptr", 0, "UInt", 0, "Ptr") : 0
                DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
                old := bitmap ? DllCall("SelectObject", "Ptr", dc, "Ptr", bitmap, "Ptr") : 0
                if (!old || old = -1) {
                    if bitmap
                        DllCall("DeleteObject", "Ptr", bitmap)
                    if dc
                        DllCall("DeleteDC", "Ptr", dc)
                    return
                }
                this.FreeBuffer()
                this.dc := dc, this.hbm := bitmap, this.obm := old
                this.cw := cw, this.ch := ch
            } finally Critical(previous ? previous : "Off")
        }
        this.pw := pw, this.ph := ph
        this.lw := pw / Gfx.S, this.lh := ph / Gfx.S
        this.Relayout()
    }

    Invalidate() {
        if !this.pending {
            this.pending := true
            SetTimer(this.renderFn, -1)
        }
    }

    ; Paint now and put the frame on screen, instead of waiting for the queued
    ; render. Used when a surface is resized or about to be shown, so Windows
    ; never presents a stale, black or half-arranged buffer in between.
    RenderNow() {
        if (!this.dc || this.rendering)
            return false
        previous := A_IsCritical
        Critical("On")
        try {
            if this.layoutPending {
                SetTimer(this.layoutFn, 0)
                this.Relayout()
            }
            SetTimer(this.renderFn, 0)
            this.pending := false
            frame := this.hbm, pw := this.pw, ph := this.ph
            if (!this.DoRender() || this.hbm != frame || this.pw != pw || this.ph != ph)
                return false
            if !DllCall("IsWindowVisible", "Ptr", this.hwnd)
                return true
            hdc := DllCall("GetDC", "Ptr", this.hwnd, "Ptr")
            if !hdc
                return false
            try ok := DllCall("BitBlt", "Ptr", hdc, "Int", 0, "Int", 0, "Int", pw, "Int", ph, "Ptr", this.dc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
            finally DllCall("ReleaseDC", "Ptr", this.hwnd, "Ptr", hdc)
            if ok
                DllCall("ValidateRect", "Ptr", this.hwnd, "Ptr", 0)
            return !!ok
        } finally Critical(previous ? previous : "Off")
    }

    RequestLayout() {
        if !this.layoutPending {
            this.layoutPending := true
            SetTimer(this.layoutFn, -1)
        }
    }

    Relayout(*) {
        if this.layouting {
            this.RequestLayout()
            return
        }
        this.layoutPending := false
        if (!this.pw)
            return
        this.layouting := true
        try {
            width := this.lw
            h := this.root.Measure(width)
            if (this.scrollable && h > this.lh + 0.5) {
                width := Max(1, this.lw - 12)
                h := this.root.Measure(width)
            }
            this.contentW := width, this.contentH := Max(h, this.lh)
            this.scrollY := Max(0, Min(this.scrollY, this.contentH - this.lh))
            for n in this.natives
                n._placed := false
            this.root.Arrange(0, -this.scrollY, width, this.scrollable ? this.contentH : this.lh)
            for n in this.natives
                n.ApplyNative()
        } finally this.layouting := false
        this.Invalidate()
    }

    ScrollTo(y) {
        if this.layouting
            return false
        y := Max(0, Min(y, this.contentH - this.lh))
        if (Abs(y - this.scrollY) < 0.5)
            return false
        this.layouting := true
        try {
            this.scrollY := y
            for n in this.natives
                n._placed := false
            this.root.Arrange(0, -this.scrollY, this.contentW, this.contentH)
            for n in this.natives
                n.ApplyNative()
        } finally this.layouting := false
        this.Invalidate()
        return true
    }

    EnsureVisible(widget) {
        if !this.scrollable
            return
        if (widget.y < 0)
            this.ScrollTo(this.scrollY + widget.y - 12)
        else if (widget.y + widget.h > this.lh)
            this.ScrollTo(this.scrollY + widget.y + widget.h - this.lh + 12)
    }

    DoRender(*) {
        Critical("On")
        this.pending := false
        if (!this.dc || this.rendering)
            return
        G := 0
        if DllCall("gdiplus\GdipCreateFromHDC", "Ptr", this.dc, "Ptr*", &G) || !G
            return
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", G, "Int", 4)
        DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", G, "Int", 5)
        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", G, "Int", 7)
        DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", G, "Int", 4)
        DllCall("gdiplus\GdipSetClipRectI", "Ptr", G, "Int", 0, "Int", 0, "Int", this.pw, "Int", this.ph, "Int", 0)
        prev := Gfx.G
        this.rendering := true
        Gfx.G := G
        try {
            if (this.background)
                this.background.Call(this)
            else
                Gfx.Rect(0, 0, this.lw + 1, this.lh + 1, Theme.C("base"))
            this.root.PaintAll(this)
            if (this.scrollable && this.contentH > this.lh + 0.5)
                this.PaintScrollbar()
            if (this.overlay)
                this.overlay.Call(this)
        } finally {
            Gfx.G := prev
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", G)
            this.rendering := false
            if IsObject(this.deferredSize) {
                size := this.deferredSize
                this.deferredSize := ""
                this.Resize(size[1], size[2])
            }
        }
        DllCall("InvalidateRect", "Ptr", this.hwnd, "Ptr", 0, "Int", 0)
        return true
    }

    ScrollbarRect() {
        track := Max(0, this.lh - 4)
        handle := Min(track, Max(30, track * this.lh / this.contentH))
        pos := 2 + (track - handle) * (this.scrollY / Max(1, this.contentH - this.lh))
        return [this.lw - 10, pos, 8, handle]
    }

    PaintScrollbar() {
        r := this.ScrollbarRect()
        Gfx.RRect(r[1], r[2], r[3], r[4], 3, Theme.C("edge"))
    }

    OnPaint() {
        ps := Buffer(A_PtrSize = 8 ? 72 : 64, 0)
        hdc := DllCall("BeginPaint", "Ptr", this.hwnd, "Ptr", ps, "Ptr")
        if (this.dc)
            DllCall("BitBlt", "Ptr", hdc, "Int", 0, "Int", 0, "Int", this.pw, "Int", this.ph, "Ptr", this.dc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
        DllCall("EndPaint", "Ptr", this.hwnd, "Ptr", ps)
    }

    ; ---- input -------------------------------------------------------------
    HitTest(x, y) {
        if (this.overlay && this.HasOwnProp("overlayHit")) {
            hit := this.overlayHit.Call(x, y)
            if (hit != "")
                return hit
        }
        return this.root.HitAll(x, y)
    }

    OnMouseMove(x, y) {
        if (this.dragScroll) {
            r := this.ScrollbarRect(), track := this.lh - 4 - r[4]
            this.ScrollTo(this.dragScroll0 + (y - this.dragStart) * (this.contentH - this.lh) / Max(1, track))
            return
        }
        if (this.capture) {
            this.capture.OnDrag(x, y)
            return
        }
        hit := this.HitTest(x, y)
        if (hit !== this.hover) {
            old := this.hover
            this.hover := hit
            if (old)
                old.OnLeave()
            if (hit)
                hit.OnEnter()
            this.HideTip()
            if (hit && hit.tip != "") {
                this.tipWidget := hit
                SetTimer(this.tipFn, -650)
            }
        }
        if (hit)
            hit.OnMove(x, y)
        tme := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("UInt", tme.Size, "UInt", 2, "Ptr", this.hwnd, tme)
        DllCall("TrackMouseEvent", "Ptr", tme)
    }

    OnMouseLeave() {
        if (this.hover) {
            this.hover.OnLeave()
            this.hover := ""
        }
        this.HideTip()
    }

    ShowTip(*) {
        w := this.tipWidget
        if (!w || w !== this.hover || w.tip = "")
            return
        ToolTip(Locale.Tr(w.tip))
        this.tipShown := true
        SetTimer(this.tipFn.Bind(), 0)
        SetTimer(() => this.HideTip(), -6000)
    }

    HideTip() {
        SetTimer(this.tipFn, 0)
        this.tipWidget := ""
        if (this.tipShown)
            ToolTip()
        this.tipShown := false
    }

    OnButtonDown(x, y, double := false) {
        this.HideTip()
        if (this.scrollable && this.contentH > this.lh + 0.5 && x >= this.lw - 12) {
            r := this.ScrollbarRect()
            if (y >= r[2] && y <= r[2] + r[4]) {
                this.dragScroll := true, this.dragStart := y, this.dragScroll0 := this.scrollY
                DllCall("SetCapture", "Ptr", this.hwnd)
            } else
                this.ScrollTo(this.scrollY + (y < r[2] ? -this.lh : this.lh) * .9)
            return
        }
        hit := this.HitTest(x, y)
        mainSurface := this == MW.surface || (MW.page && this == MW.pages[MW.page].surface)
        if (!hit || !hit.IsEnabled()) {
            if (!hit) {
                this.FocusNone()
                if mainSurface
                    MW.SetKeyboardFocus("")
            }
            return
        }
        if (!hit.native) {
            this.FocusNone()
            if mainSurface
                MW.SetKeyboardFocus(hit.IsTabStop() ? hit : "")
        }
        this.pressed := hit
        this.capture := hit
        DllCall("SetCapture", "Ptr", this.hwnd)
        hit.OnPress(x, y, double)
    }

    OnButtonUp(x, y) {
        if (this.dragScroll) {
            this.dragScroll := false
            DllCall("ReleaseCapture")
            return
        }
        w := this.pressed
        this.pressed := "", this.capture := ""
        DllCall("ReleaseCapture")
        if (w) {
            inside := w.Contains(x, y)
            w.OnRelease(x, y)
            if (inside && w.IsEnabled() && w.Effective())
                w.OnClick(x, y)
        }
    }

    OnWheel(x, y, delta) {
        hit := this.root.WheelTarget(x, y)
        while (hit) {
            if (hit.OnWheel(delta))
                return true
            hit := hit.parent
        }
        if (this.scrollable && this.contentH > this.lh)
            return this.ScrollTo(this.scrollY - delta / 120 * 48) || true
        return false
    }

    FocusNone() {
        focused := DllCall("GetFocus", "Ptr")
        for n in this.natives
            if (n.ctrl && n.ctrl.Hwnd = focused) {
                DllCall("SetFocus", "Ptr", this.hwnd)
                break
            }
    }
}

; ============================================================================
; Base widget
; ============================================================================
class W {
    x := 0, y := 0, w := 0, h := 0
    visible := true, enabled := true, parent := "", surface := "", tip := "", native := false
    hovered := false, down := false, cursor := ""

    Attach(surface) {
        this.surface := surface
        for c in this.Children() {
            c.parent := this
            c.Attach(surface)
        }
    }
    Children() => []
    Measure(width) => 0
    PrefW() => 0
    Arrange(x, y, w, h) {
        this.x := x, this.y := y, this.w := w, this.h := h
    }
    Paint() {
    }
    PaintAll(surface) {
        if (!this.visible || this.w <= 0)
            return
        if (this.y > surface.lh || this.y + this.h < 0)
            return
        this.Paint()
        if (this == MW.keyboardFocus && this.IsEnabled() && !(this is Field))
            Gfx.Border(this.x, this.y, this.w, this.h, this is Toggle ? 5 : 2, Theme.C("accent"))
        for c in this.Children()
            c.PaintAll(surface)
    }
    CollectFocus(items) {
        if (!this.visible || !this.enabled)
            return
        if this.IsTabStop()
            items.Push(this)
        for child in this.Children()
            child.CollectFocus(items)
    }
    IsTabStop() => this is Field || this is Button || this is Toggle || this is Check
        || this is StrategyList || (this is Select && !this.HasOwnProp("editor"))
    Interactive() => false
    Contains(px, py) => (px >= this.x && px < this.x + this.w && py >= this.y && py < this.y + this.h)
    HitAll(px, py) {
        if (!this.visible || !this.Contains(px, py))
            return ""
        kids := this.Children()
        i := kids.Length
        while (i >= 1) {
            r := kids[i].HitAll(px, py)
            if (r != "")
                return r
            i -= 1
        }
        return this.Interactive() ? this : ""
    }
    WheelTarget(px, py) {
        if (!this.visible || !this.Contains(px, py))
            return ""
        for c in this.Children() {
            r := c.WheelTarget(px, py)
            if (r != "")
                return r
        }
        return this
    }
    Effective() {
        p := this
        while (p) {
            if !p.visible
                return false
            p := p.parent
        }
        return true
    }
    IsEnabled() {
        p := this
        while (p) {
            if !p.enabled
                return false
            p := p.parent
        }
        return true
    }
    Invalidate() {
        if (this.surface)
            this.surface.Invalidate()
    }
    Relayout() {
        if (this.surface)
            this.surface.RequestLayout()
    }
    Show(v := true) {
        v := !!v
        if (v = this.visible)
            return this
        this.visible := v
        this.Relayout()
        return this
    }
    Hide() => this.Show(false)
    Enable(v := true) {
        v := !!v
        if (v = this.enabled)
            return this
        this.enabled := v
        this.OnEnableChanged()
        this.Invalidate()
        return this
    }
    OnEnableChanged() {
        for c in this.Children()
            c.OnEnableChanged()
    }
    SetTip(t) {
        this.tip := t
        return this
    }
    OnEnter() {
        this.hovered := true
        if (this.Interactive())
            this.Invalidate()
    }
    OnLeave() {
        this.hovered := false
        if (this.Interactive())
            this.Invalidate()
    }
    OnMove(x, y) {
    }
    OnPress(x, y, double := false) {
        this.down := true
        this.Invalidate()
    }
    OnRelease(x, y) {
        this.down := false
        this.Invalidate()
    }
    OnDrag(x, y) {
        inside := this.Contains(x, y)
        if (inside != this.down) {
            this.down := inside
            this.Invalidate()
        }
    }
    OnClick(x, y) {
    }
    OnWheel(delta) => false
    ApplyNative() {
    }
}

; ============================================================================
; Layout containers
; ============================================================================
class Box extends W {
    __New(items := "", spacing := 0, margins := "") {
        this.items := []
        this.spacing := spacing
        this.margins := margins ? margins : [0, 0, 0, 0] ; left, top, right, bottom
        if IsObject(items)
            for it in items
                this.Add(it)
    }
    Children() {
        out := []
        for it in this.items
            out.Push(it.widget)
        return out
    }
    ; stretch: 0 fixed/preferred, >0 share of free space. fixed: forced main-axis size.
    Add(widget, stretch := 0, fixed := 0) {
        if !IsObject(widget)
            widget := Spacer(widget)
        this.items.Push({widget: widget, stretch: stretch, fixed: fixed})
        widget.parent := this
        if (this.surface)
            widget.Attach(this.surface)
        return widget
    }
    Insert(index, widget, stretch := 0) {
        this.items.InsertAt(index, {widget: widget, stretch: stretch, fixed: 0})
        widget.parent := this
        if (this.surface)
            widget.Attach(this.surface)
        return widget
    }
    Clear() {
        for it in this.items
            it.widget.Dispose()
        this.items := []
    }
    Dispose() {
        for it in this.items
            it.widget.Dispose()
    }
}

; Every widget can be disposed (natives destroy their control).
W.Prototype.Dispose := (this) => 0

class VBox extends Box {
    Measure(width) {
        m := this.margins, inner := width - m[1] - m[3], total := 0, n := 0
        for it in this.items {
            if !it.widget.visible
                continue
            total += it.fixed ? it.fixed : it.widget.Measure(inner)
            n += 1
        }
        return total + Max(0, n - 1) * this.spacing + m[2] + m[4]
    }
    PrefW() {
        m := this.margins, best := 0
        for it in this.items
            if it.widget.visible
                best := Max(best, it.widget.PrefW())
        return best + m[1] + m[3]
    }
    Arrange(x, y, w, h) {
        super.Arrange(x, y, w, h)
        m := this.margins, inner := w - m[1] - m[3]
        heights := [], total := 0, stretch := 0, n := 0
        for it in this.items {
            if !it.widget.visible {
                heights.Push(0)
                continue
            }
            hh := it.fixed ? it.fixed : it.widget.Measure(inner)
            heights.Push(hh)
            total += hh, stretch += it.stretch, n += 1
        }
        free := h - m[2] - m[4] - total - Max(0, n - 1) * this.spacing
        cy := y + m[2]
        for i, it in this.items {
            if !it.widget.visible
                continue
            hh := heights[i]
            if (stretch > 0 && it.stretch > 0 && free > 0)
                hh += free * it.stretch / stretch
            it.widget.Arrange(x + m[1], cy, inner, hh)
            cy += hh + this.spacing
        }
    }
}

class HBox extends Box {
    align := "center"
    Widths(width) {
        m := this.margins, inner := width - m[1] - m[3]
        ws := [], total := 0, stretch := 0, n := 0
        for it in this.items {
            if !it.widget.visible {
                ws.Push(0)
                continue
            }
            ww := it.fixed ? it.fixed : (it.stretch ? 0 : it.widget.PrefW())
            ws.Push(ww)
            total += ww, stretch += it.stretch, n += 1
        }
        free := Max(0, inner - total - Max(0, n - 1) * this.spacing)
        for i, it in this.items
            if (it.widget.visible && it.stretch > 0)
                ws[i] := stretch ? free * it.stretch / stretch : 0
        return ws
    }
    Measure(width) {
        ws := this.Widths(width), best := 0
        for i, it in this.items
            if it.widget.visible
                best := Max(best, it.widget.Measure(ws[i]))
        return best + this.margins[2] + this.margins[4]
    }
    PrefW() {
        total := 0, n := 0
        for it in this.items
            if it.widget.visible {
                total += it.fixed ? it.fixed : it.widget.PrefW()
                n += 1
            }
        return total + Max(0, n - 1) * this.spacing + this.margins[1] + this.margins[3]
    }
    Arrange(x, y, w, h) {
        super.Arrange(x, y, w, h)
        ws := this.Widths(w), m := this.margins
        cx := x + m[1], inner := h - m[2] - m[4]
        for i, it in this.items {
            if !it.widget.visible
                continue
            hh := (this.align = "stretch") ? inner : Min(inner, it.widget.Measure(ws[i]))
            cy := (this.align = "top") ? y + m[2] : y + m[2] + (inner - hh) / 2
            it.widget.Arrange(cx, Round(cy), ws[i], hh)
            cx += ws[i] + this.spacing
        }
    }
}

class Spacer extends W {
    __New(size := 0) {
        this.size := size
    }
    Measure(width) => this.size
    PrefW() => this.size
}

; Card: Qt QFrame#Card (or #Section) with 16/14 margins and 10 px spacing.
class Card extends VBox {
    __New(title := "", section := false) {
        super.__New(, 10, [16, 14, 16, 14])
        this.section := section
        this.title := ""
        if (title != "")
            this.title := this.Add(Label(Locale.Heading(title), "sectionTitle", true))
    }
    Paint() {
        if this.section {
            Gfx.HLine(this.x, this.y, this.w, Theme.C("line"))
            return
        }
        Gfx.RRect(this.x, this.y, this.w, this.h, 2, Theme.C("card"))
        Gfx.Border(this.x, this.y, this.w, this.h, 2, Theme.C("line"))
    }
}

; ============================================================================
; Leaf widgets
; ============================================================================
class Label extends W {
    __New(text := "", role := "", wrap := false) {
        this.text := text, this.role := role, this.wrap := wrap, this.fixedColor := "", this.align := 0
        this.selectable := false
    }
    Font() {
        switch this.role {
            case "title": return Gfx.Font(20, "semi")
            case "sectionTitle": return Gfx.Font(13, "semi")
            case "bootTitle": return Gfx.Font(23, "semi")
            case "version": return Gfx.Font(11, "normal", "Consolas")
            default: return Gfx.Font(13)
        }
    }
    Color() {
        if (this.fixedColor != "")
            return IsInteger(this.fixedColor) ? this.fixedColor : Theme.C(this.fixedColor)
        switch this.role {
            case "subtitle", "caption", "version": return Theme.C("muted")
            case "sectionTitle": return Theme.C("sectionTitle")
            case "notice": return Theme.C("notice")
            default: return Theme.C("text")
        }
    }
    SetText(t) {
        t := String(t)
        if (t == this.text)
            return this
        oldH := this.h
        this.text := t
        if (this.surface) {
            if (this.wrap && this.w > 0 && this.Measure(this.w) != oldH) || (!this.wrap && this.PrefW() != this.w)
                this.Relayout()
            else
                this.Invalidate()
        }
        return this
    }
    Measure(width) {
        if (this.text = "")
            return 0
        f := this.Font()
        if (this.wrap && width > 0)
            return Max(Gfx.LineH(f), Gfx.Measure(this.text, f, width, true)[2])
        return Gfx.Measure(this.text, f, 0, false)[2]
    }
    PrefW() => (this.text = "") ? 0 : Gfx.Measure(this.text, this.Font(), 0, false)[1] + 1
    Paint() {
        Gfx.Text(this.text, this.x, this.y, this.w + 2, this.h + 2, this.Font(), this.Color(), this.align, this.wrap ? 0 : 1, this.wrap, true)
    }
    Interactive() => this.tip != ""
}

; Strategy metadata strip: "map · mode · steps" chips that wrap.
class MetaStrip extends W {
    text := ""
    SetText(t) {
        this.text := t
        this.Relayout()
    }
    Parts() {
        out := []
        for i, part in StrSplit(this.text, " · ")
            out.Push(i = 1 ? part : "·  " part)
        return out
    }
    Measure(width) {
        if (this.text = "")
            return 0
        f := Gfx.Font(13), lh := Gfx.LineH(f), cx := 0, rows := 1
        for p in this.Parts() {
            pw := Gfx.Measure(p, f)[1]
            if (cx > 0 && cx + pw > width)
                rows += 1, cx := 0
            cx += pw + 6
        }
        return rows * Max(1,lh-2) + (rows - 1) * 6
    }
    Paint() {
        f := Gfx.Font(13), lh := Gfx.LineH(f), cx := this.x, cy := this.y
        for p in this.Parts() {
            pw := Gfx.Measure(p, f)[1]
            if (cx > this.x && cx + pw > this.x + this.w)
                cx := this.x, cy += lh + 6
            Gfx.Text(p, cx, cy, pw + 4, lh, f, Theme.C("muted"), 0, 1)
            cx += pw + 6
        }
    }
}

class ImageBox extends W {
    __New(img, size) {
        this.img := img, this.size := size
    }
    Measure(width) => this.size
    PrefW() => this.size
    Paint() {
        Gfx.Image(this.img, this.x, this.y + (this.h - this.size) / 2, this.size, this.size)
    }
}

; ----------------------------------------------------------------------------
; Push button (QPushButton + HoverButton). kind: "", "accent", "stop", "nav",
; "chrome", "flat". icon: "", "play", "stop", "min", "max", "close", "refresh", "plus".
; ----------------------------------------------------------------------------
class UiTween {
    static To(control, prop, target, ms) {
        timer := prop "Timer"
        if (control.HasOwnProp(timer) && control.%timer%)
            SetTimer(control.%timer%, 0)
        origin := control.%prop%
        if (ms <= 0 || !Store.settings["motion"] || origin = target || !control.visible) {
            control.%prop% := target, control.%timer% := ""
            control.Invalidate()
            return
        }
        start := A_TickCount
        step() {
            t := !Store.settings["motion"] || !control.visible ? 1 : Min(1, (A_TickCount - start) / ms)
            control.%prop% := origin + (target - origin) * (1 - (1 - t)**3)
            control.Invalidate()
            if (t >= 1) {
                SetTimer(step, 0)
                control.%timer% := ""
            }
        }
        control.%timer% := step
        SetTimer(step, 15)
    }
}

class Button extends W {
    __New(text, callback := "", kind := "", icon := "") {
        this.text := text, this.callback := callback, this.kind := kind, this.icon := icon
        this.checked := false, this.checkable := false, this.fixedW := 0, this.fixedH := 0
        this.align := (kind = "output") ? 0 : 1
        this.cursor := "hand"
        this.hoverStrength := 0
    }
    Interactive() => true
    OnEnter() {
        super.OnEnter()
        if this.IsEnabled()
            UiTween.To(this, "hoverStrength", 1, 150)
    }
    OnLeave() {
        super.OnLeave()
        UiTween.To(this, "hoverStrength", 0, 150)
    }
    Measure(width) {
        if this.fixedH
            return this.fixedH
        switch this.kind {
            case "nav": return 46
            case "chrome": return 46
            default: return 30
        }
    }
    PrefW() {
        if this.fixedW
            return this.fixedW
        f := Gfx.Font(13), tw := (this.text = "") ? 0 : Gfx.Measure(this.text, f)[1]
        iw := (this.icon != "") ? 14 + (this.text = "" ? 0 : 8) : 0
        pad := (this.kind = "nav") ? 13 : ((this.kind = "accent" || this.kind = "stop") && this.icon != "" ? 14 : 26)
        return Ceil(tw + iw + pad)
    }
    SetText(t) {
        if (t == this.text)
            return this
        this.text := t
        this.Relayout()
        return this
    }
    SetChecked(v) {
        v := !!v
        if (v != this.checked) {
            this.checked := v
            this.Invalidate()
        }
        return this
    }
    OnClick(x, y) {
        if this.checkable
            this.SetChecked(!this.checked)
        if (this.callback)
            this.callback.Call(this)
    }
    Colors() {
        en := this.IsEnabled()
        bg := 0, edge := Theme.C("edge"), fg := Theme.C("muted")
        switch this.kind {
            case "accent":
                bg := en ? Theme.C("accent") : Theme.C("field")
                edge := en ? Theme.C("accent") : Theme.C("dimEdge")
                fg := en ? Theme.C("onAccent") : Theme.C("dimText")
            case "stop":
                bg := en ? Theme.C("field") : 0
                fg := en ? Theme.C("stop") : Theme.C("dimText")
                edge := en ? Theme.C("edge") : Theme.C("dimEdge")
            case "nav":
                edge := 0
                fg := this.checked ? Theme.C("text") : (en ? Theme.C("nav") : Theme.C("dimText"))
                if (this.hovered && en && !this.checked)
                    fg := Theme.C("text")
            case "chrome", "output":
                edge := 0
                fg := (this.hovered && en) ? Theme.C("text") : Theme.C("muted")
            default:
                if !en
                    fg := Theme.C("dimText"), edge := Theme.C("dimEdge")
                else if (this.hovered || this.checked)
                    fg := Theme.C("text")
        }
        if (this.down && en && this.kind != "accent" && this.kind != "nav")
            bg := Theme.C("pressed")
        if (this.checkable && this.checked && this.kind = "" && en)
            bg := Theme.C("pressed")
        return [bg, edge, fg]
    }
    Paint() {
        c := this.Colors(), x := this.x, y := this.y, w := this.w, h := this.h
        if (this.kind = "chrome") {
            if (this.hovered && this.IsEnabled())
                Gfx.Rect(x, y, w, h, this.icon = "close" ? 0xFFC42B1C : 0x14FFFFFF)
            this.PaintIcon(x + w / 2, y + h / 2, (this.hovered && this.icon = "close") ? 0xFFFFFFFF : c[3])
            return
        }
        if (c[1])
            Gfx.RRect(x, y, w, h, 2, c[1])
        if (c[2])
            Gfx.Border(x, y, w, h, 2, c[2])
        if (this.hoverStrength > 0 && this.IsEnabled() && this.kind != "output")
            Gfx.RRect(x + 1, y + 1, w - 2, h - 2, 2, Alpha(Theme.C("hover"), Round(19 * this.hoverStrength)))
        if (this.kind = "nav" && this.checked)
            Gfx.Rect(x, y + h - 2, w, 2, Theme.C("accent"))
        f := Gfx.Font(13)
        if (this.icon != "") {
            tw := (this.text = "") ? 0 : Gfx.Measure(this.text, f)[1]
            total := 14 + (tw ? 8 + tw : 0)
            ix := (this.align = 1) ? x + (w - total) / 2 : x + 14
            this.PaintIcon(ix + 7, y + h / 2, c[3])
            if (tw)
                Gfx.Text(this.text, ix + 22, y, w - (ix + 22 - x), h, f, c[3], 0, 1)
            return
        }
        if (this.align = 0)
            Gfx.Text(this.text, x + 14, y, w - 20, h, f, c[3], 0, 1)
        else
            Gfx.Text(this.text, x + 4, y, w - 8, h, f, c[3], 1, 1)
    }
    PaintIcon(cx, cy, col) {
        switch this.icon {
            case "play": Gfx.Polygon([cx - 2, cy - 3, cx + 3, cy, cx - 2, cy + 3], col)
            case "stop": Gfx.Border(cx - 3, cy - 3, 6, 6, 0, col, 1)
            case "min": Gfx.Line(cx - 5, cy, cx + 5, cy, col, 1, false)
            case "max": Gfx.Border(cx - 5, cy - 5, 10, 10, 0, col, 1)
            case "restore":
                Gfx.Border(cx - 5, cy - 3, 8, 8, 0, col, 1)
                Gfx.Line(cx - 3, cy - 5, cx + 5, cy - 5, col, 1, false)
                Gfx.Line(cx + 5, cy - 5, cx + 5, cy + 3, col, 1, false)
            case "close":
                Gfx.Line(cx - 5, cy - 5, cx + 5, cy + 5, col, 1, false)
                Gfx.Line(cx + 5, cy - 5, cx - 5, cy + 5, col, 1, false)
            case "plus":
                Gfx.Line(cx - 5, cy, cx + 5, cy, col, 1.4)
                Gfx.Line(cx, cy - 5, cx, cy + 5, col, 1.4)
            case "refresh":
                Gfx.Arc(cx - 6, cy - 6, 12, 12, -60, 290, col, 1.4)
                Gfx.Polygon([cx + 1.5, cy - 9, cx + 6.5, cy - 5.6, cx + 1.2, cy - 2.6], col)
        }
    }
}

; QCheckBox styled as ToggleRow (label left, 36x20 switch right).
class Toggle extends W {
    __New(text, checked := false, callback := "") {
        this.text := text, this.checked := !!checked, this.callback := callback, this.cursor := "hand"
        this.position := this.checked ? 1 : 0
    }
    Interactive() => true
    Measure(width) {
        th := Gfx.Measure(this.text, Gfx.Font(13), Max(1, width - 48), true)[2]
        return Max(26, th + 6)
    }
    PrefW() => Gfx.Measure(this.text, Gfx.Font(13))[1] + 56
    SetChecked(v, notify := false) {
        v := !!v
        if (v = this.checked)
            return this
        this.checked := v
        UiTween.To(this, "position", v ? 1 : 0, notify ? 120 : 0)
        this.Invalidate()
        if (notify && this.callback)
            this.callback.Call(this, v)
        return this
    }
    OnClick(x, y) {
        this.SetChecked(!this.checked, true)
    }
    Paint() {
        en := this.IsEnabled()
        Gfx.Text(this.text, this.x, this.y, this.w - 48, this.h, Gfx.Font(13), en ? Theme.C("muted") : Theme.C("dimText"), 0, 1, true)
        tx := this.x + this.w - 36, ty := this.y + (this.h - 20) / 2
        acc := Theme.C("accent")
        Gfx.RRect(tx, ty, 36, 20, 10, this.checked ? acc : Theme.C("field"))
        Gfx.Border(tx, ty, 36, 20, 10, this.checked ? acc : Theme.C("edge"))
        knob := this.checked ? Theme.C("onAccent") : Theme.C("muted")
        Gfx.Ellipse(tx + 3 + this.position * 16, ty + 3, 14, 14, knob)
        if (!en)
            Gfx.RRect(tx, ty, 36, 20, 10, Alpha(Theme.C("base"), 110))
    }
}

; Plain QCheckBox (15 px indicator, text right).
class Check extends W {
    __New(text, checked := false, callback := "") {
        this.text := text, this.checked := !!checked, this.callback := callback, this.cursor := "hand"
    }
    Interactive() => true
    Measure(width) {
        th := Gfx.Measure(this.text, Gfx.Font(13), Max(1, width - 23), true)[2]
        return Max(20, th + 2)
    }
    PrefW() => Gfx.Measure(this.text, Gfx.Font(13))[1] + 26
    SetChecked(v, notify := false) {
        v := !!v
        if (v = this.checked)
            return this
        this.checked := v
        this.Invalidate()
        if (notify && this.callback)
            this.callback.Call(this, v)
        return this
    }
    OnClick(x, y) {
        this.checked := !this.checked
        this.Invalidate()
        if (this.callback)
            this.callback.Call(this, this.checked)
    }
    Paint() {
        en := this.IsEnabled(), lh := Gfx.LineH(Gfx.Font(13))
        bx := this.x, by := this.y + Max(0, (Min(this.h, lh + 2) - 15) / 2)
        if this.checked {
            Gfx.RRect(bx, by, 15, 15, 2, en ? Theme.C("accent") : Theme.C("dimEdge"))
            Gfx.Line(bx + 3.5, by + 7.8, bx + 6.4, by + 10.6, Theme.C("onAccent"), 1.6)
            Gfx.Line(bx + 6.4, by + 10.6, bx + 11.6, by + 4.6, Theme.C("onAccent"), 1.6)
        } else {
            Gfx.RRect(bx, by, 15, 15, 2, Theme.C("field"))
            Gfx.Border(bx, by, 15, 15, 2, en ? Theme.C("edge") : Theme.C("dimEdge"))
        }
        if (this.hovered && en)
            Gfx.RRect(bx, by, 15, 15, 2, Theme.C("hover"))
        Gfx.Text(this.text, this.x + 23, this.y, this.w - 23, this.h, Gfx.Font(13), en ? Theme.C("muted") : Theme.C("dimText"), 0, 1, true)
    }
}

; ----------------------------------------------------------------------------
; Native single-line edit painted as QLineEdit.
; ----------------------------------------------------------------------------
class Field extends W {
    __New(text := "", placeholder := "", opts := "") {
        this.initial := text, this.placeholder := placeholder
        this.password := false, this.number := false, this.maxLength := 0, this.fixedW := 0
        this.readOnly := false, this.onChange := "", this.onCommit := "", this.suffix := ""
        this.ctrl := "", this.focused := false, this.native := true, this._placed := false
        this.innerRight := 10, this.cursor := "ibeam"
        if IsObject(opts)
            for k, v in opts.OwnProps()
                this.%k% := v
    }
    Interactive() => true
    Attach(surface) {
        super.Attach(surface)
        if (this.ctrl)
            return
        g := surface.gui
        g.SetFont("s10 norm c" Theme.Hex("text"), "Segoe UI")
        opt := "x0 y0 w20 h20 -E0x200 -Border +0x80 Hidden Background" Theme.Hex("field")
        if this.password
            opt .= " Password"
        if this.number
            opt .= " Number"
        if this.readOnly
            opt .= " ReadOnly"
        this.ctrl := g.Add("Edit", opt, this.initial)
        if (this.maxLength)
            SendMessage(0xC5, this.maxLength, 0, this.ctrl)
        if (this.placeholder != "")
            DllCall("SendMessage", "Ptr", this.ctrl.Hwnd, "UInt", 0x1501, "Ptr", 1, "WStr", Locale.Tr(this.placeholder))
        ; Zero inner margins so text aligns with the painted padding.
        SendMessage(0xD3, 3, 0, this.ctrl)
        this.ctrl.OnEvent("Change", (*) => this.onChange ? this.onChange.Call(this) : 0)
        this.ctrl.OnCommand(0x100, (*) => this.SetFocused(true))
        this.ctrl.OnCommand(0x200, (*) => this.SetFocused(false))
        surface.natives.Push(this)
    }
    Dispose() {
        if (this.ctrl) {
            if (this.surface) {
                for i, n in this.surface.natives
                    if (n == this) {
                        this.surface.natives.RemoveAt(i)
                        break
                    }
            }
            try DllCall("DestroyWindow", "Ptr", this.ctrl.Hwnd)
            this.ctrl := ""
        }
    }
    SetFocused(v) {
        this.focused := v
        this.Invalidate()
        ; Tab navigation scrolls explicitly. Native focus notifications can also
        ; arrive while controls are being hidden and must not move the page.
        if (!v && this.onCommit)
            this.onCommit.Call(this)
    }
    Text {
        get => this.ctrl ? this.ctrl.Value : this.initial
        set {
            if (this.ctrl)
                this.ctrl.Value := value
            else
                this.initial := value
        }
    }
    Clear() => (this.Text := "")
    Focus() {
        if (this.ctrl)
            this.ctrl.Focus()
    }
    Measure(width) => 34
    PrefW() => this.fixedW ? this.fixedW : 160
    OnPress(x, y, double := false) {
        if (this.ctrl && !this.readOnly) {
            this.ctrl.Focus()
            SendMessage(0xB1, 0, -1, this.ctrl)
        }
    }
    OnRelease(x, y) {
    }
    OnDrag(x, y) {
    }
    OnEnableChanged() {
        if (this.ctrl)
            this.ApplyNative()
    }
    SetReadOnly(v) {
        this.readOnly := !!v
        if (this.ctrl)
            SendMessage(0xCF, this.readOnly, 0, this.ctrl)
        this.Invalidate()
    }
    Arrange(x, y, w, h) {
        super.Arrange(x, y, w, h)
        this._placed := true
    }
    Rethemed() {
        if !this.ctrl
            return
        this.ctrl.Opt("Background" Theme.Hex("field"))
        this.ctrl.SetFont("c" Theme.Hex("text"))
        DllCall("InvalidateRect", "Ptr", this.ctrl.Hwnd, "Ptr", 0, "Int", 1)
    }
    ApplyNative() {
        if !this.ctrl
            return
        show := this._placed && this.Effective() && this.w > 20
            && this.y + this.h > 0 && this.y < this.surface.lh
        if (show) {
            s := Gfx.S, lh := Gfx.LineH(Gfx.Font(13)) + 2
            right := this.innerRight + (this.suffix != "" ? Gfx.Measure(this.suffix, Gfx.Font(13))[1] + 4 : 0)
            ix := Round((this.x + 10) * s), iy := Round((this.y + (this.h - lh) / 2) * s)
            iw := Round((this.w - 10 - right) * s), ih := Round(lh * s)
            bounds := ix "|" iy "|" Max(4, iw) "|" ih
            if (!this.HasOwnProp("nativeBounds") || this.nativeBounds != bounds) {
                DllCall("SetWindowPos", "Ptr", this.ctrl.Hwnd, "Ptr", 0, "Int", ix, "Int", iy, "Int", Max(4, iw), "Int", ih, "UInt", 0x14)
                this.nativeBounds := bounds
            }
        }
        enabled := this.IsEnabled()
        if (this.ctrl.Enabled != enabled)
            this.ctrl.Enabled := enabled
        if (!show && DllCall("GetFocus", "Ptr") = this.ctrl.Hwnd)
            DllCall("SetFocus", "Ptr", this.surface.hwnd)
        if (this.ctrl.Visible != show)
            this.ctrl.Visible := show
    }
    Paint() {
        en := this.IsEnabled()
        Gfx.RRect(this.x, this.y, this.w, this.h, 2, Theme.C("field"))
        Gfx.Border(this.x, this.y, this.w, this.h, 2, this.focused ? Theme.C("accent") : (en ? Theme.C("edge") : Theme.C("dimEdge")))
        if (this.suffix != "")
            Gfx.Text(this.suffix, this.x, this.y, this.w - this.innerRight, this.h, Gfx.Font(13), en ? Theme.C("text") : Theme.C("dimText"), 2, 1)
    }
}

; QSpinBox: numeric Field with painted step arrows; changes commit on Enter/blur/arrows.
class Spin extends Field {
    __New(value, lo, hi, suffix := "", callback := "") {
        super.__New(String(value), "", {number: true, maxLength: StrLen(String(hi)) + (lo < 0 ? 1 : 0), suffix: suffix})
        this.lo := lo, this.hi := hi, this.val := value, this.callback := callback
        this.innerRight := 26
        this.onCommit := (f) => this.Commit()
    }
    Value {
        get => this.val
        set {
            this.val := Max(this.lo, Min(this.hi, Integer(value)))
            this.Text := String(this.val)
        }
    }
    Commit() {
        t := Trim(this.Text)
        v := (t ~= "^-?\d+$") ? Max(this.lo, Min(this.hi, Integer(t))) : this.val
        this.Text := String(v)
        if (v != this.val) {
            this.val := v
            if this.callback
                this.callback.Call(this, v)
        }
    }
    Step(n) {
        if !this.IsEnabled()
            return
        v := Max(this.lo, Min(this.hi, this.val + n))
        this.Text := String(v)
        if (v != this.val) {
            this.val := v
            if this.callback
                this.callback.Call(this, v)
        }
    }
    OnPress(x, y, double := false) {
        if (x >= this.x + this.w - 22) {
            this.down := true
            this.Step(y < this.y + this.h / 2 ? 1 : -1)
            this.Invalidate()
            return
        }
        super.OnPress(x, y, double)
    }
    OnRelease(x, y) {
        this.down := false
        this.Invalidate()
    }
    Paint() {
        super.Paint()
        en := this.IsEnabled(), col := en ? Theme.C("muted") : Theme.C("dimText")
        ax := this.x + this.w - 15, my := this.y + this.h / 2
        Gfx.Polygon([ax - 4, my - 3, ax + 4, my - 3, ax, my - 8], col)
        Gfx.Polygon([ax - 4, my + 3, ax + 4, my + 3, ax, my + 8], col)
    }
}

; QComboBox: painted field + owner-drawn popup list.
class Select extends W {
    __New(items := "", index := 1, callback := "") {
        this.labels := [], this.values := []
        this.index := index, this.callback := callback, this.fixedW := 0, this.minChars := 0
        this.cursor := "hand", this.open := false
        if IsObject(items)
            for it in items
                this.AddItem(it)
    }
    Interactive() => true
    AddItem(label, value := unset) {
        this.labels.Push(label)
        this.values.Push(IsSet(value) ? value : label)
    }
    SetItems(labels, values := "") {
        this.labels := [], this.values := []
        for i, l in labels
            this.AddItem(l, IsObject(values) ? values[i] : l)
        this.index := this.labels.Length ? Max(1, Min(this.index, this.labels.Length)) : 0
        this.Invalidate()
    }
    Count => this.labels.Length
    Text => (this.index >= 1 && this.index <= this.labels.Length) ? this.labels[this.index] : ""
    Value => (this.index >= 1 && this.index <= this.values.Length) ? this.values[this.index] : ""
    Find(value) {
        for i, v in this.values
            if (v == value)
                return i
        return 0
    }
    FindText(text) {
        for i, v in this.labels
            if (v = text)
                return i
        return 0
    }
    Choose(i, notify := false) {
        i := Integer(i)
        if (i < 0 || i > this.labels.Length)
            return false
        changed := i != this.index
        this.index := i
        this.Invalidate()
        if (notify && changed && this.callback)
            this.callback.Call(this, i)
        return true
    }
    ChooseValue(value, notify := false) {
        i := this.Find(value)
        return i ? this.Choose(i, notify) : false
    }
    Measure(width) => 34
    PrefW() {
        if this.fixedW
            return this.fixedW
        f := Gfx.Font(13), best := 0
        for l in this.labels
            best := Max(best, Gfx.Measure(l, f)[1])
        if (this.minChars)
            best := Min(best, Max(this.minChars * 8, 60))
        return Ceil(best + 44)
    }
    OnClick(x, y) {
        if (!this.labels.Length)
            return
        SelectPopup.Open(this)
    }
    OnWheel(delta) => false
    Paint() {
        en := this.IsEnabled()
        Gfx.RRect(this.x, this.y, this.w, this.h, 2, Theme.C("field"))
        Gfx.Border(this.x, this.y, this.w, this.h, 2, this.open ? Theme.C("accent") : (en ? Theme.C("edge") : Theme.C("dimEdge")))
        if (this.hovered && en)
            Gfx.RRect(this.x + 1, this.y + 1, this.w - 2, this.h - 2, 2, Theme.C("hover"))
        if !this.HasOwnProp("editor")
            Gfx.Text(this.Text, this.x + 10, this.y, this.w - 34, this.h, Gfx.Font(13), en ? Theme.C("text") : Theme.C("dimText"), 0, 1)
        cx := this.x + this.w - 15, cy := this.y + this.h / 2, col := en ? Theme.C("muted") : Theme.C("dimText")
        Gfx.Line(cx - 4, cy - 2, cx, cy + 2, col, 1.3)
        Gfx.Line(cx, cy + 2, cx + 4, cy - 2, col, 1.3)
    }
}

class ComboEditor extends Field {
    Paint() {
        ; The parent draws one border around both the edit and arrow.
    }
}

class EditableSelect extends Select {
    __New(items, index, callback) {
        super.__New(items, index, callback)
        this.editor := ComboEditor(this.labels[index], "", {maxLength: 80, onChange: (*) => this.EditChanged()})
    }
    Children() => [this.editor]
    Text => this.editor.Text
    Arrange(x, y, w, h) {
        super.Arrange(x, y, w, h)
        this.editor.Arrange(x, y, Max(1,w-24), h)
    }
    EditChanged() {
        this.index := this.FindText(this.editor.Text)
        if this.callback
            this.callback.Call(this, this.index)
    }
    Choose(i, notify := false) {
        if !super.Choose(i, false)
            return false
        this.editor.Text := i ? this.labels[i] : ""
        if (notify && this.callback)
            this.callback.Call(this, i)
        return true
    }
    ChooseValue(value, notify := false) {
        i := this.Find(value)
        if i
            return this.Choose(i, notify)
        this.editor.Text := value
        this.index := 0
        if (notify && this.callback)
            this.callback.Call(this, 0)
        return true
    }
}

; Popup list window for Select (QComboBox QAbstractItemView).
class SelectPopup {
    static gui := "", surface := "", owner := "", list := "", watchFn := ""

    static Open(sel) {
        SelectPopup.Close()
        SelectPopup.owner := sel
        sel.open := true
        sel.Invalidate()
        s := Gfx.S
        rowH := 28, n := sel.labels.Length, visibleRows := Min(n, 12)
        hostHwnd := sel.surface.hwnd
        pt := Buffer(8, 0)
        NumPut("Int", Round(sel.x * s), "Int", Round((sel.y + sel.h) * s), pt)
        DllCall("ClientToScreen", "Ptr", hostHwnd, "Ptr", pt)
        sx := NumGet(pt, 0, "Int"), sy := NumGet(pt, 4, "Int")
        pw := Round(Max(sel.w, 80) * s), ph := Round((visibleRows * rowH + 4) * s)
        ; Flip above when the list would leave the monitor work area.
        mon := DllCall("MonitorFromPoint", "Int64", (sx & 0xFFFFFFFF) | (sy << 32), "UInt", 2, "Ptr")
        mi := Buffer(40, 0), NumPut("UInt", 40, mi)
        DllCall("GetMonitorInfo", "Ptr", mon, "Ptr", mi)
        workBottom := NumGet(mi, 32, "Int")
        if (sy + ph > workBottom)
            sy := sy - ph - Round(sel.h * s)
        top := DllCall("GetAncestor", "Ptr", hostHwnd, "UInt", 2, "Ptr")
        g := Gui("-Caption +ToolWindow -DPIScale +Owner" top)
        if (WinGetExStyle("ahk_id " top) & 0x8)
            g.Opt("+AlwaysOnTop")
        g.BackColor := Theme.Hex("field")
        list := PopupList(sel, rowH)
        root := VBox([list], 0, [2, 2, 2, 2])
        root.items[1].stretch := 1
        surf := Surface(g, root)
        surf.background := (sf) => (Gfx.Rect(0, 0, sf.lw + 1, sf.lh + 1, Theme.C("field")), Gfx.Border(0, 0, sf.lw, sf.lh, 0, Theme.C("edge")))
        SelectPopup.gui := g, SelectPopup.surface := surf, SelectPopup.list := list
        g.Show("x" sx " y" sy " w" pw " h" ph " NA")
        surf.Resize(pw, ph)
        ; Rows() needs the arranged height. Before Resize it reports one row,
        ; which can hide OFF/the first items even when the entire list fits.
        list.Scroll(Max(0, sel.index - 1 - visibleRows // 2))
        DllCall("SetForegroundWindow", "Ptr", g.Hwnd)
        g.Show()
        if !SelectPopup.watchFn
            SelectPopup.watchFn := ObjBindMethod(SelectPopup, "Watch")
        SetTimer(SelectPopup.watchFn, 60)
    }

    static Watch() {
        if !SelectPopup.gui {
            SetTimer(SelectPopup.watchFn, 0)
            return
        }
        if (DllCall("GetForegroundWindow", "Ptr") != SelectPopup.gui.Hwnd)
            SelectPopup.Close()
    }

    static Close() {
        if SelectPopup.watchFn
            SetTimer(SelectPopup.watchFn, 0)
        if (SelectPopup.owner) {
            SelectPopup.owner.open := false
            SelectPopup.owner.Invalidate()
        }
        if (SelectPopup.gui) {
            g := SelectPopup.gui
            SelectPopup.surface.Destroy()
            SelectPopup.gui := "", SelectPopup.surface := "", SelectPopup.list := ""
            try g.Destroy()
        }
        SelectPopup.owner := ""
    }

    static Key(vk) {
        l := SelectPopup.list
        if !l
            return false
        switch vk {
            case 0x1B: SelectPopup.Close()
            case 0x0D: l.Pick(l.cursorRow)
            case 0x26: l.MoveCursor(-1)
            case 0x28: l.MoveCursor(1)
            case 0x21: l.MoveCursor(-10)
            case 0x22: l.MoveCursor(10)
            default: return false
        }
        return true
    }

    static Char(ch) {
        l := SelectPopup.list
        if (!l || ch = "")
            return
        n := l.sel.labels.Length
        Loop n {
            i := Mod(l.cursorRow + A_Index - 1, n) + 1
            if (SubStr(l.sel.labels[i], 1, 1) = ch) {
                l.cursorRow := i
                l.EnsureRow(i)
                l.Invalidate()
                return
            }
        }
    }
}

class PopupList extends W {
    __New(sel, rowH) {
        this.sel := sel, this.rowH := rowH, this.top := 0, this.hoverRow := 0, this.cursorRow := sel.index
        this.cursor := "hand"
    }
    Interactive() => true
    Rows() => Max(1, Floor(this.h / this.rowH))
    Scroll(top) {
        this.top := Max(0, Min(top, this.sel.labels.Length - this.Rows()))
        this.Invalidate()
    }
    EnsureRow(i) {
        if (i - 1 < this.top)
            this.Scroll(i - 1)
        else if (i > this.top + this.Rows())
            this.Scroll(i - this.Rows())
    }
    MoveCursor(d) {
        this.cursorRow := Max(1, Min(this.sel.labels.Length, this.cursorRow + d))
        this.EnsureRow(this.cursorRow)
        this.Invalidate()
    }
    RowAt(y) {
        r := this.top + Floor((y - this.y) / this.rowH) + 1
        return (r >= 1 && r <= this.sel.labels.Length) ? r : 0
    }
    OnMove(x, y) {
        r := this.RowAt(y)
        if (r != this.hoverRow) {
            this.hoverRow := r, this.cursorRow := r ? r : this.cursorRow
            this.Invalidate()
        }
    }
    OnWheel(delta) {
        this.Scroll(this.top - Round(delta / 120) * 3)
        return true
    }
    OnClick(x, y) {
        r := this.RowAt(y)
        if r
            this.Pick(r)
    }
    Pick(r) {
        sel := this.sel
        SelectPopup.Close()
        if (r >= 1)
            sel.Choose(r, true)
    }
    Paint() {
        f := Gfx.Font(13), n := this.sel.labels.Length, rows := this.Rows()
        Loop Min(rows, n - this.top) {
            i := this.top + A_Index, ry := this.y + (A_Index - 1) * this.rowH
            if (i = this.cursorRow || i = this.hoverRow)
                Gfx.Rect(this.x, ry, this.w, this.rowH, Theme.C("pressed"))
            col := (i = this.sel.index) ? Theme.C("accent") : Theme.C("text")
            Gfx.Text(this.sel.labels[i], this.x + 9, ry, this.w - 18, this.rowH, f, col, 0, 1)
        }
        if (n > rows) {
            track := this.h - 4, handle := Max(20, track * rows / n)
            pos := this.y + 2 + (track - handle) * this.top / Max(1, n - rows)
            Gfx.RRect(this.x + this.w - 7, pos, 5, handle, 2, Theme.C("edge"))
        }
    }
}
