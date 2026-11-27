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
CoordMode("ToolTip", "Screen")

ListLines(False)
KeyHistory(0)
SetTitleMatchMode(1)

if (RegExMatch(A_ScriptDir, "i)\.(zip|rar)")) {
    LocalizationMsgBox("You are attempting to run the script from a ZIP file.`n`nPlease Extract/Unzip the file first, then run the script in the extracted folder.","Running From ZIP", 0x10)
    ExitApp()
}

if WinExist("Ultimate Macro") {
    WinClose("Ultimate Macro")
}

if (A_PtrSize == 4) {
    LocalizationMsgBox("You are running 32-bit AutoHotkey, the macro will not work properly, sadly.")
}

#Include lib\Gdip_All.ahk
#Include lib\OCR.ahk
#Include lib\Gdip_ImageSearch.ahk
#Include lib\Roblox.ahk
#Include lib\HyperSleep.ahk
#Include lib\ImageSearch\ImageSearch.ahk
#Include lib\JSON.ahk
#Include lib\Localization.ahk
#Include lib\Discord.ahk
#Include lib\WebhookMentions.ahk
#Include lib\TowerXP.ahk
#Include lib\BatchProgress.ahk
#Include lib\BatchB.ahk
#Include lib\BatchC.ahk
#Include lib\DiscordSettings.ahk
#Include lib\FarmingTab.ahk
#Include lib\FarmingPresets.ahk
#Include lib\EarningsLog.ahk
#Include lib\FarmingEarnings.ahk
#Include lib\Appearance.ahk
#Include lib\AppearanceSettings.ahk
#Include lib\SettingsPage.ahk
#Include lib\DiscordPage.ahk
#Include lib\RecordPage.ahk

ver := "1.3.3b-final"

A_MaxHotkeysPerInterval := 9999

pToken := Gdip_Startup()
MacroAppearance.Load()
global LocalizationAppearanceRefresh := (*) => MacroAppearance.Wording()
global MacroClosing := false, MacroClosingManually := false
OnExit(ShutdownMacro)

global AppDataOpt := A_AppData "\Ultimate_Macro\Options"
global SettingsFile := AppDataOpt "\Settings.tds"
global BotSettings := AppDataOpt "\Discord-Bot-Settings.ini"
global RecordingsDir := A_AppData "\Ultimate_Macro\Recordings"
global StateFile := A_AppData "\Ultimate_Macro\state.ini"
try EarningsImportLegacy(StateFile)

global StratsDir := A_WorkingDir "\Resources\Strats"

global ShowIndicators := true

global WebhookQueue := []
global WebhookTimerActive := false
global WebhookInstantQueue := []
global WebhookInstantTimerActive := false
global WebhookEnabled := false

if !DirExist(AppDataOpt)
    DirCreate(AppDataOpt)
if !DirExist(RecordingsDir)
    DirCreate(RecordingsDir)

LocalizationInit(SettingsFile, A_ScriptDir "\Resources\Languages")

;INI READS
global VipLink := IniRead(SettingsFile, "Options", "VipLink", "") 
global UseVipServer := IniRead(SettingsFile, "Options", "UseVipServer", "0")
global AlwaysOnTop := IniRead(SettingsFile, "Options", "AlwaysOnTop", 0)

global LegacyMode := IniRead(SettingsFile, "Options", "LegacyMode", 0)

global WebhookLink := IniRead(SettingsFile, "Webhook", "Link", "")
global WebhookLink2 := IniRead(SettingsFile, "Webhook", "Link2", "")
global WebhookUserID := IniRead(SettingsFile, "Webhook", "WebhookUserID", "")
global WebhookEnabled := IniRead(SettingsFile, "Webhook", "Enabled", 0)
global PotatoMode := IniRead(SettingsFile, "Options", "PotatoMode", 0)
global SendCurrenciesEnabled := IniRead(SettingsFile, "Webhook", "SendCurrencies", "1")
global WebhookDebugLogs := IniRead(SettingsFile, "Webhook", "WebhookDebugLogs", "1")
global WebhookScreenshots := IniRead(SettingsFile, "Webhook", "WebhookScreenshots", "1")
global WebhookTriumphScreenshots := IniRead(SettingsFile, "Webhook", "WebhookTriumphScreenshots", 1)
global WebhookSepatateTriumphScreenshots := IniRead(SettingsFile, "Webhook", "WebhookSepatateTriumphScreenshots", 0)
;
global BotToken := IniRead(BotSettings, "Token", "BotToken", "")
global BotEnabled := IniRead(BotSettings, "Settings", "Enabled", 0)
global ChannelID := IniRead(BotSettings, "Settings", "Channel", "")
global UserID := IniRead(BotSettings, "Settings", "UserID", "")
;
global UseRestartBtn := IniRead(SettingsFile, "Options", "UseRestartBtn", "1")
global UsePlayAgainBtn := IniRead(SettingsFile, "Options", "UsePlayAgainBtn", "1")
global RotateStrategies := IniRead(SettingsFile, "Options", "RotateStrategies", 0)
global AutoEquip := IniRead(SettingsFile, "Options", "AutoEquip", 0)
global CheckTheMap := IniRead(SettingsFile, "Options", "CheckTheMap", 1)
global UseNumbersForHotbar := IniRead(SettingsFile, "Options", "UseNumbers", 1)
global UseHForUpgrade := IniRead(SettingsFile, "Options", "UseHotkeyForUpgrade", 1)
global CollectPlaytimeRewards:= IniRead(SettingsFile, "Options", "CollectPlaytimeRewards", 1)
global AutoCloseChat := IniRead(SettingsFile, "Options", "AutoCloseChat", 1)
global Strategy1Path := IniRead(SettingsFile, "Options", "Strategy1", "")
global Strategy2Path := IniRead(SettingsFile, "Options", "Strategy2", "")
global PartyMembers := IniRead(SettingsFile, "Multiplayer", "PartyMembers", "someone, someone...")
global PlayerRole := IniRead(SettingsFile, "Multiplayer", "PlayerRole", "Host")
global LeaveCondition := IniRead(SettingsFile, "Multiplayer", "LeaveCondition", "Any")
global HostName := IniRead(SettingsFile, "Multiplayer", "HostName", "...")
global MultiplayerEnabled := IniRead(SettingsFile, "Multiplayer", "MultiplayerEnabled", 0)

global DefaultMouseSpeed := IniRead(SettingsFile, "Options", "DefaultMouseSpeed", "2")
global MouseDelay := IniRead(SettingsFile, "Options", "MouseDelay", "-1")
global KeyDelay := IniRead(SettingsFile, "Options", "KeyDelay", "-1")

global PlaceTowerKey := IniRead(SettingsFile, "RecordingHotkeys", "PlaceTowerKey", "f")
global UpgradeTowerKey := IniRead(SettingsFile, "RecordingHotkeys", "UpgradeTowerKey", "^u")
global AlignCameraKey := IniRead(SettingsFile, "RecordingHotkeys", "AlignCameraKey", "^t")
global ChangeDJTrackKey := IniRead(SettingsFile, "RecordingHotkeys", "ChangeDJTrackKey", "^d")
global SellTowerKey := IniRead(SettingsFile, "RecordingHotkeys", "SellTowerKey", "^x")
global DeleteTowerRecordingKey := IniRead(SettingsFile, "RecordingHotkeys", "DeleteTowerRecordingKey", "^b")
global RecordInputsKey := IniRead(SettingsFile, "RecordingHotkeys", "RecordInputsKey", "^+e")
global HoloKey := IniRead(SettingsFile, "RecordingHotkeys", "HoloKey", "^!h")
global ChangeTargetsKey := IniRead(SettingsFile, "RecordingHotkeys", "ChangeTargetsKey", "^vkC0")

global CurrentStratStartTime := Integer(IniRead(StateFile, "State", "CurrentStratStartTime", "0"))
global CurrentRotationIndex := Integer(IniRead(StateFile, "State", "CurrentRotationIndex", "1"))

global g_IsFirstLaunch := Integer(IniRead(StateFile, "State", "IsFirstLaunch", 1))

global SwapAmount := IniRead(SettingsFile, "Options", "SwapAmount", "4")
global SwapUnit := IniRead(SettingsFile, "Options", "SwapUnit", "Runs")
global CurrentRunCount := Integer(IniRead(StateFile, "State", "CurrentRunCount", "0"))

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
global DebugConsole := IniRead(SettingsFile, "Options", "DebugConsole", "1")

global TimescaleActive := false

if (TimeScaleMode = "1.5x") {
    UseTimeScale := true,  TimeScaleMultiplier := 1.5
} else if (TimeScaleMode = "2x") {
    UseTimeScale := true,  TimeScaleMultiplier := 2
} else {
    UseTimeScale := false, TimeScaleMultiplier := 1
}

global UpgradeDelay := IniRead(SettingsFile, "Options", "UpgradeDelay", 200)

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

IsRecordingActive(*) {
    global Recording
    return (Recording != false)
}

if (PlaceTowerKey = "") {
    IniWrite("f", SettingsFile, "RecordingHotkeys", "PlaceTowerKey")
    global PlaceTowerKey := IniRead(SettingsFile, "RecordingHotkeys", "PlaceTowerKey", "f")
}
if (UpgradeTowerKey = "") {
    IniWrite("^u", SettingsFile, "RecordingHotkeys", "UpgradeTowerKey")
    global UpgradeTowerKey := IniRead(SettingsFile, "RecordingHotkeys", "UpgradeTowerKey", "^u")
}
if (AlignCameraKey = "") {
    IniWrite("^t", SettingsFile, "RecordingHotkeys", "AlignCameraKey")
    global AlignCameraKey := IniRead(SettingsFile, "RecordingHotkeys", "AlignCameraKey", "^t")
}
if (ChangeDJTrackKey = "") {
    IniWrite("^d", SettingsFile, "RecordingHotkeys", "ChangeDJTrackKey")
    global ChangeDJTrackKey := IniRead(SettingsFile, "RecordingHotkeys", "ChangeDJTrackKey", "^d")
}
if (SellTowerKey = "") {
    IniWrite("^x", SettingsFile, "RecordingHotkeys", "SellTowerKey")
    global SellTowerKey := IniRead(SettingsFile, "RecordingHotkeys", "SellTowerKey", "^x")
}
if (DeleteTowerRecordingKey = "") {
    IniWrite("^b", SettingsFile, "RecordingHotkeys", "DeleteTowerRecordingKey")
    global DeleteTowerRecordingKey := IniRead(SettingsFile, "RecordingHotkeys", "DeleteTowerRecordingKey", "^b")
}
if (RecordInputsKey = "") {
    IniWrite("^+e", SettingsFile, "RecordingHotkeys", "RecordInputsKey")
    global RecordInputsKey := IniRead(SettingsFile, "RecordingHotkeys", "RecordInputsKey", "^+e")
}
if (HoloKey = "") {
    IniWrite("^!h", SettingsFile, "RecordingHotkeys", "HoloKey")
    global HoloKey := IniRead(SettingsFile, "RecordingHotkeys", "HoloKey", "^!h")
}
if (ChangeTargetsKey = "") {
    IniWrite("^vkC0", SettingsFile, "RecordingHotkeys", "ChangeTargetsKey")
    global ChangeTargetsKey := IniRead(SettingsFile, "RecordingHotkeys", "ChangeTargetsKey", "^vkC0")
}

RegisterRecordingHotkeys()

;Got this from someone on a Discord server
RegisterRecordingHotkeys(oldKeys := "") {
    global PlaceTowerKey, UpgradeTowerKey, ChangeDJTrackKey, DeleteTowerRecordingKey, IsRecordingActive
    global SellTowerKey, AlignCameraKey, RecordInputsKey, HoloKey, ChangeTargetsKey, RepoKey, UpgradeTowerGKey

    HotIf(IsRecordingActive)

    if IsObject(oldKeys) {
        for old in oldKeys {
            if (old != "") {
                try Hotkey(old, "Off")
            }
        }
    }

    Hotkey(PlaceTowerKey, PlaceTowerHK, "On")
    Hotkey(UpgradeTowerKey, UpgradeTowerHK, "On")
    Hotkey(ChangeDJTrackKey, ChangeDJTrackHK, "On")
    Hotkey(DeleteTowerRecordingKey, DeleteTowerRecordingHK, "On")
    Hotkey(SellTowerKey, SellTowerHK, "On")
    Hotkey(AlignCameraKey, AlignCameraHK, "On")
    Hotkey(RecordInputsKey, RecordInputsHK, "On")
    Hotkey(HoloKey, CloneTowerHK, "On")
    Hotkey(ChangeTargetsKey, ChangeTargetsHK, "On")
    Hotkey("~^" RepoKey, BrawlerRepositionHK, "On")
    Hotkey("~^" RaiseDeadKey, ActivateRaiseTheDeadHK, "On")
    Hotkey("~LButton", DetectTowerForUpgrading, "On")
    Hotkey("~LButton Up", DetectUpgrade, "On")

    HotIf()
}

DetectTowerForUpgrading(*) {
    global MacroRecording, MacroSteps, MacroStartTime, Recording, Towers, RecordedSteps, Commander, ActiveRTowerID, CachedMenuUI, isUiPositionSaved, isUpgradeAuthorized, activeUpgradeRegions, CachedResV2, CachedResV1

    if (IsSet(MacroRecording) && MacroRecording) {
        MouseGetPos(&mx, &my)
        elapsed := A_TickCount - MacroStartTime
        MacroStartTime := A_TickCount
        MacroSteps.Push("Sleep(" elapsed ")")
        MacroSteps.Push("Click(" mx ", " my ")")
        return
    }

    if (!Recording)
        return

    MouseGetPos(&mx, &my, &clickWindow)
    robloxHwnd := GetRobloxHWND()
    
    if (clickWindow != robloxHwnd)
        return

    currentTowerID := ""
    for id, t in Towers {
        ix1 := t.x - 16
        iy1 := t.y - 16
        ix2 := ix1 + 32
        iy2 := iy1 + 32
        
        if (mx >= ix1 && mx <= ix2 && my >= iy1 && my <= iy2) {
            currentTowerID := id
            break
        }
    }

    if (currentTowerID != "") {
        ActiveRTowerID := currentTowerID
        isUpgradeAuthorized := false
        
        openedSuccessfully := waitForTowerUI(&resv2, &resv1)
        
        if (!openedSuccessfully) {
            ActiveRTowerID := ""
        } else {
            CachedResV2 := IsSet(resv2) ? resv2 : ""
            CachedResV1 := IsSet(resv1) ? resv1 : ""
        }
        return
    } else {
        if (ActiveRTowerID != "") {
            openedSuccessfully := waitForTowerUI(&resv2, &resv1, 120)
            
            if (!openedSuccessfully) {
                ActiveRTowerID := ""
            }
        }
    }
}

