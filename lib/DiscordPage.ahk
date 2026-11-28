DiscordPageBuild(gui) {
    global
    local routeLabel, routeReveal, mentionNote, webhookReveal, revealBot, webhookTest, botTest, index, row, spec
    DiscordPageTabs := [AppearanceDarkButton(gui, "x244 y94 w112 h30 Hidden", "Webhook", 2),
        AppearanceDarkButton(gui, "x364 y94 w92 h30 Hidden", "Bot", 3)]
    DiscordPageTabs[1].OnEvent("Click", (*) => DiscordPageShow(false))
    DiscordPageTabs[2].OnEvent("Click", (*) => DiscordPageShow(true))
    DiscordPageStatus := DiscordPageLabel(gui, "x206 y502 w292 h32", "")

    DiscordWebhookTab.Push(DiscordPageLabel(gui, "x24 y139 w230 h20", "Connection", true))
    WebhookEnabledCtrl := DiscordPageCheck(gui,"x500 y136 w176 h26","Enable Webhook",WebhookEnabled)
    DiscordWebhookTab.Push(WebhookEnabledCtrl, DiscordPageLabel(gui, "x24 y169 w230 h20", "Webhook URL:"))
    WebhookLinkCtrl := DiscordPageEdit(gui, "x24 y191 w540 h27 Password", WebhookLink)
    webhookReveal := DiscordRevealButton(gui, WebhookLinkCtrl, 574, 191)
    DiscordWebhookTab.Push(WebhookLinkCtrl, webhookReveal, DiscordPageLabel(gui, "x24 y231 w260 h22", "Notifications", true))
    SendCurrCtrl := DiscordPageCheck(gui,"x24 y256 w310 h26","Send Statistics",SendCurrenciesEnabled)
    DebugLogsCtrl := DiscordPageCheck(gui,"x356 y256 w320 h26","Debug Logs",WebhookDebugLogs)
    WebhookScreenshotsCtrl := DiscordPageCheck(gui,"x24 y285 w310 h26","Automatic screenshots",WebhookScreenshots)
    WebhookTriumphScreenshotsCtrl := DiscordPageCheck(gui,"x356 y285 w320 h26","Triumph and Loss screenshots",WebhookTriumphScreenshots)
    DiscordWebhookTab.Push(SendCurrCtrl,DebugLogsCtrl,WebhookScreenshotsCtrl,WebhookTriumphScreenshotsCtrl)
    DiscordWebhookTab.Push(DiscordPageLabel(gui,"x24 y322 w270 h20","Channel routing",true))
    WebhookSepatateTriumphScreenshotsCtrl := DiscordPageCheck(gui,"x24 y345 w650 h25","Send match results to a separate channel",WebhookSepatateTriumphScreenshots)
    routeLabel := DiscordPageLabel(gui,"x24 y378 w148 h27","Results webhook URL")
    WebhookLinkCtrl2 := DiscordPageEdit(gui,"x176 y375 w388 h27 Password",WebhookLink2)
    routeReveal := DiscordRevealButton(gui,WebhookLinkCtrl2,574,375)
    DiscordRoutingControls := [routeLabel,WebhookLinkCtrl2,routeReveal]
    DiscordWebhookTab.Push(WebhookSepatateTriumphScreenshotsCtrl,DiscordRoutingControls*)
    DiscordWebhookTab.Push(DiscordPageLabel(gui,"x24 y410 w180 h20","Mentions",true))
    WebhookMentionToggle := DiscordPageCheck(gui,"x24 y432 w324 h27","Mention me on important events",IniRead(SettingsFile,"Webhook","MentionEvents",0))
    mentionNote := DiscordPageLabel(gui,"x24 y460 w324 h33","Wins, losses, and when Timescale tickets run out.")
    WebhookMentionLabel := DiscordPageLabel(gui,"x356 y432 w320 h22","Discord user ID")
    WebhookMentionIDCtrl := DiscordPageEdit(gui,"x356 y457 w320 h27 Number Limit20",WebhookUserID)
    DiscordMentionControls := [WebhookMentionLabel,WebhookMentionIDCtrl]
    DiscordWebhookTab.Push(WebhookMentionToggle,mentionNote,DiscordMentionControls*)
    webhookTest := AppearanceDarkButton(gui,"x508 y502 w168 h32 Hidden","Test Webhook")
    webhookTest.OnEvent("Click", DiscordTestConnection.Bind(false))
    DiscordWebhookTab.Push(DiscordGuide(gui,"Webhook setup guide","https://support.discord.com/hc/en-us/articles/228383668"),webhookTest)

    DiscordBotTab.Push(DiscordPageLabel(gui,"x24 y139 w230 h20","Connection",true))
    BotEnabledCtrl := DiscordPageCheck(gui,"x500 y136 w176 h26","Enable Bot",BotEnabled)
    BotTokenCtrl := DiscordPageEdit(gui,"x24 y191 w540 h27 Password",BotToken)
    revealBot := DiscordRevealButton(gui,BotTokenCtrl,574,191)
    DiscordBotTab.Push(BotEnabledCtrl,DiscordPageLabel(gui,"x24 y169 w230 h20","Bot Token:"),BotTokenCtrl,revealBot)
    DiscordBotTab.Push(DiscordPageLabel(gui,"x24 y242 w340 h20","Bot configuration",true))
    ChannelIDCtrl := DiscordPageEdit(gui,"x24 y296 w314 h27 Number Limit20",ChannelID)
    WebhookUserIDCtrl2 := DiscordPageEdit(gui,"x362 y296 w314 h27 Number Limit20",UserID)
    DiscordBotTab.Push(DiscordPageLabel(gui,"x24 y271 w314 h20","Channel ID:"),DiscordPageLabel(gui,"x362 y271 w314 h20","User ID:"),ChannelIDCtrl,WebhookUserIDCtrl2)
    BotPrefixCtrl := DiscordPageEdit(gui,"x173 y349 w52 h27 Center Limit1",IniRead(BotSettings,"Settings","Prefix","!"))
    DiscordBotTab.Push(DiscordPageLabel(gui,"x24 y351 w145 h24","Command prefix"), BotPrefixCtrl,
        DiscordPageLabel(gui,"x237 y351 w439 h36","One punctuation symbol. Default is !. Use help to list commands."))
    botTest := AppearanceDarkButton(gui,"x508 y502 w168 h32 Hidden","Test Bot")
    botTest.OnEvent("Click",DiscordTestConnection.Bind(true))
    DiscordBotTab.Push(DiscordGuide(gui,"Bot setup guide","https://youtu.be/eAQ5Hm7fQu4"),botTest)
    DiscordSecrets := Map(WebhookLinkCtrl,webhookReveal,WebhookLinkCtrl2,routeReveal,BotTokenCtrl,revealBot)
    for index, row in [
        [WebhookLinkCtrl,"WebhookLink","Link","url"], [WebhookLinkCtrl2,"WebhookLink2","Link2","url"],
        [WebhookMentionIDCtrl,"WebhookUserID","WebhookUserID","id"],
        [BotTokenCtrl,"BotToken","BotToken","token"], [ChannelIDCtrl,"ChannelID","Channel","id"],
        [WebhookUserIDCtrl2,"UserID","UserID","id"], [BotPrefixCtrl,"","Prefix","prefix"]
    ] {
        spec := {name:row[2], key:row[3], kind:row[4], bot:index >= 4}
        row[1].OnEvent("Change",DiscordQueueField.Bind(spec))
    }
    for index, row in [[WebhookEnabledCtrl,"WebhookEnabled","Enabled"],[SendCurrCtrl,"SendCurrenciesEnabled","SendCurrencies"],
        [DebugLogsCtrl,"WebhookDebugLogs","WebhookDebugLogs"],[WebhookScreenshotsCtrl,"WebhookScreenshots","WebhookScreenshots"],
        [WebhookTriumphScreenshotsCtrl,"WebhookTriumphScreenshots","WebhookTriumphScreenshots"],
        [WebhookSepatateTriumphScreenshotsCtrl,"WebhookSepatateTriumphScreenshots","WebhookSepatateTriumphScreenshots"],
        [WebhookMentionToggle,"","MentionEvents"],[BotEnabledCtrl,"BotEnabled","Enabled"]] {
        spec := {name:row[2],key:row[3],kind:"toggle",bot:index = 8}
        row[1].OnEvent("Click",DiscordSaveField.Bind(spec))
    }
}

