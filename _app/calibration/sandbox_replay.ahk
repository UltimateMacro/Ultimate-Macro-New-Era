#Requires AutoHotkey v2.0
#SingleInstance Force

CoordMode("Mouse", "Client")
CoordMode("Pixel", "Client")
SendMode("Event")

Esc:: ExitApp()
F2:: ExitApp()

if (A_Args.Length >= 1 && A_Args[1] = "--self-test") {
    try {
        SLE_RunParserContractSelfTest()
        ExitApp(0)
    } catch as err {
        FileAppend("Sandbox replay parser self-test failed: " err.Message "`n", "**")
        ExitApp(2)
    }
}

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
    . "Requested upgrades: " replay.requestedUpgrades "`n"
    . "Supported Enforcer actions: " replay.actionCount "`n"
    . (replay.ignored.Length ? "Other strategy commands reported as skipped: " replay.ignored.Length "`n" : "")
    . "Current client: " clientW "×" clientH "`n`n"
    . "It will:`n"
    . "1) re-align the camera with the verified Ultimate Macro sequence,`n"
    . "2) execute supported [Steps] in their original order,`n"
    . "3) place towers, buy every requested UpgradeTower level/path, and confirm each input,`n"
    . "4) run Sleep, EnforcerReposition, and ActivateEnforcerVan commands,`n"
    . "5) report every skipped or failed command explicitly.`n`n"
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
    .upgradeKey " UpgradeBottom=" runtime.upgradeBottomKey " Repo=" runtime.repoKey " EnforcerVan=" runtime.enforcerVanKey
    " PotatoMode=" runtime.potatoMode " MouseSpeed=" runtime.mouseSpeed " MouseDelay=" runtime.mouseDelay " KeyDelay=" runtime.keyDelay)
SLE_Log(logPath, "loadout=" loadout)

