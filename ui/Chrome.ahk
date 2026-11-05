; Window frame pieces: backdrop, main layout, strategy list, resize grip, boot stage.

class Backdrop {
    static image := 0, imgW := 0, imgH := 0

    static Load(path) {
        Backdrop.image := Gfx.LoadImage(path)
        if Backdrop.image {
            sz := Gfx.ImageSize(Backdrop.image)
            Backdrop.imgW := sz[1], Backdrop.imgH := sz[2]
        }
    }

    ; Flat base colour like the Python window. The optional scenery ("Theme
    ; background") is drawn straight from the decoded image, cropped to the window,
    ; with no shared cached bitmap that a resize or theme change could free mid-paint.
    static PaintFor(surface, offX, offY) {
        base := Theme.C("base")
        Gfx.Rect(0, 0, surface.lw, surface.lh, base)
        if (!Backdrop.image || !Store.settings["themeBackground"] || !Backdrop.imgW || !MW.surface || MW.surface.pw < 2)
            return
        ww := MW.surface.pw, wh := MW.surface.ph
        scale := Max(ww / Backdrop.imgW, wh / Backdrop.imgH)
        dw := Backdrop.imgW * scale, dh := Backdrop.imgH * scale
        s := Gfx.S
        ; Blend the image directly over the base. This avoids a separate
        ; translucent rectangle pass on a freshly resized child surface.
        Gfx.ImageRegion(Backdrop.image, ((ww - dw) / 2 - offX) / s, ((wh - dh) / 2 - offY) / s
            , dw / s, dh / s, 0, 0, Backdrop.imgW, Backdrop.imgH, (255 - Theme.C("overlay")) / 255)
    }
}

; Absolute layout of the main window (QVBoxLayout root in window.py).
class MainLayout extends W {
    __New(header, ultra, compact, sidebar, outputBar, status) {
        this.header := header, this.ultra := ultra, this.compact := compact, this.sidebar := sidebar
        this.outputBar := outputBar, this.status := status
        this.pageRect := [0, 0, 0, 0], this.bodyRect := [0, 0, 0, 0], this.outputRect := [0, 0, 0, 0]
    }
    Children() => [this.header, this.ultra, this.compact, this.sidebar, this.outputBar, this.status]
    Arrange(x, y, w, h) {
        super.Arrange(x, y, w, h)
        this.header.Arrange(0, 0, w, 46)
        top := 46
        if this.ultra.visible {
            this.ultra.Arrange(0, top, w, 34)
            top += 34
        }
        if this.compact.visible {
            this.compact.Arrange(0, top, w, 34)
            top += 34
        }
        bottom := h - 28
        this.status.Arrange(0, bottom, w, 28)
        outH := MW.outputVisible ? MW.OutputHeight() : 0
        bottom -= outH
        this.outputRect := [0, bottom, w, outH]
        if this.outputBar.visible {
            bottom -= 32
            this.outputBar.Arrange(0, bottom, w, 32)
        }
        this.bodyRect := [0, top, w, Max(0, bottom - top)]
        sw := this.sidebar.visible ? 236 : 0
        if this.sidebar.visible
            this.sidebar.Arrange(0, top, 236, Max(0, bottom - top))
        this.pageRect := [sw, top, Max(0, w - sw), Max(0, bottom - top)]
    }
    Paint() {
        hl := Theme.C("headerLine"), hw := Theme.C("headerLineW")
        Gfx.Rect(0, 0, this.w, 46, Theme.C("header"))
        Gfx.Rect(0, 46 - hw, this.w, hw, hl)
        if this.sidebar.visible {
            r := this.sidebar
            Gfx.Rect(r.x, r.y, r.w, r.h, Theme.C("sidebar"))
            Gfx.Rect(r.x + r.w - 1, r.y, 1, r.h, Theme.C("line"))
        }
        if this.outputBar.visible
            Gfx.Rect(0, this.outputBar.y, this.w, 1, Theme.C("line"))
        if (MW.outputVisible)
            Gfx.Rect(0, this.outputRect[2], this.w, this.outputRect[4], Theme.C("panel"))
        Gfx.Rect(0, this.status.y, this.w, 28, Theme.C("status"))
        Gfx.Rect(0, this.status.y, this.w, 1, Theme.C("line"))
    }
}

; Sidebar library rows (StrategyDelegate): two lines, 50 px, slot badges.
class StrategyList extends W {
    __New(onSelect) {
        this.rows := [], this.index := 0, this.top := 0, this.hoverRow := 0, this.onSelect := onSelect
        this.cursor := "hand", this.dragging := false, this.drag0 := 0, this.top0 := 0
    }
    Interactive() => true
    Measure(width) => 60
    SetRows(rows, index) {
        this.rows := rows, this.index := index
        this.ClampTop()
        this.Invalidate()
    }
    MaxTop() => Max(0, this.rows.Length * 50 - this.h)
    ClampTop() => (this.top := Max(0, Min(this.top, this.MaxTop())))
    EnsureVisible(i) {
        if (i < 1 || this.h <= 0)
            return
        if ((i - 1) * 50 < this.top)
            this.top := (i - 1) * 50
        else if (i * 50 > this.top + this.h)
            this.top := i * 50 - this.h
        this.ClampTop()
    }
    RowAt(y) {
        r := Floor((y - this.y + this.top) / 50) + 1
        return (r >= 1 && r <= this.rows.Length) ? r : 0
    }
    OnMove(x, y) {
        r := (x < this.x + this.w - 12 || this.MaxTop() = 0) ? this.RowAt(y) : 0
        if (r != this.hoverRow) {
            this.hoverRow := r
            this.Invalidate()
        }
        this.tip := r ? this.rows[r].item.title "`n" this.rows[r].item.map " · " this.rows[r].item.mode : ""
    }
    OnLeave() {
        this.hoverRow := 0
        super.OnLeave()
    }
    OnWheel(delta) {
        old := this.top
        this.top -= delta / 120 * 50
        this.ClampTop()
        if (old != this.top)
            this.Invalidate()
        return true
    }
    OnPress(x, y, double := false) {
        if (this.MaxTop() > 0 && x >= this.x + this.w - 12) {
            this.dragging := true, this.drag0 := y, this.top0 := this.top
            return
        }
        r := this.RowAt(y)
        if (r && r != this.index && this.IsEnabled()) {
            this.index := r
            this.Invalidate()
            if (this.onSelect)
                this.onSelect.Call(r)
        }
    }
    OnDrag(x, y) {
        if !this.dragging
            return
        track := this.h - Max(30, this.h * this.h / Max(1, this.rows.Length * 50))
        this.top := this.top0 + (y - this.drag0) * this.MaxTop() / Max(1, track)
        this.ClampTop()
        this.Invalidate()
    }
    OnRelease(x, y) {
        this.dragging := false
    }
    Paint() {
        region := Gfx.SaveClip()
        Gfx.ClipIntersect(this.x, this.y, this.w, this.h)
        first := Floor(this.top / 50) + 1
        tf := Gfx.Font(13), mf := Gfx.Font(13)
        i := first
        while (i <= this.rows.Length) {
            ry := this.y + (i - 1) * 50 - this.top
            if (ry > this.y + this.h)
                break
            row := this.rows[i]
            sel := i = this.index
            if sel
                Gfx.Rect(this.x, ry, this.w, 50, Theme.C("selected"))
            else if (i = this.hoverRow)
                Gfx.Rect(this.x, ry, this.w, 50, Theme.C("field"))
            Gfx.Rect(this.x, ry + 49, this.w, 1, sel ? Theme.C("edge") : Theme.C("line"))
            left := this.x + 13, right := this.x + this.w - 8 - (this.MaxTop() > 0 ? 8 : 0)
            if (row.slots != "") {
                bw := Gfx.Measure(row.slots, mf)[1] + 16
                Gfx.RRect(right - bw, ry + 13, bw, 22, 2, Theme.C("badge"))
                Gfx.Text(row.slots, right - bw, ry + 13, bw, 22, mf, Theme.C("accent"), 1, 1)
                right -= bw + 8
            }
            Gfx.Text(row.item.title, left, ry + 5, right - left, 19, tf, Theme.C("text"), 0, 1)
            Gfx.Text(row.item.map " · " row.item.mode, left, ry + 26, right - left, 17, mf, Theme.C("muted"), 0, 1)
            i += 1
        }
        if (this.MaxTop() > 0) {
            total := this.rows.Length * 50, handle := Max(30, this.h * this.h / total)
            pos := this.y + 2 + (this.h - 4 - handle) * this.top / this.MaxTop()
            Gfx.RRect(this.x + this.w - 10, pos, 8, handle, 3, Theme.C("edge"))
        }
        if !this.rows.Length
            Gfx.Text(_T("No strategies match."), this.x + 4, this.y + 8, this.w - 8, 20, mf, Theme.C("muted"), 0, 1)
        Gfx.RestoreClip(region)
    }
}

class ResizeGrip extends W {
    cursor := "size"
    Interactive() => true
    Measure(width) => 28
    PrefW() => 22
    OnPress(x, y, double := false) {
        if !MW.ResizeEditable()
            return
        s := this.surface
        s.pressed := "", s.capture := ""
        DllCall("ReleaseCapture")
        if (WinGetMinMax("ahk_id " MW.gui.Hwnd) = 0)
            PostMessage(0xA1, 17, 0, , "ahk_id " MW.gui.Hwnd)
    }
    Paint() {
        col := MW.ResizeEditable() ? 0xFFA79ABD : 0xFF514A5D
        bx := this.x + this.w - 4, by := this.y + this.h - 4
        for length in [5, 10, 15]
            Gfx.Line(bx - length, by, bx, by - length, col, 1.2)
    }
}

; Startup stage (boot_stage.py): logo with halo, title, version, spinner, status.
class BootStage {
    static start := 0, ready := false, done := false, angle := 40, status := "Preparing the engine…", timer := ""