DiscordPageLabel(gui, options, caption, heading := false) {
    AppearanceFont(gui, heading ? "s10 Norm c3A86FF" : "s9 Norm cE2E4E7", "Segoe UI")
    return AppearanceAdd(gui,"Text",options " Hidden BackgroundTrans",caption)
}

DiscordPageCheck(gui, options, caption, checked) {
    AppearanceFont(gui,"s9 Norm cE2E4E7","Segoe UI")
    return AppearanceAdd(gui,"Checkbox",options " Hidden +0x2000 " (checked ? "Checked" : ""),caption)
}

DiscordPageEdit(gui, options, value) {
    AppearanceFont(gui,"s9 Norm cE2E4E7","Segoe UI")
    return AppearanceAdd(gui,"Edit",options " Hidden",value)
}

DiscordGuide(gui, caption, url) {
    ctrl := AppearanceDarkButton(gui,"x24 y502 w174 h32 Hidden",caption)
    ctrl.OnEvent("Click",(*) => Run(url))
    return ctrl
}

DiscordRevealButton(gui, field, x, y) {
    ctrl := AppearanceDarkButton(gui,"x" x " y" y " w102 h28 Hidden","Show")
    ctrl.OnEvent("Click",DiscordToggleSecret.Bind(field))
    return ctrl
}

