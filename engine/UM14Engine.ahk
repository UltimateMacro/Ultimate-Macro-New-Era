OnError(MacroErrorHandler)

MacroErrorHandler(thrown, mode) {
    if InStr(thrown.Message, "Item has no value") {
        return -1
    }
    return 0
}

; Ultimate Macro (macro for TDS) by Darksen
;   Free for anyone to use
;   Modifications are welcome, however stealing credit is not.
;   You can add your name, but my original credit must remain.
;
; Thanks to everyone who helped me.
;
; Started on March 30, 2026. My friend bet me that I wouldn't make a macro for TDS, but I did.
;
; Discord Server - https://discord.gg/DQnc2JDJtr

#Requires AutoHotkey v2.0
#SingleInstance Force

SetWorkingDir(A_ScriptDir)
CoordMode("Mouse", "Client")
CoordMode("Pixel", "Client")

ListLines(False)
KeyHistory(0)
SetTitleMatchMode(1)

; #SingleInstance applies to this exact launcher path; do not close other scripts.
if (RegExMatch(A_ScriptDir, "i)\.(zip|rar)")) {
    MsgBox("You are attempting to run the script from a ZIP file.`n`nPlease Extract/Unzip the file first, then run the script in the extracted folder.","Running From ZIP", 0x10)
    ExitApp()
}

; Same-title windows from other installations are not targeted.

if (A_PtrSize == 4) {
    MsgBox("You are running 32-bit AutoHotkey, the macro will not work properly, sadly.")
}

#Include %A_ScriptDir%\lib\Gdip_All.ahk
#Include %A_ScriptDir%\lib\OCR.ahk
#Include %A_ScriptDir%\lib\Gdip_ImageSearch.ahk
#Include %A_ScriptDir%\lib\Roblox.ahk
#Include %A_ScriptDir%\lib\HyperSleep.ahk
#Include %A_ScriptDir%\lib\ImageSearch\ImageSearch.ahk
#Include %A_ScriptDir%\lib\JSON.ahk
#Include %A_ScriptDir%\ui\Gfx.ahk
#Include %A_ScriptDir%\ui\Toolkit.ahk
#Include %A_ScriptDir%\ui\Chrome.ahk
#Include %A_ScriptDir%\ui\Events.ahk
#Include %A_ScriptDir%\ui\LegacySkin.ahk
#Include %A_ScriptDir%\app\PairingNet.ahk
#Include %A_ScriptDir%\app\DashboardMatch.ahk
#Include %A_ScriptDir%\app\Dashboard.ahk
#Include %A_ScriptDir%\app\DashboardHealth.ahk
#Include %A_ScriptDir%\app\DashboardActivity.ahk
#Include %A_ScriptDir%\app\DashboardRemote.ahk
#Include %A_ScriptDir%\app\UltBot.ahk
#Include %A_ScriptDir%\app\LegacyConnections.ahk
#Include %A_ScriptDir%\app\Lifecycle.ahk
#Include %A_ScriptDir%\app\Updater.ahk
#Include %A_ScriptDir%\app\ShotClient.ahk

ver := "1.3.3.10"

A_MaxHotkeysPerInterval := 9999

pToken := Gdip_Startup()
OnExit(CleanupGdip)
OnExit(HandleExit)

global AppDataOpt := A_AppData "\Ultimate_Macro\Options"
global SettingsFile := AppDataOpt "\Settings.tds"
global StateFile := A_AppData "\Ultimate_Macro\state.ini"

global ShowIndicators := true

global WebhookQueue := []
global WebhookTimerActive := false
global WebhookInstantQueue := []
global WebhookInstantTimerActive := false
global WebhookEnabled := false

if !DirExist(AppDataOpt)
    DirCreate(AppDataOpt)

;INI READS
global VipLink := IniRead(SettingsFile, "Options", "VipLink", "") 
global UseVipServer := IniRead(SettingsFile, "Options", "UseVipServer", "0")
global AlwaysOnTop := IniRead(SettingsFile, "Options", "AlwaysOnTop", 0)

global LegacyMode := IniRead(SettingsFile, "Options", "LegacyMode", 0)

global WebhookLink := IniRead(SettingsFile, "Webhook", "Link", "")
global WebhookLink2 := IniRead(SettingsFile, "Webhook", "Link2", "")
global WebhookUserID := IniRead(SettingsFile, "Webhook", "WebhookUserID", "")
global PingOnWin := Integer(IniRead(SettingsFile, "Webhook", "PingOnWin", 0))
global PingOnLoss := Integer(IniRead(SettingsFile, "Webhook", "PingOnLoss", 0))
global PingOnTimescale := Integer(IniRead(SettingsFile, "Webhook", "PingOnTimescale", 0))
global WebhookEnabled := IniRead(SettingsFile, "Webhook", "Enabled", 0)
global WebhookSepatateTriumphScreenshots := Integer(IniRead(SettingsFile, "Webhook", "WebhookSepatateTriumphScreenshots", 0))
global PotatoMode := IniRead(SettingsFile, "Options", "PotatoMode", 0)
global SendCurrenciesEnabled := IniRead(SettingsFile, "Webhook", "SendCurrencies", "1")
global WebhookDebugLogs := IniRead(SettingsFile, "Webhook", "WebhookDebugLogs", "1")
global WebhookScreenshots := IniRead(SettingsFile, "Webhook", "WebhookScreenshots", "1")
global WebhookTriumphScreenshots := IniRead(SettingsFile, "Webhook", "WebhookTriumphScreenshots", 1)

GetDiscordMention(rawId) {
    if (rawId = "" || Trim(rawId) = "")
        return ""
    cleanId := RegExReplace(Trim(rawId), "[<@!>]", "")
    cleanId := Trim(cleanId)
    if (cleanId = "" || !RegExMatch(cleanId, "^\d+$"))
        return ""
    return "<@" cleanId ">"
}
;
global UseRestartBtn := IniRead(SettingsFile, "Options", "UseRestartBtn", "0")
global UsePlayAgainBtn := IniRead(SettingsFile, "Options", "UsePlayAgainBtn", "1")
global AutoEquip := IniRead(SettingsFile, "Options", "AutoEquip", 0)
global ScrollDownForMap := IniRead(SettingsFile, "Options", "ScrollDownForMap", 1)
global ScrollDownAmount := Integer(IniRead(SettingsFile, "Options", "ScrollDownAmount", 5))
if (ScrollDownAmount < 5)
    ScrollDownAmount := 5
else if (ScrollDownAmount > 20)
    ScrollDownAmount := 20
global CheckTheMap := IniRead(SettingsFile, "Options", "CheckTheMap", 0)
global UseNumbersForHotbar := IniRead(SettingsFile, "Options", "UseNumbers", 1)
global UseHForUpgrade := IniRead(SettingsFile, "Options", "UseHotkeyForUpgrade", 1)
global CollectPlaytimeRewards:= IniRead(SettingsFile, "Options", "CollectPlaytimeRewards", "1")
global Strategy1Path := IniRead(SettingsFile, "Options", "Strategy1", "")
global MultiplayerEnabled := 0

global DefaultMouseSpeed := IniRead(SettingsFile, "Options", "DefaultMouseSpeed", "2")
global MouseDelay := IniRead(SettingsFile, "Options", "MouseDelay", "10")
global KeyDelay := IniRead(SettingsFile, "Options", "KeyDelay", "20")

global g_IsFirstLaunch := Integer(IniRead(StateFile, "State", "IsFirstLaunch", 1))

SendMode("Event")
SetDefaultMouseSpeed(DefaultMouseSpeed)
SetMouseDelay(MouseDelay)
SetKeyDelay(KeyDelay)

global LogLines := []
global OverlayHWND := 0
global OverlayBitmap := 0
global OverlayGraphics := 0
global OverlayPicHWND := 0
global OverlayWidth := 500
global OverlayHeight := 200
global OverlayX := 1400
global OverlayY := 820

global StrategyWidth := 1920
global StrategyHeight := 1090

global Slots := [
    ScaleX(800) ", " ScaleY(960), 
    ScaleX(880) ", " ScaleY(960), 
    ScaleX(960) ", " ScaleY(960), 
    ScaleX(1040) ", " ScaleY(960), 
    ScaleX(1120) ", " ScaleY(960)
]

global readyX := 0
global readyY := 0

global ChainKey, BeatKey, CaravanKey, CancelPlacementKey, TimeScaleMode, UseTimeScale, TimeScaleMultiplier
ChainKey := IniRead(SettingsFile, "Hotkeys", "Chain", "C")
BeatKey := IniRead(SettingsFile, "Hotkeys", "Beat", "B")
CaravanKey := IniRead(SettingsFile, "Hotkeys", "Caravan", "J")
global RaiseDeadKey := IniRead(SettingsFile, "Hotkeys", "RaiseTheDead", "V")
global HologramKey := IniRead(SettingsFile, "Hotkeys", "Hologram", "K")
global RepoKey := IniRead(SettingsFile, "Hotkeys", "Repo", "L")
CancelPlacementKey := IniRead(SettingsFile, "Hotkeys", "CancelPlacement", "Q")
global UpgradeTowerGKey := IniRead(SettingsFile, "Hotkeys", "UpgradeTower", "E")
global UpgradeTowerGBKey := IniRead(SettingsFile, "Hotkeys", "UpgradeBottom", "Z")
TimeScaleMode := IniRead(SettingsFile, "Options", "TimeScaleMode", "OFF")
global DebugConsole := IniRead(SettingsFile, "Options", "DebugConsole", "0")

global TimescaleActive := false

if (TimeScaleMode = "1.5x") {
    UseTimeScale := true,  TimeScaleMultiplier := 1.5
} else if (TimeScaleMode = "2x") {
    UseTimeScale := true,  TimeScaleMultiplier := 2
} else {
    UseTimeScale := false, TimeScaleMultiplier := 1
}

global UpgradeDelay := IniRead(SettingsFile, "Options", "UpgradeDelay", 200)
global ScrollDelay := Integer(IniRead(SettingsFile, "Options", "ScrollDelay", 1000))

global gamemap := "", difficulty := "", requiredTowers := ""
global autoChain := "OFF", autoCaravan := "OFF", autoDropTheBeat := "OFF"
global Commander := false, AutoSkip := "ON", AbilitySpam := "ON"

global SpecialMaps := ["Simplicity", "Cataclysm"]

global MoveEnabled := false, MoveDirection := "W", MoveDuration := 750
global unfocusX := 150, unfocusY := 200
global Towers := Map(), RecordedSteps := [], Recording := false, RunningStrategy := false
global modifiers := ""
global LastDisconnectCheck := 0
global LastOpenedTowerID := ""
global IsRestarting := false
global SafeExitFlag := false
global RestartLock := false

global isUiPositionSaved := false
global isUpgradeAuthorized := false
global activeUpgradeRegions := [0, 0, 0, 0]
global CachedMenuUI := {x: 0, y: 0}
global ActiveRTowerID := false

global canUseAbility := true, canBeUpgraded := true, needtocheckTowerUI := true

global KeyDownTimes := Map()

global MacroRecording := false
global MacroSteps := []
global MacroStartTime := 0
global InputHookObj := ""

global LastSkipCheck := 0
global SKIP_CHECK_INTERVAL := 1000
global AutorunStartTime := 0
global watchdogPID := ""

global SC_L:="sc026"
global SC_R:="sc013" 
global SC_Esc:="sc001"
global SC_Enter:="sc01c" 
SC_E:="sc012" ; e

if (DebugConsole = "1")
    ShowDebugConsole()

IconPath := A_WorkingDir "\icon.ico"
if FileExist(IconPath)
    TraySetIcon(IconPath)

WM_LBUTTONDOWN_Drag(wParam, lParam, msg, hwnd) {
    global MainGui
    If (MainGui) {
        if (hwnd != MainGui.Hwnd) {
            return
        }
    }
    mouseY := lParam >> 16
    if (mouseY >= 42)
        return

    PostMessage(0xA1, 2, , , "ahk_id " MainGui.Hwnd)
}

ScaleX(baseX, Width := 1920) {
    getRobloxPos(&pX, &pY, &currentWidth, &currentHeight)
    return Round(baseX * (currentWidth / Width))
}

ScaleY(baseY, Height := 1009) {
    getRobloxPos(&pX, &pY, &currentWidth, &currentHeight)
    return Round(baseY * (currentHeight / Height))
}

sX(baseX, Width := 1920) {
    global StrategyHeight
    hwnd := GetRobloxHWND()
    if !hwnd
        return

    getRobloxPos(&pX, &pY, &currentWidth, &currentHeight, hwnd)
    if (Width == 0) 
        return baseX

    if (Width == 1920 && StrategyHeight == 1090) {
        WinGetClientPos(&cX, , , , "ahk_id " hwnd)
        WinGetPos(&wX, , , , "ahk_id " hwnd)
        currentBorderX := cX - wX
        baseX := baseX - currentBorderX 
        Width := 1920 
    }
    
    return Round(baseX * (currentWidth / Width))
}

sY(baseY, Height := 1090) {
    hwnd := GetRobloxHWND()
    if !hwnd
        return
    getRobloxPos(&pX, &pY, &currentWidth, &currentHeight, hwnd)
    if (Height == 0) 
        return baseY
    
    if (Height == 1090) {
        WinGetClientPos(, &cY, , , "ahk_id " hwnd)
        WinGetPos(, &wY, , , "ahk_id " hwnd)
        currentBorderY := cY - wY
        baseY := baseY - currentBorderY 
        Height := 1009 
    }
    
    return Round(baseY * (currentHeight / Height))
}

