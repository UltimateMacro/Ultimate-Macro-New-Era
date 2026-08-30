#Requires AutoHotkey v2.0

; Persistent runtime/crash logging for Ultimate Macro.
; Logs are intentionally local-only and redact common secret formats before write.

global RuntimeLogState := {
    Installed: false,
    Component: "Unknown",
    Version: "",
    Dir: "",
    SessionFile: "",
    StartTick: 0
}

RuntimeLogInstall(component := "Main", version := "") {
    global RuntimeLogState

    if (RuntimeLogState.Installed)
        return RuntimeLogState.SessionFile

    logDir := A_AppData "\Ultimate_Macro\Logs"
    try {
        if !DirExist(logDir)
            DirCreate(logDir)
    } catch {
        return ""
    }

    safeComponent := RegExReplace(component, "[^A-Za-z0-9_.-]", "_")
    stamp := FormatTime(, "yyyyMMdd-HHmmss")
    pid := DllCall("Kernel32\GetCurrentProcessId", "UInt")
    sessionFile := logDir "\" safeComponent "-" stamp "-pid" pid ".log"

    RuntimeLogState := {
        Installed: true,
        Component: component,
        Version: version,
        Dir: logDir,
        SessionFile: sessionFile,
        StartTick: A_TickCount
    }

    RuntimeLogPrune(14)
    RuntimeLogWrite("INFO", "session_start", "Runtime logging initialized",
        "version=" version "; ahk=" A_AhkVersion "; os=" A_OSVersion "; 64bit=" (A_PtrSize = 8 ? "yes" : "no"))

    ; Keep normal AutoHotkey error behavior. The callback records the exception
    ; and returns 0 so the normal error UI/termination semantics still apply.
    OnError(RuntimeLogOnError)
    OnExit(RuntimeLogOnExit)

    return sessionFile
}

RuntimeLogInfo(event, message := "", details := "") {
    RuntimeLogWrite("INFO", event, message, details)
}

RuntimeLogWarn(event, message := "", details := "") {
    RuntimeLogWrite("WARN", event, message, details)
}

RuntimeLogError(event, message := "", details := "") {
    RuntimeLogWrite("ERROR", event, message, details)
}

RuntimeLogWrite(level, event, message := "", details := "") {
    global RuntimeLogState

    if (!RuntimeLogState.Installed || RuntimeLogState.SessionFile = "")
        return false

    try {
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        uptimeMs := Max(0, A_TickCount - RuntimeLogState.StartTick)
        line := timestamp " | " StrUpper(level) " | " RuntimeLogState.Component
        line .= " | " RuntimeLogRedact(event) " | uptime_ms=" uptimeMs

        if (message != "")
            line .= " | " RuntimeLogRedact(message)
        if (details != "")
            line .= " | " RuntimeLogRedact(details)

        line := StrReplace(StrReplace(line, "`r", " "), "`n", " ")
        FileAppend(line "`n", RuntimeLogState.SessionFile, "UTF-8")
        return true
    } catch {
        ; Logging must never crash the macro or recurse through OnError.
        return false
    }
}

RuntimeLogOnError(err, mode) {
    global RuntimeLogState

    try {
        details := "mode=" mode
        try details .= "; what=" err.What
        try details .= "; file=" RuntimeLogSafeFile(err.File)
        try details .= "; line=" err.Line
        try details .= "; extra=" err.Extra
        try details .= "; stack=" err.Stack

        message := "Unhandled AutoHotkey error"
        try message := err.Message

        RuntimeLogWrite("FATAL", "unhandled_exception", message, details)

        ; Keep one easy-to-find copy for testers/support while retaining the
        ; timestamped session log as the authoritative history.
        if (RuntimeLogState.Dir != "") {
            crashPath := RuntimeLogState.Dir "\last-crash.log"
            crashText := "Ultimate Macro crash report`n"
            crashText .= "Timestamp: " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`n"
            crashText .= "Component: " RuntimeLogState.Component "`n"
            crashText .= "Version: " RuntimeLogState.Version "`n"
            crashText .= "Message: " RuntimeLogRedact(message) "`n"
            crashText .= "Details: " RuntimeLogRedact(details) "`n"
            crashText .= "Session log: " RuntimeLogSafeFile(RuntimeLogState.SessionFile) "`n"
            try {
                if FileExist(crashPath)
                    FileDelete(crashPath)
                FileAppend(crashText, crashPath, "UTF-8")
            }
        }
    }

    return 0
}

RuntimeLogOnExit(exitReason, exitCode) {
    try RuntimeLogWrite("INFO", "session_exit", "AutoHotkey process exiting",
        "reason=" exitReason "; code=" exitCode)
}

RuntimeLogSafeFile(path) {
    if (path = "")
        return ""
    try {
        return RegExReplace(path, "i)^.*\\", "")
    } catch {
        return path
    }
}

RuntimeLogRedact(value) {
    text := String(value)

    ; Discord webhook URLs contain a secret token in the path.
    text := RegExReplace(
        text,
        "i)https://(?:canary\.|ptb\.)?discord(?:app)?\.com/api/webhooks/[0-9]+/[A-Za-z0-9._-]+",
        "[REDACTED_DISCORD_WEBHOOK]"
    )

    ; Avoid leaking common key/value secret fields into tester evidence.
    text := RegExReplace(
        text,
        "i)\b(BotToken|Authorization|WebhookLink|Token)\s*[:=]\s*[^;|\s]+",
        "$1=[REDACTED]"
    )

    return text
}

RuntimeLogPrune(maxAgeDays := 14) {
    global RuntimeLogState
    if (RuntimeLogState.Dir = "" || !DirExist(RuntimeLogState.Dir))
        return

    try {
        Loop Files, RuntimeLogState.Dir "\*.log", "F" {
            if (A_LoopFileFullPath = RuntimeLogState.SessionFile)
                continue
            try {
                if (DateDiff(A_Now, A_LoopFileTimeModified, "Days") > maxAgeDays)
                    FileDelete(A_LoopFileFullPath)
            }
        }
    }
}

RuntimeLogDirectory() {
    global RuntimeLogState
    return RuntimeLogState.Dir
}
