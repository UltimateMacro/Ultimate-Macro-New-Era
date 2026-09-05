#Requires AutoHotkey v2.0
#SingleInstance Force

; This file is both an include used by Main.ahk and a tiny restore helper.
; Keep helper-only side effects inside the standalone guard so including this
; library never hides or otherwise mutates the main process UI.
global AutoSettingsLastErrorMessage := ""

if (A_ScriptFullPath == A_LineFile) {
    A_IconHidden := true
    restoreToken := A_Args.Length >= 1 ? A_Args[1] : ""
    WaitForRobloxExitAndRestore(restoreToken)
    ExitApp()
}

AutoSettingsPaths(settingsPath := "") {
    if (settingsPath = "")
        settingsPath := EnvGet("LOCALAPPDATA") "\Roblox\GlobalBasicSettings_13.xml"
    return {
        settings: settingsPath,
        backup: settingsPath ".macro_bak",
        backupTemp: settingsPath ".macro_backup_tmp",
        metadata: settingsPath ".macro_bak.meta",
        metadataTemp: settingsPath ".macro_meta_tmp",
        applyTemp: settingsPath ".macro_apply_tmp",
        restoreTemp: settingsPath ".macro_restore_tmp",
        restoreRequest: settingsPath ".macro_restore_requested",
        requestTemp: settingsPath ".macro_request_tmp",
        errorLog: settingsPath ".macro_error.log"
    }
}

AutoSettingsBackupExists(settingsPath := "") {
    paths := AutoSettingsPaths(settingsPath)
    return FileExist(paths.backup) != ""
}

GetAutoSettingsLastError() {
    global AutoSettingsLastErrorMessage
    return IsSet(AutoSettingsLastErrorMessage) ? AutoSettingsLastErrorMessage : ""
}

AutoSettingsClearLastError() {
    global AutoSettingsLastErrorMessage
    AutoSettingsLastErrorMessage := ""
}

AutoSettingsFail(message, paths := "") {
    global AutoSettingsLastErrorMessage
    AutoSettingsLastErrorMessage := message
    if IsObject(paths) {
        try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") "`t" StrReplace(message, "`n", " ") "`n",
            paths.errorLog, "UTF-8")
    }
    return false
}

AutoSettingsManagedTargets() {
    return Map(
        "CameraMode", { tag: "token", value: "0" },
        "ChatVisible", { tag: "bool", value: "false" },
        "FramerateCap", { tag: "int", value: "60" },
        "Fullscreen", { tag: "bool", value: "false" },
        "GraphicsOptimizationMode", { tag: "token", value: "1" },
        "GraphicsQualityLevel", { tag: "int", value: "1" },
        "HasEverUsedVR", { tag: "bool", value: "false" },
        "OnScreenProfilerEnabled", { tag: "bool", value: "false" },
        "PerformanceStatsVisible", { tag: "bool", value: "true" },
        "SavedQualityLevel", { tag: "token", value: "1" },
        "PlayerListVisible", { tag: "bool", value: "false" },
        "UiNavigationKeyBindEnabled", { tag: "bool", value: "true" },
        "VREnabled", { tag: "bool", value: "false" }
    )
}

AutoSettingsParseXml(xmlContent) {
    try document := ComObject("Msxml2.DOMDocument.6.0")
    catch Error as err
        throw Error("Windows XML parser is unavailable: " err.Message)

    document.async := false
    document.validateOnParse := false
    document.resolveExternals := false
    try document.setProperty("ProhibitDTD", true)
    if !document.loadXML(xmlContent)
        throw Error("Roblox settings XML is invalid: " document.parseError.reason)
    if !document.documentElement || StrLower(document.documentElement.nodeName) != "roblox"
        throw Error("Roblox settings XML does not have a roblox root element")
    return document
}

AutoSettingsValidateXml(xmlContent, requireManaged := false) {
    document := AutoSettingsParseXml(xmlContent)
    if !requireManaged
        return document

    for key, target in AutoSettingsManagedTargets() {
        nodes := document.selectNodes("//*[@name='" key "']")
        if (nodes.length != 1)
            throw Error("Managed Auto Settings node count is not one: " key)
        node := nodes.item(0)
        if (StrLower(node.nodeName) != target.tag || Trim(node.text) != target.value)
            throw Error("Managed Auto Settings node has an unexpected value: " key)
    }
    return document
}

TransformAutoSettingsXml(xmlContent) {
    sourceDocument := AutoSettingsParseXml(xmlContent)

    for key, target in AutoSettingsManagedTargets() {
        nodes := sourceDocument.selectNodes("//*[@name='" key "']")
        if (nodes.length > 1)
            throw Error("Refusing to transform duplicate Auto Settings nodes: " key)
        if (nodes.length = 1) {
            existingTag := StrLower(nodes.item(0).nodeName)
            if !(existingTag = "token" || existingTag = "bool" || existingTag = "int")
                throw Error("Refusing to replace an unexpected Auto Settings node type: " key)
        }

        replacement := "<" target.tag ' name="' key '">' target.value "</" target.tag ">"
        pattern := 'i)<(token|bool|int)\s+name="' key '">[^<]*</\1>'
        if (nodes.length = 1) {
            xmlContent := RegExReplace(xmlContent, pattern, replacement, &replacementCount, 1)
            if (replacementCount != 1)
                throw Error("Could not replace existing Auto Settings node: " key)
        } else {
            xmlContent := RegExReplace(xmlContent, "i)(</roblox>\s*)$", "`t" replacement "`r`n$1",
                &insertionCount, 1)
            if (insertionCount != 1)
                throw Error("Could not insert missing Auto Settings node: " key)
        }
    }

    AutoSettingsValidateXml(xmlContent, true)
    return xmlContent
}

