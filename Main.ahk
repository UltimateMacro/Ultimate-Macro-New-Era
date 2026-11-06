; Ultimate Macro 1.4 - AutoHotkey edition
;
; Ultimate Macro (macro for TDS) by Darksen. Free for anyone to use.
; Modifications are welcome, however stealing credit is not.
; You can add your name, but the original credit must remain.
;
; This is a modified version of "Ultimate Macro", licensed GNU GPLv3. The 1.4
; Python/Qt window and C# engine host were ported back to AutoHotkey v2; the
; gameplay engine in .\engine is the 1.4 patched 1.3.3a engine (see
; engine\ENGINE-NOTICE.md). Discord server - https://discord.gg/ultmacro

#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#NoTrayIcon
SetWorkingDir(A_ScriptDir)
ListLines(False)
KeyHistory(0)
CoordMode("Mouse", "Screen")
SetWinDelay(-1)
A_MaxHotkeysPerInterval := 9999

#Include ui\Gfx.ahk
#Include ui\Toolkit.ahk
#Include ui\Chrome.ahk
#Include ui\Window.ahk
#Include ui\Dialog.ahk
#Include ui\Events.ahk
#Include app\lib\JSON.ahk
#Include app\lib\Gdip_All.ahk
#Include app\Locale.ahk
#Include app\Strategy.ahk
#Include app\Store.ahk
#Include app\Updater.ahk
#Include app\Engine.ahk
#Include app\PrivateServer.ahk
#Include app\Roblox.ahk
#Include app\Docking.ahk
#Include app\Discord.ahk
#Include app\Dashboard.ahk
#Include app\Passive.ahk

DashboardDevelopmentOrigin := ""
#Include *i app\DashboardDevelopment.local.ahk

class App {
    static VERSION := "1.4.0.41-ahk"
    static UPDATE_VERSION := "1.4.0.41"
    static RELEASE := "1.4.0.23"   ; protocol version string for the official relay
    static SHORT_VERSION := "1.4"
    static assets := A_ScriptDir "\assets"
    static engine := A_ScriptDir "\engine"
    static mutex := 0

    static Main() {
        global DashboardDevelopmentOrigin
        if RegExMatch(A_ScriptDir, "i)\.(zip|rar|7z)(\\|$)") {
            MsgBox("You are running Ultimate Macro from inside a ZIP file.`n`nExtract the whole folder first, then run Main.ahk from the extracted folder.", "Running From ZIP", 0x10)
            ExitApp()
        }
        ; One instance per user: focus the running window instead of starting a second engine owner.
        App.mutex := DllCall("CreateMutex", "Ptr", 0, "Int", 0, "Str", "UltimateMacro14AHK." A_UserName, "Ptr")
        if (A_LastError = 183) {
            DetectHiddenWindows(false)
            if WinExist("Ultimate Macro ahk_class AutoHotkeyGUI")
                WinActivate()
            ExitApp()
        }
        OnError(App.OnError.Bind(App))
        DllCall("SetProcessDPIAware")
        Gfx.Init()
        OnExit(App.Cleanup.Bind(App))
        UI_Install()
        Store.Init()
        PrivateServer.Init(Store.root)
        Theme.christmas := Store.settings["halloween"]
        Locale.Set(Store.settings["language"])
        if (Store.settings["policyRevision"] != FirstUse.POLICY_REVISION && !FirstUse.Terms())
            ExitApp()
        if (!Store.settings["languageChosen"] && !FirstUse.Language())
            ExitApp()
        Dashboard.Init(Store.root, App.UPDATE_VERSION, DashboardDevelopmentOrigin)
        Engine.Init()
        ; Temporary draft paths are an implementation detail, not a saved strategy.
        Engine.onLog := (text) => InStr(text, "\UMDraft-") ? 0 : MW.Log(text)
        Engine.onChange := () => MW.Sync()
        Engine.onRecorded := (path) => MW.OnRecorded(path)
        Engine.onRecState := (steps, aligned) => MW.OnRecState(steps, aligned)
        try TraySetIcon(App.assets "\UltBot.ico")
        A_IconTip := "Ultimate Macro"
        MW.Build()
        try {
            hIcon := LoadPicture(App.assets "\UltBot.ico", "w32", &type)
            SendMessage(0x80, 1, hIcon, MW.gui)
            SendMessage(0x80, 0, hIcon, MW.gui)
        }
        Hotkeys.Install()
        MW.Show()
        Dashboard.Restore()
        UpdateHelper.Arm(4500)
    }

    ; Unexpected script errors are logged next to the settings for support.
    static OnError(e, mode) {
        try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " " Type(e) ": " e.Message " (" e.What ") " e.File ":" e.Line "`n" e.Stack "`n"
            , EnvGet("LOCALAPPDATA") "\UltimateMacro14AHK\error.log", "UTF-8")
        return 0
    }

    static Cleanup(reason, code) {
        try Dashboard.Stop()
        ; No queued paint may touch fonts, brushes or buffers after shutdown.
        try UI_Uninstall()
        try {
            for hwnd, surface in Surface.all.Clone()
                surface.Destroy()
        }
        try {
            if (Engine.phase != "offline" || Engine.ToolsRunning()) {
                Engine.KillOwned(true)
                Engine.Revoke()
                Engine.ReleaseInputs()
            }
        }
        try {
            if Docking.active
                Docking.Detach()
        }
        try Backdrop.Dispose()
        try Gfx.Shutdown()
        return 0
    }
}

if (A_LineFile = A_ScriptFullPath)
    App.Main()
