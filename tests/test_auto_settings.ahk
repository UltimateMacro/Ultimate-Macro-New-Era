#Requires AutoHotkey v2.0
#Include "%A_LineFile%\..\..\lib\auto_settings.ahk"

AssertTrue(condition, message) {
    if !condition
        throw Error(message)
}

WriteFixture(path, content) {
    fileObj := FileOpen(path, "w", "UTF-8")
    if !IsObject(fileObj)
        throw Error("Could not create fixture: " path)
    fileObj.Write(content)
    fileObj.Close()
}

CountMatches(haystack, pattern) {
    count := 0
    position := 1
    while (position := RegExMatch(haystack, pattern, &match, position)) {
        count++
        position += Max(1, StrLen(match[0]))
    }
    return count
}

ReportResult(message, exitCode, resultPath) {
    if (resultPath != "")
        WriteFixture(resultPath, message)
    else
        FileAppend(message "`n", "*")
    ExitApp(exitCode)
}

fixture := '<?xml version="1.0" encoding="UTF-8"?><roblox><string name="Unrelated">keep-me</string><token name="CameraMode">9</token><bool name="ChatVisible">true</bool><int name="FramerateCap">144</int></roblox>'
neverRunning := "UltimateMacro_Test_No_Process.exe"
resultPath := A_Args.Length >= 1 ? A_Args[1] : ""
testRoot := A_Temp "\UltimateMacro-auto-settings-test-" DllCall("kernel32\GetCurrentProcessId", "UInt") "-" A_TickCount
tempPrefix := RTrim(A_Temp, "\/") "\"

