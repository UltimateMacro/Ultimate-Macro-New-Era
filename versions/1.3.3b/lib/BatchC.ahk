BatchProcessCommands() {
    global ChannelID, UserID, BotEnabled, BotSettings
    static busy := false, cursor := Map()
    if busy || !BotEnabled || !(UserID ~= "^\d+$") || !(ChannelID ~= "^\d+$")
        return
    busy := true
    try {
        first := !cursor.Has(ChannelID)
        messages := JSON.Parse(Discord.GetMessageAPI(first ? "?limit=1" : "?limit=100&after=" cursor[ChannelID]))
        if first && !messages.Length
            cursor[ChannelID] := "0"
        loop messages.Length {
            msg := messages[messages.Length - A_Index + 1]
            cursor[ChannelID] := msg["id"]
            if first || msg["author"]["id"] != UserID || msg["author"].Get("bot", false)
                continue
            prefix := IniRead(BotSettings, "Settings", "Prefix", "!")
            if SubStr(msg["content"], 1, StrLen(prefix)) != prefix
                continue
            line := Trim(SubStr(msg["content"], StrLen(prefix) + 1))
            try reply := BatchDispatch(line, msg, prefix)
            catch {
                reply := "That command failed. Check the macro and try again."
            }
            if reply != ""
                BatchReply(line, reply)
        }
    } catch {
        return
    } finally busy := false
}

BatchReply(line, message) {
    command := StrLower(RegExReplace(line, "\s.*$"))
    titles := Map("help", "macro controls", "status", "towering defensively :)", "start", "Start macro",
        "stop", "Stop macro", "settings", "Macro settings", "timescale", "Timescale", "party", "Party setup", "vip", "VIP server", "strategy", "Strategies", "goal", "Farming goal", "loadout", "Saved loadouts",
        "towerxp", "Tower XP farming", "prefix", "Command prefix", "screenshot", "Desktop screenshot", "logs", "Macro logs")
    Discord.SendMessageAPI(BatchEmbed(titles.Get(command, "Macro controls"), message))
}

BatchEmbed(title, message, image := "") {
    embed := Map("title", title, "description", SubStr(message, 1, 3900), "color", 8836321)
    if image != ""
        embed["image"] := Map("url", "attachment://" image)
    return JSON.Stringify(Map("embeds", [embed], "allowed_mentions", Map("parse", [])))
}

BatchUpload(title, description, attachment, image := "") {
    data := Map("name", "payload_json", "content-type", "application/json", "content", BatchEmbed(title, description, image))
    Discord.CreateFormData(&body, &type, [data, attachment])
    return BatchSent(Discord.SendMessageAPI(body, type))
}

BatchCode(value) => Chr(96) StrReplace(value, Chr(96), "’") Chr(96)

BatchHelp(p, topic := "") {
    if topic = "settings"
        return "**Settings**`n" BatchCode(p "settings") " lists values. " BatchCode(p "settings auto-equip on") " changes a toggle."
            . "`n" BatchCode(p "settings mouse-speed 2") " · " BatchCode(p "settings mouse-delay 10") " · " BatchCode(p "settings key-delay 12")
            . "`n`n**Match speed and VIP**`n" BatchCode(p "timescale 1.5x") " · " BatchCode(p "vip on") " · " BatchCode(p "vip off")
            . "`n`n**Party**`n" BatchCode(p "party") " · " BatchCode(p "party on") " · " BatchCode(p "party off") " · " BatchCode(p "party role host")
            . "`n" BatchCode(p "party host Builder") " · " BatchCode(p "party members Scout, Builder") " · " BatchCode(p "party leave any")
    return "**Settings**`n" BatchCode(p "help settings") " for switches, input timing, party and VIP. " BatchCode(p "timescale 1.5x") ".`n`n**Run**`n" BatchCode(p "status") " · " BatchCode(p "start [strategy]") " · " BatchCode(p "stop now|after-match")
        . "`n`n**Strategies**`n" BatchCode(p "strategy list [page]") " · " BatchCode(p "strategy select|run <name>") " · " BatchCode(p "strategy import") " + attachment"
        . "`n`n**Farming**`n" BatchCode(p "goal status|clear") " · " BatchCode(p "goal set <coins|gems> <amount>")
        . "`n" BatchCode(p "loadout list [page]") " · " BatchCode(p "loadout select <name|off>")
        . "`n" BatchCode(p "towerxp status|enable|disable") " · " BatchCode(p "towerxp target <tower> <level>")
        . "`n" BatchCode(p "towerxp progress [level XP]")
        . "`n`n**Utilities**`n" BatchCode(p "screenshot") " · " BatchCode(p "logs export") " · " BatchCode(p "prefix set <symbol>") " · " BatchCode(p "prefix reset")
}

