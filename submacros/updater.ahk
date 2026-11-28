#Requires AutoHotkey v2.0
#SingleInstance Force

if (A_LineFile = A_ScriptFullPath) {
    ExitApp()
}

CheckForUpdate(currentVer) {
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", "https://api.github.com/repos/DarksenDev/tds-macro/releases/latest", false)
        whr.Send()
        
        if (whr.Status = 200) {
            json := whr.ResponseText
            
            RegExMatch(json, '"tag_name":"([^"]+)"', &tag)
            latestVer := tag[1]
            
            RegExMatch(json, '"browser_download_url":"([^"]+)"', &download)
            downloadURL := download[1]
            
            RegExMatch(json, '"body":"([^"]+)"', &body)
            releaseBody := body[1]
            
            releaseBody := StrReplace(releaseBody, "\r\n", "`n")
            releaseBody := StrReplace(releaseBody, "\n", "`n")
            releaseBody := StrReplace(releaseBody, "\r", "")
            releaseBody := StrReplace(releaseBody, '\"', '"')
            releaseBody := StrReplace(releaseBody, "\\", "\")
            releaseBody := RegExReplace(releaseBody, "\\/", "/")
            
            if (latestVer != currentVer && downloadURL != "") {
                updateMsg := "New version " latestVer " is available!`n"
                updateMsg .= "Current version: " currentVer "`n`n"
                
                if (releaseBody != "") {
                    updateMsg .= "Changelog:`n--------------------------------`n"
                    if (StrLen(releaseBody) > 500) {
                        releaseBody := SubStr(releaseBody, 1, 500) . "...`n(Full changelog on GitHub)"
                    }
                    updateMsg .= releaseBody . "`n--------------------------------`n`n"
                }
                updateMsg .= "Do you want to update now?"
                
                if (MsgBox(updateMsg, "Update Available", 4 " T10") = "Yes") {
                    updateBat := A_ScriptDir "\submacros\update.bat"
                    tempBat := A_Temp "\TDSMacro_update.bat"
                    
                    if !FileExist(updateBat) {
                        MsgBox("update.bat not found!`n" updateBat, "Error", 16)
                        return 0
                    }
                    
                    FileCopy(updateBat, tempBat, 1)
                    
                    Run('"' tempBat '" "' downloadURL '" "' A_ScriptDir '"')
                    ExitApp()
                }
            }
        }
    } catch {
    }
    return 0
}
