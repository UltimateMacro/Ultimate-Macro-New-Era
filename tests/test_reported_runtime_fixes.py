#!/usr/bin/env python3
"""Source contracts for the reported-runtime QA hotfix."""
from __future__ import annotations

import hashlib
import importlib.util
import re
import subprocess
import sys
import tempfile
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
    safe_updater = read(root / "submacros/safe_update.ps1")
    updater_smoke = read(root / "tests/safe_updater_smoke.ps1")
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

    spec = importlib.util.spec_from_file_location("release_validator_fixture", root / "tests/validate_repo.py")
    require(spec is not None and spec.loader is not None, "repository validator could not be loaded")
    validator_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(validator_module)
    require("lib/auto_settings.ahk" in validator_module.REQUIRED_RUNTIME_FILES,
            "source/release manifest omits mandatory lib/auto_settings.ahk")
    require("'lib\\auto_settings.ahk'" in safe_updater,
            "safe updater payload allowlist omits mandatory lib/auto_settings.ahk")
    require("missing-auto-settings.zip" in updater_smoke and
            "Package missing lib\\auto_settings.ahk unexpectedly succeeded." in updater_smoke,
            "updater smoke test does not reject a package missing auto_settings.ahk")
    with tempfile.TemporaryDirectory(prefix="ultimate-macro-validator-") as fixture_dir:
        fixture_root = Path(fixture_dir)
        for relative in validator_module.REQUIRED_RUNTIME_FILES + validator_module.REQUIRED_QA_FILES:
            if relative == "lib/auto_settings.ahk":
                continue
            target = fixture_root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.touch()
        fixture_errors: list[str] = []
        validator_module.validate_required_files(fixture_root, fixture_errors)
        require(fixture_errors == ["required project file is missing: lib/auto_settings.ahk"],
                "source/release validation did not reject a fixture missing auto_settings.ahk")


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



def validate_positive_backports(main_source: str) -> None:
    required = {
        "party preflight validation": "PartySettingsProblem()",
        "party GUI sync": "SyncPartySettingsFromGui(false)",
        "party invite race lock": "PartyInviteBusy",
        "scaled party menu offset": "x + ScaleX(200)",
        "fresh party member recount": "CountPartyMembersPresent(w, h)",
        "party host watchdog phase": 'MacroPhase("party_host_wait", 190000)',
        "party member watchdog phase": 'MacroPhase("party_member_wait", 190000)',
        "draggable strategy scrollbar": "TryBeginScrollDrag()",
        "checkbox locking": "SetCheckboxLocked(AutoEquipCtrl, show, 1)",
        "debounced webhook validation": 'SetTimer(CheckWebhookLink, -700)',
        "gradient action buttons": "MakeActionButton(MainGui",
        "runtime timer stop": "StopRuntimeTimers()",
        "scan-code input release": '"sc011"',
    }
    for label, marker in required.items():
        require(marker in main_source, f"missing positive backport: {label}")

    forbidden = {
        "synchronous webhook validation on every keystroke": 'WebhookLinkCtrl.OnEvent("Change", CheckWebhookLink)',
        "OS-disabled AutoEquip rotation control": "AutoEquipCtrl.Enabled := !show",
    }
    for label, marker in forbidden.items():
        require(marker not in main_source, f"regression retained: {label}")

    # Anti-downgrade contracts: the Ziadod snapshot predates these production fixes.
    anti_downgrade = {
        "Darksen attribution": "; Ultimate Macro (macro for TDS) by Darksen",
        "safe updater include": "#Include submacros\\updater.ahk",
        "Discord bot": "TestBot(ctrl, *)",
        "ability timer hardening": "UseAbilitiesPass()",
        "watchdog local PID": "newWatchdogPID := 0",
        "watchdog IsSet guard": "IsSet(watchdogPID)",
        "absolute difficulty deadline": "difficultyDeadline := difficultyStart + 60000",
        "dynamic hotbar click": "SelectHotbarSlotByClick(slotNumber)",
        "portable image fallback": "image_backend_fallback",
    }
    for label, marker in anti_downgrade.items():
        require(marker in main_source, f"anti-downgrade contract missing: {label}")

