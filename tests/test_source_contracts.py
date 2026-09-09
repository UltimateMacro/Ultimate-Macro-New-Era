from __future__ import annotations

import argparse
import re
from pathlib import Path


def read(path: Path) -> str:
    if not path.exists():
        raise AssertionError(f"missing required source file: {path}")
    return path.read_text(encoding="utf-8-sig")


def region(source: str, start: str, end: str) -> str:
    start_index = source.find(start)
    end_index = source.find(end, start_index + len(start))
    assert start_index >= 0, f"missing region start: {start}"
    assert end_index > start_index, f"missing region end: {end}"
    return source[start_index:end_index]


def validate_source_dependency_bootstrap(main: str) -> None:
    assert r"#Include *i lib\OCR.ahk" in main
    assert r"#Include *i lib\JSON.ahk" in main

    assert "IsSet(OCR)" in main
    assert "IsSet(JSON)" in main

    first_boot_call = main.index("BootstrapPinnedSourceDependencies()")
    assert main.index("IsSet(OCR)") < first_boot_call
    assert main.index("IsSet(JSON)") < first_boot_call

    assert "#Warn VarUnset, Off" not in main

    json_include = main.index(r"#Include *i lib\JSON.ahk")
    updater_include = main.index(r"#Include submacros\updater.ahk")
    assert json_include < updater_include, "JSON must be included before updater.ahk"

    startup = region(
        main,
        'if (!FileExist(A_ScriptDir "\\lib\\OCR.ahk")',
        'if WinExist("Ultimate Macro")',
    )
    assert "BootstrapPinnedSourceDependencies()" in startup

    bootstrap = region(
        main,
        "BootstrapPinnedSourceDependencies() {",
        "command_buffer := []",
    )

    assert r"tools\sync_dependencies.ps1" in bootstrap
    assert "RunWait(" in bootstrap
    assert "-NoProfile -ExecutionPolicy Bypass -File" in bootstrap
    assert r"lib\OCR.ahk" in bootstrap
    assert r"lib\JSON.ahk" in bootstrap
    assert "Reload()" in bootstrap



def validate_dependency_bootstrap_portability(root: Path) -> None:
    sync = read(root / "tools" / "sync_dependencies.ps1")

    assert "Get-FileHash" not in sync
    assert "Get-Command git" not in sync
    assert "hash-object" not in sync

    assert "System.Security.Cryptography.SHA256" in sync
    assert "System.Security.Cryptography.SHA1" in sync
    assert 'Get-GitBlobHash' in sync


def validate_settings_contracts(main: str) -> None:
    assert re.search(
        r'global\s+UpgradeDelay\s*:=\s*IniRead\(SettingsFile,\s*"Options",\s*"UpgradeDelay",\s*200\)',
        main,
    ), "UpgradeDelay must load from persisted settings"
    assert 'SaveOption("UpgradeDelay", UpgradeDelay)' in main, (
        "UpgradeDelay must be persisted the moment its field changes"
    )

    assert re.search(
        r'global\s+UpgradeTowerGBKey\s*:=\s*IniRead\(SettingsFile,\s*"Hotkeys",\s*"UpgradeBottom",\s*"Z"\)',
        main,
    ), "UpgradeTowerGBKey must retain its persisted default"

    save_settings = region(main, "AutoSaveKeybinds(*) {", "FirstKeyChar(value, fallback) {")
    assert (
        "tempUpgradeTowerGBKey := FirstKeyChar(UpgradeTowerGBCtrl.Value, UpgradeTowerGBKey)"
        in save_settings
    ), "a momentarily blank UpgradeTowerGBKey field must keep the key already in use"
    assert "UpgradeTowerGBKey := tempUpgradeTowerGBKey" in save_settings
    assert 'SaveHotkeySetting("UpgradeBottom", UpgradeTowerGBKey)' in save_settings


