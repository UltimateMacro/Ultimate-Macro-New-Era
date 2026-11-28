RecordPageBuild(gui) {
    global RecordControls, RecordModifierChecks := Map(), RecordTutorial
    RecordControls := [Tab2_Lbl1, RecMapsD, Tab2_Lbl2, RecDiffCtrl, Tab2_Lbl3, Tab2_Lbl4, RecTowersCtrl,
        Tab2_Info1, Tab2_Line2, Tab2_Line3, RecAutoChainCtrl, RecAutoCaravanCtrl, RecAutoDropCtrl,
        RecAutoSkipCtrl, RecAbilitySpamCtrl, RecMoveCtrl, DIRECTIONTEXTCtrl, RecMoveDirCtrl, Tab2_Txt4,
        RecMoveDurCtrl, Tab2_Btn1, Tab2_Btn2]
    for row in [[Tab2_Lbl1,24,121,65,26], [RecMapsD,93,120,243,27], [Tab2_Lbl2,360,121,65,26],
        [RecDiffCtrl,429,120,247,27], [Tab2_Lbl4,24,158,65,26], [RecTowersCtrl,93,156,583,27],
        [Tab2_Info1,93,189,583,29], [Tab2_Lbl3,24,231,325,22], [Tab2_Line2,24,254,325,1],
        [Tab2_Line3,373,254,303,1], [RecMoveCtrl,24,432,130,28], [DIRECTIONTEXTCtrl,341,434,70,26],
        [RecMoveDirCtrl,415,430,58,27], [Tab2_Txt4,485,434,105,26], [RecMoveDurCtrl,595,430,81,27],
        [Tab2_Btn1,505,502,171,32], [Tab2_Btn2,393,502,100,32]]
        row[1].Move(row[2],row[3],row[4],row[5])
    Tab2_Info1.Text := "Separate tower names with commas. Use G before a golden tower name."
    AppearanceFont(gui, "s10 Norm c3A86FF", "Segoe UI")
    RecordControls.Push(AppearanceAdd(gui, "Text", "x24 y94 w310 h22 Hidden BackgroundTrans", "Strategy Setup"))
    RecordControls.Push(AppearanceAdd(gui, "Text", "x373 y231 w303 h22 Hidden BackgroundTrans", "Recording options"))
    AppearanceFont(gui, "s9 Norm cE2E4E7", "Segoe UI")
    for index, modifier in ["Broke","Exploding","Flying","Fog","Glass","Healthy","Hidden","Inflation","Jailed","Limitation","Committed","Quarantine","Speedy"] {
        x := 24 + Mod(index - 1, 3) * 109, y := 262 + Floor((index - 1) / 3) * 29
        ctrl := AppearanceAdd(gui, "Checkbox", "Hidden x" x " y" y " w105 h26", modifier)
        RecordModifierChecks[modifier] := ctrl
        RecordControls.Push(ctrl)
    }
    for index, ctrl in [RecAutoChainCtrl,RecAutoCaravanCtrl,RecAutoDropCtrl,RecAutoSkipCtrl,RecAbilitySpamCtrl]
        ctrl.Move(373, 262 + (index - 1) * 29, 303, 26)
    RecordControls.Push(AppearanceAdd(gui, "Progress", "x24 y418 w652 h1 Hidden Background333333", 0))
    RecordControls.Push(AppearanceAdd(gui, "Text", "x24 y470 w652 h24 Hidden BackgroundTrans", "A Timescale ticket can help when recording complex strategies."))
    RecordTutorial := AppearanceDarkButton(gui, "x24 y502 w175 h32 Hidden", "Recording Tutorial")
    RecordTutorial.OnEvent("Click", (*) => Run("https://www.youtube.com/watch?v=j8Y5qHBaYOs"))
    RecordControls.Push(RecordTutorial)
    RecMoveCtrl.OnEvent("Click", RecordMovementUpdate)
    RecordMovementUpdate()
}

RecordPageShow() {
    global RecordControls
    for ctrl in RecordControls
        ctrl.Visible := true
    RecordActionsUpdate()
    RecordMovementUpdate()
}

RecordSelectedModifiers() {
    global RecordModifierChecks
    selected := []
    for name, ctrl in RecordModifierChecks {
        if ctrl.Value
            selected.Push(name)
    }
    return selected
}

RecordMovementUpdate(*) {
    RecMoveDirCtrl.Enabled := !!RecMoveCtrl.Value
    RecMoveDurCtrl.Enabled := !!RecMoveCtrl.Value
}

RecordActionsUpdate() {
    Tab2_Btn1.Enabled := !Recording
    Tab2_Btn2.Enabled := !!Recording
}
