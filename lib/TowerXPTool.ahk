#Requires AutoHotkey v2.0

global TowerXPToolGui := 0
global TowerXPToolRows := []
global TowerXPToolEnabledCtrl := 0
global TowerXPToolStopModeCtrl := 0
global TowerXPToolMessageCtrl := 0

ShowTowerXPTool(*) {
    global MainGui, AppDataOpt, SettingsFile
    global TowerXPToolGui, TowerXPToolRows, TowerXPToolEnabledCtrl, TowerXPToolStopModeCtrl, TowerXPToolMessageCtrl

    statePath := TowerXPStatePath(AppDataOpt)
    TowerXPMigrateLegacy(SettingsFile, statePath)
    config := TowerXPReadConfig(statePath)

    if IsObject(TowerXPToolGui) {
        try TowerXPToolGui.Show()
        try WinActivate("ahk_id " TowerXPToolGui.Hwnd)
        return
    }

    TowerXPToolGui := Gui("+Owner" MainGui.Hwnd " +MinSize650x490", "Tower XP Tracker")
    TowerXPToolGui.BackColor := "0D0E12"
    TowerXPToolGui.SetFont("s9 cFFFFFF", "Segoe UI")

    TowerXPToolGui.SetFont("s15 w600 c3A86FF")
    TowerXPToolGui.Add("Text", "x22 y16 w606 h26", "Tower XP Tracker")
    TowerXPToolGui.SetFont("s9 w600 cFFB347")
    TowerXPToolGui.Add("Text", "x22 y46 w606 h34",
        "IMPORTANT - Set every tracked tower's current level and XP in level before enabling the tracker.")

    TowerXPToolEnabledCtrl := TowerXPToolGui.Add("Checkbox", "x22 y88 w170 h22", "Enable XP tracking")
    TowerXPToolEnabledCtrl.Value := config.enabled
    TowerXPToolGui.Add("Text", "x330 y90 w90 h20 Right", "Stop macro:")
    stopOptions := ["Never", "Any selected tower", "All selected towers"]
    TowerXPToolStopModeCtrl := TowerXPToolGui.Add("DropDownList", "x430 y86 w198 Choose1", stopOptions)
    TowerXPToolStopModeCtrl.Text := TowerXPStopModeLabel(config.stopMode)

    TowerXPToolGui.SetFont("s8 w600 c9AA4B2")
    TowerXPToolGui.Add("Text", "x22 y124 w45 h20", "TRACK")
    TowerXPToolGui.Add("Text", "x82 y124 w138 h20", "TOWER")
    TowerXPToolGui.Add("Text", "x232 y124 w60 h20 Center", "LEVEL")
    TowerXPToolGui.Add("Text", "x310 y124 w76 h20 Center", "XP IN LEVEL")
    TowerXPToolGui.Add("Text", "x404 y124 w112 h20 Center", "NEXT LEVEL")
    TowerXPToolGui.Add("Text", "x548 y124 w80 h20 Center", "STOP TARGET")

    TowerXPToolRows := []
    rowY := 148
    for definition in TowerXPDefinitions() {
        saved := config.towers[definition.name]
        trackCtrl := TowerXPToolGui.Add("Checkbox", "x30 y" rowY " w18 h20")
        trackCtrl.Value := saved.tracked
        TowerXPToolGui.SetFont("s9 w400 cFFFFFF")
        TowerXPToolGui.Add("Text", "x82 y" rowY " w138 h20 +0x200", definition.name)
        ; Native Edit controls use a light background. Set their foreground on
        ; the Gui before creation, matching the working input pattern in Main.
        TowerXPToolGui.SetFont("s9 w400 c000000")
        levelCtrl := TowerXPToolGui.Add("Edit", "x240 y" rowY " w52 h20 Center Number Limit2", saved.level)
        xpCtrl := TowerXPToolGui.Add("Edit", "x316 y" rowY " w70 h20 Center Number Limit7", saved.xp)
        TowerXPToolGui.SetFont("s9 w400 cFFFFFF")
        nextText := saved.level >= definition.maxLevel ? "MAX" : saved.xp "/" TowerXPNextRequired(definition, saved.level) " XP"
        nextCtrl := TowerXPToolGui.Add("Text", "x404 y" rowY " w112 h20 Center +0x200", nextText)
        stopCtrl := TowerXPToolGui.Add("Checkbox", "x578 y" rowY " w18 h20")
        stopCtrl.Value := saved.stopTarget
        row := { definition: definition, track: trackCtrl, level: levelCtrl, xp: xpCtrl, next: nextCtrl, stop: stopCtrl }
        TowerXPToolRows.Push(row)
        levelCtrl.OnEvent("Change", TowerXPToolRefreshPreview.Bind(row))
        xpCtrl.OnEvent("Change", TowerXPToolRefreshPreview.Bind(row))
        rowY += 28
    }

    TowerXPToolGui.SetFont("s8 w600 cFF626E")
    TowerXPToolGui.Add("Text", "x22 y376 w606 h34",
        "DEFAULT SKINS REQUIRED - tracked towers must use their default skin. Alternate skins cannot be identified safely and are left unchanged.")
    TowerXPToolGui.SetFont("s9 w400 cC8CDD8")
    TowerXPToolMessageCtrl := TowerXPToolGui.Add("Text", "x22 y414 w606 h22 Center", "")

    cancelBtn := TowerXPToolGui.Add("Button", "x22 y447 w194 h32", "Cancel")
    saveBtn := TowerXPToolGui.Add("Button", "x228 y447 w400 h32 Default", "Save Tower XP settings")
    cancelBtn.OnEvent("Click", TowerXPToolClose)
    saveBtn.OnEvent("Click", TowerXPToolSave)
    TowerXPToolGui.OnEvent("Close", TowerXPToolClose)
    TowerXPToolGui.OnEvent("Escape", TowerXPToolClose)
    TowerXPToolGui.Show("w650 h490")
}