BatchNamePage(names, pageText, nextCommand, emptyMessage) {
    if !names.Length
        return emptyMessage
    pageSize := 8, pages := Ceil(names.Length/pageSize)
    page := pageText = "" ? 1 : (pageText ~= "^[1-9]\d{0,6}$" ? Integer(pageText) : 0)
    if page < 1 || page > pages
        return "Choose a page from 1 to " pages "."
    result := ""
    Loop Min(pageSize, names.Length - (page-1)*pageSize)
        result .= "• " BatchCode(SubStr(names[(page-1)*pageSize + A_Index], 1, 160)) "`n"
    if pages > 1
        result .= "`nPage " page "/" pages ". " (page < pages ? "Next: " BatchCode(nextCommand " " (page+1)) : "")
    return RTrim(result)
}

BatchStrategies() {
    global StratsDir, RecordingsDir
    paths := Map()
    paths.CaseSense := "Off"
    for root in [StratsDir, RecordingsDir] {
        Loop Files, root "\*.strat", "FR" {
            name := A_LoopFileName
            if paths.Has(name) && paths[name] != A_LoopFileFullPath
                paths[name] := ""
            else
                paths[name] := A_LoopFileFullPath
        }
    }
    return paths
}

BatchSelectStrategy(name) {
    global Strategy1Ctrl
    paths := BatchStrategies()
    if !RegExMatch(name, "i)\.strat$")
        name .= ".strat"
    if !paths.Has(name) || paths[name] = ""
        return false
    Strategy1Ctrl.Value := paths[name]
    SaveStrat1(Strategy1Ctrl)
    return true
}

