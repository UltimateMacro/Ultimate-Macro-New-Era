#!/usr/bin/env python3
"""Source contracts for the reported-runtime QA hotfix."""
from __future__ import annotations

import hashlib
import re
import subprocess
import sys
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    require(path.is_file(), f"missing source file: {path}")
    return path.read_text(encoding="utf-8-sig")


def region(source: str, start: str, end: str) -> str:
    start_index = source.find(start)
    require(start_index >= 0, f"missing region start: {start}")
    end_index = source.find(end, start_index + len(start))
    require(end_index > start_index, f"missing region end after {start}: {end}")
    return source[start_index:end_index]


def validate_image_fallback(main: str, image_search: str) -> None:
    fallback = region(image_search, "; GDI+ fallback.", "\nBuildImageSearchScaleCandidates(")
    candidates = region(
        image_search,
        "BuildImageSearchScaleCandidates(baseScale, minScale, maxScale, scaleStep) {",
        "\nAddImageSearchScaleCandidate(scales, value) {",
    )

    require("GetRobloxScreenClientRect" in image_search, "capture must resolve the screen-space client rect")
    require(
        'pBitmapHaystack := Gdip_BitmapFromScreen(screenX "|" screenY "|" widthC "|" heightC)'
        in fallback,
        "GDI+ capture must use SCREEN coordinates",
    )
    require("Gdip_ResizeBitmap(pBitmapTemplate, scaledW, scaledH, 7)" in fallback, "fallback must resize templates")
    require("for candidateScale in scaleCandidates" in fallback, "fallback must test multiple fractional scales")
    require("Gdip_DisposeImage(pCandidate)" in fallback, "temporary scaled bitmaps must be disposed")
    require('degraded: true' in fallback and 'scoreKind: "binary"' in fallback,
            "fallback results must disclose binary/degraded scoring")
    require("maxCandidates := 12" in candidates and "maxOffsetSteps := 10" in candidates,
            "fallback scale enumeration needs a practically small candidate/offset budget")
    require("scales.Length >= maxCandidates - 1" in candidates,
            "fallback must stop nearby enumeration before exhausting a broad caller range")
    require("AddImageSearchScaleCandidate(scales, minScale)" not in candidates and
            "AddImageSearchScaleCandidate(scales, maxScale)" not in candidates,
            "fallback must not force expensive far-range endpoint searches")
    require("offset += scaleStep" in candidates, "scale candidates must retain the fractional step")
    require("Round(baseScale)" not in image_search and "Round(candidateScale)" not in image_search,
            "fractional scale factors must not collapse to integers")
    require("x: centerX" in fallback and "y: centerY" in fallback,
            "fallback matches must remain Roblox CLIENT-relative")
    for forbidden in ("screenX + centerX", "screenY + centerY", "xC + centerX", "yC + centerY"):
        require(forbidden not in fallback, f"fallback must not add a screen origin to CLIENT results: {forbidden}")

    startup = region(main, "ImageBackend := GetImageSearchBackendInfo()", "A_MaxHotkeysPerInterval")
    require("image_backend_fallback" in startup and "RuntimeLogWarn" in startup,
            "the optional fallback must be visible in diagnostics")
    require("MsgBox(" not in startup, "missing optional OpenCV must not block startup")


