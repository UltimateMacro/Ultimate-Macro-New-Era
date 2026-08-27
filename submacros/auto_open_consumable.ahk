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
global text := aGui.Add("Text", "x10 y10 w180 h50 BackgroundTrans", "The tool for auto opening consumable crates.")

global usedtickets_text := aGui.Add("Text", "x10 y50 w180 BackgroundTrans", "Total opened consumable crates: " usedt)

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

    try aGui.Title := "Running..."

    SetTimer(StartSpinningtheWheel, 100)
}

StopMacro() {
    global IsRunning, usedt
    if (!IsRunning)
        return
    IsRunning := false

    try aGui.Title := "auto_open_consumable.ahk"

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

    getRobloxPos(,,&w,&h)

    startTime := A_TickCount

    Loop {
        resOpen := AdvImageSearch("Resources/open.png", Round(w*0.25), Round(h*0.6), Round(w*0.5), h)
        if (resOpen.score > 0.7) {
            Click(resOpen.x, resOpen.y)
            MouseMove(ScaleX(unfocusX), ScaleY(unfocusY))
            Sleep(550)
            break
        } 
        if (A_TickCount - startTime > 3000) {
            StopMacro()
            return
        }
    }

    loop 15 {
        Click(Round(w*0.5),Round(h*0.5))
        Sleep 5
    }

    usedt++
    usedtickets_text.Value := "Total opened consumable crates: " usedt
    usedtickets_text.Redraw()

    getRobloxPos(,,&w,&h)

    attempts := 0
    Loop {
        if (!IsRunning)
            break
            
        resConfirm := AdvImageSearch("Resources/next.png", Round(w*0.25), Round(h*0.6), Round(w*0.5), h)
        
        if (resConfirm.status == "success" && resConfirm.score > 0.55) {
            oldMode := A_SendMode
            oldDelay := A_MouseDelay
            SetMouseDelay(0)
            SendMode('Input')
            Loop 30 {
            Click(resConfirm.x, resConfirm.y)
            Sleep(1)
            }
            SetMouseDelay(oldDelay)
            SendMode(oldMode)
            break
        } else {
            try aGui.Title := resConfirm.score
            attempts++
            Sleep 50
        }

        resConfirm := AdvImageSearch("Resources/claim_c.png", Round(w*0.25), Round(h*0.6), Round(w*0.5), h)
        if (resConfirm.status == "success" && resConfirm.score > 0.55) {
            MouseMove(resConfirm.x, resConfirm.y)
            Sleep 30
            MouseClick()
            Sleep 50
            MouseMove(ScaleX(unfocusX), ScaleY(unfocusY))
            Sleep(300)
            break
        }

        if attempts > 10 
            break

        
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
