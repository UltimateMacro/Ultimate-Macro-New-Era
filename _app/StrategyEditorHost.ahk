#Requires AutoHotkey v2.0
#SingleInstance Off
SetWorkingDir(A_ScriptDir)
CoordMode("Mouse", "Client")
CoordMode("Pixel", "Client")
SendMode("Event")
#Include vendor\WebViewToo\WebViewToo.ahk
#Include lib\StrategySafety.ahk

global SLEWindowTitle := "Ultimate Macro — Strategy Editor"
global SLECopyDataTag := 0x534C4235 ; "SLB5" - shared with the Main_Lab launcher
global SLEWindow := 0
global SLEUiReady := false
global SLEDoc := 0
global SLEPendingPath := SLE_InitialStrategyArg()
global SLETowerCatalog := 0
global SLEMapCatalog := 0
global SLEMacroRootCache := ""
global SLECalibrationSessionDir := ""
global SLELastReplayPath := ""
global SLEBrandIcon := ""
global SLEDragging := false
global SLEDragOffsetX := 0
global SLEDragOffsetY := 0
global SLEDragLastX := 0
global SLEDragLastY := 0

; Match the standalone launcher contract used by Strategy Lab 0.5. A second manual
; launch never kills the active editor: it hands the requested .strat to the existing
; window and exits. Main_Lab uses the same WM_COPYDATA payload.
existing := WinExist(SLEWindowTitle)
if existing {
    if (SLEPendingPath != "" && FileExist(SLEPendingPath))
        SLE_SendOpenPath(existing, SLEPendingPath)
    try WinActivate("ahk_id " existing)
    ExitApp()
}

OnMessage(0x004A, SLE_ReceiveCopyData) ; WM_COPYDATA

dllPath := A_ScriptDir "\vendor\WebViewToo\" (A_PtrSize * 8) "bit\WebView2Loader.dll"
if !FileExist(dllPath) {
    MsgBox("Strategy Lab Editor dependencies are missing.`nRun run_editor.ps1 first.", "Strategy Lab Editor", "Iconx")
    ExitApp()
}

localAppData := EnvGet("LOCALAPPDATA")
if (localAppData = "")
    localAppData := A_AppData
dataDir := localAppData "\Ultimate_Macro\StrategyLabEditorWebView"
if !DirExist(dataDir)
    DirCreate(dataDir)

for required in [
    A_ScriptDir "\ui\index.html",
    A_ScriptDir "\ui\styles.css",
    A_ScriptDir "\ui\app.js",
    A_ScriptDir "\data\towers.ini",
    A_ScriptDir "\data\maps.ini",
    A_ScriptDir "\capture_roblox.ps1",
    A_ScriptDir "\sync_portraits.ps1",
    A_ScriptDir "\calibration\sandbox_replay.ahk"
] {
    if !FileExist(required) {
        MsgBox("Strategy Lab Editor package is incomplete.`nMissing: " required, "Strategy Lab Editor", "Iconx")
        ExitApp()
    }
}

try {
    SLEWindow := WebViewGui("+Resize -Caption MinSize1080x700", SLEWindowTitle, , {
        DllPath: dllPath,
        DataDir: dataDir,
        DefaultWidth: 1440,
        DefaultHeight: 900
    })
    SLEWindow.OnEvent("Close", (*) => ExitApp())
    SLEWindow.AddCallbackToScript("AppReady", SLE_AppReady)
    SLEWindow.AddCallbackToScript("OpenStrategy", SLE_OpenStrategy)
    SLEWindow.AddCallbackToScript("GetMapCatalog", SLE_GetMapCatalog)
    SLEWindow.AddCallbackToScript("ChooseMacroRoot", SLE_ChooseMacroRoot)
    SLEWindow.AddCallbackToScript("LoadCachedMap", SLE_LoadCachedMap)
    SLEWindow.AddCallbackToScript("ImportMap", SLE_ImportMap)
    SLEWindow.AddCallbackToScript("CaptureRoblox", SLE_CaptureRoblox)
    SLEWindow.AddCallbackToScript("GetPortrait", SLE_GetPortrait)
    SLEWindow.AddCallbackToScript("RefreshPortrait", SLE_RefreshPortrait)
    SLEWindow.AddCallbackToScript("GetPortraitStatus", SLE_GetPortraitStatus)
    SLEWindow.AddCallbackToScript("SyncLoadoutPortraits", SLE_SyncLoadoutPortraits)
    SLEWindow.AddCallbackToScript("SaveCopy", SLE_SaveCopy)
    SLEWindow.AddCallbackToScript("OverwriteStrategy", SLE_OverwriteStrategy)
    SLEWindow.AddCallbackToScript("CalibrationCapture", SLE_CalibrationCapture)
    SLEWindow.AddCallbackToScript("FocusRoblox", SLE_FocusRoblox)
    SLEWindow.AddCallbackToScript("OpenCalibrationFolder", SLE_OpenCalibrationFolder)
    SLEWindow.AddCallbackToScript("SaveCalibrationStrat", SLE_SaveCalibrationStrat)
    SLEWindow.AddCallbackToScript("ReplayCalibrationStrat", SLE_ReplayCalibrationStrat)
    SLEWindow.AddCallbackToScript("ReplayStrategySandbox", SLE_ReplayCalibrationStrat)
    SLEWindow.AddCallbackToScript("GetReplayStatus", SLE_GetReplayStatus)
    SLEWindow.AddCallbackToScript("MinimizeWindow", SLE_MinimizeWindow)
    SLEWindow.AddCallbackToScript("ToggleMaximize", SLE_ToggleMaximize)
    SLEWindow.AddCallbackToScript("BeginWindowDrag", SLE_BeginWindowDrag)
    SLEWindow.AddCallbackToScript("GetBrandIcon", SLE_GetBrandIcon)
    SLEWindow.AddCallbackToScript("CloseWindow", SLE_CloseWindow)
    SLEWindow.Navigate("ui/index.html")
    SLEWindow.Show("w1440 h900 Center")
} catch as err {
    MsgBox("Could not start Strategy Lab Editor.`n`n" err.Message "`n`nMake sure Microsoft Edge WebView2 Runtime is installed.",
        "Strategy Lab Editor", "Iconx")
    ExitApp()
}

SLE_ArgValue(name) {
    loop A_Args.Length {
        if (A_Args[A_Index] = name && A_Index < A_Args.Length)
            return A_Args[A_Index + 1]
    }
    return ""
}

SLE_InitialStrategyArg() {
    path := SLE_ArgValue("--strategy")
    if (path != "")
        return path

    ; Backward-compatible direct invocation used by the recovered alpha launcher.
    for arg in A_Args {
        if (SubStr(arg, 1, 2) != "--")
            return arg
    }
    return ""
}

SLE_SendOpenPath(hwnd, path) {
    global SLECopyDataTag
    if !hwnd || path = "" || !FileExist(path)
        return false

    charCount := StrPut(path, "UTF-16")
    if (charCount < 2 || charCount > 16384)
        return false
    payload := Buffer(charCount * 2, 0)
    StrPut(path, payload, "UTF-16")

    ptrOffset := A_PtrSize = 8 ? 16 : 8
    cdsSize := A_PtrSize = 8 ? 24 : 12
    cds := Buffer(cdsSize, 0)
    NumPut("UPtr", SLECopyDataTag, cds, 0)
    NumPut("UInt", payload.Size, cds, A_PtrSize)
    NumPut("Ptr", payload.Ptr, cds, ptrOffset)

    result := 0
    sent := 0
    try sent := DllCall("user32\SendMessageTimeoutW",
        "Ptr", hwnd, "UInt", 0x004A, "Ptr", 0, "Ptr", cds.Ptr,
        "UInt", 0x2, "UInt", 1000, "Ptr*", &result, "Ptr")
    return sent != 0 && result != 0
}

SLE_ReceiveCopyData(wParam, lParam, msg, hwnd) {
    global SLECopyDataTag, SLEUiReady, SLEPendingPath
    if !lParam
        return 0

    ptrOffset := A_PtrSize = 8 ? 16 : 8
    tag := NumGet(lParam, 0, "UPtr")
    bytes := NumGet(lParam, A_PtrSize, "UInt")
    dataPtr := NumGet(lParam, ptrOffset, "Ptr")
    if (tag != SLECopyDataTag || !dataPtr || bytes < 2 || bytes > 32768 || Mod(bytes, 2) != 0)
        return 0

    path := ""
    try path := RTrim(StrGet(dataPtr, Floor(bytes / 2), "UTF-16"), Chr(0))
    if (path = "" || !FileExist(path))
        return 0

    ; Never parse a strategy inside SendMessage. Defer all file I/O and WebView work so
    ; Main_Lab returns immediately and gameplay remains isolated from editor latency.
    if !SLEUiReady {
        SLEPendingPath := path
    } else {
        SetTimer(SLE_LoadStrategyIntoWeb.Bind(path), -10)
    }
    return 1
}