DetectUpgrade(*) {
    global Recording, ActiveRTowerID, Towers, RecordedSteps, Commander, isUpgradeAuthorized, activeUpgradeRegions, CachedResV2, CachedResV1
    
    if (!Recording || !IsSet(ActiveRTowerID) || ActiveRTowerID == "")
        return

    towerID := ActiveRTowerID
    
    if (!Towers.Has(towerID)) {
        ActiveRTowerID := ""
        return
    }

    MouseGetPos(&mx, &my, &clickWindow)
    robloxHwnd := GetRobloxHWND()
    
    if (clickWindow != robloxHwnd)
        return

    if (!IsSet(CachedResV2) || !IsSet(CachedResV1) || (CachedResV2 == "" && CachedResV1 == "")) {
        resv2 := ""
        resv1 := ""
        openedSuccessfully := waitForTowerUI(&resv2, &resv1)
        if (!openedSuccessfully) {
            ActiveRTowerID := ""
            return
        }
        CachedResV2 := IsSet(resv2) ? resv2 : ""
        CachedResV1 := IsSet(resv1) ? resv1 : ""
    } else {
        resv2 := CachedResV2
        resv1 := CachedResV1
    }

    path := Towers[towerID].path
    pathLevel := Towers[towerID].pathLevel
    nextLevel := Towers[towerID].level + 1

    doResV2 := (IsObject(resv2) && resv2.HasProp("score") && resv2.score > 0.55)

    if (doResV2) {
        upgAX := resv2.x - ScaleX(100)
        upgAY := resv2.y - ScaleY(260)
        upgAW := ScaleX(300)
        upgAH := ScaleY(110)
    } else if (IsObject(resv1)) {
        upgAX := resv1.x - ScaleX(344)
        upgAY := resv1.y + ScaleY(343)
        upgAW := ScaleX(300)
        upgAH := ScaleY(110)
    } else {
        return
    }

    region := [upgAX, upgAY, upgAW, upgAH]

    if (path != 0 && nextLevel > pathLevel && pathLevel != 0) {
        if (path = 2 && IsObject(resv1)) { 
            region := [resv1.x - ScaleX(344), resv1.y + ScaleY(488), ScaleX(300), ScaleY(110)]
        }
    }

    x1 := region[1]
    y1 := region[2]
    x2 := region[1] + region[3]
    y2 := region[2] + region[4]

    if (mx >= x1 && mx <= x2 && my >= y1 && my <= y2) {
        if PixelSearch(&gx, &gy, x1, y1, x2, y2, 0x206435, 7) {
            if (AdvancedImageSearch("Resources/fully_upgraded.png", x1, y1, region[3], region[4]).score >= 0.69) {
                return
            }

            Towers[towerID].level += 1
            LogToConsole("Upgraded tower " towerID " to level " Towers[towerID].level ".")
            UpdateTowerIndicator(towerID)
            
            if (Towers[towerID].path != 0 && Towers[towerID].path != "") {
                RecordedSteps.Push("UpgradeTower(" towerID ", false, 1, " Towers[towerID].path ", " Towers[towerID].pathLevel ")")
            } else {
                RecordedSteps.Push("UpgradeTower(" towerID ")")
            }
            
            if (Towers[towerID].level >= 2 && RegExMatch(towerID, "i)^Commander\d*$") && !Commander) {
                Commander := true
                if (!HasStep("Commander := true"))
                    RecordedSteps.Push("Commander := true")
            }
        }
    }
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


autoRun := IniRead(StateFile, "State", "Running",   0)
autoStrat := IniRead(StateFile, "State", "Strategy",  "")
savedStartTime := IniRead(StateFile, "State", "StartTime", 0)

if (BotEnabled && ChannelID != "" && UserID != "") {
    SetTimer(ProcessCommands, 1000, 1)
    SetTimer(() => ProcessCommands(), -50, 1)
}

if (savedStartTime != 0)
    AutorunStartTime := Integer(savedStartTime)

if (autoRun = 1 && autoStrat != "" && FileExist(autoStrat)) {
    LoadStrategyFile(autoStrat)
    RunningStrategy := true
    ActivateRoblox()
    RunStrategy()
} else {
    ; This customized build keeps its local files on startup.
    MultiInstanceTools := "RobloxAccountManager.exe,Roblox Account Manager.exe,RAM.exe,RobloxMulti.exe,MultiRoblox.exe,MultipleRoblox.exe,Multiple Roblox.exe"
    Loop Parse, MultiInstanceTools, "," {
        if ProcessExist(A_LoopField) {
            LocalizationMsgBox("Conflicting program detected:`n" A_LoopField "`n`nFor this script to work properly, please close all Roblox multi-client utilities.`nPlease close them and try again.", "Error", 48)
            ExitApp()
        }
    }
}

global MainGui := Gui("-Caption +Border +MaximizeBox +LastFound")
MainGui.BackColor := MacroAppearance.Color("background", "121212")

global SystemHwnds := Map()
MacroAppearance.wallpaper := MainGui.Add("Picture", "x0 y78 w700 h487 Hidden Disabled +0xE", "")
SystemHwnds[MacroAppearance.wallpaper.Hwnd] := true

sysBar1 := AppearanceAdd(MainGui, "Progress", "x0 y3 w700 h39 Disabled Background0A0A0A", 0)
SystemHwnds[sysBar1.Hwnd] := true

AppearanceFont(MainGui, "s11 w300 cFFFFFF", "Segoe UI")
if FileExist(IconPath) {
    sysIcon := AppearanceAdd(MainGui, "Picture", "BackgroundTrans x17 y7 w28 h28", IconPath)
    SystemHwnds[sysIcon.Hwnd] := true
    sysIcon.OnEvent("Click", (*) => MacroAppearance.LogoClick())
}

global GuiTitleCtrl := AppearanceAdd(MainGui, "Text", "x52 y8 w185 h26 0x200 BackgroundTrans", "Ultimate Macro")
GuiTitleCtrl.OnEvent("Click", MoveWindow)
SystemHwnds[GuiTitleCtrl.Hwnd] := true

AppearanceFont(MainGui, "s11 Norm cFFFFFF", "Marlett")
global BtnMin := AppearanceAdd(MainGui, "Text", "x600 y12 w30 h25 Center BackgroundTrans", "0")
global BtnMax := AppearanceAdd(MainGui, "Text", "x630 y12 w30 h25 Center BackgroundTrans", "1")
global BtnClose := AppearanceAdd(MainGui, "Text", "x660 y12 w30 h25 Center BackgroundTrans", "r")
BtnMin.OnEvent("Click", MinimizeWindow)
BtnMax.OnEvent("Click", MaximizeWindow)
BtnClose.OnEvent("Click", CloseWindow)
for button in [BtnMin, BtnMax, BtnClose] {
    SystemHwnds[button.Hwnd] := true
}
sysLine1 := AppearanceAdd(MainGui, "Progress", "x0 y42 w700 h1 Background222222", 0)
SystemHwnds[sysLine1.Hwnd] := true


AppearanceFont(MainGui, "s10 w400 c888888", "Segoe UI")
global HoverTab := []
global TabCtrl  := []
global HoverEffect := []
global GradientButtons := []

;tabs
global Tab3 := []

global DiscordWebhookTab := []
global DiscordBotTab := []
global DiscordBotSettingsOpen := false
;==

global TopPages := ["Tab1", "Farming", "Tab2", "Tab3", "Tab4", "Tab5", "Tab7"]
global TopTabWidth := 92, TopTabPitch := 95
tabNames := ["Main", "Farming", "Record", "(Beta) Party", "Discord", "Settings", "Credits"]

MacroAppearance.baseTabs := tabNames
Loop tabNames.Length {
    i   := A_Index
    xTab := 20 + (i-1) * TopTabPitch
    
    hBg := AppearanceAdd(MainGui, "Progress", "x" xTab " y43 w" TopTabWidth " h34 Hidden Background222222 Disabled")
    HoverTab.Push(hBg)
    SystemHwnds[hBg.Hwnd] := true 
    
    t := AppearanceAdd(MainGui, "Text", "x" xTab " y52 w" TopTabWidth " h22 Center BackgroundTrans", tabNames[i])
    t.OnEvent("Click", SelectTab)
    TabCtrl.Push(t)
    SystemHwnds[t.Hwnd] := true 
}

global TabLine := AppearanceAdd(MainGui, "Progress", "x20 y75 w" TopTabWidth " h2 BackgroundFFFFFF", 0)
SystemHwnds[TabLine.Hwnd] := true 

sysLine2 := AppearanceAdd(MainGui, "Progress", "x0 y77 w700 h1 Background222222", 0)
SystemHwnds[sysLine2.Hwnd] := true

; tab 1 - MAIN ===========================

AppearanceFont(MainGui, "s10 w400 c3A86FF", "Segoe UI")
global Tab1_Section1 := AppearanceAdd(MainGui, "Text", "x30 y95  w200 h22",  "Custom Strategies")
global Tab1_Line1 := AppearanceAdd(MainGui, "Progress", "x30 y118 w640 h1  Background333333", 0)

AppearanceFont(MainGui, "s9 w400 cAAAAAA", "Segoe UI")
global Tab1_Lbl1 := AppearanceAdd(MainGui, "Text", "x30 y130 w100 h20", "Strategy:")
AppearanceFont(MainGui, "s9 w400 c000000")
global Strategy1Ctrl := AppearanceAdd(MainGui, "Edit", "x110 y127 w400 h22 vStrategy1", Strategy1Path)
Strategy1Ctrl.OnEvent("Change", SaveStrat1)
AppearanceFont(MainGui, "s9 w400 cFFFFFF")
global Tab1_Btn1 := AppearanceAdd(MainGui, "Text", "x515 y126 w70 h22 +Border +Border 0x200 Center", "Browse")
Tab1_Btn1.OnEvent("Click", SelectStrat1)
global Tab1_Btn2 := AppearanceAdd(MainGui, "Text", "x590 y126 w70 h22 +Border +Border 0x200 Center", "Clear")
Tab1_Btn2.OnEvent("Click", ClearStrat1)

HoverEffect.Push(Tab1_Btn1) 
HoverEffect.Push(Tab1_Btn2) 

AppearanceFont(MainGui, "s9 w400 cAAAAAA")
global Tab1_Lbl2 := AppearanceAdd(MainGui, "Text", "x30 y160 w100 h20", "Strategy 2:")
AppearanceFont(MainGui, "s9 w400 c000000")
global Strategy2Ctrl := AppearanceAdd(MainGui, "Edit", "x110 y157 w400 h22 vStrategy2", Strategy2Path)
Strategy2Ctrl.OnEvent("Change", SaveStrat2)
AppearanceFont(MainGui, "s9 w400 cFFFFFF")
global Tab1_Btn3 := AppearanceAdd(MainGui, "Text", "x515 y156 w70 h22 +Border +Border 0x200 Center", "Browse")
Tab1_Btn3.OnEvent("Click", SelectStrat2)
global Tab1_Btn4 := AppearanceAdd(MainGui, "Text", "x590 y156 w70 h22 +Border +Border 0x200 Center", "Clear")
Tab1_Btn4.OnEvent("Click", ClearStrat2)

HoverEffect.Push(Tab1_Btn3) 
HoverEffect.Push(Tab1_Btn4) 

AppearanceFont(MainGui, "s9 w400 cFFFFFF")
global RotateStrategiesCtrl := AppearanceAdd(MainGui, "Checkbox", "x30 y190 vRotateStrategies 0x200 Checked" RotateStrategies, "Strategy Rotation")
RotateStrategiesCtrl.OnEvent("Click", EnableStratRotation)

AppearanceFont(MainGui, "s9 w400 cAAAAAA")
global SwapAfterLbl := AppearanceAdd(MainGui, "Text", "x148 y188 w70 h20 0x200 BackgroundTrans", "Swap after:")

AppearanceFont(MainGui, "s9 w400 c000000") 
global SwapAmountCtrl := AppearanceAdd(MainGui, "Edit", "x217 y186 w40 h22 +Border Number Center vSwapAmount", SwapAmount)

SwapAmountCtrl.OnEvent("Change", (*) => (
    IniWrite(SwapAmountCtrl.Text, SettingsFile, "Options", "SwapAmount"),
    SwapAmount := SwapAmountCtrl.Text
))

AppearanceFont(MainGui, "s9 w400 c000000")
global SwapUnitCtrl := AppearanceAdd(MainGui, "DropDownList", "+0x210 x267 y186 w80 Choose" (SwapUnit = "Minutes" ? 2 : 1) " vSwapUnit", [TranslateText("Runs"), TranslateText("Minutes")])

SwapUnitCtrl.OnEvent("Change", (*) => (
    IniWrite(LocalizationSwapUnitValue(SwapUnitCtrl.Value), SettingsFile, "Options", "SwapUnit"),
    SwapUnit := LocalizationSwapUnitValue(SwapUnitCtrl.Value)
    IniWrite(SwapAmountCtrl.Text, SettingsFile, "Options", "SwapAmount")
))

AppearanceFont(MainGui, "s9 w400 cFFFFFF")
global AutoEquipCtrl := AppearanceAdd(MainGui, "Checkbox", "x357 y190 vAutoEquip 0x200 Checked" AutoEquip, "Auto Equip Towers")
AutoEquipCtrl.OnEvent("Click", EnableAutoEquip)

AppearanceFont(MainGui, "s10 w400 c3A86FF", "Segoe UI")
global Tab1_Section2 := AppearanceAdd(MainGui, "Text", "x30 y225 h22", "Community Strategies")
global Tab1_Line2 := AppearanceAdd(MainGui, "Progress", "x30 y248 w640 h1 Background333333", 0)


if !DirExist(StratsDir)
    DirCreate(StratsDir)

LoadedStrats := []
global StrategyCardBackgrounds := []
global FrameX := 30
global FrameY := 260
global FrameW := 640
global FrameH := 220
global ContentH := 400
global CurrentScrollPos := 0
global SliderH := 30
global ChildHwnd := 0

ChildGui := Gui("-Caption +E0x20 +Border +Parent" MainGui.Hwnd)
ChildGui.BackColor := MacroAppearance.Color("secondary", "181818")
AppearanceFont(ChildGui, "s10 cWhite", "Segoe UI")
width := FrameW - 6

Loop Files, StratsDir "\*.strat" {
    localPath := A_LoopFileFullPath
    
    info := ReadBundledStrategyInfo(localPath)
    sMap := IniRead(localPath, "Settings", "map", "")
    sDifficulty := IniRead(localPath, "Settings", "difficulty", "")
    sTowers := IniRead(localPath, "Settings", "requiredTowers", "")
    sDesc := info.Get("desc", "")
    sAuthor := info.Get("author", "")
    sTitle := Trim(info.Get("title", ""))
    if sTitle = ""
        sTitle := RegExReplace(A_LoopFileName, "i)\.strat$")
    sTime := info.Get("time", "")
    sIncome := info.Get("income", "")
    sModifiers := IniRead(localPath, "Settings", "modifiers", "")
    
    LoadedStrats.Push({
        fileName: A_LoopFileName,
        map: sMap,
        difficulty: sDifficulty,
        towers: sTowers,
        desc: sDesc,
        author: sAuthor,
        title: sTitle,
        time: sTime,
        income: sIncome,
        modifiers: sModifiers
    })
}

StartY := 15
CardH  := 115
CardW  := 600
Gap    := 15

ContentH := StartY

for index, strat in LoadedStrats {
    CurrentY := StartY + ((index - 1) * (CardH + Gap))
    ContentH := CurrentY + CardH + Gap 

    C1X := 10
    C1Y := CurrentY

    hFrameBg := CreateFrame(CardW, CardH, 10, "0xFF" MacroAppearance.Color("surface", "161616"),
        "0xFF" MacroAppearance.Color("secondary", "1D1D1D"), "0x62" MacroAppearance.Color("border", "302D2D"))
    frameCtrl := AppearanceAdd(ChildGui, "Picture", "x" C1X " y" C1Y " w" CardW " h" CardH " +BackgroundTrans", "HBITMAP:*" hFrameBg)
    StrategyCardBackgrounds.Push(frameCtrl)

    hIconBg := CreateGradientButton(56, 56, 8, "0xff2f353f", "0xff15171b", "0xff000000", "0x232c3a50", "", "Segoe UI", 10, 1)
    AppearanceAdd(ChildGui, "Picture", "x" (C1X + 10) " y" (C1Y + 30) " w76 h76 +BackgroundTrans", "HBITMAP:*" hIconBg)
    
    diffImg := "Resources/Strats/images/" strat.difficulty ".png"
    if !FileExist(diffImg) {
        LogToConsole("Missing resource file: " diffImg, "Error", 0x1010)
    } else {
        AppearanceAdd(ChildGui, "Picture", "x" (C1X + 20) " y" (C1Y + 40) " h56 w56 +BackgroundTrans", diffImg)
    }

    AppearanceAdd(ChildGui, "Picture", "x" (C1X + 75) " y" (C1Y + 30) " w76 h76 +BackgroundTrans", "HBITMAP:*" hIconBg)
    
    coinsCount := 0
    if RegExMatch(strat.income, "i)([\d,]+)\s*coins", &match) {
        coinsCount := Number(StrReplace(match[1], ","))
    }

    if (strat.difficulty = "Hardcore" || strat.difficulty = "Voidcore") {
        rewardIcon := "Resources/Strats/images/GemsMediumPile.png"
    } else {
        if (coinsCount >= 8000) {
            rewardIcon := "Resources/Strats/images/CoinsSmallChest.png"
        } else if (coinsCount >= 6000) {
            rewardIcon := "Resources/Strats/images/CoinsMediumPile.png"
        } else {
            rewardIcon := "Resources/Strats/images/CoinsSmallPile.png"
        }
    }

    if !FileExist(rewardIcon) {
        LogToConsole("Missing resource file: " rewardIcon, "Error", 0x1010)
    } else {
        AppearanceAdd(ChildGui, "Picture", "x" (C1X + 85) " y" (C1Y + 40) " h56 w56 +BackgroundTrans", rewardIcon)
    }


    AppearanceFont(ChildGui, "s11 Bold cWhite", "Segoe UI")
    AppearanceAdd(ChildGui, "Text", "x" (C1X + 15) " y" (C1Y + 12) " w234 h23 +0x4000 +BackgroundTrans", strat.title)
 
    AppearanceFont(ChildGui, "s9 w500 c7E848E", "Segoe UI")
    helpDl1 := AppearanceAdd(ChildGui, "Text", "x" (C1X + 580) " y" (C1Y + 10) " +BackgroundTrans", "?") 
    helpDl1.OnEvent("Click", ((t, a, r, m, d, earnings, duration) => (*) => StratInfo(t, a, r, m, d, earnings, duration))(
        strat.title, 
        strat.author, 
        strat.towers, 
        (strat.modifiers != "" ? strat.modifiers : "none"), 
        strat.desc, strat.income, strat.time
    ))

    AppearanceFont(ChildGui, "s9 w400 cE2E4E7", "Segoe UI")
    AppearanceAdd(ChildGui, "Text", "x" (C1X + 260) " y" (C1Y + 15) " w307 h17 +0x4000 +BackgroundTrans", (strat.towers != "" ? strat.towers : "None"))

    AppearanceFont(ChildGui, "s9 w400 c7E848E", "Segoe UI")
    lineBreak := InStr(strat.desc, "\n")
    preview := Trim(lineBreak ? SubStr(strat.desc, 1, lineBreak - 1) : strat.desc)
    if preview != ""
        AppearanceAdd(ChildGui, "Text", "x" (C1X + 260) " y" (C1Y + 36) " w325 h18 +0x4000 +BackgroundTrans", preview)

    if (strat.difficulty = "Hardcore") {
        badgeColor1 := "0xFFAB457B", badgeColor2 := "0xFF5C2040"
    } else if (strat.difficulty = "Molten") {
        badgeColor1 := "0xFFE09334", badgeColor2 := "0xFF8F5413"
    } else if (strat.difficulty = "Frost") {
        badgeColor1 := "0xff34a9e0", badgeColor2 := "0xff17559c"
    } else if (strat.difficulty = "Fallen") {
        badgeColor1 := "0xff17559c", badgeColor2 := "0xff351570"
    } else {
        badgeColor1 := "0xb900ff2a", badgeColor2 := "0xff1a5f39"
    }

    hgmMode := CreateGradientButton(102, 28, 3, badgeColor1, badgeColor2, "0x40000000", "0x7effffff", strat.difficulty != "" ? strat.difficulty : "Easy", "Segoe UI", 11, 1)
    AppearanceAdd(ChildGui, "Picture", "x" (C1X + 145) " y" (C1Y + 35) " w102 h28 +BackgroundTrans", "HBITMAP:*" hgmMode)

    AppearanceFont(ChildGui, "s9 w500 c9CA4B0", "Segoe UI")
    if strat.time != ""
        AppearanceAdd(ChildGui, "Text", "x" (C1X + 155) " y" (C1Y + 65) " w202 h18 +0x4000 +BackgroundTrans", "🕒 " strat.time)
    if strat.income != "" {
        compactIncome := RegExReplace(strat.income, "i)^(.*?Coins/h).*\bat 1x.*$", "$1 at 1x")
        AppearanceAdd(ChildGui, "Text", "x" (C1X + 155) " y" (C1Y + (strat.time != "" ? 83 : 69)) " w202 h20 +0x4000 +BackgroundTrans", "⛃ " compactIncome)
    }

    if ((strat.difficulty = "Hardcore" || strat.difficulty = "Voidcore")) {
        hBtnNormal := CreateGradientButton(220, 38, 8, "0xff961ea1", "0xff5f237a", "0x40000000", "0x5dffffff", "Load", "Segoe UI", 14, 1)
        hBtnHover := CreateGradientButton(220, 38, 8, "0xffea00ff", "0xff8d32b7", "0x60000000", "0x5dffffff", "Load", "Segoe UI", 14, 1)
    } else {
        hBtnNormal := CreateGradientButton(220, 38, 8, "0xFF147A6E", "0xFF214B75", "0x40000000", "0x5dffffff", "Load", "Segoe UI", 14, 1)
        hBtnHover := CreateGradientButton(220, 38, 8, "0xFF1CB5A2", "0xFF3272B7", "0x60000000", "0x5dffffff", "Load", "Segoe UI", 14, 1)
    }

    picLoadBtn := AppearanceAdd(ChildGui, "Picture", "x" (C1X + 365) " y" (C1Y + 68) " w220 h38 +BackgroundTrans", "HBITMAP:*" hBtnNormal)

    dl1 := AppearanceAdd(ChildGui, "Text", "x" (C1X + 365) " y" (C1Y + 68) " w220 h38 +BackgroundTrans +0x200 Center", "")
    AppearanceFont(dl1, "cFFFFFF s10 Bold", "Segoe UI")
    
    dl1.StratFile := strat.fileName
    dl1.OnEvent("Click", DownloadStrat)

    dl1.PicControl := picLoadBtn  
    dl1.ImgNormal := hBtnNormal   
    dl1.ImgHover := hBtnHover    
    GradientButtons.Push(dl1) 
}

if (LoadedStrats.Length == 0) {
    AppearanceFont(ChildGui, "s12 c7E848E", "Segoe UI")
    AppearanceAdd(ChildGui, "Text", "x0 y0 w" FrameW " h" FrameH " +BackgroundTrans Center +0x200", "No strategies found.")
    ContentH := 220
}

SliderX := FrameW - 10 
SliderW := 6 

if (ContentH > 0) {
    SliderH := Round(FrameH * (FrameH / ContentH))
    
    if (ContentH <= FrameH) {
        SliderH := FrameH
    } else {
        SliderH := Max(30, SliderH)
    }
    
    if (ContentH > FrameH && CurrentScrollPos > 0) {
        maxScroll := ContentH - FrameH
        scrollPercent := CurrentScrollPos / maxScroll
        sliderPos := Round(scrollPercent * (FrameH - SliderH))
        sliderPos := Max(0, Min(sliderPos, FrameH - SliderH))
    } else {
        sliderPos := 0
    }
    
    hSlider := CreateScrollThumb(SliderW, SliderH, 3, "0xFF6EA7FF", "0xff4076ce", "0xd4d4d4")
    hSliderBG := CreateScrollThumb(SliderW, FrameH, 3, "0xff000000", "0xff000000", "0x000000")
    
    global SliderBG := AppearanceAdd(ChildGui, "Picture", "x" SliderX " y0 w" SliderW " h" FrameH+ContentH " +BackgroundTrans", "HBITMAP:*" hSliderBG)
    global Slider := AppearanceAdd(ChildGui, "Picture", "x" SliderX " y" sliderPos " w" SliderW " h" SliderH " +BackgroundTrans", "HBITMAP:*" hSlider)
    
    SliderBG.Visible := true
    Slider.Visible := true
}

OnMessage(0x0115, OnScroll)
OnMessage(0x020A, OnMouseWheel)


AppearanceFont(MainGui, "s11 w400 cFFFFFF", "Segoe UI")
global Tab1_Start := AppearanceAdd(MainGui, "Text", "x30 y500 w300 h40 Center Background0e0e0f +Border 0x200", "Start (F1)")
Tab1_Start.OnEvent("Click", StartStrategy)
global Tab1_Stop := AppearanceAdd(MainGui, "Text",  "x340 y500 w330 h40 Center Background0e0e0f +Border 0x200", "Stop (F2)")
Tab1_Stop.OnEvent("Click", StopStrategy)

HoverEffect.Push(Tab1_Start)
HoverEffect.Push(Tab1_Stop)


; tab 2 - RECORD ===========================

AppearanceFont(MainGui, "s10 w400 c3A86FF", "Segoe UI")

AppearanceFont(MainGui, "s9 w400 cAAAAAA")
global Tab2_Lbl1 := AppearanceAdd(MainGui, "Text", "x30 y109 w80 h20 Hidden", "Map:")
AppearanceFont(MainGui, "s9 w400 cFFFFFF")
global RecMapsD := AppearanceAdd(MainGui, "DropDownList", "+0x210 x80 y106 w220 Hidden vRecMaps", [ ; WARNING: These are all the supported maps for this macro. If a map is not listed here, it is unsupported
    "Abandoned City", "Area 52", "Autumn Falling", 
    "Badlands II", "Black Spot Exchange", "Candy Valley", "Cataclysm", "Chess Board", 
    "Construction Crazy", "Coral Deep", "Crossroads", "Crystal Cave", 
    "Cyber City", "Dead Ahead", "Derelict Outpost", "Deserted Village", "Dusty Bridges", 
    "Enchanted Forest", "Farm Lands", "Forest Camp", "Forgetten Docks", "Four Seasons", 
    "Fungi Island", "Grass Isle", "Happy Home of Robloxia", "Harbor", "Honey Valley", 
    "Hot Spot", "Iceville", "Infernal Abyss", "Lay By", "Lighthaos", "Marshlands", "Mason Arch", "Medieval Times", "Meltdown", 
    "Midnight Issue", "Moon Base", "Musaceae Kingdom", "Necropolis", "Nether", "Night Station", 
    "Northern Lights", "Outskirts Commune", "Pier Pressure", "Pizza Party", "Polluted Wasteland II", 
    "Portland", "Retro Crossroads", "Retro Lighthouse", "Retro Rocket Arena", "Retro Stained Temple", 
    "Retro The Heights", "Retro Zone", "Rocket Arena", "Ruby Escort", "Sacred Mountains", 
    "Sky Islands", "Simplicity", "Space City", "Spring Fever", "Stained Temple", "Sugar Rush", 
    "The Heavens", "The Heights", "Toyboard", "Tropical Industries", "Tropical Isles", "U-Turn", 
    "Unknown Garden", "Winter Abyss", "Winter Bridges", "Winter Stronghold", "Wrecked Battlefield", 
    "Wrecked Battlefield II", "Wretched Front"
])

AppearanceFont(MainGui, "s9 w400 cAAAAAA")
global Tab2_Lbl2 := AppearanceAdd(MainGui, "Text", "x320 y109 w80 h20 Hidden", "Mode:")
AppearanceFont(MainGui, "s9 w400 cFFFFFF")
global RecDiffCtrl := AppearanceAdd(MainGui, "DropDownList", "+0x210 x380 y106 w220 Hidden vRecDifficulty", [
    "Easy", "Casual", "Intermediate", "Molten", "Fallen", "Frost", 
    "Hardcore", "Voidcore", "Pizza Party", "Badlands II", "Polluted Wasteland II"
])

AppearanceFont(MainGui, "s9 w400 cAAAAAA")
global Tab2_Lbl3 := AppearanceAdd(MainGui, "Text", "x30 y235 w80 h20 Hidden", "Modifiers:")
AppearanceFont(MainGui, "s9 w400 c000000")

AppearanceFont(MainGui, "s9 w400 cAAAAAA", "Segoe UI")

AppearanceFont(MainGui, "s9 w400 cAAAAAA")
global Tab2_Lbl4 := AppearanceAdd(MainGui, "Text", "x30 y149 w80 h20 Hidden", "Towers:")
AppearanceFont(MainGui, "s9 w400 c000000")
global RecTowersCtrl := AppearanceAdd(MainGui, "Edit", "x80 y146 w220 h22 Hidden vRecRequiredTowers", requiredTowers)

AppearanceFont(MainGui, "s9 w400 cAAAAAA", "Segoe UI")
global Tab2_Info1 := AppearanceAdd(MainGui, "Text", "x320 y139 BackgroundTrans Hidden", "Enter towers for your strategy using comma after every tower.`nMinigunner, Ranger, Commander, DJ, Military Base for example.`nType G Whatever if the tower you using NEEDS to be golden.")

AppearanceAdd(MainGui, "Progress", "x360 y232 w320 h1 Hidden Background333333 vTab2_Line2", 0)
global Tab2_Line2 := MainGui["Tab2_Line2"]

AppearanceFont(MainGui, "s9 w400 cFFFFFF", "Segoe UI")
global RecAutoChainCtrl := AppearanceAdd(MainGui, "Checkbox", "x360 y255 Hidden vRecAutoChain Checked" (autoChain="ON"?1:0), "Use Call of Arms")
global RecAutoCaravanCtrl := AppearanceAdd(MainGui, "Checkbox", "x490 y255 Hidden vRecAutoCaravan Checked" (autoCaravan="ON"?1:0), "Use Support Caravan")
global RecAutoDropCtrl := AppearanceAdd(MainGui, "Checkbox", "x360 y275 Hidden vRecAutoDropTheBeat Checked" (autoDropTheBeat="ON"?1:0), "Use Drop the Beat")

AppearanceAdd(MainGui, "Progress", "x360 y300 w320 h1 Hidden Background333333 vTab2_Line3", 0)
global Tab2_Line3 := MainGui["Tab2_Line3"]
global RecAutoSkipCtrl := AppearanceAdd(MainGui, "Checkbox", "x360 y315 h20 Hidden vRecAutoSkip", "Auto Skip Waves")
global RecAbilitySpamCtrl := AppearanceAdd(MainGui, "Checkbox", "x490 y315 h20 Hidden vRecAbilitySpam", "Abilities Spam")
RecAutoSkipCtrl.OnEvent("Click", RecordToggleAutoskip)

global RecMoveCtrl := AppearanceAdd(MainGui, "Checkbox", "x30 y452 w60 h20 Hidden vRecMoveEnabled Checked" (MoveEnabled?1:0), "Move")
AppearanceFont(MainGui, "s9 w400 cAAAAAA")
global DIRECTIONTEXTCtrl := AppearanceAdd(MainGui, "Text", "x100 y452 w45 Hidden", "Direction")
AppearanceFont(MainGui, "s9 w400 cFFFFFF")
global RecMoveDirCtrl := AppearanceAdd(MainGui, "DropDownList", "+0x210 x160 y450 w45 Hidden Choose1 vRecMoveDirection", ["W", "A", "S", "D"])
AppearanceFont(MainGui, "s9 w400 cAAAAAA")
global Tab2_Txt4 := AppearanceAdd(MainGui, "Text", "x220 y452 Hidden", "Duration (ms):")
AppearanceFont(MainGui, "s9 w400 c000000")
global RecMoveDurCtrl := AppearanceAdd(MainGui, "Edit", "x310 y450 w50 h22 Hidden Number Limit5 vRecMoveDuration", 1000)

AppearanceFont(MainGui, "s11 w400 cFFFFFF", "Segoe UI")
global Tab2_Btn1 := AppearanceDarkButton(MainGui, "x505 y502 w171 h32 Hidden", "Start Recording", true)
Tab2_Btn1.OnEvent("Click", StartRecording)
AppearanceFont(MainGui, "s11 w400 c808080", "Segoe UI")
global Tab2_Btn2 := AppearanceDarkButton(MainGui, "x393 y502 w100 h32 Hidden", "Stop")
Tab2_Btn2.OnEvent("Click", StopRecord)


; tab 3 - MULTIPLAYER ===========================

AppearanceFont(MainGui, "s10 w400 c3A86FF", "Segoe UI")
global Tab3_Title := AppearanceAdd(MainGui, "Text", "x30 y95  w200 h22 Hidden", "Usernames")
global Tab3_Line1 := AppearanceAdd(MainGui, "Progress", "x30 y118 w640 h1 Hidden Background333333", 0)

AppearanceFont(MainGui, "s9 w400 cAAAAAA")
global Tab3_HostNm := AppearanceAdd(MainGui, "Text", "x30 y140 w170 BackgroundTrans h20 Hidden", "Host Username:")
AppearanceFont(MainGui, "s9 w400 c000000")
global Tab3_HostNm_EDIT := AppearanceAdd(MainGui, "Edit", "x130 y137 w540 Hidden vHostName", HostName)

AppearanceFont(MainGui, "s9 w400 cAAAAAA")
global Tab3_PartyMemb := AppearanceAdd(MainGui, "Text", "x30 y175 w165 BackgroundTrans h20 Hidden", "Party Members:")
AppearanceFont(MainGui, "s9 w400 c000000")
global Tab3_PartyMemb_Edit := AppearanceAdd(MainGui, "Edit", "x130 y168 w540 Hidden vPartyMembersStr", PartyMembers)

AppearanceFont(MainGui, "s10 w400 c3A86FF", "Segoe UI")
global Tab3_Title2 := AppearanceAdd(MainGui, "Text", "x30 y201  w200 h22 Hidden", "Settings")
global Tab3_Line2 := AppearanceAdd(MainGui, "Progress", "x30 y224 w640 h1 Hidden Background333333", 0)

AppearanceFont(MainGui, "s9 w400 cffffff")
global Tab3_RoleTxt := AppearanceAdd(MainGui, "Text", "x30 y240 w60 BackgroundTrans h20 Hidden", "You are:")

global Tab3_Role_Host := MacroPartyRadio(MainGui, 30, 260, 47, "Host", "vPlayerRole Group", PlayerRole != "Member")
global Tab3_Role_Member := MacroPartyRadio(MainGui, 105, 260, 80, "Member", "", PlayerRole = "Member")

global Tab3_LConditionTxt := AppearanceAdd(MainGui, "Text", "x30 y290 w170 BackgroundTrans h20 Hidden", "Go back to lobby if:")

global Tab3_LCondition_All := MacroPartyRadio(MainGui, 30, 310, 145, "All members are gone", "vLeaveCondition Group", LeaveCondition = "All")
global Tab3_LCondition_Any := MacroPartyRadio(MainGui, 205, 310, 145, "Any member is gone", "", LeaveCondition = "Any")

AppearanceFont(MainGui, "s10 w400 cFFFFFF")
global MultiplayerEnabledTGL := AppearanceAdd(MainGui, "Checkbox", "x30 y368 Hidden vMultiplayerEnabled Checked" MultiplayerEnabled, "Enabled")
global Tab3_Line3 := AppearanceAdd(MainGui, "Progress", "x30 y360 w640 h1 Hidden Background333333", 0)

AppearanceFont(MainGui, "s11 w400 cFFFFFF")
PartyAutosaveInit()



AppearanceFont(MainGui, "s9 w400 cFFFFFF")
global Tab3_Info := AppearanceAdd(MainGui, "Text", "x30 y400 w640 h100 Hidden", "The macro can now run simultaneously with other users. Just enter the host's username and the party members.`nHow to use:`n1. Enter the party leader's username in 'Host Username'.`n2. Enter other players' display names in 'Party Members' (separated by commas).`n3. Click 'Save all settings'.")

TAB3.Push(Tab3_Title, Tab3_Line1, Tab3_HostNm, Tab3_HostNm_EDIT, Tab3_PartyMemb, Tab3_PartyMemb_Edit, Tab3_Line2, Tab3_Info, MultiplayerEnabledTGL, Tab3_RoleTxt, Tab3_Role_Host, Tab3_Role_Member, Tab3_Title2, Tab3_Line3, Tab3_LCondition_All, Tab3_LCondition_Any, Tab3_LConditionTxt, Tab3_Role_Host.CaptionCtrl, Tab3_Role_Member.CaptionCtrl, Tab3_LCondition_All.CaptionCtrl, Tab3_LCondition_Any.CaptionCtrl)

; tab 4 - WEBHOOK ===========================

AppearanceFont(MainGui, "s10 w400 c3A86FF", "Segoe UI")
DiscordPageBuild(MainGui)

;TAB 5 - SETTINGS ==========================

AppearanceFont(MainGui, "s10 w400 c3A86FF", "Segoe UI")
global Tab5_Section1 := AppearanceAdd(MainGui, "Text", "x30 y95  w200 h22 Hidden", "TDS Keybinds")
global Tab5_Line1 := AppearanceAdd(MainGui, "Progress", "x30 y118 w250 h1  Hidden Background333333", 0)

AppearanceFont(MainGui, "s8 w400 cAAAAAA", "Segoe UI")
global Tab5_Lbl1 := AppearanceAdd(MainGui, "Text", "x30 y135 w70 h16 Hidden", "Call of Arms:")
AppearanceFont(MainGui, "s8 w400 c000000")
global ChainKeyCtrl := AppearanceAdd(MainGui, "Edit", "x105 y132 w40 h18 Center Limit1 Hidden", ChainKey)

AppearanceFont(MainGui, "s8 w400 cAAAAAA")
global Tab5_Lbl2 := AppearanceAdd(MainGui, "Text", "x152 y135 w80 h16 Hidden", "Drop The Beat:")
AppearanceFont(MainGui, "s8 w400 c000000")
global BeatKeyCtrl := AppearanceAdd(MainGui, "Edit", "x238 y132 w40 h18 Center Limit1 Hidden", BeatKey)

AppearanceFont(MainGui, "s8 w400 cAAAAAA")
global Tab5_Lbl3 := AppearanceAdd(MainGui, "Text", "x30 y160 h16 Hidden", "S. Caravan:")
AppearanceFont(MainGui, "s8 w400 c000000")
global CaravanKeyCtrl := AppearanceAdd(MainGui, "Edit", "x105 y157 w40 h18 Center Limit1 Hidden", CaravanKey)

AppearanceFont(MainGui, "s8 w400 cAAAAAA")
global Tab5_Lbl44 := AppearanceAdd(MainGui, "Text", "x152 y160 w80 h16 Hidden", "Raise the Dead:")
AppearanceFont(MainGui, "s8 w400 c000000")
global RaiseDeadKeyCtrl := AppearanceAdd(MainGui, "Edit", "x238 y157 w40 h18 Center Limit1 Hidden", RaiseDeadKey)
AppearanceFont(MainGui, "s9 w400 cFFFFFF", "Segoe UI")
global Tab5_Help12 := AppearanceAdd(MainGui, "Text", "x280 y157 w18 h18 0x200 Center Hidden", "?")
Tab5_Help12.OnEvent("Click", HelpRaise)

AppearanceFont(MainGui, "s8 w400 cAAAAAA")
global Tab5_Lbl55 := AppearanceAdd(MainGui, "Text", "x30 y185 h16 Hidden", "Hologram:")
AppearanceFont(MainGui, "s8 w400 c000000")
global HologramKeyCtrl := AppearanceAdd(MainGui, "Edit", "x105 y182 w40 h18 Center Limit1 Hidden", HologramKey)

AppearanceFont(MainGui, "s8 w400 cAAAAAA")
global Tab5_Lbl56 := AppearanceAdd(MainGui, "Text", "x152 y185 h16 Hidden", "Reposition:")
AppearanceFont(MainGui, "s8 w400 c000000")
global RepoKeyCtrl := AppearanceAdd(MainGui, "Edit", "x238 y182 w40 h18 Center Limit1 Hidden", RepoKey)
AppearanceFont(MainGui, "s9 w400 cFFFFFF", "Segoe UI")
global Tab5_Help11 := AppearanceAdd(MainGui, "Text", "x280 y182 w18 h18 0x200 Center Hidden", "?")
Tab5_Help11.OnEvent("Click", HelpBrawler)

AppearanceFont(MainGui, "s9 w400 cAAAAAA")
global Tab5_Lbl99 := AppearanceAdd(MainGui, "Text", "x183 y248 BackgroundTrans Hidden", "cancel:")
AppearanceFont(MainGui, "s8 w400 c000000")
global CancelPlacementKeyCtrl := AppearanceAdd(MainGui, "Edit", "x230 y248 w17 h17 Center Limit1 Hidden", CancelPlacementKey)

AppearanceFont(MainGui, "s9 w400 cAAAAAA")
global Tab5_LblUPG := AppearanceAdd(MainGui, "Text", "x30 y248 BackgroundTrans Hidden", "upgrade:")
AppearanceFont(MainGui, "s8 w400 c000000")
global UpgradeTowerGCtrl := AppearanceAdd(MainGui, "Edit", "x85 y248 w17 h17 Center Limit1 Hidden", UpgradeTowerGKey)

AppearanceFont(MainGui, "s9 w400 cAAAAAA")
global Tab5_LblUPGBTM := AppearanceAdd(MainGui, "Text", "x108 y248 BackgroundTrans Hidden", "bottom:")
AppearanceFont(MainGui, "s8 w400 c000000")
global UpgradeTowerGBCtrl := AppearanceAdd(MainGui, "Edit", "x158 y248 W17 h17 Center Limit1 Hidden", UpgradeTowerGBKey)

AppearanceFont(MainGui, "s9 w400 cFFFFFF")

AppearanceFont(MainGui, "s10 w400 c3A86FF", "Segoe UI")
global Tab5_Section2 := AppearanceAdd(MainGui, "Text", "x310 y95  w200 h22 Hidden BackgroundTrans", "Macro Settings")
global Tab5_Line2    := AppearanceAdd(MainGui, "Progress", "x310 y118 w360 h1  Hidden Background333333", 0)

AppearanceFont(MainGui, "s9 w400 cFFFFFF", "Segoe UI")
global UseUpgradeHCtrl := AppearanceAdd(MainGui, "Checkbox", "x310 y135 Hidden", "Use Hotkeys for Upgrading")
UseUpgradeHCtrl.Value := (UseHForUpgrade = 1)
global Tab5_Help6 := AppearanceAdd(MainGui, "Text", "x475 y135 w18 h18 0x200 Center Hidden", "?")
Tab5_Help6.OnEvent("Click", HelpAutoCameraCorrection)

global UseRestartBtnCtrl := AppearanceAdd(MainGui, "Checkbox", "x310 y160 Hidden", "Click Restart button")
UseRestartBtnCtrl.Value := (UseRestartBtn = "1" || UseRestartBtn = 1)
global Tab5_Help4 := AppearanceAdd(MainGui, "Text", "x475 y158 w18 h18 0x200 Center Hidden", "?")
Tab5_Help4.OnEvent("Click", HelpRestartBtn)

global UsePlayAgainBtnCtrl := AppearanceAdd(MainGui, "Checkbox", "x310 y185 Hidden", "Click Play Again button")
UsePlayAgainBtnCtrl.Value := (UsePlayAgainBtn = "1" || UsePlayAgainBtn = 1)
global Tab5_Help5 := AppearanceAdd(MainGui, "Text", "x475 y183 w18 h18 0x200 Center Hidden", "?")
Tab5_Help5.OnEvent("Click", HelpPlayAgainBtn)

global CheckTheMapCtrl := AppearanceAdd(MainGui, "Checkbox", "x310 y210 Hidden", "Check the map")
CheckTheMapCtrl.Value := (CheckTheMap = "1" || CheckTheMap = 1)
global Tab5_Help7 := AppearanceAdd(MainGui, "Text", "x475 y207 w18 h18 0x200 Center Hidden", "?")
Tab5_Help7.OnEvent("Click", HelpCheckTheMap)

global UseNumbersForHotbarCtrl := AppearanceAdd(MainGui, "Checkbox", "x310 y235 Hidden", "Use Numbers for Hotbar")
UseNumbersForHotbarCtrl.Value := (UseNumbersForHotbar = "1" || UseNumbersForHotbar = 1)

global AutoCloseChatCtrl := AppearanceAdd(MainGui, "Checkbox", "x554 y130 Hidden", "Auto Close Chat")
global CollectPlaytimeRewardsCtrl := AppearanceAdd(MainGui, "Checkbox", "x510 y193 Hidden", "Collect playtime rewards")
CollectPlaytimeRewardsCtrl.Value := (CollectPlaytimeRewards = 1)
AutoCloseChatCtrl.Value := (AutoCloseChat = 1)

global DebugConsoleCtrl := AppearanceAdd(MainGui, "Checkbox", "x570 y152 Hidden", "Debug Logs")
DebugConsoleCtrl.Value := (DebugConsole = "1" || DebugConsole = 1)

global PotatoModeCtrl := AppearanceAdd(MainGui, "Checkbox", "x570 y172 Hidden", "Potato Mode")
PotatoModeCtrl.Value := (PotatoMode = 1)

AppearanceFont(MainGui, "s9 w400 cAAAAAA")
global Tab1_Lbl3 := AppearanceAdd(MainGui, "Text", "x530 y220 w100 h20 Hidden BackgroundTrans", "Timescale:")
global TimeScaleModeCtrl := AppearanceAdd(MainGui, "DropDownList", "+0x210 x595 y216 w80 Hidden", [TranslateText("OFF"),"1.5x","2x"])
TimeScaleModeCtrl.Choose(LocalizationTimeScaleIndex(TimeScaleMode))

AppearanceFont(MainGui, "s9 w400 cAAAAAA")
global Tab1_Lbl4 := AppearanceAdd(MainGui, "Text", "x505 y245 w100 h20 Hidden BackgroundTrans", "Upgrade Delay:")
AppearanceFont(MainGui, "s8 w400 c000000")
global UpgradeDelayCtrl := AppearanceAdd(MainGui, "Edit", "x595 y241 w80 Hidden Number Limit3 vUpgradeDelay", UpgradeDelay)
UpgradeDelayCtrl.Text := UpgradeDelay

AppearanceFont(MainGui, "s9 w400 cFFFFFF")
global MouseSpeedLbl := AppearanceAdd(MainGui, "Text", "x310 y270 w110 h20 Hidden BackgroundTrans", "Mouse Speed:")
global MouseSpeedTxt := AppearanceAdd(MainGui, "Text", "x389 y270 w26 Hidden", DefaultMouseSpeed)
global MouseSpeedUpDown := AppearanceAdd(MainGui, "UpDown", "Range1-3 Hidden", DefaultMouseSpeed)
MouseSpeedUpDown.OnEvent("Change", (ctrl, *) => MouseSpeedTxt.Value := ctrl.Value)

global MouseDelayLbl := AppearanceAdd(MainGui, "Text", "x435 y270 w90 h20 Hidden BackgroundTrans", "Mouse Delay:")
global MouseDelayTxt := AppearanceAdd(MainGui, "Text", "x509 y270 w32 Hidden", MouseDelay)
global MouseDelayUpDown := AppearanceAdd(MainGui, "UpDown", "Range-1-75 Hidden", MouseDelay)
MouseDelayUpDown.OnEvent("Change", (ctrl, *) => MouseDelayTxt.Value := ctrl.Value)

global KeyDelayLbl := AppearanceAdd(MainGui, "Text", "x565 y270 w90 h20 Hidden BackgroundTrans", "Key Delay:")
global KeyDelayTxt := AppearanceAdd(MainGui, "Text", "x625 y270 w32 Hidden", KeyDelay)
global KeyDelayUpDown := AppearanceAdd(MainGui, "UpDown", "Range-1-100 Hidden", KeyDelay)
KeyDelayUpDown.OnEvent("Change", (ctrl, *) => KeyDelayTxt.Value := ctrl.Value)

AppearanceFont(MainGui, "s10 w400 c3A86FF", "Segoe UI")
global Tab5_Section3 := AppearanceAdd(MainGui, "Text", " BackgroundTrans x30 y272 w200 h22 Hidden", "Recording Hotkeys")
global Tab5_Line3    := AppearanceAdd(MainGui, "Progress", "x30 y295 w640 h1  Hidden Background333333", 0)

AppearanceFont(MainGui, "s9 w400 cAAAAAA")
global PlcTowerTEXT := AppearanceAdd(MainGui, "Text", "x30 y304 w95 h20 Hidden", "Place Tower:")
global PlaceTowerKeyCtrl := AppearanceAdd(MainGui, "Hotkey", "x130 y304 w110 h20 Center Hidden", PlaceTowerKey)

global UpgTowerTEXT := AppearanceAdd(MainGui, "Text", "x30 y334 w95 h20 Hidden", "Upgrade Tower:")
global UpgradeTowerKeyCtrl := AppearanceAdd(MainGui, "Hotkey", "x130 y334 w110 h20 Center Hidden", UpgradeTowerKey)

global AlignCamTEXT := AppearanceAdd(MainGui, "Text", "x30 y366 w95 h20 Hidden", "Align Camera:")
global AlignCameraKeyCtrl := AppearanceAdd(MainGui, "Hotkey", "x130 y366 w110 h20 Center Hidden", AlignCameraKey)

global DjTrackTEXT := AppearanceAdd(MainGui, "Text", "x255 y304 w95 h20 Hidden", "Change DJ Track:")
global ChangeDJTrackKeyCtrl := AppearanceAdd(MainGui, "Hotkey", "x355 y304 w110 h20 Center Hidden", ChangeDJTrackKey)

global SellTowTEXT := AppearanceAdd(MainGui, "Text", "x255 y334 w95 h20 Hidden", "Sell Tower:")
global SellTowerKeyCtrl := AppearanceAdd(MainGui, "Hotkey", "x355 y334 w110 h20 Center Hidden", SellTowerKey)

global DelRecTEXT := AppearanceAdd(MainGui, "Text", "x255 y366 w95 h20 Hidden", "Delete Record:")
global DeleteTowerRecordingKeyCtrl := AppearanceAdd(MainGui, "Hotkey", "x355 y366 w110 h20 Center Hidden", DeleteTowerRecordingKey)

global RecInputsTEXT := AppearanceAdd(MainGui, "Text", "x480 y304 w95 h20 Hidden", "Record Inputs:")
global RecordInputsKeyCtrl := AppearanceAdd(MainGui, "Hotkey", "x580 y304 w90 h20 Center Hidden", RecordInputsKey)

global HoloTEXT := AppearanceAdd(MainGui, "Text", "x480 y334 w95 h20 Hidden", "Hologram Tower:")
global HoloKeyCtrl := AppearanceAdd(MainGui, "Hotkey", "x580 y334 w90 h20 Center Hidden", HoloKey)

global RaiseDeadTEXT := AppearanceAdd(MainGui, "Text", "x480 y366 w95 h20 Hidden", "Change Targets:")
global ChangeTargetsCTRL := AppearanceAdd(MainGui, "Hotkey", "x580 y366 w90 h20 Center Hidden", ChangeTargetsKey)

global Tab5_Line4 := AppearanceAdd(MainGui, "Progress", "x30 y393 w640 h1 Hidden Background333333", 0)

AppearanceFont(MainGui, "s9 w400 cAAAAAA")
global Tab5_Lbl4 := AppearanceAdd(MainGui, "Text", "x30 y405 w100 h20 Hidden", "VIP Server")
AppearanceFont(MainGui, "s9 w400 c000000")
global VipLinkCtrl := AppearanceAdd(MainGui, "Edit", "x30 y430 w640 h24 Hidden", VipLink)
AppearanceFont(MainGui, "s11 w400 cFFFFFF")

AppearanceFont(MainGui, "s9 w400 cAAAAAA", "Segoe UI")
global LanguageLbl := AppearanceAdd(MainGui, "Text", "x395 y405 w60 h20 Hidden", "Language:")
global LanguageCtrl := AppearanceAdd(MainGui, "DropDownList", "x455 y402 w210 Hidden", LocalizationLanguageOptions())
LanguageCtrl.Text := LocalizationPreferenceName()
LanguageCtrl.OnEvent("Change", LocalizationSaveChoice)
AppearanceFont(MainGui, "s11 w400 cFFFFFF")

global UseVipServerCtrl := AppearanceAdd(MainGui, "Checkbox", "x30 y465 Hidden", "Use VIP Server")
UseVipServerCtrl.Value := (UseVipServer = "1" || UseVipServer = 1)

global AlwaysOnTopCtrl := AppearanceAdd(MainGui, "Checkbox", "x160 y465 Hidden", "Always On Top")
AlwaysOnTopCtrl.Value := (AlwaysOnTop = "1" || AlwaysOnTop = 1)

global LegacyModeCtrl := AppearanceAdd(MainGui, "Checkbox", "x560 y465 Hidden", "Legacy Mode")
LegacyModeCtrl.Value := (LegacyMode = "1" || LegacyMode = 1)

AppearanceFont(MainGui, "s11 w400 cFFFFFF")
SettingsPageInit()

; tab 7 - credits ===========================

global CreditMode := "Contributors", CreditPage := 1
global CreditCards := [], CreditControls := [], CreditHoverDetails := Map()

AppearanceFont(MainGui, "s18 bold cFFFFFF", "Segoe UI")
global Credit_TITLE := AppearanceAdd(MainGui, "Text", "x30 y95 w640 h28 Hidden Center", "Ultimate Macro")
AppearanceFont(MainGui, "s11 bold c3A86FF", "Segoe UI")
global Credit_Content := AppearanceAdd(MainGui, "Text", "x30 y124 w640 h20 Hidden Center BackgroundTrans", "made by Darksen")

global Credit_Divider := AppearanceAdd(MainGui, "Progress", "x40 y151 w620 h2 Hidden Center Background333333", 0)
; Keep the panel background clear of the page buttons so it cannot intercept clicks.
global Credit_InfoBG := AppearanceAdd(MainGui, "Progress", "x20 y183 w660 h230 Hidden Disabled Background1B1B1B", 0)
AppearanceFont(MainGui, "s9 w400 cAAAAAA", "Segoe UI")
global Credit_Info := AppearanceAdd(MainGui, "Text", "x30 y185 w640 h22 Hidden Center BackgroundTrans", "")

AppearanceFont(MainGui, "s10 bold cFFFFFF", "Segoe UI")
global CreditContributorsTab := AppearanceDarkButton(MainGui, "x30 y157 w145 h24 Hidden", "Contributors")
global CreditSupportersTab := AppearanceDarkButton(MainGui, "x180 y157 w145 h24 Hidden", "Supporters")
CreditContributorsTab.OnEvent("Click", CreditsShowContributors)
CreditSupportersTab.OnEvent("Click", CreditsShowSupporters)
global CreditModeIndicator := AppearanceAdd(MainGui, "Progress", "x30 y181 w145 h2 Hidden Background3A86FF", 0)
CreditControls.Push(CreditContributorsTab, CreditSupportersTab, CreditModeIndicator, Credit_InfoBG, Credit_Info)

AppearanceFont(MainGui, "s10 w400 cE7EDF8", "Segoe UI")
Loop 10 {
    slot := A_Index - 1
    x := 30 + Mod(slot, 2) * 320
    y := 214 + Floor(slot / 2) * 40
    card := AppearanceAdd(MainGui, "Text", "Hidden x" x " y" y " w300 h34 Center 0x200 Background202020", "")
    CreditCards.Push(card)
    CreditControls.Push(card)
}

AppearanceFont(MainGui, "s9 w400 cAAAAAA", "Segoe UI")
global CreditPrev := AppearanceDarkButton(MainGui, "x225 y418 w90 h24 Hidden", "Previous page")
global CreditPageText := AppearanceAdd(MainGui, "Text", "x315 y418 w70 h24 Hidden Center 0x200 BackgroundTrans", "")
global CreditNext := AppearanceDarkButton(MainGui, "x385 y418 w90 h24 Hidden", "Next page")
CreditPrev.OnEvent("Click", CreditsPreviousPage)
CreditNext.OnEvent("Click", CreditsNextPage)
CreditControls.Push(CreditPrev, CreditPageText, CreditNext)

AppearanceFont(MainGui, "s10 italic cFFFFFF", "Segoe UI")
global Credit_Support := AppearanceAdd(MainGui, "Link", "x30 y455 w640 h38 Hidden Center", "
(
You can *support* me and the macro with <a href="https://www.donationalerts.com/r/darksen1">real money</a> or with <a href="https://www.roblox.com/games/115405526400244/Raise-an-Onett">robux (press donations button when you joined)</a>.
I truly appreciate any support!
)")

global Divider := AppearanceAdd(MainGui, "Progress", "x0 y500 w700 h1 Hidden Background222222", 0)
global FooterBg := AppearanceAdd(MainGui, "Progress", "x0 y501 w700 h64 Disabled Hidden Background0f0f0f", 0)

AppearanceFont(MainGui, "s10 italic cFFFFFF", "Segoe UI")
global version_text := AppearanceAdd(MainGui, "Text", "x30 y520 +0x80 BackgroundTrans Hidden", "1.3.3b-final made by darksen & UM developers")

global githubImg := AppearanceAdd(MainGui, "Picture", "x580 y520 w24 h-1 Hidden BackgroundTrans", "Resources\github.png")
githubImg.OnEvent("Click", githubLink)
global DiscordImg := AppearanceAdd(MainGui, "Picture", "x611 y520 w24 h-1 Hidden BackgroundTrans", "Resources\discord.png")
DiscordImg.OnEvent("Click", DiscordLink)
global YoutubeImg := AppearanceAdd(MainGui, "Picture", "x642 y520 w24 h-1 Hidden BackgroundTrans", "Resources\youtube.png")
YoutubeImg.OnEvent("Click", YouTubeLink)

global AppearanceLink := AppearanceDarkButton(MainGui, "x280 y400 w110 h24 Hidden", "Appearance")
AppearanceLink.OnEvent("Click", AppearanceOpen)
SettingsLayout()
RecordPageBuild(MainGui)

MainGui.Title := "Ultimate Macro"
A_TrayMenu.Add(TranslateText("Farming settings"), BatchFarmingSettings)
FarmingBuild(MainGui)
FarmingLoad()
LocalizationApplyGui(MainGui)
ApplyMacroDarkControls(MainGui)
MainGui.OnEvent("Size", MacroResizeTitle)
MainGui.Show("w700 h565")

if (AlwaysOnTop = 1) {
    MainGui.Opt("+AlwaysOnTop")
} else {
    MainGui.Opt("-AlwaysOnTop")
}

SetTimer(() => RemoveInitialFocus(), -50)

global CurrentTab := "Tab1"
AppearanceFont(TabCtrl[1], "cFFFFFF")
ShowTabContent("Tab1")
EnableStratRotation()
MacroAppearance.Wording()
MacroAppearance.QueuePaint()

SetTimer(Hoverwatchdog, 10)

OnMessage(0x0201, WM_LBUTTONDOWN_Drag)

RemoveInitialFocus() {
    if !WinActive("ahk_id " MainGui.Hwnd)
        return
    ControlFocus(GuiTitleCtrl, "ahk_id " MainGui.Hwnd)
}

~F1:: StartStrategy(0, 0)
~F2:: StopStrategy(0, 0)

SelectTab(ctrl, *) {
    global CurrentTab
    for index, item in TabCtrl {
        if item != ctrl
            continue
        newTab := TopPages[index]
        if newTab = CurrentTab
            return
        Critical("On")
        hwnd := MainGui.Hwnd
        DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0xB, "Ptr", 0, "Ptr", 0, "Ptr") ; WM_SETREDRAW
        try {
            for old in TabCtrl
                AppearanceFont(old, "c888888")
            HideAllTabContent()
            CurrentTab := newTab
            AppearanceFont(ctrl, "cFFFFFF")
            TabLine.Move(20 + (index - 1) * TopTabPitch, , TopTabWidth)
            ShowTabContent(newTab)
            MacroAppearance.TabOpened(newTab)
            MacroAppearance.QueuePaint()
        } finally {
            DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0xB, "Ptr", 1, "Ptr", 0, "Ptr")
            FarmRedraw()
            Critical("Off")
        }
        return
    }
}

