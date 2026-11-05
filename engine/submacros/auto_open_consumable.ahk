#Requires AutoHotkey v2.0
#SingleInstance Force

#Include %A_LineFile%/../../lib/Roblox.ahk
#Include %A_LineFile%/../../lib/ImageSearch/ImageSearch.ahk

SetWorkingDir(A_ScriptDir "\..")

global unfocusX := 150, unfocusY := 200

UM14_CrateForeground() {
    hwnd := GetRobloxHWND()
    root := hwnd ? DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") : 0
    return hwnd && WinActive("ahk_id " (root ? root : hwnd))
}
UM14_CrateGuard() {
    global IsRunning
    if (!IsRunning || !UM14_CrateForeground()) {
        StopMacro()
        return false
    }
    return true
}
UM14_CrateClick(x, y) {
    if (UM14_CrateGuard())
        Click(x, y)
}
UM14_CrateMove(x, y) {
    if (UM14_CrateGuard())
        MouseMove(x, y)
}
UM14_CrateTap() {
    if (UM14_CrateGuard())
        MouseClick()
}
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

#HotIf UM14_CrateForeground()
F3::StartMacro()
#HotIf
F4::StopMacro()

StartMacro() {
    global IsRunning
    if (IsRunning)
        return
    if (!ActivateRoblox())
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
    if (!UM14_CrateGuard())
        return

    if (!IsRunning)
        return

    getRobloxPos(,,&w,&h)

    startTime := A_TickCount

    Loop {
        if (!UM14_CrateGuard())
            return
        Sleep(75)
        resOpen := AdvImageSearch("Resources/open.png", Round(w*0.25), Round(h*0.6), Round(w*0.5), h)
        if (resOpen.status == "success" && resOpen.score > 0.7) {
            UM14_CrateClick(resOpen.x, resOpen.y)
            UM14_CrateMove(ScaleX(unfocusX), ScaleY(unfocusY))
            Sleep(550)
            break
        } 
        if (A_TickCount - startTime > 3000) {
            StopMacro()
            return
        }
    }

    loop 15 {
        UM14_CrateClick(Round(w*0.5),Round(h*0.5))
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
            UM14_CrateClick(resConfirm.x, resConfirm.y)
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
            UM14_CrateMove(resConfirm.x, resConfirm.y)
            Sleep 30
            UM14_CrateTap()
            Sleep 50
            UM14_CrateMove(ScaleX(unfocusX), ScaleY(unfocusY))
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