AutoSettingsSha256Buffer(data) {
    if !IsObject(data)
        throw Error("SHA-256 input must be a Buffer")

    algorithm := 0
    hashHandle := 0
    try {
        status := DllCall("bcrypt\BCryptOpenAlgorithmProvider", "Ptr*", &algorithm,
            "WStr", "SHA256", "Ptr", 0, "UInt", 0, "Int")
        if (status != 0)
            throw Error("BCryptOpenAlgorithmProvider failed: " status)

        objectLength := 0
        resultLength := 0
        status := DllCall("bcrypt\BCryptGetProperty", "Ptr", algorithm, "WStr", "ObjectLength",
            "UInt*", &objectLength, "UInt", 4, "UInt*", &resultLength, "UInt", 0, "Int")
        if (status != 0 || objectLength <= 0)
            throw Error("BCryptGetProperty(ObjectLength) failed: " status)

        digestLength := 0
        status := DllCall("bcrypt\BCryptGetProperty", "Ptr", algorithm, "WStr", "HashDigestLength",
            "UInt*", &digestLength, "UInt", 4, "UInt*", &resultLength, "UInt", 0, "Int")
        if (status != 0 || digestLength != 32)
            throw Error("BCryptGetProperty(HashDigestLength) failed: " status)

        hashObject := Buffer(objectLength, 0)
        digestBuffer := Buffer(digestLength, 0)
        status := DllCall("bcrypt\BCryptCreateHash", "Ptr", algorithm, "Ptr*", &hashHandle,
            "Ptr", hashObject.Ptr, "UInt", hashObject.Size, "Ptr", 0, "UInt", 0, "UInt", 0, "Int")
        if (status != 0)
            throw Error("BCryptCreateHash failed: " status)

        status := DllCall("bcrypt\BCryptHashData", "Ptr", hashHandle, "Ptr", data.Ptr,
            "UInt", data.Size, "UInt", 0, "Int")
        if (status != 0)
            throw Error("BCryptHashData failed: " status)
        status := DllCall("bcrypt\BCryptFinishHash", "Ptr", hashHandle, "Ptr", digestBuffer.Ptr,
            "UInt", digestBuffer.Size, "UInt", 0, "Int")
        if (status != 0)
            throw Error("BCryptFinishHash failed: " status)

        digest := ""
        loop digestBuffer.Size
            digest .= Format("{:02x}", NumGet(digestBuffer, A_Index - 1, "UChar"))
        return digest
    } finally {
        if (hashHandle)
            DllCall("bcrypt\BCryptDestroyHash", "Ptr", hashHandle)
        if (algorithm)
            DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr", algorithm, "UInt", 0)
    }
}

