#Requires AutoHotkey v2.0
#SingleInstance Force

CoordMode("Mouse", "Client")
CoordMode("Pixel", "Client")
SendMode("Event")

Esc:: ExitApp()
F2:: ExitApp()

if (A_Args.Length < 1) {
    MsgBox("No replay .strat was supplied.", "Strategy Lab Sandbox Replay", "Iconx")
    ExitApp()
}

stratPath := A_Args[1]
if !FileExist(stratPath) {
    MsgBox("Replay strategy was not found:`n" stratPath, "Strategy Lab Sandbox Replay", "Iconx")
    ExitApp()
}

try replay := SLE_ParseReplay(stratPath)
catch as err {
    MsgBox("Could not read the replay strategy.`n`n" err.Message, "Strategy Lab Sandbox Replay", "Iconx")
    ExitApp()
}

if (replay.steps.Length = 0) {
    MsgBox("The replay strategy has no SpawnTower steps.", "Strategy Lab Sandbox Replay", "Icon!")
    ExitApp()
}
for index, step in replay.steps {
    if (step.slot < 1 || step.slot > 5) {
        MsgBox("SpawnTower step " index " uses invalid slot " step.slot ".", "Strategy Lab Sandbox Replay", "Iconx")
        ExitApp()
    }
}

contract := SLE_GetMacroContract()
if !contract.exact {
    MsgBox(
        "Strategy Lab refused to run an exact calibration replay because the installed Ultimate Macro camera/coordinate contract could not be verified.`n`n"
        . "Reason: " contract.reason "`n"
        . (contract.version != "" ? "Detected macro: " contract.version "`n" : "")
        . (contract.mainPath != "" ? "Main file: " contract.mainPath "`n`n" : "`n")
        . "This guard is intentional: a future macro camera change would make the measurement meaningless.",
        "Strategy Lab Sandbox Replay", "Iconx")
    ExitApp()
}

runtime := SLE_ReadMacroRuntimeSettings()
SetDefaultMouseSpeed(runtime.mouseSpeed)
SetMouseDelay(runtime.mouseDelay)
SetKeyDelay(runtime.keyDelay)

hwnd := SLE_GetRobloxHwnd()
if !hwnd {
    MsgBox("Roblox was not found.`nEnter Sandbox first, then launch Replay again.", "Strategy Lab Sandbox Replay",
        "Icon!")
    ExitApp()
}

try WinGetClientPos(&clientScreenX, &clientScreenY, &clientW, &clientH, "ahk_id " hwnd)
catch {
    MsgBox("Could not read the Roblox client rectangle.", "Strategy Lab Sandbox Replay", "Iconx")
    ExitApp()
}
if (clientW < 100 || clientH < 100) {
    MsgBox("The Roblox client rectangle is not usable.", "Strategy Lab Sandbox Replay", "Iconx")
    ExitApp()
}

loadout := replay.requiredTowers.Length ? SLE_Join(replay.requiredTowers, " → ") : "(not declared)"
sizeNote := ""
if (replay.width > 0 && replay.height > 0 && (replay.width != clientW || replay.height != clientH)) {
    sizeNote := "`n`nStrategy source size " replay.width "×" replay.height " differs from the current client " clientW "×" clientH ". Coordinates will be scaled with Ultimate Macro's sX/sY contract."
}

answer := MsgBox(
    "SANDBOX STRATEGY REPLAY`n`n"
    . "Stay inside an already-open Sandbox match. This runner will NOT choose a map or mode.`n`n"
    . "Verified Ultimate Macro: " contract.version "`n"
    . "Coordinate space: Roblox CLIENT`n"
    . "Camera contract: verified v1.3.x AlignCamera sequence`n"
    . (SLE_MapCameraZoomInSteps(replay.mapName)
        ? replay.mapName " keeps the camera " SLE_MapCameraZoomInSteps(replay.mapName) " zoom step closer, matching the macro.`n`n"
        : "`n")
    . "Loadout order:`n" loadout "`n`n"
    . "Placements: " replay.steps.Length "`n"
    . "Current client: " clientW "×" clientH "`n`n"
    . "It will:`n"
    . "1) re-align the camera with the verified Ultimate Macro sequence,`n"
    . "2) select each requested slot and place at the marked client-local X/Y,`n"
    . "3) retry the exact point on ambiguous UI lag and use bounded offsets only after TDS explicitly rejects the space,`n"
    . "4) confirm each placement and report any tower that was not detected.`n`n"
    . "IMPORTANT: sell/clear the manual sample towers before continuing, otherwise the same positions are occupied."
    . sizeNote,
    "Strategy Lab Sandbox Replay", "YesNo Icon!")
