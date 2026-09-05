; Official Ultimate Macro remote bridge. The worker process owns network polling;
; Main.ahk only handles small authenticated command files in the user's AppData.

OfficialRemoteDir() {
    global AppDataOpt
    dir := AppDataOpt "\Remote"
    if !DirExist(dir)
        DirCreate(dir)
    return dir
}
OfficialRemoteWorkerPath() {
    return A_ScriptDir "\submacros\official_remote.ahk"
}

OfficialRemoteInit() {
    SetTimer(OfficialRemoteProcessCommands, 500)
    settings := OfficialRemoteDir() "\remote.ini"
    if ((IniRead(settings, "Remote", "TokenProtected", "") != "" || IniRead(settings, "Remote", "Token", "") != "") && IniRead(settings, "Remote", "BaseUrl", "") != "")
        OfficialRemoteStartWorker()
}

OfficialRemoteStartWorker(*) {
    worker := OfficialRemoteWorkerPath()
    if !FileExist(worker)
        return
    DetectHiddenWindows(true)
    if WinExist("ULT Official Remote Worker ahk_class AutoHotkey")
        return
    Run('"' A_AhkPath '" "' worker '" worker', A_ScriptDir, "Hide")
}

OfficialRemoteOpenSetup(*) {
    worker := OfficialRemoteWorkerPath()
    if !FileExist(worker) {
        ModernMsgBox("Remote Control", "The official Remote Control client is missing from this build.", "OK", "WARNING")
        return
    }
    Run('"' A_AhkPath '" "' worker '" setup', A_ScriptDir)
}

OfficialRemoteRefreshControls() {
    global Tab4_RemoteStatus
    if !IsSet(Tab4_RemoteStatus) || !Tab4_RemoteStatus
        return
    settings := OfficialRemoteDir() "\remote.ini"
    linked := (IniRead(settings, "Remote", "TokenProtected", "") != "" || IniRead(settings, "Remote", "Token", "") != "") && IniRead(settings, "Remote", "BaseUrl", "") != ""
    Tab4_RemoteStatus.Text := linked ? "Connected to EngineerBot" : "Not linked yet"
    Tab4_RemoteStatus.SetFont(linked ? "c62D995" : "cAAAAAA")
}

OfficialRemoteConnectFromControls(ctrl, *) {
    global Tab4_RemoteCodeCtrl, Tab4_RemoteStatus, Tab4_RemoteConsent
    worker := OfficialRemoteWorkerPath()
    code := Trim(Tab4_RemoteCodeCtrl.Value)
    if !FileExist(worker) {
        Tab4_RemoteStatus.Text := "Remote Control files are missing from this build."
        Tab4_RemoteStatus.SetFont("cE57373")
        return
    }
    if (code = "") {
        Tab4_RemoteStatus.Text := "Run /remote link in Discord, then paste the private code above."
        Tab4_RemoteStatus.SetFont("cE6B85C")
        return
    }
    if !Tab4_RemoteConsent.Value {
        Tab4_RemoteStatus.Text := "Review the privacy notice and check the consent box first."
        Tab4_RemoteStatus.SetFont("cE6B85C")
        return
    }

    dir := OfficialRemoteDir()
    nonce := A_TickCount "-" Random(100000, 999999)
    inputPath := dir "\setup-input-" nonce ".txt"
    resultPath := dir "\setup-result-" nonce ".txt"
    try {
        FileAppend(code, inputPath, "UTF-8")
        SetActionButtonEnabled(ctrl, false)
        Tab4_RemoteStatus.Text := "Connecting securely..."
        Tab4_RemoteStatus.SetFont("c3A86FF")
        Tab4_RemoteStatus.Redraw()
        RunWait('"' A_AhkPath '" "' worker '" setup-file "' inputPath '" "' resultPath '"', A_ScriptDir, "Hide")
        if !FileExist(resultPath)
            throw Error("The remote setup helper did not return a result.")
        result := FileRead(resultPath, "UTF-8")
        separator := InStr(result, "`n")
        state := separator ? Trim(SubStr(result, 1, separator - 1), " `t`r`n") : "ERROR"
        message := separator ? Trim(SubStr(result, separator + 1), " `t`r`n") : Trim(result)
        if (state != "OK")
            throw Error(message != "" ? message : "The bot did not accept the connection code.")

        Tab4_RemoteCodeCtrl.Value := ""
        Tab4_RemoteStatus.Text := message
        Tab4_RemoteStatus.SetFont("c62D995")
        OfficialRemoteStartWorker()
    } catch Error as err {
        Tab4_RemoteStatus.Text := "Could not link: " SubStr(err.Message, 1, 180)
        Tab4_RemoteStatus.SetFont("cE57373")
    } finally {
        try FileDelete(inputPath)
        try FileDelete(resultPath)
        SetActionButtonEnabled(ctrl, true)
    }
}