def validate_equip_and_resolution(main: str) -> None:
    equip = region(main, "EquipTowers(towers) {", "CheckRestart() {")
    scale = region(main, "GetClientTemplateScale(clientHeight) {", "Join(arr, delim :=")
    execute = region(main, "ExecuteStep(step) {", "LowerGraphics() {")
    spawn = region(main, "SpawnTower(X, Y, slotNumber, towerID) {", "SellTower(towerID) {")

    require("return Float(clientHeight) / 1009.0" in scale, "client template scale must be fractional")
    expected_scales = {1080: 1080 / 1009.0, 768: 768 / 1009.0, 720: 720 / 1009.0}
    require(0.70 < expected_scales[720] < expected_scales[768] < 0.77,
            "720p/768p scale regression calculation is invalid")
    require('Round(rw * 0.5), Round(rh * 0.5)' in equip,
            "Auto Equip search width must derive from Roblox width and height from height")
    require('Round(rh * 0.5), Round(rh * 0.5)' not in equip,
            "Auto Equip must not reuse height for search width")
    require("towerEquipped := false" in equip and "autoequip_tower_timeout" in equip,
            "each requested tower needs bounded confirmation")
    require('Send("^a")' in equip and 'Send("{Backspace}")' in equip,
            "Auto Equip must replace, not append to, the prior search")

    require("SpawnTower(m[1], m[2], m[3], Trim(m[4]))" in execute,
            "SpawnTower must receive recorded coordinates for its single normalization point")
    require(spawn.count("X := sX(X, StrategyWidth)") == 1 and
            spawn.count("Y := sY(Y, StrategyHeight)") == 1,
            "SpawnTower must normalize exactly once from strategy dimensions")
    require('Click(sX(m[1], StrategyWidth) " " sY(m[2], StrategyHeight) " " button)' in execute,
            "recorded Click must normalize from strategy dimensions")
    require("CloneTower(Trim(m[1]), sX(Integer(m[2]), StrategyWidth), sY(Integer(m[3]), StrategyHeight)" in execute,
            "CloneTower destination must normalize from strategy dimensions")
    require("BrawlerReposition(Trim(m[1]), sX(Integer(m[2]), StrategyWidth), sY(Integer(m[3]), StrategyHeight))" in execute,
            "Brawler destination must normalize from strategy dimensions")

    clone = region(main, "CloneTower(towerId, x, y, wait := 0) {", "BrawlerReposition(towerId, x, y) {")
    brawler = region(main, "BrawlerReposition(towerId, x, y) {", "ActivateRaiseTheDead(wait := 0) {")
    for name, body in (("CloneTower", clone), ("BrawlerReposition", brawler)):
        require(not re.search(r"(?:sX|ScaleX)\(x(?:\s*[,)]|\s*$)", body, re.MULTILINE),
                f"{name} must not scale its already-normalized x coordinate again")
        require(not re.search(r"(?:sY|ScaleY)\(y(?:\s*[,)]|\s*$)", body, re.MULTILINE),
                f"{name} must not scale its already-normalized y coordinate again")

    load = region(main, "LoadStrategyFile(file) {", "RunStrategy(stratFile :=")
    require('IniRead(file, "DO NOT EDIT", "width", "1920")' in load, "old strategies need a width default")
    require('IniRead(file, "DO NOT EDIT", "height", "1080")' in load, "old strategies need a height default")

    start_recording = region(main, "StartRecording(ctrl, *) {", "StopRecord(ctrl, *) {")
    stop_recording = region(main, "StopRecord(ctrl, *) {", "PlaceTowerHK(*) {")
    require("&RecordingWidth, &RecordingHeight" in start_recording and "recording_geometry_required" in start_recording,
            "recording must capture valid client geometry before state changes")
    require("strategyWidthToSave := RecordingWidth" in stop_recording,
            "saved strategy width must be the recording-start width")
    require("strategyHeightToSave := RecordingHeight" in stop_recording,
            "saved strategy height must be the recording-start height")
    require('`nwidth=" currentWidth' not in stop_recording and '`nheight=" currentHeight' not in stop_recording,
            "save-time geometry must not replace the recording coordinate plane")
    require("GetDpiForWindow" in start_recording and "100% recommended" in start_recording,
            "recording must warn when window DPI is non-recommended")