if (answer != "Yes")
    ExitApp()

logPath := SLE_SiblingPath(stratPath, "replay.log")
statusPath := SLE_SiblingPath(stratPath, "replay-status.ini")
try FileDelete(statusPath)
IniWrite("running", statusPath, "Replay", "State")
IniWrite(replay.steps.Length, statusPath, "Replay", "Total")
try FileDelete(logPath)
SLE_Log(logPath, "START strat=" stratPath)
SLE_Log(logPath, "macroVersion=" contract.version " main=" contract.mainPath)
SLE_Log(logPath, "coordMode=Client source=" replay.width "x" replay.height " client=" clientW "x" clientH)
SLE_Log(logPath, "map=" (replay.mapName != "" ? replay.mapName : "(not declared)") " cameraZoomInSteps=" SLE_MapCameraZoomInSteps(
    replay.mapName))
SLE_Log(logPath, "clientScreenOrigin=" clientScreenX "," clientScreenY " (capture metadata only; never added to .strat X/Y)"
)
SLE_Log(logPath, "settings UseNumbers=" runtime.useNumbers " CancelPlacement=" runtime.cancelKey " UpgradeTower=" runtime
    .upgradeKey " PotatoMode=" runtime.potatoMode " MouseSpeed=" runtime.mouseSpeed " MouseDelay=" runtime.mouseDelay " KeyDelay=" runtime
    .keyDelay)
SLE_Log(logPath, "loadout=" loadout)

try {
    placedSteps := []
    failedSteps := []
    upgradeFailedSteps := []
    cameraPitchRecovered := false
    SLE_AlignCameraLikeDarksen(hwnd, runtime.mouseDelay, replay.mapName)
    Sleep(300)

    for index, step in replay.steps {
        placement := SLE_PlaceReplayTower(contract.root, hwnd, step, replay, runtime, logPath, index, cameraPitchRecovered)
        cameraPitchRecovered := placement.pitchRecovered
        if placement.ok {
            placedSteps.Push({ index: index, slot: step.slot, id: step.id, x: placement.x, y: placement.y })
            IniWrite("placed", statusPath, "Steps", "Status" index)
            IniWrite(step.id, statusPath, "Steps", "ID" index)
            SLE_Log(logPath, "PLACED step=" index " slot=" step.slot " id=" step.id " source=" step.x "," step.y
                . " actual=" placement.x "," placement.y " attempts=" placement.attempts " offset=" (placement.offset ? "1" : "0"))
            IniWrite("upgrading", statusPath, "Steps", "Status" index)
            if SLE_UpgradePlacedTower(contract.root, hwnd, placement.x, placement.y, runtime.upgradeKey) {
                IniWrite("upgraded", statusPath, "Steps", "Status" index)
                SLE_Log(logPath, "UPGRADED step=" index " slot=" step.slot " id=" step.id)
            } else {
                upgradeFailedSteps.Push({ index: index, slot: step.slot, id: step.id })
                IniWrite("upgrade_failed", statusPath, "Steps", "Status" index)
                SLE_Log(logPath, "UPGRADE_FAILED step=" index " slot=" step.slot " id=" step.id)
            }
            SLE_CloseTowerPanelIfOpen(contract.root, hwnd)
        } else {
            failedSteps.Push({ index: index, slot: step.slot, id: step.id, x: placement.x, y: placement.y })
            IniWrite("failed", statusPath, "Steps", "Status" index)
            IniWrite(step.id, statusPath, "Steps", "ID" index)
            SLE_Log(logPath, "FAILED step=" index " slot=" step.slot " id=" step.id " source=" step.x "," step.y
                . " scaled=" placement.x "," placement.y " attempts=" placement.attempts " reason=" placement.reason)
        }
    }

    failedText := ""
    for item in failedSteps
        failedText .= "`n• Step " item.index ": slot " item.slot " - " item.id
    if (failedText = "")
        failedText := "`nNone - all placements were confirmed."
    upgradeFailedText := ""
    for item in upgradeFailedSteps
        upgradeFailedText .= "`n• Step " item.index ": slot " item.slot " - " item.id
    if (upgradeFailedText = "")
        upgradeFailedText := "`nNone - all confirmed towers were upgraded."
    IniWrite("complete", statusPath, "Replay", "State")

    MsgBox(
        "Sandbox placement and upgrade finished.`n`n"
        . "Placed: " placedSteps.Length "/" replay.steps.Length "`n"
        . "Upgraded: " (placedSteps.Length - upgradeFailedSteps.Length) "/" replay.steps.Length "`n"
        . "Towers not confirmed:" failedText "`n`n"
        . "Towers not upgraded:" upgradeFailedText "`n`n"
        . "The full placement log is here:`n" logPath,
        "Strategy Lab Sandbox Replay", "Iconi")
} catch as err {
    IniWrite("error", statusPath, "Replay", "State")
    SLE_Log(logPath, "ERROR " err.Message)
    MsgBox("Sandbox replay stopped.`n`n" err.Message "`n`nLog:`n" logPath, "Strategy Lab Sandbox Replay", "Iconx")
}

