; Timescale is optional. An empty balance must not restart a healthy match.
UM14_TimescaleButton(identity, name) {
    if !UM14_ConnectionSame(identity)
        UM14_Fatal("Roblox changed while checking the timescale dialog.")
    result := AdvancedImageSearch("Resources/" name ".png", Round(identity.w*.25),
        Round(identity.h*.35), Round(identity.w*.5), Round(identity.h*.5))
    if !UM14_ConnectionSame(identity)
        UM14_Fatal("Roblox changed while checking the timescale dialog.")
    return IsObject(result) && result.status = "success" && result.score >= .75 ? result : false
}

UM14_TimescaleClick(identity, button) {
    UM14_RequireReadyFocus()
    UM14_RequireInputPoint(identity, button.x, button.y)
    MouseMove(button.x, button.y, 0)
    Sleep(180)
    UM14_RequireInputPoint(identity, button.x, button.y)
    Click("Down")
    try Sleep(100)
    finally Click("Up")
}

UM14_TimescaleFallback(identity, reason) {
    global TimescaleActive, TimeScaleMultiplier, UseTimeScale, StateFile
    TimescaleActive := false, TimeScaleMultiplier := 1, UseTimeScale := false
    ; This state lasts for this Start only; Engine.Prepare clears it next time.
    IniWrite(1, StateFile, "State", "TimescaleUnavailable")
    Loop 2 {
        dialogOpen := IsObject(UM14_TimescaleButton(identity, "GetMore"))
            || IsObject(UM14_TimescaleButton(identity, "confirm"))
        if !dialogOpen
            break
        cancel := UM14_TimescaleButton(identity, "cancel")
        if !IsObject(cancel)
            UM14_Fatal("Timescale is unavailable, but its Cancel button could not be verified. Close the dialog and retry with timescale OFF. No purchase or restart was attempted.")
        UM14_TimescaleClick(identity, cancel)
        Sleep(180)
    }
    if (IsObject(UM14_TimescaleButton(identity, "GetMore"))
        || IsObject(UM14_TimescaleButton(identity, "confirm")))
        UM14_Fatal("The timescale dialog did not close. Close it and retry with timescale OFF. No purchase or restart was attempted.")
    LogToConsole("Timescale unavailable (" reason "). Continuing at normal speed for this run.", true, false)
    return false
}

UM14_ActivateTimescale() {
    global UseTimeScale, TimeScaleMode, TimeScaleMultiplier, difficulty, AutorunStartTime,
        MultiplayerEnabled, TimescaleActive, StateFile
    TimescaleActive := false, TimeScaleMultiplier := 1
    if (!UseTimeScale || MultiplayerEnabled || difficulty = "Pizza Party"
        || difficulty = "Badlands II" || difficulty = "Polluted Wasteland II")
        return false
    if (IniRead(StateFile, "State", "TimescaleUnavailable", "0") = "1") {
        UseTimeScale := false
        return false
    }
    UM14_RequireReadyFocus()
    identity := UM14_ConnectionSnapshot()
    if !IsObject(identity)
        UM14_Fatal("Roblox is not ready for timescale input.")
    LogToConsole("Applying timescale: " TimeScaleMode ". Please enable UI Navigation Toggle.")
    UM14_TimescaleClick(identity, {x:Round(identity.w*.5), y:Round(identity.h*.5)})
    navigationOpen := false
    try {
        Send("#")
        Send("{sc02B}")
        navigationOpen := true
        Sleep(80)
        Loop 10 {
            UM14_RequireReadyFocus()
            Send("{Down}")
            Sleep(25)
        }
        Loop 20 {
            UM14_RequireReadyFocus()
            Send("{Left}")
            Sleep(25)
        }
        Send("{Right}")
        Sleep(80)
        Send("{Enter}")
        confirm := false
        Loop 8 {
            Sleep(150)
            ; Never click Get More: it leads to the purchase flow.
            if IsObject(UM14_TimescaleButton(identity, "GetMore"))
                return UM14_TimescaleFallback(identity, "no tickets")
            confirm := UM14_TimescaleButton(identity, "confirm")
            if IsObject(confirm)
                break
        }
        if !IsObject(confirm)
            return UM14_TimescaleFallback(identity, "confirmation was not found")
        UM14_TimescaleClick(identity, confirm)
        dismissed := 0
        Loop 8 {
            Sleep(150)
            if IsObject(UM14_TimescaleButton(identity, "GetMore"))
                return UM14_TimescaleFallback(identity, "no tickets")
            dismissed := IsObject(UM14_TimescaleButton(identity, "confirm")) ? 0 : dismissed+1
            if (dismissed >= 2)
                break
        }
        if (dismissed < 2)
            return UM14_TimescaleFallback(identity, "confirmation did not close")
        UM14_RequireReadyFocus()
        if !UM14_ConnectionSame(identity)
            UM14_Fatal("Roblox changed before setting timescale speed.")
        Loop (TimeScaleMode = "2x" ? 2 : 1) {
            Sleep(80)
            Send("{Enter}")
        }
        TimescaleActive := true
        TimeScaleMultiplier := TimeScaleMode = "2x" ? 2 : 1.5
        timescales := Integer(IniRead(StateFile, "State", "Timescale", 0))+1
        IniWrite(timescales, StateFile, "State", "Timescale")
        LogToConsole("-1 Timescale ticket. Total Timescale Tickets Used: " timescales)
        SendToWebhookInstant("[" FormatRuntime(AutorunStartTime) "] -1 Timescale ticket. `n-# Total Timescale Tickets Used: " timescales, 12370112, false)
        return true
    } finally {
        if (navigationOpen && UM14_ConnectionSame(identity)) {
            UM14_RequireReadyFocus()
            Send("{sc02B}")
            Send("#")
        }
    }
}
