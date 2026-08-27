#Requires AutoHotkey v2.0
#SingleInstance Force

#Include %A_LineFile%/../../lib/Roblox.ahk
#Include %A_LineFile%/../../lib/ImageSearch/ImageSearch.ahk

global AppDataOpt := A_AppData "\Ultimate_Macro\Options"
global SettingsFile := AppDataOpt "\Settings.tds"

if !DirExist(AppDataOpt)
    DirCreate(AppDataOpt)

SetWorkingDir(A_LineFile "/../../")

global ChainKey, BeatKey
ChainKey := IniRead(SettingsFile, "Hotkeys", "Chain", "C")
BeatKey := IniRead(SettingsFile, "Hotkeys", "Beat", "B")
global unfocusX := 150, unfocusY := 200

global LastChainTime := 0
global LastBeatTime := 0
global IsRunning := false

global aGui := Gui("+LastFound +Border +ToolWindow +AlwaysOnTop")

aGui.SetFont("s9")
global cooldown := aGui.Add("Edit", "vchainInterval Number Limit2 x75 y10 w50 h20", "10")
global cooldown_txt := aGui.Add("Text", "x10 y15 h20", "Chain every:")
global s_txt := aGui.Add("Text", "x132 y15 h20", "seconds")

global beatCooldown := aGui.Add("Edit", "vbeatInterval Number Limit2 x75 y35 w50 h20", "26")
global beatCooldown_txt := aGui.Add("Text", "x10 y40 h20", "Beat every:")
global s2_txt := aGui.Add("Text", "x132 y40 h20", "seconds")

global chkChain := aGui.Add("Checkbox", "vuseChain x10 y65 w180 h20 Checked", "Auto Call of Arms")
global chkBeat := aGui.Add("Checkbox", "vuseBeat x10 y85 w180 h20 Checked", "Auto Drop the Beat")

aGui.SetFont("s11")
global Start_Btn := aGui.Add("Button", "x10 y115 w85 h25", "Start (F3)")
global Stop_Btn := aGui.Add("Button", "x105 y115 w85 h25", "Stop (F4)")

Start_Btn.OnEvent("Click", (*) => StartMacro())
Stop_Btn.OnEvent("Click", (*) => StopMacro())

aGui.Show("w200 h150")
aGui.OnEvent("Close", (*) => ExitApp())
SetTimer(() => RemoveInitialFocus(), -50)

RemoveInitialFocus() {
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
    IsRunning := true
    aGui.Title := "auto_coa.ahk - Running"
    SetTimer(UseAbilities, 100)
}

StopMacro() {
    global IsRunning
    if (!IsRunning)
        return
    IsRunning := false
    aGui.Title := "auto_coa.ahk"
    SetTimer(UseAbilities, 0)
}

UseAbilities() {
    global LastChainTime, LastBeatTime
    v := aGui.Submit(false)

    if (v.useChain) {
        if (A_TickCount - LastChainTime > v.chainInterval * 1000) {
            if (waitForTowerUI()) {
                SendEvent("{RButton Up}")
                Click(ScaleX(unfocusX), ScaleY(unfocusY))
                Sleep(300)
                SendEvent("{" ChainKey "}")
                LastChainTime := A_TickCount
            } else {
            SendEvent("{" ChainKey "}")
            LastChainTime := A_TickCount
            }
        }
    }

    if (v.useBeat) {
        if (A_TickCount - LastBeatTime > v.beatInterval * 1000) {
            if (waitForTowerUI()) {
                SendEvent("{RButton Up}")
                Click(ScaleX(unfocusX), ScaleY(unfocusY))
                Sleep(300)
                SendEvent("{" BeatKey "}")
                LastBeatTime := A_TickCount
            } else {
            SendEvent("{" BeatKey "}")
            LastBeatTime := A_TickCount
            }
        }
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

waitForTowerUI(&resV2 := "", &resV1 := "") {
    StartTime := A_TickCount
    Loop {
        getRobloxPos(&rx, &ry, &w, &h)
        X1_v2 := 0
        Y1_v2 := Round(h/2)
        W_v2 := Round(w * 0.3) - X1_v2
        H_v2 := Round(h) - Y1_v2

        resV2 := AdvImageSearch("Resources\TowerUI\Variant2.png", X1_v2, Y1_v2, W_v2, H_v2, ,,0.05)

        if (resV2.status == "success" && resV2.score > 0.55) {
            return true
        }

        Sleep(30)

        X1_v1 := 0
        Y1_v1 := 0
        W_v1  := Round(w * 0.3) - X1_v1
        H_v1 := Round(h * 0.4) - Y1_v1
        resV1 := AdvImageSearch("Resources\TowerUI\Variant1.png", X1_v1, Y1_v1, W_v1, H_v1, ,,0.05)

        if (resV1.status == "success" && resV1.score > 0.68) {
            return true
        }
        Sleep(30)


        if (A_TickCount - StartTime > 1000) {
            return false
        }

    }
}