DiscordToggleSecret(field, ctrl, *) {
    reveal := SendMessage(0xD2, 0, 0, field.Hwnd) != 0
    SendMessage(0xCC, reveal ? 0 : 0x25CF, 0, field.Hwnd)
    ctrl.Text := TranslateText(reveal ? "Hide" : "Show")
    field.Redraw()
}

DiscordPageShow(bot) {
    global DiscordBotSettingsOpen, DiscordPageTabs, DiscordPageStatus, DiscordSecrets
    DiscordBotSettingsOpen := bot
    for ctrl in DiscordWebhookTab
        ctrl.Visible := !bot
    for ctrl in DiscordBotTab
        ctrl.Visible := bot
    for field, reveal in DiscordSecrets {
        SendMessage(0xCC, 0x25CF, 0, field.Hwnd)
        reveal.Text := TranslateText("Show")
    }
    for ctrl in DiscordPageTabs {
        ctrl.Visible := true
        ctrl.Redraw()
    }
    DiscordPageStatus.Visible := true
    DiscordStatus()
    DiscordDependencies()
}

DiscordDependencies() {
    if CurrentTab != "Tab4" || DiscordBotSettingsOpen
        return
    for ctrl in DiscordRoutingControls
        ctrl.Visible := !!WebhookSepatateTriumphScreenshotsCtrl.Value
    for ctrl in DiscordMentionControls
        ctrl.Visible := !!WebhookMentionToggle.Value
}

DiscordStatus(message := "") {
    DiscordPageStatus.Text := TranslateText(message)
}

DiscordQueueField(spec, ctrl, *) {
    SettingsQueueAction("discord." spec.key, DiscordSaveField.Bind(spec, ctrl))
}

DiscordWebhookValid(url) => url ~= "i)^https://(?:(?:canary|ptb)\.)?(?:discord\.com|discordapp\.com)/api/(?:v[0-9]+/)?webhooks/\d{17,20}/[a-z0-9_-]+/?$"
DiscordTokenValid(token) => token ~= "^[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{15,}$|^mfa\.[A-Za-z0-9_-]{30,}$"

