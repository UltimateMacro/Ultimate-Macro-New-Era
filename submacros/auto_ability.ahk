#Requires AutoHotkey v2.0
#SingleInstance Force

#Include %A_LineFile%/../../lib/Roblox.ahk
#Include %A_LineFile%/../../lib/ToolWindow.ahk
#Include %A_LineFile%/../../lib/ImageSearch/ImageSearch.ahk

global AppDataOpt := A_AppData "\Ultimate_Macro\Options"
global SettingsFile := AppDataOpt "\Settings.tds"

if !DirExist(AppDataOpt)
    DirCreate(AppDataOpt)

SetWorkingDir(A_ScriptDir "\..")

global ChainKey, BeatKey
ChainKey := IniRead(SettingsFile, "Hotkeys", "Chain", "C")
BeatKey := IniRead(SettingsFile, "Hotkeys", "Beat", "B")
global unfocusX := 150, unfocusY := 200

global LastChainTime := 0
global LastBeatTime := 0
global IsRunning := false

global TOOL_W := 250
global aGui := CreateToolWindow("Auto Abilities", TOOL_W)

aGui.SetFont("s9 w400 cAAAAAA", ToolWindowFont())
global cooldown_txt := aGui.Add("Text", "x14 y50 w88 h22 0x200 BackgroundTrans", "Chain every:")
aGui.SetFont("s9 w400 c000000", ToolWindowFont())
global cooldown := aGui.Add("Edit", "vchainInterval Number Limit2 Center x108 y50 w50 h22", "10")
aGui.SetFont("s9 w400 cAAAAAA", ToolWindowFont())
global s_txt := aGui.Add("Text", "x166 y50 w70 h22 0x200 BackgroundTrans", "seconds")

aGui.SetFont("s9 w400 cAAAAAA", ToolWindowFont())
global beatCooldown_txt := aGui.Add("Text", "x14 y80 w88 h22 0x200 BackgroundTrans", "Beat every:")
aGui.SetFont("s9 w400 c000000", ToolWindowFont())
global beatCooldown := aGui.Add("Edit", "vbeatInterval Number Limit2 Center x108 y80 w50 h22", "26")
aGui.SetFont("s9 w400 cAAAAAA", ToolWindowFont())
global s2_txt := aGui.Add("Text", "x166 y80 w70 h22 0x200 BackgroundTrans", "seconds")

aGui.Add("Progress", "x14 y112 w222 h1 Disabled Background222222", 0)

aGui.SetFont("s9 w400 cFFFFFF", ToolWindowFont())
global chkChain := aGui.Add("Checkbox", "vuseChain x14 y124 w222 h22 Checked", "  Auto Call of Arms")
global chkBeat := aGui.Add("Checkbox", "vuseBeat x14 y150 w222 h22 Checked", "  Auto Drop the Beat")

global Start_Btn := AddToolWindowButton(aGui, 14, 186, 108, 30, "Start (F3)", (*) => StartMacro())
global Stop_Btn := AddToolWindowButton(aGui, 128, 186, 108, 30, "Stop (F4)", (*) => StopMacro())

AddToolWindowStatus(aGui, 14, 224, 222)

ShowToolWindow(aGui, TOOL_W, 252)
aGui.OnEvent("Close", CloseToolWindow)
SetTimer(() => RemoveInitialFocus(), -50)

RemoveInitialFocus() {
    global aGui, s_txt
    if !WinActive("ahk_id " aGui.Hwnd)
        return
    ControlFocus(s_txt, "ahk_id " aGui.Hwnd)
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
    SetTimer(UseAbilities, 100)
}

StopMacro() {
    global IsRunning
    if (!IsRunning)
        return
    IsRunning := false
    SetToolWindowStatus("Stopped")
    SetTimer(UseAbilities, 0)
}

UseAbilities() {
    global LastChainTime, LastBeatTime, aGui, unfocusX, unfocusY, ChainKey, BeatKey

    if !GetRobloxHWND() {
        StopMacro()
        SetToolWindowStatus("Roblox not found", true)
        return
    }

    v := aGui.Submit(false)

    if (v.useChain && A_TickCount - LastChainTime > v.chainInterval * 1000) {
        if (waitForTowerUI()) {
            SendEvent("{RButton Up}")
            Click(ScaleX(unfocusX), ScaleY(unfocusY))
            Sleep(300)
        }
        SendEvent("{" ChainKey "}")
        LastChainTime := A_TickCount
    }

    if (v.useBeat && A_TickCount - LastBeatTime > v.beatInterval * 1000) {
        if (waitForTowerUI()) {
            SendEvent("{RButton Up}")
            Click(ScaleX(unfocusX), ScaleY(unfocusY))
            Sleep(300)
        }
        SendEvent("{" BeatKey "}")
        LastBeatTime := A_TickCount
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

waitForTowerUI(&resV2 := "", &resV1 := "") {
    if !GetRobloxHWND()
        return false

    StartTime := A_TickCount
    Loop {
        getRobloxPos(&rx, &ry, &w, &h)
        if (w <= 0 || h <= 0)
            return false

        X1_v2 := 0
        Y1_v2 := Round(h/2)
        W_v2 := Round(w * 0.3) - X1_v2
        H_v2 := Round(h) - Y1_v2

        resV2 := AdvImageSearch("Resources\TowerUI\Variant2.png", X1_v2, Y1_v2, W_v2, H_v2, ,,0.05)
        if (resV2.status == "success" && resV2.score > 0.55)
            return true

        Sleep(30)

        X1_v1 := 0
        Y1_v1 := 0
        W_v1  := Round(w * 0.3) - X1_v1
        H_v1 := Round(h * 0.4) - Y1_v1
        resV1 := AdvImageSearch("Resources\TowerUI\Variant1.png", X1_v1, Y1_v1, W_v1, H_v1, ,,0.05)

        if (resV1.status == "success" && resV1.score > 0.68)
            return true

        Sleep(30)

        if (A_TickCount - StartTime > 1000)
            return false
    }
}
