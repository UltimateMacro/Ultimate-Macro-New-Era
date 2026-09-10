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
#Include *i lib\Profiles.ahk
#Include lib\Discord.ahk
#Include *i lib\DiscordCommands.ahk
#Include lib\OfficialRemote.ahk
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

    Reload()
    ExitApp()
}

command_buffer := []
global BotStrategyChoices := []
global BotStrategyChoiceTime := 0

ver := "1.3.5"

RuntimeLogInstall("Main", ver)

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

global RunningStrategy := false
global Recording := false
global MacroRecording := false
global InputHookObj := ""
global AutorunStartTime := 0
global RenderedBitmaps := []

pToken := Gdip_Startup()
OnExit(CleanupGdip)
OnExit(HandleExit)
OnMessage(0x84, DebugOverlayHitTest)

global AppDataOpt := A_AppData "\Ultimate_Macro\Options"
global SettingsFile := AppDataOpt "\Settings.tds"
global BotSettings := AppDataOpt "\Discord-Bot-Settings.ini"
global RecordingsDir := A_AppData "\Ultimate_Macro\Recordings"
global ProfilesDir := A_AppData "\Ultimate_Macro\Profiles"
global StateFile := A_AppData "\Ultimate_Macro\state.ini"

global StratsDir := A_WorkingDir "\Resources\Strats"

global ShowIndicators := true

global DarkInputSurfaces := Map()
global ToolPreviewWatch := Map()
global HoverHostHwnds := Map()
global HotkeyFields := []
global ActiveHotkeyCapture := 0

global WebhookCheckedLink := ""
global WebhookCheckedState := ""
global WebhookLink2Checked := ""

global WebhookQueue := []
global WebhookTimerActive := false
global WebhookInstantQueue := []
global WebhookInstantTimerActive := false

if !DirExist(AppDataOpt)
    DirCreate(AppDataOpt)
if !DirExist(RecordingsDir)
    DirCreate(RecordingsDir)
if !DirExist(ProfilesDir)
    DirCreate(ProfilesDir)

global VipLink := IniRead(SettingsFile, "Options", "VipLink", "")
global UseVipServer := IniRead(SettingsFile, "Options", "UseVipServer", "0")
global AlwaysOnTop := IniRead(SettingsFile, "Options", "AlwaysOnTop", 0)

global LegacyMode := IniRead(SettingsFile, "Options", "LegacyMode", 0)

global WebhookLink := IniRead(SettingsFile, "Webhook", "Link", "")
global WebhookLink2 := IniRead(SettingsFile, "Webhook", "Link2", "")
global WebhookEnabled := IniRead(SettingsFile, "Webhook", "Enabled", 0)
global PotatoMode := IniRead(SettingsFile, "Options", "PotatoMode", 0)
global SendCurrenciesEnabled := IniRead(SettingsFile, "Webhook", "SendCurrencies", "1")
global WebhookDebugLogs := IniRead(SettingsFile, "Webhook", "WebhookDebugLogs", "1")
global WebhookScreenshots := IniRead(SettingsFile, "Webhook", "WebhookScreenshots", "1")
global WebhookTriumphScreenshots := IniRead(SettingsFile, "Webhook", "WebhookTriumphScreenshots", 1)
global WebhookSepatateTriumphScreenshots := IniRead(SettingsFile, "Webhook", "WebhookSepatateTriumphScreenshots", 0)
global BotToken := IniRead(BotSettings, "Token", "BotToken", "")
global BotEnabled := IniRead(BotSettings, "Settings", "Enabled", 0)
global ChannelID := IniRead(BotSettings, "Settings", "Channel", "")
global UserID := IniRead(BotSettings, "Settings", "UserID", "")
global BotPrefix := IniRead(BotSettings, "Settings", "Prefix", "!")
global AutoEquip := IniRead(SettingsFile, "Options", "AutoEquip", 0)
global AutoConfigureSettings := IniRead(SettingsFile, "Options", "AutoConfigureSettings", 0)
global UseRestartBtn := IniRead(SettingsFile, "Options", "UseRestartBtn", "1")
global UsePlayAgainBtn := IniRead(SettingsFile, "Options", "UsePlayAgainBtn", "1")
global RotateStrategies := IniRead(SettingsFile, "Options", "RotateStrategies", 0)
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

