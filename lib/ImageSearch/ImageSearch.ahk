#Requires AutoHotkey v2.0

#Include %A_LineFile%/../../Gdip_All.ahk
#Include %A_LineFile%/../../Gdip_ImageSearch.ahk
#Include %A_LineFile%/../../Roblox.ahk

; Advanced image search wrapper.
; Contract: returned x/y coordinates are Roblox CLIENT coordinates so callers can
; use them directly while CoordMode("Mouse", "Client") is active.

global ImageSearchBackendState := {
    initialized: false,
    backend: "uninitialized",
    reason: "not initialized",
    nativeAvailable: false
}

GetImageSearchBackendInfo() {
    global ImageSearchBackendState
    return {
        initialized: ImageSearchBackendState.initialized,
        backend: ImageSearchBackendState.backend,
        reason: ImageSearchBackendState.reason,
        nativeAvailable: ImageSearchBackendState.nativeAvailable
    }
}

; Resolve the image-search backend once. Native OpenCV is optional: when it
; is unavailable the portable GDI+ fallback below performs bounded multi-scale
; matching and preserves the same CLIENT-coordinate contract.
EnsureImageSearchBackend() {
    global ImageSearchBackendState
    static isInitialized := false
    static hOpenCV := 0
    static hModule := 0

    if isInitialized
        return ImageSearchBackendState.nativeAvailable

    SplitPath(A_LineFile, , &dir)
    opencvPath := dir "\opencv_world500.dll"
    dllPath := dir "\image_search.dll"

    if !FileExist(dllPath) {
        ImageSearchBackendState.backend := "GDI+ fallback"
        ImageSearchBackendState.reason := "image_search.dll is missing"
    } else if !FileExist(opencvPath) {
        ImageSearchBackendState.backend := "GDI+ fallback"
        ImageSearchBackendState.reason := "opencv_world500.dll is missing"
    } else {
        try {
            DllCall("Kernel32.dll\SetDllDirectoryW", "Str", dir)
            hOpenCV := DllCall("Kernel32.dll\LoadLibraryW", "Str", opencvPath, "Ptr")
            hModule := DllCall("Kernel32.dll\LoadLibraryW", "Str", dllPath, "Ptr")
        } finally {
            DllCall("Kernel32.dll\SetDllDirectoryW", "Ptr", 0)
        }

        if (!hOpenCV || !hModule) {
            if hOpenCV {
                DllCall("Kernel32.dll\FreeLibrary", "Ptr", hOpenCV)
                hOpenCV := 0
            }
            if hModule {
                DllCall("Kernel32.dll\FreeLibrary", "Ptr", hModule)
                hModule := 0
            }
            ImageSearchBackendState.backend := "GDI+ fallback"
            ImageSearchBackendState.reason := "native image-search dependencies failed to load"
        } else {
            ImageSearchBackendState.backend := "OpenCV native"
            ImageSearchBackendState.reason := "native dependencies loaded"
            ImageSearchBackendState.nativeAvailable := true
        }
    }

    ImageSearchBackendState.initialized := true
    isInitialized := true
    return ImageSearchBackendState.nativeAvailable
}

