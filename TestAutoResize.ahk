#Requires AutoHotkey v2.0
#Warn All, Off
#NoTrayIcon
#Include Main.ahk
Need(ok, message) {
    if !ok
        throw Error(message)
}
try {
    b := AutoResize.Target({x: 0, y: 0, w: 1920, h: 1040})
    Need(b[1] = 0 && b[2] = 0 && b[3] = 1680 && b[4] = 945, "A 1080p work area gets the full size in the top left corner")
    b := AutoResize.Target({x: 1920, y: 100, w: 2560, h: 1400})
    Need(b[1] = 1920 && b[2] = 100 && b[3] = 1680 && b[4] = 945, "The work area origin offsets the corner")
    b := AutoResize.Target({x: 0, y: 0, w: 2560, h: 1392}, 7)
    Need(b[1] = -7 && b[2] = 0, "The invisible border sits past the left edge")
    b := AutoResize.Target({x: 0, y: 0, w: 1366, h: 728})
    Need(b[1] >= 0 && b[2] >= 0 && b[1]+b[3] <= 1366 && b[2]+b[4] <= 728, "A small display keeps the window on screen")
    Need(Abs(b[3]/b[4] - 16/9) < 0.01, "A small display keeps the aspect ratio")
    Need(AutoResize.Apply(0) = "skipped" && !AutoResize.busy, "No game window means nothing to resize")
    Docking.active := true
    Need(AutoResize.Apply(1) = "skipped", "Docking keeps ownership of the layout")
    Docking.active := false
    source := FileRead(A_ScriptDir "\ui\Window.ahk", "UTF-8")
    start := SubStr(source, InStr(source, "static StartRun("))
    Need(InStr(start, "AutoResize.Apply(") && InStr(start, "AutoResize.Apply(") < InStr(start, "Engine.Launch(")
        , "Start resizes the game before the engine launches")
} catch as e {
    FileAppend(e.Message "`n", "**")
    ExitApp(1)
}
ExitApp(0)
