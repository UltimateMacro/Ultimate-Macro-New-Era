#Requires AutoHotkey v2.0 64-bit
#Warn All, Off
#NoTrayIcon
#SingleInstance Off
#Include engine\lib\Gdip_All.ahk
#Include engine\lib\OCR.ahk
#Include engine\lib\UM14WindowOCR.ahk

Need(ok, message) {
    if !ok
        throw Error(message)
}

CheckText(result) => RegExMatch(result.Text,"i)\bMap\s+changed\s+to\s+Dead\s+Ahead\b") && !InStr(result.Text,"HUD")

bitmap := 0, graphic := 0, handle := 0, software := "", gdip := 0, status := 0
try {
    gdip := Gdip_Startup(), w := 460, h := 104
    bitmap := Gdip_CreateBitmap(w,h)
    graphic := Gdip_GraphicsFromImage(bitmap)
    Gdip_GraphicsClear(graphic,0xFF91B45C)
    Gdip_TextToGraphics(graphic,"unrelated HUD text","x24 y2 cFFFFFFFF s18","Segoe UI",w,h)
    Gdip_TextToGraphics(graphic,"Map changed to Dead Ahead","x24 y37 cFF00EC00 s23 Bold","Segoe UI",w,h)
    Gdip_DeleteGraphics(graphic), graphic := 0

    handle := Gdip_CreateHBITMAPFromBitmap(bitmap)
    software := UM14_WindowOCR.HBitmapToSoftwareBitmap(handle)
    Need(UM14_WindowOCR.MaskToast(software,w,h), "Mask the selected-window SoftwareBitmap path")
    Need(CheckText(UM14_WindowOCR(software,{lang:"en-US",scale:1})), "Read only the success toast from the SoftwareBitmap")
    DeleteObject(handle), handle := 0

    Need(UM14_MaskGreenToastGdi(bitmap,w,h), "Mask the clear desktop GDI path")
    handle := Gdip_CreateHBITMAPFromBitmap(bitmap)
    Need(CheckText(OCR.FromBitmap(handle,{lang:"en-US",scale:1})), "Read only the success toast from GDI")
    FileAppend("PASS: Windows OCR isolates the green map toast in both bitmap paths`n","*")
} catch as e {
    FileAppend("FAIL: " e.Message " (line " e.Line ")`n","**")
    status := 1
} finally {
    if IsObject(software)
        try UM14_WindowOCR.CloseIClosable(software)
    if handle
        DeleteObject(handle)
    if graphic
        Gdip_DeleteGraphics(graphic)
    if bitmap
        Gdip_DisposeImage(bitmap)
    if gdip
        Gdip_Shutdown(gdip)
}
ExitApp(status)