def validate_hotbar_mouse_selection(main: str) -> None:
    helper = region(main, "SelectHotbarSlotByClick(slotNumber) {", "ScaleX(baseX, Width :=")
    recording = region(main, "PlaceTowerHK(*) {", "UpgradeTowerHK(*) {")
    spawn = region(main, "SpawnTower(X, Y, slotNumber, towerID) {", "SellTower(towerID) {")

    require("global Slots :=" not in main and "Click(Slots[" not in main,
            "hotbar clicks must not use startup-cached slot coordinates")
    require("static baseXBySlot := [800, 880, 960, 1040, 1120]" in helper,
            "the shared helper must retain the canonical five-slot x positions")
    require("getRobloxPos(, , &clientWidth, &clientHeight)" in helper,
            "hotbar selection must snapshot current Roblox client dimensions")
    require("clientWidth <= 0 || clientHeight <= 0" in helper,
            "invalid client geometry must be rejected before clicking")
    require("baseXBySlot[slot] * (clientWidth / 1920.0)" in helper and
            "960 * (clientHeight / 1009.0)" in helper,
            "hotbar positions must scale from the established 1920x1009 client plane")
    require('RuntimeLogInfo("hotbar_slot_resolved"' in helper,
            "successful mouse slot resolution must emit runtime diagnostics")
    for field in ('"slot=" slot', '"; x=" slotX', '"; y=" slotY',
                  '"; client_width=" clientWidth', '"; client_height=" clientHeight'):
        require(field in helper, f"hotbar diagnostics are missing: {field}")
    require("Click(slotX, slotY)" in helper,
            "hotbar selection must pass explicit numeric x/y Click arguments")
    require("ScaleX(" not in helper and "ScaleY(" not in helper,
            "one client snapshot must drive both hotbar coordinates")

    require(recording.count("SelectHotbarSlotByClick(slot)") == 1,
            "recording must use the shared dynamic mouse slot helper")
    require(spawn.count("SelectHotbarSlotByClick(slotNumber)") == 1,
            "SpawnTower must use the shared dynamic mouse slot helper")
    require('Send("{" slot "}")' in recording and 'Send("{" slotNumber "}")' in spawn,
            "the passing Numbers ON keyboard paths must remain intact")
    require(spawn.find("loop {") < spawn.find("SelectHotbarSlotByClick(slotNumber)"),
            "each placement retry must resolve fresh client dimensions")

    def resolve(slot: int, width: int, height: int) -> tuple[int, int]:
        return round([800, 880, 960, 1040, 1120][slot - 1] * width / 1920), round(960 * height / 1009)

    require(resolve(1, 1920, 1009) == (800, 960), "canonical slot scaling changed")
    require(resolve(5, 1280, 720) == (747, 685), "cross-resolution slot scaling changed")


def validate_matchmaking_ready_map(main: str, validator: str) -> None:
    join = region(main, "JoinGame() {", "CreateParty(x, y) {")
    difficulty = region(main, "TryClickDifficultyTarget(target, w, h) {", "WaitForLobbyLoad() {")
    map_check = region(main, "CheckTheMapF() {", "ApplyModifiers() {")
    ready_find = region(main, "FindReadyButton(&foundX, &foundY) {", "ClickReady() {")
    ready_click = region(main, "ClickReady() {", "waitReady() {")

    require(join.count("difficultyDeadline := difficultyStart + 60000") == 1,
            "Easy/mode selection needs one absolute deadline")
    require("A_TickCount >= difficultyDeadline" in join, "mode selection must enforce its absolute deadline")
    deadline_index = join.find("difficultyDeadline := difficultyStart + 60000")
    loop_index = join.find("loop {", deadline_index)
    require(0 <= deadline_index < loop_index, "the mode deadline must be initialized outside the retry loop")
    require("difficultyDeadline :=" not in join[loop_index:], "Play recovery must never reset the mode deadline")
    require("difficulty_play_recovery" in join and "modeScrollAttempts < 12" in join,
            "mode selection needs bounded Play/scroll recovery")
    require("firstModeScrollAt := difficultyStart + 1500" in join and
            "A_TickCount >= firstModeScrollAt" in join,
            "the first mode scroll needs a settling grace so Easy stays visible")
    require("TryClickDifficultyTarget(difficulty, w, h)" in join, "Easy and Frost must share reliable targeting")

    require("AdvancedImageSearch(imagePath" in difficulty and "OCR.FromRect(" in difficulty,
            "Frost/standard targeting needs template matching plus bounded OCR fallback")
    require("GetRobloxScreenClientRect" in difficulty and "match.Click()" in difficulty,
            "difficulty OCR must capture/click in SCREEN space")
    require('"Resources/Frost.png"' in validator, "Frost runtime image must remain required")

    require("mapDeadline := A_TickCount + 12000" in map_check and "mapSamples < 16" in map_check,
            "map detection needs both time and sample bounds")
    require("mapSamples = 4 || mapSamples = 9" in map_check and "AlignCamera(" in map_check,
            "map detection must realign after transient misses")
    require("map_detection_failed" in map_check and "SafeReload()" in map_check,
            "map detection must log and fail safely after its real deadline")

    require("AdvancedImageSearch" in ready_find, "Ready must prefer its template")
    require("PixelSearch" not in ready_find, "Ready must never click generic green pixels")
    require("rx := Round(w * 0.4)" in ready_find and "rw := Round(w * 0.3)" in ready_find,
            "Ready search must remain inside its expected client region")
    require("readyDeadline := A_TickCount + 8000" in ready_click and "attempts < 6" in ready_click,
            "Ready retry must be bounded by time and count")
    require("disappearedSamples >= 2" in ready_click and "ready_click_confirmed" in ready_click,
            "Ready success needs consecutive post-click disappearance evidence")
    require("ready_click_timeout" in ready_click and "SafeReload()" in ready_click,
            "unconfirmed Ready must fail safely")


