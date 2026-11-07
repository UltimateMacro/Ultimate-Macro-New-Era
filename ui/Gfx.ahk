; Ultimate Macro 1.4 (AutoHotkey edition) - drawing primitives and palette.
; Part of a modified version of "Ultimate Macro" by Darksen, licensed GNU GPLv3.
;
; Everything is painted in logical (96-DPI) units. Gfx scales to physical pixels
; itself, so fonts are created at the physical size and text metrics stay exact.

class Theme {
    static christmas := false
    ; Qt stylesheet palette (theme.py). Christmas swaps follow HALLOWEEN_STYLE.
    static normal := Map(
        "base", 0xFF0E0D12, "text", 0xFFECE8F2, "muted", 0xFFBDB5CA, "nav", 0xFF9C93AB,
        "line", 0xFF26222E, "panel", 0xFF15131A, "field", 0xFF1B1822, "edge", 0xFF6B6379,
        "accent", 0xFFB9A6F2, "onAccent", 0xFF16121E, "pressed", 0xFF2A2340, "dimText", 0xFF625A70,
        "dimEdge", 0xFF302A38, "selected", 0xFF24212B, "stop", 0xFFF2A7B8, "hover", 0x13D9CAFF,
        "header", 0xFF0E0D12, "headerLine", 0xFF26222E, "headerLineW", 1, "sidebar", 0xF815131A,
        "card", 0xEE15131A, "status", 0xFF0E0D12, "sectionTitle", 0xFFECE8F2, "badge", 0xFF2A2340,
        "overlay", 194, "track", 0xFF3A3445, "notice", 0xFFE8C583, "error", 0xFFF2A7B8)
    static festive := Map(
        "base", 0xFF0B1713, "text", 0xFFF4F7F3, "muted", 0xFFCCDAD2, "nav", 0xFFAABEB1,
        "line", 0xFF30453B, "panel", 0xFF10221B, "field", 0xFF172D23, "edge", 0xFF657C6E,
        "accent", 0xFFF29B99, "onAccent", 0xFF231014, "pressed", 0xFF244B37, "dimText", 0xFF778C80,
        "dimEdge", 0xFF2A4538, "selected", 0xFF20392D, "stop", 0xFFF2A7B8, "hover", 0x13FFB6B0,
        "header", 0xFF491F2A, "headerLine", 0xFFCB6B73, "headerLineW", 2, "sidebar", 0xFF18382A,
        "card", 0xF210221B, "status", 0xFF14271E, "sectionTitle", 0xFFF3D99F, "badge", 0xFF244B37,
        "overlay", 201, "track", 0xFF30453B, "notice", 0xFFE8C583, "error", 0xFFF2A7B8)
    static C(name) => (Theme.christmas ? Theme.festive : Theme.normal)[name]
    static Hex(name) => Format("{:06X}", Theme.C(name) & 0xFFFFFF)
}

class Gfx {
    static G := 0, S := 1.0, token := 0
    static fonts := Map(), families := Map(), formats := Map()
    static measureBitmap := 0, measureG := 0
    static measureCache := Map()

    static Init() {
        if (Gfx.token)
            return
        if !DllCall("GetModuleHandle", "Str", "gdiplus", "Ptr")
            DllCall("LoadLibrary", "Str", "gdiplus")
        si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("UInt", 1, si)
        token := 0
        DllCall("gdiplus\GdiplusStartup", "UPtr*", &token, "Ptr", si, "Ptr", 0)
        Gfx.token := token
        Gfx.S := A_ScreenDPI / 96
        bmp := 0, g := 0
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", 8, "Int", 8, "Int", 0, "Int", 0xE200B, "Ptr", 0, "Ptr*", &bmp)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &g)
        DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", g, "Int", 5)
        Gfx.measureBitmap := bmp, Gfx.measureG := g
    }

    static Shutdown() {
        for k, f in Gfx.fonts
            DllCall("gdiplus\GdipDeleteFont", "Ptr", f)
        for k, f in Gfx.families
            DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", f)
        for k, f in Gfx.formats
            DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", f)
        Gfx.fonts := Map(), Gfx.families := Map(), Gfx.formats := Map()
        if (Gfx.measureG)
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", Gfx.measureG)
        if (Gfx.measureBitmap)
            DllCall("gdiplus\GdipDisposeImage", "Ptr", Gfx.measureBitmap)
        if (Gfx.token)
            DllCall("gdiplus\GdiplusShutdown", "UPtr", Gfx.token)
        Gfx.token := 0
    }