Hoverwatchdog(*) {
    if MacroClosing
        return
    static hClose := 0, hMin := 0, hMain := 0, hChild := 0
    static hoverClose := false, hoverMin := false, hoverTabs := []
    static creditHoverHwnd := 0
    global CreditHoverDetails
    while hoverTabs.Length < HoverTab.Length {
        hoverTabs.Push(false)
    }
    static activeHoverHwnd := 0
    static activeGradHwnd := 0 
    
    if (!hMain)
        hMain := MainGui.Hwnd
        
    if (!hChild && IsSet(ChildGui))
        hChild := ChildGui.Hwnd
    
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

    if (mouseWin = hMain && CreditHoverDetails.Has(mouseCtrl)) {
        if (creditHoverHwnd != mouseCtrl) {
            ToolTip(CreditHoverDetails[mouseCtrl], screenX + 14, screenY + 18)
            creditHoverHwnd := mouseCtrl
        }
    } else if creditHoverHwnd {
        ToolTip()
        creditHoverHwnd := 0
    }
    
    if (mouseWin != hMain && mouseWin != hChild) {
        Loop HoverTab.Length {
            if (hoverTabs[A_Index]) {
                HoverTab[A_Index].Visible := false
                if (CurrentTab != TopPages[A_Index])
                    AppearanceFont(TabCtrl[A_Index], "c888888")
                hoverTabs[A_Index] := false
            }
        }
        if (hoverClose) { 
            AppearanceFont(BtnClose, "cFFFFFF")
            hoverClose := false 
        }
        if (hoverMin) { 
            AppearanceFont(BtnMin, "cFFFFFF")
            hoverMin := false 
        }
        
        if (activeHoverHwnd != 0 && IsSet(HoverEffect)) {
            for ctrl in HoverEffect {
                if (ctrl.Hwnd = activeHoverHwnd) {
                    if RegExMatch(ctrl.name, "i)Title") {
                        AppearanceOpt(ctrl, "BackgroundTrans")
                        AppearanceFont(ctrl, "c3A86FF Norm")
                    } else {
                        AppearanceOpt(ctrl, "Background0E0E0F")
                        AppearanceFont(ctrl, "cFFFFFF Norm")
                    }
                    ctrl.Redraw()
                    break
                }
            }
            activeHoverHwnd := 0
        }
        
        if (activeGradHwnd != 0 && IsSet(GradientButtons)) {
            for ctrl in GradientButtons {
                if (ctrl.Hwnd = activeGradHwnd) {
                    if (HasProp(ctrl, "PicControl"))
                        ctrl.PicControl.Value := "HBITMAP:*" ctrl.ImgNormal
                    ctrl.Redraw()
                    break
                }
            }
            activeGradHwnd := 0
        }
        return
    }
    
    if (!hClose) {
        hClose := BtnClose.Hwnd
        hMin := BtnMin.Hwnd
    }
    
    if (mouseCtrl = hClose) {
        if (!hoverClose) { 
            AppearanceFont(BtnClose, "cFF4D4D")
            hoverClose := true 
        }
    } else if (hoverClose) { 
        AppearanceFont(BtnClose, "cFFFFFF")
        hoverClose := false 
    }

    if (mouseCtrl = hMin) {
        if (!hoverMin) { 
            AppearanceFont(BtnMin, "c3A86FF")
            hoverMin := true 
        }
    } else if (hoverMin) { 
        AppearanceFont(BtnMin, "cFFFFFF")
        hoverMin := false 
    }
    
    Loop HoverTab.Length {
        hTab := TabCtrl[A_Index].Hwnd
        if (mouseCtrl = hTab) {
            if (!hoverTabs[A_Index]) {
                HoverTab[A_Index].Visible := true
                AppearanceFont(TabCtrl[A_Index], "cFFFFFF")
                hoverTabs[A_Index] := true
            }
        } else if (hoverTabs[A_Index]) {
            if (CurrentTab != TopPages[A_Index]) {
                HoverTab[A_Index].Visible := false
                AppearanceFont(TabCtrl[A_Index], "c888888")
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
                                    AppearanceOpt(oldCtrl, "BackgroundTrans")
                                    AppearanceFont(oldCtrl, "c3A86FF Norm")
                                } else {
                                    AppearanceOpt(oldCtrl, "Background0E0E0F")
                                    AppearanceFont(oldCtrl, "cFFFFFF Norm")
                                }
                                oldCtrl.Redraw()
                                break
                            }
                        }
                    }
                    AppearanceOpt(ctrl, "Background222222")
                    AppearanceFont(ctrl, "c3A86FF Bold")
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
                        AppearanceOpt(ctrl, "BackgroundTrans")
                        AppearanceFont(ctrl, "c3A86FF Norm")
                    } else {
                        AppearanceOpt(ctrl, "Background0E0E0F")
                        AppearanceFont(ctrl, "cFFFFFF Norm")
                    }
                    ctrl.Redraw()
                    break
                }
            }
            activeHoverHwnd := 0
        }
    }

    
    if (IsSet(GradientButtons) && hChild) {
        matchedGrad := false
        
        try {
            WinGetPos(&chX, &chY,,, "ahk_id " hChild)
            childMouseX := screenX - chX
            childMouseY := screenY - chY
        } catch {
            childMouseX := 0
            childMouseY := 0
        }
        
        for ctrl in GradientButtons {
            if (!ctrl.Visible)
                continue

            ctrl.GetPos(&cX, &cY, &cW, &cH)
            
            if (childMouseX >= cX && childMouseX <= cX + cW && childMouseY >= cY && childMouseY <= cY + cH) {
                matchedGrad := true
                if (activeGradHwnd != ctrl.Hwnd) {
                    
                    if (activeGradHwnd != 0) {
                        for oldCtrl in GradientButtons {
                            if (oldCtrl.Hwnd = activeGradHwnd) {
                                if (HasProp(oldCtrl, "PicControl"))
                                    oldCtrl.PicControl.Value := "HBITMAP:*" oldCtrl.ImgNormal
                                oldCtrl.Redraw()
                                break
                            }
                        }
                    }
                    
                    if (HasProp(ctrl, "PicControl")) {
                        ctrl.PicControl.Value := "HBITMAP:*" ctrl.ImgHover
                    }
                    ctrl.Redraw()
                    activeGradHwnd := ctrl.Hwnd
                }
                break
            }
        }
         
        if (!matchedGrad && activeGradHwnd != 0) {
            for ctrl in GradientButtons {
                if (ctrl.Hwnd = activeGradHwnd) {
                    if (HasProp(ctrl, "PicControl"))
                        ctrl.PicControl.Value := "HBITMAP:*" ctrl.ImgNormal
                    ctrl.Redraw()
                    break
                }
            }
            activeGradHwnd := 0
        }
    }
}

