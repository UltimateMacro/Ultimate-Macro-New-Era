#Requires AutoHotkey v2.0
#SingleInstance Force

#Include %A_LineFile%/../../lib/Roblox.ahk
#Include %A_LineFile%/../../lib/ToolWindow.ahk
#Include %A_LineFile%/../../lib/ImageSearch/ImageSearch.ahk

SetWorkingDir(A_ScriptDir "\..")

global unfocusX := 150, unfocusY := 200
global isRunning := false
global usedt := 0

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

F3::StartMacro()
F4::StopMacro()

StartMacro() {
    global IsRunning
    if (IsRunning)
        return
    if !GetRobloxHWND() {
        SetToolWindowStatus("Roblox not found", true)
        return
    }

    IsRunning := true
    SetToolWindowStatus("Running")
    SetTimer(StartSpinningtheWheel, 100)
}

StopMacro() {
    global IsRunning, usedt, usedtickets_text
    if (!IsRunning)
        return
    IsRunning := false

    usedt := 0
    usedtickets_text.Value := "Total used tickets: " usedt
    usedtickets_text.Redraw()

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
        SetTimer(StartSpinningtheWheel, 100)
}

SpinWheel() {
    global IsRunning, usedt, usedtickets_text, unfocusX, unfocusY
    if !ActivateRoblox() {
        StopMacro()
        SetToolWindowStatus("Roblox not found", true)
        return
    }

    if (!IsRunning)
        return

    SendEvent("{e}")
    usedt++
    usedtickets_text.Value := "Total used tickets: " usedt
    usedtickets_text.Redraw()

    startTime := A_TickCount
    getRobloxPos(,,&w,&h)
    Loop {
        if (!IsRunning)
            break

        if (A_TickCount - startTime > 15000)
            break

        resConfirm := AdvImageSearch("Resources/claimreward.png", Round(w*0.3), Round(h*0.5), Round(w*0.4), Round(h*0.5))

        if (resConfirm.status == "success" && resConfirm.score > 0.65) {
            Click(resConfirm.x, resConfirm.y)
            MouseMove(ScaleX(unfocusX), ScaleY(unfocusY))
            Sleep(800)
            break
        }
        Sleep(250)
    }
}

ScaleX(baseX, Width := 1920) {
    getRobloxPos(&pX, &pY, &currentWidth, &currentHeight)
    return currentWidth > 0 ? Round(baseX * (currentWidth / Width)) : baseX
}

ScaleY(baseY, Height := 1009) {
    getRobloxPos(&pX, &pY, &currentWidth, &currentHeight)
    return currentHeight > 0 ? Round(baseY * (currentHeight / Height)) : baseY
}