def validate_automatic_settings_persistence(main: str) -> None:
    """Ultimate Macro has no save buttons: every setting writes through on change."""
    for removed in (
        "SaveAllSettings(ctrl, *)",
        "SaveAllSettingsMULTIPLAYER(ctrl, *)",
        "SaveWebhookSettings(ctrl, *)",
        '"Save all settings"',
        '"Save Discord Settings"',
    ):
        assert removed not in main, f"save-button era code still present: {removed}"

    assert "SaveOption(key, value) {" in main, "settings must persist through a shared writer"
    assert "ResetSettingsToDefault(*) {" in main, "the Settings page must offer Reset to Default"

    assert 'Tab3_HostNm_EDIT.OnEvent("Change", (*) => AutoSavePartySettings())' in main, (
        "party settings must write through on change instead of waiting for a debounce"
    )
    assert 'VipLinkCtrl.OnEvent("Change", (*) => RefreshVipServerStatus())' in main, (
        "the VIP link must write through on change instead of waiting for a debounce"
    )
    assert 'UpgradeDelayCtrl.OnEvent("Change", (*) => AutoSaveUpgradeDelay())' in main, (
        "the upgrade delay must write through on change instead of waiting for a debounce"
    )

    assert 'QueueSettingSave("botsettings", AutoSaveBotSettings, 600)' in main
    assert 'QueueSettingSave("keybinds", AutoSaveKeybinds, 600)' in main

    assert "FlushPendingSettingSaves() {" in main, (
        "settings that stay debounced need a flush so a queued change is never dropped"
    )
    for owner, start, end in (
        ("StartStrategy", "StartStrategy(*) {", "StopStrategy(*) {"),
        ("SafeReload", "SafeReload() {", "ClearRestartLock() {"),
        ("HandleExit", "HandleExit(ExitReason, ExitCode) {", "CleanupGdip("),
    ):
        assert "FlushPendingSettingSaves()" in region(main, start, end), (
            f"{owner} must flush queued settings before it can discard them"
        )


def validate_placement_position_tracking(main: str) -> None:
    """Only an explicit space rejection may retire a recorded coordinate."""
    spawn = region(main, "SpawnTower(X, Y, slotNumber, towerID) {", "PlacementPositionKey(px, py) {")
    classifier = region(main, "IsPlacementExplicitlyRejected() {", "ResolvePlacementAmbiguity(towerID, &resV2) {")
    resolver = region(main, "ResolvePlacementAmbiguity(towerID, &resV2) {", "SellTower(towerID) {")

    assert "rejectedPositions := Map()" in spawn
    assert "rejectedPositions.Has(PlacementPositionKey(candidate[1], candidate[2]))" in spawn
    assert spawn.count("rejectedPositions[PlacementPositionKey(currentX, currentY)] := true") == 1, (
        "only confirmed space rejection may retire a position"
    )
    assert 'placementStatus = "funds"' in spawn and 'targetIndex--' in spawn, (
        "insufficient funds must keep the exact recorded position"
    )
    assert 'placementStatus = "unknown"' in spawn and 'placement_unknown_exhausted' in spawn, (
        "unknown placement state must fail safely without drifting coordinates"
    )
    assert 'placementStatus = "space"' in spawn, (
        "space rejection must be an explicit classifier result"
    )
    assert "cannot_place_here_v2.png" in classifier
    assert "IsPlacementInsufficientFunds()" in classifier and 'return "funds"' in classifier
    assert "afford" in classifier, "cannot-afford messages must classify as funds, not blocked space"
    assert 'ReadMessage(["cannot"' not in classifier, (
        "a bare cannot token is too broad for space rejection and misclassifies cannot-afford messages"
    )
    assert 'return "space"' in classifier
    assert 'return failureReason' in resolver
    assert "BuildPlacementTargets(X, Y)" in spawn
    assert "attemptMultiplier" not in spawn


def validate_recording_resilience(main: str) -> None:
    autosave = region(main, "RecordingAutosaveSnapshot(includeMacroSteps := false) {", "RecordingAutosaveDiscard() {")
    record_input = region(main, "RecordInputsHK(*) {", "CloneTowerHK(*) {")
    stop_record = region(main, "StopRecord(ctrl, *) {", "SafeStrategyFileName(value) {")
    exit_handler = region(main, "HandleExit(ExitReason, ExitCode) {", "CleanupGdip(")
    safe_reload = region(main, "SafeReload() {", "ClearRestartLock() {")

    assert "RecordMacroStep(step)" in autosave
    assert "RecordingAutosaveRewrite(true)" in autosave
    assert "SetTimer(FlushRecordingAutosaveSnapshot, -250)" in autosave
    assert 'nextHook := InputHook("V")' in record_input and "try {" in record_input
    assert "raw_input_recording_start_failed" in record_input, (
        "InputHook startup failure must be visible instead of silently killing recording"
    )
    assert "FinalizeMacroInputRecording(true)" in record_input
    assert "FinalizeMacroInputRecording(true)" in stop_record
    assert "RecordingAutosaveRewrite(true)" in exit_handler
    assert "RecordingAutosaveRewrite(true)" in safe_reload
    assert "SetWindowDisplayAffinity" not in main and "WDA_EXCLUDEFROMCAPTURE" not in main, (
        "the macro must not intentionally block external screen capture"
    )


