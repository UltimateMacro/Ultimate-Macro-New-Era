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

; Repository source checkouts intentionally omit pinned OCR/JSON files
; during the first parse. Keep VarUnset warnings enabled while registering
; these optional global dependency symbols for the bootstrap/reload flow.
IsSet(OCR)
IsSet(JSON)

if (RegExMatch(A_ScriptDir, "i)\.(zip|rar)")) {
    MsgBox(
        "You are attempting to run the script from a ZIP file.`n`nPlease Extract/Unzip the file first, then run the script in the extracted folder.",
        "Running From ZIP", 0x10)
    ExitApp()
}

if (!FileExist(A_ScriptDir "\lib\OCR.ahk") || !FileExist(A_ScriptDir "\lib\JSON.ahk")) {
    BootstrapPinnedSourceDependencies()
}

if WinExist("Ultimate Macro") {
    WinClose("Ultimate Macro")
}

if (A_PtrSize == 4) {
    MsgBox("You are running 32-bit AutoHotkey, the macro will not work properly, sadly.")
}

#Include lib\Gdip_All.ahk
#Include *i lib\OCR.ahk
#Include lib\Gdip_ImageSearch.ahk
#Include lib\Roblox.ahk
#Include lib\HyperSleep.ahk
#Include lib\ImageSearch\ImageSearch.ahk
#Include *i lib\JSON.ahk
#Include submacros\updater.ahk
#Include lib\Discord.ahk
#Include lib\RuntimeLog.ahk
#Include lib\auto_settings.ahk

BootstrapPinnedSourceDependencies() {
    ocrPath := A_ScriptDir "\lib\OCR.ahk"
    jsonPath := A_ScriptDir "\lib\JSON.ahk"
    syncScript := A_ScriptDir "\tools\sync_dependencies.ps1"

    if (FileExist(ocrPath) && FileExist(jsonPath))
        return

    if !FileExist(syncScript) {
        MsgBox(
            "Ultimate Macro is missing its verified OCR/JSON source dependencies.`n`n"
            "This normally means you downloaded repository source files instead of an official release.`n`n"
            "Please download TDS_Macro.zip from GitHub Releases, or restore tools\sync_dependencies.ps1.",
            "Missing Runtime Dependencies",
            0x10
        )
        ExitApp()
    }

    powershell := A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe"
    quote := Chr(34)
    command := quote powershell quote
        . " -NoProfile -ExecutionPolicy Bypass -File "
        . quote syncScript quote

    try {
        exitCode := RunWait(command, A_ScriptDir, "Hide")
    } catch Error as err {
        MsgBox(
            "Ultimate Macro could not prepare its verified OCR/JSON dependencies.`n`n"
            err.Message
            "`n`nYou can also run tools\sync_dependencies.ps1 manually.",
            "Dependency Setup Failed",
            0x10
        )
        ExitApp()
    }

    if (
        exitCode != 0
        || !FileExist(ocrPath)
        || !FileExist(jsonPath)
    ) {
        MsgBox(
            "Verified OCR/JSON dependency setup did not complete successfully.`n`n"
            "Check your internet connection or download the official TDS_Macro.zip release.",
            "Dependency Setup Failed",
            0x10
        )
        ExitApp()
    }

    ; Includes are processed when the script starts, so restart once the
    ; verified files have been materialized.
    Reload()
    ExitApp()
}

command_buffer := []

ver := "1.3.4"

RuntimeLogInstall("Main", ver)

; Resolve image detection once at startup. Native OpenCV is an optional fast
; path; the portable GDI+ backend is intentionally supported and multi-scale.
ImageBackend := GetImageSearchBackendInfo()
try {
    EnsureImageSearchBackend()
    ImageBackend := GetImageSearchBackendInfo()
} catch Error as backendErr {
    RuntimeLogWarn("image_backend_probe_failed", "Could not probe image-search backend", "error=" backendErr.Message)
}

if (ImageBackend.nativeAvailable)
    RuntimeLogInfo("image_backend", "Image search backend resolved", "backend=" ImageBackend.backend "; reason=" ImageBackend.reason)
else
    RuntimeLogWarn("image_backend_fallback", "Using portable multi-scale image detection",
        "backend=" ImageBackend.backend "; reason=" ImageBackend.reason)

A_MaxHotkeysPerInterval := 9999

pToken := Gdip_Startup()
OnExit(CleanupGdip)
OnExit(HandleExit)

global AppDataOpt := A_AppData "\Ultimate_Macro\Options"
global SettingsFile := AppDataOpt "\Settings.tds"
global BotSettings := AppDataOpt "\Discord-Bot-Settings.ini"
global RecordingsDir := A_AppData "\Ultimate_Macro\Recordings"
global StateFile := A_AppData "\Ultimate_Macro\state.ini"

global StratsDir := A_WorkingDir "\Resources\Strats"

global ShowIndicators := true

global WebhookQueue := []
global WebhookTimerActive := false
global WebhookInstantQueue := []
global WebhookInstantTimerActive := false

if !DirExist(AppDataOpt)
    DirCreate(AppDataOpt)
if !DirExist(RecordingsDir)
    DirCreate(RecordingsDir)

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
global AutoEquip := IniRead(SettingsFile, "Options", "AutoEquip", 0)
global AutoConfigureSettings := IniRead(SettingsFile, "Options", "AutoConfigureSettings", 1)
;
global UseRestartBtn := IniRead(SettingsFile, "Options", "UseRestartBtn", "1")
global UsePlayAgainBtn := IniRead(SettingsFile, "Options", "UsePlayAgainBtn", "1")
global RotateStrategies := IniRead(SettingsFile, "Options", "RotateStrategies", 0)
global AutoEquip := IniRead(SettingsFile, "Options", "AutoEquip", 0)
global CheckTheMap := IniRead(SettingsFile, "Options", "CheckTheMap", 1)
global UseNumbersForHotbar := IniRead(SettingsFile, "Options", "UseNumbers", 1)
global UseHForUpgrade := IniRead(SettingsFile, "Options", "UseHotkeyForUpgrade", 1)
global CollectPlaytimeRewards := IniRead(SettingsFile, "Options", "CollectPlaytimeRewards", "1")
global Strategy1Path := IniRead(SettingsFile, "Options", "Strategy1", "")
global Strategy2Path := IniRead(SettingsFile, "Options", "Strategy2", "")
global PartyMembers := IniRead(SettingsFile, "Multiplayer", "PartyMembers", "someone, someone...")
global PlayerRole := IniRead(SettingsFile, "Multiplayer", "PlayerRole", "Host")
global LeaveCondition := IniRead(SettingsFile, "Multiplayer", "LeaveCondition", "Any")
global HostName := IniRead(SettingsFile, "Multiplayer", "HostName", "...")
global MultiplayerEnabled := IniRead(SettingsFile, "Multiplayer", "MultiplayerEnabled", 0)

global DefaultMouseSpeed := IniRead(SettingsFile, "Options", "DefaultMouseSpeed", "2")
global MouseDelay := IniRead(SettingsFile, "Options", "MouseDelay", "10")
global KeyDelay := IniRead(SettingsFile, "Options", "KeyDelay", "20")

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