def validate_auto_settings_hardening(
    root: Path, main_source: str, auto_settings_source: str, auto_settings_test: str
) -> None:
    tray_guard = region(
        auto_settings_source,
        "AutoSettingsRobloxSessionActive(robloxProcess :=",
        "ApplyMacroSettings(",
    )
    require("--launch-to-tray" in tray_guard and 'ComObjGet("winmgmts:")' in tray_guard,
            "Auto Settings must distinguish Roblox's persistent tray launcher from a game session")
    require("WMI/COM inspection failure must never make an active game look closed." in tray_guard and
            "return true" in tray_guard,
            "Roblox process inspection must fail closed")
    require("Roblox tray command line was not recognized" in auto_settings_test and
            "A normal Roblox command line was misclassified as tray-only" in auto_settings_test,
            "AHK behavioral fixtures must cover Roblox tray command-line classification")

    require('global AutoConfigureSettings := IniRead(SettingsFile, "Options", "AutoConfigureSettings", 0)' in main_source,
            "Auto Settings must be opt-in by default for the first hardened release")
    require(main_source.count('global AutoEquip := IniRead(SettingsFile, "Options", "AutoEquip", 0)') == 1,
            "AutoEquip should be initialized exactly once")

    startup = region(main_source, "; Opening Ultimate Macro must never apply Roblox settings.", "global LogLines := []")
    require("RecoverPendingAutoSettings(A_ScriptDir)" in startup,
            "startup must recover a verified pending original-settings backup")
    require("ApplyMacroSettings(" not in startup,
            "opening Ultimate Macro must not apply settings")

    enable = region(main_source, "EnableAutoConfig(ctrl, *) {", "SelectStrat1(ctrl, *) {")
    require("CancelPendingAutoSettingsRestore()" in enable,
            "enabling Auto Settings must cancel stale restore requests")
    require("ApplyMacroSettings(" not in enable,
            "enabling the option must not mutate Roblox XML immediately")
    require("RequestAutoSettingsRestore(A_ScriptDir)" in enable,
            "disabling Auto Settings must defer restoration safely while Roblox is alive")
    require("AutoConfigCtrl.Value := 0" in enable,
            "failed cancellation must turn the option back off")

    run_roblox = region(main_source, "RunRoblox(doReload := true) {", "CloseRoblox() {")
    require(run_roblox.count("PrepareAutoSettingsForRobloxLaunch(AutoConfigureSettings)") == 1,
            "RunRoblox must have one centralized Auto Settings preparation call")
    require(run_roblox.find("PrepareAutoSettingsForRobloxLaunch") < run_roblox.find("Run(DeepLink)"),
            "Auto Settings must be prepared immediately before Roblox launch")
    require("auto_settings_prepare_failed" in run_roblox and "return false" in run_roblox,
            "unsafe preparation must be diagnosable and block launch")

    handle_exit = region(main_source, "HandleExit(ExitReason, ExitCode) {", "CleanupGdip(exitReason, exitCode) {")
    require("RequestAutoSettingsRestore(A_ScriptDir)" in handle_exit,
            "Main exit must schedule the robust restore path")
    require("AutoSettingsBackupExists()" in handle_exit,
            "Main exit must recover a preserved backup even if the option was already disabled")
    require("IsSet(AutoConfigureSettings) && AutoConfigureSettings" in handle_exit,
            "early-startup OnExit must guard AutoConfigureSettings before reading it")
    require("if (AutoConfigureSettings ||" not in handle_exit,
            "early-startup OnExit retains an unguarded AutoConfigureSettings read")

    transform = region(auto_settings_source, "TransformAutoSettingsXml(xmlContent) {", "AutoSettingsSha256Buffer(data) {")
    require(r'\s+name="' in transform and r'</\1>' in transform,
            "AHK transformation must pass PCRE whitespace/backreference escapes")
    require(r'\\s+name="' not in transform and r'</\\1>' not in transform,
            "AHK transformation retains generated doubled regex escaping")
    require("AutoSettingsParseXml(xmlContent)" in transform and
            "AutoSettingsValidateXml(xmlContent, true)" in transform,
            "transformation must validate source and managed output XML")
    require("nodes.length > 1" in transform,
            "transformation must reject duplicate managed settings")

    provenance = region(auto_settings_source, "AutoSettingsReadBackupState(paths) {", "AutoSettingsWriteMetadata(")
    for field in ("Format", "Generation", "BackupSha256", "AppliedSha256"):
        require(field in provenance, f"backup provenance field missing: {field}")
    require('status: "unknown"' in provenance and "AutoSettingsFileSha256(paths.backup) != backupHash" in provenance,
            "legacy/corrupt backups must be classified unknown by strong identity")

    apply_region = region(auto_settings_source, 'ApplyMacroSettings(settingsPath := "",', "RestoreOriginalSettings(")
    require("backupState.status = \"unknown\"" in apply_region and
            "Unknown Auto Settings backup was preserved" in apply_region,
            "apply must preserve and refuse unknown backups")
    require("AutoSettingsRobloxSessionActive(robloxProcess)" in apply_region and
            apply_region.rfind("AutoSettingsRobloxSessionActive(robloxProcess)") < apply_region.find("FileMove(paths.applyTemp"),
            "apply must recheck Roblox immediately before replacement")

    classifier = region(auto_settings_source, "AutoSettingsClassifyCurrent(paths, backupState) {", "AutoSettingsWriteMetadata(")
    require('status: "backup"' in classifier and 'status: "applied_exact"' in classifier and
            'status: "applied_semantic"' in classifier and 'status: "foreign"' in classifier,
            "current settings must distinguish exact, semantic, and foreign states")
    require("AutoSettingsValidateFile(paths.settings, true)" in classifier and
            classifier.find("backupState.appliedHash") < classifier.find("AutoSettingsValidateFile(paths.settings, true)"),
            "semantic validation must be a fallback after exact identity checks")
    require("AutoSettingsClassifierReason(currentState)" in classifier and
            'RegExReplace(reason, "[\\r\\n\\t]+", " ")' in classifier and "SubStr(reason, 1, 300)" in classifier,
            "foreign-state diagnostics must be detailed, single-line, and bounded")
    require('Reason: "' in apply_region and "AutoSettingsClassifierReason(currentState)" in apply_region,
            "apply failure must preserve the detailed classifier reason for every log sink")

    restore_region = region(auto_settings_source, "RestoreOriginalSettings(", "ResolveAutoSettingsHelperExe(")
    require("AutoSettingsClassifyCurrent(paths, state)" in restore_region and
            'currentState.status = "foreign"' in restore_region,
            "restore must fail closed when a managed setting is outside the macro target")
    require(restore_region.find("AutoSettingsFileSha256(paths.settings) != state.backupHash") <
            restore_region.find("FileDelete(paths.backup)"),
            "backup deletion must follow restored content-identity verification")
    require("AutoSettingsRestoreRequestMatches(paths, expectedToken)" in restore_region and
            "AutoSettingsRobloxSessionActive(robloxProcess)" in restore_region,
            "restore must recheck generation and Roblox under the mutex")

    mutex_region = region(auto_settings_source, "AutoSettingsAcquireMutex(", "AutoSettingsNewGeneration() {")
    require("CreateMutexW" in mutex_region and "WaitForSingleObject" in mutex_region and
            "ReleaseMutex" in mutex_region,
            "apply/restore lifecycle must use inter-process exclusion")
    wait_region = auto_settings_source[auto_settings_source.index("WaitForRobloxExitAndRestore(expectedToken) {"):]
    require(wait_region.count("AutoSettingsRestoreRequestMatches(paths, expectedToken)") >= 3,
            "helper must repeatedly honor cancellation/generation changes")
    require('Sleep(2000)' in wait_region and
            wait_region.find('Sleep(2000)') < wait_region.rfind('AutoSettingsRobloxSessionActive("RobloxPlayerBeta.exe")'),
            "helper must recheck Roblox after its grace delay")

    require(auto_settings_source.count("A_IconHidden := true") == 1,
            "including auto_settings.ahk must not hide the main tray icon")
    standalone = region(auto_settings_source, "if (A_ScriptFullPath == A_LineFile) {", "AutoSettingsPaths(settingsPath := \"\") {")
    require("A_IconHidden := true" in standalone,
            "tray hiding is allowed only in standalone helper mode")
    require("A_Args[1]" in standalone and "WaitForRobloxExitAndRestore(restoreToken)" in standalone,
            "standalone helper must be bound to its restore generation")

    for forbidden in ("MEMORY_IDLE_THRESHOLD", "WorkingSetSize", "GetRobloxHWND()"):
        require(forbidden not in auto_settings_source,
                f"unsafe early-restore heuristic remains: {forbidden}")
    require(auto_settings_source.count("Win32_Process") == tray_guard.count("Win32_Process") == 1,
            "Win32_Process inspection must be confined to the fail-closed Roblox tray classifier")

    dll_targets = re.findall(r'DllCall\("([^"]+)"', main_source + auto_settings_source)
    require(all("\\\\" not in target for target in dll_targets),
            "runtime DllCall target contains a doubled generated separator")

    scroll_watch = region(main_source, "ScrollDragWatch() {", "OnScroll(wp, lp, msg, hwnd) {")
    require(scroll_watch.count("StopScrollDrag()") >= 3 and
            "!WinExist(\"ahk_id \" childHwnd)" in scroll_watch and
            "catch Error as err" in scroll_watch,
            "scroll drag must stop on release, missing GUI, and WinGetPos failure")
    require("SetTimer(ScrollDragWatch, 0)" in scroll_watch and "ScrollDragging := false" in scroll_watch,
            "scroll cleanup must clear state and stop the 10 ms timer")

    runtime_timers = region(main_source, "StopRuntimeTimers() {", "; Persistent application/UI timers")
    application_timers = region(main_source, "StopApplicationTimers() {", "ReleaseHeldInput() {")
    stop_strategy = region(main_source, "StopStrategy(*) {", "StartRecording(ctrl, *) {")
    require("ProcessCommands" not in runtime_timers,
            "ordinary runtime cleanup must not stop the persistent Discord bot timer")
    require("ProcessCommands" in application_timers and "CheckWebhookLink" in application_timers and
            "CheckWebhookLink2" in application_timers and "StopScrollDrag()" in application_timers,
            "application teardown must stop bot, debounce, and scrollbar callbacks")
    require("StopRuntimeTimers()" in stop_strategy and "StopApplicationTimers()" not in stop_strategy,
            "F2/record/strategy cleanup must preserve application timers")

    require("TransformAutoSettingsXml(fixture)" in auto_settings_test and
            "A legacy backup without provenance was accepted" in auto_settings_test and
            "Semantically applied settings were rejected" in auto_settings_test and
            "An unexpected managed setting was accepted" in auto_settings_test and
            "Live managed-value reproduction did not fail closed" in auto_settings_test and
            "Detailed classifier reason was missing from macro_error.log" in auto_settings_test and
            "Repeated lifecycle reused stale backup provenance" in auto_settings_test and
            "A superseded helper generation restored settings" in auto_settings_test,
            "isolated AHK fixture does not cover semantic state, provenance, repetition, and generation")
    bundled_ahk = root / "submacros/AutoHotkey64.exe"
    with tempfile.TemporaryDirectory(prefix="ultimate-macro-ahk-fixture-") as fixture_dir:
        result_path = Path(fixture_dir) / "result.txt"
        result = subprocess.run(
            [str(bundled_ahk), "/ErrorStdOut=UTF-8", str(root / "tests/test_auto_settings.ahk"), str(result_path)],
            cwd=root,
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
        fixture_result = result_path.read_text(encoding="utf-8-sig") if result_path.is_file() else ""
        require(result.returncode == 0 and fixture_result == "Auto Settings behavioral fixtures: PASS",
                "bundled AHK 2.0.12 Auto Settings behavioral fixture failed: " +
                (fixture_result or result.stdout + result.stderr).strip())

def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    main_source = read(root / "Main.ahk")
    image_source = read(root / "lib/ImageSearch/ImageSearch.ahk")
    watchdog_source = read(root / "submacros/watchdog.ahk")
    auto_settings_source = read(root / "lib/auto_settings.ahk")
    auto_settings_test = read(root / "tests/test_auto_settings.ahk")
    validator = read(root / "tests/validate_repo.py")
    workflow = read(root / ".github/workflows/ci.yml")

    validate_image_fallback(main_source, image_source)
    validate_equip_and_resolution(main_source)
    validate_hotbar_mouse_selection(main_source)
    validate_matchmaking_ready_map(main_source, validator)
    validate_paths(main_source)
    validate_dj_watchdog_and_pr30(main_source, watchdog_source)
    validate_watchdog_pid_lifecycle(main_source)
    validate_positive_backports(main_source)
    validate_auto_settings_hardening(root, main_source, auto_settings_source, auto_settings_test)
    validate_community_strategy_sync(main_source)
    validate_packaging(root, validator, workflow)

    print("reported runtime hotfix contracts: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
