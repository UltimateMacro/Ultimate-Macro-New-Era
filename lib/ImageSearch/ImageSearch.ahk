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

    if !WinExist("ahk_exe RobloxPlayerBeta.exe")
        return {status: "error", message: "Roblox window not found", score: 0}

    WinGetClientPos(&xC, &yC, &widthC, &heightC, "ahk_exe RobloxPlayerBeta.exe")

    baseScale := heightC / 1009

    if (maxScale == 0.0) {
        maxScale := baseScale + 0.1
    }

    if (minScale == 0.0) {
        minScale := baseScale - 0.1
    }
    
    if (maxScale == 0.0 && minScale == 0.0) {
        scaleStep := 0.025
    }
    
    if (maxScale <= 1.0) {
        maxScale := 1.05
    }

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
            
            if ((status == 1 || status == 2) && score >= 0.0) {
                return {
                    status: "success", 
                    score: Round(Float(score), 4), 
                    x: Integer(x), 
                    y: Integer(y), 
                    w: Integer(w), 
                    h: Integer(h), 
                    scale: Round(Float(scale), 4), 
                    message: "success"
                }
            } else if (status == 3 || status == 4) {
                return {
                    status: "success", 
                    score: Round(Float(score), 4), 
                    x: Integer(x), 
                    y: Integer(y), 
                    w: Integer(w), 
                    h: Integer(h), 
                    scale: Round(Float(scale), 4), 
                    message: "success"
                }
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
    
    ; GDI+ Fallback
    if (useFallback) {
        pToken := Gdip_Startup()
        if (!pToken)
            return {status: "error", message: "GDI+ failed to start", score: 0}

        getRobloxPos(&xC, &yC, &widthC, &heightC)
            
        pBitmapHaystack := Gdip_BitmapFromScreen(xC "|" yC "|" widthC "|" heightC)
        pBitmapTemplate := Gdip_CreateBitmapFromFile(templatePath)
        
        if (!pBitmapHaystack || !pBitmapTemplate) {
            Gdip_DisposeImage(pBitmapHaystack)
            Gdip_DisposeImage(pBitmapTemplate)
            Gdip_Shutdown(pToken)
            return {status: "error", message: "GDI+ failed to load images", score: 0}
        }
        
        Gdip_GetImageDimensions(pBitmapTemplate, &tW, &tH)
        
        searchX1 := ax
        searchY1 := ay
        searchX2 := (aw == 0) ? widthC : (ax + aw)
        searchY2 := (ah == 0) ? heightC : (ay + ah)
        
        bestResult := {
            status: "error", 
            message: "image not found via gdip (gdip used as dll call fallback)", 
            score: 0
        }
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
            sX := Integer(firstMatch[1])
            sY := Integer(firstMatch[2])
            
            centerX := sX + Integer(tW / 2)
            centerY := sY + Integer(tH / 2)
            
            bestResult := {
                status: "success",
                score: 1.0,
                x: Integer(xC + centerX),
                y: Integer(yC + centerY),
                w: Integer(tW),
                h: Integer(tH),
                scale: 1.0,
                message: "success (Gdip fallback)"
            }
        }
        
        Gdip_DisposeImage(pBitmapHaystack)
        Gdip_DisposeImage(pBitmapTemplate)
        Gdip_Shutdown(pToken)
        
        return bestResult
    }
    
    return {status: "error", message: "Unknown error occurred", score: 0}
}