ExitApp()

SLE_ParseReplay(path) {
    required := []
    steps := []
    section := ""
    mapName := ""
    width := 1920
    height := 1009

    loop read, path {
        line := Trim(A_LoopReadLine)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue

        if RegExMatch(line, "^\[(.+)\]$", &sectionMatch) {
            section := StrLower(Trim(sectionMatch[1]))
            continue
        }

        if (section = "settings" && RegExMatch(line, "i)^requiredTowers\s*=\s*(.*)$", &m)) {
            for tower in StrSplit(m[1], ",") {
                name := Trim(tower)
                if (name != "")
                    required.Push(name)
            }
            continue
        }

        if (section = "settings" && RegExMatch(line, "i)^map\s*=\s*(.*)$", &mMap)) {
            mapName := Trim(mMap[1])
            continue
        }

        if (section = "do not edit") {
            if RegExMatch(line, "i)^width\s*=\s*(\d+)$", &mWidth) {
                width := Max(1, Integer(mWidth[1]))
                continue
            }
            if RegExMatch(line, "i)^height\s*=\s*(\d+)$", &mHeight) {
                height := Max(1, Integer(mHeight[1]))
                continue
            }
        }

        if (section = "steps" && RegExMatch(line,
            "i)^SpawnTower\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(\d+)\s*,\s*([^\)]+)\)\s*$", &m)) {
            rawId := Trim(m[4])
            if (StrLen(rawId) >= 2) {
                firstChar := SubStr(rawId, 1, 1)
                lastChar := SubStr(rawId, -1)
                if ((firstChar = Chr(34) && lastChar = Chr(34)) || (firstChar = Chr(39) && lastChar = Chr(39)))
                    rawId := SubStr(rawId, 2, StrLen(rawId) - 2)
            }
            steps.Push({
                x: Round(Number(m[1])),
                y: Round(Number(m[2])),
                slot: Integer(m[3]),
                id: Trim(rawId)
            })
        }
    }

    return { requiredTowers: required, steps: steps, width: width, height: height, mapName: mapName }
}