SLE_GetRobloxHwnd() {
    if (hwnd := WinExist("Roblox ahk_exe RobloxPlayerBeta.exe"))
        return hwnd
    if (hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe"))
        return hwnd
    if WinExist("Roblox ahk_exe ApplicationFrameHost.exe") {
        try return ControlGetHwnd("ApplicationFrameInputSinkWindow1")
    }
    return 0
}

SLE_FocusRoblox(WebView, *) {
    hwnd := SLE_GetRobloxHwnd()
    if !hwnd
        return false
    try {
        if WinGetMinMax("ahk_id " hwnd) = -1
            WinRestore("ahk_id " hwnd)
        WinActivate("ahk_id " hwnd)
        return true
    } catch {
        return false
    }
}

; WebView2 marshals a JavaScript boolean as a VARIANT_BOOL, so `true` can arrive
; as -1 rather than 1. Accept every shape the bridge can produce.
; A blocking MsgBox inside a WebView callback stops that callback's COM call from
; ever completing, and WebView2 serialises host-object calls, so every later
; bridge call queues behind it and the whole UI goes dead. Callbacks therefore
; never open a dialog: they push the message to the page's toast stack instead.
SLE_Notify(message, kind := "error") {
    global SLEWindow, SLEUiReady
    if (!IsObject(SLEWindow) || !SLEUiReady || Trim(String(message)) = "")
        return
    script := "window.strategyLab.notify(" SLE_JsonQuote(message) "," SLE_JsonQuote(kind) ");"
    SetTimer(() => SLEWindow.ExecuteScriptAsync(script), -1)
}

SLE_TruthyArg(value) {
    if (value = "" || IsObject(value))
        return false
    if IsNumber(value)
        return Number(value) != 0
    text := StrLower(Trim(String(value)))
    return (text = "true" || text = "yes")
}

; The window has no caption, so the web titlebar drags it. The page only reports
; that the titlebar was grabbed; AHK then follows the cursor itself. Sending one
; position per pointermove across the WebView bridge capped the drag near ten
; updates a second because every host-object call is a serialised COM round trip.
SLE_BeginWindowDrag(WebView, *) {
    global SLEWindow, SLEDragging, SLEDragOffsetX, SLEDragOffsetY, SLEDragLastX, SLEDragLastY
    if (!IsObject(SLEWindow) || SLEDragging)
        return false

    CoordMode("Mouse", "Screen")
    try {
        if (WinGetMinMax("ahk_id " SLEWindow.Hwnd) != 0)
            return false
        MouseGetPos(&mouseX, &mouseY)
        WinGetPos(&winX, &winY, , , "ahk_id " SLEWindow.Hwnd)
    } catch {
        return false
    }

    SLEDragOffsetX := winX - mouseX
    SLEDragOffsetY := winY - mouseY
    SLEDragLastX := winX
    SLEDragLastY := winY
    SLEDragging := true
    SetTimer(SLE_DragWindowStep, 8)
    return true
}

SLE_DragWindowStep() {
    global SLEWindow, SLEDragging, SLEDragOffsetX, SLEDragOffsetY, SLEDragLastX, SLEDragLastY
    CoordMode("Mouse", "Screen")

    ; The physical button state ends the drag even when the pointer is released
    ; outside the window and the page never sees a pointerup.
    if (!SLEDragging || !IsObject(SLEWindow) || !GetKeyState("LButton", "P")) {
        SLEDragging := false
        SetTimer(SLE_DragWindowStep, 0)
        return
    }

    MouseGetPos(&mouseX, &mouseY)
    targetX := mouseX + SLEDragOffsetX
    targetY := mouseY + SLEDragOffsetY
    if (targetX = SLEDragLastX && targetY = SLEDragLastY)
        return

    SLEDragLastX := targetX
    SLEDragLastY := targetY
    ; WinMove costs ~110 ms on a window this size because it repaints the whole
    ; client area; SetWindowPos with NOSIZE only relocates it and costs ~0.3 ms.
    static SWP_MOVEONLY := 0x1 | 0x4 | 0x10 ; NOSIZE | NOZORDER | NOACTIVATE
    try DllCall("user32\SetWindowPos",
        "Ptr", SLEWindow.Hwnd, "Ptr", 0,
        "Int", targetX, "Int", targetY, "Int", 0, "Int", 0,
        "UInt", SWP_MOVEONLY)
}

; Same icon.ico the main macro window uses, handed to the page as a data URL.
SLE_BrandIconPath() {
    candidates := []
    SplitPath(A_ScriptDir, , &parent)
    if (parent != "")
        candidates.Push(parent "\icon.ico")
    candidates.Push(A_ScriptDir "\icon.ico")
    root := SLE_FindMacroRoot()
    if (root != "")
        candidates.Push(root "\icon.ico")

    for path in candidates {
        if FileExist(path)
            return path
    }
    return ""
}

SLE_GetBrandIcon(WebView := 0, *) {
    global SLEBrandIcon
    if (SLEBrandIcon != "")
        return SLEBrandIcon
    path := SLE_BrandIconPath()
    if (path = "")
        return ""
    try SLEBrandIcon := SLE_ImageDataUrl(path)
    catch
        return ""
    return SLEBrandIcon
}

SLE_MinimizeWindow(WebView, *) {
    global SLEWindow
    if !IsObject(SLEWindow)
        return false
    try {
        SLEWindow.Minimize()
        return true
    } catch {
        return false
    }
}

SLE_ToggleMaximize(WebView, *) {
    global SLEWindow
    if !IsObject(SLEWindow)
        return false
    try {
        if (WinGetMinMax("ahk_id " SLEWindow.Hwnd) = 1)
            SLEWindow.Restore()
        else
            SLEWindow.Maximize()
        return true
    } catch {
        return false
    }
}

; The web titlebar owns the close button. Unsaved work is confirmed in the page;
; this only posts WM_CLOSE so the window's own Close handler performs the exit
; after the callback has returned.
SLE_CloseWindow(WebView, *) {
    global SLEWindow
    if !IsObject(SLEWindow)
        return false
    try PostMessage(0x0010, 0, 0, , "ahk_id " SLEWindow.Hwnd)
    return true
}

SLE_AppReady(WebView, *) {
    global SLEPendingPath, SLEUiReady
    SLEUiReady := true
    if (SLEPendingPath != "" && FileExist(SLEPendingPath)) {
        pending := SLEPendingPath
        SLEPendingPath := ""
        SetTimer(() => SLE_LoadStrategyIntoWeb(pending), -80)
    }
    return "ready"
}

SLE_OpenStrategy(WebView, *) {
    path := FileSelect(1, , "Open Ultimate Macro strategy", "Strategy (*.strat)")
    if (path = "")
        return ""
    try {
        SLE_LoadStrategyIntoWeb(path)
        return path
    } catch as err {
        SLE_Notify("Could not open that strategy: " err.Message)
        return ""
    }
}

SLE_LoadStrategyIntoWeb(path) {
    global SLEDoc, SLEWindow
    SLEDoc := SLEStratDocument(path)
    json := SLEDoc.ToJson()
    SLEWindow.ExecuteScriptAsync("window.strategyLab.loadStrategy(" json ");")

    if (SLEDoc.MapName != "") {
        cached := SLE_MapCameraPath(SLEDoc.MapName)
        if (cached != "") {
            payload := SLE_ImagePayloadJson(cached, "macro-camera-cache", SLEDoc.MapName)
            SetTimer(() => SLEWindow.ExecuteScriptAsync("window.strategyLab.setMapPayload(" SLE_JsonQuote(payload) ");"
            ), -120)
        }
    }
}

SLE_GetMapCatalog(WebView, *) {
    catalog := SLE_MapCatalog()
    macroRoot := SLE_FindMacroRoot()
    installedMaps := SLE_InstalledMacroMapKeys(macroRoot)
    items := []
    for entry in catalog.list {
        key := SLE_SafeKey(entry.name)
        verified := installedMaps.Has(key)
        evidence := verified ? installedMaps[key] : ""
        cached := SLE_MapCameraPath(entry.name) != ""
        items.Push("{"
            . '"name":' SLE_JsonQuote(entry.name) ','
            . '"category":' SLE_JsonQuote(entry.category) ','
            . '"difficulty":' SLE_JsonQuote(entry.difficulty) ','
            . '"supported":' (verified ? "true" : "false") ','
            . '"supportEvidence":' SLE_JsonQuote(evidence) ','
            . '"cached":' (cached ? "true" : "false")
            . "}")
    }
    return "{"
    . '"macroRoot":' SLE_JsonQuote(macroRoot) ','
    . '"maps":[' SLE_Join(items, ",") "]"
    . "}"
}

SLE_InstalledMacroMapKeys(macroRoot) {
    result := Map()
    if (macroRoot = "")
        return result

    mapsDir := macroRoot "\Resources\Maps"
    if DirExist(mapsDir) {
        try {
            loop files, mapsDir "\*.png", "F" {
                SplitPath(A_LoopFileName, , , &ext, &nameNoExt)
                name := RegExReplace(nameNoExt, "i)_Selection$", "")
                key := SLE_SafeKey(name)
                if (key != "")
                    result[key] := InStr(nameNoExt, "_Selection") ? "selection-template" : "map-template"
            }
        }
    }

    stratsDir := macroRoot "\Resources\Strats"
    if DirExist(stratsDir) {
        try {
            loop files, stratsDir "\*.strat", "F" {
                mapName := Trim(IniRead(A_LoopFileFullPath, "Settings", "map", ""))
                key := SLE_SafeKey(mapName)
                if (key != "" && !result.Has(key))
                    result[key] := "bundled-strategy"
            }
        }
    }
    return result
}

SLE_LoadCachedMap(WebView, mapName := "", *) {
    mapName := Trim(String(mapName))
    if (mapName = "")
        return ""
    cached := SLE_MapCameraPath(mapName)
    if (cached = "")
        return ""
    try return SLE_ImagePayloadJson(cached, "map-library-cache", mapName)
    catch
        return ""
}

SLE_ImportMap(WebView, mapName := "", *) {
    mapName := Trim(String(mapName))
    if (mapName = "") {
        SLE_Notify("Choose a map from the list first.", "warn")
        return ""
    }

    path := FileSelect(1, , "Import exact Roblox client screenshot for " mapName,
        "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    if (path = "")
        return ""

    try {
        SplitPath(path, , , &ext)
        ext := StrLower(ext)
        if !(ext = "png" || ext = "jpg" || ext = "jpeg" || ext = "bmp")
            throw Error("Unsupported image format.")

        key := SLE_SafeKey(mapName)
        dir := SLE_MapCameraDir()
        SLE_RemoveMapVariants(key)
        target := dir "\" key "." ext
        FileCopy(path, target, true)
        if !FileExist(target) || FileGetSize(target) < 200
            throw Error("Imported map image was not copied correctly.")
        SLE_WriteCameraMeta(mapName, "manual-import", 0, 0, ext)
        return SLE_ImagePayloadJson(target, "map-library-import", mapName)
    } catch as err {
        SLE_Notify("Map import failed: " err.Message)
        return ""
    }
}

SLE_MapCatalog() {
    global SLEMapCatalog
    if IsObject(SLEMapCatalog)
        return SLEMapCatalog

    result := { list: [], byKey: Map() }
    path := A_ScriptDir "\data\maps.ini"
    if !FileExist(path) {
        SLEMapCatalog := result
        return result
    }

    sections := IniRead(path)
    for section in StrSplit(StrReplace(sections, "`r"), "`n") {
        section := Trim(section)
        if (section = "")
            continue
        display := Trim(IniRead(path, section, "display", section))
        category := Trim(IniRead(path, section, "category", "Known"))
        difficulty := Trim(IniRead(path, section, "difficulty", ""))
        macroHintText := Trim(IniRead(path, section, "macroHint", "0"))
        entry := {
            name: display,
            category: category,
            difficulty: difficulty,
            macroHint: (macroHintText = "1")
        }
        result.list.Push(entry)
        result.byKey[SLE_SafeKey(section)] := entry
        result.byKey[SLE_SafeKey(display)] := entry
        aliases := IniRead(path, section, "aliases", display)
        for alias in StrSplit(aliases, "|") {
            key := SLE_SafeKey(alias)
            if (key != "")
                result.byKey[key] := entry
        }
    }
    SLEMapCatalog := result
    return result
}

SLE_SettingsRoot() {
    dir := A_AppData "\Ultimate_Macro\StrategyLabEditor"
    if !DirExist(dir)
        DirCreate(dir)
    return dir
}

SLE_ChooseMacroRoot(WebView, *) {
    global SLEMacroRootCache, SLEWindow
    start := SLE_FindMacroRoot()
    if (start = "")
        start := A_Desktop

    ; Do NOT Hide()/Show() the WebView host around DirSelect. WebView2 can lose
    ; its compositor surface after that lifecycle transition on some Windows
    ; builds, leaving a large blank/white editor window. Instead, keep the host
    ; alive and briefly focus the native picker once Windows creates it.
    SetTimer(SLE_FocusMacroFolderPicker.Bind(0), -100)
    chosen := DirSelect(start, 0, "Select the Ultimate Macro / TDS_Macro folder")
    if IsObject(SLEWindow)
        try WinActivate("ahk_id " SLEWindow.Hwnd)
    if (chosen = "")
        return ""
    chosen := SLE_NormalizeDir(chosen)
    if !SLE_IsMacroRoot(chosen) {
        SLE_Notify(
            "That folder is not an Ultimate Macro root. Choose the folder that contains Main.ahk (or Main_Lab.ahk) and Resources.",
            "warn")
        return ""
    }

    SLEMacroRootCache := chosen
    settings := SLE_SettingsRoot() "\settings.ini"
    try IniWrite(chosen, settings, "Paths", "MacroRoot")
    return chosen
}

SLE_FocusMacroFolderPicker(attempt := 0) {
    title := "Select the Ultimate Macro / TDS_Macro folder"
    hwnd := WinExist(title)
    if hwnd {
        try WinActivate("ahk_id " hwnd)
        return
    }
    if (attempt < 20)
        SetTimer(SLE_FocusMacroFolderPicker.Bind(attempt + 1), -100)
}

SLE_FindMacroRoot() {
    global SLEMacroRootCache
    if (SLEMacroRootCache != "" && SLE_IsMacroRoot(SLEMacroRootCache))
        return SLEMacroRootCache

    candidates := []
    settings := SLE_SettingsRoot() "\settings.ini"
    try {
        saved := Trim(IniRead(settings, "Paths", "MacroRoot", ""))
        if (saved != "")
            candidates.Push(saved)
    }
    candidates.Push(A_ScriptDir)
    SplitPath(A_ScriptDir, , &scriptParent)
    if (scriptParent != "")
        candidates.Push(scriptParent)
    try candidates.Push(A_Desktop "\TDS_Macro")
    try candidates.Push(A_Desktop "\Ultimate_Macro")
    try candidates.Push(A_Desktop "\Ultimate_Macro\TDS_Macro")

    for candidate in candidates {
        if SLE_IsMacroRoot(candidate) {
            SLEMacroRootCache := SLE_NormalizeDir(candidate)
            try IniWrite(SLEMacroRootCache, settings, "Paths", "MacroRoot")
            return SLEMacroRootCache
        }
    }

    try {
        loop files, A_Desktop "\*", "D" {
            name := StrLower(A_LoopFileName)
            if !(InStr(name, "macro") || InStr(name, "tds"))
                continue
            candidate := A_LoopFileFullPath
            if SLE_IsMacroRoot(candidate) {
                SLEMacroRootCache := SLE_NormalizeDir(candidate)
                try IniWrite(SLEMacroRootCache, settings, "Paths", "MacroRoot")
                return SLEMacroRootCache
            }
        }
    }
    return ""
}

; Canonicalize so "<root>\_app\.." never reaches settings.ini or the UI label.
SLE_NormalizeDir(path) {
    path := Trim(String(path))
    path := Trim(path, '"')
    if (path = "")
        return ""

    buf := Buffer(32768 * 2, 0)
    length := 0
    try length := DllCall("kernel32\GetFullPathNameW", "Str", path, "UInt", 32767, "Ptr", buf.Ptr, "Ptr", 0, "UInt")
    if (length > 0 && length < 32767)
        path := StrGet(buf, length, "UTF-16")

    ; Keep the trailing separator of a drive root ("C:\"); trim it everywhere else.
    return StrLen(path) > 3 ? RTrim(path, "\/") : path
}

SLE_IsMacroRoot(path) {
    if (path = "")
        return false
    path := SLE_NormalizeDir(path)
    return (FileExist(path "\Main.ahk") || FileExist(path "\Main_Lab.ahk")) && DirExist(path "\Resources")
}

SLE_MacroMainPath(root) {
    if (root = "")
        return ""
    if FileExist(root "\Main_Lab.ahk")
        return root "\Main_Lab.ahk"
    if FileExist(root "\Main.ahk")
        return root "\Main.ahk"
    return ""
}

SLE_GetMacroContract(strict := false, profile := "full") {
    root := SLE_FindMacroRoot()
    result := {
        root: root,
        mainPath: "",
        version: "",
        exact: false,
        reason: "Ultimate Macro installation was not found.",
        profile: profile,
        hotbarMode: "unknown"
    }
    if (root = "") {
        if strict
            throw Error(result.reason)
        return result
    }

    mainPath := SLE_MacroMainPath(root)
    result.mainPath := mainPath
    if (mainPath = "") {
        result.reason := "Ultimate Macro Main.ahk was not found."
        if strict
            throw Error(result.reason)
        return result
    }

    try text := FileRead(mainPath, "UTF-8")
    catch as err {
        result.reason := "Could not read the installed macro source: " err.Message
        if strict
            throw Error(result.reason)
        return result
    }

    if RegExMatch(text, 'm)^\s*ver\s*:=\s*"([^"]+)"', &vm)
        result.version := vm[1]

    ; Camera/map capture has deliberately narrower requirements than calibration
    ; replay. A hotbar implementation change cannot make AlignCamera unsafe, and
    ; tying the two contracts together caused the valid 2026-09 tester runtime
    ; to be rejected after it replaced the startup-cached Slots array with a
    ; placement-time client-geometry helper.
    checks := [
        ["CoordMode Mouse Client", 'i)CoordMode\(\s*"Mouse"\s*,\s*"Client"\s*\)'],
        ["CoordMode Pixel Client", 'i)CoordMode\(\s*"Pixel"\s*,\s*"Client"\s*\)'],
        ["SendMode Event", 'i)SendMode\(\s*"Event"\s*\)'],
        ["sX default width", 'i)sX\(\s*baseX\s*,\s*Width\s*:=\s*1920\s*\)'],
        ["sY legacy default", 'i)sY\(\s*baseY\s*,\s*Height\s*:=\s*1090\s*\)'],
        ["ScaleY client baseline", 'i)ScaleY\(\s*baseY\s*,\s*Height\s*:=\s*1009\s*\)'],
        ["AlignCamera center", 'i)MouseMove\(\s*rw\s*/\s*2\s*,\s*rh\s*/\s*2\s*,\s*0\s*\)'],
        ["AlignCamera right drag", 'i)MouseMove\(\s*0\s*,\s*rh\s*,\s*3\s*\+\s*MouseDelay\s*,\s*"R"\s*\)'],
        ["AlignCamera zoom hold", 'i)HyperSleep\(\s*750\s*\)'],
        ["SpawnTower sX", 'i)X\s*:=\s*sX\(\s*X\s*,\s*StrategyWidth\s*\)'],
        ["SpawnTower sY", 'i)Y\s*:=\s*sY\(\s*Y\s*,\s*StrategyHeight\s*\)']
    ]

    if (StrLower(profile) != "camera") {
        checks.Push(["UseNumbers setting",
            'i)UseNumbersForHotbar\s*:=\s*IniRead\(SettingsFile,\s*"Options",\s*"UseNumbers",\s*1\)'])
        checks.Push(["CancelPlacement setting",
            'i)CancelPlacementKey\s*:=\s*IniRead\(SettingsFile,\s*"Hotkeys",\s*"CancelPlacement",\s*"Q"\)'])
    }

    missing := []
    for check in checks {
        if !RegExMatch(text, check[2])
            missing.Push(check[1])
    }

    if (StrLower(profile) != "camera") {
        legacyHotbar := RegExMatch(text, 'is)global\s+Slots\s*:=\s*\[\s*ScaleX\(800\).*?ScaleX\(1120\)')
        && RegExMatch(text, 'i)ScaleY\(960\)')
        dynamicHotbar := RegExMatch(text, 'i)SelectHotbarSlotByClick\(\s*slotNumber\s*\)')
        && RegExMatch(text, 'is)static\s+baseXBySlot\s*:=\s*\[\s*800\s*,\s*880\s*,\s*960\s*,\s*1040\s*,\s*1120\s*\]')
        && RegExMatch(text, 'i)getRobloxPos\(\s*,\s*,\s*&clientWidth\s*,\s*&clientHeight\s*\)')
        && RegExMatch(text, 'i)baseXBySlot\[slot\]\s*\*\s*\(\s*clientWidth\s*/\s*1920(?:\.0)?\s*\)')
        && RegExMatch(text, 'i)960\s*\*\s*\(\s*clientHeight\s*/\s*1009(?:\.0)?\s*\)')
        && RegExMatch(text, 'i)Click\(\s*slotX\s*,\s*slotY\s*\)')

        if dynamicHotbar
            result.hotbarMode := "dynamic-client"
        else if legacyHotbar
            result.hotbarMode := "legacy-slots"
        else
            missing.Push("Hotbar selection contract")
    } else {
        result.hotbarMode := "not-required"
    }

    if (missing.Length) {
        result.reason := "Installed macro contract differs from the audited v1.3.x family: " SLE_Join(missing, ", ")
        if strict
            throw Error(result.reason)
        return result
    }

    result.exact := true
    result.reason := "verified"
    return result
}

SLE_ReadMacroRuntimeSettings() {
    settingsPath := A_AppData "\Ultimate_Macro\Options\Settings.tds"
    result := { mouseSpeed: 2, mouseDelay: 10, keyDelay: 20, cancelKey: "Q", useNumbers: true }
    if !FileExist(settingsPath)
        return result
    try result.mouseSpeed := Integer(IniRead(settingsPath, "Options", "DefaultMouseSpeed", "2"))
    try result.mouseDelay := Integer(IniRead(settingsPath, "Options", "MouseDelay", "10"))
    try result.keyDelay := Integer(IniRead(settingsPath, "Options", "KeyDelay", "20"))
    try result.cancelKey := Trim(String(IniRead(settingsPath, "Hotkeys", "CancelPlacement", "Q")))
    try result.useNumbers := (String(IniRead(settingsPath, "Options", "UseNumbers", "1")) != "0")
    if (result.cancelKey = "")
        result.cancelKey := "Q"
    result.mouseSpeed := Max(0, Min(100, result.mouseSpeed))
    result.mouseDelay := Max(-1, Min(1000, result.mouseDelay))
    result.keyDelay := Max(-1, Min(1000, result.keyDelay))
    return result
}

SLE_RemoveMapVariants(key, keepPath := "") {
    if (key = "")
        return
    for ext in ["png", "jpg", "jpeg", "bmp"] {
        path := SLE_MapCameraDir() "\" key "." ext
        if (keepPath != "" && path = keepPath)
            continue
        if FileExist(path)
            try FileDelete(path)
    }
}

SLE_CaptureRoblox(WebView, mapName := "", *) {
    global SLEWindow
    hwnd := SLE_GetRobloxHwnd()
    if !hwnd {
        SLE_Notify("Roblox was not found. Open a TDS match and align the camera first.", "warn")
        return ""
    }

    payload := ""
    failure := ""
    try {
        WinActivate("ahk_id " hwnd)
        try WinWaitActive("ahk_id " hwnd, , 1.5)
        ; Capture needs only the verified camera/coordinate profile. Hotbar input
        ; is irrelevant here and is checked separately by sandbox replay.
        contract := SLE_AlignCameraLikeDarksen(hwnd)
        Sleep(250)

        x := 0, y := 0, w := 0, h := 0
        WinGetClientPos(&x, &y, &w, &h, "ahk_id " hwnd)
        if (w < 100 || h < 100)
            throw Error("Roblox client rectangle is not usable.")

        key := SLE_SafeKey(mapName)
        if (key = "")
            key := "manual-" FormatTime(, "yyyyMMdd-HHmmss")
        dir := SLE_MapCameraDir()
        target := dir "\" key ".png"
        helper := A_ScriptDir "\capture_roblox.ps1"
        cmd := "powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"" helper "`" -X " x " -Y " y " -Width " w " -Height " h " -Target `"" target "`""
        exitCode := RunWait(cmd, A_ScriptDir, "Hide")
        if (exitCode != 0 || !FileExist(target) || FileGetSize(target) < 1000)
            throw Error("Lossless Roblox client capture failed.")

        if (mapName != "")
            SLE_WriteCameraMeta(mapName, "standalone-aligned", w, h, "png-lossless")

        payload := SLE_ImagePayloadJson(target, "roblox-client-lossless-aligned", mapName)
    } catch as err {
        failure := err.Message
    } finally {
        ; Defensive cleanup/restoration for every success/failure branch.
        try Click("Right Up")
        try SendEvent("{o up}")
        if IsObject(SLEWindow)
            try WinActivate("ahk_id " SLEWindow.Hwnd)
    }

    if (failure != "") {
        SLE_Notify("Could not capture Roblox: " failure)
        return ""
    }
    return payload
}

SLE_CalibrationRoot() {
    dir := A_AppData "\Ultimate_Macro\StrategyEditor\CalibrationRuns"
    if !DirExist(dir)
        DirCreate(dir)
    return dir
}

SLE_CalibrationSession(reset := false) {
    global SLECalibrationSessionDir
    if (reset || SLECalibrationSessionDir = "") {
        stamp := FormatTime(, "yyyyMMdd-HHmmss")
        dir := SLE_CalibrationRoot() "\" stamp
        suffix := 1
        while DirExist(dir) {
            dir := SLE_CalibrationRoot() "\" stamp "-" suffix
            suffix += 1
        }
        DirCreate(dir)
        SLECalibrationSessionDir := dir
    }
    return SLECalibrationSessionDir
}

SLE_ColorDistance(c1, c2) {
    r1 := (c1 >> 16) & 0xFF, g1 := (c1 >> 8) & 0xFF, b1 := c1 & 0xFF
    r2 := (c2 >> 16) & 0xFF, g2 := (c2 >> 8) & 0xFF, b2 := c2 & 0xFF
    return Sqrt((r1 - r2) ** 2 + (g1 - g2) ** 2 + (b1 - b2) ** 2)
}

SLE_CloseRobloxChat(hwnd) {
    try {
        WinActivate("ahk_id " hwnd)
        chatColor := PixelGetColor(140, 29, "RGB")
        if (SLE_ColorDistance(chatColor, 0xF4F5F8) < 12) {
            MouseGetPos(&mx, &my)
            MouseMove(140, 35, 2)
            Sleep(100)
            Click()
            Sleep(100)
            MouseMove(mx, my)
        }
    }
}

SLE_HyperSleep(ms) {
    static freq := (DllCall("QueryPerformanceFrequency", "Int64*", &f := 0), f)
    DllCall("QueryPerformanceCounter", "Int64*", &begin := 0)
    current := 0
    finish := begin + ms * freq / 1000
    while (current < finish) {
        if ((finish - current) > (freq * 2.0 / 1000)) {
            DllCall("Winmm.dll\timeBeginPeriod", "UInt", 1)
            DllCall("Sleep", "UInt", 1)
            DllCall("Winmm.dll\timeEndPeriod", "UInt", 1)
        }
        DllCall("QueryPerformanceCounter", "Int64*", &current)
    }
}

SLE_AlignCameraLikeDarksen(hwnd) {
    if !hwnd
        throw Error("Roblox was not found.")

    contract := SLE_GetMacroContract(true, "camera")
    runtime := SLE_ReadMacroRuntimeSettings()
    SetDefaultMouseSpeed(runtime.mouseSpeed)
    SetMouseDelay(runtime.mouseDelay)
    SetKeyDelay(runtime.keyDelay)

    WinActivate("ahk_id " hwnd)
    if !WinWaitActive("ahk_id " hwnd, , 2.0)
        throw Error("Roblox could not be focused.")

    SLE_CloseRobloxChat(hwnd)
    WinGetClientPos(, , &rw, &rh, "ahk_id " hwnd)
    if (rw < 100 || rh < 100)
        throw Error("Roblox client rectangle is not usable.")

    ; Re-audited against Ultimate Macro New Era v1.3.4 AlignCamera(move := true,
    ; skipZoom := false, log := true), with MoveEnabled intentionally omitted so
    ; calibration always uses the canonical no-movement camera pose. Always send
    ; matching Up events on every exit path; a failed capture must never leave
    ; RMB or O physically latched for the user.
    try {
        MouseMove(rw / 2, rh / 2, 0)
        Click("Right Down")
        Sleep(50)
        MouseMove(0, rh, 3 + runtime.mouseDelay, "R")
        Sleep(10)
        Click("Right Up")
        Sleep(200)
        SendEvent("{o down}")
        SLE_HyperSleep(750)
        SendEvent("{o up}")
        Sleep(200)
        Sleep(200)
        return contract
    } finally {
        try Click("Right Up")
        try SendEvent("{o up}")
    }
}

SLE_CaptureClientLossless(hwnd, target) {
    WinGetClientPos(&x, &y, &w, &h, "ahk_id " hwnd)
    if (w < 100 || h < 100)
        throw Error("Roblox client rectangle is not usable.")
    helper := A_ScriptDir "\capture_roblox.ps1"
    cmd := 'powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "' helper
        . '" -X ' x ' -Y ' y ' -Width ' w ' -Height ' h ' -Target "' target '"'
    code := RunWait(cmd, A_ScriptDir, "Hide")
    if (code != 0 || !FileExist(target) || FileGetSize(target) < 1000)
        throw Error("Lossless Roblox client capture failed.")
    return { x: x, y: y, w: w, h: h }
}

SLE_CalibrationPayloadJson(path, stage, sessionPath, mapName, info, contract) {
    SplitPath(path, &name, , &ext)
    return "{"
    . '"name":' SLE_JsonQuote(name) ','
    . '"mapName":' SLE_JsonQuote(mapName) ','
    . '"source":' SLE_JsonQuote("sandbox-calibration-" stage) ','
    . '"format":' SLE_JsonQuote(StrLower(ext)) ','
    . '"lossless":true,'
    . '"calibrationStage":' SLE_JsonQuote(stage) ','
    . '"sessionPath":' SLE_JsonQuote(sessionPath) ','
    . '"clientX":' info.x ','
    . '"clientY":' info.y ','
    . '"clientWidth":' info.w ','
    . '"clientHeight":' info.h ','
    . '"macroVersion":' SLE_JsonQuote(contract.version) ','
    . '"cameraContract":' SLE_JsonQuote(contract.reason) ','
    . '"path":' SLE_JsonQuote(path) ','
    . '"dataUrl":' SLE_JsonQuote(SLE_ImageDataUrl(path))
    . "}"
}

SLE_CalibrationCapture(WebView, stage := "baseline", mapName := "Sandbox", silent := false, *) {
    global SLEWindow
    stage := StrLower(Trim(String(stage)))
    if !(stage = "baseline" || stage = "manual")
        stage := "manual"
    mapName := Trim(String(mapName))
    if (mapName = "")
        mapName := "Sandbox"

    silent := SLE_TruthyArg(silent)

    hwnd := SLE_GetRobloxHwnd()
    if !hwnd {
        if !silent
            SLE_Notify("Roblox was not found. Enter Sandbox first, then run the calibration capture.", "warn")
        return ""
    }

    try {
        session := SLE_CalibrationSession(stage = "baseline")
        contract := SLE_AlignCameraLikeDarksen(hwnd)
        target := session "\" stage ".png"
        info := SLE_CaptureClientLossless(hwnd, target)

        meta := session "\session.ini"
        IniWrite(mapName, meta, "Calibration", "Map")
        IniWrite(stage, meta, "Calibration", "LastStage")
        IniWrite(FormatTime(, "yyyy-MM-dd HH:mm:ss"), meta, "Calibration", "CapturedAt")
        IniWrite(info.w, meta, "Calibration", "Width")
        IniWrite(info.h, meta, "Calibration", "Height")
        IniWrite("Ultimate Macro verified client-coordinate AlignCamera contract", meta, "Calibration", "Camera")
        IniWrite(contract.version, meta, "Calibration", "MacroVersion")
        IniWrite(contract.mainPath, meta, "Calibration", "MacroMain")
        IniWrite("Client", meta, "Calibration", "CoordinateSpace")

        if IsObject(SLEWindow)
            try WinActivate("ahk_id " SLEWindow.Hwnd)
        return SLE_CalibrationPayloadJson(target, stage, session, mapName, info, contract)
    } catch as err {
        if IsObject(SLEWindow)
            try WinActivate("ahk_id " SLEWindow.Hwnd)
        if !silent
            SLE_Notify("Calibration capture failed: " err.Message)
        return ""
    }
}

SLE_OpenCalibrationFolder(WebView := 0, *) {
    dir := SLE_CalibrationSession(false)
    try Run('explorer.exe "' dir '"')
    return dir
}

SLE_SaveCalibrationStrat(WebView, text := "", *) {
    text := String(text)
    if (Trim(text) = "")
        return ""
    suggestedDir := SLE_CalibrationSession(false)
    suggested := suggestedDir "\StrategyLab_Sandbox_Replay.strat"
    path := FileSelect("S16", suggested, "Save Sandbox calibration replay", "Strategy (*.strat)")
    if (path = "")
        return ""
    if !RegExMatch(path, "i)\.strat$")
        path .= ".strat"
    SLE_WriteText(path, text, "UTF-8-RAW")
    return path
}

SLE_ReplayCalibrationStrat(WebView, text := "", *) {
    global SLELastReplayPath
    text := String(text)
    if (Trim(text) = "")
        return ""
    session := SLE_CalibrationSession(false)
    path := session "\replay-current.strat"
    SLE_WriteText(path, text, "UTF-8-RAW")
    SLELastReplayPath := path
    runner := A_ScriptDir "\calibration\sandbox_replay.ahk"
    cmd := '"' A_AhkPath '" "' runner '" "' path '"'
    try {
        Run(cmd, A_ScriptDir)
        return path
    } catch as err {
        SLE_Notify("Could not start the Sandbox replay runner: " err.Message)
        return ""
    }
}

SLE_GetReplayStatus(WebView := 0, *) {
    global SLELastReplayPath
    if (SLELastReplayPath = "")
        return ""

    statusPath := SLE_SiblingPath(SLELastReplayPath, "replay-status.ini")
    if !FileExist(statusPath)
        return ""

    state := IniRead(statusPath, "Replay", "State", "")
    total := Integer(IniRead(statusPath, "Replay", "Total", "0"))
    failed := []
    steps := []
    for index in 1..total {
        stepStatus := IniRead(statusPath, "Steps", "Status" index, "pending")
        stepId := IniRead(statusPath, "Steps", "ID" index, "")
        steps.Push("{" . '"id":' SLE_JsonQuote(stepId) . ',"status":' SLE_JsonQuote(stepStatus) "}")
        if (stepStatus = "failed")
            failed.Push(SLE_JsonQuote(stepId))
    }
    return "{" . '"state":"' state '"' . "," . '"total":' total . "," . '"failed":[' SLE_Join(failed, ",") "]" .
    ',"steps":[' SLE_Join(steps, ",") "]}"
}

SLE_SiblingPath(path, fileName) {
    SplitPath(path, , &dir)
    return dir "\" fileName
}

SLE_GetPortrait(WebView, towerName := "", *) {
    towerName := Trim(String(towerName))
    if (towerName = "")
        return ""

    path := SLE_PortraitPath(towerName)
    if (path = "") {
        try SLE_SyncPortraits(towerName, false)
        path := SLE_PortraitPath(towerName)
    }
    if (path = "")
        return ""
    try return SLE_ImageDataUrl(path)
    catch
        return ""
}

SLE_RefreshPortrait(WebView, towerName := "", *) {
    towerName := Trim(String(towerName))
    if (towerName = "")
        return ""

    old := SLE_PortraitPath(towerName)
    backup := ""
    if (old != "") {
        backup := old ".strategy-lab-refresh-backup"
        try {
            if FileExist(backup)
                FileDelete(backup)
            FileMove(old, backup, true)
        }
    }

    ok := false
    try ok := SLE_SyncPortraits(towerName, true)

    fresh := SLE_PortraitPath(towerName)
    if (fresh != "") {
        if (backup != "" && FileExist(backup))
            try FileDelete(backup)
        try return SLE_ImageDataUrl(fresh)
        catch
            return ""
    }

    if (backup != "" && FileExist(backup)) {
        SplitPath(old, , , &ext)
        try FileMove(backup, old, true)
        try return SLE_ImageDataUrl(old)
    }
    return ""
}

SLE_GetPortraitStatus(WebView := 0, *) {
    global SLEDoc
    if !IsObject(SLEDoc) || SLEDoc.RequiredTowers.Length = 0
        return '{"total":0,"available":0,"missing":[]}'

    seen := Map()
    missing := []
    total := 0
    available := 0

    for tower in SLEDoc.RequiredTowers {
        name := Trim(String(tower))
        if (name = "")
            continue
        key := SLE_SafeKey(name)
        if (key = "" || seen.Has(key))
            continue
        seen[key] := true
        total += 1
        if (SLE_PortraitPath(name) != "")
            available += 1
        else
            missing.Push(name)
    }

    missingJson := []
    for name in missing
        missingJson.Push(SLE_JsonQuote(name))

    return "{"
    . '"total":' total ","
        . '"available":' available ","
        . '"missing":[' SLE_Join(missingJson, ",") "]"
        . "}"
}

SLE_SyncLoadoutPortraits(WebView, *) {
    global SLEDoc
    if !IsObject(SLEDoc) || SLEDoc.RequiredTowers.Length = 0
        return SLE_GetPortraitStatus()

    names := []
    for tower in SLEDoc.RequiredTowers {
        name := Trim(String(tower))
        if (name != "")
            names.Push(name)
    }
    joined := SLE_Join(names, "|")
    try SLE_SyncPortraits(joined, false)
    return SLE_GetPortraitStatus()
}

SLE_PortraitPath(towerName) {
    root := A_AppData "\Ultimate_Macro\StrategyEditor\TowerLibrary"
    if !DirExist(root)
        DirCreate(root)
    key := SLE_SafeKey(towerName)
    for ext in ["png", "jpg", "jpeg", "bmp", "webp"] {
        path := root "\" key "." ext
        if FileExist(path)
            return path
    }
    return ""
}

SLE_SyncPortraits(towerNames, force := false) {
    root := A_AppData "\Ultimate_Macro\StrategyEditor\TowerLibrary"
    if !DirExist(root)
        DirCreate(root)
    helper := A_ScriptDir "\sync_portraits.ps1"
    catalog := A_ScriptDir "\data\towers.ini"
    cleanNames := StrReplace(String(towerNames), '"', "")
    cleanRoot := StrReplace(root, '"', "")
    cleanCatalog := StrReplace(catalog, '"', "")
    cmd := 'powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "' helper
        . '" -CatalogPath "' cleanCatalog '" -TowerDir "' cleanRoot
        . '" -TowerNames "' cleanNames '" -Force ' (force ? "1" : "0")
    try {
        code := RunWait(cmd, A_ScriptDir, "Hide")
        return code = 0
    } catch {
        return false
    }
}

SLE_SaveCopy(WebView, text := "", *) {
    global SLEDoc
    if !IsObject(SLEDoc)
        return ""
    SplitPath(SLEDoc.Path, &name, &dir, &ext, &nameNoExt)
    suggested := dir "\" nameNoExt ".strategy-lab." (ext != "" ? ext : "strat")
    path := FileSelect("S16", suggested, "Save strategy copy", "Strategy (*.strat)")
    if (path != "" && !RegExMatch(path, "i)\.strat$"))
        path .= ".strat"
    if (path = "")
        return ""
    SLE_WriteText(path, String(text), SLEDoc.Encoding)
    return path
}

SLE_OverwriteStrategy(WebView, text := "", *) {
    global SLEDoc
    if !IsObject(SLEDoc)
        return ""
    stamp := FormatTime(, "yyyyMMdd-HHmmss") "-" Format("{:03}", A_MSec)
    SplitPath(SLEDoc.Path, &name, &dir, &ext, &nameNoExt)
    backup := dir "\" nameNoExt ".backup-" stamp (ext != "" ? "." ext : "")
    suffix := 1
    while FileExist(backup) {
        backup := dir "\" nameNoExt ".backup-" stamp "-" suffix (ext != "" ? "." ext : "")
        suffix += 1
    }
    FileCopy(SLEDoc.Path, backup, false)
    temp := SLEDoc.Path ".strategy-lab.tmp"
    if FileExist(temp)
        FileDelete(temp)
    SLE_WriteText(temp, String(text), SLEDoc.Encoding)
    FileMove(temp, SLEDoc.Path, 1)
    SLEDoc.Text := String(text)
    return backup
}

class SLEStratDocument {
    __New(path) {
        if !FileExist(path)
            throw Error("Strategy file does not exist.")
        this.Path := path
        loaded := SLE_LoadValidatedStrategy(path)
        this.Text := loaded.Text
        this.Encoding := loaded.Encoding
        this.Newline := InStr(this.Text, "`r`n") ? "`r`n" : "`n"
        this.Lines := StrSplit(StrReplace(this.Text, "`r"), "`n")
        this.Placements := []
        this.RequiredTowers := []
        this.Settings := Map()
        this.Meta := Map()
        this.MapName := ""
        this.StrategyLabMode := ""
        this.Parse()
    }

    Parse() {
        section := ""
        for lineNo, line in this.Lines {
            trimmed := Trim(line)
            if RegExMatch(trimmed, "^\[([^\]]+)\]$", &sectionMatch) {
                section := StrLower(Trim(sectionMatch[1]))
                continue
            }
            if RegExMatch(line, "^\s*([^=]+?)\s*=\s*(.*)$", &kv) {
                key := StrLower(Trim(kv[1]))
                value := Trim(kv[2])
                if (section = "settings")
                    this.Settings[key] := value
                else if (section = "do not edit")
                    this.Meta[key] := value
            }
            if (section != "steps")
                continue
            if RegExMatch(line, "i)^\s*SpawnTower\(\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*([^,]+?)\s*,\s*([^)]+?)\s*\)\s*$", &m
            ) {
                this.Placements.Push({ lineNo: lineNo, x: Integer(m[1]), y: Integer(m[2]), slot: Trim(m[3]), towerId: Trim(
                    m[4]) })
            }
        }
        towersText := this.Settings.Has("requiredtowers") ? this.Settings["requiredtowers"] : ""
        if (towersText != "") {
            for tower in StrSplit(towersText, ",") {
                tower := Trim(tower)
                if (tower != "")
                    this.RequiredTowers.Push(tower)
            }
        }
        this.MapName := this.Settings.Has("map") ? Trim(String(this.Settings["map"])) : ""
        this.StrategyLabMode := this.Settings.Has("strategylabmode") ? Trim(String(this.Settings["strategylabmode"])) :
            ""
        this.HasExplicitDimensions := this.Meta.Has("width") && this.Meta.Has("height")
        && IsNumber(this.Meta["width"]) && IsNumber(this.Meta["height"])
        ; New Era v1.3.4 LoadStrategyFile() falls back to 1920x1080 for strategies
        ; with no [DO NOT EDIT] dimensions. Keep the old explicit 1090 compatibility
        ; path in replay scaling, but do not assign that legacy value to missing metadata.
        this.StrategyWidth := (this.Meta.Has("width") && IsNumber(this.Meta["width"])) ? Max(1, Integer(this.Meta[
            "width"])) : 1920
        this.StrategyHeight := (this.Meta.Has("height") && IsNumber(this.Meta["height"])) ? Max(1, Integer(this.Meta[
            "height"])) : 1080
        this.CoordinateContract := this.HasExplicitDimensions ? "explicit-client" : "fallback-1920x1080"
    }

    TowerNameForSlot(slotText) {
        if !RegExMatch(String(slotText), "^\d+$")
            return ""
        slot := Integer(slotText)
        return (slot >= 1 && slot <= this.RequiredTowers.Length) ? this.RequiredTowers[slot] : ""
    }

    ToJson() {
        SplitPath(this.Path, &name)
        towers := []
        for tower in this.RequiredTowers
            towers.Push(SLE_JsonQuote(tower))

        geometry := SLE_GeometryConfig(this.MapName)
        placements := []
        for index, p in this.Placements {
            towerName := this.TowerNameForSlot(p.slot)
            towerInfo := SLE_TowerInfo(towerName)
            placements.Push("{"
                . '"lineNo":' p.lineNo ','
                . '"x":' p.x ','
                . '"y":' p.y ','
                . '"slot":' (IsNumber(p.slot) ? Integer(p.slot) : 0) ','
                . '"towerId":' SLE_JsonQuote(p.towerId) ','
                . '"towerName":' SLE_JsonQuote(towerName) ','
                . '"footprint":' towerInfo.radius ','
                . '"footprintKnown":' (towerInfo.known ? "true" : "false") ','
                . '"footprintStatus":' SLE_JsonQuote(towerInfo.status) ','
                . '"placementType":' SLE_JsonQuote(towerInfo.placementType)
                . "}")
        }
        return "{"
        . '"path":' SLE_JsonQuote(this.Path) ','
        . '"name":' SLE_JsonQuote(name) ','
        . '"text":' SLE_JsonQuote(this.Text) ','
        . '"newline":' SLE_JsonQuote(this.Newline) ','
        . '"encoding":' SLE_JsonQuote(this.Encoding) ','
        . '"strategyWidth":' this.StrategyWidth ','
        . '"strategyHeight":' this.StrategyHeight ','
        . '"hasExplicitDimensions":' (this.HasExplicitDimensions ? "true" : "false") ','
        . '"coordinateContract":' SLE_JsonQuote(this.CoordinateContract) ','
        . '"mapName":' SLE_JsonQuote(this.MapName) ','
        . '"strategyLabMode":' SLE_JsonQuote(this.StrategyLabMode) ','
        . '"pixelsPerUnit":' geometry.pixelsPerUnit ','
        . '"geometrySource":' SLE_JsonQuote(geometry.source) ','
        . '"geometryConfidence":' geometry.confidence ','
        . '"geometryOffsetX":' geometry.offsetX ','
        . '"geometryOffsetY":' geometry.offsetY ','
        . '"geometryProjection":{'
        . '"model":' SLE_JsonQuote(geometry.projection.model) ','
        . '"referenceWidth":' geometry.projection.referenceWidth ','
        . '"referenceHeight":' geometry.projection.referenceHeight ','
        . '"ppuX0":' geometry.projection.ppuX0 ','
        . '"ppuXX":' geometry.projection.ppuXX ','
        . '"ppuXY":' geometry.projection.ppuXY ','
        . '"ppuY0":' geometry.projection.ppuY0 ','
        . '"ppuYX":' geometry.projection.ppuYX ','
        . '"ppuYY":' geometry.projection.ppuYY ','
        . '"samples":' geometry.projection.samples ','
        . '"rmseX":' geometry.projection.rmseX ','
        . '"rmseY":' geometry.projection.rmseY ','
        . '"confidence":' geometry.projection.confidence ','
        . '"source":' SLE_JsonQuote(geometry.projection.source)
        . '},'
        . '"requiredTowers":[' SLE_Join(towers, ",") '],'
        . '"placements":[' SLE_Join(placements, ",") ']'
        . "}"
    }
}

SLE_TowerCatalog() {
    global SLETowerCatalog
    if IsObject(SLETowerCatalog)
        return SLETowerCatalog

    result := Map()
    path := A_ScriptDir "\data\towers.ini"
    if !FileExist(path) {
        SLETowerCatalog := result
        return result
    }

    sections := IniRead(path)
    for section in StrSplit(StrReplace(sections, "`r"), "`n") {
        section := Trim(section)
        if (section = "")
            continue
        radiusText := IniRead(path, section, "placementFootprint", "1.5")
        radius := IsNumber(radiusText) ? Number(radiusText) : 1.5
        status := StrLower(Trim(IniRead(path, section, "verificationStatus", "estimated")))
        known := (status = "verified-current" || status = "reviewed")
        placementType := StrLower(Trim(IniRead(path, section, "placementType", "unknown")))
        if !(placementType = "ground" || placementType = "cliff" || placementType = "both")
            placementType := "unknown"
        entry := { radius: Max(0.5, Min(4.0, radius)), known: known, status: status, placementType: placementType }
        result[SLE_SafeKey(section)] := entry
        display := IniRead(path, section, "display", section)
        result[SLE_SafeKey(display)] := entry
        aliases := IniRead(path, section, "aliases", section)
        for alias in StrSplit(aliases, "|") {
            key := SLE_SafeKey(alias)
            if (key != "")
                result[key] := entry
        }
    }
    SLETowerCatalog := result
    return result
}

SLE_TowerInfo(towerName) {
    catalog := SLE_TowerCatalog()
    key := SLE_SafeKey(towerName)
    if (key != "" && catalog.Has(key))
        return catalog[key]
    return { radius: 1.5, known: false, status: "estimated", placementType: "unknown" }
}

SLE_GeometryConfig(mapName) {
    result := {
        pixelsPerUnit: 26.0,
        confidence: 0.0,
        source: "visual-baseline",
        offsetX: 0.0,
        offsetY: 0.0,
        projection: {
            model: "global-v1",
            referenceWidth: 1920.0,
            referenceHeight: 1009.0,
            ppuX0: 26.0,
            ppuXX: 0.0,
            ppuXY: 0.0,
            ppuY0: 26.0,
            ppuYX: 0.0,
            ppuYY: 0.0,
            samples: 0,
            rmseX: 0.0,
            rmseY: 0.0,
            confidence: 0.0,
            source: "visual-baseline"
        }
    }
    key := SLE_SafeKey(mapName)
    if (key = "")
        return result
    path := A_AppData "\Ultimate_Macro\StrategyEditor\MapLibrary\calibration\" key ".ini"
    if !FileExist(path)
        return result
    try {
        ppu := IniRead(path, "Geometry", "PixelsPerUnit", result.pixelsPerUnit)
        confidence := IniRead(path, "Geometry", "Confidence", 0)
        source := IniRead(path, "Geometry", "Source", "calibration")
        offsetX := IniRead(path, "Geometry", "OffsetX", 0)
        offsetY := IniRead(path, "Geometry", "OffsetY", 0)
        if IsNumber(ppu) && Number(ppu) >= 16 && Number(ppu) <= 40
            result.pixelsPerUnit := Number(ppu)
        if IsNumber(confidence)
            result.confidence := Max(0.0, Min(1.0, Number(confidence)))
        if IsNumber(offsetX) && Abs(Number(offsetX)) <= 50
            result.offsetX := Number(offsetX)
        if IsNumber(offsetY) && Abs(Number(offsetY)) <= 50
            result.offsetY := Number(offsetY)
        result.source := String(source)

        ; Backwards compatibility: the historical single PPU remains the exact fallback
        ; when no position-aware projection section exists or its data is invalid.
        result.projection.ppuX0 := result.pixelsPerUnit
        result.projection.ppuY0 := result.pixelsPerUnit
        result.projection.confidence := result.confidence
        result.projection.source := result.source

        model := StrLower(Trim(String(IniRead(path, "Projection", "Model", ""))))
        if (model = "affine-v1") {
            rw := IniRead(path, "Projection", "ReferenceWidth", 1920)
            rh := IniRead(path, "Projection", "ReferenceHeight", 1009)
            x0 := IniRead(path, "Projection", "PpuX0", "")
            xx := IniRead(path, "Projection", "PpuXX", "")
            xy := IniRead(path, "Projection", "PpuXY", "")
            y0 := IniRead(path, "Projection", "PpuY0", "")
            yx := IniRead(path, "Projection", "PpuYX", "")
            yy := IniRead(path, "Projection", "PpuYY", "")
            samples := IniRead(path, "Projection", "Samples", 0)
            rmseX := IniRead(path, "Projection", "RmseX", 0)
            rmseY := IniRead(path, "Projection", "RmseY", 0)
            pconf := IniRead(path, "Projection", "Confidence", result.confidence)
            psource := IniRead(path, "Projection", "Source", result.source)

            valid := IsNumber(rw) && IsNumber(rh) && Number(rw) >= 100 && Number(rh) >= 100
            && IsNumber(x0) && IsNumber(xx) && IsNumber(xy)
            && IsNumber(y0) && IsNumber(yx) && IsNumber(yy)
            if valid {
                candidate := {
                    model: "affine-v1",
                    referenceWidth: Number(rw),
                    referenceHeight: Number(rh),
                    ppuX0: Number(x0),
                    ppuXX: Number(xx),
                    ppuXY: Number(xy),
                    ppuY0: Number(y0),
                    ppuYX: Number(yx),
                    ppuYY: Number(yy),
                    samples: IsNumber(samples) ? Max(0, Integer(samples)) : 0,
                    rmseX: IsNumber(rmseX) ? Max(0.0, Number(rmseX)) : 0.0,
                    rmseY: IsNumber(rmseY) ? Max(0.0, Number(rmseY)) : 0.0,
                    confidence: IsNumber(pconf) ? Max(0.0, Min(1.0, Number(pconf))) : result.confidence,
                    source: String(psource)
                }
                if SLE_ProjectionConfigValid(candidate)
                    result.projection := candidate
            }
        }
    }
    return result
}

SLE_ProjectionConfigValid(p) {
    ; Affine values are evaluated at center + four corners. Reject impossible/corrupt
    ; models rather than drawing huge rings or hiding them entirely.
    for point in [[-0.5, -0.5], [0.5, -0.5], [-0.5, 0.5], [0.5, 0.5], [0.0, 0.0]] {
        nx := point[1], ny := point[2]
        ppuX := p.ppuX0 + p.ppuXX * nx + p.ppuXY * ny
        ppuY := p.ppuY0 + p.ppuYX * nx + p.ppuYY * ny
        if (ppuX < 8.0 || ppuX > 60.0 || ppuY < 8.0 || ppuY > 60.0)
            return false
    }
    return true
}

SLE_MapRoot() {
    dir := A_AppData "\Ultimate_Macro\StrategyEditor\MapLibrary"
    if !DirExist(dir)
        DirCreate(dir)
    return dir
}

SLE_MapCameraDir() {
    dir := SLE_MapRoot() "\camera"
    if !DirExist(dir)
        DirCreate(dir)
    return dir
}

SLE_MapCameraPath(mapName) {
    key := SLE_SafeKey(mapName)
    if (key = "")
        return ""
    for ext in ["png", "jpg", "jpeg", "bmp"] {
        path := SLE_MapCameraDir() "\" key "." ext
        if FileExist(path)
            return path
    }
    return ""
}

SLE_WriteCameraMeta(mapName, stage, width, height, format) {
    key := SLE_SafeKey(mapName)
    if (key = "")
        return
    meta := SLE_MapCameraDir() "\" key ".meta.ini"
    try {
        IniWrite(stage, meta, "Capture", "Stage")
        IniWrite("0.5-alpha.5.5.1", meta, "Capture", "WriterVersion")
        IniWrite(1, meta, "Capture", "ClientAligned")
        IniWrite(format, meta, "Capture", "Format")
        IniWrite(FormatTime(, "yyyy-MM-dd HH:mm:ss"), meta, "Capture", "CapturedAt")
        IniWrite(width, meta, "Capture", "Width")
        IniWrite(height, meta, "Capture", "Height")
    }
}

SLE_Join(items, sep := ",") {
    out := ""
    for index, value in items
        out .= (index = 1 ? "" : sep) value
    return out
}

SLE_JsonQuote(value) {
    s := String(value)
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    return '"' s '"'
}

SLE_SafeKey(value) {
    key := StrLower(Trim(String(value)))
    key := RegExReplace(key, "[^a-z0-9]+", "-")
    return Trim(key, "-")
}

SLE_ImagePayloadJson(path, source := "file", mapName := "") {
    SplitPath(path, &name, , &ext)
    ext := StrLower(ext)
    lossless := ext = "png" || ext = "bmp"
    return "{" . '"name":' SLE_JsonQuote(name) ','
    . '"mapName":' SLE_JsonQuote(mapName) ','
    . '"source":' SLE_JsonQuote(source) ','
    . '"format":' SLE_JsonQuote(ext) ','
    . '"lossless":' (lossless ? "true" : "false") ','
    . '"dataUrl":' SLE_JsonQuote(SLE_ImageDataUrl(path)) . "}"
}

SLE_ImageDataUrl(path) {
    if !FileExist(path)
        return ""
    SplitPath(path, , , &ext)
    ext := StrLower(ext)
    mime := ext = "png" ? "image/png"
        : ext = "bmp" ? "image/bmp"
            : ext = "webp" ? "image/webp"
                : ext = "ico" ? "image/x-icon"
                    : "image/jpeg"
    raw := FileRead(path, "RAW")
    if (raw.Size <= 0)
        return ""
    flags := 0x40000001
    chars := 0
    if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", raw.Ptr, "UInt", raw.Size, "UInt", flags, "Ptr", 0, "UInt*", &
        chars)
        throw Error("Could not encode image.")
    buf := Buffer(chars * 2, 0)
    if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", raw.Ptr, "UInt", raw.Size, "UInt", flags, "Ptr", buf.Ptr,
        "UInt*", &chars)
        throw Error("Could not encode image.")
    return "data:" mime ";base64," StrGet(buf, chars, "UTF-16")
}

SLE_WriteText(path, text, encoding) {
    if FileExist(path)
        FileDelete(path)
    FileAppend(text, path, encoding)
}