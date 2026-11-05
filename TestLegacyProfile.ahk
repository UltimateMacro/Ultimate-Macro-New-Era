#Include Main.ahk

Need(ok, reason) {
    if !ok
        throw Error(reason)
}

profile := A_Temp "\UltimateMacroProfileFixture-" DllCall("GetCurrentProcessId") ".ump"
resultCode := 0
try {
    original := Store.Defaults()
    doc := Map("formatVersion", 1, "application", "Ultimate Macro",
        "settings", Map("Options", Map("AutoEquip", 0, "AlwaysOnTop", 0, "WebhookURL", "ignored"),
        "Hotkeys", Map("CancelPlacement", "x")), "strategies", [Map("fileName", "../never-import.strat", "content", "ignored")])
    FileAppend(JSON.stringify(doc), profile, "UTF-8")
    result := LegacyProfile.Read(profile, original)
    Need(result.imported = 3 && result.skipped = 1, "1.3.6 settings counts")
    Need(!result.candidate["autoEquip"] && !result.candidate["topmost"], "1.3.6 flags")
    Need(result.candidate["runtime"]["cancelKey"] = "X", "1.3.6 hotkey")
    Need(original["autoEquip"] && !result.candidate.Has("webhookurl") && result.candidate["slot1"] = "", "no secret or strategy import")
    Need(InStr(FileRead(profile), "never-import"), "original profile not modified")
    FileAppend("PASS: exact 1.3.6 UMP schema, flags, hotkey and allowlist`n", "*")
} catch as e {
    FileAppend("FAIL: " e.Message "`n", "**")
    resultCode := 1
} finally {
    if FileExist(profile)
        FileDelete(profile)
}
ExitApp(resultCode)