AutoSettingsFileSha256(path) {
    if !FileExist(path)
        throw Error("File is missing for SHA-256 verification: " path)
    return AutoSettingsSha256Buffer(FileRead(path, "RAW"))
}

AutoSettingsValidateFile(path, requireManaged := false) {
    if !FileExist(path) || FileGetSize(path) <= 0
        throw Error("Roblox settings file is missing or empty: " path)
    AutoSettingsValidateXml(FileRead(path), requireManaged)
    return true
}

AutoSettingsAcquireMutex(timeoutMs := 5000) {
    mutex := DllCall("kernel32\CreateMutexW", "Ptr", 0, "Int", 0,
        "WStr", "Local\UltimateMacro_AutoSettings_v1", "Ptr")
    if !mutex
        return 0
    waitResult := DllCall("kernel32\WaitForSingleObject", "Ptr", mutex, "UInt", timeoutMs, "UInt")
    if (waitResult = 0 || waitResult = 0x80)
        return mutex
    DllCall("kernel32\CloseHandle", "Ptr", mutex)
    return 0
}

AutoSettingsReleaseMutex(mutex) {
    if !mutex
        return
    DllCall("kernel32\ReleaseMutex", "Ptr", mutex)
    DllCall("kernel32\CloseHandle", "Ptr", mutex)
}

AutoSettingsNewGeneration() {
    return FormatTime(A_NowUTC, "yyyyMMddHHmmss") "-" DllCall("kernel32\GetCurrentProcessId", "UInt") "-" A_TickCount "-" Random(100000, 999999)
}

AutoSettingsReadBackupState(paths) {
    backupExists := FileExist(paths.backup) != ""
    metadataExists := FileExist(paths.metadata) != ""
    if (!backupExists && !metadataExists)
        return { status: "none" }
    if (!backupExists || !metadataExists)
        return { status: "unknown", reason: "backup and provenance metadata are not both present" }

    try {
        formatVersion := IniRead(paths.metadata, "AutoSettingsBackup", "Format", "")
        generation := IniRead(paths.metadata, "AutoSettingsBackup", "Generation", "")
        backupHash := StrLower(IniRead(paths.metadata, "AutoSettingsBackup", "BackupSha256", ""))
        appliedHash := StrLower(IniRead(paths.metadata, "AutoSettingsBackup", "AppliedSha256", ""))
        if (formatVersion != "1")
            throw Error("unsupported backup metadata format")
        if !RegExMatch(generation, "^[0-9]{14}-[0-9]+-[0-9]+-[0-9]+$")
            throw Error("invalid backup generation")
        if !RegExMatch(backupHash, "^[0-9a-f]{64}$") || !RegExMatch(appliedHash, "^[0-9a-f]{64}$")
            throw Error("invalid backup metadata hash")
        AutoSettingsValidateFile(paths.backup)
        if (AutoSettingsFileSha256(paths.backup) != backupHash)
            throw Error("backup SHA-256 does not match provenance metadata")
        return {
            status: "trusted",
            generation: generation,
            backupHash: backupHash,
            appliedHash: appliedHash
        }
    } catch Error as err {
        return { status: "unknown", reason: err.Message }
    }
}

AutoSettingsClassifyCurrent(paths, backupState) {
    AutoSettingsValidateFile(paths.settings)
    currentHash := AutoSettingsFileSha256(paths.settings)
    if (currentHash = backupState.backupHash)
        return { status: "backup", hash: currentHash }
    if (currentHash = backupState.appliedHash)
        return { status: "applied_exact", hash: currentHash }

    try AutoSettingsValidateFile(paths.settings, true)
    catch Error as err
        return { status: "foreign", hash: currentHash, reason: err.Message }
    return { status: "applied_semantic", hash: currentHash }
}

AutoSettingsClassifierReason(currentState) {
    fallback := "Managed-state validation failed"
    if !IsObject(currentState) || !currentState.HasProp("reason")
        return fallback

    reason := Trim(String(currentState.reason))
    if (reason = "")
        return fallback

    ; Keep diagnostics single-line and bounded. Validation reasons identify the
    ; failing managed node or parser condition, never the user's XML values.
    reason := RegExReplace(reason, "[\r\n\t]+", " ")
    return SubStr(reason, 1, 300)
}