    ; ---- fonts -----------------------------------------------------------
    static Family(name) {
        if Gfx.families.Has(name)
            return Gfx.families[name]
        fam := 0
        ; Selawik is Microsoft's open Segoe UI metric twin (used where Segoe UI is absent).
        candidates := (name = "Segoe UI Semibold") ? [name, "Selawik Semibold", "Segoe UI", "Selawik", "Tahoma"]
            : (name = "Segoe UI") ? [name, "Selawik", "Tahoma", "Arial"] : [name, "Segoe UI", "Selawik", "Tahoma", "Arial"]
        for candidate in candidates {
            if !DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", candidate, "Ptr", 0, "Ptr*", &fam)
                break
            fam := 0
        }
        Gfx.families[name] := fam
        return fam
    }

    ; role: "body", "semi", "title", "caption", "small", "mono", "boot", "bootTitle", "version"
    static Font(size, weight := "normal", family := "") {
        key := size "|" weight "|" family "|" Gfx.S
        if Gfx.fonts.Has(key)
            return Gfx.fonts[key]
        style := 0
        if (family = "") {
            ; GDI+ has no automatic CJK fallback: use the Windows UI font for Chinese.
            if (SubStr(Locale.active, 1, 2) = "zh") {
                family := "Microsoft YaHei UI"
                if (weight = "semi")
                    weight := "bold"
            } else
                family := (weight = "semi") ? "Segoe UI Semibold" : "Segoe UI"
        }
        fam := Gfx.Family(family)
        if (weight = "semi" && family = "Segoe UI Semibold" && !Gfx.FamilyIs(fam, "Segoe UI Semibold") && !Gfx.FamilyIs(fam, "Selawik Semibold"))
            style := 1
        if (weight = "bold")
            style := 1
        font := 0
        DllCall("gdiplus\GdipCreateFont", "Ptr", fam, "Float", size * Gfx.S, "Int", style, "Int", 2, "Ptr*", &font)
        Gfx.fonts[key] := font
        return font
    }

    static FamilyIs(fam, name) {
        buf := Buffer(64, 0)
        DllCall("gdiplus\GdipGetFamilyName", "Ptr", fam, "Ptr", buf, "UShort", 0)
        return StrGet(buf, "UTF-16") = name
    }

    ; align: 0 near, 1 center, 2 far.  flags: wrap / noclip.
    static Format(align := 0, valign := 0, wrap := true, ellipsis := false) {
        key := align "|" valign "|" wrap "|" ellipsis
        if Gfx.formats.Has(key)
            return Gfx.formats[key]
        fmt := 0
        ; NoClip only for wrapped text; single lines trim with an ellipsis instead.
        flags := wrap ? 0x4000 : 0
        if !wrap
            flags |= 0x1000 ; NoWrap
        DllCall("gdiplus\GdipCreateStringFormat", "Int", flags, "UShort", 0, "Ptr*", &fmt)
        DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", fmt, "Int", align)
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", fmt, "Int", valign)
        DllCall("gdiplus\GdipSetStringFormatTrimming", "Ptr", fmt, "Int", ellipsis ? 3 : (wrap ? 1 : 0))
        Gfx.formats[key] := fmt
        return fmt
    }

    ; Returns [width, height] of text in logical units.
    static Measure(text, font, width := 0, wrap := true) {
        if (text = "")
            return [0, 0]
        key := text "`n" font "`n" width "`n" wrap
        if Gfx.measureCache.Has(key)
            return Gfx.measureCache[key]
        if (Gfx.measureCache.Count > 4000)
            Gfx.measureCache := Map()
        layout := Buffer(16, 0), bound := Buffer(16, 0)
        NumPut("Float", 0, "Float", 0, "Float", (width > 0 ? width * Gfx.S : 100000), "Float", 100000, layout)
        fmt := Gfx.Format(0, 0, wrap && width > 0, false)
        DllCall("gdiplus\GdipMeasureString", "Ptr", Gfx.measureG, "WStr", text, "Int", -1, "Ptr", font
            , "Ptr", layout, "Ptr", fmt, "Ptr", bound, "Int*", 0, "Int*", 0)
        result := [Ceil(NumGet(bound, 8, "Float") / Gfx.S), Ceil(NumGet(bound, 12, "Float") / Gfx.S)]
        Gfx.measureCache[key] := result
        return result
    }

