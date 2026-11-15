#Requires AutoHotkey v2.0.31 64-bit
#NoTrayIcon
#Include "%A_LineFile%\..\..\app\Lifecycle.ahk"
#Include "%A_LineFile%\..\..\app\PairingNet.ahk"
#Include "%A_LineFile%\..\..\app\ShotCapture.ahk"
#Include "%A_LineFile%\..\..\lib\Gdip_All.ahk"

if A_Args.Length != 3 || !RegExMatch(A_Args[2], "\A[0-9a-f-]{36}\z") || !OwnedParent.Attach(A_Args[3])
    ExitApp(2)
dir := A_Temp "\UltimateMacroShot-" A_Args[2]
if A_Args[1] != dir || !DirExist(dir) || InStr(FileGetAttrib(dir), "L")
    ExitApp(2)
token := Gdip_Startup()
OnExit((*) => Gdip_Shutdown(token))
try {
    png := ShotCapture.Capture()
    if !IsObject(png)
        ExitApp(3)
    sealed := PairingVault.Dpapi(png, "Ultimate Macro requested Roblox screenshot v1 " A_Args[2], true, 700000)
    outputFile := FileOpen(dir "\capture.dpapi", "w")
    try {
        if outputFile.RawWrite(sealed, sealed.Size) != sealed.Size
            ExitApp(4)
    } finally outputFile.Close()
    ExitApp(0)
} catch
    ExitApp(4)
