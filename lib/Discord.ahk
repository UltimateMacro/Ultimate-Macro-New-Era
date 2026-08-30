/********************************************
* @Author SP
* @Description Class to interact with Discord
*********************************************/

; Originally derived from Natro Macro.
; New Era hardening keeps one request path for retries/rate limits while
; preserving caller-owned bitmap lifetime.

class Discord
{
    static baseURL := "https://discord.com/api/v10/"

    static EscapeJson(value)
    {
        value := String(value)
        ; Existing macro callsites frequently use literal \n / \t sequences to
        ; describe Discord formatting. Normalize those before JSON escaping.
        value := StrReplace(value, "\r\n", "`n")
        value := StrReplace(value, "\n", "`n")
        value := StrReplace(value, "\t", "`t")
        value := StrReplace(value, "\", "\\")
        value := StrReplace(value, '"', '\"')
        value := StrReplace(value, "`r", "")
        value := StrReplace(value, "`n", "\n")
        value := StrReplace(value, "`t", "\t")
        return value
    }

    static SendEmbed(message, color:=3223350, content:="", pBitmap:=0, channel:="", replyID:=0)
    {
        message := this.EscapeJson(message)
        content := this.EscapeJson(content)
        colorValue := IsNumber(color) ? Integer(color) : 3223350

        payload_json :=
        (
        '
        {
            "content": "' content '",
            "embeds": [{
                "description": "' message '",
                "color": ' colorValue '
                ' (pBitmap ? (',"image": {"url": "attachment://ss.png"}') : '') '
            }]
            ' (replyID ? (',"allowed_mentions": {"parse": []}, "message_reference": {"message_id": "' replyID '", "fail_if_not_exists": false}') : '') '
        }
        '
        )

        if pBitmap
            this.CreateFormData(&postdata, &contentType, [Map("name","payload_json","content-type","application/json","content",payload_json), Map("name","files[0]","filename","ss.png","content-type","image/png","pBitmap",pBitmap)])
        else
            postdata := payload_json, contentType := "application/json"

        return this.SendMessageAPI(postdata, contentType, channel)
    }

    ; No full-desktop default. Callers may pass CaptureRobloxClientBitmap(), or
    ; omit the bitmap for a text-only embed when Roblox is unavailable.
    static SendScreenshot(pBitmap := 0, description := "", color := 12434877, channel := "", replyID := 0)
    {
        escapedDescription := this.EscapeJson(description)
        colorValue := IsNumber(color) ? Integer(color) : 12434877

        fields := []
        payload_json := '{"embeds": [{"description": "' escapedDescription '", "color": ' colorValue '}]}'
        fields.Push(Map("name", "payload_json", "content-type", "application/json", "content", payload_json))

        if pBitmap
        {
            payload_json := '{"embeds": [{"description": "' escapedDescription '", "color": ' colorValue ', "image": {"url": "attachment://screenshot.png"}}]}'
            fields[1] := Map("name", "payload_json", "content-type", "application/json", "content", payload_json)
            fields.Push(Map("name", "files[0]", "filename", "screenshot.png", "content-type", "image/png", "pBitmap", pBitmap))
        }

        this.CreateFormData(&postdata, &contentType, fields)
        return this.SendMessageAPI(postdata, contentType, channel)
    }

    static SendImage(pBitmap, imgname:="image.png", replyID:=0)
    {
        params := []
        (replyID > 0) && params.Push(Map("name","payload_json","content-type","application/json","content",'{"allowed_mentions": {"parse": []}, "message_reference": {"message_id": "' replyID '", "fail_if_not_exists": false}}'))
        params.Push(Map("name","files[0]","filename",imgname,"content-type","image/png","pBitmap",pBitmap))
        this.CreateFormData(&postdata, &contentType, params)
        return this.SendMessageAPI(postdata, contentType)
    }

    static SendMessageAPI(postdata, contentType:="application/json", channel:="", url:="")
    {
        global ChannelID

        if (!channel && ChannelID)
            channel := ChannelID

        if !url
            url := this.baseURL "channels/" channel "/messages"

        return this.Request("POST", url, postdata, contentType)
    }

    static GetCommands(channel)
    {
        global UserID, command_buffer
        messages := this.GetRecentMessages(channel)

        for msg in messages {
            if (msg["author"]["id"] != UserID)
                continue

            content := Trim(msg["content"])
            if (SubStr(content, 1, 1) != "!")
                continue

            command_buffer.Push({
                content: content,
                id: msg["id"],
                url: msg["attachments"].Has(1) ? msg["attachments"][1]["url"] : "",
                user_id: msg["author"]["id"]
            })
        }
    }

    static GetChannel(channelid)
    {
        return this.Request("GET", this.baseURL "channels/" channelid)
    }

    static GetMember(guild_id, user_id)
    {
        return this.Request("GET", this.baseURL "guilds/" guild_id "/members/" user_id)
    }

    static GetRecentMessages(channel)
    {
        static lastmsg := Map()

        ; On the first poll after a macro restart, establish a baseline but do
        ; not replay the last command from before the restart.
        if !lastmsg.Has(channel) {
            try
                firstMessages := JSON.parse(this.GetMessageAPI("?limit=1", channel))
            catch
                return []

            if firstMessages.Has(1)
                lastmsg[channel] := firstMessages[1]["id"]
            return []
        }

        try
            messages := JSON.parse(this.GetMessageAPI("?after=" lastmsg[channel], channel))
        catch
            return []

        if (messages.Has(1))
            lastmsg[channel] := messages[1]["id"]

        return messages
    }

    static GetMessageAPI(params:="", channel:="")
    {
        global ChannelID
        if !channel
            channel := ChannelID
        return this.Request("GET", this.baseURL "channels/" channel "/messages" params)
    }

    ; Central Discord request path. Retries transient network failures, HTTP 429
    ; using Discord's Retry-After/retry_after value, and 5xx server failures.
    ; Authentication/permission/client errors are returned immediately.
    static Request(method, url, body?, contentType := "", maxAttempts := 3)
    {
        global BotToken
        lastResponse := ""

        loop maxAttempts {
            try {
                wr := ComObject("WinHttp.WinHttpRequest.5.1")
                wr.Option[9] := 2720
                wr.Open(method, url, false)
                wr.SetRequestHeader("User-Agent", "DiscordBot (AHK, " A_AhkVersion ")")
                if (BotToken != "")
                    wr.SetRequestHeader("Authorization", "Bot " BotToken)
                if (contentType != "")
                    wr.SetRequestHeader("Content-Type", contentType)
                wr.SetTimeouts(10000, 15000, 60000, 60000)

                if IsSet(body)
                    wr.Send(body)
                else
                    wr.Send()

                status := wr.Status
                lastResponse := wr.ResponseText

                if (status = 429) {
                    if (A_Index = maxAttempts)
                        return lastResponse
                    Sleep(this.GetRetryDelayMs(wr, lastResponse))
                    continue
                }

                if (status >= 500 && status <= 599) {
                    if (A_Index = maxAttempts)
                        return lastResponse
                    Sleep(Min(5000, 750 * A_Index))
                    continue
                }

                return lastResponse
            } catch Error {
                if (A_Index = maxAttempts)
                    return lastResponse
                Sleep(Min(5000, 750 * A_Index))
            }
        }

        return lastResponse
    }

    static GetRetryDelayMs(wr, responseText := "")
    {
        seconds := 0

        try {
            header := Trim(wr.GetResponseHeader("Retry-After"))
            if IsNumber(header)
                seconds := Number(header)
        }

        if (seconds <= 0) {
            try {
                parsed := JSON.parse(responseText)
                if parsed.Has("retry_after") && IsNumber(parsed["retry_after"])
                    seconds := Number(parsed["retry_after"])
            }
        }

        if (seconds <= 0) {
            try {
                header := Trim(wr.GetResponseHeader("X-RateLimit-Reset-After"))
                if IsNumber(header)
                    seconds := Number(header)
            }
        }

        if (seconds <= 0)
            seconds := 1

        return Min(30000, Max(500, Ceil(seconds * 1000) + 150))
    }

    static CreateFormData(&retData, &contentType, fields)
    {
        static chars := "0|1|2|3|4|5|6|7|8|9|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z"

        chars := Sort(chars, "D| Random")
        boundary := SubStr(StrReplace(chars, "|"), 1, 12)
        hData := DllCall("GlobalAlloc", "UInt", 0x2, "UPtr", 0, "Ptr")
        if !hData
            throw Error("Unable to allocate multipart buffer")

        pStream := 0
        if DllCall("ole32\CreateStreamOnHGlobal", "Ptr", hData, "Int", 0, "PtrP", &pStream, "UInt")
            throw Error("Unable to create multipart stream")

        try {
            for field in fields
            {
                str :=
                (
                '

                ------------------------------' boundary '
                Content-Disposition: form-data; name="' field["name"] '"' (field.Has("filename") ? ('; filename="' field["filename"] '"') : "") '
                Content-Type: ' field["content-type"] '

                ' (field.Has("content") ? (field["content"] "`r`n") : "")
                )

                utf8 := Buffer(length := StrPut(str, "UTF-8") - 1)
                StrPut(str, utf8, length, "UTF-8")
                DllCall("shlwapi\IStream_Write", "Ptr", pStream, "Ptr", utf8.Ptr, "UInt", length, "UInt")

                if field.Has("pBitmap")
                {
                    pFileStream := 0
                    try {
                        pFileStream := Gdip_SaveBitmapToStream(field["pBitmap"])
                        if !pFileStream
                            throw Error("Unable to encode screenshot")
                        DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", &size:=0, "UInt")
                        DllCall("shlwapi\IStream_Reset", "Ptr", pFileStream, "UInt")
                        DllCall("shlwapi\IStream_Copy", "Ptr", pFileStream, "Ptr", pStream, "UInt", size, "UInt")
                    } finally {
                        if pFileStream
                            ObjRelease(pFileStream)
                    }
                }

                if field.Has("file")
                {
                    pFileStream := 0
                    try {
                        DllCall("shlwapi\SHCreateStreamOnFileEx", "WStr", field["file"], "Int", 0, "UInt", 0x80, "Int", 0, "Ptr", 0, "PtrP", &pFileStream)
                        if !pFileStream
                            throw Error("Unable to open multipart file")
                        DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", &size:=0, "UInt")
                        DllCall("shlwapi\IStream_Copy", "Ptr", pFileStream, "Ptr", pStream, "UInt", size, "UInt")
                    } finally {
                        if pFileStream
                            ObjRelease(pFileStream)
                    }
                }
            }

            str := "`r`n------------------------------" boundary "--`r`n"
            utf8 := Buffer(length := StrPut(str, "UTF-8") - 1)
            StrPut(str, utf8, length, "UTF-8")
            DllCall("shlwapi\IStream_Write", "Ptr", pStream, "Ptr", utf8.Ptr, "UInt", length, "UInt")
        } finally {
            if pStream
                ObjRelease(pStream)
        }

        pData := DllCall("GlobalLock", "Ptr", hData, "Ptr")
        if !pData {
            DllCall("GlobalFree", "Ptr", hData, "Ptr")
            throw Error("Unable to lock multipart buffer")
        }

        try {
            size := DllCall("GlobalSize", "Ptr", hData, "UPtr")
            retData := ComObjArray(0x11, size)
            pvData := NumGet(ComObjValue(retData), 8 + A_PtrSize, "Ptr")
            DllCall("RtlMoveMemory", "Ptr", pvData, "Ptr", pData, "UPtr", size)
        } finally {
            DllCall("GlobalUnlock", "Ptr", hData)
            DllCall("GlobalFree", "Ptr", hData, "Ptr")
        }

        contentType := "multipart/form-data; boundary=----------------------------" boundary
    }
}