SLE_PlaceReplayTower(root, hwnd, step, replay, runtime, logPath, stepIndex, cameraPitchRecovered := false) {
    baseX := SLE_ScaleReplayX(step.x, replay.width, replay.height, hwnd)
    baseY := SLE_ScaleReplayY(step.y, replay.width, replay.height, hwnd)
    targets := SLE_BuildPlacementTargets(baseX, baseY, hwnd)
    targetIndex := 1
    placeAttempts := 0
    samePositionAttempts := 0
    maxPlacementAttempts := 9
    maxSameSpotRetries := 8

    loop {
        if (targetIndex > targets.Length || placeAttempts >= maxPlacementAttempts)
            return { ok: false, x: baseX, y: baseY, attempts: placeAttempts, reason: "retry_exhausted", offset: false, pitchRecovered: cameraPitchRecovered }

        current := targets[targetIndex]
        currentX := current[1]
        currentY := current[2]

        WinActivate("ahk_id " hwnd)
        if !WinWaitActive("ahk_id " hwnd, , 2.0)
            throw Error("Roblox lost focus before placement " stepIndex ".")

        SLE_CloseTowerPanelIfOpen(root, hwnd)

        if runtime.useNumbers {
            Send("{" step.slot "}")
        } else {
            slotPoint := SLE_DefaultSlotPoint(step.slot, hwnd)
            Click(slotPoint[1], slotPoint[2])
        }

        Sleep(runtime.potatoMode = 1 ? 100 : 30)
        MouseMove(currentX, currentY, runtime.mouseSpeed)
        Sleep(runtime.potatoMode = 1 ? 100 : 40)
        MouseClick()
        placeAttempts++
        Sleep(100)
        SendEvent("{" runtime.cancelKey "}")

        if SLE_WaitForTowerConfirmation(root, hwnd, 5000) {
            return {
                ok: true,
                x: currentX,
                y: currentY,
                attempts: placeAttempts,
                reason: "confirmed",
                offset: currentX != baseX || currentY != baseY,
                pitchRecovered: cameraPitchRecovered
            }
        }

        if SLE_IsPlacementExplicitlyRejected(root, hwnd) {
            SLE_Log(logPath, "SPACE_REJECTED step=" stepIndex " slot=" step.slot " id=" step.id " x=" currentX " y=" currentY)
            if !cameraPitchRecovered {
                pitchNudge := SLE_ApplyPlacementSafePitch(hwnd, runtime.mouseDelay)
                cameraPitchRecovered := true
                samePositionAttempts := 0
                SLE_Log(logPath, "CAMERA_PITCH_RECOVERY step=" stepIndex " slot=" step.slot " id=" step.id
                    . " nudge_px=" pitchNudge " retry_x=" currentX " retry_y=" currentY)
                Sleep(350)
                continue
            }
            targetIndex++
            samePositionAttempts := 0
            Sleep(350)
            continue
        }

        if (samePositionAttempts < maxSameSpotRetries) {
            samePositionAttempts++
            placeAttempts--
            SLE_Log(logPath, "RETRY_SAME_POSITION step=" stepIndex " slot=" step.slot " id=" step.id " x=" currentX " y=" currentY
                . " retry=" samePositionAttempts)
            Sleep(750)
            continue
        }

        return {
            ok: false,
            x: currentX,
            y: currentY,
            attempts: placeAttempts,
            reason: "unconfirmed",
            offset: currentX != baseX || currentY != baseY,
            pitchRecovered: cameraPitchRecovered
        }
    }
}

SLE_ApplyPlacementSafePitch(hwnd, mouseDelay := 10) {
    WinActivate("ahk_id " hwnd)
    if !WinWaitActive("ahk_id " hwnd, , 2.0)
        return 0

    WinGetClientPos(, , &rw, &rh, "ahk_id " hwnd)
    if (rw < 100 || rh < 100)
        return 0

    pitchNudge := Max(18, Round(rh * 0.03))
    MouseMove(rw / 2, rh / 2, 0)
    Click("Right Down")
    try {
        Sleep(40)
        MouseMove(0, -pitchNudge, 3 + mouseDelay, "R")
        Sleep(15)
    } finally {
        Click("Right Up")
    }
    Sleep(300)
    return pitchNudge
}

SLE_BuildPlacementTargets(baseX, baseY, hwnd) {
    WinGetClientPos(, , &w, &h, "ahk_id " hwnd)
    targets := [[Round(baseX), Round(baseY)]]

    for radius in [5, 10, 20] {
        rx := Max(2, Round(radius * (w / 1920.0)))
        ry := Max(2, Round(radius * (h / 1009.0)))
        for offset in [[0, -ry], [rx, 0], [0, ry], [-rx, 0], [rx, -ry], [rx, ry], [-rx, ry], [-rx, -ry]]
            targets.Push([Round(baseX + offset[1]), Round(baseY + offset[2])])
    }

    return targets
}

SLE_IsPlacementExplicitlyRejected(root, hwnd) {
    WinGetClientPos(, , &w, &h, "ahk_id " hwnd)
    x1 := Round(w * 0.2)
    y1 := Round(h * 0.18)
    x2 := Round(w * 0.7)
    y2 := Round(h * 0.3)

    for fileName in ["cannot_place_here.png", "cannot_place_here_v2.png"] {
        image := root "\Resources\" fileName
        if !FileExist(image)
            continue
        try {
            if ImageSearch(&fx, &fy, x1, y1, x2, y2, "*Trans000000 *50 " image)
                return true
        }
    }
    return false
}

