; Local-only health sampler. The worker never receives credentials and cannot
; issue macro commands; it only writes a bounded, short-lived JSON snapshot.
class DashboardHealth {
    static output := A_AppData "\Ultimate_Macro\Dashboard-health.json"
    static workerPid := 0
    static process := ""
    static maxBytes := 16384

    static Start() {
        if !Dashboard.token
            return false
        if IsObject(DashboardHealth.process) && !OwnedProcess.Finished(DashboardHealth.process)
            return true
        worker := A_ScriptDir "\app\DashboardHealthWorker.ps1"
        powershell := A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe"
        if (!FileExist(worker) || !FileExist(powershell))
            return false
        try {
            DashboardHealth.process := OwnedProcess.Start(powershell
                , ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", worker
                    , "-ParentPid", String(DllCall("GetCurrentProcessId", "UInt")), "-OutputPath", DashboardHealth.output]
                , A_ScriptDir, true)
            DashboardHealth.workerPid := DashboardHealth.process.pid
            return true
        } catch {
            DashboardHealth.workerPid := 0
            return false
        }
    }

    static Stop() {
        OwnedProcess.Stop(DashboardHealth.process)
        DashboardHealth.process := ""
        DashboardHealth.workerPid := 0
    }

    static Read() {
        if !FileExist(DashboardHealth.output)
            return JSON.null
        try {
            if (FileGetSize(DashboardHealth.output) > DashboardHealth.maxBytes)
                return JSON.null
            value := JSON.parse(FileRead(DashboardHealth.output, "UTF-8"))
            if !(value is Map) || !value.Has("sampledAt")
                return JSON.null
            sampled := value["sampledAt"]
            if !(sampled is String) || StrLen(sampled) > 40
                return JSON.null
            ; Never relay stale readings as current device health.
            if !RegExMatch(sampled, "\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,7})?Z\z")
                return JSON.null
            compact := RegExReplace(SubStr(sampled, 1, 19), "\D")
            if !IsTime(compact)
                return JSON.null
            age := DateDiff(A_NowUTC, compact, "Seconds")
            if (age < -5 || age > 45)
                return JSON.null
            return value
        } catch {
            return JSON.null
        }
    }

    static CloseSelected(payload) {
        if !(payload is Map) || !payload.Has("pid") || !payload.Has("name") || !payload.Has("startedAt")
            return false
        pid := payload["pid"], name := payload["name"], startedAt := payload["startedAt"]
        if (!(pid is Integer) || pid <= 4 || pid = DllCall("GetCurrentProcessId", "UInt")
            || !(name is String) || !RegExMatch(name, "i)^[a-z0-9_. -]{1,80}$")
            || !(startedAt is String) || !RegExMatch(startedAt, "^\d{14}$"))
            return false
        protected := Map("system", true, "idle", true, "registry", true, "smss", true, "csrss", true,
            "wininit", true, "services", true, "lsass", true, "svchost", true, "winlogon", true,
            "dwm", true, "fontdrvhost", true, "powershell", true, "autohotkey64", true)
        if protected.Has(StrLower(name))
            return false
        health := DashboardHealth.Read(), reported := false
        if (health is Map) && health.Has("processes") && (health["processes"] is Array)
            for item in health["processes"]
                if ((item is Map) && item.Has("pid") && item.Has("name") && item.Has("startedAt")
                    && item["pid"] = pid && StrLower(item["name"]) = StrLower(name) && item["startedAt"] = startedAt)
                    reported := true
        if !reported
            return false
        try {
            actualName := RegExReplace(ProcessGetName(pid), "i)\.exe$")
            if (StrLower(actualName) != StrLower(name) || DashboardHealth.ProcessStartedAt(pid) != startedAt)
                return false
            WinClose("ahk_pid " pid)
            return true
        } catch {
            return false
        }
    }

    ; Read the process creation time through Win32. AHK v2 has no built-in
    ; ProcessGetTime function; this also guards against a PID being reused.
    static ProcessStartedAt(pid) {
        access := 0x1000 ; PROCESS_QUERY_LIMITED_INFORMATION
        handle := DllCall("OpenProcess", "UInt", access, "Int", false, "UInt", pid, "Ptr")
        if !handle
            return ""
        try {
            created := Buffer(8, 0), exited := Buffer(8, 0), kernel := Buffer(8, 0), user := Buffer(8, 0)
            if !DllCall("GetProcessTimes", "Ptr", handle, "Ptr", created.Ptr, "Ptr", exited.Ptr,
                "Ptr", kernel.Ptr, "Ptr", user.Ptr, "Int")
                return ""
            utc := Buffer(16, 0), localTime := Buffer(16, 0)
            if !DllCall("FileTimeToSystemTime", "Ptr", created.Ptr, "Ptr", utc.Ptr, "Int")
                return ""
            if !DllCall("SystemTimeToTzSpecificLocalTime", "Ptr", 0, "Ptr", utc.Ptr, "Ptr", localTime.Ptr, "Int")
                return ""
            return Format("{:04}{:02}{:02}{:02}{:02}{:02}", NumGet(localTime, 0, "UShort"),
                NumGet(localTime, 2, "UShort"), NumGet(localTime, 6, "UShort"), NumGet(localTime, 8, "UShort"),
                NumGet(localTime, 10, "UShort"), NumGet(localTime, 12, "UShort"))
        } finally {
            DllCall("CloseHandle", "Ptr", handle)
        }
    }
}