if (AutoConfigureSettings) {
    ApplyMacroSettings()
}

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
global StrategyHeight := 1080

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
    UseTimeScale := true, TimeScaleMultiplier := 1.5
} else if (TimeScaleMode = "2x") {
    UseTimeScale := true, TimeScaleMultiplier := 2
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
global RecordingWidth := 0, RecordingHeight := 0
global modifiers := ""
global LastDisconnectCheck := 0
global LastOpenedTowerID := ""
global IsRestarting := false
global SafeExitFlag := false
global RestartLock := false

global isUiPositionSaved := false
global isUpgradeAuthorized := false
global activeUpgradeRegions := [0, 0, 0, 0]
global CachedMenuUI := { x: 0, y: 0 }
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

global SC_L := "sc026"
global SC_R := "sc013"
global SC_Esc := "sc001"
global SC_Enter := "sc01c"
SC_E := "sc012" ; e

if (DebugConsole = "1")
    ShowDebugConsole()

IconPath := A_WorkingDir "\icon.ico"
if FileExist(IconPath)
    TraySetIcon(IconPath)

WM_LBUTTONDOWN_Drag(wParam, lParam, msg, hwnd) {
    global MainGui
    if (MainGui) {
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
    global MacroRecording, MacroSteps, MacroStartTime, Recording, Towers, RecordedSteps, Commander, ActiveRTowerID,
        CachedMenuUI, isUiPositionSaved, isUpgradeAuthorized, activeUpgradeRegions, CachedResV2, CachedResV1

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
    global Recording, ActiveRTowerID, Towers, RecordedSteps, Commander, isUpgradeAuthorized, activeUpgradeRegions,
        CachedResV2, CachedResV1

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

    if IsPathSpecificUpgrade(towerID, nextLevel, path, pathLevel) {
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
                RecordedSteps.Push("UpgradeTower(" towerID ", false, 1, " Towers[towerID].path ", " Towers[towerID].pathLevel ")"
                )
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

SelectHotbarSlotByClick(slotNumber) {
    static baseXBySlot := [800, 880, 960, 1040, 1120]

    try slot := Integer(slotNumber)
    catch Error {
        RuntimeLogWarn("hotbar_slot_invalid", "Mouse hotbar selection received a non-numeric slot",
            "slot=" slotNumber)
        return false
    }

    if (slot < 1 || slot > baseXBySlot.Length) {
        RuntimeLogWarn("hotbar_slot_invalid", "Mouse hotbar selection received an out-of-range slot",
            "slot=" slot)
        return false
    }

    if !getRobloxPos(, , &clientWidth, &clientHeight) || clientWidth <= 0 || clientHeight <= 0 {
        RuntimeLogWarn("hotbar_slot_geometry_missing", "Mouse hotbar selection could not resolve Roblox client geometry",
            "slot=" slot "; client_width=" clientWidth "; client_height=" clientHeight)
        return false
    }

    slotX := Round(baseXBySlot[slot] * (clientWidth / 1920.0))
    slotY := Round(960 * (clientHeight / 1009.0))
    RuntimeLogInfo("hotbar_slot_resolved", "Resolved mouse hotbar selection in Roblox client coordinates",
        "slot=" slot "; x=" slotX "; y=" slotY "; client_width=" clientWidth "; client_height=" clientHeight)
    Click(slotX, slotY)
    return true
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

GetClientTemplateScale(clientHeight) {
    if (!IsNumber(clientHeight) || clientHeight <= 0)
        return 1.0
    return Float(clientHeight) / 1009.0
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

        score := ImageSearch(&nx, &ny, x, y, x + w, y + h, "*80 " templ)

        status := "failed"

        if score == 1
            status := "success"

        return { score: score, x: nx, y: ny, message: " ", status: status }
    } else {
        return AdvImageSearch(templ, x, y, w, h, minScale, maxScale, scaleStep)
    }
}

UIFont() {
    static selected := ""
    if (selected != "")
        return selected

    for candidate in ["Segoe UI", "Tahoma", "Arial"] {
        if IsFontAvailable(candidate) {
            selected := candidate
            return selected
        }
    }

    selected := "Arial"
    return selected
}

IsFontAvailable(faceName) {
    hdc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    if !hdc
        return false

    hFont := DllCall("gdi32\CreateFontW",
        "Int", -12, "Int", 0, "Int", 0, "Int", 0, "Int", 400,
        "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1,
        "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0,
        "Str", faceName, "Ptr")
    if !hFont {
        DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
        return false
    }

    oldFont := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
    faceBuf := Buffer(256, 0)
    chars := DllCall("gdi32\GetTextFaceW", "Ptr", hdc, "Int", 128, "Ptr", faceBuf.Ptr, "Int")
    actualFace := (chars > 0) ? StrGet(faceBuf, "UTF-16") : ""

    if oldFont
        DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")
    DllCall("gdi32\DeleteObject", "Ptr", hFont)
    DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", hdc)

    return (StrLower(actualFace) = StrLower(faceName))
}

autoRun := IniRead(StateFile, "State", "Running", 0)
autoStrat := IniRead(StateFile, "State", "Strategy", "")
savedStartTime := IniRead(StateFile, "State", "StartTime", 0)

if (BotEnabled && ChannelID != "" && UserID != "") {
    SetTimer(ProcessCommands, 7500, 1)
}

if (savedStartTime != 0)
    AutorunStartTime := Integer(savedStartTime)

if (autoRun = 1 && autoStrat != "" && FileExist(autoStrat)) {
    LoadStrategyFile(autoStrat)
    RunningStrategy := true
    ActivateRoblox()
    RunStrategy()
} else {
    updateResult := CheckForUpdate(ver)
    if (updateResult = 2) {
        SafeReload()
    }

    MultiInstanceTools :=
        "RobloxAccountManager.exe,Roblox Account Manager.exe,RAM.exe,RobloxMulti.exe,MultiRoblox.exe,MultipleRoblox.exe,Multiple Roblox.exe"
    loop parse, MultiInstanceTools, "," {
        if ProcessExist(A_LoopField) {
            MsgBox("Conflicting program detected:`n" A_LoopField "`n`nFor this script to work properly, please close all Roblox multi-client utilities.`nPlease close them and try again.",
                "Error", 48)
            ExitApp()
        }
    }
}

global MainGui := Gui("-Caption +Border +LastFound")
MainGui.BackColor := "121212"

global SystemHwnds := Map()

sysBar1 := MainGui.Add("Progress", "x0 y3 w700 h39 Disabled Background0A0A0A", 0)
SystemHwnds[sysBar1.Hwnd] := true

MainGui.SetFont("s11 w300 cFFFFFF", UIFont())
if FileExist(IconPath) {
    sysIcon := MainGui.Add("Picture", "BackgroundTrans x20 y12 w20 h20", IconPath)
    SystemHwnds[sysIcon.Hwnd] := true
}

global GuiTitleCtrl := MainGui.Add("Text", "x50 y12 w150 h25 BackgroundTrans", "Ultimate Macro | TDS")
GuiTitleCtrl.OnEvent("Click", MoveWindow)
SystemHwnds[GuiTitleCtrl.Hwnd] := true

MainGui.SetFont("s11 w400 cFFFFFF", "Marlett")
global BtnMin := MainGui.Add("Text", "x600 y12 w30 h25 Center BackgroundTrans", "0")
BtnMin.OnEvent("Click", MinimizeWindow)
SystemHwnds[BtnMin.Hwnd] := true

MainGui.SetFont("s11 w400 c888888", "Marlett")
sysDot := MainGui.Add("Text", "x630 y12 w30 h25 Center BackgroundTrans", "1")
SystemHwnds[sysDot.Hwnd] := true

MainGui.SetFont("s11 w400 cFFFFFF", "Marlett")
global BtnClose := MainGui.Add("Text", "x660 y12 w30 h25 Center BackgroundTrans", "r")
BtnClose.OnEvent("Click", CloseWindow)
SystemHwnds[BtnClose.Hwnd] := true

sysLine1 := MainGui.Add("Progress", "x0 y42 w700 h1 Background222222", 0)
SystemHwnds[sysLine1.Hwnd] := true

MainGui.SetFont("s10 w400 c888888", UIFont())
global HoverTab := []
global TabCtrl := []
global HoverEffect := []
global GradientButtons := []

;tabs
global Tab3 := []

global DiscordWebhookTab := []
global DiscordBotTab := []
;==

tabNames := ["Main", "Record", "(Beta) Party", "Discord", "Settings", "Tools", "Credits"]

loop tabNames.Length {
    i := A_Index
    xTab := 20 + (i - 1) * 90

    hBg := MainGui.Add("Progress", "x" xTab " y43 w80 h34 Hidden Background222222 Disabled")
    HoverTab.Push(hBg)
    SystemHwnds[hBg.Hwnd] := true

    t := MainGui.Add("Text", "x" xTab " y52 w80 h22 Center BackgroundTrans", tabNames[i])
    t.OnEvent("Click", SelectTab)
    TabCtrl.Push(t)
    SystemHwnds[t.Hwnd] := true
}

global TabLine := MainGui.Add("Progress", "x20 y75 w80 h2 BackgroundFFFFFF", 0)
SystemHwnds[TabLine.Hwnd] := true

sysLine2 := MainGui.Add("Progress", "x0 y77 w700 h1 Background222222", 0)
SystemHwnds[sysLine2.Hwnd] := true

; tab 1 - MAIN ===========================

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global Tab1_Section1 := MainGui.Add("Text", "x30 y95  w200 h22", "Custom Strategies")
global Tab1_Line1 := MainGui.Add("Progress", "x30 y118 w640 h1  Background333333", 0)

MainGui.SetFont("s9 w400 cAAAAAA", UIFont())
global Tab1_Lbl1 := MainGui.Add("Text", "x30 y130 w100 h20", "Strategy:")
MainGui.SetFont("s9 w400 c000000")
global Strategy1Ctrl := MainGui.Add("Edit", "x110 y127 w400 h22 vStrategy1", Strategy1Path)
Strategy1Ctrl.OnEvent("Change", SaveStrat1)
MainGui.SetFont("s9 w400 cFFFFFF")
global Tab1_Btn1 := MainGui.Add("Text", "x515 y126 w70 h22 +Border 0x200 Center", "Browse")
Tab1_Btn1.OnEvent("Click", SelectStrat1)
global Tab1_Btn2 := MainGui.Add("Text", "x590 y126 w70 h22 +Border 0x200 Center", "Clear")
Tab1_Btn2.OnEvent("Click", ClearStrat1)

HoverEffect.Push(Tab1_Btn1)
HoverEffect.Push(Tab1_Btn2)

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab1_Lbl2 := MainGui.Add("Text", "x30 y160 w100 h20", "Strategy 2:")
MainGui.SetFont("s9 w400 c000000")
global Strategy2Ctrl := MainGui.Add("Edit", "x110 y157 w400 h22 vStrategy2", Strategy2Path)
Strategy2Ctrl.OnEvent("Change", SaveStrat2)
MainGui.SetFont("s9 w400 cFFFFFF")
global Tab1_Btn3 := MainGui.Add("Text", "x515 y156 w70 h22 +Border 0x200 Center", "Browse")
Tab1_Btn3.OnEvent("Click", SelectStrat2)
global Tab1_Btn4 := MainGui.Add("Text", "x590 y156 w70 h22 +Border 0x200 Center", "Clear")
Tab1_Btn4.OnEvent("Click", ClearStrat2)

HoverEffect.Push(Tab1_Btn3)
HoverEffect.Push(Tab1_Btn4)

MainGui.SetFont("s9 w400 cFFFFFF")
global RotateStrategiesCtrl := MainGui.Add("Checkbox", "x30 y190 vRotateStrategies 0x200 Checked" RotateStrategies, "Strategy Rotation")
RotateStrategiesCtrl.OnEvent("Click", EnableStratRotation)

MainGui.SetFont("s9 w400 cAAAAAA")
global SwapAfterLbl := MainGui.Add("Text", "x148 y188 w70 h20 0x200 BackgroundTrans", "Swap after:")

MainGui.SetFont("s9 w400 c000000")
global SwapAmountCtrl := MainGui.Add("Edit", "x217 y186 w40 h22 +Border Number Center vSwapAmount", SwapAmount)

SwapAmountCtrl.OnEvent("Change", (*) => (
    IniWrite(SwapAmountCtrl.Text, SettingsFile, "Options", "SwapAmount"),
    SwapAmount := SwapAmountCtrl.Text
))

MainGui.SetFont("s9 w400 c000000")
global SwapUnitCtrl := MainGui.Add("DropDownList", "x267 y186 w80 Choose" (SwapUnit = "Minutes" ? 2 : 1) " vSwapUnit", ["Runs", "Minutes"])

SwapUnitCtrl.OnEvent("Change", (*) => (
    IniWrite(SwapUnitCtrl.Text, SettingsFile, "Options", "SwapUnit"),
    SwapUnit := SwapUnitCtrl.Text
    IniWrite(SwapAmountCtrl.Text, SettingsFile, "Options", "SwapAmount")
))

MainGui.SetFont("s9 w400 cFFFFFF")
global AutoEquipCtrl := MainGui.Add("Checkbox", "x357 y190 vAutoEquip 0x200 Checked" AutoEquip, "Auto Equip Towers")
AutoEquipCtrl.OnEvent("Click", EnableAutoEquip)

global AutoConfigCtrl := MainGui.Add("Checkbox", "x490 y190 vAutoConfigureSettings 0x200 Checked" AutoConfigureSettings, "Auto Configure Settings")
AutoConfigCtrl.OnEvent("Click", EnableAutoConfig)

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global Tab1_Section2 := MainGui.Add("Text", "x30 y225 h22", "Strategies")
global Tab1_Line2 := MainGui.Add("Progress", "x30 y248 w640 h1 Background333333", 0)

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global BtnCommStrats := MainGui.Add("Text", "x30 y257 w120 h24 Center Background222222 +Border 0x200", "Community")
MainGui.SetFont("s10 w400 cFFFFFF", UIFont())
global BtnMyStrats := MainGui.Add("Text", "x160 y257 w120 h24 Center Background0e0e0f +Border 0x200", "My Strats")

BtnCommStrats.OnEvent("Click", (*) => SwitchStrategiesTab("Community"))
BtnMyStrats.OnEvent("Click", (*) => SwitchStrategiesTab("MyStrats"))
HoverEffect.Push(BtnCommStrats)
HoverEffect.Push(BtnMyStrats)

if !DirExist(StratsDir)
    DirCreate(StratsDir)

IsGitDevelopmentCheckout(rootDir) {
    ; A normal checkout stores repository metadata in a .git directory. A
    ; linked worktree stores a .git file instead. Official release archives
    ; contain neither, so only those installs receive automatic strategies.
    return FileExist(rootDir "\.git") != ""
}

LoadedStrats := []
needUpdate := !IsGitDevelopmentCheckout(A_ScriptDir)
lastUpdate := IniRead(StateFile, "Cache", "LastUpdateTime", "0")

if (lastUpdate != "0") {
    timeDiff := DateDiff(A_Now, lastUpdate, "Hours")
    if (timeDiff < 6) {
        needUpdate := false
    }
}

if (needUpdate) {
    tempDir := StratsDir "\.download_temp"
    communityBackupDir := StratsDir "\.community_backup"

    try {
        apiURL := "https://api.github.com/repos/UltimateMacro/Ultimate-Macro-New-Era/contents/Resources/Strats?ref=main"

        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", apiURL, false)
        whr.SetRequestHeader("User-Agent", "Ultimate-Macro-New-Era-Strategy-Updater")
        whr.SetRequestHeader("Accept", "application/vnd.github+json")
        whr.SetRequestHeader("X-GitHub-Api-Version", "2022-11-28")
        whr.SetTimeouts(5000, 5000, 10000, 10000)
        whr.Send()

        if (whr.Status != 200)
            throw Error("API request failed with status: " whr.Status)

        if DirExist(tempDir)
            DirDelete(tempDir, true)
        if DirExist(communityBackupDir)
            DirDelete(communityBackupDir, true)
        DirCreate(tempDir)

        try strategyIndex := JSON.parse(whr.ResponseText)
        catch Error as parseErr
            throw Error("Community strategy index JSON is invalid: " parseErr.Message)

        if !IsObject(strategyIndex)
            throw Error("Community strategy index is not an array/object.")

        fileCount := 0
        successCount := 0

        for item in strategyIndex {
            if !item.Has("name")
                continue

            fileName := item["name"]
            if !RegExMatch(fileName, "i)\.strat$")
                continue

            fileCount++
            if !item.Has("download_url") || item["download_url"] = "" {
                LogToConsole("Community strategy has no download URL: " fileName, false)
                continue
            }

            downloadURL := item["download_url"]
            try {
                fileWhr := ComObject("WinHttp.WinHttpRequest.5.1")
                fileWhr.Open("GET", downloadURL, false)
                fileWhr.SetRequestHeader("User-Agent", "Ultimate-Macro-New-Era-Strategy-Updater")
                fileWhr.SetTimeouts(5000, 5000, 10000, 10000)
                fileWhr.Send()

                if (fileWhr.Status == 200) {
                    ado := ComObject("ADODB.Stream")
                    try {
                        ado.Type := 1
                        ado.Open()
                        ado.Write(fileWhr.ResponseBody)
                        ado.SaveToFile(tempDir "\" fileName, 2)
                        successCount++
                    } finally {
                        try ado.Close()
                    }
                } else {
                    LogToConsole("Failed to download community strategy '" fileName "'. Status: " fileWhr.Status, false)
                }
            } catch Error as fileErr {
                LogToConsole("Network error downloading community strategy '" fileName "': " fileErr.Message, false)
            }

            Sleep(30)
        }

        ; Transaction guard: an empty/partial fetch can never replace the
        ; currently installed community strategy set.
        if (fileCount == 0)
            throw Error("Community strategy index returned zero .strat files; keeping current files.")
        if (successCount != fileCount)
            throw Error("Community strategy refresh incomplete (" successCount "/" fileCount "); keeping current files.")

        oldManifestStr := IniRead(StateFile, "Cache", "CommunityStratFiles", "")
        oldLastUpdate := IniRead(StateFile, "Cache", "LastUpdateTime", "0")
        oldManifestFiles := (oldManifestStr = "") ? [] : StrSplit(oldManifestStr, "|")
        oldManifestMap := Map()
        for oldFile in oldManifestFiles {
            if (oldFile != "")
                oldManifestMap[oldFile] := true
        }

        ; A local file not owned by the previous community manifest belongs to
        ; the user/package. Never overwrite it silently.
        newManifestFiles := []
        loop files, tempDir "\*.strat" {
            target := StratsDir "\" A_LoopFileName
            if (FileExist(target) && !oldManifestMap.Has(A_LoopFileName)) {
                LogToConsole("Community refresh would overwrite a local strategy; keeping local file: " A_LoopFileName, false)
                FileDelete(A_LoopFileFullPath)
                continue
            }
            newManifestFiles.Push(A_LoopFileName)
        }

        DirCreate(communityBackupDir)
        for oldFile in oldManifestFiles {
            if (oldFile != "" && FileExist(StratsDir "\" oldFile))
                FileCopy(StratsDir "\" oldFile, communityBackupDir "\" oldFile, 1)
        }

        newManifestStr := ""
        for newFile in newManifestFiles
            newManifestStr .= (newManifestStr = "" ? "" : "|") newFile

        try {
            for oldFile in oldManifestFiles {
                if (oldFile != "" && FileExist(StratsDir "\" oldFile))
                    FileDelete(StratsDir "\" oldFile)
            }

            for newFile in newManifestFiles
                FileMove(tempDir "\" newFile, StratsDir "\" newFile, 1)

            IniWrite(newManifestStr, StateFile, "Cache", "CommunityStratFiles")
            IniWrite(A_Now, StateFile, "Cache", "LastUpdateTime")
        } catch Error as commitErr {
            ; Restore only files managed by the community updater. User files are
            ; outside this transaction and are never deleted.
            for newFile in newManifestFiles {
                if FileExist(StratsDir "\" newFile)
                    try FileDelete(StratsDir "\" newFile)
            }
            loop files, communityBackupDir "\*.strat" {
                try FileCopy(A_LoopFileFullPath, StratsDir "\" A_LoopFileName, 1)
            }
            try IniWrite(oldManifestStr, StateFile, "Cache", "CommunityStratFiles")
            try IniWrite(oldLastUpdate, StateFile, "Cache", "LastUpdateTime")
            throw commitErr
        }
    } catch Error as err {
        LogToConsole("Error while downloading strats: " err.Message)
    } finally {
        if DirExist(tempDir)
            try DirDelete(tempDir, true)
        if DirExist(communityBackupDir)
            try DirDelete(communityBackupDir, true)
    }
}

global FrameX := 30
global FrameY := 290 ; Shifted down for the toggle buttons
global FrameW := 640
global FrameH := 190 ; Adjusted height
global ContentH := 400
global CurrentScrollPos := 0
global SliderH := 30
global ChildHwnd := 0
global ChildGui := ""

global IsRenderingStrategies := false
global ContentGui := ""

global RenderedBitmaps := []  ; Track all created bitmaps for cleanup

; Add this function to properly dispose of GDI+ bitmaps
DisposeBitmap(hBitmap) {
    if (hBitmap) {
        try {
            DeleteObject(hBitmap)
        } catch Error as e {
            ; Silently ignore disposal errors
            ; The bitmap may already be disposed or invalid
        }
    }
}


CleanupRenderedBitmaps() {
    global RenderedBitmaps
    for index, hBitmap in RenderedBitmaps {
        DisposeBitmap(hBitmap)
    }
    RenderedBitmaps := []
}

SwitchStrategiesTab(mode) {
    global BtnCommStrats, BtnMyStrats, IsRenderingStrategies, ContentGui, RenderedBitmaps
    
    ; Lock to prevent concurrent rendering when spam clicking
    if (IsRenderingStrategies)
        return
    IsRenderingStrategies := true
    
    ; Clean up resources before switching
    CleanupRenderedBitmaps()
    
    if (mode == "Community") {
        BtnCommStrats.IsSelected := true
        BtnMyStrats.IsSelected := false
        BtnCommStrats.Opt("Background222222")
        BtnCommStrats.SetFont("c3A86FF Bold")
        BtnMyStrats.Opt("Background0e0e0f")
        BtnMyStrats.SetFont("cFFFFFF Norm")
    } else {
        BtnCommStrats.IsSelected := false
        BtnMyStrats.IsSelected := true
        BtnMyStrats.Opt("Background222222")
        BtnMyStrats.SetFont("c3A86FF Bold")
        BtnCommStrats.Opt("Background0e0e0f")
        BtnCommStrats.SetFont("cFFFFFF Norm")
    }
    
    RenderStrategies(mode)
    
    IsRenderingStrategies := false
}

RenderStrategies(mode := "Community") {
    global ChildGui, ContentGui, MainGui, LoadedStrats, GradientButtons
    global FrameX, FrameY, FrameW, FrameH, ContentH, CurrentScrollPos, SliderH, SliderBG, Slider
    global StratsDir, RecordingsDir, CurrentTab, ChildHwnd, RenderedBitmaps

    ; CRITICAL: Clean up ALL previous GDI+ resources before creating new ones
    CleanupRenderedBitmaps()
    
    ; Clean up GradientButtons references (but don't dispose - they're just text controls)
    GradientButtons := []

    ; Create the persistent ChildGui container only if it doesn't exist yet
    if (!IsSet(ChildGui) || ChildGui == "") {
        ChildGui := Gui("-Caption +E0x20 +Border +Parent" MainGui.Hwnd)
        ChildGui.BackColor := "181818"
        ChildGui.SetFont("s10 cWhite", UIFont())
        ChildHwnd := ChildGui.Hwnd
    }

    ; Destroy and recreate only the internal ContentGui on tab switch
    if (IsSet(ContentGui) && ContentGui != "") {
        ; Destroy the GUI - this should clean up its controls
        try ContentGui.Destroy()
        catch
        ContentGui := ""
    }

    ContentGui := Gui("-Caption +Parent" ChildGui.Hwnd)
    ContentGui.BackColor := "181818"
    ContentGui.SetFont("s10 cWhite", UIFont())
    width := FrameW - 6

    LoadedStrats := []
    CurrentScrollPos := 0

    targetDir := (mode == "Community") ? StratsDir : RecordingsDir

    loop files, targetDir "\*.strat" {
        localPath := A_LoopFileFullPath

        sMap := IniRead(localPath, "Settings", "map", "Unknown")
        sDifficulty := IniRead(localPath, "Settings", "difficulty", "Easy")
        sTowers := IniRead(localPath, "Settings", "requiredTowers", "None")
        sDesc := IniRead(localPath, "Info", "desc", "Local recording.")
        sAuthor := IniRead(localPath, "Info", "author", "You")
        sTitle := IniRead(localPath, "Info", "title", StrReplace(A_LoopFileName, ".strat", ""))
        sTime := IniRead(localPath, "Info", "time", "N/A")
        sIncome := IniRead(localPath, "Info", "income", "N/A")
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
            modifiers: sModifiers,
            fullPath: localPath
        })
    }

    StartY := 15
    CardH := 115
    CardW := 600
    Gap := 15

    ContentH := StartY

    for index, strat in LoadedStrats {
        CurrentY := StartY + ((index - 1) * (CardH + Gap))
        ContentH := CurrentY + CardH + Gap

        C1X := 10
        C1Y := CurrentY

        hFrameBg := CreateFrame(CardW, CardH, 10, "0xff161616", "0xff1d1d1d", "0x62302d2d")
        RenderedBitmaps.Push(hFrameBg)  ; Track for cleanup
        ContentGui.Add("Picture", "x" C1X " y" C1Y " w" CardW " h" CardH " +BackgroundTrans", "HBITMAP:*" hFrameBg)

        hIconBg := CreateGradientButton(56, 56, 8, "0xff2f353f", "0xff15171b", "0xff000000", "0x232c3a50", "", UIFont(), 10, 1)
        RenderedBitmaps.Push(hIconBg)  ; Track for cleanup
        ContentGui.Add("Picture", "x" (C1X + 10) " y" (C1Y + 30) " w76 h76 +BackgroundTrans", "HBITMAP:*" hIconBg)
        
        ; Track the duplicate - wait, we reused the same bitmap twice. Let's fix that:
        hIconBg2 := CreateGradientButton(56, 56, 8, "0xff2f353f", "0xff15171b", "0xff000000", "0x232c3a50", "", UIFont(), 10, 1)
        RenderedBitmaps.Push(hIconBg2)  ; Track for cleanup
        ContentGui.Add("Picture", "x" (C1X + 75) " y" (C1Y + 30) " w76 h76 +BackgroundTrans", "HBITMAP:*" hIconBg2)

        diffImg := "Resources/Strats/images/" strat.difficulty ".png"
        if !FileExist(diffImg) {
            LogToConsole("Missing resource file: " diffImg)
        } else {
            ContentGui.Add("Picture", "x" (C1X + 20) " y" (C1Y + 40) " h56 w56 +BackgroundTrans", diffImg)
        }

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
            LogToConsole("Missing resource file: " rewardIcon)
        } else {
            ContentGui.Add("Picture", "x" (C1X + 85) " y" (C1Y + 40) " h56 w56 +BackgroundTrans", rewardIcon)
        }

        ContentGui.SetFont("s11 Bold cWhite", UIFont())
        ContentGui.Add("Text", "x" (C1X + 15) " y" (C1Y + 12) " +BackgroundTrans", strat.title != "" ? strat.title : "Unknown Strat")

        ContentGui.SetFont("s9 w500 c7E848E", UIFont())
        helpDl1 := ContentGui.Add("Text", "x" (C1X + 580) " y" (C1Y + 10) " +BackgroundTrans", "?")
        helpDl1.OnEvent("Click", ((t, a, r, m, d) => (*) => StratInfo(t, a, r, m, d))(
            strat.title,
            strat.author,
            strat.towers,
            (strat.modifiers != "" ? strat.modifiers : "none"),
            strat.desc
        ))

        ContentGui.SetFont("s9 w400 cE2E4E7", UIFont())
        ContentGui.Add("Text", "x" (C1X + 260) " y" (C1Y + 15) " w340 +BackgroundTrans", (strat.towers != "" ? strat.towers : "None"))

        ContentGui.SetFont("s9 w400 c7E848E", UIFont())
        ContentGui.Add("Text", "x" (C1X + 260) " y" (C1Y + 36) " w320 +BackgroundTrans", strat.desc)

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

        hgmMode := CreateGradientButton(102, 28, 3, badgeColor1, badgeColor2, "0x40000000", "0x7effffff", strat.difficulty != "" ? strat.difficulty : "Easy", UIFont(), 11, 1)
        RenderedBitmaps.Push(hgmMode)  ; Track for cleanup
        ContentGui.Add("Picture", "x" (C1X + 145) " y" (C1Y + 35) " w102 h28 +BackgroundTrans", "HBITMAP:*" hgmMode)

        ContentGui.SetFont("s9 w500 c9CA4B0", UIFont())
        ContentGui.Add("Text", "x" (C1X + 155) " y" (C1Y + 65) " +BackgroundTrans", "🕒 " (strat.time != "" ? strat.time : "Unknown"))
        ContentGui.Add("Text", "x" (C1X + 155) " y" (C1Y + 83) " +BackgroundTrans", "⛃ " (strat.income != "" ? strat.income : "Unknown"))

        if ((strat.difficulty = "Hardcore" || strat.difficulty = "Voidcore")) {
            loadColor1 := "0xff961ea1", loadColor2 := "0xff5f237a"
            loadHover1 := "0xffea00ff", loadHover2 := "0xff8d32b7"
        } else {
            loadColor1 := "0xFF147A6E", loadColor2 := "0xFF214B75"
            loadHover1 := "0xFF1CB5A2", loadHover2 := "0xFF3272B7"
        }

        if (mode == "MyStrats") {
            hBtnNormal := CreateGradientButton(145, 38, 8, loadColor1, loadColor2, "0x40000000", "0x5dffffff", "Load", UIFont(), 14, 1)
            RenderedBitmaps.Push(hBtnNormal)
            hBtnHover := CreateGradientButton(145, 38, 8, loadHover1, loadHover2, "0x60000000", "0x5dffffff", "Load", UIFont(), 14, 1)
            RenderedBitmaps.Push(hBtnHover)
            
            editColor1 := "0xFF4b5563", editColor2 := "0xFF374151"
            editHover1 := "0xFF6b7280", editHover2 := "0xFF4b5563"
            hEditNormal := CreateGradientButton(70, 38, 8, editColor1, editColor2, "0x40000000", "0x5dffffff", "Edit", UIFont(), 12, 1)
            RenderedBitmaps.Push(hEditNormal)
            hEditHover := CreateGradientButton(70, 38, 8, editHover1, editHover2, "0x60000000", "0x5dffffff", "Edit", UIFont(), 12, 1)
            RenderedBitmaps.Push(hEditHover)

            picLoadBtn := ContentGui.Add("Picture", "x" (C1X + 365) " y" (C1Y + 68) " w145 h38 +BackgroundTrans", "HBITMAP:*" hBtnNormal)
            dl1 := ContentGui.Add("Text", "x" (C1X + 365) " y" (C1Y + 68) " w145 h38 +BackgroundTrans +0x200 Center", "")
            
            picEditBtn := ContentGui.Add("Picture", "x" (C1X + 515) " y" (C1Y + 68) " w70 h38 +BackgroundTrans", "HBITMAP:*" hEditNormal)
            dlEdit := ContentGui.Add("Text", "x" (C1X + 515) " y" (C1Y + 68) " w70 h38 +BackgroundTrans +0x200 Center", "")
            
            dlEdit.SetFont("cFFFFFF s10 Bold", UIFont())
            dlEdit.StratFile := strat.fullPath
            dlEdit.OnEvent("Click", EditStratFile)
            dlEdit.PicControl := picEditBtn
            dlEdit.ImgNormal := hEditNormal
            dlEdit.ImgHover := hEditHover
            GradientButtons.Push(dlEdit)
        } else {
            hBtnNormal := CreateGradientButton(220, 38, 8, loadColor1, loadColor2, "0x40000000", "0x5dffffff", "Load", UIFont(), 14, 1)
            RenderedBitmaps.Push(hBtnNormal)
            hBtnHover := CreateGradientButton(220, 38, 8, loadHover1, loadHover2, "0x60000000", "0x5dffffff", "Load", UIFont(), 14, 1)
            RenderedBitmaps.Push(hBtnHover)
            
            picLoadBtn := ContentGui.Add("Picture", "x" (C1X + 365) " y" (C1Y + 68) " w220 h38 +BackgroundTrans", "HBITMAP:*" hBtnNormal)
            dl1 := ContentGui.Add("Text", "x" (C1X + 365) " y" (C1Y + 68) " w220 h38 +BackgroundTrans +0x200 Center", "")
        }

        dl1.SetFont("cFFFFFF s10 Bold", UIFont())
        dl1.StratFile := strat.fullPath
        dl1.OnEvent("Click", DownloadStrat)
        dl1.PicControl := picLoadBtn
        dl1.ImgNormal := hBtnNormal
        dl1.ImgHover := hBtnHover
        GradientButtons.Push(dl1)
    }

    if (LoadedStrats.Length == 0) {
        ContentGui.SetFont("s12 c7E848E", UIFont())
        ContentGui.Add("Text", "x0 y0 w" FrameW " h" FrameH " +BackgroundTrans Center +0x200", "No strategies found.")
        ContentH := FrameH
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

        sliderPos := 0

        hSlider := CreateScrollThumb(SliderW, SliderH, 3, "0xFF6EA7FF", "0xff4076ce", "0xd4d4d4")
        RenderedBitmaps.Push(hSlider)
        hSliderBG := CreateScrollThumb(SliderW, FrameH, 3, "0xff000000", "0xff000000", "0x000000")
        RenderedBitmaps.Push(hSliderBG)

        SliderBG := ContentGui.Add("Picture", "x" SliderX " y0 w" SliderW " h" (ContentH <= FrameH ? FrameH : FrameH + ContentH) " +BackgroundTrans +0x0100", "HBITMAP:*" hSliderBG)
        Slider := ContentGui.Add("Picture", "x" SliderX " y" sliderPos " w" SliderW " h" SliderH " +BackgroundTrans +0x0100", "HBITMAP:*" hSlider)

        if (ContentH <= FrameH) {
            SliderBG.Visible := false
            Slider.Visible := false
        } else {
            SliderBG.Visible := true
            Slider.Visible := true
        }
    }
    
    ContentGui.Show("x0 y0 w" FrameW " h" FrameH)
    
    if (CurrentTab == "Tab1") {
        ShowChildGui()
    }
}

OnMessage(0x0115, OnScroll)
OnMessage(0x020A, OnMouseWheel)
OnMessage(0x0201, HandleSliderMouseDown)

MainGui.SetFont("s11 w400 cFFFFFF", UIFont())
global Tab1_Start := MainGui.Add("Text", "x30 y500 w300 h40 Center Background0e0e0f +Border 0x200", "Start (F1)")
Tab1_Start.OnEvent("Click", StartStrategy)
global Tab1_Stop := MainGui.Add("Text", "x340 y500 w330 h40 Center Background0e0e0f +Border 0x200", "Stop (F2)")
Tab1_Stop.OnEvent("Click", StopStrategy)

HoverEffect.Push(Tab1_Start)
HoverEffect.Push(Tab1_Stop)

; tab 2 - RECORD ===========================

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global Tab2_Title := MainGui.Add("Text", "x30 y95  w200 h22 Hidden", "Configuration")
global Tab2_Line1 := MainGui.Add("Progress", "x30 y118 w640 h1  Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab2_Lbl1 := MainGui.Add("Text", "x30 y145 w80 h20 Hidden", "Map:")
MainGui.SetFont("s9 w400 c000000")
global RecMapsD := MainGui.Add("ComboBox", "x80 y142 w220 Hidden vRecMaps", [ ; WARNING: These are all the supported maps for this macro. If a map is not listed here, it is unsupported
    "Abandoned City", "Area 52", "Autumn Falling",
    "Badlands II", "Black Spot Exchange", "Candy Valley", "Cataclysm", "Chess Board",
    "Construction Crazy", "Coral Deep", "Crossroads", "Crystal Cave",
    "Cyber City", "Dead Ahead", "Derelict Outpost", "Deserted Village", "Dusty Bridges",
    "Enchanted Forest", "Farm Lands", "Forest Camp", "Forgetten Docks", "Four Seasons",
    "Fungi Island", "Grass Isle", "Happy Home of Robloxia", "Harbor", "Honey Valley",
    "Hot Spot", "Iceville", "Infernal Abyss", "Lay By", "Lighthaos", "Marshlands", "Mason Arch", "Medieval Times",
    "Meltdown",
    "Midnight Issue", "Moon Base", "Musaceae Kingdom", "Necropolis", "Nether", "Night Station",
    "Northern Lights", "Outskirts Commune", "Pier Pressure", "Pizza Party", "Polluted Wasteland II",
    "Portland", "Retro Crossroads", "Retro Lighthouse", "Retro Rocket Arena", "Retro Stained Temple",
    "Retro The Heights", "Retro Zone", "Rocket Arena", "Ruby Escort", "Sacred Mountains",
    "Sky Islands", "Simplicity", "Space City", "Spring Fever", "Stained Temple", "Sugar Rush",
    "The Heavens", "The Heights", "Toyboard", "Tropical Industries", "Tropical Isles", "U-Turn",
    "Unknown Garden", "Winter Abyss", "Winter Bridges", "Winter Stronghold", "Wrecked Battlefield",
    "Wrecked Battlefield II", "Wretched Front"
])

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab2_Lbl2 := MainGui.Add("Text", "x320 y145 w80 h20 Hidden", "Mode:")
MainGui.SetFont("s9 w400 c000000")
global RecDiffCtrl := MainGui.Add("DropDownList", "x380 y142 w220 Hidden vRecDifficulty", [
    "Easy", "Casual", "Intermediate", "Molten", "Fallen", "Frost",
    "Hardcore", "Voidcore", "Arcade", "Pizza Party", "Badlands II", "Polluted Wasteland II"
])

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab2_Lbl3 := MainGui.Add("Text", "x30 y235 w80 h20 Hidden", "Modifiers:")
MainGui.SetFont("s9 w400 c000000")

global RecModifiersCtrl := MainGui.Add("ListBox", "x110 y232 w220 h200 Multi Hidden vRecModifiers", [
    "Broke", "Exploding", "Flying", "Fog", "Glass",
    "Healthy", "Hidden", "Inflation", "Jailed", "Limitation",
    "Committed", "Quarantine", "Speedy"
])

MainGui.SetFont("s9 w400 cAAAAAA", UIFont())
global Tab2_Info2 := MainGui.Add("Text", "x20 w60 y275 BackgroundTrans Hidden",
    "Hold CTRL to deselect/select multiple modifiers.")

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab2_Lbl4 := MainGui.Add("Text", "x30 y185 w80 h20 Hidden", "Towers:")
MainGui.SetFont("s9 w400 c000000")
global RecTowersCtrl := MainGui.Add("Edit", "x80 y182 w220 h22 Hidden vRecRequiredTowers", requiredTowers)

MainGui.SetFont("s9 w400 cAAAAAA", UIFont())
global Tab2_Info1 := MainGui.Add("Text", "x320 y173 BackgroundTrans Hidden",
    "Enter towers for your strategy using comma after every tower.`nMinigunner, Ranger, Commander, DJ, Military Base for example.`nType G Whatever if the tower you using NEEDS to be golden."
)

MainGui.Add("Progress", "x360 y232 w320 h1 Hidden Background333333 vTab2_Line2", 0)
global Tab2_Line2 := MainGui["Tab2_Line2"]

MainGui.SetFont("s9 w400 cFFFFFF", UIFont())
global RecAutoChainCtrl := MainGui.Add("Checkbox", "x360 y255 Hidden vRecAutoChain Checked" (autoChain = "ON" ? 1 : 0),
"Use Call of Arms")
global RecAutoCaravanCtrl := MainGui.Add("Checkbox", "x490 y255 Hidden vRecAutoCaravan Checked" (autoCaravan = "ON" ? 1 :
    0), "Use Support Caravan")
global RecAutoDropCtrl := MainGui.Add("Checkbox", "x360 y275 Hidden vRecAutoDropTheBeat Checked" (autoDropTheBeat =
    "ON" ? 1 : 0), "Use Drop the Beat")

MainGui.Add("Progress", "x360 y300 w320 h1 Hidden Background333333 vTab2_Line3", 0)
global Tab2_Line3 := MainGui["Tab2_Line3"]
global RecAutoSkipCtrl := MainGui.Add("Checkbox", "x360 y315 h20 Hidden vRecAutoSkip", "Auto Skip Waves")
global RecAbilitySpamCtrl := MainGui.Add("Checkbox", "x490 y315 h20 Hidden vRecAbilitySpam", "Abilities Spam")
global Tab2_Info := MainGui.Add("Link", "x360 y360 w320 h100 Hidden", "
(
There you can create your own strategy and save it into a file. Watch the tutorial here: <a href="https://www.youtube.com/watch?v=j8Y5qHBaYOs&feature=youtu.be">https://www.youtube.com/watch?v=j8Y5qHBaYOs&feature=youtu.be</a>. I recommend using the timescale ticket when recording complex strategies.
)"
)
RecAutoSkipCtrl.OnEvent("Click", RecordToggleAutoskip)

global RecMoveCtrl := MainGui.Add("Checkbox", "x30 y452 w60 h20 Hidden vRecMoveEnabled Checked" (MoveEnabled ? 1 : 0),
"Move")
MainGui.SetFont("s9 w400 cAAAAAA")
global DIRECTIONTEXTCtrl := MainGui.Add("Text", "x100 y452 w45 Hidden", "Direction")
MainGui.SetFont("s9 w400 c000000")
global RecMoveDirCtrl := MainGui.Add("DropDownList", "x160 y450 w45 Hidden Choose1 vRecMoveDirection", ["W", "A", "S",
    "D"])
MainGui.SetFont("s9 w400 cAAAAAA")
global Tab2_Txt4 := MainGui.Add("Text", "x220 y452 Hidden", "Duration (ms):")
MainGui.SetFont("s9 w400 c000000")
global RecMoveDurCtrl := MainGui.Add("Edit", "x310 y450 w50 h22 Hidden vRecMoveDuration", 1000)

MainGui.SetFont("s11 w400 cFFFFFF", UIFont())
global Tab2_Btn1 := MainGui.Add("Text", "x30  y500 w300 h40 Center Background0e0e0f +Border 0x200 Hidden",
    "Start Recording")
Tab2_Btn1.OnEvent("Click", StartRecording)
MainGui.SetFont("s11 w400 c808080", UIFont())
global Tab2_Btn2 := MainGui.Add("Text", "x340 y500 w330 h40 Center Background0e0e0f +Border 0x200 Hidden", "Stop")
Tab2_Btn2.OnEvent("Click", StopRecord)

HoverEffect.Push(Tab2_Btn1)

; tab 3 - MULTIPLAYER ===========================

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global Tab3_Title := MainGui.Add("Text", "x30 y95  w200 h22 Hidden", "Usernames")
global Tab3_Line1 := MainGui.Add("Progress", "x30 y118 w640 h1 Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab3_HostNm := MainGui.Add("Text", "x30 y140 w170 BackgroundTrans h20 Hidden", "Host Username:")
MainGui.SetFont("s9 w400 c000000")
global Tab3_HostNm_EDIT := MainGui.Add("Edit", "x130 y137 w540 Hidden vHostName", HostName)

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab3_PartyMemb := MainGui.Add("Text", "x30 y175 w165 BackgroundTrans h20 Hidden", "Party Members:")
MainGui.SetFont("s9 w400 c000000")
global Tab3_PartyMemb_Edit := MainGui.Add("Edit", "x130 y168 w540 Hidden vPartyMembersStr", PartyMembers)

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global Tab3_Title2 := MainGui.Add("Text", "x30 y201  w200 h22 Hidden", "Settings")
global Tab3_Line2 := MainGui.Add("Progress", "x30 y224 w640 h1 Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cffffff")
global Tab3_RoleTxt := MainGui.Add("Text", "x30 y240 w60 BackgroundTrans h20 Hidden", "You are:")

global Tab3_Role_Host := MainGui.Add("Radio", "x30 y260 w54 Hidden vPlayerRole Group " (PlayerRole != "Member" ?
    "Checked" : ""), "Host")
global Tab3_Role_Member := MainGui.Add("Radio", "x85 y260 w80 Hidden " (PlayerRole == "Member" ? "Checked" : ""),
"Member")

global Tab3_LConditionTxt := MainGui.Add("Text", "x30 y290 w170 BackgroundTrans h20 Hidden", "Go back to lobby if:")

global Tab3_LCondition_All := MainGui.Add("Radio", "x30 y310 w144 Hidden vLeaveCondition Group " (LeaveCondition ==
    "All" ? "Checked" : ""), "All members are gone")
global Tab3_LCondition_Any := MainGui.Add("Radio", "x175 y310 Hidden " (LeaveCondition == "Any" ? "Checked" : ""),
"Any member is gone")

MainGui.SetFont("s10 w400 cFFFFFF")
global MultiplayerEnabledTGL := MainGui.Add("Checkbox", "x30 y368 Hidden vMultiplayerEnabled Checked" MultiplayerEnabled,
    "Enabled")
global Tab3_Line3 := MainGui.Add("Progress", "x30 y360 w640 h1 Hidden Background333333", 0)

MainGui.SetFont("s11 w400 cFFFFFF")
global Tab3_Btn1 := MainGui.Add("Text", "x30 y500 w645 h40 Center Background0e0e0f +Border 0x200 Hidden",
    "Save all settings")
Tab3_Btn1.OnEvent("Click", SaveAllSettingsMULTIPLAYER)

HoverEffect.Push(Tab3_Btn1)

MainGui.SetFont("s9 w400 cFFFFFF")
global Tab3_Info := MainGui.Add("Text", "x30 y400 w640 h100 Hidden",
    "The macro can now run simultaneously with other users. Just enter the host's username and the party members.`nHow to use:`n1. Enter the party leader's username in 'Host Username'.`n2. Enter other players' display names in 'Party Members' (separated by commas).`n3. Click 'Save all settings'."
)

TAB3.Push(Tab3_Title, Tab3_Line1, Tab3_HostNm, Tab3_HostNm_EDIT, Tab3_PartyMemb, Tab3_PartyMemb_Edit, Tab3_Line2,
    Tab3_Btn1, Tab3_Info, MultiplayerEnabledTGL, Tab3_RoleTxt, Tab3_Role_Host, Tab3_Role_Member, Tab3_Title2,
    Tab3_Line3, Tab3_LCondition_All, Tab3_LCondition_Any, Tab3_LConditionTxt)

; tab 4 - WEBHOOK ===========================

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global Tab4_Title := MainGui.Add("Text", "x30 y95 vTab4_TITLE BackgroundTrans h22 w110 Hidden", "Discord Webhook")
HoverEffect.Push(Tab4_Title)
Tab4_Title.OnEvent("Click", DiscordSettings)
global Tab4_Line1 := MainGui.Add("Progress", "x30 y118 w640 h1  Hidden Background333333", 0)
MainGui.SetFont("s9 w400 cAAAAAA")
MainGui.Add("Text", "x30 y135 w200 h20 Hidden vTab4_Lbl1", "Webhook URL:")
global Tab4_Lbl1 := MainGui["Tab4_Lbl1"]
MainGui.SetFont("s9 w400 c000000")
global WebhookLinkCtrl := MainGui.Add("Edit", "x30 y155 w640 h24 Hidden vWebhookLink", WebhookLink)
WebhookLinkCtrl.OnEvent("Change", CheckWebhookLink)
MainGui.SetFont("s9 w400 cFFFFFF")
global WebhookEnabledCtrl := MainGui.Add("Checkbox", "x30 y195 Hidden vWebhookEnabled Checked" WebhookEnabled,
    "Enable Webhook")
global Tab4_Line2 := MainGui.Add("Progress", "x30 y243 w640 h1 Hidden Background333333", 0)
global SendCurrCtrl := MainGui.Add("Checkbox", "x30 y253 Hidden vSendCurrenciesEnabled Checked" SendCurrenciesEnabled,
    "Send Statistics")
SendCurrCtrl.OnEvent("Click", (CtrlObj, *) => CtrlObj.Value ? CheckOcrLanguage() : "")
global DebugLogsCtrl := MainGui.Add("Checkbox", "x140 y253 Hidden vWebhookDebugLogs Checked" WebhookDebugLogs,
    "Debug Logs")
global WebhookScreenshotsCtrl := MainGui.Add("Checkbox", "x235 y253 Hidden vWebhookScreenshots Checked" WebhookScreenshots,
    "Automatic screenshots")
global WebhookTriumphScreenshotsCtrl := MainGui.Add("Checkbox", "x385 y253 Hidden vWebhookTriumphScreenshots Checked" WebhookTriumphScreenshots,
    "Triumph and Loss screenshots")
global WebhookSepatateTriumphScreenshotsCtrl := MainGui.Add("Checkbox",
    "x30 y283 Hidden vWebhookSepatateTriumphScreenshots Checked" WebhookSepatateTriumphScreenshots,
    "Send Triumph/Loss to a separate channel")
; global WebhookPingsCtrl := MainGui.Add("Checkbox", "x30 y316 Hidden vWebhookPings Checked" WebhookPings, "Ping")
; MainGui.SetFont("s8 w400 cb9b9b8")
; global WebhookErrorsPingCtrl := MainGui.Add("Checkbox", "x30 y346 Hidden vWebhookErrorsPing Checked" WebhookErrorsPing, "Errors")
; global WebhookWinsPingCtrl := MainGui.Add("Checkbox", "x85 y346 Hidden vWebhookWinsPing Checked" WebhookWinsPing, "Wins")
; global WebhookLossesPingCtrl := MainGui.Add("Checkbox", "x136 y346 Hidden vWebhookLossesPing Checked" WebhookLossesPing, "Losses")
MainGui.SetFont("s9 w400 c000000")
global WebhookLinkCtrl2 := MainGui.Add("Edit", "x280 y280 w360 h20 Hidden vWebhookLink2", WebhookLink2)
; global WebhookUserIDCtrl := MainGui.Add("Edit", "x85 y313 w200 h20 Hidden vWebhookUserID", WebhookUserID)
MainGui.SetFont("s9 w400 cFFFFFF")
WebhookLinkCtrl2.OnEvent("Change", CheckWebhookLink2)
EnableWebhookLink2()
WebhookSepatateTriumphScreenshotsCtrl.OnEvent("Click", EnableWebhookLink2)
global Tab4_Info := MainGui.Add("Text", "x30 y400 w640 h100 Hidden",
    "Webhook sends real-time logs, screenshots, and currency stats to your Discord server.`nUseful to check if your macro is working while being outside.`nHow to get a webhook URL: Create your own Discord Server > Open any channel's settings > Integrations > Create Webhook > Copy Webhook URL.`nYou can also set up a Discord bot by clicking on the 'Discord Webhook' text to view the Discord bot settings."
)
MainGui.SetFont("s12 w400 cFFFFFF")
global Tab4_Btn1 := MainGui.Add("Text", "x30  y500 w300 h40 Center Background0e0e0f +Border 0x200 Hidden",
    "Test Webhook")
Tab4_Btn1.OnEvent("Click", TestWebhook)
global Tab4_Btn2 := MainGui.Add("Text", "x340 y500 w330 h40 Center Background0e0e0f +Border 0x200 Hidden",
    "Save Discord Settings")
Tab4_Btn2.OnEvent("Click", SaveWebhookSettings)

HoverEffect.Push(Tab4_Btn1)
HoverEffect.Push(Tab4_Btn2)

DiscordWebhookTab.Push(Tab4_Title, Tab4_Line1, Tab4_Line2, Tab4_Btn1, Tab4_Btn2, Tab4_Info, Tab4_Lbl1,
    WebhookEnabledCtrl, SendCurrCtrl, WebhookLinkCtrl, WebhookLinkCtrl2, DebugLogsCtrl, WebhookScreenshotsCtrl,
    WebhookTriumphScreenshotsCtrl, WebhookSepatateTriumphScreenshotsCtrl)

;bot tab

MainGui.SetFont("s9 w400 c000000")
global BotTokenCtrl := MainGui.Add("Edit", "x30 y155 w640 h24 Hidden vBotToken", BotToken)

global ChannelIDCtrl := MainGui.Add("Edit", "x30 y273 w310 h24 Hidden vChannelID", ChannelID)
global WebhookUserIDCtrl2 := MainGui.Add("Edit", "x360 y273 w310 h24 Hidden vWebhookUserID2", UserID)

global Tab4_Line3 := MainGui.Add("Progress", "x30 y305 w640 h1 Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cFFFFFF")
global BotEnabledCtrl := MainGui.Add("Checkbox", "x30 y195 Hidden vBotEnabled Checked" BotEnabled, "Enable Bot")

global Tab4_Info_Bot := MainGui.Add("Link", "x30 y368 w640 h100 Hidden", "
(
Here you can set up a Discord bot.`nThe Discord bot can be used as a remote control for your macro.`nFor example, you can start or stop your macro from your phone, as well as get screenshots, statistics, and more!`n`nYou can find the tutorial on how to set up a bot for your macro here: <a href="https://youtu.be/eAQ5Hm7fQu4">https://youtu.be/eAQ5Hm7fQu4</a>
)"
)

MainGui.SetFont("s9 w400 cAAAAAA")
global bot_token_text := MainGui.Add("Text", "x30 y135 w200 h20 Hidden", "Bot Token:")

global channel_id_text := MainGui.Add("Text", "x30 y253 w200 h20 Hidden BackgroundTrans", "Channel ID:")
global userid_text := MainGui.Add("Text", "x360 y253 w200 h20 Hidden BackgroundTrans", "User ID:")

MainGui.SetFont("s12 w400 cFFFFFF")

global Tab4_bot_Btn1 := MainGui.Add("Text", "x30  y500 w300 h40 Center Background0e0e0f +Border 0x200 Hidden",
    "Test Bot")
Tab4_bot_Btn1.OnEvent("Click", TestBot)

HoverEffect.Push(Tab4_bot_Btn1)

DiscordBotTab.Push(Tab4_Title, Tab4_Line1, Tab4_Line2, BotTokenCtrl, BotEnabledCtrl, Tab4_Btn2, Tab4_bot_Btn1,
    bot_token_text, WebhookUserIDCtrl2, ChannelIDCtrl, channel_id_text, userid_text, Tab4_Line3, Tab4_Info_Bot)

;TAB 5 - SETTINGS ==========================

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global Tab5_Section1 := MainGui.Add("Text", "x30 y95  w200 h22 Hidden", "TDS Keybinds")
global Tab5_Line1 := MainGui.Add("Progress", "x30 y118 w250 h1  Hidden Background333333", 0)

MainGui.SetFont("s8 w400 cAAAAAA", UIFont())
global Tab5_Lbl1 := MainGui.Add("Text", "x30 y135 w70 h16 Hidden", "Call of Arms:")
MainGui.SetFont("s8 w400 c000000")
global ChainKeyCtrl := MainGui.Add("Edit", "x105 y132 w40 h18 Center Limit1 Hidden", ChainKey)

MainGui.SetFont("s8 w400 cAAAAAA")
global Tab5_Lbl2 := MainGui.Add("Text", "x152 y135 w80 h16 Hidden", "Drop The Beat:")
MainGui.SetFont("s8 w400 c000000")
global BeatKeyCtrl := MainGui.Add("Edit", "x238 y132 w40 h18 Center Limit1 Hidden", BeatKey)

MainGui.SetFont("s8 w400 cAAAAAA")
global Tab5_Lbl3 := MainGui.Add("Text", "x30 y160 h16 Hidden", "S. Caravan:")
MainGui.SetFont("s8 w400 c000000")
global CaravanKeyCtrl := MainGui.Add("Edit", "x105 y157 w40 h18 Center Limit1 Hidden", CaravanKey)

MainGui.SetFont("s8 w400 cAAAAAA")
global Tab5_Lbl44 := MainGui.Add("Text", "x152 y160 w80 h16 Hidden", "Raise the Dead:")
MainGui.SetFont("s8 w400 c000000")
global RaiseDeadKeyCtrl := MainGui.Add("Edit", "x238 y157 w40 h18 Center Limit1 Hidden", RaiseDeadKey)
MainGui.SetFont("s9 w400 cFFFFFF", UIFont())
global Tab5_Help12 := MainGui.Add("Text", "x280 y157 w18 h18 0x200 Center Hidden", "?")
Tab5_Help12.OnEvent("Click", HelpRaise)

MainGui.SetFont("s8 w400 cAAAAAA")
global Tab5_Lbl55 := MainGui.Add("Text", "x30 y185 h16 Hidden", "Hologram:")
MainGui.SetFont("s8 w400 c000000")
global HologramKeyCtrl := MainGui.Add("Edit", "x105 y182 w40 h18 Center Limit1 Hidden", HologramKey)

MainGui.SetFont("s8 w400 cAAAAAA")
global Tab5_Lbl56 := MainGui.Add("Text", "x152 y185 h16 Hidden", "Reposition:")
MainGui.SetFont("s8 w400 c000000")
global RepoKeyCtrl := MainGui.Add("Edit", "x238 y182 w40 h18 Center Limit1 Hidden", RepoKey)
MainGui.SetFont("s9 w400 cFFFFFF", UIFont())
global Tab5_Help11 := MainGui.Add("Text", "x280 y182 w18 h18 0x200 Center Hidden", "?")
Tab5_Help11.OnEvent("Click", HelpBrawler)

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab5_Lbl99 := MainGui.Add("Text", "x183 y248 BackgroundTrans Hidden", "cancel:")
MainGui.SetFont("s8 w400 c000000")
global CancelPlacementKeyCtrl := MainGui.Add("Edit", "x230 y248 w17 h17 Center Limit1 Hidden", CancelPlacementKey)

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab5_LblUPG := MainGui.Add("Text", "x30 y248 BackgroundTrans Hidden", "upgrade:")
MainGui.SetFont("s8 w400 c000000")
global UpgradeTowerGCtrl := MainGui.Add("Edit", "x85 y248 w17 h17 Center Limit1 Hidden", UpgradeTowerGKey)

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab5_LblUPGBTM := MainGui.Add("Text", "x108 y248 BackgroundTrans Hidden", "bottom:")
MainGui.SetFont("s8 w400 c000000")
global UpgradeTowerGBCtrl := MainGui.Add("Edit", "x158 y248 W17 h17 Center Limit1 Hidden", UpgradeTowerGBKey)

MainGui.SetFont("s9 w400 cFFFFFF")

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global Tab5_Section2 := MainGui.Add("Text", "x310 y95  w200 h22 Hidden BackgroundTrans", "Macro Settings")
global Tab5_Line2 := MainGui.Add("Progress", "x310 y118 w360 h1  Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cFFFFFF", UIFont())
global UseUpgradeHCtrl := MainGui.Add("Checkbox", "x310 y135 Hidden", "Use Hotkeys for Upgrading")
UseUpgradeHCtrl.Value := (UseHForUpgrade = 1)
global Tab5_Help6 := MainGui.Add("Text", "x475 y135 w18 h18 0x200 Center Hidden", "?")
Tab5_Help6.OnEvent("Click", HelpAutoCameraCorrection)

global UseRestartBtnCtrl := MainGui.Add("Checkbox", "x310 y160 Hidden", "Click Restart button")
UseRestartBtnCtrl.Value := (UseRestartBtn = "1" || UseRestartBtn = 1)
global Tab5_Help4 := MainGui.Add("Text", "x475 y158 w18 h18 0x200 Center Hidden", "?")
Tab5_Help4.OnEvent("Click", HelpRestartBtn)

global UsePlayAgainBtnCtrl := MainGui.Add("Checkbox", "x310 y185 Hidden", "Click Play Again button")
UsePlayAgainBtnCtrl.Value := (UsePlayAgainBtn = "1" || UsePlayAgainBtn = 1)
global Tab5_Help5 := MainGui.Add("Text", "x475 y183 w18 h18 0x200 Center Hidden", "?")
Tab5_Help5.OnEvent("Click", HelpPlayAgainBtn)

global CheckTheMapCtrl := MainGui.Add("Checkbox", "x310 y210 Hidden", "Check the map")
CheckTheMapCtrl.Value := (CheckTheMap = "1" || CheckTheMap = 1)
global Tab5_Help7 := MainGui.Add("Text", "x475 y207 w18 h18 0x200 Center Hidden", "?")
Tab5_Help7.OnEvent("Click", HelpCheckTheMap)

global UseNumbersForHotbarCtrl := MainGui.Add("Checkbox", "x310 y235 Hidden", "Use Numbers for Hotbar")
UseNumbersForHotbarCtrl.Value := (UseNumbersForHotbar = "1" || UseNumbersForHotbar = 1)

global CollectPlaytimeRewardsCtrl := MainGui.Add("Checkbox", "x510 y185 Hidden", "Collect playtime rewards")
CollectPlaytimeRewardsCtrl.Value := (CollectPlaytimeRewards = "1" || CollectPlaytimeRewards = 1)

global DebugConsoleCtrl := MainGui.Add("Checkbox", "x570 y135 Hidden", "Debug Logs")
DebugConsoleCtrl.Value := (DebugConsole = "1" || DebugConsole = 1)

global PotatoModeCtrl := MainGui.Add("Checkbox", "x570 y160 Hidden", "Potato Mode")
PotatoModeCtrl.Value := (PotatoMode = 1)

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab1_Lbl3 := MainGui.Add("Text", "x530 y210 w100 h20 Hidden BackgroundTrans", "Timescale:")
global TimeScaleModeCtrl := MainGui.Add("DropDownList", "x595 y206 w80 Hidden", ["OFF", "1.5x", "2x"])
TimeScaleModeCtrl.Text := TimeScaleMode

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab1_Lbl4 := MainGui.Add("Text", "x505 y235 w100 h20 Hidden BackgroundTrans", "Upgrade Delay:")
MainGui.SetFont("s8 w400 c000000")
global UpgradeDelayCtrl := MainGui.Add("Edit", "x595 y231 w80 Hidden Number Limit3 vUpgradeDelay", UpgradeDelay)
UpgradeDelayCtrl.Text := UpgradeDelay

MainGui.SetFont("s9 w400 cFFFFFF")
global MouseSpeedLbl := MainGui.Add("Text", "x310 y270 w110 h20 Hidden BackgroundTrans", "Mouse Speed:")
global MouseSpeedTxt := MainGui.Add("Text", "x389 y270 w26 Hidden", DefaultMouseSpeed)
global MouseSpeedUpDown := MainGui.Add("UpDown", "Range1-3 Hidden", DefaultMouseSpeed)
MouseSpeedUpDown.OnEvent("Change", (ctrl, *) => MouseSpeedTxt.Value := ctrl.Value)

global MouseDelayLbl := MainGui.Add("Text", "x435 y270 w90 h20 Hidden BackgroundTrans", "Mouse Delay:")
global MouseDelayTxt := MainGui.Add("Text", "x509 y270 w32 Hidden", MouseDelay)
global MouseDelayUpDown := MainGui.Add("UpDown", "Range3-75 Hidden", MouseDelay)
MouseDelayUpDown.OnEvent("Change", (ctrl, *) => MouseDelayTxt.Value := ctrl.Value)

global KeyDelayLbl := MainGui.Add("Text", "x565 y270 w90 h20 Hidden BackgroundTrans", "Key Delay:")
global KeyDelayTxt := MainGui.Add("Text", "x625 y270 w32 Hidden", KeyDelay)
global KeyDelayUpDown := MainGui.Add("UpDown", "Range5-100 Hidden", KeyDelay)
KeyDelayUpDown.OnEvent("Change", (ctrl, *) => KeyDelayTxt.Value := ctrl.Value)

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global Tab5_Section3 := MainGui.Add("Text", " BackgroundTrans x30 y272 w200 h22 Hidden", "Recording Hotkeys")
global Tab5_Line3 := MainGui.Add("Progress", "x30 y295 w640 h1  Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cAAAAAA")
global PlcTowerTEXT := MainGui.Add("Text", "x30 y304 w95 h20 Hidden", "Place Tower:")
global PlaceTowerKeyCtrl := MainGui.Add("Hotkey", "x130 y304 w110 h20 Center Hidden", PlaceTowerKey)

global UpgTowerTEXT := MainGui.Add("Text", "x30 y334 w95 h20 Hidden", "Upgrade Tower:")
global UpgradeTowerKeyCtrl := MainGui.Add("Hotkey", "x130 y334 w110 h20 Center Hidden", UpgradeTowerKey)

global AlignCamTEXT := MainGui.Add("Text", "x30 y366 w95 h20 Hidden", "Align Camera:")
global AlignCameraKeyCtrl := MainGui.Add("Hotkey", "x130 y366 w110 h20 Center Hidden", AlignCameraKey)

global DjTrackTEXT := MainGui.Add("Text", "x255 y304 w95 h20 Hidden", "Change DJ Track:")
global ChangeDJTrackKeyCtrl := MainGui.Add("Hotkey", "x355 y304 w110 h20 Center Hidden", ChangeDJTrackKey)

global SellTowTEXT := MainGui.Add("Text", "x255 y334 w95 h20 Hidden", "Sell Tower:")
global SellTowerKeyCtrl := MainGui.Add("Hotkey", "x355 y334 w110 h20 Center Hidden", SellTowerKey)

global DelRecTEXT := MainGui.Add("Text", "x255 y366 w95 h20 Hidden", "Delete Record:")
global DeleteTowerRecordingKeyCtrl := MainGui.Add("Hotkey", "x355 y366 w110 h20 Center Hidden", DeleteTowerRecordingKey
)

global RecInputsTEXT := MainGui.Add("Text", "x480 y304 w95 h20 Hidden", "Record Inputs:")
global RecordInputsKeyCtrl := MainGui.Add("Hotkey", "x580 y304 w90 h20 Center Hidden", RecordInputsKey)

global HoloTEXT := MainGui.Add("Text", "x480 y334 w95 h20 Hidden", "Hologram Tower:")
global HoloKeyCtrl := MainGui.Add("Hotkey", "x580 y334 w90 h20 Center Hidden", HoloKey)

global RaiseDeadTEXT := MainGui.Add("Text", "x480 y366 w95 h20 Hidden", "Change Targets:")
global ChangeTargetsCTRL := MainGui.Add("Hotkey", "x580 y366 w90 h20 Center Hidden", ChangeTargetsKey)

global Tab5_Line4 := MainGui.Add("Progress", "x30 y393 w640 h1 Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab5_Lbl4 := MainGui.Add("Text", "x30 y405 w100 h20 Hidden", "VIP Server Link:")
MainGui.SetFont("s9 w400 c000000")
global VipLinkCtrl := MainGui.Add("Edit", "x30 y430 w640 h24 Hidden", VipLink)
MainGui.SetFont("s11 w400 cFFFFFF")
VipLinkCtrl.OnEvent("Change", CheckVipLink)

global UseVipServerCtrl := MainGui.Add("Checkbox", "x30 y465 Hidden", "Use VIP Server")
UseVipServerCtrl.Value := (UseVipServer = "1" || UseVipServer = 1)

global AlwaysOnTopCtrl := MainGui.Add("Checkbox", "x160 y465 Hidden", "Always On Top")
AlwaysOnTopCtrl.Value := (AlwaysOnTop = "1" || AlwaysOnTop = 1)

global LegacyModeCtrl := MainGui.Add("Checkbox", "x560 y465 Hidden", "Legacy Mode")
LegacyModeCtrl.Value := (LegacyMode = "1" || LegacyMode = 1)
LegacyModeCtrl.OnEvent("Click", LegacyModeInfo)

MainGui.SetFont("s9 w400 cFFFFFF")
global Tab5_BtnClearLogs := MainGui.Add("Text",
    "x310 y463 w120 h24 Center Background0e0e0f +Border 0x200 Hidden", "Clear Logs")
Tab5_BtnClearLogs.OnEvent("Click", ClearStoredLogs)

HoverEffect.Push(Tab5_BtnClearLogs)

MainGui.SetFont("s11 w400 cFFFFFF")
global Tab5_Btn1 := MainGui.Add("Text", "x30 y500 w645 h40 Center Background0e0e0f +Border 0x200 Hidden",
    "Save all settings")
Tab5_Btn1.OnEvent("Click", SaveAllSettings)

HoverEffect.Push(Tab5_Btn1)

; tab 6 - tools ===========================

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global Tools_Section := MainGui.Add("Text", "x30 y95 w200 h22 Hidden", "Tools")
global Tools_Section_Line := MainGui.Add("Progress", "x30 y118 w640 h1 Hidden  Background333333", 0)

MainGui.SetFont("s9 w400 cffffff")
global Tools_Info := MainGui.Add("Text", "x30 y490 w640 h100 Hidden",
    "Additional utilities for optimizing and simplifying the gameplay and automating repetitive actions. It reduces your suffering."
)

global Auto_COA := MainGui.Add("Picture", "x30 y125 w197 h176 Hidden", "Resources/Gui/auto_coa_preview.png")

Auto_COA.OnEvent("Click", RunAutoAbTool)

global Auto_Spin := MainGui.Add("Picture", "x240 y125 w197 h139 Hidden", "Resources/Gui/auto_spin_preview.png")

Auto_Spin.OnEvent("Click", RunAutoSpinTool)

global Auto_Consum := MainGui.Add("Picture", "x450 y125 w200 h140 Hidden",
    "Resources/Gui/auto_open_consumable_preview.png")

Auto_Consum.OnEvent("Click", RunAutoConsumableTool)

; tab 7 - credits ===========================

MainGui.SetFont("s18 bold cFFFFFF", UIFont())
global Credit_TITLE := MainGui.Add("Text", "x30 y95 w640 Hidden Center", "Ultimate Macro")

global Credit_Divider := MainGui.Add("Progress", "x80 y132 w530 h2 Hidden Center Background6e6e6e", 0)

MainGui.SetFont("s11 w400 cFFFFFF", UIFont())
global Credit_Content := MainGui.Add("Edit", "x80 y150 w530 h155 Multi ReadOnly +VScroll -Wrap -E0x200 Background111111 Hidden", "
(
Started on March 30, 2026. Built in AutoHotkey v2.

Original Creator
• Darksen

Lead Developer
• pizzaroles24

Developers
• ziadod
• kronoxxv
• banana.dev

Development Contributor
• 4riff

QA
• hetzel401
• tristanm1ce
• frostzzz
)")

MainGui.SetFont("s12 italic w400 cFFFFFF", UIFont())
global Credit_Support := MainGui.Add("Link", "x30 y390 w640 h90 Hidden", "
(
You can *support* me and the macro with <a href="https://www.donationalerts.com/r/darksen1">real money</a> or with <a href="https://www.roblox.com/games/115405526400244/Raise-an-Onett">robux (press donations button when you joined)</a>, do it if you're really enjoying the macro.
I truly appreciate any support! (Please Donate)
)"
)

global Credit_InfoBG := MainGui.Add("Progress", "x0 y320 w700 h50 Hidden Center Background2a5c3d", 0)
MainGui.SetFont("s12 norm w400 cFFFFFF", UIFont())
global Credit_Info := MainGui.Add("Text", "x0 y320 w700 h50 BackgroundTrans 0x200 Center Hidden", "
(
Special thanks to my Discord Community!
)")

global Divider := MainGui.Add("Progress", "x0 y500 w700 h1 Hidden Background222222", 0)
global FooterBg := MainGui.Add("Progress", "x0 y501 w700 h64 Disabled Hidden Background0f0f0f", 0)

MainGui.SetFont("s10 italic cFFFFFF", UIFont())
global version_text := MainGui.Add("Text", "x30 y520 BackgroundTrans Hidden", ver " * made by darksen")

global githubImg := MainGui.Add("Picture", "x580 y520 w24 h24 Hidden BackgroundTrans", "Resources\github.png")
githubImg.OnEvent("Click", githubLink)
global DiscordImg := MainGui.Add("Picture", "x611 y520 w24 h24 Hidden BackgroundTrans", "Resources\discord.png")
DiscordImg.OnEvent("Click", DiscordLink)
global YoutubeImg := MainGui.Add("Picture", "x642 y520 w24 h24 Hidden BackgroundTrans", "Resources\youtube.png")
YoutubeImg.OnEvent("Click", YouTubeLink)

MainGui.Title := "Ultimate Macro"
MainGui.Show("w700 h565")

if (AlwaysOnTop = 1) {
    MainGui.Opt("+AlwaysOnTop")
} else {
    MainGui.Opt("-AlwaysOnTop")
}

SetTimer(() => RemoveInitialFocus(), -50)

global CurrentTab := "Tab1"
TabCtrl[1].SetFont("cFFFFFF")
SwitchStrategiesTab("Community")
ShowTabContent("Tab1")
EnableStratRotation()

; 10ms was 100 sweeps/second of Win32 geometry calls for a purely cosmetic hover
; effect. 40ms is still visually immediate and cuts that load by 4x.
SetTimer(Hoverwatchdog, 40)

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
    loop HoverTab.Length {
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

    newX := 20 + (idx - 1) * 90
    TabLine.Move(newX, , 80)

    ShowTabContent(newTab)
}

Hoverwatchdog(*) {
    static hClose := 0, hMin := 0, hMain := 0, hChild := 0
    static hoverClose := false, hoverMin := false, hoverTabs := []
    static activeHoverHwnd := 0
    static activeGradHwnd := 0

    ; Populate ONCE. This used to push HoverTab.Length entries on every tick, so a
    ; 10ms timer appended ~700 dead entries per second and this static array grew
    ; without bound for the life of the process (~2.5M entries per hour).
    while (hoverTabs.Length < HoverTab.Length)
        hoverTabs.Push(false)

    if (!hMain)
        hMain := MainGui.Hwnd

    ; Nothing can be hovered while the window is hidden (which is the entire time
    ; a strategy is running). Skip the per-control GetPos sweep entirely.
    if (!hMain || !WinExist("ahk_id " hMain))
        return

    if (IsSet(ChildGui) && HasProp(ChildGui, "Hwnd"))
        hChild := ChildGui.Hwnd

    oldMode := A_CoordModeMouse
    CoordMode("Mouse", "Screen")
    MouseGetPos(&screenX, &screenY, &mouseWin, &mouseCtrl, 2)
    CoordMode("Mouse", oldMode)

    try {
        WinGetPos(&mX, &mY, , , "ahk_id " hMain)
        mouseX := screenX - mX
        mouseY := screenY - mY
    } catch {
        mouseX := 0
        mouseY := 0
    }

    if (mouseWin != hMain && mouseWin != hChild) {
        loop HoverTab.Length {
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
                    } else if (HasProp(ctrl, "IsSelected") && ctrl.IsSelected) {
                        ctrl.Opt("Background222222")
                        ctrl.SetFont("c3A86FF Bold")
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

    loop HoverTab.Length {
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
                                } else if (HasProp(oldCtrl, "IsSelected") && oldCtrl.IsSelected) {
                                    oldCtrl.Opt("Background222222")
                                    oldCtrl.SetFont("c3A86FF Bold")
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
                    } else if (HasProp(ctrl, "IsSelected") && ctrl.IsSelected) {
                        ctrl.Opt("Background222222")
                        ctrl.SetFont("c3A86FF Bold")
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

    if (IsSet(GradientButtons) && hChild) {
        matchedGrad := false

        try {
            WinGetPos(&chX, &chY, , , "ahk_id " hChild)
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
    if (IsSet(ChildGui) && ChildGui != "") {
        ChildGui.Hide()
    }
}

ShowTabContent(tab) {
    global ChildGui
    ; Explicitly declare Tab 1 variables as global to prevent #Warn
    global Tab1_Section1, Tab1_Line1, Tab1_Lbl1, Strategy1Ctrl, Tab1_Btn1, Tab1_Btn2
    global Tab1_Lbl2, Strategy2Ctrl, Tab1_Btn3, Tab1_Btn4, RotateStrategiesCtrl, AutoEquipCtrl, AutoConfigCtrl
    global Tab1_Section2, Tab1_Line2, BtnCommStrats, BtnMyStrats, Tab1_Start, Tab1_Stop

    if (tab = "Tab1") {
        for ctrl in [Tab1_Section1, Tab1_Line1, Tab1_Lbl1, Strategy1Ctrl, Tab1_Btn1, Tab1_Btn2,
            Tab1_Lbl2, Strategy2Ctrl, Tab1_Btn3, Tab1_Btn4, RotateStrategiesCtrl, AutoEquipCtrl, AutoConfigCtrl, Tab1_Section2,
            Tab1_Line2, BtnCommStrats, BtnMyStrats,
            Tab1_Start, Tab1_Stop]
            ctrl.Visible := true
        EnableStratRotation()
        ShowChildGui()
    } else if (tab = "Tab2") {
        for ctrl in [Tab2_Title, Tab2_Line1, Tab2_Lbl1, RecMapsD, Tab2_Lbl2, RecDiffCtrl,
            Tab2_Lbl3, RecModifiersCtrl, Tab2_Info2, Tab2_Lbl4, RecTowersCtrl, Tab2_Info1,
            Tab2_Line2, Tab2_Line3, RecAutoChainCtrl, RecAutoCaravanCtrl, RecAutoDropCtrl,
            RecAutoSkipCtrl, RecAbilitySpamCtrl, Tab2_Info, RecMoveCtrl, DIRECTIONTEXTCtrl, RecMoveDirCtrl,
            Tab2_Txt4, RecMoveDurCtrl, Tab2_Btn1, Tab2_Btn2]
            ctrl.Visible := true
    } else if (tab = "Tab3") {
        for ctrl in TAB3
            ctrl.Visible := true
    } else if (tab = "Tab4") {
        for ctrl in DiscordWebhookTab
            ctrl.Visible := true
        tab4_Title.Text := "Discord Webhook"
        EnableWebhookLink2()
    } else if (tab = "Tab5") {
        for ctrl in [Tab5_Section1, Tab5_Line1, Tab5_Lbl1, ChainKeyCtrl,
            Tab5_Lbl2, BeatKeyCtrl, Tab5_Lbl3, CaravanKeyCtrl,
            Tab5_Lbl44, RaiseDeadKeyCtrl, Tab5_Lbl55, Tab5_Lbl56, HologramKeyCtrl, RepoKeyCtrl,
            Tab5_Lbl99, Tab5_LblUPG, Tab5_LblUPGBTM, CancelPlacementKeyCtrl, UpgradeTowerGCtrl, UpgradeTowerGBCtrl,
            Tab1_Lbl3, Tab1_Lbl4, TimeScaleModeCtrl, UpgradeDelayCtrl,
            Tab5_Section2, Tab5_Line2, Tab5_Help6,
            UseRestartBtnCtrl, Tab5_Help4, UsePlayAgainBtnCtrl, Tab5_Help5,
            CheckTheMapCtrl, UseNumbersForHotbarCtrl, UseUpgradeHCtrl, Tab5_Help7, Tab5_Help11, Tab5_Help12,
            PotatoModeCtrl, DebugConsoleCtrl,
            Tab5_Section3, Tab5_Line3, PlcTowerTEXT, UpgTowerTEXT, AlignCamTEXT,
            DjTrackTEXT, SellTowTEXT, DelRecTEXT, RecInputsTEXT,
            HoloTEXT, RaiseDeadTEXT,
            PlaceTowerKeyCtrl, UpgradeTowerKeyCtrl, AlignCameraKeyCtrl,
            ChangeDJTrackKeyCtrl, SellTowerKeyCtrl, DeleteTowerRecordingKeyCtrl,
            RecordInputsKeyCtrl, HoloKeyCtrl, ChangeTargetsCTRL,
            CollectPlaytimeRewardsCtrl,
            Tab5_Line4, Tab5_Lbl4, VipLinkCtrl, UseVipServerCtrl, AlwaysOnTopCtrl, LegacyModeCtrl,
            Tab5_BtnClearLogs, Tab5_Btn1,
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
        AlignCameraKeyCtrl.Value := AlignCameraKey
        PlaceTowerKeyCtrl.Value := PlaceTowerKey
        UpgradeTowerKeyCtrl.Value := UpgradeTowerKey
        SellTowerKeyCtrl.Value := SellTowerKey
        DeleteTowerRecordingKeyCtrl.Value := DeleteTowerRecordingKey
        ChangeDJTrackKeyCtrl.Value := ChangeDJTrackKey
        RecordInputsKeyCtrl.Value := RecordInputsKey
        HoloKeyCtrl.Value := HoloKey
        ChangeTargetsCTRL.Value := ChangeTargetsKey
        TimeScaleModeCtrl.Text := TimeScaleMode

        MouseSpeedUpDown.Value := DefaultMouseSpeed
        MouseSpeedTxt.Value := DefaultMouseSpeed
        MouseDelayUpDown.Value := MouseDelay
        MouseDelayTxt.Value := MouseDelay
        KeyDelayUpDown.Value := KeyDelay
        KeyDelayTxt.Value := KeyDelay
        UpgradeDelayCtrl.Value := UpgradeDelay

    } else if (tab = "Tab6") {
        for ctrl in [Tools_Section, Tools_Section_Line, Tools_Info, Auto_COA, Auto_Spin, Auto_Consum]
            ctrl.Visible := true
    } else if (tab = "Tab7") {
        Credit_Content.Visible := true
        Credit_Info.Visible := true
        Credit_Support.Visible := true
        version_text.Visible := true
        Divider.Visible := true
        FooterBg.Visible := true
        Credit_TITLE.Visible := true
        DiscordImg.Visible := true
        YoutubeImg.Visible := true
        githubImg.Visible := true
        Credit_Divider.Visible := true
        Credit_InfoBG.Visible := true
    }
}

ShowChildGui() {
    global ChildGui, FrameX, FrameY, FrameW, FrameH, MainGui
    if (IsSet(ChildGui) && ChildGui != "") {
        ChildGui.Show("x" FrameX " y" FrameY " w" FrameW " h" FrameH)
    }
}

MoveWindow(ctrl, *) {
    PostMessage(0xA1, 2, , , MainGui)
}
MinimizeWindow(ctrl, *) {
    MainGui.Minimize()
}
CloseWindow(ctrl, *) {
    ExitApp()
}
DiscordLink(ctrl, *) {
    Run("https://discord.gg/DQnc2JDJtr")
}
githubLink(ctrl, *) {
    Run("https://github.com/UltimateMacro/Ultimate-Macro-New-Era")
}
YouTubeLink(ctrl, *) {
    Run("https://www.youtube.com/@darksenn")
}

DownloadStrat(ctrl, *) {
    nm := ctrl.StratFile

    ; If it is an absolute path (local recording), use it directly. Otherwise, assume Community relative.
    if (RegExMatch(nm, "^[a-zA-Z]:\\")) {
        downloadedStrat := nm
    } else {
        downloadedStrat := A_WorkingDir "\Resources\Strats" (SubStr(nm, 1, 1) = "\" ? nm : "\" nm)
    }

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

EditStratFile(ctrl, *) {
    stratToEdit := ctrl.StratFile
    if FileExist(stratToEdit) {
        Run("notepad.exe `"" stratToEdit "`"")
    } else {
        MsgBox("Strategy file not found!`n" stratToEdit, "Error", 0x10)
    }
}

OnMouseWheel(wp, lp, msg, hwnd) {
    global ChildHwnd, ChildGui, ContentGui
    MouseGetPos(, , &maxH, &ctrlH, 2)

    parentH := (ctrlH != "") ? DllCall("GetParent", "Ptr", ctrlH, "Ptr") : 0
    
    ch := (IsSet(ChildGui) && ChildGui != "") ? ChildGui.Hwnd : 0
    co := (IsSet(ContentGui) && ContentGui != "") ? ContentGui.Hwnd : 0

    if (ch && (maxH = ch || maxH = co || ctrlH = ch || ctrlH = co || parentH = ch || parentH = co)) {
        dir := ((wp >> 16) & 0xFFFF) > 0x7FFF ? 1 : 0
        loop 3 {
            SendMessage(0x0115, dir, 0, , "ahk_id " ch)
        }
    }
}

OnScroll(wp, lp, msg, hwnd) {
    global ChildGui, ContentGui, CurrentScrollPos, ContentH, FrameH, SliderH, Slider
    if (!IsSet(ChildGui) || ChildGui == "")
        return
        
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
    if (maxScroll <= 0)
        return
        
    newPos := Max(0, Min(newPos, maxScroll))
    
    if (newPos != CurrentScrollPos) {
        if (IsSet(ContentGui) && ContentGui != "") {
            DllCall("ScrollWindow", "Ptr", ContentGui.Hwnd, "Int", 0, "Int", CurrentScrollPos - newPos, "Ptr", 0, "Ptr", 0)
            CurrentScrollPos := newPos

            availableTrackSpace := FrameH - SliderH
            sliderVisualY := Round((newPos / maxScroll) * availableTrackSpace)

            Slider.Move(, sliderVisualY)
            DllCall("UpdateWindow", "Ptr", ContentGui.Hwnd)
        }
    }
}

HandleSliderMouseDown(wParam, lParam, msg, hwnd) {
    global Slider, SliderBG, ContentGui, FrameH, SliderH, ContentH, CurrentScrollPos

    ; Check if required objects exist and are valid
    if (!IsSet(Slider) || !Slider || !IsSet(SliderBG) || !SliderBG || !IsSet(ContentGui) || ContentGui == "")
        return

    ; Check if the control still exists in the GUI before accessing properties
    try {
        ; Try to get the control's position - this will throw if destroyed
        Slider.GetPos(&sx, &sy, &sw, &sh)
    } catch {
        return
    }

    ; Only trigger if clicking the scrollbar area
    if (hwnd != Slider.Hwnd && hwnd != SliderBG.Hwnd)
        return

    ; Get absolute screen position of the mouse
    oldMode := A_CoordModeMouse
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mouseX, &mouseY)
    CoordMode("Mouse", oldMode)

    ; Get exact screen position of the GUI's inner working area
    WinGetClientPos(&winX, &winY, , , "ahk_id " ContentGui.Hwnd)
    
    ; Get the thumb's current internal Y position
    Slider.GetPos(&sx, &sy, &sw, &sh)
    
    ; Calculate physical screen boundaries of the thumb
    thumbTop := winY + sy
    thumbBot := thumbTop + sh

    maxScroll := ContentH - FrameH
    if (maxScroll <= 0)
        return
    availableTrack := FrameH - SliderH

    ; --- DRAG THUMB LOGIC --- 
    ; If the mouse is physically inside the vertical space of the thumb
    if (mouseY >= thumbTop && mouseY <= thumbBot) {
        startY := mouseY
        startScroll := CurrentScrollPos

        While GetKeyState("LButton", "P") {
            ; Check if controls still exist during drag
            try {
                Slider.GetPos()
            } catch {
                break
            }

            oldModeDrag := A_CoordModeMouse
            CoordMode("Mouse", "Screen")
            MouseGetPos(, &currentY)
            CoordMode("Mouse", oldModeDrag)

            deltaY := currentY - startY
            
            scrollDelta := (deltaY / availableTrack) * maxScroll
            newPos := startScroll + scrollDelta
            newPos := Max(0, Min(newPos, maxScroll))
            
            if (newPos != CurrentScrollPos) {
                try {
                    DllCall("ScrollWindow", "Ptr", ContentGui.Hwnd, "Int", 0, "Int", CurrentScrollPos - newPos, "Ptr", 0, "Ptr", 0)
                    CurrentScrollPos := newPos
                    
                    sliderVisualY := Round((newPos / maxScroll) * availableTrack)
                    Slider.Move(, sliderVisualY)
                    DllCall("UpdateWindow", "Ptr", ContentGui.Hwnd)
                } catch {
                    break
                }
            }
            Sleep(10)
        }
    } 
    ; --- JUMP LOGIC --- 
    ; If clicking the track above/below the thumb
    else {
        ; Calculate where they clicked relative to the visible window track (ignoring scroll drift)
        trackClickY := mouseY - winY
        targetY := trackClickY - (SliderH / 2)
        
        newPos := (targetY / availableTrack) * maxScroll
        newPos := Max(0, Min(newPos, maxScroll))
        
        if (newPos != CurrentScrollPos) {
            try {
                DllCall("ScrollWindow", "Ptr", ContentGui.Hwnd, "Int", 0, "Int", CurrentScrollPos - newPos, "Ptr", 0, "Ptr", 0)
                CurrentScrollPos := newPos
                
                sliderVisualY := Round((newPos / maxScroll) * availableTrack)
                Slider.Move(, sliderVisualY)
                DllCall("UpdateWindow", "Ptr", ContentGui.Hwnd)
            } catch {
                return
            }
        }
    }
}

EnableStratRotation(*) {
    global RotateStrategies, SwapAmount, SwapUnit

    v := MainGui.Submit(false)
    RotateStrategies := v.RotateStrategies
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
        IniWrite(AutoEquip, SettingsFile, "Options", "AutoEquip")
        SwapAmount := SwapAmountCtrl.Text
        SwapUnit := SwapUnitCtrl.Text
        AutoEquipCtrl.Move(357, 190)
	AutoConfigCtrl.Move(490, 190)
        IniWrite(SwapAmount, SettingsFile, "Options", "SwapAmount")
        IniWrite(SwapUnit, SettingsFile, "Options", "SwapUnit")
    } else {
        AutoEquipCtrl.Move(155, 190)
	AutoConfigCtrl.Move(285, 190)
    }
}

EnableAutoEquip(*) {
    global AutoEquip

    v := MainGui.Submit(false)
    AutoEquip := v.AutoEquip
    IniWrite(AutoEquip, SettingsFile, "Options", "AutoEquip")
}

EnableAutoConfig(*) {
    global AutoConfigureSettings
    v := MainGui.Submit(false)
    AutoConfigureSettings := v.AutoConfigureSettings
    IniWrite(AutoConfigureSettings, SettingsFile, "Options", "AutoConfigureSettings")
    
    if (AutoConfigureSettings) {
        ApplyMacroSettings()
    } else {
        RestoreOriginalSettings()
    }
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
                ModernMsgBox("Warning", "Rotation mode is enabled but strategy " num " is empty or file doesn't exist!`nPlease select a valid file for Strategy " num "!",
                    "OK", "WARNING")
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
        MsgBox(
            "Since you are starting the macro for the first time... Read this so your macro can work properly:`n`n1. Go to the TDS Settings and ENABLE 'Prefer Vertical Upgrades`n2. Go to the TDS Settings and set UI Scale to 'LARGE'`n3. Set your Roblox Camera Mode to Classic`n4. If your Roblox graphics are automatic, set them to manual.`n5. Turn off camera shake in TDS.`n6. Disable Dialog in TDS`n7. Enable UI Navigation toggle in the Roblox settings.`n8. Enable 'Show Tower Options' in TDS.`n9. Set Roblox Maximum Frame Rate to 60 FPS (recommended for consistent macro timing).`n10. Set Windows Display Scale to 100%.`n`nRecommended screen resolution for this macro is 1920x1080 (Resolutions bigger than 1080p may not work. You can use 1366x768 & 1280x720 though, they work pretty well).`nThis macro requires a good CPU. You can use it though if your device is bad, enable potato mode and make the delays bigger.`nPlease, join my Discord server to get help and check the FAQ.",
            "READ THIS!!", 0x1030)
    }

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

    LoadStrategyFile(stratFile)

    if (requiredTowers != "" && !AutoEquip)
        MsgBox(requiredTowers, "Required Towers", "0x1040 T60")

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
    SendToWebhookInstant(startInfo, , flush := false)

    CheckOcrLanguage()

    MultiInstanceTools :=
        "RobloxAccountManager.exe,Roblox Account Manager.exe,RAM.exe,RobloxMulti.exe,MultiRoblox.exe,MultipleRoblox.exe,Multiple Roblox.exe"
    loop parse, MultiInstanceTools, "," {
        if ProcessExist(A_LoopField) {
            MsgBox("Conflicting program detected:`n" A_LoopField "`n`nFor this script to work properly, please close all Roblox multi-client utilities.`nPlease close them and try again.",
                "Error", 0x1030)
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
            Gems := IniRead(StateFile, "State", "Gems", "0")
            Timescales := IniRead(StateFile, "State", "Timescale", "0")
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
        IniDelete(StateFile, "State", "HeartbeatPhase")
        IniDelete(StateFile, "State", "HeartbeatTick")
        IniDelete(StateFile, "State", "HeartbeatTimeout")
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
    global Tab2_Btn1, Tab2_Btn2, HoverEffect
    global RecordingWidth, RecordingHeight

    if (Recording)
        return

    v := MainGui.Submit(false)

    if (!v.RecMaps or !v.RecDifficulty or !v.RecRequiredTowers) {
        MsgBox(
            "Failed to start recording!`nMake sure you have entered the towers, the map, and the difficulty, then try again.",
            "Error", 0x1010)
        return
    }

    ; Validate Roblox before changing button/title state. A failed Start Recording
    ; must leave both the runtime state and the GUI in their idle state.
    if !getRobloxPos(, , &RecordingWidth, &RecordingHeight) || RecordingWidth <= 0 || RecordingHeight <= 0 {
        RecordingWidth := 0
        RecordingHeight := 0
        RuntimeLogWarn("recording_geometry_required", "Recording blocked because Roblox client geometry is unavailable")
        MsgBox(
            "Roblox must be open and detectable before starting a recording.`n`nOpen Roblox, then try Start Recording again.",
            "Roblox required for recording",
            0x30
        )
        return
    }

    RuntimeLogInfo("recording_geometry_captured", "Captured Roblox client size for recording", "width=" RecordingWidth "; height=" RecordingHeight)

    recordingWarnings := []
    if (A_ScreenWidth != 1920 || A_ScreenHeight != 1080)
        recordingWarnings.Push("• Screen resolution is " A_ScreenWidth "x" A_ScreenHeight " (1920x1080 recommended).")

    try {
        recordingHwnd := GetRobloxHWND()
        if recordingHwnd {
            recordingDpi := DllCall("User32.dll\GetDpiForWindow", "Ptr", recordingHwnd, "UInt")
            if (recordingDpi > 0) {
                recordingScalePct := Round((recordingDpi / 96) * 100)
                if (recordingScalePct != 100)
                    recordingWarnings.Push("• Windows display scaling is approximately " recordingScalePct "% (100% recommended).")
            }
        }
    } catch Error as dpiErr {
        RuntimeLogWarn("recording_dpi_check_failed", "Could not read Roblox window DPI", "error=" dpiErr.Message)
    }

    if (recordingWarnings.Length > 0) {
        warningText := "Your recording environment differs from the recommended baseline:`n`n"
        for recordingWarning in recordingWarnings
            warningText .= recordingWarning "`n"
        warningText .= "`nCoordinates are saved with the Roblox client size and normalized during replay.`nContinue recording?"
        if (MsgBox(warningText, "Recording environment warning", 0x1034) = "No")
            return
    }

    if (IsSet(GuiTitleCtrl) && GuiTitleCtrl) {
        GuiTitleCtrl.SetFont("cff6b6b")
    }

    if (IsSet(Tab2_Btn1) && Tab2_Btn1) {
        Tab2_Btn1.SetFont("c808080 norm")
        Tab2_Btn1.Opt("Background0e0e0f")
        if (IsSet(HoverEffect) && IsObject(HoverEffect)) {
            for index, element in HoverEffect {
                if (element = Tab2_Btn1) {
                    HoverEffect.RemoveAt(index)
                    break
                }
            }
        }
    }

    if (IsSet(Tab2_Btn2) && Tab2_Btn2) {
        Tab2_Btn2.SetFont("cWhite norm")
        if (IsSet(HoverEffect) && IsObject(HoverEffect)) {
            hasElement := false
            for element in HoverEffect {
                if (element = Tab2_Btn2) {
                    hasElement := true
                    break
                }
            }
            if (!hasElement) {
                HoverEffect.Push(Tab2_Btn2)
            }
        }
    }

    gamemap := v.RecMaps
    difficulty := v.RecDifficulty
    requiredTowers := v.RecRequiredTowers
    modifiers := v.RecModifiers
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
    global Tab2_Btn1, Tab2_Btn2, HoverEffect
    global RecordingWidth, RecordingHeight

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
    DeleteAllIndicators()

    if (IsSet(GuiTitleCtrl) && GuiTitleCtrl) {
        GuiTitleCtrl.SetFont("cWhite")
    }

    if (IsSet(Tab2_Btn1) && Tab2_Btn1) {
        Tab2_Btn1.SetFont("cWhite norm")
        if (IsSet(HoverEffect) && IsObject(HoverEffect)) {
            hasElement := false
            for element in HoverEffect {
                if (element = Tab2_Btn1) {
                    hasElement := true
                    break
                }
            }
            if (!hasElement) {
                HoverEffect.Push(Tab2_Btn1)
            }
        }
    }

    if (IsSet(Tab2_Btn2) && Tab2_Btn2) {
        Tab2_Btn2.SetFont("c808080 norm")
        Tab2_Btn2.Opt("Background0e0e0f")
        if (IsSet(HoverEffect) && IsObject(HoverEffect)) {
            for index, element in HoverEffect {
                if (element = Tab2_Btn2) {
                    HoverEffect.RemoveAt(index)
                    break
                }
            }
        }
    }

    if (ModernMsgBox("Save", "Save the recorded strategy?", "YES|NO") = "YES") {
        box := InputBox("File name (without .strat):", "Save", "w300 h130", "MyStrategy")
        if (box.Result = "Cancel")
            return
        filePath := RecordingsDir "\" box.Value ".strat"

        ; Placement coordinates were captured in the client plane established
        ; when recording began. Persist that exact plane even if the user resized
        ; Roblox before pressing Stop; using the save-time size mis-scaled replay.
        strategyWidthToSave := RecordingWidth
        strategyHeightToSave := RecordingHeight
        if getRobloxPos(, , &currentWidth, &currentHeight) && currentWidth > 0 && currentHeight > 0 {
            if (currentWidth != RecordingWidth || currentHeight != RecordingHeight) {
                RuntimeLogWarn("recording_geometry_changed", "Roblox client size changed during recording",
                    "recorded=" RecordingWidth "x" RecordingHeight "; current=" currentWidth "x" currentHeight)
            }
        }

        if (strategyWidthToSave <= 0 || strategyHeightToSave <= 0) {
            RuntimeLogError("recording_geometry_invalid", "Strategy save blocked because no valid Roblox client geometry is available")
            MsgBox(
                "The recording cannot be saved because its Roblox window size could not be determined.`n`nKeep Roblox open and try again.",
                "Recording geometry unavailable",
                0x10
            )
            return
        }

        ; Write beside the destination first. The previous strategy remains
        ; untouched until the complete replacement is ready.
        tempPath := filePath ".tmp"
        try {
            if FileExist(tempPath)
                FileDelete(tempPath)

            FileAppend("[Settings]`nmap=" gamemap "`ndifficulty=" difficulty "`nrequiredTowers=" requiredTowers
                . "`nmodifiers=" Join(modifiers)
                . "`nautoChain=" autoChain "`nautoCaravan=" autoCaravan "`nautoDropTheBeat=" autoDropTheBeat
                . "`nautoSkip=" AutoSkip "`nabilitySpam=" AbilitySpam "`nmoveEnabled=" MoveEnabled "`nmoveDirection=" MoveDirection
                . "`nmoveDuration=" MoveDuration "`n`n[DO NOT EDIT]`nwidth=" strategyWidthToSave "`nheight=" strategyHeightToSave "`n`n[Steps]`n",
                tempPath)
            for i, step in RecordedSteps
                FileAppend(step "`n", tempPath)

            FileMove(tempPath, filePath, 1)
        } catch Error as err {
            try {
                if FileExist(tempPath)
                    FileDelete(tempPath)
            }
            RuntimeLogError("recording_save_failed", "Recorded strategy save failed", "error=" err.Message)
            MsgBox(
                "The strategy could not be saved. Your previous file was left untouched.`n`n" err.Message,
                "Recording save failed",
                0x10
            )
            return
        }

        LogToConsole("Strategy saved: " filePath)
        Strategy1Ctrl.Value := filePath
    } else {
        LogToConsole("Recording cancelled, strategy not saved")
    }
}

PlaceTowerHK(*) {
    global Recording, Towers, RecordedSteps, ActiveRTowerID, CachedMenuUI, isUiPositionSaved, UseNumbersForHotbar

    if (!Recording) {
        pureKey := RegExReplace(PlaceTowerKey, "[\^+!#]")
        SEND_modifiers := RegExMatch(PlaceTowerKey, "^([\^+!#]+)", &match) ? match[1] : ""

        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }

    towersStringBackup := Towers

    MouseGetPos(&mx, &my)
    loop {
        slotBox := InputBox("Enter the tower slot number (1-5):", "Slot (1-5)", "w300 h130", "1")

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

    idBox := InputBox("Enter a specific tower id:", "Tower ID", "w300 h130", suggestedID)
    if (idBox.Result = "Cancel")
        return
    towerID := idBox.Value
    ActivateRoblox()

    LogToConsole("Recording: placing tower " towerID " (slot " slot ") at x:" mx " y:" my "...")

    getRobloxPos(, , &w, &h)

    ActivateRoblox()

    if UseNumbersForHotbar {
        Send("{" slot "}")
    } else if !SelectHotbarSlotByClick(slot) {
        LogToConsole("Recording placement cancelled because hotbar slot " slot " could not be resolved.")
        return
    }

    Sleep(30)

    MouseMove(mx, my, A_DefaultMouseSpeed)
    Sleep((PotatoMode = 1) ? 100 : 40)
    Click()
    Sleep(100)
    SendEvent("{" CancelPlacementKey "}")

    Towers[towerID] := { x: mx, y: my, slot: slot, level: 0, path: 0, pathLevel: 0, target: "First Enemy" }
    UpdateTowerIndicator(towerID)
    LogToConsole("Recorded tower " towerID " (slot " slot ")")

    RecordedSteps.Push("SpawnTower(" mx ", " my ", " slot ", " towerID ")")

    if (towerID = "" || RegExMatch(towerID, "i)(Juggernaut|Hacker|Pursuit|Kingpin)")) {
        ShowTowerPathDialog(towerID)
    }

    ActiveRTowerID := towerID

    openedSuccessfully := false
    loop 10 {
        getRobloxPos(, , &w, &h)
        resV2 := AdvancedImageSearch("Resources\TowerUI\Variant2.png", 0, Round(h / 2), Round(w * 0.3), Round(h * 0.9) -
        Round(h / 2), 0.5, 1.5)

        if (resV2.status == "success" && resV2.score > 0.6) {

            if (!isUiPositionSaved) {
                Sleep(300)

                getRobloxPos(, , &w, &h)
                resV2Final := AdvancedImageSearch("Resources\TowerUI\Variant2.png", 0, Round(h / 2), Round(w * 0.3),
                Round(h * 0.9) - Round(h / 2), 0.5, 1.5)

                if (resV2Final.status == "success") {
                    CachedMenuUI := { x: resV2Final.x, y: resV2Final.y }
                    isUiPositionSaved := true
                    openedSuccessfully := true
                } else {
                    CachedMenuUI := { x: resV2.x, y: resV2.y }
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
            RecordedSteps.Push("UpgradeTower(" closestID ", false, 1, " Towers[closestID].path ", " Towers[closestID].pathLevel ")"
            )
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
    box := InputBox("Enter Track Color (Purple/Red/Green):", "DJ Track", "w300 h130", "Green")
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
        ; Escape the id (it is free text) and accept the multi-argument
        ; UpgradeTower(id, false, n, path, level) form, which the old pattern
        ; missed - leaving orphaned upgrade steps behind after a sell.
        escapedSellID := RegExReplace(closestID, "([\.\^\$\*\+\?\(\)\[\]\{\}\|])", "\$1")
        for i, step in RecordedSteps {
            if (RegExMatch(step, "i)^SpawnTower\s*\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*" escapedSellID "\s*\)$"))
                continue
            if (RegExMatch(step, "i)^UpgradeTower\s*\(\s*" escapedSellID "\s*(?:,.*)?\s*\)$"))
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
        MacroSteps := []
        KeyDownTimes := Map()
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
        SEND_modifiers := RegExMatch(HoloKey, "^([\^+!#]+)", &match) ? match[1] : ""

        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }

    CoordMode("Mouse", "Client")
    ActivateRoblox()
    MouseGetPos(&mx, &my)

    idBox := InputBox("Enter the tower ID to clone:", "Clone Tower", "w300 h130", "")
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
        SEND_modifiers := RegExMatch(HoloKey, "^([\^+!#]+)", &match) ? match[1] : ""

        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }

    CoordMode("Mouse", "Client")
    MouseGetPos(&mx, &my)

    if (ActiveRTowerID = "") {
        idBox := InputBox("Enter the tower ID to reposition:", "Repo Brawler", "w300 h130", "")
        if (idBox.Result = "Cancel")
            return

        towerID := Trim(idBox.Value)
        if (towerID = "") {
            return
        }
        BrawlerReposition(towerID, mx, my)
    } else {
        towerID := ActiveRTowerID

        ; The hotkey was registered under HotIf(IsRecordingActive); toggling it
        ; from the default context targets a variant that does not exist and
        ; throws. Restore the criterion around the toggle, and bound the wait so
        ; a change of mind cannot wedge the recording thread forever.
        HotIf(IsRecordingActive)
        try Hotkey("~LButton", "Off")
        HotIf()

        clicked := KeyWait("LButton", "D T15")

        HotIf(IsRecordingActive)
        try Hotkey("~LButton", "On")
        HotIf()

        if (!clicked) {
            LogToConsole("Reposition cancelled: no click within 15 seconds.")
            return
        }

        MouseGetPos(&mx, &my)

        if (!Towers.Has(towerId)) {
            LogToConsole("Tower " towerId " not found for reposition!")
            return
        }

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
        idBox := InputBox("Enter the tower ID:", "Change Targets", "w300 h100", "")
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

    targetBox := InputBox("Enter the target:", "Change Targets", "w300 h100", "")
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
    loop {
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

        if (FileExist("Resources\Maps\Simplicity.png") && CheckTheMap = 1 && !RegExMatch(modifiers_str, "i)fog") && !
        LegacyMode) {
            getRobloxPos(, , &w, &h)
            FoundMap := false
            loop 5 {
                res := AdvancedImageSearch("Resources\Maps\Simplicity.png", 0, 0, w, h, 0.5, 2)

                if (res.score > 0.65) {
                    FoundMap := true
                    LogToConsole("break " res.score)
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
    global canUseAbility
    canUseAbility := false

    if (LastOpenedTowerID != towerID) {
        Click(Towers[towerID].x, Towers[towerID].y)
        Sleep 250
    } else {
        MouseMove(0, ScaleY(50), , "R")
    }

    LastOpenedTowerID := towerID
    needtocheckTowerUI := true
    attempts := 0
    targets := ["First Enemy", "Last Enemy", "Strongest", "Weakest", "Closest", "Farthest", "Random"]

    LogToConsole("Changing " towerID " targets to " target "...")

    upgTime := A_TickCount
    loop {
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
            if (A_TickCount - startedSearching > 5000) {
                LogToConsole("Failed to change tower targets...", true)
                return false
            }

            getRobloxPos(, , &w, &h)
            left := AdvancedImageSearch("Resources/TowerUI/left.png", 0, 0, w / 2, h / 1.3)

            if left.score > 0.66 {
                right := AdvancedImageSearch("Resources/TowerUI/right.png", left.x + 20, 0, w / 2, h / 1.3)
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

            loop clickCount {
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

        loop {
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

        getRobloxPos(, , &w, &h)
        checkTargetImg := AdvancedImageSearch("Resources/TowerUI/" target ".png", 0, 0, w / 2, h / 1.3)

        if (checkTargetImg.score > 0.66) {
            LogToConsole("Successfully changed tower's target to " target)
            break
        }

        bestScore := 0
        detectedTarget := "First Enemy"

        for index, name in targets {
            imgScan := AdvancedImageSearch("Resources/TowerUI/" name ".png", 0, 0, w / 2, h / 1.3)
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
    global Towers, unfocusX, unfocusY, LastOpenedTowerID, CancelPlacementKey, HologramKey, Recording, canUseAbility

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

        getRobloxPos(, , &w, &h)
        x1 := Round(w * 0.2)
        y1 := Round(h * 0.18)
        x2 := Round(w * 0.7)
        y2 := Round(h * 0.3)

        if (ImageSearch(&fx, &fy, x1, y1, x2, y2, "*Trans000000 *50 " A_WorkingDir "/Resources/hologram_tower_cooldown.png"
        ) || ReadMessage(["hologram", "ability", "is on", "cooldown", "hol%ram%", "ility"])) {
            LogToConsole("Failed to clone " towerId "! (hologram cooldown) Retrying again in 5 seconds...")
            canUseAbility := true
            Sleep 4650
            canUseAbility := false
            continue
        }

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

                ; Distinct names on purpose: this probe used to overwrite x1..y2,
                ; the shared TDS message region computed above, so every later
                ; message ImageSearch scanned a ~30x10px box and never matched.
                cashX1 := cashX - 20
                cashY1 := cashY - 5
                cashX2 := cashX + 10
                cashY2 := cashY + 5

                if PixelSearch(&Fx, &Fy, cashX1, cashY1, cashX2, cashY2, 0x99BFD4, 6) {
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

        if (ImageSearch(&fx, &fy, x1, y1, x2, y2, "*Trans000000 *50 " A_WorkingDir "/Resources/no_cash_cloning.png") ||
        ReadMessage(["don't", "have", "enough", "cash", "clone", "this"])) {
            LogToConsole("Failed to clone " towerId "! (no cash) Retrying again in 5 seconds...")
            canUseAbility := true
            Sleep 4650
            canUseAbility := false
            continue
        }

        openedUI := waitForTowerUI(, , 500)
        if (openedUI) {
            LogToConsole("Failed to clone tower: accidentally opened upgrade ui! Retrying again..")
            Click(ScaleX(unfocusX), ScaleY(unfocusY))
            Sleep(500)
            continue
        }

        MouseMove(x, y)
        Sleep 100
        MouseClick()

        Sleep 50
        SendEvent("{" CancelPlacementKey "}")

        Sleep 350

        MouseMove(ScaleX(unfocusX), ScaleY(unfocusY))

        Sleep 100

        if (ImageSearch(&fx, &fy, x1, y1, x2, y2, "*Trans000000 *50 " A_WorkingDir "/Resources/stunned.png") ||
        ReadMessage(["error", "that", "cannot", "cann", "activated", "while", "stunned"], , ["need", "more", "to"],
        "\$|\d")) {
            LogToConsole("Failed to clone " towerId "! (hacker is stunned) Retrying again in 5 seconds...")
            canUseAbility := true
            Sleep 4650
            canUseAbility := false
            continue
        }

        if (ImageSearch(&fx, &fy, x1, y1, x2, y2, "*Trans000000 *50 " A_WorkingDir "/Resources/cannot_place_here.png") ||
        ReadMessage(["cannot", "here", "hereg", "herd", "her", "here!", "cann", "cannd", "he", "h", "hed"], , ["need",
            "more", "to"], "\$|\d")) {
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
    global canUseAbility

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

        loop {
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

        getRobloxPos(, , &w, &h)
        send "{" RepoKey "}"

        x1 := Round(w * 0.2)
        y1 := Round(h * 0.18)
        x2 := Round(w * 0.7)
        y2 := Round(h * 0.3)

        Sleep 300

        if (ImageSearch(&fx, &fy, x1, y1, x2, y2, "*Trans000000 *50 " A_WorkingDir "/Resources/reposition_cooldown.png"
        ) || ReadMessage(["reposition", "ability", "is on", "cooldown", "ility"])) {
            LogToConsole("Failed to reposition brawler! Retrying again in 4.5 seconds...")
            Sleep 4500
            continue
        }

        placeattempts := 0
        px := x, py := y
        loop {
            placeattempts++

            if (placeattempts > 5) {
                Send("{" CancelPlacementKey "}")
                LogToConsole("Failed to reposition brawler :( ")
                return false
            }

            MouseMove(px, py)
            Sleep 20
            MouseClick

            sleep 400

            if (ImageSearch(&fx, &fy, x1, y1, x2, y2, "*Trans000000 *50 " A_WorkingDir "/Resources/cannot_place_here.png"
            ) || ReadMessage(["cannot", "here", "hereg", "herd", "her", "here!", "cann", "cannd", "he", "h", "hed"], ,
            ["need", "more", "to"], "\$|\d")) {
                LogToConsole("Failed to reposition brawler: cannot place here! Retrying..")
                Sleep 4400
                variation := Random(-3, 3)
                py := y + variation
                continue
            } else {
                break
            }
        }

        if (ImageSearch(&fx, &fy, x1, y1, x2, y2, "*Trans000000 *50 " A_WorkingDir "/Resources/stunned.png") ||
        ReadMessage(["error", "that", "cannot", "cann", "activated", "while", "tower", "tmeer", "stunned"], , ["need",
            "more", "to"], "\$|\d")) {
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

    ; 0x41 is the letter "A" - filtering it silently dropped strafe-left from every
    ; recording. The intended entry was 0x10 (VK_SHIFT).
    if (vk = 0xA0 || vk = 0xA1 || vk = 0xA2 || vk = 0xA3
        || vk = 0xA4 || vk = 0xA5 || vk = 0x5B || vk = 0x5C
        || vk = 0x11 || vk = 0x12 || vk = 0x10)
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

    ; 0x41 is the letter "A" - filtering it silently dropped strafe-left from every
    ; recording. The intended entry was 0x10 (VK_SHIFT).
    if (vk = 0xA0 || vk = 0xA1 || vk = 0xA2 || vk = 0xA3
        || vk = 0xA4 || vk = 0xA5 || vk = 0x5B || vk = 0x5C
        || vk = 0x11 || vk = 0x12 || vk = 0x10)
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

    ; The Send step already consumes holdDuration on replay. `elapsed` here is the
    ; time since key-down, i.e. the same interval, so emitting it again as a Sleep
    ; made every recorded hold replay at roughly double its real length.
    idle := elapsed - holdDuration
    if (idle > 0) {
        MacroSteps.Push("Sleep(" idle ")")
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

    if RegExMatch(lastStep, "i)SpawnTower\s*\(\s*[^,]+\s*,\s*[^,]+\s*,\s*[^,]+\s*,\s*(.*?)\s*\)", &matchPlace) {
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

KnownPathBranchLevel(towerID) {
    if RegExMatch(towerID, "i)^(Juggernaut|Pursuit|Kingpin)\d*$")
        return 4
    if RegExMatch(towerID, "i)^Hacker\d*$")
        return 5
    return 0
}

ResolvePathBranchLevel(towerID, pathLevel := 0) {
    suppliedLevel := 0
    try {
        if IsNumber(pathLevel)
            suppliedLevel := Integer(pathLevel)
    } catch {
        suppliedLevel := 0
    }

    knownLevel := KnownPathBranchLevel(towerID)
    if (knownLevel > 0) {
        if (suppliedLevel <= 0)
            return knownLevel

        ; Compatibility with old recordings, which stored the LAST shared
        ; level (3 for Juggernaut/Pursuit/Kingpin and 4 for Hacker).
        if (suppliedLevel = knownLevel - 1)
            return knownLevel
    }

    ; Never impose known-tower defaults on a custom ID.
    return suppliedLevel
}

IsPathSpecificUpgrade(towerID, nextLevel, path, pathLevel) {
    effectivePathLevel := ResolvePathBranchLevel(towerID, pathLevel)
    return (path != 0 && effectivePathLevel > 0 && nextLevel >= effectivePathLevel)
}

ShowTowerPathDialog(towerID) {
    global Towers, ActivePathSelectTowerID
    if !Towers.Has(towerID)
        return

    ; Allow reopening the dialog so a recorder can correct an earlier choice.
    ActivePathSelectTowerID := towerID
    PathGui := Gui("+AlwaysOnTop +Border", "Path Selection")
    PathGui.SetFont("s12 Bold c000000", UIFont())
    PathGui.Add("Text", "x25 y20 w350", "Tower " towerID)
    PathGui.SetFont("s11 w400 c000000", UIFont())
    PathGui.Add("Text", "x25 y+10 w350", "Choose an upgrade path")
    PathGui.Add("Text", "x25 y+10 w350",
        "Right-click the tower indicator to change this later.`nEnter the FIRST path-specific upgrade level (Juggernaut/Pursuit/Kingpin = 4, Hacker = 5)."
    )
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

SelectPath(pathGui, pathNum) {
    global Towers, ActivePathSelectTowerID
    pathGui.Destroy()
    towerID := ActivePathSelectTowerID
    if (towerID = "" || !Towers.Has(towerID))
        return

    knownBranchLevel := KnownPathBranchLevel(towerID)
    defaultBranchLevel := (knownBranchLevel > 0) ? String(knownBranchLevel) : ""

    box := InputBox("Enter the FIRST path-specific upgrade level:", "Path starts at level", "w340 h140", defaultBranchLevel)
    if (box.Result = "Cancel" || !IsInteger(box.Value) || Integer(box.Value) < 1)
        return

    branchLevel := Integer(box.Value)
    Towers[towerID].path := pathNum
    Towers[towerID].pathLevel := branchLevel
    UpdateTowerIndicator(towerID)
    LogToConsole("Tower " towerID " set to path " pathNum " starting at level " branchLevel)
}

TestWebhook(ctrl, *) {
    global WebhookLink
    v := MainGui.Submit(false)
    if (v.WebhookLink = "") {
        ModernMsgBox("Error", "Enter a webhook URL first!", "OK", "WARNING")
        return
    }
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", v.WebhookLink, false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.SetTimeouts(0, 3000, 3000, 3000)
        whr.Send('{"content": "✅ Webhook test successful! Ultimate Macro TDS is connected."}')
        if (whr.Status = 200 || whr.Status = 204)
            ModernMsgBox("Success", "Webhook test successful!", "OK")
        else
            ModernMsgBox("Error", "Webhook test failed! Status: " whr.Status, "OK", "WARNING")
    } catch {
        ModernMsgBox("Error", "Failed to send test message. Check your connection and webhook URL.", "OK", "WARNING")
    }
}

TestBot(ctrl, *) {
    global BotToken, ChannelID
    v := MainGui.Submit(false)

    if (v.BotToken = "") {
        ModernMsgBox("Error", "Enter a bot token first!", "OK", "WARNING")
        return
    }

    if (v.ChannelID = "") {
        ModernMsgBox("Error", "Enter a channel ID first!", "OK", "WARNING")
        return
    }

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Option[9] := 2720
        whr.Open("POST", "https://discord.com/api/v10/channels/" v.ChannelID "/messages", false)
        whr.SetRequestHeader("User-Agent", "DiscordBot (AHK, " A_AhkVersion ")")
        whr.SetRequestHeader("Authorization", "Bot " v.BotToken)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.SetTimeouts(0, 3000, 3000, 3000)
        whr.Send('{"content": "✅ Bot test successful! Ultimate Macro TDS is connected."}')

        if (whr.Status = 200 || whr.Status = 201 || whr.Status = 204) {
            ModernMsgBox("Success", "Bot test successful! Message sent to channel.", "OK")
        } else {
            errorMsg := "Bot test failed! Status: " whr.Status

            try {
                response := JSON.parse(whr.ResponseText)
                if response.Has("message")
                    errorMsg .= "`n`nDiscord Error: " response["message"]
            }

            switch whr.Status {
                case 401:
                    errorMsg .= "`n`nInvalid bot token!"
                case 403:
                    errorMsg .= "`n`nBot lacks permission to send messages in this channel!"
                case 404:
                    errorMsg .= "`n`nChannel not found! Check Channel ID."
                case 429:
                    errorMsg .= "`n`nRate limited! Try again later."
            }

            ModernMsgBox("Error", errorMsg, "OK", "WARNING")
        }
    } catch as err {
        ModernMsgBox("Error", "Failed to send test message. Check your connection and settings.`n`n" err.Message, "OK",
            "WARNING")
    }
}

SaveWebhookSettings(ctrl, *) {
    global WebhookLink, WebhookLink2, WebhookEnabled, SendCurrenciesEnabled, WebhookDebugLogs, WebhookScreenshots,
        WebhookTriumphScreenshots, WebhookSepatateTriumphScreenshots, UserID, ChannelID, BotEnabled, BotToken
    v := MainGui.Submit(0)
    WebhookLink := v.WebhookLink
    WebhookLink2 := v.WebhookLink2
    WebhookEnabled := v.WebhookEnabled
    SendCurrenciesEnabled := v.SendCurrenciesEnabled
    WebhookDebugLogs := v.WebhookDebugLogs
    WebhookScreenshots := v.WebhookScreenshots
    WebhookTriumphScreenshots := v.WebhookTriumphScreenshots
    WebhookSepatateTriumphScreenshots := v.WebhookSepatateTriumphScreenshots
    BotToken := v.BotToken
    BotEnabled := v.BotEnabled
    ChannelID := v.ChannelID
    UserID := v.WebhookUserID2
    IniWrite(BotToken, BotSettings, "Token", "BotToken")
    IniWrite(BotEnabled, BotSettings, "Settings", "Enabled")
    IniWrite(ChannelID, BotSettings, "Settings", "Channel")
    IniWrite(UserID, BotSettings, "Settings", "UserID")
    IniWrite(WebhookLink, SettingsFile, "Webhook", "Link")
    IniWrite(WebhookLink2, SettingsFile, "Webhook", "Link2")
    IniWrite(WebhookUserID, SettingsFile, "Webhook", "WebhookUserID")
    IniWrite(WebhookEnabled, SettingsFile, "Webhook", "Enabled")
    IniWrite(SendCurrenciesEnabled, SettingsFile, "Webhook", "SendCurrencies")
    IniWrite(WebhookDebugLogs, SettingsFile, "Webhook", "WebhookDebugLogs")
    IniWrite(WebhookScreenshots, SettingsFile, "Webhook", "WebhookScreenshots")
    IniWrite(WebhookTriumphScreenshots, SettingsFile, "Webhook", "WebhookTriumphScreenshots")
    IniWrite(WebhookSepatateTriumphScreenshots, SettingsFile, "Webhook", "WebhookSepatateTriumphScreenshots")

    if (BotEnabled && ChannelID != "" && UserID != "") {
        SetTimer(ProcessCommands, 7500, 1)
    } else {
        SetTimer(ProcessCommands, 0)
    }

    MsgBox("All discord settings have been successfully saved!", "Ultimate Macro", 0x1040)
}

NormalizeKey(keyName) {
    if (keyName = "")
        return ""

    if !RegExMatch(keyName, "^([~!#^+<>*]*)(.*)$", &Match)
        return keyName

    modifiers := Match[1]
    pureKey := Match[2]

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

SaveAllSettings(ctrl, *) {
    global ChainKey, BeatKey, CaravanKey, CancelPlacementKey, TimeScaleMode, UseTimeScale
    global TimeScaleMultiplier, VipLink, UseVipServer, AlwaysOnTop, LegacyMode, DebugConsole
    global PotatoMode, UseRestartBtn, UsePlayAgainBtn, CheckTheMap
    global PlaceTowerKey, UpgradeTowerKey, AlignCameraKey, ChangeDJTrackKey
    global SellTowerKey, DeleteTowerRecordingKey, RecordInputsKey
    global SettingsFile
    global DefaultMouseSpeed, MouseDelay, KeyDelay
    global HoloKey, RaiseDeadKey, ChangeTargetsKey, HologramKey, RepoKey, CollectPlaytimeRewards, UpgradeTowerGKey,
        UpgradeTowerGBKey, UseHForUpgrade, UseNumbersForHotbar
    global UpgradeDelay

    tempChainKey := SubStr(RegExReplace(ChainKeyCtrl.Value, "\s", ""), 1, 1)
    tempBeatKey := SubStr(RegExReplace(BeatKeyCtrl.Value, "\s", ""), 1, 1)
    tempCaravanKey := SubStr(RegExReplace(CaravanKeyCtrl.Value, "\s", ""), 1, 1)
    tempCancelPlacementKey := SubStr(RegExReplace(CancelPlacementKeyCtrl.Value, "\s", ""), 1, 1)
    tempUpgradeTowerGKey := SubStr(RegExReplace(UpgradeTowerGCtrl.Value, "\s", ""), 1, 1)
    tempUpgradeTowerGBKey := SubStr(RegExReplace(UpgradeTowerGBCtrl.Value, "\s", ""), 1, 1)

    if (tempChainKey = "")
        tempChainKey := "C"
    if (tempBeatKey = "")
        tempBeatKey := "B"
    if (tempCaravanKey = "")
        tempCaravanKey := "J"
    if (tempCancelPlacementKey = "")
        tempCancelPlacementKey := "Q"
    if (tempUpgradeTowerGKey = "")
        tempUpgradeTowerGKey := "E"
    if (tempUpgradeTowerGBKey = "")
        tempUpgradeTowerGBKey := "Z"

    tempPlaceTowerKey := NormalizeKey(PlaceTowerKeyCtrl.Value)
    tempUpgradeTowerKey := NormalizeKey(UpgradeTowerKeyCtrl.Value)
    tempAlignCameraKey := NormalizeKey(AlignCameraKeyCtrl.Value)
    tempChangeDJTrackKey := NormalizeKey(ChangeDJTrackKeyCtrl.Value)
    tempSellTowerKey := NormalizeKey(SellTowerKeyCtrl.Value)
    tempDeleteTowerRecordingKey := NormalizeKey(DeleteTowerRecordingKeyCtrl.Value)
    tempRecordInputsKey := NormalizeKey(RecordInputsKeyCtrl.Value)
    tempHoloKey := NormalizeKey(HoloKeyCtrl.Value)
    tempChangeTargetsKey := NormalizeKey(ChangeTargetsCTRL.Value)

    UsedKeys := Map()

    KeysToCheck := [{ val: NormalizeKey(tempChainKey), name: "Call of Arms Ability" }, { val: NormalizeKey(tempBeatKey),
        name: "Drop the Beat Ability" }, { val: NormalizeKey(tempCaravanKey), name: "Support Caravan Ability" }, { val: NormalizeKey(
            tempCancelPlacementKey), name: "Cancel Placement" }, { val: NormalizeKey(tempUpgradeTowerGKey), name: "Upgrade Tower (TDS keybind)" }, { val: NormalizeKey(
                tempUpgradeTowerGBKey), name: "Upgrade Bottom Path (TDS keybind)" }, { val: tempPlaceTowerKey, name: "Place Tower" }, { val: tempUpgradeTowerKey,
                    name: "Upgrade Tower" }, { val: tempAlignCameraKey, name: "Align Camera" }, { val: tempChangeDJTrackKey,
                        name: "Change DJ Track" }, { val: tempSellTowerKey, name: "Sell Tower" }, { val: tempDeleteTowerRecordingKey,
                            name: "Delete Tower Recording" }, { val: tempRecordInputsKey, name: "Record Inputs" }, { val: tempHoloKey,
                                name: "Hologram Tower" }, { val: tempChangeTargetsKey, name: "Change Targets" }
    ]

    for item in KeysToCheck {
        if (item.val = "") {
            MsgBox("Error: Empty hotkey detected!`n`n"
                . "The hotkey is assigned to: `"" item.name "`"`n"
                . "Please change it before saving.", "Empty Hotkey", 0x10)
            return
        }
        if UsedKeys.Has(item.val) {
            MsgBox("Error: Duplicate hotkey detected!`n`n"
                . "The hotkey is assigned to: `"" UsedKeys[item.val] "`"`n"
                . "And also that hotkey is assigned to: `"" item.name "`"`n`n"
                . "Please change it before saving.", "Duplicate Hotkey", 0x10)
            return
        }
        UsedKeys[item.val] := item.name
    }

    ChainKey := tempChainKey
    BeatKey := tempBeatKey
    CaravanKey := tempCaravanKey
    CancelPlacementKey := tempCancelPlacementKey
    UpgradeTowerGKey := tempUpgradeTowerGKey
    UpgradeTowerGBKey := tempUpgradeTowerGBKey

    oldRecordingKeys := [PlaceTowerKey, UpgradeTowerKey, AlignCameraKey, ChangeDJTrackKey,
        SellTowerKey, DeleteTowerRecordingKey, RecordInputsKey, HoloKey, ChangeTargetsKey]

    PlaceTowerKey := tempPlaceTowerKey
    UpgradeTowerKey := tempUpgradeTowerKey
    AlignCameraKey := tempAlignCameraKey
    ChangeDJTrackKey := tempChangeDJTrackKey
    SellTowerKey := tempSellTowerKey
    DeleteTowerRecordingKey := tempDeleteTowerRecordingKey
    RecordInputsKey := tempRecordInputsKey
    HoloKey := tempHoloKey
    ChangeTargetsKey := tempChangeTargetsKey
    RaiseDeadKey := RaiseDeadKeyCtrl.Value
    HologramKey := HologramKeyCtrl.Value
    RepoKey := RepoKeyCtrl.Value

    RegisterRecordingHotkeys(oldRecordingKeys)

    TimeScaleMode := (TimeScaleModeCtrl.Text = "") ? "OFF" : TimeScaleModeCtrl.Text
    VipLink := VipLinkCtrl.Value
    UseVipServer := UseVipServerCtrl.Value
    AlwaysOnTop := AlwaysOnTopCtrl.Value
    DebugConsole := DebugConsoleCtrl.Value
    PotatoMode := PotatoModeCtrl.Value
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

    IniWrite(ChainKey, SettingsFile, "Hotkeys", "Chain")
    IniWrite(BeatKey, SettingsFile, "Hotkeys", "Beat")
    IniWrite(CaravanKey, SettingsFile, "Hotkeys", "Caravan")
    IniWrite(CancelPlacementKey, SettingsFile, "Hotkeys", "CancelPlacement")
    IniWrite(UpgradeTowerGKey, SettingsFile, "Hotkeys", "UpgradeTower")
    IniWrite(UpgradeTowerGBKey, SettingsFile, "Hotkeys", "UpgradeBottom")
    IniWrite(RaiseDeadKey, SettingsFile, "Hotkeys", "RaiseTheDead")
    IniWrite(HologramKey, SettingsFile, "Hotkeys", "Hologram")
    IniWrite(RepoKey, SettingsFile, "Hotkeys", "Repo")
    IniWrite(TimeScaleMode, SettingsFile, "Options", "TimeScaleMode")
    IniWrite(VipLink, SettingsFile, "Options", "VipLink")
    IniWrite(UseVipServer, SettingsFile, "Options", "UseVipServer")
    IniWrite(DebugConsole, SettingsFile, "Options", "DebugConsole")
    IniWrite(PotatoMode, SettingsFile, "Options", "PotatoMode")
    IniWrite(AlwaysOnTop, SettingsFile, "Options", "AlwaysOnTop")
    IniWrite(LegacyModeCtrl.Value, SettingsFile, "Options", "LegacyMode")
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

    IniWrite(PlaceTowerKey, SettingsFile, "RecordingHotkeys", "PlaceTowerKey")
    IniWrite(UpgradeTowerKey, SettingsFile, "RecordingHotkeys", "UpgradeTowerKey")
    IniWrite(AlignCameraKey, SettingsFile, "RecordingHotkeys", "AlignCameraKey")
    IniWrite(ChangeDJTrackKey, SettingsFile, "RecordingHotkeys", "ChangeDJTrackKey")
    IniWrite(SellTowerKey, SettingsFile, "RecordingHotkeys", "SellTowerKey")
    IniWrite(DeleteTowerRecordingKey, SettingsFile, "RecordingHotkeys", "DeleteTowerRecordingKey")
    IniWrite(RecordInputsKey, SettingsFile, "RecordingHotkeys", "RecordInputsKey")
    IniWrite(ChangeTargetsKey, SettingsFile, "RecordingHotkeys", "ChangeTargetsKey")
    IniWrite(HoloKey, SettingsFile, "RecordingHotkeys", "HoloKey")

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

    if (DebugConsole = "1" || DebugConsole = 1) {
        ShowDebugConsole()
    } else {
        HideDebugConsole()
    }

    if (AlwaysOnTop = 1) {
        MainGui.Opt("+AlwaysOnTop")
    } else {
        MainGui.Opt("-AlwaysOnTop")
    }

    if (LegacyModeCtrl.Value = 1 && LegacyMode = 0) {
        if A_ScreenHeight != 1080 && A_ScreenWidth != 1920 {
            MsgBox("WARNING! Legacy mode works only for 1920x1080!", "Warning", 0x1030)
        }
        Reload
    }
    if (LegacyModeCtrl.Value = 0 && LegacyMode = 1) {
        Reload
    }

    LegacyMode := LegacyModeCtrl.Value

    SetDefaultMouseSpeed(DefaultMouseSpeed)
    SetMouseDelay(MouseDelay)
    SetKeyDelay(KeyDelay)

    MsgBox("All settings have been successfully saved!", "Ultimate Macro", 0x1040)
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

    MsgBox("Multiplayer settings saved!", "Success", 0x1040)
}

LegacyModeInfo(*) {
    if LegacyModeCtrl.Value = 1 {
        MsgBox(
            "Changes how the image detection works. May not work for some people.`n`nWarning: some features - such as Auto Equip, Changing Tower Targeting will not work with this mode!",
            "Legacy Mode", "0x1040")
    }
}

ClearStoredLogs(ctrl, *) {
    logDir := RuntimeLogDirectory()

    if (logDir = "" || !DirExist(logDir)) {
        MsgBox("There are no stored logs yet.", "Clear Logs", "0x1040")
        return
    }

    storedBytes := RuntimeLogStoredBytes()
    if (storedBytes = 0) {
        MsgBox("There are no stored logs to clear.", "Clear Logs", "0x1040")
        return
    }

    prompt := "Delete every stored log in:`n" logDir
    prompt .= "`n`nCurrently stored: " FormatLogSize(storedBytes)
    prompt .= "`n`nThis removes the persistent log, past session logs, and the last crash report."
    prompt .= " It cannot be undone."

    if (MsgBox(prompt, "Clear Logs", "0x1024") != "Yes")
        return

    removed := RuntimeLogClear()
    MsgBox("Cleared " removed " log file" (removed = 1 ? "" : "s") ".", "Clear Logs", "0x1040")
}

FormatLogSize(bytes) {
    if (bytes >= 1048576)
        return Format("{:.1f} MB", bytes / 1048576)
    if (bytes >= 1024)
        return Format("{:.1f} KB", bytes / 1024)
    return bytes " bytes"
}

CheckVipLink(ctrl, *) {

    str := Trim(VipLinkCtrl.Value)

    if (RegExMatch(str,
        "i)roblox\.com\/(?:[a-z]{2}\/)?games\/3260590327\/[^\/]*\?privateServerLinkCode=(?<code>[a-z0-9]{32})", &m)) {
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
        WebhookEnabledCtrl.Value := 0
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

EnableWebhookLink2(*) {
    v := MainGui.Submit(false)
    toggle := v.WebhookSepatateTriumphScreenshots
    if toggle = 1 {
        WebhookLinkCtrl2.Visible := true
    } else {
        WebhookLinkCtrl2.Visible := false
    }
}

DiscordSettings(*) {
    if tab4_Title.Text = "Discord Webhook" {
        tab4_Title.Text := "Discord Bot"
        HideAllTabContent()
        ShowDiscordSettings()
    } else {
        tab4_Title.Text := "Discord Webhook"
        HideAllTabContent()
        ShowDiscordSettings()
    }
}

ShowDiscordSettings(*) {
    if tab4_Title.Text = "Discord Webhook" {
        HideAllTabContent()
        for ctrl in DiscordWebhookTab
            ctrl.Visible := true
    } else {
        HideAllTabContent()
        for ctrl in DiscordBotTab
            ctrl.Visible := true
    }
}

CheckWebhookLink2(ctrl, *) {
    v := MainGui.Submit(false)
    link := v.WebhookLink2
    if (link = "" || (!InStr(link, "discord.com/api/webhooks/") && !InStr(link, "discordapp.com/api/webhooks/"))) {
        WebhookSepatateTriumphScreenshotsCtrl.Value := 0
        return
    }
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", link, false)
        whr.Send()
        WebhookSepatateTriumphScreenshotsCtrl.Enabled := (whr.Status = 200)
        if (whr.Status != 200)
            WebhookSepatateTriumphScreenshotsCtrl.Value := 0
    } catch {
        WebhookSepatateTriumphScreenshotsCtrl.Value := 0
    }
}

ShowFAQ(*) {
    ModernMsgBox("FAQ",
        "[SCREEN AND SYSTEM SETTINGS]`n" .
        "- Screen Resolution: 1920x1080 is recommended; client coordinates are saved and normalized for replay.`n" .
        "- Windows Scale: 100% is recommended for best image accuracy.`n" .
        "- Taskbar: Must be visible.`n`n" .
        "[ROBLOX AND GAME SETTINGS]`n" .
        "- UI Scale: Set to Large.`n" .
        "- Screen Shake: Must be DISABLED.`n" .
        "- Roblox Chat: Close the chat before starting the macro.`n" .
        "- Set 'Prefer Vertical Upgrades' to Enabled.`n" .
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
    ModernMsgBox("Timescale Info",
        "1.5x — more stable and recommended for most cases.`n2x — requires special strategies but is much more effective.`n`nThis will automatically turn off if you run out of timescale tickets.",
        "OK")
}
HelpPotatoMode(*) {
    ModernMsgBox("Info", "Turn this on if your macro acts inconsistently or if you have lags.", "OK")
}
HelpSendCurrencies(*) {
    ModernMsgBox("Info",
        "If you enable the 'Send currencies' toggle, the macro will send you information about your coins, gems, total matches, triumphs, and losses.`n`nMay be buggy.",
        "OK")
}
HelpRestartBtn(*) {
    ModernMsgBox("Info",
        "If this setting is ON, the macro will use the restart button when you lose.`n`nIt's recommended to turn it OFF if you are using a win strategy and your macro sometimes appears on the wrong map.",
        "OK")
}
HelpPlayAgainBtn(*) {
    ModernMsgBox("Info", "If this setting is ON, the macro will use the play again button when you win.", "OK")
}
HelpAutoCameraCorrection(*) {
    ModernMsgBox("Info", "The macro will use tds keybind when upgrading the tower.`n`nIt's recommended to turn it ON.",
        "OK")
}
HelpBrawler(*) {
    ModernMsgBox("Info", "To record brawler reposition, press CTRL+your keybind", "OK")
}
HelpRaise(*) {
    ModernMsgBox("Info", "To record raise the dead, press CTRL+your keybind", "OK")
}
HelpCheckTheMap(*) {
    ModernMsgBox("Info",
        "When you join the map, the macro will check is it in the correct map or not. If no, it reloads.`n`nIt's recommended to turn it ON.",
        "OK")
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
    requiredTowers := IniRead(file, "Settings", "requiredTowers", "")
    autoChain := IniRead(file, "Settings", "autoChain", "OFF")
    autoCaravan := IniRead(file, "Settings", "autoCaravan", "OFF")
    autoDropTheBeat := IniRead(file, "Settings", "autoDropTheBeat", "OFF")
    AutoSkip := IniRead(file, "Settings", "autoSkip", "ON")
    AbilitySpam := IniRead(file, "Settings", "abilitySpam", "ON")
    modifiers := IniRead(file, "Settings", "modifiers", "")

    moveDown := IniRead(file, "Settings", "moveDown", "false")
    tempEnabled := IniRead(file, "Settings", "moveEnabled", "")
    tempDir := IniRead(file, "Settings", "moveDirection", "")
    tempDur := IniRead(file, "Settings", "moveDuration", "")

    if (tempEnabled != "") {
        MoveEnabled := (tempEnabled = "true" || tempEnabled = "1") ? true : false
        MoveDirection := (tempDir != "" && (tempDir = "W" || tempDir = "A" || tempDir = "S" || tempDir = "D")) ?
            tempDir : "W"
        MoveDuration := IsNumber(tempDur) ? Integer(tempDur) : 750
    } else {
        if (moveDown = "true") {
            MoveEnabled := true, MoveDirection := "S", MoveDuration := 750
        } else {
            MoveEnabled := false, MoveDirection := "W", MoveDuration := 750
        }
    }

    Commander := false

    StrategyWidth := Integer(IniRead(file, "DO NOT EDIT", "width", "1920"))
    StrategyHeight := Integer(IniRead(file, "DO NOT EDIT", "height", "1080"))

    inSteps := false
    loop read, file {
        line := Trim(A_LoopReadLine)
        if (line ~= "i)^\[Settings\]") {
            inSteps := false
        }
        if (line ~= "i)^\[Steps\]") {
            inSteps := true
            ; Skip the header itself; it used to be stored as step #1.
            continue
        }
        if (inSteps && line != "" && !(line ~= "^\[")) {
            RecordedSteps.Push(line)
        }
    }

    for i, step in RecordedSteps {
        if RegExMatch(step, "i)SpawnTower\s*\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*(.*?)\s*\)", &m) {
            towerID := Trim(m[1])
            Towers[towerID] := { x: 0, y: 0, slot: 0, level: 0, path: 0, pathLevel: 0 }
        }
        if RegExMatch(step,
            "i)UpgradeTower\s*\(\s*([^,]+?)\s*(?:,\s*(?:false|true)\s*)?(?:,\s*\d+\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?\s*\)", &
            m) {
            tid := Trim(m[1])
            if (Towers.Has(tid) && m[2] != "") {
                Towers[tid].path := m[2]
                Towers[tid].pathLevel := ResolvePathBranchLevel(tid, (m[3] != "") ? m[3] : 0)
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

    if (!skiprestart)
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
    MacroPhase("startup", 240000)

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
        SendToWebhookInstant(startInfo, , flush := false)
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
            CloseRoblox()
            RunRoblox()
            if (AutoEquip) {
                EquipTowers(RequiredTowers)
            }
            JoinGame()
        }
    } else {
        CloseRoblox()
        RunRoblox()
        EquipTowers(RequiredTowers)

        JoinGame()
    }

    if (readyX = 0 && readyY = 0) {
        waitReady()
    }

    if (!IsRestarting) {
        CheckTheMapF()
        if (!InArray(SpecialMaps, gamemap) && ResolveArcadeTarget() = "") {
            AlignCamera()
        }
    }

    activateTimescale()

    if (!IsRestarting && ResolveArcadeTarget() != "") {
        ; Arcade/Trial worlds should use the same deterministic camera baseline
        ; before gameplay begins. Align while the Ready screen is still active,
        ; then press Ready only after the camera operation has completed.
        RuntimeLogInfo("arcade_camera_pre_ready", "Aligning Arcade camera before Ready", "target=" ResolveArcadeTarget())
        AlignCamera()
    }

    ClickReady()

    PlayStrategy()
}

PlayStrategy() {
    global canUseAbility, MultiplayerEnabled, StateFile

    MacroPhase("playing", 900000)
    IniWrite(A_TickCount, StateFile, "State", "TimeWhenStartedPlaying")
    SetTimer(UseAbilities, 750)
    if (MultiplayerEnabled) {
        SetTimer(checkCondition, 15000)
    }

    i := 1
    while (i <= RecordedSteps.Length) {
        step := RecordedSteps[i]
        MacroPhase("playing_step", 900000)
        isMacroStep := RegExMatch(step, "i)^(Click|Send|Sleep)\s*\(")

        if RegExMatch(step,
            "i)UpgradeTower\s*\(\s*([^,]+?)\s*(?:,\s*(false|true)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?\s*\)", &
            m) {
            currentID := Trim(m[1])
            ; Tower IDs come from a free-text prompt. Unescaped, an id containing
            ; regex metacharacters ( ) . + * threw and aborted the whole strategy.
            escapedID := RegExReplace(currentID, "([\.\^\$\*\+\?\(\)\[\]\{\}\|])", "\$1")
            countUpgrades := (m[3] != "") ? Integer(m[3]) : 1
            currentPath := (m[4] != "") ? Integer(m[4]) : 0
            currentpathLevel := ResolvePathBranchLevel(currentID, (m[5] != "") ? Integer(m[5]) : 0)

            lookAhead := i + 1
            while (lookAhead <= RecordedSteps.Length) {
                nextStep := RecordedSteps[lookAhead]
                if RegExMatch(nextStep, "i)UpgradeTower\s*\(\s*" escapedID "\s*(?:,\s*(?:false|true)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?\s*\)", &
                    mN) {
                    nextPath := (mN[2] != "") ? Integer(mN[2]) : 0
                    nextPathLevel := ResolvePathBranchLevel(currentID, (mN[3] != "") ? Integer(mN[3]) : 0)
                    if (nextPath != currentPath || (nextPath != 0 && nextPathLevel != currentpathLevel))
                        break
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
    MacroPhase("waiting_result", 7200000)
    loop {
        canUseAbility := true
        LastOpenedTowerID := ""
        Sleep 3000
    }
    ;If the macro doesn't replaying again after win/loss it's a watchdog.ahk issue. Please report it if this happened to you.
    ;Do not add anything here.
}

ExecuteStep(step) {
    global Commander, unfocusX, unfocusY, StrategyWidth, StrategyHeight
    step := RegExReplace(step, "\s*;.*$", "")
    step := Trim(step)
    if (step = "")
        return
    if RegExMatch(step, "i)SpawnTower\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d)\s*,\s*(.*?)\s*\)", &m) {
        SpawnTower(m[1], m[2], m[3], Trim(m[4]))
        return
    }
    if RegExMatch(step,
        "i)UpgradeTower\s*\(\s*([^,]+?)\s*(?:,\s*(false|true)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?\s*\)", &
        m) {
        UpgradeTower(Trim(m[1]), (m[2] = "true"), (m[3] != "") ? Integer(m[3]) : 1, (m[4] != "") ? Integer(m[4]) : 0, (
            m[5] != "") ? Integer(m[5]) : 0)
        return
    }

    if RegExMatch(step, "i)CloneTower\s*\(\s*([^,]+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)", &m) {
        CloneTower(Trim(m[1]), sX(Integer(m[2]), StrategyWidth), sY(Integer(m[3]), StrategyHeight), Integer(m[4]))
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
        CloneTower(Trim(m[1]), sX(Integer(m[2]), StrategyWidth), sY(Integer(m[3]), StrategyHeight), 0)
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
        BrawlerReposition(Trim(m[1]), sX(Integer(m[2]), StrategyWidth), sY(Integer(m[3]), StrategyHeight))
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
        Click(sX(m[1], StrategyWidth) " " sY(m[2], StrategyHeight) " " button)
        return
    }
    if RegExMatch(step, 'i)^Send\s*\(\s*"([^"]+)"\s*,\s*hold:=(\d+)\s*\)$', &m) {
        SendEvent("{" m[1] " down}")
        HyperSleep(Integer(m[2]))
        SendEvent("{" m[1] " up}")
        return
    }
    if RegExMatch(step, "i)^Sleep\s*\(\s*(\d+)\s*\)$", &m) {
        strategySleepMs := Integer(m[1])
        ; A recorded wait is intentional progress, not a frozen macro. Give the
        ; watchdog a budget derived from the step itself, then restore the normal
        ; per-step stall budget after the wait finishes.
        MacroPhase("strategy_sleep", Max(300000, strategySleepMs + 120000))
        Sleep(strategySleepMs)
        MacroPhase("playing_step", 900000)
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
    loop 10 {
        SendEvent("{SC044}")
        Sleep(20)
    }
    SendEvent("{SC02A up}")
}

EquipTowers(towers) {
    MacroPhase("equipping_towers", 300000)
    if !getRobloxPos(, , &rw, &rh) {
        RuntimeLogWarn("autoequip_geometry_missing", "Auto Equip could not resolve Roblox client geometry")
        SafeReload()
        return false
    }

    savedCloseX := 0
    savedCloseY := 0

    closeChat()
    Sleep(600)

    StartTime := A_TickCount
    loop {
        W := Round(rw * 0.3)
        H := rh - 0

        resItems := AdvancedImageSearch("Resources\items.png", 0, 0, W, H)
        if (resItems.status == "success" && resItems.score > 0.56) {
            fx := resItems.x
            fy := resItems.y
            MouseMove(fx, fy + ScaleY(7), A_DefaultMouseSpeed + 1)
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
    loop {
        X1 := Round(rw * 0.2)
        Y1 := 0
        W := Round(rw * 1) - X1
        H := Round(rh * 0.4) - Y1
        resclose := AdvancedImageSearch("Resources\close_items.png", X1, Y1, W, H)

        if (resclose.status = "success" && resclose.score >= 0.85) {
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

        loop {
            resItems := AdvancedImageSearch("Resources\items.png", 0, 0, W, H)
            if (resItems.status == "success" && resItems.score > 0.56) {
                fx := resItems.x
                fy := resItems.y
                MouseMove(fx, fy + ScaleY(7), A_DefaultMouseSpeed + 1)
                Sleep(100)
                MouseClick()
                break
            }

            if (A_TickCount - StartTime > 5000)
                break
            Sleep(300)
        }

        openedMenu := false
        StartTime := A_TickCount
        loop {
            X1 := Round(rw * 0.2)
            Y1 := 0
            W := Round(rw * 1) - X1
            H := Round(rh * 0.4) - Y1
            resclose := AdvancedImageSearch("Resources\close_items.png", X1, Y1, W, H)

            if (resclose.status = "success" && resclose.score >= 0.85) {
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
    loop {
        resBar := AdvancedImageSearch("Resources\searchbar_items.png", 0, 0, Round(rw * 0.5), Round(rh * 0.5))
        if (resBar.status == "success" && resBar.score > 0.67) {
            srchX := resBar.x + 30
            srchY := resBar.y
            break
        }
        if (A_TickCount - StartTime > 4000)
            break
        Sleep(400)
    }

    if (resBar.status != "success" || resBar.score <= 0.67) {
        RuntimeLogWarn("autoequip_searchbar_fallback", "Auto Equip search bar template was not found; using scaled fallback",
            "width=" rw "; height=" rh "; x=" srchX "; y=" srchY)
    }

    Click(srchX, srchY)
    Sleep(150)

    SendText("Sniper")
    Sleep(400)
    Click(srchX + 10, ScaleY(409))
    Sleep(500)

    X := Round(rw * 0.61)
    Y := ScaleY(830)
    X1 := Round(rw * 0.4)
    Y1 := Round(rh * 0.4)
    W := Round(rw * 0.9) - X1
    H := rh - Y1

    StartTime := A_TickCount
    loop {
        getRobloxPos(, , &w, &h)
        baseScale := GetClientTemplateScale(h)

        resAlign := AdvancedImageSearch("Resources\equip.png", X1, Y1, W, H, 0.5 * baseScale, 2, 0.025)

        if (resAlign.status == "success" && resAlign.score > 0.4) {
            Y := resAlign.y + ScaleY(110)
        }

        offset := -30
        baseY := Y

        MouseMove(X, Y + ScaleY(offset))

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
        loop {
            X1 := Round(rw * 0.4)
            Y1 := Round(rh * 0.5)
            W := Round(rw * 0.9) - X1
            H := rh - Y1

            getRobloxPos(, , &w, &h)
            baseScale := GetClientTemplateScale(h)

            resUnequip := AdvancedImageSearch("Resources\unequip.png", X1, Y1, W, H, 0.3 * baseScale, 1.4, 0.025)
            if (resUnequip.status == "success" && resUnequip.score > 0.63) {
                if (PixelSearch(&uX, &uY, resUnequip.x - ScaleX(40), resUnequip.y - ScaleY(25), resUnequip.x + ScaleX(
                    40), resUnequip.y + ScaleY(25), 0x7A797A, 5)) {
                    Click(resUnequip.x, resUnequip.y)
                    MouseMove(resUnequip.x, resUnequip.y - ScaleY(80))
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

    loop parse, towers, "," {
        ActivateRoblox()
        tower := Trim(A_LoopField)
        if (tower = "")
            continue

        if !getRobloxPos(, , &rw, &rh) {
            RuntimeLogWarn("autoequip_geometry_lost", "Roblox client geometry disappeared while equipping",
                "tower=" tower)
            SafeReload()
            return false
        }

        goldtower := RegExMatch(tower, "i)\b(Golden|G\.|G)\b") ? true : false
        regulartower := RegExMatch(tower, "i)\b(Regular|R\.|R)\b") ? true : false

        towerToEnter := RegExReplace(tower, "i)\b(Golden|G\.|G|Regular|R\.|R)\b\s*|\.")
        towerToEnter := Trim(towerToEnter)

        Click(srchX, srchY)
        Sleep(150)

        Send("^a")
        Send("{Backspace}")
        SendText(towerToEnter)
        Sleep(500)
        Click(srchX + 10, ScaleY(409))
        Sleep(500)

        X1 := Round(rw * 0.4)
        Y1 := Round(rh * 0.5)
        W := Round(rw * 0.9) - X1
        H := rh - Y1

        TowerStart := A_TickCount
        towerEquipped := false
        loop {
            baseScale := GetClientTemplateScale(rh)

            resEquip := AdvancedImageSearch("Resources\equip.png", X1, Y1, W, H, 0.5 * baseScale, 1.4, 0.025)

            if (resEquip.status == "success" && resEquip.score > 0.4) {
                if (PixelSearch(&eX, &eY, resEquip.x - ScaleX(40), resEquip.y - ScaleY(25),
                    resEquip.x + ScaleX(40), resEquip.y + ScaleY(25), 0x45DC4A, 7)) {
                    Click(resEquip.x, resEquip.y)
                    towerEquipped := true

                    if (goldtower) {
                        GoldStart := A_TickCount
                        loop {
                            resGolden := AdvancedImageSearch("Resources\notgolden.png", X1, Y1, W, H)
                            if (resGolden.status == "success" && resGolden.score > 0.55) {
                                if (PixelSearch(&eX, &eY, resGolden.x - 40, resGolden.y - 25, resGolden.x + 40,
                                    resGolden.y + 25, 0x1E1E1E, 4)) {
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
                        loop {
                            resGolden := AdvancedImageSearch("Resources\golden.png", X1, Y1, W, H, 0.4, 2)
                            if (resGolden.status == "success" && resGolden.score > 0.55) {
                                if (PixelSearch(&eX, &eY, resGolden.x - 40, resGolden.y - 25, resGolden.x + 40,
                                    resGolden.y + 25, 0xFFC11F, 8)) {
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

        if !towerEquipped {
            RuntimeLogWarn("autoequip_tower_timeout", "Tower equip control was not confirmed within bounded retries",
                "tower=" tower "; elapsed_ms=" (A_TickCount - TowerStart))
            LogToConsole("Failed to equip tower '" tower "' reliably. Reloading...", true, false)
            SafeReload()
            return false
        }
        Sleep(400)
    }
    X1 := Round(rw * 0.2)
    Y1 := 0
    W := Round(rw * 1) - X1
    H := Round(rh * 0.4) - Y1
    resclose := AdvancedImageSearch("Resources\close_items.png", X1, Y1, W, H)

    if (resclose.status = "success" && resclose.score >= 0.85) {
        Click(resclose.x, resclose.y)
    } else if (savedCloseX != 0 && savedCloseY != 0) {
        Click(savedCloseX, savedCloseY)
    }

    LogToConsole("Successfully equipped towers: " towers, true, false)
    IniWrite(1, StateFile, "State", "Equipped")
    return true
}

CheckRestart() {
    global IsRestarting, difficulty, UseRestartBtn, UsePlayAgainBtn, CollectPlaytimeRewards, requiredTowers, AutoEquip

    shouldCollectRewards := (CollectPlaytimeRewards = "1" || CollectPlaytimeRewards = 1) && CheckDailyRewardTime() && (
        AutorunStartTime = 0 || (A_TickCount - AutorunStartTime) > 300000)
    shouldEquip := !Number(IniRead(StateFile, "State", "Equipped", 0))

    if (shouldCollectRewards && !MultiplayerEnabled) {
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
        getRobloxPos(, , &w, &h)

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

            if ((resRestart.status == "success" && resRestart.score > 0.64) || (resRestart2.status == "success" &&
                resRestart2.score > 0.64)) {
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
                    loop parse, PartyMembers, "," {
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

            resReplay := AdvancedImageSearch("Resources\PlayAgain.png", 0, h * 0.5, w, h * 0.5, 0.5, 1.5, 0.025)

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
    if (shouldEquip && AutoEquip) {
        EquipTowers(requiredTowers)
    }
    JoinGame()
}

RunRoblox(doReload := true) {
    global VipLink, UseVipServer
    PlaceID := "3260590327"

    loop {
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

        MacroPhase("launching_roblox", 240000)
        Run(DeepLink)
        robloxopened := false
        loop 60 {
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
        getRobloxPos(, , &w, &h)
        loop {
            ActivateRoblox()

            if (A_TickCount - startTime > 60000) {
                if (doReload) {
                    SafeReload()
                } else {
                    return false
                }
            }

            res0 := AdvancedImageSearch("Resources/Play.png", Round(w * 0.25), Round(h * 0.66), Round(w * 0.75), Round(
                h * 0.34))
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

    if (hwnd := GetRobloxHWND()) {
        getRobloxPos(, , , &windowHeight)
        GetRobloxClientPos(hwnd)
        if (windowHeight >= 500) {
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

    for p in ComObjGet("winmgmts:").ExecQuery(
        "SELECT * FROM Win32_Process WHERE Name LIKE '%Roblox%' OR CommandLine LIKE '%ROBLOXCORPORATION%'")
        ProcessClose p.ProcessID
}

resetCharacter() {
    if (hwnd := GetRobloxHWND()) {
        getRobloxPos(, , , &windowHeight)
        GetRobloxClientPos(hwnd)
        if (windowHeight >= 500) {
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

IsLegacyArcadeTarget(value) {
    return (value = "Pizza Party" || value = "Badlands II" || value = "Polluted Wasteland II")
}

ResolveArcadeTarget() {
    global gamemap, difficulty

    ; v1.3.4 canonical format: Mode=Arcade and Map=<visible Arcade/Trial card label>.
    ; Keep historical Pizza Party / Badlands II / PW2 strategy formats working.
    if (difficulty = "Arcade" && gamemap != "")
        return gamemap
    if IsLegacyArcadeTarget(gamemap)
        return gamemap
    if IsLegacyArcadeTarget(difficulty)
        return difficulty
    return ""
}

TryOpenArcadeCategory(w, h) {
    ; Prefer text targeting, but OCR must use SCREEN coordinates because
    ; OCR.FromRect is independent of AHK's client-relative CoordMode.
    try {
        if GetRobloxScreenClientRect(&screenX, &screenY, &screenW, &screenH) {
            langCode := "en-US"
            for availableLang in StrSplit(OCR.GetAvailableLanguages(), "`n", "`r") {
                if (availableLang != "" && SubStr(availableLang, 1, 2) = "en") {
                    langCode := availableLang
                    break
                }
            }

            navX := screenX + Round(screenW * 0.145)
            navY := screenY + Round(screenH * 0.08)
            navW := Round(screenW * 0.09)
            navH := Round(screenH * 0.50)
            ocrResult := OCR.FromRect(navX, navY, navW, navH, {
                lang: langCode,
                scale: 1.7,
                grayscale: 1
            })
            match := ocrResult.FindString("Arcade", { CaseSense: false, IgnoreLinebreaks: true })
            if (match) {
                RuntimeLogInfo("arcade_category_select", "Opening Arcade category by sidebar text")
                match.Click()
                Sleep(650)
                return true
            }
        }
    } catch Error as e {
        RuntimeLogWarn("arcade_category_ocr_error", "Could not target Arcade category by text", "error=" e.Message)
    }

    ; The Play navigation rail is a fixed client-relative layout. This bounded
    ; fallback prevents OCR/font/locale changes from blocking Arcade entirely.
    ; At supported client sizes Arcade is the fourth item in the rail.
    ActivateRoblox()
    fallbackX := Round(w * 0.18)
    fallbackY := Round(h * 0.43)
    RuntimeLogInfo("arcade_category_fallback", "Opening Arcade category by relative sidebar position", "x=" fallbackX "; y=" fallbackY)
    Click(fallbackX, fallbackY)
    Sleep(650)
    return true
}

GetArcadeCardClientRegion(w, h, &cardX, &cardY, &cardW, &cardH) {
    ; Intentionally exclude the left category rail and the lower-right macro
    ; console/log overlay. That overlay contains the configured map name and
    ; previously caused OCR to click its own log text instead of a game card.
    cardX := Round(w * 0.22)
    cardY := Round(h * 0.06)
    cardW := Round(w * 0.62)
    cardH := Round(h * 0.70)
}

TryClickArcadeTarget(target, w, h) {
    GetArcadeCardClientRegion(w, h, &cardX, &cardY, &cardW, &cardH)

    imagePath := "Resources/" target ".png"
    if FileExist(imagePath) {
        ; Params 4 and 5 are WIDTH and HEIGHT, not x2/y2. Passing the corner made
        ; the region spill past the client edge, which defeated the exclusion of
        ; the console overlay this function's comment relies on.
        res := AdvancedImageSearch(imagePath, cardX, cardY, cardW, cardH)
        if (res.status = "success" && res.score >= 0.67) {
            RuntimeLogInfo("arcade_card_image_select", "Selecting Arcade card by image", "target=" target "; score=" res.score)
            Click(res.x, res.y)
            Sleep(250)
            return true
        }
    }

    ; Generic fallback for future Arcade/Trial cards. OCR only the central game
    ; card panel and capture it in SCREEN coordinates so moved Roblox windows
    ; remain supported. Never OCR the macro console or sidebar here.
    try {
        if !GetRobloxScreenClientRect(&screenX, &screenY, &screenW, &screenH)
            return false

        langCode := "en-US"
        for availableLang in StrSplit(OCR.GetAvailableLanguages(), "`n", "`r") {
            if (availableLang != "" && SubStr(availableLang, 1, 2) = "en") {
                langCode := availableLang
                break
            }
        }

        ocrX := screenX + Round(screenW * 0.22)
        ocrY := screenY + Round(screenH * 0.06)
        ocrW := Round(screenW * 0.62)
        ocrH := Round(screenH * 0.70)
        ocrResult := OCR.FromRect(ocrX, ocrY, ocrW, ocrH, {
            lang: langCode,
            scale: 1.45,
            grayscale: 1
        })
        match := ocrResult.FindString(target, { CaseSense: false, IgnoreLinebreaks: true })
        if (match) {
            RuntimeLogInfo("arcade_card_text_select", "Selecting Arcade/Trial card by bounded text OCR", "target=" target)
            match.Click()
            Sleep(250)
            return true
        }
    } catch Error as e {
        RuntimeLogWarn("arcade_ocr_error", "Arcade card OCR targeting failed", "target=" target "; error=" e.Message)
    }

    return false
}

TryClickDifficultyTarget(target, w, h) {
    cardX := Round(w * 0.22)
    cardY := Round(h * 0.06)
    cardW := Round(w * 0.62)
    cardH := Round(h * 0.76)

    imagePath := "Resources/" target ".png"
    if FileExist(imagePath) {
        res := AdvancedImageSearch(imagePath, cardX, cardY, cardW, cardH)
        if (res.status = "success" && res.score >= 0.67) {
            RuntimeLogInfo("difficulty_image_select", "Selecting difficulty by image", "target=" target "; score=" res.score)
            Click(res.x, res.y)
            return true
        }
    }

    ; OCR fallback tolerates changed card artwork while staying inside the game
    ; card panel (never the macro log/console). OCR uses SCREEN coordinates.
    try {
        if !GetRobloxScreenClientRect(&screenX, &screenY, &screenW, &screenH)
            return false

        langCode := "en-US"
        for availableLang in StrSplit(OCR.GetAvailableLanguages(), "`n", "`r") {
            if (availableLang != "" && SubStr(availableLang, 1, 2) = "en") {
                langCode := availableLang
                break
            }
        }

        ocrResult := OCR.FromRect(
            screenX + Round(screenW * 0.22),
            screenY + Round(screenH * 0.06),
            Round(screenW * 0.62),
            Round(screenH * 0.76),
            { lang: langCode, scale: 1.45, grayscale: 1 }
        )
        match := ocrResult.FindString(target, { CaseSense: false, IgnoreLinebreaks: true })
        if (match) {
            RuntimeLogInfo("difficulty_text_select", "Selecting difficulty by OCR", "target=" target)
            match.Click()
            return true
        }
    } catch Error as difficultyOcrErr {
        RuntimeLogWarn("difficulty_ocr_error", "Difficulty OCR targeting failed",
            "target=" target "; error=" difficultyOcrErr.Message)
    }
    return false
}

WaitForLobbyLoad() {
    global difficulty, MultiplayerEnabled, PlayerRole

    MacroPhase("lobby_load", 180000)
    SetTimer(CheckPopups, 0)

    startTime := A_TickCount
    if (ResolveArcadeTarget() = "") {
        Sleep(6000)
        loop {
            if (A_TickCount - startTime > 60000) {
                CloseRoblox()
                SafeReload()
            }
            getRobloxPos(, , &w, &h)
            res := AdvancedImageSearch("Resources/Ready.png", Round(w * 0.25), Round(h * 0.66), Round(w * 0.5), Round(h *
                0.34), 0.6, 1.7)
            if (res.status = "success" && res.score >= 0.7) {
                break
            }
            Sleep(100)
        }
        if (!MultiplayerEnabled || PlayerRole = "Host") {
            SelectMap(res.x, res.y)
        } else {
            Click(Round(w * 0.5), res.y)
            Sleep 250
            Click(Round(w * 0.6), res.y)
            if (modifiers != "")
                ApplyModifiers()
        }
    }
}

JoinGame() {
    global SendCurrenciesEnabled, WebhookEnabled, difficulty, CollectPlaytimeRewards, PlayerRole, MultiplayerEnabled
    global readyX, readyY
    readyX := 0
    readyY := 0
    MacroPhase("matchmaking", 240000)
    RuntimeLogInfo("matchmaking_ready_reset", "Reset Ready coordinates before fresh matchmaking join")
    getRobloxPos(, , &w, &h)

    startTime := A_TickCount
    loop {
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

            joinTarget := ResolveArcadeTarget()
            if (joinTarget = "")
                joinTarget := difficulty
            LogToConsole("Joining " joinTarget "...", true, false)

            Click(res.x, res.y)
            MacroPhase("selecting_mode", 180000)
            break
        }
        Sleep(100)
    }
    Sleep(300)

    lastArcadeScroll := 0
    arcadeScrollAttempts := 0

    arcadeTarget := ResolveArcadeTarget()
    if (arcadeTarget != "") {
        categoryStart := A_TickCount
        categoryOpened := false
        loop {
            getRobloxPos(, , &w, &h)
            if TryOpenArcadeCategory(w, h) {
                categoryOpened := true
                break
            }
            if (A_TickCount - categoryStart > 8000) {
                RuntimeLogWarn("arcade_category_timeout", "Could not open Arcade category before card selection", "target=" arcadeTarget)
                break
            }
            Sleep(150)
        }
        if !categoryOpened {
            SafeReload()
            return
        }

        ; Start card scrolling only after the Arcade category is active.
        lastArcadeScroll := 0
        arcadeScrollAttempts := 0
        startTime := A_TickCount
        loop {
            getRobloxPos(, , &w, &h)
            if (A_TickCount - startTime > 35000) {
                RuntimeLogWarn("arcade_matchmaking_timeout", "Could not find Arcade/Trial card", "target=" arcadeTarget)
                SafeReload()
                break
            }

            if TryClickArcadeTarget(arcadeTarget, w, h)
                break

            ; Arcade lives below the standard matchmaking rows in the current Play UI.
            ; Keep scrolling here (not inside ImageSearch) so image, OCR, and LegacyMode
            ; all share the exact same bounded navigation behavior.
            if (A_TickCount - lastArcadeScroll >= 650 && arcadeScrollAttempts < 12) {
                ActivateRoblox()
                MouseMove(Round(w * 0.78), Round(h * 0.78), 0)
                SendEvent("{WheelDown 4}")
                lastArcadeScroll := A_TickCount
                arcadeScrollAttempts++
            }
            Sleep(100)
        }
        Sleep(300)
    } else {
        difficultyStart := A_TickCount
        difficultyDeadline := difficultyStart + 60000
        lastPlayRetry := 0
        firstModeScrollAt := difficultyStart + 1500
        lastModeScroll := difficultyStart
        modeScrollAttempts := 0

        loop {
            getRobloxPos(, , &w, &h)
            elapsedDifficulty := A_TickCount - difficultyStart
            if (A_TickCount >= difficultyDeadline) {
                LogToConsole("Could not select difficulty '" difficulty "' within 60s. Reloading...", true)
                RuntimeLogWarn("difficulty_select_timeout", "Difficulty card never matched",
                    "difficulty=" difficulty "; scrolls=" modeScrollAttempts)
                SafeReload()
                return
            }

            if TryClickDifficultyTarget(difficulty, w, h) {
                break
            }

            ; Frost and other standard cards may sit below the first viewport in
            ; the current Play UI. Scroll in a bounded way and retry both image
            ; and OCR targeting on each viewport.
            if (A_TickCount >= firstModeScrollAt && A_TickCount - lastModeScroll >= 650 && modeScrollAttempts < 12) {
                ActivateRoblox()
                MouseMove(Round(w * 0.78), Round(h * 0.78), 0)
                SendEvent("{WheelDown 4}")
                lastModeScroll := A_TickCount
                modeScrollAttempts++
                RuntimeLogInfo("difficulty_scroll_retry", "Scrolling the bounded mode-card panel",
                    "difficulty=" difficulty "; attempt=" modeScrollAttempts)
            }

            ; If the Play screen bounced closed, re-open it, but NEVER reset the
            ; absolute difficulty deadline. The previous PR reset that deadline
            ; and could still hang forever on "Entering/Joining Easy...".
            if (elapsedDifficulty > 15000 && (lastPlayRetry = 0 || A_TickCount - lastPlayRetry >= 5000)) {
                playX := Round(w * 0.25)
                playY := Round(h * 0.66)
                playW := Round(w * 0.5)
                playH := Round(h * 0.34)
                resPlay := AdvancedImageSearch("Resources\Play.png", playX, playY, playW, playH)
                if (resPlay.status == "success" && resPlay.score > 0.7) {
                    RuntimeLogInfo("difficulty_play_recovery", "Reopening Play without extending the mode deadline",
                        "difficulty=" difficulty "; elapsed_ms=" elapsedDifficulty)
                    Click(resPlay.x, resPlay.y)
                }
                lastPlayRetry := A_TickCount
            }
            Sleep(100)
        }
        Sleep(300)
    }

    MacroPhase("selecting_party_size", 120000)
    startTime := A_TickCount
    loop {
        getRobloxPos(, , &w, &h)
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
            loop parse, PartyMembers, "," {
                member := Trim(A_LoopField)
                if (member = "") {
                    continue
                }
                totalPartyMembers++
            }
            if (totalPartyMembers = 1) {
                res := AdvancedImageSearch("Resources/duo.png", Round(w * 0.2), Round(h * 0.2), Round(w * 0.6), Round(h *
                    0.6))
            } else if (totalPartyMembers = 2) {
                res := AdvancedImageSearch("Resources/trio.png", Round(w * 0.2), Round(h * 0.2), Round(w * 0.6), Round(
                    h * 0.6))
            } else if (totalPartyMembers = 3) {
                res := AdvancedImageSearch("Resources/quad.png", Round(w * 0.2), Round(h * 0.2), Round(w * 0.6), Round(
                    h * 0.6))
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

    loop {
        Click(x + 200, y)

        InnerStartTime := A_TickCount

        if (A_TickCount - StartTime > 10000) {
            LogToConsole("Failed to Create Party: The macro can't see the menu!", true)
            SafeReload()
        }

        getRobloxPos(, , &w, &h)
        loop {
            resclose := AdvancedImageSearch("Resources\close.png", Round(w * 0.25), Round(h * 0.1), Round(w * 0.5),
            Round(h * 0.4))

            if (resclose.status = "success" && resclose.score >= 0.7) {
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

    create_btn := AdvancedImageSearch("Resources\create_party.png", Round(w * 0.25), Round(h * 0.5), Round(w * 0.5),
    Round(h * 0.5))
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

    loop 3 {
        search_bar := AdvancedImageSearch("Resources\type_to_search.png", Round(w * 0.25), Round(h * 0.1), Round(w *
            0.5), Round(h * 0.3))
        if (search_bar.score > 0.58) {
            loop parse, PartyMembers, "," {
                member := Trim(A_LoopField)
                if (member = "") {
                    continue
                }
                Click(search_bar.x, search_bar.y)
                Sleep(100)
                SendText(member)
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
    loop parse, PartyMembers, "," {
        member := Trim(A_LoopField)
        if (member = "") {
            continue
        }
        totalPartyMembers++
    }

    xs := 0
    sy := Round(h * 0.1)

    waitStartTime := A_TickCount

    loop {
        x_btn := AdvancedImageSearch("Resources\x.png", Round(w * 0.25), sy, Round(w * 0.25), Round(h * 0.75) - sy)
        if (x_btn.score > 0.7) {

            xs++
            sy := x_btn.y + x_btn.h / 2
        }
        LogToConsole("Waiting for " totalPartyMembers " players... (" xs "/" totalPartyMembers ")")
        if (xs >= totalPartyMembers) {
            LogToConsole("All players: " PartyMembers " have joined!")
            break
        }
        if (A_TickCount - waitStartTime > 30000) {
            sy := Round(h * 0.1)
            xs := 0
            loop parse, PartyMembers, "," {
                member := Trim(A_LoopField)
                if (member = "") {
                    continue
                }
                Click(search_bar.x, search_bar.y)
                Sleep(100)
                SendText(member)
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

    resclose := AdvancedImageSearch("Resources\close.png", Round(w * 0.25), Round(h * 0.1), Round(w * 0.5), Round(h *
        0.4))

    if (resclose.status = "success" && resclose.score >= 0.7) {
        Click(resclose.x, resclose.y)
    }
    Sleep 200
}

CancelInviteIfAppeared(*) {
    getRobloxPos(, , &w, &h)

    cancel_btn := AdvancedImageSearch("Resources/cancel_invite.png", Round(w * 0.2), Round(h * 0.2), Round(w * 0.6),
    Round(h * 0.65))
    if (cancel_btn.status = "success" && cancel_btn.score >= 0.65) {
        Click(cancel_btn.x, cancel_btn.y)
    }
}

AcceptInvite(x, y) {

    StartTime := A_TickCount
    CloseX := 0
    CloseY := 0
    loop {
        Click(x + 200, y)

        InnerStartTime := A_TickCount

        if (A_TickCount - StartTime > 15000) {
            LogToConsole("Failed to Create Party: The macro can't see the menu!", true)
            SafeReload()
        }

        getRobloxPos(, , &w, &h)
        loop {
            resclose := AdvancedImageSearch("Resources\close.png", Round(w * 0.25), Round(h * 0.1), Round(w * 0.5),
            Round(h * 0.4))

            if (resclose.status = "success" && resclose.score >= 0.7) {
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

    loop 5 {
        create_btn := AdvancedImageSearch("Resources\invites_btn.png", Round(w * 0.25), 0, Round(w * 0.5), Round(h *
            0.4))
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
    SendText(HostName)
    Sleep 100

    InnerStartTime := A_TickCount
    loop {
        LogToConsole("Waiting for an invite from host: " HostName "...")
        accept_btn := AdvancedImageSearch("Resources\accept_invite.png", Round(w * 0.25), Round(h * 0.1), Round(w * 0.5
        ), Round(h * 0.3))
        if (accept_btn.score > 0.66) {
            Click(accept_btn.x, accept_btn.y)
            if !(ReadMessage(["Error", "Party", "not", "found"])) {
                LogToConsole("Successfully accepted an invitation from " HostName)
                break
            }
        }
        if (A_TickCount - InnerStartTime > 180000) {
            LogToConsole(
                "Didn't receive an invite from the host within 3 minutes! Reloading the script and rejoining...", true)
            SafeReload()
        }
        Sleep 5000
    }

    resclose := AdvancedImageSearch("Resources\close.png", Round(w * 0.25), Round(h * 0.1), Round(w * 0.5), Round(h *
        0.4))

    if (resclose.status = "success" && resclose.score >= 0.7) {
        Click(resclose.x, resclose.y)
    }
}

checkCondition(*) {
    global LeaveCondition, PartyMembers

    totalPartyMembers := 0
    loop parse, PartyMembers, "," {
        member := Trim(A_LoopField)
        if (member = "") {
            continue
        }
        totalPartyMembers++
    }

    ActivateRoblox()
    getRobloxPos(&rX, &rY, &w, &h)

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

    ; Region is x/y/width/height. Width must not exceed the client from x onward.
    result := AdvancedImageSearch(img ".png", Round(w * 0.5), rY, w - Round(w * 0.5), h)

    if (LeaveCondition = "All") {
        ; "All members are gone" -> only leave when the all-gone marker matches.
        ; The old else-branch also left when it did NOT match, which made this
        ; mode quit the moment the check first ran.
        if (result.score > 0.8) {
            LogToConsole("All players are gone! Closing roblox and reloading the macro...", true)
            CloseRoblox()
            SafeReload()
        }
    } else {
        ; "Any member is gone" -> the marker shows the full party; a miss means
        ; somebody left.
        if (result.score <= 0.8) {
            LogToConsole("Someone has just left! Closing roblox and reloading the macro...", true)
            CloseRoblox()
            SafeReload()
        }
    }

}

SelectMap(readyX := ScaleX(963), readyY := ScaleY(838)) {
    global gamemap, difficulty, modifiers, CheckTheMap, LegacyMode

    getRobloxPos(, , &w, &h)
    readyX := Round(w * 0.5)

    MacroPhase("selecting_map", 420000)
    LogToConsole("Selecting map: " gamemap, true, false)
    Sleep(100)
    closeChat()

    if (difficulty = "Hardcore" || difficulty = "Voidcore") {
        if (!LegacyMode) {
            image := A_WorkingDir "/Resources/map_selection.png"

            foundObject := false

            loop 3 {
                getRobloxPos(&x, &y, &w, &h)
                res := AdvancedImageSearch(image, 0, 0, Round(w / 2), h)
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

        loop {
            Sleep(200)
            ActivateRoblox()
            Sleep(600)
            SendEvent("{sc011 down}")
            Sleep(3550)
            SendEvent("{sc011 up}")
            Sleep(300)

            LogToConsole("Trying to find: " gamemap ". Please wait..")

            ; Gdip_BitmapFromScreen needs SCREEN coordinates; getRobloxPos returns a
            ; client rect anchored at 0,0. Offset by the real client origin so the
            ; map-name OCR reads the Roblox window instead of the desktop corner.
            if !GetRobloxScreenClientRect(&mapClientX, &mapClientY, &w, &h) {
                LogToConsole("Cannot resolve Roblox window for map OCR. Reloading...", true)
                SafeReload()
                return
            }
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

            escapedMap := RegExReplace(gamemap, "([\\.\^\$\*\+\?\(\)\[\]\{\}\|])", "\$1")
            loop 4 {
                r := regions[A_Index]
                pBmp := 0
                result := ""
                try {
                    pBmp := Gdip_BitmapFromScreen((mapClientX + r[1]) "|" (mapClientY + r[2]) "|" r[3] "|" r[4])
                    if pBmp
                        result := OCR.FromBitmap(pBmp, { lang: langCode, scale: 1.5, grayscale: 1 }).Text
                } catch Error as mapOcrErr {
                    RuntimeLogWarn("map_ocr_failed", "Map name OCR failed", "slot=" A_Index "; error=" mapOcrErr.Message)
                } finally {
                    if pBmp
                        Gdip_DisposeImage(pBmp)
                }
                if (result != "" && RegExMatch(result, "i)\b" . escapedMap . "\b")) {
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
                LogToConsole(gamemap " found in slot " FoundSlot, true, false)
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

        loop 3 {
            e_pr := AdvancedImageSearch("Resources\e_prompt.png", 0, 0, w, h, 1, 1)

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
        loop 2 {
            if (!LegacyMode) {
                res := AdvancedImageSearch("Resources/searchbar.png", Round(w * 0.1), 0, Round(w * 0.6), h, 0.5, 1.5)

                if (res.status = "success" && res.score >= 0.6) {
                    Click(res.x, res.y)
                    foundsearchbar := true
                    break
                }
            } else {
                res := { x: ScaleX(810), y: ScaleY(218) }
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
        loop {
            Sleep(300)
            if (InArray(SpecialMaps, gamemap)) {
                SelectionICON := AdvancedImageSearch("Resources/Maps/" gamemap "_Selection.png", Round(w * 0.1), 0,
                Round(w * 0.7), h, 0.5, 1.5)

                if (SelectionICON.score >= 0.65) {
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
            loop 2 {
                if PixelSearch(&gx, &gy, Round(w * 0.2), Round(h * 0.24), Round(w * 0.7), Round(h * 0.3), 0x00EC00, 3) {
                    LogToConsole("Successfully changed the map to " gamemap, true, false)
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
                resVeto := AdvancedImageSearch("Resources\Veto.png", 0, 0, w, h, 0.5, 1.5)
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
        loop 3 {
            e_pr := AdvancedImageSearch("Resources\e_prompt.png", 0, 0, w, h, 0.6, 1.5)

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
            loop 3 {
                e_pr := AdvancedImageSearch("Resources\e_prompt.png", 0, 0, w, h, 0.6, 1.5)

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

    if (ResolveArcadeTarget() = "" && FileExist("Resources\Maps\" . gamemap . ".png") && CheckTheMap = 1 && !InArray(SpecialMaps, gamemap) && !
    RegExMatch(modifiers_str, "i)fog")) {
        AlignCamera(false, false, false)

        LogToConsole("Checking the map... (Make sure you have the lowest graphics)")

        FoundMap := false
        mapDeadline := A_TickCount + 12000
        mapSamples := 0
        cameraRecoveries := 0
        lastMapScore := 0

        while (A_TickCount < mapDeadline && mapSamples < 16) {
            if !getRobloxPos(, , &w, &h) {
                RuntimeLogWarn("map_geometry_missing", "Roblox client geometry disappeared during map detection",
                    "map=" gamemap)
                break
            }

            mapSamples++
            res := AdvancedImageSearch("Resources\Maps\" gamemap ".png", 0, 0, w, h)
            lastMapScore := res.HasProp("score") ? res.score : 0

            if (res.status = "success" && lastMapScore > 0.62) {
                FoundMap := true
                break
            }

            ; A noisy first viewport is not a reload condition. Re-establish the
            ; deterministic camera twice during the same absolute deadline.
            if (cameraRecoveries < 2 && (mapSamples = 4 || mapSamples = 9)) {
                AlignCamera(false, false, false)
                cameraRecoveries++
                RuntimeLogInfo("map_camera_recovery", "Realigned camera after transient map misses",
                    "map=" gamemap "; recovery=" cameraRecoveries "; samples=" mapSamples)
            }
            Sleep(650)
        }

        if (!FoundMap) {
            RuntimeLogWarn("map_detection_failed", "Configured map image was not detected",
                "map=" gamemap "; score=" lastMapScore "; samples=" mapSamples "; camera_recoveries=" cameraRecoveries)
            LogToConsole("Can't detect the map! Reloading script...", true)
            Sleep 300
            SafeReload()
            return
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
    loop 2 {
        res := AdvancedImageSearch("Resources/searchbar_modifiers.png", Round(w * 0.1), 0, Round(w * 0.7), Round(h *
            0.6), 0.5, 1.5)

        if (res.status = "success" && res.score >= 0.7) {
            searchX := res.x
            searchY := res.y
            foundsearchbar := true
            break
        }
        Sleep(500)
    }

    loop parse, modifiers, "," {
        modifier := Trim(A_LoopField)
        if (modifier = "") {
            continue
        }
        Click(searchX, searchY)
        Sleep(100)
        SendText(modifier)
        Sleep(100)
        Click(Round(w / 2), searchY + ScaleY(80))
        Sleep(50)
        LogToConsole("Modifier added: " modifier)
    }
    Sleep(100)
    Click(ScaleX(1122), ScaleY(853))
    LogToConsole("All modifiers configured")
}

FindReadyButton(&foundX, &foundY) {
    if !getRobloxPos(, , &w, &h) {
        foundX := 0
        foundY := 0
        return false
    }
    rx := Round(w * 0.4)
    ry := Round(h * 0.05)
    rw := Round(w * 0.3)
    rh := Round(h * 0.3)

    result := AdvancedImageSearch("Resources/ready_gs.png", rx, ry, rw, rh)
    if (result.status = "success" && result.score > 0.7) {
        foundX := result.x
        foundY := result.y
        return true
    }

    foundX := 0
    foundY := 0
    return false
}

ClickReady() {
    global readyX, readyY

    readyDeadline := A_TickCount + 8000
    attempts := 0
    while (A_TickCount < readyDeadline && attempts < 6) {
        attempts++
        if !FindReadyButton(&readyX, &readyY) {
            LogToConsole("Ready button image not found (attempt " attempts "/6), retrying...")
            Sleep(300)
            continue
        }

        MouseMove(readyX, readyY)
        Sleep 50
        MouseClick()
        Sleep 250

        ; Require two consecutive bounded misses after a click. A single noisy
        ; frame is not enough evidence that the match started.
        disappearedSamples := 0
        loop 3 {
            if !FindReadyButton(&checkX, &checkY) {
                disappearedSamples++
                if (disappearedSamples >= 2) {
                    LogToConsole("Successfully started the match by clicking the ready button.")
                    RuntimeLogInfo("ready_click_confirmed", "Ready disappeared after a template-based click",
                        "attempt=" attempts)
                    return true
                }
            } else {
                disappearedSamples := 0
                readyX := checkX
                readyY := checkY
            }
            Sleep(200)
        }

        LogToConsole("Ready button is still visible, retrying...")
        Sleep(250)
    }

    LogToConsole("Failed to confirm the Ready button after multiple attempts. Reloading...", true)
    RuntimeLogWarn("ready_click_timeout", "Ready could not be clicked and confirmed within bounded retries",
        "attempts=" attempts)
    SafeReload()
    return false
}

waitReady() {
    global readyX, readyY, MultiplayerEnabled, PlayerRole
    MacroPhase("waiting_ready", 180000)
    start := A_TickCount
    getRobloxPos(&x, &y, &w, &h)
    KillSubmacros()
    loop {
        wt := 40000
        if (MultiplayerEnabled && PlayerRole = "Member") {
            wt := 90000
        }
        if (A_TickCount - start > wt) {
            LogToConsole("The ready button hasn't appeared for too long! Reloading the script...", true)
            CloseRoblox()
            SafeReload()
        }
        if FindReadyButton(&fx, &fy) {
            readyX := fx
            readyY := fy
            break
        }
        Sleep(250)
    }
    startWatchdog()
}

activateTimescale() {
    global UseTimeScale, TimeScaleMode, TimeScaleMultiplier, difficulty, SettingsFile, AutorunStartTime,
        MultiplayerEnabled, TimescaleActive
    if (MultiplayerEnabled) {
        return
    }

    getRobloxPos(&x, &y, &w, &h)
    if (UseTimeScale && ResolveArcadeTarget() = "") {
        LogToConsole("Applying timescale: " TimeScaleMode ". Please, enable UI Navigation Toggle.")
        Click(Round(w * 0.5), Round(h * 0.5))

        Send("#")
        Send("{sc02B}")
        Sleep 50
        loop 10 {
            Send("{Down}")
            Sleep 10
        }
        loop 20 {
            Send("{Left}")
            Sleep 10
        }
        Send("{Right}")
        Sleep 10
        Send("{Enter}")

        Sleep(250)

        res := AdvancedImageSearch("Resources/GetMore.png", Round(w * 0.25), Round(h * 0.45), Round(w * 0.50), Round(h *
            0.55))
        if (res.status = "success" && res.score >= 0.67) {
            Click(res.x, res.y + 55)
            LogToConsole("Failed to activate timescale! You are out of tickets.", true, false)

        } else {
            res := AdvancedImageSearch("Resources/confirm.png", Round(w * 0.25), Round(h * 0.45), Round(w * 0.50),
            Round(h * 0.55))
            if (res.status = "success" && res.score >= 0.67) {
                Click(res.x, res.y)
            } else {
                LogToConsole("failed to activate timescale. the macro can't see the confirm/get more button... (" res.score ")",
                    true)
                SafeReload()
            }

            timescales := IniRead(StateFile, "State", "Timescale", 0)
            timescales := timescales + 1
            LogToConsole("-1 Timescale ticket. Total Timescale Tickets Used: " timescales)
            SendToWebhookInstant("[" runtime := FormatRuntime(AutorunStartTime) "] -1 Timescale ticket. `n-# Total Timescale Tickets Used: " .
            timescales, 12370112, false)
            IniWrite(timescales, StateFile, "State", "Timescale")
            TimescaleActive := true

            Sleep(250)
            if (TimeScaleMode = "2x") {
                loop 2 {
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

    MouseMove(rw / 2, rh / 2, 0)
    Click("Right Down")
    Sleep(50)
    MouseMove(0, rh, 3 + MouseDelay, "R")
    Sleep(10)
    Click("Right Up")
    if (!skipZoom) {
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
    endX := Integer(w * 0.75)

    startX := Integer(w * 0.15)

    for digit, Image in numbers {
        if (!Image)
            continue

        Variation := 10

        Result := AdvancedImageSearch(Image, startX, offsetY, endX, endY, 0.75, 2)

        if (Result.status == "success" && Result.score >= 0.84) {
            startX := Result.x + ScaleX(70)
            endY := Result.y + ScaleY(40) - offsetY
            endX := Integer(w * 0.1)

            currentSlotsState[digit] := [Result.x + ScaleX(15), Result.y + ScaleY(20)]
        }
    }

    cachedSlotsState := currentSlotsState
    return cachedSlotsState
}

SpawnTower(X, Y, slotNumber, towerID) {
    global Towers, LastOpenedTowerID, CancelPlacementKey, canUseAbility, UseNumbersForHotbar
    LogToConsole("Placing tower " towerID " (slot " slotNumber ") at x:" X " y:" Y "...")

    X := sX(X, StrategyWidth)
    Y := sY(Y, StrategyHeight)

    getRobloxPos(, , , &h)
    TowerY := Y
    if (Y < h * 0.5) {
        TowerY := Y - ScaleY(5)
    }

    placeAttempts := 0
    attemptMultiplier := 1
    startTime := A_TickCount
    canUseAbility := false

    loop {
        placeAttempts++

        if (A_TickCount - startTime > 300000) {
            LogToConsole("Tower placement timed out (5+ minutes). Reloading the macro...")
            SafeReload()
            return
        }

        ActivateRoblox()

        if UseNumbersForHotbar {
            Send("{" slotNumber "}")
        } else if !SelectHotbarSlotByClick(slotNumber) {
            LogToConsole("Hotbar slot " slotNumber " could not be resolved; retrying placement...")
            Sleep(500)
            continue
        }

        Sleep((PotatoMode = 1) ? 100 : 30)

        MouseMove(X, Y, A_DefaultMouseSpeed)
        Sleep((PotatoMode = 1) ? 100 : 40)
        MouseClick()
        Sleep(100)
        SendEvent("{" CancelPlacementKey "}")

        placedSuccessfully := waitForTowerUI(&resV2)

        if (placedSuccessfully) {
            Towers[towerID] := { x: X, y: TowerY, slot: Integer(slotNumber), level: 0, path: 0, pathLevel: 0, target: "First Enemy" }
            LogToConsole("Tower " towerID " placed successfully")
            LastOpenedTowerID := towerID
            break
        } else {
            LogToConsole("Tower " towerID " placement failed, retrying...")
            if (placeAttempts = 1) {
                continue
            }

            getRobloxPos(, , &w, &h)
            x1 := Round(w * 0.2)
            y1 := Round(h * 0.18)
            x2 := Round(w * 0.7)
            y2 := Round(h * 0.3)
            if (ImageSearch(&fx, &fy, x1, y1, x2, y2, "*Trans000000 *50 " A_WorkingDir "/Resources/cannot_place_here.png"
            ) || ReadMessage(["cannot", "here", "hereg", "herd", "her", "here!", "cann", "cannd", "he", "h", "hed"], ,
            ["need", "more", "to"], "\$|\d")) {
                MouseClick()

                placedSuccessfully := waitForTowerUI(&resV2)
                if (placedSuccessfully) {
                    Towers[towerID] := { x: X, y: TowerY, slot: Integer(slotNumber), level: 0, path: 0, pathLevel: 0,
                        target: "First Enemy" }
                    LogToConsole("Tower " towerID " placed successfully")
                    LastOpenedTowerID := towerID
                    break
                }

                offsets := [[0, -5 * attemptMultiplier], [5 * attemptMultiplier, 0], [0, 5 * attemptMultiplier], [-5 *
                    attemptMultiplier, 0]]
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
                        Towers[towerID] := { x: newX, y: newY, slot: Integer(slotNumber), level: 0, path: 0, pathLevel: 0,
                            target: "First Enemy" }
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
    loop {
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
        Y1_v2 := Round(h / 2)
        W_v2 := Round(w * 0.3) - X1_v2
        H_v2 := Round(h) - Y1_v2

        resV2 := AdvancedImageSearch("Resources\TowerUI\Variant2.png", X1_v2, Y1_v2, W_v2, H_v2, , , 0.05)

        if (resV2.score > 0.55) {
            Click(resV2.x, resV2.y)
        }

        LogToConsole("Tower " towerID " sold successfully")
        ; Towers created by LoadStrategyFile/SpawnTower have no `hwnd` property -
        ; only UpdateTowerIndicator adds one, and only while recording. Reading it
        ; unguarded threw a PropertyError here, which skipped Towers.Delete() and
        ; left a phantom tower in the map for the rest of the run.
        try {
            if (Towers[towerID].HasProp("hwnd") && Towers[towerID].hwnd)
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

    effectivePathLevel := ResolvePathBranchLevel(towerID, pathLevel)

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
    ; Absolute deadline for this tower. Waiting for cash and being permanently
    ; un-upgradeable used to be indistinguishable here, so a maxed tower (or a
    ; mis-aimed green probe) spun this loop forever at 100% CPU.
    upgradeDeadline := A_TickCount
    maxLevelChecked := 0

    Sleep(20)

    loop {
        openedSuccessfully := false
        StartTime := A_TickCount

        if (A_TickCount - upgradeDeadline > 300000) {
            LogToConsole("Tower " towerID " could not be upgraded within 5 minutes. Skipping step.", true)
            RuntimeLogWarn("upgrade_timeout", "Upgrade step abandoned",
                "tower=" towerID "; done=" upgradesDone "/" totalUpgrades)
            canUseAbility := true
            return false
        }

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
            UpgradeX := resV2.x + ScaleX(50)
            UpgradeY := resV2.y - ScaleY(220)

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

            UpgradeX := resV1.x - ScaleX(164)
            UpgradeY := resV1.y + ScaleY(383)

            upgAX := resV1.x - ScaleX(194)
            upgAY := resV1.y + ScaleY(363)
            upgAW := ScaleX(80)
            upgAH := ScaleY(70)
        }

        nextLevel := Towers[towerID].level + 1

        region := [upgAX, upgAY, upgAW, upgAH]

        if IsPathSpecificUpgrade(towerID, nextLevel, path, effectivePathLevel) {
            if (path = 2) {
                if (doResV2) {
                    region := [resV2.x + ScaleX(20), resV2.y - ScaleY(95), ScaleX(80), ScaleY(70)]
                    UpgradeY := resV2.y - ScaleY(120)
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
                if IsPathSpecificUpgrade(towerID, nextLevel, path, effectivePathLevel) {
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
            MacroPhase("playing_upgrade_progress", 900000)
            LogToConsole("Tower " towerID " upgraded to level " Towers[towerID].level " (" upgradesDone "/" totalUpgrades ")"
            )
            UpdateTowerIndicator(towerID)

            if (Towers[towerID].level >= 2 && RegExMatch(towerID, "i)^Commander\d*$") && !Commander) {
                Commander := true
                if (Recording && !HasStep("Commander := true"))
                    RecordedSteps.Push("Commander := true")
            }

            canUseAbility := true

            if (upgradesDone >= totalUpgrades)
                return true

            upgradeDeadline := A_TickCount
            continue
        }

        ; Not green. Either the tower cannot be afforded yet, or it is already
        ; fully upgraded. The recording path (DetectUpgrade) distinguishes these
        ; with fully_upgraded.png; the replay path never did, so a maxed tower
        ; hung here forever. Check periodically rather than every pass.
        if (A_TickCount - maxLevelChecked > 3000) {
            maxLevelChecked := A_TickCount
            if (AdvancedImageSearch("Resources/fully_upgraded.png", XA, YA, WA, HA).score >= 0.69) {
                LogToConsole("Tower " towerID " is already fully upgraded, moving on.")
                canUseAbility := true
                return true
            }
        }

        ; Waiting for cash: yield instead of spinning on back-to-back searches.
        Sleep((PotatoMode = 1) ? 200 : 100)
    }
}

isDisconnected() {
    ActivateRoblox()

    ; The search below runs in SCREEN space, so it needs the Roblox client rect in
    ; screen coordinates. It previously mixed client dimensions with screen origin,
    ; which missed the dialog whenever Roblox was not at the desktop origin - and
    ; always missed it on a secondary monitor.
    if !GetRobloxScreenClientRect(&cx, &cy, &cw, &ch) {
        cx := 0, cy := 0
        cw := A_ScreenWidth, ch := A_ScreenHeight
    }

    if (cw <= 0 || ch <= 0) {
        cx := 0, cy := 0
        cw := A_ScreenWidth, ch := A_ScreenHeight
    }

    oldMode := A_CoordModePixel
    CoordMode("Pixel", "Screen")

    disconnected := false
    try {
        if ImageSearch(&FoundX, &FoundY, cx, cy, cx + cw, cy + ch, "*26 " "Resources\Disconnected.png")
            disconnected := true
        else if ImageSearch(&FoundX, &FoundY, cx, cy, cx + cw, cy + ch, "*26 " "Resources\disconnected2.png")
            disconnected := true
    } catch Error as err {
        disconnected := false
    } finally {
        CoordMode("Pixel", oldMode)
    }

    if (disconnected)
        TryReconnect()
}

TryReconnect() {
    attempts := 0
    loop {
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

    getRobloxPos(, , &w, &h)

    res := AdvancedImageSearch("Resources/Claim.png", Round(w * 0.25), Round(h * 0.4), Round(w * 0.5), Round(h * 0.5))
    if (res.status = "success" && res.score >= 0.65) {
        LogToConsole("Claimed daily reward.")
        Click(res.x, res.y)
    }

    res := AdvancedImageSearch("Resources/cancel_rejoin.png", Round(w * 0.15), Round(h * 0.4), Round(w * 0.7), Round(h *
        0.4))
    if (res.status = "success" && res.score >= 0.65) {
        Click(res.x, res.y)
    }

    if (!clickedNotNow) {
        res2 := AdvancedImageSearch("Resources/notnow.png", Round(w * 0.25), Round(h * 0.4), Round(w * 0.5), Round(h *
            0.5))
        if (res2.status = "success" && res2.score >= 0.65) {
            clickedNotNow := true
            Click(res2.x, res2.y)
        }
    }
}

UseAbilities(*) {
    global canUseAbility, canBeUpgraded, needtocheckTowerUI
    static callbackActive := false

    if (callbackActive || !canUseAbility)
        return

    callbackActive := true
    try {
        UseAbilitiesPass()
    } catch Error as abilityErr {
        RuntimeLogWarn("ability_timer_error", "Ability timer pass failed safely", "error=" abilityErr.Message)
    } finally {
        ; The timer entered only while abilities were available, so restoring
        ; these flags cannot release a lock owned by an interrupted runtime step.
        callbackActive := false
        canUseAbility := true
        canBeUpgraded := true
        needtocheckTowerUI := true
    }
}

UseAbilitiesPass() {
    global ChainKey, BeatKey, CaravanKey, CancelPlacementKey, TimeScaleMultiplier, AutoSkip, AbilitySpam
    global autoChain, autoCaravan, autoDropTheBeat, Commander, unfocusX, unfocusY, canUseAbility
    global LastOpenedTowerID, Towers, TimescaleActive, needtocheckTowerUI
    global canBeUpgraded
    static LastChainTime := 0, LastDropTime := 0, LastCaravanTime := 0

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
        ; Region must come from the Roblox CLIENT, not the desktop. Using screen
        ; dimensions under client CoordMode overshoots whenever the client is
        ; smaller than the monitor (windowed, multi-monitor, scaled).
        getRobloxPos(, , &skw, &skh)
        skX := Round(skw * 0.3)
        skW := Round(skw * 0.7)
        skH := Round(skh * 0.35)

        res := AdvancedImageSearch("Resources/Skip.png", skX, 0, skW, skH, 0.5, 1.5)
        if (res.status = "success" && res.score >= 0.65) {
            Sleep(200)
            res := AdvancedImageSearch("Resources/Skip.png", skX, 0, skW, skH, 0.5, 1.5)
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
        ; LastOpenedTowerID can hold a stale id (or the literal 0 that
        ; ChangeTargets parks there), so membership must be checked before index.
        if (LastOpenedTowerID != "" && Towers.Has(LastOpenedTowerID)) {
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

        ; Skip only the Caravan block when no level-4 Commander exists. This used
        ; to `return`, which silently disabled Drop the Beat below it for every
        ; strategy that enabled Support Caravan.
        if (foundCommander) {
            canBeUpgraded := false

            canUseAbility := false
            SendEvent("{" CancelPlacementKey "}")
            if (LastOpenedTowerID != "" && Towers.Has(LastOpenedTowerID)) {
                Click(ScaleX(unfocusX), ScaleY(unfocusY))
                Sleep(300)
            }
            LastCaravanTime := A_TickCount
            SendEvent("{" CaravanKey "}")
            LogToConsole("Activated Support Caravan")
            if (LastOpenedTowerID != "" && Towers.Has(LastOpenedTowerID)) {
                Click(Towers[LastOpenedTowerID].x, Towers[LastOpenedTowerID].y)
                Sleep 400
            }
            canUseAbility := true
            canBeUpgraded := true
            needtocheckTowerUI := true
        }
    }

    if (autoDropTheBeat = "ON" && Towers.Has("DJ") && Towers["DJ"].level >= 3 && (A_TickCount - LastDropTime > 28000 /
        multiplier)) {

        canBeUpgraded := false

        SendEvent("{" CancelPlacementKey "}")
        if (LastOpenedTowerID != "DJ" && LastOpenedTowerID != "") {
            Click(ScaleX(unfocusX), ScaleY(unfocusY))
            Sleep(100)
        }

        ; Bounded: this runs inside a timer thread, so an unbounded retry here
        ; blocks the whole macro. Give up after a few attempts and let the next
        ; timer tick try again.
        loop 3 {
            LastDropTime := A_TickCount
            SendEvent("{" BeatKey "}")

            Sleep 350
            getRobloxPos(, , &w, &h)
            x1 := Round(w * 0.2)
            y1 := Round(h * 0.18)
            x2 := Round(w * 0.7)
            y2 := Round(h * 0.3)
            if (ImageSearch(&fx, &fy, x1, y1, x2, y2, "*Trans000000 *50 " A_WorkingDir "/Resources/stunned.png") ||
            ReadMessage(["error", "that", "cannot", "cann", "activated", "while", "stunned"], , ["need", "more", "to"],
            "\$|\d")) {
                if (A_Index = 3) {
                    LogToConsole("Drop the Beat still stunned after 3 attempts, will retry next cycle")
                    break
                }
                LogToConsole("Failed to use Drop the Beat! The tower is stunned! Retrying...")
                Sleep 4400
            } else {
                LogToConsole("Successfully used Drop the Beat")
                break
            }
        }

        if (LastOpenedTowerID != "" && LastOpenedTowerID != "DJ" && Towers.Has(LastOpenedTowerID)) {
            Click(Towers[LastOpenedTowerID].x, Towers[LastOpenedTowerID].y)
            Sleep 250
        }
        canBeUpgraded := true
        canUseAbility := true
        needtocheckTowerUI := true
    }
}

SetDJTrack(track) {
    global Towers, unfocusX, unfocusY, LastOpenedTowerID
    global canUseAbility, needtocheckTowerUI, PotatoMode

    if (!Towers.Has("DJ")) {
        LogToConsole("DJ tower not found!")
        return false
    }

    cleanTrack := StrReplace(track, Chr(34), "")
    cleanTrack := StrReplace(cleanTrack, "'", "")
    trackName := Format("{:L}", Trim(cleanTrack))
    trackImage := "Resources\" trackName ".png"
    if (trackName = "" || !FileExist(trackImage)) {
        LogToConsole("Unknown DJ track/color: " track, true)
        RuntimeLogWarn("dj_track_invalid", "DJ track image is unavailable", "track=" trackName)
        return false
    }

    LogToConsole("Setting DJ track to " track "...")
    canUseAbility := false
    needtocheckTowerUI := true
    mouseCaptured := false

    try {
        MouseGetPos(&originalMouseX, &originalMouseY)
        mouseCaptured := true

        if (LastOpenedTowerID != "DJ") {
            Click(Towers["DJ"].x, Towers["DJ"].y)
            LastOpenedTowerID := "DJ"
        }
        Sleep(200)

        deadline := A_TickCount + 25000
        attempts := 0
        loop {
            attempts++
            if (A_TickCount >= deadline) {
                LogToConsole("Could not change DJ track to " track " within 25 seconds.", true)
                RuntimeLogWarn("dj_track_timeout", "DJ track control was not reliably detected",
                    "track=" trackName "; attempts=" attempts)
                return false
            }

            getRobloxPos(, , &w, &h)
            towerUiTimeout := (PotatoMode = 1) ? 1800 : 1200
            retryDelay := (PotatoMode = 1) ? 450 : 300
            openedSuccessfully := waitForTowerUI(&resv2, &resv1, towerUiTimeout)
            if (!openedSuccessfully) {
                variation := Random(-8, 8)
                Click(Towers["DJ"].x, Towers["DJ"].y + ScaleY(variation))
                LastOpenedTowerID := "DJ"
                Sleep(retryDelay)
                continue
            }

            DJTrack := AdvancedImageSearch(trackImage, 0, 0, w, h, 0.5, 1.5, 0.05)
            if (DJTrack.status = "success" && DJTrack.score > 0.6) {
                Click(DJTrack.x, DJTrack.y)
                Sleep(400)

                getRobloxPos(, , &w, &h)
                x1 := Round(w * 0.2)
                y1 := Round(h * 0.18)
                x2 := Round(w * 0.7)
                y2 := Round(h * 0.3)
                if (ImageSearch(&fx, &fy, x1, y1, x2, y2, "*Trans000000 *50 " A_WorkingDir "/Resources/please_wait.png") ||
                ReadMessage(["please", "wait"])) {
                    LogToConsole("DJ track is on cooldown. Waiting and retrying...")
                    remainingMs := deadline - A_TickCount
                    if (remainingMs <= 250)
                        continue
                    Sleep(Min(4500, remainingMs - 100))
                    needtocheckTowerUI := true
                    continue
                }

                LogToConsole("Successfully changed DJ track to " track)
                RuntimeLogInfo("dj_track_changed", "DJ track click completed without cooldown",
                    "track=" trackName "; attempts=" attempts)
                return true
            }

            if (Mod(attempts, 3) = 0) {
                Click(ScaleX(unfocusX), ScaleY(unfocusY))
                Sleep(150)
                Click(Towers["DJ"].x, Towers["DJ"].y)
                LastOpenedTowerID := "DJ"
            }
            needtocheckTowerUI := true
            Sleep(250)
        }
    } finally {
        canUseAbility := true
        needtocheckTowerUI := true
        if mouseCaptured
            MouseMove(originalMouseX, originalMouseY)
    }
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

    if (Towers[towerID].HasProp("hwnd") && Towers[towerID].hwnd) {
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

    getRobloxPos(, , &clientLeft, &clientTop)

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
        dist := Sqrt((t.x - mx) ** 2 + (t.y - my) ** 2)
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
    if (type = "WARNING") {
        boxType += 48
    } else {
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

    OverlayWidth := Round(A_ScreenWidth * 0.26)
    OverlayHeight := Round(A_ScreenHeight * 0.185)
    OverlayX := Round(A_ScreenWidth * 0.73)
    OverlayY := Round(A_ScreenHeight * 0.76)

    og := Gui("+AlwaysOnTop +ToolWindow -Caption +E0x20 +E0x08000000 +E0x00000008 +LastFound")
    og.BackColor := "000000"
    og.Title := "DebugOverlay"

    global OverlayPicCtrl := og.Add("Picture", "x0 y0 w" OverlayWidth " h" OverlayHeight " +0xE")
    OverlayPicHWND := OverlayPicCtrl.Hwnd
    OverlayHWND := og.Hwnd

    og.Show("x" OverlayX " y" OverlayY " w" OverlayWidth " h" OverlayHeight " NA")

    WinSetTransColor("0x000000", "ahk_id " OverlayHWND)

    OverlayBitmap := Gdip_CreateBitmap(OverlayWidth, OverlayHeight)
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
    OverlayHWND := 0
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
    hFontOverlay := Gdip_FontCreate(hFamilyOverlay, fontSize, style)
    hFormatOverlay := Gdip_StringFormatCreate(0x0000)

    if (!hFormatOverlay || !hFontOverlay || !hFamilyOverlay) {
        ; These were written as `if (cond) => Func(...)`, which defines a fat-arrow
        ; function instead of calling one, so nothing was ever released here.
        if (hFormatOverlay)
            Gdip_DeleteStringFormat(hFormatOverlay)
        if (hFontOverlay)
            Gdip_DeleteFont(hFontOverlay)
        if (hFamilyOverlay)
            Gdip_DeleteFontFamily(hFamilyOverlay)
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
    pBrushBgOverlay := Gdip_BrushCreateSolid(0xAA000000)

    if (!pBrushTextOverlay || !pBrushBgOverlay) {
        ; Same fat-arrow defect as above: the brushes were never released.
        if (pBrushTextOverlay)
            Gdip_DeleteBrush(pBrushTextOverlay)
        if (pBrushBgOverlay)
            Gdip_DeleteBrush(pBrushBgOverlay)
        Gdip_DeleteStringFormat(hFormatOverlay)
        Gdip_DeleteFont(hFontOverlay)
        Gdip_DeleteFontFamily(hFamilyOverlay)
        return
    }

    maxLines := Floor(OverlayHeight / (fontSize * 1.4))
    startIndex := Max(1, LogLines.Length - maxLines + 1)
    yPos := 5, maxWidth := OverlayWidth - 20

    wrappedLines := []
    loop maxLines {
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
        Gdip_FillRectangle(OverlayGraphics, pBrushBgOverlay, 5, yPos, OverlayWidth - 10, fontSize * 1.4)
        CreateRectF(&RC, 5, yPos, OverlayWidth - 5, fontSize * 1.4)
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

    RuntimeLogConsole(text)

    if (OverlayHWND && WinExist("ahk_id " OverlayHWND))
        UpdateOverlay()

    if (WebhookEnabled && WebhookLink != "" && RunningStrategy) {
        runtime := (AutorunStartTime > 0) ? FormatRuntime(AutorunStartTime) : "00:00"
        wText := "[" runtime "] " text
        if (!SendWebhookInstantly && WebhookDebugLogs) {
            SendToWebhook(wText)
        } else if (SendWebhookInstantly) {
            SendToWebhookInstant(wText, , flush)
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
    diff := Sqrt((r1 - r2) ** 2 + (g1 - g2) ** 2 + (b1 - b2) ** 2)

    if (diff < 3) {
        LogToConsole("Claiming playtime rewards..")
        Click(w - 290, pY + 32)

        Sleep(1000)

        openedMenu := false
        loop 15 {
            getRobloxPos(&pX, &pY, &w, &h)
            X1 := Round(w * 0.2)
            Y1 := Round(h * 0.15)
            W := Round(w * 1) - X1
            H := Round(h * 0.4) - Y1
            resclose := AdvancedImageSearch("Resources\close_freerewards.png", X1, Y1, W, H)

            if (resclose.status = "success" && resclose.score >= 0.86) {
                openedMenu := true
                break
            }
            Sleep(300)
        }

        if (!openedMenu) {
            getRobloxPos(&pX, &pY, &w, &h)
            MouseMove(w - 290, pY + 32, A_DefaultMouseSpeed + 1)
            Sleep(50)
            MouseClick()

            openedMenu := false
            loop 25 {
                getRobloxPos(&pX, &pY, &w, &h)
                X1 := Round(w * 0.2)
                Y1 := Round(h * 0.15)
                W := Round(w * 1) - X1
                H := Round(h * 0.4) - Y1
                resclose := AdvancedImageSearch("Resources\close_freerewards.png", X1, Y1, W, H)

                if (resclose.status = "success" && resclose.score >= 0.86) {
                    openedMenu := true
                    break
                }

                res := AdvancedImageSearch("Resources/Claim.png", Round(w * 0.25), Round(h * 0.4), Round(w * 0.5),
                Round(h * 0.5), 0.5, 2)
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

        loop {
            getRobloxPos(&pX, &pY, &w, &h)

            loop 10 {
                if (PixelSearch(&cx, &cy, Round(w * 0.25), Round(h * 0.2), Round(w * 0.55), Round(h * 0.76), 0x64F711,
                5))
                    break
                else
                    Sleep(100)
            }

            if (!PixelSearch(&cx, &cy, Round(w * 0.25), Round(h * 0.2), Round(w * 0.55), Round(h * 0.76), 0x64F711, 5)) {
                break
            }

            Click(cx, cy)
            rewardsCollected := true
            Sleep(500)

            loop {
                resConfirm := AdvancedImageSearch("Resources/claimreward.png", Round(w * 0.25), Round(h * 0.5), Round(w *
                    0.5), Round(h * 0.5), , 1.5)

                if (resConfirm.status == "success" && resConfirm.score > 0.65) {
                    Click(resConfirm.x, resConfirm.y)
                    MouseMove(ScaleX(unfocusX), ScaleY(unfocusY))
                    Sleep(800)
                } else {
                    Sleep(300)
                    resConfirm := AdvancedImageSearch("Resources/claimreward.png", Round(w * 0.25), Round(h * 0.5),
                    Round(w * 0.5), Round(h * 0.5), , 1.5)
                    if (resConfirm.status == "success" && resConfirm.score > 0.65) {
                        continue
                    }
                    break
                }
            }
        }

        Sleep(800)

        ; OCR.FromRect works in SCREEN space and takes x/y/width/height. This was
        ; being handed client-relative coordinates, so the reward counter was read
        ; from the wrong part of the desktop (or the wrong monitor entirely).
        if !GetRobloxScreenClientRect(&rewClientX, &rewClientY, &w, &h)
            return

        x1 := rewClientX + Round(w * 0.39)
        y1 := rewClientY + Round(h * 0.36)
        x2 := Round(w * 0.22)
        y2 := Round(h * 0.4)

        langCode := "en-US"
        for availableLang in StrSplit(OCR.GetAvailableLanguages(), "`n", "`r") {
            if (availableLang != "" && SubStr(availableLang, 1, 2) = "en") {
                langCode := availableLang
                break
            }
        }

        textOnScreen := ""
        try textOnScreen := OCR.FromRect(x1, y1, x2, y2, { lang: langCode, invertcolors: 1, scale: 2 }).Text
        catch Error as rewErr
            RuntimeLogWarn("playtime_ocr_failed", "Reward counter OCR failed", "error=" rewErr.Message)

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

        if (resclose.status = "success" && resclose.score >= 0.86) {
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
    getRobloxPos(&pX, &pY, &w, &h)
    chatColor := PixelGetColor(pX + 140, pY + 29, "RGB")
    r1 := (chatColor >> 16) & 0xFF, g1 := (chatColor >> 8) & 0xFF, b1 := chatColor & 0xFF
    r2 := 0xF4, g2 := 0xF5, b2 := 0xF8
    diff := Sqrt((r1 - r2) ** 2 + (g1 - g2) ** 2 + (b1 - b2) ** 2)
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
    if (message = "" || Trim(message) = "")
        return

    WebhookQueue.Push(message)
    if (!WebhookTimerActive) {
        WebhookTimerActive := true
        ; Debounce once, then send whatever is queued. Small batches are never
        ; held indefinitely waiting to reach 20 messages.
        SetTimer(ProcessWebhookQueue, -2000)
    }
}

SendToWebhookInstant(message, embedColor := 3447003, flush := true) {
    global WebhookInstantQueue, WebhookInstantTimerActive, WebhookEnabled
    if (!WebhookEnabled || message = "" || Trim(message) = "")
        return

    if (flush)
        FlushWebhookQueue()

    WebhookInstantQueue.Push({ msg: message, color: embedColor })
    if (!WebhookInstantTimerActive) {
        WebhookInstantTimerActive := true
        SetTimer(ProcessWebhookInstantQueue, -100)
    }
}

WebhookEscapeJson(value) {
    value := String(value)
    value := StrReplace(value, "\", "\\")
    value := StrReplace(value, '"', '\"')
    value := StrReplace(value, "`r", "")
    value := StrReplace(value, "`n", "\n")
    value := StrReplace(value, "`t", "\t")
    return value
}

WebhookRetryDelayMs(whr, responseText := "") {
    seconds := 0

    try {
        parsed := JSON.parse(responseText)
        if parsed.Has("retry_after") && IsNumber(parsed["retry_after"])
            seconds := Number(parsed["retry_after"])
    }

    if (seconds <= 0) {
        try {
            header := Trim(whr.GetResponseHeader("Retry-After"))
            if IsNumber(header)
                seconds := Number(header)
        }
    }

    if (seconds <= 0) {
        try {
            header := Trim(whr.GetResponseHeader("X-RateLimit-Reset-After"))
            if IsNumber(header)
                seconds := Number(header)
        }
    }

    if (seconds <= 0)
        seconds := 1

    return Min(30000, Max(500, Ceil(seconds * 1000) + 150))
}

PostWebhookJson(url, payload, maxAttempts := 3) {
    global ver
    if (url = "")
        return false

    loop maxAttempts {
        try {
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("POST", url, false)
            whr.SetRequestHeader("Content-Type", "application/json")
            whr.SetRequestHeader("User-Agent", "Ultimate-Macro-New-Era/" ver)
            whr.SetTimeouts(5000, 5000, 10000, 10000)
            whr.Send(payload)

            status := whr.Status
            responseText := whr.ResponseText

            if (status >= 200 && status < 300)
                return true

            if (status = 429) {
                if (A_Index < maxAttempts) {
                    Sleep(WebhookRetryDelayMs(whr, responseText))
                    continue
                }
                return false
            }

            if (status >= 500 && status <= 599) {
                if (A_Index < maxAttempts) {
                    Sleep(Min(5000, 750 * A_Index))
                    continue
                }
                return false
            }

            return false
        } catch Error {
            if (A_Index >= maxAttempts)
                return false
            Sleep(Min(5000, 750 * A_Index))
        }
    }

    return false
}

PostWebhookDescription(url, description, color := 3447003, codeBlock := false) {
    ; Discord embed descriptions are limited to 4096 characters. Keep a margin
    ; for code fences and split large debug batches instead of receiving HTTP 400.
    maxChars := codeBlock ? 3600 : 3900
    remaining := String(description)

    if (remaining = "")
        return true

    while (StrLen(remaining) > 0) {
        chunk := SubStr(remaining, 1, maxChars)
        remaining := SubStr(remaining, maxChars + 1)
        escaped := WebhookEscapeJson(chunk)
        fence := Chr(96) Chr(96) Chr(96)
        rendered := codeBlock ? (fence "\n" escaped "\n" fence) : escaped
        payload := '{"embeds":[{"description":"' rendered '","color":' color '}]}'
        if !PostWebhookJson(url, payload)
            return false
    }

    return true
}

ProcessWebhookInstantQueue() {
    global WebhookInstantQueue, WebhookInstantTimerActive, WebhookLink

    if (WebhookInstantQueue.Length = 0) {
        WebhookInstantTimerActive := false
        return
    }

    allMessages := ""
    finalColor := 3447003
    hasCustomColor := false

    while (WebhookInstantQueue.Length > 0) {
        item := WebhookInstantQueue.RemoveAt(1)
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
        if (InStr(lower, "error") || InStr(lower, "failed") || InStr(lower, "reloading"))
            finalColor := 15158332
        else if (InStr(lower, "success") || InStr(lower, "completed"))
            finalColor := 3066993
        else if (InStr(lower, "warning"))
            finalColor := 16776960
    }

    PostWebhookDescription(WebhookLink, allMessages, finalColor, false)
}

ProcessWebhookQueue() {
    global WebhookQueue, WebhookTimerActive, WebhookLink

    if (WebhookQueue.Length = 0) {
        WebhookTimerActive := false
        return
    }

    allMessages := ""
    batchCount := Min(20, WebhookQueue.Length)

    loop batchCount {
        msg := WebhookQueue.RemoveAt(1)
        if (Trim(msg) = "")
            continue
        allMessages .= (allMessages != "") ? "`n" msg : msg
    }

    if (allMessages != "")
        PostWebhookDescription(WebhookLink, allMessages, 9868950, true)

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
        allMessages .= (allMessages != "") ? "`n" msg : msg
    }

    if (allMessages != "")
        PostWebhookDescription(WebhookLink, allMessages, 9868950, true)
}

; Release anything the macro may be physically holding down. AutoHotkey does not
; do this on Reload/ExitApp, so a stop during AlignCamera (right-drag) or a
; movement step left the button or key stuck for the user afterwards.
ReleaseHeldInput() {
    global MoveDirection, CancelPlacementKey
    try Click("Right Up")
    try Click("Up")
    for k in ["o", "w", "a", "s", "d", "Shift", "Ctrl", "Left", "Right", "Up", "Down"] {
        try SendEvent("{" k " up}")
    }
    if (IsSet(MoveDirection) && MoveDirection != "")
        try SendEvent("{" MoveDirection " up}")
}

SafeReload() {
    global RestartLock, StateFile, RunningStrategy, OverlayHWND, MainGui
    if (RestartLock) {
        return
    }
    RestartLock := true

    ; Stop every recurring thread first. These used to keep firing (clicking and
    ; sending keys into Roblox) during the blocking webhook flush below.
    try SetTimer(UseAbilities, 0)
    try SetTimer(checkCondition, 0)
    try SetTimer(CheckPopups, 0)
    try SetTimer(CancelInviteIfAppeared, 0)
    try SetTimer(Hoverwatchdog, 0)
    try SetTimer(ProcessCommands, 0)

    ReleaseHeldInput()

    KillSubmacros()
    if (OverlayHWND) {
        WinClose("ahk_id " OverlayHWND)
    }

    DeleteAllIndicators()
    if (RunningStrategy) {
        currentStrat := IniRead(StateFile, "State", "Strategy", "")
        if (currentStrat != "") {
            IniWrite(1, StateFile, "State", "Running")
        }
    }

    FlushWebhookQueue()

    ; Destroy the GUI only once the slow work is done, so a failure above still
    ; leaves a usable window instead of a headless, permanently locked process.
    if (IsSet(MainGui) && MainGui) {
        try MainGui.Destroy()
    }

    Reload()

    ; Reload() is asynchronous. If the process is still alive shortly after, the
    ; reload did not take - clear the lock so recovery can be attempted again
    ; rather than leaving the macro wedged forever.
    SetTimer(ClearRestartLock, -4000)
}

ClearRestartLock() {
    global RestartLock
    RestartLock := false
    RuntimeLogWarn("reload_did_not_take", "Reload() did not replace the process; restart lock cleared")
}

; Progress heartbeat consumed by submacros\watchdog.ahk.
;
; This deliberately records PHASE TRANSITIONS, not liveness. A plain "still
; alive" ping would keep ticking from a timer even while the main thread was
; wedged in a retry loop - which is exactly the failure this exists to catch.
; Each phase declares how long it may legitimately take; the watchdog restarts
; Main when that budget is exceeded with no transition.
MacroPhase(name, timeoutMs) {
    global StateFile
    try {
        IniWrite(name, StateFile, "State", "HeartbeatPhase")
        IniWrite(A_TickCount, StateFile, "State", "HeartbeatTick")
        IniWrite(timeoutMs, StateFile, "State", "HeartbeatTimeout")
    }
}

startWatchdog() {
    global watchdogPID
    KillSubmacros()

    currentPID := DllCall("GetCurrentProcessId")
    watchdogExe := A_ScriptDir "\submacros\" (A_PtrSize == 4 ? "AutoHotkey32.exe" : "AutoHotkey64.exe")
    watchdogScript := A_ScriptDir "\submacros\watchdog.ahk"
    command := '"' watchdogExe '" "' watchdogScript '" ' currentPID
    newWatchdogPID := 0

    try {
        Run(command, , , &newWatchdogPID)
        if (!IsSet(newWatchdogPID) || newWatchdogPID = "" || newWatchdogPID <= 0)
            throw Error("Run did not return a watchdog process ID.")

        watchdogPID := newWatchdogPID
        RuntimeLogInfo("watchdog_started", "Watchdog process launched",
            "watchdog_pid=" watchdogPID "; main_pid=" currentPID)
        return true
    } catch Error as err {
        watchdogPID := ""
        RuntimeLogError("watchdog_start_failed", "Could not launch watchdog; Main will continue without it",
            "main_pid=" currentPID "; error=" err.Message)
        return false
    }
}

KillSubmacros() {
    global watchdogPID

    trackedPID := ""
    if (IsSet(watchdogPID) && watchdogPID != "")
        trackedPID := watchdogPID

    ; Publish the idle state before cleanup so repeated calls are idempotent.
    watchdogPID := ""

    ; Prefer the exact PID returned when this installation launched watchdog.
    if (trackedPID != "") {
        try {
            if ProcessExist(trackedPID) {
                ProcessClose(trackedPID)
                RuntimeLogInfo("watchdog_stopped", "Stopped tracked watchdog process",
                    "watchdog_pid=" trackedPID "; source=tracked_pid")
            }
        } catch Error as err {
            RuntimeLogWarn("watchdog_cleanup_failed", "Could not close tracked watchdog process",
                "watchdog_pid=" trackedPID "; source=tracked_pid; error=" err.Message)
        }
    }

    ; Fallback cleanup is path-scoped so another checkout/instance is untouched.
    targetScript := StrLower(StrReplace(A_ScriptDir "\submacros\watchdog.ahk", "/", "\"))
    pathClosed := 0
    try {
        for process in ComObjGet("winmgmts:").ExecQuery(
            "SELECT * FROM Win32_Process WHERE Name = 'AutoHotkey64.exe' OR Name = 'AutoHotkey.exe' OR Name = 'AutoHotkey32.exe'"
        ) {
            try {
                cmd := process.CommandLine
                if (cmd = "")
                    continue
                normalizedCmd := StrLower(StrReplace(cmd, "/", "\"))
                if InStr(normalizedCmd, targetScript) {
                    try {
                        ProcessClose(process.ProcessId)
                        pathClosed += 1
                    } catch Error as err {
                        RuntimeLogWarn("watchdog_cleanup_failed", "Could not close path-scoped watchdog process",
                            "watchdog_pid=" process.ProcessId "; source=path_scan; error=" err.Message)
                    }
                }
            }
        }
    } catch Error as err {
        RuntimeLogWarn("watchdog_cleanup_scan_failed", "Could not scan for path-scoped watchdog processes",
            "target=" targetScript "; error=" err.Message)
    }

    if (pathClosed > 0)
        RuntimeLogInfo("watchdog_stopped", "Stopped path-scoped watchdog process",
            "count=" pathClosed "; source=path_scan")
}

HandleExit(ExitReason, ExitCode) {
    global StateFile, SettingsFile, RunningStrategy, AutoConfigureSettings

    ; Never leave a mouse button or movement key latched down for the user.
    try ReleaseHeldInput()
    
    if (AutoConfigureSettings) {
        ; If Roblox is currently open, run the helper script in the background
        if (ProcessExist("RobloxPlayerBeta.exe")) {
            ; Use the bundled AHK executable to launch the helper script
            helperExe := A_ScriptDir "\submacros\" (A_PtrSize == 4 ? "AutoHotkey32.exe" : "AutoHotkey64.exe")
            helperScript := A_ScriptDir "\lib\auto_settings.ahk"
            
            if FileExist(helperExe) && FileExist(helperScript) {
                Run('"' helperExe '" /restart "' helperScript '"')
            } else {
                ; Fallback just in case the executable is missing
                RestoreOriginalSettings()
            }
        } else {
            ; Roblox is already closed, safe to restore immediately
            RestoreOriginalSettings()
        }
    }
	
    try KillSubmacros()
    catch Error as err
        RuntimeLogWarn("watchdog_exit_cleanup_failed", "Watchdog cleanup failed during Main exit",
            "reason=" ExitReason "; error=" err.Message)

    if (IsSet(RunningStrategy) && RunningStrategy) {
        if (ExitReason = "Close" || ExitReason = "Menu" || ExitReason = "Shutdown" || ExitReason = "Logoff") {
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
            IniDelete(StateFile, "State", "HeartbeatPhase")
            IniDelete(StateFile, "State", "HeartbeatTick")
            IniDelete(StateFile, "State", "HeartbeatTimeout")
        }
    }
}

CleanupGdip(exitReason, exitCode) {
    global pToken, RenderedBitmaps
    ; Clean up any remaining bitmaps
    CleanupRenderedBitmaps()
    Gdip_Shutdown(pToken)
}

MainGui.OnEvent("Close", (*) => ExitApp())

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

SendScreenshot(pBitmap := CaptureRobloxClientBitmap(), description := "", color := 12434877, screenshot := WebhookScreenshots) {
    global WebhookLink

    escapedDescription := WebhookEscapeJson(description)
    fields := []

    if (screenshot == "0" || screenshot == 0 || !pBitmap) {
        payload_json := '{"embeds": [{"description": "' escapedDescription '", "color": ' color '}]}'
        fields.Push(Map("name", "payload_json", "content-type", "application/json", "content", payload_json))
    } else {
        payload_json := '{"embeds": [{"description": "' escapedDescription '", "color": ' color ', "image": {"url": "attachment://screenshot.png"}}]}'
        fields.Push(Map("name", "payload_json", "content-type", "application/json", "content", payload_json))
        fields.Push(Map("name", "files[0]", "filename", "screenshot.png", "content-type", "image/png", "pBitmap", pBitmap))
    }

    CreateFormData(&postdata, &contentType, fields)
    return PostWebhookMultipart(WebhookLink "?wait=true", postdata, contentType)
}

PostWebhookMultipart(url, postdata, contentType, maxAttempts := 3) {
    global ver

    loop maxAttempts {
        try {
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("POST", url, false)
            whr.SetRequestHeader("Content-Type", contentType)
            whr.SetRequestHeader("User-Agent", "Ultimate-Macro-New-Era/" ver)
            whr.SetTimeouts(5000, 5000, 15000, 15000)
            whr.Send(postdata)

            status := whr.Status
            responseText := whr.ResponseText
            if (status >= 200 && status < 300)
                return true

            if (status = 429) {
                if (A_Index < maxAttempts) {
                    Sleep(WebhookRetryDelayMs(whr, responseText))
                    continue
                }
                return false
            }

            if (status >= 500 && status <= 599) {
                if (A_Index < maxAttempts) {
                    Sleep(Min(5000, 750 * A_Index))
                    continue
                }
                return false
            }

            return false
        } catch Error as err {
            if (A_Index >= maxAttempts) {
                LogToConsole("Screenshot webhook failed: " err.Message)
                return false
            }
            Sleep(Min(5000, 750 * A_Index))
        }
    }
    return false
}

CreateFormData(&retData, &contentType, fields) {
    chars := "0123456789abcdefghijklmnopqrstuvwxyz"
    boundary := ""
    loop 12 {
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
                DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64*", &size := 0, "UInt")
                DllCall("shlwapi\IStream_Reset", "Ptr", pFileStream, "UInt")
                DllCall("shlwapi\IStream_Copy", "Ptr", pFileStream, "Ptr", pStream, "UInt", size, "UInt")
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
    size := DllCall("GlobalSize", "Ptr", hData, "UPtr")
    retData := ComObjArray(0x11, size)
    pvData := NumGet(ComObjValue(retData), 8 + A_PtrSize, "Ptr")
    DllCall("RtlMoveMemory", "Ptr", pvData, "Ptr", pData, "Ptr", size)
    DllCall("GlobalUnlock", "Ptr", hData)
    DllCall("GlobalFree", "Ptr", hData, "Ptr")
    contentType := "multipart/form-data; boundary=----------------------------" boundary
}

InArray(arr, value) {
    for item in arr
        if (item = value)
            return true
    return false
}

CreateGradientButton(w, h, r, colorStart, colorEnd, shadowColor, strokeColor, btnText := "...", textFont := "",
    textSize := 12, gradientDirection := 0) {
    if (textFont = "")
        textFont := UIFont()

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

    loop 6 {
        alpha := Format("{:02X}", Integer(25 / A_Index))
        currentShadow := "0x" alpha SubStr(shadowColor, -6)
        pBrushShadow := Gdip_BrushCreateSolid(currentShadow)

        offset := A_Index * 0.7
        pPathShadow := Gdip_CreateRoundRectanglePath(bx - (offset * 0.5), by + offset, bw + offset, bh, r)
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

CreateScrollThumb(w, h, r, colorStart, colorEnd, glowColor) {
    hbm := CreateDIBSection(w, h), hdcMem := CreateCompatibleDC()
    obm := SelectObject(hdcMem, hbm), G := Gdip_GraphicsFromHDC(hdcMem)
    Gdip_SetSmoothingMode(G, 4)

    loop 3 {
        alpha := Format("{:02X}", Integer(30 / A_Index))
        pBrush := Gdip_BrushCreateSolid("0x" alpha SubStr(glowColor, -6))
        pPath := Gdip_CreateRoundRectanglePath(0, A_Index * 0.5, w, h, r)
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

    loop 5 {
        alpha := Format("{:02X}", Integer(15 - (A_Index * 2)))
        currentGlow := SubStr(glowColor, 1, 4) . alpha . SubStr(glowColor, 7)

        pBrushGlow := Gdip_BrushCreateSolid(currentGlow)
        pPathGlow := Gdip_CreateRoundRectanglePath(bx - A_Index, by - A_Index, bw + (A_Index * 2), bh + (A_Index * 2),
        r)
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
    DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", x, "float", y, "float", r * 2, "float", r * 2, "float",
        180, "float", 90)
    DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", x + w - r * 2, "float", y, "float", r * 2, "float", r * 2,
        "float", 270, "float", 90)
    DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", x + w - r * 2, "float", y + h - r * 2, "float", r * 2,
        "float", r * 2, "float", 0, "float", 90)
    DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", x, "float", y + h - r * 2, "float", r * 2, "float", r * 2,
        "float", 90, "float", 90)
    DllCall("gdiplus\GdipClosePathFigure", "ptr", pPath)
    return pPath
}

StratInfo(title := "unknown strat", author := "darksen", RequiredTowrs := "error", modifs := "none", desc := "") {
    text := title " by " author "`n"
    text .= "-----------------------------------------`n`n"
    text .= "Required towers:`t" RequiredTowrs "`n"
    text .= "Modifiers:`t" modifs "`n`n"

    if (desc != "")
        text .= desc "`n`n"

    text .= "-----------------------------------------`n"
    text .= "* To edit the strategy, open the strat file in the notepad.`n"

    MsgBox(text, "Strategy Info | " title, 0x1040)
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

    ; Gdip_BitmapFromScreen takes SCREEN coordinates. Feeding it the client-relative
    ; rect (origin 0,0) captured the wrong area on every non-origin window and the
    ; wrong monitor entirely on multi-monitor setups, so this OCR fallback silently
    ; read blank pixels for every "cannot place here" / "no cash" / "stunned" check.
    if !GetRobloxScreenClientRect(&clientX, &clientY, &w, &h)
        return false

    x := clientX + Round(w * 0.2)
    y := clientY + Round(h * 0.18)
    width := Round(w * 0.7) - Round(w * 0.2)
    height := Round(h * 0.35) - Round(h * 0.18)

    if (width <= 0 || height <= 0)
        return false

    pBitmap := 0, pGraphics := 0, pBitmapFiltered := 0, pGraphicsFiltered := 0, hBitmap := 0
    ocrText := ""

    ; try/finally: an OCR throw used to leak all five GDI/GDI+ handles, and this
    ; runs inside 4.5s retry loops that can execute hundreds of times per session.
    try {
        pBitmap := Gdip_BitmapFromScreen(x "|" y "|" width "|" height)
        if !pBitmap
            return false
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

        ocrText := OCR.FromBitmap(hBitmap, { lang: langCode, scale: 3, grayscale: 1 }).Text
    } catch Error as ocrErr {
        RuntimeLogWarn("readmessage_ocr_failed", "Message OCR failed", "error=" ocrErr.Message)
        return false
    } finally {
        if hBitmap
            DeleteObject(hBitmap)
        if pGraphicsFiltered
            Gdip_DeleteGraphics(pGraphicsFiltered)
        if pBitmapFiltered
            Gdip_DisposeImage(pBitmapFiltered)
        if pGraphics
            Gdip_DeleteGraphics(pGraphics)
        if pBitmap
            Gdip_DisposeImage(pBitmap)
    }

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
    loop {
        getRobloxPos(&rx, &ry, &w, &h)
        X1_v2 := Round(w * 0.02)
        Y1_v2 := Round(h / 2.5)
        W_v2 := Round(w * 0.22) - X1_v2
        ; Height must be derived from h, not w. Using the width here produced a
        ; region extending far past the bottom of the client (y ~1824 at 1920x1009).
        H_v2 := Round(h * 0.95) - Y1_v2

        resV2 := AdvancedImageSearch("Resources\TowerUI\Variant2.png", X1_v2, Y1_v2, W_v2, H_v2, , , 0.05)

        if (resV2.status == "success" && resV2.score > 0.55) {
            return true
        }

        Sleep(30)

        X1_v1 := Round(w * 0.16)
        Y1_v1 := Round(h * 0.05)
        W_v1 := Round(w * 0.2) - X1_v1
        H_v1 := Round(h * 0.3) - Y1_v1
        resV1 := AdvancedImageSearch("Resources\TowerUI\Variant1.png", X1_v1, Y1_v1, W_v1, H_v1, , , 0.05)

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

ProcessCommands(*) {
    global command_buffer, UserID, RunningStrategy, ChannelID

    Discord.GetCommands(ChannelID)

    for command in command_buffer {
        content := command.content

        if (content == "!help") {
            Discord.SendEmbed(
                "**Available commands:**\n" .
                "\n!help - shows the help menu" .
                "\n!screenshot - take and send a screenshot" .
                "\n!status - view macro status and statistics" .
                "\n!stop - stop the macro" .
                "\n!start - start the macro"
            )
        }
        else if (content == "!screenshot") {
            pBitmap := CaptureRobloxClientBitmap()
            Discord.SendScreenshot(pBitmap, "Requested Screenshot")
            Gdip_DisposeImage(pBitmap)
        }
        else if (content == "!status") {
            status := "stopped"
            if (RunningStrategy)
                status := "working"

            savedCoins := IniRead(StateFile, "State", "Coins", 0)
            savedGems := IniRead(StateFile, "State", "Gems", 0)
            savedExp := IniRead(StateFile, "State", "EXP", 0)

            totalTriumphs := IniRead(StateFile, "State", "TotalTriumphs", 0)
            totalLosses := IniRead(StateFile, "State", "TotalLosses", 0)
            totalMatches := totalTriumphs + totalLosses
            winrate := (totalMatches > 0) ? Round((totalTriumphs / totalMatches) * 100) : 0
            wlRatio := (totalLosses > 0) ? Round(totalTriumphs / totalLosses, 1) : totalTriumphs

            runtime := FormatRuntime(AutorunStartTime)

            autorunStart := IniRead(StateFile, "State", "StartTime", 0)
            coinsPerHour := 0, gemsPerHour := 0, expPerHour := 0
            if (autorunStart > 0) {
                elapsedMs := A_TickCount - autorunStart
                elapsedHours := elapsedMs / 3600000
                if (elapsedHours > 0.001) {
                    coinsPerHour := Round(savedCoins / elapsedHours)
                    gemsPerHour := Round(savedGems / elapsedHours)
                    expPerHour := Round(savedExp / elapsedHours)
                }
            }

            currentStrategy := IniRead(StateFile, "State", "Strategy", "")

            SplitPath(currentStrategy, &stratName)

            if (RunningStrategy) {
                statusMsg := "**Macro Status:** Working\n"
                statusMsg .= "**Runtime:** " runtime "\n\n"
                statusMsg .= "**Current Strategy:** " stratName "\n\n"
                statusMsg .= "+" savedCoins " **Coins**\t+" savedGems " **Gems**\t+" savedExp " **EXP**\n"
                statusMsg .= coinsPerHour " Coins/h\t" gemsPerHour " Gems/h\t" expPerHour " EXP/h\n\n"
                statusMsg .= "**Total Matches:** " totalMatches "\t**Wins:** " totalTriumphs "\t**Losses:** " totalLosses "\n"
                statusMsg .= "**Winrate:** " winrate "%\t**W/L Ratio:** " wlRatio
            } else {
                statusMsg := "**Macro Status:** Stopped"
            }

            currentTime := A_Hour ":" A_Min ":" A_Sec
            statusMsg .= "\n-# Ultimate Macro Bot • " currentTime

            Discord.SendEmbed(statusMsg, "3447003")
        }
        else if (content == "!stop") {
            if (RunningStrategy) {
                Discord.SendEmbed("Stopping the macro..", "56320")
                id := Discord.GetMessageAPI()
                StopStrategy()
            } else {
                Discord.SendEmbed("Failed to stop: the macro is not running!", "16515072")
            }
        }
        else if (content == "!start") {
            if (RunningStrategy) {
                Discord.SendEmbed("Failed to start: the macro is already running!", "16515072")
            } else {
                Discord.SendEmbed("Starting the macro..", "56320")
                SetTimer(StartStrategy, -100)
            }
        }
    }

    command_buffer := []
}