AutoSettingsWriteMetadata(paths, generation, backupHash, appliedHash) {
    try {
        if FileExist(paths.metadataTemp)
            FileDelete(paths.metadataTemp)
        IniWrite("1", paths.metadataTemp, "AutoSettingsBackup", "Format")
        IniWrite(generation, paths.metadataTemp, "AutoSettingsBackup", "Generation")
        IniWrite(backupHash, paths.metadataTemp, "AutoSettingsBackup", "BackupSha256")
        IniWrite(appliedHash, paths.metadataTemp, "AutoSettingsBackup", "AppliedSha256")
        FileMove(paths.metadataTemp, paths.metadata, 0)
        state := AutoSettingsReadBackupState(paths)
        return state.status = "trusted" && state.generation = generation
            && state.backupHash = backupHash && state.appliedHash = appliedHash
    } catch Error as err {
        return false
    }
}

AutoSettingsWriteRestoreRequest(paths, token) {
    try {
        if FileExist(paths.requestTemp)
            FileDelete(paths.requestTemp)
        request := FileOpen(paths.requestTemp, "w", "UTF-8")
        if !IsObject(request)
            return false
        request.Write(token)
        request.Close()
        FileMove(paths.requestTemp, paths.restoreRequest, 1)
        return AutoSettingsRestoreRequestMatches(paths, token)
    } catch Error as err {
        return false
    }
}

AutoSettingsRestoreRequestMatches(paths, token) {
    if (token = "" || !FileExist(paths.restoreRequest))
        return false
    try return Trim(FileRead(paths.restoreRequest)) = token
    catch Error as err
        return false
}

AutoSettingsCancelRestoreUnlocked(paths) {
    try {
        if FileExist(paths.restoreRequest)
            FileDelete(paths.restoreRequest)
        return !FileExist(paths.restoreRequest)
    } catch Error as err {
        return false
    }
}

CancelPendingAutoSettingsRestore(settingsPath := "") {
    paths := AutoSettingsPaths(settingsPath)
    mutex := AutoSettingsAcquireMutex()
    if !mutex
        return AutoSettingsFail("Could not acquire the Auto Settings lifecycle mutex", paths)
    try {
        if !AutoSettingsCancelRestoreUnlocked(paths)
            return AutoSettingsFail("Could not cancel the pending Auto Settings restore request", paths)
        AutoSettingsClearLastError()
        return true
    } finally AutoSettingsReleaseMutex(mutex)
}

MarkAutoSettingsRestoreRequested(settingsPath := "") {
    paths := AutoSettingsPaths(settingsPath)
    mutex := AutoSettingsAcquireMutex()
    if !mutex {
        AutoSettingsFail("Could not acquire the Auto Settings lifecycle mutex", paths)
        return ""
    }
    try {
        token := AutoSettingsNewGeneration()
        if !AutoSettingsWriteRestoreRequest(paths, token) {
            AutoSettingsFail("Could not persist the Auto Settings restore generation", paths)
            return ""
        }
        AutoSettingsClearLastError()
        return token
    } finally AutoSettingsReleaseMutex(mutex)
}

AutoSettingsWriteAppliedTemp(paths, xmlContent) {
    if FileExist(paths.applyTemp)
        FileDelete(paths.applyTemp)
    fileObj := FileOpen(paths.applyTemp, "w", "UTF-8")
    if !IsObject(fileObj)
        throw Error("Auto Settings temporary file could not be opened")
    fileObj.Write(xmlContent)
    fileObj.Close()
    AutoSettingsValidateFile(paths.applyTemp, true)
    return AutoSettingsFileSha256(paths.applyTemp)
}

AutoSettingsRobloxCommandLineIsTray(commandLine) {
    commandLine := Trim(String(commandLine))
    return commandLine != "" && RegExMatch(commandLine, "i)(?:^|\s)--launch-to-tray(?:\s|$)")
}

