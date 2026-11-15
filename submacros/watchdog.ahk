; TDS Macro Watchdog - Optimized OCR & GDI+
#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
#Include "%A_LineFile%\..\..\app\Lifecycle.ahk"

ListLines(False)
KeyHistory(0)

#MaxThreads 1

CoordMode("Mouse", "Client")
CoordMode("Pixel", "Client")

SetWorkingDir(A_ScriptDir "\..\")

#Include  "%A_LineFile%\..\..\lib\ImageSearch\ImageSearch.ahk"
#Include "%A_LineFile%\..\..\lib\Gdip_All.ahk"
#Include "%A_LineFile%\..\..\lib\OCR.ahk"
#Include "%A_LineFile%\..\..\lib\Roblox.ahk"
#Include "%A_LineFile%\..\..\lib\JSON.ahk"
#Include "%A_LineFile%\..\..\app\DashboardMatch.ahk"
#Include "%A_LineFile%\..\..\lib\RobloxMemory.ahk"

Opt := A_AppData "\Ultimate_Macro\Options"
SettingsFile := Opt "\Settings.tds"
global StateFile := A_AppData "\Ultimate_Macro\state.ini"

global WebhookLink := IniRead(SettingsFile, "Webhook", "Link", "")
global WebhookLink2 := IniRead(SettingsFile, "Webhook", "Link2", "")
tWebhook := IniRead(SettingsFile, "Webhook", "Enabled", 0)
global WebhookEnabled := (tWebhook = 1) ? true : false
global SendCurrenciesEnabled := IniRead(SettingsFile, "Webhook", "SendCurrencies", 1)
global WebhookScreenshots := IniRead(SettingsFile, "Webhook", "WebhookScreenshots", 1)
global WebhookTriumphScreenshots := IniRead(SettingsFile, "Webhook", "WebhookTriumphScreenshots", 1)
global WebhookSepatateTriumphScreenshots := Integer(IniRead(SettingsFile, "Webhook", "WebhookSepatateTriumphScreenshots", 0))
global WebhookUserID := IniRead(SettingsFile, "Webhook", "WebhookUserID", "")
global PingOnWin := Integer(IniRead(SettingsFile, "Webhook", "PingOnWin", 0))
global PingOnLoss := Integer(IniRead(SettingsFile, "Webhook", "PingOnLoss", 0))
global WebhookDebugLogs := IniRead(SettingsFile, "Webhook", "WebhookDebugLogs", "1")

GetDiscordMention(rawId) {
    if (rawId = "" || Trim(rawId) = "")
        return ""
    cleanId := RegExReplace(Trim(rawId), "[<@!>]", "")
    cleanId := Trim(cleanId)
    if (cleanId = "" || !RegExMatch(cleanId, "^\d+$"))
        return ""
    return "<@" cleanId ">"
}

global LegacyMode := IniRead(SettingsFile, "Options", "LegacyMode", 0)

global ResourcesDir := A_WorkingDir "\Resources"
global TriumphImg1 := ResourcesDir "\triumph.png"
global TriumphImg2 := ResourcesDir "\PlayAgain.png"
global YouLostImg := ResourcesDir "\YouLost.png"
global ReviveIMG := ResourcesDir "\use_revive_ticket.png"
global RestartImg := ResourcesDir "\Restart.png"
global RestartImg2 := ResourcesDir "\Restart2.png"
global cancel := ResourcesDir "\cancel.png"
global CoinsImg := ResourcesDir "\coins.png"
global GemImg := ResourcesDir "\gem.png"
global XpImg := ResourcesDir "\xp.png"

pToken := Gdip_Startup()

OnExit(CleanupGdip)
 

global ID := Random(0.0, 1.0)

if (A_Args.Length < 1) {
    MsgBox("You are not supposed to run it manually!")
    ExitApp()
}

MainPID := A_Args[1]
if !OwnedParent.Attach(MainPID)
    ExitApp()

if (WebhookEnabled && WebhookLink != "" && WebhookScreenshots = "1") {
    screenshotDelay := Random(25000, 300000)
    SetTimer(TakeRandomScreenshot, screenshotDelay)
}

Sleep(15000)
Loop 60 {
    if WinExist("Roblox ahk_exe RobloxPlayerBeta.exe")
        break
    if WinExist("Roblox ahk_exe ApplicationFrameHost.exe")
        break
        
    Sleep(500)
}
loopCounter := 0

Loop {
    getRobloxPos(,,&w,&h)

    loopCounter++ 

    if (Mod(loopCounter, 15) == 0) {
        if !Integer(IniRead(StateFile, "State", "Running", 0)) {
            ExitApp()
        }
    }

    if WinExist("Roblox Crash") {
        if (WebhookEnabled && WebhookLink != "") {
            SendScreenshot(,"Roblox has crashed!")
        }
        RestartMain()
        return
    }

    if !WinExist("Roblox ahk_exe RobloxPlayerBeta.exe") && !WinExist("Roblox ahk_exe ApplicationFrameHost.exe") {
        if (WebhookEnabled && WebhookLink != "") {
            SendScreenshot(,"Roblox is not running!")
        }
        RestartMain()
        return
    }

    if (Mod(loopCounter, 3) == 0) {
        CoordMode("Pixel", "Screen")
        
        sw := A_ScreenWidth
        sh := A_ScreenHeight
        
        try {
            if ImageSearch(&FoundX, &FoundY, 0, 0, sw, sh, "*26 Resources/Disconnected.png") {
                CoordMode("Pixel", "Client")
                if (WebhookEnabled && WebhookLink != "") {
                    SendScreenshot(, "Disconnected, rejoining")
                }
                RestartMain()
                ExitApp()
            } else if ImageSearch(&FoundX, &FoundY, 0, 0, sw, sh, "*26 Resources/disconnected2.png") {
                CoordMode("Pixel", "Client")
                if (WebhookEnabled && WebhookLink != "") {
                    SendScreenshot(, "Disconnected, rejoining")
                }
                RestartMain()
                ExitApp()
            }
        } catch Error as err {
            CoordMode("Pixel", "Client")
        }
        
        CoordMode("Pixel", "Client")
    }


    if (Mod(loopCounter, 2) == 0) {
        resTriumph1 := AdvancedImageSearch(TriumphImg1, w * 0.2, h * 0.2, w * 0.6, h * 0.7)
        
        if (resTriumph1.status == "success" && resTriumph1.score > 0.7) {
            FinishDetectedMatch("Triumph", resTriumph1)
            ExitApp()
        }
    } else {
        resTriumph2 := AdvancedImageSearch(TriumphImg2, w * 0.2, h * 0.2, w * 0.6, h * 0.7)
        Sleep 200
        resLost := AdvancedImageSearch(YouLostImg, w * 0.2, h * 0.2, w * 0.6, h * 0.7)

        if (resTriumph2.status == "success" && resTriumph2.score > 0.7) {
            FinishDetectedMatch("Triumph", resTriumph2)
            ExitApp()
        }
        
        if (resLost.status == "success" && resLost.score > 0.7) {
            FinishDetectedMatch("Loss", resLost)
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

FinishDetectedMatch(matchResult, anchorObj) {
    global StateFile, WebhookEnabled, WebhookLink
    paired := DashboardMatch.Linked()
    if paired
        DashboardMatch.ApplyStop(StateFile)
    ; Dashboard-only collection must not activate another game over the user.
    collect := (WebhookEnabled && WebhookLink != "")
        || (paired && GetRobloxHWND() && WinActive("ahk_id " GetRobloxHWND()))
    if collect {
        CloseMain()
        try SendInfo(matchResult, anchorObj)
    }
    ; Covers disabled webhooks, a background Roblox window, and OCR failures.
    ; Publish is idempotent for the current match; it never replaces good data.
    if paired
        DashboardMatch.Publish(matchResult, StateFile)
    RestartMain()
}

SendInfo(matchResult := "", anchorObj := "") {
    global WebhookLink, WebhookLink2, WebhookSepatateTriumphScreenshots, StateFile, SendCurrenciesEnabled, WebhookEnabled, WebhookDebugLogs

    originalWebhookLink := WebhookLink
    if (WebhookSepatateTriumphScreenshots == 1 && WebhookLink2 != "") {
        WebhookLink := WebhookLink2
    }

    mapName := "Unknown"
    timeInSeconds := 0
    coinVal := 0
    gemVal := 0
    expVal := 0

    timeCompleted_T := IniRead(StateFile, "State", "TimeWhenStartedPlaying", "Failed")

    if (timeCompleted_T != "Failed" && IsInteger(timeCompleted_T)) {
        ms := A_TickCount - Integer(timeCompleted_T)
        if (ms < 0 || ms > 86400000) {
            timeCompleted := "N/A"
            timeInSeconds := 0
        } else {
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
        }
    } else {
        timeCompleted := "N/A"
        timeInSeconds := 0
    }

    try IniDelete(StateFile, "State", "TimeWhenStartedPlaying")

    getRobloxPos(&pX, &pY, &w, &h)

    robloxHwnd := GetRobloxHWND()
    winClientX := 0, winClientY := 0
    if (robloxHwnd) {
        try WinGetClientPos(&winClientX, &winClientY,,, "ahk_id " robloxHwnd)
        try WinActivate("ahk_id " robloxHwnd)
    }

    ; Cancel any tower placement/hotbar selection with 'q'
    Send("{q}")
    Sleep(50)

    ; Move mouse away to safe top-left corner (5%, 5%) so no cards or stats are hovered
    MouseMove(Round(w * 0.05), Round(h * 0.05), 0)

    FoundX := 0
    FoundY := 0

    ; 1) Initialize from anchor passed from main loop if available
    if (IsObject(anchorObj) && HasProp(anchorObj, "status") && anchorObj.status = "success" && HasProp(anchorObj, "score") && anchorObj.score > 0.45) {
        if (matchResult = "Triumph" && HasProp(anchorObj, "x") && HasProp(anchorObj, "y") && anchorObj.y > (winClientY + Round(h * 0.5))) {
            FoundX := anchorObj.x
            FoundY := anchorObj.y
        } else if (matchResult = "Loss" && HasProp(anchorObj, "x") && HasProp(anchorObj, "y")) {
            FoundX := anchorObj.x + sX(130)
            FoundY := anchorObj.y + sY(180)
        }
    }

    ; 2) Search for Play Again (Triumph) or Restart Match (Loss)
    if (FoundX == 0 || FoundY < (winClientY + Round(h * 0.45))) {
        Loop 6 {
            if (matchResult = "Triumph") {
                Play_Again := AdvancedImageSearch(TriumphImg2, w * 0.2, h * 0.2, w * 0.6, h * 0.7)
                if (Play_Again.status = "success" && Play_Again.score > 0.50) {
                    FoundX := Play_Again.x
                    FoundY := Play_Again.y
                    break
                }
            } else {
                Restart := AdvancedImageSearch(RestartImg, w * 0.2, h * 0.2, w * 0.6, h * 0.7)
                Restart2 := AdvancedImageSearch(RestartImg2, w * 0.2, h * 0.2, w * 0.6, h * 0.7)
                if (Restart.status = "success" && Restart.score > 0.40) {
                    FoundX := Restart.x
                    FoundY := Restart.y
                    break
                } else if (Restart2.status = "success" && Restart2.score > 0.40) {
                    FoundX := Restart2.x
                    FoundY := Restart2.y
                    break
                }
                resLostBanner := AdvancedImageSearch(YouLostImg, w * 0.2, h * 0.2, w * 0.6, h * 0.7)
                if (resLostBanner.status = "success" && resLostBanner.score > 0.55) {
                    FoundX := resLostBanner.x + sX(130)
                    FoundY := resLostBanner.y + sY(180)
                    break
                }
            }
            Sleep(300)
        }
    }

    ; Allow rewards and counters to finish fading in and counting up (extended delay per user request)
    Sleep(3500)

    ; Re-park mouse at safe top-left corner after cards appear, clearing any hover tooltips
    MouseMove(Round(w * 0.05), Round(h * 0.05), 0)
    Sleep(150)

    ; 3) Fail-safe fallback anchor: The TDS end-game modal is always horizontally and vertically centered in Roblox window.
    ; Calibrated Play Again / Restart position: Triumph Y ≈ 72.8% (sY(734)), Loss Y ≈ 61.4% (sY(620))
    if (FoundX == 0 || FoundY < (winClientY + Round(h * 0.45))) {
        FoundX := winClientX + Round(w * (1090 / 1920))
        if (matchResult = "Loss") {
            FoundY := winClientY + Round(h * (620 / 1009))
        } else {
            FoundY := winClientY + Round(h * (734 / 1009))
        }
    }

    if (SendCurrenciesEnabled = "1") {
        coinVal := 0
        gemVal := 0
        expVal := 0
        detectedLevel := 0
        detectedNextExp := 0

        ; ----------------------------------------------------------------------
        ; Step 1: Right Panel OCR (Game Mode, Difficulty, Map, Time)
        ; Read this first so we know whether Gems are eligible for this match.
        ; ----------------------------------------------------------------------
        infoX := winClientX + Round(w * 0.50)
        infoY := winClientY + Round(h * 0.18)
        InfoW := Round(w * 0.35)
        InfoH := Round(h * 0.54)

        ocrInfo := ""
        pBitmapInfo := Gdip_BitmapFromScreen(infoX . "|" . infoY . "|" . InfoW . "|" . InfoH)
        if (pBitmapInfo) {
            pBitmapInfoResized := 0, G2 := 0
            try {
                scaleIW := Round(InfoW * 1.5), scaleIH := Round(InfoH * 1.5)
                pBitmapInfoResized := Gdip_CreateBitmap(scaleIW, scaleIH)
                if (pBitmapInfoResized) {
                    G2 := Gdip_GraphicsFromImage(pBitmapInfoResized)
                    if (G2) {
                        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", G2, "Int", 7)
                        Gdip_DrawImage(G2, pBitmapInfo, 0, 0, scaleIW, scaleIH, 0, 0, InfoW, InfoH)
                        try ocrInfo := OCR.FromBitmap(pBitmapInfoResized, {lang:"en-US"}).Text
                    }
                }
            } finally {
                if (G2)
                    try Gdip_DeleteGraphics(G2)
                if (pBitmapInfoResized)
                    try Gdip_DisposeImage(pBitmapInfoResized)
                try Gdip_DisposeImage(pBitmapInfo)
            }
        }

        ; TDS Gem Rules: Gems are strictly ONLY awarded in Hardcore mode or special Event modes (e.g. Frost Invasion).
        ; In standard Survival modes (Normal, Molten, Fallen, etc.), Gems are ALWAYS 0!
        isHardcore := InStr(ocrInfo, "Hardcore")
        isGemsEligible := isHardcore || InStr(ocrInfo, "Frost") || InStr(ocrInfo, "Event")

        ; ----------------------------------------------------------------------
        ; ----------------------------------------------------------------------
        ; Step 2: Top EXP Bar OCR (EXP, Current Level, Next Level Req)
        ; Isolated crop for the top EXP bar: calibrated to Roblox result screen
        ; ----------------------------------------------------------------------
        expAreaX := winClientX + Round(w * 0.27)
        expAreaY := winClientY + Round(h * 0.40)
        expAreaW := Round(w * 0.30)
        expAreaH := Round(h * 0.11)

        ocrExpArea := ""
        pBitmapExp := Gdip_BitmapFromScreen(expAreaX . "|" . expAreaY . "|" . expAreaW . "|" . expAreaH)
        if (pBitmapExp) {
            pExpResized := 0, GExp := 0
            try {
                sEW := Round(expAreaW * 1.5), sEH := Round(expAreaH * 1.5)
                pExpResized := Gdip_CreateBitmap(sEW, sEH)
                if (pExpResized) {
                    GExp := Gdip_GraphicsFromImage(pExpResized)
                    if (GExp) {
                        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", GExp, "Int", 7)
                        Gdip_DrawImage(GExp, pBitmapExp, 0, 0, sEW, sEH, 0, 0, expAreaW, expAreaH)
                        try ocrExpArea := OCR.FromBitmap(pExpResized, {lang:"en-US"}).Text
                    }
                }
            } finally {
                if (GExp)
                    try Gdip_DeleteGraphics(GExp)
                if (pExpResized)
                    try Gdip_DisposeImage(pExpResized)
                try Gdip_DisposeImage(pBitmapExp)
            }
        }

        allExpVals := []
        topBarExpVal := 0

        ; Extract (+)<num> XP from the top EXP bar (minimum 50 to filter out stray single digits like 3)
        pos := 1
        while RegExMatch(ocrExpArea, "i)(?:\+\s*)?(\d[\d,]{2,5})[ \t]*(?:exp|xp)\b", &mBarExp, pos) {
            vExp := Integer(StrReplace(mBarExp[1], ",", ""))
            if (vExp >= 50 && vExp <= 2500) {
                allExpVals.Push(vExp)
                if (topBarExpVal == 0)
                    topBarExpVal := vExp
            }
            pos := mBarExp.Pos + StrLen(mBarExp[0])
        }
        if (topBarExpVal > 0)
            expVal := topBarExpVal

        ; Detect Player Level (e.g. "Lv. 1215") and Next EXP requirement (e.g. "2,083") to blacklist them from Coins!
        if (RegExMatch(ocrExpArea, "i)Lv\.?\s*(\d[\d,]*)", &mLv)) {
            detectedLevel := Integer(StrReplace(mLv[1], ",", ""))
        }
        pos := 1
        while RegExMatch(ocrExpArea, "(\d[\d,]+)", &mNum, pos) {
            numVal := Integer(StrReplace(mNum[1], ",", ""))
            if (numVal != detectedLevel && (allExpVals.Length == 0 || numVal != allExpVals[1])) {
                if (numVal > detectedNextExp)
                    detectedNextExp := numVal
            }
            pos := mNum.Pos + StrLen(mNum[0])
        }

        ; ----------------------------------------------------------------------
        ; Step 3: Phase A - Direct ImageSearch & Targeted Crop for Coins Card
        ; Reward cards ONLY appear below the EXP bar (strictly Y >= h * 0.50)
        ; ----------------------------------------------------------------------
        cardsStartY := winClientY + Round(h * 0.50)

        ; Calibrated location of the 5th card (Coins Card, bottom-right)
        calibratedCoinX := winClientX + Round(w * 0.37)
        calibratedCoinY := winClientY + Round(h * 0.60)
        calibratedCoinW := Round(w * 0.08)
        calibratedCoinH := Round(h * 0.16)

        coinFound := false
        coinCard := AdvancedImageSearch(CoinsImg, w * 0.30, h * 0.50, w * 0.20, h * 0.30)
        if (coinCard.status = "success" && coinCard.score >= 0.50 && coinCard.y >= cardsStartY) {
            coinFound := true
            cBoxX := Max(winClientX, coinCard.x - sX(8))
            cBoxY := Max(winClientY, coinCard.y - sY(8))
            cBoxW := Min(winClientX + w - cBoxX, sX(100))
            cBoxH := Min(winClientY + h - cBoxY, sY(120))
        } else if (matchResult = "Triumph") {
            ; Triumph always has all 5 cards in fixed positions even if image search misses
            cBoxX := calibratedCoinX
            cBoxY := calibratedCoinY
            cBoxW := calibratedCoinW
            cBoxH := calibratedCoinH
        } else {
            ; On Loss: if the Coins card image was not found, the card is not present on screen!
            cBoxX := 0, cBoxY := 0, cBoxW := 0, cBoxH := 0
        }

        if (cBoxW > 0 && cBoxH > 0) {
            pCardBmp := Gdip_BitmapFromScreen(cBoxX . "|" . cBoxY . "|" . cBoxW . "|" . cBoxH)
            if (pCardBmp) {
                pCardResized := 0, GC := 0
                try {
                    scaleC := 4
                    pCardResized := Gdip_CreateBitmap(cBoxW * scaleC, cBoxH * scaleC)
                    if (pCardResized) {
                        GC := Gdip_GraphicsFromImage(pCardResized)
                        if (GC) {
                            DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", GC, "Int", 7)
                            Gdip_DrawImage(GC, pCardBmp, 0, 0, cBoxW * scaleC, cBoxH * scaleC, 0, 0, cBoxW, cBoxH)
                            try cText := OCR.FromBitmap(pCardResized, {lang:"en-US"}).Text
                            if (!InStr(cText, "coin") && !InStr(cText, "corn") && !InStr(cText, "coln") && !RegExMatch(cText, "\d")) {
                                BinarizeTargetBitmap(pCardResized)
                                try cText .= "`n" OCR.FromBitmap(pCardResized, {lang:"en-US"}).Text
                            }
                        }
                    }
                } finally {
                    if (GC)
                        try Gdip_DeleteGraphics(GC)
                    if (pCardResized)
                        try Gdip_DisposeImage(pCardResized)
                    try Gdip_DisposeImage(pCardBmp)
                }

                cleanCText := RegExReplace(cText, "(\d+)'", "$19")
                if (!RegExMatch(cleanCText, "i)\b(?:exp|xp|lvl|level|cp)\b")) {
                    ; 1. Standard denomination matching
                    if (RegExMatch(cleanCText, "i)(?:\+\s*)?(\d[\d,]*)[ \t]*(?:coins?|corns?|colns?|gold)\b", &mNum)) {
                        val := Integer(StrReplace(mNum[1], ",", ""))
                        if (val > 0 && val != detectedLevel && val != detectedNextExp && val != expVal && !(val >= 1210 && val <= 1220)) {
                            coinVal := val
                            coinFound := true
                        }
                    }
                    ; 2. Ligature handling (e.g. '24B' or '248' where '79' was merged into 'B' or '8')
                    if (coinVal == 0 && RegExMatch(cleanCText, "i)(\d{2,4})[B8]", &mB)) {
                        val := Integer(mB[1] "79")
                        if (val > 0 && val != detectedLevel && val != detectedNextExp && val != expVal && !(val >= 1210 && val <= 1220)) {
                            coinVal := val
                            coinFound := true
                        }
                    }
                    ; 3. Any 3-5 digit number on the Coin Card (Card 5 only ever contains the coin amount)
                    if (coinVal == 0 && RegExMatch(cleanCText, "(\d{3,5})", &mAnyNum)) {
                        val := Integer(StrReplace(mAnyNum[1], ",", ""))
                        if (val >= 100 && val != detectedLevel && val != detectedNextExp && val != expVal && !(val >= 1210 && val <= 1220)) {
                            coinVal := val
                            coinFound := true
                        }
                    }
                }
            }
        }

        ; Gems Card Search: ONLY executed if this game mode actually drops gems!
        gemFound := false
        if (isGemsEligible) {
            gemCard := AdvancedImageSearch(GemImg, w * 0.17, h * 0.35, w * 0.38, h * 0.40)
            if (gemCard.status = "success" && gemCard.score >= 0.65 && gemCard.y >= cardsStartY) {
                gemFound := true
                gBoxX := Max(winClientX, gemCard.x - sX(8))
                gBoxY := Max(winClientY, gemCard.y - sY(8))
                gBoxW := Min(winClientX + w - gBoxX, sX(100))
                gBoxH := Min(winClientY + h - gBoxY, sY(120))
                pGemBmp := Gdip_BitmapFromScreen(gBoxX . "|" . gBoxY . "|" . gBoxW . "|" . gBoxH)
                if (pGemBmp) {
                    pGemResized := 0, GG := 0
                    try {
                        pGemResized := Gdip_CreateBitmap(gBoxW * 2, gBoxH * 2)
                        if (pGemResized) {
                            GG := Gdip_GraphicsFromImage(pGemResized)
                            if (GG) {
                                DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", GG, "Int", 7)
                                Gdip_DrawImage(GG, pGemBmp, 0, 0, gBoxW * 2, gBoxH * 2, 0, 0, gBoxW, gBoxH)
                                try gText := OCR.FromBitmap(pGemResized, {lang:"en-US"}).Text
                                if (!RegExMatch(gText, "\d")) {
                                    BinarizeTargetBitmap(pGemResized)
                                    try gText .= "`n" OCR.FromBitmap(pGemResized, {lang:"en-US"}).Text
                                }
                            }
                        }
                    } finally {
                        if (GG)
                            try Gdip_DeleteGraphics(GG)
                        if (pGemResized)
                            try Gdip_DisposeImage(pGemResized)
                        try Gdip_DisposeImage(pGemBmp)
                    }

                    if (!RegExMatch(gText, "i)\b(?:exp|xp|lvl|level|cp)\b")) {
                        if (RegExMatch(gText, "i)(?:\+\s*)?(\d[\d,]*)[ \t]*gems?\b", &mGNum)) {
                            valStr := mGNum[1]
                            val := Integer(StrReplace(valStr, ",", ""))
                            if (val > 0 && val <= 500 && val != expVal)
                                gemVal := val
                        }
                    }
                }
            }
        }

        ; XP Card Search (fallback for expVal if top bar missed)
        expFound := (topBarExpVal > 0)
        if (expVal == 0) {
            xpCard := AdvancedImageSearch(XpImg, w * 0.17, h * 0.35, w * 0.38, h * 0.40)
            if (xpCard.status = "success" && xpCard.score >= 0.60 && xpCard.y >= cardsStartY) {
                expFound := true
                xBoxX := Max(winClientX, xpCard.x - sX(8))
                xBoxY := Max(winClientY, xpCard.y - sY(8))
                xBoxW := Min(winClientX + w - xBoxX, sX(100))
                xBoxH := Min(winClientY + h - xBoxY, sY(120))
                pXpBmp := Gdip_BitmapFromScreen(xBoxX . "|" . xBoxY . "|" . xBoxW . "|" . xBoxH)
                if (pXpBmp) {
                    pXpResized := 0, GX := 0
                    try {
                        pXpResized := Gdip_CreateBitmap(xBoxW * 2, xBoxH * 2)
                        if (pXpResized) {
                            GX := Gdip_GraphicsFromImage(pXpResized)
                            if (GX) {
                                DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", GX, "Int", 7)
                                Gdip_DrawImage(GX, pXpBmp, 0, 0, xBoxW * 2, xBoxH * 2, 0, 0, xBoxW, xBoxH)
                                try xText := OCR.FromBitmap(pXpResized, {lang:"en-US"}).Text
                                if (!RegExMatch(xText, "\d")) {
                                    BinarizeTargetBitmap(pXpResized)
                                    try xText .= "`n" OCR.FromBitmap(pXpResized, {lang:"en-US"}).Text
                                }
                            }
                        }
                    } finally {
                        if (GX)
                            try Gdip_DeleteGraphics(GX)
                        if (pXpResized)
                            try Gdip_DisposeImage(pXpResized)
                        try Gdip_DisposeImage(pXpBmp)
                    }

                    if (!RegExMatch(xText, "i)\b(?:lvl|level|till)\b")) {
                        if (RegExMatch(xText, "i)(?:\+\s*)?(\d[\d,]*)[ \t]*(?:exp|xp)\b", &mXNum)) {
                            val := Integer(StrReplace(mXNum[1], ",", ""))
                            if (val >= 50 && val <= 2500) {
                                allExpVals.Push(val)
                                expVal := val
                            }
                        }
                    }
                }
            }
        }

        ; ----------------------------------------------------------------------
        ; Step 4: Phase B - Reward Cards Panel OCR (Excluding top EXP Bar)
        ; Crop strictly from Y = 51% to 76% so Level and EXP numbers CANNOT enter this OCR text!
        ; ----------------------------------------------------------------------
        cardsPanelX := winClientX + Round(w * 0.31)
        cardsPanelY := winClientY + Round(h * 0.51)
        cardsPanelW := Round(w * 0.22)
        cardsPanelH := Round(h * 0.25)

        ocrCards := ""
        pBitmapCards := Gdip_BitmapFromScreen(cardsPanelX . "|" . cardsPanelY . "|" . cardsPanelW . "|" . cardsPanelH)
        if (pBitmapCards) {
            pCardsResized := 0, G1 := 0
            try {
                scaleW := Round(cardsPanelW * 1.5), scaleH := Round(cardsPanelH * 1.5)
                pCardsResized := Gdip_CreateBitmap(scaleW, scaleH)
                if (pCardsResized) {
                    G1 := Gdip_GraphicsFromImage(pCardsResized)
                    if (G1) {
                        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", G1, "Int", 7)
                        Gdip_DrawImage(G1, pBitmapCards, 0, 0, scaleW, scaleH, 0, 0, cardsPanelW, cardsPanelH)
                        try ocrCards := OCR.FromBitmap(pCardsResized, {lang:"en-US"}).Text
                        if ((coinVal == 0 && !InStr(ocrCards, "coin") && !InStr(ocrCards, "corn") && !InStr(ocrCards, "coln"))) {
                            BinarizeTargetBitmap(pCardsResized)
                            try ocrCards .= "`n" OCR.FromBitmap(pCardsResized, {lang:"en-US"}).Text
                        }
                    }
                }
            } finally {
                if (G1)
                    try Gdip_DeleteGraphics(G1)
                if (pCardsResized)
                    try Gdip_DisposeImage(pCardsResized)
                try Gdip_DisposeImage(pBitmapCards)
            }
        }

        ; Combine full text for backward compatibility
        ocrTarget := ocrExpArea . "`n" . ocrCards

        ; Fallback Coins extraction from cards OCR
        if (coinVal == 0 && (coinFound || matchResult = "Triumph")) {
            pos := 1
            ; Strict single-line denomination matching: no multiline jump
            while RegExMatch(ocrCards, "i)(?:(?:\+\s*)?(\d[\d,]*)[ \t]*(?:coins?|corns?|colns?|gold)\b|(?:coins?|corns?|colns?|gold)[ \t]*[:=]?[ \t]*(?:\+\s*)?(\d[\d,]*))", &coinsMatch, pos) {
                valStr := coinsMatch[1] != "" ? coinsMatch[1] : coinsMatch[2]
                val := Integer(StrReplace(valStr, ",", ""))
                ; Sanity Check: reject values matching EXP, Level, or Next EXP, or player level range
                if (val > 0 && val != expVal && val != detectedLevel && val != detectedNextExp && !(val >= 1210 && val <= 1220)) {
                    coinVal := val
                    coinFound := true
                    break
                }
                pos := coinsMatch.Pos + StrLen(coinsMatch[0])
            }
        }

        ; Fallback Gems extraction from cards OCR ONLY IF gems are eligible
        if (gemVal == 0 && gemFound && isGemsEligible) {
            pos := 1
            while RegExMatch(ocrCards, "i)(?:(?:\+\s*)?(\d[\d,]*)[ \t]*gems?\b|gems?[ \t]*[:=]?[ \t]*(?:\+\s*)?(\d[\d,]*))", &gemsMatch, pos) {
                valStr := gemsMatch[1] != "" ? gemsMatch[1] : gemsMatch[2]
                val := Integer(StrReplace(valStr, ",", ""))
                if (val > 0 && val <= 500 && val != expVal && val != detectedLevel && val != detectedNextExp) {
                    gemVal := val
                    break
                }
                pos := gemsMatch.Pos + StrLen(gemsMatch[0])
            }
        }

        ; Collect any valid EXP (>= 50) from cards text as fallback ONLY IF expVal is not yet found from top bar or xpCard
        if (expVal == 0 && (expFound || matchResult = "Triumph")) {
            pos := 1
            while RegExMatch(ocrCards, "i)(?:([a-zA-Z.]+)\s+)?(?:\+\s*)?(\d[\d,]*)[ \t]*(?:exp|xp)\b", &expMatch, pos) {
                prefix := StrLower(expMatch[1])
                if (prefix = "till" || prefix = "level" || prefix = "lvl" || prefix = "lv" || prefix = "lv.") {
                    pos := expMatch.Pos + StrLen(expMatch[0])
                    continue
                }
                val := Integer(StrReplace(expMatch[2], ",", ""))
                if (val >= 50 && val <= 2500)
                    allExpVals.Push(val)
                pos := expMatch.Pos + StrLen(expMatch[0])
            }

            if (allExpVals.Length > 0) {
                maxV := 0
                for v in allExpVals {
                    if (v > maxV)
                        maxV := v
                }
                expVal := maxV
                expFound := true
            }
        }

        ; ----------------------------------------------------------------------
        ; Step 5: Memory Read Cross-Check & Always-On Debug Logging
        ; ----------------------------------------------------------------------
        ocrCoinVal := coinVal
        ocrGemVal := gemVal
        ocrExpVal := expVal
        memoryRewards := TDSRobloxMemory.ReadRewards()
        if (memoryRewards.available) {
            if (memoryRewards.coins > 0) {
                coinVal := memoryRewards.coins
                coinFound := true
            }
            if (memoryRewards.gems > 0 && isGemsEligible) {
                gemVal := memoryRewards.gems
                gemFound := true
            }
            if (memoryRewards.exp >= 50) {
                expVal := memoryRewards.exp
                expFound := true
            }

            coinsVerified := (memoryRewards.coins > 0 && ocrCoinVal = memoryRewards.coins)
            gemsVerified := (gemFound && memoryRewards.gems > 0 && ocrGemVal = memoryRewards.gems)
            expVerified := (memoryRewards.exp >= 50 && ocrExpVal = memoryRewards.exp)
        }

        ; Always write comprehensive reward log to C:\Users\...\AppData\Roaming\Ultimate_Macro\Logs\reward_debug.log
        try {
            logsDir := A_AppData "\Ultimate_Macro\Logs"
            if !DirExist(logsDir)
                DirCreate(logsDir)
            logEntry := FormatTime(, "yyyy-MM-dd HH:mm:ss") " [" matchResult "] Mode: " (isHardcore ? "Hardcore" : "Survival") " | Map: " mapName "`n"
            logEntry .= "  Memory: available=" (memoryRewards.available ? "true" : "false") ", coins=" memoryRewards.coins ", gems=" memoryRewards.gems ", exp=" memoryRewards.exp ", error=" memoryRewards.error "`n"
            logEntry .= "  OCR: coins=" ocrCoinVal ", gems=" ocrGemVal ", exp=" ocrExpVal " (candidates: "
            for idx, cv in allExpVals
                logEntry .= (idx > 1 ? ", " : "") cv
            logEntry .= "), Level=" detectedLevel ", NextEXP=" detectedNextExp "`n"
            logEntry .= "  Final Result: +" expVal " EXP, +" coinVal " Coins, +" gemVal " Gems`n"
            logEntry .= "------------------------------------------------------------`n"
            FileAppend(logEntry, logsDir "\reward_debug.log", "UTF-8")
        }

        ; ----------------------------------------------------------------------
        ; Phase C: Anomaly Protection & Smart Cache (Triumph only)
        ; ----------------------------------------------------------------------
        ; Strict Card Presence Rule: If a reward card was not detected via OCR or Memory, its value is strictly 0!
        if (!coinFound) {
            coinVal := 0
        }

        if (!isGemsEligible || !gemFound) {
            gemVal := 0
        }

        if (!expFound) {
            expVal := 0
        }

        ; In TDS, defeat never gives gems unless it's Hardcore mode
        if (matchResult = "Loss" && !isHardcore)
            gemVal := 0

        ; Hard limit guard: TDS single-match EXP never exceeds 2500
        if (expVal > 2500)
            expVal := 0

        lastTriumphCoins := Integer(IniRead(StateFile, "LastRewards", "LastTriumphCoins", 0))
        lastTriumphGems  := Integer(IniRead(StateFile, "LastRewards", "LastTriumphGems", 0))

        if (matchResult = "Triumph") {
            ; A 1- or 2-digit value is implausible for victory coins.
            ; Also reject values matching Level, Next EXP, or player's level (1210-1220)!
            if (coinVal > 0 && (coinVal < 100 || coinVal == detectedLevel || coinVal == detectedNextExp || (coinVal >= 1210 && coinVal <= 1220)))
                coinVal := 0

            ; If coins was completely missed (0), recover from last triumph coins
            if (coinVal == 0 && lastTriumphCoins >= 100 && lastTriumphCoins != detectedLevel && lastTriumphCoins != detectedNextExp && !(lastTriumphCoins >= 1210 && lastTriumphCoins <= 1220)) {
                coinVal := lastTriumphCoins
            } else if (coinVal >= 100 && coinVal != detectedLevel && coinVal != detectedNextExp && !(coinVal >= 1210 && coinVal <= 1220)) {
                try IniWrite(coinVal, StateFile, "LastRewards", "LastTriumphCoins")
            }

            ; Only check/cache gems if eligible and found
            if (gemFound && isGemsEligible) {
                if ((gemVal == 0 || gemVal > 500) && lastTriumphGems > 0 && isHardcore) {
                    gemVal := lastTriumphGems
                } else if (gemVal > 0 && gemVal <= 500) {
                    try IniWrite(gemVal, StateFile, "LastRewards", "LastTriumphGems")
                }
            }
        }
        ; On Loss: coin rewards vary by wave reached, so we do not cache/substitute from past runs

        mapName := "Unknown"

        mapList := [
        "Abandoned City", "Area 52", "Autumn Falling", 
        "Badlands II", "Black Spot Exchange", "Candy Valley", "Cataclysm", "Chess Board", 
        "Construction Crazy", "Coral Deep", "Crossroads", "Crystal Cave", 
        "Cyber City", "Dead Ahead", "Derelict Outpost", "Deserted Village", "Dusty Bridges", 
        "Enchanted Forest", "Farm Lands", "Forest Camp", "Forgotten Docks", "Four Seasons", 
        "Fungi Island", "Grass Isle", "Simplicity", "Happy Home of Robloxia", "Harbor", "Honey Valley", 
        "Hot Spot", "Iceville", "Infernal Abyss", "Lay By", "Lighthouse", "Marshlands", "Mason Arch", "Medieval Times", "Meltdown", 
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

        if (mapName == "Unknown") {
            cleanOcrInfo := StrLower(RegExReplace(ocrInfo, "[\s\r\n\-_:]+", ""))
            for currentMap in mapList {
                cleanMap := StrLower(RegExReplace(currentMap, "[\s\r\n\-_:]+", ""))
                if InStr(cleanOcrInfo, cleanMap) {
                    mapName := currentMap
                    break
                }
            }
        }

        ; Fallback: read map from active strategy or StateFile if OCR could not detect it
        if (mapName == "Unknown") {
            mapName := IniRead(StateFile, "State", "Map", "Unknown")
        }

        if (mapName == "Unknown") {
            currentStrat := IniRead(StateFile, "State", "Strategy", "")
            if (currentStrat != "" && currentStrat != "0") {
                SplitPath(currentStrat, &stratFileName)
                cleanStrat := StrLower(RegExReplace(stratFileName, "[\s\r\n\-_:]+", ""))
                for currentMap in mapList {
                    cleanMap := StrLower(RegExReplace(currentMap, "[\s\r\n\-_:]+", ""))
                    if InStr(cleanStrat, cleanMap) {
                        mapName := currentMap
                        break
                    }
                }
            }
        }

        ; Fallback: extract Time Completed from OCR if state had no start time
        if ((timeCompleted = "N/A" || timeCompleted = "Failed" || timeInSeconds == 0) && RegExMatch(ocrInfo, "i)Time\s*Completed\s*[:;]?\s*([0-9hm\s]+s|[0-9]+m|[0-9]+s)", &tcMatch)) {
            timeCompleted := Trim(tcMatch[1])
            tcSec := 0
            if RegExMatch(timeCompleted, "(\d+)\s*h", &hM)
                tcSec += Integer(hM[1]) * 3600
            if RegExMatch(timeCompleted, "(\d+)\s*m", &mM)
                tcSec += Integer(mM[1]) * 60
            if RegExMatch(timeCompleted, "(\d+)\s*s", &sM)
                tcSec += Integer(sM[1])
            if (tcSec > 0 && timeInSeconds == 0)
                timeInSeconds := tcSec
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
    elapsedHours := 0

    if (autorunStart > 0) {
        elapsedMs := A_TickCount - autorunStart
        if (elapsedMs > 0 && elapsedMs < 2592000000) { ; valid if positive and < 30 days
            elapsedHours := elapsedMs / 3600000
        }
    }

    ; Fallback to totalTime if autorunStart was invalidated (e.g. PC rebooted / timer overflow)
    if (elapsedHours <= 0.001 && totalTime > 60) {
        elapsedHours := totalTime / 3600
    }

    if (elapsedHours > 0.001) {
        coinsPerHour := Round(totalCoins / elapsedHours)
        gemsPerHour := Round(totalGems / elapsedHours)
        expPerHour := Round(totalExp / elapsedHours)
    }
    
    totalMatches := totalTriumphs + totalLosses
    winrate := (totalMatches > 0) ? Round((totalTriumphs / totalMatches) * 100) : 0
    rawRatio := (totalLosses > 0) ? (totalTriumphs / totalLosses) : totalTriumphs
    roundedRatio := Round(rawRatio, 2)
    wlRatioStr := (Mod(roundedRatio, 1) == 0) ? String(Integer(roundedRatio)) : Format("{:0.2f}", roundedRatio)

    avgTimeStr := "0s"
    if (totalMatches > 0 && totalTime > 0) {
        avgSeconds := Round(totalTime / totalMatches)
        avgMinutes := Floor(avgSeconds / 60)
        avgRemSeconds := Mod(avgSeconds, 60)
        avgTimeStr := (avgMinutes > 0) ? avgMinutes "m " avgRemSeconds "s" : avgRemSeconds "s"
    }

    description := ""
    color := (matchResult = "Triumph") ? 3066993 : 16724526

    if (matchResult = "Triumph") {
        description := "### :trophy: TRIUMPH!"
    } else {
        description := "### :skull: YOU LOST!"
    }

    if (SendCurrenciesEnabled = "1") {
        description .= "`n"
        description .= "Map: **" mapName "**  Time Completed: **" timeCompleted "**`n"
        description .= "+" expVal " EXP (+" totalExp ")`n"
        description .= "+" coinVal " Coins (+" totalCoins ")  +" gemVal " Gems (+" totalGems ")`n"
        description .= "-# Total Matches: " totalMatches ", wins: " totalTriumphs ", losses: " totalLosses ", W/R: " winrate "%, W/L ratio: " wlRatioStr ", " coinsPerHour " coins/h, " gemsPerHour " gems/h, " expPerHour " exp/h, avg. time: " avgTimeStr
    }

    mention := ""
    if (matchResult = "Triumph" && PingOnWin = 1) {
        mention := GetDiscordMention(WebhookUserID)
    } else if (matchResult = "Loss" && PingOnLoss = 1) {
        mention := GetDiscordMention(WebhookUserID)
    }

    DashboardMatch.Publish(matchResult, StateFile, Map("map", mapName, "coins", Integer(coinVal)
        , "gems", Integer(gemVal), "towerXp", Integer(expVal), "durationSeconds", Integer(timeInSeconds)))

    if (WebhookEnabled && WebhookLink != "") {
        pBitmap := 0
        if (robloxHwnd) {
            try {
                WinGetClientPos(&rwX, &rwY, &rwW, &rwH, "ahk_id " robloxHwnd)
                if (rwW > 100 && rwH > 100)
                    pBitmap := Gdip_BitmapFromScreen(rwX "|" rwY "|" rwW "|" rwH)
            }
        }
        if (!pBitmap)
            pBitmap := Gdip_BitmapFromScreen()
        if (pBitmap) {
            try {
                SendScreenshot(pBitmap, description, color, WebhookTriumphScreenshots, mention)
            } finally {
                Gdip_DisposeImage(pBitmap)
            }
        }
    }

    if (WebhookSepatateTriumphScreenshots == 1 && WebhookLink2 != "") {
        WebhookLink := originalWebhookLink
    }
}

BinarizeTargetBitmap(pBitmap) {
    Gdip_GetImageDimensions(pBitmap, &w, &h)
    Rect := Buffer(16, 0)
    NumPut("int", 0, Rect, 0), NumPut("int", 0, Rect, 4)
    NumPut("int", w, Rect, 8), NumPut("int", h, Rect, 12)
    
    BitmapData := Buffer(A_PtrSize = 8 ? 32 : 24, 0)
    if DllCall("gdiplus\GdipBitmapLockBits", "Ptr", pBitmap, "Ptr", Rect, "UInt", 3, "Int", 0x26200A, "Ptr", BitmapData)
        return
        
    Scan0 := NumGet(BitmapData, A_PtrSize = 8 ? 16 : 12, "Ptr")
    Stride := NumGet(BitmapData, 8, "Int")
    
    Loop h {
        y := A_Index - 1
        Loop w {
            x := A_Index - 1
            offset := (y * Stride) + (x * 4)
            b := NumGet(Scan0 + offset, 0, "UChar")
            g := NumGet(Scan0 + offset, 1, "UChar")
            r := NumGet(Scan0 + offset, 2, "UChar")
            
            brightness := (r + g + b) / 3
            isWhite := (brightness > 175)
            isYellow := (r > 150 && g > 120 && b < 120)
            isPurple := (r > 120 && b > 130 && g < 130)
            isCyan := (g > 140 && b > 150)
            if (isWhite || isYellow || isPurple || isCyan) { 
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
    
    pBitmap := Gdip_BitmapFromScreen()
    if (pBitmap > 0) {
        try {
            SendScreenshot(pBitmap, "Automatic screenshot", 3447003)
        } finally {
            Gdip_DisposeImage(pBitmap)
        }
    }
    
    screenshotDelay := Random(180000, 360000)
    SetTimer(TakeRandomScreenshot, screenshotDelay)
}

SendScreenshot(pBitmap := 0, description := "", color := 12434877, screenshot := WebhookScreenshots, mention := "") {
    global WebhookLink

    escapedDescription := StrReplace(description, "\", "\\")
    escapedDescription := StrReplace(escapedDescription, '"', '\"')
    escapedDescription := StrReplace(escapedDescription, "`n", "\n")

    fields := []
    internalBitmap := 0

    contentPrefix := (mention != "") ? '"content": "' mention '", ' : ''

    if (screenshot == "0" || screenshot == 0) {
        payload_json := '{' contentPrefix '"embeds": [{"description": "' escapedDescription '", "color": ' color '}]}'
        fields.Push(Map("name", "payload_json", "content-type", "application/json", "content", payload_json))
    } 
    else {
        if (!pBitmap) {
            pBitmap := Gdip_BitmapFromScreen()
            internalBitmap := pBitmap
        }
        payload_json := '{' contentPrefix '"embeds": [{"description": "' escapedDescription '", "color": ' color ', "image": {"url": "attachment://screenshot.png"}}]}'
        fields.Push(Map("name", "payload_json", "content-type", "application/json", "content", payload_json))
        fields.Push(Map("name", "files[0]", "filename", "screenshot.png", "content-type", "image/png", "pBitmap", pBitmap))
    }
    
    try {
        CreateFormData(&postdata, &contentType, fields)
    } finally {
        if (internalBitmap) {
            try Gdip_DisposeImage(internalBitmap)
        }
    }

    try {
        MaxAttempts := 3
        Loop MaxAttempts {
            try {
                whr := ComObject("WinHttp.WinHttpRequest.5.1")
                whr.Open("POST", WebhookLink "?wait=true", false)
                whr.SetRequestHeader("Content-Type", contentType)
                whr.SetTimeouts(10000, 10000, 10000, 10000)
                whr.Send(postdata)

                if (whr.Status >= 200 && whr.Status < 300)
                    break

                retryWait := 2500
                if (whr.Status == 429) {
                    retryWait := 5000
                    try {
                        if RegExMatch(whr.ResponseText, '"retry_after"\s*:\s*([\d.]+)', &mWait) {
                            retryWait := Max(1000, Round(Float(mWait[1]) * 1000) + 500)
                        }
                    }
                }
                Sleep(retryWait)
            } catch as err {
                if (A_Index == MaxAttempts) {
                } else {
                    Sleep(2500)
                }
            }
        }
    }
}

CreateFormData(&retData, &contentType, fields) {
    charArray := StrSplit("0123456789abcdefghijklmnopqrstuvwxyz")
    boundary := ""
    Loop 12 {
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
    size := DllCall("GlobalSize", "Ptr", pData, "UPtr")
    
    retData := ComObjArray(0x11, size)  
    pvData := NumGet(ComObjValue(retData), 8 + A_PtrSize, "Ptr")
    DllCall("RtlMoveMemory", "Ptr", pvData, "Ptr", pData, "Ptr", size)
    
    DllCall("GlobalUnlock", "Ptr", hData)
    DllCall("GlobalFree", "Ptr", hData, "Ptr")
    
    contentType := "multipart/form-data; boundary=----------------------------" boundary
}

CloseMain() => OwnedParent.Close()

RestartMain() {
    global MainPID, SettingsFile
    OwnedParent.Close()
    WebhookLink := IniRead(SettingsFile, "Webhook", "Link", "")
    tempWebhook := IniRead(SettingsFile, "Webhook", "Enabled", "OFF")
    WebhookEnabled := (tempWebhook = "1") ? true : false
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

        score := ImageSearch(&nx, &ny, x, y, x+w, y+h, "*80 " templ)

        status := "failed"

        if score == 1
            status := "success"

        return {score: score, x: nx, y: ny, message: " ", status: status}
    } else {
        return AdvImageSearch(templ, x, y, w, h, minScale, maxScale, scaleStep)
    }
}