BatchDispatch(line, msg, prefix) {
    global RunningStrategy, Recording, MacroRecording, SettingsFile, StateFile, BotSettings
    global Strategy1Ctrl, Strategy2Ctrl, RotateStrategiesCtrl, LogLines
    if !RegExMatch(line, "^(\S+)(?:\s+(\S+)(?:\s+(.+))?)?$", &m)
        return "Try " prefix "help."
    command := StrLower(m[1]), sub := StrLower(m[2]), args := m[3]
    switch command {
        case "help":
            return BatchHelp(prefix, sub)
        case "settings", "timescale", "party", "vip":
            return BatchConfigCommand(command, Trim(SubStr(line, StrLen(command) + 1)), prefix)
        case "status":
            path := RunningStrategy ? IniRead(StateFile, "State", "Strategy", "") : (Strategy1Ctrl.Value != "" ? Strategy1Ctrl.Value : Strategy2Ctrl.Value)
            SplitPath(path, &name)
            start := IniRead(StateFile, "State", "StartTime", 0)
            return (RunningStrategy ? "**Running**" : "**Stopped**") "`n**Strategy** " (name = "" ? "None selected" : BatchCode(name))
                . (RunningStrategy && start > 0 ? "`n**Runtime** " FormatRuntime(start) : "")
                . "`n**Earned** " IniRead(StateFile, "State", "Coins", 0) " Coins · " IniRead(StateFile, "State", "Gems", 0) " Gems"
        case "start":
            return BatchQueueStart(Trim(SubStr(line, 6)))
        case "stop":
            if !RunningStrategy
                return "The macro is already stopped."
            if sub = "after-match" {
                IniWrite(1, StateFile, "Batch", "StopAfter")
                return "I’ll stop after this match."
            }
            if sub = "now" || sub = "" {
                SetTimer(StopStrategy, -50)
                return "Stopping now."
            }
        case "strategy":
            if sub = "list" {
                names := []
                for name, path in BatchStrategies() {
                    if path != ""
                        names.Push(name)
                }
                return BatchNamePage(names, args, prefix "strategy list", "No strategies found.")
            }
            if sub = "import"
                return BatchImport(msg, prefix)
            if sub = "run"
                return BatchQueueStart(args)
            if sub = "select"
                return RunningStrategy || Recording || MacroRecording ? "Stop the macro first."
                    : BatchSelectStrategy(args) ? "Selected " BatchCode(args) "." : "Strategy missing or name is ambiguous. Try " BatchCode(prefix "strategy list") "."
        case "goal":
            if sub = "status"
                return BatchGoalStatus()
            if sub = "clear" {
                IniDelete(SettingsFile, "FarmingGoal")
                return "Goal cleared."
            }
            if sub = "set" && RegExMatch(args, "i)^(Coins|Gems)\s+([1-9]\d{0,8}|1000000000)$", &goal) {
                IniWrite(Integer(goal[2]), SettingsFile, "FarmingGoal", "Target")
                IniWrite(goal[1], SettingsFile, "FarmingGoal", "Currency")
                IniWrite(1, SettingsFile, "FarmingGoal", "Enabled")
                return "Target set to " Integer(goal[2]) " " goal[1] ". " BatchGoalStatus()
            }
            return "Use " prefix "goal set coins|gems <amount>."
        case "loadout":
            selected := IniRead(SettingsFile, "Loadouts", "Selected", "")
            if sub = "list" {
                names := []
                for name in StrSplit(IniRead(SettingsFile, "Loadouts", "Names", ""), "|") {
                    if name != ""
                        names.Push(name)
                }
                return BatchNamePage(names, args, prefix "loadout list", "No presets recorded by the macro yet. Add one with " BatchCode(prefix "loadout select <exact Roblox name>") ".")
                    . "`n**Selected** " (selected != "" ? BatchCode(selected) : "None")
            }
            if sub = "select" {
                if args = "off" {
                    IniDelete(SettingsFile, "Loadouts", "Selected")
                    return "Default preset cleared."
                }
                if !IsValidLoadoutName(args) || InStr(args, "|")
                    return "Enter the exact Roblox preset name, or off."
                names := IniRead(SettingsFile, "Loadouts", "Names", "")
                if !InStr("|" names "|", "|" args "|")
                    IniWrite((names = "" ? "" : names "|") args, SettingsFile, "Loadouts", "Names")
                IniWrite(args, SettingsFile, "Loadouts", "Selected")
                return "Selected " BatchCode(args) " for the next lobby join. A strategy preset takes priority."
            }
        case "towerxp":
            return BatchXPCommand(sub, args, prefix)
        case "prefix":
            if sub = "reset" {
                BatchSetPrefix("!")
                return "Prefix reset to " BatchCode("!") ". Try " BatchCode("!help") "."
            }
            if sub = "set" && BatchValidPrefix(args) {
                BatchSetPrefix(args)
                return "Prefix changed to " BatchCode(args) ". Try " BatchCode(args "help") "."
            }
            return "Choose one punctuation symbol, such as ! or ?."
        case "screenshot":
            bitmap := Gdip_BitmapFromScreen(0)
            if bitmap <= 0
                return "Desktop capture failed."
            try return BatchUpload("Desktop screenshot", "Desktop captured.", Map("name", "files[0]", "filename", "screenshot.png",
                "content-type", "image/png", "pBitmap", bitmap), "screenshot.png") ? "" : "Could not send the screenshot to Discord."
            finally Gdip_DisposeImage(bitmap)
        case "logs":
            if sub = "export" {
                if !LogLines.Length
                    return "No logs yet. Start a run, then try " BatchCode(prefix "logs export") "."
                logs := Join(LogLines, "`n")
                return BatchUpload("Macro logs", "Log attached.", Map("name", "files[0]", "filename", "macro.log",
                    "content-type", "text/plain", "content", logs)) ? "" : "Could not send the log to Discord."
            }
    }
    return "Try " prefix "help."
}