AutoSettingsRobloxSessionActive(robloxProcess := "RobloxPlayerBeta.exe") {
    if !ProcessExist(robloxProcess)
        return false

    ; Test fixtures and callers may provide a synthetic process name. Preserve
    ; the old ProcessExist behavior unless this is the real Roblox executable.
    if (StrLower(String(robloxProcess)) != "robloxplayerbeta.exe")
        return true

    try {
        sawRoblox := false
        query := "Select ProcessId, CommandLine from Win32_Process where Name='RobloxPlayerBeta.exe'"
        for process in ComObjGet("winmgmts:").ExecQuery(query) {
            sawRoblox := true
            commandLine := ""
            try commandLine := String(process.CommandLine)
            catch Error
                return true

            ; A real game process must keep blocking settings replacement. The
            ; only process identity ignored here is Roblox's windowless tray
            ; launcher, observed in live QA as `--launch-to-tray`.
            if !AutoSettingsRobloxCommandLineIsTray(commandLine)
                return true

            ; Be conservative if a nominal tray process owns a normal window.
            try {
                if WinExist("ahk_pid " process.ProcessId)
                    return true
            } catch Error {
                return true
            }
        }

        if sawRoblox
            return false

        ; ProcessExist and WMI can race. If the name still exists but WMI did
        ; not enumerate it, fail closed rather than restoring under uncertainty.
        return ProcessExist(robloxProcess) != 0
    } catch Error {
        ; WMI/COM inspection failure must never make an active game look closed.
        return true
    }
}

ApplyMacroSettings(settingsPath := "", robloxProcess := "RobloxPlayerBeta.exe") {
    paths := AutoSettingsPaths(settingsPath)
    if AutoSettingsRobloxSessionActive(robloxProcess)
        return AutoSettingsFail("Roblox must be closed before Auto Settings can be applied", paths)

    mutex := AutoSettingsAcquireMutex()
    if !mutex
        return AutoSettingsFail("Could not acquire the Auto Settings lifecycle mutex", paths)

    try {
        if AutoSettingsRobloxSessionActive(robloxProcess)
            return AutoSettingsFail("Roblox reopened before Auto Settings preparation", paths)
        if !AutoSettingsCancelRestoreUnlocked(paths)
            return AutoSettingsFail("Could not cancel a pending Auto Settings restore request", paths)
        if !FileExist(paths.settings)
            return AutoSettingsFail("Roblox settings XML was not found", paths)

        try {
            AutoSettingsValidateFile(paths.settings)
            currentHash := AutoSettingsFileSha256(paths.settings)
            backupState := AutoSettingsReadBackupState(paths)
            if (backupState.status = "unknown")
                return AutoSettingsFail("Unknown Auto Settings backup was preserved: " backupState.reason, paths)

            if (backupState.status = "none") {
                transformedXml := TransformAutoSettingsXml(FileRead(paths.settings))
                appliedHash := AutoSettingsWriteAppliedTemp(paths, transformedXml)
                if FileExist(paths.backupTemp)
                    FileDelete(paths.backupTemp)
                FileCopy(paths.settings, paths.backupTemp, 0)
                AutoSettingsValidateFile(paths.backupTemp)
                backupHash := AutoSettingsFileSha256(paths.backupTemp)
                if (backupHash != currentHash)
                    throw Error("Original backup copy failed SHA-256 verification")
                FileMove(paths.backupTemp, paths.backup, 0)
                generation := AutoSettingsNewGeneration()
                if !AutoSettingsWriteMetadata(paths, generation, backupHash, appliedHash)
                    return AutoSettingsFail("Original backup was preserved, but provenance metadata could not be verified", paths)
                backupState := AutoSettingsReadBackupState(paths)
            } else {
                currentState := AutoSettingsClassifyCurrent(paths, backupState)
                if (currentState.status = "foreign")
                    return AutoSettingsFail("Current Roblox settings no longer match the verified backup or macro-applied state. Reason: "
                        AutoSettingsClassifierReason(currentState), paths)
                if (currentState.status = "applied_exact" || currentState.status = "applied_semantic") {
                    AutoSettingsClearLastError()
                    return true
                }

                transformedXml := TransformAutoSettingsXml(FileRead(paths.settings))
                appliedHash := AutoSettingsWriteAppliedTemp(paths, transformedXml)
                if (appliedHash != backupState.appliedHash)
                    return AutoSettingsFail("Macro-applied settings identity changed while a backup was pending", paths)
            }

            if (backupState.status != "trusted")
                return AutoSettingsFail("Auto Settings backup provenance could not be established", paths)
            if AutoSettingsRobloxSessionActive(robloxProcess)
                return AutoSettingsFail("Roblox reopened immediately before Auto Settings replacement", paths)

            FileMove(paths.applyTemp, paths.settings, 1)
            AutoSettingsValidateFile(paths.settings, true)
            if (AutoSettingsFileSha256(paths.settings) != backupState.appliedHash)
                throw Error("Installed Auto Settings file failed SHA-256 verification")
            AutoSettingsClearLastError()
            return true
        } catch Error as err {
            return AutoSettingsFail(err.Message, paths)
        }
    } finally {
        for tempPath in [paths.applyTemp, paths.backupTemp] {
            try {
                if FileExist(tempPath)
                    FileDelete(tempPath)
            }
        }
        AutoSettingsReleaseMutex(mutex)
    }
}

