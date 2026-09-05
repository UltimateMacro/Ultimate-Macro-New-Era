#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
#Include ..\lib\JSON.ahk

SetWorkingDir(A_ScriptDir "\..")
global RemoteDir := A_AppData "\Ultimate_Macro\Options\Remote"
global RemoteSettings := RemoteDir "\remote.ini"
global ClientVersion := "1.4.0"
if !DirExist(RemoteDir)
    DirCreate(RemoteDir)

mode := A_Args.Length ? A_Args[1] : "worker"
if (mode = "setup") {
    SetupOfficialRemote()
    ExitApp()
}
if (mode = "setup-file") {
    resultPath := A_Args.Length >= 3 ? A_Args[3] : ""
    try {
        if (A_Args.Length < 3)
            throw Error("The secure setup request is incomplete.")
        inputPath := A_Args[2]
        code := FileRead(inputPath, "UTF-8")
        result := SetupOfficialRemote(code, false)
        FileAppend((result["ok"] ? "OK" : "ERROR") "`n" result["message"], resultPath, "UTF-8")
    } catch Error as err {
        if (resultPath != "") {
            try FileDelete(resultPath)
            try FileAppend("ERROR`n" err.Message, resultPath, "UTF-8")
        }
    }
    ExitApp()
}

DetectHiddenWindows(true)
WinSetTitle("ULT Official Remote Worker", "ahk_id " A_ScriptHwnd)
RunWorker()

SetupOfficialRemote(connectionCode := "", interactive := true) {
    global RemoteSettings, ClientVersion
    if (Trim(connectionCode) = "") {
        if !interactive
            return Map("ok", false, "message", "Paste the private connection code first.")
        prompt := InputBox(
            "By linking, you consent to storing a random installation ID, Discord ID, macro version, link/active times, online status, and aggregated coin/gem gains. No hardware ID is collected; security events expire after 30 days.`n`nPaste the private /remote link code. Never share it.",
            "Ultimate Macro Remote Control",
            "w620 h170"
        )
        if (prompt.Result != "OK" || Trim(prompt.Value) = "")
            return Map("ok", false, "message", "Linking was cancelled.")
        connectionCode := prompt.Value
    }
    try {
        parts := StrSplit(Trim(connectionCode), ".")
        if (parts.Length != 3 || parts[1] != "ULT1" || !RegExMatch(parts[3], "^[A-Z2-9]{10}$"))
            throw Error("That connection code is not valid.")
        baseUrl := RTrim(Base64UrlDecodeText(parts[2]), "/")
        if !RegExMatch(baseUrl, "^https://[A-Za-z0-9.-]+(?::\d+)?(?:/.*)?$")
            throw Error("The remote address is not secure.")
        pairCode := SubStr(parts[3], 1, 5) "-" SubStr(parts[3], 6)
        installId := GetOrCreateInstallId()
        response := RemoteRequest("POST", baseUrl "/v1/remote/link", JSON.stringify(Map(
            "code", pairCode,
            "deviceName", "Windows PC",
            "clientVersion", ClientVersion,
            "installId", installId
        )), "", 35000, installId)
        parsed := JSON.parse(response)
        if !parsed.Has("token")
            throw Error(parsed.Has("error") ? parsed["error"] : "The bot did not accept the code.")
        IniWrite(baseUrl, RemoteSettings, "Remote", "BaseUrl")
        IniWrite(1, RemoteSettings, "Remote", "EconomyConsent")
        SaveProtectedToken(parsed["token"])
        message := "Linked successfully. Keep Ultimate Macro open for remote commands."
        if interactive {
            MsgBox(message, "Remote Control", 0x1040)
            Run('"' A_AhkPath '" "' A_ScriptFullPath '" worker', A_ScriptDir, "Hide")
        }
        return Map("ok", true, "message", message)
    } catch Error as err {
        if interactive
            MsgBox("Could not link Remote Control.`n`n" err.Message, "Remote Control", 0x1010)
        return Map("ok", false, "message", err.Message)
    }
}

