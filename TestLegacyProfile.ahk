#Include Main.ahk

Need(ok, reason) {
    if !ok
        throw Error(reason)
}

profile := A_Temp "\UltimateMacroProfileFixture-" DllCall("GetCurrentProcessId") ".ump"
exported := A_Temp "\UltimateMacroProfileExport-" DllCall("GetCurrentProcessId") ".ump"
resultCode := 0
try {
    original := Store.Defaults()
    doc := Map("formatVersion", 1, "application", "Ultimate Macro",
        "settings", Map("Options", Map("AutoEquip", 0, "AutoCloseChat", 0, "AlwaysOnTop", 0, "WebhookURL", "ignored"),
        "Hotkeys", Map("CancelPlacement", "x")), "strategies", [Map("fileName", "../never-import.strat", "content", "ignored")])
    FileAppend(JSON.stringify(doc), profile, "UTF-8")
    result := LegacyProfile.Read(profile, original)
    Need(result.imported = 4 && result.skipped = 1, "1.3.6 settings counts")
    Need(original["autoCloseChat"] && !result.candidate["autoCloseChat"]
        && !result.candidate["autoEquip"] && !result.candidate["topmost"], "1.3.6 flags")
    Need(result.candidate["runtime"]["cancelKey"] = "X", "1.3.6 hotkey")
    Need(original["autoEquip"] && !result.candidate.Has("webhookurl") && result.candidate["slot1"] = "", "no secret or strategy import")
    Need(InStr(FileRead(profile), "never-import"), "original profile not modified")

    source := Store.Defaults()
    source["topmost"] := false, source["autoEquip"] := false
    source["rotationAmount"] := 17, source["rotationUnit"] := "Minutes"
    source["runtime"]["upgradeDelayMs"] := 319, source["runtime"]["cancelKey"] := "N"
    source["runtime"]["enforcerVanKey"] := "Q"
    source["recordBindings"]["place"] := "Shift+F3"
    source["slot1"] := "C:\qa\PRIVATE_PATH.strat"
    source["vipLink"] := "VIP_SECRET", source["discordToken"] := "DISCORD_SECRET"
    source["webhookUrl"] := "WEBHOOK_SECRET"
    source["recordBindings"]["unused"] := "EXTRA_BINDING_SECRET"
    source["runtime"]["unused"] := "EXTRA_RUNTIME_SECRET"
    LegacyProfile.Export(exported, source)
    saved := FileRead(exported, "UTF-8")
    payload := JSON.parse(saved)
    Need(payload["formatVersion"] = 1 && payload["application"] = "Ultimate Macro"
        && !payload.Has("strategies"), "Export writes a settings-only legacy UMP")
    Need(!RegExMatch(saved, "i)private_path|vip|discord|webhook|secret|slot1|unused|strategies"),
        "Export excludes account data, strategy paths and unsupported fields")
    roundTrip := LegacyProfile.Read(exported, original)
    restored := roundTrip.candidate
    Need(roundTrip.skipped = 0 && !restored["topmost"] && !restored["autoEquip"]
        && restored["rotationAmount"] = 17 && restored["rotationUnit"] = "Minutes"
        && restored["runtime"]["upgradeDelayMs"] = 319 && restored["runtime"]["cancelKey"] = "N"
        && restored["runtime"]["enforcerVanKey"] = "Q"
        && restored["recordBindings"]["place"] = "Shift+F3" && restored["slot1"] = "",
        "Supported values round-trip through the real legacy importer")
    source["rotationAmount"] := 99
    refused := false
    try LegacyProfile.Export(exported, source)
    catch
        refused := true
    Need(refused && FileRead(exported, "UTF-8") == saved, "Export cannot replace an existing profile")
    FileAppend("PASS: legacy UMP import, compatible settings export, privacy allowlist and no overwrite`n", "*")
} catch as e {
    FileAppend("FAIL: " e.Message "`n", "**")
    resultCode := 1
} finally {
    if FileExist(profile)
        FileDelete(profile)
    if FileExist(exported)
        FileDelete(exported)
}
ExitApp(resultCode)