def validate_timescale_reliability(main: str) -> None:
    """Once the ticket is spent the run must never be thrown away."""
    timescale = region(main, "activateTimescale() {", "AlignCamera(move := true")
    confirm_index = timescale.index("Click(hit.x, hit.y)")

    assert "WaitForTimescaleDialog(w, h, 4000, &hit)" in timescale, (
        "the dialog must be polled for rather than assumed after a fixed sleep"
    )
    assert "maxOpenAttempts" in timescale, "opening the dialog must be retried before giving up"
    assert "StopStrategy()" not in timescale[confirm_index:], (
        "the run must not be stopped after the TimeScale ticket has been consumed"
    )
    assert "timescale_confirmation_unverified" in timescale, (
        "an unverifiable confirmation must warn and continue, not abort"
    )

    ticketless = region(timescale, 'if (dialogKind = "getmore") {', "Click(hit.x, hit.y)")
    assert "StopStrategy()" not in ticketless, (
        "running out of timescale tickets must continue the run, not stop the macro"
    )
    assert "return true" in ticketless, (
        "the ticketless path must report success so the run proceeds without timescale"
    )

    dialog = region(main, "WaitForTimescaleDialog(w, h, timeoutMs, &hit) {", "activateTimescale() {")
    assert "confirmHit && (!getMoreHit || confirm.score >= getMore.score)" in dialog, (
        "a visible confirm button must win over Get More instead of losing a probe-order race"
    )
    assert "settleUntil" in dialog and "getMoreHit && A_TickCount >= settleUntil" in dialog, (
        "Get More must persist past a settle window before the run is declared ticketless"
    )


def validate_resolution_scaling(main: str) -> None:
    """Coordinate scaling must survive Roblox being closed or minimized."""
    scale_x = region(main, "ScaleX(baseX, Width := 1920) {", "ScaleY(baseY, Height := 1009) {")
    scale_y = region(main, "ScaleY(baseY, Height := 1009) {", "sX(baseX, Width := 1920) {")

    for name, body in (("ScaleX", scale_x), ("ScaleY", scale_y)):
        assert "> 0 ?" in body and ": baseX" in body or ": baseY" in body, (
            f"{name} must return the unscaled base when the client size is unavailable"
        )

    tower_ui = region(main, "waitForTowerUI(&resV2 := \"\", &resV1 := \"\", timeout := 0) {",
                      "WaitForTowerUIClosed(timeout := 500) {")
    assert "H_v2 := h - Y1_v2" in tower_ui, (
        "the tower panel search must reach the bottom of the client; clipping it at "
        "h * 0.95 cut the Sell label out of the region at 1920x1009"
    )


def validate_strategy_geometry(main: str) -> None:
    assert re.search(r"(?m)^global\s+StrategyHeight\s*:=\s*1080\b", main)
    assert not re.search(r"(?m)^global\s+StrategyHeight\s*:=\s*1090\b", main)


def validate_hotbar_mouse_selection(main: str) -> None:
    helper = region(main, "SelectHotbarSlotByClick(slotNumber) {", "ScaleX(baseX, Width :=")
    recording = region(main, "PlaceTowerHK(*) {", "UpgradeTowerHK(*) {")
    spawn = region(main, "SpawnTower(X, Y, slotNumber, towerID) {", "SellTower(towerID) {")

    assert "global Slots :=" not in main
    assert "Click(Slots[" not in main
    assert "getRobloxPos(, , &clientWidth, &clientHeight)" in helper
    assert "baseXBySlot[slot] * (clientWidth / 1920.0)" in helper
    assert "960 * (clientHeight / 1009.0)" in helper
    assert 'RuntimeLogInfo("hotbar_slot_resolved"' in helper
    assert "Click(slotX, slotY)" in helper
    assert recording.count("SelectHotbarSlotByClick(slot)") == 1
    assert spawn.count("SelectHotbarSlotByClick(slotNumber)") == 1
    assert 'Send("{" slot "}")' in recording
    assert 'Send("{" slotNumber "}")' in spawn