RunWorker() {
    global RemoteSettings, RemoteDir, ClientVersion
    baseUrl := RTrim(IniRead(RemoteSettings, "Remote", "BaseUrl", ""), "/")
    token := LoadProtectedToken()
    installId := GetOrCreateInstallId()
    if (baseUrl = "" || token = "")
        ExitApp()
    loop {
        try {
            pollUrl := baseUrl "/v1/remote/poll"
            if (IniRead(RemoteSettings, "Remote", "EconomyConsent", "0") = "1") {
                stateFile := A_AppData "\Ultimate_Macro\state.ini"
                coins := Max(0, Integer(IniRead(stateFile, "State", "Coins", 0)))
                gems := Max(0, Integer(IniRead(stateFile, "State", "Gems", 0)))
                pollUrl .= "?coins=" coins "&gems=" gems
            }
            response := RemoteRequest("GET", pollUrl, "", token, 40000, installId)
            parsed := JSON.parse(response)
            if parsed.Has("rotateToken") && Trim(parsed["rotateToken"]) != "" {
                token := parsed["rotateToken"]
                SaveProtectedToken(token)
            }
            if !parsed.Has("job") || !IsObject(parsed["job"])
                continue
            job := parsed["job"]
            if !job.Has("id") || !RegExMatch(job["id"], "^[0-9a-f-]{36}$")
                continue
            commandPath := RemoteDir "\command-" job["id"] ".json"
            tempPath := commandPath ".tmp"
            try FileDelete(tempPath)
            FileAppend(JSON.stringify(job), tempPath, "UTF-8")
            FileMove(tempPath, commandPath, 1)
            SubmitResult(baseUrl, token, installId, job["id"])
        } catch Error {
            Sleep(5000)
        }
    }
}

SubmitResult(baseUrl, token, installId, jobId) {
    global RemoteDir
    resultPath := RemoteDir "\result-" jobId ".json"
    deadline := A_TickCount + 30000
    while (!FileExist(resultPath) && A_TickCount < deadline)
        Sleep(100)
    if !FileExist(resultPath) {
        payload := Map("jobId", jobId, "ok", JSON.false, "result", Map("error", "The macro timed out handling this command."))
    } else {
        payload := JSON.parse(FileRead(resultPath, "UTF-8"))
        FileDelete(resultPath)
        payload["jobId"] := jobId
        if payload.Has("imagePath") {
            imagePath := payload["imagePath"]
            if FileExist(imagePath) {
                payload["imageBase64"] := Base64EncodeFile(imagePath)
                payload["mime"] := "image/png"
                FileDelete(imagePath)
            }
            payload.Delete("imagePath")
        }
    }
    RemoteRequest("POST", baseUrl "/v1/remote/result", JSON.stringify(payload), token, 45000, installId)
}

RemoteRequest(method, url, body := "", token := "", timeout := 35000, installId := "") {
    global ClientVersion
    wr := ComObject("WinHttp.WinHttpRequest.5.1")
    wr.Option[9] := 2720
    wr.Open(method, url, false)
    wr.SetRequestHeader("User-Agent", "UltimateMacro-Remote/" ClientVersion)
    wr.SetRequestHeader("Accept", "application/json")
    wr.SetRequestHeader("X-ULT-Version", ClientVersion)
    if (installId != "")
        wr.SetRequestHeader("X-ULT-Install-ID", installId)
    if (token != "")
        wr.SetRequestHeader("Authorization", "Bearer " token)
    if (method = "POST")
        wr.SetRequestHeader("Content-Type", "application/json")
    wr.SetTimeouts(10000, 10000, timeout, timeout)
    wr.Send(body)
    if (wr.Status < 200 || wr.Status >= 300)
        throw Error("Remote server returned HTTP " wr.Status ".")
    return wr.ResponseText
}