BatchSent(response) {
    try return JSON.Parse(response).Has("id")
    return false
}

BatchQueueStart(name) {
    global RunningStrategy, Recording, MacroRecording, StateFile, Strategy1Ctrl, Strategy2Ctrl, RotateStrategiesCtrl
    if RunningStrategy || Recording || MacroRecording
        return "The macro is busy."
    if IniRead(StateFile, "State", "IsFirstLaunch", 1) = 1
        return "Complete the first launch from the macro window."
    if name != "" && !BatchSelectStrategy(name)
        return "Strategy missing or name is ambiguous."
    if (RotateStrategiesCtrl.Value && (!FileExist(Strategy1Ctrl.Value) || !FileExist(Strategy2Ctrl.Value)))
        return "Select both strategies or turn rotation off."
    if !FileExist(Strategy1Ctrl.Value) && !FileExist(Strategy2Ctrl.Value)
        return "Select a strategy first."
    SetTimer(StartStrategy, -50)
    path := FileExist(Strategy1Ctrl.Value) ? Strategy1Ctrl.Value : Strategy2Ctrl.Value
    SplitPath(path, &fileName)
    return "Starting " BatchCode(fileName) "."
}

BatchGoalStatus() {
    global SettingsFile, StateFile
    goal := BatchGoal(SettingsFile, StateFile)
    return goal ? Format("{} / {} {} · {}%", goal.earned, goal.target, goal.currency, Min(100, Round(100 * goal.earned / goal.target)))
        . (goal.reached ? " · Reached" : "") : "No farming goal set."
}

BatchXPCommand(sub, args, prefix) {
    global SettingsFile, RunningStrategy, RotateStrategies
    if sub = "status"
        return BatchXPStatus(SettingsFile)
    if sub != "target" && sub != "enable" && sub != "disable" && sub != "progress"
        return "Try " BatchCode(prefix "towerxp status") "."
    definition := BatchXPActiveTower(SettingsFile)
    if sub = "target" {
        if RunningStrategy
            return "Stop the macro before changing the tower."
        for candidate in TowerXPDefinitions() {
            if RegExMatch(args, "^(.+)\s+(\d{1,2})$", &target) && target[1] = candidate.name && target[2] >= 1 && target[2] <= 20 {
                IniWrite(Integer(target[2]), SettingsFile, TowerXPSectionName(candidate.name), "Target")
                IniWrite(candidate.name, SettingsFile, "TowerXP", "Selected")
                IniWrite(0, SettingsFile, "TowerXP", "Cycle")
                return candidate.name " target set to level " Integer(target[2]) "."
            }
        }
        names := []
        for candidate in TowerXPDefinitions()
            names.Push(candidate.name)
        return "Use " prefix "towerxp target <tower> <1–20>. Towers: " Join(names)
    }
    if sub = "disable" || sub = "enable" {
        if RunningStrategy
            return "Stop the macro before changing Tower XP mode."
        if sub = "enable" && (!definition || RotateStrategies)
            return RotateStrategies ? "Turn off strategy rotation with " BatchCode(prefix "settings rotation off") "." : "Set an unfinished target first, for example " BatchCode(prefix "towerxp target Scout 20") "."
        IniWrite(sub = "enable" ? 1 : 0, SettingsFile, "TowerXP", "Enabled")
        return "Tower XP " (sub = "enable" ? "enabled." : "disabled.")
    }
    if sub = "progress" && args != "" {
        if RunningStrategy || !definition
            return "Stop the macro and select a tower first."
        if !RegExMatch(args, "^([0-9]|1\d|20)\s+(\d{1,5})$", &entry)
            return "Use " prefix "towerxp progress <level> <XP>."
        needed := TowerXPNextRequired(definition, Integer(entry[1]))
        if (needed > 0 && Integer(entry[2]) >= needed || needed = 0 && Integer(entry[2]) != 0)
            return "Enter XP earned within the current level."
        IniWrite(Integer(entry[1]) "," Integer(entry[2]) ",", SettingsFile, TowerXPSectionName(definition.name), "Progress")
    }
    if !definition
        return "Choose a tower with " prefix "towerxp target."
    progress := TowerXPSavedProgress(SettingsFile, definition)
    target := IniRead(SettingsFile, TowerXPSectionName(definition.name), "Target", 20)
    return definition.name " · Level " progress.level "/" target " · " progress.xp " XP toward next level"
        . (IniRead(SettingsFile, "TowerXP", "Enabled", 0) = 1 ? " · enabled" : " · disabled")
}