    ; Keep the longest prefix or filename suffix that fits.
    static Elide(text, font, width, keepEnd := false) {
        if (Gfx.Measure(text, font)[1] <= width + 1)
            return text
        lo := 0, len := StrLen(text), hi := len
        while (lo < hi) {
            mid := (lo + hi + 1) // 2
            candidate := keepEnd ? "…" LTrim(SubStr(text, len - mid + 1)) : RTrim(SubStr(text, 1, mid)) "…"
            if (Gfx.Measure(candidate, font)[1] <= width + 1)
                lo := mid
            else
                hi := mid - 1
        }
        return !lo ? "…" : keepEnd ? "…" LTrim(SubStr(text, len - lo + 1)) : RTrim(SubStr(text, 1, lo)) "…"
    }

    static LineH(font) {
        return Gfx.Measure("Ag", font)[2]
    }

    ; ---- shapes ----------------------------------------------------------
    static _Brush(argb) {
        b := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &b)
        return b
    }

    static Rect(x, y, w, h, argb) {
        if (w <= 0 || h <= 0 || !(argb >> 24))
            return
        s := Gfx.S, b := Gfx._Brush(argb)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", Gfx.G, "Ptr", b, "Float", Round(x * s), "Float", Round(y * s)
            , "Float", Round((x + w) * s) - Round(x * s), "Float", Round((y + h) * s) - Round(y * s))
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", b)
    }

    static _RoundPath(x, y, w, h, r) {
        s := Gfx.S
        x := x * s, y := y * s, w := w * s, h := h * s, r := Min(r * s, w / 2, h / 2)
        path := 0
        DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &path)
        if (r < 0.5) {
            DllCall("gdiplus\GdipAddPathRectangle", "Ptr", path, "Float", x, "Float", y, "Float", w, "Float", h)
            return path
        }
        d := r * 2
        DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x, "Float", y, "Float", d, "Float", d, "Float", 180, "Float", 90)
        DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + w - d, "Float", y, "Float", d, "Float", d, "Float", 270, "Float", 90)
        DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + w - d, "Float", y + h - d, "Float", d, "Float", d, "Float", 0, "Float", 90)
        DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x, "Float", y + h - d, "Float", d, "Float", d, "Float", 90, "Float", 90)
        DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
        return path
    }

    static RRect(x, y, w, h, r, argb) {
        if (w <= 0 || h <= 0 || !(argb >> 24))
            return
        path := Gfx._RoundPath(x, y, w, h, r), b := Gfx._Brush(argb)
        DllCall("gdiplus\GdipFillPath", "Ptr", Gfx.G, "Ptr", b, "Ptr", path)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", b)
        DllCall("gdiplus\GdipDeletePath", "Ptr", path)
    }

    ; 1-logical-pixel outline drawn inside the rectangle.
    static Border(x, y, w, h, r, argb, width := 1) {
        if (w <= 0 || h <= 0 || !(argb >> 24))
            return
        s := Gfx.S, pw := Max(1, Round(width * s)), half := pw / 2 / s
        path := Gfx._RoundPath(x + half, y + half, w - 2 * half, h - 2 * half, r)
        pen := 0
        DllCall("gdiplus\GdipCreatePen1", "UInt", argb, "Float", pw, "Int", 2, "Ptr*", &pen)
        DllCall("gdiplus\GdipDrawPath", "Ptr", Gfx.G, "Ptr", pen, "Ptr", path)
        DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
        DllCall("gdiplus\GdipDeletePath", "Ptr", path)
    }

    static HLine(x, y, w, argb, width := 1) {
        Gfx.Rect(x, y, w, width, argb)
    }

    static VLine(x, y, h, argb, width := 1) {
        Gfx.Rect(x, y, width, h, argb)
    }

    static Line(x1, y1, x2, y2, argb, width := 1, round := true) {
        s := Gfx.S, pen := 0
        DllCall("gdiplus\GdipCreatePen1", "UInt", argb, "Float", width * s, "Int", 2, "Ptr*", &pen)
        if round {
            DllCall("gdiplus\GdipSetPenStartCap", "Ptr", pen, "Int", 2)
            DllCall("gdiplus\GdipSetPenEndCap", "Ptr", pen, "Int", 2)
        }
        DllCall("gdiplus\GdipDrawLine", "Ptr", Gfx.G, "Ptr", pen, "Float", x1 * s, "Float", y1 * s, "Float", x2 * s, "Float", y2 * s)
        DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
    }

    static Ellipse(x, y, w, h, argb) {
        s := Gfx.S, b := Gfx._Brush(argb)
        DllCall("gdiplus\GdipFillEllipse", "Ptr", Gfx.G, "Ptr", b, "Float", x * s, "Float", y * s, "Float", w * s, "Float", h * s)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", b)
    }

    static EllipseLine(x, y, w, h, argb, width := 1) {
        s := Gfx.S, pen := 0
        DllCall("gdiplus\GdipCreatePen1", "UInt", argb, "Float", width * s, "Int", 2, "Ptr*", &pen)
        DllCall("gdiplus\GdipDrawEllipse", "Ptr", Gfx.G, "Ptr", pen, "Float", x * s, "Float", y * s, "Float", w * s, "Float", h * s)
        DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
    }

    static Arc(x, y, w, h, start, sweep, argb, width := 2) {
        s := Gfx.S, pen := 0
        DllCall("gdiplus\GdipCreatePen1", "UInt", argb, "Float", width * s, "Int", 2, "Ptr*", &pen)
        DllCall("gdiplus\GdipSetPenStartCap", "Ptr", pen, "Int", 2)
        DllCall("gdiplus\GdipSetPenEndCap", "Ptr", pen, "Int", 2)
        DllCall("gdiplus\GdipDrawArc", "Ptr", Gfx.G, "Ptr", pen, "Float", x * s, "Float", y * s, "Float", w * s, "Float", h * s, "Float", start, "Float", sweep)
        DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
    }

    static Polygon(points, argb) {
        s := Gfx.S, buf := Buffer(points.Length * 4, 0)
        for i, v in points
            NumPut("Float", v * s, buf, (i - 1) * 4)
        b := Gfx._Brush(argb)
        DllCall("gdiplus\GdipFillPolygon", "Ptr", Gfx.G, "Ptr", b, "Ptr", buf, "Int", points.Length // 2, "Int", 0)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", b)
    }

    static RadialHalo(cx, cy, r, argb, alphaCenter, alphaMid) {
        ; Concentric fills approximate Qt's radial gradient without a path brush.
        steps := 14
        Loop steps {
            t := 1 - (A_Index - 1) / steps
            a := Round(alphaCenter * (1 - t) ** 1.6 * 0 + (t < .5 ? alphaMid * t * 2 : alphaMid + (alphaCenter - alphaMid) * (t - .5) * 2) / steps * 1.6)
            rr := r * (1 - (A_Index - 1) / steps)
            Gfx.Ellipse(cx - rr, cy - rr, rr * 2, rr * 2, (Min(255, a) << 24) | (argb & 0xFFFFFF))
        }
    }

    ; ---- text ------------------------------------------------------------
    static Text(text, x, y, w, h, font, argb, align := 0, valign := 1, wrap := false, ellipsis := true) {
        if (text = "" || w <= 0 || h <= 0)
            return
        if (!wrap && ellipsis)
            text := Gfx.Elide(text, font, w)
        s := Gfx.S, rc := Buffer(16, 0)
        NumPut("Float", x * s, "Float", y * s, "Float", w * s, "Float", h * s, rc)
        b := Gfx._Brush(argb)
        DllCall("gdiplus\GdipDrawString", "Ptr", Gfx.G, "WStr", text, "Int", -1, "Ptr", font, "Ptr", rc
            , "Ptr", Gfx.Format(align, valign, wrap, ellipsis && !wrap), "Ptr", b)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", b)
    }

    static Clip(x, y, w, h) {
        s := Gfx.S
        DllCall("gdiplus\GdipSetClipRect", "Ptr", Gfx.G, "Float", x * s, "Float", y * s, "Float", w * s, "Float", h * s, "Int", 0)
    }

    static ClipIntersect(x, y, w, h) {
        s := Gfx.S
        DllCall("gdiplus\GdipSetClipRect", "Ptr", Gfx.G, "Float", x * s, "Float", y * s, "Float", w * s, "Float", h * s, "Int", 1)
    }

    static Unclip() {
        DllCall("gdiplus\GdipResetClip", "Ptr", Gfx.G)
    }

    static SaveClip() {
        region := 0
        DllCall("gdiplus\GdipCreateRegion", "Ptr*", &region)
        DllCall("gdiplus\GdipGetClip", "Ptr", Gfx.G, "Ptr", region)
        return region
    }

    static RestoreClip(region) {
        DllCall("gdiplus\GdipSetClipRegion", "Ptr", Gfx.G, "Ptr", region, "Int", 0)
        DllCall("gdiplus\GdipDeleteRegion", "Ptr", region)
    }

    ; ---- images ----------------------------------------------------------
    static LoadImage(path) {
        if !FileExist(path)
            return 0
        img := 0
        DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", path, "Ptr*", &img)
        return img
    }

    static ImageSize(img) {
        w := 0, h := 0
        DllCall("gdiplus\GdipGetImageWidth", "Ptr", img, "UInt*", &w)
        DllCall("gdiplus\GdipGetImageHeight", "Ptr", img, "UInt*", &h)
        return [w, h]
    }

    static Image(img, x, y, w, h) {
        if !img
            return
        s := Gfx.S
        DllCall("gdiplus\GdipDrawImageRect", "Ptr", Gfx.G, "Ptr", img, "Float", x * s, "Float", y * s, "Float", w * s, "Float", h * s)
    }

    static ImageRegion(img, x, y, w, h, sx, sy, sw, sh, opacity := 1) {
        if (!img || Min(w,h,sw,sh,opacity) <= 0)
            return
        s := Gfx.S, attributes := 0
        if (opacity < 1) {
            matrix := Buffer(100, 0)
            for index in [0, 6, 12, 18, 24]
                NumPut("Float", index = 18 ? opacity : 1, matrix, index * 4)
            DllCall("gdiplus\GdipCreateImageAttributes", "Ptr*", &attributes)
            if attributes
                DllCall("gdiplus\GdipSetImageAttributesColorMatrix", "Ptr", attributes, "Int", 1, "Int", 1, "Ptr", matrix, "Ptr", 0, "Int", 0)
        }
        try DllCall("gdiplus\GdipDrawImageRectRect", "Ptr", Gfx.G, "Ptr", img
            , "Float", x*s, "Float", y*s, "Float", w*s, "Float", h*s
            , "Float", sx, "Float", sy, "Float", sw, "Float", sh, "Int", 2, "Ptr", attributes, "Ptr", 0, "Ptr", 0)
        finally {
            if attributes
                DllCall("gdiplus\GdipDisposeImageAttributes", "Ptr", attributes)
        }
    }

    static VerticalGradient(x, y, w, h, top, bottom) {
        if (Min(w,h) < 1)
            return
        s := Gfx.S, brush := 0
        a := Buffer(8, 0), b := Buffer(8, 0)
        NumPut("Int", Round(y*s), a, 4)
        NumPut("Int", Round((y+h)*s), b, 4)
        if (DllCall("gdiplus\GdipCreateLineBrushI", "Ptr", a, "Ptr", b, "UInt", top, "UInt", bottom, "Int", 3, "Ptr*", &brush) != 0)
            return
        try DllCall("gdiplus\GdipFillRectangle", "Ptr", Gfx.G, "Ptr", brush
            , "Float", x*s, "Float", y*s, "Float", w*s, "Float", h*s)
        finally DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
    }

    ; Draw a physical-pixel region of a cached bitmap 1:1 (backdrop slices).
    static ImagePhysical(img, dx, dy, sx, sy, w, h) {
        DllCall("gdiplus\GdipDrawImageRectRectI", "Ptr", Gfx.G, "Ptr", img, "Int", dx, "Int", dy, "Int", w, "Int", h
            , "Int", sx, "Int", sy, "Int", w, "Int", h, "Int", 2, "Ptr", 0, "Ptr", 0, "Ptr", 0)
    }

    static Disposable(img) {
        if img
            DllCall("gdiplus\GdipDisposeImage", "Ptr", img)
    }
}

; Mixed alpha colour helper: ARGB with replaced alpha.
Alpha(argb, a) => ((a & 0xFF) << 24) | (argb & 0xFFFFFF)
