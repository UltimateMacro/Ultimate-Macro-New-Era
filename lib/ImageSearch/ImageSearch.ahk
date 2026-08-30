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

AdvImageSearch(templatePath, ax := 0, ay := 0, aw := 0, ah := 0, minScale := 0.0, maxScale := 0.0, scaleStep := 0.05) {
    global ImageSearchBackendState
    static hOpenCV := 0
    static hModule := 0
    static isInitialized := false
    static useFallback := false

    if (!isInitialized) {
        SplitPath(A_LineFile, , &dir)
        opencvPath := dir "\opencv_world500.dll"
        dllPath := dir "\image_search.dll"

        if !FileExist(dllPath) {
            useFallback := true
            ImageSearchBackendState.backend := "GDI+ fallback"
            ImageSearchBackendState.reason := "image_search.dll is missing"
        } else if !FileExist(opencvPath) {
            useFallback := true
            ImageSearchBackendState.backend := "GDI+ fallback"
            ImageSearchBackendState.reason := "opencv_world500.dll is missing"
        } else {
            oldDllDir := ""
            try {
                DllCall("Kernel32.dll\SetDllDirectory", "Str", dir)
                hOpenCV := DllCall("Kernel32.dll\LoadLibraryW", "Str", opencvPath, "Ptr")
                hModule := DllCall("Kernel32.dll\LoadLibraryW", "Str", dllPath, "Ptr")
            } finally {
                DllCall("Kernel32.dll\SetDllDirectoryW", "Ptr", 0)
            }

            if (!hOpenCV || !hModule) {
                useFallback := true
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
    }

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
                ; JoinGame requires >= 0.67 for SpecialMode.png. A weak native
                ; match is therefore still a miss for that flow; scroll the new
                ; vertically-scrollable Play menu and let its existing loop retry.
                if (IsSpecialModeTemplate(templatePath) && score < 0.67) {
                    if MaybeScrollSpecialModeSearch(templatePath, widthC, heightC)
                        return ImageSearchError("special-mode menu scrolled; retrying", score)
                }

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
                    message: "success"
                }
            }

            if MaybeScrollSpecialModeSearch(templatePath, widthC, heightC)
                return ImageSearchError("special-mode menu scrolled; retrying", score)

            return ImageSearchError("Native image search returned code " status, score)
        } catch Error as err {
            useFallback := true
            ImageSearchBackendState.backend := "GDI+ fallback"
            ImageSearchBackendState.reason := "native call failed: " err.Message
            ImageSearchBackendState.nativeAvailable := false

            if hOpenCV {
                DllCall("Kernel32.dll\FreeLibrary", "Ptr", hOpenCV)
                hOpenCV := 0
            }
            if hModule {
                DllCall("Kernel32.dll\FreeLibrary", "Ptr", hModule)
                hModule := 0
            }
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

        outputList := ""
        result := Gdip_ImageSearch(
            pBitmapHaystack,
            pBitmapTemplate,
            &outputList,
            searchX1,
            searchY1,
            searchX2,
            searchY2,
            40
        )

        if (result > 0 && outputList != "") {
            firstMatch := StrSplit(StrSplit(outputList, "`n")[1], ",")
            matchX := Integer(firstMatch[1])
            matchY := Integer(firstMatch[2])
            centerX := matchX + Integer(tW / 2)
            centerY := matchY + Integer(tH / 2)

            return {
                status: "success",
                score: 1.0,
                x: centerX,
                y: centerY,
                w: Integer(tW),
                h: Integer(tH),
                scale: 1.0,
                backend: "GDI+ fallback",
                message: "success (GDI+ fallback)"
            }
        }

        if MaybeScrollSpecialModeSearch(templatePath, widthC, heightC)
            return ImageSearchError("special-mode menu scrolled; retrying")

        return ImageSearchError("image not found via GDI+ fallback")
    } finally {
        if pBitmapHaystack
            Gdip_DisposeImage(pBitmapHaystack)
        if pBitmapTemplate
            Gdip_DisposeImage(pBitmapTemplate)
        Gdip_Shutdown(pToken)
    }
}

IsSpecialModeTemplate(templatePath) {
    SplitPath(templatePath, &templateName)
    return (templateName = "SpecialMode.png")
}

MaybeScrollSpecialModeSearch(templatePath, clientWidth, clientHeight) {
    ; TDS' current Play/Survival UI is vertically scrollable. In older layouts the
    ; Special Mode entry was visible immediately, so JoinGame() only searched the
    ; current viewport. If the template is not visible, gently scroll the menu and
    ; let the caller's existing retry loop search again. This is deliberately
    ; limited to SpecialMode.png so normal gameplay/image searches are unaffected.
    static lastScrollTick := 0
    static scrollAttempts := 0
    static previousTemplate := ""

    SplitPath(templatePath, &templateName)

    if (templateName != previousTemplate) {
        if (templateName != "SpecialMode.png")
            scrollAttempts := 0
        previousTemplate := templateName
    }

    if (templateName != "SpecialMode.png")
        return false

    if (A_TickCount - lastScrollTick < 650)
        return false

    if (scrollAttempts >= 10)
        return false

    try {
        ActivateRoblox()
        MouseMove(Round(clientWidth * 0.78), Round(clientHeight * 0.78), 0)
        SendEvent("{WheelDown 4}")
        lastScrollTick := A_TickCount
        scrollAttempts++
        return true
    } catch {
        return false
    }
}

ImageSearchError(message, score := 0) {
    global ImageSearchBackendState
    return {
        status: "error",
        message: message,
        score: score,
        backend: ImageSearchBackendState.backend
    }
}