def validate_bitmap_ownership(main: str, watchdog: str, discord: str, discord_commands: str) -> None:
    assert 'SendScreenshot(, "' not in watchdog, (
        "watchdog screenshot callers must allocate and own their bitmap explicitly"
    )

    owned_captures = re.findall(
        r"(?m)^\s*pBitmap\s*:=\s*CaptureRobloxClientBitmap\(\)\s*$",
        watchdog,
    )
    owned_pairs = re.findall(
        r"SendScreenshot\(pBitmap,[^\r\n]*\)\s*(?:\r?\n)\s*Gdip_DisposeImage\(pBitmap\)",
        watchdog,
    )

    assert owned_captures, "watchdog must explicitly capture Roblox-client bitmaps"
    assert len(owned_pairs) == len(owned_captures), (
        "every watchdog CaptureRobloxClientBitmap path must dispose its owned bitmap"
    )

    assert 'SendScreenshot(0, "Roblox is not running!"' in watchdog

    bot_screenshot = region(
        discord_commands,
        'else if (content = "screenshot")',
        'else if (content = "status")',
    )
    assert "Gdip_BitmapFromScreen()" not in bot_screenshot, (
        "the bot must never capture the whole desktop"
    )
    assert "pBitmap := CaptureRobloxClientBitmap()" in bot_screenshot
    assert 'Discord.SendScreenshot(pBitmap, "Requested Screenshot")' in bot_screenshot
    assert "Gdip_DisposeImage(pBitmap)" in bot_screenshot

    discord_send = region(discord, "static SendScreenshot(", "static SendImage(")
    assert "Gdip_DisposeImage" not in discord_send, (
        "Discord.SendScreenshot must not dispose a caller-owned bitmap"
    )

def validate_watchdog_result_fallbacks(watchdog: str) -> None:
    send_info = region(watchdog, 'SendInfo(matchResult := "")', "BinarizeTargetBitmap(pBitmap)")
    assert "FoundX := 0" in send_info and "FoundY := 0" in send_info
    invalid_coordinates = send_info.find("if (FoundX == 0 && FoundY == 0)")
    currency_ocr = send_info.find('if (SendCurrenciesEnabled = "1")')
    assert 0 <= invalid_coordinates < currency_ocr, (
        "invalid result coordinates must take the screenshot-only fallback before OCR regions are calculated"
    )
    invalid_region = send_info[invalid_coordinates:currency_ocr]
    assert "return" in invalid_region, "invalid-coordinate fallback must stop before OCR"

    assert "pBitmapInfo := Gdip_BitmapFromScreen" in send_info
    assert "Gdip_DisposeImage(pBitmapInfo)" in send_info, "pBitmapInfo must be disposed"


def validate_watchdog_conditions_and_formatting(watchdog: str) -> None:
    guarded = 'if ((WebhookEnabled && WebhookLink != "") || botEnabled)'
    assert watchdog.count(guarded) >= 3, "webhook/bot conditions must preserve explicit precedence"
    assert 'if (WebhookEnabled && WebhookLink != "" || botEnabled)' not in watchdog

    assert 'wlRatioStr := StrReplace(String(wlRatio), ".", ",")' in watchdog, (
        "W/L ratio formatting must remain locale-safe and decimal-comma compatible"
    )


def validate_watchdog_retry_lifecycle(watchdog: str) -> None:
    send = region(watchdog, "SendScreenshot(pBitmap :=", "CreateFormData(&retData")
    loop_index = send.find("loop MaxAttempts")
    request_index = send.find('whr := ComObject("WinHttp.WinHttpRequest.5.1")')
    assert 0 <= loop_index < request_index, (
        "each watchdog retry must create a fresh WinHttpRequest inside the attempt loop"
    )
    assert "static whr" not in send
    assert "status >= 200 && status < 300" in send
    assert "status != 429" in send and "status < 500" in send
    assert "return true" in send and "return false" in send


