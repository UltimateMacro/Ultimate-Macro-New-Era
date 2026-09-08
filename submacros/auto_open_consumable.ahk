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
global aGui := CreateToolWindow("Auto Consumables", TOOL_W)

aGui.SetFont("s9 w400 cAAAAAA", ToolWindowFont())
global text := aGui.Add("Text", "x14 y50 w222 h36 BackgroundTrans",
    "Opens consumable crates automatically and claims what is inside.")

aGui.Add("Progress", "x14 y94 w222 h1 Disabled Background222222", 0)

aGui.SetFont("s9 w400 cFFFFFF", ToolWindowFont())
global usedtickets_text := aGui.Add("Text", "x14 y106 w222 h22 0x200 BackgroundTrans", "Crates opened: " usedt)

aGui.SetFont("s8 w400 c7E848E", ToolWindowFont())
global hint_text := aGui.Add("Text", "x14 y140 w222 h32 BackgroundTrans",
    "Open your crate inventory in Roblox first.`nF3 starts the tool, F4 stops it.")

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
    SetTimer(StartOpeningCrates, 100)
}

StopMacro() {
    global IsRunning
    if (!IsRunning)
        return
    IsRunning := false

    SetToolWindowStatus("Stopped")
    SetTimer(StartOpeningCrates, 0)
}

StartOpeningCrates() {
    global IsRunning

    if (!IsRunning)
        return

    SetTimer(StartOpeningCrates, 0)
    OpenCrate()

    if (IsRunning)
        SetTimer(StartOpeningCrates, 100)
}

OpenCrate() {
    global IsRunning, usedt, unfocusX, unfocusY, usedtickets_text
    if !ActivateRoblox() {
        StopMacro()
        SetToolWindowStatus("Roblox not found", true)
        return
    }

    if (!IsRunning)
        return

    getRobloxPos(,,&w,&h)
    if (w <= 0 || h <= 0) {
        StopMacro()
        return
    }

    startTime := A_TickCount

    Loop {
        if (!IsRunning)
            return

        resOpen := AdvImageSearch("Resources/open.png", Round(w*0.25), Round(h*0.6), Round(w*0.5), h)
        if (resOpen.status == "success" && resOpen.score > 0.7) {
            Click(resOpen.x, resOpen.y)
            MouseMove(ScaleX(unfocusX), ScaleY(unfocusY))
            Sleep(550)
            break
        }

        if (A_TickCount - startTime > 3000) {
            SetToolWindowStatus("No crate to open", true)
            StopMacro()
            return
        }

        Sleep(75)
    }

    loop 15 {
        Click(Round(w*0.5),Round(h*0.5))
        Sleep 5
    }

    usedt++
    usedtickets_text.Value := "Crates opened: " usedt
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
    return currentWidth > 0 ? Round(baseX * (currentWidth / Width)) : baseX
}

ScaleY(baseY, Height := 1009) {
    getRobloxPos(&pX, &pY, &currentWidth, &currentHeight)
    return currentHeight > 0 ? Round(baseY * (currentHeight / Height)) : baseY
}
