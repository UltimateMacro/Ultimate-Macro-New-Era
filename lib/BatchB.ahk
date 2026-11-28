IsValidLoadoutName(name) => Trim(name) != "" && StrLen(name) <= 80 && !RegExMatch(name, "[\r\n\x00-\x1F]")

WaitForLoadoutTemplate(template, x, y, w, h, timeoutMs := 5000, minScore := 0.62) {
    start := A_TickCount
    Loop {
        if !GetRobloxHWND()
            return ""
        result := AdvancedImageSearch(template, x, y, w, h, 0.5, 1.8, 0.025)
        if (result.status = "success" && result.score >= minScore)
            return result
        if (A_TickCount - start >= timeoutMs)
            return ""
        Sleep(250)
    }
}

LoadoutTextKey(text) => StrLower(RegExReplace(Trim(text), "\s+", " "))

FindRobloxTab(name, hwnd) {
    WinGetClientPos(&screenX, &screenY, &clientW, &clientH, "ahk_id " hwnd)
    x := screenX + Round(clientW * 0.34)
    y := screenY + Round(clientH * 0.07)
    w := Round(clientW * 0.34)
    h := Round(clientH * 0.12)
    try result := OCR.FromRect(x, y, w, h, {lang: "en-US", scale: 2, grayscale: true})
    catch
        return ""
    target := LoadoutTextKey(name)
    for line in result.Lines {
        if (LoadoutTextKey(line.Text) = target)
            return {x: Round(line.x - screenX + line.w / 2), y: Round(line.y - screenY + line.h / 2)}
    }
    return ""
}

WaitForRobloxTab(name, hwnd, timeoutMs := 5000) {
    start := A_TickCount
    Loop {
        if !GetRobloxHWND()
            return ""
        tab := FindRobloxTab(name, hwnd)
        if tab
            return tab
        if (A_TickCount - start >= timeoutMs)
            return ""
        Sleep(350)
    }
}

FindLoadoutRow(name, hwnd, searchBottom, &row) {
    WinGetClientPos(&screenX, &screenY, &clientW, &clientH, "ahk_id " hwnd)
    ocrX := screenX + Round(clientW * 0.30)
    ocrY := screenY + Round(clientH * 0.25)
    ocrW := Round(clientW * 0.46)
    ocrH := Round(clientH * 0.62)
    try result := OCR.FromRect(ocrX, ocrY, ocrW, ocrH, {lang: "en-US", scale: 2, grayscale: true})
    catch {
        return false
    }
    target := LoadoutTextKey(name), matches := []
    for line in result.Lines {
        if (line.y < screenY + searchBottom || LoadoutTextKey(line.Text) != target)
            continue
        matches.Push(line)
    }
    if (matches.Length != 1)
        return false
    row := matches[1]
    return true
}