Join(arr, delim := ", ") {
    if !IsObject(arr)
        return String(arr)

    str := ""
    for index, value in arr
        str .= (index = 1 ? "" : delim) . value
    return str
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


LegacyConnectionsStart(A_AppData "\Ultimate_Macro\Connections-14", App.RELEASE, App.UPDATE_VERSION)
UpdateHelper.Initialize(SettingsFile, App.UPDATE_VERSION)
autoRun := IniRead(StateFile, "State", "Running",   0)
autoStrat := IniRead(StateFile, "State", "Strategy",  "")
savedStartTime := IniRead(StateFile, "State", "StartTime", 0)

if (savedStartTime != 0)
    AutorunStartTime := Integer(savedStartTime)

if (autoRun = 1 && autoStrat != "" && FileExist(autoStrat)) {
    LoadStrategyFile(autoStrat)
    RunningStrategy := true
    ActivateRoblox()
    RunStrategy()
} else {
    MultiInstanceTools := "RobloxAccountManager.exe,Roblox Account Manager.exe,RAM.exe,RobloxMulti.exe,MultiRoblox.exe,MultipleRoblox.exe,Multiple Roblox.exe"
    Loop Parse, MultiInstanceTools, "," {
        if ProcessExist(A_LoopField) {
            MsgBox("Conflicting program detected:`n" A_LoopField "`n`nFor this script to work properly, please close all Roblox multi-client utilities.`nPlease close them and try again.", "Error", 48)
            ExitApp()
        }
    }
}

global MainGui := Gui("-Caption +Border +LastFound")
MainGui.BackColor := "121212"

global SystemHwnds := Map()

sysBar1 := MainGui.Add("Progress", "x0 y3 w700 h39 Disabled Background0A0A0A", 0)
SystemHwnds[sysBar1.Hwnd] := true

MainGui.SetFont("s11 w300 cFFFFFF", "Segoe UI")
if FileExist(IconPath) {
    sysIcon := MainGui.Add("Picture", "BackgroundTrans x20 y12 w20 h20", IconPath)
    SystemHwnds[sysIcon.Hwnd] := true
}

global GuiTitleCtrl := MainGui.Add("Text", "x50 y12 w150 h25 BackgroundTrans", "Ultimate Macro | TDS")
MW.Bind(GuiTitleCtrl, "Click", MoveWindow)
SystemHwnds[GuiTitleCtrl.Hwnd] := true

MainGui.SetFont("s11 w400 cFFFFFF", "Marlett")
global BtnMin   := MainGui.Add("Text", "x600 y12 w30 h25 Center BackgroundTrans", "0")
MW.Bind(BtnMin, "Click", MinimizeWindow)
SystemHwnds[BtnMin.Hwnd] := true

MainGui.SetFont("s11 w400 c888888", "Marlett")
sysDot := MainGui.Add("Text", "x630 y12 w30 h25 Center BackgroundTrans", "1")
SystemHwnds[sysDot.Hwnd] := true

MainGui.SetFont("s11 w400 cFFFFFF", "Marlett")
global BtnClose := MainGui.Add("Text", "x660 y12 w30 h25 Center BackgroundTrans", "r")
MW.Bind(BtnClose, "Click", CloseWindow)
SystemHwnds[BtnClose.Hwnd] := true

sysLine1 := MainGui.Add("Progress", "x0 y42 w700 h1 Background222222", 0)
SystemHwnds[sysLine1.Hwnd] := true


MainGui.SetFont("s10 w400 c888888", "Segoe UI")
global HoverTab := []
global TabCtrl  := []
global HoverEffect := []
global GradientButtons := []

global DiscordWebhookTab := []
;==

tabNames := ["Main", "Discord", "Settings", "Tools", "Tutorial", "What's Change"]
global tabWidths := [80, 80, 85, 80, 85, 125]
global tabXs := [20, 110, 200, 295, 385, 480]

Loop tabNames.Length {
    i   := A_Index
    xTab := tabXs[i]
    wTab := tabWidths[i]
    
    hBg := MainGui.Add("Progress", "x" xTab " y43 w" wTab " h34 Hidden Background222222 Disabled")
    HoverTab.Push(hBg)
    SystemHwnds[hBg.Hwnd] := true 
    
    t := MainGui.Add("Text", "x" xTab " y52 w" wTab " h22 Center BackgroundTrans", tabNames[i])
    MW.Bind(t, "Click", SelectTab)
    TabCtrl.Push(t)
    SystemHwnds[t.Hwnd] := true 
}

global TabLine := MainGui.Add("Progress", "x20 y75 w80 h2 BackgroundFFFFFF", 0)
SystemHwnds[TabLine.Hwnd] := true 

sysLine2 := MainGui.Add("Progress", "x0 y77 w700 h1 Background222222", 0)
SystemHwnds[sysLine2.Hwnd] := true

; tab 1 - MAIN ===========================

MainGui.SetFont("s10 w400 c3A86FF", "Segoe UI")
global Tab1_Section1 := MainGui.Add("Text", "x30 y92  w200 h22",  "Custom Strategies")
global Tab1_Line1 := MainGui.Add("Progress", "x30 y114 w640 h1  Background333333", 0)

MainGui.SetFont("s9 w400 cAAAAAA", "Segoe UI")
global Tab1_Lbl1 := MainGui.Add("Text", "x30 y123 w75 h20", "Strategy:")
MainGui.SetFont("s9 w400 c000000")
global Strategy1Ctrl := MainGui.Add("Edit", "x110 y120 w400 h22 vStrategy1", Strategy1Path)
MW.Bind(Strategy1Ctrl, "Change", SaveStrat1)
MainGui.SetFont("s9 w400 cFFFFFF")
global Tab1_Btn1 := MainGui.Add("Text", "x515 y120 w70 h22 +Border 0x200 Center", "Browse")
MW.Bind(Tab1_Btn1, "Click", SelectStrat1)
global Tab1_Btn2 := MainGui.Add("Text", "x590 y120 w70 h22 +Border 0x200 Center", "Clear")
MW.Bind(Tab1_Btn2, "Click", ClearStrat1)

HoverEffect.Push(Tab1_Btn1) 
HoverEffect.Push(Tab1_Btn2) 

MainGui.SetFont("s9 w400 cFFFFFF")
global AutoEquipCtrl := MainGui.Add("Checkbox", "x30 y153 vAutoEquip Checked" AutoEquip, "Auto Equip Towers")
MW.Bind(AutoEquipCtrl, "Click", EnableAutoEquip)
global ScrollDownForMapCtrl := MainGui.Add("Checkbox", "x170 y153 vScrollDownForMap Checked" ScrollDownForMap, "Scroll Down for Map")
MW.Bind(ScrollDownForMapCtrl, "Click", EnableScrollDownForMap)
MainGui.SetFont("s9 w400 c000000")
global ScrollDownAmountCtrl := MainGui.Add("Edit", "x320 y150 w42 h22 +Border Number Center vScrollDownAmount", ScrollDownAmount)
global ScrollDownAmountUpDown := MainGui.Add("UpDown", "Range5-20", ScrollDownAmount)
MW.Bind(ScrollDownAmountCtrl, "Change", OnScrollDownAmountChange)
MW.Bind(ScrollDownAmountUpDown, "Change", (ctrl, *) => (
    ScrollDownAmount := ctrl.Value,
    IniWrite(ctrl.Value, SettingsFile, "Options", "ScrollDownAmount")
))

MainGui.SetFont("s9 w400 cAAAAAA", "Segoe UI")
global Tab1_Lbl3 := MainGui.Add("Text", "x375 y153 w60 h20 BackgroundTrans", "Timescale:")
MainGui.SetFont("s9 w400 c000000")
global TimeScaleModeCtrl := MainGui.Add("DropDownList", "x440 y150 w75", ["OFF","1.5x","2x"])
TimeScaleModeCtrl.Text := TimeScaleMode
MW.Bind(TimeScaleModeCtrl, "Change", (*) => SaveAllSettingsQuiet())

; Strategy Modifiers Section
MainGui.SetFont("s10 w400 c3A86FF", "Segoe UI")
global Tab1_ModSection := MainGui.Add("Text", "x30 y202 w200 h20", "Strategy Modifiers")
global Tab1_ModLine := MainGui.Add("Progress", "x30 y222 w640 h1 Background333333", 0)

MainGui.SetFont("s9 w400 cFFFFFF", "Segoe UI")
global ModCb_Gla := MainGui.Add("Checkbox", "x30  y228 w95 h20", "Glass")
global ModCb_Hid := MainGui.Add("Checkbox", "x135 y228 w95 h20", "Hidden")
global ModCb_Exp := MainGui.Add("Checkbox", "x240 y228 w95 h20", "Exploding")
global ModCb_Lim := MainGui.Add("Checkbox", "x345 y228 w95 h20", "Limitation")
global ModCb_Com := MainGui.Add("Checkbox", "x450 y228 w95 h20", "Committed")
global ModCb_Fly := MainGui.Add("Checkbox", "x555 y228 w95 h20", "Flying")

global ModCb_Fog := MainGui.Add("Checkbox", "x30  y250 w95 h20", "Fog")
global ModCb_Qua := MainGui.Add("Checkbox", "x135 y250 w95 h20", "Quarantine")
global ModCb_Inf := MainGui.Add("Checkbox", "x240 y250 w95 h20", "Inflation")
global ModCb_Bro := MainGui.Add("Checkbox", "x345 y250 w95 h20", "Broke")
global ModCb_Spe := MainGui.Add("Checkbox", "x450 y250 w95 h20", "Speedy")
global ModCb_Hea := MainGui.Add("Checkbox", "x555 y250 w95 h20", "Healthy")

MainGui.SetFont("s9 w400 cAAAAAA", "Segoe UI")
global Tab1_ModActiveLbl := MainGui.Add("Text", "x30 y274 w50 h20 BackgroundTrans", "Active:")

MainGui.SetFont("s9 w400 c000000")
global ModifiersTextCtrl := MainGui.Add("Edit", "x85 y272 w455 h22 vModifiersText", modifiers)
MW.Bind(ModifiersTextCtrl, "Change", OnModifiersTextChange)

MainGui.SetFont("s9 w400 cFFFFFF", "Segoe UI")
global Tab1_ModSaveBtn := MainGui.Add("Text", "x550 y271 w120 h24 +Border 0x200 Center", "Save to Strat")
HoverEffect.Push(Tab1_ModSaveBtn)

global ModifierCheckboxes := [
    { ctrl: ModCb_Gla, name: "Glass",        code: "Gla" },
    { ctrl: ModCb_Hid, name: "Hidden",       code: "Hid" },
    { ctrl: ModCb_Exp, name: "Exploding",    code: "Exp" },
    { ctrl: ModCb_Lim, name: "Limitation",   code: "Lim" },
    { ctrl: ModCb_Com, name: "Committed",    code: "Com" },
    { ctrl: ModCb_Fly, name: "Flying",       code: "Fly" },
    { ctrl: ModCb_Fog, name: "Fog",          code: "Fog" },
    { ctrl: ModCb_Qua, name: "Quarantine",   code: "Qua" },
    { ctrl: ModCb_Inf, name: "Inflation",    code: "Inf" },
    { ctrl: ModCb_Bro, name: "Broke",        code: "Bro" },
    { ctrl: ModCb_Spe, name: "Speedy",       code: "Spe" },
    { ctrl: ModCb_Hea, name: "Healthy",      code: "Hea" }
]

for item in ModifierCheckboxes {
    MW.Bind(item.ctrl, "Click", OnModifierCheckboxClick)
}
MW.Bind(Tab1_ModSaveBtn, "Click", OnSaveModifiersBtnClick)

MainGui.SetFont("s11 w400 cFFFFFF", "Segoe UI")
global Tab1_Start := MainGui.Add("Text", "x30 y302 w300 h36 Center Background0e0e0f +Border 0x200", "Start (F1)")
MW.Bind(Tab1_Start, "Click", StartStrategy)
global Tab1_Stop := MainGui.Add("Text",  "x340 y302 w330 h36 Center Background0e0e0f +Border 0x200", "Stop (F2)")
MW.Bind(Tab1_Stop, "Click", StopStrategy)

HoverEffect.Push(Tab1_Start) 
HoverEffect.Push(Tab1_Stop) 

; tab 2 - WEBHOOK (Discord) ===========================

; Section 1: Discord Webhook
MainGui.SetFont("s10 w400 c3A86FF", "Segoe UI")
global Tab4_Title := MainGui.Add("Text", "x30 y92 vTab4_TITLE BackgroundTrans h22 w150 Hidden", "Discord Webhook")
global Tab4_Line1 := MainGui.Add("Progress", "x30 y114 w640 h1 Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cAAAAAA", "Segoe UI")
global Tab4_Lbl1 := MainGui.Add("Text", "x30 y124 w200 h18 Hidden vTab4_Lbl1", "Webhook URL:")
MainGui.SetFont("s9 w400 c000000")
global WebhookLinkCtrl := MainGui.Add("Edit", "x30 y144 w640 h24 Hidden vWebhookLink", WebhookLink)
MW.Bind(WebhookLinkCtrl, "Change", (ctrl, *) => (CheckWebhookLink(ctrl), SetTimer(SaveDiscordSettingsQuiet, -750)))
MainGui.SetFont("s9 w400 cFFFFFF", "Segoe UI")
global WebhookEnabledCtrl := MainGui.Add("Checkbox", "x30 y174 w125 h20 Hidden vWebhookEnabled Checked" WebhookEnabled, "Enable Webhook")
MW.Bind(WebhookEnabledCtrl, "Click", (*) => SaveDiscordSettingsQuiet())
global WebhookSepatateTriumphScreenshotsCtrl := MainGui.Add("Checkbox", "x160 y174 w235 h20 Hidden vWebhookSepatateTriumphScreenshots Checked" WebhookSepatateTriumphScreenshots, "Send Triumph/Loss to separate channel")
MainGui.SetFont("s9 w400 c000000")
global WebhookLinkCtrl2 := MainGui.Add("Edit", "x400 y172 w270 h24 Hidden vWebhookLink2", WebhookLink2)
MW.Bind(WebhookLinkCtrl2, "Change", (ctrl, *) => (CheckWebhookLink2(ctrl), SetTimer(SaveDiscordSettingsQuiet, -750)))
DllCall("user32\SendMessageW", "Ptr", WebhookLinkCtrl2.Hwnd, "UInt", 0x1501, "Ptr", 1, "WStr", "Separate Webhook URL...")
MainGui.SetFont("s9 w400 cFFFFFF", "Segoe UI")

EnableWebhookLink2(*) {
    if !IsSet(MainGui) or !MainGui or !IsSet(WebhookSepatateTriumphScreenshotsCtrl) or !IsSet(WebhookLinkCtrl2)
        return
    WebhookLinkCtrl2.Visible := (WebhookSepatateTriumphScreenshotsCtrl.Value == 1)
}
MW.Bind(WebhookSepatateTriumphScreenshotsCtrl, "Click", (*) => (EnableWebhookLink2(), SaveDiscordSettingsQuiet()))

; Section 2: Webhook Options
MainGui.SetFont("s10 w400 c3A86FF", "Segoe UI")
global Tab4_Section_Options := MainGui.Add("Text", "x30 y200 w200 h22 Hidden", "Webhook Options")
global Tab4_Line2 := MainGui.Add("Progress", "x30 y222 w640 h1 Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cFFFFFF", "Segoe UI")
global SendCurrCtrl := MainGui.Add("Checkbox", "x30 y230 w115 h20 Hidden vSendCurrenciesEnabled Checked" SendCurrenciesEnabled, "Send Statistics")
MW.Bind(SendCurrCtrl, "Click", (CtrlObj, *) => (CtrlObj.Value ? CheckOcrLanguage() : "", SaveDiscordSettingsQuiet()))
global DebugLogsCtrl := MainGui.Add("Checkbox", "x155 y230 w95 h20 Hidden vWebhookDebugLogs Checked" WebhookDebugLogs, "Debug Logs")
MW.Bind(DebugLogsCtrl, "Click", (*) => SaveDiscordSettingsQuiet())
global WebhookScreenshotsCtrl := MainGui.Add("Checkbox", "x260 y230 w160 h20 Hidden vWebhookScreenshots Checked" WebhookScreenshots, "Automatic screenshots")
MW.Bind(WebhookScreenshotsCtrl, "Click", (*) => SaveDiscordSettingsQuiet())
global WebhookTriumphScreenshotsCtrl := MainGui.Add("Checkbox", "x430 y230 w200 h20 Hidden vWebhookTriumphScreenshots Checked" WebhookTriumphScreenshots, "Triumph and Loss screenshots")
MW.Bind(WebhookTriumphScreenshotsCtrl, "Click", (*) => SaveDiscordSettingsQuiet())

; Section 3: Webhook Mentions
MainGui.SetFont("s10 w400 c3A86FF", "Segoe UI")
global Tab4_Section_Mention := MainGui.Add("Text", "x30 y258 w200 h22 Hidden", "Webhook Mentions")
global Tab4_Line_Mention := MainGui.Add("Progress", "x30 y280 w640 h1 Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cAAAAAA", "Segoe UI")
global WebhookUserIDLbl := MainGui.Add("Text", "x30 y292 w55 h20 Hidden BackgroundTrans", "User ID:")
MainGui.SetFont("s9 w400 c000000")
global WebhookUserIDCtrl := MainGui.Add("Edit", "x90 y289 w140 h22 Hidden vWebhookUserID", WebhookUserID)
MW.Bind(WebhookUserIDCtrl, "Change", (*) => SetTimer(SaveDiscordSettingsQuiet, -750))
MainGui.SetFont("s9 w400 cFFFFFF", "Segoe UI")
global WebhookPingOnWinCtrl := MainGui.Add("Checkbox", "x245 y290 w95 h20 Hidden vPingOnWin Checked" PingOnWin, "Ping on Win")
MW.Bind(WebhookPingOnWinCtrl, "Click", (*) => SaveDiscordSettingsQuiet())
global WebhookPingOnLossCtrl := MainGui.Add("Checkbox", "x350 y290 w100 h20 Hidden vPingOnLoss Checked" PingOnLoss, "Ping on Loss")
MW.Bind(WebhookPingOnLossCtrl, "Click", (*) => SaveDiscordSettingsQuiet())
global WebhookPingOnTimescaleCtrl := MainGui.Add("Checkbox", "x460 y290 w185 h20 Hidden vPingOnTimescale Checked" PingOnTimescale, "Timescale Depleted")
MW.Bind(WebhookPingOnTimescaleCtrl, "Click", (*) => SaveDiscordSettingsQuiet())

; Tab4_Btn2 removed - Discord settings auto-save quietly on change/click
DiscordWebhookTab.Push(Tab4_Title,Tab4_Line1,Tab4_Lbl1,WebhookLinkCtrl,WebhookEnabledCtrl,WebhookSepatateTriumphScreenshotsCtrl,Tab4_Section_Options,Tab4_Line2,SendCurrCtrl,DebugLogsCtrl,WebhookScreenshotsCtrl,WebhookTriumphScreenshotsCtrl,Tab4_Section_Mention,Tab4_Line_Mention,WebhookUserIDLbl,WebhookUserIDCtrl,WebhookPingOnWinCtrl,WebhookPingOnLossCtrl,WebhookPingOnTimescaleCtrl)

;TAB 5 - SETTINGS ==========================

MainGui.SetFont("s10 w400 c3A86FF", "Segoe UI")
global Tab5_Section1 := MainGui.Add("Text", "x30 y92  w200 h22 Hidden", "TDS Keybinds")
global Tab5_Line1 := MainGui.Add("Progress", "x30 y114 w250 h1  Hidden Background333333", 0)

MainGui.SetFont("s8 w400 cAAAAAA", "Segoe UI")
global Tab5_Lbl1 := MainGui.Add("Text", "x30 y129 w70 h16 Hidden", "Call of Arms:")
MainGui.SetFont("s8 w400 c000000")
global ChainKeyCtrl := MainGui.Add("Edit", "x105 y126 w40 h18 Center Limit1 Hidden", ChainKey)
MW.Bind(ChainKeyCtrl, "Change", (*) => SetTimer(SaveAllSettingsQuiet, -750))

MainGui.SetFont("s8 w400 cAAAAAA")
global Tab5_Lbl2 := MainGui.Add("Text", "x152 y129 w80 h16 Hidden", "Drop The Beat:")
MainGui.SetFont("s8 w400 c000000")
global BeatKeyCtrl := MainGui.Add("Edit", "x238 y126 w40 h18 Center Limit1 Hidden", BeatKey)
MW.Bind(BeatKeyCtrl, "Change", (*) => SetTimer(SaveAllSettingsQuiet, -750))

MainGui.SetFont("s8 w400 cAAAAAA")
global Tab5_Lbl3 := MainGui.Add("Text", "x30 y153 h16 Hidden", "S. Caravan:")
MainGui.SetFont("s8 w400 c000000")
global CaravanKeyCtrl := MainGui.Add("Edit", "x105 y150 w40 h18 Center Limit1 Hidden", CaravanKey)
MW.Bind(CaravanKeyCtrl, "Change", (*) => SetTimer(SaveAllSettingsQuiet, -750))

MainGui.SetFont("s8 w400 cAAAAAA")
global Tab5_Lbl44 := MainGui.Add("Text", "x152 y153 w80 h16 Hidden", "Raise the Dead:")
MainGui.SetFont("s8 w400 c000000")
global RaiseDeadKeyCtrl := MainGui.Add("Edit", "x238 y150 w40 h18 Center Limit1 Hidden", RaiseDeadKey)
MW.Bind(RaiseDeadKeyCtrl, "Change", (*) => SetTimer(SaveAllSettingsQuiet, -750))
MainGui.SetFont("s9 w400 cFFFFFF", "Segoe UI")
global Tab5_Help12 := MainGui.Add("Text", "x280 y150 w18 h18 0x200 Center Hidden", "?")
MW.Bind(Tab5_Help12, "Click", HelpRaise)

MainGui.SetFont("s8 w400 cAAAAAA")
global Tab5_Lbl55 := MainGui.Add("Text", "x30 y177 h16 Hidden", "Hologram:")
MainGui.SetFont("s8 w400 c000000")
global HologramKeyCtrl := MainGui.Add("Edit", "x105 y174 w40 h18 Center Limit1 Hidden", HologramKey)
MW.Bind(HologramKeyCtrl, "Change", (*) => SetTimer(SaveAllSettingsQuiet, -750))

MainGui.SetFont("s8 w400 cAAAAAA")
global Tab5_Lbl56 := MainGui.Add("Text", "x152 y177 h16 Hidden", "Reposition:")
MainGui.SetFont("s8 w400 c000000")
global RepoKeyCtrl := MainGui.Add("Edit", "x238 y174 w40 h18 Center Limit1 Hidden", RepoKey)
MW.Bind(RepoKeyCtrl, "Change", (*) => SetTimer(SaveAllSettingsQuiet, -750))
MainGui.SetFont("s9 w400 cFFFFFF", "Segoe UI")
global Tab5_Help11 := MainGui.Add("Text", "x280 y174 w18 h18 0x200 Center Hidden", "?")
MW.Bind(Tab5_Help11, "Click", HelpBrawler)

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab5_LblUPG := MainGui.Add("Text", "x30 y201 BackgroundTrans Hidden", "upgrade:")
MainGui.SetFont("s8 w400 c000000")
global UpgradeTowerGCtrl := MainGui.Add("Edit", "x85 y199 w18 h18 Center Limit1 Hidden", UpgradeTowerGKey)
MW.Bind(UpgradeTowerGCtrl, "Change", (*) => SetTimer(SaveAllSettingsQuiet, -750))

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab5_LblUPGBTM := MainGui.Add("Text", "x108 y201 BackgroundTrans Hidden", "bottom:")
MainGui.SetFont("s8 w400 c000000")
global UpgradeTowerGBCtrl := MainGui.Add("Edit", "x158 y199 w18 h18 Center Limit1 Hidden", UpgradeTowerGBKey)
MW.Bind(UpgradeTowerGBCtrl, "Change", (*) => SetTimer(SaveAllSettingsQuiet, -750))

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab5_Lbl99 := MainGui.Add("Text", "x183 y201 BackgroundTrans Hidden", "cancel:")
MainGui.SetFont("s8 w400 c000000")
global CancelPlacementKeyCtrl := MainGui.Add("Edit", "x230 y199 w18 h18 Center Limit1 Hidden", CancelPlacementKey)
MW.Bind(CancelPlacementKeyCtrl, "Change", (*) => SetTimer(SaveAllSettingsQuiet, -750))

MainGui.SetFont("s9 w400 cFFFFFF")

; Right Column: Macro Settings
MainGui.SetFont("s10 w400 c3A86FF", "Segoe UI")
global Tab5_Section2 := MainGui.Add("Text", "x330 y92 w200 h22 Hidden BackgroundTrans", "Macro Settings")
global Tab5_Line2 := MainGui.Add("Progress", "x330 y114 w340 h1 Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cFFFFFF", "Segoe UI")
global UseUpgradeHCtrl := MainGui.Add("Checkbox", "x330 y126 Hidden", "Use Hotkeys for Upgrading")
UseUpgradeHCtrl.Value := (UseHForUpgrade = 1)
MW.Bind(UseUpgradeHCtrl, "Click", (*) => SaveAllSettingsQuiet())
global Tab5_Help6 := MainGui.Add("Text", "x495 y124 w18 h18 0x200 Center Hidden", "?")
MW.Bind(Tab5_Help6, "Click", HelpAutoCameraCorrection)

global UseRestartBtnCtrl := MainGui.Add("Checkbox", "x330 y150 Hidden", "Click Restart button")
UseRestartBtnCtrl.Value := (UseRestartBtn = "1" || UseRestartBtn = 1)
MW.Bind(UseRestartBtnCtrl, "Click", (*) => SaveAllSettingsQuiet())
global Tab5_Help4 := MainGui.Add("Text", "x465 y148 w18 h18 0x200 Center Hidden", "?")
MW.Bind(Tab5_Help4, "Click", HelpRestartBtn)

global UsePlayAgainBtnCtrl := MainGui.Add("Checkbox", "x330 y174 Hidden", "Click Play Again button")
UsePlayAgainBtnCtrl.Value := (UsePlayAgainBtn = "1" || UsePlayAgainBtn = 1)
MW.Bind(UsePlayAgainBtnCtrl, "Click", (*) => SaveAllSettingsQuiet())
global Tab5_Help5 := MainGui.Add("Text", "x485 y172 w18 h18 0x200 Center Hidden", "?")
MW.Bind(Tab5_Help5, "Click", HelpPlayAgainBtn)

global CheckTheMapCtrl := MainGui.Add("Checkbox", "x330 y198 Hidden", "Check the map")
CheckTheMapCtrl.Value := (CheckTheMap = "1" || CheckTheMap = 1)
MW.Bind(CheckTheMapCtrl, "Click", (*) => SaveAllSettingsQuiet())
global Tab5_Help7 := MainGui.Add("Text", "x440 y196 w18 h18 0x200 Center Hidden", "?")
MW.Bind(Tab5_Help7, "Click", HelpCheckTheMap)

global UseNumbersForHotbarCtrl := MainGui.Add("Checkbox", "x520 y126 Hidden", "Use Numbers for Hotbar")
UseNumbersForHotbarCtrl.Value := (UseNumbersForHotbar = "1" || UseNumbersForHotbar = 1)
MW.Bind(UseNumbersForHotbarCtrl, "Click", (*) => SaveAllSettingsQuiet())

global CollectPlaytimeRewardsCtrl := MainGui.Add("Checkbox", "x520 y150 Hidden", "Collect playtime rewards")
CollectPlaytimeRewardsCtrl.Value := (CollectPlaytimeRewards = "1" || CollectPlaytimeRewards = 1)
MW.Bind(CollectPlaytimeRewardsCtrl, "Click", (*) => SaveAllSettingsQuiet())

MainGui.SetFont("s9 w400 cAAAAAA", "Segoe UI")
global Tab1_Lbl4 := MainGui.Add("Text", "x520 y176 w85 h20 Hidden BackgroundTrans", "Upgrade Delay:")
MainGui.SetFont("s8 w400 c000000")
global UpgradeDelayCtrl := MainGui.Add("Edit", "x610 y172 w55 h20 Hidden Number Limit3 vUpgradeDelay", UpgradeDelay)
UpgradeDelayCtrl.Text := UpgradeDelay
MW.Bind(UpgradeDelayCtrl, "Change", (*) => SetTimer(SaveAllSettingsQuiet, -750))

MainGui.SetFont("s9 w400 cAAAAAA", "Segoe UI")
global Tab5_LblScrollDelay := MainGui.Add("Text", "x520 y200 w85 h20 Hidden BackgroundTrans", "Scroll Delay:")
MainGui.SetFont("s8 w400 c000000")
global ScrollDelayCtrl := MainGui.Add("Edit", "x610 y196 w55 h20 Hidden Number Limit4 vScrollDelay", ScrollDelay)
ScrollDelayCtrl.Text := ScrollDelay
MW.Bind(ScrollDelayCtrl, "Change", (*) => SetTimer(SaveAllSettingsQuiet, -750))

; Lower Section: Timing, Delays & VIP Server
global Tab5_Line4 := MainGui.Add("Progress", "x30 y230 w640 h1 Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cFFFFFF", "Segoe UI")
global MouseSpeedLbl := MainGui.Add("Text", "x30 y244 w75 h20 Hidden BackgroundTrans", "Mouse Speed:")
global MouseSpeedTxt := MainGui.Add("Text", "x107 y244 w26 Hidden", DefaultMouseSpeed)
global MouseSpeedUpDown := MainGui.Add("UpDown", "Range1-3 Hidden", DefaultMouseSpeed)
MW.Bind(MouseSpeedUpDown, "Change", (ctrl, *) => (MouseSpeedTxt.Value := ctrl.Value, SaveAllSettingsQuiet()))

global MouseDelayLbl := MainGui.Add("Text", "x155 y244 w75 h20 Hidden BackgroundTrans", "Mouse Delay:")
global MouseDelayTxt := MainGui.Add("Text", "x232 y244 w30 Hidden", MouseDelay)
global MouseDelayUpDown := MainGui.Add("UpDown", "Range3-75 Hidden", MouseDelay)
MW.Bind(MouseDelayUpDown, "Change", (ctrl, *) => (MouseDelayTxt.Value := ctrl.Value, SaveAllSettingsQuiet()))

global KeyDelayLbl := MainGui.Add("Text", "x285 y244 w60 h20 Hidden BackgroundTrans", "Key Delay:")
global KeyDelayTxt := MainGui.Add("Text", "x347 y244 w30 Hidden", KeyDelay)
global KeyDelayUpDown := MainGui.Add("UpDown", "Range5-100 Hidden", KeyDelay)
MW.Bind(KeyDelayUpDown, "Change", (ctrl, *) => (KeyDelayTxt.Value := ctrl.Value, SaveAllSettingsQuiet()))

global UseVipServerCtrl := MainGui.Add("Checkbox", "x415 y244 w115 h20 Hidden", "Use VIP Server")
UseVipServerCtrl.Value := (UseVipServer = "1" || UseVipServer = 1)
MW.Bind(UseVipServerCtrl, "Click", (*) => SaveAllSettingsQuiet())

global AlwaysOnTopCtrl := MainGui.Add("Checkbox", "x545 y244 w120 h20 Hidden", "Always On Top")
AlwaysOnTopCtrl.Value := (AlwaysOnTop = "1" || AlwaysOnTop = 1)
MW.Bind(AlwaysOnTopCtrl, "Click", (*) => SaveAllSettingsQuiet())

MainGui.SetFont("s9 w400 cAAAAAA", "Segoe UI")
global Tab5_Lbl4 := MainGui.Add("Text", "x30 y274 w95 h20 Hidden BackgroundTrans", "VIP Server Link:")
MainGui.SetFont("s9 w400 c000000")
global VipLinkCtrl := MainGui.Add("Edit", "x130 y271 w540 h22 Hidden", VipLink)
MW.Bind(VipLinkCtrl, "Change", (ctrl, *) => (CheckVipLink(ctrl), SetTimer(SaveAllSettingsQuiet, -750)))

; Tab5_Btn1 removed - All settings auto-save quietly on change/toggle

; tab 4 - tools ===========================

MainGui.SetFont("s10 w400 c3A86FF", "Segoe UI")
global Tools_Section := MainGui.Add("Text", "x30 y92 w200 h22 Hidden", "Tools")
global Tools_Section_Line := MainGui.Add("Progress", "x30 y114 w640 h1 Hidden Background333333", 0)

global Auto_Spin := MainGui.Add("Picture", "x130 y145 w197 h139 Hidden", "Resources/Gui/auto_spin_preview.png")
MW.Bind(Auto_Spin, "Click", RunAutoSpinTool)

global Auto_Consum := MainGui.Add("Picture", "x370 y145 w200 h140 Hidden", "Resources/Gui/auto_open_consumable_preview.png")
MW.Bind(Auto_Consum, "Click", RunAutoConsumableTool)


; tab 5 - tutorial =========================

global TutorialTab := []

MainGui.SetFont("s10 w600 c3A86FF", "Segoe UI")
global Tut_Title := MainGui.Add("Text", "x30 y92 w450 h22 Hidden BackgroundTrans", "Prerequisites && Setup Tutorial")
global Tut_TopLine := MainGui.Add("Progress", "x30 y114 w640 h1 Hidden Background333333", 0)
TutorialTab.Push(Tut_Title, Tut_TopLine)

; --- Column 1: Windows Settings ---
MainGui.SetFont("s9 bold c3A86FF", "Segoe UI")
global Tut_Col1_Title := MainGui.Add("Text", "x30 y120 w200 h18 Hidden BackgroundTrans", "■ 1. Windows Settings")
global Tut_Col1_Line := MainGui.Add("Progress", "x30 y139 w200 h1 Hidden Background2A2A2A", 0)
TutorialTab.Push(Tut_Col1_Title, Tut_Col1_Line)

MainGui.SetFont("s8.5 w500 cFFFFFF", "Segoe UI")
global Tut_Win_Res := MainGui.Add("Text", "x30 y144 w200 h15 Hidden BackgroundTrans", "• Resolution: 1920x1080 (16:9)")
MainGui.SetFont("s8 w400 c888888", "Segoe UI")
global Tut_Win_ResSub := MainGui.Add("Text", "x38 y159 w192 h14 Hidden BackgroundTrans", "  Recommended baseline (16:9)")

MainGui.SetFont("s8.5 w500 cFFFFFF", "Segoe UI")
global Tut_Win_Scale := MainGui.Add("Text", "x30 y175 w200 h15 Hidden BackgroundTrans", "• Display Scale: 100% (Required)")
MainGui.SetFont("s8 w400 c888888", "Segoe UI")
global Tut_Win_ScaleSub := MainGui.Add("Text", "x38 y190 w192 h14 Hidden BackgroundTrans", "  Strictly 100% to avoid click drift")

MainGui.SetFont("s8.5 w500 cFFFFFF", "Segoe UI")
global Tut_Win_Lang := MainGui.Add("Text", "x30 y206 w200 h15 Hidden BackgroundTrans", "• Windows Language: English (US)")
MainGui.SetFont("s8 w400 c888888", "Segoe UI")
global Tut_Win_LangSub := MainGui.Add("Text", "x38 y221 w192 h14 Hidden BackgroundTrans", "  English (US) OCR pack required")

MainGui.SetFont("s8.5 w500 cFFFFFF", "Segoe UI")
global Tut_Win_Taskbar := MainGui.Add("Text", "x30 y237 w200 h15 Hidden BackgroundTrans", "• Taskbar: Always Visible")
MainGui.SetFont("s8 w400 c888888", "Segoe UI")
global Tut_Win_TaskbarSub := MainGui.Add("Text", "x38 y252 w192 h14 Hidden BackgroundTrans", "  Do not set taskbar to auto-hide")

MainGui.SetFont("s8 w400 cFFFFFF", "Segoe UI")
global Tut_BtnDisplay := MainGui.Add("Text", "x30 y270 w96 h22 +Border 0x200 Center Background0E0E0F Hidden", "Display Settings")
global Tut_BtnLang := MainGui.Add("Text", "x134 y270 w96 h22 +Border 0x200 Center Background0E0E0F Hidden", "Language / OCR")
MW.Bind(Tut_BtnDisplay, "Click", OpenDisplaySettings)
MW.Bind(Tut_BtnLang, "Click", OpenLanguageSettings)
HoverEffect.Push(Tut_BtnDisplay)
HoverEffect.Push(Tut_BtnLang)
TutorialTab.Push(Tut_Win_Res, Tut_Win_ResSub, Tut_Win_Scale, Tut_Win_ScaleSub, Tut_Win_Lang, Tut_Win_LangSub, Tut_Win_Taskbar, Tut_Win_TaskbarSub, Tut_BtnDisplay, Tut_BtnLang)

; --- Column 2: Roblox Client ---
MainGui.SetFont("s9 bold c06D6A0", "Segoe UI")
global Tut_Col2_Title := MainGui.Add("Text", "x245 y120 w200 h18 Hidden BackgroundTrans", "■ 2. Roblox Client")
global Tut_Col2_Line := MainGui.Add("Progress", "x245 y139 w200 h1 Hidden Background2A2A2A", 0)
TutorialTab.Push(Tut_Col2_Title, Tut_Col2_Line)

MainGui.SetFont("s8.5 w500 cFFFFFF", "Segoe UI")
global Tut_Rbx_Vc := MainGui.Add("Text", "x245 y144 w200 h15 Hidden BackgroundTrans", "• Voice Chat: Enabled on Account")
MainGui.SetFont("s8 w400 c888888", "Segoe UI")
global Tut_Rbx_VcSub := MainGui.Add("Text", "x253 y159 w192 h14 Hidden BackgroundTrans", "  (Feature must exist in settings)")

MainGui.SetFont("s8.5 w500 cFFFFFF", "Segoe UI")
global Tut_Rbx_CamText := MainGui.Add("Text", "x245 y175 w200 h15 Hidden BackgroundTrans", "• Camera / Text Size: Default")
global Tut_Rbx_Gfx := MainGui.Add("Text", "x245 y191 w200 h15 Hidden BackgroundTrans", "• Graphics Quality: 1 (Lowest/Manual)")
global Tut_Rbx_Screen := MainGui.Add("Text", "x245 y207 w200 h15 Hidden BackgroundTrans", "• Fullscreen: OFF (Windowed Mode)")
global Tut_Rbx_Fps := MainGui.Add("Text", "x245 y223 w200 h15 Hidden BackgroundTrans", "• Max FPS: 60 / Default Fonts Only")
global Tut_Rbx_Nav := MainGui.Add("Text", "x245 y239 w200 h15 Hidden BackgroundTrans", "• UI Navigation Toggle: Enabled")

MainGui.SetFont("s8.5 bold cFFB703", "Segoe UI")
global Tut_Rbx_Avatar := MainGui.Add("Text", "x245 y258 w200 h15 Hidden BackgroundTrans", "★ Avatar Scaling && Body Type:")
MainGui.SetFont("s8 w400 cFFFFFF", "Segoe UI")
global Tut_Rbx_AvatarSub1 := MainGui.Add("Text", "x253 y274 w192 h14 Hidden BackgroundTrans", "  Configure per strategy guide")
MainGui.SetFont("s8 w400 c888888", "Segoe UI")
global Tut_Rbx_AvatarSub2 := MainGui.Add("Text", "x253 y289 w192 h14 Hidden BackgroundTrans", "  (Match R6 / R15 && body scales)")
TutorialTab.Push(Tut_Rbx_Vc, Tut_Rbx_VcSub, Tut_Rbx_CamText, Tut_Rbx_Gfx, Tut_Rbx_Screen, Tut_Rbx_Fps, Tut_Rbx_Nav, Tut_Rbx_Avatar, Tut_Rbx_AvatarSub1, Tut_Rbx_AvatarSub2)

; --- Column 3: TDS Settings ---
MainGui.SetFont("s9 bold cFFB703", "Segoe UI")
global Tut_Col3_Title := MainGui.Add("Text", "x460 y120 w210 h18 Hidden BackgroundTrans", "■ 3. TDS Settings")
global Tut_Col3_Line := MainGui.Add("Progress", "x460 y139 w210 h1 Hidden Background2A2A2A", 0)
TutorialTab.Push(Tut_Col3_Title, Tut_Col3_Line)

MainGui.SetFont("s8.5 w500 cFFFFFF", "Segoe UI")
global Tut_Tds_Scale := MainGui.Add("Text", "x460 y144 w210 h15 Hidden BackgroundTrans", "• UI Scale: Large (Required)")
global Tut_Tds_Shake := MainGui.Add("Text", "x460 y164 w210 h15 Hidden BackgroundTrans", "• Camera Shake: OFF (Disabled)")
global Tut_Tds_Vert := MainGui.Add("Text", "x460 y184 w210 h15 Hidden BackgroundTrans", "• Prefer Vertical Upgrades: ON")
global Tut_Tds_Opts := MainGui.Add("Text", "x460 y204 w210 h15 Hidden BackgroundTrans", "• Dialog: OFF / Tower Options: ON")
global Tut_Tds_Binds := MainGui.Add("Text", "x460 y224 w210 h15 Hidden BackgroundTrans", "• TDS Keybinds: Match Macro Settings")

MainGui.SetFont("s8.5 bold cFFB703", "Segoe UI")
global Tut_Tds_Skip := MainGui.Add("Text", "x460 y248 w210 h15 Hidden BackgroundTrans", "★ Auto Skip Waves (Autoskip):")
MainGui.SetFont("s8 w400 cFFFFFF", "Segoe UI")
global Tut_Tds_SkipSub1 := MainGui.Add("Text", "x468 y265 w202 h14 Hidden BackgroundTrans", "  Configure per strategy guide")
MainGui.SetFont("s8 w400 c888888", "Segoe UI")
global Tut_Tds_SkipSub2 := MainGui.Add("Text", "x468 y281 w202 h14 Hidden BackgroundTrans", "  (Different strats require ON or OFF)")
TutorialTab.Push(Tut_Tds_Scale, Tut_Tds_Shake, Tut_Tds_Vert, Tut_Tds_Opts, Tut_Tds_Binds, Tut_Tds_Skip, Tut_Tds_SkipSub1, Tut_Tds_SkipSub2)


; tab 6 - what's changed ====================

MainGui.SetFont("s10 w400 c3A86FF", "Segoe UI")
global Change_Title := MainGui.Add("Text", "x30 y92 w350 h22 Hidden", "What's Changed")
global Change_Line := MainGui.Add("Progress", "x30 y114 w640 h1 Hidden Background333333", 0)

; Scroll buttons for changelog
MainGui.SetFont("s9 bold c888888", "Segoe UI")
global Change_BtnUp := MainGui.Add("Text", "x646 y120 w22 h24 Center +Border Background18181c 0x200 Hidden", "▲")
global Change_BtnDn := MainGui.Add("Text", "x646 y268 w22 h24 Center +Border Background18181c 0x200 Hidden", "▼")
MW.Bind(Change_BtnUp, "Click", (*) => ScrollChangelogUp())
MW.Bind(Change_BtnDn, "Click", (*) => ScrollChangelogDown())
HoverEffect.Push(Change_BtnUp)
HoverEffect.Push(Change_BtnDn)

; Child GUI for scrollable accordion
global ChildGui := Gui("+Parent" MainGui.Hwnd " -Caption +ToolWindow", "")
ChildGui.BackColor := "0e0e0f"

global ChangelogItems := [
    ; --- FIXES ---
    { type: "cat", title: "  ■  BUG FIXES", col: "cFF5964" },
    { type: "item", cat: "FIX", title: "MOLTEN ABILITY CRASH", col: "cFF5964",
      cause: "> Cause of Bug:`n  • Tower ID was not validated before firing abilities, causing an unhandled crash.",
      fix:   "> Fix Details:`n  • Added pre-call ID validation and safe exception wrapper to completely stop crashes." },
    { type: "item", cat: "FIX", title: "REWARD STATS DETECTION", col: "cFF5964", h: 72,
      cause: "> Cause of Bug:`n  • Single scan method easily missed reward stats (Coins, Gems, EXP) or timed out before animations settled.",
      fix:   "> Fix Details:`n  • Multi-step detection pipeline: Memory reading, adaptive OCR scanning, and 3-pass retry fallbacks.`n  • Fixed detection misses by cross-verifying game memory and OCR with account EXP prioritization." },
    { type: "item", cat: "FIX", title: "END-GAME MOUSE HOVER PREVENTION", col: "cFF5964",
      cause: "> Cause of Bug:`n  • Mouse cursor stayed in screen center on match end, triggering card hover tooltips.",
      fix:   "> Fix Details:`n  • Automatically parks cursor to safe top-left corner on game end to prevent card hover." },
    { type: "item", cat: "FIX", title: "PLAYTIME REWARDS CLAIM & RED-DOT", col: "cFF5964", h: 72,
      cause: "> Cause of Bug:`n  • Gift icon failed to open, outdated close images broke exit, and Play button coordinates shifted.",
      fix:   "> Fix Details:`n  • Added modern x.png / close_freerewards.png, RGB delta red-dot check, and fresh Play button re-scan." },

    ; --- OPTIMIZATIONS ---
    { type: "cat", title: "  ■  OPTIMIZATIONS", col: "c06D6A0" },
    { type: "item", cat: "OPTIMIZE", title: "PERFORMANCE & WATCHDOG CLEANUP", col: "c06D6A0",
      cause: "> Reason for Change:`n  • Frequent 100ms watchdog loops and loose timers wasted CPU cycles and dropped FPS.",
      fix:   "> Optimization Details:`n  • Integrated watchdogs into main game loop and trimmed webhook timeouts by 10s." },
    { type: "item", cat: "OPTIMIZE", title: "REMOVED BLOATWARE & UNUSED FEATURES", col: "c06D6A0", h: 118,
      cause: "> Reason for Change:`n  • Unused legacy modes, potato mode, and strategy rotation caused crashes, desyncs, and high CPU.",
      fix:   "> Removed Features (Bloatware Cleanup):`n  • Removed Legacy Mode: Slow GDI fallback & legacy coordinate logic`n  • Removed Potato Mode: Forced sleeps (100ms+) & OCR-breaking scale`n  • Removed Strategy Rotation: Buggy multi-strat cycle & state desync`n  • Removed Manual Save Buttons: Replaced with quiet background auto-save`n  • Removed Unused Dead Code: Purged 40+ lines of redundant functions" },

    ; --- FEATURES ---
    { type: "cat", title: "  ■  NEW FEATURES", col: "c3A86FF" },
    { type: "item", cat: "FEATURE", title: "AUTOSAVE ALL SETTINGS", col: "c3A86FF",
      cause: "> Reason for Change:`n  • Manually clicking 'Save' buttons every time was tedious and frequently forgotten.",
      fix:   "> Feature Details:`n  • All checkboxes, keys, and inputs now silently auto-save in background (2 save buttons removed)." },
    { type: "item", cat: "FEATURE", title: "MAIN TAB TIMESCALE SELECTION", col: "c3A86FF",
      cause: "> Reason for Change:`n  • Changing game speed required switching back and forth to the Settings tab.",
      fix:   "> Feature Details:`n  • Moved timescale dropdown directly to Main tab next to 'Scroll Down for Map'." },
    { type: "item", cat: "FEATURE", title: "LOBBY MAP SCROLL DOWN", col: "c3A86FF",
      cause: "> Reason for Change:`n  • Bottom lobby maps (such as Molten) could not be selected when off-screen.",
      fix:   "> Feature Details:`n  • Automatically scrolls down lobby list before selecting map to ensure reliable detection." },
    { type: "item", cat: "FEATURE", title: "IN-APP STRATEGY MODIFIERS", col: "c3A86FF",
      cause: "> Reason for Change:`n  • Modifying 3-letter modifiers (Gla, Hid, etc.) required opening strategy files in Notepad.",
      fix:   "> Feature Details:`n  • Checkboxes on Main tab allow instant toggle with real-time sync into strategy files." },
    { type: "item", cat: "FEATURE", title: "DISCORD USER PINGS & ALERTS", col: "c3A86FF",
      cause: "> Reason for Change:`n  • Standard webhook messages lacked user pings, making phone notifications easy to miss.",
      fix:   "> Feature Details:`n  • Added Discord user ID (<@ID>) pings on Win/Loss and instant alert on Timescale ticket depletion." }
]

global ChangelogCtrls := []
global changelogScrollY := 0
global maxChangelogScroll := 0

for idx, item in ChangelogItems {
    if (item.type = "cat") {
        ChildGui.SetFont("s8 bold " item.col, "Segoe UI")
        banner := ChildGui.Add("Text", "x0 y0 w606 h20 +Border Background141418 0x200 0x80", item.title)
        ChangelogCtrls.Push({type: "cat", ctrl: banner, data: item})
    } else {
        item.expanded := false
        ChildGui.SetFont("s9 bold " item.col, "Segoe UI")
        hBtn := ChildGui.Add("Text", "x0 y0 w606 h26 +Border Background18181c 0x200 0x80", "  ▶  [" item.cat "] " item.title)
        
        detH := item.HasProp("h") ? item.h : 58
        ChildGui.SetFont("s8 w400 cCCCCCC", "Segoe UI")
        dTxt := ChildGui.Add("Text", "x8 y0 w596 h" detH " Hidden Background121214 +Border 0x80", item.cause "`n" item.fix)
        
        MW.Bind(hBtn, "Click", MakeChangelogToggle(idx))
        ChangelogCtrls.Push({type: "item", header: hBtn, detail: dTxt, data: item})
    }
}
UpdateChangelogLayout()

MakeChangelogToggle(i) {
    return (*) => ToggleChangelogItem(i)
}

ToggleChangelogItem(i) {
    global ChangelogCtrls
    it := ChangelogCtrls[i]
    if (it.type != "item")
        return
    it.data.expanded := !it.data.expanded
    it.header.Text := (it.data.expanded ? "  ▼  [" : "  ▶  [") it.data.cat "] " it.data.title
    UpdateChangelogLayout()
    try it.header.Redraw()
}

UpdateChangelogLayout() {
    global changelogScrollY, maxChangelogScroll, ChangelogCtrls
    y := -changelogScrollY
    
    for it in ChangelogCtrls {
        if (it.type = "cat") {
            it.ctrl.Move(0, y, 606, 20)
            y += 24
        } else {
            it.header.Move(0, y, 606, 26)
            y += 28
            
            if (it.data.expanded) {
                it.detail.Visible := true
                detH := it.data.HasProp("h") ? it.data.h : 58
                it.detail.Move(8, y, 596, detH)
                y += detH + 4
            } else {
                it.detail.Visible := false
            }
        }
    }
    
    totalH := y + changelogScrollY
    maxChangelogScroll := Max(0, totalH - 172)
    if (changelogScrollY > maxChangelogScroll) {
        changelogScrollY := maxChangelogScroll
        if (changelogScrollY < 0)
            changelogScrollY := 0
    }
    try ChildGui.Redraw()
}

ScrollChangelogUp(*) {
    global changelogScrollY
    if (changelogScrollY > 0) {
        changelogScrollY := Max(0, changelogScrollY - 35)
        UpdateChangelogLayout()
    }
}

ScrollChangelogDown(*) {
    global changelogScrollY, maxChangelogScroll
    if (changelogScrollY < maxChangelogScroll) {
        changelogScrollY := Min(maxChangelogScroll, changelogScrollY + 35)
        UpdateChangelogLayout()
    }
}

ChangelogMouseWheel(wParam, lParam, msg, hwnd) {
    global CurrentTab
    if (CurrentTab != "Tab6")
        return
    distance := (wParam >> 16) & 0xFFFF
    if (distance > 0x7FFF)
        distance := distance - 0x10000
    
    if (distance > 0)
        ScrollChangelogUp()
    else
        ScrollChangelogDown()
}
OnMessage(0x020A, ChangelogMouseWheel)

; Footer Line & Version
global Divider := MainGui.Add("Progress", "x30 y304 w640 h1 Hidden Background333333", 0)
MainGui.SetFont("s9 italic c888888", "Segoe UI")
global version_text := MainGui.Add("Text", "x30 y314 w450 h20 Hidden BackgroundTrans", ver " * TDS Macro IlMlN Edition")
MW.Bind(version_text, "Click", (*) => CheckForUpdates(true))

MainGui.Title := "Ultimate Macro"
MainGui.Show("w700 h350 Hide")

if (AlwaysOnTop = 1) {
    MainGui.Opt("+AlwaysOnTop")
} else {
    MainGui.Opt("-AlwaysOnTop")
}

SetTimer(() => RemoveInitialFocus(), -50)

global CurrentTab := "Tab1"
TabCtrl[1].SetFont("cFFFFFF")
ShowTabContent("Tab1")
if (Strategy1Path != "" && FileExist(Strategy1Path)) {
    try UpdateModifierUI(IniRead(Strategy1Path, "Settings", "modifiers", ""))
} else {
    try UpdateModifierUI(IniRead(SettingsFile, "Options", "Modifiers", ""))
}

#Include %A_ScriptDir%\app\RecorderBridge.ahk
#Include %A_ScriptDir%\app\LegacyRecorder.ahk
#Include %A_ScriptDir%\app\RecorderControls.ahk
MW.Open()
InstallResidentTrayMenu()
SetTimer(Hoverwatchdog, 10)
SetTimer(() => CheckForUpdates(false), -1500)

OnMessage(0x0201, WM_LBUTTONDOWN_Drag)

RemoveInitialFocus() {
    if !WinActive("ahk_id " MainGui.Hwnd)
        return
    ControlFocus(GuiTitleCtrl, "ahk_id " MainGui.Hwnd)
}

~F1:: StartStrategy(0, 0)
~F2:: StopStrategy(0, 0)

SelectTab(ctrl, *) {
    global CurrentTab, TabCtrl, TabLine, HoverTab
    idx := 0
    Loop HoverTab.Length {
        if (TabCtrl[A_Index] = ctrl) {
            idx := A_Index
            break
        }
    }
    if (!idx)
        return
    newTab := "Tab" idx
    if (newTab = CurrentTab)
        return
    
    oldIdx := Integer(SubStr(CurrentTab, 4))
    TabCtrl[oldIdx].SetFont("c888888")
    HideAllTabContent()
    
    CurrentTab := newTab
    TabCtrl[idx].SetFont("cFFFFFF")
    
    
    global tabXs, tabWidths
    TabLine.Move(tabXs[idx], , tabWidths[idx])
    
    ShowTabContent(newTab)
}

Hoverwatchdog(*) {
    static hClose := 0, hMin := 0, hMain := 0, hChild := 0
    static hoverClose := false, hoverMin := false
    static hoverTabs := [false, false, false, false, false, false]
    static activeHoverHwnd := 0
    
    if (!hMain)
        hMain := MainGui.Hwnd
    
    oldMode := A_CoordModeMouse
    CoordMode("Mouse", "Screen")
    MouseGetPos(&screenX, &screenY, &mouseWin, &mouseCtrl, 2)
    CoordMode("Mouse", oldMode)
    
    try {
        WinGetPos(&mX, &mY,,, "ahk_id " hMain)
        mouseX := screenX - mX
        mouseY := screenY - mY
    } catch {
        mouseX := 0
        mouseY := 0
    }
    
    if (mouseWin != hMain) {
        Loop HoverTab.Length {
            if (hoverTabs[A_Index]) {
                HoverTab[A_Index].Visible := false
                if (CurrentTab != "Tab" A_Index)
                    TabCtrl[A_Index].SetFont("c888888")
                hoverTabs[A_Index] := false
            }
        }
        if (hoverClose) { 
            BtnClose.SetFont("cFFFFFF")
            hoverClose := false 
        }
        if (hoverMin) { 
            BtnMin.SetFont("cFFFFFF")
            hoverMin := false 
        }
        
        if (activeHoverHwnd != 0 && IsSet(HoverEffect)) {
            for ctrl in HoverEffect {
                if (ctrl.Hwnd = activeHoverHwnd) {
                    if RegExMatch(ctrl.name, "i)Title") {
                        ctrl.Opt("BackgroundTrans")
                        ctrl.SetFont("c3A86FF Norm")
                    } else {
                        ctrl.Opt("Background0E0E0F")
                        ctrl.SetFont("cFFFFFF Norm")
                    }
                    ctrl.Redraw()
                    break
                }
            }
            activeHoverHwnd := 0
        }
        return
    }
    
    if (!hClose) {
        hClose := BtnClose.Hwnd
        hMin := BtnMin.Hwnd
    }
    
    if (mouseCtrl = hClose) {
        if (!hoverClose) { 
            BtnClose.SetFont("cFF4D4D")
            hoverClose := true 
        }
    } else if (hoverClose) { 
        BtnClose.SetFont("cFFFFFF")
        hoverClose := false 
    }

    if (mouseCtrl = hMin) {
        if (!hoverMin) { 
            BtnMin.SetFont("c3A86FF")
            hoverMin := true 
        }
    } else if (hoverMin) { 
        BtnMin.SetFont("cFFFFFF")
        hoverMin := false 
    }
    
    Loop HoverTab.Length {
        hTab := TabCtrl[A_Index].Hwnd
        if (mouseCtrl = hTab) {
            if (!hoverTabs[A_Index]) {
                HoverTab[A_Index].Visible := true
                TabCtrl[A_Index].SetFont("cFFFFFF")
                hoverTabs[A_Index] := true
            }
        } else if (hoverTabs[A_Index]) {
            if (CurrentTab != "Tab" A_Index) {
                HoverTab[A_Index].Visible := false
                TabCtrl[A_Index].SetFont("c888888")
            } else {
                HoverTab[A_Index].Visible := false
            }
            hoverTabs[A_Index] := false
        }
    }

    if (IsSet(HoverEffect)) {
        matchedAny := false
        for ctrl in HoverEffect {
            if (!ctrl.Visible)
                continue
            ctrl.GetPos(&cX, &cY, &cW, &cH)
            if (mouseX >= cX && mouseX <= cX + cW && mouseY >= cY && mouseY <= cY + cH) {
                matchedAny := true
                if (activeHoverHwnd != ctrl.Hwnd) {
                    if (activeHoverHwnd != 0) {
                        for oldCtrl in HoverEffect {
                            if (oldCtrl.Hwnd = activeHoverHwnd) {
                                if RegExMatch(oldCtrl.name, "i)title") {
                                    oldCtrl.Opt("BackgroundTrans")
                                    oldCtrl.SetFont("c3A86FF Norm")
                                } else {
                                    oldCtrl.Opt("Background0E0E0F")
                                    oldCtrl.SetFont("cFFFFFF Norm")
                                }
                                oldCtrl.Redraw()
                                break
                            }
                        }
                    }
                    ctrl.Opt("Background222222")
                    ctrl.SetFont("c3A86FF Bold")
                    ctrl.Redraw()
                    activeHoverHwnd := ctrl.Hwnd
                }
                break
            }
        }
        if (!matchedAny && activeHoverHwnd != 0) {
            for ctrl in HoverEffect {
                if (ctrl.Hwnd = activeHoverHwnd) {
                    if RegExMatch(ctrl.name, "i)title") {
                        ctrl.Opt("BackgroundTrans")
                        ctrl.SetFont("c3A86FF Norm")
                    } else {
                        ctrl.Opt("Background0E0E0F")
                        ctrl.SetFont("cFFFFFF Norm")
                    }
                    ctrl.Redraw()
                    break
                }
            }
            activeHoverHwnd := 0
        }
    }
}

HideAllTabContent() {
    global MainGui, SystemHwnds, ChildGui
    try ChildGui.Hide()
    for hwnd, ctrl in MainGui {
        if (SystemHwnds.Has(hwnd))
            continue

        try {
            ctrl.Visible := false
        }
    }
}

ShowTabContent(tab) {
    if (tab = "Tab1") {
        for ctrl in [Tab1_Section1, Tab1_Line1, Tab1_Lbl1, Strategy1Ctrl, Tab1_Btn1, Tab1_Btn2,
                     AutoEquipCtrl, ScrollDownForMapCtrl,
                     ScrollDownAmountCtrl, ScrollDownAmountUpDown, Tab1_Lbl3, TimeScaleModeCtrl,
                     Tab1_ModSection, Tab1_ModLine,
                     ModCb_Gla, ModCb_Hid, ModCb_Exp, ModCb_Lim, ModCb_Com, ModCb_Fly,
                     ModCb_Fog, ModCb_Qua, ModCb_Inf, ModCb_Bro, ModCb_Spe, ModCb_Hea,
                     Tab1_ModActiveLbl, ModifiersTextCtrl, Tab1_ModSaveBtn,
                     Tab1_Start, Tab1_Stop]
            ctrl.Visible := true
        TimeScaleModeCtrl.Text := TimeScaleMode
    } else if (tab = "Tab2") {
        for ctrl in DiscordWebhookTab
            ctrl.Visible := true
        tab4_Title.Text := "Discord Webhook"
    } else if (tab = "Tab3") {
        for ctrl in [Tab5_Section1, Tab5_Line1, Tab5_Lbl1, ChainKeyCtrl,
                     Tab5_Lbl2, BeatKeyCtrl, Tab5_Lbl3, CaravanKeyCtrl,
                     Tab5_Lbl44, RaiseDeadKeyCtrl, Tab5_Lbl55, Tab5_Lbl56, HologramKeyCtrl, RepoKeyCtrl,
                     Tab5_Lbl99, Tab5_LblUPG, Tab5_LblUPGBTM, CancelPlacementKeyCtrl, UpgradeTowerGCtrl, UpgradeTowerGBCtrl, Tab1_Lbl4, UpgradeDelayCtrl, Tab5_LblScrollDelay, ScrollDelayCtrl,
                     Tab5_Section2, Tab5_Line2, Tab5_Help6,
                     UseRestartBtnCtrl, Tab5_Help4, UsePlayAgainBtnCtrl, Tab5_Help5,
                     CheckTheMapCtrl, UseNumbersForHotbarCtrl, UseUpgradeHCtrl, Tab5_Help7, Tab5_Help11, Tab5_Help12,
                     CollectPlaytimeRewardsCtrl,
                     Tab5_Line4, Tab5_Lbl4, VipLinkCtrl, UseVipServerCtrl, AlwaysOnTopCtrl,
                     MouseSpeedLbl, MouseSpeedTxt, MouseSpeedUpDown,
                     MouseDelayLbl, MouseDelayTxt, MouseDelayUpDown, KeyDelayLbl, KeyDelayTxt, KeyDelayUpDown]
            ctrl.Visible := true

        ChainKeyCtrl.Value := ChainKey
        BeatKeyCtrl.Value := BeatKey
        CaravanKeyCtrl.Value := CaravanKey
        RaiseDeadKeyCtrl.Value := RaiseDeadKey     
        HologramKeyCtrl.Value := HologramKey
        RepoKeyCtrl.Value := RepoKey       
        CancelPlacementKeyCtrl.Value := CancelPlacementKey
        
        MouseSpeedUpDown.Value := DefaultMouseSpeed
        MouseSpeedTxt.Value := DefaultMouseSpeed
        MouseDelayUpDown.Value := MouseDelay
        MouseDelayTxt.Value := MouseDelay
        KeyDelayUpDown.Value := KeyDelay
        KeyDelayTxt.Value := KeyDelay
        UpgradeDelayCtrl.Value := UpgradeDelay
        ScrollDelayCtrl.Value := ScrollDelay

    } else if (tab = "Tab4") {
        for ctrl in [Tools_Section, Tools_Section_Line, Auto_Spin, Auto_Consum]
            ctrl.Visible := true
    } else if (tab = "Tab5") {
        for ctrl in TutorialTab
            ctrl.Visible := true
        Divider.Visible := true
        version_text.Visible := true
    } else if (tab = "Tab6") {
        for ctrl in [Change_Title, Change_Line, Change_BtnUp, Change_BtnDn, Divider, version_text]
            ctrl.Visible := true
        try {
            ChildGui.Show("x30 y120 w612 h172 NA")
            UpdateChangelogLayout()
            ChildGui.Redraw()
        }
    }
}


OpenDisplaySettings(*) {
    try Run("ms-settings:display")
}
OpenLanguageSettings(*) {
    try Run("ms-settings:regionlanguage")
}

MoveWindow(ctrl, *) {
    PostMessage(0xA1, 2, , , MainGui)
}
MinimizeWindow(ctrl, *) {
    MainGui.Minimize()
}
CloseWindow(ctrl, *) {
    ; Finish the current button event before releasing its painted controls.
    SetTimer(HideToResidentTray, -20)
}

InstallResidentTrayMenu() {
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Open Ultimate Macro", ShowResidentMacro)
    A_TrayMenu.Add()
    A_TrayMenu.Add("Exit Ultimate Macro", ExitResidentMacro)
    A_TrayMenu.Default := "Open Ultimate Macro"
    A_TrayMenu.ClickCount := 2
}

HideToResidentTray() {
    SetTimer(Hoverwatchdog, 0)
    MainGui.Hide()
    MW.Hide()
}

ShowResidentMacro(*) {
    SetTimer(HideToResidentTray, 0)
    MainGui.Hide()
    if !IsObject(MW.gui)
        MW.Open()
    else
        MW.gui.Show()
    SetTimer(Hoverwatchdog, 10)
}

ExitResidentMacro(*) {
    global RunningStrategy
    if Recording
        StopRecord(0)
    DashboardRemote.CancelCooldown(false)
    ; ExitApp uses reason "Exit", not "Close". Clear the legacy autorun state
    ; explicitly so an intentional tray exit cannot restart a run next launch.
    HandleExit("Close", 0)
    if RunningStrategy
        DashboardActivity.RunStopped()
    RunningStrategy := false
    ExitApp()
}
DiscordLink(ctrl, *) {
    Run("https://discord.gg/DQnc2JDJtr")
}
githubLink(ctrl, *) {
    Run("https://github.com/DarksenDev/tds-macro")
}
YouTubeLink(ctrl, *) {
    Run("https://www.youtube.com/@darksenn")
}

EnableAutoEquip(*) {
    global MainGui, SettingsFile, AutoEquip
    
    v := MainGui.Submit(false)
    AutoEquip := v.AutoEquip
    IniWrite(AutoEquip, SettingsFile, "Options", "AutoEquip")
}

EnableScrollDownForMap(*) {
    global MainGui, SettingsFile, ScrollDownForMap
    
    v := MainGui.Submit(false)
    ScrollDownForMap := v.ScrollDownForMap
    IniWrite(ScrollDownForMap, SettingsFile, "Options", "ScrollDownForMap")
}

OnScrollDownAmountChange(*) {
    global ScrollDownAmountCtrl, ScrollDownAmount, SettingsFile
    raw := Trim(ScrollDownAmountCtrl.Text)
    if (raw == "")
        return
    val := Integer(raw)
    if (val > 20) {
        val := 20
        ScrollDownAmountCtrl.Text := "20"
    } else if (val < 5) {
        val := 5
        ScrollDownAmountCtrl.Text := "5"
    }
    ScrollDownAmount := val
    IniWrite(val, SettingsFile, "Options", "ScrollDownAmount")
}

SelectStrat1(ctrl, *) {
    global Strategy1Path
    defaultDir := DirExist(A_ScriptDir "\Strategies") ? A_ScriptDir "\Strategies" : A_ScriptDir
    targDir := defaultDir
    if (Strategy1Ctrl.Value) {
        SplitPath(Strategy1Ctrl.Value, , &parentDir) 
        targDir := parentDir
    }
    f := FileSelect("3", targDir, "Select strategy file 1", "Strategy (*.strat)")
    if (f != "") {
        Strategy1Ctrl.Value := f
        Strategy1Path := f
        IniWrite(f, SettingsFile, "Options", "Strategy1")
        LoadStrategyFile(f)
    }
}
ClearStrat1(ctrl, *) {
    global Strategy1Path
    Strategy1Ctrl.Value := ""
    Strategy1Path := ""
    IniWrite(" ", SettingsFile, "Options", "Strategy1")
    try UpdateModifierUI("")
}
SaveStrat1(ctrl, *) {
    global Strategy1Path, Strategy1Ctrl
    Strategy1Path := Strategy1Ctrl.Text
    IniWrite(Strategy1Ctrl.Text, SettingsFile, "Options", "Strategy1")
    if (Strategy1Path != "" && FileExist(Strategy1Path)) {
        try LoadStrategyFile(Strategy1Path)
    }
}


StartStrategy(*) {
    remoteStart := DashboardRemote.remoteStartPrompt
    DashboardRemote.remoteStartPrompt := false
    if (RunningStrategy or Recording) {
        return
    }
    g_IsFirstLaunch := Integer(IniRead(StateFile, "State", "IsFirstLaunch", 1))

    global RunningStrategy, gamemap, difficulty, requiredTowers, modifiers
    global autoChain, autoCaravan, autoDropTheBeat, AutoSkip, AbilitySpam, MoveEnabled, MoveDirection, MoveDuration
    global AutorunStartTime

    if !IsSet(MainGui) or !MainGui
        return

    v := MainGui.Submit(false)
    IniWrite(v.Strategy1, SettingsFile, "Options", "Strategy1")

    stratFile := Trim(v.Strategy1)
    if (stratFile == "" || !FileExist(stratFile)) {
        ModernMsgBox("Warning", "No valid strategy file selected!", "OK", "WARNING")
        return
    }

    if (g_IsFirstLaunch = 1) {
        IniWrite(0, StateFile, "State", "IsFirstLaunch")
        MsgBox("Since you are starting the macro for the first time... Read this so your macro can work properly:`n`n1. Go to the TDS Settings and ENABLE 'Prefer Vertical Upgrades`n2. Go to the TDS Settings and set UI Scale to 'LARGE'`n3. Set your Roblox Camera Mode to Classic`n4. If your Roblox graphics are automatic, set them to manual.`n5. Turn off camera shake in TDS.`n6. Disable Dialog in TDS`n7. Enable UI Navigation toggle in the Roblox settings.`n8. Enable 'Show Tower Options' in TDS.`n9. Make sure you have 60 fps in Roblox settings.`n`nRecommended screen resolution for this macro is 1920x1080 (Resolutions bigger than 1080p may not work. You can use 1366x768 & 1280x720 though, they work pretty well). The scale must be 100%.`nThis macro requires a good CPU. You can use it though if your device is bad, enable potato mode and make the delays bigger.`nPlease, join my Discord server to get help and check the FAQ.","READ THIS!!", 0x1030)
    }

    IniDelete(StateFile, "State", "Coins")
    IniDelete(StateFile, "State", "Gems")
    IniDelete(StateFile, "State", "EXP")
    IniDelete(StateFile, "State", "TotalTriumphs")
    IniDelete(StateFile, "State", "TotalLosses")
    IniDelete(StateFile, "State", "TotalTimeSeconds")
    IniDelete(StateFile, "State", "Timescale")
    IniDelete(StateFile, "State", "StartTime")
    IniDelete(StateFile, "State", "TimeWhenStartedPlaying")
    IniDelete(StateFile, "State", "Equipped")

    AutorunStartTime := 0
    SaveModifiersToStrategyFile(modifiers)
    LoadStrategyFile(stratFile)

    if (requiredTowers != "" && !AutoEquip)
        MsgBox(requiredTowers, "Required Towers", remoteStart ? "0x1040 T3" : "0x1040 T60")

    IniWrite(1, StateFile, "State", "Running")
    IniWrite(stratFile, StateFile, "State", "Strategy")
    if (gamemap != "")
        IniWrite(gamemap, StateFile, "State", "Map")

    MainGui.Hide()
    SetTimer(Hoverwatchdog, 0)
    MW.Hide()
    RunningStrategy := true

    time := FormatTime(, "HH:mm:ss")
    SplitPath(stratFile, &fileName)
    startInfo := "[" time "] Started strategy: " fileName "`n"
    startInfo .= "Map = " gamemap "`nMode = " difficulty "`nTimescale = " TimeScaleMode "`nRequired Towers: " requiredTowers
    if (modifiers != "")
        startInfo .= "`nModifiers: " modifiers
    SendToWebhookInstant(startInfo,, flush := false)

    CheckOcrLanguage()

    MultiInstanceTools := "RobloxAccountManager.exe,Roblox Account Manager.exe,RAM.exe,RobloxMulti.exe,MultiRoblox.exe,MultipleRoblox.exe,Multiple Roblox.exe"
    Loop Parse, MultiInstanceTools, "," {
        if ProcessExist(A_LoopField) {
            MsgBox("Conflicting program detected:`n" A_LoopField "`n`nFor this script to work properly, please close all Roblox multi-client utilities.`nPlease close them and try again.", "Error", 0x1030)
            ExitApp()
        }
    }

    DashboardActivity.RunStarted()
    RunStrategy("", true)
}

StopStrategy(*) {
    global RunningStrategy, AutorunStartTime, Recording, MacroRecording, InputHookObj

    KillSubmacros()
    DashboardRemote.CancelCooldown(false)

    if Recording {
        StopRecord(0)
        return
    }

    if (RunningStrategy) {
        if (AutorunStartTime > 0) {
            runtime := FormatRuntime(AutorunStartTime)
            Coins := IniRead(StateFile, "State", "Coins", "0")
            Gems  := IniRead(StateFile, "State", "Gems",  "0")
            Timescales  := IniRead(StateFile, "State", "Timescale",  "0")
            LogToConsole("Strategy stopped. Runtime: " runtime)
            time := FormatTime(, "HH:mm:ss")
            SendToWebhookInstant("[" time "] Strategy stopped. Runtime: " runtime)
            IniDelete(StateFile, "State", "StartTime")
            AutorunStartTime := 0
        }
        DeleteAllIndicators()
        IniWrite(0, StateFile, "State", "Running")
        IniWrite(0, StateFile, "State", "Strategy")
        IniDelete(StateFile, "State", "Coins")
        IniDelete(StateFile, "State", "Gems")
        IniDelete(StateFile, "State", "EXP")
        IniDelete(StateFile, "State", "TotalTriumphs")
        IniDelete(StateFile, "State", "TotalLosses")
        IniDelete(StateFile, "State", "TotalTimeSeconds")
        IniDelete(StateFile, "State", "Timescale")
        IniDelete(StateFile, "State", "TimeWhenStartedPlaying")
        IniDelete(StateFile, "State", "Equipped")
        DashboardActivity.RunStopped()
        RunningStrategy := false
        SafeReload()
    }
}



;PATHS =======================================

CataclysmPath() {
    AlignCamera(true, false)

    SendEvent("{WheelUp}")
}

SimplicityPath() {
    global LegacyMode
    attempts := 0
    Loop {
        AlignCamera(false, false)
        SendEvent("{sc01f Down}") 
        HyperSleep(2500)
        SendEvent("{sc01f Up}")
        HyperSleep(300)
        SendEvent("{sc01f Down}")
        SendEvent("{sc020 Down}")
        HyperSleep(2000)
        SendEvent("{sc01f Up}")
        SendEvent("{sc020 Up}")
        HyperSleep(300)
        SendEvent("{sc01e Down}")
        HyperSleep(125)
        SendEvent("{sc01e Up}")
        HyperSleep(300)
        SendEvent("{sc01f Down}")
        SendEvent("{sc020 Down}")
        HyperSleep(2000)
        SendEvent("{sc01f Up}")
        SendEvent("{sc020 Up}")
        HyperSleep(300)
        Send("{sc011 Down}")
        HyperSleep(1300)
        Send("{sc011 Up}")

        modifiers_str := (modifiers is Array) ? Join(modifiers) : String(modifiers)

        if (FileExist("Resources\Maps\Simplicity.png") && CheckTheMap = 1 && !RegExMatch(modifiers_str, "i)fog") && !LegacyMode)
        {
            getRobloxPos(,,&w,&h)
            FoundMap := false
            Loop 5 {
                res := AdvancedImageSearch("Resources\Maps\Simplicity.png", 0, 0, w, h, 0.5, 2)
                
                if (res.score > 0.65) {
                    FoundMap := true
                    LogToConsole("break " res.score )
                    break
                }
                
                Sleep(300)
            }

            if (!FoundMap) {
                if (attempts > 3)
                    SafeReload()
                LogToConsole("Can't detect the correct position! Resetting..", true)
                resetCharacter()
                Sleep(7500)
                attempts++
                continue
            }
        }
        break
    }
}



;=====

ToggleAutoskip() {
    global AutoSkip
    if AutoSkip = "ON" {
        AutoSkip := "OFF"
        LogToConsole("Toggled auto-skip: OFF")
    } else {
        AutoSkip := "ON"
        LogToConsole("Toggled auto-skip: ON")
    }
}


ChangeTargets(towerID, target) {
    global LastOpenedTowerID, needtocheckTowerUI, Towers, PotatoMode, ResV2, ResV1, canBeUpgraded, unfocusX, unfocusY
    canUseAbility := false
    
    if (LastOpenedTowerID != towerID) {
        Click(Towers[towerID].x, Towers[towerID].y)
        Sleep 250
    } else {
        MouseMove(0, ScaleY(50),, "R")
    }

    LastOpenedTowerID := towerID
    needtocheckTowerUI := true
    attempts := 0
    targets := ["First Enemy", "Last Enemy", "Strongest", "Weakest", "Closest", "Farthest", "Random"]

    LogToConsole("Changing " towerID " targets to " target "...")

    upgTime := A_TickCount
    Loop {
        openedSuccessfully := false
        StartTime := A_TickCount

        if (PotatoMode) {
            if (A_TickCount - upgTime > 600) {
                needtocheckTowerUI := true
                upgTime := A_TickCount
            }
        } else {
            needtocheckTowerUI := true
        }

        if (needtocheckTowerUI || (!IsObject(ResV2) && !IsObject(ResV1))) {
            openedSuccessfully := waitForTowerUI(&ResV2, &ResV1)

            if (!openedSuccessfully && canBeUpgraded) {
                attempts++
                if (attempts > 30) {
                    LogToConsole("Tower " towerID " menu not found after 30 attempts, reloading...", true)
                    SafeReload()
                }
                variation := Random(-4, 4)
                Click(Towers[towerID].x, Towers[towerID].y + ScaleY(variation))
                Sleep(100)
                continue
            } else {
                attempts := 0
                needtocheckTowerUI := false
            }
        }

        startedSearching := A_TickCount
        loop {
            if (A_TickCount - startedSearching > 5000)
            {
                LogToConsole("Failed to change tower targets...", true)
                return false
            }

            getRobloxPos(,,&w,&h)
            left := AdvancedImageSearch("Resources/TowerUI/left.png", 0,0,w/2,h/1.3)

            if left.score > 0.66 {
                right := AdvancedImageSearch("Resources/TowerUI/right.png", left.x+20,0,w/2,h/1.3)
                if right.score > 0.66 {
                    break
                } 
            }
            Sleep 150
        }

        currentTarget := Towers[towerID].target
        currentIndex := 0
        targetIndex := 0

        for index, name in targets {
            if (name == currentTarget)
                currentIndex := index
            if (name == target)
                targetIndex := index
        }

        if (currentIndex == 0)
            currentIndex := 1

        if (currentIndex == targetIndex) {
            Towers[towerID].target := target
        } else {
            diffRight := targetIndex - currentIndex
            if (diffRight < 0)
                diffRight += 7

            diffLeft := currentIndex - targetIndex
            if (diffLeft < 0)
                diffLeft += 7

            if (diffRight <= diffLeft) {
                clickCount := diffRight
                buttonToClick := right
            } else {
                clickCount := diffLeft
                buttonToClick := left
            }

            Loop clickCount {
                Click(buttonToClick.x, buttonToClick.y)
                Sleep 500
            }
            Towers[towerID].target := target
        }

        Click(ScaleX(unfocusX), ScaleY(unfocusY))
        Sleep 250

        LastOpenedTowerID := ""
        Click(Towers[towerID].x, Towers[towerID].y)
        Sleep 250
        LastOpenedTowerID := towerID
        needtocheckTowerUI := true

        Loop {
            openedSuccessfully := false
            if (needtocheckTowerUI || (!IsObject(ResV2) && !IsObject(ResV1))) {
                openedSuccessfully := waitForTowerUI(&ResV2, &ResV1)
                if (!openedSuccessfully && canBeUpgraded) {
                    variation := Random(-4, 4)
                    Click(Towers[towerID].x, Towers[towerID].y + ScaleY(variation))
                    Sleep(100)
                    continue
                } else {
                    needtocheckTowerUI := false
                    break
                }
            }
            break
        }

        getRobloxPos(,,&w,&h)
        checkTargetImg := AdvancedImageSearch("Resources/TowerUI/" target ".png", 0,0,w/2,h/1.3)
        
        if (checkTargetImg.score > 0.66) {
            LogToConsole("Successfully changed tower's target to " target)
            break
        }

        bestScore := 0
        detectedTarget := "First Enemy"
        
        for index, name in targets {
            imgScan := AdvancedImageSearch("Resources/TowerUI/" name ".png", 0,0,w/2,h/1.3)
            if (imgScan.score > bestScore) {
                bestScore := imgScan.score
                detectedTarget := name
            }
        }

        Towers[towerID].target := detectedTarget
        
        if (detectedTarget == target) {
            LogToConsole("Successfully changed tower's target to " target)
            break
        }
    }

    canUseAbility := true
}

CloneTower(towerId, x, y, wait := 0) {
    global Towers, unfocusX, unfocusY, LastOpenedTowerID, CancelPlacementKey, HologramKey, Recording,canUseAbility

    if (!Towers.Has(towerID)) {
        LogToConsole("Tower " towerID " not found!")
        return false
    }

    if (wait > 0 && !Recording) {
        Sleep(wait)
    }

    canUseAbility := false

    SendEvent("{" CancelPlacementKey "}")
    Sleep 50

    loop {
        SendEvent("{" CancelPlacementKey "}")
        Click(ScaleX(unfocusX), ScaleY(unfocusY))
        Sleep(120)

        SendEvent("{" HologramKey "}")
        Sleep 300

        getRobloxPos(,,&w,&h)
        x1 := Round(w * 0.2)
        y1 := Round(h * 0.18)
        x2 := Round(w * 0.7)
        y2 := Round(h * 0.3)

        if (ImageSearch(&fx,&fy,x1,y1,x2,y2, "*Trans000000 *50 " A_WorkingDir "/Resources/hologram_tower_cooldown.png") || ReadMessage(["hologram", "ability", "is on", "cooldown", "hol%ram%", "ility"])) {
            LogToConsole("Failed to clone " towerId "! (hologram cooldown) Retrying again in 5 seconds...")
            canUseAbility := true
            Sleep 4650
            canUseAbility := false
            continue
        }

        baseX := Towers[towerId].x
        baseY := Towers[towerId].y

        baseX := Towers[towerId].x
        baseY := Towers[towerId].y

        found := false
        startTime := A_TickCount

        while (!found && (A_TickCount - startTime < 6000)) {
            loop 15 {
                variationY := A_Index - 8 

                MouseMove(baseX, baseY + variationY)
                Sleep 270 

                MouseGetPos(&mx, &my)
                
                cashX := mx + 69 
                cashY := my - 59
                
                x1 := cashX - 20
                y1 := cashY - 5
                x2 := cashX + 10
                y2 := cashY + 5

                if PixelSearch(&Fx, &Fy, x1, y1, x2, y2, 0x99BFD4, 6) {
                    found := true
                    MouseClick
                    break 2
                }
            }
            
            if (!found) {
                Sleep 100
            }
        }

        if !found {
            MouseClick(, baseX, baseY)
        }

        Sleep 350

        if (ImageSearch(&fx,&fy,x1,y1,x2,y2, "*Trans000000 *50 " A_WorkingDir "/Resources/no_cash_cloning.png") || ReadMessage(["don't", "have", "enough", "cash", "clone", "this"])) {
            LogToConsole("Failed to clone " towerId "! (no cash) Retrying again in 5 seconds...")
            canUseAbility := true
            Sleep 4650
            canUseAbility := false
            continue
        }
        
        openedUI := waitForTowerUI(,,500)
        if (openedUI) {
            LogToConsole("Failed to clone tower: accidentally opened upgrade ui! Retrying again..")
            Click(ScaleX(unfocusX), ScaleY(unfocusY))
            Sleep(500)
            continue
        }

        MouseMove(x,y)
        Sleep 100
        MouseClick()

        Sleep 50
        SendEvent("{" CancelPlacementKey "}")

        Sleep 350

        MouseMove(ScaleX(unfocusX), ScaleY(unfocusY))

        Sleep 100

        if (ImageSearch(&fx,&fy,x1,y1,x2,y2, "*Trans000000 *50 " A_WorkingDir "/Resources/stunned.png") || ReadMessage(["error", "that", "cannot", "cann", "activated", "while", "stunned"],,["need", "more", "to"],"\$|\d")) {
            LogToConsole("Failed to clone " towerId "! (hacker is stunned) Retrying again in 5 seconds...")
            canUseAbility := true
            Sleep 4650
            canUseAbility := false
            continue
        }

        if (ImageSearch(&fx,&fy,x1,y1,x2,y2, "*Trans000000 *50 " A_WorkingDir "/Resources/cannot_place_here.png") || ReadMessage(["cannot", "here", "hereg", "herd", "her", "here!", "cann", "cannd", "he", "h", "hed"],,["need", "more", "to"],"\$|\d")) {
            LogToConsole("Failed to clone " towerId "! (cannot place here!) Retrying again in 5 seconds...")
            canUseAbility := true
            Sleep 4650
            canUseAbility := false
            continue
        } else {
            LogToConsole("Successfully cloned tower " towerId ".")
            break
        }
    }

    canUseAbility := true
}

BrawlerReposition(towerId, x, y) {
    global Towers, unfocusX, unfocusY, LastOpenedTowerID, CancelPlacementKey, RepoKey, Recording

    canUseAbility := false

    loop {

        if (!Towers.Has(towerID)) {
            LogToConsole("Tower " towerID " not found!")
            return false
        }

        SendEvent("{" CancelPlacementKey "}")
        Sleep 20

        if (LastOpenedTowerID != towerId && LastOpenedTowerID != "") {
            click(ScaleX(unfocusX), ScaleY(unfocusY))
        }

        Sleep 50

        if (LastOpenedTowerID != towerId) {
            click(Towers[towerId].x, Towers[towerId].y)
        }

        attempts := 0
        
        Loop {
            opened := waitForTowerUI()
            if opened {
                attempts := 0
                break
            } else {
                attempts++
                if (attempts > 30) {
                    LogToConsole("Tower " towerID " menu not found after 30 attempts, reloading...", true)
                    SafeReload()
                }
                variation := Random(-4, 4)
                Click(Towers[towerId].x, Towers[towerId].y + ScaleY(variation))
                Sleep(100)
                continue
            }

        }

        getRobloxPos(,,&w,&h)
        send "{" RepoKey "}"

        x1 := Round(w * 0.2)
        y1 := Round(h * 0.18)
        x2 := Round(w * 0.7)
        y2 := Round(h * 0.3)

        Sleep 300

        if (ImageSearch(&fx,&fy,x1,y1,x2,y2, "*Trans000000 *50 " A_WorkingDir "/Resources/reposition_cooldown.png") || ReadMessage(["reposition", "ability", "is on", "cooldown", "ility"])) {
            LogToConsole("Failed to reposition brawler! Retrying again in 4.5 seconds...")
            Sleep 4500
            continue
        }

        placeattempts := 0
        px := x, py := y
        Loop {
            placeattempts++

            if (placeattempts > 5) {
                Send("{" CancelPlacementKey "}")
                LogToConsole("Failed to reposition brawler :( ")
                return false
            }

            MouseMove(px,py)
            Sleep 20
            MouseClick

            sleep 400

            if (ImageSearch(&fx,&fy,x1,y1,x2,y2, "*Trans000000 *50 " A_WorkingDir "/Resources/cannot_place_here.png") || ReadMessage(["cannot", "here", "hereg", "herd", "her", "here!", "cann", "cannd", "he", "h", "hed"],,["need", "more", "to"],"\$|\d")) {
                LogToConsole("Failed to reposition brawler: cannot place here! Retrying..")
                Sleep 4400
                variation := Random(-3, 3)
                py := y + variation
                continue
            } else {
                break
            }
        }

        if (ImageSearch(&fx,&fy,x1,y1,x2,y2, "*Trans000000 *50 " A_WorkingDir "/Resources/stunned.png") || ReadMessage(["error", "that", "cannot", "cann", "activated", "while", "tower", "tmeer", "stunned"],,["need", "more", "to"],"\$|\d")) {
            LogToConsole("Failed to reposition brawler! Retrying again in 4.5 seconds...")
            Sleep 4400
            continue
        }

        Towers[towerId].x := x
        Towers[towerId].y := y
        UpdateTowerIndicator(towerId)
        LogToConsole("Successfully reposited " towerId " to " x ", " y ".")
        break
    }

    canUseAbility := true
}

ActivateRaiseTheDead(wait := 0) {
    global CancelPlacementKey, LastOpenedTowerID, unfocusX, unfocusY, RaiseDeadKey, Recording

    if (wait > 0 && !Recording) {
        Sleep(wait)
    }

    SendEvent("{" CancelPlacementKey "}")
    if (LastOpenedTowerID != "") {
        Click(ScaleX(unfocusX), ScaleY(unfocusY))
        Sleep(450)
    }

    SendEvent("{" RaiseDeadKey "}")
    LogToConsole("Successfully activated 'Raise the Dead'")
}


OnKeyDown(ih, vk, sc) {
    global MacroSteps, MacroStartTime, MacroRecording, KeyDownTimes
    if (!MacroRecording)
        return
    if !RecorderGameFocused() {
        KeyDownTimes.Clear()
        MacroStartTime := A_TickCount
        return
    }
        
    if (vk = 0xA0 || vk = 0xA1 || vk = 0xA2 || vk = 0xA3
        || vk = 0xA4 || vk = 0xA5 || vk = 0x5B || vk = 0x5C
        || vk = 0x11 || vk = 0x12 || vk = 0x41)
        return
        
    keyId := vk "-" sc
    
    if (KeyDownTimes.Has(keyId))
        return
        
    currentTime := A_TickCount
    elapsed := currentTime - MacroStartTime
    MacroStartTime := currentTime
    
    KeyDownTimes[keyId] := currentTime
    MacroSteps.Push("Sleep(" elapsed ")")
}

OnKeyUp(ih, vk, sc) {
    global MacroSteps, MacroStartTime, MacroRecording, KeyDownTimes
    if (!MacroRecording)
        return
    if !RecorderGameFocused() {
        KeyDownTimes.Clear()
        MacroStartTime := A_TickCount
        return
    }
        
    if (vk = 0xA0 || vk = 0xA1 || vk = 0xA2 || vk = 0xA3
        || vk = 0xA4 || vk = 0xA5 || vk = 0x5B || vk = 0x5C
        || vk = 0x11 || vk = 0x12 || vk = 0x41)
        return
        
    currentTime := A_TickCount
    keyId := vk "-" sc
    
    holdDuration := 50
    if (KeyDownTimes.Has(keyId)) {
        holdDuration := currentTime - KeyDownTimes[keyId]
        KeyDownTimes.Delete(keyId) 
    }

    elapsed := currentTime - MacroStartTime
    MacroStartTime := currentTime
    
    keyName := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
    if (keyName = "")
        keyName := "VK" Format("{:02X}", vk)
        
    MacroSteps.Push('Send("' keyName '", hold:=' holdDuration ')')
    
    if (elapsed > 0) {
        MacroSteps.Push("Sleep(" elapsed ")")
    }
}

^SC02C:: {
    global RecordedSteps, Towers, Recording, Commander
    
    if (!IsRecordingActive()) {
        Send("^{SC02C}")
        return
    }
    if (RecordedSteps.Length == 0) {
        return
    }

    lastStep := RecordedSteps.Pop()
    LogToConsole("Undo: Reverting step -> " lastStep)

    if RegExMatch(lastStep, "i)UpgradeTower\s*\(\s*([^\n,\)]+)", &matchUpgrade) {
        towerID := Trim(matchUpgrade[1]) 
        
        if (Towers.Has(towerID)) {
            Towers[towerID].level := Max(0, Towers[towerID].level - 1)
            UpdateTowerIndicator(towerID)
        }
        return
    }

    if RegExMatch(lastStep, "i)SpawnTower\s*\(\s*[^,]+\s*,\s*[^,]+\s*,\s*[^,]+\s*,\s*(.*?)\s*\)", &matchPlace)
    {
        towerID := matchPlace[1] 
        
        if (Towers.Has(towerID)) {
            if (Towers[towerID].HasProp("hwnd") && Towers[towerID].hwnd && WinExist("ahk_id " Towers[towerID].hwnd)) {
                WinClose("ahk_id " Towers[towerID].hwnd)
            }
            Towers.Delete(towerID)

        }
        return
    }

    if (lastStep = "Commander := true") {
        Commander := false
        return
    }
}

~RButton:: {
    global MacroRecording, MacroSteps, MacroStartTime, Towers
    if (!IsRecordingActive()) {
        return
    }

    if (MacroRecording) {
        MouseGetPos(&mx, &my)
        elapsed := A_TickCount - MacroStartTime
        MacroStartTime := A_TickCount
        MacroSteps.Push("Sleep(" elapsed ")")
        MacroSteps.Push("Click(" mx ", " my ", Right)")
        return
    }

    MouseGetPos(&mx, &my)

    towerID := ""

    for id, t in Towers {
        ix1 := t.x - 16
        iy1 := t.y - 16
        ix2 := ix1 + 32
        iy2 := iy1 + 32
        
        if (mx >= ix1 && mx <= ix2 && my >= iy1 && my <= iy2) {
            towerID := id
            break
        }
    }

    if (towerID != "")
        ShowTowerPathDialog(towerID)
}

global ActivePathSelectTowerID := ""

ShowTowerPathDialog(towerID) {
    global Towers, ActivePathSelectTowerID
    if (!Towers.Has(towerID) || Towers[towerID].path = 0 || Towers[towerID].path = "") {
        ActivePathSelectTowerID := towerID
        PathGui := Gui("+AlwaysOnTop +Border", "Path Selection")
        PathGui.SetFont("s12 Bold c000000", "Segoe UI")
        PathGui.Add("Text", "x25 y20 w350", "Tower " towerID)
        PathGui.SetFont("s11 w400 c000000", "Segoe UI")
        PathGui.Add("Text", "x25 y+10 w350", "Choose an upgrade path")
        PathGui.Add("Text", "x25 y+10 w350", "Rigth click on the tower indicator to make this appear.`nNote: enter 3 for Pursuit, Juggernaut, and Kingpin, 4 for Hacker")
        PathGui.SetFont("s10 w600 c000000")
        b1 := PathGui.Add("Button", "x25 y+25 w165 h40", "Path 1 (Top)")
        b1.OnEvent("Click", (*) => SelectPath(PathGui, 1))
        b2 := PathGui.Add("Button", "x+10 w165 h40", "Path 2 (Bottom)")
        b2.OnEvent("Click", (*) => SelectPath(PathGui, 2))
        bc := PathGui.Add("Button", "x25 y+10 w340 h35", "Cancel")
        bc.OnEvent("Click", (*) => PathGui.Destroy())
        PathGui.Show("w390 h280")
        WinWaitClose("ahk_id " PathGui.Hwnd)
    }
}

SelectPath(pathGui, pathNum) {
    global Towers, ActivePathSelectTowerID
    pathGui.Destroy()
    towerID := ActivePathSelectTowerID
    if (towerID = "")
        return
    box := InputBox("Enter the level where the paths appear:", "Level", "w300 h130", "")
    if (box.Result = "Cancel" || !IsInteger(box.Value))
        return
    Towers[towerID].path      := pathNum
    Towers[towerID].pathLevel := Integer(box.Value)
    UpdateTowerIndicator(towerID)
    LogToConsole("Tower " towerID " set to path " pathNum " from level " box.Value)
}


SaveWebhookSettings(ctrl := 0, *) {
    SaveWebhookSettingsInternal(true)
}

SaveDiscordSettingsQuiet(*) {
    SaveWebhookSettingsInternal(false)
}

SaveWebhookSettingsInternal(showMsg := true) {
    global WebhookLink, WebhookLink2, WebhookSepatateTriumphScreenshots, WebhookEnabled, SendCurrenciesEnabled, WebhookDebugLogs, WebhookScreenshots, WebhookTriumphScreenshots
    global WebhookUserID, PingOnWin, PingOnLoss, PingOnTimescale
    
    if !IsSet(MainGui) or !MainGui
        return
        
    try {
        v := MainGui.Submit(0)
        WebhookLink := v.WebhookLink
        WebhookLink2 := v.WebhookLink2
        WebhookSepatateTriumphScreenshots := v.WebhookSepatateTriumphScreenshots
        WebhookEnabled := v.WebhookEnabled
        SendCurrenciesEnabled := v.SendCurrenciesEnabled
        WebhookDebugLogs := v.WebhookDebugLogs
        WebhookScreenshots := v.WebhookScreenshots
        WebhookTriumphScreenshots := v.WebhookTriumphScreenshots
        WebhookUserID := v.WebhookUserID
        PingOnWin := v.PingOnWin
        PingOnLoss := v.PingOnLoss
        PingOnTimescale := v.PingOnTimescale
        IniWrite(WebhookLink, SettingsFile, "Webhook", "Link")
        IniWrite(WebhookLink2, SettingsFile, "Webhook", "Link2")
        IniWrite(WebhookUserID, SettingsFile, "Webhook", "WebhookUserID")
        IniWrite(PingOnWin, SettingsFile, "Webhook", "PingOnWin")
        IniWrite(PingOnLoss, SettingsFile, "Webhook", "PingOnLoss")
        IniWrite(PingOnTimescale, SettingsFile, "Webhook", "PingOnTimescale")
        IniWrite(WebhookEnabled, SettingsFile, "Webhook", "Enabled")
        IniWrite(SendCurrenciesEnabled, SettingsFile, "Webhook", "SendCurrencies")
        IniWrite(WebhookDebugLogs, SettingsFile, "Webhook", "WebhookDebugLogs")
        IniWrite(WebhookScreenshots, SettingsFile, "Webhook", "WebhookScreenshots")
        IniWrite(WebhookTriumphScreenshots, SettingsFile, "Webhook", "WebhookTriumphScreenshots")
        IniWrite(WebhookSepatateTriumphScreenshots, SettingsFile, "Webhook", "WebhookSepatateTriumphScreenshots")

        if (showMsg) {
            MsgBox("All discord settings have been successfully saved!", "Ultimate Macro", 0x1040)
        }
    }
}


NormalizeKey(keyName) {
    if (keyName = "")
        return ""

    if !RegExMatch(keyName, "^([~!#^+<>*]*)(.*)$", &Match)
        return keyName
        
    modifiers := Match[1]
    pureKey   := Match[2]

    if (StrLen(pureKey) > 1)
        return keyName
    
    res := DllCall("User32.dll\VkKeyScanW", "UShort", Ord(pureKey), "Short")
    vk := res & 0xFF
    
    if (vk = 0xFF || vk = 0)
        return keyName
    
    sc := DllCall("User32.dll\MapVirtualKeyW", "UInt", vk, "UInt", 0, "UInt")
    
    if (!sc)
        return keyName
    
    return modifiers . Format("sc{:03X}", sc)
}


SaveAllSettings(ctrl := 0, *) {
    SaveAllSettingsInternal(true)
}

SaveAllSettingsQuiet(*) {
    SaveAllSettingsInternal(false)
}

SaveAllSettingsInternal(showMsg := true) {
    global ChainKey, BeatKey, CaravanKey, CancelPlacementKey, TimeScaleMode, UseTimeScale
    global TimeScaleMultiplier, VipLink, UseVipServer, AlwaysOnTop, LegacyMode, DebugConsole
    global PotatoMode, UseRestartBtn, UsePlayAgainBtn, CheckTheMap
    global SettingsFile
    global DefaultMouseSpeed, MouseDelay, KeyDelay, UpgradeDelay, ScrollDelay
    global RaiseDeadKey, HologramKey, RepoKey, CollectPlaytimeRewards, UpgradeTowerGKey, UpgradeTowerGBKey, UseHForUpgrade, UseNumbersForHotbar
    global ChainKeyCtrl, BeatKeyCtrl, CaravanKeyCtrl, CancelPlacementKeyCtrl, UpgradeTowerGCtrl, UpgradeTowerGBCtrl
    global RaiseDeadKeyCtrl, HologramKeyCtrl, RepoKeyCtrl, TimeScaleModeCtrl, VipLinkCtrl, UseVipServerCtrl, AlwaysOnTopCtrl
    global UseRestartBtnCtrl, UsePlayAgainBtnCtrl, CheckTheMapCtrl, UseNumbersForHotbarCtrl, CollectPlaytimeRewardsCtrl, UseUpgradeHCtrl
    global MouseSpeedUpDown, MouseDelayUpDown, KeyDelayUpDown, UpgradeDelayCtrl, ScrollDelayCtrl

    if !IsSet(MainGui) or !MainGui
        return

    try {
        tempChainKey := SubStr(RegExReplace(ChainKeyCtrl.Value, "\s", ""), 1, 1)
        tempBeatKey := SubStr(RegExReplace(BeatKeyCtrl.Value, "\s", ""), 1, 1)
        tempCaravanKey := SubStr(RegExReplace(CaravanKeyCtrl.Value, "\s", ""), 1, 1)
        tempCancelPlacementKey := SubStr(RegExReplace(CancelPlacementKeyCtrl.Value, "\s", ""), 1, 1)
        tempUpgradeTowerGKey := SubStr(RegExReplace(UpgradeTowerGCtrl.Value, "\s", ""), 1, 1)
        tempUpgradeTowerGBKey := SubStr(RegExReplace(UpgradeTowerGBCtrl.Value, "\s", ""), 1, 1)
        
        if (tempChainKey = "")           
            tempChainKey := "C"
        if (tempBeatKey = "")            
            tempBeatKey  := "B"
        if (tempCaravanKey = "")         
            tempCaravanKey := "J"
        if (tempCancelPlacementKey = "") 
            tempCancelPlacementKey := "Q"
        if (tempUpgradeTowerGKey = "")
            tempUpgradeTowerGKey := "E"
        if (tempUpgradeTowerGBKey = "")
            tempUpgradeTowerGBKey := "Z"

        UsedKeys := Map()
        
        KeysToCheck := [
            {val: NormalizeKey(tempChainKey), name: "Call of Arms Ability"},
            {val: NormalizeKey(tempBeatKey), name: "Drop the Beat Ability"},
            {val: NormalizeKey(tempCaravanKey), name: "Support Caravan Ability"},
            {val: NormalizeKey(tempCancelPlacementKey), name: "Cancel Placement"},
            {val: NormalizeKey(tempUpgradeTowerGKey), name: "Upgrade Tower (TDS keybind)"},
            {val: NormalizeKey(tempUpgradeTowerGBKey), name: "Upgrade Bottom Path (TDS keybind)"}
        ]

        hasKeyError := false
        for item in KeysToCheck {
            if (item.val = "") {
                hasKeyError := true
                if (showMsg) {
                    MsgBox("Error: Empty hotkey detected!`n`n" 
                    . "The hotkey is assigned to: `"" item.name "`"`n"
                    . "Please change it before saving.", "Empty Hotkey", 0x10)
                }
                break
            }
            if UsedKeys.Has(item.val) {
                hasKeyError := true
                if (showMsg) {
                    MsgBox("Error: Duplicate hotkey detected!`n`n" 
                         . "The hotkey is assigned to: `"" UsedKeys[item.val] "`"`n"
                         . "And also that hotkey is assigned to: `"" item.name "`"`n`n"
                         . "Please change it before saving.", "Duplicate Hotkey", 0x10)
                }
                break
            }
            UsedKeys[item.val] := item.name
        }

        if (!hasKeyError) {
            ChainKey := tempChainKey
            BeatKey := tempBeatKey
            CaravanKey := tempCaravanKey
            CancelPlacementKey := tempCancelPlacementKey
            UpgradeTowerGKey := tempUpgradeTowerGKey
            UpgradeTowerGBKey := tempUpgradeTowerGBKey

            IniWrite(ChainKey, SettingsFile, "Hotkeys", "Chain")
            IniWrite(BeatKey, SettingsFile, "Hotkeys", "Beat")
            IniWrite(CaravanKey, SettingsFile, "Hotkeys", "Caravan")
            IniWrite(CancelPlacementKey, SettingsFile, "Hotkeys", "CancelPlacement")
            IniWrite(UpgradeTowerGKey, SettingsFile, "Hotkeys", "UpgradeTower")
            IniWrite(UpgradeTowerGBKey, SettingsFile, "Hotkeys", "UpgradeBottom")
        }

        RaiseDeadKey := RaiseDeadKeyCtrl.Value
        HologramKey := HologramKeyCtrl.Value
        RepoKey := RepoKeyCtrl.Value

        TimeScaleMode := (TimeScaleModeCtrl.Text = "") ? "OFF" : TimeScaleModeCtrl.Text
        VipLink := VipLinkCtrl.Value
        UseVipServer := UseVipServerCtrl.Value
        AlwaysOnTop := AlwaysOnTopCtrl.Value
        DebugConsole := 0
        PotatoMode := 0
        LegacyMode := 0
        UseRestartBtn := UseRestartBtnCtrl.Value
        UsePlayAgainBtn := UsePlayAgainBtnCtrl.Value
        CheckTheMap := CheckTheMapCtrl.Value
        UseNumbersForHotbar := UseNumbersForHotbarCtrl.Value
        CollectPlaytimeRewards := CollectPlaytimeRewardsCtrl.Value
        UseHForUpgrade := UseUpgradeHCtrl.Value
        
        DefaultMouseSpeed := MouseSpeedUpDown.Value
        MouseDelay := MouseDelayUpDown.Value
        KeyDelay := KeyDelayUpDown.Value
        UpgradeDelay := UpgradeDelayCtrl.Value
        ScrollDelay := ScrollDelayCtrl.Value
        
        IniWrite(RaiseDeadKey, SettingsFile, "Hotkeys", "RaiseTheDead")
        IniWrite(HologramKey, SettingsFile, "Hotkeys", "Hologram")
        IniWrite(RepoKey, SettingsFile, "Hotkeys", "Repo")
        IniWrite(TimeScaleMode, SettingsFile, "Options", "TimeScaleMode")
        IniWrite(VipLink, SettingsFile, "Options", "VipLink")
        IniWrite(UseVipServer, SettingsFile, "Options", "UseVipServer")
        IniWrite(DebugConsole, SettingsFile, "Options", "DebugConsole")
        IniWrite(PotatoMode, SettingsFile, "Options", "PotatoMode")
        IniWrite(AlwaysOnTop, SettingsFile, "Options", "AlwaysOnTop")
        IniWrite(LegacyMode, SettingsFile, "Options", "LegacyMode")
        IniWrite(UseRestartBtn, SettingsFile, "Options", "UseRestartBtn")
        IniWrite(UsePlayAgainBtn, SettingsFile, "Options", "UsePlayAgainBtn")
        IniWrite(CheckTheMap, SettingsFile, "Options", "CheckTheMap")
        IniWrite(UseNumbersForHotbar, SettingsFile, "Options", "UseNumbers")
        IniWrite(CollectPlaytimeRewards, SettingsFile, "Options", "CollectPlaytimeRewards")
        IniWrite(UseHForUpgrade, SettingsFile, "Options", "UseHotkeyForUpgrade")
        IniWrite(DefaultMouseSpeed, SettingsFile, "Options", "DefaultMouseSpeed")
        IniWrite(MouseDelay, SettingsFile, "Options", "MouseDelay")
        IniWrite(KeyDelay, SettingsFile, "Options", "KeyDelay")
        IniWrite(UpgradeDelay, SettingsFile, "Options", "UpgradeDelay")
        IniWrite(ScrollDelay, SettingsFile, "Options", "ScrollDelay")

        if (TimeScaleMode = "1.5x") {
            UseTimeScale := true
            TimeScaleMultiplier := 1.5
        } else if (TimeScaleMode = "2x") {
            UseTimeScale := true
            TimeScaleMultiplier := 2
        } else {
            UseTimeScale := false
            TimeScaleMultiplier := 1
        }

        HideDebugConsole()

        if (AlwaysOnTop = 1) {
            MainGui.Opt("+AlwaysOnTop")
        } else {
            MainGui.Opt("-AlwaysOnTop")
        }

        SetDefaultMouseSpeed(DefaultMouseSpeed)
        SetMouseDelay(MouseDelay)
        SetKeyDelay(KeyDelay)

        if (showMsg) {
            MsgBox("All settings have been successfully saved!", "Ultimate Macro", 0x1040)
        }
    }
}

CheckVipLink(ctrl, *) {
    
    str := Trim(VipLinkCtrl.Value)
    
    if (RegExMatch(str, "i)roblox\.com\/(?:[a-z]{2}\/)?games\/3260590327\/[^\/]*\?privateServerLinkCode=(?<code>[a-z0-9]{32})", &m)) {
        UseVipServerCtrl.Value := 1
        return
    }
    if (RegExMatch(str, "i)roblox\.com\/share\?code=(?<code>[a-f0-9]{32})", &m)) {
        try {
            wr := ComObject("WinHttp.WinHttpRequest.5.1")
            wr.Open("GET", "https://www.roblox.com/share?code=" m["code"] "&type=Server", true)
            wr.Send()
            if (wr.WaitForResponse(3) && wr.Status = 200 && InStr(wr.ResponseText, "3260590327")) {
                return
            }
        } catch Error {
            
        }
    }
    UseVipServerCtrl.Value := 0
}

CheckWebhookLink(ctrl, *) {
    v := MainGui.Submit(false)
    link := v.WebhookLink
    if (link = "" || (!InStr(link, "discord.com/api/webhooks/") && !InStr(link, "discordapp.com/api/webhooks/"))) {
        WebhookEnabledCtrl.Value   := 0
        return
    }
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", link, false)
        whr.SetTimeouts(3000, 3000, 4000, 4000)
        whr.Send()
        WebhookEnabledCtrl.Enabled := (whr.Status = 200)
        if (whr.Status != 200)
            WebhookEnabledCtrl.Value := 0
    } catch {
        WebhookEnabledCtrl.Value := 0
    }
}

CheckWebhookLink2(ctrl, *) {
    v := MainGui.Submit(false)
    link := v.WebhookLink2
    if (link = "" || (!InStr(link, "discord.com/api/webhooks/") && !InStr(link, "discordapp.com/api/webhooks/"))) {
        return
    }
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", link, false)
        whr.SetTimeouts(3000, 3000, 4000, 4000)
        whr.Send()
    } catch {
    }
}

ShowDiscordSettings(*) {
    HideAllTabContent()
    for ctrl in DiscordWebhookTab
        ctrl.Visible := true
    EnableWebhookLink2()
}


ShowFAQ(*) {
    ModernMsgBox("FAQ",
        "[SCREEN AND SYSTEM SETTINGS]`n" .
        "- Screen Resolution: Works strictly in 1920x1080.`n" .
        "- Windows Scale: Must be set to 100%.`n" .
        "- Taskbar: Must be visible.`n`n" .
        "[ROBLOX AND GAME SETTINGS]`n" .
        "- UI Scale: Set to Large.`n" .
        "- Screen Shake: Must be DISABLED.`n" .
        "- Roblox Chat: Close the chat before starting the macro.`n" .
        "- Set 'Prefer Vertical Upgrades' to Disabled.`n" .
        "- Fonts: Do not use custom fonts.`n`n" .
        "[COMMANDER ISSUES]`n" .
        "- Auto Chain: Enter 'Commander1', 'Commander2', etc., when placing them.", "OK")
}
HelpChain(*) {
    ModernMsgBox("Info", "Configure hotkey for Commander's 'Call of Arms'.", "OK")
}
HelpBeat(*) {
    ModernMsgBox("Info", "Configure hotkey for DJ's 'Drop The Beat'.", "OK")
}
HelpCaravan(*) {
    ModernMsgBox("Info", "Configure hotkey for the 'Support Caravan'.", "OK")
}
HelpCancelPlacement(*) {
    ModernMsgBox("Info", "Configure hotkey for the 'Cancel Placement'.", "OK")
}
HelpTimeScale(*) {
    ModernMsgBox("Timescale Info", "1.5x — more stable and recommended for most cases.`n2x — requires special strategies but is much more effective.`n`nThis will automatically turn off if you run out of timescale tickets.", "OK")
}
HelpPotatoMode(*) {
    ModernMsgBox("Info", "Turn this on if your macro acts inconsistently or if you have lags.", "OK")
}
HelpSendCurrencies(*) {
    ModernMsgBox("Info", "If you enable the 'Send currencies' toggle, the macro will send you information about your coins, gems, total matches, triumphs, and losses.`n`nMay be buggy.", "OK")
}
HelpRestartBtn(*) {
    ModernMsgBox("Info", "If this setting is ON, the macro will use the restart button when you lose.`n`nIt's recommended to turn it OFF if you are using a win strategy and your macro sometimes appears on the wrong map.", "OK")
}
HelpPlayAgainBtn(*) {
    ModernMsgBox("Info", "If this setting is ON, the macro will use the play again button when you win.", "OK")
}
HelpAutoCameraCorrection(*) {
    ModernMsgBox("Info", "The macro will use tds keybind when upgrading the tower.`n`nIt's recommended to turn it ON.", "OK")
}
HelpBrawler(*) {
    ModernMsgBox("Info", "To record brawler reposition, press CTRL+your keybind", "OK")
}
HelpRaise(*) {
    ModernMsgBox("Info", "To record raise the dead, press CTRL+your keybind", "OK")
}
HelpCheckTheMap(*) {
    ModernMsgBox("Info", "When you join the map, the macro will check is it in the correct map or not. If no, it reloads.`n`nIt's recommended to turn it ON.", "OK")
}


NormalizeModifierToken(token) {
    tok := Trim(token)
    if (tok = "")
        return ""
    tokLower := StrLower(tok)
    
    static modMap := [
        { code: "Gla", prefix: "gl", name: "glass" },
        { code: "Hid", prefix: "hi", name: "hidden" },
        { code: "Exp", prefix: "ex", name: "exploding" },
        { code: "Lim", prefix: "li", name: "limitation" },
        { code: "Com", prefix: "co", name: "committed" },
        { code: "Fly", prefix: "fl", name: "flying" },
        { code: "Fog", prefix: "fo", name: "fog",        aliases: ["foggy"] },
        { code: "Qua", prefix: "qu", name: "quarantine", aliases: ["arm", "armored"] },
        { code: "Inf", prefix: "in", name: "inflation",  aliases: ["reg", "regeneration"] },
        { code: "Bro", prefix: "br", name: "broke",      aliases: ["slo", "slow"] },
        { code: "Spe", prefix: "sp", name: "speedy" },
        { code: "Hea", prefix: "he", name: "healthy",    aliases: ["str", "strong"] }
    ]
    
    for item in modMap {
        if (tokLower = StrLower(item.code)
            || tokLower = item.prefix
            || tokLower = item.name
            || (StrLen(tokLower) >= 2 && SubStr(tokLower, 1, 2) = item.prefix)
            || InStr(item.name, tokLower) = 1) {
            return item.code
        }
        if (item.HasProp("aliases")) {
            for alias in item.aliases {
                if (tokLower = alias || (StrLen(tokLower) >= 3 && InStr(alias, tokLower) = 1))
                    return item.code
            }
        }
    }
    
    if (StrLen(tok) >= 3)
        return StrUpper(SubStr(tok, 1, 1)) . StrLower(SubStr(tok, 2, 2))
    return tok
}

ModifierCodeToName(code) {
    global ModifierCheckboxes
    codeLower := StrLower(Trim(code))
    if IsSet(ModifierCheckboxes) {
        for item in ModifierCheckboxes {
            if (StrLower(item.code) = codeLower || StrLower(item.name) = codeLower)
                return item.name
        }
    }
    return code
}

UpdateModifierUI(modString, autoSave := false) {
    global ModifierCheckboxes, ModifiersTextCtrl, modifiers
    
    activeMap := Map()
    normalizedCodes := []
    fullNamesList := []
    
    Loop Parse, modString, "," {
        c := NormalizeModifierToken(A_LoopField)
        if (c != "" && !activeMap.Has(c)) {
            activeMap[c] := true
            normalizedCodes.Push(c)
            fullNamesList.Push(ModifierCodeToName(c))
        }
    }
    
    if IsSet(ModifierCheckboxes) {
        for item in ModifierCheckboxes {
            isChecked := activeMap.Has(item.code) ? 1 : 0
            try item.ctrl.Value := isChecked
        }
    }
    
    cleanCodesStr := ""
    for idx, code in normalizedCodes {
        cleanCodesStr .= (idx = 1 ? "" : ", ") . code
    }
    
    fullNamesStr := ""
    for idx, fn in fullNamesList {
        fullNamesStr .= (idx = 1 ? "" : ", ") . fn
    }
    
    modifiers := cleanCodesStr
    
    if IsSet(ModifiersTextCtrl) {
        try ModifiersTextCtrl.Value := fullNamesStr
    }
    
    if (autoSave || (cleanCodesStr != "" && cleanCodesStr != modString)) {
        SaveModifiersToStrategyFile(cleanCodesStr)
    }
}

OnModifierCheckboxClick(*) {
    global ModifierCheckboxes, ModifiersTextCtrl, modifiers
    
    activeCodes := []
    activeFullNames := []
    for item in ModifierCheckboxes {
        if (item.ctrl.Value = 1) {
            activeCodes.Push(item.code)
            activeFullNames.Push(item.name)
        }
    }
    
    currentRaw := IsSet(ModifiersTextCtrl) ? ModifiersTextCtrl.Value : ""
    Loop Parse, currentRaw, "," {
        tok := Trim(A_LoopField)
        if (tok = "")
            continue
        c := NormalizeModifierToken(tok)
        isStandard := false
        for item in ModifierCheckboxes {
            if (c = item.code) {
                isStandard := true
                break
            }
        }
        if (!isStandard) {
            alreadyIn := false
            for ac in activeCodes {
                if (ac = c) {
                    alreadyIn := true
                    break
                }
            }
            if (!alreadyIn) {
                activeCodes.Push(c)
                activeFullNames.Push(tok)
            }
        }
    }
    
    newCodesStr := ""
    for idx, c in activeCodes {
        newCodesStr .= (idx = 1 ? "" : ", ") . c
    }
    
    newFullNamesStr := ""
    for idx, fn in activeFullNames {
        newFullNamesStr .= (idx = 1 ? "" : ", ") . fn
    }
    
    if IsSet(ModifiersTextCtrl) {
        ModifiersTextCtrl.Value := newFullNamesStr
    }
    modifiers := newCodesStr
    SaveModifiersToStrategyFile(newCodesStr)
}

OnModifiersTextChange(*) {
    global ModifierCheckboxes, ModifiersTextCtrl, modifiers
    
    if !IsSet(ModifiersTextCtrl)
        return
        
    rawText := ModifiersTextCtrl.Value
    
    activeMap := Map()
    Loop Parse, rawText, "," {
        c := NormalizeModifierToken(A_LoopField)
        if (c != "")
            activeMap[c] := true
    }
    
    if IsSet(ModifierCheckboxes) {
        for item in ModifierCheckboxes {
            isChecked := activeMap.Has(item.code) ? 1 : 0
            try item.ctrl.Value := isChecked
        }
    }
    
    SetTimer(DebouncedSaveModifiers, -600)
}

DebouncedSaveModifiers() {
    global ModifiersTextCtrl, modifiers
    if !IsSet(ModifiersTextCtrl)
        return
        
    rawText := ModifiersTextCtrl.Value
    activeMap := Map()
    normalizedCodes := []
    fullNamesList := []
    Loop Parse, rawText, "," {
        c := NormalizeModifierToken(A_LoopField)
        if (c != "" && !activeMap.Has(c)) {
            activeMap[c] := true
            normalizedCodes.Push(c)
            fullNamesList.Push(ModifierCodeToName(c))
        }
    }
    cleanCodesStr := ""
    for idx, c in normalizedCodes {
        cleanCodesStr .= (idx = 1 ? "" : ", ") . c
    }
    fullNamesStr := ""
    for idx, fn in fullNamesList {
        fullNamesStr .= (idx = 1 ? "" : ", ") . fn
    }
    modifiers := cleanCodesStr
    SaveModifiersToStrategyFile(cleanCodesStr)
    
    if (ModifiersTextCtrl.Value != fullNamesStr && !WinActive("ahk_id " ModifiersTextCtrl.Hwnd)) {
        try ModifiersTextCtrl.Value := fullNamesStr
    }
}

OnSaveModifiersBtnClick(*) {
    global ModifiersTextCtrl, modifiers
    rawText := IsSet(ModifiersTextCtrl) ? ModifiersTextCtrl.Value : ""
    
    UpdateModifierUI(rawText, true)
    fullNames := ModifiersTextCtrl.Value
    ModernMsgBox("Modifiers Saved", "Strategy modifiers successfully saved:`n`nActive: " (fullNames != "" ? fullNames : "(None)") "`n(Applied Codes: " (modifiers != "" ? modifiers : "(None)") ")", "OK")
}

SaveModifiersToStrategyFile(modStr) {
    global Strategy1Ctrl, Strategy1Path, SettingsFile
    stratPath := (IsSet(Strategy1Ctrl) && Strategy1Ctrl.Value != "") ? Strategy1Ctrl.Value : Strategy1Path
    if (stratPath != "" && FileExist(stratPath)) {
        try {
            IniWrite(modStr, stratPath, "Settings", "modifiers")
            LogToConsole("Saved modifiers to " stratPath ": " modStr)
        }
    }
    try IniWrite(modStr, SettingsFile, "Options", "Modifiers")
}

LoadStrategyFile(file) {
    global Towers, RecordedSteps, gamemap, difficulty, requiredTowers, autoChain, autoCaravan
    global autoDropTheBeat, AutoSkip, AbilitySpam, MoveEnabled, MoveDirection, MoveDuration
    global modifiers, Commander, StrategyWidth, StrategyHeight

    Towers := Map()
    RecordedSteps := []
    DeleteAllIndicators()

    gamemap := IniRead(file, "Settings", "map", "")
    if (gamemap != "")
        IniWrite(gamemap, StateFile, "State", "Map")
    difficulty := IniRead(file, "Settings", "difficulty", "")
    requiredTowers  := IniRead(file, "Settings", "requiredTowers",  "")
    autoChain := IniRead(file, "Settings", "autoChain", "OFF")
    autoCaravan := IniRead(file, "Settings", "autoCaravan", "OFF")
    autoDropTheBeat := IniRead(file, "Settings", "autoDropTheBeat", "OFF")
    AutoSkip := IniRead(file, "Settings", "autoSkip", "ON")
    AbilitySpam := IniRead(file, "Settings", "abilitySpam", "ON")
    modifiers := IniRead(file, "Settings", "modifiers", "")
    try UpdateModifierUI(modifiers)

    moveDown := IniRead(file, "Settings", "moveDown", "false")
    tempEnabled := IniRead(file, "Settings", "moveEnabled",   "")
    tempDir := IniRead(file, "Settings", "moveDirection", "")
    tempDur := IniRead(file, "Settings", "moveDuration",  "")

    if (tempEnabled != "") {
        MoveEnabled := (tempEnabled = "true" || tempEnabled = "1") ? true : false
        MoveDirection := (tempDir != "" && (tempDir = "W" || tempDir = "A" || tempDir = "S" || tempDir = "D")) ? tempDir : "W"
        MoveDuration := IsNumber(tempDur) ? Integer(tempDur) : 750
    } else {
        if (moveDown = "true") {
            MoveEnabled := true, MoveDirection := "S", MoveDuration := 750
        } else {
            MoveEnabled := false, MoveDirection := "W", MoveDuration := 750
        }
    }

    Commander := false

    StrategyWidth  := Integer(IniRead(file, "DO NOT EDIT", "width",  "1920"))
    StrategyHeight := Integer(IniRead(file, "DO NOT EDIT", "height", "1090"))

    inSteps := false
    Loop Read, file {
        line := Trim(A_LoopReadLine)
        if (line ~= "i)^\[Settings\]") { 
            inSteps := false
        }
        if (line ~= "i)^\[Steps\]")    { 
            inSteps := true
        }
        if (inSteps && line != "") {
            RecordedSteps.Push(line)
        }
    }

    
    for i, step in RecordedSteps {
        if RegExMatch(step, "i)SpawnTower\s*\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*(.*?)\s*\)", &m) {
            towerID := Trim(m[1])
            Towers[towerID] := {x: 0, y: 0, slot: 0, level: 0, path: 0, pathLevel: 0}
        }
        if RegExMatch(step, "i)UpgradeTower\s*\(\s*([^,]+?)\s*(?:,\s*(?:false|true)\s*)?(?:,\s*\d+\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?\s*\)", &m) {
            tid := Trim(m[1])
            if (Towers.Has(tid) && m[2] != "") {
                Towers[tid].path := m[2]
                Towers[tid].pathLevel := (m[3] != "") ? m[3] : 4
            }
        }
    }
}

RunStrategy(stratFile := "", skipRestart := false) {
    global RunningStrategy, difficulty, MoveEnabled, MoveDirection, MoveDuration
    global unfocusX, unfocusY, UseTimeScale, TimeScaleMultiplier, TimeScaleMode
    global SettingsFile, requiredTowers, modifiers, LastOpenedTowerID
    global LastSkipCheck, SKIP_CHECK_INTERVAL, AutorunStartTime, StateFile
    global WebhookEnabled, gamemap, AutoEquip

    if (RunningStrategy != true)
        return

    If (!skiprestart)
    	isDisconnected()

    KillSubmacros()
    startWatchdog()

    LastOpenedTowerID := ""

    LogToConsole("Starting strategy... Press F2 to STOP!!!")
    LogToConsole("Map = " gamemap)
    LogToConsole("Mode = " difficulty)
    LogToConsole("Timescale = " TimeScaleMode)
    LogToConsole("Required Towers: " requiredTowers)
    if (modifiers != "")
        LogToConsole("Modifiers: " modifiers)

    checkStart := IniRead(StateFile, "State", "StartTime", 0)
    if (checkStart = 0) {
        IniWrite(A_TickCount, StateFile, "State", "StartTime")
        AutorunStartTime := A_TickCount
    } else {
        AutorunStartTime := checkStart
    }

    if (!skipRestart) {
        CheckRestart()
    } else {
        CloseRoblox()
        RunRoblox()
        if (AutoEquip) {
            EquipTowers(RequiredTowers)
        }
        JoinGame()
    }

    if (readyX = 0 && readyY = 0) {
        waitReady()
    }

    if (!IsRestarting) {
        CheckTheMapF()
        if (!InArray(SpecialMaps, gamemap)) {
            AlignCamera()
        }
    }

    activateTimescale()

    ClickReady()
    DashboardMatch.Started(StateFile)
    DashboardActivity.SessionStarted()
    
    PlayStrategy()
}

PlayStrategy() {
    global canUseAbility, StateFile

    IniWrite(A_TickCount, StateFile, "State", "TimeWhenStartedPlaying")
    SetTimer(UseAbilities, 750)

    i := 1
    while (i <= RecordedSteps.Length) {
        step := RecordedSteps[i]
        isMacroStep := RegExMatch(step, "i)^(Click|Send|Sleep)\s*\(")

        if RegExMatch(step, "i)UpgradeTower\s*\(\s*([^,]+?)\s*(?:,\s*(false|true)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?\s*\)", &m) {
            currentID    := Trim(m[1])
            countUpgrades := (m[3] != "") ? Integer(m[3]) : 1
            currentPath   := (m[4] != "") ? Integer(m[4]) : 0
            currentpathLevel := (m[5] != "") ? Integer(m[5]) : 4

            lookAhead := i + 1
            while (lookAhead <= RecordedSteps.Length) {
                nextStep := RecordedSteps[lookAhead]
                if RegExMatch(nextStep, "i)UpgradeTower\s*\(\s*" currentID "\s*(?:,\s*(?:false|true)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?\s*\)", &mN) {
                    countUpgrades += (mN[1] != "") ? Integer(mN[1]) : 1
                    lookAhead++
                } else {
                    break
                }
            }

            success := UpgradeTower(currentID, false, countUpgrades, currentPath, currentpathLevel)
            i := success ? lookAhead : i + 1
        } else if RegExMatch(step, "i)SetDJTrack\s*\(\s*([^\s,)]+)\s*\)", &t) {
            SetDJTrack(t[1])
            i++
        } else if RegExMatch(step, "i)SpawnTower\s*\(.*\)") {
            ExecuteStep(step)
            i++
        } else {
            try {
                ExecuteStep(step)
            } catch Error as e { 
                LogToConsole("ERROR executing step " . i . ": " . step . " '" . e.Message . "' ")
            }
            i++
        }
    }

    Click(ScaleX(unfocusX), ScaleY(unfocusY))
    LogToConsole("All strategy steps completed...")
    Loop {
        canUseAbility := true
        LastOpenedTowerID := ""
        Sleep 3000
    }
    ;If the macro doesn't replaying again after win/loss it's a watchdog.ahk issue. Please report it if this happened to you. 
    ;Do not add anything here.
}

ExecuteStep(step) {
    global Commander, unfocusX, unfocusY
    step := RegExReplace(step, "\s*;.*$", "")
    step := Trim(step)
    if (step = "")
        return
    if RegExMatch(step, "i)SpawnTower\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d)\s*,\s*(.*?)\s*\)", &m) {
        SpawnTower(m[1], m[2], m[3], Trim(m[4]))
        return
    }
    if RegExMatch(step, "i)UpgradeTower\s*\(\s*([^,]+?)\s*(?:,\s*(false|true)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?\s*\)", &m) {
        UpgradeTower(Trim(m[1]), (m[2]="true"), (m[3]!="") ? Integer(m[3]) : 1, (m[4]!="") ? Integer(m[4]) : 0, (m[5]!="") ? Integer(m[5]) : 4)
        return
    }
    
    if RegExMatch(step, "i)CloneTower\s*\(\s*([^,]+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)", &m) {
        CloneTower(Trim(m[1]), Integer(m[2]), Integer(m[3]), Integer(m[4]))
        return
    }

    if RegExMatch(step, "i)^ToggleAutoskip\s*\(\s*\)$", &m) {
        ToggleAutoskip()
        return
    }
    if RegExMatch(step, "i)ChangeTargets\s*\(\s*([^,]+?)\s*,\s*([^)]+?)\s*\)", &m) {
        ChangeTargets(Trim(m[1]), Trim(m[2]))
        return
    }


    if RegExMatch(step, "i)CloneTower\s*\(\s*([^,]+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)", &m) {
        CloneTower(Trim(m[1]), Integer(m[2]), Integer(m[3]), 0)
        return
    }
    if RegExMatch(step, "i)ActivateRaiseTheDead\s*\(\s*(\d+)\s*\)", &m) {
        ActivateRaiseTheDead(Integer(m[1]))
        return
    }
    if RegExMatch(step, "i)ActivateRaiseTheDead\s*\(\s*\)", &m) {
        ActivateRaiseTheDead(0)
        return
    }

    if RegExMatch(step, "i)BrawlerReposition\s*\(\s*([^,]+?)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)", &m) {
        BrawlerReposition(Trim(m[1]), Integer(m[2]), Integer(m[3]))
        return
    }

    if RegExMatch(step, "i)SetDJTrack\s*\(\s*(.+?)\s*\)", &m) {
        track := Trim(m[1], ' "')
        if (track != "")
            SetDJTrack(track)
        return
    }
    if RegExMatch(step, "i)^Click\s*\(\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(.+?))?\s*\)$", &m) {
        button := InStr(m[3], "Right") ? "Right" : "Left"
        Click(ScaleX(m[1]) " " ScaleY(m[2]) " " button)
        return
    }
    if RegExMatch(step, 'i)^Send\s*\(\s*"([^"]+)"\s*,\s*hold:=(\d+)\s*\)$', &m) {
        SendEvent("{" m[1] " down}")
        HyperSleep(Integer(m[2]))
        SendEvent("{" m[1] " up}")
        return
    }
    if RegExMatch(step, "i)^Sleep\s*\(\s*(\d+)\s*\)$", &m) {
        Sleep(Integer(m[1]))
        return
    }
    if RegExMatch(step, "i)Commander\s*:=\s*true") {
        Commander := true
        return
    }
    if RegExMatch(step, "i)SellTower\s*\(\s*([^)]+?)\s*\)", &m) {
        SellTower(Trim(m[1]))
        return
    }
}

LowerGraphics() {
    ActivateRoblox()
    SendEvent("{SC02A down}")
    Loop 10 {
        SendEvent("{SC044}")
        Sleep(20)
    }
    SendEvent("{SC02A up}")
}

EquipTowers(towers) {
    getRobloxPos(,,&rw,&rh)

    savedCloseX := 0
    savedCloseY := 0

    closeChat()
    Sleep(600)

    StartTime := A_TickCount
    Loop {
        W := Round(rw * 0.3)
        H := rh - 0

        resItems := AdvancedImageSearch("Resources\items.png", 0, 0, W, H)
        if (resItems.status == "success" && resItems.score > 0.56) {
            fx := resItems.x
            fy := resItems.y
            MouseMove(fx, fy+ScaleY(7), A_DefaultMouseSpeed+1)
            Sleep(100)
            MouseClick()
            break
        } 
        if (A_TickCount - StartTime > 4000) {
            break
        }
        Sleep(500)
    }

    Sleep(800)

    openedMenu := false
    StartTime := A_TickCount
    Loop {
        X1 := Round(rw * 0.2)
        Y1 := 0
        W := Round(rw * 1) - X1
        H := Round(rh * 0.4) - Y1
        resclose := AdvancedImageSearch("Resources\close_items.png", X1, Y1, W, H)

        If (resclose.status = "success" && resclose.score >= 0.85) {
            openedMenu := true
            savedCloseX := resclose.x
            savedCloseY := resclose.y
            break
        } 
        if (A_TickCount - StartTime > 4000)
            break
        Sleep(500)
    }

    if (!openedMenu) {
        StartTime := A_TickCount

        W := Round(rw * 0.3)
        H := rh - 0

        Loop {
            resItems := AdvancedImageSearch("Resources\items.png", 0, 0, W, H)
            if (resItems.status == "success" && resItems.score > 0.56) {
                fx := resItems.x
                fy := resItems.y
                MouseMove(fx, fy+ScaleY(7), A_DefaultMouseSpeed+1)
                Sleep(100)
                MouseClick()
                break
            } 

            if (A_TickCount - StartTime > 5000)
                break
        }

        openedMenu := false
        StartTime := A_TickCount
        Loop {
            X1 := Round(rw * 0.2)
            Y1 := 0
            W := Round(rw * 1) - X1
            H := Round(rh * 0.4) - Y1
            resclose := AdvancedImageSearch("Resources\close_items.png", X1, Y1, W, H)

            If (resclose.status = "success" && resclose.score >= 0.85) {
                openedMenu := true
                savedCloseX := resclose.x
                savedCloseY := resclose.y
                break
            } 

            if (A_TickCount - StartTime > 2000)
                break
            Sleep(500)
        }

        if (!openedMenu) {
            LogToConsole("Failed to equip towers! The macro can't see the towers menu! Reloading...", true, false)
            Sleep 400
            SafeReload()
            return
        }
    }

    srchX := ScaleX(484)
    srchY := ScaleY(229)

    StartTime := A_TickCount
    Loop {
        resBar := AdvancedImageSearch("Resources\searchbar_items.png", 0,0,Round(rh*0.5),Round(rh*0.5))
        if (resBar.status == "success" && resBar.score > 0.67) {
            srchX := resBar.x+30
            srchY := resBar.y
            break
        }
        if (A_TickCount - StartTime > 4000)
            break
        Sleep(400)
    }

    Click(srchX, srchY)
    Sleep(150)

    SendText("Sniper")
    Sleep(400)
    Click(srchX+10, ScaleY(409))
    Sleep(500)

    X := Round(rw * 0.61)
    Y := ScaleY(830)
    X1 := Round(rw * 0.4)
    Y1 := Round(rh * 0.4)
    W := Round(rw * 0.9) - X1
    H := rh - Y1

    StartTime := A_TickCount
    Loop {
        getRobloxPos(,,&w,&h)
        baseScale := h / 1009

        resAlign := AdvancedImageSearch("Resources\equip.png", X1, Y1, W, H, 0.5 * baseScale, 2, 0.025)

        if (resAlign.status == "success" && resAlign.score > 0.4) {
            Y := resAlign.y+ScaleY(110)
        }

        offset := -30
        baseY := Y

        MouseMove(X, Y+ ScaleY(offset))

        oldMode := A_SendMode
        oldDelay := A_MouseDelay
        SendMode("Input")
        SetMouseDelay(0)

        while (offset <= 30) {
            cY := baseY + ScaleY(offset)

            MouseClick("Left", X, cY)

            offset += 5
            Sleep 5
        }
        SendMode(oldMode)
        SetMouseDelay(oldDelay)

        Sleep(600)
        failCount := 0
        
        InnerStart := A_TickCount
        Loop {
            X1 := Round(rw * 0.4)
            Y1 := Round(rh * 0.5)
            W := Round(rw * 0.9) - X1
            H := rh - Y1

            getRobloxPos(,,&w,&h)
            baseScale := Round(h / 1009)

            resUnequip := AdvancedImageSearch("Resources\unequip.png", X1, Y1, W, H, 0.3 * baseScale, 1.4, 0.025)
            if (resUnequip.status == "success" && resUnequip.score > 0.63) {
                if (PixelSearch(&uX, &uY, resUnequip.x-ScaleX(40), resUnequip.y-ScaleY(25), resUnequip.x+ScaleX(40), resUnequip.y+ScaleY(25), 0x7A797A, 5)) {
                    Click(resUnequip.x, resUnequip.y)
		    MouseMove(resUnequip.x, resUnequip.y-ScaleY(80))
                    failCount := 0
                    break
                } else {
                    failCount++
                    if (failCount >= 5) {
                        break 2
                    }
                    Sleep(200)
                    continue
                }
            } else {
                failCount++
                if (failCount >= 3) {
                    break 2
                }
            }
            if (A_TickCount - InnerStart > 3000)
                break
            Sleep(200)
        }
        Sleep(400)
    }
    
    Loop Parse, towers, ","
    {
        ActivateRoblox()
        tower := Trim(A_LoopField)

        goldtower := RegExMatch(tower, "i)\b(Golden|G\.|G)\b") ? true : false
        regulartower := RegExMatch(tower, "i)\b(Regular|R\.|R)\b") ? true : false

        towerToEnter := RegExReplace(tower, "i)\b(Golden|G\.|G|Regular|R\.|R)\b\s*|\.")
        towerToEnter := Trim(towerToEnter) 

        Click(srchX, srchY)
        Sleep(150)

        SendText(towerToEnter)
        Sleep(500)
        Click(srchX+10, ScaleY(409))
        Sleep(500)

        X1 := Round(rw * 0.4)
        Y1 := Round(rh * 0.5)
        W := Round(rw * 0.9) - X1
        H := rh - Y1

        TowerStart := A_TickCount
        Loop {
            getRobloxPos(,,&w,&h)
            baseScale := h / 1009

            resEquip := AdvancedImageSearch("Resources\equip.png", X1, Y1, W, H, 0.5 * baseScale, 1.4, 0.025)

            if (resEquip.status == "success" && resEquip.score > 0.4) {
                If (PixelSearch(&eX, &eY, resEquip.x-40, resEquip.y-25, resEquip.x+40, resEquip.y+25, 0x45DC4A, 7)) {
                    Click(resEquip.x, resEquip.y)
                    
                    if (goldtower) {
                        GoldStart := A_TickCount
                        Loop {
                            resGolden := AdvancedImageSearch("Resources\notgolden.png", X1, Y1, W, H) 
                            if (resGolden.status == "success" && resGolden.score > 0.55) {
                                If (PixelSearch(&eX, &eY, resGolden.x-40, resGolden.y-25, resGolden.x+40, resGolden.y+25, 0x1E1E1E, 4)) {
                                    Click(resGolden.x, resGolden.y)
                                    Sleep(300)
                                    break
                                }
                            }
                            if (A_TickCount - GoldStart > 1000)
                                break
                            Sleep(400)
                        }
                    }
                    
                    if (regulartower) {
                        RegStart := A_TickCount
                        Loop {
                            resGolden := AdvancedImageSearch("Resources\golden.png", X1, Y1, W, H, 0.4, 2) 
                            if (resGolden.status == "success" && resGolden.score > 0.55) {
                                If (PixelSearch(&eX, &eY, resGolden.x-40, resGolden.y-25, resGolden.x+40, resGolden.y+25, 0xFFC11F, 8)) {
                                    Click(resGolden.x, resGolden.y)
                                    Sleep(300)
                                    break
                                }
                            }
                            if (A_TickCount - RegStart > 1000)
                                break
                            Sleep(400)
                        }
                    }
                    break
                }
                Sleep(100)
            }
            if (A_TickCount - TowerStart > 5000)
                break
            Sleep(400)
        }
        Sleep(400)
    }
    X1 := Round(rw * 0.2)
    Y1 := 0
    W := Round(rw * 1) - X1
    H := Round(rh * 0.4) - Y1
    resclose := AdvancedImageSearch("Resources\close_items.png", X1, Y1, W, H)

    If (resclose.status = "success" && resclose.score >= 0.85) {
        Click(resclose.x, resclose.y)
    } else if (savedCloseX != 0 && savedCloseY != 0) {
        Click(savedCloseX, savedCloseY)
    }
    
    LogToConsole("Successfully equipped towers: " towers, true, false)
    IniWrite(1, StateFile, "State", "Equipped")
}

CheckRestart() {
    global IsRestarting, difficulty, UseRestartBtn, UsePlayAgainBtn, CollectPlaytimeRewards, requiredTowers, AutoEquip

    shouldCollectRewards := (CollectPlaytimeRewards = "1" || CollectPlaytimeRewards = 1) && CheckDailyRewardTime() && (AutorunStartTime = 0 || (A_TickCount - AutorunStartTime) > 300000)
    shouldEquip := !Number(IniRead(StateFile, "State", "Equipped", 0))

    if (shouldCollectRewards) {
        LogToConsole("Navigating to lobby to check playtime rewards...", true, false)
        IsRestarting := false
        CloseRoblox()
        RunRoblox()
        if (shouldEquip && AutoEquip) {
            EquipTowers(requiredTowers)
        }
        JoinGame()
        return
    }

    KillSubmacros()

    if GetRobloxHWND() {
        ActivateRoblox()
        Sleep(1500)
        ActivateRoblox()
        SendEvent("{" CancelPlacementKey "}")
        getRobloxPos(,, &w, &h)
        
        resRevive := AdvancedImageSearch("Resources\use_revive_ticket.png", w * 0.2, h * 0.2, w * 0.6, h * 0.7)

        if (resRevive.status == "success" && resRevive.score > 0.7) {
            resCancel := AdvancedImageSearch("Resources\cancel.png", w * 0.2, h * 0.2, w * 0.6, h * 0.7)
            
            if (resCancel.status == "success" && resCancel.score > 0.7) {
                ActivateRoblox()
                Click(resCancel.x, resCancel.y)
                Sleep 250
            }
        }

        if (UseRestartBtn = "1" || UseRestartBtn = 1) {
            resRestart := AdvancedImageSearch("Resources\Restart.png", 0, h * 0.5, w, h * 0.5, 0.5, 1.5)
            resRestart2 := AdvancedImageSearch("Resources\Restart2.png", 0, h * 0.5, w, h * 0.5, 0.5, 1.5)

            if ((resRestart.status == "success" && resRestart.score > 0.64) || (resRestart2.status == "success" && resRestart2.score > 0.64)) {
                res := resRestart.score > resRestart2.score ? resRestart : resRestart2
                IsRestarting := true
                LogToConsole("Restarting the match")
                Click(res.x, res.y)
                Sleep(150)
                startWatchdog()
                return
            }
        }

        if (UsePlayAgainBtn = "1" || UsePlayAgainBtn = 1) {

            resReplay := AdvancedImageSearch("Resources\PlayAgain.png", 0, h * 0.5, w, h*0.5, 0.5, 1.5, 0.025)
            
            if (resReplay.status == "success" && resReplay.score > 0.64) {
                Click(resReplay.x, resReplay.y)
                Sleep(150)
                WaitForLobbyLoad()
                startWatchdog()
                return
            }
        }
    }

    startWatchdog()
    IsRestarting := false
    CloseRoblox()
    RunRoblox()
    if (shouldEquip && AutoEquip) {
        EquipTowers(requiredTowers)
    }
    JoinGame()
}

RunRoblox(doReload := true) {
    global VipLink, UseVipServer
    PlaceID := "3260590327"

    Loop {
        if ((UseVipServer = "1" || UseVipServer = 1) && VipLink != "") {
            if InStr(VipLink, "privateServerLinkCode=") {
                RegExMatch(VipLink, "privateServerLinkCode=([a-fA-F0-9]+)", &f)
                DeepLink := "roblox://placeID=" PlaceID "&linkcode=" f[1]
            } else if InStr(VipLink, "share?code=") {
                RegExMatch(VipLink, "code=([a-fA-F0-9]+)", &f)
                DeepLink := "roblox://navigation/share_links?code=" f[1] "&type=Server"
            } else {
                DeepLink := "roblox://placeID=" PlaceID
            }
        } else {
            DeepLink := "roblox://placeID=" PlaceID
        }

        Run(DeepLink)
        robloxopened := false
        Loop 60 {
            if WinExist("Roblox ahk_exe RobloxPlayerBeta.exe") {
                robloxopened := true
                break
            }
            if WinExist("Roblox ahk_exe ApplicationFrameHost.exe") {
                robloxopened := true
                break
            }
                
            Sleep(1000)
        }
        if (!robloxopened && doReload) {
            LogToConsole("Roblox not started after 1 minute! Reloading...", true)
            SafeReload()
        } else if (!robloxopened && !doReload) {
            return false
        }
        ActivateRoblox()
        ExitFullScreen()
        WinMinimize "Roblox"
        WinMaximize "Roblox"
        ActivateRoblox()

        SetTimer(CheckPopups, 5000)

        startTime := A_TickCount
        getRobloxPos(,,&w,&h)
        Loop {
            ActivateRoblox()

            if (A_TickCount - startTime > 60000) {
                if (doReload) {
                    SafeReload()
                } else {
                    return false
                }
            }

            res0 := AdvancedImageSearch("Resources/Play.png", Round(w * 0.25), Round(h * 0.66), Round(w * 0.75), Round(h * 0.34))
            if (res0.status = "success" && res0.score > 0.65) {
                break
            } 
            Sleep(1500)
        }
        SendEvent("{sc00F}")
        return true 
    }
}

ExitFullScreen() {
    if WinExist("Roblox ahk_exe RobloxPlayerBeta.exe") || WinExist("Roblox ahk_exe ApplicationFrameHost.exe") {
        ActivateRoblox()
        style := WinGetStyle("Roblox")
        if !(style & 0xC00000) {
            SendEvent("{F11}")
            Sleep(500)
        }
        WinRestore "Roblox"
        ActivateRoblox()
    }
}

CloseRoblox() {
	
	if (hwnd := GetRobloxHWND())
	{
        getRobloxPos(,,,&windowHeight)
		GetRobloxClientPos(hwnd)
		if (windowHeight >= 500) 
		{
			ActivateRoblox()
			PrevKeyDelay := A_KeyDelay
			SetKeyDelay 500
			send "{" SC_Esc "}{" SC_L "}{" SC_Enter "}"
			SetKeyDelay PrevKeyDelay
		}
		try WinClose "Roblox"
		Sleep 500
		try WinClose "Roblox"
		Sleep 4500 
	}
	
	for p in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_Process WHERE Name LIKE '%Roblox%' OR CommandLine LIKE '%ROBLOXCORPORATION%'")
		ProcessClose p.ProcessID
}

resetCharacter() {
	if (hwnd := GetRobloxHWND())
	{
        getRobloxPos(,,,&windowHeight)
		GetRobloxClientPos(hwnd)
		if (windowHeight >= 500) 
		{
            LogToConsole("Resetting character...")
			ActivateRoblox()
			send "{" SC_Esc "}"
            Sleep 550 
            send "{" SC_R "}"
            Sleep 550 
            send "{" SC_Enter "}"
		}
	}
}



WaitForLobbyLoad() {
    global difficulty

    SetTimer(CheckPopups, 0)

    startTime := A_TickCount
    if (difficulty != "Pizza Party" && difficulty != "Badlands II" && difficulty != "Polluted Wasteland II") {
        Sleep(6000)
        Loop {
            if (A_TickCount - startTime > 60000) {
                CloseRoblox()
                SafeReload()
            }
            getRobloxPos(,,&w,&h)

            res := AdvancedImageSearch("Resources/Ready.png", Round(w * 0.25), Round(h * 0.66), Round(w * 0.5), Round(h * 0.34), 0.6, 1.7)
            if (res.status = "success" && res.score >= 0.7) {
                break
            }
            Sleep(100)
        }
        SelectMap(res.x, res.y)
    }
}

JoinGame() {
    global SendCurrenciesEnabled, WebhookEnabled, difficulty, CollectPlaytimeRewards, ScrollDownForMap, ScrollDownAmount, ScrollDelay
    getRobloxPos(,, &w, &h)

    startTime := A_TickCount
    Loop {
        if (A_TickCount - startTime > 80000) { 
            SafeReload()
            break
        }

        x1 := Round(w * 0.25)
        y1 := Round(h * 0.66)
        x2 := Round(w * 0.75)
        y2 := Round(h * 0.34)
        
        res := AdvancedImageSearch("Resources\Play.png", x1, y1, x2, y2)
        if (res.status == "success" && res.score > 0.65) {
            ActivateRoblox()
            if (CollectPlaytimeRewards = "1" || CollectPlaytimeRewards = 1) {
                claimPlaytimeRewards()
                ; Re-detect Play.png after rewards claim to ensure fresh coordinates
                getRobloxPos(,, &w, &h)
                x1 := Round(w * 0.25)
                y1 := Round(h * 0.66)
                x2 := Round(w * 0.75)
                y2 := Round(h * 0.34)
                resFresh := AdvancedImageSearch("Resources\Play.png", x1, y1, x2, y2)
                if (resFresh.status == "success" && resFresh.score > 0.65) {
                    res := resFresh
                }
            }
            
            LowerGraphics()
            Sleep(50)

            LogToConsole("Joining " difficulty "...", true, false)
            
            Click(res.x, res.y)
            break
        }
        Sleep(100)
    }
    Sleep(500)

    startTime := A_TickCount
    modeImg := ""

    if (difficulty = "Pizza Party" || difficulty = "Badlands II" || difficulty = "Polluted Wasteland II") {
        modeImg := "SpecialMode.png"
    }

    if modeImg != "" {
        getRobloxPos(,, &w, &h)
        lastPlayClick := 0
        Loop {
            if (A_TickCount - startTime > 45000) {
                LogToConsole("Timed out waiting for special mode, reloading...", true, false)
                SafeReload()
                break
            }

            if (A_TickCount - startTime > 15000 && A_TickCount - lastPlayClick > 8000) {
                lastPlayClick := A_TickCount
                resPlay := AdvancedImageSearch("Resources\Play.png", x1, y1, x2, y2)
                if (resPlay.status == "success" && resPlay.score > 0.65) {
                    Click(resPlay.x, resPlay.y)
                    Sleep(500)
                }
            }

            res := AdvancedImageSearch("Resources/" modeImg, 0, 0, w, h)
            if (res.status = "success" && res.score >= 0.67) {
                Click(res.x, res.y)
                break 
            }
            Sleep(100)
        }
        Sleep(300)
    }

    ; Difficulty selection
    getRobloxPos(,, &w, &h)
    diffImg := "Resources/" difficulty ".png"
    scrollAmt := 5
    try scrollAmt := Min(Max(Integer(ScrollDownAmount), 5), 20)
    delayMs := 1000
    try delayMs := Max(Integer(ScrollDelay), 0)

    ; Perform x (ScrollDelay wait for window to open) + y (ScrollDownAmount wheel down)
    if (ScrollDownForMap) {
        MouseMove(Round(w * 0.5), Round(h * 0.5))
        Sleep(delayMs) ; x: Wait for game mode window to appear (for potato PCs)
        Send("{WheelDown " scrollAmt "}") ; y: Scroll down by configured amount
        Sleep(500) ; Wait for scroll motion to settle
    } else {
        Sleep(delayMs) ; x: Wait for game mode window to appear
    }

    ; Only after the above actions (x wait + y scroll) are completely finished, search for difficulty
    startTime := A_TickCount
    lastRetry := 0
    Loop {
        getRobloxPos(,, &w, &h)
        if (A_TickCount - startTime > 45000) {
            LogToConsole("Timed out waiting for difficulty " difficulty ", reloading...", true, false)
            SafeReload()
            break
        }

        res := AdvancedImageSearch(diffImg, 0, 0, w, h)
        if (res.status = "success" && res.score >= 0.7) {
            Click(res.x, res.y)
            break 
        }

        ; Periodic recovery every 8 seconds if difficulty card is not appearing
        if (A_TickCount - startTime > 8000 && A_TickCount - lastRetry > 8000) {
            lastRetry := A_TickCount
            ; Check if Play button is still visible (Play click didn't register or menu closed)
            resPlay := AdvancedImageSearch("Resources\Play.png", x1, y1, x2, y2)
            if (resPlay.status == "success" && resPlay.score > 0.65) {
                Click(resPlay.x, resPlay.y)
                Sleep(delayMs)
                if (ScrollDownForMap) {
                    MouseMove(Round(w * 0.5), Round(h * 0.5))
                    Send("{WheelDown " scrollAmt "}")
                    Sleep(500)
                }
            } else {
                ; Try adjusting scroll in case list overshot or didn't scroll
                MouseMove(Round(w * 0.5), Round(h * 0.5))
                if (ScrollDownForMap) {
                    Send("{WheelUp 4}")
                } else {
                    Send("{WheelDown 5}")
                }
                Sleep(500)
            }
        }
        Sleep(100)
    }
    Sleep(300)

    startTime := A_TickCount
    Loop {
        getRobloxPos(,, &w, &h)
        if (A_TickCount - startTime > 40000) { 
            LogToConsole("Timed out waiting for Solo button, reloading...", true, false)
            SafeReload()
            break
        }
        res := AdvancedImageSearch("Resources/Solo.png", 0, Round(h * 0.2), Round(w * 0.7), Round(h * 0.55))
        if (res.status = "success" && res.score >= 0.7) {
            Click(res.x, res.y)
            break 
        }
        Sleep(100)
    }
    WaitForLobbyLoad()
}

SelectMap(readyX := ScaleX(963), readyY := ScaleY(838)) {
    global gamemap, difficulty, modifiers, CheckTheMap, LegacyMode

    getRobloxPos(,,&w,&h)
    readyX := Round(w*0.5)

    LogToConsole("Selecting map: " gamemap, true, false)
    Sleep(100)
    closeChat()

    if (difficulty = "Hardcore" || difficulty = "Voidcore") {
        If (!LegacyMode) {
            image := A_WorkingDir "/Resources/map_selection.png"

            foundObject := false

            Loop 3 {
                getRobloxPos(&x, &y, &w, &h)
                res := AdvancedImageSearch(image, 0,0,Round(w/2),h)
                if (res.status == "success" && res.score >= 0.51) { 
                    foundObject := true
                    break 
                }
                Sleep(500)
            }

            if (!foundObject) {
                LogToConsole("Wrong camera position!")
                SendEvent("{Left down}")
                Sleep(1500) 
                SendEvent("{Left up}")
                Sleep(50)
            }
        }
    } else {
        ActivateRoblox()
        resetCharacter()
        Sleep(7500)
        AlignCamera(false, false)
    }
    
    if (difficulty = "Hardcore" || difficulty = "Voidcore") {
        attempts := 0

        Sleep(300)
        Send("{WheelDown}")

        Loop {
            Sleep(200)
            ActivateRoblox()
            Sleep(600)
            SendEvent("{sc011 down}")  
            Sleep(3550)
            SendEvent("{sc011 up}")
            Sleep(300)

            LogToConsole("Trying to find: " gamemap ". Please wait..")

            getRobloxPos(,,&w,&h)
            FoundSlot := 0
            regions := [[0, 0, Floor(w * 0.3307), Floor(h * 0.6)],
            [Floor(w * 0.3307), 0, Floor(w * 0.1729), Floor(h * 0.6)],
            [Floor(w * 0.5036), 0, Floor(w * 0.1729), Floor(h * 0.6)],
            [Floor(w * 0.6765), 0, w - Floor(w * 0.6765), Floor(h * 0.6)]]

            langCode := "en-US"
            for availableLang in StrSplit(OCR.GetAvailableLanguages(), "`n", "`r") {
                if (availableLang != "" && SubStr(availableLang, 1, 2) = "en") {
                    langCode := availableLang
                    break
                }
            }

            Loop 4 {
                r := regions[A_Index]
                pBmp := Gdip_BitmapFromScreen(r[1] "|" r[2] "|" r[3] "|" r[4])
                result := OCR.FromBitmap(pBmp, {lang:langCode, scale:1.5, grayscale: 1}).Text
                Gdip_DisposeImage(pBmp)
                if RegExMatch(result, "i)\b" . gamemap . "\b") {
                    FoundSlot := A_Index
                    break
                }
            }
            
            if (attempts >= 5) {
                LogToConsole("Map is not found after 5 attempts! Reloading...", true)
                SafeReload()
            }

            if (FoundSlot = 0) {
                LogToConsole("Map is not found! Resetting...", true, false)
                resetCharacter()
                Sleep(8000)
                attempts++
                SendEvent("{Left down}")
                Sleep(1500) 
                SendEvent("{Left up}")
                Sleep(50)
                continue
            } else {
                LogToConsole(gamemap " found in slot " FoundSlot,true,false)
                break
            }
        }

        Sleep(300)
        ActivateRoblox()
        Sleep(100)

        SendEvent("{sc011 down}")  
        HyperSleep(400)
        SendEvent("{sc011 up}")
        Sleep(200)

        if (FoundSlot = 1) { 
            SendEvent("{sc01e down}")
            Sleep(1400)
            SendEvent("{sc01e up}")
            Sleep(600) 
        } else if (FoundSlot = 2) { 
            SendEvent("{sc01e down}")
            Sleep(500)
            SendEvent("{sc01e up}")
            Sleep(600) 
        } else if (FoundSlot = 3) { 
            SendEvent("{sc020 down}")
            Sleep(500)
            SendEvent("{sc020 up}")
            Sleep(600) 
        } else if (FoundSlot = 4) { 
            SendEvent("{sc020 down}")
            Sleep(1400)
            SendEvent("{sc020 up}")
            Sleep(600) 
        }

        if (modifiers != "")
            ApplyModifiers()

        SendEvent("{sc012 down}")  
        Sleep(1000)
        SendEvent("{sc012 up}")
        Sleep(100)
    } else {
        ActivateRoblox()
        Sleep(150)
        SendEvent("{sc01f down}") 
        Sleep(1900)
        SendEvent("{sc01f up}")
        Sleep(700)
        SendEvent("{sc01e down}") 
        Sleep(1800)
        SendEvent("{sc01e up}")
        Sleep(700)

        Loop 3 {
            e_pr := AdvancedImageSearch("Resources\e_prompt.png", 0, 0, w, h,1,1)

            if (e_pr.score >= 0.75) {
                break
            } else {
                Sleep(150)
            }
        }

        if !(e_pr.score >= 0.75) {
            LogToConsole("The macro can't see the E prompt (" e_pr.score "), retrying again... ", true) 
            SelectMap(readyX, readyY)
            return
        }

        SendEvent("{sc012 down}") 
        Sleep(1000)
        SendEvent("{sc012 up}")
        Sleep(500)

        foundsearchbar := false
        getRobloxPos(&x, &y, &w, &h)
        Loop 2 {
            if (!LegacyMode) {
                res := AdvancedImageSearch("Resources/searchbar.png", Round(w*0.1),0,Round(w*0.6),h,0.5,1.5)

                if (res.status = "success" && res.score >= 0.6)  { 
                    Click(res.x, res.y)
                    foundsearchbar := true 
                    break
                } 
            } else {
                res := {x: ScaleX(810), y: ScaleY(218)}
                click(Res.x, res.y)
                foundsearchbar := true 
                break
            }

            Sleep(500)
        }

        if (!foundsearchbar) {
            LogToConsole("Can not found the search bar in the override map menu! Reloading..", true)
            SafeReload()
            return 
        }        

        Sleep(100)
        SendText(gamemap)
        Loop {
            Sleep(300)
            if (InArray(SpecialMaps, gamemap)) {
                SelectionICON := AdvancedImageSearch("Resources/Maps/" gamemap "_Selection.png", Round(w*0.1),0,Round(w*0.7),h,0.5,1.5)
            
                if (SelectionICON.score >= 0.65)  { 
                    Click(SelectionICON.x, SelectionICON.y)
                } else {
                    Click(res.x - ScaleX(90), res.y + 80)
                }
            } else {
                Click(res.x - ScaleX(90), res.y + 80)
            }
            Sleep(400)

            changedMap := false
            alrinRotation := false
            Loop 2 {
                if PixelSearch(&gx, &gy, Round(w*0.2), Round(h*0.24), Round(w*0.7), Round(h*0.3), 0x00EC00, 3) {
                    LogToConsole("Successfully changed the map to " gamemap,true,false)
                    changedMap := true
                    break
                }

                Sleep(200)
            }

            if (changedMap) {
                break
            }

            if (ReadMessage(["already", "current", "rotation"])) {
                LogToConsole(gamemap " is already in the current rotation. Clicking veto..", true)
                resVeto := AdvancedImageSearch("Resources\Veto.png", 0, 0, w, h,0.5,1.5)
                if (resVeto.status == "success" && resVeto.score > 0.65) {
                    MouseMove(resVeto.x, resVeto.y)
                    Sleep(30)
                    MouseClick
                } else {
                    MouseMove(ScaleX(1152), ScaleY(834))
                    Sleep(30)
                    MouseClick
                }
                Sleep(300)
                Send("{" SC_E " down}")
                Sleep(760)
                Send("{" SC_E " up}")

                alrinRotation := false
                Sleep(400)
                continue
            }

            if (!changedMap) {
                LogToConsole("Failed to change the map to " gamemap, true)
                SafeReload()
            } else {
                break
            }
        }

        if (modifiers != "")
            ApplyModifiers()

        Sleep(200)
        ActivateRoblox()
        Sleep(100)
        SendEvent("{sc020 down}") 
        Sleep(1800)
        SendEvent("{sc020 up}")
        Sleep(200)
        SendEvent("{sc01f down}") 
        Sleep(1680)
        SendEvent("{sc01f up}")
        Sleep(300)
        SendEvent("{sc020 down}") 
        Sleep(1500)
        SendEvent("{sc020 up}")
        Sleep(600)
        Loop 3 {
            e_pr := AdvancedImageSearch("Resources\e_prompt.png", 0, 0, w, h,0.6,1.5)

            if (e_pr.score >= 0.65) {
                break
            } else {
                Sleep(150)
            }
        }

        if !(e_pr.score >= 0.7) {
            LogToConsole("The macro can't see the E prompt (" e_pr.score "), moving slightly to the left... ", true) 
            SendEvent("{sc01e down}") 
            Sleep 300
            SendEvent("{sc01e up}") 
            Loop 3 {
                e_pr := AdvancedImageSearch("Resources\e_prompt.png", 0, 0, w, h,0.6,1.5)

                if (e_pr.score >= 0.65) {
                    break
                } else {
                    Sleep(150)
                }
            }
            if !(e_pr.score >= 0.7) {
                LogToConsole("The macro can't see the E prompt (" e_pr.score "), reloading... ", true) 
                SafeReload()
            }
        }

        SendEvent("{sc012 down}") 
        Sleep(800)
        SendEvent("{sc012 up}")
    }
    Sleep(100)

    Click(readyX, readyY)
    waitReady()
}

CheckTheMapF() {
    global gamemap, CheckTheMap, modifiers

    modifiers_str := (modifiers is Array) ? Join(modifiers) : String(modifiers)

    if (FileExist("Resources\Maps\" . gamemap . ".png") && CheckTheMap = 1 && !InArray(SpecialMaps, gamemap) && !RegExMatch(modifiers_str, "i)fog"))
    {
        AlignCamera(false, false, false)

        LogToConsole("Checking the map... (Make sure you have the lowest graphics)")


        getRobloxPos(,,&w,&h)
        FoundMap := false
        Loop 2 {
            res := AdvancedImageSearch("Resources\Maps\" gamemap ".png", 0, 0, w, h)

            if (res.score > 0.62) {
                FoundMap := true
                break
            }
            
            Sleep(1250)
        }

        if (!FoundMap) {
            LogToConsole("Can't detect the map! Reloading script...", true)
            Sleep 300
            SafeReload()
        }
    }

    if (InArray(SpecialMaps, gamemap)) {
        functionName := gamemap . "Path"

        %functionName%() 
    }
}

ApplyModifiers() {
    global modifiers
    LogToConsole("Setting up modifiers: " modifiers)
    Click(56, ScaleY(930))

    Sleep(300)

    searchX := ScaleX(951)
    searchY := ScaleY(262)

    foundsearchbar := false
    getRobloxPos(&x, &y, &w, &h)
    Loop 2 {
        res := AdvancedImageSearch("Resources/searchbar_modifiers.png", Round(w*0.1),0,Round(w*0.7),Round(h*0.6), 0.5, 1.5)
        
        if (res.status = "success" && res.score >= 0.7)  { 
            searchX := res.x
            searchY := res.y
            foundsearchbar := true 
            break
          } 
        Sleep(500)
    }

    Loop Parse, modifiers, "," {
        modifier := Trim(A_LoopField)
        if (modifier = "") {
            continue
        }
        Click(searchX, searchY)
        Sleep(100)
        SendText(modifier)
        Sleep(100)
        Click(Round(w/2), searchY+ScaleY(80))
        Sleep(50)
        LogToConsole("Modifier added: " modifier)
    }
    Sleep(100)
    Click(ScaleX(1122), ScaleY(853))
    LogToConsole("All modifiers configured")
}

ClickReady() {
    global readyX, readyY

    Loop {
        MouseMove(readyX, readyY)
        Sleep 50
        MouseClick()
        Sleep 200

        getRobloxPos(,,&w,&h)
        readyc := AdvancedImageSearch("Resources/ready_gs.png",Round(w * 0.25), Round(h * 0.08), Round(w * 0.5), Round(h * 0.34))
        if !(readyc.score > 0.7) {
            LogToConsole("Successfully started the match by clicking the ready button.")
            break
        } else {
            LogToConsole("Failed to press the ready button, retrying...")
            if PixelSearch(&fx, &fy, Round(w*0.4),Round(h*0.05), Round(w*0.7), Round(h*0.35), 0x2BEB00, 2) {
                readyX := fx
                readyY := fy
                continue
            } else {
                break
            }
        }
    }
}

waitReady() {
    global readyX, readyY
    start := A_TickCount
    getRobloxPos(&x, &y, &w, &h)
    KillSubmacros()
    Loop {
        wt := 40000
        If (A_TickCount - start > wt) {
            LogToConsole("The ready button hasn't appeared for too long! Reloading the script...", true)
            CloseRoblox()
            SafeReload()
        }
        if PixelSearch(&fx, &fy, Round(w*0.4),Round(h*0.05), Round(w*0.7), Round(h*0.35), 0x2BEB00, 2) {
            readyX := fx
            readyY := fy
            break
        } else {
            Sleep(50)
        }
    }
    startWatchdog()
}

activateTimescale() {
    global UseTimeScale, TimeScaleMode, TimeScaleMultiplier, difficulty, SettingsFile, AutorunStartTime, TimescaleActive

    getRobloxPos(&x, &y, &w, &h)
    if (UseTimeScale && difficulty != "Pizza Party" && difficulty != "Badlands II" && difficulty != "Polluted Wasteland II") { 
        LogToConsole("Applying timescale: " TimeScaleMode ". Please, enable UI Navigation Toggle.")
        Click(Round(w*0.5), Round(h*0.5))

        Send("#")
        Send("{sc02B}")
        Sleep 50
        Loop 10 {
            Send("{Down}")
            Sleep 10
        }
        Loop 20 {
            Send("{Left}")
            Sleep 10
        }
        Send("{Right}")
        Sleep 10
        Send("{Enter}")

        Sleep(250)

        res := AdvancedImageSearch("Resources/GetMore.png", Round(w * 0.25), Round(h * 0.45), Round(w * 0.50), Round(h * 0.55))
        if (res.status = "success" && res.score >= 0.67) {
            Click(res.x, res.y+55)
            LogToConsole("Failed to activate timescale! You are out of tickets.", true, false)
            timescaleMention := (PingOnTimescale = 1) ? GetDiscordMention(WebhookUserID) : ""
            SendToWebhookInstant("⚠️ **Timescale Tickets Depleted!**`nFailed to activate timescale because you are out of tickets.", 16724526, true, timescaleMention)
            UseTimeScale := false
            TimescaleActive := false
        } else {
            res := AdvancedImageSearch("Resources/confirm.png", Round(w * 0.25), Round(h * 0.45), Round(w * 0.50), Round(h * 0.55))
            if (res.status = "success" && res.score >= 0.67) {
                Click(res.x, res.y)
            } else {
                LogToConsole("failed to activate timescale. the macro can't see the confirm/get more button... (" res.score ")", true)
                SafeReload()
            }

            timescales := IniRead(StateFile, "State", "Timescale", 0)
            timescales := timescales+1
            LogToConsole("-1 Timescale ticket. Total Timescale Tickets Used: " timescales)
            SendToWebhookInstant("[" runtime := FormatRuntime(AutorunStartTime) "] -1 Timescale ticket. `n-# Total Timescale Tickets Used: " . timescales, 12370112, false)
            IniWrite(timescales, StateFile, "State", "Timescale")
            TimescaleActive := true

            Sleep(250)
            if (TimeScaleMode = "2x") {
                Loop 2 {
                    Sleep(20)
                    Send("{Enter}")
                }
            } else if (TimeScaleMode = "1.5x") {
                Sleep(20)
                Send("{Enter}")
            }
        }

        Send("{sc02B}")
        Send("#")
    }
}

AlignCamera(move := true, skipZoom := false, log := true) {
    global MoveEnabled, MoveDirection, MoveDuration, IsRestarting, MouseDelay
    if (IsRestarting)
        return
    if (log) {
        LogToConsole("Aligning camera")
    }
    closeChat()

    getRobloxPos(&rx, &ry, &rw, &rh)

    MouseMove(rw/2, rh/2, 0)
    Click("Right Down")
    Sleep(50)
    MouseMove(0, rh, 3+MouseDelay, "R")
    Sleep(10)
    Click("Right Up")
    If (!skipZoom) {
        Sleep(200)
        SendEvent("{o down}")
        HyperSleep(750)
        SendEvent("{o up}")
        Sleep(200)
    }
    if (MoveEnabled && !IsRestarting && move) {
        Sleep(200)
        SendEvent("{" MoveDirection " down}")
        HyperSleep(MoveDuration)
        SendEvent("{" MoveDirection " up}")
    }
}

getSlots() {
    static cachedSlotsState := ""
    
    if (cachedSlotsState != "") {
        return cachedSlotsState
    }
    
    numbers := Map(
        1, A_WorkingDir "\Resources\1.png",
        2, A_WorkingDir "\Resources\2.png",
        3, A_WorkingDir "\Resources\3.png",
        4, A_WorkingDir "\Resources\4.png",
        5, A_WorkingDir "\Resources\5.png"
    )
    
    Ys := ScaleY(960)
    x1 := ScaleX(800)
    x2 := ScaleX(880)
    x3 := ScaleX(960)
    x4 := ScaleX(1040)
    x5 := ScaleX(1120)

    currentSlotsState := Map(
        1, [x1, Ys], 
        2, [x2, Ys], 
        3, [x3, Ys], 
        4, [x4, Ys], 
        5, [x5, Ys]
    )

    getRobloxPos(&x, &y, &w, &h)
    offsetY := Integer(h * 0.8)
    endY := Integer(h * 0.17)
    endX := Integer(w* 0.75)

    startX := Integer(w*0.15)
    
    for digit, Image in numbers {
        if (!Image)
            continue
            
        Variation := 10 

        Result := AdvancedImageSearch(Image, startX, offsetY, endX, endY, 0.75, 2)
        
        if (Result.status == "success" && Result.score >= 0.84) {
            startX := Result.x+ScaleX(70)
            endY := Result.y+ScaleY(40)-offsetY
            endX := Integer(w* 0.1)

            currentSlotsState[digit] := [Result.x+ScaleX(15), Result.y+ScaleY(20)]
        }
    }

    cachedSlotsState := currentSlotsState
    return cachedSlotsState
}


SpawnTower(X, Y, slotNumber, towerID) {
    global Towers, LastOpenedTowerID, CancelPlacementKey, canUseAbility, UseNumbersForHotbar, Slots
    LogToConsole("Placing tower " towerID " (slot " slotNumber ") at x:" X " y:" Y "...")

    X := sX(X, StrategyWidth)
    Y := sY(Y, StrategyHeight)
    
    getRobloxPos(,,,&h)
    TowerY := Y
    if (Y < h * 0.5) {
        TowerY := Y - ScaleY(5)
    }

    placeAttempts := 0
    attemptMultiplier := 1
    startTime := A_TickCount
    canUseAbility := false

    Loop {
        placeAttempts++

        if (A_TickCount - startTime > 300000) {
            LogToConsole("Tower placement timed out (5+ minutes). Reloading the macro...")
            SafeReload()
            return
        }

        ActivateRoblox()
        
        if UseNumbersForHotbar {
            Send("{" slotNumber "}")
        } else {
            Click(Slots[slotNumber])
        }

        Sleep((PotatoMode = 1) ? 100 : 30)
        
        MouseMove(X, Y, A_DefaultMouseSpeed)
        Sleep((PotatoMode = 1) ? 100 : 40)
        MouseClick()
        Sleep(100)
        SendEvent("{" CancelPlacementKey "}")

        placedSuccessfully := waitForTowerUI(&resV2)

        if (placedSuccessfully) {
            Towers[towerID] := {x: X, y: TowerY, slot: Integer(slotNumber), level: 0, path: 0, pathLevel: 0, target: "First Enemy"}
            LogToConsole("Tower " towerID " placed successfully")
            DashboardActivity.Succeeded("spawntower", towerID)
            LastOpenedTowerID := towerID
            break
        } else {
            LogToConsole("Tower " towerID " placement failed, retrying...")
            if (placeAttempts = 1) {
                continue
            }

            getRobloxPos(,,&w,&h)
            x1 := Round(w * 0.2)
            y1 := Round(h * 0.18)
            x2 := Round(w * 0.7)
            y2 := Round(h * 0.3)
            if (ImageSearch(&fx,&fy,x1,y1,x2,y2, "*Trans000000 *50 " A_WorkingDir "/Resources/cannot_place_here.png") || ReadMessage(["cannot", "here", "hereg", "herd", "her", "here!", "cann", "cannd", "he", "h", "hed"],,["need", "more", "to"],"\$|\d")) {
                MouseClick()

                placedSuccessfully := waitForTowerUI(&resV2)
                if (placedSuccessfully) {
                    Towers[towerID] := {x: X, y: TowerY, slot: Integer(slotNumber), level: 0, path: 0, pathLevel: 0, target: "First Enemy"}
                    LogToConsole("Tower " towerID " placed successfully")
            DashboardActivity.Succeeded("spawntower", towerID)
                    LastOpenedTowerID := towerID
                    break
                }

                offsets := [[0, -5 * attemptMultiplier], [5 * attemptMultiplier, 0], [0, 5 * attemptMultiplier], [-5 * attemptMultiplier, 0]]
                placedSuccessfully := false

                ActivateRoblox()
        
                Send("{" slotNumber "}")
                Sleep(30)

                LogToConsole("Cannot place here! Trying to place tower in different spots...")
                
                for index, offset in offsets {
                    if (A_TickCount - startTime > 300000) {
                        LogToConsole("Tower placement timed out during offset retry. Executing safereload()...")
                        safeReload()
                        return
                    }

                    newX := X + offset[1]
                    newY := Y + offset[2]
                    
                    MouseMove(newX, newY, A_DefaultMouseSpeed)
                    Sleep((PotatoMode = 1) ? 100 : 40)
                    MouseClick()
                    Sleep(100)

                    placedSuccessfully := waitForTowerUI(&resV2)
                    if (placedSuccessfully) {
                        Towers[towerID] := {x: newX, y: newY, slot: Integer(slotNumber), level: 0, path: 0, pathLevel: 0, target: "First Enemy"}
                        LogToConsole("Tower " towerID " placed successfully")
            DashboardActivity.Succeeded("spawntower", towerID)
                        LastOpenedTowerID := towerID
                        break 2
                    }
                }
                
                if (!placedSuccessfully) {
                    SendEvent("{" CancelPlacementKey "}")
                    attemptMultiplier := attemptMultiplier * 2
                }
            } 
        }
    }
    canUseAbility := true
}

SellTower(towerID) {
    global Towers, unfocusX, unfocusY

    if (!Towers.Has(towerID)) {
        LogToConsole("Tower " towerID " not found for selling!")
        return false
    }

    LogToConsole("Selling tower " towerID "...")
    targetX := Towers[towerID].x
    targetY := Towers[towerID].y
    Click(targetX, targetY)
    Sleep(400)

    attempts := 0
    Loop {
        menuFound := waitForTowerUI()
        
        if (!menuFound) {
            attempts++
            if (attempts > 15) {
                LogToConsole("Tower " towerID " menu not found for selling")
                return false
            }
            variation := Random(-10, 10)
            Click(Towers[towerID].x, Towers[towerID].y + variation)
            Sleep(400)
            continue
        }
        getRobloxPos(&rx, &ry, &w, &h)
        X1_v2 := 0
        Y1_v2 := Round(h/2)
        W_v2 := Round(w * 0.3) - X1_v2
        H_v2 := Round(h) - Y1_v2

        resV2 := AdvancedImageSearch("Resources\TowerUI\Variant2.png", X1_v2, Y1_v2, W_v2, H_v2, ,,0.05)

        if (resV2.score > 0.55) {
            Click(resV2.x, resV2.y)
        }

        LogToConsole("Tower " towerID " sold successfully")
        if (Towers[towerID].hwnd) {
            WinClose("ahk_id " Towers[towerID].hwnd)
        }
        Towers.Delete(towerID)
        DashboardActivity.Succeeded("selltower", towerID)
        return true
    }
    return false
}

UpgradeTower(towerID, skipOpen := false, totalUpgrades := 1, path := 0, pathLevel := 0) {
    global Towers, unfocusX, unfocusY, LastOpenedTowerID, needtocheckTowerUI, UpgradeDelay
    global PotatoMode, Recording, RecordedSteps, Commander, canUseAbility

    static resV2 := 0
    static resV1 := 0

    needtocheckTowerUI := true

    if (!Towers.Has(towerID)) {
        LogToConsole("Tower " towerID " not found!")
        return false
    }

    targetX := Towers[towerID].x
    targetY := Towers[towerID].y

    if (!skipOpen && LastOpenedTowerID != towerID) {
        canUseAbility := false
        Click(targetX, targetY)
        Sleep 250
        canUseAbility := true
    }

    LastOpenedTowerID := towerID
    upgradesDone := 0
    attempts := 0

    upgTime := A_TickCount

    Sleep(20)

    Loop {
        openedSuccessfully := false
        StartTime := A_TickCount

        if (PotatoMode) {
            if (A_TickCount - upgTime > 600) {
                needtocheckTowerUI := true
                upgTime := A_TickCount
            }
        } else {
            needtocheckTowerUI := true
        }

        if (needtocheckTowerUI || (!IsObject(ResV2) && !IsObject(ResV1))) {
            openedSuccessfully := waitForTowerUI(&ResV2, &ResV1)

            if (!openedSuccessfully && canBeUpgraded) {
                attempts++
                if (attempts > 30) {
                    LogToConsole("Tower " towerID " menu not found after 30 attempts, reloading...", true)
                    SafeReload()
                }
                variation := Random(-4, 4)
                Click(targetX, targetY + ScaleY(variation))
                Sleep(100)
                continue
            } else {
                attempts := 0
                needtocheckTowerUI := false
            }
        }
        
        doResV2 := (IsObject(resV2) && resV2.HasProp("score") && resV2.score > 0.55)

        if (doResV2) {
            UpgradeX := resV2.x+ScaleX(50)
            UpgradeY := resV2.y-ScaleY(220)

            upgAX := resV2.x + ScaleX(20)
            upgAY := resV2.y - ScaleY(240)
            upgAW := ScaleX(80)
            upgAH := ScaleY(70)
        } else {
            if (!IsObject(ResV1)) {
                needtocheckTowerUI := true
                Sleep(50)
                continue
            }
    
            UpgradeX := resV1.x-ScaleX(164)
            UpgradeY := resV1.y+ScaleY(383)

            upgAX := resV1.x - ScaleX(194)
            upgAY := resV1.y + ScaleY(363)
            upgAW := ScaleX(80)
            upgAH := ScaleY(70)
        }
        
        nextLevel := Towers[towerID].level + 1

        region := [upgAX, upgAY, upgAW, upgAH]

        if (path != 0 && nextLevel > pathLevel && pathLevel != 0) {
            if (path = 2) { 
                if (doResV2) {
                    region := [resV2.x+ScaleX(20), resV2.y-ScaleY(95), ScaleX(80), ScaleY(70)]
                    UpgradeY := resV2.y-ScaleY(120)
                } else {
                    region := [resV1.x - ScaleX(194), resV1.y + ScaleY(508), ScaleX(80), ScaleY(70)]
                    UpgradeY := resV1.y + ScaleY(483)
                }
            }
        } 

        XA := region[1]
        YA := region[2]
        WA := region[3]
        HA := region[4]

        X2 := XA + WA
        Y2 := YA + HA

        searchArea := XA "|" YA "|" X2 "|" Y2

        try {
            isGreen := PixelSearch(&gx, &gy, XA, YA, X2, Y2, 0x206235, 12)
        } catch Error {
            isGreen := false
        }
        if (isGreen && canBeUpgraded) {
            canUseAbility := false
            if (UseHForUpgrade) {
                if (path != 0 && nextLevel > pathLevel && pathLevel != 0) {
                    if (path = 1) { 
                        SendEvent("{" UpgradeTowerGKey "}")
                    } else if (path = 2) {
                    SendEvent("{" UpgradeTowerGBKey "}")
                    } 
                } else {
                    SendEvent("{" UpgradeTowerGKey "}")
                }
            } else {
                Click(UpgradeX, UpgradeY)
            }

            Sleep(UpgradeDelay)

            Towers[towerID].level += 1
            upgradesDone++
            LogToConsole("Tower " towerID " upgraded to level " Towers[towerID].level " (" upgradesDone "/" totalUpgrades ")")
            DashboardActivity.Succeeded("upgradetower", towerID " · Level " Towers[towerID].level)
            UpdateTowerIndicator(towerID)

            if (Towers[towerID].level >= 2 && RegExMatch(towerID, "i)^Commander\d*$") && !Commander) {
                Commander := true
                if (Recording && !HasStep("Commander := true"))
                    RecordedSteps.Push("Commander := true")
            }

            canUseAbility := true

            if (upgradesDone >= totalUpgrades) 
                return true

            continue
        }
    }
}

isDisconnected() {
    w := A_ScreenWidth
    h := A_ScreenHeight
    
    getRobloxPos(,, &w, &h)
    ActivateRoblox()

    if (!w || !h || w <= 0 || h <= 0) {
        w := A_ScreenWidth
        h := A_ScreenHeight
    }

    oldMode := A_CoordModePixel
    CoordMode("Pixel", "Screen")
    
    try {
        if ImageSearch(&FoundX, &FoundY, 0, 0, w, h, "*26 " "Resources\Disconnected.png") {
            CoordMode("Pixel", oldMode)
            TryReconnect()
        } else if ImageSearch(&FoundX, &FoundY, 0, 0, w, h, "*26 " "Resources\disconnected2.png") {
            CoordMode("Pixel", oldMode)
            TryReconnect()
        }
    } catch Error as err {
        CoordMode("Pixel", oldMode)
    }
    
    CoordMode("Pixel", oldMode)
}

TryReconnect() {
    attempts := 0
    Loop {
        attempts++
        LogToConsole("Reconnecting... Attempt " attempts ".", true, false)
        KillSubmacros()
        CloseRoblox()
        if (RunRoblox(false) == false) {
            continue
        } else {
            LogToConsole("Reconnect successful after " attempts " attempts!", true, false)
            startWatchdog()
            break
        }
    }
}

CheckPopups(*) {
    static clickedNotNow := false

    getRobloxPos(,,&w,&h)

    res := AdvancedImageSearch("Resources/Claim.png", Round(w * 0.25), Round(h * 0.4), Round(w * 0.5), Round(h * 0.5))
    if (res.status = "success" && res.score >= 0.65) {
        LogToConsole("Claimed daily reward.")
        Click(res.x, res.y)
    }

    res := AdvancedImageSearch("Resources/cancel_rejoin.png", Round(w * 0.15), Round(h * 0.4), Round(w * 0.7), Round(h * 0.4))
    if (res.status = "success" && res.score >= 0.65) {
        Click(res.x, res.y)
    }

    if (!clickedNotNow) {
        res2 := AdvancedImageSearch("Resources/notnow.png", Round(w * 0.25), Round(h * 0.4), Round(w * 0.5), Round(h * 0.5))
        if (res2.status = "success" && res2.score >= 0.65) {
            clickedNotNow := true
            Click(res2.x, res2.y)
        }
    }
}

UseAbilities(*) {
    global ChainKey, BeatKey, CaravanKey, CancelPlacementKey, TimeScaleMultiplier, AutoSkip, AbilitySpam
    global autoChain, autoCaravan, autoDropTheBeat, Commander, unfocusX, unfocusY, canUseAbility
    global LastOpenedTowerID, Towers, TimescaleActive, needtocheckTowerUI
    static LastChainTime := 0, LastDropTime := 0, LastCaravanTime := 0

    try {
        if (!canUseAbility) {
            return
        }

        multiplier := 1
        if (TimescaleActive) {
            multiplier := TimescaleMultiplier
        } 

        caravanInterval := 26
        chainInterval := 14

        if (AbilitySpam = "ON") {
            caravanInterval := 20
            chainInterval := 10
        }

        if (AutoSkip = "ON") {
            res := AdvancedImageSearch("Resources/Skip.png", Round(A_ScreenWidth * 0.3), 0, Round(A_ScreenWidth * 0.7), Round(A_ScreenHeight * 0.35), 0.5, 1.5)
            if (res.status = "success" && res.score >= 0.65) {
                Sleep(200)
                res := AdvancedImageSearch("Resources/Skip.png", Round(A_ScreenWidth * 0.3), 0, Round(A_ScreenWidth * 0.7), Round(A_ScreenHeight * 0.35), 0.5, 1.5)
                if (res.status = "success" && res.score >= 0.65) {
                    SendEvent("{" CancelPlacementKey "}")
                    MouseGetPos(&cx, &cy)
                    Click(res.x, res.y)
                    Sleep(30)
                    MouseMove(cx, cy)
                    Sleep(20)
                    LogToConsole("skipped wave")
                }
            }
        }

        if (autoChain = "ON" && Commander && (A_TickCount - LastChainTime > chainInterval * 1000 / multiplier)) {
            canUseAbility := false
            canBeUpgraded := false
            if (LastOpenedTowerID != "" && LastOpenedTowerID != 0 && LastOpenedTowerID != "0") {
                try Click(ScaleX(unfocusX), ScaleY(unfocusY))
                Sleep(100)
            }
            LastChainTime := A_TickCount
            SendEvent("{" ChainKey "}")
            LogToConsole("Activated Call of Arms")
            canUseAbility := true
            if (LastOpenedTowerID != "" && LastOpenedTowerID != 0 && LastOpenedTowerID != "0" && Towers.Has(LastOpenedTowerID)) {
                try Click(Towers[LastOpenedTowerID].x, Towers[LastOpenedTowerID].y)
                Sleep 250
            }
            canBeUpgraded := true
            needtocheckTowerUI := true
        }

        if (autoCaravan = "ON" && (A_TickCount - LastCaravanTime > caravanInterval * 1000 / multiplier)) {

            foundCommander := false
            for name, towerID in Towers {
                if towerID.level >= 4 && RegExMatch(name, "i)^Commander\d*$") {
                    foundCommander := true
                    break
                }
            }

            if (!foundCommander) {
                return
            }

            canBeUpgraded := false
            
            canUseAbility := false
            SendEvent("{" CancelPlacementKey "}")
            if (LastOpenedTowerID != "" && LastOpenedTowerID != 0 && LastOpenedTowerID != "0") {
                try Click(ScaleX(unfocusX), ScaleY(unfocusY))
                Sleep(300)
            }
            LastCaravanTime := A_TickCount
            SendEvent("{" CaravanKey "}")
            LogToConsole("Activated Support Caravan")
            if (LastOpenedTowerID != "" && LastOpenedTowerID != 0 && LastOpenedTowerID != "0" && Towers.Has(LastOpenedTowerID)) {
                try Click(Towers[LastOpenedTowerID].x, Towers[LastOpenedTowerID].y)
                Sleep 400
            }
            canUseAbility := true
            canBeUpgraded := true
            needtocheckTowerUI := true
        }

        if (autoDropTheBeat = "ON" && Towers.Has("DJ") && Towers["DJ"].level >= 3 && (A_TickCount - LastDropTime > 28000 / multiplier)) {

            canBeUpgraded := false

            SendEvent("{" CancelPlacementKey "}")
            if (LastOpenedTowerID != "DJ" && LastOpenedTowerID != "" && LastOpenedTowerID != 0 && LastOpenedTowerID != "0") {
                try Click(ScaleX(unfocusX), ScaleY(unfocusY))
                Sleep(100)
            }

            Loop {
                LastDropTime := A_TickCount
                SendEvent("{" BeatKey "}")

                Sleep 350
                getRobloxPos(,,&w,&h)
                x1 := Round(w * 0.2)
                y1 := Round(h * 0.18)
                x2 := Round(w * 0.7)
                y2 := Round(h * 0.3)
                if (ImageSearch(&fx,&fy,x1,y1,x2,y2, "*Trans000000 *50 " A_WorkingDir "/Resources/stunned.png") || ReadMessage(["error", "that", "cannot", "cann", "activated", "while", "stunned"],,["need", "more", "to"],"\$|\d")) {
                    LogToConsole("Failed to use Drop the Beat! The tower is stunned! Retrying...")
                    Sleep 4400
                } else {    
                    LogToConsole("Successfully used Drop the Beat")
                    break
                }
            }

            if (LastOpenedTowerID != "" && LastOpenedTowerID != 0 && LastOpenedTowerID != "0" && LastOpenedTowerID != "DJ" && Towers.Has(LastOpenedTowerID)) {
                try Click(Towers[LastOpenedTowerID].x, Towers[LastOpenedTowerID].y)
                Sleep 250
            }
            canBeUpgraded := true
            canUseAbility := true
            needtocheckTowerUI := true
        }
    } catch {
    }
}

SetDJTrack(track) {
    global Towers, unfocusX, unfocusY, LastOpenedTowerID, UseTimeScale, TimeScaleMode
    if (!Towers.Has("DJ")) {
        LogToConsole("DJ tower not found!")
        return
    }
    LogToConsole("Setting DJ track to " track "...")
    canUseAbility := false
    needtocheckTowerUI := true
    
    cleanTrack := StrReplace(track, '"', '')
    cleanTrack := StrReplace(cleanTrack, "'", "")
    trackName  := Format("{:L}", cleanTrack)

    if (LastOpenedTowerID != "DJ") {
        Click(Towers["DJ"].x, Towers["DJ"].y)
        LastOpenedTowerID := "DJ"
    }

    Sleep(200)

    upgTime := A_TickCount

    Loop {
        getRobloxPos(&rx, &ry, &w, &h)
        startTime := A_TickCount

        openedSuccessfully := false
        StartTime := A_TickCount

        if (PotatoMode) {
            if (A_TickCount - upgTime > 600) {
                needtocheckTowerUI := true
                upgTime := A_TickCount
            }
        } else {
            needtocheckTowerUI := true
        }

        if (needtocheckTowerUI) {
            openedSuccessfully := waitForTowerUI(&resv2, &resv1)

            if (!openedSuccessfully) {
                variation := Random(-10, 10)
                Click(Towers["DJ"].x, Towers["DJ"].y + ScaleY(variation))
                Sleep(400)
                continue
            }
        }

        DJTrack := resV2 := AdvancedImageSearch("Resources\" trackName ".png", 0, 0, w, h, 0.5, 1.5, 0.05)
        if (DJTrack.score > 0.6) {
            MouseGetPos(&cx, &cy)
            MouseClick(,DJTrack.x, DJTrack.y)

            Sleep 400
            getRobloxPos(,,&w,&h)
            x1 := Round(w * 0.2)
            y1 := Round(h * 0.18)
            x2 := Round(w * 0.7)
            y2 := Round(h * 0.3)
            If (ImageSearch(&fx,&fy,x1,y1,x2,y2, "*Trans000000 *50 " A_WorkingDir "/Resources/please_wait.png") || ReadMessage(["please", "wait"])) {
                LogToConsole("Need to wait before swithcing the track. Waiting 5 seconds...")
                Sleep(4500)
                continue
            } else {
                LogToConsole("Successfully changed DJ track to " track)
            }

            Sleep 10
            MouseMove(cx, cy)
        }
        break
    }
    canUseAbility := true
}

UpdateTowerIndicator(towerID) {
    global Towers, Recording, ShowIndicators, MainGui
    if (!Recording || !ShowIndicators || !Towers.Has(towerID))
        return
        
    Critical

    level := Towers[towerID].level
    MultiplePaths := (Towers[towerID].path != 0 && Towers[towerID].path != "")

    DetectHiddenWindows True
    
    oldMatchMode := A_TitleMatchMode
    SetTitleMatchMode 3 

    tTitle := "TowerIndicator_" towerID

    mainHwnd := 0
    try mainHwnd := MainGui.Hwnd

    If (Towers[towerID].HasProp("hwnd") && Towers[towerID].hwnd) {
        currentHwnd := Towers[towerID].hwnd
        if (currentHwnd != mainHwnd && WinExist("ahk_id " currentHwnd)) {
            try GuiFromHwnd(currentHwnd).Destroy()
        }
        Towers[towerID].hwnd := 0
    }

    if (oldHwnd := WinExist(tTitle " ahk_class AutoHotkeyGUI")) {
        if (oldHwnd != mainHwnd) {
            try GuiFromHwnd(oldHwnd).Destroy()
        }
    }

    clientLeft := 0
    clientTop := 0
    
    getRobloxPos(,, &clientLeft, &clientTop)
    
    hwnd := GetRobloxHWND()
    pt := Buffer(8, 0)
    DllCall("ClientToScreen", "UPtr", hwnd, "Ptr", pt)
    
    x := NumGet(pt, 0, "Int") + Towers[towerID].x - 16
    y := NumGet(pt, 4, "Int") + Towers[towerID].y - 16

    styleStr := "+ToolWindow +AlwaysOnTop -Caption +Disabled +Border +E0x20 +E0x08000000"

    tg := Gui(styleStr, tTitle)
    tg.BackColor := MultiplePaths ? "1A1A1A" : "FFFFFF"
    
    if (MultiplePaths)
        tg.SetFont("s12 w600 cFFFFFF", "Bahnschrift")
    else
        tg.SetFont("s10 c000000", "Arial")
    
    idLen := StrLen(towerID)

    if (idLen <= 3) {
        fontSize := "s12"
    } else if (idLen <= 5) {
        fontSize := "s8"
    } else if (idLen <= 8) {
        fontSize := "s6"
    } else if (idLen <= 11) {
        fontSize := "s4"
    } else {
        fontSize := "s3"
    }

    tg.SetFont("Bold " fontSize)

    tg.Add("Text", "x0 y0 w32 h24 Center BackgroundTrans 0x200", towerID)

    tg.SetFont("s8 norm")
    tg.Add("Text", "x0 y22 w32 h8 Center BackgroundTrans 0x200", level)
    
    tg.Show("x" x " y" y " w32 h32 NoActivate")
    
    WinSetTransparent(128, "ahk_id " tg.Hwnd)
    
    Towers[towerID].hwnd := tg.Hwnd

    SetTitleMatchMode oldMatchMode
    Critical("Off")
}



DeleteAllIndicators() {
    global Towers
    Critical("On")
    SetWinDelay(-1) 
    for id, t in Towers {
        if (t.HasProp("hwnd") && t.hwnd) {
            WinClose("ahk_id " t.hwnd)
            t.hwnd := ""
        }
    }
    SetWinDelay(10) 
    Critical("Off")
}

FindClosestTower(mx, my) {
    global Towers
    closestID := "", minDist := 20
    for id, t in Towers {
        dist := Sqrt((t.x - mx)**2 + (t.y - my)**2)
        if (dist < minDist) {
            minDist := dist
            closestID := id
        }
    }
    return closestID
}

HasStep(searchStep) {
    global RecordedSteps
    for i, s in RecordedSteps {
        if (s = searchStep) {
            return true
        }
    }
    return false
}


GetNextTowerID(slot) {
    global requiredTowers, Towers

    slotArray := StrSplit(requiredTowers, ",")
    for index, name in slotArray {
        slotArray[index] := Trim(name)
    }

    targetSlot := Integer(slot)
    if (targetSlot > slotArray.Length || targetSlot < 1) {
        baseName := ""
    } else {
        baseName := slotArray[targetSlot]
    }
    
    if (InStr(baseName, "DJ") || InStr(baseName, "DJ Booth")) {
        baseName := "DJ"
    }
    
    count := 0

    if (IsObject(Towers)) {
        for id, t in Towers {
            if (RegExMatch(id, "i)^" baseName "(\d+)$", &match)) {
                num := Integer(match[1])
                if (num > count) {
                    count := num
                }
            }
        }
    }

    if (InStr(baseName, "DJ")) {
        return baseName
    } else {
        return baseName (count + 1)
    }
}

ModernMsgBox(Title, Text, Buttons := "OK", type := "") {
    boxType := (Buttons = "OK") ? 0 : 4
    If (type = "WARNING") {
        boxType += 48
    } Else {
        boxType += 64
    }
    if (AlwaysOnTop = 1) {
        boxType += 4096
    }
    result := MsgBox(Text, Title, boxType)
    return (result = "OK" || result = "Yes") ? "YES" : "NO"
}

MapToString(inputMap) {
    result := ""
    for k, v in inputMap
        result .= k " => " v "`n"
    return RTrim(result, "`n")
}


ShowDebugConsole() {
    global DebugConsole, OverlayHWND, OverlayBitmap, OverlayGraphics, OverlayPicHWND
    global OverlayX, OverlayY, OverlayWidth, OverlayHeight
    
    if (DebugConsole != "1" && DebugConsole != 1) {
        return
    }
    if (OverlayHWND && WinExist("ahk_id " OverlayHWND)) {
        return
    }

    OverlayWidth  := Round(A_ScreenWidth  * 0.26)
    OverlayHeight := Round(A_ScreenHeight * 0.185)
    OverlayX      := Round(A_ScreenWidth  * 0.73)
    OverlayY      := Round(A_ScreenHeight * 0.76)

    og := Gui("+AlwaysOnTop +ToolWindow -Caption +E0x20 +E0x08000000 +E0x00000008 +LastFound")
    og.BackColor := "000000"
    og.Title     := "DebugOverlay"
    
    global OverlayPicCtrl := og.Add("Picture", "x0 y0 w" OverlayWidth " h" OverlayHeight " +0xE")
    OverlayPicHWND := OverlayPicCtrl.Hwnd
    OverlayHWND    := og.Hwnd
    
    og.Show("x" OverlayX " y" OverlayY " w" OverlayWidth " h" OverlayHeight " NA")
    
    WinSetTransColor("0x000000", "ahk_id " OverlayHWND)

    OverlayBitmap   := Gdip_CreateBitmap(OverlayWidth, OverlayHeight)
    OverlayGraphics := Gdip_GraphicsFromImage(OverlayBitmap)
    Gdip_SetSmoothingMode(OverlayGraphics, 4)
    
}

HideDebugConsole() {
    global OverlayHWND, OverlayBitmap, OverlayGraphics, OverlayPicHWND
    
    if (OverlayBitmap) { 
        Gdip_DisposeImage(OverlayBitmap)
        OverlayBitmap := 0 
    }
    if (OverlayGraphics) { 
        Gdip_DeleteGraphics(OverlayGraphics)
        OverlayGraphics := 0 
    }
    if (OverlayHWND) {
        WinClose("ahk_id " OverlayHWND)
    }
    OverlayHWND    := 0
    OverlayPicHWND := 0
}

UpdateOverlay() {
    global OverlayBitmap, OverlayGraphics, OverlayPicHWND, LogLines, OverlayWidth, OverlayHeight
    if (!OverlayGraphics) {
        return
    }

    if (IsSet(OverlayGraphics) && OverlayGraphics) {
        if (OverlayGraphics != 0 && OverlayGraphics != "") {
            try {
                Gdip_GraphicsClear(OverlayGraphics, 0x00000000)
            } catch Error as err {
                OverlayGraphics := 0 
                return
            }
        }
    }
    
    fontSize := 12
    fontName := "Consolas", style := 1
    textColor := 0xFFFFFFFF

    hFamilyOverlay := Gdip_FontFamilyCreate(fontName)
    hFontOverlay   := Gdip_FontCreate(hFamilyOverlay, fontSize, style)
    hFormatOverlay := Gdip_StringFormatCreate(0x0000)

    if (!hFormatOverlay || hFormatOverlay == 0 || !hFontOverlay || hFontOverlay == 0) {
        if (hFormatOverlay) => Gdip_DeleteStringFormat(hFormatOverlay)
        if (hFontOverlay) => Gdip_DeleteFont(hFontOverlay)
        if (hFamilyOverlay) => Gdip_DeleteFontFamily(hFamilyOverlay)
        return
    }

    try {
        Gdip_SetStringFormatAlign(hFormatOverlay, 0)
    } catch {
        Gdip_DeleteStringFormat(hFormatOverlay)
        Gdip_DeleteFont(hFontOverlay)
        Gdip_DeleteFontFamily(hFamilyOverlay)
        return
    }

    pBrushTextOverlay := Gdip_BrushCreateSolid(textColor)
    pBrushBgOverlay  := Gdip_BrushCreateSolid(0xAA000000)

    if (!pBrushTextOverlay || !pBrushBgOverlay) {
        if (pBrushTextOverlay) => Gdip_DeleteBrush(pBrushTextOverlay)
        if (pBrushBgOverlay) => Gdip_DeleteBrush(pBrushBgOverlay)
        Gdip_DeleteStringFormat(hFormatOverlay)
        Gdip_DeleteFont(hFontOverlay)
        Gdip_DeleteFontFamily(hFamilyOverlay)
        return
    }

    maxLines   := Floor(OverlayHeight / (fontSize * 1.4))
    startIndex := Max(1, LogLines.Length - maxLines + 1)
    yPos := 5, maxWidth := OverlayWidth - 20

    wrappedLines := []
    Loop maxLines {
        idx := startIndex + A_Index - 1
        if (idx > LogLines.Length)
            break
        line := LogLines[idx]
        while (StrLen(line) > 0) {
            if (StrLen(line) * fontSize * 0.6 <= maxWidth) { 
                wrappedLines.Push(line)
                break 
            }
            cutPos := Floor(maxWidth / (fontSize * 0.6))
            wrappedLines.Push(SubStr(line, 1, cutPos))
            line := SubStr(line, cutPos + 1)
        }
    }
    while (wrappedLines.Length > maxLines)
        wrappedLines.RemoveAt(1)

    for i, line in wrappedLines {
        Gdip_FillRectangle(OverlayGraphics, pBrushBgOverlay, 5, yPos, OverlayWidth-10, fontSize * 1.4)
        CreateRectF(&RC, 5, yPos, OverlayWidth-5, fontSize * 1.4)
        try {
            Gdip_DrawString(OverlayGraphics, line, hFontOverlay, hFormatOverlay, pBrushTextOverlay, &RC)
        }
        yPos += fontSize * 1.4
    }

    Gdip_DeleteBrush(pBrushTextOverlay)
    Gdip_DeleteBrush(pBrushBgOverlay)
    Gdip_DeleteStringFormat(hFormatOverlay)
    Gdip_DeleteFont(hFontOverlay)
    Gdip_DeleteFontFamily(hFamilyOverlay)

    if (IsSet(OverlayBitmap) && OverlayBitmap) {
        try {
            hBitmap := Gdip_CreateHBITMAPFromBitmap(OverlayBitmap)
            SetImage(OverlayPicHWND, hBitmap)
            DeleteObject(hBitmap)
        }
    }
}

LogToConsole(text, SendWebhookInstantly := false, flush := true) {
    global DebugConsole, LogLines, OverlayHWND, WebhookEnabled, WebhookLink, RunningStrategy, AutorunStartTime

    time := FormatTime(, "HH:mm:ss")
    formattedText := "[" time "] " text
    LogLines.Push(formattedText)
    while (LogLines.Length > 500)
        LogLines.RemoveAt(1)

    if (OverlayHWND && WinExist("ahk_id " OverlayHWND))
        UpdateOverlay()

    if (WebhookEnabled && WebhookLink != "" && RunningStrategy) {
        runtime := (AutorunStartTime > 0) ? FormatRuntime(AutorunStartTime) : "00:00"
        wText := "[" runtime "] " text
        if (!SendWebhookInstantly && WebhookDebugLogs) {
            SendToWebhook(wText)
        } else if (SendWebhookInstantly) {
            SendToWebhookInstant(wText,,flush)
        }
    }
}

FormatRuntime(StartTicks) {
    if (StartTicks = 0) {
        return "00:00"
    }
    elapsed := Floor((A_TickCount - StartTicks) / 1000)
    h := Floor(elapsed / 3600)
    m := Floor(Mod(elapsed, 3600) / 60)
    s := Mod(elapsed, 60)
    return (h > 0) ? Format("{:d}:{:02d}:{:02d}", h, m, s) : Format("{:d}:{:02d}", m, s)
}

claimPlaytimeRewards() { 
    global CollectPlaytimeRewards, NextCheckInterval, unfocusX, unfocusY
    
    if (CollectPlaytimeRewards != "1" && CollectPlaytimeRewards != 1) {
        return
    }
    Sleep(2000) ; load
    
    getRobloxPos(&pX, &pY, &w, &h)
    popupColor := PixelGetColor(w - 268, pY + 5, "RGB")
    r1 := (popupColor >> 16) & 0xFF, g1 := (popupColor >> 8) & 0xFF, b1 := popupColor & 0xFF
    r2 := 0xEE, g2 := 0x18, b2 := 0x18
    diff := Sqrt((r1-r2)**2 + (g1-g2)**2 + (b1-b2)**2)

    hasRedDot := (diff < 15)
    if (!hasRedDot) {
        hasRedDot := PixelSearch(&rx, &ry, w - 280, pY, w - 250, pY + 20, 0xEE1818, 20)
    }

    findRewardCloseBtn() {
        getRobloxPos(,, &rw, &rh)
        X1 := Round(rw * 0.2)
        Y1 := Round(rh * 0.1)
        W := Round(rw * 0.8)
        H := Round(rh * 0.45)
        
        ; Try x.png (newest TDS modal close button)
        res := AdvancedImageSearch("Resources\x.png", X1, Y1, W, H, 0.5, 1.5)
        if (res.status == "success" && res.score >= 0.65)
            return res

        ; Try close_freerewards.png
        res := AdvancedImageSearch("Resources\close_freerewards.png", X1, Y1, W, H, 0.5, 1.5)
        if (res.status == "success" && res.score >= 0.65)
            return res

        ; Try close.png
        res := AdvancedImageSearch("Resources\close.png", X1, Y1, W, H, 0.5, 1.5)
        if (res.status == "success" && res.score >= 0.65)
            return res

        return {status: "failed", score: 0}
    }

    closeRewardModal() {
        getRobloxPos(&rx, &ry, &rw, &rh)
        rc := findRewardCloseBtn()
        if (rc.status == "success") {
            Click(rc.x, rc.y)
            Sleep(500)
        } else {
            Click(ScaleX(1126), ScaleY(307))
            Sleep(500)
        }
        
        ; Verify it's closed, if still open click gift icon to toggle off
        rc2 := findRewardCloseBtn()
        if (rc2.status == "success") {
            Click(rw - 290, ry + 32)
            Sleep(500)
        }
    }

    isRewardMenuOpen() {
        getRobloxPos(,, &rw, &rh)
        rc := findRewardCloseBtn()
        if (rc.status == "success")
            return true
            
        resClaim := AdvancedImageSearch("Resources/Claim.png", Round(rw * 0.25), Round(rh * 0.2), Round(rw * 0.55), Round(rh * 0.6), 0.5, 1.5)
        if (resClaim.status == "success" && resClaim.score >= 0.65)
            return true

        resClaimDaily := AdvancedImageSearch("Resources/claimdailyreward.png", Round(rw * 0.25), Round(rh * 0.2), Round(rw * 0.55), Round(rh * 0.6), 0.5, 1.5)
        if (resClaimDaily.status == "success" && resClaimDaily.score >= 0.65)
            return true

        if (PixelSearch(&cx, &cy, Round(rw*0.25), Round(rh*0.2), Round(rw*0.55), Round(rh*0.76), 0x64F711, 10))
            return true

        return false
    }

    if (hasRedDot) {
        LogToConsole("Claiming playtime rewards..")
        Click(w - 290, pY + 32)
        Sleep(1000)

        openedMenu := false
        Loop 10 {
            if (isRewardMenuOpen()) {
                openedMenu := true
                break
            }
            Sleep(300)
        }

        if (!openedMenu) {
            getRobloxPos(&pX, &pY, &w, &h)
            MouseMove(w - 290, pY + 32, A_DefaultMouseSpeed+1)
            Sleep(50)
            MouseClick()

            Loop 10 {
                if (isRewardMenuOpen()) {
                    openedMenu := true
                    break
                }
                Sleep(300)
            }
        }

        if (!openedMenu) {
            closeRewardModal()
            LogToConsole("Failed to claim rewards!", true, false)
            UpdateDailyRewardTime()
            return
        }

        rewardsCollected := false
        Loop 12 {
            getRobloxPos(&pX, &pY, &w, &h)
            
            foundClaim := false
            Loop 5 {
                if (PixelSearch(&cx, &cy, Round(w*0.25), Round(h*0.2), Round(w*0.55), Round(h*0.76), 0x64F711, 10)) {
                    foundClaim := true
                    break
                }
                Sleep(100)
            }

            if (!foundClaim) {
                resClaim := AdvancedImageSearch("Resources/Claim.png", Round(w * 0.25), Round(h * 0.2), Round(w * 0.55), Round(h * 0.6), 0.5, 1.5)
                if (resClaim.status == "success" && resClaim.score >= 0.65) {
                    cx := resClaim.x, cy := resClaim.y
                    foundClaim := true
                } else {
                    resClaimDaily := AdvancedImageSearch("Resources/claimdailyreward.png", Round(w * 0.25), Round(h * 0.2), Round(w * 0.55), Round(h * 0.6), 0.5, 1.5)
                    if (resClaimDaily.status == "success" && resClaimDaily.score >= 0.65) {
                        cx := resClaimDaily.x, cy := resClaimDaily.y
                        foundClaim := true
                    }
                }
            }

            if (!foundClaim) {
                break
            }
            
            Click(cx, cy)
            rewardsCollected := true
            Sleep(600)

            Loop 5 {
                resConfirm := AdvancedImageSearch("Resources/claimreward.png", Round(w*0.25), Round(h*0.4), Round(w*0.5), Round(h*0.5), 0.5, 1.5)
                if (resConfirm.status == "success" && resConfirm.score >= 0.65) {
                    Click(resConfirm.x, resConfirm.y)
                    MouseMove(ScaleX(unfocusX), ScaleY(unfocusY))
                    Sleep(600)
                } else {
                    resConfirm2 := AdvancedImageSearch("Resources/claim_c.png", Round(w*0.25), Round(h*0.4), Round(w*0.5), Round(h*0.5), 0.5, 1.5)
                    if (resConfirm2.status == "success" && resConfirm2.score >= 0.65) {
                        Click(resConfirm2.x, resConfirm2.y)
                        MouseMove(ScaleX(unfocusX), ScaleY(unfocusY))
                        Sleep(600)
                    } else {
                        break
                    }
                }
            }
        }

        Sleep(800)

        try {
            getRobloxPos(&pX, &pY, &w, &h)
            x1 := Round(w*0.39)
            y1 := Round(h*0.36)
            x2 := Round(w*0.22)
            y2 := Round(h*0.4)

            langCode := "en-US"
            for availableLang in StrSplit(OCR.GetAvailableLanguages(), "`n", "`r") {
                if (availableLang != "" && SubStr(availableLang, 1, 2) = "en") {
                    langCode := availableLang
                    break
                }
            }
            
            ocrResult := OCR.FromRect(x1, y1, x2, y2, {lang: langCode, invertcolors: 1, scale: 2})
            textOnScreen := ocrResult.Text

            claimedCount := 0
            StrReplace(textOnScreen, "CLAIMED", , , &claimedCount)
            
            if (claimedCount != 0) {
                LogToConsole("Claimed free rewards (" . claimedCount . "/6)")   
            }

            if (claimedCount >= 6) {
                LogToConsole("All rewards collected! Next check in 24 hours.")
                NextCheckInterval := 86400000 
            } else {
                LogToConsole("Not all rewards collected. Next check in 2 hours.")
                NextCheckInterval := 7200000  
            }
        } catch {
            NextCheckInterval := 7200000
        }

        closeRewardModal()
    }
    UpdateDailyRewardTime()
}

UpdateDailyRewardTime() {
    global StateFile, NextCheckInterval

    if (!HasGlobal("NextCheckInterval") || NextCheckInterval == "") {
        NextCheckInterval := 7200000
    }
      
    IniWrite(A_Now, StateFile, "State", "LastDailyCheck")
    IniWrite(NextCheckInterval, StateFile, "State", "NextCheckInterval")
}

CheckDailyRewardTime() {
    global StateFile
    
    lastCheckTime := IniRead(StateFile, "State", "LastDailyCheck", "")
    
    currentIntervalMs := Integer(IniRead(StateFile, "State", "NextCheckInterval", "7200000"))
    
    if (lastCheckTime == "") {
        return true
    }

    intervalSeconds := currentIntervalMs / 1000
    
    try {
        timeDiffSeconds := DateDiff(A_Now, lastCheckTime, "Seconds")
        
        if (timeDiffSeconds >= intervalSeconds) {
            return true
        }
    } catch {
        return true
    }
    
    return false
}

HasGlobal(varName) {
    try {
        return %varName% !== ""
    } catch {
        return false
    }
}

closeChat() {
    hwnd := GetRobloxHWND()
    if (!hwnd || !WinActive("ahk_id " DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")))
        return
    getRobloxPos(&pX, &pY, &w, &h)
    chatColor := PixelGetColor(pX + 80, pY + 29, "RGB")
    r1 := (chatColor >> 16) & 0xFF, g1 := (chatColor >> 8) & 0xFF, b1 := chatColor & 0xFF
    r2 := 0xF4, g2 := 0xF5, b2 := 0xF8
    diff := Sqrt((r1-r2)**2 + (g1-g2)**2 + (b1-b2)**2)
    if (diff < 12) {
        MouseGetPos(&cx, &cy)
        MouseMove(pX + 80, pY + 35, 2)
        Sleep(100)
        Click()
        Sleep(100)
        MouseMove(cx, cy)
        LogToConsole("Closed chat")
    }
}


SendToWebhook(message) {
    global WebhookQueue, WebhookTimerActive
    if (message = "" || Trim(message) = "") {
        return
    }
    WebhookQueue.Push(message)
    if (!WebhookTimerActive) {
        WebhookTimerActive := true
        SetTimer(ProcessWebhookQueue, -100)
    }
}

SendToWebhookInstant(message, embedColor := 3447003, flush := true, mention := "") {
    global WebhookInstantQueue, WebhookInstantTimerActive, WebhookEnabled
    if (!WebhookEnabled || message = "" || Trim(message) = "") { 
        return
    }
    if (flush) {
        FlushWebhookQueue()
    }

    WebhookInstantQueue.Push({msg: message, color: embedColor, mention: mention})
    
    if (!WebhookInstantTimerActive) {
        WebhookInstantTimerActive := true
        SetTimer(ProcessWebhookInstantQueue, -100)
    }
}

ProcessWebhookInstantQueue() { 
    global WebhookInstantQueue, WebhookInstantTimerActive, WebhookLink

    static whr := ComObject("WinHttp.WinHttpRequest.5.1")

    if (WebhookInstantQueue.Length = 0) { 
        WebhookInstantTimerActive := false 
        return 
    }
    
    allMessages := ""
    finalColor := 3447003
    hasCustomColor := false
    finalMention := ""
    
    while (WebhookInstantQueue.Length > 0) {
        item := WebhookInstantQueue.RemoveAt(1)
        if (Trim(item.msg) = "") 
            continue
            
        allMessages .= (allMessages != "") ? "`n" item.msg : item.msg
        
        if (item.HasProp("mention") && item.mention != "" && finalMention = "") {
            finalMention := item.mention
        }
        
        if (item.color != 3447003) {
            finalColor := item.color
            hasCustomColor := true
        }
    }
    
    WebhookInstantTimerActive := false
    if (allMessages = "") 
        return
        
    if (!hasCustomColor) {
        lower := Format("{:L}", allMessages)
        if (InStr(lower, "error") || InStr(lower, "failed") || InStr(lower, "reloading")) {
            finalColor := 15158332
        } else if (InStr(lower, "success") || InStr(lower, "completed")) {
            finalColor := 3066993
        } else if (InStr(lower, "warning")) {
            finalColor := 16776960
        }
    }
    
    escaped := StrReplace(StrReplace(StrReplace(allMessages, "\", "\\"), '"', '\"'), "`n", "\n")
    if (finalMention != "") {
        payload := '{"content":"' finalMention '","embeds":[{"description":"' escaped '","color":' finalColor '}]}'
    } else {
        payload := '{"embeds":[{"description":"' escaped '","color":' finalColor '}]}'
    }
    
    try {
        whr.Open("POST", WebhookLink, true)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.SetTimeouts(5000, 5000, 8000, 8000)
        whr.Send(payload)
    } catch Error as err {
        LogToConsole("Webhook send failed: " err.Message)
    }
}



ProcessWebhookQueue() {
    global WebhookQueue, WebhookTimerActive, WebhookLink
    static whr := ComObject("WinHttp.WinHttpRequest.5.1")
    
    if (WebhookQueue.Length = 0) { 
        WebhookTimerActive := false 
        return 
    }
    if (WebhookQueue.Length < 20) { 
        SetTimer(ProcessWebhookQueue, -2000) 
        return 
    }
    
    allMessages := ""
    Loop 20 {
        if (WebhookQueue.Length = 0) 
            break
        
        msg := WebhookQueue.RemoveAt(1)
        if (Trim(msg) = "") 
            continue
            
        escaped := StrReplace(msg, "\", "\\")
        escaped := StrReplace(escaped, '"', '\"')
        escaped := StrReplace(escaped, "`n", "\n")
        escaped := StrReplace(escaped, "`r", "")
        
        if (Trim(escaped) = "") 
            continue
            
        allMessages .= escaped "\n"
    }
    
    if (allMessages = "") { 
        WebhookTimerActive := false 
        return 
    }
    
    allMessages := RTrim(allMessages, "\n")
    
    embedColor := 9868950
    payload := '{"embeds":[{"description":"``````\n' allMessages '\n``````","color":' embedColor '}]}'
    
    try {
        whr.Open("POST", WebhookLink, true)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send(payload)
    } catch Error {
    }
    
    if (WebhookQueue.Length > 0)
        SetTimer(ProcessWebhookQueue, -1000)
    else
        WebhookTimerActive := false
}


FlushWebhookQueue() {
    global WebhookQueue, WebhookTimerActive, WebhookLink
    
    if (WebhookQueue.Length = 0) 
        return
        
    WebhookTimerActive := false
    SetTimer(ProcessWebhookQueue, 0)
    
    allMessages := ""
    while (WebhookQueue.Length > 0) {
        msg := WebhookQueue.RemoveAt(1)
        if (Trim(msg) = "") 
            continue

        escaped := StrReplace(msg, "\", "\\")
        escaped := StrReplace(escaped, '"', '\"')
        escaped := StrReplace(escaped, "`n", "\n")
        escaped := StrReplace(escaped, "`r", "")
        
        if (Trim(escaped) = "") 
            continue
            
        allMessages .= escaped "\n"
    }
    
    if (allMessages = "") 
        return
        
    allMessages := RTrim(allMessages, "\n")
    
    embedColor := 9868950
    payload := '{"embeds":[{"description":"``````\n' allMessages '\n``````","color":' embedColor '}]}'
    
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", WebhookLink, false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.SetTimeouts(5000, 5000, 8000, 8000)
        whr.Send(payload)
    } catch Error as err {
        LogToConsole("Webhook send failed: " err.Message)
    }
}

SafeReload() {
    global RestartLock, StateFile, RunningStrategy, OverlayHWND, MainGui
    if (RestartLock) {
        return
    }
    RestartLock := true
    KillSubmacros()
    if (OverlayHWND) {
        WinClose("ahk_id " OverlayHWND)
    }
    
    if (IsSet(MainGui) && MainGui) {
        MainGui.Destroy()
    }
    
    DeleteAllIndicators()
    if (RunningStrategy) {
        currentStrat := IniRead(StateFile, "State", "Strategy", "")
        if (currentStrat != "") {
            IniWrite(1, StateFile, "State", "Running")
        }
    } 

    FlushWebhookQueue()

    Reload()
}

startWatchdog() {
    global watchdogPID
    KillSubmacros()
    watchdogPID := OwnedWatchdog.Start(A_ScriptDir)
}

KillSubmacros() {
    global watchdogPID
    OwnedWatchdog.Stop()
    watchdogPID := ""
}

HandleExit(ExitReason, ExitCode) {
    global StateFile, SettingsFile

    if (RunningStrategy) {
        KillSubmacros()
        if (ExitReason = "Close" || ExitReason = "Menu" || ExitReason = "Shutdown" || ExitReason = "Logoff") {
            IniWrite(0, StateFile, "State", "Running")
            IniDelete(StateFile, "State", "Strategy")
            IniDelete(StateFile, "State", "StartTime")
            IniDelete(StateFile, "State", "Coins")
            IniDelete(StateFile, "State", "Gems")
            IniDelete(StateFile, "State", "EXP")
            IniDelete(StateFile, "State", "TotalTriumphs")
            IniDelete(StateFile, "State", "TotalLosses")
            IniDelete(StateFile, "State", "TotalTimeSeconds")
            IniDelete(StateFile, "State", "Timescale")
            IniDelete(StateFile, "State", "TimeWhenStartedPlaying")
            IniDelete(StateFile, "State", "Equipped")
        }
    }
}

CleanupGdip(exitReason, exitCode) {
    global pToken
    Gdip_Shutdown(pToken)
}

MainGui.OnEvent("Close", CloseWindow)

CheckOcrLanguage() {
    try {
        rawLangs := OCR.GetAvailableLanguages()
        hasEnglish := false
        
        availableLangs := StrSplit(rawLangs, ["`n", "`r", ",", " "])
        
        for lang in availableLangs {
            if (lang = "")
                continue
                
            if InStr(lang, "en") {
                hasEnglish := true
                break
            }
        }
        
        if (!hasEnglish) {
            msgText := "English language pack for OCR (text detection) is not installed on your system!`n`n"
                    . "Without it, the script cannot read text from the screen properly.`n`n"
                    . "Would you like to open Windows Settings to download the Language?"
            
            result := MsgBox(msgText, "Missing OCR Language", 48 + 4)
            
            if (result = "Yes") {
                Run("ms-settings:regionlanguage")
            }
            
            ExitApp()
        }
    }
}

SendScreenshot(pBitmap := 0, description := "", color := 12434877, screenshot := WebhookScreenshots) {
    global WebhookLink

    escapedDescription := StrReplace(description, "\", "\\")
    escapedDescription := StrReplace(escapedDescription, '"', '\"')
    escapedDescription := StrReplace(escapedDescription, "`n", "\n")

    fields := []
    internalBitmap := 0

    if (screenshot == "0" || screenshot == 0) {
        payload_json := '{"embeds": [{"description": "' escapedDescription '", "color": ' color '}]}'
        fields.Push(Map("name", "payload_json", "content-type", "application/json", "content", payload_json))
    } 
    else {
        if (!pBitmap) {
            pBitmap := Gdip_BitmapFromScreen()
            internalBitmap := pBitmap
        }
        payload_json := '{"embeds": [{"description": "' escapedDescription '", "color": ' color ', "image": {"url": "attachment://screenshot.png"}}]}'
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
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", WebhookLink "?wait=true", false)
        whr.SetRequestHeader("Content-Type", contentType)
        whr.SetTimeouts(5000, 5000, 15000, 15000)
        whr.Send(postdata)
    } catch Error as err {
        LogToConsole("Screenshot webhook failed: " err.Message)
    }
}

CreateFormData(&retData, &contentType, fields) {
    chars := "0123456789abcdefghijklmnopqrstuvwxyz"
    boundary := ""
    Loop 12 {
        boundary .= SubStr(chars, Random(1, StrLen(chars)), 1)
    }

    hData := DllCall("GlobalAlloc", "UInt", 0x2, "UPtr", 0, "Ptr")
    DllCall("ole32\CreateStreamOnHGlobal", "Ptr", hData, "Int", 0, "PtrP", &pStream)

    for index, field in fields {
        str := "`r`n------------------------------" boundary "`r`n"
        str .= 'Content-Disposition: form-data; name="' field["name"] '"'
        if (field.Has("filename"))
            str .= '; filename="' field["filename"] '"'
        str .= "`r`nContent-Type: " field["content-type"] "`r`n`r`n"
        if (field.Has("content"))
            str .= field["content"] "`r`n"

        length := StrPut(str, "UTF-8") - 1
        utf8 := Buffer(length)
        StrPut(str, utf8, length, "UTF-8")
        DllCall("shlwapi\IStream_Write", "Ptr", pStream, "Ptr", utf8, "UInt", length, "UInt")

        if (field.Has("pBitmap")) {
            try {
                pFileStream := Gdip_SaveBitmapToStream(field["pBitmap"])
                DllCall("shlwapi\IStream_Size",  "Ptr", pFileStream, "UInt64*", &size := 0, "UInt")
                DllCall("shlwapi\IStream_Reset", "Ptr", pFileStream, "UInt")
                DllCall("shlwapi\IStream_Copy",  "Ptr", pFileStream, "Ptr", pStream, "UInt", size, "UInt")
                ObjRelease(pFileStream)
            } catch Error as err {
                LogToConsole("Failed to attach screenshot to webhook: " err.Message)
            }
        }
    }

    str := "`r`n------------------------------" boundary "--`r`n"
    length := StrPut(str, "UTF-8") - 1
    utf8 := Buffer(length)
    StrPut(str, utf8, length, "UTF-8")
    DllCall("shlwapi\IStream_Write", "Ptr", pStream, "Ptr", utf8, "UInt", length, "UInt")
    ObjRelease(pStream)

    pData := DllCall("GlobalLock", "Ptr", hData, "Ptr")
    size  := DllCall("GlobalSize", "Ptr", pData, "UPtr")
    retData := ComObjArray(0x11, size)
    pvData  := NumGet(ComObjValue(retData), 8 + A_PtrSize, "Ptr")
    DllCall("RtlMoveMemory", "Ptr", pvData, "Ptr", pData, "Ptr", size)
    DllCall("GlobalUnlock", "Ptr", hData)
    DllCall("GlobalFree",   "Ptr", hData, "Ptr")
    contentType := "multipart/form-data; boundary=----------------------------" boundary
}

InArray(arr, value) {
    for item in arr
        if (item = value)
            return true
    return false
}

; reads tds message (e.g., "You cannot place here")
; returns 1 if the given text is found, 0 if not
; ReadMessage(["already", "current", "rotation"]), for example
; works only with red color
ReadMessage(includeStr := "", includeRx := "", excludeStr := "", excludeRx := "") {
    langCode := "en-US"
    for availableLang in StrSplit(OCR.GetAvailableLanguages(), "`n", "`r") {
        if (availableLang != "" && SubStr(availableLang, 1, 2) = "en") {
            langCode := availableLang
            break
        }
    }

    getRobloxPos(,,&w,&h)
    x := Round(w * 0.2), y := Round(h * 0.18)
    width := Round(w * 0.7) - x, height := Round(h * 0.35) - y

    if (width <= 0 || height <= 0)
        return false

    pBitmap := Gdip_BitmapFromScreen(x "|" y "|" width "|" height)
    pGraphics := Gdip_GraphicsFromImage(pBitmap)
    Matrix := "
    (
    5.0|0.0|0.0|0.0|0.0|
    0.0|-5.0|0.0|0.0|0.0|
    0.0|0.0|-5.0|0.0|0.0|
    0.0|0.0|0.0|1.0|0.0|
    -2.5|1.0|1.0|0.0|1.0
    )"
    pBitmapFiltered := Gdip_CreateBitmap(width, height)
    pGraphicsFiltered := Gdip_GraphicsFromImage(pBitmapFiltered)
    Gdip_DrawImage(pGraphicsFiltered, pBitmap, 0, 0, width, height, 0, 0, width, height, Matrix)
    hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmapFiltered)

    ocrResult := OCR.FromBitmap(hBitmap, {lang: langCode, scale: 3, grayscale: 1})

    DeleteObject(hBitmap)
    Gdip_DisposeImage(pBitmapFiltered), Gdip_DeleteGraphics(pGraphicsFiltered)
    Gdip_DeleteGraphics(pGraphics), Gdip_DisposeImage(pBitmap)

    ocrText := ocrResult.Text

    for s in (HasMethod(excludeStr, "__Enum") ? excludeStr : [excludeStr]) {
        if (s != "" && RegExMatch(ocrText, "i)\b" . s . "\b"))
            return false
    }
    for rx in (HasMethod(excludeRx, "__Enum") ? excludeRx : [excludeRx]) {
        if (rx != "" && RegExMatch(ocrText, "i)" . rx))
            return false
    }

    matchStr := (includeStr == "")
    for s in (HasMethod(includeStr, "__Enum") ? includeStr : [includeStr]) {
        if (s != "" && RegExMatch(ocrText, "i)\b" . s . "\b")) {
            matchStr := true
            break
        }
    }

    matchRx := (includeRx == "")
    for rx in (HasMethod(includeRx, "__Enum") ? includeRx : [includeRx]) {
        if (rx != "" && RegExMatch(ocrText, "i)" . rx)) {
            matchRx := true
            break
        }
    }

    return matchStr && matchRx
}

waitForTowerUI(&resV2 := "", &resV1 := "", timeout := 0) {
    global PotatoMode
    StartTime := A_TickCount
    Loop {
        getRobloxPos(&rx, &ry, &w, &h)
        X1_v2 := Round(w * 0.02)
        Y1_v2 := Round(h/2.5)
        W_v2 := Round(w * 0.22) - X1_v2
        H_v2 := Round(w * 0.95) - Y1_v2

        resV2 := AdvancedImageSearch("Resources\TowerUI\Variant2.png", X1_v2, Y1_v2, W_v2, H_v2, ,,0.05)

        if (resV2.status == "success" && resV2.score > 0.55) {
            return true
        }

        Sleep(30)

        X1_v1 := Round(w * 0.16)
        Y1_v1 := Round(h * 0.05)
        W_v1  := Round(w * 0.2) - X1_v1
        H_v1 := Round(h * 0.3) - Y1_v1
        resV1 := AdvancedImageSearch("Resources\TowerUI\Variant1.png", X1_v1, Y1_v1, W_v1, H_v1, ,,0.05)

        if (resV1.status == "success" && resV1.score > 0.68) {
            return true
        }
        Sleep(30)

        if (timeout != 0) {
            if (A_TickCount - StartTime > timeout) {
                return false
            }
        }

        if (A_TickCount - StartTime > (PotatoMode == 1 ? 3500 : 2200)) {
            return false
        }

    }
}


RunAutoSpinTool(*) {
    Run('"' A_ScriptDir '\submacros\AutoHotkey64.exe" "' A_ScriptDir '\submacros\auto_spin.ahk"')
}

RunAutoConsumableTool(*) {
    Run('"' A_ScriptDir '\submacros\AutoHotkey64.exe" "' A_ScriptDir '\submacros\auto_open_consumable.ahk"')
}

; ==============================================================================
; Auto-Update System (GitHub Releases)
; ==============================================================================

; Release-owned update adapter. The old download URL is never executed.
CheckForUpdates(manual := false) => UpdateHelper.Begin(manual)
ApplyAutoUpdate(downloadUrl, targetVer) => UpdateHelper.Begin(true)
