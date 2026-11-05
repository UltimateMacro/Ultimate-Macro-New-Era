#Requires AutoHotkey v2.0 64-bit
#Warn All, Off
#NoTrayIcon
#Include Main.ahk

Need(ok, message) {
    if !ok
        throw Error(message)
}

class LaunchProbe {
    static windows := [], requests := [], fail := false
    static Open(uri) {
        LaunchProbe.requests.Push(uri)
        if LaunchProbe.fail
            throw Error("Test launch failure.")
    }
}

root := A_Temp "\UM14-private-invite-test-" Engine.NewId()
exitCode := 0
try {
    code := "0123456789abcdefFEDCBA9876543210"
    gameLink := "https://www.roblox.com/games/3260590327/Tower-Defense-Simulator?privateServerLinkCode=" code
    shareLink := "https://www.roblox.com/share?code=" code "&type=Server"
    gameUri := Roblox.URI "&linkCode=" code
    shareUri := "roblox://navigation/share_links?code=" code "&type=Server"
    Need(PrivateServer.InviteUri(" " gameLink " ") == gameUri, "TDS place invite")
    Need(PrivateServer.InviteUri(StrReplace(gameLink, "/games/", "/en-us/games/")) == gameUri, "localized TDS invite")
    Need(PrivateServer.InviteUri(shareLink) == shareUri, "Roblox server share invite")
    Need(PrivateServer.InviteUri("https://roblox.com/share?type=Server&code=" code) == shareUri, "share parameter order")
    for bad in ["", Roblox.URI, StrReplace(gameLink, "3260590327", "3260590328"),
        StrReplace(shareLink, "https:", "http:"), StrReplace(shareLink, "roblox.com", "roblox.com.evil.example"),
        StrReplace(shareLink, "www.roblox.com", "www.roblox.com@evil.example"),
        StrReplace(shareLink, "roblox.com", "roblox.com:443"), StrReplace(shareLink, "Server", "Experience"),
        StrReplace(shareLink, code, "%30" SubStr(code, 2)), StrReplace(shareLink, code, "z" SubStr(code, 2)),
        shareLink "&redirect=anything", shareLink "&code=" code, shareLink "#fragment", shareLink Chr(10),
        shareLink Chr(34), shareLink " | another-program", SubStr(shareLink, 1, -1)] {
        Need(PrivateServer.InviteUri(bad) == "", "Rejected unsafe, incomplete, or unsupported input")
    }

    DirCreate(root)
    PrivateServer.Init(root)
    Need(PrivateServer.Target(Roblox.URI) == Roblox.URI, "A fresh profile still opens public TDS")
    Store.settings := Store.Defaults()
    MW.BuildSettings(VBox())
    MW.booting := false, MW.engineReady := true
    Need(MW.privateLink.password, "Invite input is masked")
    MW.privateLink.Text := shareLink
    MW.SavePrivateServer()
    Need(MW.privateLink.Text == "" && PrivateServer.Enabled, "The save action clears the field and enables the invite")
    sealed := FileRead(PrivateServer.file, "UTF-8")
    Need(!InStr(sealed, code) && !InStr(sealed, "roblox"), "The local file does not contain the link in plaintext")
    PrivateServer.Init(root)
    Need(PrivateServer.Target(Roblox.URI) == shareUri, "The same Windows user can reload the invite")
    MW.privateLink.Text := "https://example.com/"
    MW.SavePrivateServer()
    Need(PrivateServer.Target(Roblox.URI) == shareUri && InStr(MW.privateStatus.text, "previous setting"),
        "Invalid replacement leaves the old invite intact and shows a generic error")
    Need(!InStr(MW.privateStatus.text, code), "The card never displays the invite")
    Need(!Store.settings.Has("privateServer") && !Store.settings.Has("VipLink"), "No invite in portable settings")
    Engine.data := root "\engine"
    Engine.Prepare(Map("Options.VipLink", shareLink))
    engineProfile := FileRead(Engine.data "\Options\Settings.tds", "UTF-16")
    Need(!InStr(engineProfile, code) && IniRead(Engine.data "\Options\Settings.tds", "Options", "UseVipServer") == "0",
        "The engine receives neither the invite nor a VIP launch flag")

    ; Replace only the OS boundary: no game process or real network requests.
    Roblox.DefineProp("Windows", {Call: (*) => LaunchProbe.windows})
    Roblox.DefineProp("OpenUri", {Call: (self, uri) => LaunchProbe.Open(uri)})
    GameRecovery.DefineProp("InputStamp", {Call: (*) => 42})
    Need(Roblox.Launch() == "waiting" && LaunchProbe.requests[1] == shareUri, "New launches use the private route")
    Roblox.Cancel()
    LaunchProbe.windows := [101]
    Need(Roblox.Launch() == "ready" && LaunchProbe.requests.Length == 1, "An ordinary start does not interrupt an open game")
    Need(Roblox.Launch(true) == "invite-opened" && LaunchProbe.requests[2] == shareUri, "Explicit join can open the invite with Roblox already open")
    LaunchProbe.windows := [101, 102]
    Need(Roblox.Launch(true) == "multiple" && LaunchProbe.requests.Length == 2, "Multiple windows block explicit join")
    LaunchProbe.windows := []
    GameRecovery.state := "closing", GameRecovery.pid := 2147483647, GameRecovery.stamp := 42
    GameRecovery.launchUri := PrivateServer.Target(Roblox.URI), GameRecovery.deadline := A_TickCount + 3000
    Need(GameRecovery.Poll(true) == "" && GameRecovery.state == "opening" && LaunchProbe.requests[3] == shareUri,
        "Recovery dispatches the private route")
    GameRecovery.Cancel()
    Need(GameRecovery.launchUri == "", "Recovery discards its invite after ending")
    LaunchProbe.fail := true
    GameRecovery.state := "closing", GameRecovery.pid := 2147483647, GameRecovery.stamp := 42
    GameRecovery.launchUri := PrivateServer.Target(Roblox.URI), GameRecovery.deadline := A_TickCount + 3000
    Need(GameRecovery.Poll(true) == false && LaunchProbe.requests.Length == 4 && LaunchProbe.requests[4] == shareUri,
        "A launch error ends recovery without retrying on a public server")
    LaunchProbe.fail := false

    AtomicWrite(PrivateServer.file, "00")
    PrivateServer.Init(root)
    Need(PrivateServer.unreadable && !PrivateServer.Enabled, "A corrupt local link is not usable")
    Need(Roblox.Launch() == "invalid-private" && LaunchProbe.requests.Length == 4, "Unreadable link does not silently launch public TDS")
    MW.ForgetPrivateServer()
    Need(!FileExist(PrivateServer.file) && !PrivateServer.unreadable, "Forget removes the protected invite")
    Need(Roblox.Launch(true) == "invalid-private" && LaunchProbe.requests.Length == 4, "Join private without a saved link must not launch public")
    Need(Roblox.Launch() == "waiting" && LaunchProbe.requests[5] == Roblox.URI, "Public TDS restored only after forget")
    FileAppend("PASS: private invite validation, protected storage, settings, launch and recovery`n", "*")
} catch as e {
    FileAppend("FAIL: " e.Message " (" e.Line ")`n", "**")
    exitCode := 1
} finally {
    if DirExist(root) {
        for path in [root "\private-server.dpapi", root "\engine\Options\Settings.tds",
            root "\engine\Options\Discord-Bot-Settings.ini", root "\engine\state.ini"]
            try FileDelete(path)
        for folder in ["Options", "Recordings", "Active", "Logs"]
            try DirDelete(root "\engine\" folder)
        try DirDelete(root "\engine")
        try DirDelete(root)
    }
}
ExitApp(exitCode)
