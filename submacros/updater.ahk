#Requires AutoHotkey v2.0
#SingleInstance Force

if (A_LineFile = A_ScriptFullPath)
    ExitApp()

CheckForUpdate(currentVer) {
    static ReleaseApi := "https://api.github.com/repos/UltimateMacro/Ultimate-Macro-New-Era/releases/latest"
    static PreferredAsset := "TDS_Macro.zip"

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", ReleaseApi, false)
        whr.SetRequestHeader("Accept", "application/vnd.github+json")
        whr.SetRequestHeader("X-GitHub-Api-Version", "2022-11-28")
        whr.SetRequestHeader("User-Agent", "Ultimate-Macro-New-Era/" currentVer)
        whr.SetTimeouts(10000, 10000, 20000, 20000)
        whr.Send()

        if (whr.Status != 200)
            return 0

        release := JSON.parse(whr.ResponseText)
        if !release.Has("tag_name")
            return 0

        latestTag := release["tag_name"]
        if !RegExMatch(latestTag, "i)^v?\d+(?:\.\d+){1,3}(?:[-+][0-9A-Za-z.-]+)?$")
            return 0

        latestVer := NormalizeMacroVersion(latestTag)
        installedVer := NormalizeMacroVersion(currentVer)
        if (CompareMacroVersions(latestVer, installedVer) <= 0)
            return 0

        downloadURL := ""
        digest := ""
        if release.Has("assets") {
            for asset in release["assets"] {
                if !asset.Has("name") || asset["name"] != PreferredAsset
                    continue
                if !asset.Has("browser_download_url") || !asset.Has("digest")
                    continue

                candidateURL := asset["browser_download_url"]
                candidateDigest := asset["digest"]
                if !RegExMatch(candidateURL,
                    "i)^https://github\.com/UltimateMacro/Ultimate-Macro-New-Era/releases/download/")
                    continue
                if !RegExMatch(candidateDigest, "i)^sha256:[0-9a-f]{64}$")
                    continue

                downloadURL := candidateURL
                digest := candidateDigest
                break
            }
        }

        ; A release without the expected named asset and a valid GitHub digest
        ; is not eligible for automatic installation.
        if (downloadURL = "" || digest = "")
            return 0

        releaseBody := release.Has("body") && release["body"] ? release["body"] : ""
        updateMsg := "New version " latestTag " is available!`n"
        updateMsg .= "Current version: " currentVer "`n`n"

        if (releaseBody != "") {
            if (StrLen(releaseBody) > 800)
                releaseBody := SubStr(releaseBody, 1, 800) "...`n(Full changelog on GitHub)"
            updateMsg .= "Changelog:`n--------------------------------`n" releaseBody
            updateMsg .= "`n--------------------------------`n`n"
        }

        updateMsg .= "The update is downloaded to a staging directory, checksum-verified, and validated before replacement. Existing strategies are preserved and a rollback backup is retained.`n`n"
        updateMsg .= "Do you want to update now?"

        if (MsgBox(updateMsg, "Update Available", "YesNo Iconi") != "Yes")
            return 0

        safeUpdater := A_ScriptDir "\submacros\safe_update.ps1"
        if !FileExist(safeUpdater) {
            MsgBox("safe_update.ps1 was not found. The update was cancelled without changing the installation.`n`n" safeUpdater,
                "Update Error", "Iconx")
            return 0
        }

        currentPid := DllCall("Kernel32.dll\GetCurrentProcessId", "UInt")
        tempUpdater := A_Temp "\UltimateMacro_safe_update_" currentPid "_" A_TickCount ".ps1"
        FileCopy(safeUpdater, tempUpdater, 1)

        command := "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File " QuoteArg(tempUpdater)
        command .= " -DownloadUrl " QuoteArg(downloadURL)
        command .= " -MacroDir " QuoteArg(A_ScriptDir)
        command .= " -ExpectedSha256 " QuoteArg(digest)
        command .= " -ExpectedVersion " QuoteArg(latestTag)
        command .= " -WaitPid " currentPid
        command .= " -SelfDelete"

        Run(command, , "Hide")
        ExitApp()
    } catch Error {
        ; Update checks must never prevent normal macro startup.
        return 0
    }

    return 0
}

NormalizeMacroVersion(version) {
    version := Trim(version)
    return RegExReplace(version, "i)^v", "")
}

CompareMacroVersions(leftVersion, rightVersion) {
    leftCore := RegExReplace(NormalizeMacroVersion(leftVersion), "[^0-9.].*$", "")
    rightCore := RegExReplace(NormalizeMacroVersion(rightVersion), "[^0-9.].*$", "")

    left := StrSplit(leftCore, ".")
    right := StrSplit(rightCore, ".")
    count := Max(left.Length, right.Length)

    loop count {
        l := (A_Index <= left.Length && left[A_Index] != "") ? Integer(left[A_Index]) : 0
        r := (A_Index <= right.Length && right[A_Index] != "") ? Integer(right[A_Index]) : 0

        if (l > r)
            return 1
        if (l < r)
            return -1
    }

    return 0
}

QuoteArg(value) {
    value := StrReplace(value, '"', '\"')
    return '"' value '"'
}