try {
    AssertTrue(InStr(testRoot, tempPrefix) = 1, "Fixture root escaped the system temp directory")
    DirCreate(testRoot)

    ; This exercises PCRE replacement behavior. The previously generated \\s and
    ; \\1 patterns fail these assertions by leaving old values and adding copies.
    transformed := TransformAutoSettingsXml(fixture)
    AssertTrue(InStr(transformed, '<token name="CameraMode">0</token>') > 0,
        "Existing CameraMode value was not replaced")
    AssertTrue(InStr(transformed, '<bool name="ChatVisible">false</bool>') > 0,
        "Existing ChatVisible value was not replaced")
    AssertTrue(InStr(transformed, '<int name="FramerateCap">60</int>') > 0,
        "Existing FramerateCap value was not replaced")
    AssertTrue(InStr(transformed, '<string name="Unrelated">keep-me</string>') > 0,
        "Unrelated XML was changed")
    for key, target in AutoSettingsManagedTargets() {
        AssertTrue(CountMatches(transformed, 'i)<(token|bool|int)\s+name="' key '">') = 1,
            "Managed setting is missing or duplicated: " key)
    }
    AutoSettingsValidateXml(transformed, true)

    hashInput := Buffer(3)
    NumPut("UChar", 0x61, "UChar", 0x62, "UChar", 0x63, hashInput)
    AssertTrue(AutoSettingsSha256Buffer(hashInput) = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        "Windows SHA-256 implementation failed the abc test vector")

    unknownPath := testRoot "\unknown.xml"
    WriteFixture(unknownPath, fixture)
    FileCopy(unknownPath, unknownPath ".macro_bak", 0)
    unknownSettingsBefore := FileRead(unknownPath)
    unknownBackupBefore := AutoSettingsFileSha256(unknownPath ".macro_bak")
    AssertTrue(!ApplyMacroSettings(unknownPath, neverRunning),
        "A legacy backup without provenance was accepted")
    AssertTrue(FileRead(unknownPath) = unknownSettingsBefore,
        "Unknown backup attempt changed current settings")
    AssertTrue(AutoSettingsFileSha256(unknownPath ".macro_bak") = unknownBackupBefore,
        "Unknown backup was overwritten or deleted")
    AssertTrue(!FileExist(unknownPath ".macro_bak.meta"),
        "Unknown backup was silently adopted")

    knownPath := testRoot "\known.xml"
    WriteFixture(knownPath, fixture)
    originalKnownHash := AutoSettingsFileSha256(knownPath)
    AssertTrue(ApplyMacroSettings(knownPath, neverRunning),
        "Verified apply failed: " GetAutoSettingsLastError())
    knownState := AutoSettingsReadBackupState(AutoSettingsPaths(knownPath))
    AssertTrue(knownState.status = "trusted", "Created backup provenance is not trusted")
    AssertTrue(knownState.backupHash = originalKnownHash, "Original backup identity was not recorded")
    AssertTrue(AutoSettingsFileSha256(knownPath) = knownState.appliedHash,
        "Applied identity does not match provenance")
    knownToken := MarkAutoSettingsRestoreRequested(knownPath)
    AssertTrue(knownToken != "", "Could not create a restore generation")
    AssertTrue(RestoreOriginalSettings(knownToken, knownPath, neverRunning),
        "Verified restore failed: " GetAutoSettingsLastError())
    AssertTrue(AutoSettingsFileSha256(knownPath) = originalKnownHash,
        "Restore did not reproduce the verified original")
    AssertTrue(!FileExist(knownPath ".macro_bak") && !FileExist(knownPath ".macro_bak.meta"),
        "Verified backup artifacts remained after successful identity check")

    tamperPath := testRoot "\tampered.xml"
    WriteFixture(tamperPath, fixture)
    AssertTrue(ApplyMacroSettings(tamperPath, neverRunning), "Tamper fixture apply failed")
    tamperAppliedHash := AutoSettingsFileSha256(tamperPath)
    WriteFixture(tamperPath ".macro_bak", StrReplace(fixture, "keep-me", "changed-backup"))
    tamperToken := MarkAutoSettingsRestoreRequested(tamperPath)
    AssertTrue(!RestoreOriginalSettings(tamperToken, tamperPath, neverRunning),
        "Backup with a mismatched SHA-256 was restored")
    AssertTrue(AutoSettingsFileSha256(tamperPath) = tamperAppliedHash,
        "Integrity failure changed current settings")
    AssertTrue(FileExist(tamperPath ".macro_bak") && FileExist(tamperPath ".macro_bak.meta"),
        "Integrity failure deleted recovery evidence")

    racePath := testRoot "\race.xml"
    WriteFixture(racePath, fixture)
    AssertTrue(ApplyMacroSettings(racePath, neverRunning), "Race fixture apply failed")
    raceAppliedHash := AutoSettingsFileSha256(racePath)
    supersededToken := MarkAutoSettingsRestoreRequested(racePath)
    currentToken := MarkAutoSettingsRestoreRequested(racePath)
    AssertTrue(supersededToken != currentToken, "Restore generations were not unique")
    AssertTrue(!RestoreOriginalSettings(supersededToken, racePath, neverRunning),
        "A superseded helper generation restored settings")
    AssertTrue(AutoSettingsFileSha256(racePath) = raceAppliedHash,
        "Superseded helper changed the applied settings")
    AssertTrue(RestoreOriginalSettings(currentToken, racePath, neverRunning),
        "Current restore generation did not restore settings")

    cancelPath := testRoot "\cancel.xml"
    WriteFixture(cancelPath, fixture)
    AssertTrue(ApplyMacroSettings(cancelPath, neverRunning), "Cancellation fixture apply failed")
    cancelledToken := MarkAutoSettingsRestoreRequested(cancelPath)
    AssertTrue(CancelPendingAutoSettingsRestore(cancelPath), "Restore cancellation reported failure")
    AssertTrue(!RestoreOriginalSettings(cancelledToken, cancelPath, neverRunning),
        "Cancelled helper generation restored settings")

    invalidPath := testRoot "\invalid.xml"
    WriteFixture(invalidPath, "<roblox><bool></roblox>")
    AssertTrue(!ApplyMacroSettings(invalidPath, neverRunning), "Malformed XML was accepted")
    AssertTrue(!FileExist(invalidPath ".macro_bak"), "Malformed XML produced a backup")

    ReportResult("Auto Settings behavioral fixtures: PASS", 0, resultPath)
} catch Error as err {
    ReportResult("Auto Settings behavioral fixtures: FAIL - " err.Message, 1, resultPath)
} finally {
    if DirExist(testRoot) && InStr(testRoot, tempPrefix) = 1
        DirDelete(testRoot, true)
}
