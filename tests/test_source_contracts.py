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


def validate_bitmap_ownership(main: str, watchdog: str, discord: str) -> None:
    assert 'SendScreenshot(, "' not in watchdog, (
        "watchdog screenshot callers must allocate and own their bitmap explicitly"
    )
    owned_pairs = re.findall(
        r"SendScreenshot\(pBitmap,[^\r\n]*\)\s*(?:\r?\n)\s*Gdip_DisposeImage\(pBitmap\)",
        watchdog,
    )
    assert len(owned_pairs) >= 7, "every watchdog screenshot path must dispose its owned bitmap"

    bot_screenshot = region(main, 'else if (content == "!screenshot")', 'else if (content == "!status")')
    assert "pBitmap := Gdip_BitmapFromScreen()" in bot_screenshot
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


def validate_roblox_coordinates(roblox: str) -> None:
    client_region = region(roblox, "getRobloxPos(", "; Returns the Roblox client rectangle in SCREEN coordinates.")
    assert "GetClientRect" in client_region
    assert re.search(r"(?m)^\s*x\s*:=\s*0\s*$", client_region)
    assert re.search(r"(?m)^\s*y\s*:=\s*0\s*$", client_region)

    screen_region = region(roblox, "GetRobloxScreenClientRect(", "; Returns hWnd on success")
    assert "WinGetClientPos(&x, &y, &width, &height" in screen_region


def validate(root: Path) -> None:
    main = read(root / "Main.ahk")
    watchdog = read(root / "submacros" / "watchdog.ahk")
    discord = read(root / "lib" / "Discord.ahk")
    roblox = read(root / "lib" / "Roblox.ahk")

    validate_settings_contracts(main)
    validate_strategy_geometry(main)
    validate_bitmap_ownership(main, watchdog, discord)
    validate_watchdog_result_fallbacks(watchdog)
    validate_watchdog_conditions_and_formatting(watchdog)
    validate_watchdog_retry_lifecycle(watchdog)
    validate_roblox_coordinates(roblox)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", default=".")
    arguments = parser.parse_args()
    validate(Path(arguments.root).resolve())
    print("source regression contracts: PASS")