HideAllTabContent() {
    global ChildGui, MainGui, SystemHwnds
    for hwnd, ctrl in MainGui {
        if (SystemHwnds.Has(hwnd))
            continue

        try {
            ctrl.Visible := false
        }
    }
    ChildGui.Hide()
}

ShowTabContent(tab) {
    global ChildGui, DiscordBotSettingsOpen, CreditControls
    if (tab = "Farming") {
        FarmingShow(false)
    } else if (tab = "Tab1") {
        for ctrl in [Tab1_Section1, Tab1_Line1, Tab1_Lbl1, Strategy1Ctrl, Tab1_Btn1, Tab1_Btn2,
                     Tab1_Lbl2, Strategy2Ctrl, Tab1_Btn3, Tab1_Btn4, RotateStrategiesCtrl, AutoEquipCtrl, Tab1_Section2, Tab1_Line2,
                     Tab1_Start, Tab1_Stop]
            ctrl.Visible := true
        UpdateStratRotationControls(false)
        ShowChildGui()
    } else if (tab = "Tab2") {
        RecordPageShow()
    } else if (tab = "Tab3") {
        for ctrl in TAB3
            ctrl.Visible := true
        PartySaveStatus.Visible := true
    } else if (tab = "Tab4") {
        DiscordPageShow(DiscordBotSettingsOpen)
    } else if (tab = "Tab5") {
        for ctrl in [Tab5_Section1, Tab5_Line1, Tab5_Lbl1, ChainKeyCtrl,
                     Tab5_Lbl2, BeatKeyCtrl, Tab5_Lbl3, CaravanKeyCtrl,
                     Tab5_Lbl44, RaiseDeadKeyCtrl, Tab5_Lbl55, Tab5_Lbl56, HologramKeyCtrl, RepoKeyCtrl,
                     Tab5_Lbl99, Tab5_LblUPG, Tab5_LblUPGBTM, CancelPlacementKeyCtrl, UpgradeTowerGCtrl, UpgradeTowerGBCtrl, Tab1_Lbl3, Tab1_Lbl4, TimeScaleModeCtrl, UpgradeDelayCtrl,
                     Tab5_Section2, Tab5_Line2, Tab5_Help6,
                     UseRestartBtnCtrl, Tab5_Help4, UsePlayAgainBtnCtrl, Tab5_Help5,
                     CheckTheMapCtrl, UseNumbersForHotbarCtrl, UseUpgradeHCtrl, Tab5_Help7, Tab5_Help11, Tab5_Help12, PotatoModeCtrl, DebugConsoleCtrl,
                     Tab5_Section3, Tab5_Line3, PlcTowerTEXT, UpgTowerTEXT, AlignCamTEXT,
                     DjTrackTEXT, SellTowTEXT, DelRecTEXT, RecInputsTEXT,
                     HoloTEXT, RaiseDeadTEXT,
                     PlaceTowerKeyCtrl, UpgradeTowerKeyCtrl, AlignCameraKeyCtrl,
                     ChangeDJTrackKeyCtrl, SellTowerKeyCtrl, DeleteTowerRecordingKeyCtrl,
                     RecordInputsKeyCtrl, HoloKeyCtrl, ChangeTargetsCTRL,
                     CollectPlaytimeRewardsCtrl, AutoCloseChatCtrl,
                     Tab5_Line4, Tab5_Lbl4, AppearanceLink, LanguageLbl, LanguageCtrl, VipLinkCtrl, UseVipServerCtrl, AlwaysOnTopCtrl, LegacyModeCtrl, SettingsAppHeading, SettingsStatus,
                     MouseSpeedLbl, MouseSpeedTxt, MouseSpeedUpDown,
                     MouseDelayLbl, MouseDelayTxt, MouseDelayUpDown, KeyDelayLbl, KeyDelayTxt, KeyDelayUpDown]
            ctrl.Visible := true

        
    } else if (tab = "Tab7") {
        for ctrl in CreditControls
            ctrl.Visible := true
        Credit_Content.Visible := true
        Credit_Info.Visible := true
        version_text.Visible := true
        Divider.Visible := true
        FooterBg.Visible := true
        Credit_TITLE.Visible := true
        DiscordImg.Visible := true
        YoutubeImg.Visible := true
        githubImg.Visible := true
        Credit_Divider.Visible := true
        Credit_InfoBG.Visible := true
        CreditsRender()
    }
}

ShowChildGui() {
    global ChildGui, FrameX, FrameY, FrameW, FrameH, MainGui
    ChildGui.Show("NA x" FrameX " y" FrameY " w" FrameW " h" FrameH)
}


MoveWindow(ctrl, *) {
    PostMessage(0xA1, 2, , , MainGui)
}
MinimizeWindow(ctrl, *) {
    MainGui.Minimize()
}
MaximizeWindow(ctrl, *) {
    if WinGetMinMax("ahk_id " MainGui.Hwnd) = 1
        MainGui.Restore()
    else
        MainGui.Maximize()
}

MacroResizeTitle(gui, mode, width, height) {
    if MacroClosing || mode = -1
        return
    BtnMin.Move(width-100)
    BtnMax.Move(width-70)
    BtnClose.Move(width-40)
    BtnMax.Text := mode = 1 ? "2" : "1"
    sysBar1.Move(,,width)
    sysLine1.Move(,,width)
    sysLine2.Move(,,width)
    MacroAppearance.QueuePaint()
}

MacroPartyRadio(gui, x, y, width, name, options, selected) {
    radio := gui.Add("Radio", "Hidden x" x " y" y " w17 h22 " options (selected ? " Checked" : ""), "")
    gui.SetFont("s9 Norm cE2E4E7", "Segoe UI")
    radio.CaptionCtrl := gui.Add("Text", "Hidden x" (x+21) " y" y " w" width " h22 0x200 BackgroundTrans", name)
    radio.CaptionCtrl.OnEvent("Click", (*) => SendMessage(0xF5, 0, 0, radio))
    return radio
}