GetOrCreateInstallId() {
    global RemoteSettings
    installId := IniRead(RemoteSettings, "Remote", "InstallId", "")
    if RegExMatch(installId, "i)^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
        return StrLower(installId)
    guid := Buffer(16, 0)
    if DllCall("Ole32\CoCreateGuid", "Ptr", guid.Ptr) != 0
        throw Error("Could not create the private installation ID.")
    text := Buffer(78, 0)
    if DllCall("Ole32\StringFromGUID2", "Ptr", guid.Ptr, "Ptr", text.Ptr, "Int", 39) <= 0
        throw Error("Could not format the private installation ID.")
    installId := StrLower(Trim(StrGet(text, "UTF-16"), "{}"))
    IniWrite(installId, RemoteSettings, "Remote", "InstallId")
    return installId
}

SaveProtectedToken(token) {
    global RemoteSettings
    input := Buffer(StrPut(token, "UTF-8"), 0)
    size := StrPut(token, input, "UTF-8") - 1
    inputBlob := Buffer(A_PtrSize = 8 ? 16 : 8, 0)
    outputBlob := Buffer(A_PtrSize = 8 ? 16 : 8, 0)
    NumPut("UInt", size, inputBlob, 0)
    NumPut("Ptr", input.Ptr, inputBlob, A_PtrSize)
    if !DllCall("Crypt32\CryptProtectData", "Ptr", inputBlob.Ptr, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 0x1, "Ptr", outputBlob.Ptr)
        throw Error("Windows could not protect the remote token.")
    protectedSize := NumGet(outputBlob, 0, "UInt")
    protectedPtr := NumGet(outputBlob, A_PtrSize, "Ptr")
    try IniWrite(Base64EncodeBuffer(protectedPtr, protectedSize), RemoteSettings, "Remote", "TokenProtected")
    finally DllCall("Kernel32\LocalFree", "Ptr", protectedPtr)
    try IniDelete(RemoteSettings, "Remote", "Token")
}

LoadProtectedToken() {
    global RemoteSettings
    encoded := IniRead(RemoteSettings, "Remote", "TokenProtected", "")
    if (encoded = "") {
        legacy := IniRead(RemoteSettings, "Remote", "Token", "")
        if (legacy != "") {
            SaveProtectedToken(legacy)
            return legacy
        }
        return ""
    }
    encrypted := Base64Decode(encoded)
    inputBlob := Buffer(A_PtrSize = 8 ? 16 : 8, 0)
    outputBlob := Buffer(A_PtrSize = 8 ? 16 : 8, 0)
    NumPut("UInt", encrypted.Size, inputBlob, 0)
    NumPut("Ptr", encrypted.Ptr, inputBlob, A_PtrSize)
    if !DllCall("Crypt32\CryptUnprotectData", "Ptr", inputBlob.Ptr, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 0x1, "Ptr", outputBlob.Ptr)
        return ""
    plainSize := NumGet(outputBlob, 0, "UInt")
    plainPtr := NumGet(outputBlob, A_PtrSize, "Ptr")
    try return StrGet(plainPtr, plainSize, "UTF-8")
    finally DllCall("Kernel32\LocalFree", "Ptr", plainPtr)
}

Base64EncodeBuffer(pointer, size) {
    chars := 0
    DllCall("Crypt32\CryptBinaryToStringW", "Ptr", pointer, "UInt", size, "UInt", 0x40000001, "Ptr", 0, "UIntP", &chars)
    output := Buffer(chars * 2)
    if !DllCall("Crypt32\CryptBinaryToStringW", "Ptr", pointer, "UInt", size, "UInt", 0x40000001, "Ptr", output.Ptr, "UIntP", &chars)
        throw Error("Could not protect the remote token.")
    return StrGet(output, "UTF-16")
}

Base64UrlDecodeText(value) {
    value := StrReplace(StrReplace(value, "-", "+"), "_", "/")
    while Mod(StrLen(value), 4)
        value .= "="
    bytes := Base64Decode(value)
    return StrGet(bytes, bytes.Size, "UTF-8")
}

Base64Decode(value) {
    size := 0
    if !DllCall("Crypt32\CryptStringToBinaryW", "Str", value, "UInt", 0, "UInt", 1, "Ptr", 0, "UIntP", &size, "Ptr", 0, "Ptr", 0)
        throw Error("The connection code could not be decoded.")
    decodedBytes := Buffer(size)
    if !DllCall("Crypt32\CryptStringToBinaryW", "Str", value, "UInt", 0, "UInt", 1, "Ptr", decodedBytes.Ptr, "UIntP", &size, "Ptr", 0, "Ptr", 0)
        throw Error("The connection code could not be decoded.")
    return decodedBytes
}

Base64EncodeFile(path) {
    file := FileOpen(path, "r")
    if !file
        throw Error("Could not open the screenshot.")
    if (file.Length > 4000000) {
        file.Close()
        throw Error("Screenshot is too large to send.")
    }
    fileBytes := Buffer(file.Length)
    file.RawRead(fileBytes)
    file.Close()
    chars := 0
    DllCall("Crypt32\CryptBinaryToStringW", "Ptr", fileBytes, "UInt", fileBytes.Size, "UInt", 0x40000001, "Ptr", 0, "UIntP", &chars)
    output := Buffer(chars * 2)
    if !DllCall("Crypt32\CryptBinaryToStringW", "Ptr", fileBytes, "UInt", fileBytes.Size, "UInt", 0x40000001, "Ptr", output, "UIntP", &chars)
        throw Error("Could not encode the screenshot.")
    return StrGet(output, "UTF-16")
}