if !RecoverPendingAutoSettings(A_ScriptDir) {
    RuntimeLogWarn("auto_settings_restore_pending", "A Roblox settings backup was preserved and needs attention",
        "detail=" GetAutoSettingsLastError())
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
global DebugConsole := IniRead(SettingsFile, "Options", "DebugConsole", "0")

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
global RecordedTowerIds := Map()
global modifiers := ""
global LastOpenedTowerID := ""
global IsRestarting := false
global RestartLock := false
global PendingSettingSaves := Map()
global PartyInviteBusy := false

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
SC_E := "sc012"

if (DebugConsole = "1")
    ShowDebugConsole()

IconPath := A_WorkingDir "\icon.ico"
if FileExist(IconPath)
    TraySetIcon(IconPath)

WM_LBUTTONDOWN_Drag(wParam, lParam, msg, hwnd) {
    global MainGui

    if (TryBeginScrollDrag())
        return 0

    if (MainGui) {
        if (hwnd != MainGui.Hwnd)
            return
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

RegisterRecordingHotkeys(oldKeys := "") {
    global PlaceTowerKey, UpgradeTowerKey, ChangeDJTrackKey, DeleteTowerRecordingKey, IsRecordingActive
    global SellTowerKey, AlignCameraKey, RecordInputsKey, HoloKey, ChangeTargetsKey, RepoKey, RaiseDeadKey, UpgradeTowerGKey

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
        RecordMacroStep("Sleep(" elapsed ")")
        RecordMacroStep("Click(" mx ", " my ")")
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
                RecordStep("UpgradeTower(" towerID ", false, 1, " Towers[towerID].path ", " Towers[towerID].pathLevel ")"
                )
            } else {
                RecordStep("UpgradeTower(" towerID ")")
            }

            if (Towers[towerID].level >= 2 && RegExMatch(towerID, "i)^Commander\d*$") && !Commander) {
                Commander := true
                if (!HasStep("Commander := true"))
                    RecordStep("Commander := true")
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
    if (Width = 0)
        return baseX
    getRobloxPos(&pX, &pY, &currentWidth, &currentHeight)
    return currentWidth > 0 ? Round(baseX * (currentWidth / Width)) : baseX
}

ScaleY(baseY, Height := 1009) {
    if (Height = 0)
        return baseY
    getRobloxPos(&pX, &pY, &currentWidth, &currentHeight)
    return currentHeight > 0 ? Round(baseY * (currentHeight / Height)) : baseY
}

sX(baseX, Width := 1920) {
    global StrategyHeight
    hwnd := GetRobloxHWND()
    if !hwnd
        return baseX

    getRobloxPos(&pX, &pY, &currentWidth, &currentHeight, hwnd)
    if (Width == 0 || currentWidth <= 0)
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
        return baseY
    getRobloxPos(&pX, &pY, &currentWidth, &currentHeight, hwnd)
    if (Height == 0 || currentHeight <= 0)
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

SaveSetting(file, section, key, value) {
    try {
        IniWrite(value, file, section, key)
    } catch Error as err {
        RuntimeLogWarn("setting_write_failed", "A setting could not be persisted",
            "section=" section "; key=" key "; error=" err.Message)
    }
    return value
}

SaveOption(key, value) {
    global SettingsFile
    return SaveSetting(SettingsFile, "Options", key, value)
}

QueueSettingSave(name, saver, delayMs) {
    global PendingSettingSaves
    PendingSettingSaves[name] := saver
    SetTimer(saver, -delayMs)
}

ClearPendingSettingSave(name) {
    global PendingSettingSaves
    try PendingSettingSaves.Delete(name)
}

FlushPendingSettingSaves() {
    global PendingSettingSaves

    if (!IsSet(PendingSettingSaves) || PendingSettingSaves.Count = 0)
        return

    pending := PendingSettingSaves
    PendingSettingSaves := Map()

    for name, saver in pending {
        try SetTimer(saver, 0)
        try saver()
        catch Error as err
            RuntimeLogWarn("setting_flush_failed", "A pending setting could not be flushed before the macro continued",
                "setting=" name "; error=" err.Message)
    }
}

SaveHotkeySetting(key, value) {
    global SettingsFile
    return SaveSetting(SettingsFile, "Hotkeys", key, value)
}

SaveRecordingHotkeySetting(key, value) {
    global SettingsFile
    return SaveSetting(SettingsFile, "RecordingHotkeys", key, value)
}

SaveWebhookSetting(key, value) {
    global SettingsFile
    return SaveSetting(SettingsFile, "Webhook", key, value)
}

SaveMultiplayerSetting(key, value) {
    global SettingsFile
    return SaveSetting(SettingsFile, "Multiplayer", key, value)
}

SaveBotSetting(section, key, value) {
    global BotSettings
    return SaveSetting(BotSettings, section, key, value)
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
    if !RunStrategy() {
        if (RunningStrategy) {
            RuntimeLogError("strategy_lifecycle_failed", "Strategy lifecycle ended before completing its transition")
            StopStrategy()
        }
    }
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
global HelpTips := Map()
global HelpTipGui := 0
global HelpTipOwner := 0
global GradientButtons := []

global Tab3 := []

global DiscordNavTab := []
global DiscordWebhookTab := []
global DiscordBotTab := []
global DiscordRemoteTab := []
global DiscordPage := "Webhook"

tabNames := ["Main", "Create", "(Beta) Party", "Discord", "Settings", "Tools", "Credits"]

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

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global Tab1_Section1 := MainGui.Add("Text", "x30 y95  w200 h22", "Custom Strategies")
global Tab1_Line1 := MainGui.Add("Progress", "x30 y118 w640 h1  Background333333", 0)

MainGui.SetFont("s9 w400 cAAAAAA", UIFont())
global Tab1_Lbl1 := MainGui.Add("Text", "x30 y130 w76 h22 0x200 BackgroundTrans", "Strategy:")
MainGui.SetFont("s9 w400 c000000")
global Strategy1Ctrl := MainGui.Add("Edit", "x110 y130 w402 h22 vStrategy1", Strategy1Path)
Strategy1Ctrl.OnEvent("Change", SaveStrat1)
MainGui.SetFont("s9 w400 cFFFFFF")
global Tab1_Btn1 := MainGui.Add("Text", "x522 y130 w70 h22 +Border 0x200 Center", "Browse")
Tab1_Btn1.OnEvent("Click", SelectStrat1)
global Tab1_Btn2 := MainGui.Add("Text", "x600 y130 w70 h22 +Border 0x200 Center", "Clear")
Tab1_Btn2.OnEvent("Click", ClearStrat1)

RegisterHoverEffect(Tab1_Btn1)
RegisterHoverEffect(Tab1_Btn2)

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab1_Lbl2 := MainGui.Add("Text", "x30 y160 w76 h22 0x200 BackgroundTrans", "Strategy 2:")
MainGui.SetFont("s9 w400 c000000")
global Strategy2Ctrl := MainGui.Add("Edit", "x110 y160 w402 h22 vStrategy2", Strategy2Path)
Strategy2Ctrl.OnEvent("Change", SaveStrat2)
MainGui.SetFont("s9 w400 cFFFFFF")
global Tab1_Btn3 := MainGui.Add("Text", "x522 y160 w70 h22 +Border 0x200 Center", "Browse")
Tab1_Btn3.OnEvent("Click", SelectStrat2)
global Tab1_Btn4 := MainGui.Add("Text", "x600 y160 w70 h22 +Border 0x200 Center", "Clear")
Tab1_Btn4.OnEvent("Click", ClearStrat2)

RegisterHoverEffect(Tab1_Btn3)
RegisterHoverEffect(Tab1_Btn4)

MainGui.SetFont("s9 w400 cFFFFFF")
global RotateStrategiesCtrl := MainGui.Add("Checkbox", "x30 y192 w140 h22 vRotateStrategies Checked" RotateStrategies,
    "Strategy Rotation")
RotateStrategiesCtrl.OnEvent("Click", EnableStratRotation)

MainGui.SetFont("s9 w400 cAAAAAA")
global SwapAfterLbl := MainGui.Add("Text", "x175 y192 w70 h22 0x200 BackgroundTrans", "Swap after:")

MainGui.SetFont("s9 w400 c000000")
global SwapAmountCtrl := MainGui.Add("Edit", "x247 y192 w44 h22 +Border Number Center vSwapAmount", SwapAmount)

SwapAmountCtrl.OnEvent("Change", (*) => (
    SwapAmount := SwapAmountCtrl.Text,
    SaveOption("SwapAmount", SwapAmount)
))

MainGui.SetFont("s9 w400 c000000")
global SwapUnitCtrl := MainGui.Add("DropDownList", "x297 y191 w90 Choose" (SwapUnit = "Minutes" ? 2 : 1) " vSwapUnit",
["Runs", "Minutes"])

SwapUnitCtrl.OnEvent("Change", (*) => (
    SwapUnit := SwapUnitCtrl.Text,
    SaveOption("SwapUnit", SwapUnit)
))

MainGui.SetFont("s9 w400 cFFFFFF")
global AutoEquipCtrl := MainGui.Add("Checkbox", "x30 y220 w140 h22 vAutoEquip Checked" AutoEquip, "Auto Equip Towers")
AutoEquipCtrl.OnEvent("Click", EnableAutoEquip)

global AutoConfigCtrl := MainGui.Add("Checkbox", "x175 y220 w212 h22 vAutoConfigureSettings Checked" AutoConfigureSettings,
    "Auto Configure Settings")
AutoConfigCtrl.OnEvent("Click", EnableAutoConfig)

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global Tab1_Section2 := MainGui.Add("Text", "x30 y252 w200 h24 0x200", "Strategies")
global Tab1_Line2 := MainGui.Add("Progress", "x30 y280 w640 h1 Background333333", 0)

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global BtnCommStrats := MainGui.Add("Text", "x424 y252 w120 h24 Center Background222222 +Border 0x200", "Community")
MainGui.SetFont("s10 w400 cFFFFFF", UIFont())
global BtnMyStrats := MainGui.Add("Text", "x550 y252 w120 h24 Center Background0e0e0f +Border 0x200", "My Strats")

BtnCommStrats.OnEvent("Click", (*) => SwitchStrategiesTab("Community"))
BtnMyStrats.OnEvent("Click", (*) => SwitchStrategiesTab("MyStrats"))
RegisterHoverEffect(BtnCommStrats)
RegisterHoverEffect(BtnMyStrats)

if !DirExist(StratsDir)
    DirCreate(StratsDir)

IsGitDevelopmentCheckout(rootDir) {
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
    apiStatus := 0

    try {
        apiURL := "https://api.github.com/repos/UltimateMacro/Ultimate-Macro-New-Era/contents/Resources/Strats?ref=main"

        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", apiURL, false)
        whr.SetRequestHeader("User-Agent", "Ultimate-Macro-New-Era-Strategy-Updater")
        whr.SetRequestHeader("Accept", "application/vnd.github+json")
        whr.SetRequestHeader("X-GitHub-Api-Version", "2022-11-28")
        whr.SetTimeouts(5000, 5000, 10000, 10000)
        whr.Send()
        apiStatus := whr.Status

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
        if (apiStatus = 403)
            LogToConsole("Community strategy refresh skipped because GitHub returned 403; keeping local strategies.", false)
        else
            LogToConsole("Error while downloading strats: " err.Message)
    } finally {
        if DirExist(tempDir)
            try DirDelete(tempDir, true)
        if DirExist(communityBackupDir)
            try DirDelete(communityBackupDir, true)
    }
}

global FrameX := 30
global FrameY := 290
global FrameW := 640
global FrameH := 195
global ContentH := 400
global CurrentScrollPos := 0
global ScrollDragging := false
global ScrollDragGrab := 0
global SliderH := 30
global SliderX := 0
global SliderW := 0
global ChildHwnd := 0
global ChildGui := ""
global ContentGui := ""

global IsRenderingStrategies := false

DisposeBitmap(hBitmap) {
    if (hBitmap) {
        try {
            DeleteObject(hBitmap)
        } catch Error as e {
        }
    }
}

CleanupRenderedBitmaps() {
    global RenderedBitmaps
    if (!IsSet(RenderedBitmaps) || !IsObject(RenderedBitmaps)) {
        RenderedBitmaps := []
        return
    }
    for index, hBitmap in RenderedBitmaps {
        DisposeBitmap(hBitmap)
    }
    RenderedBitmaps := []
}

global CurrentStratTabMode := ""

SwitchStrategiesTab(mode) {
    global BtnCommStrats, BtnMyStrats, IsRenderingStrategies, CurrentStratTabMode

    if (IsRenderingStrategies)
        return

    IsRenderingStrategies := true

    try {
        CleanupRenderedBitmaps()

        BtnCommStrats.IsSelected := (mode == "Community")
        BtnMyStrats.IsSelected := (mode != "Community")
        ApplyHoverStyle(BtnCommStrats, false)
        ApplyHoverStyle(BtnMyStrats, false)

        RenderStrategies(mode)

        CurrentStratTabMode := mode
    } finally {
        IsRenderingStrategies := false
    }
}

RenderStrategies(mode := "Community") {
    global ChildGui, ContentGui, MainGui, LoadedStrats, GradientButtons
    global FrameX, FrameY, FrameW, FrameH, ContentH, CurrentScrollPos, SliderH, SliderBG, Slider
    global StratsDir, RecordingsDir, CurrentTab, ChildHwnd, RenderedBitmaps, SliderX, SliderW
    global Strategy1Path, Strategy2Path, RotateStrategies

    CleanupRenderedBitmaps()

    newGradBtns := []
    if IsSet(GradientButtons) {
        for btn in GradientButtons {
            if !HasProp(btn, "StratFile")
                newGradBtns.Push(btn)
        }
    }
    GradientButtons := newGradBtns

    if (!IsSet(ChildGui) || ChildGui == "") {
        ChildGui := Gui("-Caption +E0x20 +Border +Parent" MainGui.Hwnd)
        ChildGui.BackColor := "181818"
        ChildGui.SetFont("s10 cWhite", UIFont())
        ChildHwnd := ChildGui.Hwnd
    }

    if (IsSet(ContentGui) && ContentGui != "") {
        try ContentGui.Destroy()
        catch
        ContentGui := ""
    }

    ContentGui := Gui("-Caption +Parent" ChildGui.Hwnd)
    ContentGui.BackColor := "181818"
    ContentGui.SetFont("s10 cWhite", UIFont())
    ContentGui.OnEvent("DropFiles", HandleStrategyDrop)
    HideFocusIndicators(ContentGui)

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
        RenderedBitmaps.Push(hFrameBg)
        ContentGui.Add("Picture", "x" C1X " y" C1Y " w" CardW " h" CardH " +BackgroundTrans", "HBITMAP:*" hFrameBg)

        hIconBg := CreateGradientButton(56, 56, 8, "0xff2f353f", "0xff15171b", "0xff000000", "0x232c3a50", "", UIFont(), 10, 1)
        RenderedBitmaps.Push(hIconBg)
        ContentGui.Add("Picture", "x" (C1X + 10) " y" (C1Y + 30) " w76 h76 +BackgroundTrans", "HBITMAP:*" hIconBg)

        hIconBg2 := CreateGradientButton(56, 56, 8, "0xff2f353f", "0xff15171b", "0xff000000", "0x232c3a50", "", UIFont(), 10, 1)
        RenderedBitmaps.Push(hIconBg2)
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
        ContentGui.Add("Text", "x" (C1X + 15) " y" (C1Y + 12) " w235 h20 +BackgroundTrans", strat.title != "" ? strat.title : "Unknown Strat")

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
        ContentGui.Add("Text", "x" (C1X + 260) " y" (C1Y + 15) " w306 h18 +BackgroundTrans", (strat.towers != "" ? strat.towers : "None"))

        ContentGui.SetFont("s9 w400 c7E848E", UIFont())
        ContentGui.Add("Text", "x" (C1X + 260) " y" (C1Y + 36) " w306 h28 +BackgroundTrans", strat.desc)

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
        RenderedBitmaps.Push(hgmMode)
        ContentGui.Add("Picture", "x" (C1X + 145) " y" (C1Y + 35) " w102 h28 +BackgroundTrans", "HBITMAP:*" hgmMode)

        ContentGui.SetFont("s9 w500 c9CA4B0", UIFont())
        ContentGui.Add("Text", "x" (C1X + 155) " y" (C1Y + 65) " +BackgroundTrans", "🕒 " (strat.time != "" ? strat.time : "Unknown"))
        ContentGui.Add("Text", "x" (C1X + 155) " y" (C1Y + 83) " +BackgroundTrans", "⛃ " (strat.income != "" ? strat.income : "Unknown"))

        isLoaded := false
        if (Strategy1Path != "" && StrLower(strat.fullPath) == StrLower(Strategy1Path))
            isLoaded := true
        else if (Strategy2Path != "" && RotateStrategies && StrLower(strat.fullPath) == StrLower(Strategy2Path))
            isLoaded := true

        btnText := isLoaded ? "Currently Loaded" : "Load"

        if (isLoaded) {
            loadColor1 := "0xFF4b5563", loadColor2 := "0xFF374151"
            loadHover1 := "0xFF505A69", loadHover2 := "0xFF3A4557"
        } else if ((strat.difficulty = "Hardcore" || strat.difficulty = "Voidcore")) {
            loadColor1 := "0xff961ea1", loadColor2 := "0xff5f237a"
            loadHover1 := "0xffea00ff", loadHover2 := "0xff8d32b7"
        } else {
            loadColor1 := "0xFF147A6E", loadColor2 := "0xFF214B75"
            loadHover1 := "0xFF1CB5A2", loadHover2 := "0xFF3272B7"
        }

        if (mode == "MyStrats") {
            hBtnNormal := CreateGradientButton(145, 38, 8, loadColor1, loadColor2, "0x40000000", "0x5dffffff", btnText, UIFont(), isLoaded ? 11 : 14, 1)
            RenderedBitmaps.Push(hBtnNormal)
            hBtnHover := CreateGradientButton(145, 38, 8, loadHover1, loadHover2, "0x60000000", "0x5dffffff", btnText, UIFont(), isLoaded ? 11 : 14, 1)
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
            dlEdit.GradEnabled := true
            GradientButtons.Push(dlEdit)
        } else {
            hBtnNormal := CreateGradientButton(220, 38, 8, loadColor1, loadColor2, "0x40000000", "0x5dffffff", btnText, UIFont(), isLoaded ? 12 : 14, 1)
            RenderedBitmaps.Push(hBtnNormal)
            hBtnHover := CreateGradientButton(220, 38, 8, loadHover1, loadHover2, "0x60000000", "0x5dffffff", btnText, UIFont(), isLoaded ? 12 : 14, 1)
            RenderedBitmaps.Push(hBtnHover)

            picLoadBtn := ContentGui.Add("Picture", "x" (C1X + 365) " y" (C1Y + 68) " w220 h38 +BackgroundTrans", "HBITMAP:*" hBtnNormal)
            dl1 := ContentGui.Add("Text", "x" (C1X + 365) " y" (C1Y + 68) " w220 h38 +BackgroundTrans +0x200 Center", "")
        }

        dl1.SetFont("cFFFFFF s10 Bold", UIFont())
        dl1.StratFile := strat.fullPath
        dl1.StratDiff := strat.difficulty
        dl1.IsSmallBtn := (mode == "MyStrats")

        dl1.OnEvent("Click", DownloadStrat)
        dl1.ImgHover := isLoaded ? hBtnNormal : hBtnHover

        dl1.PicControl := picLoadBtn
        dl1.ImgNormal := hBtnNormal
        dl1.GradEnabled := true
        GradientButtons.Push(dl1)
    }

    if (LoadedStrats.Length == 0) {
        ContentH := FrameH

        if (mode == "MyStrats") {
            emptyHitArea := ContentGui.Add("Text", "x0 y0 w" FrameW " h" FrameH " +BackgroundTrans")
            emptyHitArea.OnEvent("Click", OpenMyStratsFolder)

            ContentGui.SetFont("s11 w500 cE2E4E7", UIFont())
            emptyTitle := ContentGui.Add("Text", "x0 y" (FrameH // 2 - 58) " w" FrameW " h22 +BackgroundTrans Center",
                "You have not saved any strategies yet.")

            ContentGui.SetFont("s9 w400 c7E848E", UIFont())
            emptyHint := ContentGui.Add("Text", "x0 y" (FrameH // 2 - 36) " w" FrameW " h20 +BackgroundTrans Center",
                "Drop .strat files here, or click anywhere to open the folder.")

            ContentGui.SetFont("s24 w400 c9CA4B0", UIFont())
            addBtn := ContentGui.Add("Text",
                "x" ((FrameW - 48) // 2) " y" (FrameH // 2 - 14) " w48 h38 Center 0x200 +BackgroundTrans", "+")

            ContentGui.SetFont("s8 w400 c7E848E", UIFont())
            emptyCaption := ContentGui.Add("Text", "x0 y" (FrameH // 2 + 24) " w" FrameW " h18 +BackgroundTrans Center",
                "Open My Strats folder")

            for ctrl in [emptyTitle, emptyHint, addBtn, emptyCaption]
                ctrl.OnEvent("Click", OpenMyStratsFolder)
        } else {
            ContentGui.SetFont("s12 c7E848E", UIFont())
            ContentGui.Add("Text", "x0 y0 w" FrameW " h" FrameH " +BackgroundTrans Center +0x200",
                "No strategies found.")
        }
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

global Tab1_Start := MakeActionButton(MainGui, 30, 500, 310, 40, "Start  (F1)", StartStrategy, "start")
global Tab1_Stop := MakeActionButton(MainGui, 360, 500, 310, 40, "Stop  (F2)", StopStrategy, "stop")

global CreateView := "Choose"

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global Tab2_Title := MainGui.Add("Text", "x30 y95 w300 h22 Hidden", "Create a Strategy")
global Tab2_Line1 := MainGui.Add("Progress", "x30 y118 w640 h1 Hidden Background333333", 0)

MainGui.SetFont("s13 w600 cFFFFFF", UIFont())
global Create_RecordTitle := MainGui.Add("Text", "x30 y160 w310 h26 Hidden BackgroundTrans", "Record a Strategy")
global Create_LabTitle := MainGui.Add("Text", "x360 y160 w310 h26 Hidden BackgroundTrans", "Edit a Strategy")

MainGui.SetFont("s9 w400 cAAAAAA", UIFont())
global Create_RecordInfo := MainGui.Add("Text", "x30 y194 w310 h96 Hidden BackgroundTrans",
    "Play a round while Ultimate Macro records it. Tower placements, upgrades, sells, abilities and camera moves are captured and saved as a .strat file you can replay.")
global Create_LabInfo := MainGui.Add("Text", "x360 y194 w310 h96 Hidden BackgroundTrans",
    "Open Strategy Lab, the standalone visual editor. Build a strategy from scratch or fine-tune an existing .strat file without playing a round.")

global Create_RecordBtn := MakeActionButton(MainGui, 30, 300, 310, 44, "Record a Strategy", ShowCreateRecordView, "accent", true)
global Create_LabBtn := MakeActionButton(MainGui, 360, 300, 310, 44, "Open Strategy Lab", OpenStrategyLab, "neutral", true)

global Create_ChooseLine := MainGui.Add("Progress", "x30 y376 w640 h1 Hidden Background333333", 0)
MainGui.SetFont("s9 w400 c7E848E", UIFont())
global Create_ChooseHint := MainGui.Add("Text", "x30 y392 w640 h60 Hidden BackgroundTrans",
    "Recorded and edited strategies are both saved in your My Strats folder and show up on the Main tab.`nA timescale ticket makes recording long strategies much easier.")

MainGui.SetFont("s9 w400 cAAAAAA", UIFont())
global Tab2_Lbl1 := MainGui.Add("Text", "x30 y132 w66 h22 0x200 Hidden BackgroundTrans", "Map:")
MainGui.SetFont("s9 w400 c000000")
global RecMapsD := MainGui.Add("ComboBox", "x100 y131 w240 Hidden vRecMaps", [
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
global Tab2_Lbl2 := MainGui.Add("Text", "x30 y162 w66 h22 0x200 Hidden BackgroundTrans", "Mode:")
MainGui.SetFont("s9 w400 c000000")
global RecDifficultyChoices := ["Easy", "Casual", "Intermediate", "Molten", "Fallen", "Frost",
    "Hardcore", "Voidcore", "Arcade", "Pizza Party", "Badlands II", "Polluted Wasteland II"]
global RecDiffCtrl := MainGui.Add("ComboBox", "x100 y161 w240 Hidden vRecDifficulty", RecDifficultyChoices)

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab2_Lbl4 := MainGui.Add("Text", "x30 y192 w66 h22 0x200 Hidden BackgroundTrans", "Towers:")
MainGui.SetFont("s9 w400 c000000")
global RecTowersCtrl := MainGui.Add("Edit", "x100 y192 w240 h22 Hidden vRecRequiredTowers", requiredTowers)
SetEditPlaceholder(RecTowersCtrl, "Minigunner, Ranger, Commander")

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab2_Lbl3 := MainGui.Add("Text", "x30 y224 w66 h22 0x200 Hidden BackgroundTrans", "Modifiers:")
global RecModifiersFrame := AddDarkListFrame(MainGui, 100, 223, 240, 130)
MainGui.SetFont("s9 w400 c000000")
global RecModifiersCtrl := MainGui.Add("ListBox", "x100 y223 w240 h130 Multi Hidden -Border -E0x200 vRecModifiers", [
    "Broke", "Exploding", "Flying", "Fog", "Glass",
    "Healthy", "Hidden", "Inflation", "Jailed", "Limitation",
    "Committed", "Quarantine", "Speedy"
])
FitDarkListFrame(RecModifiersFrame, RecModifiersCtrl)
EnableDarkScrollbar(RecModifiersCtrl)

MainGui.SetFont("s8 w400 c7E848E", UIFont())
global Tab2_Info2 := MainGui.Add("Text", "x100 y358 w240 h30 Hidden BackgroundTrans",
    "Hold CTRL to select or deselect several modifiers.")

global Tab2_Info1 := MainGui.Add("Text", "x360 y132 w310 h58 Hidden BackgroundTrans",
    "Separate the towers your strategy needs with commas, for example: Minigunner, Ranger, Commander, DJ, Military Base. Prefix a tower with G when it has to be the golden version.")

global Tab2_Line2 := MainGui.Add("Progress", "x360 y196 w310 h1 Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cFFFFFF", UIFont())
global RecAutoChainCtrl := MainGui.Add("Checkbox", "x360 y208 w310 h22 Hidden vRecAutoChain Checked" (autoChain = "ON" ? 1 : 0),
    "Use Call of Arms")
global RecAutoCaravanCtrl := MainGui.Add("Checkbox", "x360 y234 w310 h22 Hidden vRecAutoCaravan Checked" (autoCaravan = "ON" ? 1 : 0),
    "Use Support Caravan")
global RecAutoDropCtrl := MainGui.Add("Checkbox", "x360 y260 w310 h22 Hidden vRecAutoDropTheBeat Checked" (autoDropTheBeat = "ON" ? 1 : 0),
    "Use Drop the Beat")

global Tab2_Line3 := MainGui.Add("Progress", "x360 y292 w310 h1 Hidden Background333333", 0)
global RecAutoSkipCtrl := MainGui.Add("Checkbox", "x360 y304 w310 h22 Hidden vRecAutoSkip", "Auto Skip Waves")
global RecAbilitySpamCtrl := MainGui.Add("Checkbox", "x360 y330 w310 h22 Hidden vRecAbilitySpam", "Abilities Spam")
RecAutoSkipCtrl.OnEvent("Click", RecordToggleAutoskip)

global Tab2_Line4 := MainGui.Add("Progress", "x30 y396 w640 h1 Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cFFFFFF", UIFont())
global RecMoveCtrl := MainGui.Add("Checkbox", "x30 y408 w70 h22 Hidden vRecMoveEnabled Checked" (MoveEnabled ? 1 : 0),
    "Move")
MainGui.SetFont("s9 w400 cAAAAAA")
global DIRECTIONTEXTCtrl := MainGui.Add("Text", "x110 y408 w66 h22 0x200 Hidden BackgroundTrans", "Direction:")
MainGui.SetFont("s9 w400 c000000")
global RecMoveDirCtrl := MainGui.Add("DropDownList", "x180 y407 w60 Hidden Choose1 vRecMoveDirection", ["W", "A", "S", "D"])
MainGui.SetFont("s9 w400 cAAAAAA")
global Tab2_Txt4 := MainGui.Add("Text", "x262 y408 w92 h22 0x200 Hidden BackgroundTrans", "Duration (ms):")
MainGui.SetFont("s9 w400 c000000")
global RecMoveDurCtrl := MainGui.Add("Edit", "x358 y408 w60 h22 Hidden vRecMoveDuration", 1000)

MainGui.SetFont("s8 w400 c7E848E", UIFont())
global Tab2_Info := MainGui.Add("Link", "x30 y442 w640 h44 Hidden", "
(
Watch the recording tutorial here: <a href=`"https://www.youtube.com/watch?v=j8Y5qHBaYOs&feature=youtu.be`">youtube.com/watch?v=j8Y5qHBaYOs</a>. A timescale ticket makes recording complex strategies much easier.
)")

global Tab2_BackBtn := MakeActionButton(MainGui, 30, 500, 140, 40, "Back", ShowCreateChooseView, "neutral", true)
global Tab2_Btn1 := MakeActionButton(MainGui, 180, 500, 240, 40, "Start Recording", StartRecording, "start", true)
global Tab2_Btn2 := MakeActionButton(MainGui, 430, 500, 240, 40, "Stop", StopRecord, "stop", true)
SetActionButtonEnabled(Tab2_Btn2, false)

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global Tab3_Title := MainGui.Add("Text", "x30 y95 w300 h22 Hidden", "Usernames")
global Tab3_Line1 := MainGui.Add("Progress", "x30 y118 w640 h1 Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab3_HostNm := MainGui.Add("Text", "x30 y134 w110 h22 0x200 BackgroundTrans Hidden", "Host Username:")
MainGui.SetFont("s9 w400 c000000")
global Tab3_HostNm_EDIT := MainGui.Add("Edit", "x146 y134 w524 h22 Hidden vHostName", PartyFieldValue(HostName))

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab3_PartyMemb := MainGui.Add("Text", "x30 y166 w110 h22 0x200 BackgroundTrans Hidden", "Party Members:")
MainGui.SetFont("s9 w400 c000000")
global Tab3_PartyMemb_Edit := MainGui.Add("Edit", "x146 y166 w524 h22 Hidden vPartyMembersStr", PartyFieldValue(PartyMembers))

SetEditPlaceholder(Tab3_HostNm_EDIT, "Username")
SetEditPlaceholder(Tab3_PartyMemb_Edit, "user, user, user")

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global Tab3_Title2 := MainGui.Add("Text", "x30 y204 w300 h22 Hidden", "Settings")
global Tab3_Line2 := MainGui.Add("Progress", "x30 y227 w640 h1 Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab3_RoleTxt := MainGui.Add("Text", "x30 y242 w110 h22 0x200 BackgroundTrans Hidden", "You are:")
MainGui.SetFont("s9 w400 cFFFFFF")
global PartyRoleRadios := []
global Tab3_Role_Host := MakeDarkRadio(MainGui, 146, 242, 74, "Host", "vPlayerRole Group",
    PlayerRole != "Member", PartyRoleRadios)
global Tab3_Role_Member := MakeDarkRadio(MainGui, 242, 242, 74, "Member", "",
    PlayerRole == "Member", PartyRoleRadios)

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab3_LConditionTxt := MainGui.Add("Text", "x30 y272 w110 h22 0x200 BackgroundTrans Hidden", "Leave lobby if:")
MainGui.SetFont("s9 w400 cFFFFFF")
global PartyLeaveRadios := []
global Tab3_LCondition_All := MakeDarkRadio(MainGui, 146, 272, 144, "All members are gone", "vLeaveCondition Group",
    LeaveCondition == "All", PartyLeaveRadios)
global Tab3_LCondition_Any := MakeDarkRadio(MainGui, 312, 272, 144, "Any member is gone", "",
    LeaveCondition == "Any", PartyLeaveRadios)

global MultiplayerEnabledTGL := MainGui.Add("Checkbox", "x30 y302 w300 h22 Hidden vMultiplayerEnabled Checked" MultiplayerEnabled,
    "Enable Party Mode")

global Tab3_Line3 := MainGui.Add("Progress", "x30 y338 w640 h1 Hidden Background333333", 0)

MainGui.SetFont("s9 w400 c7E848E", UIFont())
global Tab3_Info := MainGui.Add("Text", "x30 y352 w640 h130 Hidden BackgroundTrans",
    "Run the macro on several accounts at once, in the same party.`n`n"
    . "1. Pick your role. The Host creates the party and invites everyone; Members wait for the invite.`n"
    . "2. Host Username: the party leader's display name. Members need this.`n"
    . "3. Party Members: the display names of the other players, separated by commas (1 to 3). The Host needs this.`n"
    . "4. Choose when to return to the lobby.`n`n"
    . "Everything on this tab saves automatically as soon as you change it."
)

TAB3.Push(Tab3_Title, Tab3_Line1, Tab3_HostNm, Tab3_HostNm_EDIT, Tab3_PartyMemb, Tab3_PartyMemb_Edit, Tab3_Line2,
    Tab3_Info, MultiplayerEnabledTGL, Tab3_RoleTxt, Tab3_Role_Host, Tab3_Role_Member, Tab3_Title2,
    Tab3_Line3, Tab3_LCondition_All, Tab3_LCondition_Any, Tab3_LConditionTxt,
    Tab3_Role_Host.LabelCtrl, Tab3_Role_Member.LabelCtrl,
    Tab3_LCondition_All.LabelCtrl, Tab3_LCondition_Any.LabelCtrl)

Tab3_HostNm_EDIT.OnEvent("Change", (*) => AutoSavePartySettings())
Tab3_PartyMemb_Edit.OnEvent("Change", (*) => AutoSavePartySettings())

MultiplayerEnabledTGL.OnEvent("Click", (*) => AutoSavePartySettings())

MainGui.SetFont("s10 w500 c888888", UIFont())
global Tab4_WebhookTabTitle := MainGui.Add("Text", "x30 y95 w160 h26 Center 0x200 BackgroundTrans Hidden", "Discord Webhook")
global Tab4_BotTabTitle := MainGui.Add("Text", "x196 y95 w160 h26 Center 0x200 BackgroundTrans Hidden", "Personal Bot")
global Tab4_RemoteTabTitle := MainGui.Add("Text", "x362 y95 w160 h26 Center 0x200 BackgroundTrans Hidden", "Official Remote")
Tab4_WebhookTabTitle.OnEvent("Click", (*) => ShowDiscordPage("Webhook"))
Tab4_BotTabTitle.OnEvent("Click", (*) => ShowDiscordPage("Bot"))
Tab4_RemoteTabTitle.OnEvent("Click", (*) => ShowDiscordPage("Remote"))
for ctrl in [Tab4_WebhookTabTitle, Tab4_BotTabTitle, Tab4_RemoteTabTitle]
    RegisterHoverEffect(ctrl, "nav")

global Tab4_NavLine := MainGui.Add("Progress", "x30 y121 w160 h2 Hidden Background3A86FF", 0)
global Tab4_Line1 := MainGui.Add("Progress", "x30 y123 w640 h1 Hidden Background333333", 0)
DiscordNavTab.Push(Tab4_WebhookTabTitle, Tab4_BotTabTitle, Tab4_RemoteTabTitle, Tab4_NavLine, Tab4_Line1)

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab4_Lbl1 := MainGui.Add("Text", "x30 y138 w300 h20 Hidden BackgroundTrans", "Webhook URL:")
MainGui.SetFont("s9 w400 c000000")
global WebhookLinkCtrl := MainGui.Add("Edit", "x30 y160 w640 h24 Hidden vWebhookLink", WebhookLink)
SetEditPlaceholder(WebhookLinkCtrl, "https://discord.com/api/webhooks/...")

MainGui.SetFont("s8 w400 c7E848E", UIFont())
global Tab4_WebhookStatus := MainGui.Add("Text", "x30 y188 w640 h18 Hidden Background121212", "")

global Tab4_Line2 := MainGui.Add("Progress", "x30 y214 w640 h1 Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cFFFFFF")
global SendCurrCtrl := MainGui.Add("Checkbox", "x30 y226 w200 h22 Hidden vSendCurrenciesEnabled Checked" SendCurrenciesEnabled,
    "Send Statistics")
global DebugLogsCtrl := MainGui.Add("Checkbox", "x240 y226 w200 h22 Hidden vWebhookDebugLogs Checked" WebhookDebugLogs,
    "Send Logs to Discord")
global WebhookScreenshotsCtrl := MainGui.Add("Checkbox", "x450 y226 w220 h22 Hidden vWebhookScreenshots Checked" WebhookScreenshots,
    "Automatic screenshots")
global WebhookTriumphScreenshotsCtrl := MainGui.Add("Checkbox", "x30 y254 w410 h22 Hidden vWebhookTriumphScreenshots Checked" WebhookTriumphScreenshots,
    "Triumph and Loss screenshots")
global WebhookSepatateTriumphScreenshotsCtrl := MainGui.Add("Checkbox",
    "x30 y282 w410 h22 Hidden vWebhookSepatateTriumphScreenshots Checked" WebhookSepatateTriumphScreenshots,
    "Send Triumph/Loss to a separate channel")

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab4_Lbl2 := MainGui.Add("Text", "x30 y314 w300 h20 Hidden BackgroundTrans", "Separate channel webhook URL:")
MainGui.SetFont("s9 w400 c000000")
global WebhookLinkCtrl2 := MainGui.Add("Edit", "x30 y336 w640 h24 Hidden vWebhookLink2", WebhookLink2)
SetEditPlaceholder(WebhookLinkCtrl2, "https://discord.com/api/webhooks/...")

global Tab4_Line5 := MainGui.Add("Progress", "x30 y388 w640 h1 Hidden Background333333", 0)
MainGui.SetFont("s9 w400 c7E848E", UIFont())
global Tab4_Info := MainGui.Add("Text", "x30 y400 w640 h84 Hidden BackgroundTrans",
    "The webhook sends live logs, screenshots and currency stats to your Discord server, so you can check on the macro while you are away.`n`n"
    . "To get a URL: open a channel's settings in your own server, then Integrations > Create Webhook > Copy Webhook URL.")

global Tab4_Btn1 := MakeActionButton(MainGui, 30, 500, 640, 40, "Test Webhook", TestWebhook, "accent", true)

global WebhookDetailControls := [Tab4_Line2, SendCurrCtrl, DebugLogsCtrl, WebhookScreenshotsCtrl,
    WebhookTriumphScreenshotsCtrl, WebhookSepatateTriumphScreenshotsCtrl, Tab4_Lbl2, WebhookLinkCtrl2, Tab4_Btn1]

DiscordWebhookTab.Push(Tab4_Line2, Tab4_Line5, Tab4_Btn1, Tab4_Info, Tab4_Lbl1, Tab4_Lbl2, Tab4_WebhookStatus,
    SendCurrCtrl, WebhookLinkCtrl, WebhookLinkCtrl2, DebugLogsCtrl, WebhookScreenshotsCtrl,
    WebhookTriumphScreenshotsCtrl, WebhookSepatateTriumphScreenshotsCtrl)
MainGui.SetFont("s9 w400 cAAAAAA")
global bot_token_text := MainGui.Add("Text", "x30 y138 w300 h20 Hidden BackgroundTrans", "Bot Token:")
MainGui.SetFont("s9 w400 c000000")
global BotTokenCtrl := MainGui.Add("Edit", "x30 y160 w640 h24 Hidden vBotToken", BotToken)
SetEditPlaceholder(BotTokenCtrl, "MTUzNz...")

MainGui.SetFont("s9 w400 cFFFFFF")
global BotEnabledCtrl := MainGui.Add("Checkbox", "x30 y194 w300 h22 Hidden vBotEnabled Checked" BotEnabled, "Enable Bot")

MainGui.SetFont("s9 w400 cAAAAAA")
global bot_prefix_text := MainGui.Add("Text", "x30 y228 w110 h22 0x200 Hidden BackgroundTrans", "Command prefix:")
MainGui.SetFont("s9 w400 c000000")
global BotPrefixCtrl := MainGui.Add("Edit", "x146 y228 w60 h22 Hidden vBotPrefix Limit1 Center", BotPrefix)
SetEditPlaceholder(BotPrefixCtrl, "!")

MainGui.SetFont("s9 w400 cAAAAAA")
global channel_id_text := MainGui.Add("Text", "x30 y264 w310 h20 Hidden BackgroundTrans", "Channel ID:")
global userid_text := MainGui.Add("Text", "x360 y264 w310 h20 Hidden BackgroundTrans", "User ID:")
MainGui.SetFont("s9 w400 c000000")
global ChannelIDCtrl := MainGui.Add("Edit", "x30 y286 w310 h24 Hidden vChannelID", ChannelID)
SetEditPlaceholder(ChannelIDCtrl, "1153724586613514366")
global WebhookUserIDCtrl2 := MainGui.Add("Edit", "x360 y286 w310 h24 Hidden vWebhookUserID2", UserID)
SetEditPlaceholder(WebhookUserIDCtrl2, "Your own Discord user ID, for example 284937261055082497")

global Tab4_Line3 := MainGui.Add("Progress", "x30 y326 w640 h1 Hidden Background333333", 0)

MainGui.SetFont("s9 w400 c7E848E", UIFont())
global Tab4_Info_Bot := MainGui.Add("Link", "x30 y338 w640 h140 Hidden", "
(
A personal Discord bot works as a remote control for your macro: start or stop it from your phone, request screenshots, read statistics and more.

Setup tutorial: <a href=`"https://youtu.be/eAQ5Hm7fQu4`">youtu.be/eAQ5Hm7fQu4</a>

The command prefix must be a single non-alphanumeric character, such as ! . or -
)")

global Tab4_bot_Btn1 := MakeActionButton(MainGui, 30, 500, 640, 40, "Test Bot", TestBot, "accent", true)

DiscordBotTab.Push(Tab4_Line2, BotTokenCtrl, BotEnabledCtrl, Tab4_bot_Btn1,
    bot_token_text, bot_prefix_text, BotPrefixCtrl, WebhookUserIDCtrl2, ChannelIDCtrl, channel_id_text, userid_text,
    Tab4_Line3, Tab4_Info_Bot)

MainGui.SetFont("s15 w600 cFFFFFF", UIFont())
global Tab4_RemoteHeading := MainGui.Add("Text", "x30 y150 w640 h30 Hidden", "Connect Ultimate Macro to Discord")
MainGui.SetFont("s10 w400 cAAAAAA", UIFont())
global Tab4_RemoteInfo := MainGui.Add("Text", "x30 y190 w640 h62 Hidden",
    "1. Run /remote link in #bot-controller.`n2. Copy the private connection code Discord shows only to you.`n3. Paste it below and select Link This PC.")
MainGui.SetFont("s9 w500 cFFFFFF", UIFont())
global Tab4_RemoteCodeLabel := MainGui.Add("Text", "x30 y266 w250 h20 Hidden", "Private connection code")
MainGui.SetFont("s10 w400 c000000", UIFont())
global Tab4_RemoteCodeCtrl := MainGui.Add("Edit", "x30 y290 w640 h30 Hidden")
SetEditPlaceholder(Tab4_RemoteCodeCtrl, "Paste the private connection code from /remote link")
MainGui.SetFont("s9 w400 cAAAAAA", UIFont())
global Tab4_RemoteSecurity := MainGui.Add("Text", "x30 y330 w640 h32 Hidden",
    "Privacy: stores a random installation ID, Discord ID, version, link/active times, online status, and aggregated coin/gem gains. No HWID.")
MainGui.SetFont("s9 w400 cFFFFFF", UIFont())
global Tab4_RemoteConsent := MainGui.Add("Checkbox", "x30 y366 w640 h22 Hidden",
    "I consent to this limited device data and 30-day security-event retention.")
global Tab4_RemoteStatus := MainGui.Add("Text", "x30 y455 w640 h28 Center 0x200 Hidden", "Not linked")
global Tab4_RemoteConnectBtn := MakeActionButton(MainGui, 180, 404, 340, 40, "Link This PC", OfficialRemoteConnectFromControls, "accent", true)

DiscordRemoteTab.Push(Tab4_RemoteHeading, Tab4_RemoteInfo, Tab4_RemoteCodeLabel, Tab4_RemoteCodeCtrl,
    Tab4_RemoteSecurity, Tab4_RemoteConsent, Tab4_RemoteStatus, Tab4_RemoteConnectBtn)

WebhookLinkCtrl.OnEvent("Change", QueueWebhookCheck)

WebhookLinkCtrl2.OnEvent("Change", (*) => (
    WebhookLink2 := WebhookLinkCtrl2.Value,
    SaveWebhookSetting("Link2", WebhookLink2),
    SetTimer(CheckWebhookLink2, -700)
))

SendCurrCtrl.OnEvent("Click", (ctrlObj, *) => (
    SendCurrenciesEnabled := ctrlObj.Value,
    SaveWebhookSetting("SendCurrencies", SendCurrenciesEnabled),
    ctrlObj.Value ? CheckOcrLanguage() : ""
))

DebugLogsCtrl.OnEvent("Click", (ctrlObj, *) => (
    WebhookDebugLogs := ctrlObj.Value,
    SaveWebhookSetting("WebhookDebugLogs", WebhookDebugLogs)
))

WebhookScreenshotsCtrl.OnEvent("Click", (ctrlObj, *) => (
    WebhookScreenshots := ctrlObj.Value,
    SaveWebhookSetting("WebhookScreenshots", WebhookScreenshots)
))

WebhookTriumphScreenshotsCtrl.OnEvent("Click", (ctrlObj, *) => (
    WebhookTriumphScreenshots := ctrlObj.Value,
    SaveWebhookSetting("WebhookTriumphScreenshots", WebhookTriumphScreenshots)
))

WebhookSepatateTriumphScreenshotsCtrl.OnEvent("Click", (ctrlObj, *) => (
    WebhookSepatateTriumphScreenshots := ctrlObj.Value,
    SaveWebhookSetting("WebhookSepatateTriumphScreenshots", WebhookSepatateTriumphScreenshots),
    EnableWebhookLink2()
))

BotTokenCtrl.OnEvent("Change", (*) => QueueSettingSave("botsettings", AutoSaveBotSettings, 600))
ChannelIDCtrl.OnEvent("Change", (*) => QueueSettingSave("botsettings", AutoSaveBotSettings, 600))
WebhookUserIDCtrl2.OnEvent("Change", (*) => QueueSettingSave("botsettings", AutoSaveBotSettings, 600))
BotPrefixCtrl.OnEvent("Change", (*) => QueueSettingSave("botsettings", AutoSaveBotSettings, 600))
BotEnabledCtrl.OnEvent("Click", (*) => AutoSaveBotSettings())

RefreshWebhookStatus()

global SettingsViewX := 30
global SettingsViewY := 92
global SettingsViewW := 640
global SettingsViewH := 398
global SettingsPanelH := 693
global SettingsScrollPos := 0
global SettingsSliderH := 0
global SettingsSlider := 0
global SettingsSliderBG := 0

global SettingsHostGui := Gui("-Caption +E0x20 +Parent" MainGui.Hwnd)
SettingsHostGui.BackColor := "121212"
SettingsHostGui.SetFont("s9 cWhite", UIFont())

global SettingsPanel := Gui("-Caption +Parent" SettingsHostGui.Hwnd)
SettingsPanel.BackColor := "121212"
SettingsPanel.SetFont("s9 cWhite", UIFont())

SettingsPanel.SetFont("s10 w400 c3A86FF", UIFont())
global Tab5_Section1 := SettingsPanel.Add("Text", "x0 y8 w290 h22", "TDS Keybinds")
global Tab5_Line1 := SettingsPanel.Add("Progress", "x0 y31 w300 h1 Background333333", 0)

SettingsPanel.SetFont("s9 w400 cAAAAAA", UIFont())
global Tab5_Lbl1 := SettingsPanel.Add("Text", "x0 y43 w86 h20 0x200 BackgroundTrans", "Call of Arms:")
SettingsPanel.SetFont("s9 w400 c000000")
global ChainKeyCtrl := SettingsPanel.Add("Edit", "x90 y43 w40 h20 Center Limit1", ChainKey)

SettingsPanel.SetFont("s9 w400 cAAAAAA")
global Tab5_Lbl2 := SettingsPanel.Add("Text", "x150 y43 w86 h20 0x200 BackgroundTrans", "Drop the Beat:")
SettingsPanel.SetFont("s9 w400 c000000")
global BeatKeyCtrl := SettingsPanel.Add("Edit", "x240 y43 w40 h20 Center Limit1", BeatKey)

SettingsPanel.SetFont("s9 w400 cAAAAAA")
global Tab5_Lbl3 := SettingsPanel.Add("Text", "x0 y69 w86 h20 0x200 BackgroundTrans", "S. Caravan:")
SettingsPanel.SetFont("s9 w400 c000000")
global CaravanKeyCtrl := SettingsPanel.Add("Edit", "x90 y69 w40 h20 Center Limit1", CaravanKey)

SettingsPanel.SetFont("s9 w400 cAAAAAA")
global Tab5_Lbl44 := SettingsPanel.Add("Text", "x150 y69 w86 h20 0x200 BackgroundTrans", "Raise the Dead:")
SettingsPanel.SetFont("s9 w400 c000000")
global RaiseDeadKeyCtrl := SettingsPanel.Add("Edit", "x240 y69 w40 h20 Center Limit1", RaiseDeadKey)
SettingsPanel.SetFont("s9 w400 c7E848E", UIFont())
global Tab5_Help12 := SettingsPanel.Add("Text", "x286 y69 w18 h20 0x200 Center", "?")
RegisterHelpTip(Tab5_Help12, "To record Raise the Dead, press CTRL together with this key.")

SettingsPanel.SetFont("s9 w400 cAAAAAA")
global Tab5_Lbl55 := SettingsPanel.Add("Text", "x0 y95 w86 h20 0x200 BackgroundTrans", "Hologram:")
SettingsPanel.SetFont("s9 w400 c000000")
global HologramKeyCtrl := SettingsPanel.Add("Edit", "x90 y95 w40 h20 Center Limit1", HologramKey)

SettingsPanel.SetFont("s9 w400 cAAAAAA")
global Tab5_Lbl56 := SettingsPanel.Add("Text", "x150 y95 w86 h20 0x200 BackgroundTrans", "Reposition:")
SettingsPanel.SetFont("s9 w400 c000000")
global RepoKeyCtrl := SettingsPanel.Add("Edit", "x240 y95 w40 h20 Center Limit1", RepoKey)
SettingsPanel.SetFont("s9 w400 c7E848E", UIFont())
global Tab5_Help11 := SettingsPanel.Add("Text", "x286 y95 w18 h20 0x200 Center", "?")
RegisterHelpTip(Tab5_Help11, "To record a Brawler reposition, press CTRL together with this key.")

SettingsPanel.SetFont("s9 w400 cAAAAAA")
global Tab5_LblUPG := SettingsPanel.Add("Text", "x0 y121 w86 h20 0x200 BackgroundTrans", "Upgrade:")
SettingsPanel.SetFont("s9 w400 c000000")
global UpgradeTowerGCtrl := SettingsPanel.Add("Edit", "x90 y121 w40 h20 Center Limit1", UpgradeTowerGKey)

SettingsPanel.SetFont("s9 w400 cAAAAAA")
global Tab5_LblUPGBTM := SettingsPanel.Add("Text", "x150 y121 w86 h20 0x200 BackgroundTrans", "Bottom path:")
SettingsPanel.SetFont("s9 w400 c000000")
global UpgradeTowerGBCtrl := SettingsPanel.Add("Edit", "x240 y121 w40 h20 Center Limit1", UpgradeTowerGBKey)

SettingsPanel.SetFont("s9 w400 cAAAAAA")
global Tab5_Lbl99 := SettingsPanel.Add("Text", "x0 y147 w86 h20 0x200 BackgroundTrans", "Cancel place:")
SettingsPanel.SetFont("s9 w400 c000000")
global CancelPlacementKeyCtrl := SettingsPanel.Add("Edit", "x90 y147 w40 h20 Center Limit1", CancelPlacementKey)

SettingsPanel.SetFont("s10 w400 c3A86FF", UIFont())
global Tab5_Section2 := SettingsPanel.Add("Text", "x330 y8 w290 h22 BackgroundTrans", "Macro Settings")
global Tab5_Line2 := SettingsPanel.Add("Progress", "x330 y31 w296 h1 Background333333", 0)

SettingsPanel.SetFont("s9 w400 cFFFFFF", UIFont())
global UseUpgradeHCtrl := SettingsPanel.Add("Checkbox", "x330 y42 w264 h22", "Use Hotkeys for Upgrading")
UseUpgradeHCtrl.Value := (UseHForUpgrade = 1)
SettingsPanel.SetFont("s9 w400 c7E848E", UIFont())
global Tab5_Help6 := SettingsPanel.Add("Text", "x600 y42 w18 h22 0x200 Center", "?")
RegisterHelpTip(Tab5_Help6, "The macro uses the TDS keybind when upgrading a tower instead of clicking the panel.`n`nRecommended: ON.")

SettingsPanel.SetFont("s9 w400 cFFFFFF", UIFont())
global UseRestartBtnCtrl := SettingsPanel.Add("Checkbox", "x330 y68 w264 h22", "Click Restart button")
UseRestartBtnCtrl.Value := (UseRestartBtn = "1" || UseRestartBtn = 1)
SettingsPanel.SetFont("s9 w400 c7E848E", UIFont())
global Tab5_Help4 := SettingsPanel.Add("Text", "x600 y68 w18 h22 0x200 Center", "?")
RegisterHelpTip(Tab5_Help4, "When ON, the macro presses the Restart button after a loss.`n`nTurn it OFF if you use a winning strategy and the macro sometimes ends up on the wrong map.")

SettingsPanel.SetFont("s9 w400 cFFFFFF", UIFont())
global UsePlayAgainBtnCtrl := SettingsPanel.Add("Checkbox", "x330 y94 w264 h22", "Click Play Again button")
UsePlayAgainBtnCtrl.Value := (UsePlayAgainBtn = "1" || UsePlayAgainBtn = 1)
SettingsPanel.SetFont("s9 w400 c7E848E", UIFont())
global Tab5_Help5 := SettingsPanel.Add("Text", "x600 y94 w18 h22 0x200 Center", "?")
RegisterHelpTip(Tab5_Help5, "When ON, the macro presses the Play Again button after a win.")

SettingsPanel.SetFont("s9 w400 cFFFFFF", UIFont())
global CheckTheMapCtrl := SettingsPanel.Add("Checkbox", "x330 y120 w264 h22", "Check the map")
CheckTheMapCtrl.Value := (CheckTheMap = "1" || CheckTheMap = 1)
SettingsPanel.SetFont("s9 w400 c7E848E", UIFont())
global Tab5_Help7 := SettingsPanel.Add("Text", "x600 y120 w18 h22 0x200 Center", "?")
RegisterHelpTip(Tab5_Help7, "After joining, the macro confirms it is on the map your strategy expects and reloads if it is not.`n`nRecommended: ON.")

SettingsPanel.SetFont("s9 w400 cFFFFFF", UIFont())
global UseNumbersForHotbarCtrl := SettingsPanel.Add("Checkbox", "x330 y146 w290 h22", "Use Numbers for Hotbar")
UseNumbersForHotbarCtrl.Value := (UseNumbersForHotbar = "1" || UseNumbersForHotbar = 1)

global CollectPlaytimeRewardsCtrl := SettingsPanel.Add("Checkbox", "x330 y172 w290 h22", "Collect playtime rewards")
CollectPlaytimeRewardsCtrl.Value := (CollectPlaytimeRewards = "1" || CollectPlaytimeRewards = 1)

SettingsPanel.SetFont("s9 w400 cAAAAAA")
global Tab5_LblTimescale := SettingsPanel.Add("Text", "x330 y202 w110 h22 0x200 BackgroundTrans", "Timescale:")
SettingsPanel.SetFont("s9 w400 c000000")
global TimeScaleModeCtrl := SettingsPanel.Add("DropDownList", "x444 y201 w110", ["OFF", "1.5x", "2x"])
TimeScaleModeCtrl.Text := TimeScaleMode
SettingsPanel.SetFont("s9 w400 c7E848E", UIFont())
global Tab5_HelpTimescale := SettingsPanel.Add("Text", "x560 y201 w18 h22 0x200 Center", "?")
RegisterHelpTip(Tab5_HelpTimescale, "1.5x is more stable and suits most strategies.`n2x needs strategies built for it but is much faster.`n`nIf you run out of timescale tickets the run continues at normal speed.")

SettingsPanel.SetFont("s9 w400 cAAAAAA")
global Tab5_LblUpgradeDelay := SettingsPanel.Add("Text", "x330 y230 w110 h22 0x200 BackgroundTrans", "Upgrade Delay:")
SettingsPanel.SetFont("s9 w400 c000000")
global UpgradeDelayCtrl := SettingsPanel.Add("Edit", "x444 y230 w110 h22 Number Limit4", UpgradeDelay)

SettingsPanel.SetFont("s10 w400 c3A86FF", UIFont())
global Tab5_Section3 := SettingsPanel.Add("Text", "x0 y268 w290 h22 BackgroundTrans", "Recording Hotkeys")
global Tab5_Line3 := SettingsPanel.Add("Progress", "x0 y291 w626 h1 Background333333", 0)

SettingsPanel.SetFont("s9 w400 cAAAAAA")
global PlcTowerTEXT := SettingsPanel.Add("Text", "x0 y303 w100 h22 0x200 BackgroundTrans", "Place Tower:")
global PlaceTowerKeyCtrl := MakeHotkeyField(SettingsPanel, 104, 303, 96, 22, PlaceTowerKey)

global UpgTowerTEXT := SettingsPanel.Add("Text", "x0 y331 w100 h22 0x200 BackgroundTrans", "Upgrade Tower:")
global UpgradeTowerKeyCtrl := MakeHotkeyField(SettingsPanel, 104, 331, 96, 22, UpgradeTowerKey)

global AlignCamTEXT := SettingsPanel.Add("Text", "x0 y359 w100 h22 0x200 BackgroundTrans", "Align Camera:")
global AlignCameraKeyCtrl := MakeHotkeyField(SettingsPanel, 104, 359, 96, 22, AlignCameraKey)

global DjTrackTEXT := SettingsPanel.Add("Text", "x214 y303 w100 h22 0x200 BackgroundTrans", "Change DJ Track:")
global ChangeDJTrackKeyCtrl := MakeHotkeyField(SettingsPanel, 318, 303, 96, 22, ChangeDJTrackKey)

global SellTowTEXT := SettingsPanel.Add("Text", "x214 y331 w100 h22 0x200 BackgroundTrans", "Sell Tower:")
global SellTowerKeyCtrl := MakeHotkeyField(SettingsPanel, 318, 331, 96, 22, SellTowerKey)

global DelRecTEXT := SettingsPanel.Add("Text", "x214 y359 w100 h22 0x200 BackgroundTrans", "Delete Record:")
global DeleteTowerRecordingKeyCtrl := MakeHotkeyField(SettingsPanel, 318, 359, 96, 22, DeleteTowerRecordingKey)

global RecInputsTEXT := SettingsPanel.Add("Text", "x428 y303 w104 h22 0x200 BackgroundTrans", "Record Inputs:")
global RecordInputsKeyCtrl := MakeHotkeyField(SettingsPanel, 534, 303, 92, 22, RecordInputsKey)

global HoloTEXT := SettingsPanel.Add("Text", "x428 y331 w104 h22 0x200 BackgroundTrans", "Hologram Tower:")
global HoloKeyCtrl := MakeHotkeyField(SettingsPanel, 534, 331, 92, 22, HoloKey)

global RaiseDeadTEXT := SettingsPanel.Add("Text", "x428 y359 w104 h22 0x200 BackgroundTrans", "Change Targets:")
global ChangeTargetsCTRL := MakeHotkeyField(SettingsPanel, 534, 359, 92, 22, ChangeTargetsKey)

SettingsPanel.SetFont("s8 w400 c7E848E", UIFont())
global Tab5_KeybindStatus := SettingsPanel.Add("Text", "x0 y389 w626 h18 Background121212", "")

SettingsPanel.SetFont("s10 w400 c3A86FF", UIFont())
global Tab5_Section4 := SettingsPanel.Add("Text", "x0 y416 w290 h22 BackgroundTrans", "Other Settings")
global Tab5_Line4 := SettingsPanel.Add("Progress", "x0 y439 w626 h1 Background333333", 0)

SettingsPanel.SetFont("s9 w400 cAAAAAA")
global Tab5_Lbl4 := SettingsPanel.Add("Text", "x0 y451 w300 h20 BackgroundTrans", "VIP Server Link:")
SettingsPanel.SetFont("s9 w400 c000000")
global VipLinkCtrl := SettingsPanel.Add("Edit", "x0 y473 w626 h24", VipLink)
SetEditPlaceholder(VipLinkCtrl, "https://www.roblox.com/share?code=...  (Leave empty for public servers)")

SettingsPanel.SetFont("s8 w400 c7E848E", UIFont())
global Tab5_VipStatus := SettingsPanel.Add("Text", "x0 y501 w626 h18 Background121212", "")

SettingsPanel.SetFont("s9 w400 cFFFFFF", UIFont())
global AlwaysOnTopCtrl := SettingsPanel.Add("Checkbox", "x0 y529 w200 h22", "Always On Top")
AlwaysOnTopCtrl.Value := (AlwaysOnTop = "1" || AlwaysOnTop = 1)

global DebugConsoleCtrl := SettingsPanel.Add("Checkbox", "x214 y529 w200 h22", "On-Screen Logs")
DebugConsoleCtrl.Value := (DebugConsole = "1" || DebugConsole = 1)

global PotatoModeCtrl := SettingsPanel.Add("Checkbox", "x0 y557 w104 h22", "Potato Mode")
PotatoModeCtrl.Value := (PotatoMode = 1)
SettingsPanel.SetFont("s9 w400 c7E848E", UIFont())
global Tab5_Help21 := SettingsPanel.Add("Text", "x108 y557 w18 h22 0x200 Center", "?")
RegisterHelpTip(Tab5_Help21, "Turn this on if the macro behaves inconsistently or your game lags. It adds extra waiting time between actions.")

SettingsPanel.SetFont("s9 w400 cFFFFFF", UIFont())
global LegacyModeCtrl := SettingsPanel.Add("Checkbox", "x214 y557 w100 h22", "Legacy Mode")
LegacyModeCtrl.Value := (LegacyMode = "1" || LegacyMode = 1)
SettingsPanel.SetFont("s9 w400 c7E848E", UIFont())
global Tab5_HelpLegacy := SettingsPanel.Add("Text", "x318 y557 w18 h22 0x200 Center", "?")
RegisterHelpTip(Tab5_HelpLegacy, "Changes how image detection works and only applies at 1920x1080.`n`nAuto Equip and tower targeting do not work in this mode. The macro restarts when you change it.")

SettingsPanel.SetFont("s9 w400 cAAAAAA")
global MouseSpeedLbl := SettingsPanel.Add("Text", "x0 y589 w78 h22 0x200 BackgroundTrans", "Mouse Speed:")
SettingsPanel.SetFont("s9 w400 cFFFFFF")
global MouseSpeedTxt := SettingsPanel.Add("Text", "x80 y589 w28 h22 0x200 Center", DefaultMouseSpeed)
MakeStepper(SettingsPanel, 113, 589, StepMouseSpeed)

SettingsPanel.SetFont("s9 w400 cAAAAAA")
global MouseDelayLbl := SettingsPanel.Add("Text", "x214 y589 w76 h22 0x200 BackgroundTrans", "Mouse Delay:")
SettingsPanel.SetFont("s9 w400 cFFFFFF")
global MouseDelayTxt := SettingsPanel.Add("Text", "x292 y589 w28 h22 0x200 Center", MouseDelay)
MakeStepper(SettingsPanel, 325, 589, StepMouseDelay)

SettingsPanel.SetFont("s9 w400 cAAAAAA")
global KeyDelayLbl := SettingsPanel.Add("Text", "x428 y589 w60 h22 0x200 BackgroundTrans", "Key Delay:")
SettingsPanel.SetFont("s9 w400 cFFFFFF")
global KeyDelayTxt := SettingsPanel.Add("Text", "x490 y589 w28 h22 0x200 Center", KeyDelay)
MakeStepper(SettingsPanel, 523, 589, StepKeyDelay)

SettingsPanel.SetFont("s8 w400 c7E848E", UIFont())
global Tab5_DelayHint := SettingsPanel.Add("Text", "x0 y617 w626 h18 BackgroundTrans",
    "Higher delays are slower but more reliable on weak machines. Wrong values make the macro miss clicks.")

global Tab5_BtnClearLogs := MakeActionButton(SettingsPanel, 0, 645, 200, 34, "Clear Logs", ClearStoredLogs, "neutral")
global Tab5_BtnExportLogs := MakeActionButton(SettingsPanel, 213, 645, 200, 34, "Export Logs", ExportLogsForDevelopers, "neutral")
global Tab5_BtnReset := MakeActionButton(SettingsPanel, 426, 645, 200, 34, "Reset to Default", ResetSettingsToDefault, "stop")

WireSettingsAutoSave()
RefreshVipServerStatus()

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global Tools_Section := MainGui.Add("Text", "x30 y95 w300 h22 Hidden", "Tools")
global Tools_Section_Line := MainGui.Add("Progress", "x30 y118 w640 h1 Hidden Background333333", 0)

MainGui.SetFont("s9 w400 c7E848E", UIFont())
global Tools_Info := MainGui.Add("Text", "x30 y130 w640 h18 Hidden BackgroundTrans",
    "Small standalone helpers for repetitive tasks. Click one to open it.")

global Auto_Ability := MainGui.Add("Picture", "x30 y152 w200 h202 Hidden", "Resources/Gui/auto_ability_preview.png")
Auto_Ability.OnEvent("Click", RunAutoAbTool)

global Auto_Spin := MainGui.Add("Picture", "x250 y152 w200 h202 Hidden", "Resources/Gui/auto_spin_preview.png")
Auto_Spin.OnEvent("Click", RunAutoSpinTool)

global Auto_Consum := MainGui.Add("Picture", "x470 y152 w200 h202 Hidden",
    "Resources/Gui/auto_open_consumable_preview.png")
Auto_Consum.OnEvent("Click", RunAutoConsumableTool)

MainGui.SetFont("s9 w500 cFFFFFF", UIFont())
global Tools_AbilityLbl := MainGui.Add("Text", "x30 y360 w200 h20 Center Hidden BackgroundTrans", "Auto Abilities")
global Tools_SpinLbl := MainGui.Add("Text", "x250 y360 w200 h20 Center Hidden BackgroundTrans", "Auto Spin")
global Tools_ConsumLbl := MainGui.Add("Text", "x470 y360 w200 h20 Center Hidden BackgroundTrans", "Auto Consumables")

MainGui.SetFont("s10 w400 c3A86FF", UIFont())
global Tools_Profiles_Section := MainGui.Add("Text", "x30 y392 w300 h22 Hidden", "Profiles && Diagnostics")
global Tools_Profiles_Line := MainGui.Add("Progress", "x30 y415 w640 h1 Hidden Background333333", 0)
global ProfileExportBtn := MakeActionButton(MainGui, 30, 427, 200, 38, "Export Profile", ExportProfile, "neutral", true)
global ProfileImportBtn := MakeActionButton(MainGui, 250, 427, 200, 38, "Import Profile", ImportProfile, "neutral", true)
global ProfileManagerBtn := MakeActionButton(MainGui, 470, 427, 200, 38, "Manage Profiles", ProfileManager, "neutral", true)

MainGui.SetFont("s18 bold cFFFFFF", UIFont())
global Credit_TITLE := MainGui.Add("Text", "x30 y95 w640 h30 Hidden Center", "Ultimate Macro")

global Credit_Divider := MainGui.Add("Progress", "x80 y132 w530 h2 Hidden Center Background6e6e6e", 0)

MainGui.SetFont("s11 w400 cFFFFFF", UIFont())
global Credit_Content := MainGui.Add("Edit",
    "x80 y150 w530 h200 Multi ReadOnly -TabStop +VScroll -Wrap -E0x200 Background111111 Hidden", "
(
Started on March 30, 2026. Built in AutoHotkey v2.

Original Creator
• Darksen

Lead Developer
• pizzaroles24

Developers
• aiden
• banana.dev
• itzshovel
• kronoxxv
• salkann
• yoshi
• ziadod

QA
• frostzzz
• menz7
• nytli
• tristanm1ce
)")

EnableDarkScrollbar(Credit_Content)
SuppressEditCaret(Credit_Content)

MainGui.SetFont("s12 italic w400 cFFFFFF", UIFont())
global Credit_Support := MainGui.Add("Link", "x30 y424 w640 h66 Hidden", "
(
You can *support* me and the macro with <a href="https://www.donationalerts.com/r/darksen1">real money</a> or with <a href="https://www.roblox.com/games/115405526400244/Raise-an-Onett">robux (press donations button when you joined)</a>, do it if you're really enjoying the macro.
I truly appreciate any support! (Please Donate)
)"
)

global Credit_InfoBG := MainGui.Add("Progress", "x0 y366 w700 h44 Hidden Center Background2a5c3d", 0)
MainGui.SetFont("s12 norm w400 cFFFFFF", UIFont())
global Credit_Info := MainGui.Add("Text", "x0 y366 w700 h44 BackgroundTrans 0x200 Center Hidden", "
(
Special thanks to my Discord Community!
)")

global Divider := MainGui.Add("Progress", "x0 y500 w700 h1 Hidden Background222222", 0)
global FooterBg := MainGui.Add("Progress", "x0 y501 w700 h64 Disabled Hidden Background0f0f0f", 0)

MainGui.SetFont("s10 italic cFFFFFF", UIFont())
global version_text := MainGui.Add("Text", "x30 y520 h24 0x200 BackgroundTrans Hidden", ver " * made by darksen")

global githubImg := MainGui.Add("Picture", "x580 y520 w24 h24 Hidden BackgroundTrans", "Resources\github.png")
githubImg.OnEvent("Click", githubLink)
global DiscordImg := MainGui.Add("Picture", "x611 y520 w24 h24 Hidden BackgroundTrans", "Resources\discord.png")
DiscordImg.OnEvent("Click", DiscordLink)
global YoutubeImg := MainGui.Add("Picture", "x642 y520 w24 h24 Hidden BackgroundTrans", "Resources\youtube.png")
YoutubeImg.OnEvent("Click", YouTubeLink)

MainGui.Title := "Ultimate Macro"
MainGui.Show("w700 h565")

OfficialRemoteInit()

if (AlwaysOnTop = 1) {
    MainGui.Opt("+AlwaysOnTop")
} else {
    MainGui.Opt("-AlwaysOnTop")
}

SetTimer(() => RemoveInitialFocus(), -50)

HideFocusIndicators(MainGui)
HideFocusIndicators(SettingsHostGui)
HideFocusIndicators(SettingsPanel)

ApplyDarkInputTheme(MainGui)
ApplyDarkInputTheme(SettingsPanel)

global CurrentTab := "Tab1"
TabCtrl[1].SetFont("cFFFFFF")
SwitchStrategiesTab("Community")
ShowTabContent("Tab1")
EnableStratRotation()

SetTimer(Hoverwatchdog, 40)

OnMessage(0x0201, WM_LBUTTONDOWN_Drag)
OnMessage(0x0202, OnAppMouseUp)
OnMessage(0x0133, DarkInputCtlColor)
OnMessage(0x0134, DarkInputCtlColor)
OnMessage(0x8001, ToolWindowClosing)

ControlClassName(hwnd) {
    if (!hwnd)
        return ""
    buf := Buffer(256, 0)
    if !DllCall("user32\GetClassNameW", "Ptr", hwnd, "Ptr", buf.Ptr, "Int", 128, "Int")
        return ""
    return StrGet(buf, "UTF-16")
}

IsTextInputControl(hwnd) {
    static inputClasses := ["Edit", "ComboBox", "ListBox", "msctls_hotkey32", "msctls_updown32"]
    cls := ControlClassName(hwnd)
    for candidate in inputClasses {
        if (cls = candidate)
            return true
    }
    return false
}

ClearStrayFocus() {
    global MainGui

    if (!IsSet(MainGui) || !MainGui)
        return
    if !WinActive("ahk_id " MainGui.Hwnd)
        return

    MouseGetPos(, , , &ctrlHwnd, 2)
    if IsTextInputControl(ctrlHwnd)
        return

    DllCall("user32\SetFocus", "Ptr", 0)
}

OnAppMouseUp(wParam, lParam, msg, hwnd) {
    SetTimer(ClearStrayFocus, -60)
}

HideFocusIndicators(guiObj) {
    static WM_CHANGEUISTATE := 0x0127
    static UIS_SET := 1
    static UISF_HIDEFOCUS := 0x1

    if (!IsSet(guiObj) || !guiObj)
        return
    try SendMessage(WM_CHANGEUISTATE, UIS_SET | (UISF_HIDEFOCUS << 16), 0, , "ahk_id " guiObj.Hwnd)
}

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
    HideFocusIndicators(MainGui)
    HideFocusIndicators(SettingsPanel)
    DllCall("user32\SetFocus", "Ptr", 0)
}

Hoverwatchdog(*) {
    static hClose := 0, hMin := 0, hMain := 0, hChild := 0
    static hoverClose := false, hoverMin := false, hoverTabs := []
    static activeHoverHwnd := 0
    static activeGradHwnd := 0
    static lastX := -1, lastY := -1, lastCtrl := 0, lastTab := ""

    if (hoverTabs.Length != HoverTab.Length) {
        hoverTabs := []
        loop HoverTab.Length
            hoverTabs.Push(false)
    }

    if (!hMain)
        hMain := MainGui.Hwnd

    if (!hChild && IsSet(ChildGui))
        hChild := ChildGui.Hwnd

    hSettingsHost := (IsSet(SettingsHostGui) && SettingsHostGui) ? SettingsHostGui.Hwnd : 0
    hSettingsPanel := (IsSet(SettingsPanel) && SettingsPanel) ? SettingsPanel.Hwnd : 0

    if !DllCall("user32\IsWindowVisible", "Ptr", hMain, "Int")
        return

    oldMode := A_CoordModeMouse
    CoordMode("Mouse", "Screen")
    MouseGetPos(&screenX, &screenY, &mouseWin, &mouseCtrl, 2)
    CoordMode("Mouse", oldMode)

    UpdateHelpTip(screenX, screenY)

    if (screenX = lastX && screenY = lastY && mouseCtrl = lastCtrl && CurrentTab = lastTab)
        return
    lastX := screenX, lastY := screenY, lastCtrl := mouseCtrl, lastTab := CurrentTab

    if (mouseWin != hMain && mouseWin != hChild
        && (!hSettingsHost || mouseWin != hSettingsHost)
        && (!hSettingsPanel || mouseWin != hSettingsPanel)
        && !HoverHostHwnds.Has(mouseWin)) {
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
                        ctrl.PicControl.Value := "HBITMAP:*" ((HasProp(ctrl, "GradEnabled") && !ctrl.GradEnabled) ? ctrl.ImgDisabled : ctrl.ImgNormal)
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
        hoverOrigins := Map()
        stale := []

        for index, ctrl in HoverEffect {
            try {
                if (!ctrl.Visible)
                    continue

                ownerHwnd := DllCall("user32\GetParent", "Ptr", ctrl.Hwnd, "Ptr")
                if (!ownerHwnd)
                    continue
                if (!hoverOrigins.Has(ownerHwnd)) {
                    WinGetPos(&oX, &oY, , , "ahk_id " ownerHwnd)
                    hoverOrigins[ownerHwnd] := [oX, oY]
                }
                origin := hoverOrigins[ownerHwnd]

                ctrl.GetPos(&cX, &cY, &cW, &cH)
                localX := screenX - origin[1]
                localY := screenY - origin[2]

                if (localX >= cX && localX <= cX + cW && localY >= cY && localY <= cY + cH) {
                    matchedAny := true
                    if (activeHoverHwnd != ctrl.Hwnd) {
                        if (activeHoverHwnd != 0)
                            ClearHoverStyle(activeHoverHwnd)
                        ApplyHoverStyle(ctrl, true)
                        activeHoverHwnd := ctrl.Hwnd
                    }
                    break
                }
            } catch {
                stale.Push(index)
            }
        }

        loop stale.Length
            HoverEffect.RemoveAt(stale[stale.Length - A_Index + 1])

        if (!matchedAny && activeHoverHwnd != 0) {
            ClearHoverStyle(activeHoverHwnd)
            activeHoverHwnd := 0
        }
    }
    if (IsSet(GradientButtons)) {
        matchedGrad := false
        originCache := Map()

        for ctrl in GradientButtons {
            if (!ctrl.Visible)
                continue
            if (HasProp(ctrl, "GradEnabled") && !ctrl.GradEnabled)
                continue

            ownerHwnd := DllCall("user32\GetParent", "Ptr", ctrl.Hwnd, "Ptr")
            if (!ownerHwnd)
                continue
            if (!originCache.Has(ownerHwnd)) {
                try {
                    WinGetPos(&oX, &oY, , , "ahk_id " ownerHwnd)
                    originCache[ownerHwnd] := [oX, oY]
                } catch {
                    originCache[ownerHwnd] := [0, 0]
                }
            }
            origin := originCache[ownerHwnd]
            childMouseX := screenX - origin[1]
            childMouseY := screenY - origin[2]

            ctrl.GetPos(&cX, &cY, &cW, &cH)

            if (childMouseX >= cX && childMouseX <= cX + cW && childMouseY >= cY && childMouseY <= cY + cH) {
                matchedGrad := true
                if (activeGradHwnd != ctrl.Hwnd) {

                    if (activeGradHwnd != 0) {
                        for oldCtrl in GradientButtons {
                            if (oldCtrl.Hwnd = activeGradHwnd) {
                                if (HasProp(oldCtrl, "PicControl"))
                                    oldCtrl.PicControl.Value := "HBITMAP:*" ((HasProp(oldCtrl, "GradEnabled") && !oldCtrl.GradEnabled) ? oldCtrl.ImgDisabled : oldCtrl.ImgNormal)
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
                        ctrl.PicControl.Value := "HBITMAP:*" ((HasProp(ctrl, "GradEnabled") && !ctrl.GradEnabled) ? ctrl.ImgDisabled : ctrl.ImgNormal)
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
    HideSettingsPage()
}

ShowTabContent(tab) {
    global ChildGui
    if (tab = "Tab1") {
        for ctrl in [Tab1_Section1, Tab1_Line1, Tab1_Lbl1, Strategy1Ctrl, Tab1_Btn1, Tab1_Btn2,
            Tab1_Lbl2, Strategy2Ctrl, Tab1_Btn3, Tab1_Btn4, RotateStrategiesCtrl, AutoEquipCtrl, AutoConfigCtrl, Tab1_Section2,
            Tab1_Line2, BtnCommStrats, BtnMyStrats,
            Tab1_Start, Tab1_Stop]
            ShowControl(ctrl)
        EnableStratRotation()
        ShowChildGui()
    } else if (tab = "Tab2") {
        for ctrl in [Tab2_Title, Tab2_Line1]
            ShowControl(ctrl)
        ShowCreateView(Recording ? "Record" : CreateView)
    } else if (tab = "Tab3") {
        for ctrl in TAB3
            ShowControl(ctrl)
    } else if (tab = "Tab4") {
        ShowDiscordPage(DiscordPage)
    } else if (tab = "Tab5") {
        ChainKeyCtrl.Value := ChainKey
        BeatKeyCtrl.Value := BeatKey
        CaravanKeyCtrl.Value := CaravanKey
        RaiseDeadKeyCtrl.Value := RaiseDeadKey
        HologramKeyCtrl.Value := HologramKey
        RepoKeyCtrl.Value := RepoKey
        CancelPlacementKeyCtrl.Value := CancelPlacementKey
        UpgradeTowerGCtrl.Value := UpgradeTowerGKey
        UpgradeTowerGBCtrl.Value := UpgradeTowerGBKey
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
        UpgradeDelayCtrl.Value := UpgradeDelay

        MouseSpeedTxt.Value := DefaultMouseSpeed
        MouseDelayTxt.Value := MouseDelay
        KeyDelayTxt.Value := KeyDelay
        RefreshHotkeyDisplays()

        SetKeybindStatus("")
        ShowSettingsPage()
    } else if (tab = "Tab6") {
        for ctrl in [Tools_Section, Tools_Section_Line, Tools_Info, Tools_Profiles_Section, Tools_Profiles_Line,
            ProfileExportBtn, ProfileImportBtn, ProfileManagerBtn,
            Auto_Ability, Auto_Spin, Auto_Consum,
            Tools_AbilityLbl, Tools_SpinLbl, Tools_ConsumLbl]
            ShowControl(ctrl)
        RestoreToolPreviews()
    } else if (tab = "Tab7") {
        for ctrl in [Credit_TITLE, Credit_Divider, Credit_Content, Credit_InfoBG, Credit_Info, Credit_Support,
            version_text, Divider, FooterBg, DiscordImg, YoutubeImg, githubImg]
            ShowControl(ctrl)
    }
}
ShowChildGui() {
    global ChildGui, FrameX, FrameY, FrameW, FrameH, MainGui
    ChildGui.Show("x" FrameX " y" FrameY " w" FrameW " h" FrameH)
}

CreateChooseControls() {
    return [Create_RecordTitle, Create_LabTitle, Create_RecordInfo, Create_LabInfo,
        Create_RecordBtn, Create_LabBtn, Create_ChooseLine, Create_ChooseHint]
}

CreateRecordControls() {
    return [Tab2_Lbl1, RecMapsD, Tab2_Lbl2, RecDiffCtrl, Tab2_Lbl4, RecTowersCtrl,
        Tab2_Lbl3, RecModifiersFrame, RecModifiersCtrl, Tab2_Info2, Tab2_Info1, Tab2_Line2, Tab2_Line3, Tab2_Line4,
        RecAutoChainCtrl, RecAutoCaravanCtrl, RecAutoDropCtrl, RecAutoSkipCtrl, RecAbilitySpamCtrl,
        RecMoveCtrl, DIRECTIONTEXTCtrl, RecMoveDirCtrl, Tab2_Txt4, RecMoveDurCtrl, Tab2_Info,
        Tab2_BackBtn, Tab2_Btn1, Tab2_Btn2]
}

SetControlVisible(ctrl, visible) {
    if (HasProp(ctrl, "PicControl"))
        ctrl.PicControl.Visible := visible
    ctrl.Visible := visible
}

ShowCreateView(view) {
    global CreateView, CurrentTab, Tab2_Title, MainGui

    CreateView := view
    if (CurrentTab != "Tab2")
        return

    onRecord := (view = "Record")
    Tab2_Title.Text := onRecord ? "Record a Strategy" : "Create a Strategy"

    for ctrl in CreateChooseControls()
        SetControlVisible(ctrl, !onRecord)
    for ctrl in CreateRecordControls()
        SetControlVisible(ctrl, onRecord)

    DllCall("RedrawWindow", "ptr", MainGui.Hwnd, "ptr", 0, "ptr", 0, "uint", 0x185)
}

ShowCreateRecordView(*) {
    ShowCreateView("Record")
}

ShowCreateChooseView(*) {
    global Recording

    if (Recording) {
        ModernMsgBox("Recording in progress",
            "Stop the current recording before going back.", "OK", "WARNING")
        return
    }
    ShowCreateView("Choose")
}

global StrategyLabState := "idle"
global StrategyLabDeadline := 0
global StrategyLabWindowTitle := "Ultimate Macro — Strategy Editor"

StrategyLabExePath() {
    return A_ScriptDir "\StrategyLab.exe"
}

StrategyLabWindow() {
    global StrategyLabWindowTitle

    prevMatchMode := A_TitleMatchMode
    SetTitleMatchMode(2)
    try
        return WinExist(StrategyLabWindowTitle)
    finally
        SetTitleMatchMode(prevMatchMode)
}

StrategyLabIsRunning() {
    return StrategyLabWindow() != 0
}

SetStrategyLabState(state) {
    global StrategyLabState, Create_LabBtn, Create_LabInfo

    StrategyLabState := state
    if (!IsSet(Create_LabBtn) || !Create_LabBtn)
        return

    if (state = "opening") {
        SetActionButtonLabel(Create_LabBtn, "Opening...", "neutral")
        SetActionButtonEnabled(Create_LabBtn, false)
    } else if (state = "open") {
        SetActionButtonLabel(Create_LabBtn, "Close Strategy Lab", "stop")
        SetActionButtonEnabled(Create_LabBtn, true)
    } else {
        SetActionButtonLabel(Create_LabBtn, "Open Strategy Lab", "neutral")
        SetActionButtonEnabled(Create_LabBtn, true)
    }

    if (IsSet(Create_LabInfo) && Create_LabInfo) {
        Create_LabInfo.Text := (state = "open")
            ? "Strategy Lab is open. Build a strategy from scratch or fine-tune an existing .strat file, then come back here."
            : "Open Strategy Lab, the standalone visual editor. Build a strategy from scratch or fine-tune an existing .strat file without playing a round."
    }
}

StrategyLabWatch() {
    global StrategyLabState, StrategyLabDeadline

    running := StrategyLabIsRunning()

    if (StrategyLabState = "opening") {
        if (running) {
            SetStrategyLabState("open")
            return
        }
        if (A_TickCount > StrategyLabDeadline) {
            SetStrategyLabState("idle")
            SetTimer(StrategyLabWatch, 0)
            LogToConsole("Strategy Lab did not start within the expected time.", true)
            ModernMsgBox("Strategy Lab did not open",
                "Strategy Lab was launched but never appeared.`n`nTry opening StrategyLab.exe directly to see what Windows reports.",
                "OK", "WARNING")
        }
        return
    }

    if (!running) {
        if (StrategyLabState != "idle")
            SetStrategyLabState("idle")
        SetTimer(StrategyLabWatch, 0)
    }
}

OpenStrategyLab(*) {
    global StrategyLabState, StrategyLabDeadline

    if (StrategyLabState = "opening")
        return

    if (StrategyLabState = "open") {
        CloseStrategyLab()
        return
    }

    labPath := StrategyLabExePath()
    if !FileExist(labPath) {
        ModernMsgBox("Strategy Lab not found",
            "StrategyLab.exe is missing from your Ultimate Macro folder.`n`nExpected it at:`n" labPath
            "`n`nRe-download the release package to restore it.",
            "OK", "WARNING")
        return
    }

    if StrategyLabIsRunning() {
        SetStrategyLabState("open")
        SetTimer(StrategyLabWatch, 1000)
        return
    }

    SetStrategyLabState("opening")

    try {
        Run('"' labPath '"', A_ScriptDir)
    } catch Error as err {
        SetStrategyLabState("idle")
        ModernMsgBox("Strategy Lab could not start",
            "Windows refused to launch Strategy Lab.`n`n" err.Message, "OK", "WARNING")
        return
    }

    StrategyLabDeadline := A_TickCount + 45000
    SetTimer(StrategyLabWatch, 500)
}

CloseStrategyLab(*) {
    hwnd := StrategyLabWindow()
    if (hwnd) {
        try WinClose("ahk_id " hwnd)
    }

    SetTimer(StrategyLabWatch, 300)
}

SettingsPanelHeight() {
    global SettingsPanelH
    return SettingsPanelH
}

SettingsMaxScroll() {
    global SettingsViewH
    return Max(0, SettingsPanelHeight() - SettingsViewH)
}

SettingsScrollWidth() {
    global SettingsViewW
    return SettingsViewW - 10
}

SettingsSetScrollPos(newPos) {
    global SettingsPanel, SettingsScrollPos, SettingsSlider, SettingsViewH, SettingsSliderH

    if (!IsSet(SettingsPanel) || !SettingsPanel)
        return

    newPos := Max(0, Min(Round(newPos), SettingsMaxScroll()))
    if (newPos = SettingsScrollPos)
        return

    delta := SettingsScrollPos - newPos
    SettingsScrollPos := newPos
    DllCall("ScrollWindow", "Ptr", SettingsPanel.Hwnd, "Int", 0, "Int", delta, "Ptr", 0, "Ptr", 0)

    if (SettingsSlider) {
        track := SettingsViewH - SettingsSliderH
        maxScroll := SettingsMaxScroll()
        thumbY := (track > 0 && maxScroll > 0) ? Round((newPos / maxScroll) * track) : 0
        SettingsSlider.Move(, thumbY)
    }

    DllCall("UpdateWindow", "Ptr", SettingsPanel.Hwnd)
    RedrawSettingsScrollbar()
}

RedrawSettingsScrollbar() {
    global SettingsSlider, SettingsSliderBG
    static RDW_INVALIDATE_NOW := 0x0101

    if (SettingsSliderBG)
        DllCall("user32\RedrawWindow", "Ptr", SettingsSliderBG.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", RDW_INVALIDATE_NOW)
    if (SettingsSlider)
        DllCall("user32\RedrawWindow", "Ptr", SettingsSlider.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", RDW_INVALIDATE_NOW)
}

ClipSiblings(hwnd) {
    static GWL_STYLE := -16
    static WS_CLIPSIBLINGS := 0x04000000

    if (!hwnd)
        return
    style := DllCall("user32\GetWindowLongPtrW", "Ptr", hwnd, "Int", GWL_STYLE, "Ptr")
    if (style & WS_CLIPSIBLINGS)
        return
    DllCall("user32\SetWindowLongPtrW", "Ptr", hwnd, "Int", GWL_STYLE, "Ptr", style | WS_CLIPSIBLINGS)
}

RefreshSettingsScrollbar() {
    global SettingsHostGui, SettingsPanel, SettingsSlider, SettingsSliderBG, SettingsSliderH
    global SettingsViewH, SettingsViewW, SettingsScrollPos

    contentH := SettingsPanelHeight()

    if (!SettingsSliderBG) {
        SettingsSliderBG := SettingsHostGui.Add("Progress",
            "x" (SettingsViewW - 8) " y0 w6 h" SettingsViewH " Disabled Background0A0A0A", 0)
        ClipSiblings(SettingsPanel.Hwnd)
    }

    ratio := (contentH > 0) ? (SettingsViewH / contentH) : 1
    SettingsSliderH := Max(40, Min(SettingsViewH, Round(SettingsViewH * ratio)))

    if (!SettingsSlider) {
        SettingsSlider := SettingsHostGui.Add("Progress",
            "x" (SettingsViewW - 8) " y0 w6 h" SettingsSliderH " Disabled Background3A86FF", 0)
    } else {
        SettingsSlider.Move(, , , SettingsSliderH)
    }

    hasScroll := (SettingsMaxScroll() > 0)
    SettingsSliderBG.Visible := hasScroll
    SettingsSlider.Visible := hasScroll

    SettingsPanel.Show("x0 y0 w" SettingsScrollWidth() " h" contentH)
    SettingsSetScrollPos(Min(SettingsScrollPos, SettingsMaxScroll()))
    RedrawSettingsScrollbar()
}

ShowSettingsPage(*) {
    global SettingsHostGui, SettingsViewX, SettingsViewY, SettingsViewW, SettingsViewH, MainGui

    SettingsHostGui.Show("x" SettingsViewX " y" SettingsViewY " w" SettingsViewW " h" SettingsViewH " NoActivate")
    RefreshSettingsScrollbar()
}

HideSettingsPage() {
    global SettingsHostGui
    if (IsSet(SettingsHostGui) && SettingsHostGui)
        try SettingsHostGui.Hide()
}

RepaintTransparentControl(ctrl) {
    if (!IsObject(ctrl))
        return

    parent := DllCall("user32\GetParent", "Ptr", ctrl.Hwnd, "Ptr")
    if (!parent)
        return

    rect := Buffer(16, 0)
    if !DllCall("user32\GetWindowRect", "Ptr", ctrl.Hwnd, "Ptr", rect)
        return

    DllCall("user32\MapWindowPoints", "Ptr", 0, "Ptr", parent, "Ptr", rect, "UInt", 2)
    DllCall("user32\InvalidateRect", "Ptr", parent, "Ptr", rect, "Int", true)
    DllCall("user32\UpdateWindow", "Ptr", parent)
}

SetStatusLabel(ctrl, text, color := "") {
    if (!IsSet(ctrl) || !IsObject(ctrl))
        return
    if (color != "")
        ctrl.SetFont("c" color)
    ctrl.Text := text
    RepaintTransparentControl(ctrl)
}

SetKeybindStatus(text, isError := false) {
    global Tab5_KeybindStatus
    if (!IsSet(Tab5_KeybindStatus) || !Tab5_KeybindStatus)
        return
    SetStatusLabel(Tab5_KeybindStatus, text, isError ? "FF6B6B" : "7E848E")
}

QueueKeybindSave(*) {
    QueueSettingSave("keybinds", AutoSaveKeybinds, 600)
}

AutoSaveKeybinds(*) {
    global ChainKey, BeatKey, CaravanKey, CancelPlacementKey, UpgradeTowerGKey, UpgradeTowerGBKey
    global RaiseDeadKey, HologramKey, RepoKey
    global PlaceTowerKey, UpgradeTowerKey, AlignCameraKey, ChangeDJTrackKey, SellTowerKey
    global DeleteTowerRecordingKey, RecordInputsKey, HoloKey, ChangeTargetsKey

    ClearPendingSettingSave("keybinds")

    tempChainKey := FirstKeyChar(ChainKeyCtrl.Value, ChainKey)
    tempBeatKey := FirstKeyChar(BeatKeyCtrl.Value, BeatKey)
    tempCaravanKey := FirstKeyChar(CaravanKeyCtrl.Value, CaravanKey)
    tempCancelPlacementKey := FirstKeyChar(CancelPlacementKeyCtrl.Value, CancelPlacementKey)
    tempUpgradeTowerGKey := FirstKeyChar(UpgradeTowerGCtrl.Value, UpgradeTowerGKey)
    tempUpgradeTowerGBKey := FirstKeyChar(UpgradeTowerGBCtrl.Value, UpgradeTowerGBKey)
    tempRaiseDeadKey := FirstKeyChar(RaiseDeadKeyCtrl.Value, RaiseDeadKey)
    tempRepoKey := FirstKeyChar(RepoKeyCtrl.Value, RepoKey)
    tempHologramKey := FirstKeyChar(HologramKeyCtrl.Value, HologramKey)

    tempPlaceTowerKey := NormalizeKey(PlaceTowerKeyCtrl.Value)
    tempUpgradeTowerKey := NormalizeKey(UpgradeTowerKeyCtrl.Value)
    tempAlignCameraKey := NormalizeKey(AlignCameraKeyCtrl.Value)
    tempChangeDJTrackKey := NormalizeKey(ChangeDJTrackKeyCtrl.Value)
    tempSellTowerKey := NormalizeKey(SellTowerKeyCtrl.Value)
    tempDeleteTowerRecordingKey := NormalizeKey(DeleteTowerRecordingKeyCtrl.Value)
    tempRecordInputsKey := NormalizeKey(RecordInputsKeyCtrl.Value)
    tempHoloKey := NormalizeKey(HoloKeyCtrl.Value)
    tempChangeTargetsKey := NormalizeKey(ChangeTargetsCTRL.Value)

    KeysToCheck := [
        { val: NormalizeKey(tempChainKey), name: "Call of Arms" },
        { val: NormalizeKey(tempBeatKey), name: "Drop the Beat" },
        { val: NormalizeKey(tempCaravanKey), name: "Support Caravan" },
        { val: NormalizeKey(tempCancelPlacementKey), name: "Cancel Placement" },
        { val: NormalizeKey(tempUpgradeTowerGKey), name: "Upgrade" },
        { val: NormalizeKey(tempUpgradeTowerGBKey), name: "Bottom path" },
        { val: tempPlaceTowerKey, name: "Place Tower" },
        { val: tempUpgradeTowerKey, name: "Upgrade Tower" },
        { val: tempAlignCameraKey, name: "Align Camera" },
        { val: tempChangeDJTrackKey, name: "Change DJ Track" },
        { val: tempSellTowerKey, name: "Sell Tower" },
        { val: tempDeleteTowerRecordingKey, name: "Delete Record" },
        { val: tempRecordInputsKey, name: "Record Inputs" },
        { val: tempHoloKey, name: "Hologram Tower" },
        { val: tempChangeTargetsKey, name: "Change Targets" },
        { val: NormalizeKey("^" tempRaiseDeadKey), name: "Raise the Dead" },
        { val: NormalizeKey("^" tempRepoKey), name: "Brawler Reposition" }
    ]

    usedKeys := Map()
    for item in KeysToCheck {
        if (item.val = "") {
            SetKeybindStatus("Not saved: " item.name " has no key assigned.", true)
            return
        }
        if usedKeys.Has(item.val) {
            SetKeybindStatus("Not saved: " usedKeys[item.val] " and " item.name " use the same key.", true)
            return
        }
        usedKeys[item.val] := item.name
    }

    oldRecordingKeys := [PlaceTowerKey, UpgradeTowerKey, AlignCameraKey, ChangeDJTrackKey,
        SellTowerKey, DeleteTowerRecordingKey, RecordInputsKey, HoloKey, ChangeTargetsKey,
        "~^" RepoKey, "~^" RaiseDeadKey]

    ChainKey := tempChainKey
    BeatKey := tempBeatKey
    CaravanKey := tempCaravanKey
    CancelPlacementKey := tempCancelPlacementKey
    UpgradeTowerGKey := tempUpgradeTowerGKey
    UpgradeTowerGBKey := tempUpgradeTowerGBKey
    RaiseDeadKey := tempRaiseDeadKey
    HologramKey := tempHologramKey
    RepoKey := tempRepoKey

    PlaceTowerKey := tempPlaceTowerKey
    UpgradeTowerKey := tempUpgradeTowerKey
    AlignCameraKey := tempAlignCameraKey
    ChangeDJTrackKey := tempChangeDJTrackKey
    SellTowerKey := tempSellTowerKey
    DeleteTowerRecordingKey := tempDeleteTowerRecordingKey
    RecordInputsKey := tempRecordInputsKey
    HoloKey := tempHoloKey
    ChangeTargetsKey := tempChangeTargetsKey

    RegisterRecordingHotkeys(oldRecordingKeys)

    SaveHotkeySetting("Chain", ChainKey)
    SaveHotkeySetting("Beat", BeatKey)
    SaveHotkeySetting("Caravan", CaravanKey)
    SaveHotkeySetting("CancelPlacement", CancelPlacementKey)
    SaveHotkeySetting("UpgradeTower", UpgradeTowerGKey)
    SaveHotkeySetting("UpgradeBottom", UpgradeTowerGBKey)
    SaveHotkeySetting("RaiseTheDead", RaiseDeadKey)
    SaveHotkeySetting("Hologram", HologramKey)
    SaveHotkeySetting("Repo", RepoKey)

    SaveRecordingHotkeySetting("PlaceTowerKey", PlaceTowerKey)
    SaveRecordingHotkeySetting("UpgradeTowerKey", UpgradeTowerKey)
    SaveRecordingHotkeySetting("AlignCameraKey", AlignCameraKey)
    SaveRecordingHotkeySetting("ChangeDJTrackKey", ChangeDJTrackKey)
    SaveRecordingHotkeySetting("SellTowerKey", SellTowerKey)
    SaveRecordingHotkeySetting("DeleteTowerRecordingKey", DeleteTowerRecordingKey)
    SaveRecordingHotkeySetting("RecordInputsKey", RecordInputsKey)
    SaveRecordingHotkeySetting("ChangeTargetsKey", ChangeTargetsKey)
    SaveRecordingHotkeySetting("HoloKey", HoloKey)

    SetKeybindStatus("Keybinds saved.")
}

FirstKeyChar(value, fallback) {
    trimmed := SubStr(RegExReplace(value, "\s", ""), 1, 1)
    return (trimmed = "") ? fallback : trimmed
}

ApplyTimeScaleMode(mode) {
    global TimeScaleMode, UseTimeScale, TimeScaleMultiplier

    TimeScaleMode := (mode = "") ? "OFF" : mode
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
    SaveOption("TimeScaleMode", TimeScaleMode)
}

AutoSaveUpgradeDelay(*) {
    global UpgradeDelay

    value := Trim(UpgradeDelayCtrl.Value)
    if (value = "")
        return
    UpgradeDelay := value
    SaveOption("UpgradeDelay", UpgradeDelay)
}

AutoSaveLegacyMode(ctrl, *) {
    global LegacyMode

    newValue := ctrl.Value
    if (newValue = LegacyMode)
        return

    if (newValue = 1) {
        if (A_ScreenHeight != 1080 || A_ScreenWidth != 1920)
            MsgBox("WARNING! Legacy mode works only for 1920x1080!", "Warning", 0x1030)
        MsgBox(
            "Changes how the image detection works. May not work for some people.`n`nWarning: some features - such as Auto Equip and Changing Tower Targeting - will not work with this mode!`n`nUltimate Macro will now restart to apply it.",
            "Legacy Mode", 0x1040)
    }

    LegacyMode := newValue
    SaveOption("LegacyMode", LegacyMode)
    Reload()
}

WireSettingsAutoSave() {
    global UseHForUpgrade, UseRestartBtn, UsePlayAgainBtn, CheckTheMap, UseNumbersForHotbar
    global CollectPlaytimeRewards, DebugConsole, PotatoMode, DefaultMouseSpeed, MouseDelay, KeyDelay
    global VipLink, UseVipServer, AlwaysOnTop

    for ctrl in [ChainKeyCtrl, BeatKeyCtrl, CaravanKeyCtrl, RaiseDeadKeyCtrl, HologramKeyCtrl, RepoKeyCtrl,
        CancelPlacementKeyCtrl, UpgradeTowerGCtrl, UpgradeTowerGBCtrl]
        ctrl.OnEvent("Change", QueueKeybindSave)

    for ctrl in [PlaceTowerKeyCtrl, UpgradeTowerKeyCtrl, AlignCameraKeyCtrl, ChangeDJTrackKeyCtrl,
        SellTowerKeyCtrl, DeleteTowerRecordingKeyCtrl, RecordInputsKeyCtrl, HoloKeyCtrl, ChangeTargetsCTRL]
        ctrl.OnEvent("Change", QueueKeybindSave)

    UseUpgradeHCtrl.OnEvent("Click", (c, *) => (
        UseHForUpgrade := c.Value,
        SaveOption("UseHotkeyForUpgrade", UseHForUpgrade)
    ))
    UseRestartBtnCtrl.OnEvent("Click", (c, *) => (
        UseRestartBtn := c.Value,
        SaveOption("UseRestartBtn", UseRestartBtn)
    ))
    UsePlayAgainBtnCtrl.OnEvent("Click", (c, *) => (
        UsePlayAgainBtn := c.Value,
        SaveOption("UsePlayAgainBtn", UsePlayAgainBtn)
    ))
    CheckTheMapCtrl.OnEvent("Click", (c, *) => (
        CheckTheMap := c.Value,
        SaveOption("CheckTheMap", CheckTheMap)
    ))
    UseNumbersForHotbarCtrl.OnEvent("Click", (c, *) => (
        UseNumbersForHotbar := c.Value,
        SaveOption("UseNumbers", UseNumbersForHotbar)
    ))
    CollectPlaytimeRewardsCtrl.OnEvent("Click", (c, *) => (
        CollectPlaytimeRewards := c.Value,
        SaveOption("CollectPlaytimeRewards", CollectPlaytimeRewards)
    ))

    TimeScaleModeCtrl.OnEvent("Change", (c, *) => ApplyTimeScaleMode(c.Text))
    UpgradeDelayCtrl.OnEvent("Change", (*) => AutoSaveUpgradeDelay())

    VipLinkCtrl.OnEvent("Change", (*) => RefreshVipServerStatus())
    AlwaysOnTopCtrl.OnEvent("Click", (c, *) => (
        AlwaysOnTop := c.Value,
        SaveOption("AlwaysOnTop", AlwaysOnTop),
        MainGui.Opt((AlwaysOnTop = 1 ? "+" : "-") "AlwaysOnTop")
    ))
    LegacyModeCtrl.OnEvent("Click", AutoSaveLegacyMode)

    DebugConsoleCtrl.OnEvent("Click", (c, *) => (
        DebugConsole := c.Value,
        SaveOption("DebugConsole", DebugConsole),
        (DebugConsole = 1) ? ShowDebugConsole() : HideDebugConsole()
    ))
    PotatoModeCtrl.OnEvent("Click", (c, *) => (
        PotatoMode := c.Value,
        SaveOption("PotatoMode", PotatoMode)
    ))
}

ResetSettingsToDefault(*) {
    global SettingsFile

    prompt := "Reset every setting on this page back to its default?`n`n"
    prompt .= "This restores the TDS keybinds, recording hotkeys, macro settings and advanced settings.`n`n"
    prompt .= "Your strategies, party settings, Discord settings and VIP link are not touched."

    if (ModernMsgBox("Reset to Default", prompt, "YES|NO", "QUESTION") != "YES")
        return

    defaults := Map(
        "Hotkeys", Map("Chain", "C", "Beat", "B", "Caravan", "J", "RaiseTheDead", "V",
            "Hologram", "K", "Repo", "L", "CancelPlacement", "Q", "UpgradeTower", "E", "UpgradeBottom", "Z"),
        "RecordingHotkeys", Map("PlaceTowerKey", "f", "UpgradeTowerKey", "^u", "AlignCameraKey", "^t",
            "ChangeDJTrackKey", "^d", "SellTowerKey", "^x", "DeleteTowerRecordingKey", "^b",
            "RecordInputsKey", "^+e", "HoloKey", "^!h", "ChangeTargetsKey", "^vkC0"),
        "Options", Map("TimeScaleMode", "OFF", "UpgradeDelay", 200, "UseRestartBtn", 1, "UsePlayAgainBtn", 1,
            "CheckTheMap", 1, "UseNumbers", 1, "UseHotkeyForUpgrade", 1, "CollectPlaytimeRewards", 1,
            "PotatoMode", 0, "DebugConsole", 0, "DefaultMouseSpeed", 2, "MouseDelay", 10, "KeyDelay", 20,
            "AlwaysOnTop", 0, "LegacyMode", 0)
    )

    for section, entries in defaults {
        for key, value in entries
            SaveSetting(SettingsFile, section, key, value)
    }

    ModernMsgBox("Settings reset",
        "Every setting on this page is back to its default.`n`nUltimate Macro will restart now to apply them.", "OK")
    Reload()
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

UpdateStrategyButtons() {
    global GradientButtons, Strategy1Path, Strategy2Path, RotateStrategies, RenderedBitmaps

    for ctrl in GradientButtons {
        if !HasProp(ctrl, "StratFile") || !HasProp(ctrl, "StratDiff")
            continue

        isLoaded := false
        if (Strategy1Path != "" && StrLower(ctrl.StratFile) == StrLower(Strategy1Path))
            isLoaded := true
        else if (Strategy2Path != "" && RotateStrategies && StrLower(ctrl.StratFile) == StrLower(Strategy2Path))
            isLoaded := true

        btnText := isLoaded ? "Currently Loaded" : "Load"

        if (isLoaded) {
            loadColor1 := "0xFF4b5563", loadColor2 := "0xFF374151"
            loadHover1 := "0xFF505A69", loadHover2 := "0xFF3A4557"
        } else if ((ctrl.StratDiff = "Hardcore" || ctrl.StratDiff = "Voidcore")) {
            loadColor1 := "0xff961ea1", loadColor2 := "0xff5f237a"
            loadHover1 := "0xffea00ff", loadHover2 := "0xff8d32b7"
        } else {
            loadColor1 := "0xFF147A6E", loadColor2 := "0xFF214B75"
            loadHover1 := "0xFF1CB5A2", loadHover2 := "0xFF3272B7"
        }

        width := HasProp(ctrl, "IsSmallBtn") && ctrl.IsSmallBtn ? 145 : 220

        hBtnNormal := CreateGradientButton(width, 38, 8, loadColor1, loadColor2, "0x40000000", "0x5dffffff", btnText, UIFont(), isLoaded ? (width==145?10:12) : 14, 1)
        if (!isLoaded)
            hBtnHover := CreateGradientButton(width, 38, 8, loadHover1, loadHover2, "0x60000000", "0x5dffffff", btnText, UIFont(), isLoaded ? (width==145?10:12) : 14, 1)
        else
            hBtnHover := hBtnNormal

        if (HasProp(ctrl, "ImgNormal") && ctrl.ImgNormal) {
            i := RenderedBitmaps.Length
            while (i > 0) {
                if (RenderedBitmaps[i] == ctrl.ImgNormal)
                    RenderedBitmaps.RemoveAt(i)
                i--
            }
            DisposeBitmap(ctrl.ImgNormal)
        }
        if (HasProp(ctrl, "ImgHover") && ctrl.ImgHover && ctrl.ImgHover != ctrl.ImgNormal) {
            i := RenderedBitmaps.Length
            while (i > 0) {
                if (RenderedBitmaps[i] == ctrl.ImgHover)
                    RenderedBitmaps.RemoveAt(i)
                i--
            }
            DisposeBitmap(ctrl.ImgHover)
        }

        RenderedBitmaps.Push(hBtnNormal)
        if (!isLoaded)
            RenderedBitmaps.Push(hBtnHover)

        ctrl.ImgNormal := hBtnNormal
        ctrl.ImgHover := hBtnHover
        ctrl.PicControl.Value := "HBITMAP:*" hBtnNormal
    }
}

DownloadStrat(ctrl, *) {
    global Strategy1Path, Strategy2Path, RotateStrategies
    nm := ctrl.StratFile

    if (RegExMatch(nm, "^[a-zA-Z]:\\")) {
        downloadedStrat := nm
    } else {
        downloadedStrat := A_WorkingDir "\Resources\Strats" (SubStr(nm, 1, 1) = "\" ? nm : "\" nm)
    }

    isAlreadyLoaded := false
    if (Strategy1Path != "" && StrLower(downloadedStrat) == StrLower(Strategy1Path))
        isAlreadyLoaded := true
    else if (Strategy2Path != "" && RotateStrategies && StrLower(downloadedStrat) == StrLower(Strategy2Path))
        isAlreadyLoaded := true

    if (isAlreadyLoaded)
        return

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

    UpdateStrategyButtons()
}

HandleStrategyDrop(guiObj, ctrlObj, fileArray, dropX, dropY) {
    global RecordingsDir

    added := 0
    skipped := 0
    failures := []

    for droppedPath in fileArray {
        if !RegExMatch(droppedPath, "i)\.strat$") {
            skipped++
            continue
        }

        SplitPath(droppedPath, &droppedName)
        destination := RecordingsDir "\" droppedName

        if (StrLower(droppedPath) = StrLower(destination)) {
            skipped++
            continue
        }

        if FileExist(destination) {
            prompt := "'" droppedName "' already exists in My Strats.`n`nReplace it?"
            if (ModernMsgBox("Strategy already exists", prompt, "YES|NO", "QUESTION") != "YES") {
                skipped++
                continue
            }
        }

        try {
            if !DirExist(RecordingsDir)
                DirCreate(RecordingsDir)
            FileMove(droppedPath, destination, 1)
            added++
        } catch Error {
            try {
                FileCopy(droppedPath, destination, 1)
                added++
            } catch Error as copyErr {
                failures.Push(droppedName ": " copyErr.Message)
            }
        }
    }

    if (added > 0) {
        LogToConsole("Added " added " strategy file(s) to My Strats.")
        SwitchStrategiesTab("MyStrats")
    }

    if (failures.Length > 0) {
        ModernMsgBox("Some strategies were not added",
            "These files could not be moved into My Strats:`n`n" Join(failures, "`n"), "OK", "WARNING")
    } else if (added = 0 && skipped > 0) {
        ModernMsgBox("Nothing to add",
            "Only .strat files can be added to My Strats.", "OK", "WARNING")
    }
}

OpenMyStratsFolder(*) {
    global RecordingsDir

    try {
        if !DirExist(RecordingsDir)
            DirCreate(RecordingsDir)
        Run('explorer.exe "' RecordingsDir '"')
    } catch Error as err {
        ModernMsgBox("Could not open the folder",
            "Ultimate Macro could not open:`n" RecordingsDir "`n`n" err.Message, "OK", "WARNING")
    }
}

EditStratFile(ctrl, *) {
    global CurrentScrollPos, CurrentStratTabMode
    stratToEdit := ctrl.StratFile
    if FileExist(stratToEdit) {
        RunWait("notepad.exe `"" stratToEdit "`"")
        savedScroll := CurrentScrollPos
        RenderStrategies(CurrentStratTabMode)
        SetScrollPos(savedScroll)
    } else {
        MsgBox("Strategy file not found!`n" stratToEdit, "Error", 0x10)
    }
}

OnMouseWheel(wp, lp, msg, hwnd) {
    global ChildHwnd, ChildGui, ContentGui, SettingsHostGui, SettingsPanel, SettingsScrollPos, CurrentTab
    MouseGetPos(, , &maxH, &ctrlH, 2)

    parentH := (ctrlH != "") ? DllCall("GetParent", "Ptr", ctrlH, "Ptr") : 0
    ch := (IsSet(ChildGui) && ChildGui != "") ? ChildGui.Hwnd : 0
    co := (IsSet(ContentGui) && ContentGui != "") ? ContentGui.Hwnd : 0

    if (ch && (maxH = ch || maxH = co || ctrlH = ch || ctrlH = co || parentH = ch || parentH = co)) {

        dir := ((wp >> 16) & 0xFFFF) > 0x7FFF ? 1 : 0
        loop 3 {
            SendMessage(0x0115, dir, 0, , "ahk_id " ch)
        }
        return
    }

    if (IsSet(CurrentTab) && CurrentTab = "Tab5" && IsSet(SettingsHostGui) && SettingsHostGui) {
        sh := SettingsHostGui.Hwnd
        sp := (IsSet(SettingsPanel) && SettingsPanel) ? SettingsPanel.Hwnd : 0
        grandParentH := parentH ? DllCall("GetParent", "Ptr", parentH, "Ptr") : 0

        if (maxH = sh || maxH = sp || ctrlH = sh || ctrlH = sp
            || parentH = sh || parentH = sp || grandParentH = sh || grandParentH = sp) {
            step := (((wp >> 16) & 0xFFFF) > 0x7FFF) ? 60 : -60
            SettingsSetScrollPos(SettingsScrollPos + step)
        }
    }
}

ScrollMaxOffset() {
    global ContentH, FrameH
    return Max(0, ContentH - FrameH)
}

ScrollThumbY(pos) {
    global FrameH, SliderH
    track := FrameH - SliderH
    maxScroll := ScrollMaxOffset()
    if (track <= 0 || maxScroll <= 0)
        return 0
    return Round((pos / maxScroll) * track)
}

ScrollPosFromThumbY(thumbY) {
    global FrameH, SliderH
    track := FrameH - SliderH
    if (track <= 0)
        return 0
    thumbY := Max(0, Min(thumbY, track))
    return Round((thumbY / track) * ScrollMaxOffset())
}

SetScrollPos(newPos) {
    global ContentGui, CurrentScrollPos, Slider

    if (!IsSet(ContentGui) || ContentGui == "")
        return

    newPos := Max(0, Min(Round(newPos), ScrollMaxOffset()))
    if (newPos = CurrentScrollPos)
        return

    hwnd := ContentGui.Hwnd
    DllCall("ScrollWindow", "Ptr", hwnd, "Int", 0, "Int", CurrentScrollPos - newPos, "Ptr", 0, "Ptr", 0)
    CurrentScrollPos := newPos
    if (IsSet(Slider) && Slider)
        Slider.Move(, ScrollThumbY(newPos))
    DllCall("UpdateWindow", "Ptr", hwnd)
}

TryBeginScrollDrag() {
    global ContentGui, Slider, SliderX, SliderW, SliderH, CurrentScrollPos, FrameH
    global ScrollDragging, ScrollDragGrab

    if (!IsSet(ContentGui) || ContentGui == "" || !IsSet(Slider))
        return false
    if (ScrollMaxOffset() <= 0)
        return false
    if !DllCall("user32\IsWindowVisible", "Ptr", ContentGui.Hwnd, "Int")
        return false

    oldMode := A_CoordModeMouse
    CoordMode("Mouse", "Screen")
    MouseGetPos(&screenX, &screenY)
    CoordMode("Mouse", oldMode)

    try WinGetPos(&childX, &childY, , , "ahk_id " ContentGui.Hwnd)
    catch
        return false

    localX := screenX - childX
    localY := screenY - childY

    if (localY < 0 || localY > FrameH)
        return false
    if (localX < SliderX - 5 || localX > SliderX + SliderW + 5)
        return false

    thumbY := ScrollThumbY(CurrentScrollPos)
    if (localY >= thumbY && localY <= thumbY + SliderH) {
        ScrollDragGrab := localY - thumbY
    } else {
        ScrollDragGrab := SliderH // 2
        SetScrollPos(ScrollPosFromThumbY(localY - ScrollDragGrab))
    }

    ScrollDragging := true
    SetTimer(ScrollDragWatch, 10)
    return true
}

ScrollDragWatch() {
    global ContentGui, ScrollDragging, ScrollDragGrab

    try {
        if (!ScrollDragging || !GetKeyState("LButton", "P") || !IsSet(ContentGui) || ContentGui == "") {
            StopScrollDrag()
            return
        }
        childHwnd := ContentGui.Hwnd
        if (!childHwnd || !WinExist("ahk_id " childHwnd)) {
            StopScrollDrag()
            return
        }

        oldMode := A_CoordModeMouse
        try {
            CoordMode("Mouse", "Screen")
            MouseGetPos(, &screenY)
        } finally CoordMode("Mouse", oldMode)

        try WinGetPos(, &childY, , , "ahk_id " childHwnd)
        catch {
            StopScrollDrag()
            return
        }

        SetScrollPos(ScrollPosFromThumbY(screenY - childY - ScrollDragGrab))
    } catch Error as err {
        StopScrollDrag()
    }
}

StopScrollDrag() {
    global ScrollDragging
    ScrollDragging := false
    try SetTimer(ScrollDragWatch, 0)
}

OnScroll(wp, lp, msg, hwnd) {
    global ChildGui, CurrentScrollPos
    if (hwnd != ChildGui.Hwnd)
        return

    action := wp & 0xFFFF
    if (action = 0)
        SetScrollPos(CurrentScrollPos - 3)
    else if (action = 1)
        SetScrollPos(CurrentScrollPos + 3)
}

RegisterHoverEffect(ctrl, kind := "button") {
    global HoverEffect
    ctrl.HoverKind := kind
    HoverEffect.Push(ctrl)
    ApplyHoverStyle(ctrl, false)
    return ctrl
}

ApplyHoverStyle(ctrl, hovered) {
    kind := HasProp(ctrl, "HoverKind") ? ctrl.HoverKind : "button"
    if (kind = "plain")
        return

    selected := HasProp(ctrl, "IsSelected") && ctrl.IsSelected

    if (kind = "dialog") {
        accent := HasProp(ctrl, "AccentButton") && ctrl.AccentButton
        ctrl.Opt(hovered ? "Background2E2E2E" : "Background1B1B1B")
        ctrl.SetFont(hovered ? "c3A86FF" : (accent ? "c3A86FF" : "cFFFFFF"))
        try ctrl.Redraw()
        return
    }

    if (kind = "stepper") {
        ctrl.Opt(hovered ? "Background2E2E2E" : "Background1B1B1B")
        ctrl.SetFont(hovered ? "c3A86FF" : "cE2E4E7")
        try ctrl.Redraw()
        return
    }

    if (kind = "nav") {
        ctrl.Opt(selected ? "Background1B1B1B" : "BackgroundTrans")
        ctrl.SetFont(selected ? "c3A86FF Bold" : (hovered ? "cFFFFFF Norm" : "c888888 Norm"))
    } else if (kind = "caption") {
        ctrl.Opt("BackgroundTrans")
        ctrl.SetFont(hovered ? "c3A86FF Norm" : "cFFFFFF Norm")
    } else {
        ctrl.Opt((hovered || selected) ? "Background222222" : "Background0e0e0f")
        ctrl.SetFont((hovered || selected) ? "c3A86FF Bold" : "cFFFFFF Norm")
    }

    try ctrl.Redraw()
}

ClearHoverStyle(hwnd) {
    global HoverEffect
    for ctrl in HoverEffect {
        try {
            if (ctrl.Hwnd = hwnd) {
                ApplyHoverStyle(ctrl, false)
                return
            }
        }
    }
}

RegisterHoverHost(guiObj) {
    global HoverHostHwnds
    if (IsObject(guiObj) && guiObj.Hwnd)
        HoverHostHwnds[guiObj.Hwnd] := true
}

UnregisterHoverHost(guiObj) {
    global HoverHostHwnds, HoverEffect
    if (!IsObject(guiObj))
        return
    try {
        if HoverHostHwnds.Has(guiObj.Hwnd)
            HoverHostHwnds.Delete(guiObj.Hwnd)
    }

    kept := []
    for ctrl in HoverEffect {
        try {
            if (DllCall("user32\GetParent", "Ptr", ctrl.Hwnd, "Ptr") != guiObj.Hwnd)
                kept.Push(ctrl)
        }
    }
    HoverEffect := kept
}

GetControlScreenRect(hwnd, &x, &y, &w, &h) {
    rect := Buffer(16, 0)
    if !DllCall("user32\GetWindowRect", "Ptr", hwnd, "Ptr", rect, "Int")
        return false
    x := NumGet(rect, 0, "Int")
    y := NumGet(rect, 4, "Int")
    w := NumGet(rect, 8, "Int") - x
    h := NumGet(rect, 12, "Int") - y
    return (w > 0 && h > 0)
}

RegisterHelpTip(ctrl, body) {
    global HelpTips
    HelpTips[ctrl.Hwnd] := { ctrl: ctrl, body: body }
    ctrl.SetFont("c7E848E")
    ctrl.OnEvent("Click", HelpTipClicked)
    return ctrl
}

HelpTipClicked(ctrl, *) {
    ShowHelpTip(ctrl.Hwnd)
}

ShowHelpTip(hwnd) {
    global HelpTips, HelpTipGui, HelpTipOwner, MainGui

    if (!HelpTips.Has(hwnd))
        return
    if (HelpTipOwner = hwnd && HelpTipGui)
        return

    HideHelpTip()

    entry := HelpTips[hwnd]
    if !GetControlScreenRect(hwnd, &ownerX, &ownerY, &ownerW, &ownerH)
        return

    HelpTipGui := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20 +Border +Owner" MainGui.Hwnd)
    HelpTipGui.BackColor := "1B1B1B"
    HelpTipGui.MarginX := 0
    HelpTipGui.MarginY := 0
    HelpTipGui.SetFont("s9 w400 cE2E4E7", UIFont())

    body := HelpTipGui.Add("Text", "x14 y12 w300 BackgroundTrans", entry.body)
    body.GetPos(, , , &textH)
    tipW := 328
    tipH := textH + 24

    tipX := ownerX + ownerW + 10
    tipY := ownerY + (ownerH // 2) - (tipH // 2)

    if (tipX + tipW > A_ScreenWidth - 8)
        tipX := ownerX - tipW - 10
    if (tipX < 8)
        tipX := 8
    if (tipY + tipH > A_ScreenHeight - 8)
        tipY := A_ScreenHeight - 8 - tipH
    if (tipY < 8)
        tipY := 8

    HelpTipOwner := hwnd
    HelpTipGui.Show("x" tipX " y" tipY " w" tipW " h" tipH " NoActivate")
}

HideHelpTip() {
    global HelpTipGui, HelpTipOwner

    if (HelpTipGui) {
        try HelpTipGui.Destroy()
        HelpTipGui := 0
    }
    HelpTipOwner := 0
}

UpdateHelpTip(screenX, screenY) {
    global HelpTips, HelpTipOwner

    for hwnd, entry in HelpTips {
        if !DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int")
            continue
        if !GetControlScreenRect(hwnd, &cx, &cy, &cw, &ch)
            continue
        if (screenX >= cx && screenX <= cx + cw && screenY >= cy && screenY <= cy + ch) {
            ShowHelpTip(hwnd)
            return
        }
    }

    if (HelpTipOwner)
        HideHelpTip()
}

ActionButtonClick(ctrl, *) {
    if (HasProp(ctrl, "GradEnabled") && !ctrl.GradEnabled)
        return
    if (HasProp(ctrl, "ActionHandler") && IsObject(ctrl.ActionHandler))
        ctrl.ActionHandler.Call(ctrl)
}

BuildActionButtonImages(btn) {
    tone := btn.ActionTone
    w := btn.ActionW
    h := btn.ActionH
    label := btn.ActionLabel

    if (tone = "start")
        c1 := "0xFF1E8A5E", c2 := "0xFF0F5C3D", k1 := "0xFF2FBE81", k2 := "0xFF17805A"
    else if (tone = "stop")
        c1 := "0xFF8C333F", c2 := "0xFF561F27", k1 := "0xFFC24C5A", k2 := "0xFF7B2D39"
    else
        c1 := "0xFF2C63C4", c2 := "0xFF1A3A7C", k1 := "0xFF3A86FF", k2 := "0xFF2657AC"

    for old in [HasProp(btn, "ImgNormal") ? btn.ImgNormal : 0,
        HasProp(btn, "ImgHover") ? btn.ImgHover : 0,
        HasProp(btn, "ImgDisabled") ? btn.ImgDisabled : 0]
        DisposeBitmap(old)

    btn.ImgNormal := CreateGradientButton(w, h, 8, c1, c2, "0x40000000", "0x5DFFFFFF", label, UIFont(), 13, 1)
    btn.ImgHover := CreateGradientButton(w, h, 8, k1, k2, "0x60000000", "0x8CFFFFFF", label, UIFont(), 13, 1)
    btn.ImgDisabled := CreateGradientButton(w, h, 8, "0xFF23262C", "0xFF17191E", "0x20000000", "0x30FFFFFF", label,
        UIFont(), 13, 1)
}

MakeActionButton(guiObj, x, y, w, h, label, handler, tone := "accent", hidden := false) {
    global GradientButtons

    box := "x" x " y" y " w" w " h" h " +BackgroundTrans" (hidden ? " Hidden" : "")
    pic := guiObj.Add("Picture", box, "")
    btn := guiObj.Add("Text", box " +0x200 Center", "")

    btn.ActionTone := tone
    btn.ActionW := w
    btn.ActionH := h
    btn.ActionLabel := label
    btn.ActionHandler := handler
    btn.PicControl := pic
    btn.GradEnabled := true

    BuildActionButtonImages(btn)
    pic.Value := "HBITMAP:*" btn.ImgNormal

    btn.OnEvent("Click", ActionButtonClick)
    GradientButtons.Push(btn)
    return btn
}

SetActionButtonLabel(btn, label, tone := "") {
    if (!IsSet(btn) || !btn || !HasProp(btn, "PicControl"))
        return
    if (tone = "")
        tone := btn.ActionTone
    if (btn.ActionLabel = label && btn.ActionTone = tone)
        return

    btn.ActionLabel := label
    btn.ActionTone := tone
    BuildActionButtonImages(btn)
    btn.PicControl.Value := "HBITMAP:*" (btn.GradEnabled ? btn.ImgNormal : btn.ImgDisabled)
    btn.PicControl.Redraw()
}

SetActionButtonEnabled(btn, enabled) {
    if (!IsSet(btn) || !btn || !HasProp(btn, "PicControl"))
        return
    btn.GradEnabled := enabled ? true : false
    btn.PicControl.Value := "HBITMAP:*" (enabled ? btn.ImgNormal : btn.ImgDisabled)
    btn.PicControl.Redraw()
}

ShowControl(ctrl) {
    if (HasProp(ctrl, "PicControl"))
        ctrl.PicControl.Visible := true
    ctrl.Visible := true
}

EnableStratRotation(*) {
    global RotateStrategies, SwapAmount, SwapUnit

    RotateStrategies := RotateStrategiesCtrl.Value
    IniWrite(RotateStrategies, SettingsFile, "Options", "RotateStrategies")

    show := (RotateStrategies = 1)
    Tab1_Lbl2.Visible := show
    Strategy2Ctrl.Visible := show
    Tab1_Btn3.Visible := show
    Tab1_Btn4.Visible := show
    SwapAfterLbl.Visible := show
    SwapAmountCtrl.Visible := show
    SwapUnitCtrl.Visible := show

    if (show) {
        SwapAmount := SwapAmountCtrl.Text
        SwapUnit := SwapUnitCtrl.Text
        IniWrite(SwapAmount, SettingsFile, "Options", "SwapAmount")
        IniWrite(SwapUnit, SettingsFile, "Options", "SwapUnit")
    }

    UpdateStrategyButtons()
}

EnableAutoEquip(ctrl, *) {
    global AutoEquip

    AutoEquip := ctrl.Value
    IniWrite(AutoEquip, SettingsFile, "Options", "AutoEquip")
}

EnableAutoConfig(ctrl, *) {
    global AutoConfigureSettings, SettingsFile, AutoConfigCtrl

    AutoConfigureSettings := ctrl.Value ? 1 : 0
    IniWrite(AutoConfigureSettings, SettingsFile, "Options", "AutoConfigureSettings")

    if (AutoConfigureSettings) {
        if !CancelPendingAutoSettingsRestore() {
            AutoConfigureSettings := 0
            AutoConfigCtrl.Value := 0
            IniWrite(0, SettingsFile, "Options", "AutoConfigureSettings")
            ModernMsgBox("Auto Settings unavailable",
                "Ultimate Macro could not safely cancel a pending restore.`n`nNo Roblox settings were changed. " GetAutoSettingsLastError(),
                "OK", "WARNING")
        }
    } else if !RequestAutoSettingsRestore(A_ScriptDir) {
        ModernMsgBox("Auto Settings restore pending",
            "The original Roblox settings backup is still preserved, but Ultimate Macro could not schedule the restore helper.`n`nClose Roblox and reopen Ultimate Macro to retry the restore.",
            "OK", "WARNING")
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
        UpdateStrategyButtons()
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
        UpdateStrategyButtons()
    }
}
ClearStrat1(ctrl, *) {
    global Strategy1Path
    Strategy1Ctrl.Value := ""
    Strategy1Path := ""
    IniWrite(" ", SettingsFile, "Options", "Strategy1")
    UpdateStrategyButtons()
}

ClearStrat2(ctrl, *) {
    global Strategy2Path
    Strategy2Ctrl.Value := ""
    Strategy2Path := ""
    IniWrite(" ", SettingsFile, "Options", "Strategy2")
    UpdateStrategyButtons()
}

SaveStrat1(ctrl, *) {
    global Strategy1Path, Strategy1Ctrl
    Strategy1Path := Strategy1Ctrl.Text
    IniWrite(Strategy1Ctrl.Text, SettingsFile, "Options", "Strategy1")
    SetTimer(DebouncedUpdateStrategyButtons, -500)
}

SaveStrat2(ctrl, *) {
    global Strategy2Path, Strategy2Ctrl
    Strategy2Path := Strategy2Ctrl.Text
    IniWrite(Strategy2Ctrl.Text, SettingsFile, "Options", "Strategy2")
    SetTimer(DebouncedUpdateStrategyButtons, -500)
}

DebouncedUpdateStrategyButtons() {
    UpdateStrategyButtons()
}

GetStrategyStartProblem() {
    global MainGui

    if (!IsSet(MainGui) || !MainGui)
        return "The macro UI is not ready."

    try {
        v := MainGui.Submit(false)
    } catch Error as err {
        return "Could not read the strategy settings: " err.Message
    }

    partyProblem := SyncPartySettingsFromGui(false)
    if (partyProblem != "")
        return partyProblem

    if (v.RotateStrategies = 1) {
        for num, path in [Trim(v.Strategy1), Trim(v.Strategy2)] {
            if (path = "" || !FileExist(path))
                return "Rotation strategy " num " is empty or missing."
        }
        return ""
    }

    if ((Trim(v.Strategy1) != "" && FileExist(Trim(v.Strategy1)))
        || (Trim(v.Strategy2) != "" && FileExist(Trim(v.Strategy2))))
        return ""

    return "No valid strategy file is selected."
}

QueueStrategyStart() {
    global RunningStrategy, Recording

    if (RunningStrategy)
        return "The macro is already running."
    if (Recording)
        return "The macro is currently recording."

    problem := GetStrategyStartProblem()
    if (problem != "")
        return problem

    SetTimer(StartStrategy, -100)
    return ""
}

StartStrategy(*) {
    if (RunningStrategy or Recording) {
        return
    }
    FlushPendingSettingSaves()
    g_IsFirstLaunch := Integer(IniRead(StateFile, "State", "IsFirstLaunch", 1))

    global RunningStrategy, CurrentRotationIndex, gamemap, difficulty, requiredTowers, modifiers
    global autoChain, autoCaravan, autoDropTheBeat, AutoSkip, AbilitySpam, MoveEnabled, MoveDirection, MoveDuration
    global AutorunStartTime, CurrentStratStartTime

    if !IsSet(MainGui) or !MainGui
        return

    partyProblem := SyncPartySettingsFromGui(false)
    if (partyProblem != "") {
        ModernMsgBox("Party settings incomplete",
            partyProblem "`n`nFill it in on the Party tab, or turn party mode off.", "OK", "WARNING")
        return
    }

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

    if !RunStrategy("", true) {
        if (RunningStrategy) {
            RuntimeLogError("strategy_lifecycle_failed", "Strategy lifecycle ended before completing its transition")
            StopStrategy()
        }
    }
}

StopStrategy(*) {
    global RunningStrategy, AutorunStartTime, Recording, MacroRecording, InputHookObj

    wasRunning := RunningStrategy
    if (wasRunning)
        RunningStrategy := false

    StopRuntimeTimers()
    if (wasRunning || Recording || MacroRecording)
        ReleaseHeldInput()
    KillSubmacros()

    if (wasRunning) {
        if (AutorunStartTime > 0) {
            runtime := FormatRuntime(AutorunStartTime)
            Coins := IniRead(StateFile, "State", "Coins", "0")
            Gems := IniRead(StateFile, "State", "Gems", "0")
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
        SafeReload()
        return
    }

    if (Recording) {
        StopRecord(0)
    }
}

ResolveRecordingChoice(value, choices) {
    value := Trim(value)
    if (value = "")
        return ""

    for candidate in choices {
        if (StrLower(candidate) = StrLower(value))
            return candidate
    }

    match := ""
    for candidate in choices {
        if (SubStr(StrLower(candidate), 1, StrLen(value)) = StrLower(value)) {
            if (match != "")
                return ""
            match := candidate
        }
    }
    return match
}

RecordingAutosavePath() {
    return A_AppData "\Ultimate_Macro\recording_autosave.strat"
}

BuildStrategyFileText(steps, width := 0, height := 0) {
    global gamemap, difficulty, requiredTowers, modifiers
    global autoChain, autoCaravan, autoDropTheBeat, AutoSkip, AbilitySpam
    global MoveEnabled, MoveDirection, MoveDuration, RecordingWidth, RecordingHeight

    if (width <= 0)
        width := RecordingWidth
    if (height <= 0)
        height := RecordingHeight

    text := "[Settings]`nmap=" gamemap "`ndifficulty=" difficulty "`nrequiredTowers=" requiredTowers
        . "`nmodifiers=" Join(modifiers)
        . "`nautoChain=" autoChain "`nautoCaravan=" autoCaravan "`nautoDropTheBeat=" autoDropTheBeat
        . "`nautoSkip=" AutoSkip "`nabilitySpam=" AbilitySpam "`nmoveEnabled=" MoveEnabled "`nmoveDirection=" MoveDirection
        . "`nmoveDuration=" MoveDuration "`n`n[DO NOT EDIT]`nwidth=" width "`nheight=" height
        . "`n`n[Steps]`n"

    for i, step in steps
        text .= step "`n"

    return text
}

RecordingAutosaveStart() {
    global RecordedSteps
    path := RecordingAutosavePath()
    try {
        if FileExist(path)
            FileDelete(path)
        FileAppend(BuildStrategyFileText(RecordedSteps), path, "UTF-8-RAW")
    } catch Error as err {
        RuntimeLogWarn("recording_autosave_start_failed", "Recording autosave could not be created",
            "error=" err.Message)
    }
}

RecordingAutosaveSnapshot(includeMacroSteps := false) {
    global RecordedSteps, MacroRecording, MacroSteps

    snapshot := []
    for step in RecordedSteps
        snapshot.Push(step)

    if (includeMacroSteps && MacroRecording) {
        for step in MacroSteps
            snapshot.Push(step)
    }
    return snapshot
}

RecordingAutosaveRewrite(includeMacroSteps := false) {
    global Recording
    if (!Recording)
        return
    path := RecordingAutosavePath()
    try {
        if FileExist(path)
            FileDelete(path)
        FileAppend(BuildStrategyFileText(RecordingAutosaveSnapshot(includeMacroSteps)), path, "UTF-8-RAW")
    } catch Error as err {
        RuntimeLogWarn("recording_autosave_rewrite_failed", "Recording autosave could not be rewritten",
            "error=" err.Message)
    }
}

FlushRecordingAutosaveSnapshot() {
    RecordingAutosaveRewrite(true)
}

ScheduleRecordingAutosaveSnapshot() {
    global Recording
    if Recording
        SetTimer(FlushRecordingAutosaveSnapshot, -250)
}

RecordMacroStep(step) {
    global MacroSteps
    MacroSteps.Push(step)
    ScheduleRecordingAutosaveSnapshot()
}

RecordingAutosaveDiscard() {
    path := RecordingAutosavePath()
    try {
        if FileExist(path)
            FileDelete(path)
    } catch Error as err {
        RuntimeLogWarn("recording_autosave_discard_failed", "Recording autosave could not be removed",
            "error=" err.Message)
    }
}

RecordingAutosaveRecover() {
    global RecordingsDir
    path := RecordingAutosavePath()
    if !FileExist(path)
        return

    stepCount := 0
    try {
        inSteps := false
        loop read, path {
            line := Trim(A_LoopReadLine)
            if (line ~= "i)^\[Steps\]") {
                inSteps := true
                continue
            }
            if (inSteps && line != "" && !(line ~= "^\["))
                stepCount++
        }
    } catch Error as err {
        RuntimeLogWarn("recording_autosave_scan_failed", "Interrupted recording could not be inspected",
            "error=" err.Message)
        return
    }

    if (stepCount = 0) {
        RecordingAutosaveDiscard()
        return
    }

    recovered := RecordingsDir "\Recovered_" FormatTime(, "yyyyMMdd-HHmmss") ".strat"
    try {
        FileMove(path, recovered, 1)
    } catch Error as err {
        RuntimeLogWarn("recording_autosave_recover_failed", "Interrupted recording could not be preserved",
            "error=" err.Message)
        return
    }

    RuntimeLogWarn("recording_autosave_recovered", "An interrupted recording was preserved",
        "steps=" stepCount "; file=" recovered)
    LogToConsole("A previous recording was interrupted. Its " stepCount " actions were saved to " recovered)
    MsgBox(
        "A previous recording was never saved.`n`nIts " stepCount " recorded actions were kept in:`n" recovered
        . "`n`nYou can load that file from the Main tab.",
        "Interrupted recording recovered",
        0x40
    )
}

RecordStep(step) {
    global RecordedSteps, MacroRecording
    RecordedSteps.Push(step)

    ; If raw-input recording is active, its in-memory steps are already part of
    ; the crash-safe snapshot. Rewrite atomically so the autosave never mixes a
    ; stale snapshot with newly appended structured actions.
    if MacroRecording {
        RecordingAutosaveRewrite(true)
        return
    }

    try
        FileAppend(step "`n", RecordingAutosavePath(), "UTF-8-RAW")
    catch Error as err
        RuntimeLogWarn("recording_autosave_append_failed", "A recorded action could not be mirrored to the autosave",
            "error=" err.Message)
}

FinalizeMacroInputRecording(promptToAdd := true) {
    global MacroRecording, InputHookObj, MacroSteps, RecordedSteps, KeyDownTimes

    if !MacroRecording
        return 0

    try SetTimer(FlushRecordingAutosaveSnapshot, 0)
    MacroRecording := false
    try {
        if (InputHookObj != "")
            InputHookObj.Stop()
    }
    InputHookObj := ""
    KeyDownTimes := Map()

    capturedCount := MacroSteps.Length
    addToStrategy := promptToAdd && capturedCount > 0
        && (ModernMsgBox("Add to Strategy?", "Add recorded actions to current strategy?", "YES|NO") = "YES")

    if addToStrategy {
        for step in MacroSteps
            RecordedSteps.Push(step)
    }

    MacroSteps := []
    RecordingAutosaveRewrite(false)
    return addToStrategy ? capturedCount : 0
}

StartRecording(ctrl, *) {
    global Recording, gamemap, difficulty, requiredTowers, modifiers, autoChain, autoCaravan
    global autoDropTheBeat, AutoSkip, AbilitySpam, MoveEnabled, MoveDirection, MoveDuration
    global Commander, RecordedSteps, Towers, MacroRecording, GuiTitleCtrl
    global Tab2_Btn1, Tab2_Btn2, HoverEffect
    global RecordingWidth, RecordingHeight, RecordedTowerIds
    global RecDiffCtrl, RecDifficultyChoices

    if (Recording)
        return

    RecordingAutosaveRecover()

    v := MainGui.Submit(false)

    if (!v.RecMaps or !v.RecDifficulty or !v.RecRequiredTowers) {
        MsgBox(
            "Failed to start recording!`nMake sure you have entered the towers, the map, and the difficulty, then try again.",
            "Error", 0x1010)
        return
    }

    resolvedDifficulty := ResolveRecordingChoice(v.RecDifficulty, RecDifficultyChoices)
    if (resolvedDifficulty = "") {
        MsgBox(
            "'" v.RecDifficulty "' is not a mode Ultimate Macro knows.`n`nPick one from the Mode list, or type enough of its name to match it.",
            "Unknown mode", 0x1010)
        return
    }
    if (resolvedDifficulty != v.RecDifficulty)
        RecDiffCtrl.Text := resolvedDifficulty

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

    SetActionButtonEnabled(Tab2_Btn1, false)
    SetActionButtonEnabled(Tab2_Btn2, true)

    if (IsSet(GuiTitleCtrl) && GuiTitleCtrl) {
        GuiTitleCtrl.SetFont("cff6b6b")
    }

    gamemap := v.RecMaps
    difficulty := resolvedDifficulty
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
    RecordedTowerIds := Map()
    DeleteAllIndicators()
    RecordingAutosaveStart()

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
        capturedCount := MacroSteps.Length
        addedCount := FinalizeMacroInputRecording(true)
        LogToConsole("Macro recording auto-stopped. Steps: " capturedCount)
        if (addedCount > 0)
            LogToConsole("Added " addedCount " macro steps to strategy")
    }

    if (!Recording)
        return
    Recording := false
    DeleteAllIndicators()

    SetActionButtonEnabled(Tab2_Btn1, true)
    SetActionButtonEnabled(Tab2_Btn2, false)

    if (IsSet(GuiTitleCtrl) && GuiTitleCtrl) {
        GuiTitleCtrl.SetFont("cWhite")
    }

    recordedCount := RecordedSteps.Length

    if (ModernMsgBox("Save", "Save the recorded strategy? (" recordedCount " actions)", "YES|NO") = "YES") {
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
                "The recording cannot be saved because its Roblox window size could not be determined.`n`n"
                . "Keep Roblox open and try again.`n`nYour " recordedCount " recorded actions are still kept in:`n"
                . RecordingAutosavePath(),
                "Recording geometry unavailable",
                0x10
            )
            return
        }

        fileName := ""
        loop {
            box := InputBox("File name (without .strat):", "Save", "w300 h130", "MyStrategy")
            if (box.Result = "Cancel") {
                LogToConsole("Strategy save cancelled. The recording is kept in " RecordingAutosavePath())
                return
            }
            fileName := SafeStrategyFileName(box.Value)
            if (fileName != "")
                break
            MsgBox("That file name cannot be used. Avoid these characters: " Chr(92) " / : * ? " Chr(34) " < > |",
                "Invalid file name", 0x30)
        }

        filePath := RecordingsDir "\" fileName ".strat"
        tempPath := filePath ".tmp"
        try {
            if FileExist(tempPath)
                FileDelete(tempPath)

            FileAppend(BuildStrategyFileText(RecordedSteps, strategyWidthToSave, strategyHeightToSave), tempPath,
                "UTF-8-RAW")
            FileMove(tempPath, filePath, 1)
        } catch Error as err {
            try {
                if FileExist(tempPath)
                    FileDelete(tempPath)
            }
            RuntimeLogError("recording_save_failed", "Recorded strategy save failed", "error=" err.Message)
            MsgBox(
                "The strategy could not be saved. Your previous file was left untouched.`n`n" err.Message
                . "`n`nYour " recordedCount " recorded actions are still kept in:`n" RecordingAutosavePath(),
                "Recording save failed",
                0x10
            )
            return
        }

        RecordingAutosaveDiscard()
        RuntimeLogInfo("recording_saved", "Recorded strategy written",
            "steps=" recordedCount "; file=" filePath)
        LogToConsole("Strategy saved: " filePath " (" recordedCount " actions)")
        Strategy1Ctrl.Value := filePath
    } else {
        RecordingAutosaveDiscard()
        LogToConsole("Recording cancelled, strategy not saved")
    }
}

SafeStrategyFileName(value) {
    value := Trim(value)
    if (value = "")
        return ""
    if RegExMatch(value, "[\\/:*?" Chr(34) "<>|]")
        return ""
    value := RegExReplace(value, "i)\.strat$", "")
    value := RegExReplace(value, "[. ]+$", "")
    return SubStr(Trim(value), 1, 120)
}

PlaceTowerHK(*) {
    global Recording, Towers, RecordedSteps, ActiveRTowerID, CachedMenuUI, isUiPositionSaved, UseNumbersForHotbar
    global RecordedTowerIds

    if (!Recording) {
        pureKey := RegExReplace(PlaceTowerKey, "[\^+!#]")
        SEND_modifiers := RegExMatch(PlaceTowerKey, "^([\^+!#]+)", &match) ? match[1] : ""

        SendEvent("{Blind}" SEND_modifiers "{" pureKey "}")
        return
    }

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
    RecordedTowerIds[towerID] := true
    UpdateTowerIndicator(towerID)
    LogToConsole("Recorded tower " towerID " (slot " slot ")")

    RecordStep("SpawnTower(" mx ", " my ", " slot ", " towerID ")")

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
            RecordStep("UpgradeTower(" closestID ", false, 1, " Towers[closestID].path ", " Towers[closestID].pathLevel ")"
            )
        } else {
            RecordStep("UpgradeTower(" closestID ")")
        }
        if (Towers[closestID].level >= 2 && RegExMatch(closestID, "i)^Commander\d*$") && !Commander) {
            Commander := true
            if (!HasStep("Commander := true"))
                RecordStep("Commander := true")
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
        RecordStep('SetDJTrack("' box.Value '")')
        LogToConsole("Recorded DJ-track " box.Value)
    }
}

DeleteTowerRecordingHK(*) {
    global Recording, Towers, RecordedSteps, RecordedTowerIds
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
        RecordingAutosaveRewrite()

        try {
            if Towers.Has(closestID) {
                Towers.Delete(closestID)
            }
        } catch {
        }
        if RecordedTowerIds.Has(closestID)
            RecordedTowerIds.Delete(closestID)

        LogToConsole("Removed tower " closestID " from the recording")
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
            Towers[closestID].hwnd := ""
        }
        RecordStep("SellTower(" closestID ")")
        SellTower(closestID)
        if Towers.Has(closestID)
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
        capturedCount := MacroSteps.Length
        addedCount := FinalizeMacroInputRecording(true)
        LogToConsole("Recording ALL clicks and keys STOPPED. Steps: " capturedCount)
        if (addedCount > 0)
            LogToConsole("Added " addedCount " steps to strategy")
        return
    }

    LogToConsole("Recording ALL clicks and keys...!")
    MacroSteps := []
    KeyDownTimes := Map()
    MacroStartTime := A_TickCount

    try {
        nextHook := InputHook("V")
        nextHook.KeyOpt("{All}", "N")
        nextHook.OnKeyDown := OnKeyDown
        nextHook.OnKeyUp := OnKeyUp
        nextHook.Start()

        InputHookObj := nextHook
        MacroRecording := true
        RecordingAutosaveRewrite(true)
        RuntimeLogInfo("raw_input_recording_started", "Raw input recording hook started successfully")
    } catch Error as err {
        MacroRecording := false
        InputHookObj := ""
        MacroSteps := []
        KeyDownTimes := Map()
        RecordingAutosaveRewrite(false)
        RuntimeLogError("raw_input_recording_start_failed", "Raw input recording hook could not start", "error=" err.Message)
        MsgBox("Ultimate Macro could not start raw input recording.`n`n" err.Message,
            "Input recording failed", 0x10)
    }
}

CloneTowerHK(*) {
    global Recording, RecordedSteps

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

    RecordStep("CloneTower(" towerID ", " mx ", " my ")")
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

    RecordStep("BrawlerReposition(" towerID ", " mx ", " my ")")
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

    RecordStep("ActivateRaiseTheDead(" waitTime ")")
}

RecordToggleAutoskip(*) {
    global Recording, AutoSkip
    if !Recording {
        return
    }

    v := MainGui.Submit(false)
    at := v.RecAutoSkip ? "ON" : "OFF"

    RecordStep("ToggleAutoskip()")

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

    RecordStep("ChangeTargets(" towerID ", " target ")")
    LogToConsole("Recorded ChangeTargets(" towerID ", " target ")")
}

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
                if (attempts > 3) {
                    SafeReload()
                    return false
                }
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

    if (!Towers.Has(towerID)) {
        LogToConsole("Cannot change targets: tower " towerID " is no longer available.", true)
        return false
    }

    targets := ["First Enemy", "Last Enemy", "Strongest", "Weakest", "Closest", "Farthest", "Random"]
    canUseAbility := false

    try {
        if (LastOpenedTowerID != towerID) {
            Click(Towers[towerID].x, Towers[towerID].y)
            Sleep 250
        } else {
            MouseMove(0, ScaleY(50), , "R")
        }

        LastOpenedTowerID := towerID
        needtocheckTowerUI := true
        attempts := 0

        LogToConsole("Changing " towerID " targets to " target "...")

        upgTime := A_TickCount
        loop {
        openedSuccessfully := false

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
                    return false
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

        if (targetIndex = 0) {
            LogToConsole("Cannot change tower " towerID ": unknown target '" target "'.", true)
            return false
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

        LastOpenedTowerID := ""
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
    } finally {
        canUseAbility := true
    }
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
                    return false
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
    RecordMacroStep("Sleep(" elapsed ")")
}

OnKeyUp(ih, vk, sc) {
    global MacroSteps, MacroStartTime, MacroRecording, KeyDownTimes
    if (!MacroRecording)
        return

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

    RecordMacroStep('Send("' keyName '", hold:=' holdDuration ')')

    idle := elapsed - holdDuration
    if (idle > 0) {
        RecordMacroStep("Sleep(" idle ")")
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
    RecordingAutosaveRewrite()
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
        RecordMacroStep("Sleep(" elapsed ")")
        RecordMacroStep("Click(" mx ", " my ", Right)")
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

        if (suppliedLevel = knownLevel - 1)
            return knownLevel
    }

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

AutoSaveBotSettings(*) {
    global BotToken, BotEnabled, ChannelID, UserID, BotPrefix
    static lastPrefixWarning := ""

    ClearPendingSettingSave("botsettings")

    BotToken := BotTokenCtrl.Value
    BotEnabled := BotEnabledCtrl.Value
    ChannelID := ChannelIDCtrl.Value
    UserID := WebhookUserIDCtrl2.Value

    SaveBotSetting("Token", "BotToken", BotToken)
    SaveBotSetting("Settings", "Enabled", BotEnabled)
    SaveBotSetting("Settings", "Channel", ChannelID)
    SaveBotSetting("Settings", "UserID", UserID)

    nextPrefix := Trim(BotPrefixCtrl.Value)
    if (nextPrefix = "") {
        lastPrefixWarning := ""
    } else if (StrLen(nextPrefix) != 1 || RegExMatch(nextPrefix, "[A-Za-z0-9\s]")) {
        if (lastPrefixWarning != nextPrefix) {
            lastPrefixWarning := nextPrefix
            ModernMsgBox("Invalid command prefix",
                "Use one non-alphanumeric character, such as !, ., or -.`n`nThe previous prefix (" BotPrefix ") is still in use.",
                "OK", "WARNING")
        }
    } else {
        lastPrefixWarning := ""
        BotPrefix := nextPrefix
        SaveBotSetting("Settings", "Prefix", BotPrefix)
    }

    if (BotEnabled && ChannelID != "" && UserID != "") {
        SetTimer(ProcessCommands, 7500, 1)
    } else {
        SetTimer(ProcessCommands, 0)
    }
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

NormalizePartyMembers(value) {
    normalized := ""
    loop parse, value, "," {
        member := Trim(A_LoopField)
        if (member = "")
            continue
        normalized .= (normalized = "" ? "" : ",") member
    }
    return normalized
}

IsPartyFieldUnset(value) {
    value := Trim(value)
    return (value = "" || value = "..." || value = "someone, someone..." || value = "someone,someone...")
}

PartyFieldValue(value) {
    return IsPartyFieldUnset(value) ? "" : Trim(value)
}

SetEditPlaceholder(ctrl, text) {
    static EM_SETCUEBANNER := 0x1501
    try SendMessage(EM_SETCUEBANNER, 0, StrPtr(text), ctrl)
}

ApplyDarkInputTheme(guiObj) {
    for hwnd, ctrl in guiObj {
        try {
            switch ctrl.Type {
                case "Edit":
                    try ctrl.Opt("Background181818")
                    try ctrl.SetFont("cE2E4E7")
                    EnableDarkInputFrame(ctrl.Hwnd, HasEditScrollBar(ctrl.Hwnd))
                case "ListBox":
                    try ctrl.Opt("Background181818")
                    try ctrl.SetFont("cE2E4E7")
                    EnableDarkInputFrame(ctrl.Hwnd, true)
                    RegisterDarkInputSurface(ctrl.Hwnd)
                case "ComboBox", "DDL":
                    try ctrl.Opt("Background181818")
                    try ctrl.SetFont("cE2E4E7")
                    EnableDarkComboBox(ctrl)
                case "Hotkey":
                    try ctrl.SetFont("cE2E4E7")
                    EnableDarkInputFrame(ctrl.Hwnd, false)
                    RegisterDarkInputSurface(ctrl.Hwnd)
                case "CheckBox":
                    EnableDarkInputFrame(ctrl.Hwnd, true)
            }
        }
    }
}

HasEditScrollBar(hwnd) {
    static WS_VSCROLL := 0x00200000
    static WS_HSCROLL := 0x00100000
    style := DllCall("user32\GetWindowLongPtrW", "Ptr", hwnd, "Int", -16, "Ptr")
    return (style & (WS_VSCROLL | WS_HSCROLL)) != 0
}

MakeDarkRadio(guiObj, x, y, labelWidth, label, extraOptions, checked, groupMembers) {
    radio := guiObj.Add("Radio", "x" x " y" y " w16 h22 Hidden " extraOptions " " (checked ? "Checked" : ""), "")
    EnableDarkInputFrame(radio.Hwnd, true)

    text := guiObj.Add("Text", "x" (x + 18) " y" y " w" labelWidth " h22 0x200 Hidden BackgroundTrans", label)
    text.OnEvent("Click", (*) => SelectDarkRadio(radio))

    radio.LabelCtrl := text
    radio.GroupMembers := groupMembers
    radio.OnEvent("Click", (*) => SelectDarkRadio(radio))
    groupMembers.Push(radio)
    return radio
}

SelectDarkRadio(radio) {
    for member in radio.GroupMembers {
        if (member.Hwnd = radio.Hwnd)
            continue
        if (member.Value)
            member.Value := 0
    }
    if (!radio.Value)
        radio.Value := 1

    AutoSavePartySettings()
}

FormatHotkeyLabel(value) {
    value := Trim(value)
    if (value = "")
        return ""

    seen := Map("^", false, "+", false, "!", false, "#", false)
    while (value != "" && seen.Has(SubStr(value, 1, 1))) {
        seen[SubStr(value, 1, 1)] := true
        value := SubStr(value, 2)
    }

    label := ""
    if (seen["^"])
        label .= "Ctrl + "
    if (seen["+"])
        label .= "Shift + "
    if (seen["!"])
        label .= "Alt + "
    if (seen["#"])
        label .= "Win + "

    keyName := value
    if RegExMatch(value, "i)^(sc[0-9a-f]+|vk[0-9a-f]+)$") {
        resolved := ""
        try resolved := GetKeyName(value)
        if (resolved != "")
            keyName := resolved
    }

    if (keyName = "")
        return Trim(label, " +")

    return label StrUpper(SubStr(keyName, 1, 1)) SubStr(keyName, 2)
}

MakeHotkeyField(guiObj, x, y, w, h, value) {
    global HotkeyFields

    hk := guiObj.Add("Hotkey", "x" x " y" y " w" w " h" h " Center Hidden", value)
    display := guiObj.Add("Edit", "x" x " y" y " w" w " h" h " Center ReadOnly -TabStop",
        FormatHotkeyLabel(value))
    display.Opt("Background181818")
    display.SetFont("cE2E4E7")

    hk.DisplayCtrl := display
    display.HotkeyCtrl := hk
    display.OnEvent("Focus", (c, *) => BeginHotkeyCapture(c.HotkeyCtrl))

    HotkeyFields.Push(hk)
    return hk
}

BeginHotkeyCapture(hk) {
    global ActiveHotkeyCapture

    if (!IsObject(hk) || ActiveHotkeyCapture = hk)
        return
    if (ActiveHotkeyCapture)
        EndHotkeyCapture()

    ActiveHotkeyCapture := hk
    hk.DisplayCtrl.Visible := false
    hk.Visible := true
    try ControlFocus(hk)
    SetTimer(WatchHotkeyCapture, 120)
}

EndHotkeyCapture() {
    global ActiveHotkeyCapture

    hk := ActiveHotkeyCapture
    ActiveHotkeyCapture := 0
    SetTimer(WatchHotkeyCapture, 0)
    if (!IsObject(hk))
        return

    hk.DisplayCtrl.Value := FormatHotkeyLabel(hk.Value)
    hk.Visible := false
    hk.DisplayCtrl.Visible := true
}

WatchHotkeyCapture() {
    global ActiveHotkeyCapture, MainGui

    if (!ActiveHotkeyCapture) {
        SetTimer(WatchHotkeyCapture, 0)
        return
    }

    focused := 0
    try focused := ControlGetFocus("ahk_id " MainGui.Hwnd)
    if (focused != ActiveHotkeyCapture.Hwnd)
        EndHotkeyCapture()
}

RefreshHotkeyDisplays() {
    global HotkeyFields

    for hk in HotkeyFields {
        try hk.DisplayCtrl.Value := FormatHotkeyLabel(hk.Value)
    }
}

MakeStepper(guiObj, x, y, handler) {
    AddDarkListFrame(guiObj, x, y, 15, 22, false)

    guiObj.SetFont("s6 w400 cE2E4E7", "Marlett")
    up := guiObj.Add("Text", "x" x " y" y " w15 h11 Center 0x200 Background1B1B1B", "5")
    down := guiObj.Add("Text", "x" x " y" (y + 11) " w15 h11 Center 0x200 Background1B1B1B", "6")
    guiObj.SetFont("s9 w400 cFFFFFF", UIFont())

    up.OnEvent("Click", (*) => handler(1))
    down.OnEvent("Click", (*) => handler(-1))
    RegisterHoverEffect(up, "stepper")
    RegisterHoverEffect(down, "stepper")
    return { up: up, down: down }
}

StepMouseSpeed(delta) {
    global DefaultMouseSpeed, MouseSpeedTxt

    current := IsNumber(DefaultMouseSpeed) ? Integer(DefaultMouseSpeed) : 2
    value := Max(1, Min(3, current + delta))
    if (value = current && IsNumber(DefaultMouseSpeed))
        return
    DefaultMouseSpeed := value
    MouseSpeedTxt.Value := value
    SaveOption("DefaultMouseSpeed", DefaultMouseSpeed)
    SetDefaultMouseSpeed(DefaultMouseSpeed)
}

StepMouseDelay(delta) {
    global MouseDelay, MouseDelayTxt

    current := IsNumber(MouseDelay) ? Integer(MouseDelay) : 10
    value := Max(3, Min(75, current + delta))
    if (value = current && IsNumber(MouseDelay))
        return
    MouseDelay := value
    MouseDelayTxt.Value := value
    SaveOption("MouseDelay", MouseDelay)
    SetMouseDelay(MouseDelay)
}

StepKeyDelay(delta) {
    global KeyDelay, KeyDelayTxt

    current := IsNumber(KeyDelay) ? Integer(KeyDelay) : 20
    value := Max(5, Min(100, current + delta))
    if (value = current && IsNumber(KeyDelay))
        return
    KeyDelay := value
    KeyDelayTxt.Value := value
    SaveOption("KeyDelay", KeyDelay)
    SetKeyDelay(KeyDelay)
}

AddDarkListFrame(guiObj, x, y, w, h, hidden := true) {
    return guiObj.Add("Text",
        "x" (x - 1) " y" (y - 1) " w" (w + 2) " h" (h + 2) " " (hidden ? "Hidden " : "") "Background646464", "")
}

FitDarkListFrame(frame, ctrl) {
    if (!IsObject(frame) || !IsObject(ctrl))
        return
    ctrl.GetPos(&cx, &cy, &cw, &ch)
    frame.Move(cx - 1, cy - 1, cw + 2, ch + 2)
}

EnableDarkInputFrame(hwnd, keepScrollbarTheme := false) {
    if (!hwnd)
        return
    EnableDarkModeForApp()
    AllowDarkModeForWindow(hwnd)
    theme := keepScrollbarTheme ? "DarkMode_Explorer" : "DarkMode_CFD"
    try DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", theme, "Ptr", 0)
}

RegisterDarkInputSurface(hwnd) {
    global DarkInputSurfaces
    if (hwnd)
        DarkInputSurfaces[hwnd] := true
}

DarkInputBrush() {
    static brush := 0
    if (!brush)
        brush := DllCall("gdi32\CreateSolidBrush", "UInt", 0x181818, "Ptr")
    return brush
}

DarkInputCtlColor(wParam, lParam, msg, hwnd) {
    global DarkInputSurfaces
    static comboLists := Map()
    static WM_CTLCOLORLISTBOX := 0x0134

    if !DarkInputSurfaces.Has(lParam) {
        if (msg != WM_CTLCOLORLISTBOX)
            return
        if !comboLists.Has(lParam) {
            comboLists[lParam] := (ControlClassName(lParam) = "ComboLBox")
            if comboLists[lParam]
                EnableDarkInputFrame(lParam, true)
        }
        if !comboLists[lParam]
            return
    }
    DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", 0xE7E4E2)
    DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", 0x181818)
    return DarkInputBrush()
}

EnableDarkComboBox(ctrl) {
    EnableDarkInputFrame(ctrl.Hwnd, false)

    info := Buffer(A_PtrSize = 8 ? 40 : 20, 0)
    NumPut("UInt", info.Size, info, 0)
    if DllCall("user32\GetComboBoxInfo", "Ptr", ctrl.Hwnd, "Ptr", info, "Int") {
        listHwnd := NumGet(info, A_PtrSize = 8 ? 32 : 16, "Ptr")
        if (listHwnd) {
            AllowDarkModeForWindow(listHwnd)
            try DllCall("uxtheme\SetWindowTheme", "Ptr", listHwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
            RegisterDarkInputSurface(listHwnd)
        }
    }
}

UxThemeProc(ordinal) {
    static handle := 0
    if (!handle) {
        handle := DllCall("kernel32\GetModuleHandleW", "Str", "uxtheme", "Ptr")
        if (!handle)
            handle := DllCall("kernel32\LoadLibraryW", "Str", "uxtheme.dll", "Ptr")
    }
    if (!handle)
        return 0
    return DllCall("kernel32\GetProcAddress", "Ptr", handle, "Ptr", ordinal, "Ptr")
}

AllowDarkModeForWindow(hwnd) {
    if (!hwnd)
        return
    proc := UxThemeProc(133)
    if (proc)
        try DllCall(proc, "Ptr", hwnd, "Int", 1, "Int")
}

EnableDarkModeForApp() {
    static applied := false
    if (applied)
        return
    applied := true

    proc := UxThemeProc(135)
    if (proc)
        try DllCall(proc, "Int", 2, "Int")
}

EnableDarkScrollbar(ctrl) {
    EnableDarkModeForApp()
    try DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
}

SuppressEditCaret(ctrl) {
    ctrl.OnEvent("Focus", (c, *) => DllCall("user32\HideCaret", "Ptr", c.Hwnd))
    try DllCall("user32\HideCaret", "Ptr", ctrl.Hwnd)
}

CountConfiguredPartyMembers(value := "") {
    global PartyMembers
    if (value = "")
        value := PartyMembers

    count := 0
    loop parse, value, "," {
        if (Trim(A_LoopField) != "")
            count++
    }
    return count
}

PartySettingsProblem() {
    global MultiplayerEnabled, PlayerRole, HostName, PartyMembers

    if (!MultiplayerEnabled)
        return ""

    if (PlayerRole = "Member" && IsPartyFieldUnset(HostName))
        return "Party mode is enabled and you are set to Member, but 'Host Username' is empty."

    if (PlayerRole = "Host" && IsPartyFieldUnset(PartyMembers))
        return "Party mode is enabled and you are set to Host, but 'Party Members' is empty."

    if (PlayerRole = "Host") {
        count := CountConfiguredPartyMembers(PartyMembers)
        if (count < 1 || count > 3)
            return "Party mode supports 1 to 3 party members besides you; " count " are configured."
    }

    return ""
}

SyncPartySettingsFromGui(showFeedback := false) {
    global HostName, PartyMembersStr, PartyMembers, MultiplayerEnabled, PlayerRole, LeaveCondition

    HostName := Trim(Tab3_HostNm_EDIT.Value)
    PartyMembersStr := NormalizePartyMembers(Tab3_PartyMemb_Edit.Value)
    PartyMembers := PartyMembersStr
    MultiplayerEnabled := MultiplayerEnabledTGL.Value
    PlayerRole := Tab3_Role_Member.Value ? "Member" : "Host"
    LeaveCondition := Tab3_LCondition_All.Value ? "All" : "Any"

    SaveMultiplayerSetting("HostName", HostName)
    SaveMultiplayerSetting("PartyMembers", PartyMembers)
    SaveMultiplayerSetting("MultiplayerEnabled", MultiplayerEnabled)
    SaveMultiplayerSetting("PlayerRole", PlayerRole)
    SaveMultiplayerSetting("LeaveCondition", LeaveCondition)

    partyProblem := PartySettingsProblem()
    if (showFeedback && partyProblem != "") {
        ModernMsgBox("Party settings need attention",
            partyProblem "`n`nYour settings are saved, but the macro will not start Party Mode until this is fixed.",
            "OK", "WARNING")
    }
    return partyProblem
}

AutoSavePartySettings(*) {
    SyncPartySettingsFromGui(false)
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

ExportLogsForDevelopers(ctrl, *) {
    outputPath := A_Desktop "\\UltimateMacro-logs-" FormatTime(, "yyyyMMdd-HHmmss") ".txt"
    try {
        if FileExist(outputPath)
            FileDelete(outputPath)
        if !RuntimeLogExportBundle(outputPath)
            throw Error("The diagnostic log bundle could not be created.")
        MsgBox("Developer logs exported to:`n" outputPath, "Export Logs", "0x1040")
    } catch Error as err {
        RuntimeLogError("logs_export_failed", "Developer log export failed", "error=" err.Message)
        MsgBox("Could not export developer logs.`n`n" err.Message, "Export Logs", "0x1040")
    }
}

FormatLogSize(bytes) {
    if (bytes >= 1048576)
        return Format("{:.1f} MB", bytes / 1048576)
    if (bytes >= 1024)
        return Format("{:.1f} KB", bytes / 1024)
    return bytes " bytes"
}

ClassifyVipLink(str) {
    str := Trim(str)
    if (str = "")
        return "empty"

    if RegExMatch(str,
        "i)roblox\.com\/(?:[a-z]{2}\/)?games\/3260590327\/[^\/]*\?privateServerLinkCode=(?<code>[a-z0-9]{32})")
        return "valid"

    if RegExMatch(str, "i)roblox\.com\/share\?code=(?<code>[a-f0-9]{32})", &m) {
        try {
            wr := ComObject("WinHttp.WinHttpRequest.5.1")
            wr.Open("GET", "https://www.roblox.com/share?code=" m["code"] "&type=Server", true)
            wr.Send()
            if (wr.WaitForResponse(3) && wr.Status = 200 && InStr(wr.ResponseText, "3260590327"))
                return "valid"
        } catch Error {
            return "valid"
        }
        return "invalid"
    }

    return "invalid"
}

RefreshVipServerStatus(*) {
    global VipLink, UseVipServer, VipLinkCtrl, Tab5_VipStatus

    VipLink := Trim(VipLinkCtrl.Value)
    state := ClassifyVipLink(VipLink)

    UseVipServer := (state = "valid") ? 1 : 0
    SaveOption("VipLink", VipLink)
    SaveOption("UseVipServer", UseVipServer)

    if (state = "empty") {
        SetStatusLabel(Tab5_VipStatus, "No VIP server set. The macro will use public servers.", "7E848E")
    } else if (state = "valid") {
        SetStatusLabel(Tab5_VipStatus, "VIP server link recognised. It will be used automatically.", "5FD08A")
    } else {
        SetStatusLabel(Tab5_VipStatus, "This is not a TDS private server link, so it will be ignored.", "FF6B6B")
    }
}

WebhookLinkLooksValid(link) {
    link := Trim(link)
    if (link = "")
        return false
    return InStr(link, "discord.com/api/webhooks/") || InStr(link, "discordapp.com/api/webhooks/")
}

SetWebhookStatusText(state) {
    global Tab4_WebhookStatus

    if (state = "empty") {
        SetStatusLabel(Tab4_WebhookStatus, "No webhook set. Paste one to turn Discord logging on.", "7E848E")
    } else if (state = "checking") {
        SetStatusLabel(Tab4_WebhookStatus, "Checking this webhook...", "7E848E")
    } else if (state = "valid") {
        SetStatusLabel(Tab4_WebhookStatus, "Webhook recognised. Logging to Discord is on.", "5FD08A")
    } else {
        SetStatusLabel(Tab4_WebhookStatus, "This is not a working Discord webhook URL, so it will be ignored.",
            "FF6B6B")
    }
}

ApplyWebhookVisibility() {
    global WebhookEnabled, WebhookDetailControls, CurrentTab, DiscordPage

    onWebhookPage := (IsSet(CurrentTab) && CurrentTab = "Tab4" && DiscordPage = "Webhook")
    for ctrl in WebhookDetailControls
        SetControlVisible(ctrl, (WebhookEnabled = 1) && onWebhookPage)

    EnableWebhookLink2()
}

RefreshWebhookStatus(*) {
    global WebhookLink, WebhookEnabled, WebhookLinkCtrl
    global WebhookCheckedLink, WebhookCheckedState

    ClearPendingSettingSave("webhooklink")

    link := Trim(WebhookLinkCtrl.Value)

    if (WebhookCheckedState != "" && link = WebhookCheckedLink) {
        WebhookLink := link
        WebhookEnabled := (WebhookCheckedState = "valid") ? 1 : 0
        SetWebhookStatusText(WebhookCheckedState)
        ApplyWebhookVisibility()
        return
    }

    WebhookLink := link
    SaveWebhookSetting("Link", WebhookLink)

    shapeOk := WebhookLinkLooksValid(WebhookLink)
    WebhookEnabled := shapeOk ? 1 : 0
    SaveWebhookSetting("Enabled", WebhookEnabled)

    if (!shapeOk) {
        WebhookCheckedLink := link
        WebhookCheckedState := (link = "") ? "empty" : "invalid"
        SetWebhookStatusText(WebhookCheckedState)
        ApplyWebhookVisibility()
        return
    }

    WebhookCheckedLink := ""
    WebhookCheckedState := ""
    SetWebhookStatusText("checking")
    ApplyWebhookVisibility()
    SetTimer(ConfirmWebhookLink, -1)
}

ConfirmWebhookLink() {
    global WebhookLink, WebhookEnabled, WebhookLinkCtrl
    global WebhookCheckedLink, WebhookCheckedState

    link := Trim(WebhookLinkCtrl.Value)
    if (link != WebhookLink || !WebhookLinkLooksValid(link))
        return

    reachable := true
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", link, false)
        whr.SetTimeouts(3000, 3000, 4000, 4000)
        whr.Send()
        reachable := (whr.Status = 200)
    } catch {
        reachable := true
    }

    if (Trim(WebhookLinkCtrl.Value) != link)
        return

    WebhookEnabled := reachable ? 1 : 0
    SaveWebhookSetting("Enabled", WebhookEnabled)
    WebhookCheckedLink := link
    WebhookCheckedState := reachable ? "valid" : "invalid"
    SetWebhookStatusText(WebhookCheckedState)
    ApplyWebhookVisibility()
}

QueueWebhookCheck(*) {
    QueueSettingSave("webhooklink", RefreshWebhookStatus, 700)
}
EnableWebhookLink2(*) {
    global CurrentTab, DiscordPage, WebhookLinkCtrl2, Tab4_Lbl2, WebhookSepatateTriumphScreenshotsCtrl
    global WebhookEnabled

    show := (WebhookSepatateTriumphScreenshotsCtrl.Value = 1 && WebhookEnabled = 1
        && IsSet(CurrentTab) && CurrentTab = "Tab4" && DiscordPage = "Webhook")

    WebhookLinkCtrl2.Visible := show
    Tab4_Lbl2.Visible := show
}

ShowDiscordPage(page, *) {
    global DiscordPage, DiscordNavTab, DiscordWebhookTab, DiscordBotTab, DiscordRemoteTab
    global Tab4_WebhookTabTitle, Tab4_BotTabTitle, Tab4_RemoteTabTitle

    if (page != "Webhook" && page != "Bot" && page != "Remote")
        page := "Webhook"
    DiscordPage := page
    HideAllTabContent()

    for ctrl in DiscordNavTab
        ShowControl(ctrl)

    Tab4_WebhookTabTitle.IsSelected := (page = "Webhook")
    Tab4_BotTabTitle.IsSelected := (page = "Bot")
    Tab4_RemoteTabTitle.IsSelected := (page = "Remote")
    for ctrl in [Tab4_WebhookTabTitle, Tab4_BotTabTitle, Tab4_RemoteTabTitle]
        ApplyHoverStyle(ctrl, false)

    Tab4_NavLine.Move(page = "Webhook" ? 30 : (page = "Bot" ? 196 : 362))

    controls := page = "Webhook" ? DiscordWebhookTab : (page = "Bot" ? DiscordBotTab : DiscordRemoteTab)
    for ctrl in controls
        ShowControl(ctrl)

    if (page = "Webhook")
        RefreshWebhookStatus()
    else if (page = "Remote")
        OfficialRemoteRefreshControls()
}

CheckWebhookLink2(*) {
    global WebhookLinkCtrl2, WebhookLink2Checked

    link := Trim(WebhookLinkCtrl2.Value)
    if (link = WebhookLink2Checked)
        return
    WebhookLink2Checked := link

    if (link = "") {
        RuntimeLogInfo("webhook_channel_cleared", "The separate triumph channel webhook field was cleared")
        return
    }

    if (!WebhookLinkLooksValid(link)) {
        RuntimeLogWarn("webhook_channel_invalid",
            "The separate triumph channel webhook is not a Discord webhook URL and will be ignored")
        return
    }

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", link, false)
        whr.SetTimeouts(3000, 3000, 4000, 4000)
        whr.Send()
        if (whr.Status != 200)
            RuntimeLogWarn("webhook_channel_unreachable",
                "The separate triumph channel webhook did not respond", "status=" whr.Status)
    } catch Error as err {
        RuntimeLogWarn("webhook_channel_check_failed",
            "The separate triumph channel webhook could not be verified", "error=" err.Message)
    }
}

LoadStrategyFile(file) {
    global Towers, RecordedSteps, RecordedTowerIds, gamemap, difficulty, requiredTowers, autoChain, autoCaravan
    global autoDropTheBeat, AutoSkip, AbilitySpam, MoveEnabled, MoveDirection, MoveDuration
    global modifiers, Commander, StrategyWidth, StrategyHeight, TimescaleActive
    global LastOpenedTowerID, needtocheckTowerUI, canUseAbility, canBeUpgraded
    global ActiveRTowerID, CachedMenuUI, CachedResV2, CachedResV1, isUpgradeAuthorized

    Towers := Map()
    RecordedSteps := []
    RecordedTowerIds := Map()
    DeleteAllIndicators()

    TimescaleActive := false
    LastOpenedTowerID := ""
    needtocheckTowerUI := true
    canUseAbility := true
    canBeUpgraded := true
    ActiveRTowerID := false
    CachedMenuUI := { x: 0, y: 0 }
    CachedResV2 := ""
    CachedResV1 := ""
    isUpgradeAuthorized := false

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
    global WebhookEnabled, CurrentStratStartTime, CurrentRunCount, gamemap, AutoEquip, IsRestarting

    if (RunningStrategy != true)
        return

    IsRestarting := false

    if (!skiprestart && !isDisconnected())
        return false

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
            if !CheckRestart()
                return false
        } else {
            CloseRoblox()
            if !RunRoblox()
                return false
            if (AutoEquip) {
                if !EquipTowers(RequiredTowers)
                    return false
            }
            if !JoinGame()
                return false
        }
    } else {
        CloseRoblox()
        if !RunRoblox()
            return false
        if !EquipTowers(RequiredTowers)
            return false

        if !JoinGame()
            return false
    }

    if (readyX = 0 && readyY = 0) {
        if !waitReady()
            return false
    }

    if (!IsRestarting) {
        if !CheckTheMapF()
            return false
        if (!InArray(SpecialMaps, gamemap) && ResolveArcadeTarget() = "") {
            if !AlignCamera() {
                SafeReload()
                return false
            }
        }
    }

    if !activateTimescale()
        return false

    if (!IsRestarting && ResolveArcadeTarget() != "") {
        RuntimeLogInfo("arcade_camera_pre_ready", "Aligning Arcade camera before Ready", "target=" ResolveArcadeTarget())
        if !AlignCamera() {
            SafeReload()
            return false
        }
    }

    if !ClickReady()
        return false

    if !PlayStrategy() {
        if (RunningStrategy)
            StopStrategy()
        return false
    }
    return true
}

PlayStrategy() {
    global canUseAbility, MultiplayerEnabled, StateFile, RunningStrategy

    MacroPhase("playing", 900000)
    IniWrite(A_TickCount, StateFile, "State", "TimeWhenStartedPlaying")
    SetTimer(UseAbilities, 750)
    if (MultiplayerEnabled) {
        SetTimer(checkCondition, 15000)
    }

    i := 1
    while (i <= RecordedSteps.Length) {
        if (IsSet(RunningStrategy) && !RunningStrategy)
            return false
        step := RecordedSteps[i]
        MacroPhase("playing_step", 900000)

        if RegExMatch(step,
            "i)UpgradeTower\s*\(\s*([^,]+?)\s*(?:,\s*(false|true)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?\s*\)", &
            m) {
            currentID := Trim(m[1])
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
            if !ExecuteStep(step) {
                if (IsSet(RunningStrategy) && !RunningStrategy)
                    return false
                RuntimeLogWarn("placement_step_failed", "Placement did not complete; continuing with the next step",
                    "step=" i)
            }
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
}

ExecuteStep(step) {
    global Commander, unfocusX, unfocusY, StrategyWidth, StrategyHeight
    step := RegExReplace(step, "\s*;.*$", "")
    step := Trim(step)
    if (step = "")
        return
    if RegExMatch(step, "i)SpawnTower\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d)\s*,\s*(.*?)\s*\)", &m) {
        return SpawnTower(m[1], m[2], m[3], Trim(m[4]))
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
                    verifyDeadline := A_TickCount + 1800
                    loop {
                        resUnequip := AdvancedImageSearch("Resources\\unequip.png", X1, Y1, W, H,
                            0.3 * baseScale, 1.4, 0.025)
                        if (resUnequip.status == "success" && resUnequip.score > 0.63) {
                            towerEquipped := true
                            RuntimeLogInfo("autoequip_tower_confirmed", "Auto Equip state changed after click",
                                "tower=" tower)
                            break
                        }
                        if (A_TickCount >= verifyDeadline)
                            break
                        Sleep(150)
                    }

                    if !towerEquipped
                        continue

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
        if !RunRoblox()
            return false
        if (shouldEquip && AutoEquip) {
            if !EquipTowers(requiredTowers)
                return false
        }
        return JoinGame()
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
                return true
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
                if !WaitForLobbyLoad()
                    return false
                startWatchdog()
                return true
            }
        }
    }

    startWatchdog()
    IsRestarting := false
    CloseRoblox()
    if !RunRoblox()
        return false
    if (shouldEquip && AutoEquip) {
        if !EquipTowers(requiredTowers)
            return false
    }
    return JoinGame()
}

RunRoblox(doReload := true) {
    global VipLink, UseVipServer, AutoConfigureSettings, RunningStrategy
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
        if !PrepareAutoSettingsForRobloxLaunch(AutoConfigureSettings) {
            detail := GetAutoSettingsLastError()
            RuntimeLogError("auto_settings_prepare_failed",
                "Roblox launch blocked because Auto Settings could not be prepared safely", "detail=" detail)
            LogToConsole("Auto Settings preparation failed; Roblox was not launched. " detail, true, false)
            if (IsSet(RunningStrategy) && RunningStrategy)
                StopStrategy()
            return false
        }
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
            return false
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
        geometryLogAt := 0
        loop {
            ActivateRoblox()

            if (A_TickCount - startTime > 60000) {
                if (doReload) {
                    SafeReload()
                    return false
                } else {
                    return false
                }
            }

            if !getRobloxPos(, , &w, &h) || w <= 0 || h <= 0 {
                if (A_TickCount - geometryLogAt >= 5000) {
                    RuntimeLogWarn("run_roblox_geometry_wait", "Roblox client geometry is not ready while waiting for the lobby Play button")
                    geometryLogAt := A_TickCount
                }
                Sleep(250)
                continue
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

    if (difficulty = "Arcade" && gamemap != "")
        return gamemap
    if IsLegacyArcadeTarget(gamemap)
        return gamemap
    if IsLegacyArcadeTarget(difficulty)
        return difficulty
    return ""
}

TryOpenArcadeCategory(w, h) {
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
            if (match && OcrMatchTargetsGameUI(match, "Arcade")) {
                RuntimeLogInfo("arcade_category_select", "Opening Arcade category by sidebar text")
                match.Click()
                Sleep(650)
                return true
            }
        }
    } catch Error as e {
        RuntimeLogWarn("arcade_category_ocr_error", "Could not target Arcade category by text", "error=" e.Message)
    }

    ActivateRoblox()
    fallbackX := Round(w * 0.18)
    fallbackY := Round(h * 0.43)
    RuntimeLogInfo("arcade_category_fallback", "Opening Arcade category by relative sidebar position", "x=" fallbackX "; y=" fallbackY)
    Click(fallbackX, fallbackY)
    Sleep(650)
    return true
}

GetArcadeCardClientRegion(w, h, &cardX, &cardY, &cardW, &cardH) {
    cardX := 0
    cardY := 0
    cardW := w
    cardH := h
}

TryClickArcadeTarget(target, w, h) {
    GetArcadeCardClientRegion(w, h, &cardX, &cardY, &cardW, &cardH)

    imagePath := "Resources/" target ".png"
    if FileExist(imagePath) {
        res := AdvancedImageSearch(imagePath, cardX, cardY, cardW, cardH)
        if (res.status = "success" && res.score >= 0.67) {
            RuntimeLogInfo("arcade_card_image_select", "Selecting Arcade card by image", "target=" target "; score=" res.score)
            Click(res.x, res.y)
            Sleep(250)
            return true
        }
    }

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

        ocrX := screenX + Round(screenW * 0.17)
        ocrY := screenY + Round(screenH * 0.05)
        ocrW := Round(screenW * 0.76)
        ocrH := Round(screenH * 0.80)
        ocrResult := OCR.FromRect(ocrX, ocrY, ocrW, ocrH, {
            lang: langCode,
            scale: 1.45,
            grayscale: 1
        })
        match := ocrResult.FindString(target, { CaseSense: false, IgnoreLinebreaks: true })
        if (match && OcrMatchTargetsGameUI(match, target)) {
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
    cardX := 0
    cardY := 0
    cardW := w
    cardH := h

    imagePath := "Resources/" target ".png"
    if FileExist(imagePath) {
        res := AdvancedImageSearch(imagePath, cardX, cardY, cardW, cardH)
        if (res.status = "success" && res.score >= 0.67) {
            RuntimeLogInfo("difficulty_image_select", "Selecting difficulty by image", "target=" target "; score=" res.score)
            Click(res.x, res.y)
            return true
        }
    }

    if (target = "Hardcore") {
        RuntimeLogWarn("difficulty_hardcore_image_missing",
            "Hardcore image was not detected; refusing ambiguous OCR fallback")
        return false
    }

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

        ocrX := screenX + Round(screenW * 0.17)
        ocrY := screenY + Round(screenH * 0.05)
        ocrW := Round(screenW * 0.76)
        ocrH := Round(screenH * 0.80)
        ocrResult := OCR.FromRect(
            ocrX,
            ocrY,
            ocrW,
            ocrH,
            { lang: langCode, scale: 1.45, grayscale: 1 }
        )
        match := ocrResult.FindString(target, { CaseSense: false, IgnoreLinebreaks: true })
        if (match && OcrMatchTargetsGameUI(match, target)) {
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
            if (IsSet(RunningStrategy) && !RunningStrategy)
                return false
            if (A_TickCount - startTime > 60000) {
                CloseRoblox()
                SafeReload()
                return false
            }
            if !getRobloxPos(, , &w, &h) {
                RuntimeLogWarn("lobby_load_geometry_missing", "Roblox client geometry disappeared while loading the lobby")
                SafeReload()
                return false
            }
            res := AdvancedImageSearch("Resources/Ready.png", Round(w * 0.25), Round(h * 0.66), Round(w * 0.5), Round(h *
                0.34), 0.6, 1.7)
            if (res.status = "success" && res.score >= 0.7) {
                break
            }
            Sleep(100)
        }
        if (!MultiplayerEnabled || PlayerRole = "Host") {
            if !SelectMap(res.x, res.y)
                return false
        } else {
            Click(Round(w * 0.5), res.y)
            Sleep 250
            Click(Round(w * 0.6), res.y)
            if (modifiers != "")
                ApplyModifiers()
        }
    }
    return true
}

JoinGame() {
    global SendCurrenciesEnabled, WebhookEnabled, difficulty, CollectPlaytimeRewards, PlayerRole, MultiplayerEnabled
    global readyX, readyY
    readyX := 0
    readyY := 0
    MacroPhase("matchmaking", 240000)
    RuntimeLogInfo("matchmaking_ready_reset", "Reset Ready coordinates before fresh matchmaking join")

    startTime := A_TickCount
    geometryLogAt := 0
    loop {
        if (A_TickCount - startTime > 80000) {
            SafeReload()
            return false
        }

        if !getRobloxPos(, , &w, &h) || w <= 0 || h <= 0 {
            if (A_TickCount - geometryLogAt >= 5000) {
                RuntimeLogWarn("matchmaking_geometry_retry", "Roblox client geometry is not ready; retrying the Play-button search")
                geometryLogAt := A_TickCount
            }
            Sleep(250)
            continue
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
                    if !AcceptInvite(res.x, res.y)
                        return false
                    return WaitForLobbyLoad()
                } else if !CreateParty(res.x, res.y) {
                    return false
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
            if !getRobloxPos(, , &w, &h) {
                RuntimeLogWarn("arcade_category_geometry_missing", "Roblox client geometry disappeared before Arcade selection")
                SafeReload()
                return false
            }
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
            return false
        }

        lastArcadeScroll := 0
        arcadeScrollAttempts := 0
        startTime := A_TickCount
        loop {
            if !getRobloxPos(, , &w, &h) {
                RuntimeLogWarn("arcade_matchmaking_geometry_missing", "Roblox client geometry disappeared during Arcade selection")
                SafeReload()
                return false
            }
            if (A_TickCount - startTime > 35000) {
                RuntimeLogWarn("arcade_matchmaking_timeout", "Could not find Arcade/Trial card", "target=" arcadeTarget)
                SafeReload()
                return false
            }

            if TryClickArcadeTarget(arcadeTarget, w, h)
                break

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
        firstModeScrollAt := difficultyStart + 6000
        lastModeScroll := difficultyStart
        modeScrollAttempts := 0

        loop {
            if !getRobloxPos(, , &w, &h) {
                RuntimeLogWarn("difficulty_geometry_missing", "Roblox client geometry disappeared during difficulty selection")
                SafeReload()
                return false
            }
            elapsedDifficulty := A_TickCount - difficultyStart
            if (A_TickCount >= difficultyDeadline) {
                LogToConsole("Could not select difficulty '" difficulty "' within 60s. Reloading...", true)
                RuntimeLogWarn("difficulty_select_timeout", "Difficulty card never matched",
                    "difficulty=" difficulty "; scrolls=" modeScrollAttempts)
                SafeReload()
                return false
            }

            if TryClickDifficultyTarget(difficulty, w, h) {
                break
            }

            if (A_TickCount >= firstModeScrollAt && A_TickCount - lastModeScroll >= 650 && modeScrollAttempts < 12) {
                ActivateRoblox()
                MouseMove(Round(w * 0.78), Round(h * 0.78), 0)
                SendEvent("{WheelDown 4}")
                lastModeScroll := A_TickCount
                modeScrollAttempts++
                RuntimeLogInfo("difficulty_scroll_retry", "Scrolling the bounded mode-card panel",
                    "difficulty=" difficulty "; attempt=" modeScrollAttempts)
            }

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
        if !getRobloxPos(, , &w, &h) {
            RuntimeLogWarn("party_size_geometry_missing", "Roblox client geometry disappeared during party-size selection")
            SafeReload()
            return false
        }
        if (A_TickCount - startTime > 40000) {
            RuntimeLogWarn("party_size_timeout", "Party-size selection did not appear after mode selection",
                "difficulty=" difficulty "; multiplayer=" MultiplayerEnabled)
            SafeReload()
            return false
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
    return WaitForLobbyLoad()
}

InvitePartyMembers(search_bar) {
    global PartyMembers, PartyInviteBusy

    PartyInviteBusy := true
    try {
        loop parse, PartyMembers, "," {
            member := Trim(A_LoopField)
            if (member = "")
                continue

            Click(search_bar.x, search_bar.y)
            Sleep(80)
            Send("^a")
            Send("{Backspace}")
            Sleep(60)
            SendText(member)
            Sleep(120)
            Click(search_bar.x + ScaleX(75), search_bar.y + ScaleY(92))
            Sleep(120)
            LogToConsole("Invited party member: " member)
        }
        return true
    } finally {
        PartyInviteBusy := false
    }
}

CountPartyMembersPresent(w, h) {
    count := 0
    sy := Round(h * 0.1)
    bottom := Round(h * 0.75)

    loop 8 {
        if (sy >= bottom)
            break

        x_btn := AdvancedImageSearch("Resources\\x.png", Round(w * 0.25), sy, Round(w * 0.25), bottom - sy)
        if (x_btn.status != "success" || x_btn.score <= 0.7)
            break

        count++
        step := (x_btn.HasProp("h") && x_btn.h > 0) ? Round(x_btn.h / 2) : ScaleY(20)
        nextY := x_btn.y + Max(step, ScaleY(10))
        if (nextY <= sy)
            break
        sy := nextY
    }

    return count
}

CreateParty(x, y) {
    global PartyMembers, PartyInviteBusy

    MacroPhase("party_host_setup", 30000)
    setupDeadline := A_TickCount + 15000

    loop {
        getRobloxPos(, , &w, &h)
        Click(x + ScaleX(200), y)
        innerDeadline := A_TickCount + 5000

        loop {
            resclose := AdvancedImageSearch("Resources\\close.png", Round(w * 0.25), Round(h * 0.1), Round(w * 0.5),
                Round(h * 0.4))
            if (resclose.status = "success" && resclose.score >= 0.7)
                break 2
            if (A_TickCount >= innerDeadline)
                break
            Sleep(250)
        }

        if (A_TickCount >= setupDeadline) {
            LogToConsole("Failed to Create Party: the party menu did not open in time.", true)
            RuntimeLogWarn("party_create_menu_timeout", "Could not open party menu")
            SafeReload()
            return false
        }
    }

    Sleep(150)
    getRobloxPos(, , &w, &h)
    create_btn := AdvancedImageSearch("Resources\\create_party.png", Round(w * 0.25), Round(h * 0.5), Round(w * 0.5),
        Round(h * 0.5))
    if (create_btn.status != "success" || create_btn.score <= 0.58) {
        LogToConsole("Failed to Create Party: the macro can't see the create party button!", true)
        RuntimeLogWarn("party_create_button_missing", "Create Party button was not detected")
        SafeReload()
        return false
    }

    Click(create_btn.x, create_btn.y)
    LogToConsole("Successfully created the party")
    Sleep(300)

    timerEnabled := false
    try {
        SetTimer(CancelInviteIfAppeared, 7500)
        timerEnabled := true

        search_bar := ""
        loop 3 {
            getRobloxPos(, , &w, &h)
            candidate := AdvancedImageSearch("Resources\\type_to_search.png", Round(w * 0.25), Round(h * 0.1),
                Round(w * 0.5), Round(h * 0.3))
            if (candidate.status = "success" && candidate.score > 0.58) {
                search_bar := candidate
                break
            }
            Sleep(1000)
        }

        if (!IsObject(search_bar)) {
            LogToConsole("Failed to Create Party: the macro can't see the member search bar!", true)
            RuntimeLogWarn("party_search_missing", "Party member search bar was not detected")
            SafeReload()
            return false
        }

        InvitePartyMembers(search_bar)
        totalPartyMembers := CountConfiguredPartyMembers(PartyMembers)
        waitDeadline := A_TickCount + 180000
        reinviteAt := A_TickCount + 30000
        MacroPhase("party_host_wait", 190000)

        loop {
            getRobloxPos(, , &w, &h)
            present := CountPartyMembersPresent(w, h)
            LogToConsole("Waiting for " totalPartyMembers " players... (" present "/" totalPartyMembers ")")

            if (present >= totalPartyMembers) {
                LogToConsole("All players: " PartyMembers " have joined!")
                RuntimeLogInfo("party_ready", "All configured party members joined",
                    "members=" totalPartyMembers)
                break
            }

            if (A_TickCount >= waitDeadline) {
                LogToConsole("Party members did not all join within 3 minutes. Reloading...", true)
                RuntimeLogWarn("party_join_timeout", "Timed out waiting for party members",
                    "expected=" totalPartyMembers "; present=" present)
                SafeReload()
                return false
            }

            if (A_TickCount >= reinviteAt) {
                candidate := AdvancedImageSearch("Resources\\type_to_search.png", Round(w * 0.25), Round(h * 0.1),
                    Round(w * 0.5), Round(h * 0.3))
                if (candidate.status = "success" && candidate.score > 0.58) {
                    search_bar := candidate
                    InvitePartyMembers(search_bar)
                }
                reinviteAt := A_TickCount + 30000
            }
            Sleep(3000)
        }

        getRobloxPos(, , &w, &h)
        resclose := AdvancedImageSearch("Resources\\close.png", Round(w * 0.25), Round(h * 0.1), Round(w * 0.5),
            Round(h * 0.4))
        if (resclose.status = "success" && resclose.score >= 0.7)
            Click(resclose.x, resclose.y)
        Sleep(200)
        return true
    } finally {
        PartyInviteBusy := false
        if (timerEnabled)
            SetTimer(CancelInviteIfAppeared, 0)
    }
}

CancelInviteIfAppeared(*) {
    global PartyInviteBusy

    if (PartyInviteBusy)
        return

    getRobloxPos(, , &w, &h)
    cancel_btn := AdvancedImageSearch("Resources/cancel_invite.png", Round(w * 0.2), Round(h * 0.2), Round(w * 0.6),
        Round(h * 0.65))
    if (cancel_btn.status = "success" && cancel_btn.score >= 0.65)
        Click(cancel_btn.x, cancel_btn.y)
}

AcceptInvite(x, y) {
    global HostName

    MacroPhase("party_member_setup", 30000)
    setupDeadline := A_TickCount + 15000

    loop {
        getRobloxPos(, , &w, &h)
        Click(x + ScaleX(200), y)
        innerDeadline := A_TickCount + 5000

        loop {
            resclose := AdvancedImageSearch("Resources\\close.png", Round(w * 0.25), Round(h * 0.1), Round(w * 0.5),
                Round(h * 0.4))
            if (resclose.status = "success" && resclose.score >= 0.7)
                break 2
            if (A_TickCount >= innerDeadline)
                break
            Sleep(250)
        }

        if (A_TickCount >= setupDeadline) {
            LogToConsole("Failed to Accept Invite: the party menu did not open in time.", true)
            RuntimeLogWarn("party_invite_menu_timeout", "Could not open party menu as member")
            SafeReload()
            return false
        }
    }

    Sleep(150)
    clickedInviteBtn := false
    search_bar_X := 0
    search_bar_Y := 0

    loop 5 {
        getRobloxPos(, , &w, &h)
        invite_btn := AdvancedImageSearch("Resources\\invites_btn.png", Round(w * 0.25), 0, Round(w * 0.5),
            Round(h * 0.4))
        if (invite_btn.status = "success" && invite_btn.score > 0.58) {
            clickedInviteBtn := true
            Click(invite_btn.x, invite_btn.y)
            search_bar_X := invite_btn.x - ScaleX(250)
            search_bar_Y := invite_btn.y + ScaleY(50)
            break
        }
        Sleep(250)
    }

    if (!clickedInviteBtn) {
        LogToConsole("Failed to Accept Invite: the macro can't see the invites button!", true)
        RuntimeLogWarn("party_invites_tab_missing", "Invites button was not detected")
        SafeReload()
        return false
    }

    Sleep(200)
    Click(search_bar_X, search_bar_Y)
    Sleep(80)
    Send("^a")
    Send("{Backspace}")
    Sleep(60)
    SendText(HostName)
    Sleep(150)

    inviteDeadline := A_TickCount + 180000
    MacroPhase("party_member_wait", 190000)
    loop {
        getRobloxPos(, , &w, &h)
        LogToConsole("Waiting for an invite from host: " HostName "...")
        accept_btn := AdvancedImageSearch("Resources\\accept_invite.png", Round(w * 0.25), Round(h * 0.1),
            Round(w * 0.5), Round(h * 0.3))
        if (accept_btn.status = "success" && accept_btn.score > 0.66) {
            Click(accept_btn.x, accept_btn.y)
            Sleep(200)
            if !(ReadMessage(["Error", "Party", "not", "found"])) {
                LogToConsole("Successfully accepted an invitation from " HostName)
                RuntimeLogInfo("party_invite_accepted", "Member accepted host invitation", "host=" HostName)
                break
            }
        }

        if (A_TickCount >= inviteDeadline) {
            LogToConsole("Didn't receive an invite from the host within 3 minutes! Reloading...", true)
            RuntimeLogWarn("party_invite_timeout", "Timed out waiting for host invitation", "host=" HostName)
            SafeReload()
            return false
        }
        Sleep(3000)
    }

    getRobloxPos(, , &w, &h)
    resclose := AdvancedImageSearch("Resources\\close.png", Round(w * 0.25), Round(h * 0.1), Round(w * 0.5),
        Round(h * 0.4))
    if (resclose.status = "success" && resclose.score >= 0.7)
        Click(resclose.x, resclose.y)
    return true
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

    result := AdvancedImageSearch(img ".png", Round(w * 0.5), rY, w - Round(w * 0.5), h)

    if (LeaveCondition = "All") {
        if (result.score > 0.8) {
            LogToConsole("All players are gone! Closing roblox and reloading the macro...", true)
            CloseRoblox()
            SafeReload()
        }
    } else {
        if (result.score <= 0.8) {
            LogToConsole("Someone has just left! Closing roblox and reloading the macro...", true)
            CloseRoblox()
            SafeReload()
        }
    }

}

SelectMap(readyX := ScaleX(963), readyY := ScaleY(838)) {
    global gamemap, difficulty, modifiers, CheckTheMap, LegacyMode

    if !getRobloxPos(, , &w, &h) {
        RuntimeLogWarn("map_select_geometry_missing", "Roblox client geometry was unavailable before map selection")
        SafeReload()
        return false
    }
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
        if !AlignCamera(false, false) {
            SafeReload()
            return false
        }
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

            if !GetRobloxScreenClientRect(&mapClientX, &mapClientY, &w, &h) {
                LogToConsole("Cannot resolve Roblox window for map OCR. Reloading...", true)
                SafeReload()
                return false
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
                return false
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
            LogToConsole("The macro can't see the E prompt (" e_pr.score "). Map selection is ambiguous; reloading...", true)
            RuntimeLogWarn("map_selection_ambiguous", "Map interaction was not confirmed; refusing recursive re-entry",
                "map=" gamemap "; score=" e_pr.score)
            SafeReload()
            return false
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
            return false
        }

        Sleep(100)
        SendText(gamemap)
        mapChoiceAttempts := 0
        loop {
            mapChoiceAttempts++
            if (mapChoiceAttempts > 5) {
                RuntimeLogWarn("map_selection_retry_exhausted", "Map selection did not settle within the bounded retry budget",
                    "map=" gamemap)
                SafeReload()
                return false
            }
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
                return false
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
                return false
            }
        }

        SendEvent("{sc012 down}")
        Sleep(800)
        SendEvent("{sc012 up}")
    }
    Sleep(100)

    Click(readyX, readyY)
    return waitReady()
}

CheckTheMapF() {
    global gamemap, CheckTheMap, modifiers

    modifiers_str := (modifiers is Array) ? Join(modifiers) : String(modifiers)

    if (ResolveArcadeTarget() = "" && FileExist("Resources\Maps\" . gamemap . ".png") && CheckTheMap = 1 && !InArray(SpecialMaps, gamemap) && !
    RegExMatch(modifiers_str, "i)fog")) {
        if !AlignCamera(false, false, false) {
            SafeReload()
            return false
        }

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

            if (cameraRecoveries < 2 && (mapSamples = 4 || mapSamples = 9)) {
                if !AlignCamera(false, false, false) {
                    SafeReload()
                    return false
                }
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
            return false
        }
    }

    if (InArray(SpecialMaps, gamemap)) {
        functionName := gamemap . "Path"

        %functionName%()
    }
    return true
}

ApplyModifiers() {
    global modifiers
    LogToConsole("Setting up modifiers: " modifiers)
    Click(56, ScaleY(930))

    Sleep(300)

    searchX := ScaleX(951)
    searchY := ScaleY(262)

    foundSearchBar := false
    getRobloxPos(&x, &y, &w, &h)
    loop 2 {
        res := AdvancedImageSearch("Resources/searchbar_modifiers.png", Round(w * 0.1), 0, Round(w * 0.7), Round(h *
            0.6), 0.5, 1.5)

        if (res.status = "success" && res.score >= 0.7) {
            searchX := res.x
            searchY := res.y
            foundSearchBar := true
            break
        }
        Sleep(500)
    }

    if (!foundSearchBar) {
        LogToConsole("Modifier search bar was not detected; falling back to fixed coordinates.", true)
        RuntimeLogWarn("modifier_searchbar_missing", "The modifier search bar was not detected",
            "modifiers=" modifiers)
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
        if (IsSet(RunningStrategy) && !RunningStrategy)
            return false
        wt := 40000
        if (MultiplayerEnabled && PlayerRole = "Member") {
            wt := 90000
        }
        if (A_TickCount - start > wt) {
            LogToConsole("The ready button hasn't appeared for too long! Reloading the script...", true)
            CloseRoblox()
            SafeReload()
            return false
        }
        if FindReadyButton(&fx, &fy) {
            readyX := fx
            readyY := fy
            break
        }
        Sleep(250)
    }
    startWatchdog()
    return true
}

OpenTimescaleDialog(w, h) {
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
}

CloseTimescaleNavigation() {
    Send("{sc02B}")
    Send("#")
}

TimescaleDialogSearch(templ, w, h) {
    return AdvancedImageSearch("Resources/" templ, Round(w * 0.25), Round(h * 0.45), Round(w * 0.50), Round(h * 0.55))
}

TimescaleDialogHit(res) {
    return (res.status = "success" && res.score >= 0.67)
}

WaitForTimescaleDialog(w, h, timeoutMs, &hit) {
    deadline := A_TickCount + timeoutMs
    settleUntil := A_TickCount + 900
    hit := ""

    loop {
        getMore := TimescaleDialogSearch("GetMore.png", w, h)
        confirm := TimescaleDialogSearch("confirm.png", w, h)
        getMoreHit := TimescaleDialogHit(getMore)
        confirmHit := TimescaleDialogHit(confirm)

        if (confirmHit && (!getMoreHit || confirm.score >= getMore.score)) {
            hit := confirm
            return "confirm"
        }

        if (getMoreHit && A_TickCount >= settleUntil) {
            hit := getMore
            return "getmore"
        }

        if (A_TickCount >= deadline) {
            if (getMoreHit) {
                hit := getMore
                return "getmore"
            }
            return ""
        }
        Sleep(150)
    }
}

activateTimescale() {
    global UseTimeScale, TimeScaleMode, TimeScaleMultiplier, difficulty, SettingsFile, AutorunStartTime,
        MultiplayerEnabled, TimescaleActive
    if (MultiplayerEnabled) {
        return true
    }

    if (!UseTimeScale || ResolveArcadeTarget() != "")
        return true

    if !getRobloxPos(&x, &y, &w, &h) {
        RuntimeLogWarn("timescale_geometry_missing", "Roblox client geometry was unavailable before TimeScale input")
        SafeReload()
        return false
    }

    LogToConsole("Applying timescale: " TimeScaleMode ". Please, enable UI Navigation Toggle.")

    maxOpenAttempts := 3
    openAttempt := 0
    dialogKind := ""
    hit := ""

    loop maxOpenAttempts {
        openAttempt := A_Index
        OpenTimescaleDialog(w, h)

        dialogKind := WaitForTimescaleDialog(w, h, 4000, &hit)
        if (dialogKind != "")
            break

        LogToConsole("Timescale dialog did not appear (attempt " openAttempt " of " maxOpenAttempts "). Retrying...")
        RuntimeLogWarn("timescale_dialog_missing", "TimeScale dialog was not visible after UI navigation",
            "attempt=" openAttempt)
        CloseTimescaleNavigation()
        Sleep(500)
    }

    if (dialogKind = "") {
        LogToConsole("Failed to activate timescale: the confirm/get more dialog never appeared. Stopping safely.", true)
        RuntimeLogWarn("timescale_dialog_unavailable", "TimeScale dialog never appeared after bounded retries",
            "attempts=" maxOpenAttempts)
        CloseTimescaleNavigation()
        TimescaleActive := false
        StopStrategy()
        return false
    }

    if (dialogKind = "getmore") {
        Click(hit.x, hit.y + ScaleY(55))
        LogToConsole("You are out of timescale tickets. Continuing the run without timescale.", true, false)
        RuntimeLogWarn("timescale_no_tickets", "TimeScale could not be enabled because Get More was shown; the run continues without it",
            "score=" hit.score "; attempts=" openAttempt)
        CloseTimescaleNavigation()
        TimescaleActive := false
        return true
    }

    Click(hit.x, hit.y)

    timescales := IniRead(StateFile, "State", "Timescale", 0)
    timescales := timescales + 1
    LogToConsole("-1 Timescale ticket. Total Timescale Tickets Used: " timescales)
    SendToWebhookInstant("[" runtime := FormatRuntime(AutorunStartTime) "] -1 Timescale ticket. `n-# Total Timescale Tickets Used: " .
    timescales, 12370112, false)
    IniWrite(timescales, StateFile, "State", "Timescale")
    TimescaleActive := true

    closedSamples := 0
    closeDeadline := A_TickCount + 6000
    loop {
        if (WaitForTimescaleDialog(w, h, 0, &ignoredHit) = "") {
            closedSamples++
            if (closedSamples >= 2)
                break
        } else {
            closedSamples := 0
        }
        if (A_TickCount >= closeDeadline)
            break
        Sleep(150)
    }

    if (closedSamples < 2) {
        LogToConsole("Timescale was confirmed but the dialog could not be visually verified as closed. Continuing the run.",
            true)
        RuntimeLogWarn("timescale_confirmation_unverified",
            "TimeScale confirmation could not be visually verified; the run continues because the ticket was already spent")
    }

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

    CloseTimescaleNavigation()
    return true
}

AlignCamera(move := true, skipZoom := false, log := true) {
    global MoveEnabled, MoveDirection, MoveDuration, IsRestarting, MouseDelay
    if (IsRestarting)
        return false
    robloxHwnd := GetRobloxHWND()
    if !robloxHwnd {
        RuntimeLogWarn("align_camera_window_missing", "Camera alignment skipped because no Roblox window was found")
        LogToConsole("Cannot align camera: Roblox window is unavailable.", true, false)
        return false
    }
    if !getRobloxPos(&rx, &ry, &rw, &rh, robloxHwnd) {
        RuntimeLogWarn("align_camera_geometry_missing", "Camera alignment skipped because Roblox CLIENT geometry was unavailable")
        LogToConsole("Cannot align camera: Roblox client geometry is unavailable.", true, false)
        return false
    }
    if (log) {
        LogToConsole("Aligning camera")
    }
    closeChat()

    MouseMove(rw / 2, rh / 2, 0)
    Click("Right Down")
    try {
        Sleep(50)
        MouseMove(0, rh, 3 + MouseDelay, "R")
        Sleep(10)
    } finally {
        Click("Right Up")
    }
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
    return true
}

SpawnTower(X, Y, slotNumber, towerID) {
    global Towers, LastOpenedTowerID, CancelPlacementKey, canUseAbility, UseNumbersForHotbar
    global RunningStrategy, needtocheckTowerUI, unfocusX, unfocusY
    if (IsSet(RunningStrategy) && !RunningStrategy)
        return false
    LogToConsole("Placing tower " towerID " (slot " slotNumber ") at x:" X " y:" Y "...")

    X := sX(X, StrategyWidth)
    Y := sY(Y, StrategyHeight)

    getRobloxPos(, , , &h)
    TowerY := Y
    if (Y < h * 0.5) {
        TowerY := Y - ScaleY(5)
    }

    placeAttempts := 0
    maxPlacementAttempts := 9
    startTime := A_TickCount
    canUseAbility := false

    placementTargets := BuildPlacementTargets(X, Y)
    rejectedPositions := Map()
    targetIndex := 0
    samePositionAttempts := 0
    maxSameSpotRetries := 8

    needsHotbarSelection := true

    loop {
        if (IsSet(RunningStrategy) && !RunningStrategy) {
            canUseAbility := true
            return false
        }

        if (A_TickCount - startTime > 300000) {
            LogToConsole("Tower placement timed out (5+ minutes). Reloading the macro...")
            SafeReload()
            return false
        }

        currentX := ""
        currentY := ""
        while (++targetIndex <= placementTargets.Length) {
            candidate := placementTargets[targetIndex]
            if rejectedPositions.Has(PlacementPositionKey(candidate[1], candidate[2]))
                continue
            currentX := candidate[1]
            currentY := candidate[2]
            break
        }

        if (currentX = "") {
            LogToConsole("Tower " towerID " has no untried placement positions left.", true)
            RuntimeLogWarn("placement_targets_exhausted", "Every candidate placement position was rejected",
                "tower=" towerID "; attempts=" placeAttempts)
            SendEvent("{" CancelPlacementKey "}")
            canUseAbility := true
            return false
        }

        placeAttempts++
        if (placeAttempts > maxPlacementAttempts) {
            LogToConsole("Tower " towerID " placement exceeded the bounded retry budget.", true)
            RuntimeLogWarn("placement_retry_exhausted", "Placement stopped after bounded retries",
                "tower=" towerID "; attempts=" (placeAttempts - 1))
            SendEvent("{" CancelPlacementKey "}")
            canUseAbility := true
            return false
        }

        ActivateRoblox()

        if (needsHotbarSelection) {
            if waitForTowerUI(, , 120) {
                Click(ScaleX(unfocusX), ScaleY(unfocusY))
                Sleep(100)
                if !WaitForTowerUIClosed(2500) {
                    Towers[towerID] := { x: X, y: TowerY, slot: Integer(slotNumber), level: 0, path: 0, pathLevel: 0,
                        target: "First Enemy", pendingPlacement: true }
                    LogToConsole("Tower " towerID " placement is still uncertain; existing tower UI did not close. Continuing without another click.", true)
                    RuntimeLogWarn("placement_pending_precondition", "Prior tower panel stayed visible during placement precondition",
                        "tower=" towerID)
                    SendEvent("{" CancelPlacementKey "}")
                    canUseAbility := true
                    return true
                }
            }
            LastOpenedTowerID := ""
            needtocheckTowerUI := true

            if UseNumbersForHotbar {
                Send("{" slotNumber "}")
            } else if !SelectHotbarSlotByClick(slotNumber) {
                LogToConsole("Hotbar slot " slotNumber " could not be resolved; retrying placement...")
                targetIndex--
                Sleep(500)
                continue
            }

            Sleep((PotatoMode = 1) ? 100 : 30)
            needsHotbarSelection := false
        }

        if (placeAttempts > 1)
            LogToConsole("Retrying tower " towerID " at untried position x:" currentX " y:" currentY "...")

        MouseMove(currentX, currentY, A_DefaultMouseSpeed)
        Sleep((PotatoMode = 1) ? 100 : 40)
        MouseClick()
        Sleep(100)
        SendEvent("{" CancelPlacementKey "}")

        placedSuccessfully := waitForTowerUI(&resV2, , 5000)

        if (!placedSuccessfully) {
            placementStatus := ResolvePlacementAmbiguity(towerID, &resV2)
            if (placementStatus = "success") {
                placedSuccessfully := true
            } else if (placementStatus = "cancelled") {
                canUseAbility := true
                return false
            } else if (placementStatus = "funds") {
                ; Not enough cash is not a geometry failure. Keep the exact
                ; recorded pixel until the tower becomes affordable.
                samePositionAttempts := 0
                LogToConsole("Tower " towerID " is waiting for enough cash; keeping the recorded position.")
                RuntimeLogInfo("placement_waiting_for_funds",
                    "Placement was blocked by insufficient funds, so coordinates were preserved",
                    "tower=" towerID "; x=" currentX "; y=" currentY)
                SendEvent("{" CancelPlacementKey "}")
                needsHotbarSelection := true
                targetIndex--
                placeAttempts--
                Sleep(1500)
                continue
            } else if (placementStatus = "unknown") {
                ; Never invent a new coordinate unless TDS explicitly says the
                ; recorded position is blocked. Unknown/slow UI stays on the
                ; original pixel and eventually fails safely instead of drifting.
                if (samePositionAttempts < maxSameSpotRetries) {
                    samePositionAttempts++
                    LogToConsole("Tower " towerID " placement is unconfirmed; keeping the recorded spot.")
                    RuntimeLogInfo("placement_retry_same_position",
                        "Placement was unconfirmed without a space rejection, so the recorded position is kept",
                        "tower=" towerID "; x=" currentX "; y=" currentY "; attempt=" samePositionAttempts)
                    SendEvent("{" CancelPlacementKey "}")
                    needsHotbarSelection := true
                    targetIndex--
                    placeAttempts--
                    Sleep(750)
                    continue
                }

                LogToConsole("Tower " towerID " placement could not be confirmed; stopping rather than shifting the strategy.", true)
                RuntimeLogWarn("placement_unknown_exhausted",
                    "Placement remained unknown after bounded same-position retries; coordinates were not changed",
                    "tower=" towerID "; x=" currentX "; y=" currentY "; attempts=" samePositionAttempts)
                SendEvent("{" CancelPlacementKey "}")
                canUseAbility := true
                return false
            } else if (placementStatus = "space") {
                RuntimeLogInfo("placement_space_rejected",
                    "TDS explicitly rejected the recorded position; trying the next bounded offset",
                    "tower=" towerID "; x=" currentX "; y=" currentY)
            }
        }

        if (placedSuccessfully) {
            storedY := currentY
            if (currentY < h * 0.5)
                storedY := currentY - ScaleY(5)
            Towers[towerID] := { x: currentX, y: storedY, slot: Integer(slotNumber), level: 0, path: 0, pathLevel: 0,
                target: "First Enemy" }
            LogToConsole("Tower " towerID " placed successfully")
            LastOpenedTowerID := towerID
            break
        }

        LogToConsole("Cannot place tower " towerID " at x:" currentX " y:" currentY ". Trying a different spot...")
        rejectedPositions[PlacementPositionKey(currentX, currentY)] := true
        SendEvent("{" CancelPlacementKey "}")
        needsHotbarSelection := true
        samePositionAttempts := 0
        Sleep(50)
    }

    canUseAbility := true
    return true
}

PlacementPositionKey(px, py) {
    return Round(px) "," Round(py)
}

BuildPlacementTargets(baseX, baseY) {
    targets := [[Round(baseX), Round(baseY)]]

    for radius in [5, 10, 20] {
        rx := Max(2, ScaleX(radius))
        ry := Max(2, ScaleY(radius))
        for offset in [[0, -ry], [rx, 0], [0, ry], [-rx, 0], [rx, -ry], [rx, ry], [-rx, ry], [-rx, -ry]]
            targets.Push([Round(baseX + offset[1]), Round(baseY + offset[2])])
    }

    return targets
}

IsPlacementExplicitlyRejected() {
    if !getRobloxPos(, , &w, &h)
        return false

    x1 := Round(w * 0.2)
    y1 := Round(h * 0.18)
    x2 := Round(w * 0.7)
    y2 := Round(h * 0.3)
    try {
        blockedByImage := ImageSearch(&fx, &fy, x1, y1, x2, y2,
            "*Trans000000 *50 " A_WorkingDir "/Resources/cannot_place_here.png")
        if (!blockedByImage && FileExist(A_WorkingDir "/Resources/cannot_place_here_v2.png")) {
            blockedByImage := ImageSearch(&fx, &fy, x1, y1, x2, y2,
                "*Trans000000 *50 " A_WorkingDir "/Resources/cannot_place_here_v2.png")
        }
        if blockedByImage
            return true

        ; Only a phrase that explicitly describes blocked geometry may move a
        ; legacy strategy off its recorded pixel. A bare "cannot" is not enough:
        ; messages such as "cannot afford" are money failures, not space failures.
        return ReadMessage(,
            "(?:cannot|can.?t|cant)\s+(?:place|put)(?:\s+(?:the|this|a|an|unit|tower))?\s+(?:here|there)"
            . "|(?:this|that)\s+(?:spot|space|area)\s+(?:is\s+)?(?:blocked|invalid)"
            . "|(?:no|not\s+enough)\s+(?:space|room)")
    } catch Error {
        return false
    }
}

IsPlacementInsufficientFunds() {
    try {
        ; TDS wording has changed over time. Match the semantic phrases instead
        ; of one exact sentence so older/newer UI text stays compatible.
        return ReadMessage(,
            "(?:not\s+enough\s+(?:cash|money|funds)"
            . "|(?:do\s+not|don't|dont)\s+have\s+enough\s+(?:cash|money|funds)"
            . "|(?:cannot|can.?t|cant)\s+afford"
            . "|need\s+(?:more\s+)?(?:cash|money|funds)"
            . "|insufficient\s+(?:cash|funds|money))")
    } catch Error {
        return false
    }
}

GetPlacementFailureReason() {
    if IsPlacementExplicitlyRejected()
        return "space"
    if IsPlacementInsufficientFunds()
        return "funds"
    return "unknown"
}

ResolvePlacementAmbiguity(towerID, &resV2) {
    global RunningStrategy

    passiveDeadline := A_TickCount + 2500
    while (A_TickCount < passiveDeadline) {
        if (IsSet(RunningStrategy) && !RunningStrategy)
            return "cancelled"

        if waitForTowerUI(&resV2, , 300)
            return "success"

        failureReason := GetPlacementFailureReason()
        if (failureReason != "unknown")
            return failureReason
        Sleep(150)
    }

    failureReason := GetPlacementFailureReason()
    if (failureReason != "unknown")
        return failureReason

    RuntimeLogWarn("placement_ambiguous", "Placement remained unresolved after passive re-verification",
        "tower=" towerID)
    return "unknown"
}

SellTower(towerID) {
    global Towers, unfocusX, unfocusY, LastOpenedTowerID, needtocheckTowerUI

    if (!Towers.Has(towerID)) {
        LogToConsole("Tower " towerID " not found for selling!", true)
        RuntimeLogWarn("sell_tower_missing", "A sell step referenced a tower that was never placed",
            "tower=" towerID)
        return false
    }

    LogToConsole("Selling tower " towerID "...")
    needtocheckTowerUI := true
    targetX := Towers[towerID].x
    targetY := Towers[towerID].y
    Click(targetX, targetY)
    Sleep(400)

    attempts := 0
    sellAttempts := 0
    loop {
        panelResV2 := ""
        menuFound := waitForTowerUI(&panelResV2)

        if (!menuFound) {
            attempts++
            if (attempts > 15) {
                LogToConsole("Tower " towerID " menu not found for selling", true)
                RuntimeLogWarn("sell_menu_missing", "The tower panel never opened for a sell step",
                    "tower=" towerID)
                return false
            }
            variation := Random(-10, 10)
            Click(Towers[towerID].x, Towers[towerID].y + variation)
            Sleep(400)
            continue
        }

        sellButton := SellButtonFromPanel(panelResV2)

        if (!IsObject(sellButton)) {
            sellAttempts++
            if (sellAttempts > 8) {
                LogToConsole("Tower " towerID " was not sold: the Sell button could not be located.", true)
                RuntimeLogWarn("sell_button_missing", "The Sell label was not found inside the open tower panel",
                    "tower=" towerID)
                return false
            }
            Sleep(200)
            continue
        }

        Click(sellButton.x, sellButton.y)
        Sleep(350)
        needtocheckTowerUI := true

        if (!WaitForTowerUIClosed(1200)) {
            sellAttempts++
            if (sellAttempts > 8) {
                LogToConsole("Tower " towerID " sell was not confirmed; the tower panel stayed open.", true)
                RuntimeLogWarn("sell_unconfirmed", "The tower panel remained open after the Sell button was clicked",
                    "tower=" towerID)
                SellTowerForget(towerID)
                return false
            }
            Sleep(200)
            continue
        }

        LogToConsole("Tower " towerID " sold successfully")
        SellTowerForget(towerID)
        return true
    }
    return false
}

SellButtonFromPanel(panelResV2) {
    if (IsObject(panelResV2) && panelResV2.HasProp("score") && panelResV2.score > 0.55)
        return panelResV2

    getRobloxPos(&rx, &ry, &w, &h)
    X1_v2 := 0
    Y1_v2 := Round(h / 2.5)
    W_v2 := Round(w * 0.3) - X1_v2
    H_v2 := h - Y1_v2

    fallback := AdvancedImageSearch("Resources\TowerUI\Variant2.png", X1_v2, Y1_v2, W_v2, H_v2, , , 0.05)
    if (IsObject(fallback) && fallback.HasProp("score") && fallback.score > 0.55)
        return fallback

    return ""
}

SellTowerForget(towerID) {
    global Towers, LastOpenedTowerID

    if !Towers.Has(towerID)
        return

    try {
        if (Towers[towerID].HasProp("hwnd") && Towers[towerID].hwnd)
            WinClose("ahk_id " Towers[towerID].hwnd)
    }
    Towers.Delete(towerID)
    if (LastOpenedTowerID = towerID)
        LastOpenedTowerID := ""
}

UpgradeTower(towerID, skipOpen := false, totalUpgrades := 1, path := 0, pathLevel := 0) {
    global Towers, unfocusX, unfocusY, LastOpenedTowerID, needtocheckTowerUI, UpgradeDelay
    global PotatoMode, Recording, RecordedSteps, Commander, canUseAbility, RunningStrategy

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
    upgradeActionAttempts := 0

    upgTime := A_TickCount
    upgradeDeadline := A_TickCount
    maxLevelChecked := 0

    Sleep(20)

    loop {
        if (IsSet(RunningStrategy) && !RunningStrategy) {
            canUseAbility := true
            return false
        }

        openedSuccessfully := false

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
                    return false
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

        isGreen := HasStableUpgradeAffordance(XA, YA, X2, Y2)
        if (isGreen && canBeUpgraded) {
            beforeEvidence := CaptureUpgradeEvidence(XA, YA, WA, HA)
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

            settleDelay := Max(250, IsNumber(UpgradeDelay) ? Integer(UpgradeDelay) : 250)
            Sleep(settleDelay)
            needtocheckTowerUI := true

            afterEvidence := CaptureUpgradeEvidence(XA, YA, WA, HA)
            verifiedResV2 := ""
            verifiedResV1 := ""
            uiVerified := waitForTowerUI(&verifiedResV2, &verifiedResV1, 1000)
            if (!uiVerified || beforeEvidence = "" || afterEvidence = "" || beforeEvidence = afterEvidence) {
                Sleep(300)
                lateEvidence := CaptureUpgradeEvidence(XA, YA, WA, HA)
                if (lateEvidence != "" && beforeEvidence != "" && lateEvidence != beforeEvidence) {
                    afterEvidence := lateEvidence
                } else if (upgradeActionAttempts < 2 && HasStableUpgradeAffordance(XA, YA, X2, Y2)) {
                    upgradeActionAttempts++
                    RuntimeLogWarn("upgrade_retry", "Upgrade was not confirmed; retrying within bounded budget",
                        "tower=" towerID "; next_level=" nextLevel "; attempt=" upgradeActionAttempts)
                    canUseAbility := true
                    needtocheckTowerUI := true
                    Sleep(250)
                    continue
                } else {
                    LogToConsole("Tower " towerID " upgrade was not confirmed; refusing to advance internal state.", true)
                    RuntimeLogWarn("upgrade_ambiguous", "Upgrade input did not produce sufficient post-action evidence after bounded retries",
                        "tower=" towerID "; next_level=" nextLevel)
                    canUseAbility := true
                    return false
                }
            }

            if (afterEvidence = "" || beforeEvidence = afterEvidence) {
                LogToConsole("Tower " towerID " upgrade was not confirmed; refusing to advance internal state.", true)
                RuntimeLogWarn("upgrade_ambiguous", "Upgrade evidence remained unchanged after passive verification",
                    "tower=" towerID "; next_level=" nextLevel)
                canUseAbility := true
                return false
            }

            upgradeActionAttempts := 0
            Towers[towerID].level += 1
            if Towers[towerID].HasProp("pendingPlacement")
                Towers[towerID].pendingPlacement := false
            upgradesDone++
            MacroPhase("playing_upgrade_progress", 900000)
            LogToConsole("Tower " towerID " upgraded to level " Towers[towerID].level " (" upgradesDone "/" totalUpgrades ")"
            )
            UpdateTowerIndicator(towerID)

            if (Towers[towerID].level >= 2 && RegExMatch(towerID, "i)^Commander\d*$") && !Commander) {
                Commander := true
                if (Recording && !HasStep("Commander := true"))
                    RecordStep("Commander := true")
            }

            canUseAbility := true

            if (upgradesDone >= totalUpgrades)
                return true

            upgradeDeadline := A_TickCount
            continue
        }

        if (A_TickCount - maxLevelChecked > 3000) {
            maxLevelChecked := A_TickCount
            if (AdvancedImageSearch("Resources/fully_upgraded.png", XA, YA, WA, HA).score >= 0.69) {
                LogToConsole("Tower " towerID " is already fully upgraded, moving on.")
                if Towers[towerID].HasProp("pendingPlacement")
                    Towers[towerID].pendingPlacement := false
                canUseAbility := true
                return true
            }
        }

        Sleep((PotatoMode = 1) ? 200 : 100)
    }
}

HasStableUpgradeAffordance(x1, y1, x2, y2) {
    try {
        if !PixelSearch(&gx, &gy, x1, y1, x2, y2, 0x206235, 12)
            return false
        Sleep(60)
        return PixelSearch(&gx, &gy, x1, y1, x2, y2, 0x206235, 12)
    } catch Error {
        return false
    }
}

CaptureUpgradeEvidence(x, y, w, h) {
    if (w <= 0 || h <= 0)
        return ""

    evidence := ""
    for _, point in [[0.12, 0.20], [0.50, 0.20], [0.88, 0.20], [0.12, 0.50], [0.50, 0.50],
        [0.88, 0.50], [0.12, 0.80], [0.50, 0.80], [0.88, 0.80]] {
        try evidence .= PixelGetColor(x + Round(w * point[1]), y + Round(h * point[2]), "RGB") "|"
        catch Error
            return ""
    }
    return evidence
}

isDisconnected() {
    ActivateRoblox()

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
        return TryReconnect()

    return true
}

TryReconnect() {
    global RunningStrategy
    attempts := 0
    maxReconnectAttempts := 5
    loop {
        if !RunningStrategy
            return false
        attempts++
        if (attempts > maxReconnectAttempts) {
            RuntimeLogError("reconnect_retry_exhausted", "Reconnect stopped after the bounded retry budget",
                "attempts=" maxReconnectAttempts)
            StopStrategy()
            return false
        }
        LogToConsole("Reconnecting... Attempt " attempts ".", true, false)
        KillSubmacros()
        CloseRoblox()
        if (RunRoblox(false) == false) {
            if !RunningStrategy
                return false
            continue
        } else {
            LogToConsole("Reconnect successful after " attempts " attempts!", true, false)
            startWatchdog()
            return true
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
        ActivateRoblox()

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

            ActivateRoblox()
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

            DJTrack := FindDJTrackButton(trackImage, w, h)
            if (DJTrack.status = "success" && DJTrack.score > 0.6) {
                MouseMove(DJTrack.x, DJTrack.y, A_DefaultMouseSpeed)
                Sleep(80)
                Click(DJTrack.x, DJTrack.y)
                Sleep(350)

                if DJTrackCooldownActive(w, h) {
                    LogToConsole("DJ track is on cooldown. Waiting and retrying...")
                    remainingMs := deadline - A_TickCount
                    if (remainingMs <= 250)
                        continue
                    Sleep(Min(4500, remainingMs - 100))
                    needtocheckTowerUI := true
                    continue
                }

                getRobloxPos(, , &w, &h)
                confirmTrack := FindDJTrackButton(trackImage, w, h)
                if (
                    confirmTrack.status = "success"
                    && confirmTrack.score > 0.6
                    && Abs(confirmTrack.x - DJTrack.x) <= ScaleX(45)
                    && Abs(confirmTrack.y - DJTrack.y) <= ScaleY(35)
                ) {
                    RuntimeLogInfo("dj_track_confirmation_retry",
                        "DJ track control remained stable after the first click; sending one confirmation click",
                        "track=" trackName "; attempt=" attempts)
                    ActivateRoblox()
                    MouseMove(confirmTrack.x, confirmTrack.y, A_DefaultMouseSpeed)
                    Sleep(80)
                    Click(confirmTrack.x, confirmTrack.y)
                    Sleep(300)

                    if DJTrackCooldownActive(w, h) {
                        LogToConsole("Successfully changed DJ track to " track)
                        RuntimeLogInfo("dj_track_changed",
                            "DJ track selection confirmed by cooldown on the bounded verification click",
                            "track=" trackName "; attempts=" attempts)
                        return true
                    }
                }

                LogToConsole("Successfully changed DJ track to " track)
                RuntimeLogInfo("dj_track_changed", "DJ track selection completed after bounded UI verification",
                    "track=" trackName "; attempts=" attempts)
                return true
            }

            if (Mod(attempts, 3) = 0) {
                Click(ScaleX(unfocusX), ScaleY(unfocusY))
                Sleep(150)
                ActivateRoblox()
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

FindDJTrackButton(trackImage, w, h) {
    djSearchX := 0
    djSearchY := Round(h * 0.12)
    djSearchW := Round(w * 0.52)
    djSearchH := Max(1, Round(h * 0.80))
    return AdvancedImageSearch(trackImage, djSearchX, djSearchY, djSearchW, djSearchH, 0.5, 1.5, 0.05)
}

DJTrackCooldownActive(w, h) {
    x1 := Round(w * 0.2)
    y1 := Round(h * 0.18)
    x2 := Round(w * 0.7)
    y2 := Round(h * 0.3)
    return (
        ImageSearch(&fx, &fy, x1, y1, x2, y2, "*Trans000000 *50 " A_WorkingDir "/Resources/please_wait.png")
        || ReadMessage(["please", "wait"])
    )
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
    global requiredTowers, Towers, RecordedTowerIds

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
    escapedBase := RegExReplace(baseName, "([\\\.\^\$\*\+\?\(\)\[\]\{\}\|])", "\$1")

    if (IsObject(Towers)) {
        for id, t in Towers {
            if (RegExMatch(id, "i)^" escapedBase "(\d+)$", &match)) {
                num := Integer(match[1])
                if (num > count) {
                    count := num
                }
            }
        }
    }

    if (IsSet(RecordedTowerIds) && IsObject(RecordedTowerIds)) {
        for id, used in RecordedTowerIds {
            if (RegExMatch(id, "i)^" escapedBase "(\d+)$", &match)) {
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

DebugOverlayHitTest(wParam, lParam, msg, hwnd) {
    global OverlayHWND
    if (hwnd = OverlayHWND)
        return -1
}

PointIsOverMacroOverlay(px, py) {
    global OverlayHWND
    if (!OverlayHWND || !WinExist("ahk_id " OverlayHWND))
        return false
    try {
        WinGetPos(&ox, &oy, &ow, &oh, "ahk_id " OverlayHWND)
        return (px >= ox && px <= ox + ow && py >= oy && py <= oy + oh)
    } catch Error
        return false
}

OcrMatchTargetsGameUI(match, label) {
    if (!IsObject(match))
        return false

    px := match.x + (match.w // 2)
    py := match.y + (match.h // 2)

    if PointIsOverMacroOverlay(px, py) {
        RuntimeLogWarn("ocr_match_rejected_overlay", "Ignored an OCR match that landed on the macro log overlay",
            "target=" label "; x=" px "; y=" py)
        return false
    }

    if GetRobloxScreenClientRect(&cx, &cy, &cw, &ch) {
        if (px < cx || px > cx + cw || py < cy || py > cy + ch) {
            RuntimeLogWarn("ocr_match_rejected_outside", "Ignored an OCR match that landed outside the Roblox client area",
                "target=" label "; x=" px "; y=" py)
            return false
        }
    }

    return true
}

HideDebugConsole() {
    global OverlayHWND, OverlayBitmap, OverlayGraphics, OverlayPicHWND

    if (OverlayGraphics) {
        Gdip_DeleteGraphics(OverlayGraphics)
        OverlayGraphics := 0
    }
    if (OverlayBitmap) {
        Gdip_DisposeImage(OverlayBitmap)
        OverlayBitmap := 0
    }
    if (OverlayHWND) {
        try {
            GuiFromHwnd(OverlayHWND).Destroy()
        } catch {
            try WinClose("ahk_id " OverlayHWND)
        }
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
    Sleep(2000)

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

StopRuntimeTimers() {
    try SetTimer(UseAbilities, 0)
    try SetTimer(checkCondition, 0)
    try SetTimer(CheckPopups, 0)
    try SetTimer(CancelInviteIfAppeared, 0)
}

StopApplicationTimers() {
    StopScrollDrag()
    try SetTimer(RefreshWebhookStatus, 0)
    try SetTimer(ConfirmWebhookLink, 0)
    try SetTimer(CheckWebhookLink2, 0)
    try SetTimer(ProcessWebhookQueue, 0)
    try SetTimer(ProcessWebhookInstantQueue, 0)
    try SetTimer(Hoverwatchdog, 0)
    try SetTimer(WatchToolPreviews, 0)
    try SetTimer(ProcessCommands, 0)
    try OfficialRemoteShutdown()
}

ReleaseHeldInput() {
    global MoveDirection

    try Click("Left Up")
    try Click("Right Up")

    for k in ["o", "w", "a", "s", "d", "Shift", "Ctrl", "Left", "Right", "Up", "Down",
        "sc011", "sc01e", "sc01f", "sc020", "sc012", "sc02A"] {
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

    FlushPendingSettingSaves()
    try RecordingAutosaveRewrite(true)

    StopRuntimeTimers()
    StopApplicationTimers()

    ReleaseHeldInput()

    KillSubmacros()
    if (OverlayHWND) {
        HideDebugConsole()
    }

    DeleteAllIndicators()
    if (RunningStrategy) {
        currentStrat := IniRead(StateFile, "State", "Strategy", "")
        if (currentStrat != "") {
            IniWrite(1, StateFile, "State", "Running")
        }
    }

    FlushWebhookQueue()

    if (IsSet(MainGui) && MainGui) {
        try MainGui.Destroy()
    }

    Reload()

    SetTimer(ClearRestartLock, -4000)
}

ClearRestartLock() {
    global RestartLock
    RestartLock := false
    RuntimeLogWarn("reload_did_not_take", "Reload() did not replace the process; restart lock cleared")
}

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

    watchdogPID := ""

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

    try FlushPendingSettingSaves()
    try RecordingAutosaveRewrite(true)

    try StopRuntimeTimers()
    try StopApplicationTimers()

    try ReleaseHeldInput()

    autoSettingsEnabled := IsSet(AutoConfigureSettings) && AutoConfigureSettings
    if (autoSettingsEnabled || AutoSettingsBackupExists()) {
        try {
            if !RequestAutoSettingsRestore(A_ScriptDir)
                RuntimeLogWarn("auto_settings_restore_schedule_failed",
                    "Could not schedule Roblox settings restore; original backup was preserved",
                    "detail=" GetAutoSettingsLastError())
        } catch Error as err {
            RuntimeLogWarn("auto_settings_restore_schedule_failed",
                "Could not schedule Roblox settings restore; original backup was preserved",
                "error=" err.Message)
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
    global pToken
    CleanupRenderedBitmaps()
    if (IsSet(pToken) && pToken)
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

ReadMessage(includeStr := "", includeRx := "", excludeStr := "", excludeRx := "") {
    langCode := "en-US"
    for availableLang in StrSplit(OCR.GetAvailableLanguages(), "`n", "`r") {
        if (availableLang != "" && SubStr(availableLang, 1, 2) = "en") {
            langCode := availableLang
            break
        }
    }

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
        H_v2 := h - Y1_v2

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

WaitForTowerUIClosed(timeout := 500) {
    startTime := A_TickCount
    clearSamples := 0
    loop {
        if waitForTowerUI(, , 60) {
            clearSamples := 0
        } else {
            clearSamples++
            if (clearSamples >= 2)
                return true
        }
        if (A_TickCount - startTime >= timeout)
            return (clearSamples > 0)
        Sleep(50)
    }
}

RunAutoAbTool(*) {
    global Auto_Ability
    LaunchToolOverPreview("auto_ability.ahk", Auto_Ability)
}

RunAutoSpinTool(*) {
    global Auto_Spin
    LaunchToolOverPreview("auto_spin.ahk", Auto_Spin)
}

RunAutoConsumableTool(*) {
    global Auto_Consum
    LaunchToolOverPreview("auto_open_consumable.ahk", Auto_Consum)
}

ToolWindowSize() {
    return { w: 250, h: 252 }
}

PreviewLaunchPoint(previewCtrl) {
    global MainGui

    size := ToolWindowSize()
    previewCtrl.GetPos(&cx, &cy, &cw, &ch)

    point := Buffer(8, 0)
    NumPut("Int", cx, point, 0)
    NumPut("Int", cy, point, 4)
    DllCall("user32\ClientToScreen", "Ptr", MainGui.Hwnd, "Ptr", point)

    screenX := NumGet(point, 0, "Int") + Round((cw - size.w) / 2)
    screenY := NumGet(point, 4, "Int") + Round((ch - size.h) / 2)

    return { x: screenX, y: screenY }
}

LaunchToolOverPreview(scriptName, previewCtrl) {
    global ToolPreviewWatch, MainGui

    if (ToolPreviewWatch.Has(scriptName)) {
        existing := ToolPreviewWatch[scriptName]
        if ProcessExist(existing.pid) {
            try WinActivate("ahk_pid " existing.pid)
            return
        }
        ToolPreviewWatch.Delete(scriptName)
    }

    interpreter := (A_PtrSize == 4) ? "AutoHotkey32.exe" : "AutoHotkey64.exe"
    spot := PreviewLaunchPoint(previewCtrl)
    command := '"' A_ScriptDir '\submacros\' interpreter '" "' A_ScriptDir '\submacros\' scriptName '" '
        . spot.x " " spot.y " " MainGui.Hwnd

    toolPid := 0
    try {
        Run(command, , , &toolPid)
    } catch Error as err {
        RuntimeLogWarn("tool_launch_failed", "A Tools page helper could not be started",
            "tool=" scriptName "; error=" err.Message)
        MsgBox("This tool could not be started.`n`n" err.Message, "Tool unavailable", 0x10)
        return
    }

    if (!toolPid)
        return

    SetControlVisible(previewCtrl, false)
    ToolPreviewWatch[scriptName] := { pid: toolPid, preview: previewCtrl }
    SetTimer(WatchToolPreviews, 400)
}

WatchToolPreviews() {
    global ToolPreviewWatch

    finished := []
    for scriptName, entry in ToolPreviewWatch {
        if !ProcessExist(entry.pid)
            finished.Push(scriptName)
    }

    for scriptName in finished
        RestoreToolPreview(scriptName)

    if (ToolPreviewWatch.Count = 0)
        SetTimer(WatchToolPreviews, 0)
}

RestoreToolPreview(scriptName) {
    global ToolPreviewWatch, CurrentTab

    if !ToolPreviewWatch.Has(scriptName)
        return

    entry := ToolPreviewWatch[scriptName]
    ToolPreviewWatch.Delete(scriptName)

    if (IsSet(CurrentTab) && CurrentTab = "Tab6")
        SetControlVisible(entry.preview, true)

    if (ToolPreviewWatch.Count = 0)
        SetTimer(WatchToolPreviews, 0)
}

ToolWindowClosing(wParam, lParam, msg, hwnd) {
    global ToolPreviewWatch

    for scriptName, entry in ToolPreviewWatch {
        if (entry.pid = wParam) {
            RestoreToolPreview(scriptName)
            break
        }
    }
    return 0
}

RestoreToolPreviews() {
    global ToolPreviewWatch

    for scriptName, entry in ToolPreviewWatch {
        if !ProcessExist(entry.pid)
            continue
        SetControlVisible(entry.preview, false)
    }
}
