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

    # Never solve first-boot dependency handling by hiding genuine warnings.
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
    assert 'IniWrite(UpgradeDelay, SettingsFile, "Options", "UpgradeDelay")' in main, (
        "UpgradeDelay must be persisted when settings are saved"
    )

    assert re.search(
        r'global\s+UpgradeTowerGBKey\s*:=\s*IniRead\(SettingsFile,\s*"Hotkeys",\s*"UpgradeBottom",\s*"Z"\)',
        main,
    ), "UpgradeTowerGBKey must retain its persisted default"

    save_settings = region(main, "SaveAllSettings(ctrl, *)", "SaveAllSettingsMULTIPLAYER(ctrl, *)")
    fallback = re.search(
        r'if\s*\(tempUpgradeTowerGBKey\s*=\s*""\)\s*(?:\r?\n)\s*tempUpgradeTowerGBKey\s*:=\s*"Z"',
        save_settings,
    )
    assert fallback, "blank UpgradeTowerGBKey must fall back to Z"
    assert "UpgradeTowerGBKey := tempUpgradeTowerGBKey" in save_settings
    assert 'IniWrite(UpgradeTowerGBKey, SettingsFile, "Hotkeys", "UpgradeBottom")' in save_settings


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


def validate_bitmap_ownership(main: str, watchdog: str, discord: str) -> None:
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

    # Roblox being absent is intentionally text-only. Never capture the desktop
    # merely to report that the Roblox client does not exist.
    assert 'SendScreenshot(0, "Roblox is not running!"' in watchdog

    bot_screenshot = region(
        main,
        'else if (content == "!screenshot")',
        'else if (content == "!status")',
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

    # The v1.3.4 updater parses GitHub's structured response and counts only
    # valid .strat entries. Do not couple this contract to an obsolete local
    # strategyFiles array implementation.
    assert "JSON.parse(whr.ResponseText)" in community
    assert "RegExMatch(responseText" not in community

    # Empty or partial remote results can never replace the currently installed
    # community strategy set.
    assert "fileCount == 0" in community
    assert "successCount != fileCount" in community

    # User files are not silently overwritten and the refresh is transactional.
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
    # The image-search contract has two coordinate spaces:
    # capture in SCREEN coordinates, results in Roblox CLIENT coordinates.
    assert "GetRobloxScreenClientRect" in image_search
    assert 'pBitmapHaystack := Gdip_BitmapFromScreen(screenX' in image_search

    assert "x: centerX" in image_search
    assert "y: centerY" in image_search

    # Never add the screen-space client origin back into returned coordinates.
    assert "xC + centerX" not in image_search
    assert "yC + centerY" not in image_search
    assert "screenX + centerX" not in image_search
    assert "screenY + centerY" not in image_search

    # Runtime must expose which backend is active and retain a safe fallback.
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
    # GlobalSize must receive the owning HGLOBAL, never the GlobalLock pointer.
    for name, source in (("Main", main), ("watchdog", watchdog), ("Discord", discord)):
        assert 'GlobalSize", "Ptr", hData' in source, (
            f"{name} must pass HGLOBAL to GlobalSize"
        )
        assert 'GlobalSize", "Ptr", pData' not in source, (
            f"{name} must not pass the GlobalLock pointer to GlobalSize"
        )

    # AutoHotkey v2 owns COM interface references through ObjRelease.
    assert "IUnknown_Release" not in watchdog
    assert "ObjRelease(pFileStream)" in watchdog
    assert "ObjRelease(pStream)" in watchdog
    assert "ObjRelease(pStream)" in main
    assert "ObjRelease(pStream)" in discord

    discord_form = region(discord, "static CreateFormData(", "\n}")

    # Multipart streams must have explicit ownership and finally-based cleanup.
    assert "pStream := 0" in discord_form
    assert "ObjRelease(pStream)" in discord_form

    # Discord has bitmap and file-backed multipart paths. Both temporary
    # IStream references must be independently released.
    assert discord_form.count("pFileStream := 0") >= 2
    assert discord_form.count("ObjRelease(pFileStream)") >= 2

    # Backing HGLOBAL must be locked only for the final copy and released
    # regardless of whether RtlMoveMemory succeeds.
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
    client_region = region(roblox, "getRobloxPos(", "; Returns the Roblox client rectangle in SCREEN coordinates.")
    assert "GetClientRect" in client_region
    assert re.search(r"(?m)^\s*x\s*:=\s*0\s*$", client_region)
    assert re.search(r"(?m)^\s*y\s*:=\s*0\s*$", client_region)

    screen_region = region(roblox, "GetRobloxScreenClientRect(", "; Returns hWnd on success")
    assert "WinGetClientPos(&x, &y, &width, &height" in screen_region


def validate_official_remote(root: Path, main: str) -> None:
    bridge = read(root / "lib" / "OfficialRemote.ahk")
    worker = read(root / "submacros" / "official_remote.ahk")
    assert "#Include lib\\OfficialRemote.ahk" in main
    assert "OfficialRemoteInit()" in main
    assert "Official Remote" in main
    assert "Tab4_RemoteConsent" in main
    assert "OfficialRemoteShutdown()" in main
    assert 'global ClientVersion := "1.3.4a"' in worker
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


def validate(root: Path) -> None:
    main = read(root / "Main.ahk")
    watchdog = read(root / "submacros" / "watchdog.ahk")
    discord = read(root / "lib" / "Discord.ahk")
    roblox = read(root / "lib" / "Roblox.ahk")
    image_search = read(root / "lib" / "ImageSearch" / "ImageSearch.ahk")
    updater = read(root / "submacros" / "updater.ahk")
    safe_updater = read(root / "submacros" / "safe_update.ps1")
    wrapper = read(root / "submacros" / "update.bat")

    validate_source_dependency_bootstrap(main)
    validate_dependency_bootstrap_portability(root)
    validate_settings_contracts(main)
    validate_strategy_geometry(main)
    validate_hotbar_mouse_selection(main)
    validate_bitmap_ownership(main, watchdog, discord)
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