def validate_paths(main: str) -> None:
    resolver = region(main, "KnownPathBranchLevel(towerID) {", "ShowTowerPathDialog(towerID) {")
    recorder = region(main, "DetectUpgrade(*) {", "ScaleX(baseX, Width :=")
    replay = region(main, "UpgradeTower(towerID, skipOpen :=", "isDisconnected() {")
    select_path = region(main, "SelectPath(pathGui, pathNum) {", "TestWebhook(ctrl, *) {")

    require('RegExMatch(towerID, "i)^(Juggernaut|Pursuit|Kingpin)\\d*$")' in resolver,
            "Juggernaut/Pursuit/Kingpin IDs must default to first branch level 4")
    require('RegExMatch(towerID, "i)^Hacker\\d*$")' in resolver,
            "Hacker IDs must default to first branch level 5")
    require("return 4" in resolver and "return 5" in resolver, "known path defaults are incomplete")
    require("suppliedLevel = knownLevel - 1" in resolver,
            "known legacy 3/4 recordings must translate to the new 4/5 semantic")
    require("return suppliedLevel" in resolver, "custom tower IDs must retain their supplied level")
    require("nextLevel >= effectivePathLevel" in resolver,
            "pathLevel must mean the first path-specific upgrade level")
    require("Towers[towerID].pathLevel := branchLevel" in select_path and "branchLevel - 1" not in select_path,
            "new recordings must store the first path-specific level directly")

    require(recorder.count("IsPathSpecificUpgrade(") == 1,
            "DetectUpgrade must have exactly one shared path decision")
    require(replay.count("IsPathSpecificUpgrade(") == 2,
            "UpgradeTower must share path semantics at region and hotkey decisions")
    require("nextLevel > pathLevel" not in recorder + replay,
            "all three relevant legacy nextLevel > pathLevel comparisons must be removed")

    def resolve_known(tower_id: str, supplied: int) -> int:
        if re.fullmatch(r"(?i)(Juggernaut|Pursuit|Kingpin)\d*", tower_id):
            known = 4
        elif re.fullmatch(r"(?i)Hacker\d*", tower_id):
            known = 5
        else:
            known = 0
        if known and supplied <= 0:
            return known
        if known and supplied == known - 1:
            return known
        return supplied

    require(resolve_known("Juggernaut1", 0) == 4, "Juggernaut default must be 4")
    require(resolve_known("Pursuit2", 0) == 4, "Pursuit default must be 4")
    require(resolve_known("Kingpin9", 3) == 4, "legacy Kingpin level 3 must map to 4")
    require(resolve_known("Hacker1", 4) == 5, "legacy Hacker level 4 must map to 5")
    require(resolve_known("BOSSKILLER", 3) == 3, "custom tower path metadata must not be overwritten")


