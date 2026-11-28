class MacroAppearance {
    static theme := Map()
    static controls := Map()
    static fonts := Map()
    static brushes := Map()
    static root := A_AppData "\Ultimate_Macro\Appearance"
    static id := "default"
    static customRoot := ""
    static settings := 0
    static preview := 0
    static baseTabs := []
    static wallpaper := 0
    static bitmap := 0
    static paintKey := ""
    static wallpaperCache := Map()
    static wallpaperCacheOrder := []
    static wordingEnabled := true
    static wallpapersEnabled := true
    static eggsEnabled := true
    static eggClicks := 0
    static eggGui := 0
    static eggPicture := 0
    static eggTimer := (*) => MacroAppearance.ShowEasterEgg()
    static eggHideTimer := (*) => MacroAppearance.HideEasterEgg()

    static ThemeRoot(id) {
        bundled := A_ScriptDir "\Resources\Themes\" id
        return FileExist(bundled "\theme.json") ? bundled : this.root "\Themes\" id
    }
    static bgRoles := Map("121212", "background", "181818", "secondary", "0A0A0A", "chrome",
        "202020", "surface", "1B1B1B", "surface", "0F0F0F", "chrome", "0E0E0F", "button",
        "222222", "hover", "333333", "border", "3A86FF", "accent", "FFFFFF", "accent")
    static fgRoles := Map("FFFFFF", "text", "WHITE", "text", "AAAAAA", "muted", "888888", "muted",
        "7E848E", "muted", "9CA4B0", "muted", "808080", "muted", "B9B9B8", "muted",
        "E2E4E7", "text", "E0E5EF", "text", "E7EDF8", "text", "D4D9E2", "text",
        "A9C9F3", "accent", "3A86FF", "accent", "C0CAD9", "text", "FF4D4D", "error", "FF6B6B", "error")

    static Color(role, fallback) => this.theme.Has("colors") ? this.theme["colors"].Get(role, fallback) : fallback

    static ColorRef(role, fallback) {
        rgb := Integer("0x" this.Color(role, fallback))
        return (rgb & 255) << 16 | (rgb & 0xFF00) | rgb >> 16
    }

    static Brush(role, fallback) {
        color := this.ColorRef(role, fallback)
        key := role "|" fallback
        if this.brushes.Has(key) {
            pair := this.brushes[key]
            if pair[1] = color
                return pair[2]
            DeleteObject(pair[2])
        }
        brush := DllCall("CreateSolidBrush", "UInt", color, "Ptr")
        this.brushes[key] := [color, brush]
        return brush
    }

    static Style(options, background := false) {
        pattern := background ? "i)\bBackground([a-f0-9]{6})\b" : "i)\bc([a-f0-9]{6}|White)\b"
        if !RegExMatch(options, pattern, &m)
            return options
        roles := background ? this.bgRoles : this.fgRoles
        role := roles.Get(StrUpper(m[1]), "")
        if role = ""
            return options
        return StrReplace(options, m[0], (background ? "Background" : "c") this.Color(role, m[1]))
    }

    static Load() {
        this.settings := this.root "\appearance.ini"
        this.wordingEnabled := IniRead(this.settings, "Appearance", "Wording", 1) = 1
        this.wallpapersEnabled := IniRead(this.settings, "Appearance", "Wallpapers", 1) = 1
        this.eggsEnabled := IniRead(this.settings, "Appearance", "EasterEggs", 1) = 1
        try {
            id := IniRead(this.settings, "Appearance", "Theme", "default")
            if id != "default" && id ~= "i)^[a-z0-9][a-z0-9_-]{0,39}$" {
                root := this.ThemeRoot(id)
                theme := this.Read(root)
                this.theme := theme
                this.customRoot := root
                this.id := id
            }
        }
        this.ScheduleEasterEgg()
    }

    static Read(root) {
        path := root "\theme.json"
        for candidate in [root, path] {
            if InStr(FileGetAttrib(candidate), "L")
                throw Error("Linked theme files are unsupported.")
        }
        if FileGetSize(path) > 65536
            throw Error("The theme file is too large.")
        return this.Validate(JSON.Parse(FileRead(path, "UTF-8")), root)
    }

    static Validate(theme, root) {
        if !(theme is Map) || theme.Get("schemaVersion", 0) != 1
            throw Error("Expected a version 1 theme.")
        if !(theme.Get("id", "") ~= "i)^[a-z0-9][a-z0-9_-]{0,39}$") || theme["id"] = "default"
            throw Error("Choose a valid custom theme ID.")
        for key in ["name", "author"] {
            name := theme.Get(key, "")
            if Type(name) != "String" || StrLen(name) > 80 || RegExMatch(name, "[\x00-\x1f]") || (key = "name" && Trim(name) = "")
                throw Error("Check the theme name or author.")
        }
        for key in ["colors", "wording", "wallpapers"] {
            if !(theme.Get(key, Map()) is Map)
                throw Error("Invalid theme section: " key)
        }
        for key, value in theme.Get("colors", Map()) {
            if Type(value) != "String" || !(value ~= "i)^[a-f0-9]{6}$")
                throw Error("Use six hex digits for " key ".")
        }
        colors := theme.Get("colors", Map())
        for pair in [["background", "121212", "text", "FFFFFF"], ["background", "121212", "muted", "888888"],
            ["secondary", "181818", "text", "FFFFFF"], ["button", "0E0E0F", "text", "FFFFFF"],
            ["input", "181818", "inputText", "E2E4E7"], ["selected", "314662", "inputText", "E2E4E7"]] {
            if this.Contrast(colors.Get(pair[1], pair[2]), colors.Get(pair[3], pair[4])) < 4.5
                throw Error("Increase the contrast between " pair[1] " and " pair[3] ".")
        }
        for page, config in theme.Get("wallpapers", Map()) {
            if !(page ~= "^(global|Tab1|Farming|Tab2|Tab3|Tab4|Tab5|Tab7)$")
                continue
            this.ValidateWallpaper(config, root)
        }
        egg := theme.Get("easterEgg", false)
        if (egg is Map) {
            if egg.Has("asset")
                this.ValidateWallpaper(egg, root)
        }
        return theme
    }

    static Luminance(hex) {
        rgb := Integer("0x" hex)
        total := 0
        for index, weight in [0.2126, 0.7152, 0.0722] {
            component := ((rgb >> (24 - index * 8)) & 255) / 255
            total += weight * (component <= 0.04045 ? component / 12.92 : ((component + 0.055) / 1.055) ** 2.4)
        }
        return total
    }

    static Contrast(first, second) {
        a := this.Luminance(first), b := this.Luminance(second)
        return (Max(a, b) + 0.05) / (Min(a, b) + 0.05)
    }

    static ValidateWallpaper(config, root) {
        if !(config is Map)
            throw Error("Invalid wallpaper settings.")
        asset := config.Get("asset", "")
        if Type(asset) != "String" || !(asset ~= "i)^[a-z0-9][a-z0-9 _.-]{0,79}\.(png|jpe?g|bmp)$") || InStr(asset, "..")
            throw Error("Use a local PNG, JPEG or BMP filename.")
        assets := root "\Assets"
        path := assets "\" asset
        if InStr(FileGetAttrib(assets), "L")
            throw Error("Linked asset folders are unsupported.")
        this.ValidateImage(path)
        if !(config.Get("fit", "cover") ~= "^(cover|contain|stretch|original)$")
            throw Error("Unsupported wallpaper fit.")
        for key, limit in Map("opacity", 1, "dim", 1, "blur", 8) {
            value := config.Get(key, key = "opacity" ? 0.35 : 0)
            if !IsNumber(value) || value < 0 || value > limit
                throw Error("Wallpaper value is out of range: " key)
        }
        return path
    }

    static ValidateImage(path) {
        if InStr(FileGetAttrib(path), "L") || FileGetSize(path) > 12582912
            throw Error("The wallpaper is linked or exceeds 12 MB.")
        file := FileOpen(path, "r")
        header := Buffer(8)
        try bytes := file.RawRead(header, 8)
        finally file.Close()
        if bytes != 8 || !(NumGet(header, 0, "UInt") = 0x474E5089
            || NumGet(header, 0, "UShort") = 0xD8FF || NumGet(header, 0, "UShort") = 0x4D42)
            throw Error("Use a PNG, JPEG or BMP image.")
        image := Gdip_CreateBitmapFromFile(path)
        if !image
            throw Error("The wallpaper could not be decoded.")
        try {
            Gdip_GetImageDimensions(image, &width, &height)
            if width < 1 || height < 1 || width > 4096 || height > 4096
                throw Error("Wallpaper dimensions must be within 4096 by 4096.")
        } finally Gdip_DisposeImage(image)
    }

    static Apply(theme, root := "") {
        global MainGui, ChildGui, CurrentTab, TabCtrl, TopPages
        this.ClearWallpaperCache()
        this.theme := theme
        this.customRoot := root
        this.eggClicks := 0
        MainGui.BackColor := this.Color("background", "121212")
        ChildGui.BackColor := this.Color("secondary", "181818")
        RefreshStrategyCardFrames()
        for _, item in this.controls {
            try {
                if item.HasOwnProp("font")
                    item.ctrl.SetFont(this.Style(item.font))
                if item.HasOwnProp("background")
                    item.ctrl.Opt(this.Style(item.background, true))
            }
        }
        ApplyMacroDarkControls(MainGui)
        this.Wording()
        this.paintKey := ""
        this.QueuePaint()
        FarmRedraw()
        this.ScheduleEasterEgg()
    }

    static ScheduleEasterEgg() {
        SetTimer(this.eggTimer, 0)
        egg := this.theme.Get("easterEgg", false)
        if !this.eggsEnabled || !(egg is Map) || !egg.Has("asset") || this.customRoot = "" {
            this.HideEasterEgg()
            return
        }
        low := egg.Get("intervalMinSeconds", 120)
        high := egg.Get("intervalMaxSeconds", 300)
        if !IsInteger(low) || !IsInteger(high) || low < 30 || high < low || high > 3600
            return
        SetTimer(this.eggTimer, -Random(low, high) * 1000)
    }

    static ShowEasterEgg() {
        global MainGui, MacroClosing, RunningStrategy, Recording, MacroRecording
        if MacroClosing || !this.eggsEnabled
            return
        if (RunningStrategy || Recording || MacroRecording)
            return
        egg := this.theme.Get("easterEgg", false)
        if !(egg is Map) || !egg.Has("asset") || !this.customRoot
            return
        path := this.customRoot "\Assets\" egg["asset"]
        if !FileExist(path)
            return
        if !this.eggGui {
            this.eggGui := Gui("+Owner" MainGui.Hwnd " -Caption +ToolWindow")
            this.eggPicture := this.eggGui.Add("Picture", "x0 y0 w220 h220 +0xE", path)
            this.eggPicture.OnEvent("Click", (*) => this.HideEasterEgg())
        } else
            this.eggPicture.Value := path
        MainGui.GetPos(&x, &y, &w, &h)
        this.eggGui.Show("NA x" Min(x + w - 232, A_ScreenWidth - 232) " y" (y + 84))
        duration := egg.Get("displayMs", 3000)
        if !IsInteger(duration) || duration < 1000 || duration > 8000
            duration := 3000
        SetTimer(this.eggHideTimer, -duration)
        low := egg.Get("intervalMinSeconds", 120)
        high := egg.Get("intervalMaxSeconds", 300)
        if IsInteger(low) && IsInteger(high) && low >= 30 && high >= low && high <= 3600
            SetTimer(this.eggTimer, -Random(low, high) * 1000)
    }

    static HideEasterEgg(*) {
        SetTimer(this.eggHideTimer, 0)
        if this.eggGui
            this.eggGui.Hide()
    }

    static LogoClick(*) {
        if !this.eggsEnabled
            return
        egg := this.theme.Get("easterEgg", false)
        if !(egg is Map)
            return
        clicks := egg.Get("clicks", 5), message := egg.Get("message", "")
        if !IsInteger(clicks) || clicks < 3 || clicks > 20 || Type(message) != "String"
            || StrLen(message) > 120 || Trim(message) = ""
            return
        this.eggClicks += 1
        if this.eggClicks < clicks
            return
        this.eggClicks := 0
        ToolTip(message,,, 18)
        static hide := (*) => ToolTip(,,, 18)
        SetTimer(hide, -2000)
    }

    static Wording() {
        global TabCtrl, FarmPicker
        for index, source in this.baseTabs {
            key := ["tab.main", "tab.farming", "tab.record", "tab.party", "tab.discord", "tab.settings", "tab.credits"][index]
            value := this.Text(key, "")
            ctrl := TabCtrl[index]
            ctrl.Text := Type(value) = "String" && StrLen(value) <= 40 && Trim(value) != ""
                && !RegExMatch(value, "[\x00-\x1f]") && this.Fits(ctrl, value) ? value : TranslateText(source)
        }
        if IsSet(FarmPicker)
            FarmingRefreshThemeWording()
    }

    static Text(key, fallback) {
        global ActiveLocale
        if !this.wordingEnabled
            return fallback
        words := this.theme.Get("wording", Map())
        for section in [words.Get(ActiveLocale, Map()), words.Get("default", Map())] {
            if !(section is Map) || !section.Has(key)
                continue
            value := section[key]
            if Type(value) = "String" && StrLen(value) <= 80 && Trim(value) != ""
                && !RegExMatch(value, "[\x00-\x1f]")
                return value
        }
        return fallback
    }

    static Fits(ctrl, value) {
        hwnd := ctrl.Hwnd
        dc := DllCall("GetDC", "Ptr", hwnd, "Ptr")
        if !dc
            return false
        font := SendMessage(0x31, 0, 0, hwnd)
        old := font ? DllCall("SelectObject", "Ptr", dc, "Ptr", font, "Ptr") : 0
        size := Buffer(8), rect := Buffer(16)
        try {
            DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rect)
            return DllCall("GetTextExtentPoint32W", "Ptr", dc, "WStr", value, "Int", StrLen(value), "Ptr", size)
                && NumGet(size, 0, "Int") + 8 <= NumGet(rect, 8, "Int")
        } finally {
            if old
                DllCall("SelectObject", "Ptr", dc, "Ptr", old)
            DllCall("ReleaseDC", "Ptr", hwnd, "Ptr", dc)
        }
    }

    static QueuePaint() {
        if MacroClosing
            return
        static callback := (*) => MacroAppearance.SafePaint()
        SetTimer(callback, -100)
    }

    static SafePaint() {
        if MacroClosing
            return
        try this.Paint()
        catch {
            if this.wallpaper
                this.wallpaper.Visible := false
        }
    }

    static Paint() {
        global MainGui, CurrentTab
        if !this.wallpaper || !IsSet(CurrentTab)
            return
        walls := this.theme.Get("wallpapers", Map())
        config := walls.Get(CurrentTab, walls.Get("global", false))
        MainGui.GetClientPos(,, &width, &height)
        height -= Round(78 * A_ScreenDPI / 96)
        if !config || width < 1 || height < 1 || width > 4096 || height > 4096
            || !this.wallpapersEnabled {
            this.wallpaper.Visible := false
            return
        }
        key := CurrentTab "|" width "|" height "|" this.customRoot
        if key = this.paintKey && this.bitmap {
            if !this.wallpaper.Visible
                this.ShowWallpaper(width, height)
            return
        }
        if this.wallpaperCache.Has(key) {
            this.bitmap := this.wallpaperCache[key]
            SendMessage(0x172, 0, this.bitmap, this.wallpaper.Hwnd)
            this.TouchWallpaperCache(key)
            this.paintKey := key
            this.ShowWallpaper(width, height)
            return
        }
        image := Gdip_CreateBitmapFromFile(this.customRoot "\Assets\" config["asset"])
        if !image {
            this.wallpaper.Visible := false
            return
        }
        canvas := 0, graphics := 0, softened := 0, softGraphics := 0
        try {
            Gdip_GetImageDimensions(image, &iw, &ih)
            if iw < 1 || ih < 1 || iw > 4096 || ih > 4096
                return
            blur := config.Get("blur", 0)
            if blur >= 1 {
                bw := Max(1, Round(iw / (1 + blur * 8))), bh := Max(1, Round(ih / (1 + blur * 8)))
                softened := Gdip_CreateBitmap(bw, bh)
                softGraphics := Gdip_GraphicsFromImage(softened)
                Gdip_SetInterpolationMode(softGraphics, 7)
                Gdip_DrawImage(softGraphics, image, 0, 0, bw, bh, 0, 0, iw, ih)
            }
            canvas := Gdip_CreateBitmap(width, height)
            graphics := Gdip_GraphicsFromImage(canvas)
            Gdip_GraphicsClear(graphics, Integer("0xFF" this.Color("background", "121212")))
            Gdip_SetInterpolationMode(graphics, blur ? 4 : 7)
            fit := config.Get("fit", "cover")
            scale := fit = "cover" ? Max(width / iw, height / ih) : fit = "contain" ? Min(width / iw, height / ih) : 1
            dw := fit = "stretch" ? width : Round(iw * scale)
            dh := fit = "stretch" ? height : Round(ih * scale)
            hx := Map("left", 0, "right", 1).Get(config.Get("horizontal", ""), 0.5)
            vy := Map("top", 0, "bottom", 1).Get(config.Get("vertical", ""), 0.5)
            opacity := config.Get("opacity", 0.35) * (1 - config.Get("dim", 0))
            Gdip_DrawImage(graphics, softened ? softened : image, Round((width - dw) * hx), Round((height - dh) * vy),
                dw, dh, 0, 0, softened ? bw : iw, softened ? bh : ih, opacity)
            bitmap := Gdip_CreateHBITMAPFromBitmap(canvas)
            if !bitmap
                return
            SendMessage(0x172, 0, bitmap, this.wallpaper.Hwnd)
            this.bitmap := bitmap
            this.wallpaperCache[key] := bitmap
            this.wallpaperCacheOrder.Push(key)
            while this.wallpaperCacheOrder.Length > 8 {
                expired := this.wallpaperCacheOrder.RemoveAt(1)
                oldBitmap := this.wallpaperCache[expired]
                this.wallpaperCache.Delete(expired)
                if oldBitmap != this.bitmap
                    DeleteObject(oldBitmap)
            }
            this.paintKey := key
            this.ShowWallpaper(width, height)
        } finally {
            if softGraphics
                Gdip_DeleteGraphics(softGraphics)
            if softened
                Gdip_DisposeImage(softened)
            if graphics
                Gdip_DeleteGraphics(graphics)
            if canvas
                Gdip_DisposeImage(canvas)
            Gdip_DisposeImage(image)
        }
    }

    static ShowWallpaper(width, height) {
        ; Keep the picture below every sibling and repaint foreground controls.
        DllCall("SetWindowPos", "Ptr", this.wallpaper.Hwnd, "Ptr", 1, "Int", 0,
            "Int", Round(78 * A_ScreenDPI / 96), "Int", width, "Int", height, "UInt", 0x50)
        FarmRedraw()
    }

    static TouchWallpaperCache(key) {
        for index, cachedKey in this.wallpaperCacheOrder {
            if cachedKey = key {
                this.wallpaperCacheOrder.RemoveAt(index)
                break
            }
        }
        this.wallpaperCacheOrder.Push(key)
    }

    static ClearWallpaperCache() {
        if this.wallpaper
            SendMessage(0x172, 0, 0, this.wallpaper.Hwnd)
        for _, bitmap in this.wallpaperCache
            DeleteObject(bitmap)
        this.wallpaperCache := Map()
        this.wallpaperCacheOrder := []
        this.bitmap := 0
        this.paintKey := ""
    }
}

