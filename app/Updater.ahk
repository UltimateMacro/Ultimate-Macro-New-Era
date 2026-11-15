; The optional signed-download helper is a separate process, not macro code.
class UpdateHelper {
    static checking := false
    static tick := "", process := "", locked := 0, reveal := ""
    static periodic := ""
    static settingsFile := "", version := "", enabled := false, onChange := ""
    static message := "Verified updates are installed only after your approval."
    static helperSHA256 := "EDF166697458C366E30DB82A9557B307952822D3B1AFA56BD308E7EFD6766DD9"

    static Initialize(settings, version) {
        UpdateHelper.settingsFile := settings, UpdateHelper.version := version
        UpdateHelper.enabled := IniRead(settings, "VerifiedUpdates", "QuietDownload", "0") = "1"
        UpdateHelper.Arm()
        OnExit(UpdateHelper.Shutdown)
    }

    static Arm() {
        if !UpdateHelper.periodic
            UpdateHelper.periodic := ObjBindMethod(UpdateHelper, "Begin", false)
        SetTimer(UpdateHelper.periodic, UpdateHelper.enabled ? 30*60*1000 : 0)
    }

    static SetEnabled(value) {
        try IniWrite(value ? 1 : 0, UpdateHelper.settingsFile, "VerifiedUpdates", "QuietDownload")
        catch {
            UpdateHelper.message := "Couldn't save the update preference."
            UpdateHelper.Notify()
            return false
        }
        UpdateHelper.enabled := !!value
        UpdateHelper.Arm()
        return true
    }

    static Notify() {
        if UpdateHelper.onChange
            try UpdateHelper.onChange.Call()
    }

    static Begin(review := false) {
        if UpdateHelper.checking || (!review && !UpdateHelper.enabled)
            return false
        helper := A_ScriptDir "\updater\UltimateMacro.AhkUpdater.exe"
        if !FileExist(helper) {
            UpdateHelper.message := UpdateHelper.Describe(5)
            UpdateHelper.Notify()
            return false
        }
        UpdateHelper.checking := true
        started := false
        try {
            UpdateHelper.locked := UpdateHelper.LockHelper(helper)
            if (!UpdateHelper.locked || UpdateHelper.HashLocked(UpdateHelper.locked) != UpdateHelper.helperSHA256) {
                UpdateHelper.message := UpdateHelper.Describe(12)
                return false
            }
            UpdateHelper.process := OwnedProcess.Start(helper, [UpdateHelper.version, review ? "review" : "stage"], A_ScriptDir, true)
            if review {
                owner := MW.gui ? MW.gui.Hwnd : 0
                pid := UpdateHelper.process.pid
                UpdateHelper.reveal := () => UpdateHelper.RevealReview(pid, helper, owner, UpdateHelper.reveal)
                SetTimer(UpdateHelper.reveal, 180)
            }
            if !UpdateHelper.tick
                UpdateHelper.tick := ObjBindMethod(UpdateHelper, "Pump")
            SetTimer(UpdateHelper.tick, 250)
            UpdateHelper.message := review ? "Checking for a verified update to review…" : "Checking and downloading verified updates quietly…"
            started := true
            return true
        } catch {
            UpdateHelper.message := UpdateHelper.Describe(10)
            return false
        } finally {
            if !started
                UpdateHelper.Shutdown()
            UpdateHelper.Notify()
        }
    }

    static Pump(*) {
        if !UpdateHelper.checking || !OwnedProcess.Finished(UpdateHelper.process)
            return
        code := OwnedProcess.ExitCode(UpdateHelper.process)
        UpdateHelper.Shutdown()
        UpdateHelper.message := UpdateHelper.Describe(code)
        UpdateHelper.Notify()
    }

    static Shutdown(*) {
        if UpdateHelper.tick
            SetTimer(UpdateHelper.tick, 0)
        if IsObject(UpdateHelper.reveal)
            SetTimer(UpdateHelper.reveal, 0)
        UpdateHelper.reveal := ""
        ; The helper never owns or restarts the macro. Let an in-progress
        ; verified download finish if the user closes this app.
        OwnedProcess.Release(UpdateHelper.process)
        UpdateHelper.process := ""
        if UpdateHelper.locked
            DllCall("CloseHandle", "Ptr", UpdateHelper.locked)
        UpdateHelper.locked := 0, UpdateHelper.checking := false
    }

    static RevealReview(pid, helper, owner, timer) {
        if (!IsInteger(pid) || pid <= 0)
            return
        for hwnd in WinGetList("ahk_class #32770 ahk_pid " pid) {
            target := "ahk_id " hwnd
            try {
                if (WinGetTitle(target) != "Ultimate Macro — verified update"
                    || StrLower(WinGetProcessPath(target)) != StrLower(helper))
                    continue
                SetTimer(timer,0)
                if WinActive("ahk_id " owner)
                    WinActivate(target)
                else if !WinActive(target)
                    DllCall("FlashWindow", "Ptr", hwnd, "Int", true)
                return
            }
        }
    }

    static LockHelper(path) {
        SplitPath(path,, &folder)
        if InStr(FileGetAttrib(folder), "L")
            return 0
        ; No writes or replacement are shared while the verified helper runs.
        h := DllCall("CreateFileW", "WStr", path, "UInt", 0x80000000, "UInt", 1,
            "Ptr", 0, "UInt", 3, "UInt", 0x00200000, "Ptr", 0, "Ptr")
        if (!h || h = -1)
            return 0
        info := Buffer(8)
        if !DllCall("GetFileInformationByHandleEx", "Ptr", h, "Int", 9, "Ptr", info, "UInt", 8)
            || (NumGet(info,0,"UInt") & 0x410) {
            DllCall("CloseHandle", "Ptr", h)
            return 0
        }
        return h
    }

    static HashLocked(h) {
        size := read := provider := 0
        if (!DllCall("GetFileSizeEx", "Ptr", h, "Int64*", &size) || size < 1 || size > 64*1024*1024)
            return ""
        data := Buffer(size)
        if (!DllCall("ReadFile", "Ptr", h, "Ptr", data, "UInt", size, "UInt*", &read, "Ptr", 0) || read != size)
            return ""
        if DllCall("bcrypt\BCryptOpenAlgorithmProvider", "Ptr*", &provider, "WStr", "SHA256", "Ptr", 0, "UInt", 0, "Int")
            return ""
        digest := Buffer(32)
        try status := DllCall("bcrypt\BCryptHash", "Ptr", provider, "Ptr", 0, "UInt", 0,
            "Ptr", data, "UInt", size, "Ptr", digest, "UInt", 32, "Int")
        finally DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr", provider, "UInt", 0)
        if status
            return ""
        hex := ""
        Loop 32
            hex .= Format("{:02X}", NumGet(digest,A_Index-1,"UChar"))
        return hex
    }

    static Describe(status) {
        switch status {
            case 0: return "Installed to a new folder in VerifiedUpdates. Your current copy was left in place."
            case 2: return "This AHK build is up to date."
            case 3: return "Installation skipped. The verified ZIP is still saved."
            case 4: return "The AHK update feed is not available. Nothing was installed."
            case 5: return "This source checkout doesn’t include the optional update helper. Use the signed distribution ZIP."
            case 6: return "Update downloaded and verified. Select Review update when you’re ready to install."
            case 8: return "This update already has its own folder in VerifiedUpdates."
            case 11: return "The server offered an older AHK build. Nothing was downloaded."
            case 12: return "The update helper does not match this release. It was not started."
            default: return "Could not verify or save an update. Nothing was installed."
        }
    }
}
