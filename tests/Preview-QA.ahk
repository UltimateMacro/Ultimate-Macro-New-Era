; Export the application's own off-screen render buffers, not the user's screen.
QaPreview(output) {
    global Strategy1Path, Strategy2Path, RotateStrategies, AutoEquip
    Sleep(100)
    previousCritical := A_IsCritical
    Critical("On")
    MW.resizeQueued := ""
    if MW.resizeTimer
        SetTimer(MW.resizeTimer, 0)
    Loop Files, A_ScriptDir "\Strategies\*.strat", "F" {
        if A_Index = 1 {
            Strategy1Path := "Strategies\" A_LoopFileName
            Strategy1Ctrl.Value := Strategy1Path
        } else {
            Strategy2Path := "Strategies\" A_LoopFileName
            Strategy2Ctrl.Value := Strategy2Path
            break
        }
    }
    RotateStrategiesCtrl.Value := 1
    EnableStratRotation()
    Gfx.S := 1
    MW.OnSize(0, 1200, 1000)
    MW.SelectPage(1, false)
    MW.Sync(true)
    MW.surface.RenderNow()
    pane := MW.PageAt(1)
    pane.surface.RenderNow()
    image := Gdip_CreateBitmap(1200, 1000)
    graphics := Gdip_GraphicsFromImage(image)
    parent := Gdip_CreateBitmapFromHBITMAP(MW.surface.hbm)
    child := Gdip_CreateBitmapFromHBITMAP(pane.surface.hbm)
    Gdip_DrawImage(graphics, parent, 0, 0, 1200, 1000, 0, 0, 1200, 1000)
    Gdip_DrawImage(graphics, child, pane.surface.offX, pane.surface.offY, pane.surface.pw, pane.surface.ph, 0, 0, pane.surface.pw, pane.surface.ph)
    ; Export native Edit values using the same field layout/font. Their HWND
    ; text is separate from the widget buffers; no desktop capture is involved.
    previous := Gfx.G, Gfx.G := graphics
    for surface in [MW.surface, pane.surface] {
        ox := surface = MW.surface ? 0 : surface.offX
        oy := surface = MW.surface ? 0 : surface.offY
        for field in surface.natives {
            if !field.Effective() || field.password || field.y < 0 || field.y + field.h > surface.lh
                continue
            Gfx.Text(field.Text, ox + field.x + 10, oy + field.y, field.w - 24, field.h, Gfx.Font(13), field.IsEnabled() ? Theme.C("text") : Theme.C("dimText"), 0, 1, false, true)
        }
    }
    Gfx.G := previous
    if Gdip_SaveBitmapToFile(image, output) != 0
        throw Error("Cannot export UI preview")
    Gdip_DeleteGraphics(graphics)
    for bitmap in [parent, child, image]
        Gdip_DisposeImage(bitmap)
    ; QaUiTest checks the normal default-on chat/default-off rotation fixtures.
    RotateStrategiesCtrl.Value := 0
    EnableStratRotation()
    Critical(previousCritical ? previousCritical : "Off")
}