DiscordSaveField(spec, ctrl, *) {
    global
    local value := spec.kind = "toggle" ? ctrl.Value : Trim(ctrl.Value), path, section, key := spec.key, variable := spec.name
    DiscordDependencies()
    try {
        if spec.kind = "prefix" && !BatchValidPrefix(value) {
            DiscordStatus("Use one punctuation symbol, such as ! or ?.")
            return
        }
        if spec.kind = "url" && !DiscordWebhookValid(value) {
            DiscordStatus("Enter a valid Discord webhook URL.")
            return
        }
        if spec.kind = "token" && !DiscordTokenValid(value) {
            DiscordStatus("Enter a valid bot token.")
            return
        }
        if spec.kind = "id" && !WebhookMentionIDValid(value) {
            DiscordStatus("Enter a valid Discord ID.")
            return
        }
        if spec.kind = "toggle" && value {
            SettingsFlush()
            if key = "Enabled" && !spec.bot && !DiscordWebhookValid(WebhookLink) {
                ctrl.Value := WebhookEnabled
                DiscordStatus("Enter a valid Discord webhook URL.")
                return
            }
            if key = "Enabled" && spec.bot && (!DiscordTokenValid(BotToken) || !WebhookMentionIDValid(ChannelID) || !WebhookMentionIDValid(UserID)) {
                ctrl.Value := BotEnabled
                DiscordStatus("Enter a valid bot token, channel ID and user ID.")
                return
            }
            if key = "MentionEvents" && !WebhookMentionIDValid(WebhookUserID) {
                DiscordStatus("Enter a valid Discord ID.")
                return
            }
            if key = "WebhookSepatateTriumphScreenshots" && !DiscordWebhookValid(WebhookLink2) {
                DiscordStatus("Enter a valid results webhook URL.")
                return
            }
        }
        path := spec.bot ? BotSettings : SettingsFile
        section := spec.bot ? (spec.kind = "token" ? "Token" : "Settings") : "Webhook"
        if IniRead(path, section, key, "") != value
            IniWrite(value,path,section,key)
        if variable != ""
            %variable% := value
        if spec.bot && key = "Enabled" && !MacroClosing
            SetTimer(ProcessCommands, value ? 1000 : 0, 1)
        if key = "WebhookUserID" && WebhookMentionToggle.Value
            IniWrite(1,SettingsFile,"Webhook","MentionEvents")
        if key = "Link2" && WebhookSepatateTriumphScreenshotsCtrl.Value && !WebhookSepatateTriumphScreenshots {
            IniWrite(1,SettingsFile,"Webhook","WebhookSepatateTriumphScreenshots")
            WebhookSepatateTriumphScreenshots := 1
        }
        DiscordStatus()
    } catch {
        if spec.kind = "toggle"
            ctrl.Value := IniRead(spec.bot ? BotSettings : SettingsFile, spec.bot ? "Settings" : "Webhook", key, 0)
        DiscordDependencies()
        DiscordStatus("Couldn't save settings.")
    }
}

DiscordTestConnection(bot, ctrl, *) {
    SettingsFlush()
    url := Trim(WebhookLinkCtrl.Value)
    token := Trim(BotTokenCtrl.Value), channel := Trim(ChannelIDCtrl.Value)
    if bot ? (!DiscordTokenValid(token) || !WebhookMentionIDValid(channel)) : !DiscordWebhookValid(url) {
        DiscordStatus(bot ? "Enter a valid bot token and channel ID." : "Enter a valid Discord webhook URL.")
        return
    }
    ctrl.Enabled := false
    DiscordStatus("Testing connection…")
    try {
        request := ComObject("WinHttp.WinHttpRequest.5.1")
        request.SetTimeouts(3000,3000,3000,3000)
        request.Open("POST",bot ? "https://discord.com/api/v10/channels/" channel "/messages" : url,false)
        if bot
            request.SetRequestHeader("Authorization","Bot " token)
        request.SetRequestHeader("Content-Type","application/json")
        request.Send(JSON.Stringify(Map("content","Ultimate Macro connection test.")))
        DiscordStatus(request.Status >= 200 && request.Status < 300 ? "Test message sent." : "")
        if !(request.Status >= 200 && request.Status < 300)
            DiscordPageStatus.Text := TF("Connection test failed (HTTP {status}).",Map("status",request.Status))
    } catch {
        DiscordStatus("Connection test failed.")
    } finally ctrl.Enabled := true
}

PartyAutosaveInit() {
    global PartySaveStatus := DiscordPageLabel(MainGui,"x30 y503 w640 h22","")
    for ctrl in [MultiplayerEnabledTGL,Tab3_Role_Host,Tab3_Role_Member,Tab3_LCondition_All,Tab3_LCondition_Any]
        ctrl.OnEvent("Click",PartyAutosave)
    for ctrl in [Tab3_HostNm_EDIT,Tab3_PartyMemb_Edit]
        ctrl.OnEvent("Change",(*) => SettingsQueueAction("party",PartyAutosave))
}

PartyAutosave(*) {
    try {
        SaveAllSettingsMULTIPLAYER(0)
        PartySaveStatus.Text := ""
    } catch {
        PartySaveStatus.Text := TranslateText("Couldn't save settings.")
    }
}