OfficialRemoteProcessCommands(*) {
    dir := OfficialRemoteDir()
    Loop Files, dir "\command-*.json", "F" {
        commandFile := A_LoopFileFullPath
        try {
            command := JSON.parse(FileRead(commandFile, "UTF-8"))
            FileDelete(commandFile)
            OfficialRemoteExecute(command)
        } catch Error as err {
            try FileDelete(commandFile)
            RuntimeLogWarn("official_remote_command", "Remote command failed safely", "error=" err.Message)
        }
    }
}

OfficialRemoteExecute(command) {
    global RunningStrategy, StateFile, AutorunStartTime
    if !command.Has("id") || !RegExMatch(command["id"], "^[0-9a-f-]{36}$")
        return
    id := command["id"]
    action := command.Has("command") ? command["command"] : ""
    result := Map("ok", JSON.true, "result", Map())

    try {
        if (action = "status") {
            strategyPath := IniRead(StateFile, "State", "Strategy", "")
            strategyName := "None selected"
            if (strategyPath != "")
                SplitPath(strategyPath, &strategyName)
            result["result"] := Map(
                "running", RunningStrategy ? JSON.true : JSON.false,
                "strategy", strategyName,
                "wave", "Unknown",
                "runtime", RunningStrategy ? FormatRuntime(AutorunStartTime) : "Not running"
            )
        } else if (action = "start") {
            if RunningStrategy
                throw Error("The macro is already running.")
            SetTimer(StartStrategy, -100)
            result["result"] := Map("started", JSON.true)
        } else if (action = "stop") {
            if !RunningStrategy
                throw Error("The macro is not running.")
            StopStrategy()
            result["result"] := Map("stopped", JSON.true)
        } else if (action = "screenshot") {
            pBitmap := CaptureRobloxClientBitmap()
            if !pBitmap
                throw Error("Roblox is not available for a screenshot.")
            imagePath := OfficialRemoteDir() "\image-" id ".png"
            try Gdip_SaveBitmapToFile(pBitmap, imagePath, 90)
            finally Gdip_DisposeImage(pBitmap)
            if !FileExist(imagePath)
                throw Error("The screenshot could not be saved.")
            result["imagePath"] := imagePath
            result["result"] := Map("captured", JSON.true)
        } else {
            throw Error("Unsupported remote command.")
        }
    } catch Error as err {
        result["ok"] := JSON.false
        result["result"] := Map("error", SubStr(err.Message, 1, 500))
    }

    resultPath := OfficialRemoteDir() "\result-" id ".json"
    tempPath := resultPath ".tmp"
    try FileDelete(tempPath)
    FileAppend(JSON.stringify(result), tempPath, "UTF-8")
    FileMove(tempPath, resultPath, 1)
}

OfficialRemoteShutdown() {
    SetTimer(OfficialRemoteProcessCommands, 0)
    DetectHiddenWindows(true)
    if hwnd := WinExist("ULT Official Remote Worker ahk_class AutoHotkey")
        WinClose(hwnd)
}