def validate_dj_watchdog_and_pr30(main: str, watchdog: str) -> None:
    # The opening brace is intentional: searching for SetDJTrack(track) alone
    # can select a call and silently validate the wrong body.
    dj = region(main, "SetDJTrack(track) {", "UpdateTowerIndicator(towerID) {")
    play = region(main, "PlayStrategy() {", "ExecuteStep(step) {")
    execute = region(main, "ExecuteStep(step) {", "LowerGraphics() {")
    abilities_wrapper = region(main, "UseAbilities(*) {", "UseAbilitiesPass() {")
    abilities = region(main, "UseAbilitiesPass() {", "SetDJTrack(track) {")
    upgrade = region(main, "UpgradeTower(towerID, skipOpen :=", "isDisconnected() {")
    sell = region(main, "SellTower(towerID) {", "UpgradeTower(towerID, skipOpen :=")
    arcade = region(main, "TryClickArcadeTarget(target, w, h) {", "TryClickDifficultyTarget(target, w, h) {")
    process_missing = region(
        watchdog,
        "if (Mod(loopCounter, 5) == 0 && !ProcessExist(MainPID)) {",
        "\n    if (Mod(loopCounter, 15) == 0) {",
    )

    require("global canUseAbility, needtocheckTowerUI, PotatoMode" in dj, "DJ state must be global")
    require("deadline := A_TickCount + 25000" in dj and "dj_track_timeout" in dj,
            "DJ track switching must have a real deadline")
    require("towerUiTimeout := (PotatoMode = 1) ? 1800 : 1200" in dj,
            "DJ UI retry timing must honor PotatoMode")
    require("waitForTowerUI" in dj and "AdvancedImageSearch(trackImage" in dj,
            "DJ must reopen/detect the tower UI and retry track matching")
    require("please_wait.png" in dj and "ReadMessage([\"please\", \"wait\"])" in dj,
            "DJ cooldown must be detected before reporting success")
    track_click_index = dj.find("Click(DJTrack.x, DJTrack.y)")
    track_success_index = dj.find('RuntimeLogInfo("dj_track_changed"')
    require(0 <= track_click_index < track_success_index,
            "DJ success must follow an actual track click")
    require("finally" in dj and "canUseAbility := true" in dj and "MouseMove(originalMouseX, originalMouseY)" in dj,
            "DJ failure/success paths must restore state and mouse position")

    require('MacroPhase("playing_step", 900000)' in play, "watchdog must receive per-step progress")
    require('MacroPhase("waiting_result", 7200000)' in play,
            "healthy long gameplay/result waits must not inherit the old 40-minute phase")
    require('MacroPhase("strategy_sleep", Max(300000, strategySleepMs + 120000))' in execute,
            "intentional recorded sleeps need a duration-derived phase budget")
    require('MacroPhase("playing", 2400000)' not in main,
            "the old arbitrary 40-minute playing timeout must be removed")
    running_index = process_missing.find('IniRead(StateFile, "State", "Running", 0)')
    missing_log_index = process_missing.find('RuntimeLogError("main_process_missing"')
    restart_index = process_missing.find("RestartMain()")
    require(0 <= running_index < missing_log_index < restart_index,
            "process-missing recovery must read Running before logging/restarting Main")
    require("if (!runningAfterMainExit)" in process_missing and
            "ExitApp()" in process_missing[running_index:missing_log_index],
            "an intentional Main exit must stop this watchdog branch without restarting")
    require("stalledFor > hbTimeout" in watchdog and "roblox_process_missing" in watchdog,
            "watchdog must distinguish phase stalls from Roblox loss")

    require("callbackActive" in abilities_wrapper and "finally" in abilities_wrapper,
            "ability timer reentrancy/state must be released even after errors")
    caravan = region(abilities, 'if (autoCaravan = "ON"', 'if (autoDropTheBeat = "ON"')
    require(not re.search(r"(?m)^\s*return(?:\s|$)", caravan),
            "Support Caravan must not suppress Drop the Beat")
    require("Towers.Has(LastOpenedTowerID)" in abilities,
            "ability callbacks must guard stale tower IDs before indexing")
    require("upgradeDeadline" in upgrade and "fully_upgraded.png" in upgrade and "Sleep(" in upgrade,
            "maxed/unaffordable upgrade loops must remain bounded and yielding")
    require("HasProp(\"hwnd\")" in sell and "Towers.Delete(towerID)" in sell,
            "SellTower must guard optional indicators and remove tower state")
    require("AdvancedImageSearch(imagePath, cardX, cardY, cardW, cardH)" in arcade,
            "Arcade search bounds must pass width/height, not bottom-right coordinates")