CloseWindow(ctrl, *) {
    global MacroClosingManually
    MacroClosingManually := true
    SettingsFlush()
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

DownloadStrat(ctrl, *) {
    nm := ctrl.StratFile 
    
    downloadedStrat := A_WorkingDir "\Resources\Strats" (SubStr(nm, 1, 1) = "\" ? nm : "\" nm)

    if (Strategy1Ctrl.Value = "") {
    Strategy1Ctrl.Value := downloadedStrat
    Strategy1Path := downloadedStrat
    IniWrite(downloadedStrat, SettingsFile, "Options", "Strategy1")
    } else if (Strategy2Ctrl.Value = "" && Strategy2Ctrl.Visible) {
        Strategy2Ctrl.Value := downloadedStrat
        Strategy2Path := downloadedStrat
        IniWrite(downloadedStrat, SettingsFile, "Options", "Strategy2")
    } else {
        Strategy1Ctrl.Value := downloadedStrat
        Strategy1Path := downloadedStrat
        IniWrite(downloadedStrat, SettingsFile, "Options", "Strategy1")
    }
    
    LoadStrategyFile(downloadedStrat)
}


OnMouseWheel(wp, lp, msg, hwnd) {
    global ChildHwnd, ChildGui
    MouseGetPos(, , &maxH, &ctrlH, 2)

    parentH := (ctrlH != "") ? DllCall("GetParent", "Ptr", ctrlH, "Ptr") : 0
    ch := ChildGui.Hwnd
    
    if (maxH = ch || ctrlH = ch || parentH = ch) {
        
        dir := ((wp >> 16) & 0xFFFF) > 0x7FFF ? 1 : 0
        Loop 3
            SendMessage(0x0115, dir, 0, , "ahk_id " ch)
    }
}


OnScroll(wp, lp, msg, hwnd) {
    global ChildGui, CurrentScrollPos, ContentH, FrameH, SliderH, Slider
    ch := ChildGui.Hwnd
    if (hwnd != ch)
        return
    action := wp & 0xFFFF
    if (action = 0) {
        newPos := CurrentScrollPos - 3
    } else if (action = 1) {
        newPos := CurrentScrollPos + 3
    } else {
        return
    }
    maxScroll := ContentH - FrameH
    newPos := Max(0, Min(newPos, maxScroll))
    if newPos != CurrentScrollPos {
        DllCall("ScrollWindow", "Ptr", hwnd, "Int", 0, "Int", CurrentScrollPos - newPos, "Ptr", 0, "Ptr", 0)
        CurrentScrollPos := newPos
        Slider.Move(, Round(newPos / maxScroll * (FrameH - SliderH)))
        DllCall("UpdateWindow", "Ptr", hwnd)
    }
}

EnableStratRotation(*) {
    UpdateStratRotationControls(true)
}

UpdateStratRotationControls(saveSettings) {
    global RotateStrategies, SwapAmount, SwapUnit
    
    v := MainGui.Submit(false)
    RotateStrategies := v.RotateStrategies
    if saveSettings
        IniWrite(RotateStrategies, SettingsFile, "Options", "RotateStrategies")
    
    show := (RotateStrategies = 1)

    Tab1_Lbl2.Visible := show
    Strategy2Ctrl.Visible := show
    Tab1_Btn3.Visible := show
    Tab1_Btn4.Visible := show

    SwapAfterLbl.Visible := show
    SwapAmountCtrl.Visible := show
    SwapUnitCtrl.Visible := show

    AutoEquipCtrl.Enabled := !show

    if (show) {
        AutoEquipCtrl.Value := 1
        v := MainGui.Submit(false)
        AutoEquip := v.AutoEquip
        if saveSettings
            IniWrite(AutoEquip, SettingsFile, "Options", "AutoEquip")
        SwapAmount := SwapAmountCtrl.Text
        SwapUnit := LocalizationSwapUnitValue(SwapUnitCtrl.Value)
        AutoEquipCtrl.Move(357, 190)
        if saveSettings {
            IniWrite(SwapAmount, SettingsFile, "Options", "SwapAmount")
            IniWrite(SwapUnit, SettingsFile, "Options", "SwapUnit")
        }
    } else {
        AutoEquipCtrl.Move(155, 190)
    }
}

EnableAutoEquip(*) {
    global AutoEquip
    
    v := MainGui.Submit(false)
    AutoEquip := v.AutoEquip
    IniWrite(AutoEquip, SettingsFile, "Options", "AutoEquip")
}

SelectStrat1(ctrl, *) {
    global Strategy1Path
    targDir := RecordingsDir
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
SelectStrat2(ctrl, *) {
    global Strategy2Path
    targDir := RecordingsDir
    if (Strategy2Ctrl.Value) {
        SplitPath(Strategy2Ctrl.Value, , &parentDir) 
        targDir := parentDir
    }
    f := FileSelect("3", targDir, "Select strategy file 2", "Strategy (*.strat)")
    if (f != "") {
        Strategy2Ctrl.Value := f
        Strategy2Path := f
        IniWrite(f, SettingsFile, "Options", "Strategy2")
    }
}
ClearStrat1(ctrl, *) {
    global Strategy1Path
    Strategy1Ctrl.Value := ""
    Strategy1Path := ""
    IniWrite(" ", SettingsFile, "Options", "Strategy1")
}
ClearStrat2(ctrl, *) {
    global Strategy2Path
    Strategy2Ctrl.Value := ""
    Strategy2Path := ""
    IniWrite(" ", SettingsFile, "Options", "Strategy2")
}
SaveStrat1(ctrl, *) {
    global Strategy1Path, Strategy1Ctrl
    Strategy1Path := Strategy1Ctrl.Text
    IniWrite(Strategy1Ctrl.Text, SettingsFile, "Options", "Strategy1")
}

SaveStrat2(ctrl, *) {
    global Strategy2Path, Strategy2Ctrl
    Strategy2Path := Strategy2Ctrl.Text
    IniWrite(Strategy2Ctrl.Text, SettingsFile, "Options", "Strategy2")
}


StartStrategy(*) {
    SettingsFlush()
    if (RunningStrategy or Recording) {
        return
    }
    g_IsFirstLaunch := Integer(IniRead(StateFile, "State", "IsFirstLaunch", 1))

    global RunningStrategy, CurrentRotationIndex, gamemap, difficulty, requiredTowers, modifiers
    global autoChain, autoCaravan, autoDropTheBeat, AutoSkip, AbilitySpam, MoveEnabled, MoveDirection, MoveDuration
    global AutorunStartTime, CurrentStratStartTime

    if !IsSet(MainGui) or !MainGui
        return

    v := MainGui.Submit(false)
    IniWrite(v.Strategy1, SettingsFile, "Options", "Strategy1")
    IniWrite(v.Strategy2, SettingsFile, "Options", "Strategy2")

    if (v.RotateStrategies = 1) {
        s1 := Trim(v.Strategy1)
        s2 := Trim(v.Strategy2)

        for num, s in [s1, s2] {
            if (s == "" || !FileExist(s)) {
                ModernMsgBox("Warning", "Rotation mode is enabled but strategy " num " is empty or file doesn't exist!`nPlease select a valid file for Strategy " num "!", "OK", "WARNING")
                return
            }
        }
    }

    stratFile := ""
    s1 := v.Strategy1, s2 := v.Strategy2

    if (v.RotateStrategies = 1 && s2 != "") {
        if (s1 != "" && FileExist(s1)) {
            stratFile := s1
            CurrentRotationIndex := 1
        }
    } else {
        if (s1 != "" && FileExist(s1))
            stratFile := s1
        else if (s2 != "" && FileExist(s2))
            stratFile := s2
    }

    if (stratFile = "") {
        ModernMsgBox("Warning", "No valid strategy file selected!", "OK", "WARNING")
        return
    }

    if (g_IsFirstLaunch = 1) {
        IniWrite(0, StateFile, "State", "IsFirstLaunch")
        LocalizationMsgBox("Since you are starting the macro for the first time... Read this so your macro can work properly:`n`n1. Go to the TDS Settings and ENABLE 'Prefer Vertical Upgrades`n2. Go to the TDS Settings and set UI Scale to 'LARGE'`n3. Set your Roblox Camera Mode to Classic`n4. If your Roblox graphics are automatic, set them to manual.`n5. Turn off camera shake in TDS.`n6. Disable Dialog in TDS`n7. Enable UI Navigation toggle in the Roblox settings.`n8. Enable 'Show Tower Options' in TDS.`n9. Make sure you have 60 fps in Roblox settings.`n`nRecommended screen resolution for this macro is 1920x1080 (Resolutions bigger than 1080p may not work. You can use 1366x768 & 1280x720 though, they work pretty well). The scale must be 100%.`nThis macro requires a good CPU. You can use it though if your device is bad, enable potato mode and make the delays bigger.`nPlease, join my Discord server to get help and check the FAQ.","READ THIS!!", 0x1030)
    }

    IniDelete(StateFile, "TowerXP")
    IniDelete(StateFile, "TicketBudget")
    IniDelete(StateFile, "Batch", "StopAfter")
    IniDelete(StateFile, "State", "Coins")
    IniDelete(StateFile, "State", "Gems")
    IniDelete(StateFile, "State", "EXP")
    IniDelete(StateFile, "State", "TotalTriumphs")
    IniDelete(StateFile, "State", "TotalLosses")
    IniDelete(StateFile, "State", "TotalTimeSeconds")
    IniDelete(StateFile, "State", "Timescale")
    IniDelete(StateFile, "State", "CurrentStratStartTime")
    IniDelete(StateFile, "State", "CurrentRotationIndex")
    IniDelete(StateFile, "State", "CurrentRunCount")
    IniDelete(StateFile, "State", "StartTime")
    IniDelete(StateFile, "State", "TimeWhenStartedPlaying")
    IniDelete(StateFile, "State", "Equipped")

    AutorunStartTime := 0

    SetDefaultMouseSpeed(DefaultMouseSpeed)
    SetMouseDelay(MouseDelay)
    SetKeyDelay(KeyDelay)
    LoadStrategyFile(stratFile)

    if (requiredTowers != "" && !AutoEquip && !BatchUsesLobbyEquip()) {
        towerPrompt := TranslateText("Towers required for this strategy:") "`n`n" requiredTowers
        LocalizationMsgBox(towerPrompt, "Required Towers", "0x1040 T60")
    }

    IniWrite(1, StateFile, "State", "Running")
    IniWrite(stratFile, StateFile, "State", "Strategy")

    MainGui.Hide()
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
            LocalizationMsgBox("Conflicting program detected:`n" A_LoopField "`n`nFor this script to work properly, please close all Roblox multi-client utilities.`nPlease close them and try again.", "Error", 0x1030)
            ExitApp()
        }
    }

    CurrentStratStartTime := A_TickCount
    IniWrite(A_TickCount, StateFile, "State", "CurrentStratStartTime")
    CurrentRunCount := 0
    IniWrite(0, StateFile, "State", "CurrentRunCount")

    RunStrategy("", true)
}

StopStrategy(*) {
    global RunningStrategy, AutorunStartTime, Recording, MacroRecording, InputHookObj

    KillSubmacros()

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
        IniDelete(StateFile, "State", "CurrentStratStartTime")
        IniDelete(StateFile, "State", "CurrentRotationIndex")
        IniDelete(StateFile, "State", "CurrentRunCount")
        IniDelete(StateFile, "State", "TimeWhenStartedPlaying")
        IniDelete(StateFile, "State", "Equipped")
        RunningStrategy := false
        SafeReload()
    }

    if (Recording) {
        StopRecord(0)
    }
}

StartRecording(ctrl, *) {
    global Recording, gamemap, difficulty, requiredTowers, modifiers, autoChain, autoCaravan
    global autoDropTheBeat, AutoSkip, AbilitySpam, MoveEnabled, MoveDirection, MoveDuration
    global Commander, RecordedSteps, Towers, MacroRecording, GuiTitleCtrl

    if (Recording)
        return

    SettingsFlush()
    v := MainGui.Submit(false)

    if (!v.RecMaps or !v.RecDifficulty or !v.RecRequiredTowers) {
        LocalizationMsgBox("Failed to start recording!`nMake sure you have entered the towers, the map, and the difficulty, then try again.", "Error", 0x1010)
        return
    }

    if (A_ScreenWidth != 1920 || A_ScreenHeight != 1080) {
        if (LocalizationMsgBox("Your screen resolution is not 1920x1080.`nThe recording system is highly recommended for 1920x1080. Do you want to continue?", "Warning", 0x1034) = "No") {
            return
        }
    }

    if (IsSet(GuiTitleCtrl) && GuiTitleCtrl) {
        AppearanceFont(GuiTitleCtrl, "cff6b6b")
    }

    gamemap := v.RecMaps
    difficulty := v.RecDifficulty
    requiredTowers := v.RecRequiredTowers
    modifiers := RecordSelectedModifiers()
    autoChain := v.RecAutoChain ? "ON" : "OFF"
    autoCaravan := v.RecAutoCaravan ? "ON" : "OFF"
    autoDropTheBeat := v.RecAutoDropTheBeat ? "ON" : "OFF"
    AutoSkip := v.RecAutoSkip ? "ON" : "OFF"
    AbilitySpam := v.RecAbilitySpam ? "ON" : "OFF"
    MoveEnabled := v.RecMoveEnabled ? true : false
    MoveDirection := v.RecMoveDirection
    MoveDuration := IsNumber(v.RecMoveDuration) ? Integer(v.RecMoveDuration) : 750

    Commander := false
    Recording := true
    RecordActionsUpdate()
    RecordedSteps := []
    Towers := Map()
    DeleteAllIndicators()

    LogToConsole("Recording started.")
    
    ActivateRoblox()
}

StopRecord(ctrl, *) {
    global Recording, MacroRecording, InputHookObj, MacroSteps, RecordedSteps
    global gamemap, difficulty, requiredTowers, modifiers
    global autoChain, autoCaravan, autoDropTheBeat, AutoSkip, AbilitySpam, MoveEnabled, MoveDirection, MoveDuration
    global GuiTitleCtrl, Strategy1Ctrl, RecordingsDir

    if (MacroRecording) {
        MacroRecording := false
        if (InputHookObj != "")
            InputHookObj.Stop()
        LogToConsole("Macro recording auto-stopped")
        if (ModernMsgBox("Add to Strategy?", "Add recorded actions to current strategy?", "YES|NO") = "YES") {
            for i, step in MacroSteps
                RecordedSteps.Push(step)
            LogToConsole("Added " MacroSteps.Length " macro steps to strategy")
        }
    }

    if (!Recording)
        return
    Recording := false
    RecordActionsUpdate()
    DeleteAllIndicators()

    if (IsSet(GuiTitleCtrl) && GuiTitleCtrl) {
        AppearanceFont(GuiTitleCtrl, "cWhite")
    }

    if (ModernMsgBox("Save", "Save the recorded strategy?", "YES|NO") = "YES") {
        box := LocalizationInputBox("File name (without .strat):", "Save", "w300 h130", "MyStrategy")
        if (box.Result = "Cancel")
            return
        filePath := RecordingsDir "\" box.Value ".strat"
        if FileExist(filePath)
            FileDelete(filePath)
        getRobloxPos(&pX, &pY, &currentWidth, &currentHeight)

        FileAppend("[Settings]`nmap=" gamemap "`ndifficulty=" difficulty "`nrequiredTowers=" requiredTowers
            . "`nmodifiers=" Join(modifiers)
            . "`nautoChain=" autoChain "`nautoCaravan=" autoCaravan "`nautoDropTheBeat=" autoDropTheBeat
            . "`nautoSkip=" AutoSkip "`nabilitySpam=" AbilitySpam "`nmoveEnabled=" MoveEnabled "`nmoveDirection=" MoveDirection
            . "`nmoveDuration=" MoveDuration "`n`n[DO NOT EDIT]`nwidth=" currentWidth "`nheight=" currentHeight "`n`n[Steps]`n", filePath)
        for i, step in RecordedSteps
            FileAppend(step "`n", filePath)
        LogToConsole("Strategy saved: " filePath)
        Strategy1Ctrl.Value := filePath
    } else {
        LogToConsole("Recording cancelled, strategy not saved")
    }
}