RestoreOriginalSettings(expectedToken := "", settingsPath := "", robloxProcess := "RobloxPlayerBeta.exe") {
    paths := AutoSettingsPaths(settingsPath)
    mutex := AutoSettingsAcquireMutex()
    if !mutex
        return AutoSettingsFail("Could not acquire the Auto Settings lifecycle mutex", paths)

    try {
        if !AutoSettingsRestoreRequestMatches(paths, expectedToken)
            return AutoSettingsFail("Restore generation is missing, cancelled, or superseded", paths)
        if AutoSettingsRobloxSessionActive(robloxProcess)
            return AutoSettingsFail("Roblox is running; restore remains pending", paths)

        state := AutoSettingsReadBackupState(paths)
        if (state.status = "none") {
            if !AutoSettingsCancelRestoreUnlocked(paths)
                return AutoSettingsFail("Could not clear a completed restore request", paths)
            AutoSettingsClearLastError()
            return true
        }
        if (state.status != "trusted")
            return AutoSettingsFail("Unknown Auto Settings backup was preserved: " state.reason, paths)

        try {
            currentState := AutoSettingsClassifyCurrent(paths, state)
            if (currentState.status = "foreign")
                return AutoSettingsFail("Current Roblox settings changed after macro application; backup was preserved. Reason: "
                    AutoSettingsClassifierReason(currentState), paths)

            if (currentState.status != "backup") {
                if FileExist(paths.restoreTemp)
                    FileDelete(paths.restoreTemp)
                FileCopy(paths.backup, paths.restoreTemp, 0)
                AutoSettingsValidateFile(paths.restoreTemp)
                if (AutoSettingsFileSha256(paths.restoreTemp) != state.backupHash)
                    throw Error("Restore copy failed backup identity verification")

                ; Both checks are inside the lifecycle mutex and occur immediately
                ; before replacement. A superseded helper can never restore.
                if !AutoSettingsRestoreRequestMatches(paths, expectedToken)
                    return AutoSettingsFail("Restore generation was superseded before replacement", paths)
                if AutoSettingsRobloxSessionActive(robloxProcess)
                    return AutoSettingsFail("Roblox reopened immediately before restore; restore remains pending", paths)

                FileMove(paths.restoreTemp, paths.settings, 1)
                AutoSettingsValidateFile(paths.settings)
                if (AutoSettingsFileSha256(paths.settings) != state.backupHash)
                    throw Error("Restored Roblox settings failed backup identity verification")
            }

            if !AutoSettingsCancelRestoreUnlocked(paths)
                return AutoSettingsFail("Settings were restored, but the restore request could not be cleared", paths)
            FileDelete(paths.backup)
            if FileExist(paths.backup)
                throw Error("Verified backup could not be removed after restore")
            FileDelete(paths.metadata)
            if FileExist(paths.metadata)
                throw Error("Backup metadata could not be removed after restore")
            AutoSettingsClearLastError()
            return true
        } catch Error as err {
            return AutoSettingsFail(err.Message, paths)
        }
    } finally {
        try {
            if FileExist(paths.restoreTemp)
                FileDelete(paths.restoreTemp)
        }
        AutoSettingsReleaseMutex(mutex)
    }
}

ResolveAutoSettingsHelperExe(rootDir := "") {
    if (A_AhkPath != "" && FileExist(A_AhkPath))
        return A_AhkPath

    if (rootDir = "")
        rootDir := RegExReplace(A_LineFile, "i)\\lib\\auto_settings\.ahk$")

    bundled := rootDir "\submacros\" (A_PtrSize == 4 ? "AutoHotkey32.exe" : "AutoHotkey64.exe")
    return FileExist(bundled) ? bundled : ""
}