SLE_TowerPanelVisible(root, hwnd) {
    variant2 := root "\Resources\TowerUI\Variant2.png"
    variant1 := root "\Resources\TowerUI\Variant1.png"
    WinGetClientPos(, , &w, &h, "ahk_id " hwnd)

    try {
        if FileExist(variant2) && ImageSearch(&foundX, &foundY, 0, Round(h / 2.5), Round(w * 0.25), Round(h * 0.95),
            "*50 " variant2)
            return true
        if FileExist(variant1) && ImageSearch(&foundX, &foundY, Round(w * 0.16), Round(h * 0.05), Round(w * 0.36),
            Round(h * 0.35), "*50 " variant1)
            return true
    }
    return false
}

SLE_CloseTowerPanelIfOpen(root, hwnd) {
    if !SLE_TowerPanelVisible(root, hwnd)
        return true

    WinGetClientPos(, , &w, &h, "ahk_id " hwnd)
    Click(Round(150 * (w / 1920.0)), Round(200 * (h / 1009.0)))
    deadline := A_TickCount + 2500
    while (A_TickCount < deadline) {
        if !SLE_TowerPanelVisible(root, hwnd)
            return true
        Sleep(100)
    }
    return false
}

SLE_ReadMacroRuntimeSettings() {
    settingsPath := A_AppData "\Ultimate_Macro\Options\Settings.tds"
    useNumbers := true
    cancelKey := "Q"
    potatoMode := 0
    mouseSpeed := 2
    mouseDelay := 10
    keyDelay := 20
    upgradeKey := "E"

    if FileExist(settingsPath) {
        try useNumbers := (String(IniRead(settingsPath, "Options", "UseNumbers", "1")) != "0")
        try cancelKey := Trim(String(IniRead(settingsPath, "Hotkeys", "CancelPlacement", "Q")))
        try potatoMode := Integer(IniRead(settingsPath, "Options", "PotatoMode", "0"))
        try mouseSpeed := Integer(IniRead(settingsPath, "Options", "DefaultMouseSpeed", "2"))
        try mouseDelay := Integer(IniRead(settingsPath, "Options", "MouseDelay", "10"))
        try keyDelay := Integer(IniRead(settingsPath, "Options", "KeyDelay", "20"))
        try upgradeKey := Trim(String(IniRead(settingsPath, "Hotkeys", "UpgradeTower", "E")))
    }

    if (cancelKey = "")
        cancelKey := "Q"
    mouseSpeed := Max(0, Min(100, mouseSpeed))
    mouseDelay := Max(-1, Min(1000, mouseDelay))
    keyDelay := Max(-1, Min(1000, keyDelay))
    if (upgradeKey = "")
        upgradeKey := "E"
    return { useNumbers: useNumbers, cancelKey: cancelKey, upgradeKey: upgradeKey, potatoMode: potatoMode, mouseSpeed: mouseSpeed,
        mouseDelay: mouseDelay, keyDelay: keyDelay }
}