PlaceTowerHK(*) {
    global Recording, Towers, RecordedSteps, ActiveRTowerID, CachedMenuUI, isUiPositionSaved, UseNumbersForHotbar, Slots

    if (!Recording) {
        pureKey := RegExReplace(PlaceTowerKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(PlaceTowerKey, "^([\^+!#]+)", &match) ? match[1] : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }
    
    towersStringBackup := Towers 

    MouseGetPos(&mx, &my)
    loop {
        slotBox := LocalizationInputBox("Enter the tower slot number (1-5):", "Slot (1-5)", "w300 h130", "1")

        if (slotBox.Result = "Cancel")
            return

        try {
            sllot := Integer(slotBox.Value)
            
            if (sllot >= 1 && sllot <= 5) {
                break
            } else {
                continue
            }
        } 
        catch Error {
            continue
        }
    }
    slot := slotBox.Value
    
    suggestedID := GetNextTowerID(slot)
    
    idBox := LocalizationInputBox("Enter a specific tower id:", "Tower ID", "w300 h130", suggestedID)
    if (idBox.Result = "Cancel")
        return
    towerID := idBox.Value
    ActivateRoblox()

    LogToConsole("Recording: placing tower " towerID " (slot " slot ") at x:" mx " y:" my "...")

    getRobloxPos(,,&w,&h)

    ActivateRoblox()
    
    if UseNumbersForHotbar {
        Send("{" slot "}")
    } else {
        Click(Slots[slot])
    }

    Sleep(30)
    

    MouseMove(mx, my, A_DefaultMouseSpeed)
    Sleep((PotatoMode = 1) ? 100 : 40)
    Click()
    Sleep(100)
    SendEvent("{" CancelPlacementKey "}")

    Towers[towerID] := {x: mx, y: my, slot: slot, level: 0, path: 0, pathLevel: 0, target: "First Enemy"}
    UpdateTowerIndicator(towerID)
    LogToConsole("Recorded tower " towerID " (slot " slot ")")

    RecordedSteps.Push("SpawnTower(" mx ", " my ", " slot ", " towerID ")")

    if (towerID = "" || RegExMatch(towerID, "i)(Juggernaut|Hacker|Pursuit|Kingpin)")) {
        ShowTowerPathDialog(towerID)
    }

    ActiveRTowerID := towerID
    
    openedSuccessfully := false
    Loop 10 {
        getRobloxPos(,,&w,&h)
        resV2 := AdvancedImageSearch("Resources\TowerUI\Variant2.png", 0, Round(h / 2), Round(w * 0.3), Round(h * 0.9) - Round(h / 2), 0.5, 1.5)
        
        if (resV2.status == "success" && resV2.score > 0.6) {
            
            if (!isUiPositionSaved) {
                Sleep(300) 
                
                getRobloxPos(,,&w,&h)
                resV2Final := AdvancedImageSearch("Resources\TowerUI\Variant2.png", 0, Round(h / 2), Round(w * 0.3), Round(h * 0.9) - Round(h / 2), 0.5, 1.5)
                
                if (resV2Final.status == "success") {
                    CachedMenuUI := {x: resV2Final.x, y: resV2Final.y}
                    isUiPositionSaved := true 
                    openedSuccessfully := true
                } else {
                    CachedMenuUI := {x: resV2.x, y: resV2.y}
                    isUiPositionSaved := true
                    openedSuccessfully := true
                }
            } 
            else {
                openedSuccessfully := true
            }
            break
        }
        Sleep(150)
    }
    
    if (!openedSuccessfully) {
        ActiveRTowerID := ""
    }
}

UpgradeTowerHK(*) {
    global Recording, Towers, RecordedSteps, Commander
    if (!Recording) {
        pureKey := RegExReplace(UpgradeTowerKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(UpgradeTowerKey, "^([\^+!#]+)", &match) ? match[1] : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }

    MouseGetPos(&mx, &my)

    closestID := ""
    for id, t in Towers {
        ix1 := t.x - 12
        iy1 := t.y - 12
        ix2 := ix1 + 24
        iy2 := iy1 + 24
        
        if (mx >= ix1 && mx <= ix2 && my >= iy1 && my <= iy2) {
            closestID := id
            break
        }
    }

    if (closestID != "") {
        Towers[closestID].level += 1
        UpdateTowerIndicator(closestID)
        if (Towers[closestID].path != 0 && Towers[closestID].path != "") {
            RecordedSteps.Push("UpgradeTower(" closestID ", false, 1, " Towers[closestID].path ", " Towers[closestID].pathLevel ")")
        } else {
            RecordedSteps.Push("UpgradeTower(" closestID ")")
        }
        if (Towers[closestID].level >= 2 && RegExMatch(closestID, "i)^Commander\d*$") && !Commander) {
            Commander := true
            if (!HasStep("Commander := true"))
                RecordedSteps.Push("Commander := true")
        }
    }
}

ChangeDJTrackHK(*) {
    global Recording, RecordedSteps
    if (!Recording) {
        pureKey := RegExReplace(ChangeDJTrackKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(ChangeDJTrackKey, "^([\^+!#]+)", &match) ? match[1] : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }
    box := LocalizationInputBox("Enter Track Color (Purple/Red/Green):", "DJ Track", "w300 h130", "Green")
    if (box.Result != "Cancel") {
        RecordedSteps.Push('SetDJTrack("' box.Value '")')
        LogToConsole("Recorded DJ-track " box.Value)
    }
}

DeleteTowerRecordingHK(*) {
    global Recording, Towers, RecordedSteps
    if (!Recording) {
        pureKey := RegExReplace(DeleteTowerRecordingKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(DeleteTowerRecordingKey, "^([\^+!#]+)", &match) ? match[1] : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }

    MouseGetPos(&mx, &my)

    closestID := ""
    for id, t in Towers {
        if (!HasProp(t, "x") || !HasProp(t, "y"))
            continue

        ix1 := t.x - 12
        iy1 := t.y - 12
        ix2 := ix1 + 24
        iy2 := iy1 + 24
        
        if (mx >= ix1 && mx <= ix2 && my >= iy1 && my <= iy2) {
            closestID := id
            break
        }
    }

    if (closestID != "") {
        if (HasProp(Towers[closestID], "hwnd") && Towers[closestID].hwnd) {
            try WinClose("ahk_id " Towers[closestID].hwnd)
        }

        newSteps := []
        
        escapedID := RegExReplace(closestID, "([\.\ \+\*\?\^\$\(\)\[\]\{\}\|])", "\$1")

        for i, step in RecordedSteps {
            if (RegExMatch(step, "i)^SpawnTower\s*\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*" escapedID "\s*\)$"))
                continue
            if (RegExMatch(step, "i)^UpgradeTower\s*\(\s*" escapedID "\s*(?:,.*)?\s*\)$"))
                continue
            if (RegExMatch(step, "i)^SellTower\s*\(\s*" escapedID "\s*\)$"))
                continue
            newSteps.Push(step)
        }
        RecordedSteps := newSteps

        try {
            if Towers.Has(closestID) {
                Towers.Delete(closestID)
            }
        } catch {
        }

        LogToConsole("Recorded sell tower " closestID)
    }
}


SellTowerHK(*) {
    global Recording, Towers, RecordedSteps
    if (!Recording) {
        pureKey := RegExReplace(SellTowerKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(SellTowerKey, "^([\^+!#]+)", &match) ? match[1] : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }

    MouseGetPos(&mx, &my)

    closestID := ""
    for id, t in Towers {
        ix1 := t.x - 12
        iy1 := t.y - 12
        ix2 := ix1 + 24
        iy2 := iy1 + 24
        
        if (mx >= ix1 && mx <= ix2 && my >= iy1 && my <= iy2) {
            closestID := id
            break
        }
    }
    if (closestID != "") {
        if (Towers[closestID].hwnd) {
            WinClose("ahk_id " Towers[closestID].hwnd)
            Towers[closestID].hwnd := ""
        }
        RecordedSteps.Push("SellTower(" closestID ")")
        SellTower(closestID)
        newSteps := []
        for i, step in RecordedSteps {
            if (RegExMatch(step, "i)^SpawnTower\s*\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*" closestID "\s*\)$"))
                continue
            if (RegExMatch(step, "i)^UpgradeTower\s*\(\s*" closestID "\s*\)$"))
                continue
            newSteps.Push(step)
        }
        RecordedSteps := newSteps
        Towers.Delete(closestID)
        LogToConsole("Recorded sell tower " closestID)
    }
}

AlignCameraHK(*) {
    if (!Recording) {
        pureKey := RegExReplace(AlignCameraKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(AlignCameraKey, "^([\^+!#]+)", &match) ? match[1] : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }

    if (InArray(SpecialMaps, gamemap)) {
        functionName := gamemap . "Path"

        %functionName%() 
    } else {
        AlignCamera()
    }
}

RecordInputsHK(*) {
    global MacroRecording, InputHookObj, MacroSteps, MacroStartTime, RecordedSteps, Recording, KeyDownTimes
    if (!Recording) {
        pureKey := RegExReplace(RecordInputsKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(RecordInputsKey, "^([\^+!#]+)", &match) ? match[1] : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }
    if (MacroRecording) {
        MacroRecording := false
        if (InputHookObj != "")
            InputHookObj.Stop()
        LogToConsole("Recording ALL clicks and keys STOPPED. Steps: " MacroSteps.Length)
        if (ModernMsgBox("Add to Strategy?", "Add recorded actions to current strategy?", "YES|NO") = "YES") {
            for i, step in MacroSteps
                RecordedSteps.Push(step)
            LogToConsole("Added " MacroSteps.Length " steps to strategy")
        }
    } else {
        LogToConsole("Recording ALL clicks and keys...!")
        MacroRecording := true
        MacroSteps     := []
        KeyDownTimes   := Map() 
        MacroStartTime := A_TickCount
        InputHookObj := InputHook("V")
        InputHookObj.KeyOpt("{All}", "N")
        InputHookObj.OnKeyDown := OnKeyDown
        InputHookObj.OnKeyUp := OnKeyUp 
        InputHookObj.Start()
    }
}

CloneTowerHK(*) {
    global Recording, RecordedSteps
    static LastCallTime := 0

    if (!Recording) {
        pureKey := RegExReplace(HoloKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(HoloKey, "^([\^+!#]+)", &match) ? match : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }

    CoordMode("Mouse", "Client")
    ActivateRoblox()
    MouseGetPos(&mx, &my)

    idBox := LocalizationInputBox("Enter the tower ID to clone:", "Clone Tower", "w300 h130", "")
    if (idBox.Result = "Cancel")
        return

    towerID := Trim(idBox.Value)
    if (towerID = "") {
        return
    }

    CloneTower(towerID, mx, my)

    RecordedSteps.Push("CloneTower(" towerID ", " mx ", " my ")")
}

BrawlerRepositionHK(*) {
    global Recording, RecordedSteps, ActiveRTowerID

    if (!Recording) {
        pureKey := RegExReplace(HoloKey, "[\^+!#]") 
        SEND_modifiers := RegExMatch(HoloKey, "^([\^+!#]+)", &match) ? match : ""
        
        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }

    CoordMode("Mouse", "Client")
    MouseGetPos(&mx, &my)

    if (ActiveRTowerID = "") {
        idBox := LocalizationInputBox("Enter the tower ID to reposition:", "Repo Brawler", "w300 h130", "")
        if (idBox.Result = "Cancel")
            return

        towerID := Trim(idBox.Value)
        if (towerID = "") {
            return
        }
        BrawlerReposition(towerID, mx, my)
    } else {
        towerID := ActiveRTowerID

        Hotkey("~LButton", "Off")
        g := KeyWait("LButton", "D")
        Hotkey("~LButton", "On")

        MouseGetPos(&mx, &my)

        Towers[towerId].x := mx
        Towers[towerId].y := my
        UpdateTowerIndicator(towerId)
    }

    RecordedSteps.Push("BrawlerReposition(" towerID ", " mx ", " my ")")
    LogToConsole("Recorded BrawlerReposition(" towerID ", " mx ", " my ")")
}

ActivateRaiseTheDeadHK(*) {
    global Recording, RecordedSteps
    static LastCallTime := 0

    waitTime := 0
    currentTime := A_TickCount

    if (RecordedSteps.Length > 0) {
        lastStep := RecordedSteps[RecordedSteps.Length]
        
        if (InStr(lastStep, "ActivateRaiseTheDead") && LastCallTime > 0) {
            waitTime := currentTime - LastCallTime
        }
    }

    LastCallTime := currentTime
    ActivateRaiseTheDead(waitTime)

    RecordedSteps.Push("ActivateRaiseTheDead(" waitTime ")")
}

RecordToggleAutoskip(*) {
    global Recording, AutoSkip
    if !Recording {
        return
    }

    v := MainGui.Submit(false)
    at := v.RecAutoSkip ? "ON" : "OFF"

    RecordedSteps.Push("ToggleAutoskip()")

    if at = "ON" {
        LogToConsole("Toggled auto-skip: ON")
    } else {
        LogToConsole("Toggled auto-skip: OFF")
    }
}

ChangeTargetsHK(*) {
    global Recording, RecordedSteps, ActiveRTowerID, LastOpenedTowerID

    CoordMode("Mouse", "Client")
    MouseGetPos(&mx, &my)

    if (ActiveRTowerID = "") {
        idBox := LocalizationInputBox("Enter the tower ID:", "Change Targets", "w300 h100", "")
        if (idBox.Result = "Cancel")
            return

        towerID := Trim(idBox.Value)
        if (towerID = "") {
            return
        }
    } else {
        towerID := ActiveRTowerID
        LastOpenedTowerID := towerID
    }

    targetBox := LocalizationInputBox("Enter the target:", "Change Targets", "w300 h100", "")
    if (targetBox.Result = "Cancel")
        return

    target := Trim(targetBox.Value)
    if (target = "") {
        return
    }

    ChangeTargets(towerID, target)

    RecordedSteps.Push("ChangeTargets(" towerID ", " target ")")
    LogToConsole("Recorded ChangeTargets(" towerID ", " target ")")
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

        LastOpenedTowerID := 0
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
    
    if (!Recording) {
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
    if (!Recording) {
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
        LocalizationApplyGui(PathGui)
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
    box := LocalizationInputBox("Enter the level where the paths appear:", "Level", "w300 h130", "")
    if (box.Result = "Cancel" || !IsInteger(box.Value))
        return
    Towers[towerID].path      := pathNum
    Towers[towerID].pathLevel := Integer(box.Value)
    UpdateTowerIndicator(towerID)
    LogToConsole("Tower " towerID " set to path " pathNum " from level " box.Value)
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


SaveAllSettingsMULTIPLAYER(ctrl, *) {
    global HostName, PartyMembersStr, MultiplayerEnabled, PlayerRole, LeaveCondition
    global SettingsFile

    s := MainGui.Submit(false)

    HostName := Trim(Tab3_HostNm_EDIT.Value)
    PartyMembersStr := RegExReplace(Tab3_PartyMemb_Edit.Value, "\s*,\s*", ",")
    MultiplayerEnabled := MultiplayerEnabledTGL.Value
    PlayerRole := (s.PlayerRole == 2) ? "Member" : "Host"
    LeaveCondition := (s.LeaveCondition == 1) ? "All" : "Any"

    IniWrite(HostName, SettingsFile, "Multiplayer", "HostName")
    IniWrite(PartyMembersStr, SettingsFile, "Multiplayer", "PartyMembers")
    IniWrite(MultiplayerEnabled, SettingsFile, "Multiplayer", "MultiplayerEnabled")
    IniWrite(PlayerRole, SettingsFile, "Multiplayer", "PlayerRole")
    IniWrite(LeaveCondition, SettingsFile, "Multiplayer", "LeaveCondition")

    global PartyMembers := IniRead(SettingsFile, "Multiplayer", "PartyMembers", "someone, someone...")
    global PlayerRole := IniRead(SettingsFile, "Multiplayer", "PlayerRole", "Host")
    global HostName := IniRead(SettingsFile, "Multiplayer", "HostName", "...")
    global LeaveCondition := IniRead(SettingsFile, "Multiplayer", "LeaveCondition", "Any")
    global MultiplayerEnabled := IniRead(SettingsFile, "Multiplayer", "MultiplayerEnabled", 0)


}

LegacyModeInfo(*) {
    if LegacyModeCtrl.Value = 1 {
        LocalizationMsgBox("Changes how the image detection works. May not work for some people.`n`nWarning: some features - such as Auto Equip, Changing Tower Targeting will not work with this mode!", "Legacy Mode", "0x1040")
    }
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


LoadStrategyFile(file) {
    global Towers, RecordedSteps, gamemap, difficulty, requiredTowers, autoChain, autoCaravan
    global autoDropTheBeat, AutoSkip, AbilitySpam, MoveEnabled, MoveDirection, MoveDuration
    global modifiers, Commander, StrategyWidth, StrategyHeight

    Towers := Map()
    RecordedSteps := []
    DeleteAllIndicators()

    gamemap := IniRead(file, "Settings", "map", "")
    difficulty := IniRead(file, "Settings", "difficulty", "")
    requiredTowers  := IniRead(file, "Settings", "requiredTowers",  "")
    autoChain := IniRead(file, "Settings", "autoChain", "OFF")
    autoCaravan := IniRead(file, "Settings", "autoCaravan", "OFF")
    autoDropTheBeat := IniRead(file, "Settings", "autoDropTheBeat", "OFF")
    AutoSkip := IniRead(file, "Settings", "autoSkip", "ON")
    AbilitySpam := IniRead(file, "Settings", "abilitySpam", "ON")
    modifiers := IniRead(file, "Settings", "modifiers", "")

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
    global WebhookEnabled, CurrentStratStartTime, CurrentRunCount, gamemap, AutoEquip

    if (RunningStrategy != true)
        return

    If (!skiprestart)
    	isDisconnected()

    switched := false
    if (RotateStrategies) {
        SwapAmount := Integer(IniRead(SettingsFile, "Options", "SwapAmount", 4))
        SwapUnit := IniRead(SettingsFile, "Options", "SwapUnit", "Runs")
        
        timeToSwitch := false
        if (SwapUnit = "Minutes") {
            if (A_TickCount - CurrentStratStartTime > SwapAmount * 60000)
                timeToSwitch := true
        } else {
            if (CurrentRunCount >= SwapAmount)
                timeToSwitch := true
        }
        
        if (timeToSwitch) {
            SwitchToNextStrategy(&stratName)
            switched := true

            Sleep(100)
        }
    }

    CurrentRunCount++
    IniWrite(CurrentRunCount, StateFile, "State", "CurrentRunCount")

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

    if (switched) {
        time := FormatTime(, "HH:mm:ss")
        SplitPath(stratName, &fileName)
        startInfo := "[" time "] Switched strategy to: " fileName "`n"
        startInfo .= "Map = " gamemap "`nMode = " difficulty "`nTimescale = " TimeScaleMode "`nRequired Towers: " requiredTowers
        if (modifiers != "")
            startInfo .= "`nModifiers: " modifiers
        SendToWebhookInstant(startInfo,, flush := false)
    }

    checkStart := IniRead(StateFile, "State", "StartTime", 0)
    if (checkStart = 0) {
        IniWrite(A_TickCount, StateFile, "State", "StartTime")
        AutorunStartTime := A_TickCount
    } else {
        AutorunStartTime := checkStart
    }

    if (!switched) {
        if (!skipRestart) {
            CheckRestart()
        } else {
            getRobloxPos(,,&w,&h)
            closeRoblox_ := true
            if (GetRobloxHWND()){
                ActivateRoblox()
                Loop 2 {
                    play_btn := AdvancedImageSearch("Resources/Play.png", Round(w * 0.25), Round(h * 0.66), Round(w * 0.75), Round(h * 0.34))
                    if (play_btn.status = "success" && play_btn.score > 0.65) {
                        closeRoblox_ := false
                        break
                    } 
                    Sleep 150
                }
            }
            
            if (closeRoblox_) {
                CloseRoblox()
                RunRoblox()
            }

            if (AutoEquip && !BatchUsesLobbyEquip()) {
                EquipTowers(RequiredTowers)
            }
            JoinGame()
        }
    } else {

        closeRoblox_ := true
        if (GetRobloxHWND()){
            ActivateRoblox()
            Loop 2 {
                getRobloxPos(,,&w,&h)
                play_btn := AdvancedImageSearch("Resources/Play.png", Round(w * 0.25), Round(h * 0.66), Round(w * 0.75), Round(h * 0.34))
                if (play_btn.status = "success" && play_btn.score > 0.65) {
                    closeRoblox_ := false
                    break
                } 
                Sleep 150
            }
        }
        
        if (closeRoblox_) {
            CloseRoblox()
            RunRoblox()
        }

        if !BatchUsesLobbyEquip()
            EquipTowers(RequiredTowers)

        JoinGame()
    }

    if (readyX = 0 && readyY = 0) {
        waitReady()
    }

    if (!IsRestarting) {
        cameraAligned := CheckTheMapF()
        if (!InArray(SpecialMaps, gamemap)) {
            if cameraAligned
                ApplyStrategyMovement()
            else
                AlignCamera()
        }
    }

    IniWrite(0, StateFile, "Earnings", "TimescaleUsed")
    activateTimescale()

    ClickReady()
    
    PlayStrategy()
}

PlayStrategy() {
    global canUseAbility, MultiplayerEnabled, StateFile, gamemap, difficulty

    BatchBeginMatch()
    IniWrite(gamemap, StateFile, "Earnings", "Map")
    IniWrite(difficulty, StateFile, "Earnings", "Difficulty")
    IniWrite(A_TickCount, StateFile, "State", "TimeWhenStartedPlaying")
    SetTimer(UseAbilities, 750)
    if (MultiplayerEnabled) {
        SetTimer(checkCondition, 15000)
    }

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

EquipTowers(towers, strict := false) {
    getRobloxPos(,,&rw,&rh)

    LogToConsole("Equipping towers: " towers)

    savedCloseX := 0
    savedCloseY := 0

    closeChat()
    Sleep(600)

    maxAttempts := 3
    openedMenu := false

    Loop maxAttempts {
        itemsClicked := false
        StartTime := A_TickCount
        W := Round(rw * 0.3)
        H := rh - 0

        Loop {
            resItems := AdvancedImageSearch("Resources\items.png", 0, 0, W, H)
            if (resItems.status == "success" && resItems.score > 0.56) {
                fx := resItems.x
                fy := resItems.y
                MouseMove(fx, fy + ScaleY(7), A_DefaultMouseSpeed + 1)
                Sleep(100)
                MouseClick()
                itemsClicked := true
                break
            } 
            if (A_TickCount - StartTime > 5000) {
                break
            }
            Sleep(500)
        }

        if (!itemsClicked) {
            continue
        }

        Sleep(800)

        StartTime := A_TickCount
        X1 := Round(rw * 0.2)
        Y1 := 0
        W_close := Round(rw * 1) - X1
        H_close := Round(rh * 0.4) - Y1

        Loop {
            resclose := AdvancedImageSearch("Resources\close_items.png", X1, Y1, W_close, H_close)

            if (resclose.status == "success" && resclose.score >= 0.85) {
                openedMenu := true
                savedCloseX := resclose.x
                savedCloseY := resclose.y
                break
            } 
            if (A_TickCount - StartTime > 4000) {
                break
            }
            Sleep(500)
        }

        if (openedMenu) {
            break
        }
    }

    if (!openedMenu) {
        LogToConsole("Failed to equip towers! The macro can't see the towers menu! Reloading...", true, false)
        Sleep(400)
        SafeReload()
        return
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
    if (A_KeyDelay < 5) {
    SendInput("Sniper")
    } else {
        SendText("Sniper")
    }
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
                    Sleep 20
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
    
    allEquipped := true
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

        kdelay := A_KeyDelay
        changedDelay := false
        if (A_KeyDelay < 5) {
        SendInput(towerToEnter)
        } else {
            SendText(towerToEnter)
        }
        Sleep(500)
        Click(srchX+10, ScaleY(409))
        Sleep(500)

        X1 := Round(rw * 0.4)
        Y1 := Round(rh * 0.5)
        W := Round(rw * 0.9) - X1
        H := rh - Y1

        equippedThisTower := false
        TowerStart := A_TickCount
        Loop {
            getRobloxPos(,,&w,&h)
            baseScale := h / 1009

            resEquip := AdvancedImageSearch("Resources\equip.png", X1, Y1, W, H, 0.5 * baseScale, 1.4, 0.025)

            if (resEquip.status == "success" && resEquip.score > 0.4) {
                If (PixelSearch(&eX, &eY, resEquip.x-40, resEquip.y-25, resEquip.x+40, resEquip.y+25, 0x45DC4A, 7)) {
                    Click(resEquip.x, resEquip.y)
                    equippedThisTower := true
                    
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
        allEquipped := allEquipped && equippedThisTower
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
    
    if strict && !allEquipped
        return false
    LogToConsole("Successfully equipped towers: " towers, true, false)
    IniWrite(1, StateFile, "State", "Equipped")
}

CheckRestart() {
    global IsRestarting, difficulty, UseRestartBtn, UsePlayAgainBtn, CollectPlaytimeRewards, requiredTowers, AutoEquip

    shouldCollectRewards := (CollectPlaytimeRewards = "1" || CollectPlaytimeRewards = 1) && CheckDailyRewardTime() && (AutorunStartTime = 0 || (A_TickCount - AutorunStartTime) > 300000)
    shouldEquip := !Number(IniRead(StateFile, "State", "Equipped", 0))

    nextTower := BatchXPActiveTower(SettingsFile)
    equippedTower := IniRead(StateFile, "TowerXP", "Active", "")
    changeTower := IniRead(SettingsFile, "TowerXP", "Enabled", 0) = 1
        && nextTower && equippedTower != nextTower.name
    if (changeTower || (shouldCollectRewards && !MultiplayerEnabled)) {
        LogToConsole(changeTower ? "Returning to lobby to equip the next Tower XP target." : "Navigating to lobby to check playtime rewards...", true, false)
        IsRestarting := false

        closeRoblox_ := true
        if (GetRobloxHWND()){
            ActivateRoblox()
            getRobloxPos(,,&w,&h)
            Loop 2 {
                play_btn := AdvancedImageSearch("Resources/Play.png", Round(w * 0.25), Round(h * 0.66), Round(w * 0.75), Round(h * 0.34))
                if (play_btn.status = "success" && play_btn.score > 0.65) {
                    closeRoblox_ := false
                    break
                } 
                Sleep 150
            }
        }
        
        if (closeRoblox_) {
            CloseRoblox()
            RunRoblox()
        }

        if (shouldEquip && AutoEquip && !BatchUsesLobbyEquip()) {
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
                if (MultiplayerEnabled && PlayerRole = "Host") {
                    Sleep 5000
                }

                res := resRestart.score > resRestart2.score ? resRestart : resRestart2
                IsRestarting := true
                LogToConsole("Restarting the match")
                if !(MultiplayerEnabled) { 
                    Click(res.x, res.y)
                } else {
                    totalPartyMembers := 0
                    Loop Parse, PartyMembers, "," {
                        member := Trim(A_LoopField)
                        if (member = "") {
                            continue
                        }
                        totalPartyMembers++
                    }
                    if totalPartyMembers = 2 || totalPartyMembers = 3 {
                        if PlayerRole != "Host" {
                            Click(res.x, res.y)
                        }
                    } else {
                        if PlayerRole = "Host" {
                            Click(res.x, res.y)
                        }
                    }
                }
                Sleep(150)
                startWatchdog()
                return
            }
        }

        if (UsePlayAgainBtn = "1" || UsePlayAgainBtn = 1) {

            resReplay := AdvancedImageSearch("Resources\PlayAgain.png", 0, h * 0.5, w, h*0.5, 0.5, 1.5, 0.025)
            
            if (resReplay.status == "success" && resReplay.score > 0.64) {
                if (MultiplayerEnabled && PlayerRole = "Host") {
                    Sleep 5000
                }
                if (!MultiplayerEnabled || PlayerRole = "Host") {
                    Click(resReplay.x, resReplay.y)
                }
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
    if (shouldEquip && AutoEquip && !BatchUsesLobbyEquip()) {
        if !BatchUsesLobbyEquip()
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

            play_btn := AdvancedImageSearch("Resources/Play.png", Round(w * 0.25), Round(h * 0.66), Round(w * 0.75), Round(h * 0.34))
            if (play_btn.status = "success" && play_btn.score > 0.65) {
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

SwitchToNextStrategy(&stratName) {
    global CurrentRotationIndex, Strategy1Path, Strategy2Path, requiredTowers
    global CurrentStratStartTime, CurrentRunCount, StateFile, RunningStrategy, difficulty

    if (CurrentRotationIndex = 1) {
        LoadStrategyFile(Strategy2Path)
        CurrentRotationIndex := 2
        IniWrite(2, StateFile, "State", "CurrentRotationIndex")
        stratName := Strategy2Path 
    } else {
        LoadStrategyFile(Strategy1Path)
        CurrentRotationIndex := 1
        IniWrite(1, StateFile, "State", "CurrentRotationIndex")
        stratName := Strategy1Path
    }

    CurrentStratStartTime := A_TickCount
    CurrentRunCount := 0
    IniWrite(A_TickCount, StateFile, "State", "CurrentStratStartTime")
    IniWrite(0, StateFile, "State", "CurrentRunCount")

    IniWrite(1, StateFile, "State", "Running")
    IniWrite(stratName, StateFile, "State", "Strategy")

    return true
}

WaitForLobbyLoad() {
    global difficulty, MultiplayerEnabled, PlayerRole

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
        if (!MultiplayerEnabled || PlayerRole = "Host") {
            SelectMap(res.x, res.y)
        } else {
            Click(Round(w*0.5), res.y)
            Sleep 250
            Click(Round(w*0.6), res.y)
            if (modifiers != "")
                ApplyModifiers()
        }
    }
}

JoinGame() {
    if !BatchPrepareJoin() {
        LogToConsole("Could not prepare the farming loadout. Check the preset, Abstract slot and rotation settings.")
        StopStrategy()
        ExitApp()
    }
    global SendCurrenciesEnabled, WebhookEnabled, difficulty, CollectPlaytimeRewards, PlayerRole, MultiplayerEnabled
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
            }
            
            LowerGraphics()
            Sleep(50)

            if (MultiplayerEnabled) {
                if (PlayerRole = "Member") {
                    AcceptInvite(res.x, res.y)
                    WaitForLobbyLoad()
                    return
                } else {
                    CreateParty(res.x, res.y)
                }
                    
            }

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
    } else {
        modeImg := "Survival.png"
    }

    if modeImg != "" {
        getRobloxPos(,, &w, &h)
        Loop {
            if (A_TickCount - startTime > 20000) {
                newStartTime := A_TickCount
                res := AdvancedImageSearch("Resources\Play.png", x1, y1, x2, y2)
                if (res.status == "success" && res.score > 0.65) {   
                    Click(res.x, res.y)
                    startTime := A_TickCount
                } else {
                    if (A_TickCount - newStartTime > 40000) {
                        SafeReload()
                        break
                    }
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

    startTime := A_TickCount
    Loop {
        getRobloxPos(,, &w, &h)
        if (A_TickCount - startTime > 20000) {
            newStartTime := A_TickCount
            res := AdvancedImageSearch("Resources\Play.png", x1, y1, x2, y2)
            if (res.status == "success" && res.score > 0.7) {   
                Click(res.x, res.y)
                startTime := A_TickCount
            } else {
                if (A_TickCount - newStartTime > 40000) {
                    SafeReload()
                    break
                }
            }
        }
        res := AdvancedImageSearch("Resources/" difficulty ".png", 0, 0, w, h)
        if (res.status = "success" && res.score >= 0.7) {
            Click(res.x, res.y)
            break 
        }
        Sleep(100)
    }
    Sleep(300)

    startTime := A_TickCount
    Loop {
        getRobloxPos(,, &w, &h)
        if (A_TickCount - startTime > 40000) { 
            SafeReload()
            break
        }
        if (!MultiplayerEnabled) {
            res := AdvancedImageSearch("Resources/Solo.png", 0, Round(h * 0.2), Round(w * 0.7), Round(h * 0.55))
            if (res.status = "success" && res.score >= 0.7) {
                Click(res.x, res.y)
                break 
            }
        } else {
            totalPartyMembers := 0
            Loop Parse, PartyMembers, "," {
                member := Trim(A_LoopField)
                if (member = "") {
                    continue
                }
                totalPartyMembers++
            }
            if (totalPartyMembers = 1) {
                res := AdvancedImageSearch("Resources/duo.png", Round(w * 0.2), Round(h * 0.2), Round(w * 0.6), Round(h * 0.6))
            } else if (totalPartyMembers = 2) {
                res := AdvancedImageSearch("Resources/trio.png", Round(w * 0.2), Round(h * 0.2), Round(w * 0.6), Round(h * 0.6))
            } else if (totalPartyMembers = 3) {
                res := AdvancedImageSearch("Resources/quad.png", Round(w * 0.2), Round(h * 0.2), Round(w * 0.6), Round(h * 0.6))
            } else {
                res := AdvancedImageSearch("Resources/Solo.png", 0, Round(h * 0.2), Round(w * 0.7), Round(h * 0.55))
            }

            if (res.status = "success" && res.score >= 0.7) {
                Click(res.x, res.y)
                break 
            }

        }
        Sleep(100)
    }
    WaitForLobbyLoad()
}

CreateParty(x, y) {
    global PartyMembers
    StartTime := A_TickCount
    CloseX := 0
    CloseY := 0

    Loop {
        Click(x+200, y)

        InnerStartTime := A_TickCount

        if (A_TickCount - StartTime > 10000) {
            LogToConsole("Failed to Create Party: The macro can't see the menu!", true)
            SafeReload()
        }

        getRobloxPos(,,&w,&h)
        Loop {
            resclose := AdvancedImageSearch("Resources\close.png", Round(w*0.25), Round(h*0.1), Round(w*0.5), Round(h*0.4))

            If (resclose.status = "success" && resclose.score >= 0.7) {
                openedMenu := true
                CloseX := resclose.x
                CloseY := resclose.y
                break 2
            } 
            if (A_TickCount - InnerStartTime > 5000)
                break
            Sleep(500)
        }
    }

    Sleep 150

    create_btn := AdvancedImageSearch("Resources\create_party.png", Round(w*0.25), Round(h*0.5), Round(w*0.5), Round(h*0.5))
    Sleep 500
    if (create_btn.score > 0.58) {
        Click(create_btn.x, create_btn.y)
        LogToConsole("Successfully created the party")
    } else {
        LogToConsole("Failed to Create Party: The macro can't see the create party button!", true)
        SafeReload()
    }

    Sleep 300

    invited := false

    SetTimer(CancelInviteIfAppeared, 7500)

    Loop 3 {
        search_bar := AdvancedImageSearch("Resources\type_to_search.png", Round(w*0.25), Round(h*0.1), Round(w*0.5), Round(h*0.3))
        if (search_bar.score > 0.58) {
            Loop Parse, PartyMembers, "," {
                member := Trim(A_LoopField)
                if (member = "") {
                    continue
                }
                Click(search_bar.x, search_bar.y)
                Sleep(100)
                if (A_KeyDelay < 5) {
                SendInput(member)
                } else {
                    SendText(member)
                }
                Sleep(100)
                Click(search_bar.x + ScaleX(75), search_bar.y + ScaleY(92))
                Sleep(50)

                LogToConsole("Successfully invited " member)
            }
            invited := true
            break
        }
        Sleep 1500
    }

    if (!invited) {
        LogToConsole("Failed to Create Party: The macro can't see the search_bar!", true)
        SafeReload()
    }

    Sleep 300

    totalPartyMembers := 0
    Loop Parse, PartyMembers, "," {
        member := Trim(A_LoopField)
        if (member = "") {
            continue
        }
        totalPartyMembers++
    }

    xs := 0
    sy := Round(h*0.1)

    waitStartTime := A_TickCount

    Loop {
        x_btn := AdvancedImageSearch("Resources\x.png", Round(w*0.25), sy, Round(w*0.25), Round(h*0.75) - sy)
        if (x_btn.score > 0.7) {

            xs++
            sy := x_btn.y+x_btn.h/2
        }
        LogToConsole("Waiting for " totalPartyMembers " players... (" xs "/"  totalPartyMembers ")")
        if (xs >= totalPartyMembers) {
            LogToConsole("All players: " PartyMembers " have joined!")
            break
        }
        if (A_TickCount - waitStartTime > 30000) { 
            sy := Round(h*0.1)
            xs := 0
            Loop Parse, PartyMembers, "," {
                member := Trim(A_LoopField)
                if (member = "") {
                    continue
                }
                Click(search_bar.x, search_bar.y)
                Sleep(100)
                kdelay := A_KeyDelay
                changedDelay := false
                if (A_KeyDelay < 5) {
                SendInput(member)
                } else {
                    SendText(member)
                }
                Sleep(100)
                Click(search_bar.x + ScaleX(75), search_bar.y + ScaleY(92))
                Sleep(50)

                LogToConsole("Successfully invited " member)
            }
            waitStartTime := A_TickCount
        }
        Sleep 5000
    }

    SetTimer(CancelInviteIfAppeared, 0)

    resclose := AdvancedImageSearch("Resources\close.png", Round(w*0.25), Round(h*0.1), Round(w*0.5), Round(h*0.4))

    If (resclose.status = "success" && resclose.score >= 0.7) {
        Click(resclose.x, resclose.y)
    } 
    Sleep 200
}

CancelInviteIfAppeared(*) {
    getRobloxPos(,,&w,&h)

    cancel_btn := AdvancedImageSearch("Resources/cancel_invite.png", Round(w * 0.2), Round(h * 0.2), Round(w * 0.6), Round(h * 0.65))
    if (cancel_btn.status = "success" && cancel_btn.score >= 0.65) {
        Click(cancel_btn.x, cancel_btn.y)
    }
}

AcceptInvite(x, y) {

    StartTime := A_TickCount
    CloseX := 0
    CloseY := 0
    Loop {
        Click(x+200, y)

        InnerStartTime := A_TickCount

        if (A_TickCount - StartTime > 15000) {
            LogToConsole("Failed to Create Party: The macro can't see the menu!", true)
            SafeReload()
        }

        getRobloxPos(,,&w,&h)
        Loop {
            resclose := AdvancedImageSearch("Resources\close.png", Round(w*0.25), Round(h*0.1), Round(w*0.5), Round(h*0.4))

            If (resclose.status = "success" && resclose.score >= 0.7) {
                openedMenu := true
                CloseX := resclose.x
                CloseY := resclose.y
                break 2
            } 
            if (A_TickCount - InnerStartTime > 5000)
                break
            Sleep(500)
        }
    }


    Sleep 150

    clickedInviteBtn := false

    search_bar_X := 0
    search_bar_Y := 0

    Loop 5 {
        create_btn := AdvancedImageSearch("Resources\invites_btn.png", Round(w*0.25), 0, Round(w*0.5), Round(h*0.4))
        if (create_btn.score > 0.58) {
            clickedInviteBtn := true
            Click(create_btn.x, create_btn.y)
            search_bar_X := create_btn.x - 250
            search_bar_Y := create_btn.y + 50
            break
        }
        Sleep 200
    }

    if (!clickedInviteBtn) {
        LogToConsole("Failed to Accept Invite: The macro can't see the invites button!", true)
        Sleep 300
        SafeReload()
    }

    invited := false

    Sleep 200

    Click(search_bar_X, search_bar_Y)
    Sleep(100)
    if (A_KeyDelay < 5) {
    SendInput(HostName)
    } else {
        SendText(HostName)
    }
    Sleep 100

    InnerStartTime := A_TickCount
    Loop {
        LogToConsole("Waiting for an invite from host: " HostName "...")
        accept_btn := AdvancedImageSearch("Resources\accept_invite.png", Round(w*0.25), Round(h*0.1), Round(w*0.5), Round(h*0.3))
        if (accept_btn.score > 0.66) {
            Click(accept_btn.x, accept_btn.y)
            if !(ReadMessage(["Error", "Party", "not", "found"])) {
                LogToConsole("Successfully accepted an invitation from " HostName)
                break
            }
        }
        if (A_TickCount - InnerStartTime > 180000) { 
            LogToConsole("Didn't receive an invite from the host within 3 minutes! Reloading the script and rejoining...", true)
            SafeReload()
        }
        Sleep 5000
    }

    resclose := AdvancedImageSearch("Resources\close.png", Round(w*0.25), Round(h*0.1), Round(w*0.5), Round(h*0.4))

    If (resclose.status = "success" && resclose.score >= 0.7) {
        Click(resclose.x, resclose.y)
    }
}

checkCondition(*) {
    global LeaveCondition, PartyMembers

    totalPartyMembers := 0
    Loop Parse, PartyMembers, "," {
        member := Trim(A_LoopField)
        if (member = "") {
            continue
        }
        totalPartyMembers++
    }

    ActivateRoblox()
    getRobloxPos(&rX, &rY, &w,&h)

    img := ""
    if (LeaveCondition = "All") {
        img := "Resources/(1"
    } else {
        if (totalPartyMembers = 1) {
            img := "Resources/(2"
        } else if (totalPartyMembers = 2) {
            img := "Resources/(3"
        } else if (totalPartyMembers = 3) {
            img := "Resources/(4"
        }
    }

    if (img = "")
        return

    result := AdvancedImageSearch(img ".png", Round(w*0.5), rY, w, h)
    if (result.score > 0.8) {
        if (LeaveCondition = "All") {
            LogToConsole("All players are gone! Closing roblox and reloading the macro...", true)
            CloseRoblox()
            SafeReload()
        }
    } else {
        LogToConsole("Someone has just left! Closing roblox and reloading the macro...", true)
        CloseRoblox()
        SafeReload()
    }

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
        voteConfirmed := false
        Loop 3 {
            LogToConsole("Resetting vote board position (attempt " A_Index " of 3).")
            ActivateRoblox()
            resetCharacter()
            Sleep(7500)
            AlignCamera(false, false)
            getRobloxPos(,,&w,&h)
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

            if !FindVoteBoardPrompt(w, h)
                continue

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
            if (A_KeyDelay < 5) {
            SendInput(gamemap)
            } else {
                SendText(gamemap)
            }
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
            if !FindVoteBoardPrompt(w, h, true) {
                LogToConsole("Map vote was not confirmed. Retrying the vote board.", true)
                continue
            }
            voteConfirmed := true
            break
        }
        if !voteConfirmed {
            LogToConsole("Could not confirm a map vote. Stopping the strategy without pressing Ready.", true)
            StopStrategy()
            Exit()
        }
    }
    Sleep(100)

    Click(readyX, readyY)
    waitReady()
}


FindVoteBoardPrompt(w, h, castVote := false) {
    promptName := castVote ? "Map vote" : "Vote board"
    moves := [["sc020", 300, "right"], ["sc01e", 600, "left"]]
    if castVote
        moves.Push(["sc011", 300, "forward"])
    Loop moves.Length + 1 {
        Loop 3 {
            prompt := AdvancedImageSearch("Resources\e_prompt.png", Round(w*0.15), Round(h*0.18), Round(w*0.70), Round(h*0.58), 0.6, 1.5)
            if (prompt.status = "success" && prompt.score >= 0.7) {
                if !castVote
                    return true
                SendEvent("{sc012 down}")
                Sleep(800)
                SendEvent("{sc012 up}")
                if WaitForMapVoteTimer(w, h)
                    return true
                break
            }
            Sleep(150)
        }
        if moves.Has(A_Index) {
            move := moves[A_Index]
            LogToConsole(promptName " E interaction not confirmed. Nudging " move[3] ".", true)
            SendEvent("{" move[1] " down}")
            Sleep(move[2])
            SendEvent("{" move[1] " up}")
            Sleep(150)
        }
    }
    return false
}

WaitForMapVoteTimer(w, h) {
    hwnd := GetRobloxHWND()
    if !hwnd
        return false
    WinGetClientPos(&x, &y,,, "ahk_id " hwnd)
    region := (x + Round(w*0.30)) "|" (y + Round(h*0.085)) "|" Round(w*0.40) "|" Round(h*0.115)
    Loop 5 {
        Sleep(250)
        bitmap := Gdip_BitmapFromScreen(region)
        if !bitmap
            continue
        try {
            timerText := OCR.FromBitmap(bitmap, {scale: 2}).Text
            if RegExMatch(timerText, "\b\d{1,2}\s*:\s*[0-5]\d\b")
                return true
        } catch {
            ; A failed capture or OCR read is not confirmation.
        } finally {
            Gdip_DisposeImage(bitmap)
        }
    }
    return false
}

CheckTheMapF() {
    global gamemap, CheckTheMap, modifiers

    modifiers_str := (modifiers is Array) ? Join(modifiers) : String(modifiers)
    mapImage := "Resources\Maps\" gamemap ".png"
    deadAheadFallback := "Resources\Maps\Dead Ahead - fallback.png"

    if (FileExist(mapImage) && CheckTheMap = 1 && !InArray(SpecialMaps, gamemap) && !RegExMatch(modifiers_str, "i)fog"))
    {
        AlignCamera(false, false, false)

        LogToConsole("Checking the map... (Make sure you have the lowest graphics)")


        getRobloxPos(,,&w,&h)
        FoundMap := false
        hasFallback := gamemap = "Dead Ahead" && FileExist(deadAheadFallback)
        Loop 2 {
            res := AdvancedImageSearch(mapImage, 0, 0, w, h)

            if (res.score > 0.62) {
                FoundMap := true
                break
            }

            if hasFallback {
                res := AdvancedImageSearch(deadAheadFallback, 0, 0, w, h)
                if (res.score > 0.62) {
                    FoundMap := true
                    break
                }
            }
            
            if (A_Index = 1) {
                LogToConsole("Map view not detected. Realigning camera once.")
                AlignCamera(false, false, false)
                Sleep(350)
            }
        }

        if (!FoundMap) {
            LogToConsole("Can't detect the map! Reloading script...", true)
            Sleep 300
            SafeReload()
        }
        return FoundMap
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
        if (A_KeyDelay < 5) {
        SendInput(modifier)
        } else {
            SendText(modifier)
        }
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
    global readyX, readyY, MultiplayerEnabled, PlayerRole
    start := A_TickCount
    getRobloxPos(&x, &y, &w, &h)
    KillSubmacros()
    Loop {
        wt := 40000
        if (MultiplayerEnabled && PlayerRole = "Member") {
            wt := 90000
        }
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
    global UseTimeScale, TimeScaleMode, TimeScaleMultiplier, difficulty, SettingsFile, AutorunStartTime, MultiplayerEnabled, TimescaleActive
    TimescaleActive := false
    if (MultiplayerEnabled) {
        return
    }

    getRobloxPos(&x, &y, &w, &h)
    if (UseTimeScale && difficulty != "Pizza Party" && difficulty != "Badlands II" && difficulty != "Polluted Wasteland II") { 
        budget := IniRead(SettingsFile, "TicketBudget", "Enabled", 0) = 1
        used := TowerXPNumber(StateFile, "TicketBudget", "Used")
        balance := TowerXPNumber(SettingsFile, "TicketBudget", "Balance")
        reserve := TowerXPNumber(SettingsFile, "TicketBudget", "Reserve")
        cap := TowerXPNumber(SettingsFile, "TicketBudget", "Cap")
        if budget && !TimescaleBudgetAllows(balance, reserve, cap, used) {
            LogToConsole("Timescale budget reached. Using normal speed.")
            return
        }
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
            LogToConsole("Failed to activate timescale! You are out of tickets.")
            SendToWebhookInstant("Timescale tickets ran out. The macro will continue at normal speed.", 15158332, false, true)

        } else {
            res := AdvancedImageSearch("Resources/confirm.png", Round(w * 0.25), Round(h * 0.45), Round(w * 0.50), Round(h * 0.55))
            if (res.status = "success" && res.score >= 0.67) {
                Click(res.x, res.y)
                if budget {
                    IniWrite(balance - 1, SettingsFile, "TicketBudget", "Balance")
                    IniWrite(used + 1, StateFile, "TicketBudget", "Used")
                }
            } else {
                LogToConsole("failed to activate timescale. the macro can't see the confirm/get more button... (" res.score ")", true)
                SafeReload()
                return
            }

            timescales := IniRead(StateFile, "State", "Timescale", 0)
            timescales := timescales+1
            LogToConsole("-1 Timescale ticket. Total Timescale Tickets Used: " timescales)
            SendToWebhookInstant("[" runtime := FormatRuntime(AutorunStartTime) "] -1 Timescale ticket. `n-# Total Timescale Tickets Used: " . timescales, 12370112, false)
            IniWrite(timescales, StateFile, "State", "Timescale")
            IniWrite(1, StateFile, "Earnings", "TimescaleUsed")
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
    global IsRestarting
    if (IsRestarting)
        return
    if (log) {
        LogToConsole("Aligning camera")
    }
    closeChat()

    getRobloxPos(&rx, &ry, &rw, &rh)

    MouseMove(rw/2, rh/2.5)
    Sleep 50
    SendInput "{RButton down}"
    Sleep 30
    MouseMove(0, rh/8,, "R")
    Sleep 25
    SendInput "{RButton Up}"

    If (!skipZoom) {
        Send "{WheelDown 30}"
    }
    if move
        ApplyStrategyMovement()
}

ApplyStrategyMovement() {
    global MoveEnabled, MoveDirection, MoveDuration, IsRestarting
    if (MoveEnabled && !IsRestarting) {
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

    originalX := X, originalY := Y
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
                        if (offset[1] != 0 || offset[2] != 0)
                            PersistPlacementCorrection(originalX, originalY, slotNumber, towerID, newX, newY)
                        LogToConsole("Tower " towerID " placed successfully")
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
        if (LastOpenedTowerID != "") {
            Click(ScaleX(unfocusX), ScaleY(unfocusY))
            Sleep(100)
        }
        LastChainTime := A_TickCount
        SendEvent("{" ChainKey "}")
        LogToConsole("Activated Call of Arms")
        canUseAbility := true
        if (LastOpenedTowerID != "") {
            Click(Towers[LastOpenedTowerID].x, Towers[LastOpenedTowerID].y)
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
        if (LastOpenedTowerID != "") {
            Click(ScaleX(unfocusX), ScaleY(unfocusY))
            Sleep(300)
        }
        LastCaravanTime := A_TickCount
        SendEvent("{" CaravanKey "}")
        LogToConsole("Activated Support Caravan")
        if (LastOpenedTowerID != "") {
            Click(Towers[LastOpenedTowerID].x, Towers[LastOpenedTowerID].y)
            Sleep 400
        }
        canUseAbility := true
        canBeUpgraded := true
        needtocheckTowerUI := true
    }

    if (autoDropTheBeat = "ON" && Towers.Has("DJ") && Towers["DJ"].level >= 3 && (A_TickCount - LastDropTime > 28000 / multiplier)) {

        canBeUpgraded := false

        SendEvent("{" CancelPlacementKey "}")
        if (LastOpenedTowerID != "DJ" && LastOpenedTowerID != "") {
            Click(ScaleX(unfocusX), ScaleY(unfocusY))
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

        if (LastOpenedTowerID != "" && LastOpenedTowerID != "DJ") {
            Click(Towers[LastOpenedTowerID].x, Towers[LastOpenedTowerID].y)
            Sleep 250
        }
        canBeUpgraded := true
        canUseAbility := true
        needtocheckTowerUI := true
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
    result := LocalizationMsgBox(Text, Title, boxType)
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
    global CollectPlaytimeRewards, NextCheckInterval
    
    if (CollectPlaytimeRewards != "1" && CollectPlaytimeRewards != 1) {
        return
    }
    Sleep(2000) ; load
    
    getRobloxPos(&pX, &pY, &w, &h)
    popupColor := PixelGetColor(w - 268, pY + 5, "RGB")
    r1 := (popupColor >> 16) & 0xFF, g1 := (popupColor >> 8) & 0xFF, b1 := popupColor & 0xFF
    r2 := 0xEE, g2 := 0x18, b2 := 0x18
    diff := Sqrt((r1-r2)**2 + (g1-g2)**2 + (b1-b2)**2)

    
    if (diff < 3) {
        LogToConsole("Claiming playtime rewards..")
        Click(w - 290, pY + 32)
        
        Sleep(1000)

        openedMenu := false
        Loop 15 {
            getRobloxPos(&pX, &pY, &w, &h)
            X1 := Round(w * 0.2)
            Y1 := Round(h * 0.15)
            W := Round(w * 1) - X1
            H := Round(h * 0.4) - Y1
            resclose := AdvancedImageSearch("Resources\close_freerewards.png", X1, Y1, W, H)

            If (resclose.status = "success" && resclose.score >= 0.86) {
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

            openedMenu := false
            Loop 25 {
                getRobloxPos(&pX, &pY, &w, &h)
                X1 := Round(w * 0.2)
                Y1 := Round(h * 0.15)
                W := Round(w * 1) - X1
                H := Round(h * 0.4) - Y1
                resclose := AdvancedImageSearch("Resources\close_freerewards.png", X1, Y1, W, H)

                If (resclose.status = "success" && resclose.score >= 0.86) {
                    openedMenu := true
                    break
                } 

                res := AdvancedImageSearch("Resources/Claim.png", Round(w * 0.25), Round(h * 0.4), Round(w * 0.5), Round(h * 0.5), 0.5, 2)
                if (res.status = "success" && res.score >= 0.65) {
                    Click(res.x, res.y)
                }

                Sleep(300)
            }

            if (!openedMenu) {
                LogToConsole("Failed to claim rewards!", true, false)
                return
            }
        }

        rewardsCollected := false
        
        Loop {
            getRobloxPos(&pX, &pY, &w, &h)
            
            Loop 10 {
                if (PixelSearch(&cx, &cy, Round(w*0.25), Round(h*0.2), Round(w*0.55), Round(h*0.76), 0x64F711, 5)) 
                    break
                else 
                    Sleep(100)
            }

            if (!PixelSearch(&cx, &cy, Round(w*0.25), Round(h*0.2), Round(w*0.55), Round(h*0.76), 0x64F711, 5)) {
                break
            }
            
            Click(cx, cy)
            rewardsCollected := true
            Sleep(500)

            Loop {
                resConfirm := AdvancedImageSearch("Resources/claimreward.png", Round(w*0.25), Round(h*0.5), Round(w*0.5), Round(h*0.5),,1.5)
                
                if (resConfirm.status == "success" && resConfirm.score > 0.65) {
                    Click(resConfirm.x, resConfirm.y)
                    MouseMove(ScaleX(unfocusX), ScaleY(unfocusY))
                    Sleep(800)
                } else {
                    Sleep(300)
                    resConfirm := AdvancedImageSearch("Resources/claimreward.png", Round(w*0.25), Round(h*0.5), Round(w*0.5), Round(h*0.5),,1.5)
                    if (resConfirm.status == "success" && resConfirm.score > 0.65) {
                        continue
                    }
                    break
                }
            }
        }

        Sleep(800) 
 
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

        X1 := Round(w * 0.2)
        Y1 := Round(h * 0.15)
        W := Round(w * 1) - X1
        H := Round(h * 0.4) - Y1
        resclose := AdvancedImageSearch("Resources\close_freerewards.png", X1, Y1, W, H)

        If (resclose.status = "success" && resclose.score >= 0.86) {
            Click(resclose.x, resclose.y)
        } else {
            Click(ScaleX(1126), ScaleY(307))
        }
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
    global AutoCloseChat
    if !AutoCloseChat
        return

    getRobloxPos(&pX, &pY, &w, &h)
    chatColor := PixelGetColor(pX + 138, pY + 37, "RGB")
    r1 := (chatColor >> 16) & 0xFF, g1 := (chatColor >> 8) & 0xFF, b1 := chatColor & 0xFF
    r2 := 0xF4, g2 := 0xF5, b2 := 0xF8
    diff := Sqrt((r1-r2)**2 + (g1-g2)**2 + (b1-b2)**2)
    if (diff < 12) {
        MouseGetPos(&cx, &cy)
        MouseMove(pX + 140, pY + 35, 2)
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

SendToWebhookInstant(message, embedColor := 3447003, flush := true, mentionEvent := false) {
    global WebhookInstantQueue, WebhookInstantTimerActive, WebhookEnabled
    if (!WebhookEnabled || message = "" || Trim(message) = "") { 
        return
    }
    if (flush) {
        FlushWebhookQueue()
    }

    WebhookInstantQueue.Push({msg: message, color: embedColor, mention: mentionEvent})
    
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
    mentionEvent := false
    
    while (WebhookInstantQueue.Length > 0) {
        item := WebhookInstantQueue.RemoveAt(1)
        mentionEvent := mentionEvent || item.mention
        if (Trim(item.msg) = "") 
            continue
            
        allMessages .= (allMessages != "") ? "`n" item.msg : item.msg
        
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
    payload := '{' WebhookMentionFields(mentionEvent ? WebhookMentionSettings(SettingsFile) : "") '"embeds":[{"description":"' escaped '","color":' finalColor '}]}'
    
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
    KillSubmacros()

    currentPID := DllCall("GetCurrentProcessId")
    if (A_PtrSize == 4) {
    Run('"' A_ScriptDir '\submacros\AutoHotkey32.exe" "' A_ScriptDir '\submacros\watchdog.ahk" ' currentPID, , , &watchdogPID)
    } else {
    Run('"' A_ScriptDir '\submacros\AutoHotkey64.exe" "' A_ScriptDir '\submacros\watchdog.ahk" ' currentPID, , , &watchdogPID)
    }
}

KillSubmacros() {
    global watchdogPID
    
    if (watchdogPID != "") {
        try {
            RunWait(A_ComSpec " /c taskkill /PID " watchdogPID " /F /T", , "Hide")
        } catch Error {
        }
        watchdogPID := ""
    }
    
    try {
        for process in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_Process WHERE Name = 'AutoHotkey64.exe' OR Name = 'AutoHotkey.exe' OR Name = 'AutoHotkey32.exe'") {
            try {
                cmd := process.CommandLine
                if (InStr(cmd, "watchdog.ahk")) {
                    try {
                        pID := process.ProcessId 
                        try {
                            ProcessClose(pID)
                        }

                        process.Terminate()
                    } catch Error {
                        continue
                    }
                }
            } catch Error {
                continue
            }
        }
    } catch Error {
        return
    }
}


HandleExit(ExitReason, ExitCode) {
    global StateFile, SettingsFile

    if (RunningStrategy) {
        KillSubmacros()
        if (MacroClosingManually || ExitReason = "Close" || ExitReason = "Menu" || ExitReason = "Shutdown" || ExitReason = "Logoff") {
            IniWrite(0, StateFile, "State", "Running")
            IniDelete(StateFile, "State", "Strategy")
            IniDelete(StateFile, "State", "StartTime")
            IniDelete(StateFile, "State", "CurrentStratStartTime")
            IniDelete(StateFile, "State", "CurrentRotationIndex")
            IniDelete(StateFile, "State", "CurrentRunCount")
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

ShutdownMacro(reason, code) {
    global MacroClosing
    Critical("On")
    MacroClosing := true
    if reason != "Reload" && reason != "Single"
        try SettingsFlush()
    for callback in [Hoverwatchdog, FarmingShow, ProcessCommands, UseAbilities, checkCondition, CheckPopups,
        CancelInviteIfAppeared, ProcessWebhookQueue, ProcessWebhookInstantQueue]
        SetTimer(callback, 0)
    try HandleExit(reason, code)
    catch as err
        OutputDebug("Ultimate Macro shutdown: " err.Message)
    try CleanupGdip(reason, code)
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
            
            result := LocalizationMsgBox(msgText, "Missing OCR Language", 48 + 4)
            
            if (result = "Yes") {
                Run("ms-settings:regionlanguage")
            }
            
            ExitApp()
        }
    }
}

SendScreenshot(pBitmap := Gdip_BitmapFromScreen(), description := "", color := 12434877, screenshot := WebhookScreenshots) {
    global WebhookLink

    escapedDescription := StrReplace(description, "\", "\\")
    escapedDescription := StrReplace(escapedDescription, '"', '\"')
    escapedDescription := StrReplace(escapedDescription, "`n", "\n")

    fields := []

    if (screenshot == "0" || screenshot == 0) {
        payload_json := '{"embeds": [{"description": "' escapedDescription '", "color": ' color '}]}'
        fields.Push(Map("name", "payload_json", "content-type", "application/json", "content", payload_json))
    } 
    else {
        payload_json := '{"embeds": [{"description": "' escapedDescription '", "color": ' color ', "image": {"url": "attachment://screenshot.png"}}]}'
        fields.Push(Map("name", "payload_json", "content-type", "application/json", "content", payload_json))
        fields.Push(Map("name", "files[0]", "filename", "screenshot.png", "content-type", "image/png", "pBitmap", pBitmap))
    }
    
    CreateFormData(&postdata, &contentType, fields)

    if (screenshot != "0" && screenshot != 0) {
        try Gdip_DisposeImage(pBitmap)
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

CreateGradientButton(w, h, r, colorStart, colorEnd, shadowColor, strokeColor, btnText := "...", textFont := "Segoe UI", textSize := 12, gradientDirection := 0) {
    hdc := GetDC(0)
    hbm := CreateDIBSection(w, h)
    hdcMem := CreateCompatibleDC()
    obm := SelectObject(hdcMem, hbm)
    G := Gdip_GraphicsFromHDC(hdcMem)
    
    DllCall("gdiplus\GdipSetInterpolationMode", "ptr", G, "int", 7)
    
    pad := 6
    bx := pad, by := pad, bw := w - (pad * 2), bh := h - (pad * 2)

    Gdip_SetSmoothingMode(G, 4)
    Gdip_SetTextRenderingHint(G, 4) 

    Loop 6 {
        alpha := Format("{:02X}", Integer(25 / A_Index))
        currentShadow := "0x" alpha SubStr(shadowColor, -6)
        pBrushShadow := Gdip_BrushCreateSolid(currentShadow)
        
        offset := A_Index * 0.7
        pPathShadow := Gdip_CreateRoundRectanglePath(bx - (offset*0.5), by + offset, bw + offset, bh, r)
        Gdip_FillPath(G, pBrushShadow, pPathShadow)
        Gdip_DeletePath(pPathShadow)
        Gdip_DeleteBrush(pBrushShadow)
    }

    pBrushGrad := Gdip_CreateLineBrushFromRect(bx, by, bw, bh, colorStart, colorEnd, gradientDirection, 1)
    pPathMain := Gdip_CreateRoundRectanglePath(bx, by, bw, bh, r)
    Gdip_FillPath(G, pBrushGrad, pPathMain)

    pPathStroke := Gdip_CreateRoundRectanglePath(bx + 0.5, by + 0.5, bw - 1, bh - 1, r)
    pPenStroke := Gdip_CreatePen(strokeColor, 1)
    Gdip_DrawPath(G, pPenStroke, pPathStroke)
    Gdip_DeletePath(pPathStroke)
    Gdip_DeletePen(pPenStroke)
    
    hFormat := Gdip_StringFormatCreate(0x4000) 
    Gdip_SetStringFormatAlign(hFormat, 1)     
    DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", hFormat, "int", 1) 
    
    Gdip_SetSmoothingMode(G, 0)
    Gdip_SetTextRenderingHint(G, 0) 

    hFontfamily := Gdip_FontFamilyCreate(textFont)
    hFont := Gdip_FontCreate(hFontfamily, textSize, 1) 
    RC := Buffer(16, 0)
    
    NumPut("float", bx, "float", by + 1, "float", bw, "float", bh, RC)
    pBrushTxtShadow := Gdip_BrushCreateSolid("0x99000000")
    
    Gdip_DrawString(G, btnText, hFont, hFormat, pBrushTxtShadow, &RC)
    Gdip_DeleteBrush(pBrushTxtShadow)
    
    NumPut("float", bx, "float", by, "float", bw, "float", bh, RC)
    pBrushTxtMain := Gdip_BrushCreateSolid("0xFFFFFFFF")
    
    Gdip_DrawString(G, btnText, hFont, hFormat, pBrushTxtMain, &RC)
    Gdip_DeleteBrush(pBrushTxtMain)

    Gdip_DeleteFont(hFont)
    Gdip_DeleteFontFamily(hFontfamily)
    Gdip_DeleteStringFormat(hFormat)
    Gdip_DeletePath(pPathMain)
    Gdip_DeleteBrush(pBrushGrad)
    
    SelectObject(hdcMem, obm)
    DeleteDC(hdcMem)
    ReleaseDC(0, hdc)
    Gdip_DeleteGraphics(G)
    
    return hbm
}

CreateFrame(w, h, r, bgColor, strokeOuter, strokeInner) {
    hbm := CreateDIBSection(w, h), hdcMem := CreateCompatibleDC()
    obm := SelectObject(hdcMem, hbm), G := Gdip_GraphicsFromHDC(hdcMem)
    Gdip_SetSmoothingMode(G, 4)

    pBrushBg := Gdip_BrushCreateSolid(bgColor)
    pPathMain := Gdip_CreateRoundRectanglePath(0, 0, w, h, r)
    Gdip_FillPath(G, pBrushBg, pPathMain)

    pPathOuter := Gdip_CreateRoundRectanglePath(0.5, 0.5, w - 1, h - 1, r)
    pPenOuter := Gdip_CreatePen(strokeOuter, 1)
    Gdip_DrawPath(G, pPenOuter, pPathOuter)

    pPathInner := Gdip_CreateRoundRectanglePath(1.5, 1.5, w - 3, h - 3, r - 1)
    pPenInner := Gdip_CreatePen(strokeInner, 1)
    Gdip_DrawPath(G, pPenInner, pPathInner)

    Gdip_DeletePen(pPenInner), Gdip_DeletePath(pPathInner)
    Gdip_DeletePen(pPenOuter), Gdip_DeletePath(pPathOuter)
    Gdip_DeletePath(pPathMain), Gdip_DeleteBrush(pBrushBg)
    SelectObject(hdcMem, obm), DeleteDC(hdcMem), Gdip_DeleteGraphics(G)
    return hbm
}

RefreshStrategyCardFrames() {
    global StrategyCardBackgrounds, CardW, CardH
    if !IsSet(StrategyCardBackgrounds)
        return
    for ctrl in StrategyCardBackgrounds {
        bitmap := CreateFrame(CardW, CardH, 10, "0xFF" MacroAppearance.Color("surface", "161616"),
            "0xFF" MacroAppearance.Color("secondary", "1D1D1D"), "0x62" MacroAppearance.Color("border", "302D2D"))
        oldBitmap := SendMessage(0x172, 0, bitmap, ctrl.Hwnd)
        if oldBitmap && oldBitmap != bitmap
            DeleteObject(oldBitmap)
    }
}


CreateScrollThumb(w, h, r, colorStart, colorEnd, glowColor) {
    hbm := CreateDIBSection(w, h), hdcMem := CreateCompatibleDC()
    obm := SelectObject(hdcMem, hbm), G := Gdip_GraphicsFromHDC(hdcMem)
    Gdip_SetSmoothingMode(G, 4)

    Loop 3 {
        alpha := Format("{:02X}", Integer(30 / A_Index))
        pBrush := Gdip_BrushCreateSolid("0x" alpha SubStr(glowColor, -6))
        pPath := Gdip_CreateRoundRectanglePath(0, A_Index*0.5, w, h, r)
        Gdip_FillPath(G, pBrush, pPath), Gdip_DeletePath(pPath), Gdip_DeleteBrush(pBrush)
    }
    
    pBrushGrad := Gdip_CreateLineBrushFromRect(0, 0, w, h, colorStart, colorEnd, 1, 1)
    pPathMain := Gdip_CreateRoundRectanglePath(0, 0, w, h, r)
    Gdip_FillPath(G, pBrushGrad, pPathMain)
    
    Gdip_DeletePath(pPathMain), Gdip_DeleteBrush(pBrushGrad)
    SelectObject(hdcMem, obm), DeleteDC(hdcMem), Gdip_DeleteGraphics(G)
    return hbm
}


CreateGlowButton(w, h, r, colorStart, colorEnd, glowColor) {
    hdc := GetDC(0)
    hbm := CreateDIBSection(w, h)
    hdcMem := CreateCompatibleDC()
    obm := SelectObject(hdcMem, hbm)
    G := Gdip_GraphicsFromHDC(hdcMem)
    Gdip_SetSmoothingMode(G, 4)

    pad := 5
    bx := pad, by := pad, bw := w - (pad * 2), bh := h - (pad * 2)

    Loop 5 {
        alpha := Format("{:02X}", Integer(15 - (A_Index * 2)))
        currentGlow := SubStr(glowColor, 1, 4) . alpha . SubStr(glowColor, 7)
        
        pBrushGlow := Gdip_BrushCreateSolid(currentGlow)
        pPathGlow := Gdip_CreateRoundRectanglePath(bx - A_Index, by - A_Index, bw + (A_Index * 2), bh + (A_Index * 2), r)
        Gdip_FillPath(G, pBrushGlow, pPathGlow)
        Gdip_DeletePath(pPathGlow)
        Gdip_DeleteBrush(pBrushGlow)
    }

    pBrushGrad := Gdip_CreateLineBrushFromRect(bx, by, bw, bh, colorStart, colorEnd, 1, 1)
    pPathMain := Gdip_CreateRoundRectanglePath(bx, by, bw, bh, r)
    Gdip_FillPath(G, pBrushGrad, pPathMain)

    pPenStroke := Gdip_CreatePen("0x60FFFFFF", 1)
    Gdip_DrawPath(G, pPenStroke, pPathMain)

    Gdip_DeletePen(pPenStroke)
    Gdip_DeletePath(pPathMain)
    Gdip_DeleteBrush(pBrushGrad)
    SelectObject(hdcMem, obm)
    DeleteDC(hdcMem)
    ReleaseDC(0, hdc)
    Gdip_DeleteGraphics(G)
    
    return hbm
}

Gdip_CreateRoundRectanglePath(x, y, w, h, r) {
    DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &pPath := 0)
    DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", x, "float", y, "float", r*2, "float", r*2, "float", 180, "float", 90)
    DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", x+w-r*2, "float", y, "float", r*2, "float", r*2, "float", 270, "float", 90)
    DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", x+w-r*2, "float", y+h-r*2, "float", r*2, "float", r*2, "float", 0, "float", 90)
    DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", x, "float", y+h-r*2, "float", r*2, "float", r*2, "float", 90, "float", 90)
    DllCall("gdiplus\GdipClosePathFigure", "ptr", pPath)
    return pPath
}

ReadBundledStrategyInfo(path) {
    info := Map()
    inInfo := false
    for line in StrSplit(FileRead(path, "UTF-8"), Chr(10), Chr(13)) {
        line := Trim(line)
        if RegExMatch(line, "^\[([^\]]+)\]$", &section) {
            if inInfo
                break
            inInfo := section[1] = "Info"
        } else if inInfo && RegExMatch(line, "^([a-z]+)\s*=\s*(.*)$", &field) {
            info[StrLower(field[1])] := field[2]
        }
    }
    return info
}

StratInfo(title, author, towers, modifiers, desc, income, duration := "") {
    text := title (author != "" ? " by " author : "") "`n"
    text .= "-----------------------------------------`n`n"
    text .= "Required towers:`t" towers "`n"
    text .= "Modifiers:`t" modifiers "`n`n"
    
    if duration != ""
        text .= "Duration: " duration "`n"
    if income != ""
        text .= "Earnings: " income "`n`n"
    if (desc != "")
        text .= StrReplace(desc, "\n", "`n") "`n`n"
        
    text .= "-----------------------------------------`n"
    text .= "* To edit the strategy, open the strat file in the notepad.`n"

    LocalizationMsgBox(text, "Strategy Info | " title, 0x1040)
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

RunAutoAbTool(*) {
    if (A_PtrSize == 4) {
    Run('"' A_ScriptDir '\submacros\AutoHotkey32.exe" "' A_ScriptDir '\submacros\auto_coa.ahk" ')
    } else {
        Run('"' A_ScriptDir '\submacros\AutoHotkey64.exe" "' A_ScriptDir '\submacros\auto_coa.ahk" ')
    }
}

RunAutoSpinTool(*) {
    if (A_PtrSize == 4) {
    Run('"' A_ScriptDir '\submacros\AutoHotkey32.exe" "' A_ScriptDir '\submacros\auto_spin.ahk" ')
    } else {
        Run('"' A_ScriptDir '\submacros\AutoHotkey64.exe" "' A_ScriptDir '\submacros\auto_spin.ahk" ')
    }
}

RunAutoConsumableTool(*) {
    if (A_PtrSize == 4) {
    Run('"' A_ScriptDir '\submacros\AutoHotkey32.exe" "' A_ScriptDir '\submacros\auto_open_consumable.ahk" ')
    } else {
        Run('"' A_ScriptDir '\submacros\AutoHotkey64.exe" "' A_ScriptDir '\submacros\auto_open_consumable.ahk" ')
    }
}

ProcessCommands(*) => BatchProcessCommands()

CreditPeople() {
    return [
        {name: "aiden", category: "Contributors", role: "Lead developer"},
        {name: "pizzaroles24", category: "Contributors", role: "Lead developer"},
        {name: "Banana", category: "Contributors", role: "Developer"},
        {name: "hesgly", category: "Contributors", role: "Developer"},
        {name: "jackappleteam", category: "Contributors", role: "Developer"},
        {name: "Shovel", category: "Contributors", role: "Developer"},
        {name: "ultimate", category: "Contributors", role: "Developer"},
        {name: "Anton", category: "Contributors", role: "Contributor"},
        {name: "menz.7", category: "Contributors", role: "Contributor"},
        {name: "! sayrox0_0", category: "Contributors", role: "Translator"},
        {name: "3_14591", category: "Contributors", role: "Translator"},
        {name: "apanovaha", category: "Contributors", role: "Translator"},
        {name: "Ayden567843", category: "Contributors", role: "Translator"},
        {name: "creeperhouse999", category: "Contributors", role: "Translator"},
        {name: "Digiton00b1", category: "Contributors", role: "Translator"},
        {name: "EллioT🏳️‍🌈", category: "Contributors", role: "Translator"},
        {name: "Flupizinho", category: "Contributors", role: "Translator"},
        {name: "g4m3rsl4y3r", category: "Contributors", role: "Translator"},
        {name: "hazardous_dice", category: "Contributors", role: "Translator"},
        {name: "Jack/Jane", category: "Contributors", role: "Translator"},
        {name: "Ka_Demon", category: "Contributors", role: "Translator"},
        {name: "KUTMAN79", category: "Contributors", role: "Translator"},
        {name: "oasiscboncbon1", category: "Contributors", role: "Translator"},
        {name: "profesorhenrique21", category: "Contributors", role: "Translator"},
        {name: "RAZE500", category: "Contributors", role: "Translator"},
        {name: "t8Obvm", category: "Contributors", role: "Translator"},
        {name: "typoxerax", category: "Contributors", role: "Translator"},
        {name: "yz", category: "Contributors", role: "Translator"},
        {name: "[ Cubed ]", category: "Supporters", role: "Early Access"},
        {name: "4EVRNATE", category: "Supporters", role: "Early Access"},
        {name: "Banshyyi", category: "Supporters", role: "Early Access"},
        {name: "captain305993", category: "Supporters", role: "Early Access"},
        {name: "chancito", category: "Supporters", role: "Early Access"},
        {name: "N", category: "Supporters", role: "Early Access"},
        {name: "ninja89614.", category: "Supporters", role: "Early Access"},
        {name: "Slay[Alesso's Edition]", category: "Supporters", role: "Early Access"},
        {name: "TheElyBot", category: "Supporters", role: "Early Access"},
        {name: "Truck-Kun", category: "Supporters", role: "Early Access"},
        {name: "WaryAngel1837", category: "Supporters", role: "Early Access"},
        {name: "Zyven", category: "Supporters", role: "Early Access"}
    ]
}

CreditsSetMode(mode, *) {
    global CreditMode, CreditPage
    CreditMode := mode
    CreditPage := 1
    CreditsRender()
}

CreditsShowContributors(ctrl, *) {
    CreditsSetMode("Contributors")
}

CreditsShowSupporters(ctrl, *) {
    CreditsSetMode("Supporters")
}

CreditsPreviousPage(ctrl, *) {
    global CreditPage
    CreditPage -= 1
    CreditsRender()
}

CreditsNextPage(ctrl, *) {
    global CreditPage
    CreditPage += 1
    CreditsRender()
}

CreditsRender() {
    global CreditMode, CreditPage, CreditCards, CreditHoverDetails
    global CreditContributorsTab, CreditSupportersTab, CreditModeIndicator, CreditPageText, CreditPrev, CreditNext, Credit_Info, Credit_Support
    people := []
    for person in CreditPeople() {
        if (CreditMode = "Supporters" && person.category = "Supporters")
            people.Push(person)
        else if (CreditMode = "Contributors" && person.category = "Contributors")
            people.Push(person)
    }
    pageSize := CreditCards.Length
    pageCount := Max(1, Ceil(people.Length / pageSize))
    CreditPage := Max(1, Min(CreditPage, pageCount))
    first := (CreditPage - 1) * pageSize
    CreditHoverDetails := Map()
    for index, card in CreditCards {
        personIndex := first + index
        if personIndex <= people.Length {
            person := people[personIndex]
            card.Text := person.name
            card.Visible := true
            if CreditMode = "Contributors"
                CreditHoverDetails[card.Hwnd] := TranslateText(person.role)
        } else {
            card.Text := ""
            card.Visible := false
        }
    }
    AppearanceFont(CreditContributorsTab, CreditMode = "Contributors" ? "s10 Bold cFFFFFF" : "s10 Norm cAAAAAA")
    AppearanceFont(CreditSupportersTab, CreditMode = "Supporters" ? "s10 Bold cFFFFFF" : "s10 Norm cAAAAAA")
    CreditModeIndicator.Move(CreditMode = "Contributors" ? 30 : 180, 181, 145, 2)
    CreditPageText.Text := TF("Page {current} of {total}", Map("current", CreditPage, "total", pageCount))
    CreditPrev.Visible := CreditPage > 1
    CreditNext.Visible := CreditPage < pageCount
    Credit_Info.Text := TranslateText(CreditMode = "Supporters"
        ? "Early Access members" : "Developers, contributors, and translators")
    Credit_Support.Visible := CreditMode = "Supporters"
}