LaunchAutoSettingsRestoreHelper(token, rootDir := "") {
    helperExe := ResolveAutoSettingsHelperExe(rootDir)
    helperScript := A_LineFile
    if (token = "" || helperExe = "" || !FileExist(helperScript))
        return false

    try {
        Run('"' helperExe '" "' helperScript '" "' token '"', rootDir, "Hide", &helperPID)
        return helperPID > 0
    } catch Error as err {
        return false
    }
}

RequestAutoSettingsRestore(rootDir := "", settingsPath := "", robloxProcess := "RobloxPlayerBeta.exe") {
    paths := AutoSettingsPaths(settingsPath)
    mutex := AutoSettingsAcquireMutex()
    if !mutex
        return AutoSettingsFail("Could not acquire the Auto Settings lifecycle mutex", paths)
    try {
        state := AutoSettingsReadBackupState(paths)
        if (state.status = "none") {
            if !AutoSettingsCancelRestoreUnlocked(paths)
                return AutoSettingsFail("Could not clear a completed Auto Settings restore request", paths)
            AutoSettingsClearLastError()
            return true
        }
        if (state.status != "trusted")
            return AutoSettingsFail("Unknown Auto Settings backup was preserved: " state.reason, paths)
        currentState := AutoSettingsClassifyCurrent(paths, state)
        if (currentState.status = "foreign")
            return AutoSettingsFail("Current Roblox settings changed after macro application; backup was preserved. Reason: "
                AutoSettingsClassifierReason(currentState), paths)
        token := state.generation "-" A_TickCount "-" Random(100000, 999999)
        if !AutoSettingsWriteRestoreRequest(paths, token)
            return AutoSettingsFail("Could not persist the Auto Settings restore generation", paths)
    } catch Error as err {
        return AutoSettingsFail(err.Message, paths)
    } finally AutoSettingsReleaseMutex(mutex)

    if !AutoSettingsRobloxSessionActive(robloxProcess) {
        if RestoreOriginalSettings(token, settingsPath, robloxProcess)
            return true
        if !AutoSettingsRobloxSessionActive(robloxProcess)
            return false
    }
    if LaunchAutoSettingsRestoreHelper(token, rootDir) {
        AutoSettingsClearLastError()
        return true
    }
    return AutoSettingsFail("Could not launch the verified Auto Settings restore helper", paths)
}

RecoverPendingAutoSettings(rootDir := "", settingsPath := "", robloxProcess := "RobloxPlayerBeta.exe") {
    ; RequestAutoSettingsRestore owns the atomic backup/metadata classification.
    ; Never treat orphaned provenance as equivalent to no pending lifecycle.
    return RequestAutoSettingsRestore(rootDir, settingsPath, robloxProcess)
}

PrepareAutoSettingsForRobloxLaunch(enabled) {
    if !enabled
        return true
    if AutoSettingsRobloxSessionActive("RobloxPlayerBeta.exe") {
        paths := AutoSettingsPaths()
        return AutoSettingsFail("Roblox must be confirmed closed immediately before Auto Settings preparation", paths)
    }
    return ApplyMacroSettings()
}

WaitForRobloxExitAndRestore(expectedToken) {
    if (expectedToken = "")
        return false
    paths := AutoSettingsPaths()
    restoreDeadline := A_TickCount + 300000

    loop {
        if (A_TickCount >= restoreDeadline)
            return AutoSettingsFail("Timed out waiting for Roblox to exit and Auto Settings to restore", paths)
        if !AutoSettingsRestoreRequestMatches(paths, expectedToken)
            return true
        while AutoSettingsRobloxSessionActive("RobloxPlayerBeta.exe") {
            Sleep(1000)
            if !AutoSettingsRestoreRequestMatches(paths, expectedToken)
                return true
        }

        Sleep(2000)
        if !AutoSettingsRestoreRequestMatches(paths, expectedToken)
            return true
        if AutoSettingsRobloxSessionActive("RobloxPlayerBeta.exe")
            continue
        if RestoreOriginalSettings(expectedToken)
            return true
        if !AutoSettingsRobloxSessionActive("RobloxPlayerBeta.exe")
            return false
    }
}
