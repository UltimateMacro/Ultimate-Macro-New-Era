#Requires AutoHotkey v2.0

#Include %A_LineFile%/../../Gdip_All.ahk
#Include %A_LineFile%/../../Gdip_ImageSearch.ahk
#Include %A_LineFile%/../../Roblox.ahk

; this library is for ImageSearch. it uses image_search.dll, which utilizes opencv to search for images and return a score. this dll and this lib make it possible to support any screen resolution.
; also, If the dll call fails, it falls back to Gdip_ImageSearch.
AdvImageSearch(templatePath, ax := 0, ay := 0, aw := 0, ah := 0, minScale := 0.0, maxScale := 0.0, scaleStep := 0.05) {
    static hOpenCV := 0
    static hModule := 0
    static isInitialized := false
    static useFallback := false

    if (!isInitialized) {
        SplitPath(A_LineFile, , &dir)
        opencvPath := dir "\opencv_world500.dll"
        dllPath := dir "\image_search.dll"

        if (!FileExist(opencvPath) || !FileExist(dllPath)) {
            useFallback := true
        } else {
            DllCall("Kernel32.dll\SetDllDirectory", "Str", dir)
            
            hOpenCV := DllCall("LoadLibrary", "Str", opencvPath, "Ptr")
            hModule := DllCall("LoadLibrary", "Str", dllPath, "Ptr")
            
            DllCall("Kernel32.dll\SetDllDirectory", "Ptr", 0)
            
            if (!hOpenCV || !hModule) {
                useFallback := true
                if (hOpenCV) {
                    DllCall("FreeLibrary", "Ptr", hOpenCV)
                    hOpenCV := 0
                }
                if (hModule) {
                    DllCall("FreeLibrary", "Ptr", hModule)
                    hModule := 0
                }
            }
        }
        isInitialized := true
    }

    UM14_PhysicalDpi()
    hwnd := GetRobloxHWND()
    if (!hwnd)
        return {status:"error", message:"Roblox window not found", score:0}
    WinGetClientPos(&xC, &yC, &widthC, &heightC, "ahk_id " hwnd)
    region := UM14_Region(ax, ay, aw, ah, widthC, heightC)
    if (!region)
        return {status:"error", message:"Search region is outside the game client", score:0}
    ax := region.x, ay := region.y, aw := region.w, ah := region.h
    scales := UM14_ImageScales(heightC, minScale, maxScale, scaleStep)
    minScale := scales.low, maxScale := scales.high, scaleStep := scales.step

    if (!useFallback) {
        structResult := Buffer(28, 0) 

        try {
            DllCall("image_search.dll\AdvancedImageSearch", 
                "AStr", templatePath, 
                "Int", xC, "Int", yC, "Int", widthC, "Int", heightC,
                "Int", ax, "Int", ay, "Int", aw, "Int", ah,
                "Float", Float(minScale), "Float", Float(maxScale), "Float", Float(scaleStep),
                "Ptr", structResult,
                "Cdecl")
                
            status := NumGet(structResult, 0, "Int")
            score  := NumGet(structResult, 4, "Float")
            x      := NumGet(structResult, 8, "Int")
            y      := NumGet(structResult, 12, "Int")
            w      := NumGet(structResult, 16, "Int")
            h      := NumGet(structResult, 20, "Int")
            scale  := NumGet(structResult, 24, "Float")
            
            validStatus := status >= 1 && status <= 4
            validMatch := validStatus && score >= 0.0 && score <= 1.0001
                && x >= ax && x < ax+aw && y >= ay && y < ay+ah && w > 0 && h > 0
            if validMatch {
                return {
                    status: "success", 
                    score: Min(1,Round(Float(score), 4)), 
                    x: Integer(x), 
                    y: Integer(y), 
                    w: Integer(w), 
                    h: Integer(h), 
                    scale: Round(Float(scale), 4), 
                    message: "success"
                }
            } else if validStatus {
                ; A native success code without usable confidence or client
                ; geometry is not a match. Try the bounded pixel matcher.
                return UM14_GdipSearch(templatePath, xC, yC, widthC, heightC, region, scales)
            } else {
                errMsg := "error! code: " status
                return {status: "error", code: status, message: errMsg, score: score}
            }
            
        } catch Error as err {
            useFallback := true
            if (hOpenCV) {
                DllCall("FreeLibrary", "Ptr", hOpenCV)
                hOpenCV := 0
            }
            if (hModule) {
                DllCall("FreeLibrary", "Ptr", hModule)
                hModule := 0
            }
        }
    }
    
    ; Bounded, resolution-aware GDI+ fallback; native and fallback return client pixels.
    if (useFallback) {
        try
            return UM14_GdipSearch(templatePath, xC, yC, widthC, heightC, region, scales)
        catch
            return {status:"error", message:"Client image fallback failed", score:0}
    }

    return {status: "error", message: "Unknown error occurred", score: 0}
}