BatchImport(msg, prefix := "!") {
    global RecordingsDir
    attachments := msg["attachments"]
    if attachments.Length != 1
        return "Attach one .strat file."
    file := attachments[1], name := file["filename"], url := file["url"]
    if !(name ~= "i)^[a-z0-9][a-z0-9 _.-]{0,75}\.strat$") || name ~= "i)^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])\."
        return "Invalid strategy filename."
    if !(url ~= "^https://(?:cdn\.discordapp\.com|media\.discordapp\.net)/attachments/\d+/\d+/[^\s]+$") || file["size"] > 262144
        return "Use a Discord attachment up to 256 KB."
    dest := RecordingsDir "\" name
    if FileExist(dest) || BatchStrategies().Has(name)
        return "That strategy name already exists."
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    req.Open("GET", url, true)
    req.Option[6] := false
    req.SetTimeouts(5000, 5000, 5000, 5000)
    req.Send()
    if !req.WaitForResponse(8) {
        req.Abort()
        return "Attachment download timed out."
    }
    if req.Status != 200
        return "Attachment unavailable."
    bytes := req.ResponseBody
    if bytes.MaxIndex() < 0 || bytes.MaxIndex() >= 262144
        return "Attachment exceeds 256 KB or is empty."
    source := req.ResponseText
    if StrPut(source, "UTF-8") > 262145
        return "Attachment exceeds 256 KB."
    if !BatchValidStrategy(source, &reason)
        return reason
    temp := dest "." A_TickCount ".tmp"
    try {
        FileAppend(source, temp, "UTF-8")
        FileMove(temp, dest)
    } finally {
        if FileExist(temp)
            FileDelete(temp)
    }
    return "Imported " BatchCode(name) ".`nRun it with " BatchCode(prefix "strategy run " name) "."
}

