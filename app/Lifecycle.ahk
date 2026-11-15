; Own process handles, never kill scripts by filename or scan unrelated apps.
class OwnedProcess {
    static Quote(value) {
        if InStr(value, '"') || InStr(value, "`r") || InStr(value, "`n")
            throw ValueError("Invalid process argument.")
        return '"' value '"'
    }

    static Start(exe, args, workingDir, background := false) {
        command := OwnedProcess.Quote(exe)
        for arg in args
            command .= " " OwnedProcess.Quote(String(arg))
        text := Buffer(StrPut(command, "UTF-16") * 2, 0)
        StrPut(command, text, "UTF-16")
        startup := Buffer(A_PtrSize = 8 ? 104 : 68, 0), info := Buffer(A_PtrSize * 2 + 8, 0)
        NumPut("UInt", startup.Size, startup)
        NumPut("UInt", 1, startup, A_PtrSize = 8 ? 60 : 44)
        flags := 0x08000000 | (background ? 0x4000 : 0)
        if !DllCall("CreateProcessW", "WStr", exe, "Ptr", text, "Ptr", 0, "Ptr", 0, "Int", 0
            , "UInt", flags, "Ptr", 0, "WStr", workingDir, "Ptr", startup, "Ptr", info, "Int")
            throw OSError()
        DllCall("CloseHandle", "Ptr", NumGet(info, A_PtrSize, "Ptr"))
        return {handle: NumGet(info, 0, "Ptr"), pid: NumGet(info, A_PtrSize * 2, "UInt")}
    }

    static Finished(process) => !IsObject(process) || !process.handle
        || DllCall("WaitForSingleObject", "Ptr", process.handle, "UInt", 0, "UInt") = 0

    static ExitCode(process) {
        code := 259
        if IsObject(process) && process.handle
            DllCall("GetExitCodeProcess", "Ptr", process.handle, "UInt*", &code, "Int")
        return code
    }

    static Stop(process, graceful := true) {
        if !IsObject(process) || !process.handle
            return
        try {
            if !OwnedProcess.Finished(process) {
                if graceful {
                    before := A_DetectHiddenWindows
                    DetectHiddenWindows(true)
                    try {
                        for hwnd in WinGetList("ahk_class AutoHotkey ahk_pid " process.pid)
                            DllCall("PostMessageW", "Ptr", hwnd, "UInt", 0x10, "Ptr", 0, "Ptr", 0)
                    } finally DetectHiddenWindows(before)
                    DllCall("WaitForSingleObject", "Ptr", process.handle, "UInt", 750)
                }
                if !OwnedProcess.Finished(process) {
                    ; A live process handle cannot target a recycled PID.
                    DllCall("TerminateProcess", "Ptr", process.handle, "UInt", 0, "Int")
                    DllCall("WaitForSingleObject", "Ptr", process.handle, "UInt", 1000)
                }
            }
        } finally OwnedProcess.Release(process)
    }

    static Release(process) {
        if IsObject(process) && process.handle {
            DllCall("CloseHandle", "Ptr", process.handle)
            process.handle := 0
        }
    }
}

class OwnedWatchdog {
    static process := ""
    static Start(root) {
        OwnedWatchdog.Stop()
        OwnedWatchdog.process := OwnedProcess.Start(root "\submacros\AutoHotkey64.exe"
            , [root "\submacros\watchdog.ahk", String(DllCall("GetCurrentProcessId", "UInt"))], root)
        return OwnedWatchdog.process.pid
    }
    static Stop() {
        OwnedProcess.Stop(OwnedWatchdog.process)
        OwnedWatchdog.process := ""
    }
}

class OwnedParent {
    static process := ""
    static Attach(pid) {
        if !RegExMatch(String(pid), "\A[1-9][0-9]*\z")
            return false
        basic := Buffer(A_PtrSize * 6, 0)
        if DllCall("ntdll\NtQueryInformationProcess", "Ptr", DllCall("GetCurrentProcess", "Ptr"), "Int", 0
            , "Ptr", basic, "UInt", basic.Size, "Ptr", 0, "Int") != 0
            return false
        if NumGet(basic, A_PtrSize * 5, "UPtr") != Integer(pid)
            return false
        handle := DllCall("OpenProcess", "UInt", 0x101001, "Int", false, "UInt", Integer(pid), "Ptr")
        if !handle
            return false
        path := Buffer(32768 * 2, 0), count := 32768
        if !DllCall("QueryFullProcessImageNameW", "Ptr", handle, "UInt", 0, "Ptr", path, "UInt*", &count, "Int")
            || StrLower(StrGet(path, count, "UTF-16")) != StrLower(A_AhkPath) {
            DllCall("CloseHandle", "Ptr", handle)
            return false
        }
        OwnedParent.process := {handle: handle, pid: Integer(pid)}
        OnExit((*) => OwnedProcess.Release(OwnedParent.process))
        return true
    }
    ; Internal recovery retains the legacy state.ini restart semantics.
    static Close() => OwnedProcess.Stop(OwnedParent.process, false)
}