def validate_watchdog_pid_lifecycle(main: str) -> None:
    start = region(main, "startWatchdog() {", "KillSubmacros() {")
    cleanup = region(main, "KillSubmacros() {", "HandleExit(ExitReason, ExitCode) {")
    handle_exit = region(main, "HandleExit(ExitReason, ExitCode) {", "CleanupGdip(exitReason, exitCode) {")

    assert "newWatchdogPID := 0" in start
    assert "&newWatchdogPID" in start
    assert "&watchdogPID" not in start
    assert start.index("Run(command, , , &newWatchdogPID)") < start.index(
        "watchdogPID := newWatchdogPID"
    )
    assert "watchdog_start_failed" in start and "return false" in start

    assert 'if (IsSet(watchdogPID) && watchdogPID != "")' in cleanup
    assert cleanup.index('watchdogPID := ""') < cleanup.index('if (trackedPID != "")')
    assert 'if (watchdogPID != "")' not in cleanup
    assert r'A_ScriptDir "\submacros\watchdog.ahk"' in cleanup
    assert "InStr(normalizedCmd, targetScript)" in cleanup

    assert "try KillSubmacros()" in handle_exit
    assert "if (IsSet(RunningStrategy) && RunningStrategy)" in handle_exit
    assert "if (RunningStrategy)" not in handle_exit
    assert "watchdog_exit_cleanup_failed" in handle_exit


def validate_ready_detection(main: str) -> None:
    ready = region(main, "FindReadyButton(&foundX, &foundY)", "activateTimescale()")
    template_index = ready.find('AdvancedImageSearch("Resources/ready_gs.png"')
    assert template_index >= 0, "Ready must be detected by template first"

    assert "PixelSearch" not in ready, (
        "Ready clicks must be based on the bounded template, not a generic green pixel"
    )
    assert re.search(r"(?m)^\s*rx := Round\(w \* 0\.4\)", ready), (
        "the bounded Ready region must remain anchored to the Roblox client"
    )
    assert re.search(r"(?m)^\s*rw := Round\(w \* 0\.3\)", ready)

    assert "readyDeadline := A_TickCount + 8000" in ready
    assert "attempts < 6" in ready, "Ready click retries must remain bounded"
    assert ready.count("FindReadyButton(") >= 3, (
        "Ready must be detected before a click and rechecked after it"
    )
    assert "SafeReload()" in ready, "unconfirmed Ready clicks must fail safely"

def validate_community_strategy_update(main: str) -> None:
    community = region(
        main, "IsGitDevelopmentCheckout(rootDir) {", "global FrameX := 30"
    )
    checkout_guard = region(main, "IsGitDevelopmentCheckout(rootDir) {", "LoadedStrats := []")

    assert 'FileExist(rootDir "\\.git")' in checkout_guard, (
        "normal checkouts and linked worktrees must both disable community sync"
    )
    assert "DirExist(" not in checkout_guard, (
        "a directory-only guard would miss linked Git worktrees"
    )
    assert "needUpdate := !IsGitDevelopmentCheckout(A_ScriptDir)" in community
    assert community.index("needUpdate := !IsGitDevelopmentCheckout(A_ScriptDir)") < (
        community.index("if (needUpdate) {")
    ), "the development guard must run before the community request block"

    assert (
        "UltimateMacro/Ultimate-Macro-New-Era/contents/Resources/Strats?ref=main"
        in community
    )
    assert "DarksenDev/tds-macro/contents/Strategies" not in community

    assert "JSON.parse(whr.ResponseText)" in community
    assert "RegExMatch(responseText" not in community

    assert "fileCount == 0" in community
    assert "successCount != fileCount" in community

    assert "would overwrite a local strategy" in community
    assert ".download_temp" in community
    assert ".community_backup" in community
    assert "finally" in community

def validate_webhook_batching(main: str) -> None:
    queue = region(main, "SendToWebhook(message)", "SafeReload()")
    assert "SetTimer(ProcessWebhookQueue, -2000)" in queue
    process = region(queue, "ProcessWebhookQueue()", "FlushWebhookQueue() {")
    assert "WebhookQueue.Length < 20" not in process, (
        "small webhook batches must be sent after the collection window, not deferred forever"
    )


def validate_image_search_coordinates(image_search: str) -> None:
    assert "GetRobloxScreenClientRect" in image_search
    assert 'pBitmapHaystack := Gdip_BitmapFromScreen(screenX' in image_search

    assert "x: centerX" in image_search
    assert "y: centerY" in image_search

    assert "xC + centerX" not in image_search
    assert "yC + centerY" not in image_search
    assert "screenX + centerX" not in image_search
    assert "screenY + centerY" not in image_search

    assert "GetImageSearchBackendInfo()" in image_search
    assert '"GDI+ fallback"' in image_search
    assert '"OpenCV native"' in image_search

