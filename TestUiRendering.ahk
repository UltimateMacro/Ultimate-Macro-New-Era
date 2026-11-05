#Requires AutoHotkey v2.0 64-bit
#Warn All, Off
#NoTrayIcon
#Include Main.ahk

Need(ok, message) {
    if !ok
        throw Error(message)
}

Pixel(s, x, y) {
    color := DllCall("GetPixel", "Ptr", s.dc, "Int", x, "Int", y, "UInt")
    Need(color != 0xFFFFFFFF, "Read a pixel from the off-screen frame")
    return color
}

MaxChannelDiff(a, b) {
    return Max(Abs((a & 255) - (b & 255)), Abs(((a >> 8) & 255) - ((b >> 8) & 255)),
        Abs(((a >> 16) & 255) - ((b >> 16) & 255)))
}

DirectBackdrop(s) {
    Backdrop.ComposeWindow(s.pw, s.ph, Theme.C("base"), (255 - Theme.C("overlay")) / 255)
}

TimeDraws(s, rounds) {
    start := finish := frequency := 0
    DllCall("QueryPerformanceFrequency", "Int64*", &frequency)
    DllCall("QueryPerformanceCounter", "Int64*", &start)
    Loop rounds
        Need(s.RenderNow(), "Paint an off-screen frame")
    DllCall("QueryPerformanceCounter", "Int64*", &finish)
    return 1000 * (finish - start) / frequency / rounds
}

RejectComposition(*) {
    throw Error("fixture paint failed")
}

surfaces := [], guis := []
exitCode := 0
try {
    Store.settings := Store.Defaults()
    Store.settings["themeBackground"] := true
    Gfx.Init()
    Backdrop.Load(App.assets "\AlpineSunset.jpg")
    Need(Backdrop.image && Backdrop.imgW > 0 && Backdrop.imgH > 0, "Load the bundled backdrop")
    Loop 3 {
        g := Gui("-DPIScale")
        guis.Push(g), surfaces.Push(Surface(g, VBox()))
    }
    main := surfaces[1], page := surfaces[2], old := surfaces[3]
    MW.surface := main
    main.background := (s) => Backdrop.PaintFor(s, 0, 0)
    page.background := (s) => Backdrop.PaintFor(s, 229, 61)
    old.background := DirectBackdrop
    main.Resize(820, 560), page.Resize(530, 410), old.Resize(820, 560)
    previous := A_IsCritical
    Need(main.RenderNow() && page.RenderNow() && old.RenderNow(), "Paint hidden main, page and reference buffers")
    Need(A_IsCritical == previous, "Immediate paint restores the caller's Critical state")
    key := Backdrop.cache["window"].key, bmp := Backdrop.cache["window"].bmp
    for pt in [[45, 50], [132, 128], [297, 232], [479, 360]] {
        x := pt[1], y := pt[2], mx := x + 229, my := y + 61
        Need(Pixel(page, x, y) == Pixel(main, mx, my), "Page background slice stays aligned with the main window")
        Need(MaxChannelDiff(Pixel(main, mx, my), Pixel(old, mx, my)) <= 3, "Cached colors match the previous direct paint")
    }
    cachedMs := TimeDraws(main, 24), directMs := TimeDraws(old, 24)
    Need(Backdrop.cache["window"].bmp == bmp && Backdrop.cache["window"].key == key, "Unchanged frames reuse the cached image")

    oldBuffer := main.hbm, oldCapacity := [main.cw, main.ch]
    Backdrop.BeginSizing()
    main.Resize(840, 580)
    Need(main.hbm == oldBuffer && main.cw == oldCapacity[1] && main.ch == oldCapacity[2], "Small resizes reuse the backing DIB")
    Need(main.RenderNow() && !Backdrop.cache["window"].sharp && Backdrop.cache["window"].key != key,
        "A live resize repaints with a new fast cache")
    Backdrop.EndSizing()
    Need(!Backdrop.cache.Has("window") && main.RenderNow() && Backdrop.cache["window"].sharp,
        "Finishing a resize rebuilds the sharp backdrop")
    main.Resize(920, 675)
    Need(main.hbm != oldBuffer && main.cw >= 920 && main.ch >= 675 && main.RenderNow(), "Larger sizes allocate and paint a fresh backing buffer")

    beforeTheme := Backdrop.cache["window"].key
    Theme.christmas := true
    Need(main.RenderNow() && Backdrop.cache["window"].key != beforeTheme, "Changing theme invalidates the previous colors")
    Store.settings["themeBackground"] := false
    Need(main.RenderNow(), "Background can still be disabled")
    base := Theme.C("base")
    bgr := ((base & 255) << 16) | (base & 0xFF00) | ((base >> 16) & 255)
    Need(Pixel(main, 300, 300) == bgr, "Disabled background paints the flat theme color")

    graphics := Gfx.G
    failed := false
    try Backdrop.Cached("broken", "fixture", 40, 40, RejectComposition)
    catch Error as e
        failed := e.Message == "fixture paint failed"
    Need(failed && !Backdrop.cache.Has("broken") && Gfx.G == graphics, "Failed composition leaves no cached frame or invalid graphics context")
    Backdrop.Dispose()
    Need(!Backdrop.image && !Backdrop.cache.Count, "All backdrop images are released")
    FileAppend(Format("PASS: backdrop alignment, resize, theme and cache ownership. Cached {1:.3f} ms vs direct {2:.3f} ms/frame.`n", cachedMs, directMs), "*")
} catch as e {
    FileAppend("FAIL: " e.Message " (" e.Line ")`n", "**")
    exitCode := 1
} finally {
    for s in surfaces
        s.Destroy()
    for g in guis
        g.Destroy()
    Backdrop.Dispose()
    if Gfx.token
        Gfx.Shutdown()
}
ExitApp(exitCode)
