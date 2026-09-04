ProcessCommands(*) {
    global command_buffer, UserID, RunningStrategy, ChannelID, BotPrefix, ver, AutorunStartTime, StateFile

    try {
    Discord.GetCommands(ChannelID)

    for command in command_buffer {
        rawContent := Trim(command.content)
        commandPrefix := SubStr(rawContent, 1, 1)
        if (commandPrefix != "!" && commandPrefix != BotPrefix)
            continue

        commandText := StrLower(Trim(SubStr(rawContent, 2)))
        if !RegExMatch(commandText, "^[a-z]+(?:\s+.*)?$")
            continue
        content := RegExReplace(commandText, "\s+.*$")
        argument := Trim(SubStr(commandText, StrLen(content) + 1))

        if (content = "help" || content = "helpm") {
            helpText := "**Available commands:**\n"
            helpText .= "\n!help - shows the help menu"
            helpText .= "\n!screenshot - take and send a screenshot"
            helpText .= "\n!status - view macro status and statistics"
            helpText .= "\n!stop - stop the macro"
            helpText .= "\n!start - start the macro"
            helpText .= "\n!ping - check whether the bot is online"
            helpText .= "\n!version - show the macro version"
            helpText .= "\n!current - show the active strategy and runtime"
            helpText .= "\n!stats - show wins, losses, and saved resources"
            helpText .= "\n!exportlogs - upload diagnostic logs"
            helpText .= "\n!strat - list available strategy files"
            helpText .= "\n!strat <number> - select and start a strategy"
            if (BotPrefix != "!")
                helpText .= "\n\nCustom prefix enabled: " BotPrefix " (both ! and " BotPrefix " work)"
            Discord.SendEmbed(
                helpText
            )
        }

        else if (content = "ping") {
            Discord.SendEmbed("Pong! Ultimate Macro TDS bot is online.")
        }

        else if (content = "version") {
            Discord.SendEmbed("Ultimate Macro TDS v" ver)
        }

        else if (content = "current") {
            strategyPath := IniRead(StateFile, "State", "Strategy", "")
            if (strategyPath != "")
                SplitPath(strategyPath, &currentStrategyName)
            else
                currentStrategyName := "None selected"

            currentStatus := RunningStrategy ? "Working" : "Stopped"
            currentRuntime := RunningStrategy ? FormatRuntime(AutorunStartTime) : "Not running"
            Discord.SendEmbed(
                "**Macro:** " currentStatus "\n"
                . "**Strategy:** " currentStrategyName "\n"
                . "**Runtime:** " currentRuntime
            )
        }

        else if (content = "stats") {
            savedCoins := IniRead(StateFile, "State", "Coins", 0)
            savedGems := IniRead(StateFile, "State", "Gems", 0)
            savedExp := IniRead(StateFile, "State", "EXP", 0)
            totalTriumphs := IniRead(StateFile, "State", "TotalTriumphs", 0)
            totalLosses := IniRead(StateFile, "State", "TotalLosses", 0)
            totalMatches := totalTriumphs + totalLosses
            winrate := (totalMatches > 0) ? Round((totalTriumphs / totalMatches) * 100) : 0

            Discord.SendEmbed(
                "**Stats**\n"
                . "**Wins:** " totalTriumphs " | **Losses:** " totalLosses " | **Win rate:** " winrate "%\n"
                . "**Coins:** " savedCoins " | **Gems:** " savedGems " | **EXP:** " savedExp
            )
        }

        else if (content = "exportlogs") {
            ExportLogsToDiscord()
        }

        else if (content = "strat") {
            if (argument = "")
                ListBotStrategies()
            else
                SelectBotStrategy(argument)
        }
        
        else if (content = "screenshot") {
            pBitmap := Gdip_BitmapFromScreen()
            Discord.SendScreenshot(pBitmap, "Requested Screenshot")
        }
        
        else if (content = "status") {
            status := "stopped"
            if (RunningStrategy)
                status := "working"

            savedCoins := IniRead(StateFile, "State", "Coins", 0)
            savedGems := IniRead(StateFile, "State", "Gems", 0)
            savedExp := IniRead(StateFile, "State", "EXP", 0)
            
            totalTriumphs := IniRead(StateFile, "State", "TotalTriumphs", 0)
            totalLosses := IniRead(StateFile, "State", "TotalLosses", 0)
            totalMatches := totalTriumphs + totalLosses
            winrate := (totalMatches > 0) ? Round((totalTriumphs / totalMatches) * 100) : 0
            wlRatio := (totalLosses > 0) ? Round(totalTriumphs / totalLosses, 1) : totalTriumphs

            runtime := FormatRuntime(AutorunStartTime)

            autorunStart := IniRead(StateFile, "State", "StartTime", 0)
            coinsPerHour := 0, gemsPerHour := 0, expPerHour := 0
            if (autorunStart > 0) {
                elapsedMs := A_TickCount - autorunStart
                elapsedHours := elapsedMs / 3600000
                if (elapsedHours > 0.001) {
                    coinsPerHour := Round(savedCoins / elapsedHours)
                    gemsPerHour := Round(savedGems / elapsedHours)
                    expPerHour := Round(savedExp / elapsedHours)
                }
            }
            
            currentStrategy := IniRead(StateFile, "State", "Strategy", "")

            SplitPath(currentStrategy, &stratName)
            
            if (RunningStrategy) {
                statusMsg := "**Macro Status:** Working\n"
                statusMsg .= "**Runtime:** " runtime "\n\n"
                statusMsg .= "**Current Strategy:** " stratName "\n\n"
                statusMsg .= "+" savedCoins " **Coins**\t+" savedGems " **Gems**\t+" savedExp " **EXP**\n"
                statusMsg .= coinsPerHour " Coins/h\t" gemsPerHour " Gems/h\t" expPerHour " EXP/h\n\n"
                statusMsg .= "**Total Matches:** " totalMatches "\t**Wins:** " totalTriumphs "\t**Losses:** " totalLosses "\n"
                statusMsg .= "**Winrate:** " winrate "%\t**W/L Ratio:** " wlRatio
            } else {
                statusMsg := "**Macro Status:** Stopped"
            }

            currentTime := A_Hour ":" A_Min ":" A_Sec
            statusMsg .= "\n-# Ultimate Macro Bot • " currentTime

            Discord.SendEmbed(statusMsg, "3447003")
        }

        else if (content = "stop") {
            if (RunningStrategy) {
                Discord.SendEmbed("Stopping the macro..", "56320")
                id := Discord.GetMessageAPI()
                StopStrategy()
            } else {
                Discord.SendEmbed("Failed to stop: the macro is not running!", "16515072")
            }
        }

        else if (content = "start") {
            if (RunningStrategy) {
                Discord.SendEmbed("Failed to start: the macro is already running!", "16515072")
            } else {
                Discord.SendEmbed("Starting the macro..", "56320")
                SetTimer(StartStrategy, -100)
            }
        }
    }
    
    } catch Error as err {
        LogToConsole("Discord command error: " err.Message, true)
    }

    command_buffer := []
}