AdvImageSearch(templatePath, ax := 0, ay := 0, aw := 0, ah := 0, minScale := 0.0, maxScale := 0.0, scaleStep := 0.05) {
    global ImageSearchBackendState

    EnsureImageSearchBackend()
    useFallback := !ImageSearchBackendState.nativeAvailable

    hwnd := GetRobloxHWND()
    if !hwnd
        return ImageSearchError("Roblox window not found")

    if !GetRobloxScreenClientRect(&screenX, &screenY, &widthC, &heightC, hwnd)
        return ImageSearchError("Unable to resolve Roblox client rectangle")

    if !FileExist(templatePath)
        return ImageSearchError("Template not found: " templatePath)

    baseScale := heightC / 1009

    if (maxScale == 0.0)
        maxScale := baseScale + 0.1
    if (minScale == 0.0)
        minScale := Max(0.1, baseScale - 0.1)
    if (maxScale <= 1.0)
        maxScale := 1.05

    if (!useFallback) {
        structResult := Buffer(28, 0)

        try {
            DllCall("image_search.dll\AdvancedImageSearch",
                "AStr", templatePath,
                "Int", screenX, "Int", screenY, "Int", widthC, "Int", heightC,
                "Int", ax, "Int", ay, "Int", aw, "Int", ah,
                "Float", Float(minScale), "Float", Float(maxScale), "Float", Float(scaleStep),
                "Ptr", structResult,
                "Cdecl")

            status := NumGet(structResult, 0, "Int")
            score := NumGet(structResult, 4, "Float")
            x := NumGet(structResult, 8, "Int")
            y := NumGet(structResult, 12, "Int")
            w := NumGet(structResult, 16, "Int")
            h := NumGet(structResult, 20, "Int")
            scale := NumGet(structResult, 24, "Float")

            if ((status >= 1 && status <= 4) && score >= 0.0) {
                ; The native DLL historically returns coordinates relative to the
                ; searched Roblox client. Keep that established contract here.
                return {
                    status: "success",
                    score: Round(Float(score), 4),
                    x: Integer(x),
                    y: Integer(y),
                    w: Integer(w),
                    h: Integer(h),
                    scale: Round(Float(scale), 4),
                    backend: "OpenCV native",
                    degraded: false,
                    scoreKind: "confidence",
                    message: "success"
                }
            }

            return ImageSearchError("Native image search returned code " status, score)
        } catch Error as err {
            ; Demote to the fallback for the rest of the session. The loaded
            ; modules are intentionally left mapped: another thread may still be
            ; inside a native call, and unloading underneath it would crash.
            useFallback := true
            ImageSearchBackendState.backend := "GDI+ fallback"
            ImageSearchBackendState.reason := "native call failed: " err.Message
            ImageSearchBackendState.nativeAvailable := false
        }
    }

    ; GDI+ fallback. Capture must use SCREEN coordinates, while the returned
    ; match coordinates must remain CLIENT-relative for all callers.
    pToken := Gdip_Startup()
    if !pToken
        return ImageSearchError("GDI+ failed to start")

    pBitmapHaystack := 0
    pBitmapTemplate := 0
    try {
        pBitmapHaystack := Gdip_BitmapFromScreen(screenX "|" screenY "|" widthC "|" heightC)
        pBitmapTemplate := Gdip_CreateBitmapFromFile(templatePath)

        if (!pBitmapHaystack || !pBitmapTemplate)
            return ImageSearchError("GDI+ failed to load capture/template")

        Gdip_GetImageDimensions(pBitmapTemplate, &tW, &tH)

        searchX1 := Max(0, ax)
        searchY1 := Max(0, ay)
        searchX2 := (aw == 0) ? widthC : Min(widthC, ax + aw)
        searchY2 := (ah == 0) ? heightC : Min(heightC, ay + ah)

        if (searchX2 <= searchX1 || searchY2 <= searchY1)
            return ImageSearchError("Invalid image-search bounds")

        ; The portable fallback must honor the scale contract used by callers.
        ; Search the current-client scale first, then nearby fractional scales
        ; in distance order; canonical 1.0 is retained when it is in range.
        ; This keeps common sizes usable without an 80 MB optional binary.
        scaleCandidates := BuildImageSearchScaleCandidates(baseScale, minScale, maxScale, scaleStep)

        for candidateScale in scaleCandidates {
            scaledW := Max(1, Round(tW * candidateScale))
            scaledH := Max(1, Round(tH * candidateScale))
            if (scaledW > searchX2 - searchX1 || scaledH > searchY2 - searchY1)
                continue

            pCandidate := pBitmapTemplate
            disposeCandidate := false

            if (scaledW != tW || scaledH != tH) {
                pCandidate := Gdip_ResizeBitmap(pBitmapTemplate, scaledW, scaledH, 7)
                if !pCandidate
                    continue
                disposeCandidate := true
            }

            outputList := ""
            result := 0
            try {
                result := Gdip_ImageSearch(
                    pBitmapHaystack,
                    pCandidate,
                    &outputList,
                    searchX1,
                    searchY1,
                    searchX2,
                    searchY2,
                    40
                )
            } finally {
                if disposeCandidate
                    Gdip_DisposeImage(pCandidate)
            }

            if (result > 0 && outputList != "") {
                firstMatch := StrSplit(StrSplit(outputList, "`n")[1], ",")
                matchX := Integer(firstMatch[1])
                matchY := Integer(firstMatch[2])
                centerX := matchX + Integer(scaledW / 2)
                centerY := matchY + Integer(scaledH / 2)

                return {
                    status: "success",
                    score: 1.0,
                    x: centerX,
                    y: centerY,
                    w: Integer(scaledW),
                    h: Integer(scaledH),
                    scale: candidateScale,
                    backend: "GDI+ fallback",
                    degraded: true,
                    scoreKind: "binary",
                    message: "success (GDI+ fallback)"
                }
            }
        }

        return ImageSearchError("image not found via multi-scale GDI+ fallback")
    } finally {
        if pBitmapHaystack
            Gdip_DisposeImage(pBitmapHaystack)
        if pBitmapTemplate
            Gdip_DisposeImage(pBitmapTemplate)
        Gdip_Shutdown(pToken)
    }
}

BuildImageSearchScaleCandidates(baseScale, minScale, maxScale, scaleStep) {
    if (scaleStep <= 0)
        scaleStep := 0.05

    minScale := Max(0.1, minScale)
    maxScale := Max(minScale, maxScale)
    preferred := Min(maxScale, Max(minScale, baseScale))
    scales := []

    ; Gdip_ImageSearch is comparatively expensive: each distinct scale can
    ; resize the template and scan the whole requested region. Keep one small
    ; total candidate budget, ordered outward from the current client scale.
    maxCandidates := 12
    maxOffsetSteps := 10
    AddImageSearchScaleCandidate(scales, preferred)

    offset := scaleStep
    loop maxOffsetSteps {
        ; Reserve the final slot for canonical 1.0 when it is in range.
        if (scales.Length >= maxCandidates - 1)
            break

        lower := preferred - offset
        upper := preferred + offset
        added := false

        if (lower >= minScale) {
            AddImageSearchScaleCandidate(scales, lower)
            added := true
        }
        if (scales.Length < maxCandidates - 1 && upper <= maxScale) {
            AddImageSearchScaleCandidate(scales, upper)
            added := true
        }
        if (!added && lower < minScale && upper > maxScale)
            break
        offset += scaleStep
    }

    if (1.0 >= minScale && 1.0 <= maxScale)
        AddImageSearchScaleCandidate(scales, 1.0)
    return scales
}

AddImageSearchScaleCandidate(scales, value) {
    normalized := Round(value, 4)
    for existing in scales {
        if (Abs(existing - normalized) < 0.005)
            return
    }
    scales.Push(normalized)
}

ImageSearchError(message, score := 0) {
    global ImageSearchBackendState
    return {
        status: "error",
        message: message,
        score: score,
        backend: ImageSearchBackendState.backend,
        degraded: (ImageSearchBackendState.backend = "GDI+ fallback"),
        scoreKind: (ImageSearchBackendState.backend = "GDI+ fallback") ? "binary" : "confidence"
    }
}
