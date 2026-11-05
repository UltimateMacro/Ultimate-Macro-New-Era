; Client-pixel geometry for every generated engine/tool. Original baseline stays untouched.
; No screen capture or input is performed by the pure scale/region helpers.
UM14_PhysicalDpi() {
    if (!DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr"))
        throw Error("Physical display coordinates are unavailable.")
}

UM14_Viewport(width, height) {
    return IsInteger(width) && IsInteger(height) && width >= 240 && height >= 240
        && width <= 8192 && height <= 8192 && width*height <= 33554432
}

UM14_Scale(value, extent, source) {
    if (!IsNumber(value) || !IsNumber(extent) || !IsNumber(source) || extent < 0 || source < 0)
        throw ValueError("Invalid coordinate dimensions.")
    result := Round(source ? value*extent/source : value)
    return (extent > 0 && source > 0 && value >= 0 && value < source) ? Min(extent-1, result) : result
}

UM14_WorldX(value, width, height, sourceWidth, sourceHeight) {
    if (!UM14_Viewport(width, height) || !IsNumber(value) || sourceWidth < 0 || sourceHeight < 0)
        throw ValueError("Invalid world-coordinate dimensions.")
    if !sourceWidth
        return value
    if !sourceHeight
        return UM14_Scale(value, width, sourceWidth)
    ; Roblox keeps vertical field of view when a window becomes tall/narrow.
    ; World points scale about the view centre with HEIGHT, unlike HUD pixels.
    return Round(width/2 + (value-sourceWidth/2)*height/sourceHeight)
}

UM14_PlacementRadius(multiplier, height) => Max(1, Round(5*Min(4, Max(1,multiplier))*height/1009))

UM14_Region(x, y, width, height, clientWidth, clientHeight) {
    if (!UM14_Viewport(clientWidth, clientHeight) || width < 0 || height < 0)
        return false
    left := Max(0, Floor(x)), top := Max(0, Floor(y))
    right := Min(clientWidth, Ceil(width ? x+width : clientWidth))
    bottom := Min(clientHeight, Ceil(height ? y+height : clientHeight))
    if (left >= right || top >= bottom)
        return false
    return {x:left, y:top, w:right-left, h:bottom-top}
}

UM14_ImageScales(height, minimum := 0.0, maximum := 0.0, step := 0.05) {
    if (height < 240 || height > 8192 || minimum < 0 || maximum < 0 || step <= 0)
        throw ValueError("Invalid image scale.")
    base := height/1009
    ; Keep explicit legacy ranges while including the actual current client scale.
    ; Bound scan density at large/ultrawide resolutions instead of a scan storm.
    low := Max(0.1, minimum ? Min(minimum, base*0.9) : base*0.9)
    high := Min(9.0, maximum ? Max(maximum, base*1.1) : base*1.1)
    ; TDS can retain original-size controls on small/windowed clients. Preserve
    ; the baseline's 1.05 coverage and put exactly 1.0 on the native scan grid.
    high := Max(high, 1.05)
    ; Reserve one interval for aligning the lower endpoint below.
    scanStep := Max(step, (high-low)/95)
    if (low <= 1.0 && high >= 1.0)
        low := Round(1.0-Ceil((1.0-low)/scanStep)*scanStep, 6)
    return {low:low, high:high, step:scanStep, nominal:base}
}

UM14_FallbackScales(base, minimum, maximum) {
    values := []
    ; Nine candidates maximum, nearest predicted scale first. No unbounded loop.
    for factor in [1.0, 0.975, 1.025, 0.95, 1.05, 0.9, 1.1] {
        value := Round(base*factor, 4)
        if (value >= minimum && value <= maximum)
            values.Push(value)
    }
    if (1.0 >= minimum && 1.0 <= maximum && Abs(base-1.0) > 0.0001)
        values.Push(1.0)
    return values
}

UM14_GdipSearch(templatePath, screenX, screenY, width, height, region, scales) {
    failure := {status:"error", message:"Image not found in the game client.", score:0}
    token := Gdip_Startup()
    if (!token)
        return failure
    haystack := 0, template := 0, resized := 0
    try {
        ; Screen origin is only for capture; returned centers are CLIENT pixels.
        haystack := Gdip_BitmapFromScreen(screenX "|" screenY "|" width "|" height)
        template := Gdip_CreateBitmapFromFile(templatePath)
        if (!haystack || !template)
            return failure
        Gdip_GetImageDimensions(template, &tw, &th)
        for scale in UM14_FallbackScales(scales.nominal, scales.low, scales.high) {
            sw := Max(1, Round(tw*scale)), sh := Max(1, Round(th*scale))
            if (sw > region.w || sh > region.h)
                continue
            resized := Gdip_ResizeBitmap(template, sw, sh, 7)
            if (!resized)
                continue
            output := ""
            try {
                found := Gdip_ImageSearch(haystack, resized, &output, region.x, region.y,
                    region.x+region.w, region.y+region.h, 40)
            } finally {
                Gdip_DisposeImage(resized)
                resized := 0
            }
            if (found > 0 && output != "") {
                xy := StrSplit(StrSplit(output, "`n")[1], ",")
                cx := Integer(xy[1])+sw//2, cy := Integer(xy[2])+sh//2
                if (cx < region.x || cy < region.y || cx >= region.x+region.w || cy >= region.y+region.h)
                    return failure
                return {status:"success", score:1.0, x:cx, y:cy, w:sw, h:sh,
                    scale:scale, message:"success (client-scaled GDI+ fallback)"}
            }
        }
        return failure
    } finally {
        if (resized)
            Gdip_DisposeImage(resized)
        if (template)
            Gdip_DisposeImage(template)
        if (haystack)
            Gdip_DisposeImage(haystack)
        Gdip_Shutdown(token)
    }
}