ExportLogsToDiscord() {
    global LogLines
    try {
        report := "**Recent diagnostic log**\n"
        if (LogLines.Length = 0) {
            report .= "No in-memory log lines are available."
        } else {
            startAt := Max(1, LogLines.Length - 18)
            loop LogLines.Length - startAt + 1
                report .= "\n" LogLines[startAt + A_Index - 1]
        }
        Discord.SendEmbed(SubStr(report, 1, 3900))
    } catch Error as err {
        Discord.SendEmbed("Could not export diagnostics: " err.Message)
    }
}

ListBotStrategies() {
    global BotStrategyChoices, BotStrategyChoiceTime, StratsDir, RecordingsDir, BotPrefix

    choices := []
    if DirExist(StratsDir) {
        Loop Files, StratsDir "\\*.strat", "F" {
            choices.Push({name: A_LoopFileName, path: A_LoopFileFullPath})
            if (choices.Length >= 25)
                break
        }
    }

    if (choices.Length < 25 && DirExist(RecordingsDir)) {
        Loop Files, RecordingsDir "\\*.strat", "F" {
            choices.Push({name: A_LoopFileName, path: A_LoopFileFullPath})
            if (choices.Length >= 25)
                break
        }
    }

    BotStrategyChoices := choices
    BotStrategyChoiceTime := A_TickCount

    if (choices.Length = 0) {
        Discord.SendEmbed("No .strat files were found in the macro's strategy folders.")
        return
    }

    message := "**Available strategies:**\n"
    for index, item in choices
        message .= "\n" index ". " item.name
    message .= "\n\nUse " BotPrefix "strat <number> to select one."
    Discord.SendEmbed(message)
}

SelectBotStrategy(argument) {
    global BotStrategyChoices, BotStrategyChoiceTime, Strategy1Path, Strategy2Path, RotateStrategies
    global Strategy1Ctrl, Strategy2Ctrl, RotateStrategiesCtrl, SettingsFile, RunningStrategy, StateFile, BotPrefix

    if !RegExMatch(argument, "^\d+$") {
        Discord.SendEmbed("Use a number from the strategy list, for example: " BotPrefix "strat 2")
        return
    }

    if (BotStrategyChoices.Length = 0 || A_TickCount - BotStrategyChoiceTime > 300000) {
        Discord.SendEmbed("The strategy list expired. Request it again before choosing.")
        ListBotStrategies()
        return
    }

    index := Integer(argument)
    if (index < 1 || index > BotStrategyChoices.Length) {
        Discord.SendEmbed("That strategy number is not in the current list. Request the list again with " BotPrefix "strat.")
        return
    }

    selected := BotStrategyChoices[index]
    if !FileExist(selected.path) {
        Discord.SendEmbed("That strategy file is no longer available. Request the list again with " BotPrefix "strat.")
        return
    }

    Strategy1Path := selected.path
    Strategy2Path := ""
    RotateStrategies := 0
    Strategy1Ctrl.Value := selected.path
    Strategy2Ctrl.Value := ""
    RotateStrategiesCtrl.Value := 0
    IniWrite(Strategy1Path, SettingsFile, "Options", "Strategy1")
    IniWrite(Strategy2Path, SettingsFile, "Options", "Strategy2")
    IniWrite(0, SettingsFile, "Options", "RotateStrategies")

    if (RunningStrategy) {
        IniWrite(1, StateFile, "State", "Running")
        IniWrite(selected.path, StateFile, "State", "Strategy")
        Discord.SendEmbed("Selected **" selected.name "**. Restarting the macro with this strategy.")
        SafeReload()
    } else {
        Discord.SendEmbed("Selected **" selected.name "**. Starting the macro with this strategy.")
        SetTimer(StartStrategy, -100)
    }
}