SLE_GetRobloxHwnd() {
    if (hwnd := WinExist("Roblox ahk_exe RobloxPlayerBeta.exe"))
        return hwnd
    if (hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe"))
        return hwnd
    if WinExist("Roblox ahk_exe ApplicationFrameHost.exe") {
        try return ControlGetHwnd("ApplicationFrameInputSinkWindow1")
    }
    return 0
}

SLE_FindMacroRoot() {
    settingsIni := A_AppData "\Ultimate_Macro\StrategyLabEditor\settings.ini"
    candidates := []
    try {
        saved := Trim(IniRead(settingsIni, "Paths", "MacroRoot", ""))
        if (saved != "")
            candidates.Push(saved)
    }
    candidates.Push(A_Desktop "\TDS_Macro")
    candidates.Push(A_Desktop "\Ultimate_Macro")
    candidates.Push(A_Desktop "\Ultimate_Macro\TDS_Macro")

    for candidate in candidates {
        root := RTrim(Trim(String(candidate), Chr(34)), "\/")
        if (FileExist(root "\Main.ahk") || FileExist(root "\Main_Lab.ahk"))
            return root
    }

    try {
        loop files, A_Desktop "\*", "D" {
            name := StrLower(A_LoopFileName)
            if !(InStr(name, "macro") || InStr(name, "tds"))
                continue
            root := A_LoopFileFullPath
            if (FileExist(root "\Main.ahk") || FileExist(root "\Main_Lab.ahk"))
                return root
        }
    }
    return ""
}

SLE_GetMacroContract() {
    root := SLE_FindMacroRoot()
    result := { root: root, mainPath: "", version: "", exact: false, reason: "Ultimate Macro installation was not found." }
    if (root = "")
        return result

    mainPath := FileExist(root "\Main_Lab.ahk") ? root "\Main_Lab.ahk" : root "\Main.ahk"
    result.mainPath := mainPath
    try text := FileRead(mainPath, "UTF-8")
    catch as err {
        result.reason := "Could not read the installed macro source: " err.Message
        return result
    }

    if RegExMatch(text, 'm)^\s*ver\s*:=\s*"([^"]+)"', &vm)
        result.version := vm[1]

    requiredChecks := [
        ['CoordMode Mouse Client', 'i)CoordMode\(\s*"Mouse"\s*,\s*"Client"\s*\)'],
        ['CoordMode Pixel Client', 'i)CoordMode\(\s*"Pixel"\s*,\s*"Client"\s*\)'],
        ['SendMode Event', 'i)SendMode\(\s*"Event"\s*\)'],
        ['sX default width', 'i)sX\(\s*baseX\s*,\s*Width\s*:=\s*1920\s*\)'],
        ['sY legacy default', 'i)sY\(\s*baseY\s*,\s*Height\s*:=\s*1090\s*\)'],
        ['ScaleY client baseline', 'i)ScaleY\(\s*baseY\s*,\s*Height\s*:=\s*1009\s*\)'],
        ['AlignCamera center', 'i)MouseMove\(\s*rw\s*/\s*2\s*,\s*rh\s*/\s*2\s*,\s*0\s*\)'],
        ['AlignCamera right drag', 'i)MouseMove\(\s*0\s*,\s*rh\s*,\s*3\s*\+\s*MouseDelay\s*,\s*"R"\s*\)'],
        ['AlignCamera zoom hold', 'i)HyperSleep\(\s*750\s*\)'],
        ['SpawnTower sX', 'i)X\s*:=\s*sX\(\s*X\s*,\s*StrategyWidth\s*\)'],
        ['SpawnTower sY', 'i)Y\s*:=\s*sY\(\s*Y\s*,\s*StrategyHeight\s*\)'],
        ['UseNumbers setting', 'i)UseNumbersForHotbar\s*:=\s*IniRead\(SettingsFile,\s*"Options",\s*"UseNumbers",\s*1\)'],
        ['CancelPlacement setting',
            'i)CancelPlacementKey\s*:=\s*IniRead\(SettingsFile,\s*"Hotkeys",\s*"CancelPlacement",\s*"Q"\)']
    ]

    missing := []
    for check in requiredChecks {
        if !RegExMatch(text, check[2])
            missing.Push(check[1])
    }

    legacyHotbar := RegExMatch(text, 'is)global\s+Slots\s*:=\s*\[\s*ScaleX\(800\).*?ScaleX\(1120\)')
        && RegExMatch(text, 'i)ScaleY\(960\)')
    dynamicHotbar := RegExMatch(text, 'i)SelectHotbarSlotByClick\(\s*slotNumber\s*\)')
        && RegExMatch(text, 'is)static\s+baseXBySlot\s*:=\s*\[\s*800\s*,\s*880\s*,\s*960\s*,\s*1040\s*,\s*1120\s*\]')
        && RegExMatch(text, 'i)getRobloxPos\(\s*,\s*,\s*&clientWidth\s*,\s*&clientHeight\s*\)')
        && RegExMatch(text, 'i)baseXBySlot\[slot\]\s*\*\s*\(\s*clientWidth\s*/\s*1920(?:\.0)?\s*\)')
        && RegExMatch(text, 'i)960\s*\*\s*\(\s*clientHeight\s*/\s*1009(?:\.0)?\s*\)')
        && RegExMatch(text, 'i)Click\(\s*slotX\s*,\s*slotY\s*\)')
    if (!legacyHotbar && !dynamicHotbar)
        missing.Push("Hotbar selection contract")
    if (missing.Length) {
        result.reason := "Installed macro contract differs from the audited v1.3.x release: " SLE_Join(missing, ", ")
        return result
    }

    result.exact := true
    result.reason := "verified"
    return result
}

SLE_ColorDistance(c1, c2) {
    r1 := (c1 >> 16) & 0xFF, g1 := (c1 >> 8) & 0xFF, b1 := c1 & 0xFF
    r2 := (c2 >> 16) & 0xFF, g2 := (c2 >> 8) & 0xFF, b2 := c2 & 0xFF
    return Sqrt((r1 - r2) ** 2 + (g1 - g2) ** 2 + (b1 - b2) ** 2)
}

SLE_CloseRobloxChat(hwnd) {
    try {
        WinActivate("ahk_id " hwnd)
        color := PixelGetColor(140, 29, "RGB")
        if (SLE_ColorDistance(color, 0xF4F5F8) < 12) {
            MouseGetPos(&mx, &my)
            MouseMove(140, 35, 2)
            Sleep(100)
            Click()
            Sleep(100)
            MouseMove(mx, my)
        }
    }
}

SLE_HyperSleep(ms) {
    static freq := (DllCall("QueryPerformanceFrequency", "Int64*", &f := 0), f)
    DllCall("QueryPerformanceCounter", "Int64*", &begin := 0)
    current := 0
    finish := begin + ms * freq / 1000
    while (current < finish) {
        if ((finish - current) > (freq * 2.0 / 1000)) {
            DllCall("Winmm.dll\timeBeginPeriod", "UInt", 1)
            DllCall("Sleep", "UInt", 1)
            DllCall("Winmm.dll\timeEndPeriod", "UInt", 1)
        }
        DllCall("QueryPerformanceCounter", "Int64*", &current)
    }
}

SLE_MapCameraZoomInSteps(mapName) {
    static steps := Map("cataclysm", 1)
    key := Trim(RegExReplace(StrLower(Trim(String(mapName))), "[^a-z0-9]+", "-"), "-")
    return steps.Has(key) ? steps[key] : 0
}

SLE_ApplyMapCameraZoom(hwnd, mapName) {
    steps := SLE_MapCameraZoomInSteps(mapName)
    if (steps <= 0 || !hwnd)
        return 0

    WinGetClientPos(, , &rw, &rh, "ahk_id " hwnd)
    if (rw < 100 || rh < 100)
        return 0

    MouseGetPos(&restoreX, &restoreY)
    MouseMove(rw / 2, rh / 2, 0)
    Sleep(60)
    loop steps {
        SendEvent("{WheelUp}")
        Sleep(90)
    }
    MouseMove(restoreX, restoreY, 0)
    return steps
}

SLE_AlignCameraLikeDarksen(hwnd, mouseDelay := 10, mapName := "") {
    if !hwnd
        throw Error("Roblox was not found.")
    WinActivate("ahk_id " hwnd)
    if !WinWaitActive("ahk_id " hwnd, , 2.0)
        throw Error("Roblox could not be focused.")

    SLE_CloseRobloxChat(hwnd)
    WinGetClientPos(, , &rw, &rh, "ahk_id " hwnd)
    if (rw < 100 || rh < 100)
        throw Error("Roblox client rectangle is not usable.")

    MouseMove(rw / 2, rh / 2, 0)
    Click("Right Down")
    Sleep(50)
    MouseMove(0, rh, 3 + mouseDelay, "R")
    Sleep(10)
    Click("Right Up")
    Sleep(200)
    SendEvent("{o down}")
    SLE_HyperSleep(750)
    SendEvent("{o up}")
    Sleep(200)
    SLE_ApplyMapCameraZoom(hwnd, mapName)
    Sleep(200)
}

SLE_ScaleReplayX(baseX, sourceWidth, sourceHeight, hwnd) {
    WinGetClientPos(&clientX, , &currentWidth, , "ahk_id " hwnd)
    if (sourceWidth = 0)
        return Round(baseX)
    if (sourceWidth = 1920 && sourceHeight = 1090) {
        WinGetPos(&windowX, , , , "ahk_id " hwnd)
        baseX -= (clientX - windowX)
        sourceWidth := 1920
    }
    return Round(baseX * (currentWidth / sourceWidth))
}

SLE_ScaleReplayY(baseY, sourceWidth, sourceHeight, hwnd) {
    WinGetClientPos(, &clientY, , &currentHeight, "ahk_id " hwnd)
    if (sourceHeight = 0)
        return Round(baseY)
    if (sourceHeight = 1090) {
        WinGetPos(, &windowY, , , "ahk_id " hwnd)
        baseY -= (clientY - windowY)
        sourceHeight := 1009
    }
    return Round(baseY * (currentHeight / sourceHeight))
}

SLE_DefaultSlotPoint(slot, hwnd) {
    baseXs := [800, 880, 960, 1040, 1120]
    WinGetClientPos(, , &w, &h, "ahk_id " hwnd)
    x := Round(baseXs[slot] * (w / 1920))
    y := Round(960 * (h / 1009))
    return [x, y]
}

SLE_WaitForTowerConfirmation(root, hwnd, timeout := 1600) {
    if !FileExist(root "\Resources\TowerUI\Variant2.png") && !FileExist(root "\Resources\TowerUI\Variant1.png")
        return false

    deadline := A_TickCount + timeout
    while (A_TickCount < deadline) {
        if SLE_TowerPanelVisible(root, hwnd)
            return true
        Sleep(100)
    }
    return false
}

SLE_UpgradePlacedTower(root, hwnd, x, y, upgradeKey) {
    WinGetClientPos(, , &w, &h, "ahk_id " hwnd)
    variant2 := root "\Resources\TowerUI\Variant2.png"
    variant1 := root "\Resources\TowerUI\Variant1.png"

    loop 5 {
        Click(x, y)
        Sleep(180)
        if !SLE_WaitForTowerConfirmation(root, hwnd, 900) {
            Sleep(250)
            continue
        }

        upgradeX := 0
        upgradeY := 0
        if FileExist(variant2) && ImageSearch(&menuX, &menuY, 0, Round(h / 2.5), Round(w * 0.25), Round(h * 0.95),
            "*50 " variant2) {
            upgradeX := menuX + Round(50 * w / 1920)
            upgradeY := menuY - Round(220 * h / 1009)
        } else if FileExist(variant1) && ImageSearch(&menuX, &menuY, Round(w * 0.16), Round(h * 0.05), Round(w * 0.36),
            Round(h * 0.35), "*50 " variant1) {
            upgradeX := menuX - Round(164 * w / 1920)
            upgradeY := menuY + Round(383 * h / 1009)
        }

        if (!upgradeX || !upgradeY) {
            SendEvent("{" upgradeKey "}")
            Sleep(300)
            continue
        }

        beforeSignature := SLE_UpgradeRegionSignature(upgradeX, upgradeY, w, h)
        Click(upgradeX, upgradeY)
        Sleep(550)
        afterSignature := SLE_UpgradeRegionSignature(upgradeX, upgradeY, w, h)
        if (beforeSignature != afterSignature)
            return true
        SendEvent("{" upgradeKey "}")
        Sleep(300)
    }
    return false
}

SLE_UpgradeButtonIsGreen(x, y, width, height) {
    try return PixelSearch(&foundX, &foundY, x, y, x + Max(1, width), y + Max(1, height), 0x206235, 12)
    catch
        return false
}

SLE_UpgradeRegionSignature(centerX, centerY, clientWidth, clientHeight) {
    left := Max(0, centerX - Round(35 * clientWidth / 1920))
    top := Max(0, centerY - Round(30 * clientHeight / 1009))
    right := centerX + Round(35 * clientWidth / 1920)
    bottom := centerY + Round(30 * clientHeight / 1009)
    signature := 0
    loop 5 {
        px := left + Round((right - left) * (A_Index - 1) / 4)
        loop 5 {
            py := top + Round((bottom - top) * (A_Index - 1) / 4)
            try signature += PixelGetColor(px, py, "RGB")
        }
    }
    return signature
}

SLE_CaptureClientLossless(hwnd, target) {
    WinGetClientPos(&x, &y, &w, &h, "ahk_id " hwnd)
    helper := A_ScriptDir "\..\capture_roblox.ps1"
    if !FileExist(helper)
        throw Error("capture_roblox.ps1 is missing.")

    cmd := 'powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "' helper
        . '" -X ' x ' -Y ' y ' -Width ' w ' -Height ' h ' -Target "' target '"'
    code := RunWait(cmd, A_ScriptDir "\..", "Hide")
    if (code != 0 || !FileExist(target) || FileGetSize(target) < 1000)
        throw Error("Could not save replay.png.")
}

SLE_SiblingPath(path, fileName) {
    SplitPath(path, , &dir)
    return dir "\" fileName
}

SLE_Join(items, separator := ", ") {
    result := ""
    for index, item in items
        result .= (index > 1 ? separator : "") item
    return result
}

SLE_Log(path, text) {
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " " text "`n", path, "UTF-8")
}