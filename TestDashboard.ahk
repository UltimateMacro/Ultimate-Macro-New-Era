#Requires AutoHotkey v2.0 64-bit
#Warn All, Off
#NoTrayIcon
#Include Main.ahk

Need(ok, message) {
    if !ok
        throw Error(message)
}

class DashboardProbe {
    static requests := [], next := [], aborted := 0

    static Begin(method, url, headers, body, timeout) {
        DashboardProbe.requests.Push({method: method, url: url, headers: headers, data: JSON.parse(body), timeout: timeout})
        return {req: {Abort: (*) => DashboardProbe.aborted++}, response: DashboardProbe.next.RemoveAt(1)}
    }

    static Check(handle) => handle.response
    static Reply(status, body := "") => DashboardProbe.next.Push({status: status, text: body})
    static Last => DashboardProbe.requests[-1]
}

WaitFor(state, ms) {
    start := A_TickCount
    while (Dashboard.state != state && A_TickCount-start < ms)
        Sleep(50)
    Need(Dashboard.state == state, "Timed out waiting for " state " (actual: " Dashboard.state
        ", request: " (IsObject(Dashboard.pending) ? Dashboard.pending.kind : "none") ")")
}

TestWire(root) {
    dev := "http://127.0.0.1:4174"
    Dashboard.Init(root, App.UPDATE_VERSION, dev)
    Need(Dashboard.Connect("lwme-3qz7"), "Loopback claim started")
    WaitFor("connected", 4500)
    Need(FileExist(Dashboard.file), "Loopback claim saved a DPAPI credential")
    WaitFor("offline", 23000) ; the real 20-second timer receives the fixture's 503
    Need(FileExist(Dashboard.file), "Temporary HTTP failure kept the saved token")
    Dashboard.Stop()
    Dashboard.Init(root, App.UPDATE_VERSION, dev)
    Need(Dashboard.state == "connecting", "A restart restores the credential without a code")
    Dashboard.Restore()
    WaitFor("connected", 4500)
    Need(Dashboard.Disconnect(), "Explicit disconnect started")
    WaitFor("disconnected", 4500)
    Need(!FileExist(Dashboard.file), "Successful disconnect erased the stored token")
    Need(Dashboard.Connect("LWME-3QZ7"), "Send used code to authoritative server")
    WaitFor("expired", 4500)
    Need(Dashboard.Connect("RDCT-2345"), "Redirect fixture claim started")
    WaitFor("offline", 4500)
    Need(!FileExist(Dashboard.file), "Redirect did not create a local token")
    FileAppend("PASS: WinHTTP loopback claim, 20-second heartbeat, failure, relaunch, disconnect, 410 and redirect refusal`n", "*")
}