try {
    placedSteps := []
    failedSteps := []
    commandFailures := []
    towers := Map()
    upgradesDone := 0
    actionsDone := 0
    cameraPitchRecovered := false
    SLE_AlignCameraLikeDarksen(hwnd, runtime.mouseDelay, replay.mapName)
    Sleep(300)

    for commandIndex, command in replay.commands {
        if (command.type = "spawn") {
            stepIndex := command.placementIndex
            placement := SLE_PlaceReplayTower(contract.root, hwnd, command, replay, runtime, logPath, stepIndex,
                cameraPitchRecovered)
            cameraPitchRecovered := placement.pitchRecovered
            IniWrite(command.id, statusPath, "Steps", "ID" stepIndex)
            if placement.ok {
                placedSteps.Push({ index: stepIndex, slot: command.slot, id: command.id, x: placement.x, y: placement.y })
                towers[command.id] := { id: command.id, slot: command.slot, x: placement.x, y: placement.y, level: 0,
                    path: 0, pathLevel: 0, placementIndex: stepIndex }
                IniWrite("placed", statusPath, "Steps", "Status" stepIndex)
                SLE_Log(logPath, "PLACED command=" commandIndex " step=" stepIndex " slot=" command.slot " id=" command.id
                    " source=" command.x "," command.y " actual=" placement.x "," placement.y " attempts=" placement.attempts
                    " offset=" (placement.offset ? "1" : "0"))
                SLE_CloseTowerPanelIfOpen(contract.root, hwnd)
            } else {
                failedSteps.Push({ index: stepIndex, slot: command.slot, id: command.id, x: placement.x, y: placement.y })
                IniWrite("failed", statusPath, "Steps", "Status" stepIndex)
                commandFailures.Push({ lineNo: command.lineNo, text: command.raw, reason: placement.reason })
                SLE_Log(logPath, "FAILED command=" commandIndex " step=" stepIndex " slot=" command.slot " id=" command.id
                    " source=" command.x "," command.y " scaled=" placement.x "," placement.y " attempts=" placement.attempts
                    " reason=" placement.reason)
            }
            continue
        }

        if (command.type = "upgrade") {
            result := SLE_ExecuteUpgradeCommand(contract.root, hwnd, command, towers, replay, runtime, logPath, statusPath)
            upgradesDone += result.done
            if !result.ok
                commandFailures.Push({ lineNo: command.lineNo, text: command.raw, reason: result.reason })
            continue
        }

        if (command.type = "sleep") {
            SLE_Log(logPath, "SLEEP line=" command.lineNo " ms=" command.ms)
            Sleep(command.ms)
            continue
        }

        if (command.type = "enforcer_reposition") {
            result := SLE_ExecuteEnforcerReposition(contract.root, hwnd, command, towers, replay, runtime, logPath)
            if result.ok
                actionsDone++
            else
                commandFailures.Push({ lineNo: command.lineNo, text: command.raw, reason: result.reason })
            continue
        }

        if (command.type = "activate_enforcer_van") {
            result := SLE_ExecuteEnforcerVan(contract.root, hwnd, command, towers, replay, runtime, logPath)
            if result.ok
                actionsDone++
            else
                commandFailures.Push({ lineNo: command.lineNo, text: command.raw, reason: result.reason })
        }
    }

    failedText := ""
    for item in failedSteps
        failedText .= "`n• Step " item.index ": slot " item.slot " - " item.id
    if (failedText = "")
        failedText := "`nNone - all placements were confirmed."
    failureText := ""
    for item in commandFailures
        failureText .= "`n• Line " item.lineNo ": " item.text " (" item.reason ")"
    if (failureText = "")
        failureText := "`nNone - every supported command completed."
    skippedText := ""
    for item in replay.ignored
        skippedText .= "`n• Line " item.lineNo ": " item.text
    if (skippedText = "")
        skippedText := "`nNone."
    IniWrite("complete", statusPath, "Replay", "State")

    MsgBox(
        "Sandbox strategy replay finished.`n`n"
        . "Placed: " placedSteps.Length "/" replay.steps.Length "`n"
        . "Upgrade inputs confirmed: " upgradesDone "/" replay.requestedUpgrades "`n"
        . "Enforcer actions completed: " actionsDone "/" replay.actionCount "`n"
        . "Towers not confirmed:" failedText "`n`n"
        . "Failed supported commands:" failureText "`n`n"
        . "Skipped unsupported commands:" skippedText "`n`n"
        . "The full replay log is here:`n" logPath,
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
    commands := []
    ignored := []
    section := ""
    mapName := ""
    width := 1920
    height := 1009
    requestedUpgrades := 0
    actionCount := 0
    lineNo := 0

    loop read, path {
        lineNo++
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

        if (section != "steps")
            continue

        line := Trim(RegExReplace(line, "\s*;.*$", ""))
        if (line = "")
            continue

        if RegExMatch(line,
            "i)^SpawnTower\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(\d+)\s*,\s*([^\)]+)\)\s*$", &m) {
            rawId := SLE_UnquoteReplayId(m[4])
            command := {
                type: "spawn",
                lineNo: lineNo,
                raw: line,
                x: Round(Number(m[1])),
                y: Round(Number(m[2])),
                slot: Integer(m[3]),
                id: rawId,
                placementIndex: steps.Length + 1
            }
            steps.Push(command)
            commands.Push(command)
            continue
        }

        if RegExMatch(line,
            "i)^UpgradeTower\(\s*([^,\)]+?)\s*(?:,\s*(false|true)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?(?:,\s*(\d+)\s*)?\)$", &m) {
            amount := (m[3] != "") ? Max(1, Min(20, Integer(m[3]))) : 1
            pathNum := (m[4] != "") ? Integer(m[4]) : 0
            pathLevel := (m[5] != "") ? Integer(m[5]) : 0
            commands.Push({ type: "upgrade", lineNo: lineNo, raw: line, id: SLE_UnquoteReplayId(m[1]), amount: amount,
                path: pathNum, pathLevel: pathLevel })
            requestedUpgrades += amount
            continue
        }

        if RegExMatch(line, "i)^Sleep\(\s*(\d+)\s*\)$", &m) {
            commands.Push({ type: "sleep", lineNo: lineNo, raw: line, ms: Max(0, Integer(m[1])) })
            continue
        }

        if RegExMatch(line,
            "i)^EnforcerReposition\(\s*([^,]+?)\s*,\s*([^,]+?)\s*,\s*(-?\d+)\s*,\s*(-?\d+)\s*\)$", &m) {
            commands.Push({ type: "enforcer_reposition", lineNo: lineNo, raw: line, sourceId: SLE_UnquoteReplayId(m[1]),
                targetId: SLE_UnquoteReplayId(m[2]), x: Integer(m[3]), y: Integer(m[4]) })
            actionCount++
            continue
        }

        if RegExMatch(line, "i)^ActivateEnforcerVan\(\s*(\d*)\s*\)$", &m) {
            waitMs := (m[1] != "") ? Max(0, Integer(m[1])) : 0
            commands.Push({ type: "activate_enforcer_van", lineNo: lineNo, raw: line, waitMs: waitMs })
            actionCount++
            continue
        }

        ignored.Push({ lineNo: lineNo, text: line })
    }

    return { requiredTowers: required, steps: steps, commands: commands, ignored: ignored, width: width, height: height,
        mapName: mapName, requestedUpgrades: requestedUpgrades, actionCount: actionCount }
}

SLE_UnquoteReplayId(value) {
    rawId := Trim(String(value))
    if (StrLen(rawId) >= 2) {
        firstChar := SubStr(rawId, 1, 1)
        lastChar := SubStr(rawId, -1)
        if ((firstChar = Chr(34) && lastChar = Chr(34)) || (firstChar = Chr(39) && lastChar = Chr(39)))
            rawId := SubStr(rawId, 2, StrLen(rawId) - 2)
    }
    return Trim(rawId)
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
    upgradeBottomKey := "Z"
    repoKey := "L"
    enforcerVanKey := "N"

    if FileExist(settingsPath) {
        try useNumbers := (String(IniRead(settingsPath, "Options", "UseNumbers", "1")) != "0")
        try cancelKey := Trim(String(IniRead(settingsPath, "Hotkeys", "CancelPlacement", "Q")))
        try potatoMode := Integer(IniRead(settingsPath, "Options", "PotatoMode", "0"))
        try mouseSpeed := Integer(IniRead(settingsPath, "Options", "DefaultMouseSpeed", "2"))
        try mouseDelay := Integer(IniRead(settingsPath, "Options", "MouseDelay", "10"))
        try keyDelay := Integer(IniRead(settingsPath, "Options", "KeyDelay", "20"))
        try upgradeKey := Trim(String(IniRead(settingsPath, "Hotkeys", "UpgradeTower", "E")))
        try upgradeBottomKey := Trim(String(IniRead(settingsPath, "Hotkeys", "UpgradeBottom", "Z")))
        try repoKey := Trim(String(IniRead(settingsPath, "Hotkeys", "Repo", "L")))
        try enforcerVanKey := Trim(String(IniRead(settingsPath, "Hotkeys", "EnforcerVan", "N")))
    }

    if (cancelKey = "")
        cancelKey := "Q"
    mouseSpeed := Max(0, Min(100, mouseSpeed))
    mouseDelay := Max(-1, Min(1000, mouseDelay))
    keyDelay := Max(-1, Min(1000, keyDelay))
    if (upgradeKey = "")
        upgradeKey := "E"
    if (upgradeBottomKey = "")
        upgradeBottomKey := "Z"
    if (repoKey = "")
        repoKey := "L"
    if (enforcerVanKey = "")
        enforcerVanKey := "N"
    return { useNumbers: useNumbers, cancelKey: cancelKey, upgradeKey: upgradeKey, potatoMode: potatoMode, mouseSpeed: mouseSpeed,
        mouseDelay: mouseDelay, keyDelay: keyDelay, upgradeBottomKey: upgradeBottomKey, repoKey: repoKey,
        enforcerVanKey: enforcerVanKey }
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

SLE_ResolveReplayPathLevel(command, tower, replay) {
    if (command.pathLevel > 0)
        return command.pathLevel

    if RegExMatch(command.id, "i)^(Juggernaut|Pursuit|Kingpin)\d*$")
        return 4
    if RegExMatch(command.id, "i)^(Hacker|Enforcer|EvolvedEnforcer)\d*$")
        return 5

    if (tower.slot >= 1 && tower.slot <= replay.requiredTowers.Length) {
        towerName := Trim(replay.requiredTowers[tower.slot])
        if RegExMatch(towerName, "i)^(Juggernaut|Pursuit|Kingpin)$")
            return 4
        if RegExMatch(towerName, "i)^(Hacker|Enforcer|Evolved ?Enforcer)$")
            return 5
    }
    return 0
}

SLE_ExecuteUpgradeCommand(root, hwnd, command, towers, replay, runtime, logPath, statusPath) {
    if !towers.Has(command.id) {
        SLE_Log(logPath, "UPGRADE_FAILED line=" command.lineNo " id=" command.id " reason=tower_not_placed")
        return { ok: false, done: 0, reason: "tower_not_placed" }
    }
    if (command.path < 0 || command.path > 2) {
        SLE_Log(logPath, "UPGRADE_FAILED line=" command.lineNo " id=" command.id " reason=invalid_path")
        return { ok: false, done: 0, reason: "invalid_path" }
    }

    tower := towers[command.id]
    branchLevel := SLE_ResolveReplayPathLevel(command, tower, replay)
    done := 0
    IniWrite("upgrading", statusPath, "Steps", "Status" tower.placementIndex)
    SLE_Log(logPath, "UPGRADE_BEGIN line=" command.lineNo " id=" command.id " amount=" command.amount " path=" command.path
        " pathLevel=" branchLevel " currentLevel=" tower.level)

    ; Open once for the whole grouped UpgradeTower command. Re-clicking the tower
    ; before every level can toggle/rebuild the TDS panel and was the reason the
    ; QA replay frequently stopped around level 2 even with unlimited Sandbox cash.
    if !SLE_OpenReplayTowerPanel(root, hwnd, tower.x, tower.y) {
        IniWrite("upgrade_failed", statusPath, "Steps", "Status" tower.placementIndex)
        SLE_Log(logPath, "UPGRADE_FAILED line=" command.lineNo " id=" command.id " reason=tower_panel_not_found")
        return { ok: false, done: 0, reason: "tower_panel_not_found" }
    }

    loop command.amount {
        nextLevel := tower.level + 1
        bottomPath := (command.path = 2 && branchLevel > 0 && nextLevel >= branchLevel)
        result := SLE_BuyOneUpgrade(root, hwnd, bottomPath, runtime, logPath, command.id, nextLevel)
        if !result.ok {
            IniWrite("upgrade_failed", statusPath, "Steps", "Status" tower.placementIndex)
            SLE_Log(logPath, "UPGRADE_FAILED line=" command.lineNo " id=" command.id " nextLevel=" nextLevel " path="
                command.path " pathLevel=" branchLevel " completed=" done "/" command.amount " reason=" result.reason)
            SLE_CloseTowerPanelIfOpen(root, hwnd)
            return { ok: false, done: done, reason: result.reason }
        }

        tower.level := nextLevel
        if ((command.path = 1 || command.path = 2) && branchLevel > 0 && tower.level >= branchLevel) {
            tower.path := command.path
            tower.pathLevel := branchLevel
        }
        towers[command.id] := tower
        done++
        SLE_Log(logPath, "UPGRADE_CONFIRMED line=" command.lineNo " id=" command.id " level=" tower.level " path=" tower.path
            " progress=" done "/" command.amount)
        Sleep(180)
    }

    IniWrite("upgraded", statusPath, "Steps", "Status" tower.placementIndex)
    SLE_CloseTowerPanelIfOpen(root, hwnd)
    return { ok: true, done: done, reason: "" }
}

SLE_OpenReplayTowerPanel(root, hwnd, x, y) {
    if SLE_TowerPanelVisible(root, hwnd)
        return true

    loop 4 {
        Click(x, y)
        Sleep(180)
        if SLE_WaitForTowerConfirmation(root, hwnd, 1200)
            return true
        Sleep(180)
    }
    return false
}

SLE_FindUpgradePoint(root, hwnd, bottomPath := false) {
    WinGetClientPos(, , &w, &h, "ahk_id " hwnd)
    variant2 := root "\Resources\TowerUI\Variant2.png"
    variant1 := root "\Resources\TowerUI\Variant1.png"

    if FileExist(variant2) && ImageSearch(&menuX, &menuY, 0, Round(h / 2.5), Round(w * 0.25), Round(h * 0.95),
        "*50 " variant2) {
        pointX := menuX + Round(50 * w / 1920)
        pointY := menuY - Round((bottomPath ? 120 : 220) * h / 1009)
        return { ok: true, x: pointX, y: pointY, w: w, h: h, variant: 2 }
    }

    if FileExist(variant1) && ImageSearch(&menuX, &menuY, Round(w * 0.16), Round(h * 0.05), Round(w * 0.36),
        Round(h * 0.35), "*50 " variant1) {
        pointX := menuX - Round(164 * w / 1920)
        pointY := menuY + Round((bottomPath ? 483 : 383) * h / 1009)
        return { ok: true, x: pointX, y: pointY, w: w, h: h, variant: 1 }
    }

    return { ok: false, x: 0, y: 0, w: w, h: h, variant: 0 }
}

SLE_PixelLooksUpgradeGreen(color) {
    r := (color >> 16) & 0xFF
    g := (color >> 8) & 0xFF
    b := color & 0xFF
    return (g >= 55 && g >= r + 18 && g >= b + 8)
}

SLE_UpgradeGreenCoverage(centerX, centerY, clientWidth, clientHeight) {
    halfW := Max(24, Round(42 * clientWidth / 1920))
    halfH := Max(18, Round(28 * clientHeight / 1009))
    left := Max(0, centerX - halfW)
    top := Max(0, centerY - halfH)
    width := halfW * 2
    height := halfH * 2
    xSamples := [0.12, 0.31, 0.50, 0.69, 0.88]
    ySamples := [0.22, 0.50, 0.78]
    green := 0

    for yRatio in ySamples {
        for xRatio in xSamples {
            px := Round(left + width * xRatio)
            py := Round(top + height * yRatio)
            try color := PixelGetColor(px, py, "RGB")
            catch
                continue
            if SLE_PixelLooksUpgradeGreen(color)
                green++
        }
    }
    return green
}

SLE_WaitForUpgradeAffordance(point, timeoutMs := 2500) {
    deadline := A_TickCount + timeoutMs
    stable := 0
    while (A_TickCount < deadline) {
        if (SLE_UpgradeGreenCoverage(point.x, point.y, point.w, point.h) >= 3) {
            stable++
            if (stable >= 2)
                return true
        } else {
            stable := 0
        }
        Sleep(90)
    }
    return false
}

SLE_CaptureUpgradeEvidence(centerX, centerY, clientWidth, clientHeight) {
    halfW := Max(70, Round(145 * clientWidth / 1920))
    halfH := Max(35, Round(55 * clientHeight / 1009))
    left := Max(0, centerX - halfW)
    top := Max(0, centerY - halfH)
    width := halfW * 2
    height := halfH * 2
    xSamples := [0.06, 0.18, 0.30, 0.42, 0.54, 0.66, 0.78, 0.90]
    ySamples := [0.18, 0.50, 0.82]
    evidence := ""

    for yRatio in ySamples {
        for xRatio in xSamples {
            try {
                color := PixelGetColor(Round(left + width * xRatio), Round(top + height * yRatio), "RGB")
                evidence .= (color & 0xF8F8F8) "|"
            } catch {
                return ""
            }
        }
    }
    return evidence
}

SLE_UpgradeEvidenceDelta(beforeEvidence, afterEvidence) {
    if (beforeEvidence = "" || afterEvidence = "")
        return 0
    beforeParts := StrSplit(beforeEvidence, "|")
    afterParts := StrSplit(afterEvidence, "|")
    limit := Min(beforeParts.Length, afterParts.Length)
    changed := 0
    loop limit {
        if (beforeParts[A_Index] != afterParts[A_Index])
            changed++
    }
    return changed
}

SLE_WaitForUpgradeEvidenceChange(point, beforeEvidence, timeoutMs := 1800) {
    deadline := A_TickCount + timeoutMs
    changedFrames := 0
    while (A_TickCount < deadline) {
        afterEvidence := SLE_CaptureUpgradeEvidence(point.x, point.y, point.w, point.h)
        if (SLE_UpgradeEvidenceDelta(beforeEvidence, afterEvidence) >= 3) {
            changedFrames++
            if (changedFrames >= 2)
                return true
        } else {
            changedFrames := 0
        }
        Sleep(100)
    }
    return false
}

SLE_BuyOneUpgrade(root, hwnd, bottomPath, runtime, logPath, towerId, nextLevel) {
    if !SLE_TowerPanelVisible(root, hwnd)
        return { ok: false, reason: "tower_panel_closed" }

    point := SLE_FindUpgradePoint(root, hwnd, bottomPath)
    if !point.ok
        return { ok: false, reason: "upgrade_button_not_found" }

    if !SLE_WaitForUpgradeAffordance(point, 2500)
        return { ok: false, reason: "upgrade_not_affordable" }

    beforeEvidence := SLE_CaptureUpgradeEvidence(point.x, point.y, point.w, point.h)
    Click(point.x, point.y)
    Sleep(Max(220, runtime.potatoMode = 1 ? 350 : 220))

    if !SLE_WaitForUpgradeEvidenceChange(point, beforeEvidence, 1800) {
        ; Never click again after an ambiguous input: if the first purchase succeeded,
        ; a retry could buy the following level and desync the replay state.
        SLE_Log(logPath, "UPGRADE_AMBIGUOUS id=" towerId " nextLevel=" nextLevel " reason=no_persistent_visual_delta")
        return { ok: false, reason: "upgrade_" nextLevel "_not_confirmed" }
    }

    ; The TDS panel can animate/re-anchor after buying a level. Give it a short
    ; chance to settle, but do not require exact pixel equality.
    SLE_WaitForTowerConfirmation(root, hwnd, 900)
    return { ok: true, reason: "" }
}

SLE_ExecuteEnforcerReposition(root, hwnd, command, towers, replay, runtime, logPath) {
    if !towers.Has(command.sourceId) || !towers.Has(command.targetId) {
        SLE_Log(logPath, "ENFORCER_REPOSITION_FAILED line=" command.lineNo " reason=tower_not_placed source=" command.sourceId
            " target=" command.targetId)
        return { ok: false, reason: "source_or_target_not_placed" }
    }

    source := towers[command.sourceId]
    target := towers[command.targetId]
    if !SLE_IsReplayEnforcer(source, replay) || source.path != 1 || source.level < 5 {
        SLE_Log(logPath, "ENFORCER_REPOSITION_FAILED line=" command.lineNo " reason=source_not_top_path_level_5 source="
            command.sourceId " level=" source.level " path=" source.path)
        return { ok: false, reason: "source_not_top_path_level_5" }
    }

    destinationX := SLE_ScaleReplayX(command.x, replay.width, replay.height, hwnd)
    destinationY := SLE_ScaleReplayY(command.y, replay.width, replay.height, hwnd)
    WinActivate("ahk_id " hwnd)
    if !WinWaitActive("ahk_id " hwnd, , 2.0)
        return { ok: false, reason: "roblox_not_active" }

    SendEvent("{" runtime.cancelKey "}")
    Sleep(100)
    SLE_CloseTowerPanelIfOpen(root, hwnd)
    Click(source.x, source.y)
    if !SLE_WaitForTowerConfirmation(root, hwnd, 1800) {
        SLE_Log(logPath, "ENFORCER_REPOSITION_FAILED line=" command.lineNo " reason=source_panel_not_found")
        return { ok: false, reason: "source_panel_not_found" }
    }

    SendEvent("{" runtime.repoKey "}")
    Sleep(450)
    Click(target.x, target.y)
    Sleep(450)
    Click(destinationX, destinationY)
    Sleep(900)
    if SLE_IsPlacementExplicitlyRejected(root, hwnd) {
        SLE_Log(logPath, "ENFORCER_REPOSITION_FAILED line=" command.lineNo " reason=destination_rejected destination="
            destinationX "," destinationY)
        return { ok: false, reason: "destination_rejected" }
    }

    SLE_CloseTowerPanelIfOpen(root, hwnd)
    Click(destinationX, destinationY)
    confirmed := SLE_WaitForTowerConfirmation(root, hwnd, 1800)
    SLE_CloseTowerPanelIfOpen(root, hwnd)
    if !confirmed {
        SLE_Log(logPath, "ENFORCER_REPOSITION_FAILED line=" command.lineNo " reason=destination_not_confirmed destination="
            destinationX "," destinationY)
        return { ok: false, reason: "destination_not_confirmed" }
    }

    target.x := destinationX
    target.y := destinationY
    towers[command.targetId] := target
    SLE_Log(logPath, "ENFORCER_REPOSITIONED line=" command.lineNo " source=" command.sourceId " target=" command.targetId
        " destination=" destinationX "," destinationY)
    return { ok: true, reason: "" }
}

SLE_IsReplayEnforcer(tower, replay) {
    if RegExMatch(tower.id, "i)^(Enforcer|EvolvedEnforcer)\d*$")
        return true
    if (tower.slot >= 1 && tower.slot <= replay.requiredTowers.Length)
        return RegExMatch(Trim(replay.requiredTowers[tower.slot]), "i)^(Enforcer|Evolved ?Enforcer)$")
    return false
}

SLE_ExecuteEnforcerVan(root, hwnd, command, towers, replay, runtime, logPath) {
    sourceId := ""
    for towerId, tower in towers {
        if (SLE_IsReplayEnforcer(tower, replay) && tower.path = 2 && tower.level >= 5) {
            sourceId := towerId
            break
        }
    }
    if (sourceId = "") {
        SLE_Log(logPath, "ENFORCER_VAN_FAILED line=" command.lineNo " reason=no_bottom_path_level_5")
        return { ok: false, reason: "no_bottom_path_level_5" }
    }

    if (command.waitMs > 0)
        Sleep(command.waitMs)
    WinActivate("ahk_id " hwnd)
    if !WinWaitActive("ahk_id " hwnd, , 2.0)
        return { ok: false, reason: "roblox_not_active" }

    SendEvent("{" runtime.cancelKey "}")
    Sleep(50)
    SLE_CloseTowerPanelIfOpen(root, hwnd)
    WinGetClientPos(, , &w, &h, "ahk_id " hwnd)
    Click(Round(150 * (w / 1920.0)), Round(200 * (h / 1009.0)))
    Sleep(250)
    SendEvent("{" runtime.enforcerVanKey "}")
    Sleep(400)
    SLE_Log(logPath, "ENFORCER_VAN_SENT line=" command.lineNo " source=" sourceId " waitMs=" command.waitMs " key="
        runtime.enforcerVanKey)
    return { ok: true, reason: "" }
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

SLE_RunParserContractSelfTest() {
    fixturePath := A_Temp "\strategy-lab-replay-contract-" A_TickCount ".strat"
    fixture := "[Settings]`n"
        . "map=Dead Ahead`n"
        . "requiredTowers=Enforcer, Juggernaut`n`n"
        . "[DO NOT EDIT]`n"
        . "width=1920`n"
        . "height=1080`n`n"
        . "[Steps]`n"
        . "SpawnTower(1047, 320, 1, EnfTop)`n"
        . "SpawnTower(1092, 541, 2, Jug1)`n"
        . "SpawnTower(1156, 347, 1, EnfBottom)`n"
        . "UpgradeTower(EnfTop, false, 5, 1, 5)`n"
        . "UpgradeTower(EnfBottom, false, 5, 2, 5)`n"
        . "Sleep(1000)`n"
        . "EnforcerReposition(EnfTop, Jug1, 1211, 537)`n"
        . "Sleep(1200)`n"
        . "ActivateEnforcerVan(891)`n"
    try {
        FileAppend(fixture, fixturePath, "UTF-8")
        replay := SLE_ParseReplay(fixturePath)
        if (replay.steps.Length != 3)
            throw Error("expected 3 placements, got " replay.steps.Length)
        if (replay.commands.Length != 9)
            throw Error("expected 9 ordered commands, got " replay.commands.Length)
        if (replay.requestedUpgrades != 10)
            throw Error("expected 10 requested upgrades, got " replay.requestedUpgrades)
        if (replay.actionCount != 2)
            throw Error("expected 2 Enforcer actions, got " replay.actionCount)
        if (replay.ignored.Length != 0)
            throw Error("expected no ignored commands, got " replay.ignored.Length)
        if (replay.commands[4].type != "upgrade" || replay.commands[4].amount != 5 || replay.commands[4].path != 1
            || replay.commands[4].pathLevel != 5)
            throw Error("top-path grouped upgrade contract was not preserved")
        if (replay.commands[5].type != "upgrade" || replay.commands[5].amount != 5 || replay.commands[5].path != 2
            || replay.commands[5].pathLevel != 5)
            throw Error("bottom-path grouped upgrade contract was not preserved")
        if (replay.commands[7].type != "enforcer_reposition" || replay.commands[7].sourceId != "EnfTop"
            || replay.commands[7].targetId != "Jug1" || replay.commands[7].x != 1211 || replay.commands[7].y != 537)
            throw Error("Enforcer reposition contract was not preserved")
        if (replay.commands[9].type != "activate_enforcer_van" || replay.commands[9].waitMs != 891)
            throw Error("Enforcer Van wait contract was not preserved")
    } finally {
        try FileDelete(fixturePath)
    }
}

SLE_Log(path, text) {
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " " text "`n", path, "UTF-8")
}
