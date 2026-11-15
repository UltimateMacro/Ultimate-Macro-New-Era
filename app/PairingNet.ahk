; Shared non-blocking transport for the two opt-in connections.
class Http {
    static Begin(method, url, headers := "", body := "", receive := 10000) {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open(method, url, true)
        req.Option[6] := false ; Never forward a token/code across a redirect.
        req.SetAutoLogonPolicy(2)
        req.SetTimeouts(4000, 5000, 8000, receive)
        if IsObject(headers)
            for name, value in headers
                req.SetRequestHeader(name, value)
        if (body = "")
            req.Send()
        else
            req.Send(body)
        return {req: req, started: A_TickCount, limit: receive + 12000}
    }

    static Check(handle) {
        try {
            if !handle.req.WaitForResponse(0) {
                if (A_TickCount - handle.started < handle.limit)
                    return ""
                try handle.req.Abort()
                return {status: 0, text: ""}
            }
            status := handle.req.Status, text := ""
            ; Dashboard remote commands can carry a validated strategy file
            ; (up to 2 MiB, with JSON escaping overhead). Keep enough response
            ; text to parse one full command without truncating it.
            try text := SubStr(handle.req.ResponseText, 1, 8388608)
            return {status: status, text: text}
        } catch
            return {status: 0, text: ""}
    }
}

class PairingVault {
    static Save(path, purpose, value) {
        raw := PairingVault.Utf8(value)
        try sealed := PairingVault.Dpapi(raw, purpose, true)
        finally PairingVault.Wipe(raw)
        hex := ""
        Loop sealed.Size
            hex .= Format("{:02X}", NumGet(sealed, A_Index - 1, "UChar"))
        AtomicWrite(path, hex)
    }

    static Read(path, purpose) {
        if !FileExist(path)
            return ""
        if (FileGetSize(path) > 8192)
            throw ValueError()
        hex := FileRead(path, "UTF-8")
        if (hex = "")
            return "" ; Explicit disconnect left a tombstone.
        if (!RegExMatch(hex, "\A[0-9A-Fa-f]+\z") || Mod(StrLen(hex), 2))
            throw ValueError()
        sealed := Buffer(StrLen(hex) // 2)
        Loop sealed.Size
            NumPut("UChar", Integer("0x" SubStr(hex, A_Index * 2 - 1, 2)), sealed, A_Index - 1)
        raw := PairingVault.Dpapi(sealed, purpose, false)
        try {
            if (raw.Size < 2 || NumGet(raw, raw.Size - 1, "UChar") != 0)
                throw ValueError()
            value := StrGet(raw, raw.Size - 1, "UTF-8")
            if (StrPut(value, "UTF-8") != raw.Size)
                throw ValueError()
            return value
        } finally PairingVault.Wipe(raw)
    }

    static Forget(path) {
        if FileExist(path) {
            ; Replace the credential before attempting to remove the file.
            AtomicWrite(path, "")
            try FileDelete(path)
        }
    }

    static Utf8(value) {
        bytes := Buffer(StrPut(value, "UTF-8"))
        StrPut(value, bytes, "UTF-8")
        return bytes
    }

    static Blob(bytes) {
        blob := Buffer(2 * A_PtrSize, 0)
        NumPut("UInt", bytes.Size, blob)
        NumPut("Ptr", bytes.Ptr, blob, A_PtrSize)
        return blob
    }

    static Wipe(bytes) => DllCall("msvcrt\memset", "Ptr", bytes, "Int", 0, "UPtr", bytes.Size, "CDecl Ptr")

    static Dpapi(raw, purpose, protect, maxPlain := 2048) {
        context := PairingVault.Utf8(purpose)
        input := PairingVault.Blob(raw), entropy := PairingVault.Blob(context), output := Buffer(2 * A_PtrSize, 0)
        fn := protect ? "crypt32\CryptProtectData" : "crypt32\CryptUnprotectData"
        ok := DllCall(fn, "Ptr", input, "Ptr", 0, "Ptr", entropy, "Ptr", 0, "Ptr", 0, "UInt", 1, "Ptr", output, "Int")
        ptr := NumGet(output, A_PtrSize, "Ptr"), size := NumGet(output, 0, "UInt")
        try {
            if (!ok || !ptr || size < 1 || size > (protect ? maxPlain + 2048 : maxPlain))
                throw Error("Windows credential storage failed.")
            result := Buffer(size)
            DllCall("RtlMoveMemory", "Ptr", result, "Ptr", ptr, "UPtr", size)
            return result
        } finally {
            if ptr {
                if !protect
                    DllCall("msvcrt\memset", "Ptr", ptr, "Int", 0, "UPtr", size, "CDecl Ptr")
                DllCall("LocalFree", "Ptr", ptr, "Ptr")
            }
        }
    }
}

AtomicWrite(path, text) {
    SplitPath(path, , &dir)
    DirCreate(dir)
    tmp := path "." DllCall("GetCurrentProcessId", "UInt") "." A_TickCount "." Random(100000, 999999) ".tmp"
    try {
        file := FileOpen(tmp, "w", "UTF-8-RAW")
        try {
            if (file.Write(text) != StrPut(text, "UTF-8") - 1)
                throw Error("Incomplete credential write.")
            if !DllCall("FlushFileBuffers", "Ptr", file.Handle, "Int")
                throw Error("Credential flush failed.")
        } finally file.Close()
        if !DllCall("MoveFileExW", "WStr", tmp, "WStr", path, "UInt", 0x1 | 0x8, "Int")
            throw Error("Credential replacement failed.")
    } finally {
        if FileExist(tmp)
            try FileDelete(tmp)
    }
}
