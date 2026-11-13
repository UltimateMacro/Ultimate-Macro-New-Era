; The optional signed-download helper is a separate process, not macro code.
class UpdateHelper {
    static checking := false
    static tick := ""
    static helperSHA256 := "AC1FE1B5E2DFCFFE1D740616778C49C2E651A066229E510973659359D8A1389E"

    static Arm(delay := 0) {
        if !UpdateHelper.tick
            UpdateHelper.tick := ObjBindMethod(MW, "CheckUpdates", false)
        SetTimer(UpdateHelper.tick, delay > 0 && Store.settings["updatePrompts"] && !MW.closing ? -delay : 0)
    }

    static Check(review := false) {
        helper := A_ScriptDir "\updater\UltimateMacro.AhkUpdater.exe"
        if !FileExist(helper)
            return 5
        UpdateHelper.checking := true
        locked := 0, reveal := false, pid := 0
        try {
            locked := UpdateHelper.LockHelper(helper)
            if (!locked || UpdateHelper.HashLocked(locked) != UpdateHelper.helperSHA256)
                return 12
            if review {
                owner := MW.gui.Hwnd
                ; RunWait sets the PID before waiting. Only a manual check can
                ; make this timer, and it never sends a click or key to the helper.
                reveal := () => UpdateHelper.RevealReview(pid,helper,owner,reveal)
                SetTimer(reveal,180)
            }
            return RunWait('"' helper '" "' App.UPDATE_VERSION '" ' (review ? "review" : "stage"),
                A_ScriptDir,review ? "" : "Hide",&pid)
        } catch {
            return 10
        } finally {
            if IsObject(reveal)
                SetTimer(reveal,0)
            reveal := false
            if locked
                DllCall("CloseHandle", "Ptr", locked)
            UpdateHelper.checking := false
        }
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

    static Message(status) {
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
