/********************************************
* @Author SP
* @Description Class to interact with Discord
*********************************************/

;from Natro Macro.

class Discord
{
	static baseURL := "https://discord.com/api/v10/"

	static SendEmbed(message, color:=3223350, content:="", pBitmap:=0, channel:="", replyID:=0)
	{
		payload_json :=
		(
		'
		{
			"content": "' content '",
			"embeds": [{
				"description": "' message '",
				"color": "' color '"
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

	static SendScreenshot(pBitmap := Gdip_BitmapFromScreen(), description := "", color := 12434877, channel := "", replyID := 0)
	{
		global BotToken

		escapedDescription := StrReplace(description, "\", "\\")
		escapedDescription := StrReplace(escapedDescription, '"', '\"')
		escapedDescription := StrReplace(escapedDescription, "`n", "\n")

		fields := []
		payload_json := '{"embeds": [{"description": "' escapedDescription '", "color": ' color '}]}'
		fields.Push(Map("name", "payload_json", "content-type", "application/json", "content", payload_json))

		if pBitmap
		{
			payload_json := '{"embeds": [{"description": "' escapedDescription '", "color": ' color ', "image": {"url": "attachment://screenshot.png"}}]}'
			fields[1] := Map("name", "payload_json", "content-type", "application/json", "content", payload_json)
			fields.Push(Map("name", "files[0]", "filename", "screenshot.png", "content-type", "image/png", "pBitmap", pBitmap))
		}
		
		this.CreateFormData(&postdata, &contentType, fields)
		
		if pBitmap
			Gdip_DisposeImage(pBitmap)

		return this.SendMessageAPI(postdata, contentType, channel)
	}

	static SendImage(pBitmap, imgname:="image.png", replyID:=0)
	{
		params := []
		(replyID > 0) && params.Push(Map("name","payload_json","content-type","application/json","content",'{"allowed_mentions": {"parse": []}, "message_reference": {"message_id": "' replyID '", "fail_if_not_exists": false}}'))
		params.Push(Map("name","files[0]","filename",imgname,"content-type","image/png","pBitmap",pBitmap))
		this.CreateFormData(&postdata, &contentType, params)
		this.SendMessageAPI(postdata, contentType)
	}

	static SendMessageAPI(postdata, contentType:="application/json", channel:="", url:="")
	{
		global BotToken, ChannelID

		if (!channel && ChannelID)
			channel := ChannelID

		if !url
			url := this.baseURL "/channels/" channel "/messages"

		try
		{
			wr := ComObject("WinHttp.WinHttpRequest.5.1")
			wr.Option[9] := 2720
			wr.Open("POST", url, 1)
			wr.SetRequestHeader("User-Agent", "DiscordBot (AHK, " A_AhkVersion ")")
			wr.SetRequestHeader("Authorization", "Bot " BotToken)
			wr.SetRequestHeader("Content-Type", contentType)
			wr.SetTimeouts(0, 60000, 120000, 30000)
			wr.Send(postdata)
			wr.WaitForResponse()
			return wr.ResponseText
		}
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
		global BotToken
		wr := ComObject("WinHttp.WinHttpRequest.5.1")
		wr.Option[9] := 2720
		wr.Open("GET", Discord.baseURL . "channels/" channelid)
		wr.SetRequestHeader("User-Agent", "DiscordBot (AHK, " A_AhkVersion ")")
		wr.SetRequestHeader("Authorization", "Bot " . BotToken)
		wr.Send()
		wr.WaitForResponse()
		return wr.ResponseText
	}

	static GetMember(guild_id, user_id)
	{
		global BotToken
		wr := ComObject("WinHttp.WinHttpRequest.5.1")
		wr.Option[9] := 2720
		wr.Open("GET", Discord.baseURL . "guilds/" . guild_id . "/members/" . user_id)
		wr.SetRequestHeader("User-Agent", "DiscordBot (AHK, " A_AhkVersion ")")
		wr.SetRequestHeader("Authorization", "Bot " . BotToken)
		wr.Send()
		wr.WaitForResponse()
		return wr.ResponseText
	}

	static GetRecentMessages(channel)
	{
		static lastmsg := Map()

		try
			(messages := JSON.parse(this.GetMessageAPI(lastmsg.Has(channel) ? ("?after=" lastmsg[channel]) : "?limit=1", channel))).Length
		catch
			return []

		if (messages.Has(1))
			lastmsg[channel] := messages[1]["id"]

		return messages
	}

	static GetMessageAPI(params:="", channel:="")
	{
		global BotToken, ChannelID

		if !channel
			channel := ChannelID

		try
		{
			wr := ComObject("WinHttp.WinHttpRequest.5.1")
			wr.Option[9] := 2720
			wr.Open("GET", this.baseURL "/channels/" channel "/messages" params, 1)
			wr.SetRequestHeader("User-Agent", "DiscordBot (AHK, " A_AhkVersion ")")
			wr.SetRequestHeader("Authorization", "Bot " BotToken)
			wr.SetRequestHeader("Content-Type", "application/json")
			wr.Send()
			wr.WaitForResponse()
			return wr.ResponseText
		}
	}

	static CreateFormData(&retData, &contentType, fields)
	{
		static chars := "0|1|2|3|4|5|6|7|8|9|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z"

		chars := Sort(chars, "D| Random")
		boundary := SubStr(StrReplace(chars, "|"), 1, 12)
		hData := DllCall("GlobalAlloc", "UInt", 0x2, "UPtr", 0, "Ptr")
		DllCall("ole32\CreateStreamOnHGlobal", "Ptr", hData, "Int", 0, "PtrP", &pStream:=0, "UInt")

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

			utf8 := Buffer(length := StrPut(str, "UTF-8") - 1), StrPut(str, utf8, length, "UTF-8")
			DllCall("shlwapi\IStream_Write", "Ptr", pStream, "Ptr", utf8.Ptr, "UInt", length, "UInt")

			if field.Has("pBitmap")
			{
				try
				{
					pFileStream := Gdip_SaveBitmapToStream(field["pBitmap"])
					DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", &size:=0, "UInt")
					DllCall("shlwapi\IStream_Reset", "Ptr", pFileStream, "UInt")
					DllCall("shlwapi\IStream_Copy", "Ptr", pFileStream, "Ptr", pStream, "UInt", size, "UInt")
					ObjRelease(pFileStream)
				}
			}

			if field.Has("file")
			{
				DllCall("shlwapi\SHCreateStreamOnFileEx", "WStr", field["file"], "Int", 0, "UInt", 0x80, "Int", 0, "Ptr", 0, "PtrP", &pFileStream:=0)
				DllCall("shlwapi\IStream_Size", "Ptr", pFileStream, "UInt64P", &size:=0, "UInt")
				DllCall("shlwapi\IStream_Copy", "Ptr", pFileStream, "Ptr", pStream, "UInt", size, "UInt")
				ObjRelease(pFileStream)
			}
		}

		str :=
		(
		'

		------------------------------' boundary '--
		'
		)

		utf8 := Buffer(length := StrPut(str, "UTF-8") - 1), StrPut(str, utf8, length, "UTF-8")
		DllCall("shlwapi\IStream_Write", "Ptr", pStream, "Ptr", utf8.Ptr, "UInt", length, "UInt")
		ObjRelease(pStream)

		pData := DllCall("GlobalLock", "Ptr", hData, "Ptr")
		size := DllCall("GlobalSize", "Ptr", pData, "UPtr")

		retData := ComObjArray(0x11, size)
		pvData := NumGet(ComObjValue(retData), 8 + A_PtrSize, "Ptr")
		DllCall("RtlMoveMemory", "Ptr", pvData, "Ptr", pData, "Ptr", size)

		DllCall("GlobalUnlock", "Ptr", hData)
		DllCall("GlobalFree", "Ptr", hData, "Ptr")
		contentType := "multipart/form-data; boundary=----------------------------" boundary
	}
}