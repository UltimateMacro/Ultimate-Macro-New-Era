; Private invites belong to the launcher, not the engine or a portable profile.
class PrivateServer {
    static file := "", uri := "", unreadable := false
    static Enabled => PrivateServer.uri != ""

    static InviteUri(link) {
        if !(link is String)
            return ""
        link := Trim(link, " `t")
        if (StrLen(link) > 512)
            return ""
        if RegExMatch(link, "i)\Ahttps://(?:www\.)?roblox\.com/(?:[a-z]{2}(?:-[a-z]{2})?/)?games/3260590327(?:/[a-z0-9_-]{1,128})?/?\?privateServerLinkCode=([a-z0-9]{32})\z", &m)
            return "roblox://placeID=3260590327&linkCode=" m[1]
        if (RegExMatch(link, "i)\Ahttps://(?:www\.)?roblox\.com/share/?\?code=([a-f0-9]{32})&type=Server\z", &m)
            || RegExMatch(link, "i)\Ahttps://(?:www\.)?roblox\.com/share/?\?type=Server&code=([a-f0-9]{32})\z", &m))
            return "roblox://navigation/share_links?code=" m[1] "&type=Server"
        return ""
    }

    static Init(root) {
        PrivateServer.file := root "\private-server.dpapi"
        PrivateServer.uri := "", PrivateServer.unreadable := false
        if !FileExist(PrivateServer.file)
            return
        try {
            if (FileGetSize(PrivateServer.file) > 4096)
                throw ValueError()
            hex := FileRead(PrivateServer.file, "UTF-8")
            if (!RegExMatch(hex, "i)\A[0-9a-f]+\z") || Mod(StrLen(hex), 2))
                throw ValueError()
            packed := Buffer(StrLen(hex) // 2)
            Loop packed.Size
                NumPut("UChar", Integer("0x" SubStr(hex, A_Index * 2 - 1, 2)), packed, A_Index - 1)
            raw := PrivateServer.Transform(packed, false)
            if (raw.Size < 2 || raw.Size > 513 || NumGet(raw, raw.Size - 1, "UChar"))
                throw ValueError()
            link := StrGet(raw, raw.Size - 1, "UTF-8")
            uri := PrivateServer.InviteUri(link)
            if (!uri || StrLen(link) != raw.Size - 1)
                throw ValueError()
            PrivateServer.uri := uri
        } catch {
            PrivateServer.unreadable := true
        }
    }

    static Save(link) {
        uri := PrivateServer.InviteUri(link)
        if !uri
            throw ValueError("Paste a Roblox private server invite for TDS.")
        link := Trim(link, " `t")
        raw := Buffer(StrPut(link, "UTF-8"))
        StrPut(link, raw, "UTF-8")
        packed := PrivateServer.Transform(raw, true)
        hex := ""
        Loop packed.Size
            hex .= Format("{:02X}", NumGet(packed, A_Index - 1, "UChar"))
        AtomicWrite(PrivateServer.file, hex)
        PrivateServer.uri := uri, PrivateServer.unreadable := false
    }

    static Forget() {
        if FileExist(PrivateServer.file)
            FileDelete(PrivateServer.file)
        PrivateServer.uri := "", PrivateServer.unreadable := false
    }

    static Target(publicUri, requirePrivate := false) {
        if PrivateServer.unreadable
            throw ValueError("The saved private server link could not be read.")
        if PrivateServer.Enabled
            return PrivateServer.uri
        if requirePrivate
            throw ValueError("Save a private server link first.")
        return publicUri
    }

    ; Windows DPAPI, current user, with no credential or UI prompts.
    static Transform(raw, protect) {
        input := Buffer(2 * A_PtrSize, 0), output := Buffer(2 * A_PtrSize, 0)
        NumPut("UInt", raw.Size, input)
        NumPut("Ptr", raw.Ptr, input, A_PtrSize)
        fn := protect ? "crypt32\CryptProtectData" : "crypt32\CryptUnprotectData"
        ok := DllCall(fn, "Ptr", input, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 1, "Ptr", output, "Int")
        p := NumGet(output, A_PtrSize, "Ptr"), size := NumGet(output, 0, "UInt")
        try {
            if (!ok || !p || size < 1 || size > (protect ? 2048 : 513))
                throw Error("Windows could not protect or read the private server link.")
            data := Buffer(size)
            DllCall("RtlMoveMemory", "Ptr", data, "Ptr", p, "UPtr", size)
            return data
        } finally {
            if p
                DllCall("LocalFree", "Ptr", p, "Ptr")
        }
    }
}
