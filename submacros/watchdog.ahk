#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

ListLines(False)
KeyHistory(0)

#MaxThreads 1

CoordMode("Mouse", "Client")
CoordMode("Pixel", "Client")

SetWorkingDir(A_ScriptDir "\..\")

#Include "%A_LineFile%\..\..\lib\ImageSearch\ImageSearch.ahk"
#Include "%A_LineFile%\..\..\lib\Gdip_All.ahk"
#Include "%A_LineFile%\..\..\lib\OCR.ahk"
#Include "%A_LineFile%\..\..\lib\Roblox.ahk"
#Include "%A_LineFile%\..\..\lib\RuntimeLog.ahk"

RuntimeLogInstall("Watchdog")
RuntimeLogInfo("watchdog_start", "Watchdog started")

Opt := A_AppData "\Ultimate_Macro\Options"
SettingsFile := Opt "\Settings.tds"
global BotSettings := Opt "\Discord-Bot-Settings.ini"
global StateFile := A_AppData "\Ultimate_Macro\state.ini"

global WebhookLink := IniRead(SettingsFile, "Webhook", "Link", "")
tWebhook := IniRead(SettingsFile, "Webhook", "Enabled", 0)
global WebhookEnabled := (tWebhook = 1) ? true : false
global SendCurrenciesEnabled := IniRead(SettingsFile, "Webhook", "SendCurrencies", 1)
global WebhookScreenshots := IniRead(SettingsFile, "Webhook", "WebhookScreenshots", 1)
global WebhookTriumphScreenshots := IniRead(SettingsFile, "Webhook", "WebhookTriumphScreenshots", 1)
global WebhookSepatateTriumphScreenshots := IniRead(SettingsFile, "Webhook", "WebhookSepatateTriumphScreenshots", 0)
global WebhookLink2 := IniRead(SettingsFile, "Webhook", "Link2", "")

global LegacyMode := IniRead(SettingsFile, "Options", "LegacyMode", 0)

global botEnabled := IniRead(BotSettings, "Settings", "Enabled", 0)

global ResourcesDir := A_WorkingDir "\Resources"
global TriumphImg1 := ResourcesDir "\triumph.png"
global TriumphImg2 := ResourcesDir "\PlayAgain.png"
global YouLostImg := ResourcesDir "\YouLost.png"
global ReviveIMG := ResourcesDir "\use_revive_ticket.png"
global RestartImg := ResourcesDir "\Restart.png"
global RestartImg2 := ResourcesDir "\Restart2.png"
global cancel := ResourcesDir "\cancel.png"

pToken := Gdip_Startup()

OnExit(CleanupGdip)

global ID := Random(0.0, 1.0)

if (A_Args.Length < 1) {
    MsgBox("You are not supposed to run it manually!")
    ExitApp()
}

MainPID := A_Args[1]

if (WebhookEnabled && WebhookLink != "" && WebhookScreenshots = "1") {
    screenshotDelay := Random(25000, 300000)
    SetTimer(TakeRandomScreenshot, screenshotDelay)
}

Sleep(15000)
loop 60 {
    if WinExist("Roblox ahk_exe RobloxPlayerBeta.exe")
        break
    if WinExist("Roblox ahk_exe ApplicationFrameHost.exe")
        break

    Sleep(500)
}
loopCounter := 0

loop {
    getRobloxPos(, , &w, &h)

    loopCounter++

    if (Mod(loopCounter, 15) == 0) {
        if !Integer(IniRead(StateFile, "State", "Running", 0)) {
            ExitApp()
        }
    }

    if WinExist("Roblox Crash") {
        RuntimeLogError("roblox_crash_detected", "Roblox Crash window detected")
        if (WebhookEnabled && WebhookLink != "") {
            pBitmap := CaptureRobloxClientBitmap()
            if (pBitmap) {
                SendScreenshot(pBitmap, "Roblox has crashed!")
                Gdip_DisposeImage(pBitmap)
            }
        }
        RestartMain()
        return
    }

    if !WinExist("Roblox ahk_exe RobloxPlayerBeta.exe") && !WinExist("Roblox ahk_exe ApplicationFrameHost.exe") {
        RuntimeLogError("roblox_process_missing", "Roblox process/window is no longer present")
        if (WebhookEnabled && WebhookLink != "")
            SendScreenshot(0, "Roblox is not running!", 12434877, 0)
        RestartMain()
        return
    }

    if (Mod(loopCounter, 3) == 0) {
        CoordMode("Pixel", "Screen")

        sw := A_ScreenWidth
        sh := A_ScreenHeight

        try {
            if ImageSearch(&FoundX, &FoundY, 0, 0, sw, sh, "*26 Resources/Disconnected.png") {
                RuntimeLogWarn("roblox_disconnect_detected", "Disconnected dialog detected", "template=Disconnected.png")
                CoordMode("Pixel", "Client")
                if (WebhookEnabled && WebhookLink != "") {
                    pBitmap := CaptureRobloxClientBitmap()
                    if (pBitmap) {
                        SendScreenshot(pBitmap, "Disconnected, rejoining")
                        Gdip_DisposeImage(pBitmap)
                    }
                }
                RestartMain()
                ExitApp()
            } else if ImageSearch(&FoundX, &FoundY, 0, 0, sw, sh, "*26 Resources/disconnected2.png") {
                RuntimeLogWarn("roblox_disconnect_detected", "Disconnected dialog detected", "template=disconnected2.png")
                CoordMode("Pixel", "Client")
                if (WebhookEnabled && WebhookLink != "") {
                    pBitmap := CaptureRobloxClientBitmap()
                    if (pBitmap) {
                        SendScreenshot(pBitmap, "Disconnected, rejoining")
                        Gdip_DisposeImage(pBitmap)
                    }
                }
                RestartMain()
                ExitApp()
            }
        } catch Error as err {
            RuntimeLogWarn("watchdog_image_search_error", err.Message)
            CoordMode("Pixel", "Client")
        }

        CoordMode("Pixel", "Client")
    }

    if (Mod(loopCounter, 2) == 0) {
        resTriumph1 := AdvancedImageSearch(TriumphImg1, w * 0.2, h * 0.2, w * 0.6, h * 0.7)

        if (resTriumph1.status == "success" && resTriumph1.score > 0.7) {
            if ((WebhookEnabled && WebhookLink != "") || botEnabled) {
                CloseMain()
                Sleep 1300
                SendInfo("Triumph")
            }
            RestartMain()
            ExitApp()
        }
    } else {
        resTriumph2 := AdvancedImageSearch(TriumphImg2, w * 0.2, h * 0.2, w * 0.6, h * 0.7)
        Sleep 200
        resLost := AdvancedImageSearch(YouLostImg, w * 0.2, h * 0.2, w * 0.6, h * 0.7)

        if (resTriumph2.status == "success" && resTriumph2.score > 0.7) {
            if ((WebhookEnabled && WebhookLink != "") || botEnabled) {
                CloseMain()
                Sleep 1300
                SendInfo("Triumph")
            }
            RestartMain()
            ExitApp()
        }

        if (resLost.status == "success" && resLost.score > 0.7) {
            if ((WebhookEnabled && WebhookLink != "") || botEnabled) {
                CloseMain()
                Sleep 1300
                SendInfo("Loss")
            }
            RestartMain()
            ExitApp()
        }
    }

    if (Mod(loopCounter, 6) == 0) {
        resRevive := AdvancedImageSearch(ReviveIMG, w * 0.2, h * 0.2, w * 0.6, h * 0.7)

        if (resRevive.status == "success" && resRevive.score > 0.7) {
            resCancel := AdvancedImageSearch(cancel, w * 0.2, h * 0.2, w * 0.6, h * 0.7)

            if (resCancel.status == "success" && resCancel.score > 0.7) {
                ActivateRoblox()
                Click(resCancel.x, resCancel.y)
            }
        }
    }
    Sleep(300)
}

sX(baseX, Width := 1920) {
    getRobloxPos(&pX, &pY, &currentWidth, &currentHeight)
    return Round(baseX * (currentWidth / Width))
}

sY(baseY, Height := 1009) {
    getRobloxPos(&pX, &pY, &currentWidth, &currentHeight)
    return Round(baseY * (currentHeight / Height))
}

SendInfo(matchResult := "") {
    global WebhookLink, StateFile, SendCurrenciesEnabled, WebhookEnabled, WebhookSepatateTriumphScreenshots,
        WebhookLink2

    if (WebhookSepatateTriumphScreenshots = 1 && WebhookLink2 != "") {
        WebhookLink := WebhookLink2
    }

    mapName := "Unknown"
    timeInSeconds := 0
    coinVal := 0
    gemVal := 0
    expVal := 0

    timeCompleted_T := IniRead(StateFile, "State", "TimeWhenStartedPlaying", "Failed")

    if (timeCompleted_T != "Failed") {
        ms := A_TickCount - timeCompleted_T

        total_seconds := ms // 1000
        timeInSeconds := total_seconds
        hours := total_seconds // 3600
        minutes := (total_seconds // 60) - (hours * 60)
        seconds := Mod(total_seconds, 60)

        timeCompleted := ""
        if (hours > 0)
            timeCompleted .= hours "h "
        if (minutes > 0 || hours > 0)
            timeCompleted .= minutes "m "
        timeCompleted .= seconds "s"
    } else {
        timeCompleted := "Failed"
        return
    }

    IniDelete(StateFile, "State", "TimeWhenStartedPlaying")

    getRobloxPos(&pX, &pY, &w, &h)

    MouseMove(Round(w * 0.5), Round(h * 0.1), 3)

    FoundX := 0
    FoundY := 0

    loop 3 {
        Play_Again := AdvancedImageSearch(TriumphImg2, w * 0.2, h * 0.2, w * 0.6, h * 0.7)
        Restart := AdvancedImageSearch(RestartImg, w * 0.2, h * 0.2, w * 0.6, h * 0.7)
        Restart2 := AdvancedImageSearch(RestartImg2, w * 0.2, h * 0.2, w * 0.6, h * 0.7)

        if (Play_Again.status = "success" && Play_Again.score > 0.7) {
            FoundX := Play_Again.x
            FoundY := Play_Again.y
            break
        } else if (Restart.status = "success" && Restart.score > 0.7) {
            FoundX := Restart.x
            FoundY := Restart.y
            break
        } else if (Restart2.status = "success" && Restart2.score > 0.7) {
            FoundX := Restart2.x
            FoundY := Restart2.y
            break
        }
        Sleep(500)
    }

    if (FoundX == 0 && FoundY == 0) {
        if (WebhookEnabled && WebhookLink != "") {
            pBitmap := CaptureRobloxClientBitmap()
            if (pBitmap) {
                headerTitle := (matchResult = "Triumph") ? "### :trophy: TRIUMPH!" : "### :skull: YOU LOST!"
                color := (matchResult = "Triumph") ? 3066993 : 12434877
                SendScreenshot(pBitmap, headerTitle, color)
                Gdip_DisposeImage(pBitmap)
            }
        }
        return
    }

    if (SendCurrenciesEnabled = "1") {
        targetX := FoundX - sX(180)
        targetY := FoundY - sY(250)
        AreaW := sX(340)
        AreaH := sY(230)

        ocrTarget := ""
        pBitmapArea := Gdip_BitmapFromScreen(targetX . "|" . targetY . "|" . AreaW . "|" . AreaH)
        if (pBitmapArea) {
            pBitmapResized := Gdip_CreateBitmap(AreaW * 3, AreaH * 3)
            if (pBitmapResized) {
                G1 := Gdip_GraphicsFromImage(pBitmapResized)
                if (G1) {
                    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", G1, "Int", 7)
                    Gdip_DrawImage(G1, pBitmapArea, 0, 0, AreaW * 3, AreaH * 3, 0, 0, AreaW, AreaH)
                    BinarizeTargetBitmap(pBitmapResized)
                    try ocrTarget := OCR.FromBitmap(pBitmapResized, { lang: "en-US" }).Text
                    Gdip_DeleteGraphics(G1)
                }
                Gdip_DisposeImage(pBitmapResized)
            }
            Gdip_DisposeImage(pBitmapArea)
        }

        infoX := FoundX + sX(200)
        infoY := FoundY - sY(350)
        InfoW := sX(320)
        InfoH := sY(240)

        ocrInfo := ""
        pBitmapInfo := Gdip_BitmapFromScreen(infoX . "|" . infoY . "|" . InfoW . "|" . InfoH)
        if (pBitmapInfo) {
            pBitmapInfoResized := Gdip_CreateBitmap(InfoW * 3, InfoH * 3)
            if (pBitmapInfoResized) {
                G2 := Gdip_GraphicsFromImage(pBitmapInfoResized)
                if (G2) {
                    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", G2, "Int", 7)
                    Gdip_DrawImage(G2, pBitmapInfo, 0, 0, InfoW * 3, InfoH * 3, 0, 0, InfoW, InfoH)
                    try ocrInfo := OCR.FromBitmap(pBitmapInfoResized, { lang: "en-US", scale: 1.5 }).Text
                    Gdip_DeleteGraphics(G2)
                }
                Gdip_DisposeImage(pBitmapInfoResized)
            }
            Gdip_DisposeImage(pBitmapInfo)
        }

        xpX := FoundX - sX(180)
        xpY := FoundY - sY(250)
        xpW := sX(340)
        xpH := sY(230)

        if RegExMatch(ocrTarget, "i)(\d[\d,]*)\s*c[o0]ins?", &coinsMatch)
            coinVal := Integer(StrReplace(coinsMatch[1], ",", ""))

        if RegExMatch(ocrTarget, "i)(\d[\d,]*)\s*(?:[g6c]\s*[e30c]ms?|[c]\s*[c]\s*ms?)", &gemsMatch)
            gemVal := Integer(StrReplace(gemsMatch[1], ",", ""))

        if RegExMatch(ocrTarget, "i)(?<![\+\d])(\d[\d,]*)\s*xp", &expMatch)
            expVal := Integer(StrReplace(expMatch[1], ",", ""))

        mapName := "Unknown"

        mapList := [
            "Abandoned City", "Area 52", "Autumn Falling",
            "Badlands II", "Black Spot Exchange", "Candy Valley", "Cataclysm", "Chess Board",
            "Construction Crazy", "Coral Deep", "Crossroads", "Crystal Cave",
            "Cyber City", "Dead Ahead", "Derelict Outpost", "Deserted Village", "Dusty Bridges",
            "Enchanted Forest", "Farm Lands", "Forest Camp", "Forgetten Docks", "Four Seasons",
            "Fungi Island", "Grass Isle", "Simplicity", "Happy Home of Robloxia", "Harbor", "Honey Valley",
            "Hot Spot", "Iceville", "Infernal Abyss", "Lay By", "Lighthaos", "Marshlands", "Mason Arch",
            "Medieval Times", "Meltdown",
            "Midnight Issue", "Moon Base", "Musaceae Kingdom", "Necropolis", "Nether", "Night Station",
            "Northern Lights", "Outskirts Commune", "Pier Pressure", "Pizza Party", "Polluted Wasteland II",
            "Portland", "Retro Crossroads", "Retro Lighthouse", "Retro Rocket Arena", "Retro Stained Temple",
            "Retro The Heights", "Retro Zone", "Rocket Arena", "Ruby Escort", "Sacred Mountains",
            "Sky Islands", "Space City", "Spring Fever", "Stained Temple", "Sugar Rush",
            "The Heavens", "The Heights", "Toyboard", "Tropical Industries", "Tropical Isles", "U-Turn",
            "Unknown Garden", "Winter Abyss", "Winter Bridges", "Winter Stronghold", "Wrecked Battlefield",
            "Wrecked Battlefield II", "Wretched Front"
        ]

        for currentMap in mapList {
            if InStr(ocrInfo, currentMap) {
                mapName := currentMap
                break
            }
        }

    }

    totalTriumphs := IniRead(StateFile, "State", "TotalTriumphs", 0)
    totalLosses := IniRead(StateFile, "State", "TotalLosses", 0)

    if (matchResult = "Triumph") {
        totalTriumphs += 1
        IniWrite(totalTriumphs, StateFile, "State", "TotalTriumphs")
    } else if (matchResult = "Loss") {
        totalLosses += 1
        IniWrite(totalLosses, StateFile, "State", "TotalLosses")
    }

    savedCoins := IniRead(StateFile, "State", "Coins", 0)
    savedGems := IniRead(StateFile, "State", "Gems", 0)
    savedExp := IniRead(StateFile, "State", "EXP", 0)
    savedTime := IniRead(StateFile, "State", "TotalTimeSeconds", 0)

    totalCoins := savedCoins + coinVal
    totalGems := savedGems + gemVal
    totalExp := savedExp + expVal
    totalTime := savedTime + timeInSeconds

    IniWrite(totalCoins, StateFile, "State", "Coins")
    IniWrite(totalGems, StateFile, "State", "Gems")
    IniWrite(totalExp, StateFile, "State", "EXP")
    IniWrite(totalTime, StateFile, "State", "TotalTimeSeconds")

    autorunStart := IniRead(StateFile, "State", "StartTime", 0)
    coinsPerHour := 0, gemsPerHour := 0, expPerHour := 0
    if (autorunStart > 0) {
        elapsedMs := A_TickCount - autorunStart
        elapsedHours := elapsedMs / 3600000
        if (elapsedHours > 0.001) {
            coinsPerHour := Round(totalCoins / elapsedHours)
            gemsPerHour := Round(totalGems / elapsedHours)
            expPerHour := Round(totalExp / elapsedHours)
        }
    }

    totalMatches := totalTriumphs + totalLosses
    winrate := (totalMatches > 0) ? Round((totalTriumphs / totalMatches) * 100) : 0
    wlRatio := (totalLosses > 0) ? Round(totalTriumphs / totalLosses, 1) : totalTriumphs
    wlRatioStr := StrReplace(String(wlRatio), ".", ",")

    avgTimeStr := "0s"
    if (totalMatches > 0 && totalTime > 0) {
        avgSeconds := Round(totalTime / totalMatches)
        avgMinutes := Floor(avgSeconds / 60)
        avgRemSeconds := Mod(avgSeconds, 60)
        avgTimeStr := (avgMinutes > 0) ? avgMinutes "m " avgRemSeconds "s" : avgRemSeconds "s"
    }

    description := ""
    color := 12434877

    if (matchResult = "Triumph") {
        description := "### :trophy: TRIUMPH!"
        color := 3066993
    } else {
        description := "### :skull: YOU LOST!"
        color := 0xFF322E
    }

    if (SendCurrenciesEnabled = "1") {
        description .= "`n"
        description .= "Map: **" mapName "**  Time Completed: **" timeCompleted "**`n"
        description .= "+" expVal " EXP (+" totalExp ")`n"
        description .= "+" coinVal " Coins (+" totalCoins ")  +" gemVal " Gems (+" totalGems ")`n"
        description .= "-# Total Matches: " totalMatches ", wins: " totalTriumphs ", losses: " totalLosses ", W/R: " winrate "%, W/L ratio: " wlRatioStr ", " coinsPerHour " coins/h, " gemsPerHour " gems/h, " expPerHour " exp/h, avg. time: " avgTimeStr
    }

    if (WebhookEnabled && WebhookLink != "") {
        pBitmap := CaptureRobloxClientBitmap()
        if (pBitmap) {
            SendScreenshot(pBitmap, description, color, WebhookTriumphScreenshots)
            Gdip_DisposeImage(pBitmap)
        }
    }
    if (WebhookLink = WebhookLink2) {
        WebhookLink := IniRead(SettingsFile, "Webhook", "Link", "")
    }
}

BinarizeTargetBitmap(pBitmap) {
    Gdip_GetImageDimensions(pBitmap, &w, &h)
    Rect := Buffer(16, 0)
    NumPut("int", 0, Rect, 0), NumPut("int", 0, Rect, 4)
    NumPut("int", w, Rect, 8), NumPut("int", h, Rect, 12)

    BitmapData := Buffer(A_PtrSize = 8 ? 32 : 24, 0)
    if DllCall("gdiplus\GdipBitmapLockBits", "Ptr", pBitmap, "Ptr", Rect, "UInt", 3, "Int", 0x26200A, "Ptr", BitmapData
    )
        return

    Scan0 := NumGet(BitmapData, A_PtrSize = 8 ? 16 : 12, "Ptr")
    Stride := NumGet(BitmapData, 8, "Int")

    loop h {
        y := A_Index - 1
        loop w {
            x := A_Index - 1
            offset := (y * Stride) + (x * 4)
            b := NumGet(Scan0 + offset, 0, "UChar")
            g := NumGet(Scan0 + offset, 1, "UChar")
            r := NumGet(Scan0 + offset, 2, "UChar")

            brightness := (r + g + b) / 3
            if (brightness > 200) {
                NumPut("UChar", 255, Scan0 + offset, 0)
                NumPut("UChar", 255, Scan0 + offset, 1)
                NumPut("UChar", 255, Scan0 + offset, 2)
            } else {
                NumPut("UChar", 0, Scan0 + offset, 0)
                NumPut("UChar", 0, Scan0 + offset, 1)
                NumPut("UChar", 0, Scan0 + offset, 2)
            }
        }
    }
    DllCall("gdiplus\GdipBitmapUnlockBits", "Ptr", pBitmap, "Ptr", BitmapData)
}

TakeRandomScreenshot() {
    global WebhookEnabled, WebhookLink
    if (!WebhookEnabled || WebhookLink = "")
        return

    if (WebhookLink = WebhookLink2)
        WebhookLink := IniRead(SettingsFile, "Webhook", "Link", "")

    pBitmap := CaptureRobloxClientBitmap()
    if (pBitmap > 0) {
        SendScreenshot(pBitmap, "Automatic screenshot", 3447003)
        Gdip_DisposeImage(pBitmap)
    }

    screenshotDelay := Random(180000, 360000)
    SetTimer(TakeRandomScreenshot, screenshotDelay)
}

SendScreenshot(pBitmap := CaptureRobloxClientBitmap(), description := "", color := 12434877, screenshot :=
WebhookScreenshots) {
    global WebhookLink

    escapedDescription := StrReplace(description, "\", "\\")
    escapedDescription := StrReplace(escapedDescription, '"', '\"')
    escapedDescription := StrReplace(escapedDescription, "`n", "\n")

    fields := []

    if (screenshot == "0" || screenshot == 0 || !pBitmap) {
        payload_json := '{"embeds": [{"description": "' escapedDescription '", "color": ' color '}]}'
        fields.Push(Map("name", "payload_json", "content-type", "application/json", "content", payload_json))
    }
    else {
        payload_json := '{"embeds": [{"description": "' escapedDescription '", "color": ' color ', "image": {"url": "attachment://screenshot.png"}}]}'
        fields.Push(Map("name", "payload_json", "content-type", "application/json", "content", payload_json))
        fields.Push(Map("name", "files[0]", "filename", "screenshot.png", "content-type", "image/png", "pBitmap",
            pBitmap))
    }

    CreateFormData(&postdata, &contentType, fields)

    MaxAttempts := 3
    loop MaxAttempts {
        try {
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("POST", WebhookLink "?wait=true", false)
            whr.SetRequestHeader("Content-Type", contentType)
            whr.SetTimeouts(90000, 60000, 60000, 60000)
            whr.Send(postdata)

            status := whr.Status
            if (status >= 200 && status < 300)
                return true

            if (status != 0 && status != 429 && status < 500)
                return false
        } catch as err {
        }

        if (A_Index < MaxAttempts)
            Sleep(2500)
    }

    return false
}

CreateFormData(&retData, &contentType, fields) {
    charArray := StrSplit("0123456789abcdefghijklmnopqrstuvwxyz")
    boundary := ""
    loop 12 {
        boundary .= charArray[Random(1, charArray.Length)]
    }

    hData := DllCall("GlobalAlloc", "UInt", 0x2, "UPtr", 0, "Ptr")
    DllCall("ole32\CreateStreamOnHGlobal", "Ptr", hData, "Int", 0, "PtrP", &pStream := 0, "UInt")

    for index, field in fields {
        str := "`r`n------------------------------" boundary "`r`n"
        str .= 'Content-Disposition: form-data; name="' field["name"] '"'

        if field.Has("filename")
            str .= '; filename="' field["filename"] '"'

        str .= "`r`n"
        str .= "Content-Type: " field["content-type"] "`r`n`r`n"

        if field.Has("content")
            str .= field["content"] "`r`n"

        length := StrPut(str, "UTF-8") - 1
        utf8 := Buffer(length)
        StrPut(str, utf8, "UTF-8")
        DllCall("shlwapi\IStream_Write", "Ptr", pStream, "Ptr", utf8.Ptr, "UInt", length, "UInt")

        if field.Has("pBitmap") {
            try {
                pFileStream := Gdip_SaveBitmapToStream(field["pBitmap"])
                DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", &size := 0, "UInt")
                DllCall("shlwapi\IStream_Reset", "Ptr", pFileStream, "UInt")
                DllCall("shlwapi\IStream_Copy", "Ptr", pFileStream, "Ptr", pStream, "UInt", size, "UInt")
                ObjRelease(pFileStream)
            }
        }
    }

    str := "`r`n------------------------------" boundary "--`r`n"
    length := StrPut(str, "UTF-8") - 1
    utf8 := Buffer(length)
    StrPut(str, utf8, "UTF-8")
    DllCall("shlwapi\IStream_Write", "Ptr", pStream, "Ptr", utf8.Ptr, "UInt", length, "UInt")

    ObjRelease(pStream)
    pStream := 0

    pData := DllCall("GlobalLock", "Ptr", hData, "Ptr")
    size := DllCall("GlobalSize", "Ptr", hData, "UPtr")

    retData := ComObjArray(0x11, size)
    pvData := NumGet(ComObjValue(retData), 8 + A_PtrSize, "Ptr")
    DllCall("RtlMoveMemory", "Ptr", pvData, "Ptr", pData, "Ptr", size)

    DllCall("GlobalUnlock", "Ptr", hData)
    DllCall("GlobalFree", "Ptr", hData, "Ptr")

    contentType := "multipart/form-data; boundary=----------------------------" boundary
}

CloseMain() {
    global MainPID

    ; The watchdog may only close the exact parent process that launched it.
    if (MainPID && ProcessExist(MainPID))
        try ProcessClose(MainPID)
}

RestartMain() {
    RuntimeLogInfo("watchdog_restart_main", "Restarting Main after watchdog recovery event")
    global MainPID, SettingsFile, WebhookLink, WebhookEnabled

    if (MainPID && ProcessExist(MainPID))
        try ProcessClose(MainPID)

    WebhookLink := IniRead(SettingsFile, "Webhook", "Link", "")
    tempWebhook := IniRead(SettingsFile, "Webhook", "Enabled", "OFF")
    WebhookEnabled := (tempWebhook = "1") ? true : false

    if (A_PtrSize == 4)
        Run('"' A_WorkingDir '\submacros\AutoHotkey32.exe" "' A_WorkingDir '\Main.ahk"')
    else
        Run('"' A_WorkingDir '\submacros\AutoHotkey64.exe" "' A_WorkingDir '\Main.ahk"')

    ExitApp()
}

CleanupGdip(exitReason, exitCode) {
    global pToken
    Gdip_Shutdown(pToken)
}

AdvancedImageSearch(templ, x, y, w, h, minScale := 0.0, maxScale := 0.0, scaleStep := 0.05) {
    if (LegacyMode) {
        nx := 0
        ny := 0

        score := ImageSearch(&nx, &ny, x, y, x + w, y + h, "*80 " templ)

        status := "failed"

        if score == 1
            status := "success"

        return { score: score, x: nx, y: ny, message: " ", status: status }
    } else {
        return AdvImageSearch(templ, x, y, w, h, minScale, maxScale, scaleStep)
    }
}