def validate_watchdog_pid_lifecycle(main: str) -> None:
    start = region(main, "startWatchdog() {", "KillSubmacros() {")
    cleanup = region(main, "KillSubmacros() {", "HandleExit(ExitReason, ExitCode) {")
    handle_exit = region(main, "HandleExit(ExitReason, ExitCode) {", "CleanupGdip(exitReason, exitCode) {")

    require('global watchdogPID := ""' in main,
            "watchdog PID must retain an explicit startup initializer")
    require("newWatchdogPID := 0" in start and "&newWatchdogPID" in start,
            "watchdog launch must use an initialized local output PID")
    require("&watchdogPID" not in start,
            "Run must not mutate the shared watchdog PID directly")
    run_index = start.find("Run(command, , , &newWatchdogPID)")
    publish_index = start.find("watchdogPID := newWatchdogPID")
    require(0 <= run_index < publish_index,
            "the shared watchdog PID must be published only after Run succeeds")
    require('RuntimeLogInfo("watchdog_started"' in start,
            "successful watchdog launches must be diagnosable")
    require('watchdogPID := ""' in start and
            'RuntimeLogError("watchdog_start_failed"' in start and
            "return false" in start,
            "failed watchdog launches must restore a known idle state")

    require('if (IsSet(watchdogPID) && watchdogPID != "")' in cleanup,
            "cleanup must guard the shared PID before reading it")
    clear_index = cleanup.find('watchdogPID := ""')
    tracked_index = cleanup.find('if (trackedPID != "")')
    require(0 <= clear_index < tracked_index,
            "cleanup must publish the idle state before process operations")
    require('if (watchdogPID != "")' not in cleanup,
            "cleanup must not contain an unguarded shared PID read")
    require(r'A_ScriptDir "\submacros\watchdog.ahk"' in cleanup and
            "InStr(normalizedCmd, targetScript)" in cleanup,
            "fallback cleanup must remain scoped to this checkout's watchdog path")
    for event in ("watchdog_stopped", "watchdog_cleanup_failed", "watchdog_cleanup_scan_failed"):
        require(event in cleanup, f"cleanup diagnostic is missing: {event}")

    require("global StateFile, SettingsFile, RunningStrategy" in handle_exit,
            "OnExit must explicitly bind its running-state global")
    require("try KillSubmacros()" in handle_exit,
            "OnExit must attempt watchdog cleanup independently of strategy state")
    require("if (IsSet(RunningStrategy) && RunningStrategy)" in handle_exit,
            "OnExit must tolerate the startup initialization window")
    require("if (RunningStrategy)" not in handle_exit,
            "OnExit must not read an uninitialized running state")
    require("watchdog_exit_cleanup_failed" in handle_exit,
            "OnExit cleanup failures must be diagnosable")

    require("KillSubmacros()" in start,
            "watchdog launch must clean up a prior instance first")
    require("KillSubmacros()\n    startWatchdog()" in main,
            "the real repeated cleanup/start lifecycle must remain covered")