ApplySavedLoadout(name) {
    if !IsValidLoadoutName(name) {
        LogToConsole("Auto Equip Loadout needs an exact, non-empty preset name.", true)
        return false
    }
    hwnd := GetRobloxHWND()
    if !hwnd {
        LogToConsole("Auto Equip Loadout could not find the Roblox window.", true)
        return false
    }
    ActivateRoblox()
    closeChat()
    Sleep(300)
    getRobloxPos(,, &w, &h)
    loadoutsX := Round(w * 0.30), loadoutsY := Round(h * 0.10)
    loadoutsW := Round(w * 0.48), loadoutsH := Round(h * 0.28)
    dialogX := Round(w * 0.27), dialogY := Round(h * 0.24)
    dialogW := Round(w * 0.48), dialogH := Round(h * 0.22)
    dialog := AdvancedImageSearch("Resources\Loadouts\loadouts2.png", dialogX, dialogY, dialogW, dialogH, 0.5, 1.8, 0.025)
    if (dialog.status != "success" || dialog.score < 0.62) {
        loadoutsButton := AdvancedImageSearch("Resources\Loadouts\loadouts.png", loadoutsX, loadoutsY, loadoutsW, loadoutsH, 0.5, 1.8, 0.025)
        if (loadoutsButton.status != "success" || loadoutsButton.score < 0.62) {
            itemsMenu := WaitForLoadoutTemplate("Resources\items.png", 0, 0, Round(w * 0.3), h, 5000, 0.56)
            if !itemsMenu {
                LogToConsole("Auto Equip Loadout could not find Resources\items.png.", true)
                return false
            }
            MouseMove(itemsMenu.x, itemsMenu.y + ScaleY(7), A_DefaultMouseSpeed)
            Sleep(80)
            MouseClick()
            closeMenu := WaitForLoadoutTemplate("Resources\close_items.png", Round(w * 0.20), 0
                , Round(w * 0.80), Round(h * 0.40), 5000, 0.65)
            if !closeMenu {
                LogToConsole("The Items menu did not open after clicking Resources\items.png.", true)
                return false
            }
            towersTab := WaitForRobloxTab("Towers", hwnd, 3000)
            if !towersTab {
                LogToConsole("The inventory is open, but Auto Equip could not confirm the Towers tab.", true)
                return false
            }
            Click(towersTab.x, towersTab.y)
            loadoutsButton := WaitForLoadoutTemplate("Resources\Loadouts\loadouts.png", loadoutsX, loadoutsY, loadoutsW, loadoutsH, 6000, 0.62)
            if !loadoutsButton {
                LogToConsole("The Towers page opened, but its Loadouts button was not found.", true)
                return false
            }
        }

        Click(loadoutsButton.x + ScaleX(85), loadoutsButton.y + ScaleY(12))
        dialog := WaitForLoadoutTemplate("Resources\Loadouts\loadouts2.png", dialogX, dialogY, dialogW, dialogH, 6000, 0.62)
        if !dialog {
            LogToConsole("The Loadouts window did not open after clicking its button.", true)
            return false
        }
    }

    search := WaitForLoadoutTemplate("Resources\Loadouts\searchloadouts.png", 0, 0, w, h, 5000, 0.60)
    if !search {
        LogToConsole("Auto Equip Loadout could not find the search field.", true)
        return false
    }
    Click(search.x + ScaleX(112), search.y + ScaleY(10))
    Sleep(100)
    SendEvent("^a")
    SendText(name)

    WinGetClientPos(&screenX, &screenY, &clientW, &clientH, "ahk_id " hwnd)
    searchBottom := search.y + ScaleY(24)
    row := "", foundRow := false, searchStart := A_TickCount
    while (A_TickCount - searchStart < 7000) {
        if FindLoadoutRow(name, hwnd, searchBottom, &row) {
            foundRow := true
            break
        }
        Sleep(500)
    }
    if !foundRow {
        LogToConsole("Auto Equip Loadout could not find one exact match for '" name "'. The strategy was stopped.", true)
        return false
    }

    rowY := Round(row.y - screenY)
    actionX := Round(clientW * 0.51)
    actionW := Round(clientW * 0.26)
    actionY := Max(0, rowY - ScaleY(55))
    actionH := Round(ScaleY(125))
    equipped := AdvancedImageSearch("Resources\Loadouts\equipped.png", actionX, actionY, actionW, actionH, 0.5, 1.8, 0.025)
    if (equipped.status = "success" && equipped.score >= 0.62) {
        LogToConsole("Saved loadout already equipped: " name, true, false)
    } else {
        apply := AdvancedImageSearch("Resources\Loadouts\apply.png", actionX, actionY, actionW, actionH, 0.5, 1.8, 0.025)
        if (apply.status != "success" || apply.score < 0.62) {
            LogToConsole("Found '" name "', but could not find its Apply button.", true)
            return false
        }
        Click(apply.x + ScaleX(56), apply.y + ScaleY(15))
        verifyStart := A_TickCount, retried := false
        Loop {
            equipped := AdvancedImageSearch("Resources\Loadouts\equipped.png", actionX, actionY, actionW, actionH, 0.5, 1.8, 0.025)
            if (equipped.status = "success" && equipped.score >= 0.62)
                break
            if (!retried && A_TickCount - verifyStart >= 1800) {
                apply := AdvancedImageSearch("Resources\Loadouts\apply.png", actionX, actionY, actionW, actionH, 0.5, 1.8, 0.025)
                if (apply.status = "success" && apply.score >= 0.62) {
                    Click(apply.x + ScaleX(56), apply.y + ScaleY(15))
                    retried := true
                }
            }
            if (A_TickCount - verifyStart >= (retried ? 4500 : 1800))
                break
            Sleep(250)
        }
        if (equipped.status != "success" || equipped.score < 0.62) {
            LogToConsole("Loadout '" name "' was not confirmed as Equipped after one retry. The strategy was stopped.", true)
            return false
        }
        LogToConsole("Equipped saved loadout: " name, true, false)
    }

    exitButton := WaitForLoadoutTemplate("Resources\Loadouts\exitloadouts.png", Round(w * 0.54), Round(h * 0.24), Round(w * 0.22), Round(h * 0.20), 4000, 0.62)
    if !exitButton {
        LogToConsole("The loadout was equipped, but the Loadouts close button was not found.", true)
        return false
    }
    Click(exitButton.x + ScaleX(13), exitButton.y + ScaleY(11))
    startClose := A_TickCount
    Loop {
        dialog := AdvancedImageSearch("Resources\Loadouts\loadouts2.png", dialogX, dialogY, dialogW, dialogH, 0.5, 1.8, 0.025)
        if (dialog.status != "success" || dialog.score < 0.62)
            break
        if (A_TickCount - startClose >= 4000) {
            LogToConsole("The Loadouts window did not close after applying the preset.", true)
            return false
        }
        Sleep(250)
    }

    closeMenu := WaitForLoadoutTemplate("Resources\close_items.png", Round(w * 0.52), Round(h * 0.02), Round(w * 0.22), Round(h * 0.18), 4000, 0.70)
    if !closeMenu {
        LogToConsole("The inventory close button was not found after leaving Loadouts.", true)
        return false
    }
    Click(closeMenu.x + ScaleX(13), closeMenu.y + ScaleY(11))
    startClose := A_TickCount
    Loop {
        closeMenu := AdvancedImageSearch("Resources\close_items.png", Round(w * 0.52), Round(h * 0.02), Round(w * 0.22), Round(h * 0.18), 0.65, 1.6, 0.025)
        if (closeMenu.status != "success" || closeMenu.score < 0.70)
            break
        if (A_TickCount - startClose >= 4000) {
            LogToConsole("The inventory did not close after applying the saved loadout.", true)
            return false
        }
        Sleep(250)
    }
    return true
}

