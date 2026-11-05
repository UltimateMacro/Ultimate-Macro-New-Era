; Ultimate Macro 1.4 engine mode — helpers for the run guard (was submacros\watchdog.ahk).
; Part of a modified version of "Ultimate Macro" by Darksen, licensed GNU GPLv3.

#Include "%A_LineFile%\..\UM14Shared.ahk"
#Include "%A_LineFile%\..\UM14Stats.ahk"
#Include "%A_LineFile%\..\UM14Match.ahk"

UM14_GuardInit() {
    global UM14
    out := UM14_ParseArgs(A_Args, 2)
    if !IsObject(out)
        ExitApp(2)
    UM14_Apply(out)
    if (!UM14_LauncherAlive() || !UM14_SessionCurrent())
        ExitApp(4)
    UM14.guardRun := IniRead(UM14.data "\state.ini", "State", "MatchRun", "")
    UM14.matchCandidate := ""
}

; 1.3.3a closed MainPID unconditionally (PID reuse could hit another program) and every
; AutoHotkey process whose command line contained "Main.ahk". Only close our own engine.
UM14_CloseOwnedEngines() {
    global UM14
    try {
        for process in ComObjGet("winmgmts:").ExecQuery("SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name LIKE 'AutoHotkey%'") {
            cmd := process.CommandLine
            if (cmd != "" && InStr(cmd, "UM14Engine.ahk") && InStr(cmd, UM14.session, true))
                try ProcessClose(process.ProcessId)
        }
    }
}

UM14_LaunchEngine() {
    global UM14
    if (!UM14_LauncherAlive() || !UM14_SessionCurrent())
        ExitApp()
    Run('"' A_AhkPath '" "' A_WorkingDir '\UM14Engine.ahk" ' UM14_ArgString())
}

UM14_GuardMatchAction(result, width, height) {
    global UM14, StateFile, SettingsFile
    if (!UM14_LauncherAlive() || !UM14_SessionCurrent()
        || !RegExMatch(UM14.guardRun, "^[a-f0-9]{32}$")
        || IniRead(StateFile, "State", "MatchRun", "") != UM14.guardRun
        || IniRead(StateFile, "State", "Running", "0") != "1"
        || !RegExMatch(IniRead(StateFile, "State", "TimeWhenStartedPlaying", ""), "^[1-9]\d{0,18}$"))
        return "pending"
    evidence := UM14_MatchScreenEvidence(result, width, height)
    UM14.matchCandidate := UM14_ObserveMatchResult(UM14.matchCandidate, result, evidence, A_TickCount, UM14.guardRun)
    if (!UM14.matchCandidate.ready)
        return "pending"
    return IniRead(SettingsFile, "Options", "Repeat", "1") == "0" ? "stop" : "repeat"
}

UM14_GuardSingleMatch(result) {
    global UM14, StateFile
    if (!UM14_LauncherAlive() || !UM14_SessionCurrent()
        || IniRead(StateFile, "State", "MatchRun", "") != UM14.guardRun
        || (result != "Triumph" && result != "Loss"))
        return false
    IniWrite(UM14.session "|" UM14.guardRun "|" result, StateFile, "State", "MatchCompletion")
    return true
}
