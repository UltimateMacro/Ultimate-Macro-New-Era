#Requires AutoHotkey v2.0
#SingleInstance Force

#Include %A_LineFile%/../../lib/Roblox.ahk
#Include %A_LineFile%/../../lib/ToolWindow.ahk
#Include %A_LineFile%/../../lib/ImageSearch/ImageSearch.ahk

SetWorkingDir(A_ScriptDir "\..")

global SPIN_CYCLE_MS := 100
global SPIN_POLL_MS := 100
global SPIN_REWARD_TIMEOUT_MS := 8000
global SPIN_CLEAR_TIMEOUT_MS := 2500
global SPIN_MAX_MISSES := 3
global SPIN_MATCH_SCORE := 0.65

global unfocusX := 150, unfocusY := 200
global IsRunning := false
global usedt := 0
global missedSpins := 0

global TOOL_W := 250
global aGui := CreateToolWindow("Auto Spin", TOOL_W)

aGui.SetFont("s9 w400 cAAAAAA", ToolWindowFont())
global text := aGui.Add("Text", "x14 y50 w222 h36 BackgroundTrans",
    "Claims prizes automatically from the spinning wheel.")

aGui.Add("Progress", "x14 y94 w222 h1 Disabled Background222222", 0)

aGui.SetFont("s9 w400 cFFFFFF", ToolWindowFont())
global usedtickets_text := aGui.Add("Text", "x14 y106 w222 h22 0x200 BackgroundTrans", "Total used tickets: " usedt)

aGui.SetFont("s8 w400 c7E848E", ToolWindowFont())
global hint_text := aGui.Add("Text", "x14 y140 w222 h32 BackgroundTrans",
    "Open the spinning wheel in Roblox first.`nF3 starts the tool, F4 stops it.")

global Start_Btn := AddToolWindowButton(aGui, 14, 186, 108, 30, "Start (F3)", (*) => StartMacro())
global Stop_Btn := AddToolWindowButton(aGui, 128, 186, 108, 30, "Stop (F4)", (*) => StopMacro())

AddToolWindowStatus(aGui, 14, 224, 222)

ShowToolWindow(aGui, TOOL_W, 252)
aGui.OnEvent("Close", CloseToolWindow)

SetTimer(() => RemoveInitialFocus(), -50)

RemoveInitialFocus() {
    global aGui, text
    if !WinActive("ahk_id " aGui.Hwnd)
        return
    ControlFocus(text, "ahk_id " aGui.Hwnd)
}

F3:: StartMacro()
F4:: StopMacro()

SetUsedTickets(value) {
    global usedt, usedtickets_text
    usedt := value
    usedtickets_text.Value := "Total used tickets: " usedt
    usedtickets_text.Redraw()
}

StartMacro() {
    global IsRunning, missedSpins
    if (IsRunning)
        return
    if !GetRobloxHWND() {
        SetToolWindowStatus("Roblox not found", true)
        return
    }

    IsRunning := true
    missedSpins := 0
    SetUsedTickets(0)
    SetToolWindowStatus("Running")
    SetTimer(StartSpinningtheWheel, SPIN_CYCLE_MS)
}

StopMacro() {
    global IsRunning
    if (!IsRunning)
        return
    IsRunning := false

    SetToolWindowStatus("Stopped")
    SetTimer(StartSpinningtheWheel, 0)
}

StartSpinningtheWheel() {
    global IsRunning

    if (!IsRunning)
        return

    SetTimer(StartSpinningtheWheel, 0)
    SpinWheel()

    if (IsRunning)
        SetTimer(StartSpinningtheWheel, SPIN_CYCLE_MS)
}

FindClaimPrompt() {
    if !getRobloxPos(, , &w, &h)
        return 0
    if (w <= 0 || h <= 0)
        return 0

    res := AdvImageSearch("Resources/claimreward.png", Round(w * 0.3), Round(h * 0.5), Round(w * 0.4), Round(h * 0.5))
    if (res.status == "success" && res.score > SPIN_MATCH_SCORE)
        return res
    return 0
}

WaitForClaimPrompt(timeoutMs) {
    global IsRunning

    deadline := A_TickCount + timeoutMs
    loop {
        if (!IsRunning)
            return 0
        res := FindClaimPrompt()
        if (IsObject(res))
            return res
        if (A_TickCount >= deadline)
            return 0
        Sleep(SPIN_POLL_MS)
    }
}

WaitForClaimPromptCleared(timeoutMs) {
    global IsRunning

    deadline := A_TickCount + timeoutMs
    loop {
        if (!IsRunning)
            return false
        if (!IsObject(FindClaimPrompt()))
            return true
        if (A_TickCount >= deadline)
            return false
        Sleep(SPIN_POLL_MS)
    }
}

ClaimReward(res) {
    global unfocusX, unfocusY

    Click(res.x, res.y)
    MouseMove(ScaleX(unfocusX), ScaleY(unfocusY))
}

CountUnproductiveCycle(reason) {
    global missedSpins

    missedSpins++
    if (missedSpins < SPIN_MAX_MISSES)
        return false

    StopMacro()
    SetToolWindowStatus(reason, true)
    return true
}

SpinWheel() {
    global IsRunning, usedt, missedSpins

    if !ActivateRoblox() {
        StopMacro()
        SetToolWindowStatus("Roblox not found", true)
        return
    }

    if (!IsRunning)
        return

    leftover := FindClaimPrompt()
    if (IsObject(leftover)) {
        ClaimReward(leftover)
        if (!WaitForClaimPromptCleared(SPIN_CLEAR_TIMEOUT_MS)) {
            if (!IsRunning)
                return
            if (CountUnproductiveCycle("Reward prompt will not close"))
                return
            SetToolWindowStatus("Clearing the previous reward...")
            return
        }
        if (!IsRunning)
            return
    }

    SendEvent("{e}")

    res := WaitForClaimPrompt(SPIN_REWARD_TIMEOUT_MS)
    if (!IsObject(res)) {
        if (!IsRunning)
            return
        if (CountUnproductiveCycle("No tickets or wheel closed"))
            return
        SetToolWindowStatus("Waiting for the wheel...")
        return
    }

    ClaimReward(res)
    missedSpins := 0
    SetUsedTickets(usedt + 1)
    SetToolWindowStatus("Running")

    WaitForClaimPromptCleared(SPIN_CLEAR_TIMEOUT_MS)
}

ScaleX(baseX, Width := 1920) {
    getRobloxPos(&pX, &pY, &currentWidth, &currentHeight)
    return currentWidth > 0 ? Round(baseX * (currentWidth / Width)) : baseX
}

ScaleY(baseY, Height := 1009) {
    getRobloxPos(&pX, &pY, &currentWidth, &currentHeight)
    return currentHeight > 0 ? Round(baseY * (currentHeight / Height)) : baseY
}