def validate_discord_retries(discord: str) -> None:
    request = region(discord, "static Request(method, url", "static GetRetryDelayMs(")
    loop_index = request.find("loop maxAttempts")
    request_index = request.find('wr := ComObject("WinHttp.WinHttpRequest.5.1")')
    assert 0 <= loop_index < request_index
    assert "wr.Open(method, url, false)" in request
    assert "status = 429" in request
    assert "status >= 500 && status <= 599" in request

    delay = region(discord, "static GetRetryDelayMs(", "static CreateFormData(")
    assert 'GetResponseHeader("Retry-After")' in delay
    assert 'parsed.Has("retry_after")' in delay
    assert "Min(30000" in delay


def validate_multipart_handles(main: str, watchdog: str, discord: str) -> None:
    for name, source in (("Main", main), ("watchdog", watchdog), ("Discord", discord)):
        assert 'GlobalSize", "Ptr", hData' in source, (
            f"{name} must pass HGLOBAL to GlobalSize"
        )
        assert 'GlobalSize", "Ptr", pData' not in source, (
            f"{name} must not pass the GlobalLock pointer to GlobalSize"
        )

    assert "IUnknown_Release" not in watchdog
    assert "ObjRelease(pFileStream)" in watchdog
    assert "ObjRelease(pStream)" in watchdog
    assert "ObjRelease(pStream)" in main
    assert "ObjRelease(pStream)" in discord

    discord_form = region(discord, "static CreateFormData(", "\n}")

    assert "pStream := 0" in discord_form
    assert "ObjRelease(pStream)" in discord_form

    assert discord_form.count("pFileStream := 0") >= 2
    assert discord_form.count("ObjRelease(pFileStream)") >= 2

    assert 'GlobalLock", "Ptr", hData' in discord_form
    assert 'GlobalUnlock", "Ptr", hData' in discord_form
    assert 'GlobalFree", "Ptr", hData' in discord_form

    assert re.search(
        r"try\s*\{.*RtlMoveMemory.*\}\s*finally\s*\{"
        r".*GlobalUnlock.*GlobalFree",
        discord_form,
        re.DOTALL,
    ), "Discord multipart HGLOBAL must be released in finally"

def validate_transactional_updater(updater: str, safe_updater: str, wrapper: str) -> None:
    assert "https://api.github.com/repos/UltimateMacro/Ultimate-Macro-New-Era/releases/latest" in updater
    assert r"https://github\.com/UltimateMacro/Ultimate-Macro-New-Era/releases/download/" in updater
    assert 'PreferredAsset := "TDS_Macro.zip"' in updater
    assert "JSON.parse" in updater
    assert 'RegExMatch(candidateDigest, "i)^sha256:[0-9a-f]{64}$")' in updater
    assert "CompareMacroVersions(latestVer, installedVer) <= 0" in updater
    assert "GetCurrentProcessId" in updater
    assert 'command .= " -SelfDelete"' in updater
    assert "DarksenDev/tds-macro/releases/latest" not in updater
    assert "DarksenDev/tds-macro/releases/download" not in updater

    assert "[Parameter(Mandatory = $true)][string]$ExpectedSha256" in safe_updater
    assert "/UltimateMacro/Ultimate-Macro-New-Era/releases/download/" in safe_updater
    assert "DarksenDev/tds-macro/releases/download" not in safe_updater
    assert "Refusing to update a filesystem root" in safe_updater
    assert "does not contain Main.ahk" in safe_updater
    assert "A .git entry was detected" in safe_updater
    assert "Normalize-Sha256" in safe_updater
    assert "SHA-256 mismatch" in safe_updater
    assert "Assert-SafeZip" in safe_updater
    assert "Assert-RuntimePayload" in safe_updater
    assert "Move-Item -LiteralPath $MacroDir -Destination $backupDir" in safe_updater
    assert "Restore-PreservedStrategies" in safe_updater
    assert "The previous installation was restored" in safe_updater
    assert "Updater self-delete path" in safe_updater
    assert "checksum verification was skipped" not in safe_updater.casefold()

    assert "safe_update.ps1" in wrapper
    assert "del /f /s /q" not in wrapper.casefold()
    assert "rd /s /q" not in wrapper.casefold()
    assert "expand-archive" not in wrapper.casefold()