def validate_packaging(root: Path, validator: str, workflow: str) -> None:
    obsolete = {
        "Resources/Strats/2_Absolute_Zero.strat",
        "Resources/Strats/4_FrostModeStrat(Mods)(1.3 fix).strat",
        "Resources/Strats/FrostModeStrat(Mods)(1.3 fix).strat",
    }
    expected_remaining = {
        "Resources/Strats/1_NST_DEAD_AHEAD_EASY.strat",
        "Resources/Strats/3_JuggernautExp.strat",
        "Resources/Strats/JuggernautExp.strat",
        "Resources/Strats/SigmaMoltenSpeedrun(NoExplodingfastestTime).strat",
        "Resources/Strats/SUICIDE_MINIGUNNER_GEM_EXP_FARM.strat",
        "Resources/Strats/Z_Bread Toaster_DAMolten.strat",
    }
    required_dlls = {
        "lib/ImageSearch/opencv_world500.dll": (
            "7bc06231bf3cfd287e0b6853a78f78e00ceb58266f3cb49642f428ea6f4d1518"
        ),
        "lib/ImageSearch/vcruntime140.dll": (
            "d1f4225df2cd877dbf130d5668a021dce3f94118455ff5ec952061c30afc9ce7"
        ),
    }
    tracked_result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--", "Resources/Strats/*.strat"],
        check=True,
        capture_output=True,
        text=True,
    )
    tracked = {line.replace("\\", "/") for line in tracked_result.stdout.splitlines() if line}
    require(tracked == expected_remaining,
            f"tracked strategy set changed outside the three obsolete Frost removals: {sorted(tracked)}")
    for relative in obsolete:
        require(not (root / relative).exists(), f"obsolete bundled Frost strategy still exists: {relative}")
    for relative in expected_remaining:
        require((root / relative).is_file(), f"unrelated bundled strategy was removed: {relative}")

    tracked_dll_result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--", "lib/ImageSearch/*.dll"],
        check=True,
        capture_output=True,
        text=True,
    )
    tracked_dlls = {
        line.replace("\\", "/") for line in tracked_dll_result.stdout.splitlines() if line
    }
    for relative, expected_hash in required_dlls.items():
        dll_path = root / relative
        require(relative in tracked_dlls, f"required runtime DLL is not tracked: {relative}")
        require(dll_path.is_file(), f"required runtime DLL is missing: {relative}")
        actual_hash = hashlib.sha256(dll_path.read_bytes()).hexdigest()
        require(actual_hash == expected_hash,
                f"required runtime DLL hash changed: {relative} ({actual_hash})")
        require(f'"{relative.casefold()}": (' in validator,
                f"repository validator does not require: {relative}")
        require(expected_hash in validator,
                f"repository validator is missing the approved hash for: {relative}")
    require("python tests/test_reported_runtime_fixes.py ." in workflow,
            "CI must execute the reported-runtime contracts")


def validate_community_strategy_sync(main: str) -> None:
    community = region(main, "IsGitDevelopmentCheckout(rootDir) {", "global FrameX := 30")
    checkout_guard = region(main, "IsGitDevelopmentCheckout(rootDir) {", "LoadedStrats := []")

    require('FileExist(rootDir "\\.git")' in checkout_guard,
            "community sync must detect both .git directories and worktree files")
    require("DirExist(" not in checkout_guard,
            "a directory-only development guard would miss linked Git worktrees")
    guard = "needUpdate := !IsGitDevelopmentCheckout(A_ScriptDir)"
    require(guard in community, "release-only community sync guard is missing")
    require(community.find(guard) < community.find("if (needUpdate) {") <
            community.find("https://api.github.com/repos/UltimateMacro/Ultimate-Macro-New-Era"),
            "Git checkout detection must happen before any community request")


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    main_source = read(root / "Main.ahk")
    image_source = read(root / "lib/ImageSearch/ImageSearch.ahk")
    watchdog_source = read(root / "submacros/watchdog.ahk")
    validator = read(root / "tests/validate_repo.py")
    workflow = read(root / ".github/workflows/ci.yml")

    validate_image_fallback(main_source, image_source)
    validate_equip_and_resolution(main_source)
    validate_hotbar_mouse_selection(main_source)
    validate_matchmaking_ready_map(main_source, validator)
    validate_paths(main_source)
    validate_dj_watchdog_and_pr30(main_source, watchdog_source)
    validate_watchdog_pid_lifecycle(main_source)
    validate_community_strategy_sync(main_source)
    validate_packaging(root, validator, workflow)

    print("reported runtime hotfix contracts: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