PersistPlacementCorrection(originalX, originalY, slotNumber, towerID, placedX, placedY) {
    global StateFile, StrategyWidth, StrategyHeight
    strategyPath := IniRead(StateFile, "State", "Strategy", "")
    hwnd := GetRobloxHWND()
    if (!RegExMatch(strategyPath, "i)\.strat$") || !FileExist(strategyPath) || !hwnd) {
        LogToConsole("Kept the successful retry for this run, but couldn't find a writable strategy file to update.", true)
        return false
    }

    try WinGetClientPos(&clientX, &clientY, &clientW, &clientH, "ahk_id " hwnd)
    catch {
        LogToConsole("Kept the successful retry for this run, but couldn't read Roblox's size to update the strategy.", true)
        return false
    }
    if (clientW <= 0 || clientH <= 0) {
        LogToConsole("Kept the successful retry for this run, but Roblox's size wasn't ready to update the strategy.", true)
        return false
    }

    baseX := StrategyWidth ? Round(placedX * StrategyWidth / clientW) : placedX
    baseY := StrategyHeight ? Round(placedY * (StrategyHeight = 1090 ? 1009 : StrategyHeight) / clientH) : placedY
    if (StrategyHeight = 1090) {
        try {
            WinGetPos(&windowX, &windowY, , , "ahk_id " hwnd)
            if StrategyWidth = 1920
                baseX += clientX - windowX
            baseY += clientY - windowY
        }
    }

    try {
        text := FileRead(strategyPath, "UTF-8")
        inSteps := false
        matchCount := 0
        lines := StrSplit(text, Chr(10))
        for index, line in lines {
            cleanLine := RTrim(line, Chr(13))
            if RegExMatch(Trim(cleanLine), "i)^\[Steps\]$") {
                inSteps := true
                continue
            }
            if RegExMatch(Trim(cleanLine), "i)^\[") {
                inSteps := false
                continue
            }
            if (inSteps && RegExMatch(cleanLine,
                "i)^([ \t]*SpawnTower\([ \t]*)(\d+)([ \t]*,[ \t]*)(\d+)([ \t]*,[ \t]*)(\d+)([ \t]*,[ \t]*)([^,)]+?)([ \t]*\).*)$", &step)) {
                sameTower := StrLower(Trim(StrReplace(step[8], Chr(34)))) = StrLower(towerID)
                if (sameTower && Integer(step[2]) = Integer(originalX)
                    && Integer(step[4]) = Integer(originalY) && Integer(step[6]) = Integer(slotNumber)) {
                    replacement := step[1] baseX step[3] baseY step[5] step[6] step[7] step[8] step[9]
                    lines[index] := replacement SubStr(line, StrLen(cleanLine) + 1)
                    matchCount++
                }
            }
        }
        if (matchCount != 1) {
            LogToConsole("Kept the successful retry for this run, but couldn't match one unique tower step in the strategy.", true)
            return false
        }

        text := Join(lines, Chr(10))
        backupPath := strategyPath "." A_NowUTC "-" A_TickCount ".before-placement-fix.bak"
        tempPath := strategyPath ".placement-fix.tmp"
        FileCopy(strategyPath, backupPath)
        if FileExist(tempPath)
            FileDelete(tempPath)
        signatureFile := FileOpen(strategyPath, "r")
        signature := Buffer(3, 0)
        signatureBytes := signatureFile.RawRead(signature, 3)
        signatureFile.Close()
        if signatureBytes >= 2 && (NumGet(signature, 0, "UShort") = 0xFEFF || NumGet(signature, 0, "UShort") = 0xFFFE)
            return false
        hasBom := signatureBytes = 3 && NumGet(signature, 0, "UChar") = 0xEF
            && NumGet(signature, 1, "UChar") = 0xBB && NumGet(signature, 2, "UChar") = 0xBF
        FileAppend(text, tempPath, hasBom ? "UTF-8" : "UTF-8-RAW")
        FileMove(tempPath, strategyPath, 1)
        return true
    } catch Error as err {
        try if FileExist(strategyPath ".placement-fix.tmp")
            FileDelete(strategyPath ".placement-fix.tmp")
        LogToConsole("Kept the successful retry for this run, but couldn't update the strategy file: " err.Message, true)
        return false
    }
}