AppearanceFont(target, options := "", args*) {
    result := target.SetFont(MacroAppearance.Style(options), args*)
    if RegExMatch(options, "i)\bc(?:[a-f0-9]{6}|White)\b", &color) {
        if target is Gui
            MacroAppearance.fonts[target.Hwnd] := color[0]
        else if MacroAppearance.controls.Has(target.Hwnd)
            MacroAppearance.controls[target.Hwnd].font := color[0]
    }
    return result
}

AppearanceAdd(gui, type, options, value := "") {
    ctrl := gui.Add(type, MacroAppearance.Style(options, true), value)
    item := {ctrl: ctrl}
    if MacroAppearance.fonts.Has(gui.Hwnd)
        item.font := MacroAppearance.fonts[gui.Hwnd]
    if RegExMatch(options, "i)\bBackground(?:[a-f0-9]{6}|Trans)\b", &bg)
        item.background := bg[0]
    MacroAppearance.controls[ctrl.Hwnd] := item
    return ctrl
}

AppearanceOpt(ctrl, options) {
    if MacroAppearance.controls.Has(ctrl.Hwnd) && RegExMatch(options, "i)\bBackground(?:[a-f0-9]{6}|Trans)\b", &bg)
        MacroAppearance.controls[ctrl.Hwnd].background := bg[0]
    ctrl.Opt(MacroAppearance.Style(options, true))
}