BatchValidStrategy(source, &reason := "") {
    reason := "A strategy needs [Settings] and at least one step in [Steps]."
    sections := Map(), section := "", steps := 0
    sections.CaseSense := "Off"
    for raw in StrSplit(source, "`n") {
        line := Trim(raw, " `t`r" Chr(0xFEFF))
        if line = "" || SubStr(line, 1, 1) = ";"
            continue
        if RegExMatch(line, "i)^\[(Info|Settings|DO NOT EDIT|Steps)\]$", &header) {
            section := StrLower(header[1])
            if sections.Has(section) {
                reason := "Duplicate [" header[1] "] section on line " A_Index "."
                return false
            }
            sections[section] := true
            continue
        }
        if section = "steps" {
            if line ~= "i)^(Send|Click)\s*\(" {
                reason := "Line " A_Index " contains desktop input. Import this strategy from the macro window."
                return false
            }
            if !(line ~= "i)^(SpawnTower\(\d{1,5},\s*\d{1,5},\s*[1-5],\s*\d{1,8}\)|UpgradeTower\(\d{1,8}(?:,\s*(?:true|false))?(?:,\s*\d{1,3}){0,3}\)|SellTower\(\d{1,8}\)|ToggleAutoskip\(\))$")
            {
                reason := "Unsupported or malformed gameplay step on line " A_Index "."
                return false
            }
            steps++
        } else if line ~= "i)^requiredTowers=" && !(line ~= "i)^requiredTowers=[a-z0-9 .,'-]*$") {
            reason := "Invalid requiredTowers value on line " A_Index "."
            return false
        } else if section = "" || !(line ~= "^[A-Za-z][A-Za-z0-9 ]{0,39}\s*=[^\x00-\x1f]*$") {
            reason := "Unexpected section or setting on line " A_Index "."
            return false
        }
    }
    return sections.Has("settings") && steps > 0
}


BatchFarmingSettings(actionName := "", *) {
    global RunningStrategy, Recording, MacroRecording, SettingsFile
    if RunningStrategy || Recording || MacroRecording {
        LocalizationMsgBox("Stop the macro before changing farming settings.")
        return
    }
    if !(actionName ~= "^(loadout|goal|towerxp)$") {
        action := LocalizationInputBox("Choose loadout, goal, or towerxp.", "Farming settings", "w390")
        if action.Result != "OK"
            return
        actionName := StrLower(Trim(action.Value))
    }
    switch actionName {
        case "loadout":
            choice := LocalizationInputBox("Enter the exact Roblox preset name, or off.", "Saved loadout", "w390",
                IniRead(SettingsFile, "Loadouts", "Selected", ""))
            if choice.Result = "OK"
                LocalizationMsgBox(BatchDispatch("loadout select " Trim(choice.Value), "", "!"))
        case "goal":
            choice := LocalizationInputBox(BatchGoalStatus() "`nEnter coins <amount>, gems <amount>, or clear.", "Farming goal", "w390")
            if choice.Result = "OK"
                LocalizationMsgBox(BatchDispatch(choice.Value = "clear" ? "goal clear" : "goal set " Trim(choice.Value), "", "!"))
        case "towerxp":
            names := []
            for tower in TowerXPDefinitions()
                names.Push(tower.name)
            choice := LocalizationInputBox(BatchXPCommand("status", "", "!") "`nEnter target <tower> <level>, enable, disable, or progress <level> <XP>.`n" Join(names), "Tower XP farming", "w540 h175")
            if choice.Result = "OK"
                LocalizationMsgBox(BatchDispatch("towerxp " Trim(choice.Value), "", "!"))
    }
}



BatchValidPrefix(value) => value ~= "^[!#$%&*+,./:;=?^_~|-]$"

BatchSetPrefix(value) {
    global BotSettings, BotPrefixCtrl
    IniWrite(value, BotSettings, "Settings", "Prefix")
    if IsSet(BotPrefixCtrl)
        BotPrefixCtrl.Value := value
}
BatchXPStatus(settings) {
    enabled := IniRead(settings, "TowerXP", "Enabled", 0) = 1
    cycle := IniRead(settings, "TowerXP", "Cycle", 0) = 1
    selected := BatchXPSelection(settings)
    result := enabled ? "**On**" : "**Off**"
    count := 0
    for definition in TowerXPDefinitions() {
        key := TowerXPSectionName(definition.name)
        if !(cycle ? IniRead(settings, key, "Tracked", 0) = 1 : selected && selected.name = definition.name)
            continue
        progress := TowerXPSavedProgress(settings, definition)
        target := TowerXPNumber(settings, key, "Target", definition.maxLevel, definition.maxLevel)
        result .= "`n• " definition.name " · Level " progress.level " / " target
        count++
    }
    return count ? result : result "`nNo towers selected."
}



