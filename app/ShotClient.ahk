; The helper's output is temporarily DPAPI sealed; only this user's app can read it.
class ShotClient {
    static Purpose(nonce) => "Ultimate Macro requested Roblox screenshot v1 " nonce

    static Start() {
        nonce := UltBot.Guid()
        dir := A_Temp "\UltimateMacroShot-" nonce
        if DirExist(dir)
            throw Error("Temporary capture directory is already in use.")
        DirCreate(dir)
        try process := OwnedProcess.Start(A_ScriptDir "\submacros\AutoHotkey64.exe"
            , [A_ScriptDir "\submacros\remote_screenshot.ahk", dir, nonce, String(DllCall("GetCurrentProcessId", "UInt"))], A_ScriptDir, true)
        catch {
            DirDelete(dir)
            throw Error("Couldn't start the Roblox capture helper.")
        }
        return {process: process, dir: dir, nonce: nonce, started: A_TickCount}
    }

    static Poll(task) {
        if !OwnedProcess.Finished(task.process) && A_TickCount-task.started < 5000
            return ""
        try {
            if !OwnedProcess.Finished(task.process)
                return Map("error", "Roblox capture timed out. Try again when the game is responsive.")
            if OwnedProcess.ExitCode(task.process) != 0
                return Map("error", "Show a single Roblox game window in the foreground, then request another screenshot.")
            path := task.dir "\capture.dpapi"
            file := FileOpen(path, "r")
            try {
                if file.Length < 9 || file.Length > 1000000
                    throw ValueError()
                sealed := Buffer(file.Length)
                if file.RawRead(sealed, sealed.Size) != sealed.Size
                    throw ValueError()
            } finally file.Close()
            bytes := PairingVault.Dpapi(sealed, ShotClient.Purpose(task.nonce), false, 700000)
            if bytes.Size < 8 || NumGet(bytes, 0, "UInt64") != 0x0A1A0A0D474E5089
                throw ValueError()
            size := 0
            if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", bytes, "UInt", bytes.Size, "UInt", 0x40000001, "Ptr", 0, "UInt*", &size)
                throw ValueError()
            text := Buffer(size*2, 0)
            if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", bytes, "UInt", bytes.Size, "UInt", 0x40000001, "Ptr", text, "UInt*", &size)
                throw ValueError()
            return Map("imageBase64", StrGet(text, "UTF-16"), "mime", "image/png")
        } catch {
            return Map("error", "Roblox couldn't provide a valid screenshot. Nothing was uploaded.")
        } finally ShotClient.Cancel(task)
    }

    static Cancel(task) {
        if !IsObject(task)
            return
        OwnedProcess.Stop(task.process, false)
        try FileDelete(task.dir "\capture.dpapi")
        try DirDelete(task.dir) ; Non-recursive; never delete a computed tree.
    }
}
