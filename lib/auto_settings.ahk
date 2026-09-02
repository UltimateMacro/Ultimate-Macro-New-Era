#Requires AutoHotkey v2.0
#SingleInstance Force
; ==============================================================================
; Background Settings Helper
; ==============================================================================

; Include the Roblox helper library
#Include Roblox.ahk
#Include Gdip_All.ahk

A_IconHidden := true

; The helper mode from the original library file runs as a background process
if (A_ScriptFullPath == A_LineFile) {
    A_IconHidden := true
    
    ; Wait for Roblox to close completely OR become idle
    WaitForRobloxToClose()
    
    RestoreOriginalSettings()
    ExitApp()
}

; --- PUBLIC FUNCTIONS ---

ApplyMacroSettings() {
    settingsPath := EnvGet("LOCALAPPDATA") "\Roblox\GlobalBasicSettings_13.xml"
    backupPath := settingsPath ".macro_bak"
    
    if !FileExist(settingsPath)
        return false
    
    ; Create a backup if one doesn't exist yet
    if !FileExist(backupPath) {
        try FileCopy(settingsPath, backupPath, 1)
    }
    
    xmlContent := FileRead(settingsPath)
    
    targets := Map(
        "CameraMode", '<token name="CameraMode">0</token>',
        "ChatVisible", '<bool name="ChatVisible">false</bool>',
        "FramerateCap", '<int name="FramerateCap">60</int>',
        "Fullscreen", '<bool name="Fullscreen">false</bool>',
        "GraphicsOptimizationMode", '<token name="GraphicsOptimizationMode">1</token>',
        "GraphicsQualityLevel", '<int name="GraphicsQualityLevel">1</int>',
        "HasEverUsedVR", '<bool name="HasEverUsedVR">false</bool>',
        "OnScreenProfilerEnabled", '<bool name="OnScreenProfilerEnabled">false</bool>',
        "PerformanceStatsVisible", '<bool name="PerformanceStatsVisible">true</bool>',
        "SavedQualityLevel", '<token name="SavedQualityLevel">1</token>',
        "PlayerListVisible", '<bool name="PlayerListVisible">false</bool>',
        "UiNavigationKeyBindEnabled", '<bool name="UiNavigationKeyBindEnabled">true</bool>',
        "VREnabled", '<bool name="VREnabled">false</bool>'
    )
    
    for key, replacement in targets {
        pattern := 'i)<(token|bool|int)\s+name="' key '">.*?</\1>'
        if RegExMatch(xmlContent, pattern)
            xmlContent := RegExReplace(xmlContent, pattern, replacement)
        else if RegExMatch(xmlContent, "i)(</roblox>)")
            xmlContent := RegExReplace(xmlContent, "i)(</roblox>)", "`t" replacement "`n$1")
    }
    
    try {
        fileObj := FileOpen(settingsPath, "w", "UTF-8")
        fileObj.Write(xmlContent)
        fileObj.Close()
        return true
    } catch {
        return false
    }
}

RestoreOriginalSettings() {
    settingsPath := EnvGet("LOCALAPPDATA") "\Roblox\GlobalBasicSettings_13.xml"
    backupPath := settingsPath ".macro_bak"
    
    if !FileExist(backupPath) {
        return false
    }
    
    ; Retry loop to bypass file locks (Roblox holds the file when it closes)
    loop 5 {
        try {
            ; Try to copy the backup over the current settings
            FileCopy(backupPath, settingsPath, 1)
            
            ; ONLY delete the backup if FileCopy succeeds
            FileDelete(backupPath)
            return true
        } catch {
            ; If it fails due to a file lock, wait 1.5s and try again
            Sleep(1500)
        }
    }
    return false
}

; --- PRIVATE HELPER FUNCTIONS ---

WaitForRobloxToClose() {
    ; Check both window existence and process memory usage
    ; Roblox stays open in background with ~5-20MB memory when "closed"
    ; Active Roblox uses ~200MB+ memory
    
    static MEMORY_IDLE_THRESHOLD := 80 * 1024 * 1024  ; 80 MB threshold
    static POLL_INTERVAL := 1000  ; Check every second
    static STABLE_CHECKS_REQUIRED := 3  ; Need 3 consecutive stable checks
    static EXTRA_WAIT_AFTER_CLOSE := 3000  ; Extra wait after Roblox truly closes
    
    stableChecks := 0
    
    Loop {
        ; First check: Does the window exist? (Using the included Roblox.ahk function)
        hwnd := GetRobloxHWND()
        windowExists := (hwnd != 0)
        
        ; Second check: Is the process running and what's its memory usage?
        processExists := false
        memoryLow := false
        
        try {
            for process in ComObjGet("winmgmts:").ExecQuery(
                "SELECT * FROM Win32_Process WHERE Name = 'RobloxPlayerBeta.exe'"
            ) {
                processExists := true
                ; Get working set size (memory usage)
                memoryBytes := process.WorkingSetSize
                if (memoryBytes < MEMORY_IDLE_THRESHOLD) {
                    memoryLow := true
                }
                break
            }
        } catch Error as err {
            ; WMI query failed, fallback to simpler detection
            processExists := ProcessExist("RobloxPlayerBeta.exe")
            if (processExists) {
                ; If we can't query memory, use window existence as proxy
                memoryLow := !windowExists
            }
        }
        
        ; Determine if Roblox is truly closed:
        ; Case 1: Process doesn't exist at all -> fully closed
        if (!processExists) {
            break
        }
        
        ; Case 2: Window doesn't exist AND memory is low -> background idle process
        ; This means the user closed the game window but the process is lingering
        if (!windowExists && memoryLow) {
            stableChecks++
            if (stableChecks >= STABLE_CHECKS_REQUIRED) {
                ; Process is idle in background - safe to restore settings
                ; DO NOT kill the process - let it be
                break
            }
        } else {
            ; Reset stable counter if conditions change (e.g., user reopens Roblox)
            stableChecks := 0
        }
        
        Sleep(POLL_INTERVAL)
    }
    
    ; Wait extra time to ensure Roblox has released file locks
    ; (Even if process is idle, it might still be writing the settings file)
    Sleep(EXTRA_WAIT_AFTER_CLOSE)
}