#Requires AutoHotkey v2.0
#Warn All, Off
#NoTrayIcon
#Include engine\lib\UM14Timescale.ahk
#Include engine\lib\UM14Click.ahk

global TimescaleActive := false, TimeScaleMultiplier := 1, UseTimeScale := true
global TimeScaleMode := "2x", difficulty := "Hardcore", MultiplayerEnabled := false
global StateFile := "fixture", AutorunStartTime := 0, state := Map(), clicks := [], keys := []
global scene := "empty", closed := false, checks := 0, stable := true, cancelVisible := true, weak := false
global pointer := [0,0], notices := [], webhooks := 0
IniRead(file, section, key, fallback := "") => state.Has(key) ? state[key] : fallback
IniWrite(value, file, section, key) => state[key] := value
UM14_ConnectionSnapshot() => {key:"fixture", w:1366, h:768}
UM14_ConnectionSame(*) => stable
UM14_RequireReadyFocus() => 0
UM14_RequireInputPoint(*) {
    if !stable
        throw Error("Changed client")
}
UM14_Fatal(message) {
    throw Error(message)
}
MouseMove(x,y,*) {
    global pointer := [x,y]
}
MouseGetPos(&x,&y) {
    x := pointer[1], y := pointer[2]
}
Click(option := "") {
    global closed
    if (option = "Up")
        return
    clicks.Push(pointer.Clone())
    if (pointer[1] = 700 || (pointer[1] = 600 && scene != "stuck"))
        closed := true
}
Sleep(*) => 0
Send(value) {
    keys.Push(value)
}
LogToConsole(message,*) => notices.Push(message)
SendToWebhookInstant(*) {
    global webhooks
    webhooks++
}
FormatRuntime(*) => "00:00"
AdvancedImageSearch(template,*) {
    global checks, stable
    if InStr(template,"GetMore") {
        checks++
        if (scene = "changed")
            stable := false
    }
    found := !closed && ((scene = "empty" && InStr(template,"GetMore"))
        || ((scene = "confirm" || scene = "moved") && checks >= 3 && InStr(template,"confirm"))
        || (scene = "stuck" && InStr(template,"confirm"))
        || (cancelVisible && scene != "missing" && InStr(template,"cancel")))
    return found ? {status:"success",score:weak ? .6 : .95,
        x:InStr(template,"cancel") ? 700 : scene = "moved" && checks > 3 ? 640 : 600,y:500}
        : {status:"error",score:0}
}
Need(ok,message) {
    if !ok
        throw Error(message)
}
Reset(which) {
    global scene := which, TimescaleActive := true, TimeScaleMultiplier := 2, UseTimeScale := true
    global MultiplayerEnabled := false, difficulty := "Hardcore", TimeScaleMode := "2x"
    global state := Map(), clicks := [], keys := [], notices := [], closed := false, checks := 0
    global stable := true, cancelVisible := true, weak := false, webhooks := 0
}
try {
    Reset("empty")
    Need(!UM14_ActivateTimescale(), "Empty tickets do not activate speed")
    Need(!TimescaleActive && TimeScaleMultiplier = 1 && !UseTimeScale, "Empty tickets reset all runtime speed state")
    Need(clicks.Length = 2 && clicks[2][1] = 700 && closed, "Only the identified Cancel button is clicked, never Get More")
    Need(!state.Has("Timescale") && !webhooks, "No ticket is counted on an empty balance")
    Need(state["TimescaleUnavailable"] = 1, "Empty balance is remembered until the next Start")
    before := keys.Length, UseTimeScale := true
    Need(!UM14_ActivateTimescale() && keys.Length = before && clicks.Length = 2, "A resumed match does not keep opening the ticket dialog")

    Reset("confirm")
    Need(UM14_ActivateTimescale(), "A delayed confirmation is accepted")
    Need(TimescaleActive && TimeScaleMultiplier = 2 && state["Timescale"] = 1 && webhooks = 1,
        "Only a dismissed confirmation counts a ticket and enables speed")
    Need(clicks.Length = 2 && clicks[2][1] = 600, "The exact confirmation is clicked once")
    Need(keys[keys.Length-1] = "{sc02B}" && keys[keys.Length] = "#", "Navigation is closed after confirmation")

    Reset("moved")
    Need(!UM14_ActivateTimescale() && clicks.Length = 2 && clicks[2][1] = 700
        && !state.Has("Timescale"), "Moving the confirmation between observation and hover sends only Cancel")
    Reset("confirm"), TimeScaleMode := "1.5x"
    Need(UM14_ActivateTimescale() && TimeScaleMultiplier = 1.5, "The 1.5x choice retains its own speed")

    Reset("missing")
    Need(!UM14_ActivateTimescale() && !TimescaleActive && TimeScaleMultiplier = 1, "Missing confirmation continues at 1x")
    Need(clicks.Length = 1 && !state.Has("Timescale") && !webhooks, "A missing dialog never authorizes a purchase or usage count")
    for key in keys
        Need(key != "{Escape}", "A missing modal does not open Roblox's Escape menu")
    Need(checks <= 20, "The optional dialog wait is bounded")

    Reset("stuck")
    Need(!UM14_ActivateTimescale() && !TimescaleActive && TimeScaleMultiplier = 1,
        "An unresponsive confirmation does not activate speed")
    Need(clicks.Length = 3 && clicks[3][1] = 700 && closed && !state.Has("Timescale"),
        "An unresponsive confirmation is canceled without counting a ticket")

    Reset("empty"), cancelVisible := false
    failed := false
    try UM14_ActivateTimescale()
    catch
        failed := true
    Need(failed && clicks.Length = 1 && !state.Has("Timescale"),
        "A missing Cancel button stops safely without guessing a click, opening Escape, buying or restarting")

    Reset("empty"), weak := true
    Need(!UM14_ActivateTimescale() && clicks.Length = 1 && !state.Has("Timescale"), "Weak image matches authorize no button click")
    Reset("changed")
    failed := false
    try UM14_ActivateTimescale()
    catch
        failed := true
    Need(failed && clicks.Length = 1 && !state.Has("Timescale"), "Changed client stops before any dialog action")

    for mode in ["OFF", "Multiplayer", "Pizza Party", "Badlands II", "Polluted Wasteland II"] {
        Reset("empty")
        if (mode = "OFF")
            UseTimeScale := false
        else if (mode = "Multiplayer")
            MultiplayerEnabled := true
        else
            difficulty := mode
        Need(!UM14_ActivateTimescale() && !TimescaleActive && TimeScaleMultiplier = 1 && !clicks.Length,
            "An excluded or disabled mode clears stale speed without input: " mode)
    }
    FileAppend("Timescale regressions passed.`n", "*")
    ExitApp(0)
} catch Error as err {
    FileAppend(err.Message "`n" err.Stack "`n", "*")
    ExitApp(1)
}
