#Requires AutoHotkey v2.0
#SingleInstance Force

#Include %A_LineFile%/../../lib/Roblox.ahk
#Include %A_LineFile%/../../lib/ImageSearch/ImageSearch.ahk

SetWorkingDir("%A_LineFile%/../../")

global unfocusX := 150, unfocusY := 200
global isRunning := false
global usedt := 0

global aGui := Gui("+LastFound +Border +ToolWindow +AlwaysOnTop")

aGui.SetFont("s9")
global text := aGui.Add("Text", "x10 y10 w180 h50 BackgroundTrans", "The tool for auto claiming prizes via spinning wheel.")

global usedtickets_text := aGui.Add("Text", "x10 y50 w180 BackgroundTrans", "Total used tickets: " usedt)

aGui.SetFont("s11")
global Start_Btn := aGui.Add("Button", "x10 y75 w85 h25", "Start (F3)")
global Stop_Btn := aGui.Add("Button", "x105 y75 w85 h25", "Stop (F4)")

Start_Btn.OnEvent("Click", (*) => StartMacro())
Stop_Btn.OnEvent("Click", (*) => StopMacro())

aGui.Show("w200 h110")
aGui.OnEvent("Close", (*) => ExitApp())

SetTimer(() => RemoveInitialFocus(), -50)

RemoveInitialFocus() {
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
    IsRunning := true

    try aGui.Title := "auto_spin.ahk - Running"

    SetTimer(StartSpinningtheWheel, 100)
}

StopMacro() {
    global IsRunning, usedt
    if (!IsRunning)
        return
    IsRunning := false

    usedt := 0
    usedtickets_text.Value := "Total used tickets: " usedt
    usedtickets_text.Redraw()

    try aGui.Title := "auto_spin.ahk"

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
    global IsRunning, usedt
    ActivateRoblox()

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

        if (A_TickCount - startTime > 15000) {
            break
        }
            
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
    return Round(baseX * (currentWidth / Width))
}

ScaleY(baseY, Height := 1009) {
    getRobloxPos(&pX, &pY, &currentWidth, &currentHeight)
    return Round(baseY * (currentHeight / Height))
}