TestState(root) {
    Need(Dashboard.ResolveOrigin() == "https://ultmacro.xyz" && Dashboard.ResolveOrigin("https://dev.example:8443") == "https://dev.example:8443",
        "Release uses HTTPS and accepts a dedicated HTTPS development origin")
    for bad in ["http://localhost:4174", "http://127.0.0.1:4175", "https://ultmacro.xyz/path", "https://ultmacro.xyz@other.example", "https://ultmacro.xyz/", "https://ultmacro.xyz?x=1"]
        Need(!Dashboard.ResolveOrigin(bad), "An unapproved origin never falls back to production or HTTP")
    Dashboard.Init(root, App.UPDATE_VERSION, "", DashboardProbe)
    Need(Dashboard.CanConnect && !Dashboard.CanDisconnect && !DashboardProbe.requests.Length, "Fresh install makes no dashboard request")
    Store.settings := Store.Defaults()
    MW.BuildSettings(VBox())
    Need(MW.dashboardCode.password && !MW.dashboardDisconnect.enabled, "Settings masks the code and starts disconnected")
    for bad in ["LWME3QZ7", "LWME–3QZ7", "LWME-3QZ78", "LWME-3QZ7`n", "ŁWME-3QZ7"]
        Need(!Dashboard.Connect(bad) && !DashboardProbe.requests.Length, "Malformed code never reaches the network")

    code := "LWME-3QZ7", token := "test-dpapi-only-device-token_26Y+//=="
    for check in [[400, "disconnected", "rejected"], [410, "expired", "expired"], [429, "disconnected", "Too many"], [0, "offline", "Offline"]] {
        DashboardProbe.Reply(check[1], "Do not display " code " or " token)
        Need(Dashboard.Connect(" `tlwme-3qz7 "), "Valid code started a claim")
        Need(Dashboard.state == "connecting" && !Dashboard.CanConnect && !Dashboard.Connect(code), "Concurrent claims are blocked")
        Dashboard.Pump()
        Need(Dashboard.state == check[2] && InStr(MW.dashboardStatus.text, check[3])
            && !InStr(MW.dashboardStatus.text, token) && !InStr(MW.dashboardStatus.text, code), "Claim status is informative without response data")
    }
    claim := DashboardProbe.Last
    Need(claim.method == "POST" && claim.url == Dashboard.RELEASE_ORIGIN Dashboard.PREFIX "pairing/claim"
        && !claim.headers.Has("Authorization") && claim.data.Count = 3 && claim.data["code"] == code
        && claim.data["deviceName"] == "This PC" && claim.data["appVersion"] == App.UPDATE_VERSION,
        "Claim matches the API contract, preserving the hyphen and current version")

    DashboardProbe.Reply(201, '{"deviceToken":"ignored"}')
    Dashboard.Connect(code), Dashboard.Pump()
    Need(!Dashboard.token && !FileExist(Dashboard.file), "Malformed 201 must not link or persist")
    DashboardProbe.Reply(201, JSON.stringify(Map("deviceId", "test-device", "deviceToken", token, "heartbeatSeconds", 20)))
    DashboardProbe.Reply(204)
    MW.dashboardCode.Text := code
    MW.ConnectDashboard()
    Need(MW.dashboardCode.Text == "", "Submitting through Settings clears the input")
    Dashboard.Pump()
    Need(Dashboard.state == "connecting" && Dashboard.pending.kind == "heartbeat" && FileExist(Dashboard.file),
        "Claim stores the token and sends immediate heartbeat without claiming online status")
    beat := DashboardProbe.Last
    Need(beat.method == "POST" && beat.url == Dashboard.RELEASE_ORIGIN Dashboard.PREFIX "heartbeat"
        && beat.headers["Authorization"] == "Bearer " token && beat.data.Count = 1
        && beat.data["appVersion"] == App.UPDATE_VERSION, "Heartbeat matches the API contract")
    Dashboard.Pump()
    Need(Dashboard.state == "connected" && Dashboard.CanDisconnect && !Dashboard.CanConnect, "Accepted heartbeat is connected")
    sealed := FileRead(Dashboard.file, "UTF-8")
    Need(RegExMatch(sealed, "\A[0-9A-F]+\z") && !InStr(sealed, token) && !InStr(sealed, code)
        && !Store.settings.Has("deviceToken") && !Store.settings.Has("code"), "No plaintext code or token in persistent state")

    oldFile := Dashboard.file
    Dashboard.Stop()
    Need(!Dashboard.token && FileExist(oldFile), "Ordinary exit clears RAM reference but retains encrypted file")
    Dashboard.Init(root, App.UPDATE_VERSION, "http://127.0.0.1:4174", DashboardProbe)
    Need(Dashboard.file != oldFile && !Dashboard.token, "Development uses an independent file")
    AtomicWrite(Dashboard.file, sealed)
    devFile := Dashboard.file
    Dashboard.Init(root, App.UPDATE_VERSION, "http://127.0.0.1:4174", DashboardProbe)
    Need(!Dashboard.token, "Copying an encrypted production token does not make it usable in development")
    FileDelete(devFile)
    Dashboard.Init(root, App.UPDATE_VERSION, "", DashboardProbe)
    Need(Dashboard.token == token && Dashboard.state == "connecting", "Same-user DPAPI reloads the valid token")
    DashboardProbe.Reply(503), Dashboard.Restore(), Dashboard.Pump()
    Need(Dashboard.state == "offline" && Dashboard.token == token && FileExist(oldFile), "Temporary failure retains link")
    DashboardProbe.Reply(204), Dashboard.Beat(), Dashboard.Pump()
    Need(Dashboard.state == "connected", "Next good heartbeat restores the connected state")
    DashboardProbe.next.Push("")
    Dashboard.Beat()
    Need(Dashboard.CanDisconnect && Dashboard.pending.kind == "heartbeat", "User can disconnect while a heartbeat is pending")
    DashboardProbe.Reply(503)
    Need(Dashboard.Disconnect() && DashboardProbe.aborted = 1, "Disconnect cancels a pending heartbeat")
    quit := DashboardProbe.Last
    Need(quit.url == Dashboard.RELEASE_ORIGIN Dashboard.PREFIX "device/disconnect" && quit.method == "POST"
        && quit.headers["Authorization"] == "Bearer " token && quit.data.Count = 0, "Disconnect sends authenticated empty JSON")
    Dashboard.Pump()
    Need(Dashboard.state == "offline" && FileExist(oldFile), "Failed disconnect never silently drops a valid link")
    DashboardProbe.Reply(204), Dashboard.Disconnect(), Dashboard.Pump()
    Need(Dashboard.state == "disconnected" && !Dashboard.token && !FileExist(oldFile), "Successful disconnect erases the credential")
    Dashboard.SaveToken(token)
    Dashboard.Init(root, App.UPDATE_VERSION, "", DashboardProbe)
    DashboardProbe.Reply(401), Dashboard.Restore(), Dashboard.Pump()
    Need(Dashboard.state == "expired" && Dashboard.CanConnect && !Dashboard.token && !FileExist(oldFile), "401 clears the credential and asks to pair again")
    Dashboard.Init(root, App.UPDATE_VERSION, "http://other.example", DashboardProbe)
    Need(Dashboard.state == "offline" && !Dashboard.CanConnect, "Bad dev configuration is fail-closed")
    FileAppend("PASS: pairing Settings, local validation, status handling, DPAPI, restore, retry, revocation and disconnect`n", "*")
}

root := A_Temp "\UM14-dashboard-test-" Engine.NewId()
status := 0
try {
    DirCreate(root)
    if (A_Args.Length && A_Args[1] == "--wire")
        TestWire(root)
    else
        TestState(root)
} catch as e {
    FileAppend("FAIL: " e.Message " (line " e.Line ")`n", "**")
    status := 1
} finally {
    Dashboard.Stop()
    for path in [root "\dashboard.dpapi", root "\dashboard-dev.dpapi"]
        if FileExist(path)
            try FileDelete(path)
    try DirDelete(root)
}
ExitApp(status)