BatchPrepareJoin() {
    global SettingsFile, StateFile, requiredTowers, RotateStrategies
    strategy := IniRead(StateFile, "State", "Strategy", "")
    if IniRead(SettingsFile, "TowerXP", "Enabled", 0) = 1 {
        definition := BatchXPActiveTower(SettingsFile)
        towers := definition ? TowerXPBuildLoadout(requiredTowers, definition.name) : ""
        if !towers || RotateStrategies || BatchXPReached(SettingsFile)
            return false
        IniWrite(0, StateFile, "State", "Equipped")
        EquipTowers(towers, true)
        return IniRead(StateFile, "State", "Equipped", 0) = 1
    }
    name := IniRead(strategy, "Settings", "loadout", IniRead(SettingsFile, "Loadouts", "Selected", ""))
    return name = "" || ApplySavedLoadout(name)
}

BatchBeginMatch() {
    global SettingsFile, StateFile
    definition := BatchXPActiveTower(SettingsFile)
    if IniRead(StateFile, "TowerXP", "Active", "") != "" && IniRead(StateFile, "State", "TimeWhenStartedPlaying", "") != ""
        return
    IniWrite("", StateFile, "TowerXP", "Active")
    if definition && IniRead(SettingsFile, "TowerXP", "Enabled", 0) = 1 {
        id := ""
        Loop 8
            id .= Format("{:04x}", Random(0, 65535))
        IniWrite(id, StateFile, "TowerXP", "MatchId")
        IniWrite(definition.name, StateFile, "TowerXP", "Active")
    }
}

BatchUsesLobbyEquip() {
    global StateFile, SettingsFile
    strategy := IniRead(StateFile, "State", "Strategy", "")
    return IniRead(SettingsFile, "TowerXP", "Enabled", 0) = 1
        || IniRead(strategy, "Settings", "loadout", IniRead(SettingsFile, "Loadouts", "Selected", "")) != ""
}