def validate_roblox_coordinates(roblox: str) -> None:
    client_region = region(roblox, "getRobloxPos(", "GetRobloxScreenClientRect(")
    assert "GetClientRect" in client_region
    assert re.search(r"(?m)^\s*x\s*:=\s*0\s*$", client_region)
    assert re.search(r"(?m)^\s*y\s*:=\s*0\s*$", client_region)

    screen_region = region(roblox, "GetRobloxScreenClientRect(", "GetRobloxHWND() {")
    assert "WinGetClientPos(&x, &y, &width, &height" in screen_region


def validate_official_remote(root: Path, main: str) -> None:
    bridge = read(root / "lib" / "OfficialRemote.ahk")
    worker = read(root / "submacros" / "official_remote.ahk")
    assert "#Include lib\\OfficialRemote.ahk" in main
    assert "OfficialRemoteInit()" in main
    assert "Official Remote" in main
    assert "Tab4_RemoteConsent" in main
    assert "OfficialRemoteShutdown()" in main
    assert 'global ClientVersion := "1.3.5a"' in worker
    assert "CryptProtectData" in worker
    assert "CryptUnprotectData" in worker
    assert "GetOrCreateInstallId" in worker
    assert '"X-ULT-Install-ID"' in worker
    assert "rotateToken" in worker
    assert "Tab4_RemoteConsent.Value" in bridge
    assert not re.search(r"(?im)^\s*buffer\s*:=\s*Buffer\(", worker), (
        "a local named buffer shadows AutoHotkey v2's case-insensitive Buffer constructor"
    )
    assert "decodedBytes := Buffer(size)" in worker
    assert "fileBytes := Buffer(file.Length)" in worker


def validate_qa_credits(root: Path, main: str) -> None:
    readme = read(root / "README.md")
    expected_readme = """**QA**

- frostzzz
- menz7
- nytli
- tristanm1ce"""
    expected_app = """QA
• frostzzz
• menz7
• nytli
• tristanm1ce"""

    assert expected_readme in readme, "README QA roster is incomplete or out of order"
    assert expected_app in main, "in-app QA credits are incomplete or out of order"
    assert "nytil" not in readme.lower(), "README still contains the old nytli typo"


def validate(root: Path) -> None:
    main = read(root / "Main.ahk")
    watchdog = read(root / "submacros" / "watchdog.ahk")
    discord = read(root / "lib" / "Discord.ahk")
    discord_commands = read(root / "lib" / "DiscordCommands.ahk")
    roblox = read(root / "lib" / "Roblox.ahk")
    image_search = read(root / "lib" / "ImageSearch" / "ImageSearch.ahk")
    updater = read(root / "submacros" / "updater.ahk")
    safe_updater = read(root / "submacros" / "safe_update.ps1")
    wrapper = read(root / "submacros" / "update.bat")

    validate_source_dependency_bootstrap(main)
    validate_dependency_bootstrap_portability(root)
    validate_qa_credits(root, main)
    validate_settings_contracts(main)
    validate_automatic_settings_persistence(main)
    validate_placement_position_tracking(main)
    validate_recording_resilience(main)
    validate_timescale_reliability(main)
    validate_resolution_scaling(main)
    validate_strategy_geometry(main)
    validate_hotbar_mouse_selection(main)
    validate_bitmap_ownership(main, watchdog, discord, discord_commands)
    validate_watchdog_result_fallbacks(watchdog)
    validate_watchdog_conditions_and_formatting(watchdog)
    validate_watchdog_retry_lifecycle(watchdog)
    validate_watchdog_pid_lifecycle(main)
    validate_roblox_coordinates(roblox)
    validate_ready_detection(main)
    validate_community_strategy_update(main)
    validate_webhook_batching(main)
    validate_image_search_coordinates(image_search)
    validate_discord_retries(discord)
    validate_multipart_handles(main, watchdog, discord)
    validate_transactional_updater(updater, safe_updater, wrapper)
    validate_official_remote(root, main)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", default=".")
    arguments = parser.parse_args()
    validate(Path(arguments.root).resolve())
    print("source regression contracts: PASS")