TowerXPToolRefreshPreview(row, *) {
    if (!IsObject(row))
        return
    level := IsNumber(row.level.Text) ? Integer(row.level.Text) : 0
    xp := IsNumber(row.xp.Text) ? Integer(row.xp.Text) : 0
    level := Max(0, Min(row.definition.maxLevel, level))
    if (level >= row.definition.maxLevel)
        row.next.Text := "MAX"
    else
        row.next.Text := xp "/" TowerXPNextRequired(row.definition, level) " XP"
}

TowerXPToolSave(*) {
    global AppDataOpt, TowerXPToolRows, TowerXPToolEnabledCtrl, TowerXPToolStopModeCtrl, TowerXPToolMessageCtrl

    statePath := TowerXPStatePath(AppDataOpt)
    ; Preserve the processed-run key and last observed reward metadata. Saving
    ; UI preferences while a results screen is present must not make that same
    ; Triumph eligible to be counted twice.
    config := TowerXPReadConfig(statePath)
    config.enabled := TowerXPToolEnabledCtrl.Value ? 1 : 0
    config.stopMode := TowerXPStoredStopMode(TowerXPToolStopModeCtrl.Text)
    for row in TowerXPToolRows {
        saved := config.towers[row.definition.name]
        saved.tracked := row.track.Value ? 1 : 0
        saved.level := IsNumber(row.level.Text) ? Integer(row.level.Text) : -1
        saved.xp := IsNumber(row.xp.Text) ? Integer(row.xp.Text) : -1
        saved.stopTarget := row.stop.Value ? 1 : 0
    }

    validation := TowerXPValidateConfig(config)
    if (!validation.ok) {
        TowerXPToolMessageCtrl.SetFont("cFF626E")
        TowerXPToolMessageCtrl.Text := validation.message
        return
    }

    try {
        TowerXPPersistConfig(config, statePath)
        TowerXPToolMessageCtrl.SetFont("c6BD89B")
        TowerXPToolMessageCtrl.Text := "Tower XP settings saved locally."
        TowerXPRefreshMainStatus()
    } catch Error as err {
        TowerXPToolMessageCtrl.SetFont("cFF626E")
        TowerXPToolMessageCtrl.Text := "Could not save settings: " err.Message
    }
}

TowerXPRefreshMainStatus() {
    global AppDataOpt, TowerXPToolStatus
    try TowerXPToolStatus.Text := TowerXPStatusText(TowerXPStatePath(AppDataOpt))
}

TowerXPToolClose(*) {
    global TowerXPToolGui, TowerXPToolRows
    if IsObject(TowerXPToolGui)
        try TowerXPToolGui.Destroy()
    TowerXPToolGui := 0
    TowerXPToolRows := []
}
