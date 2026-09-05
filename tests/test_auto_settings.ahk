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

WriteRawUtf8Fixture(path, content) {
    fileObj := FileOpen(path, "w", "UTF-8-RAW")
    if !IsObject(fileObj)
        throw Error("Could not create raw UTF-8 fixture: " path)
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

    AssertTrue(AutoSettingsRobloxCommandLineIsTray(
        '"C:\Users\test\RobloxPlayerBeta.exe" --launch-to-tray'),
        "Roblox tray command line was not recognized")
    AssertTrue(AutoSettingsRobloxCommandLineIsTray(
        '"C:\RobloxPlayerBeta.exe" --foo --launch-to-tray --bar'),
        "Roblox tray flag was not recognized among other arguments")
    AssertTrue(!AutoSettingsRobloxCommandLineIsTray(
        '"C:\RobloxPlayerBeta.exe" --app'),
        "A normal Roblox command line was misclassified as tray-only")
    AssertTrue(!AutoSettingsRobloxCommandLineIsTray(
        '"C:\RobloxPlayerBeta.exe" --launch-to-tray-extra'),
        "A partial tray flag was accepted")

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

    firstGeneration := knownState.generation
    AssertTrue(ApplyMacroSettings(knownPath, neverRunning),
        "Repeated lifecycle apply failed: " GetAutoSettingsLastError())
    repeatedState := AutoSettingsReadBackupState(AutoSettingsPaths(knownPath))
    AssertTrue(repeatedState.status = "trusted" && repeatedState.generation != firstGeneration,
        "Repeated lifecycle reused stale backup provenance")

    semanticPath := testRoot "\semantic.xml"
    WriteFixture(semanticPath, fixture)
    semanticOriginalHash := AutoSettingsFileSha256(semanticPath)
    AssertTrue(ApplyMacroSettings(semanticPath, neverRunning), "Semantic fixture apply failed")
    semanticState := AutoSettingsReadBackupState(AutoSettingsPaths(semanticPath))
    semanticXml := StrReplace(FileRead(semanticPath), "</roblox>",
        '<string name="RobloxNormalized">preserve-me</string></roblox>')
    ; Reproduce Roblox's observed BOM removal while also preserving an unrelated
    ; serialization change which Auto Settings does not own.
    WriteRawUtf8Fixture(semanticPath, semanticXml)
    AssertTrue(AutoSettingsFileSha256(semanticPath) != semanticState.backupHash
        && AutoSettingsFileSha256(semanticPath) != semanticState.appliedHash,
        "Semantic fixture did not diverge from both recorded identities")
    AssertTrue(ApplyMacroSettings(semanticPath, neverRunning),
        "Semantically applied settings were rejected: " GetAutoSettingsLastError())
    AssertTrue(InStr(FileRead(semanticPath), '<string name="RobloxNormalized">preserve-me</string>') > 0,
        "Semantic apply rewrote an unrelated Roblox setting")
    AssertTrue(RequestAutoSettingsRestore("", semanticPath, neverRunning),
        "Semantic current state could not restore: " GetAutoSettingsLastError())
    AssertTrue(AutoSettingsFileSha256(semanticPath) = semanticOriginalHash,
        "Semantic current state did not restore the exact verified original")

    foreignPath := testRoot "\foreign-managed.xml"
    WriteFixture(foreignPath, fixture)
    AssertTrue(ApplyMacroSettings(foreignPath, neverRunning), "Foreign managed fixture apply failed")
    foreignPaths := AutoSettingsPaths(foreignPath)
    foreignBackupHash := AutoSettingsFileSha256(foreignPaths.backup)
    foreignXml := StrReplace(FileRead(foreignPath), '<token name="CameraMode">0</token>',
        '<token name="CameraMode">7</token>')
    WriteFixture(foreignPath, foreignXml)
    foreignCurrentHash := AutoSettingsFileSha256(foreignPath)
    AssertTrue(!ApplyMacroSettings(foreignPath, neverRunning),
        "An unexpected managed setting was accepted")
    AssertTrue(AutoSettingsFileSha256(foreignPath) = foreignCurrentHash,
        "Foreign managed current settings were overwritten")
    AssertTrue(AutoSettingsFileSha256(foreignPaths.backup) = foreignBackupHash,
        "Foreign managed state changed the verified backup")

    ; Sanitized reproduction of the live QA artifact: Roblox preserved the
    ; macro-applied document but PerformanceStatsVisible changed back to false.
    liveReproPath := testRoot "\live-performance-stats.xml"
    WriteFixture(liveReproPath, fixture)
    AssertTrue(ApplyMacroSettings(liveReproPath, neverRunning), "Live reproduction fixture apply failed")
    liveReproPaths := AutoSettingsPaths(liveReproPath)
    liveReproXml := StrReplace(FileRead(liveReproPath),
        '<bool name="PerformanceStatsVisible">true</bool>',
        '<bool name="PerformanceStatsVisible">false</bool>')
    WriteRawUtf8Fixture(liveReproPath, liveReproXml)
    liveReproState := AutoSettingsReadBackupState(liveReproPaths)
    liveClassification := AutoSettingsClassifyCurrent(liveReproPaths, liveReproState)
    expectedReason := "Managed Auto Settings node has an unexpected value: PerformanceStatsVisible"
    AssertTrue(liveClassification.status = "foreign", "Live managed-value reproduction did not fail closed")
    AssertTrue(liveClassification.reason = expectedReason,
        "Live managed-value reproduction returned the wrong classifier reason")
    AssertTrue(!ApplyMacroSettings(liveReproPath, neverRunning),
        "Live managed-value reproduction was accepted")
    AssertTrue(InStr(GetAutoSettingsLastError(), "Reason: " expectedReason) > 0,
        "Detailed classifier reason was missing from the caller diagnostic")
    AssertTrue(InStr(FileRead(liveReproPaths.errorLog), "Reason: " expectedReason) > 0,
        "Detailed classifier reason was missing from macro_error.log")

    noEvidencePath := testRoot "\no-evidence.xml"
    WriteFixture(noEvidencePath, fixture)
    noEvidenceHash := AutoSettingsFileSha256(noEvidencePath)
    AssertTrue(RecoverPendingAutoSettings("", noEvidencePath, neverRunning),
        "No-evidence recovery should be a safe no-op: " GetAutoSettingsLastError())
    AssertTrue(AutoSettingsFileSha256(noEvidencePath) = noEvidenceHash,
        "No-evidence recovery changed current settings")

    orphanMetaPath := testRoot "\orphan-metadata.xml"
    WriteFixture(orphanMetaPath, fixture)
    AssertTrue(ApplyMacroSettings(orphanMetaPath, neverRunning), "Orphan metadata fixture apply failed")
    orphanMetaPaths := AutoSettingsPaths(orphanMetaPath)
    orphanMetaCurrentHash := AutoSettingsFileSha256(orphanMetaPath)
    FileDelete(orphanMetaPaths.backup)
    AssertTrue(!RequestAutoSettingsRestore("", orphanMetaPath, neverRunning),
        "Metadata-only Auto Settings provenance was accepted")
    AssertTrue(AutoSettingsFileSha256(orphanMetaPath) = orphanMetaCurrentHash,
        "Metadata-only provenance changed current settings")
    AssertTrue(FileExist(orphanMetaPaths.metadata),
        "Metadata-only provenance evidence was deleted")
    AssertTrue(InStr(GetAutoSettingsLastError(), "backup and provenance metadata are not both present") > 0,
        "Metadata-only provenance did not report the asymmetric lifecycle")
    AssertTrue(!RecoverPendingAutoSettings("", orphanMetaPath, neverRunning),
        "Recovery silently treated orphaned metadata as no pending lifecycle")
    AssertTrue(FileExist(orphanMetaPaths.metadata),
        "Recovery deleted orphaned metadata evidence")

    orphanBackupPath := testRoot "\orphan-backup.xml"
    WriteFixture(orphanBackupPath, fixture)
    AssertTrue(ApplyMacroSettings(orphanBackupPath, neverRunning), "Orphan backup fixture apply failed")
    orphanBackupPaths := AutoSettingsPaths(orphanBackupPath)
    orphanBackupCurrentHash := AutoSettingsFileSha256(orphanBackupPath)
    FileDelete(orphanBackupPaths.metadata)
    AssertTrue(!RequestAutoSettingsRestore("", orphanBackupPath, neverRunning),
        "Backup-only Auto Settings provenance was accepted")
    AssertTrue(AutoSettingsFileSha256(orphanBackupPath) = orphanBackupCurrentHash,
        "Backup-only provenance changed current settings")
    AssertTrue(FileExist(orphanBackupPaths.backup),
        "Backup-only provenance evidence was deleted")
    AssertTrue(InStr(GetAutoSettingsLastError(), "backup and provenance metadata are not both present") > 0,
        "Backup-only provenance did not report the asymmetric lifecycle")
    AssertTrue(!RecoverPendingAutoSettings("", orphanBackupPath, neverRunning),
        "Recovery silently treated orphaned backup as no pending lifecycle")
    AssertTrue(FileExist(orphanBackupPaths.backup),
        "Recovery deleted orphaned backup evidence")

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
