/***********************************************************
* @description: Functions for automating the Roblox window
* @author SP
***********************************************************/

; Updates global variables windowX, windowY, windowWidth, windowHeight
; Optionally takes a known window handle to skip GetRobloxHWND call
; Returns: 1 = successful; 0 = TargetError
#Include "%A_LineFile%\..\UM14Geometry.ahk"

GetRobloxClientPos(hwnd?)
{
    global windowX, windowY, windowWidth, windowHeight
    if !IsSet(hwnd)
        hwnd := GetRobloxHWND()

    try
        WinGetClientPos &windowX, &windowY, &windowWidth, &windowHeight, "ahk_id " hwnd
    catch TargetError
        return windowX := windowY := windowWidth := windowHeight := 0
    else
        return 1
}

getRobloxPos(&x := "", &y := "", &width := "", &height := "", hwnd := "") {
    x := y := width := height := 0
    if (!hwnd)
        hwnd := GetRobloxHWND()
    if (!hwnd)
        return 0
    UM14_PhysicalDpi()
    buf := Buffer(16, 0)
    if (!DllCall("GetClientRect", "Ptr", hwnd, "Ptr", buf))
        return 0
    width := NumGet(buf, 8, "Int"), height := NumGet(buf, 12, "Int")
    return width > 0 && height > 0
}

; Returns: hWnd = successful; 0 = window not found
GetRobloxHWND()
{
	if (hwnd := WinExist("Roblox ahk_exe RobloxPlayerBeta.exe"))
		return hwnd
	else if (WinExist("Roblox ahk_exe ApplicationFrameHost.exe"))
    {
        try
            hwnd := ControlGetHwnd("ApplicationFrameInputSinkWindow1")
        catch TargetError
		    hwnd := 0
        return hwnd
    }
	else
		return 0
}

; Returns: 1 = successful; 0 = TargetError
ActivateRoblox()
{
    hwnd := GetRobloxHWND()
    if (!hwnd)
        return 0
    root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    try
        WinActivate "ahk_id " (root ? root : hwnd)
    catch
        return 0
    else
        return 1
}
