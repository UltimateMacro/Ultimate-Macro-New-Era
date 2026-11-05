; Ultimate Macro 1.4 engine mode — shared helpers (engine, guard and tools).
; Part of a modified version of "Ultimate Macro" by Darksen, licensed GNU GPLv3.
; See ENGINE-NOTICE.md for what was changed and why. Original credit retained.
;
; Nothing received through these helpers is evaluated as code, run as a program,
; or passed to Send. Arguments only select an isolated data folder and identify
; the owning 1.4 launcher window/process and session.

global UM14 := {active: false, ready: false, session: "", data: "", hwnd: 0, pid: 0
    , seqOut: 0, seqIn: 0, queue: [], helloSent: false, early: []
    , recordStop: false, recordName: "", recordAdd: true, recordArgs: ""
    , recordSlot: 0, recordPassive: false, recordClicks: true, recordSales: false, recordAligned: false, recSteps: -1}

UM14_ParseArgs(args, first := 1) {
    out := Map()
    i := first
    while (i <= args.Length) {
        k := args[i]
        if (k == "--um14-engine") {
            if out.Has("engine")
                return ""
            out["engine"] := true
            i += 1
            continue
        }
        if (i < args.Length && (k == "--session" || k == "--data" || k == "--launcher-hwnd" || k == "--launcher-pid")) {
            if out.Has(k)
                return ""
            out[k] := args[i + 1]
            i += 2
            continue
        }
        return ""
    }
    for need in ["engine", "--session", "--data", "--launcher-hwnd", "--launcher-pid"]
        if !out.Has(need)
            return ""
    if !RegExMatch(out["--session"], "^[0-9a-f]{32}$")
        return ""
    data := out["--data"]
    if (!RegExMatch(data, "^[A-Za-z]:\\[^\x22*?<>|]{1,240}$") || InStr(data, "..") || !DirExist(data))
        return ""
    if (!RegExMatch(out["--launcher-hwnd"], "^[1-9]\d{0,19}$") || !RegExMatch(out["--launcher-pid"], "^[1-9]\d{0,9}$"))
        return ""
    return out
}

UM14_Apply(out) {
    global UM14
    UM14.session := out["--session"]
    UM14.data := RTrim(out["--data"], "\")
    UM14.hwnd := Integer(out["--launcher-hwnd"])
    UM14.pid := Integer(out["--launcher-pid"])
}

; The launcher uses a message-only window, which WinExist cannot see: ask Windows directly.
UM14_LauncherAlive() {
    global UM14
    if (!UM14.hwnd || !DllCall("IsWindow", "Ptr", UM14.hwnd))
        return false
    owner := 0
    DllCall("GetWindowThreadProcessId", "Ptr", UM14.hwnd, "UInt*", &owner)
    return owner == UM14.pid
}

UM14_SessionCurrent() {
    global UM14
    return IniRead(UM14.data "\state.ini", "State", "Session", "") == UM14.session
}

UM14_ArgString() {
    global UM14
    return '--um14-engine --session ' UM14.session ' --data "' UM14.data '" --launcher-hwnd ' UM14.hwnd ' --launcher-pid ' UM14.pid
}

; For the standalone tools (auto CoA / spin / consumables): settings folder from --data only.
UM14_ToolOptions() {
    for i, a in A_Args {
        if (a == "--data" && i < A_Args.Length) {
            data := A_Args[i + 1]
            if (RegExMatch(data, "^[A-Za-z]:\\[^\x22*?<>|]{1,240}$") && !InStr(data, "..") && DirExist(data))
                return RTrim(data, "\") "\Options"
        }
    }
    MsgBox("Start this tool from Ultimate Macro 1.4.", "Ultimate Macro", 0x10)
    ExitApp(2)
}

; Key-up for anything the engine may be holding. A strategy's Send("key", hold:=N) may hold any
; single key, so every keyboard key that is down is released, plus the mouse buttons.
UM14_ReleaseInputs() {
    global UM14_ReplayHeld
    if IsSet(UM14_ReplayHeld)
        UM14_ReplayHeld.Clear()
    Loop 247 {
        key := Format("vk{:02X}", A_Index + 7) ; vk08 .. vkFE
        try {
            if GetKeyState(key)
                SendEvent("{Blind}{" key " up}")
        }
    }
    for key in ["LButton", "RButton", "MButton", "XButton1", "XButton2"] {
        try {
            if GetKeyState(key)
                SendEvent("{Blind}{" key " up}")
        }
    }
}