    static Begin() {
        BootStage.start := A_TickCount, BootStage.ready := false, BootStage.done := false
        BootStage.angle := 40
        BootStage.timer := ObjBindMethod(BootStage, "Tick")
        if Store.settings["motion"]
            SetTimer(BootStage.timer, 33)
    }

    static Finish() {
        BootStage.ready := true
        if !Store.settings["motion"]
            BootStage.Tick()
    }

    static Tick() {
        elapsed := A_TickCount - BootStage.start
        BootStage.angle := Store.settings["motion"] ? Mod(elapsed, 950) * 360 / 950 : 40
        if (BootStage.ready && (elapsed >= 1000 || !Store.settings["motion"])) {
            SetTimer(BootStage.timer, 0)
            BootStage.done := true
            MW.ShowWorkspace()
            return
        }
        MW.surface.Invalidate()
    }

    static Quint(t) {
        t := Max(0, Min(1, t))
        return 1 - (1 - t) ** 5
    }

    static Paint(surface) {
        r := MW.layout.bodyRect
        x := r[1], y := r[2], w := r[3], h := r[4]
        t := Store.settings["motion"] ? A_TickCount - BootStage.start : 1000
        Gfx.Rect(x, y, w, h, 0xFF0E0D12)
        if (Backdrop.image && Backdrop.imgW && Backdrop.imgH && Min(w,h) > 0) {
            fit := Max(w/Backdrop.imgW, h/Backdrop.imgH)
            sw := w/fit, sh := h/fit
            Gfx.ImageRegion(Backdrop.image, x,y,w,h,(Backdrop.imgW-sw)/2,Backdrop.imgH-sh,sw,sh)
        }
        Gfx.Rect(x, y, w, h, Alpha(0xFF100D18, Round(153*(1-.17*BootStage.Quint(t/1000)))))
        Gfx.VerticalGradient(x, y, w, h, 0x300E0D12, 0xE00E0D12)
        sw := Max(1, Min(420, w - 32)), compact := h < 289
        stackH := h < 210 ? Max(1,h-12) : (compact ? 198 : 269)
        fit := h < 210 ? stackH / 198 : 1
        sx := x + (w - sw) / 2, sy := y + Max(0, (h - stackH) / 2)
        elems := compact ? [[0, 64, 30, 10], [70, 28, 120, 8], [100, 18, 180, 6], [132, 22, 250, 4], [164, 34, 300, 4]]
            : [[0, 104, 30, 10], [114, 32, 120, 8], [151, 18, 180, 6], [193, 22, 250, 4], [227, 42, 300, 4]]
        accent := Theme.C("accent")
        for i, e in elems {
            settled := BootStage.Quint((t - e[3]) / 600), op := BootStage.Quint((t - e[3]) / 420)
            if (op <= 0.01)
                continue
            ey := sy + (e[1] + (1 - settled) * e[4])*fit, eh := e[2]*fit
            a := Round(255 * op)
            switch i {
                case 1:
                    cx := sx + sw / 2, cy := ey + eh / 2, rad := Min(58, sw / 2, eh / 2 + 6)
                    halo := .65 * op * BootStage.Quint((t-60)/850)
                    Loop 14 {
                        f := (15-A_Index)/14
                        Gfx.Ellipse(cx - rad * f, cy - rad * f, rad * 2 * f, rad * 2 * f, Alpha(accent, Round((f > .5 ? 3 : 5)*halo)))
                    }
                    edge := Min(64, eh)
                    if MW.logo {
                        sz := Gfx.ImageSize(MW.logo)
                        if Min(sz*) > 0 {
                            s := edge / Max(sz*), iw := sz[1]*s, ih := sz[2]*s
                            Gfx.ImageRegion(MW.logo,cx-iw/2,cy-ih/2,iw,ih,0,0,sz[1],sz[2],op)
                        }
                    }
                case 2: Gfx.Text("Ultimate Macro", sx, ey, sw, eh, Gfx.Font(Max(1,Round((compact ? 20 : 23)*fit)), "semi"), Alpha(0xFFECE8F2, a), 1, 1)
                case 3: Gfx.Text(App.SHORT_VERSION, sx, ey, sw, eh, Gfx.Font(Max(1,Round(11*fit)), "normal", "Consolas"), Alpha(0xFFBDB5CA, a), 1, 1)
                case 4:
                    cx := sx + sw / 2
                    Gfx.EllipseLine(cx - 9, ey + 2, 18, 18, Alpha(Theme.C("track"), a), 2)
                    Gfx.Arc(cx - 9, ey + 2, 18, 18, -BootStage.angle, 90, Alpha(accent, a), 2)
                case 5: Gfx.Text(_T(BootStage.status), sx, ey, sw, eh, Gfx.Font(Max(1,Round(13*fit))), Alpha(0xFFECE8F2, a), 1, 1, true)
            }
        }
    }
}
