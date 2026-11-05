; Ultimate Macro 1.4 (AutoHotkey edition) - main window.
; The layout follows projects/ultimate-140-python-ui/ultmacro_ui/window.py.
; Part of a modified version of "Ultimate Macro" by Darksen, licensed GNU GPLv3.

class MW {
    static gui := "", surface := "", layout := "", pages := [], page := 0, logo := 0
    static tabs := [], items := [], visibleItems := [], current := "", outputVisible := false, outputLines := []
    static booting := true, engineReady := false, closing := false, busy := false
    static stopPending := false, stopFailed := false, job := "", runStarted := false
    static run := {active: false, phase: "idle", matches: 0}
    static rec := {active: false, draft: false, text: "", steps: 0, aligned: false, passive: false, incomplete: false, pendingSave: false, phase: "Draft"}
    static repeatBeforeRotation := "", loadoutCache := Map(), reasonCache := Map(), compact := false
    static dockAutoPending := false, dockRestoreMax := false, launcherWaiting := false, updateReviewing := false
    static hotkeyConflict := false, lastMatches := 0, wasRunning := false, removeTarget := ""
    static NAV_PAGES := [1, 2, 3, 5, 6, 4]
    static windowFade := "", pageFade := "", pageShade := 0
    static keyboardFocus := "", ultra := false

    ; ======================================================================
    ; construction
    ; ======================================================================
    static Build() {
        s := Store.settings
        Theme.christmas := s["halloween"]
        MW.dockAutoPending := s["dockRoblox"]
        g := Gui("-Caption +Resize +MinimizeBox -DPIScale +0x02000000", "Ultimate Macro")
        g.BackColor := Theme.Hex("base")
        g.MarginX := 0, g.MarginY := 0
        MW.gui := g
        if s["topmost"]
            g.Opt("+AlwaysOnTop")
        MW.logo := Gfx.LoadImage(App.assets "\UltBot.png")
        Backdrop.Load(App.assets "\AlpineSunset.jpg")

        ; ---- header --------------------------------------------------------
        header := HBox()
        header.Add(Spacer(14))
        header.Add(ImageBox(MW.logo, 20))
        header.Add(Spacer(8))
        MW.headerTitle := header.Add(Label(_T("Ultimate Macro")))
        MW.tabs := []
        for i, name in ["Run", "Record", "Party", "Discord", "Tools", "Settings"] {
            b := Button(_T(name, name = "Record" ? "Recording" : name), ObjBindMethod(MW, "SelectPage", i), "nav")
            b.fixedH := 45
            MW.tabs.Push(header.Add(b))
        }
        MW.compactNav := Select(, 1, (sel, i) => MW.SelectPage(MW.NAV_PAGES[i]))
        for name in ["Run", "Record", "Party", "Tools", "Settings", "Discord"]
            MW.compactNav.AddItem(_T(name, name = "Record" ? "Recording" : name))
        MW.compactNav.fixedW := 132
        header.Add(Spacer(8))
        header.Add(MW.compactNav).Hide()
        MW.dragArea := header.Add(Spacer(16), 1)
        MW.startBtn := header.Add(Button(_T("Start"), (*) => MW.StartRun(), "accent", "play"))
        MW.startBtn.tip := "Start the selected strategy; F1 in Roblox."
        header.Add(Spacer(7))
        MW.stopBtn := header.Add(Button(_T("Stop"), (*) => MW.StopRun(), "stop", "stop"))
        header.Add(Spacer(10))
        for spec in [["min", (*) => MW.gui.Minimize()], ["max", (*) => MW.ToggleMaximize()], ["close", (*) => MW.Close()]] {
            b := Button("", spec[2], "chrome", spec[1])
            b.fixedW := 30, b.fixedH := 45
            b.tip := spec[1] = "min" ? "Minimize" : spec[1] = "max" ? "Maximize" : "Close"
            header.Add(b)
            if (spec[1] = "max")
                MW.maxBtn := b
        }

        MW.compactStrategies := Select(, 1, (sel, i) => MW.ChooseVisible(i))
        MW.ultraNav := Select(["Run", "Record", "Party", "Tools", "Settings", "Discord"], 1
            , (sel, i) => MW.SelectPage(MW.NAV_PAGES[i]))

        ; ---- sidebar -------------------------------------------------------
        side := VBox(, 10, [14, 16, 11, 12])
        titleRow := HBox(, 6)
        titleRow.Add(Label(_T("Strategies")), 1)
        add := Button("", (*) => MW.ImportStrategy(), "", "plus")
        add.fixedW := 30, add.tip := "Import a strategy file"
        titleRow.Add(add)
        side.Add(titleRow)
        MW.search := side.Add(Field("", "Search strategies", {onChange: (*) => MW.FilterLibrary()}))
        MW.list := side.Add(StrategyList((i) => MW.ChooseVisible(i)), 1)
        MW.sidebar := side

        ; ---- output bar and status -----------------------------------------
        bar := HBox(, 6, [0, 0, 6, 0])
        MW.outputBtn := bar.Add(Button(_T("Output") "   " _T("Ready."), (*) => MW.ToggleOutput(), "output"), 1)
        MW.outputBtn.fixedH := 32
        MW.exportBtn := bar.Add(Button(_T("Export log"), (*) => MW.ExportOutput()))
        MW.exportBtn.tip := "Save the visible Output history as a text file. Review it before sharing."
        MW.outputBar := bar
        status := HBox(, 0, [14, 0, 0, 0])
        MW.statusLabel := status.Add(Label(_T("Idle"), "caption"), 1)
        MW.grip := status.Add(ResizeGrip())
        MW.statusBar := status

        MW.layout := MainLayout(header, MW.ultraNav, MW.compactStrategies, side, bar, status)
        MW.surface := Surface(g, MW.layout)
        MW.surface.background := (sf) => Backdrop.PaintFor(sf, 0, 0)
        MW.surface.overlay := (sf) => MW.booting ? BootStage.Paint(sf) : 0
        MW.header := header

        ; Output history: read-only native edit so it can be selected and copied.
        g.SetFont("s9 c" Theme.Hex("muted"), "Consolas")
        MW.outputEdit := g.Add("Edit", "x0 y0 w10 h10 Hidden ReadOnly Multi -E0x200 +VScroll +0x100 Background" Theme.Hex("panel"))
        DllCall("uxtheme\SetWindowTheme", "Ptr", MW.outputEdit.Hwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)

        ; ---- pages ---------------------------------------------------------
        MW.pages := []
        Loop 6
            MW.pages.Push(MW.NewPage())
        MW.BuildRun(MW.pages[1].root)
        MW.BuildRecord(MW.pages[2].root)
        MW.BuildParty(MW.pages[3].root)
        MW.BuildDiscord(MW.pages[4].root)
        MW.BuildTools(MW.pages[5].root)
        MW.BuildSettings(MW.pages[6].root)

        g.OnEvent("Size", (gui, minmax, w, h) => MW.OnSize(minmax, w, h))
        g.OnEvent("Close", (*) => (MW.Close(), true))
        MW.RefreshLibrary(false)
        if Store.recovered
            MW.Log("Some presentation settings could not be read; only those use their defaults.")
    }

    static NewPage() {
        g := Gui("-Caption -DPIScale +Parent" MW.gui.Hwnd " +0x02000000")
        g.BackColor := Theme.Hex("base")
        g.MarginX := 0, g.MarginY := 0
        root := VBox(, 12, [24, 20, 22, 20])
        surf := Surface(g, root, true)
        surf.offX := 0, surf.offY := 0
        surf.background := (sf) => Backdrop.PaintFor(sf, sf.offX, sf.offY)
        surf.overlay := (sf) => MW.pageShade ? Gfx.Rect(0, 0, sf.lw, sf.lh, Alpha(Theme.C("base"), MW.pageShade)) : 0
        return {gui: g, surface: surf, root: root, shown: false}
    }

    static Show() {
        s := Gfx.S, w := Round(820 * s), h := Round(560 * s)
        MW.booting := true
        BootStage.Begin()
        MW.gui.Show("w" w " h" h " Hide")
        MW.ApplyTheme()
        MW.SelectPage(1)
        ; Centre on the work area of the primary monitor, clamped to fit.
        MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
        MW.gui.Opt("+MinSize" Min(Round(480*s), r-l) "x" Min(Round(320*s), b-t))
        w := Min(w, r - l), h := Min(h, b - t)
        x := l + (r - l - w) // 2, y := t + (b - t - h) // 2
        if Store.settings["motion"] {
            WinSetTransparent(0, MW.gui)
            MW.gui.Show()
            MW.PositionStartup(x, y, w, h)
            MW.FadeTo(Round(Store.settings["windowOpacity"] * 2.55), 220)
        } else {
            MW.gui.Show()
            MW.PositionStartup(x, y, w, h)
            MW.ApplyOpacity()
        }
        SetTimer(ObjBindMethod(MW, "Tick"), 500)
        if Store.settings["halloweenSounds"]
            SetTimer(() => MW.PlayStartupSound(), -10)
        SetTimer(() => MW.CheckEngine(true), -50)
    }

    static PositionStartup(x, y, w, h) {
        DllCall("SetWindowPos", "Ptr", MW.gui.Hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", 0x14)
    }

    static FadeTo(target, ms, then := "") {
        if MW.windowFade
            SetTimer(MW.windowFade, 0)
        current := WinGetTransparent(MW.gui)
        from := IsNumber(current) ? current : 255
        start := A_TickCount
        step() {
            t := Min(1, (A_TickCount - start) / ms)
            e := then ? t : 1 - (1 - t) ** 3
            try WinSetTransparent(Round(from + (target - from) * e), MW.gui)
            if (t >= 1) {
                SetTimer(step, 0)
                MW.windowFade := ""
                if then
                    then.Call()
            }
        }
        MW.windowFade := step
        SetTimer(step, 15)
    }

    ; ======================================================================
    ; pages (window.py _build_*)
    ; ======================================================================
    static Caption(text) => Label(_T(text), "caption", true)
    static Subtitle(text) => Label(_T(text), "subtitle", true)

    static BuildRun(root) {
        s := Store.settings
        row := HBox(, 6)
        MW.strategyTitle := row.Add(Label(_T("Choose a strategy"), "title", true), 1)
        MW.refreshBtn := row.Add(Button("↻", (*) => MW.RefreshSelectedLibrary()))
        MW.refreshBtn.fixedW := 32, MW.refreshBtn.tip := "Refresh the strategy library after editing files"
        root.Add(row)
        MW.strategyMeta := root.Add(MetaStrip())
        c := root.Add(Card("REQUIRED LOADOUT"))
        c.spacing := 9, c.margins[4] := 10
        c.Add(MW.Caption("Tower slots, in the order saved by this strategy"))
        MW.strategyLoadout := c.Add(Label("", "subtitle", true))
        MW.slotsCard := root.Add(Card("STRATEGY SLOTS"))
        MW.slotsCard.visible := s["rotation"]
        MW.slotNames := [], MW.slotLoadouts := [], MW.slotButtons := []
        Loop 2 {
            i := A_Index
            r := HBox(, 6)
            r.align := "top"
            r.Add(Label(_T("Strategy " i), "subtitle"))
            details := VBox(, 4)
            MW.slotNames.Push(details.Add(Label(_T("Not set"), "subtitle", true)))
            MW.slotLoadouts.Push(details.Add(Label("", "caption", true)))
            r.Add(details, 1)
            MW.slotButtons.Push(r.Add(Button(_T("Use selected"), ObjBindMethod(MW, "UseSlot", i))))
            MW.slotsCard.Add(r)
        }
        opts := root.Add(Card("RUN OPTIONS", true))
        MW.rotate := opts.Add(Toggle(_T("Alternate between strategy 1 and 2"), s["rotation"], (*) => MW.SaveRunSettings()))
        MW.equip := opts.Add(Toggle(_T("Auto equip towers", "Auto Equip Towers"), s["autoEquip"], (*) => MW.SaveRunSettings()))
        MW.repeat := opts.Add(Toggle(_T("Repeat after verified match results"), s["repeat"], (*) => MW.SaveRunSettings()))
        interval := HBox(, 6)
        interval.Add(Label(_T("Switch after"), "subtitle"), 1)
        MW.rotationAmount := interval.Add(Spin(s["rotationAmount"], 1, 999, "", (*) => MW.SaveRunSettings()))
        MW.rotationAmount.fixedW := 96
        MW.rotationUnit := interval.Add(Select(["Runs", "Minutes"], s["rotationUnit"] = "Minutes" ? 2 : 1, (*) => MW.SaveRunSettings()))
        MW.rotationInterval := opts.Add(interval)
        MW.rotationInterval.visible := s["rotation"]
        MW.readyCard := root.Add(Card("BEFORE YOU START", true))
        MW.readyMessage := MW.readyCard.Add(Label("", "subtitle", true))
        root.Add(MW.Caption("F1  start in Roblox     F2  stop     F8  emergency stop, anywhere"))
    }

    static BuildRecord(root) {
        root.Add(Label(_T("Record a strategy"), "title"))
        root.Add(MW.Subtitle("Start in the lobby. Join your map, then align the camera. F8 keeps the draft."))
        c := root.Add(Card("MATCH"))
        MW.recordStatus := c.Add(Label(_T("No recording active."), "subtitle", true))
        maps := SortStrings(Engine.MAPS.Clone())
        MW.recordMap := EditableSelect(maps, 1, (*) => MW.UpdateControls())
        MW.recordMap.ChooseValue("Dead Ahead")
        MW.recordMode := Select(Engine.MODES, 1, (*) => MW.UpdateControls())
        matchRow := HBox(, 6)
        for pair in [["Map", MW.recordMap], ["Mode", MW.recordMode]] {
            col := VBox(, 5)
            col.Add(Label(_T(pair[1]), "caption"))
            pair[2].fixedW := 120
            col.Add(pair[2])
            matchRow.Add(col, 1)
        }
        c.Add(matchRow)
        c.Add(Label(_T("Equipped towers, in hotbar order"), "subtitle"))
        MW.recordTowers := c.Add(Field("", "Scout, Farm, DJ Booth", {maxLength: 255, onChange: (*) => MW.UpdateControls()}))
        MW.recordGuidance := c.Add(Label("", "caption", true))
        MW.recordPassiveInputs := c.Add(Check(_T("Record as you play"), false, (*) => MW.SetPassiveInputs()))
        MW.recordPassiveInputs.tip := "After aligning, records mouse buttons, camera drags, scrolling and supported game keys inside the selected Roblox window. No action hotkeys are needed. Close chat first. Other windows are not recorded; unsupported keys or changed window size stop capture. This records physical inputs, not proof that the game accepted a purchase or ability."
        MW.recordPassiveUpgrades := c.Add(Check(_T("Record upgrade clicks"), false))
        MW.recordPassiveUpgrades.tip := "Observe supported upgrades after a recorded placement or selection. Placements, branch choices and other actions still use recording controls. Unconfirmed actions leave an incomplete draft."
        MW.recordPassiveSales := c.Add(Check(_T("Record sell clicks"), false))
        MW.recordPassiveSales.tip := "Observe Sell-button clicks after a recorded placement or selection. Other actions still use recording controls."
        MW.recordStart := c.Add(Button(_T("Start recording"), (*) => MW.StartRecording(), "accent"))
        draft := VBox(, 8, [0, 4, 0, 0])
        draft.Add(Label(_T("Save as"), "caption"))
        MW.recordName := draft.Add(Field("MyStrategy", "", {maxLength: 64}))
        btns := HBox(, 6)
        MW.recordSave := btns.Add(Button(_T("Stop and save"), (*) => MW.SaveRecording()), 1)
        MW.recordDiscard := btns.Add(Button(_T("Discard recording"), (*) => MW.DiscardRecording()), 1)
        draft.Add(btns)
        MW.recordEdit := draft.Add(Button(_T("Edit recorded towers"), (*) => MW.LoadRecordedTowers()))
        edit := VBox(, 6)
        MW.recordTowerSelect := edit.Add(Select([], 1))
        MW.recordTowerNote := edit.Add(Label("", "caption", true))
        MW.recordRemove := edit.Add(Button(_T("Preview removal"), (*) => MW.PreviewTowerRemoval()))
        MW.recordEditArea := draft.Add(edit)
        MW.recordEditArea.visible := false
        MW.recordDraftPanel := c.Add(draft)

        adv := Button(_T("Match options"), (*) => MW.advanced.Show(MW.advancedButton.checked))
        adv.checkable := true
        MW.advancedButton := root.Add(adv)
        MW.advanced := root.Add(Card())
        MW.advanced.visible := false
        MW.recordModifiers := Map()
        for name in SortStrings(Strategy.LEGACY_MODIFIERS.Clone()) {
            if (name = "Fog")
                continue
            MW.recordModifiers[name] := MW.advanced.Add(Check(name, false, (*) => MW.UpdateControls()))
        }
        MW.recordFlags := Map()
        for pair in [["auto_chain", "Call of Arms"], ["auto_caravan", "Support Caravan"], ["auto_beat", "Drop the Beat"]
            , ["auto_skip", "Auto skip waves"], ["ability_spam", "Ability spam"]]
            MW.recordFlags[pair[1]] := MW.advanced.Add(Check(_T(pair[2]), false))

        MW.recordActions := root.Add(Card("RECORDING CONTROLS"))
        MW.recordActions.Add(Label(_T("Placement slot · Ctrl+1–5"), "subtitle"))
        MW.recordSlot := MW.recordActions.Add(Select(["1", "2", "3", "4", "5"], 1, (sel, i) => Engine.RecordSlot(i)))
        MW.alignButton := MW.recordActions.Add(Button("", (*) => MW.RecordAction("align")))
        MW.recordHelp := MW.recordActions.Add(Label("", "caption", true))
        MW.strategyAction := MW.recordActions.Add(Field("", "One strategy instruction", {maxLength: 512}))
        MW.actionButton := MW.recordActions.Add(Button(_T("Run and record action"), (*) => MW.RecordAction("instruction")))
        MW.RefreshRecordHelp()

        f := Store.recordForm
        if IsObject(f) {
            MW.recordMap.ChooseValue(f["map"])
            MW.recordMode.ChooseValue(f["mode"])
            MW.recordTowers.Text := f["towers"]
            MW.recordName.Text := f["name"]
            MW.recordSlot.ChooseValue(f["slot"])
            MW.strategyAction.Text := f["action"]
            for k, v in f["flags"]
                MW.recordFlags[k].SetChecked(v)
            MW.recordPassiveUpgrades.SetChecked(f["passiveUpgrades"])
            MW.recordPassiveSales.SetChecked(f["passiveSales"])
            MW.recordPassiveInputs.SetChecked(f["passiveInputs"])
            for m in f["modifiers"]
                if MW.recordModifiers.Has(m)
                    MW.recordModifiers[m].SetChecked(true)
        }
    }

    static SetPassiveInputs() {
        if MW.recordPassiveInputs.checked {
            MW.recordPassiveUpgrades.SetChecked(false)
            MW.recordPassiveSales.SetChecked(false)
            for k, c in MW.recordFlags
                c.SetChecked(false)
        }
        MW.UpdateControls()
    }

    static RecordFormSnapshot() {
        flags := Map()
        for k, c in MW.recordFlags
            flags[k] := c.checked
        mods := []
        for k, c in MW.recordModifiers
            if c.checked
                mods.Push(k)
        return Map("schema", 1, "map", MW.recordMap.Text, "mode", MW.recordMode.Text, "towers", MW.recordTowers.Text
            , "name", MW.recordName.Text, "slot", MW.recordSlot.Text, "action", MW.strategyAction.Text, "flags", flags
            , "passiveUpgrades", MW.recordPassiveUpgrades.checked, "passiveSales", MW.recordPassiveSales.checked
            , "passiveInputs", MW.recordPassiveInputs.checked, "modifiers", mods)
    }

    static BuildParty(root) {
        root.Add(Label(_T("Party"), "title"))
        c := root.Add(Card("NEXT RUN"))
        MW.partyEnabled := c.Add(Check(_T("Enable party"), false))
        c.Add(Label(_T("Host"), "caption"))
        MW.partyHost := c.Add(Field("", "Host Roblox username", {maxLength: 20}))
        c.Add(Label(_T("Members"), "caption"))
        MW.partyMembers := c.Add(Field("", "1–3 other usernames, separated by commas", {maxLength: 64}))
        c.Add(Label(_T("Your role"), "caption"))
        MW.partyRole := c.Add(Select(["Host", "Member"], 1))
        c.Add(Label(_T("Leave when missing"), "caption"))
        MW.partyLeave := c.Add(Select(["Any", "All"], 1))
        c.Add(MW.Caption("Use Roblox usernames. These session-only options apply when you press Start."))
    }

    ; party.PartyConfig validation
    static PartyProfile() {
        if !MW.partyEnabled.checked
            return ""
        name := (v) => RegExMatch(v, "^[A-Za-z0-9_]{3,20}$")
        host := Trim(MW.partyHost.Text)
        members := []
        for m in StrSplit(MW.partyMembers.Text, ",")
            members.Push(Trim(m))
        if (!name(host) || members.Length < 1 || members.Length > 3)
            throw ValueError("A party needs a host and one to three additional members")
        seen := Map()
        seen.CaseSense := false
        seen[host] := 1
        for m in members {
            if (!name(m) || seen.Has(m))
                throw ValueError("Party usernames must be unique Roblox usernames")
            seen[m] := 1
        }
        return {role: StrLower(MW.partyRole.Text), host: host, members: members, leave: StrLower(MW.partyLeave.Text)}
    }

    static BuildDiscord(root) {
        root.Add(Label(_T("Discord"), "title"))
        o := root.Add(VBox(, 8, [9, 4, 9, 4]))
        o.Add(Label(_T("OFFICIAL ULTBOT REMOTE")))
        o.Add(Label(_T("Run /remote link in Discord, then paste its one-use code. The link lasts until this app closes. Commands affect only your linked PC. Staff commands remain restricted by Discord roles."), "", true))
        MW.officialCode := o.Add(Field("", "Connection code from /remote link", {password: true, maxLength: 1024}))
        MW.officialConsent := o.Add(Check(_T("Allow remote control and sharing for this session")))
        o.Add(Label(_T("Your linked Discord account can check status, start the selected strategy (which may focus Roblox), stop it, and request Roblox-only screenshots. This also shares new coins, gems, XP, match totals and active macro time with UltBot for the server economy view. Disconnect to stop sharing."), "", true))
        MW.officialLinkBtn := o.Add(Button(_T("Link this PC"), (*) => MW.OfficialLink()))
        MW.officialDisconnect := o.Add(Button(_T("Disconnect"), (*) => MW.OfficialShutdown()))
        MW.officialDisconnect.Enable(false)
        MW.officialStatus := o.Add(Label(_T("Not linked."), "", true))
        MW.officialGeneration := 0

        c := root.Add(Card("WEBHOOK NOTIFICATIONS"))
        c.Add(MW.Caption("Optional run and match notifications. No screenshots or strategy text are sent. The webhook is kept only until you close the app."))
        MW.webhookUrl := c.Add(Field("", "Discord webhook URL", {password: true, maxLength: 512}))
        MW.webhookConnect := c.Add(Button(_T("Enable notifications"), (*) => MW.EnableWebhook()))
        MW.webhookTest := c.Add(Button(_T("Send test notification"), (*) => MW.TestWebhook()))
        MW.webhookTest.Enable(false)
        MW.webhookDisable := c.Add(Button(_T("Disable notifications"), (*) => MW.DisableWebhook()))
        MW.webhookDisable.Enable(false)
        MW.webhookStatus := c.Add(MW.Caption("Notifications are off."))
        Webhook.onResult := (event, ok) => MW.webhookDisable.enabled ? MW.webhookStatus.SetText(_T(ok ? "Notification sent." : "Notification could not be delivered.")) : 0

        r := root.Add(Card("PERSONAL BOT REMOTE"))
        r.Add(MW.Caption("Use your own bot in a private channel. Only your user ID can use !stop or !status. Replies share app state and completed match count with that channel."))
        r.Add(MW.Caption("Your bot token is sent only to Discord and kept for this session. Start and Roblox-only screenshots require the extra permissions below."))
        MW.remoteAllowStart := r.Add(Check(_T("Allow !start for my selected strategy (may focus Roblox)")))
        MW.remoteAllowShot := r.Add(Check(_T("Allow !screenshot of the Roblox client only")))
        MW.remoteToken := r.Add(Field("", "Personal bot token — not the ULT Bot token", {password: true, maxLength: 256}))
        MW.remoteOwner := r.Add(Field("", "Your Discord user ID", {maxLength: 20}))
        MW.remoteChannel := r.Add(Field("", "Private text channel ID", {maxLength: 20}))
        r.Add(MW.Caption("Bot setup: enable Message Content Intent and grant View Channel, Read Message History and Send Messages. Existing commands are ignored when connecting."))
        MW.remoteConnect := r.Add(Button(_T("Enable remote control"), (*) => MW.EnableRemote()))
        MW.remoteDisable := r.Add(Button(_T("Disable remote control"), (*) => MW.DisableRemote()))
        MW.remoteDisable.Enable(false)
        MW.remoteStatus := r.Add(MW.Caption("Remote control is off."))
        BotRemote.onCommand := (op) => MW.HandleRemote("bot", op)
        BotRemote.onState := (gen, state) => MW.RemoteState(gen, state)
        OfficialRemote.onCommand := (op) => MW.HandleRemote("official", op)
        OfficialRemote.onState := (gen, state) => MW.OfficialState(gen, state)
    }

    static BuildTools(root) {
        root.Add(Label(_T("Tools"), "title"))
        c := root.Add(Card())
        c.Add(Button(_T("Open Roblox"), (*) => MW.LaunchRoblox()))
        c.Add(Button(_T("Check engine"), (*) => MW.CheckEngine(false)))
        MW.crateButton := c.Add(Button(_T("Open consumable crates"), (*) => MW.OpenCrateTool()))
        c.Add(MW.Caption("Opens the original crate utility. It is not in-match item use. Start it manually from its window."))
        c.Add(Button(_T("Open strategy folder"), (*) => MW.OpenStrategyFolder()))
    }

    static BuildSettings(root) {
        s := Store.settings
        root.Add(Label(_T("Settings"), "title"))
        c := root.Add(Card("SEASONAL THEME"))
        MW.christmas := c.Add(Toggle(_T("Christmas theme"), s["halloween"], (t, v) => MW.SetChristmas(v)))
        c.Add(MW.Caption("Cranberry accents, pine-green panels and festive bells."))

        u := root.Add(Card("VERSION & UPDATES"))
        u.Add(Label(_T("Installed build: ") App.VERSION, "subtitle"))
        MW.updateStatus := u.Add(MW.Caption(s["updatePrompts"] ? "Waiting for startup checks." : "Automatic update checks are off."))
        MW.updateButton := u.Add(Button(_T("Check for updates"), (*) => MW.CheckUpdates()))
        MW.updatePopups := u.Add(Check("Check and download on launch", s["updatePrompts"], (c, v) => MW.SetBackgroundUpdates(v)))
        MW.updatePopups.tip := "Downloads run in the background. Installation always asks first."
        u.Add(MW.Caption("Installation keeps your current folder and never restarts the app automatically."))
        u.Add(Button("Open update folder", (*) => MW.OpenUpdateFolder()))

        l := root.Add(Card("LANGUAGE"))
        MW.language := l.Add(Select())
        for item in Locale.Available()
            MW.language.AddItem(item.name " (" item.code ")", item.code)
        MW.language.ChooseValue(Locale.active) || MW.language.Choose(1)
        MW.language.callback := (*) => MW.SaveLanguage()
        l.Add(MW.Caption("Community translations. Missing text stays in English. Changes apply next time you open Ultimate Macro."))
        MW.languageRestart := l.Add(Label("", "caption", true))
        MW.languageRestart.visible := false

        w := root.Add(Card("WINDOW"))
        a := root.Add(Card("Appearance"))
        MW.themeBackground := a.Add(Check(_T("Theme background"), s["themeBackground"], (*) => MW.SaveWindowAppearance()))
        MW.themeBackground.tip := "Use the bundled mountain background. No image downloads or background animation."
        op := HBox(, 6)
        op.Add(Label(_T("Window opacity"), "subtitle"), 1)
        MW.opacity := op.Add(Spin(s["windowOpacity"], 90, 100, "%", (*) => MW.SaveWindowAppearance()))
        MW.opacity.fixedW := 96, MW.opacity.tip := "100% is fully opaque. Transparency never makes the app click-through."
        a.Add(op)
        MW.startupSound := a.Add(Toggle(_T("Startup sound"), s["halloweenSounds"], (t, v) => (Store.settings["halloweenSounds"] := v, MW.Persist())))
        MW.topmost := w.Add(Toggle(_T("Always on top"), s["topmost"], (t, v) => MW.SetTopmost(v)))
        MW.dockRoblox := w.Add(Toggle(_T("Dock Roblox beside the macro"), s["dockRoblox"], (t, v) => MW.SetDocked(v)))
        MW.dockRoblox.tip := "Arrange windowed Roblox while idle, including on next launch when enabled. Original bounds are restored when undocking."
        MW.dockApply := w.Add(Button(_T("Arrange windows"), (*) => MW.SetDocked(true)))
        MW.dockApply.tip := "Retry the saved layout while idle. Fullscreen Roblox must first be restored to windowed mode."
        MW.reduceMotion := w.Add(Toggle(_T("Reduce animations"), !s["motion"], (t, v) => (Store.settings["motion"] := !v, MW.Persist())))

        gp := root.Add(Card("GAMEPLAY"))
        tr := HBox(, 6)
        tr.Add(Label(_T("Timescale"), "subtitle"), 1)
        MW.timescale := tr.Add(Select(["OFF", "1.5x", "2x"], 1, (*) => MW.SaveTimescale()))
        MW.timescale.ChooseValue(s["timeScaleMode"])
        gp.Add(tr)
        gp.Add(MW.Caption("Applies when playback starts, not during a run. Availability depends on the game, mode and any required access or owned tickets. Selecting a speed does not purchase tickets."))

        more := Button(_T("Advanced settings"), (*) => MW.moreFrame.Show(MW.moreButton.checked))
        more.checkable := true
        MW.moreButton := root.Add(more)
        MW.moreFrame := root.Add(VBox(, 12))
        MW.moreFrame.visible := false
        t := MW.moreFrame.Add(Card("Gameplay tuning"))
        lo := s["legacyOptions"]
        MW.modeScroll := t.Add(Check(_T("Scroll mode list before selection"), lo["scrollModeList"], (*) => MW.SaveLegacyOptions()))
        MW.modeScrollCount := Spin(lo["scrollAmount"], 5, 20, "", (*) => MW.SaveLegacyOptions())
        MW.modeScrollDelay := Spin(lo["scrollDelayMs"], 0, 5000, " ms", (*) => MW.SaveLegacyOptions())
        for pair in [["Scroll notches", MW.modeScrollCount], ["Wait before scrolling", MW.modeScrollDelay]] {
            r := HBox(, 6)
            r.Add(Label(_T(pair[1]), "subtitle"), 1)
            pair[2].fixedW := 110
            r.Add(pair[2])
            t.Add(r)
        }
        MW.runtimeInputs := Map()
        for pair in [["cancelKey", "Cancel placement"], ["raiseDeadKey", "Raise the Dead"], ["chainKey", "Call of Arms"], ["caravanKey", "Support Caravan"]
            , ["beatKey", "Drop the Beat"], ["hologramKey", "Hologram"], ["repositionKey", "Reposition"], ["enforcerVanKey", "SWAT Van"]] {
            r := HBox(, 6)
            r.Add(Label(_T(pair[2]), "subtitle"), 1)
            f := Field(s["runtime"][pair[1]], "", {maxLength: 1, fixedW: 70, onCommit: (*) => MW.SaveRuntime()})
            MW.runtimeInputs[pair[1]] := r.Add(f)
            t.Add(r)
        }
        MW.runtimeInputs["enforcerVanKey"].SetReadOnly(true)
        MW.runtimeInputs["enforcerVanKey"].tip := "The AutoHotkey engine uses the game's own SWAT Van control; this key is not sent."
        t.Add(Label(_T("Upgrade delay", "Upgrade Delay") " (ms)", "subtitle"))
        MW.upgradeDelay := t.Add(Spin(s["runtime"]["upgradeDelayMs"], 20, 999, "", (*) => MW.SaveRuntime()))
        rc := MW.moreFrame.Add(Card("RECORDING SHORTCUTS"))
        MW.bindingInputs := Map()
        for action in Store.BINDING_ORDER {
            r := HBox(, 6)
            r.Add(Label(_T(Store.BINDING_TITLES[action]), "subtitle"), 1)
            MW.bindingInputs[action] := r.Add(Field(s["recordBindings"][action], "", {maxLength: 40, fixedW: 150}))
            rc.Add(r)
        }
        rc.Add(MW.Caption("Example: F, Ctrl+U or Shift+F3. Active only in Roblox."))
        rc.Add(Button(_T("Apply shortcuts"), (*) => MW.SaveRecordBindings()))
        MW.moreFrame.Add(Button(_T("Import older settings"), (*) => MW.ImportOlderSettings()))
        MW.moreFrame.Add(Button(_T("Export logic source"), (*) => MW.ExportLogic()))
        MW.moreFrame.Add(Button(_T("Third-party notices"), (*) => MW.OpenNotices()))
        MW.moreFrame.Add(Button(_T("Terms & conditions ↗"), (*) => Run(FirstUse.TERMS_URL)))
        MW.moreFrame.Add(Button(_T("Privacy policy ↗"), (*) => Run(FirstUse.PRIVACY_URL)))
    }

    ; ======================================================================
    ; window geometry
    ; ======================================================================
    static OnSize(minmax, w, h) {
        if (minmax = -1)
            return
        MW.compact := (w / Gfx.S) < 740
        MW.ultra := (w / Gfx.S) < 480
        MW.ApplyResponsive()
        MW.surface.Resize(w, h)
        MW.PlacePages()
        MW.maxBtn.icon := (minmax = 1) ? "restore" : "max"
    }

    static ApplyResponsive() {
        boot := MW.booting, compact := MW.compact
        ultra := MW.ultra
        for i, t in MW.tabs
            t.visible := !compact && !boot
        MW.compactNav.visible := compact && !ultra && !boot
        MW.ultraNav.visible := ultra && !boot
        MW.compactStrategies.visible := compact && !boot
        MW.sidebar.visible := !compact && !boot
        MW.headerTitle.visible := boot
        MW.startBtn.visible := !boot, MW.stopBtn.visible := !boot
        MW.startBtn.text := compact ? "" : _T("Start")
        MW.stopBtn.text := compact ? "" : _T("Stop")
        MW.outputBar.visible := !boot
    }

    static OutputHeight() {
        lh := MW.surface ? MW.surface.lh : 560
        return lh < 480 ? Min(130, Max(40, Floor((lh - 100) / 4))) : 130
    }

    static PlacePages() {
        if (!MW.layout || !MW.pages.Length)
            return
        MW.surface.Relayout()
        r := MW.layout.pageRect, s := Gfx.S
        x := Round(r[1] * s), y := Round(r[2] * s), w := Max(1, Round(r[3] * s)), h := Max(1, Round(r[4] * s))
        for i, p in MW.pages {
            if (i = MW.page && !MW.booting) {
                p.surface.offX := x, p.surface.offY := y
                DllCall("SetWindowPos", "Ptr", p.gui.Hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", 0x14)
                p.surface.Resize(w, h)
                if !p.shown {
                    p.gui.Show("NA x" x " y" y " w" w " h" h)
                    p.shown := true
                }
            } else if p.shown {
                p.gui.Hide()
                p.shown := false
            }
        }
        o := MW.layout.outputRect
        if MW.outputVisible && !MW.booting {
            MW.outputEdit.Move(Round(14 * s), Round((o[2] + 6) * s), Round((o[3] - 20) * s), Round((o[4] - 10) * s))
            if !MW.outputEdit.Visible {
                MW.outputEdit.Visible := true
                MW.ScrollOutputToEnd()
            }
        } else
            MW.outputEdit.Visible := false
    }

    static ToggleMaximize() {
        if (WinGetMinMax(MW.gui) = 1)
            MW.gui.Restore()
        else
            MW.gui.Maximize()
    }

    static ShowWorkspace() {
        MW.booting := false
        MW.ApplyResponsive()
        MW.PlacePages()
        MW.UpdateControls()
        SetTimer(() => MW.ApplySavedDocking(), -400)
    }

    static SelectPage(index, *) {
        changed := MW.page != index
        if changed
            MW.SetKeyboardFocus("")
        MW.page := index
        for i, t in MW.tabs
            t.SetChecked(i = index)
        for i, p in MW.NAV_PAGES
            if (p = index) {
                MW.compactNav.Choose(i)
                MW.ultraNav.Choose(i)
            }
        MW.PlacePages()
        MW.UpdateControls()
        if (changed && !MW.booting)
            MW.FadePage()
    }

    static TabOrder() {
        items := []
        if MW.booting || MW.closing || !MW.page
            return items
        for widget in [MW.header, MW.ultraNav, MW.compactStrategies, MW.sidebar, MW.pages[MW.page].root, MW.outputBar]
            widget.CollectFocus(items)
        return items
    }

    static SetKeyboardFocus(widget) {
        if MW.keyboardFocus
            MW.keyboardFocus.Invalidate()
        MW.keyboardFocus := widget
        if !widget
            return
        widget.surface.EnsureVisible(widget)
        if widget is Field
            widget.Focus()
        else
            DllCall("SetFocus", "Ptr", widget.surface.hwnd)
        widget.Invalidate()
    }

    static KeyboardKey(key, hwnd) {
        if MW.booting || MW.closing || !MW.page
            return false
        page := MW.pages[MW.page].gui.Hwnd, main := MW.gui.Hwnd
        if (hwnd != main && hwnd != page && !DllCall("IsChild", "Ptr", main, "Ptr", hwnd))
            return false
        order := MW.TabOrder(), index := 0
        for i, widget in order
            if ((widget is Field && widget.ctrl && widget.ctrl.Hwnd = hwnd)
                || (!(widget is Field) && widget == MW.keyboardFocus && widget.surface.hwnd = hwnd)) {
                index := i
                break
            }
        if (key = 9 && order.Length) {
            previous := GetKeyState("Shift", "P")
            next := previous ? (index <= 1 ? order.Length : index-1) : (index >= order.Length ? 1 : index+1)
            MW.SetKeyboardFocus(order[next])
            return true
        }
        if !index
            return false
        widget := order[index]
        if (widget is Field) {
            if (key = 40 && widget.parent is EditableSelect && GetKeyState("Alt","P")) {
                SelectPopup.Open(widget.parent)
                return true
            }
            return false
        }
        if (widget is StrategyList && (key = 38 || key = 40)) {
            next := Min(widget.rows.Length,Max(1,widget.index + (key=38 ? -1 : 1)))
            if next
                widget.onSelect.Call(next)
            return true
        }
        if (!(widget is StrategyList) && (key = 13 || key = 32 || (widget is Select && key = 40))) {
            widget.OnClick(widget.x + widget.w/2, widget.y + widget.h/2)
            return true
        }
        return false
    }

    static FadePage() {
        if MW.pageFade
            SetTimer(MW.pageFade, 0)
        MW.pageFade := "", MW.pageShade := 0
        if !Store.settings["motion"]
            return
        started := A_TickCount
        step() {
            t := Min(1, (A_TickCount - started) / 90)
            MW.pageShade := Store.settings["motion"] ? Round(38 * (1 - t)**3) : 0
            MW.pages[MW.page].surface.Invalidate()
            if (!MW.pageShade || t >= 1) {
                SetTimer(step, 0)
                MW.pageFade := ""
            }
        }
        MW.pageFade := step
        step()
        if MW.pageFade
            SetTimer(step, 15)
    }

    ; ======================================================================
    ; theme / appearance
    ; ======================================================================
    static ApplyTheme() {
        Theme.christmas := Store.settings["halloween"]
        MW.gui.BackColor := Theme.Hex("base")
        for p in MW.pages
            p.gui.BackColor := Theme.Hex("base")
        for sf in [MW.surface, MW.pages*]
            for n in (sf is Surface ? sf.natives : sf.surface.natives)
                n.Rethemed()
        MW.outputEdit.Opt("Background" Theme.Hex("panel"))
        MW.outputEdit.SetFont("c" Theme.Hex("muted"))
        MW.surface.Invalidate()
        for p in MW.pages
            p.surface.Invalidate()
        DllCall("InvalidateRect", "Ptr", MW.gui.Hwnd, "Ptr", 0, "Int", 1)
    }

    static ApplyOpacity() {
        op := Store.settings["windowOpacity"]
        WinSetTransparent(op >= 100 ? "Off" : Round(op * 2.55), MW.gui)
    }

    static SetChristmas(v) {
        Store.settings["halloween"] := v
        MW.ApplyTheme()
        MW.Persist()
        if v
            MW.PlayStartupSound()
    }

    static PlayStartupSound() {
        if (MW.closing || !Store.settings["halloweenSounds"])
            return
        f := App.assets "\startup-sounds\" (Store.settings["halloween"] ? "christmas.wav" : "normal.wav")
        if (FileExist(f) && FileGetSize(f) <= 1024 * 1024)
            try SoundPlay(f)
    }

    static SaveWindowAppearance() {
        Store.settings["themeBackground"] := MW.themeBackground.checked
        Store.settings["windowOpacity"] := MW.opacity.Value
        MW.Persist()
        MW.ApplyOpacity()
        MW.surface.Invalidate()
        for p in MW.pages
            p.surface.Invalidate()
    }

    static SetTopmost(v) {
        if (MW.Active || MW.busy || MW.stopPending || MW.closing || Docking.active || MW.LaunchBusy()) {
            MW.topmost.SetChecked(Store.settings["topmost"])
            return
        }
        Store.settings["topmost"] := v
        MW.gui.Opt((v ? "+" : "-") "AlwaysOnTop")
        MW.Persist()
    }

    static SaveLanguage() {
        code := MW.language.Value
        Store.settings["language"] := code, Store.settings["languageChosen"] := true
        try {
            Store.Save()
            MW.languageRestart.SetText(_T("Language saved. Restart Ultimate Macro to apply."))
        } catch
            MW.languageRestart.SetText(_T("Could not save the language. Please try again."))
        MW.languageRestart.Show()
    }

    static CheckUpdates(manual := true) {
        if (MW.closing || (!manual && !Store.settings["updatePrompts"]))
            return
        if (MW.booting || MW.busy || MW.Active || MW.LaunchBusy() || Engine.Active || UpdateHelper.checking) {
            if manual
                MW.updateStatus.SetText("Stop the current task before checking for updates.")
            else
                UpdateHelper.Arm(60000)
            return
        }
        MW.updateReviewing := manual
        MW.updateButton.Enable(false)
        if manual
            MW.updateStatus.SetText("Checking the signed AHK update channel…")
        try {
            MW.UpdateControls()
            status := UpdateHelper.Check(manual)
        } finally {
            MW.updateReviewing := false
            MW.UpdateControls()
        }
        if (manual || Store.settings["updatePrompts"]) {
            MW.updateStatus.SetText(UpdateHelper.Message(status))
            MW.updateButton.SetText(status = 6 || status = 3 ? "Review update" : _T("Check for updates"))
        }
        if !manual
            UpdateHelper.Arm(status = 2 || status = 6 ? 21600000 : status = 5 ? 0 : 900000)
    }

    static SetBackgroundUpdates(enabled) {
        Store.settings["updatePrompts"] := enabled
        MW.Persist()
        if !enabled
            MW.updateStatus.SetText("Automatic update checks are off.")
        UpdateHelper.Arm(enabled ? 1000 : 0)
    }

    static OpenUpdateFolder() {
        path := Store.root "\VerifiedUpdates"
        if DirExist(path)
            Run('explorer.exe "' path '"')
        else
            MW.updateStatus.SetText("No verified updates have been downloaded yet.")
    }

    ; ======================================================================
    ; library
    ; ======================================================================
    static RefreshLibrary(reload := true, preserveMissing := false) {
        if (reload || !MW.items.Length)
            MW.items := Store.Library()
        if Store.skipped.Length {
            shown := ""
            for i, n in Store.skipped {
                if (i > 5)
                    break
                shown .= (i > 1 ? ", " : "") n
            }
            if (Store.skipped.Length > 5)
                shown .= " and " (Store.skipped.Length - 5) " more"
            MW.Log("Not shown in the library (unreadable or invalid): " shown)
        }
        MW.loadoutCache := Map(), MW.reasonCache := Map()
        MW.FilterLibrary(preserveMissing)
    }

    static FilterLibrary(preserveMissing := false) {
        previous := IsObject(MW.current) ? MW.current.path : Store.settings["slot1"]
        term := StrLower(MW.search.Text)
        MW.visibleItems := []
        selected := 0
        labels := []
        for item in MW.items {
            if (term != "" && !InStr(StrLower(item.title " " item.map " " item.mode), term))
                continue
            MW.visibleItems.Push(item)
            labels.Push(item.title " · " item.map)
            if (item.path = previous)
                selected := MW.visibleItems.Length
        }
        if (!selected && MW.visibleItems.Length && (!preserveMissing || previous = ""))
            selected := 1
        MW.compactStrategies.SetItems(labels)
        MW.compactStrategies.Choose(selected)
        MW.ChooseVisible(selected, false)
    }

    static ChooseVisible(i, fromList := true) {
        MW.current := (i >= 1 && i <= MW.visibleItems.Length) ? MW.visibleItems[i] : ""
        if IsObject(MW.current) {
            MW.strategyTitle.SetText(MW.current.title)
            MW.strategyMeta.SetText(MW.current.map " · " MW.current.mode " · " MW.current.steps " steps")
            MW.strategyLoadout.SetText(MW.RequiredLoadout(MW.current))
        } else {
            MW.strategyTitle.SetText(_T("Choose a strategy"))
            MW.strategyMeta.SetText("")
            MW.strategyLoadout.SetText(_T("Choose a strategy to see its required towers."))
        }
        MW.compactStrategies.Choose(i)
        MW.RefreshSlots(i)
        MW.UpdateControls()
    }

    static RequiredLoadout(item) {
        if MW.loadoutCache.Has(item.path)
            return MW.loadoutCache[item.path]
        return MW.loadoutCache[item.path] := Strategy.RequiredLoadout(item)
    }

    static RefreshSlots(index := -1) {
        s := Store.settings
        Loop 2 {
            path := s["slot" A_Index], assigned := ""
            for it in MW.items
                if (it.path = path)
                    assigned := it
            MW.slotNames[A_Index].SetText(IsObject(assigned) ? assigned.title : _T("Not set"))
            MW.slotLoadouts[A_Index].SetText(IsObject(assigned) ? MW.RequiredLoadout(assigned) : _T("Not set"))
            MW.slotButtons[A_Index].SetText(_T(IsObject(MW.current) && MW.current.path = path ? "In slot" : "Use selected"))
        }
        rows := [], sel := 0
        for i, it in MW.visibleItems {
            slots := ""
            Loop 2
                if (s["slot" A_Index] = it.path)
                    slots .= (slots = "" ? "" : ", ") A_Index
            rows.Push({item: it, slots: slots})
            if (IsObject(MW.current) && it.path = MW.current.path)
                sel := i
        }
        MW.list.SetRows(rows, sel)
        if (index >= 0)
            MW.list.EnsureVisible(sel)
    }

    static RefreshSelectedLibrary() {
        if (MW.Active || MW.busy || MW.stopPending || MW.closing || MW.LaunchBusy())
            return
        had := IsObject(MW.current)
        MW.RefreshLibrary(true, true)
        MW.Log(had && !IsObject(MW.current) ? "The selected strategy is missing or invalid. Choose another strategy." : "Strategy library refreshed.")
    }

    static UseSlot(slot, *) {
        if !IsObject(MW.current)
            return
        Store.settings["slot" slot] := MW.current.path
        MW.Persist()
        MW.RefreshSlots()
        MW.UpdateControls()
    }

    static Reason(item) {
        key := item.path
        if MW.reasonCache.Has(key)
            return MW.reasonCache[key]
        reason := ""
        try Strategy.Requirement(item)
        catch as e
            reason := e.Message
        return MW.reasonCache[key] := reason
    }

    static ImportStrategy() {
        path := FileSelect(1, , _T("Add strategy file"), "Strategies (*.strat)")
        if (path = "")
            return
        try {
            target := Store.ImportStrategy(path)
            MW.RefreshLibrary()
            SplitPath(target, , , , &stem)
            MW.Log("Strategy added as " stem ".")
        } catch
            MW.Log("Strategy not added. Check that it is a valid .strat file.")
    }

    static OpenStrategyFolder() {
        DirCreate(Store.strategies)
        Run('explorer.exe "' Store.strategies '"')
    }

    ; ======================================================================
    ; settings persistence
    ; ======================================================================
    static Persist() {
        try Store.Save()
        catch
            MW.Log("Settings were not saved. Check the application folder.")
    }

    static RunSettingsEditable() => MW.engineReady && !MW.booting && !MW.Active && !MW.busy && !MW.closing
    static ResizeEditable() => MW.RunSettingsEditable() && !MW.stopPending && !MW.stopFailed && !Docking.restoring && !MW.LaunchBusy()
        && !MW.stopPending && !MW.stopFailed && !MW.LaunchBusy()

    static SaveRunSettings() {
        s := Store.settings
        if !MW.RunSettingsEditable() {
            MW.rotate.SetChecked(s["rotation"]), MW.equip.SetChecked(s["autoEquip"]), MW.repeat.SetChecked(s["repeat"])
            MW.rotationAmount.Value := s["rotationAmount"]
            MW.rotationUnit.ChooseValue(s["rotationUnit"])
            MW.rotationInterval.Show(s["rotation"]), MW.slotsCard.Show(s["rotation"])
            MW.UpdateControls()
            return
        }
        rotation := MW.rotate.checked, was := s["rotation"]
        if (rotation && !was)
            MW.repeatBeforeRotation := MW.repeat.checked
        else if (!rotation && was) {
            if (MW.repeatBeforeRotation != "")
                MW.repeat.SetChecked(MW.repeatBeforeRotation)
            MW.repeatBeforeRotation := ""
        }
        if rotation {
            MW.equip.SetChecked(true)
            MW.repeat.SetChecked(true)
        }
        s["rotation"] := rotation, s["autoEquip"] := MW.equip.checked, s["repeat"] := MW.repeat.checked
        s["rotationAmount"] := MW.rotationAmount.Value, s["rotationUnit"] := MW.rotationUnit.Text
        MW.rotationInterval.Show(rotation)
        MW.slotsCard.Show(rotation)
        MW.Persist()
        MW.UpdateControls()
    }

    static SaveTimescale() {
        prev := Store.settings["timeScaleMode"]
        if !MW.RunSettingsEditable() {
            MW.timescale.ChooseValue(prev)
            MW.Log("Timescale was not changed. Stop the macro and finish pending actions before changing it; check the settings folder if saving fails.")
            return
        }
        Store.settings["timeScaleMode"] := MW.timescale.Value
        MW.Persist()
    }

    static SaveLegacyOptions() {
        Store.settings["legacyOptions"] := Map("scrollModeList", MW.modeScroll.checked, "scrollAmount", MW.modeScrollCount.Value
            , "scrollDelayMs", MW.modeScrollDelay.Value)
        MW.Persist()
    }

    static SaveRuntime() {
        v := Map()
        for k, f in MW.runtimeInputs
            v[k] := StrUpper(f.Text)
        v["upgradeDelayMs"] := MW.upgradeDelay.Value
        try {
            v := Store.ValidRuntime(v)
            Store.ValidBindings(Store.settings["recordBindings"], v)
            Store.settings["runtime"] := v
            MW.Persist()
        } catch
            MW.Log("Use a different single letter or digit for each gameplay key, not used by a recording shortcut.")
    }

    static SaveRecordBindings() {
        if (MW.Active || MW.busy || MW.stopPending || MW.closing) {
            MW.Log("Stop the macro before changing recording shortcuts.")
            return
        }
        v := Map()
        for k, f in MW.bindingInputs
            v[k] := f.Text
        try {
            v := Store.ValidBindings(v, Store.settings["runtime"])
            prev := Store.settings["recordBindings"]
            Store.settings["recordBindings"] := v
            try Store.Save()
            catch as e {
                Store.settings["recordBindings"] := prev
                throw e
            }
        } catch {
            MW.Log("Shortcuts were not saved. Use distinct keys; F1, F2, F8, Ctrl+1–5, Ctrl+B, Ctrl+Shift+E and gameplay keys are reserved.")
            return
        }
        for k, t in v
            MW.bindingInputs[k].Text := t
        MW.RefreshRecordHelp()
        Hotkeys.Rebind()
        MW.Log("Recording shortcuts saved.")
    }

    static RefreshRecordHelp() {
        b := Store.settings["recordBindings"]
        MW.alignButton.SetText(_T("Align camera") " · " b["align"])
        help := ""
        for action in Store.BINDING_ORDER
            if (action != "align")
                help .= (help = "" ? "" : " · ") b[action] " " StrLower(_T(Store.BINDING_TITLES[action]))
        MW.recordHelp.SetText(help)
    }

    static ImportOlderSettings() {
        if (MW.Active || MW.busy || MW.stopPending || MW.closing || Docking.active) {
            MW.Log("Undock Roblox and stop the macro before importing settings.")
            return
        }
        path := FileSelect(1, , _T("Import older settings"), "Macro profiles (*.ump; *.json; *.tds)")
        if (path = "")
            return
        try result := LegacyProfile.Read(path, Store.settings)
        catch {
            MW.Log("Settings could not be imported. The original file was not changed.")
            return
        }
        if !result.imported {
            MW.Log("No supported settings were found. The original file was not changed.")
            return
        }
        if (Dialog.Ask(_T("Import older settings"), "Apply " result.imported " supported settings? " result.skipped " entries were skipped. "
            . "Delays below 20 ms are adjusted to 20 ms. Secrets and strategies are not imported. Your original file remains unchanged.", ["Yes", "No"], 2) != "Yes")
            return
        prev := Store.settings
        Store.settings := result.candidate
        try Store.Save()
        catch {
            Store.settings := prev
            MW.Log("Settings could not be saved. The original file was not changed.")
            return
        }
        c := result.candidate
        MW.topmost.SetChecked(c["topmost"]), MW.rotate.SetChecked(c["rotation"]), MW.equip.SetChecked(c["autoEquip"])
        MW.repeat.SetChecked(c["repeat"]), MW.rotationAmount.Value := c["rotationAmount"], MW.rotationUnit.ChooseValue(c["rotationUnit"])
        MW.upgradeDelay.Value := c["runtime"]["upgradeDelayMs"]
        for k, f in MW.runtimeInputs
            f.Text := c["runtime"][k]
        for k, f in MW.bindingInputs
            f.Text := c["recordBindings"][k]
        MW.RefreshRecordHelp()
        Hotkeys.Rebind()
        MW.rotationInterval.Show(c["rotation"]), MW.slotsCard.Show(c["rotation"])
        MW.gui.Opt((c["topmost"] ? "+" : "-") "AlwaysOnTop")
        MW.UpdateControls()
        MW.Log("Imported " result.imported " settings; skipped " result.skipped " unsupported entries.")
    }

    static ExportLogic() {
        path := FileSelect("S16", "UltimateMacro-" App.VERSION "-Logic.zip", _T("Export logic source"), "ZIP archive (*.zip)")
        if (path = "")
            return
        if !RegExMatch(path, "i)\.zip$")
            path .= ".zip"
        list := ""
        for item in ["Main.ahk", "app", "ui", "engine\UM14Engine.ahk", "engine\lib\*.ahk", "engine\submacros\*.ahk", "engine\ENGINE-NOTICE.md", "LICENSE", "README.md", "licenses"]
            list .= (list = "" ? "" : ",") "'" A_ScriptDir "\" item "'"
        ps := "Compress-Archive -Force -Path " list " -DestinationPath '" StrReplace(path, "'", "''") "'"
        try {
            RunWait('powershell.exe -NoProfile -NonInteractive -Command "' ps '"', , "Hide")
            if FileExist(path)
                MW.Log("Logic source exported. Component licences are included.")
            else
                throw Error()
        } catch
            MW.Log("Logic source was not exported. Check the selected folder.")
    }

    static OpenNotices() {
        if DirExist(A_ScriptDir "\licenses")
            Run('explorer.exe "' A_ScriptDir '\licenses"')
        else
            MW.Log("Dependency notices are not bundled in this copy.")
    }

    ; ======================================================================
    ; output
    ; ======================================================================
    static Log(message) {
        line := FormatTime(, "HH:mm:ss") "  " message
        ; Support aid: create debug.flag in the settings folder to mirror Output to debug.log.
        static debug := FileExist(Store.root "\debug.flag")
        if debug
            try FileAppend(line "`n", Store.root "\debug.log", "UTF-8")
        MW.outputLines.Push(line)
        while (MW.outputLines.Length > 200)
            MW.outputLines.RemoveAt(1)
        if MW.outputEdit {
            text := ""
            for i, l in MW.outputLines
                text .= (i > 1 ? "`r`n" : "") l
            MW.outputEdit.Value := text
            MW.ScrollOutputToEnd()
        }
        if MW.outputBtn
            MW.outputBtn.SetText(_T("Output") "   " SubStr(message, 1, 100))
    }

    ; Keep the newest line in view without scrolling past it (top, then caret).
    static ScrollOutputToEnd() {
        n := StrLen(MW.outputEdit.Value)
        SendMessage(0x115, 6, 0, MW.outputEdit)
        SendMessage(0xB1, n, n, MW.outputEdit)
        SendMessage(0xB7, 0, 0, MW.outputEdit)
    }

    static ToggleOutput() {
        MW.outputVisible := !MW.outputVisible
        MW.PlacePages()
    }

    static ExportOutput() {
        path := FileSelect("S16", "UltimateMacro-" App.VERSION "-Output.txt", _T("Export Output log"), "Text files (*.txt)")
        if (path = "")
            return
        text := "Ultimate Macro " App.VERSION " — Output`n`n"
        for l in MW.outputLines
            text .= l "`n"
        try {
            AtomicWrite(path, text)
            MW.Log("Output log exported. Review the text before sharing.")
        } catch
            MW.Log("Output log was not exported. Check the selected folder.")
    }

    ; ======================================================================
    ; state
    ; ======================================================================
    static Active => MW.run.active || MW.rec.active

    static LaunchBusy() => MW.launcherWaiting || GameRecovery.Busy || Docking.Busy || MW.updateReviewing

    static CheckEngine(startup := false) {
        missing := []
        for rel in ["UM14Engine.ahk", "submacros\AutoHotkey64.exe", "lib\UM14Bridge.ahk", "lib\ImageSearch\image_search.dll"
            , "lib\ImageSearch\opencv_world500.dll", "Resources\Play.png", "submacros\um14_guard.ahk"]
            if !FileExist(App.engine "\" rel)
                missing.Push(rel)
        if (InStr(A_ScriptDir, ".zip") || InStr(A_ScriptDir, "\Temp\") && InStr(A_ScriptDir, ".zip"))
            missing.Push("(running from inside a ZIP)")
        ok := !missing.Length
        if startup {
            MW.engineReady := ok
            if !ok {
                list := ""
                for m in missing
                    list .= (list = "" ? "" : ", ") m
                MW.Log("Engine files are missing: " list ". Extract the complete folder again.")
            }
            BootStage.Finish()
        } else {
            if ok {
                info := "Engine check passed: AutoHotkey " FileGetVersion(Engine.interpreter) ", build " Engine.BUILD ", " A_ScreenWidth "x" A_ScreenHeight " at " Round(A_ScreenDPI / 0.96) "% scaling."
                MW.Log(info)
                if (A_ScreenDPI != 96)
                    MW.Log("Windows scaling is not 100%. The engine expects 100% display scaling for reliable image search.")
                game := Roblox.Game()
                MW.Log(game ? "Roblox window found." : "No single Roblox window is open.")
            } else
                MW.Log("Engine check failed. Missing: " missing.Length " file(s). Extract the complete folder again.")
        }
        MW.UpdateControls()
    }

    static UpdateControls() {
        if (!MW.surface || !MW.pages.Length || !MW.HasOwnProp("readyMessage"))
            return
        idle := !MW.Active && !MW.busy && !MW.closing && !MW.stopPending
        enabled := idle && !MW.LaunchBusy() && MW.engineReady && !MW.booting
        s := Store.settings
        MW.timescale.Enable(MW.RunSettingsEditable())
        for c in [MW.partyEnabled, MW.partyHost, MW.partyMembers, MW.partyRole, MW.partyLeave]
            c.Enable(enabled)
        MW.crateButton.Enable(enabled && !MW.rec.draft)
        for k, c in MW.recordModifiers
            c.Enable(enabled && !MW.rec.draft)
        MW.refreshBtn.Enable(enabled)
        blocked := ""
        if s["rotation"] {
            Loop 2 {
                item := ""
                for it in MW.items
                    if (it.path = s["slot" A_Index])
                        item := it
                blocked := IsObject(item) ? MW.Reason(item) : _T("Choose both strategy slots for rotation.")
                if (blocked != "")
                    break
            }
        } else if IsObject(MW.current)
            blocked := MW.Reason(MW.current)
        MW.startBtn.Enable(enabled && IsObject(MW.current) && MW.page = 1 && blocked = "")
        MW.startBtn.tip := blocked != "" ? blocked : "Start the selected strategy; F1 in Roblox."
        MW.stopBtn.Enable((MW.Active || MW.busy || MW.stopPending || MW.launcherWaiting || Engine.ToolsRunning()) && !MW.closing)
        notes := ""
        if !MW.engineReady
            notes .= _T("The engine could not be prepared. Check Output, then reopen the app.") "`n"
        if !IsObject(MW.current)
            notes .= _T("Select a strategy from the library.") "`n"
        if (blocked != "")
            notes .= _T(blocked) "`n"
        if !Roblox.Game()
            notes .= _T("Start opens Roblox if needed. Wait for the TDS lobby, then press Start again.") "`n"
        MW.readyMessage.SetText(RTrim(notes, "`n"))
        MW.readyCard.Show(notes != "")

        r := MW.rec
        req := MW.RecordingRequirement()
        MW.recordGuidance.SetText(req != "" ? _T(req) : _T("Loadout valid. Check the map and mode below."))
        MW.recordStart.tip := req != "" ? req : "Start recording in the selected Roblox window."
        canStart := enabled && !r.draft && req = ""
        MW.recordStart.Enable(canStart)
        MW.recordStart.kind := canStart ? "accent" : ""
        MW.recordSave.Enable(!MW.closing && !MW.busy && (r.draft || r.active))
        MW.recordDiscard.Enable(!MW.closing && !MW.busy && !r.active && !MW.stopFailed && r.draft)
        editAllowed := !MW.closing && !MW.busy && !r.active && !MW.stopPending && r.draft
        MW.recordEdit.Show(r.draft && !r.active)
        MW.recordEdit.Enable(editAllowed)
        MW.recordTowerSelect.Enable(editAllowed)
        MW.recordRemove.Enable(editAllowed && MW.recordTowerSelect.Count > 0)
        if (!editAllowed && !MW.busy)
            MW.recordEditArea.Hide()
        MW.recordPassiveInputs.Enable(enabled && !r.draft)
        for k, c in MW.recordFlags
            c.Enable(enabled && !r.draft && !MW.recordPassiveInputs.checked)
        MW.recordPassiveUpgrades.Enable(enabled && !r.draft && !MW.recordPassiveInputs.checked)
        MW.recordPassiveSales.Enable(enabled && !r.draft && !MW.recordPassiveInputs.checked)
        recording := Engine.phase = "recording" && MW.job = "record"
        MW.alignButton.Enable(recording && !MW.busy)
        MW.actionButton.Enable(recording && r.aligned && !r.passive && !MW.busy)
        MW.recordSlot.Enable(recording && !r.passive)
        if r.active
            text := _T(recording ? "Recording" : "Starting recording") " · " r.steps " " _T("actions")
        else if r.draft
            text := _T(r.phase) " · " r.steps " " _T("actions")
        else
            text := _T("No recording active.")
        if r.incomplete
            text .= " · " _T("Incomplete draft")
        else if (r.passive && r.active)
            text .= " · " _T(r.aligned ? "Play normally in Roblox" : "Align to begin input capture")
        MW.recordSave.SetText(_T(MW.stopFailed || r.incomplete ? "Save draft…" : "Stop and save"))
        MW.recordStatus.SetText(text)
        MW.recordStatus.Show(r.active || r.draft)
        MW.recordDraftPanel.Show(r.active || r.draft)
        MW.recordActions.Show(r.active)

        phase := MW.stopFailed ? "Cleanup unconfirmed" : MW.booting ? "Preparing engine" : MW.stopPending ? "Stopping"
            : r.active ? "Recording" : (MW.job = "tool" && Engine.ToolsRunning()) ? "Crate utility open"
            : MW.launcherWaiting ? "Opening Roblox" : StrTitle(MW.run.active ? MW.run.phase : "idle")
        MW.statusLabel.SetText(_T(phase))

        MW.dockRoblox.Enable(enabled)
        MW.updateButton.Enable(enabled && !UpdateHelper.checking)
        MW.topmost.Enable(idle && !Docking.active && !MW.LaunchBusy())
        MW.topmost.tip := Docking.active ? "Undock Roblox before changing Always on top." : !idle ? "Stop playback or recording before changing Always on top." : "Keep the macro above other windows."
        MW.dockApply.Enable(enabled)
        MW.dockApply.Show(s["dockRoblox"] && !Docking.active)

        runEditable := enabled && MW.RunSettingsEditable()
        MW.rotate.Enable(runEditable)
        MW.equip.Enable(runEditable && !MW.rotate.checked)
        MW.repeat.Enable(runEditable && !MW.rotate.checked)
        MW.rotationAmount.Enable(runEditable && MW.rotate.checked)
        MW.rotationUnit.Enable(runEditable && MW.rotate.checked)
    }

    ; ======================================================================
    ; run / stop
    ; ======================================================================
    static RunOptions(withParty := true) {
        s := Store.settings
        return {autoEquip: s["autoEquip"], repeat: s["repeat"], timeScale: s["timeScaleMode"], legacy: s["legacyOptions"]
            , runtime: s["runtime"], bindings: s["recordBindings"], party: withParty ? MW.PartyProfile() : "", rotation: ""}
    }

    static StartRun(shortcut := false) {
        if (MW.booting || !MW.engineReady || MW.LaunchBusy() || MW.Active || MW.busy || MW.stopPending || !IsObject(MW.current))
            return
        if MW.rec.draft {
            MW.Log("Save or discard the recording draft before starting playback.")
            return
        }
        try {
            item := Strategy.Inspect(MW.current.path)
            opts := MW.RunOptions()
            slot2 := ""
            s := Store.settings
            if s["rotation"] {
                first := Strategy.Inspect(s["slot1"]), second := Strategy.Inspect(s["slot2"])
                item := first
                slot2 := second.text
                opts.rotation := {amount: s["rotationAmount"], unit: s["rotationUnit"]}
                if ((reason := MW.Reason(second)) != "") {
                    MW.Log(reason)
                    return
                }
            }
            if ((reason := MW.Reason(item)) != "") {
                MW.Log(reason)
                return
            }
            target := shortcut ? MW.ShortcutGame() : 0
            if (shortcut && !target)
                return
            if (shortcut && MW.CoversGame(target)) {
                MW.gui.Minimize()
                MW.Log("Minimized the macro so it doesn't cover Roblox while the run reads the game screen.")
            }
            if (!shortcut && !Roblox.Game()) {
                MW.LaunchRoblox()
                return
            }
            values := Engine.Profile(opts)
            if !shortcut
                target := MW.FocusGame()
            MW.job := "run", MW.runStarted := false
            MW.run := {active: true, phase: "launching", matches: 0}
            MW.lastMatches := 0
            Engine.Launch(values, item.text, slot2, {kind: "start"})
            Hotkeys.Update()
            MW.UpdateControls()
        } catch as e {
            MW.job := ""
            MW.run := {active: false, phase: "idle", matches: 0}
            if !shortcut
                MW.gui.Restore()
            if InStr(e.Message, "party") || InStr(e.Message, "Party")
                MW.Log(e.Message ".")
            else if InStr(e.Message, "Duplicate hotkey")
                MW.Log(e.Message " Change it in Settings → Advanced settings.")
            else if InStr(e.Message, "engine files")
                MW.Log(e.Message)
            else
                MW.Log("Choose valid strategies and open exactly one Roblox game window.")
            MW.UpdateControls()
        }
    }

    static StopRun(emergency := false) {
        GameRecovery.Cancel()
        if MW.launcherWaiting {
            Roblox.Cancel()
            MW.launcherWaiting := false
            MW.Log("Stopped waiting. Roblox may still open.")
            MW.UpdateControls()
            if !(MW.Active || MW.busy || MW.stopPending)
                return false
        }
        if (MW.job = "record" && MW.rec.active) {
            MW.StopRecording(emergency)
            return true
        }
        if (Engine.phase = "offline" && !Engine.ToolsRunning() && !MW.Active)
            return false
        if (Engine.phase != "offline" || Engine.ToolsRunning())
            MW.stopPending := true
        Engine.Stop(emergency)
        MW.Sync()
        return true
    }

    static FocusGame() {
        target := Roblox.Game()
        if !target
            throw ValueError("Open exactly one Roblox game window.")
        if (!Docking.IsCurrent() || MW.CoversGame(target))
            MW.gui.Minimize()
        Roblox.Focus(target)
        return target
    }

    ; The engine refuses to read the game (auto equip, match checks) while any
    ; visible window overlaps Roblox, and the macro is often always-on-top.
    static CoversGame(target) {
        try {
            if (!target || WinGetMinMax(MW.gui) = -1)
                return false
            WinGetPos(&mx, &my, &mw, &mh, MW.gui)
            WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " target)
            return mx < gx + gw && mx + mw > gx && my < gy + gh && my + mh > gy
        }
        return false
    }

    static ShortcutGame(pinned := 0) {
        if MW.LaunchBusy()
            return 0
        t := Roblox.Game()
        return (t && (!pinned || t = pinned) && Roblox.IsForeground(t)) ? t : 0
    }

    static LaunchRoblox() {
        if (MW.closing || MW.Active || MW.busy || MW.LaunchBusy())
            return
        MW.ShowLaunchStatus(Roblox.Launch())
    }

    static ShowLaunchStatus(state) {
        if (state = "waiting") {
            if !MW.launcherWaiting {
                MW.launcherWaiting := true
                MW.Log("Opening Roblox; waiting for its window…")
            }
        } else {
            MW.launcherWaiting := false
            static msg := Map("ready", "Roblox window detected. If another game is open, switch to TDS first. Once TDS is in the lobby, press Start."
                , "multiple", "Close extra Roblox windows before starting.", "unavailable", "Could not open Roblox. Check the installation and try again."
                , "timed-out", "Roblox did not open in time. Open it manually and try again.")
            MW.Log(msg.Has(state) ? msg[state] : "Roblox could not be opened.")
            if (state = "ready")
                SetTimer(() => MW.ApplySavedDocking(), -500)
        }
        MW.UpdateControls()
    }

    static OpenCrateTool() {
        if (MW.Active || MW.busy || MW.rec.draft || Engine.phase != "offline")
            return
        try {
            Engine.LaunchTool()
            MW.job := "tool"
            MW.Log("Crate tool opened. Open your inventory; F3 starts, F4 stops. Main Stop closes the tool.")
        } catch as e
            MW.Log(e.Message)
        MW.UpdateControls()
    }

    ; Engine phase -> UI state (hybrid_client._status + window.receive).
    static Sync() {
        p := Engine.phase
        wasRunning := MW.run.active
        if (MW.job = "run") {
            if (p = "starting" || p = "running")
                MW.runStarted := true
            active := InArray(["launching", "starting", "running", "stopping"], p)
            MW.run.active := active, MW.run.phase := p
            if (IsObject(Engine.stats) && IsInteger(Engine.stats["matches"]))
                MW.run.matches := Engine.stats["matches"]
            if (p = "idle" && MW.runStarted)
                SetTimer(() => (MW.job = "run" && Engine.phase = "idle") ? Engine.Shutdown() : 0, -10)
            if (p = "offline") {
                MW.job := "", MW.run.active := false, MW.run.phase := "idle"
            }
        } else if (MW.job = "record") {
            MW.rec.active := InArray(["launching", "starting", "recording", "stopping"], p)
            if (p = "recording")
                MW.runStarted := true
            if (p = "idle" && MW.runStarted) {
                SetTimer(() => MW.FinishRecordingSession(), -250)
                return
            }
            if (p = "offline")
                MW.FinishRecordingSession()
        } else if (MW.job = "tool") {
            MW.run.active := Engine.ToolsRunning(), MW.run.phase := "offline"
            if !MW.run.active
                MW.job := ""
        } else {
            MW.run.active := false
        }
        if (MW.stopPending && !MW.Active && Engine.phase = "offline" && !Engine.ToolsRunning()) {
            MW.stopPending := false
            MW.Log(MW.rec.draft ? "Stopped; recording draft retained." : "Stopped.")
        }
        ; Notifications and economy sampling.
        running := MW.run.active && MW.run.phase = "running"
        Economy.Observe(running, Engine.stats, Engine.session)
        if (!wasRunning && MW.run.active && MW.job = "run")
            Webhook.Submit("start")
        if (wasRunning && MW.run.matches > MW.lastMatches)
            Webhook.Submit("match")
        MW.lastMatches := MW.run.matches
        if (wasRunning && !MW.run.active && MW.job != "tool")
            Webhook.Submit(Engine.stopReason = "fault" ? "error" : "stopped")
        if (IsObject(Engine.gameLaunch) && !GameRecovery.Busy && !MW.recoveryDockPending)
            MW.BeginRecovery()
        Hotkeys.Update()
        MW.UpdateControls()
    }

    ; ======================================================================
    ; recording (engine recorder + launcher draft, recording.py semantics)
    ; ======================================================================
    static RecordingMetadata() {
        mods := []
        for k, c in MW.recordModifiers
            if c.checked
                mods.Push(k)
        flags := Map()
        for k, c in MW.recordFlags
            flags[k] := c.checked && !MW.recordPassiveInputs.checked
        return {map: MW.recordMap.Text, mode: MW.recordMode.Text, towers: Trim(MW.recordTowers.Text), modifiers: mods, flags: flags}
    }

    static RecordingRequirement() {
        m := MW.RecordingMetadata()
        if (m.towers = "")
            return "Enter 1–5 equipped towers in hotbar order, separated by commas."
        if (!InArray(Engine.MAPS, m.map) || !InArray(Engine.MODES, m.mode))
            return "Choose a valid map and mode in Match below."
        names := StrSplit(m.towers, ",")
        seen := Map()
        seen.CaseSense := false
        if (names.Length > 5)
            return "Use 1–5 distinct tower names, separated by commas."
        for n in names {
            n := Trim(n)
            if (!RegExMatch(n, "^[A-Za-z0-9][A-Za-z0-9 '-]{0,47}$") || seen.Has(n))
                return "Use 1–5 distinct tower names, separated by commas."
            seen[n] := 1
        }
        return ""
    }

    static StartRecording() {
        if (MW.booting || !MW.engineReady || MW.LaunchBusy() || MW.Active || MW.rec.draft || MW.busy || MW.stopPending)
            return
        req := MW.RecordingRequirement()
        if (req != "") {
            MW.recordGuidance.SetText(_T(req))
            return
        }
        m := MW.RecordingMetadata()
        towers := ""
        for n in StrSplit(m.towers, ",")
            towers .= (towers = "" ? "" : ",") Trim(n)
        mods := ""
        for x in m.modifiers
            mods .= (mods = "" ? "" : ",") x
        isPassive := MW.recordPassiveInputs.checked
        args := Map("map", m.map, "mode", m.mode, "towers", towers, "modifiers", mods
            , "chain", m.flags["auto_chain"] ? "1" : "0", "caravan", m.flags["auto_caravan"] ? "1" : "0"
            , "beat", m.flags["auto_beat"] ? "1" : "0", "skip", m.flags["auto_skip"] ? "1" : "0"
            , "spam", m.flags["ability_spam"] ? "1" : "0", "move", "0", "dir", "W", "ms", "1000"
            , "passive", isPassive ? "1" : "0", "clicks", MW.recordPassiveUpgrades.checked ? "1" : "0"
            , "sales", MW.recordPassiveSales.checked ? "1" : "0")
        try {
            values := Engine.Profile(MW.RunOptions(false))
            target := MW.FocusGame()
            MW.recordingWindow := target
            MW.job := "record", MW.runStarted := false
            MW.rec := {active: true, draft: true, text: "", steps: 0, aligned: false, passive: isPassive, incomplete: false
                , pendingSave: false, phase: "Draft", meta: m, towers: towers, mods: mods}
            try Store.SaveForm(MW.RecordFormSnapshot())
            if isPassive
                Passive.Prepare(target)
            Engine.Launch(values, "", "", {kind: "record", args: args})
            Hotkeys.Update()
        } catch as e {
            MW.job := ""
            Passive.Stop()
            if (Engine.phase != "offline")
                Engine.Shutdown()
            MW.rec := {active: false, draft: false, text: "", steps: 0, aligned: false, passive: false, incomplete: false, pendingSave: false, phase: "Draft"}
            MW.gui.Restore()
            if InStr(e.Message, "Duplicate hotkey")
                MW.Log(e.Message)
            else if (InStr(e.Message, "Roblox") || InStr(e.Message, "focus"))
                MW.Log("Could not focus Roblox. Open one game window and try again.")
            else
                MW.Log("Recording could not start: " e.Message)
        }
        MW.UpdateControls()
    }

    static RecordAction(action) {
        r := MW.rec
        if (!r.active || Engine.phase != "recording" || MW.busy)
            return
        try {
            if (MW.FocusGame() != MW.recordingWindow)
                throw ValueError()
        } catch {
            MW.Log("The recording game window changed. Stop recording first.")
            return
        }
        if (action = "align") {
            Engine.RecordAlign()
        } else if (action = "instruction") {
            text := Trim(MW.strategyAction.Text)
            if (text = "")
                return
            try {
                Strategy.Parse("[Settings]`nmap=x`ndifficulty=x`n[Steps]`n" text)
            } catch {
                MW.Log("Enter one supported strategy instruction, for example SpawnTower(960, 540, 1, Scout1).")
                return
            }
            if !Engine.RecordStep(text)
                MW.Log("The engine did not accept the action.")
        }
    }

    ; Stop keeps a draft (F2, F8 and the Stop button all retain it).
    static StopRecording(emergency := false) {
        if !MW.rec.active
            return
        MW.stopPending := true
        if MW.rec.passive {
            Passive.Stop()
            Engine.RecordStop("", false)
        } else if !Engine.RecordStop("UMDraft-" A_TickCount, true) {
            Engine.Stop(emergency)
        }
        ; If the engine cannot confirm, end it so inputs are released; the draft text survives.
        SetTimer(() => (MW.rec.active && MW.job = "record") ? Engine.Stop(true) : 0, -9000)
        MW.UpdateControls()
    }

    static OnRecState(steps, aligned) {
        if (MW.job != "record")
            return
        MW.rec.aligned := aligned
        if !MW.rec.passive
            MW.rec.steps := steps
        if (aligned && MW.rec.passive)
            Passive.Arm()
        MW.UpdateControls()
    }

    static OnRecorded(path) {
        try {
            text := Strategy.ReadText(path)
            MW.rec.text := text
            MW.rec.steps := Strategy.Parse(text).steps.Length
        } catch {
            MW.rec.text := ""
        }
        try FileDelete(path)
    }

    static FinishRecordingSession() {
        if (MW.job != "record")
            return
        MW.job := "", MW.rec.active := false, MW.stopPending := false
        if (Engine.phase != "offline")
            Engine.Shutdown()
        if MW.rec.passive {
            text := Passive.Draft(MW.rec.meta, MW.rec.towers, MW.rec.mods)
            MW.rec.incomplete := Passive.incomplete
            if (text != "") {
                MW.rec.text := text
                try MW.rec.steps := Strategy.Parse(text).steps.Length
            }
        }
        if (MW.rec.text = "") {
            MW.rec.draft := false
            MW.Log("Recording stopped with no actions; there is nothing to save.")
        } else {
            MW.rec.draft := true, MW.rec.phase := "Draft"
            if MW.rec.pendingSave {
                MW.rec.pendingSave := false
                MW.ExportRecording()
            } else
                MW.Log("Stopped; recording draft retained.")
        }
        Hotkeys.Update()
        MW.UpdateControls()
    }

    static SaveRecording() {
        if MW.run.active
            return
        if MW.rec.active {
            MW.rec.pendingSave := true
            MW.StopRecording()
            return
        }
        if MW.rec.draft
            MW.ExportRecording()
    }

    static ExportRecording() {
        if MW.rec.incomplete {
            if (Dialog.Ask(_T("Save incomplete draft?"), _T("Observation was interrupted or an action could not be confirmed. Save this draft anyway? Review it before playback."), ["Yes", "No"], 2) != "Yes") {
                MW.Log("Incomplete recording retained as a draft.")
                return
            }
        }
        requested := Trim(MW.recordName.Text)
        try {
            target := Store.SaveRecording(requested, MW.rec.text)
            incomplete := MW.rec.incomplete
            MW.ClearDraft()
            MW.RefreshLibrary()
            MW.Log(incomplete ? "Incomplete draft saved; review before playback." : "Recording saved.")
            SplitPath(target, , , , &stem)
            if (stem != requested)
                MW.Log("A recording named " requested " already exists; saved as " stem ".")
        } catch
            MW.Log("Recording not saved. Draft retained; check its name and try again.")
        MW.UpdateControls()
    }

    static DiscardRecording() {
        if (MW.rec.active || !MW.rec.draft)
            return
        MW.ClearDraft()
        MW.Log("Recording discarded.")
        MW.UpdateControls()
    }

    static ClearDraft() {
        MW.rec := {active: false, draft: false, text: "", steps: 0, aligned: false, passive: false, incomplete: false, pendingSave: false, phase: "Draft"}
        MW.recordTowerSelect.SetItems([])
        MW.recordEditArea.Hide()
    }

    static LoadRecordedTowers() {
        if (MW.Active || MW.busy || !MW.rec.draft)
            return
        try {
            r := Strategy.ListTowers(MW.rec.text)
            MW.recordTowerSelect.SetItems(r.ids)
            MW.recordTowerSelect.Choose(r.ids.Length ? 1 : 0)
            MW.recordEditArea.Show()
            MW.recordTowerNote.SetText(_T(r.truncated ? "Showing the first 512 towers." : r.ids.Length ? "Choose a recorded tower." : "No recorded towers."))
        } catch {
            MW.recordEditArea.Hide()
            MW.Log("Recorded towers could not be listed.")
        }
        MW.UpdateControls()
    }

    static PreviewTowerRemoval() {
        if (MW.Active || MW.busy || !MW.rec.draft)
            return
        tower := MW.recordTowerSelect.Text
        if (tower = "")
            return
        try count := Strategy.DeletionLines(MW.rec.text, tower).Count
        catch {
            MW.Log("Removal preview was not available.")
            return
        }
        if (Dialog.Ask(_T("Remove recorded tower"), "Remove " count " recorded actions for " tower " and its dependent clones? Global ability actions remain and may need separate review.", ["Yes", "No"], 2) != "Yes")
            return
        try {
            MW.rec.text := Strategy.DeleteTower(MW.rec.text, tower)
            MW.rec.steps := Strategy.Parse(MW.rec.text).steps.Length
        } catch {
            MW.Log("Removing those actions would leave an empty recording; discard the draft instead.")
            return
        }
        MW.recordEditArea.Hide()
        MW.Log("Recorded tower actions removed. Review the draft before saving.")
        MW.UpdateControls()
    }

    ; ======================================================================
    ; docking
    ; ======================================================================
    static SetDocked(enabled) {
        busy := MW.Active || MW.busy || MW.stopPending || MW.closing || Docking.restoring || MW.LaunchBusy()
        if busy {
            MW.Log("Docking waits for idle playback/recording and any pending window move [D-BUSY].")
            MW.dockRoblox.SetChecked(Store.settings["dockRoblox"])
            return
        }
        MW.dockAutoPending := false
        Store.settings["dockRoblox"] := !!enabled
        MW.Persist()
        try {
            if enabled {
                game := Roblox.Game()
                if !game {
                    MW.dockAutoPending := true
                    MW.Log("Docking enabled; waiting for exactly one visible Roblox game window [D-NOGAME].")
                } else {
                    if (WinGetMinMax(MW.gui) = 1) {
                        MW.gui.Restore()
                        MW.dockRestoreMax := true
                    }
                    result := Docking.Attach(game, MW.gui.Hwnd)
                    if (result = "pending")
                        MW.Log("Waiting for Windows to apply the window layout.")
                    else
                        MW.DockResult(result)
                }
            } else {
                result := Docking.Detach()
                if (result = "pending")
                    MW.Log("Waiting for Windows to restore the original layout.")
                else
                    MW.DockRestoreFinished(result)
            }
        } catch as e {
            static codes := Map("Restore Roblox and the macro to windowed mode first.", "Restore Roblox from maximized/fullscreen mode, then click Arrange windows [D-WINDOW-MODE]."
                , "Use the selected Roblox game in windowed mode.", "Roblox is fullscreen or borderless. Restore its window, then click Arrange windows [D-GAME-MODE]."
                , "This display is too small for the side-by-side layout.", "The available work area cannot fit both minimum window sizes at this scaling [D-SIZE]."
                , "This display is too small or too large for the side-by-side layout.", "The work area is outside safe side-by-side capture limits [D-SIZE]."
                , "Open exactly one Roblox game window.", "Close extra Roblox clients, then click Arrange windows [D-AMBIGUOUS].")
            MW.Log(codes.Has(e.Message) ? codes[e.Message] : "Window identity or geometry could not be verified. Click Arrange windows while idle [D-VERIFY].")
            if !Docking.active {
                Store.settings["dockRoblox"] := false
                MW.Persist()
            }
            if (MW.dockRestoreMax && !Docking.active) {
                MW.dockRestoreMax := false
                MW.gui.Maximize()
            }
        }
        MW.dockRoblox.SetChecked(Docking.active || Store.settings["dockRoblox"])
        MW.UpdateControls()
    }

    static DockResult(result) {
        if (result = "attached")
            MW.Log("Window layout applied.")
        else
            MW.DockRestoreFinished(result)
    }

    static DockRestoreFinished(result) {
        if (result = "attach-failed" || result = "attach-partial") {
            Store.settings["dockRoblox"] := false
            MW.Persist()
            MW.Log(result = "attach-partial" ? "Windows did not apply the layout. Unconfirmed window positions were left alone [D-TIMEOUT]."
                : "Windows did not apply the layout. Docking was turned off; try again in windowed mode [D-TIMEOUT].")
        } else if (result = "partial")
            MW.Log("Some window positions could not be confirmed. Those windows were left alone.")
        else if (result = "restored")
            MW.Log("Original window bounds restored.")
        if MW.dockRestoreMax {
            MW.dockRestoreMax := false
            if (result != "partial" && result != "attach-partial")
                MW.gui.Maximize()
        }
        MW.dockRoblox.SetChecked(Store.settings["dockRoblox"])
    }

    static ApplySavedDocking() {
        if (!MW.dockAutoPending || !Store.settings["dockRoblox"] || MW.closing || MW.booting || !MW.engineReady
            || WinGetMinMax(MW.gui) = -1 || MW.Active || MW.busy || MW.stopPending || Docking.active || MW.LaunchBusy())
            return
        if Roblox.Game()
            MW.SetDocked(true)
    }

    ; ======================================================================
    ; engine-requested game relaunch (outside the engine process)
    ; ======================================================================
    static recoveryBound := "", recoveryDockPending := false
    static RecoveryFn() => MW.recoveryBound ? MW.recoveryBound : (MW.recoveryBound := ObjBindMethod(MW, "PollRecovery"))

    static RecoveryAllowed() => MW.job = "run" && MW.run.active && InArray(["starting", "running"], Engine.phase) && !MW.closing && !MW.stopPending

    static BeginRecovery() {
        g := Engine.gameLaunch
        if (!IsObject(g) || !MW.RecoveryAllowed())
            return
        try {
            GameRecovery.Begin(g)
            MW.Log("Restarting the selected Roblox client outside the automation process.")
            SetTimer(MW.RecoveryFn(), 100)
        } catch {
            Engine.AckGameLaunch(false)
            MW.Log("Game recovery canceled. Check the game and press Start to retry.")
        }
    }

    static PollRecovery() {
        if MW.recoveryDockPending {
            if (MW.RecoveryAllowed() && Docking.Busy)
                return
            MW.recoveryDockPending := false
            r := MW.RecoveryAllowed() && Docking.IsCurrent()
        } else {
            r := GameRecovery.Poll(MW.RecoveryAllowed())
            if (r = "")
                return
            if (r && Store.settings["dockRoblox"] && Docking.active) {
                r := Docking.ReplaceGame(Roblox.Game())
                if r {
                    MW.recoveryDockPending := true
                    return
                }
            }
        }
        SetTimer(MW.RecoveryFn(), 0)
        Engine.AckGameLaunch(r)
        if !r
            MW.Log("Game recovery canceled. A launch already submitted to Windows may still finish. Check the game and press Start to retry.")
        MW.UpdateControls()
    }

    ; ======================================================================
    ; Discord
    ; ======================================================================
    static EnableWebhook() {
        try {
            Webhook.Configure(Trim(MW.webhookUrl.Text))
        } catch {
            Webhook.Disable()
            MW.webhookTest.Enable(false), MW.webhookDisable.Enable(false)
            MW.webhookStatus.SetText(_T("Enter a valid Discord webhook URL. Notifications are off."))
            return
        }
        MW.webhookUrl.Clear()
        MW.webhookStatus.SetText(_T("Notifications enabled for this session."))
        MW.webhookTest.Enable(true), MW.webhookDisable.Enable(true)
    }

    static DisableWebhook() {
        Webhook.Disable()
        MW.webhookUrl.Clear()
        MW.webhookStatus.SetText(_T("Notifications are off."))
        MW.webhookTest.Enable(false), MW.webhookDisable.Enable(false)
    }

    static TestWebhook() {
        MW.webhookStatus.SetText(_T(Webhook.Submit("test") ? "Sending test notification…" : "Notification queue is unavailable."))
    }

    static EnableRemote() {
        token := Trim(MW.remoteToken.Text), owner := Trim(MW.remoteOwner.Text), channel := Trim(MW.remoteChannel.Text)
        MW.DisableRemote()
        try {
            BotRemote.Configure(token, owner, channel, MW.remoteAllowStart.checked, MW.remoteAllowShot.checked)
        } catch {
            MW.DisableRemote()
            MW.remoteStatus.SetText(_T("Enter a personal bot token and valid Discord user/channel IDs."))
            return
        }
        MW.remoteToken.Clear()
        MW.remoteConnect.Enable(false), MW.remoteDisable.Enable(true)
        MW.remoteOwner.SetReadOnly(true), MW.remoteChannel.SetReadOnly(true)
        MW.remoteAllowStart.Enable(false), MW.remoteAllowShot.Enable(false)
        MW.remoteStatus.SetText(_T("Connecting to your bot and selected channel…"))
    }

    static DisableRemote() {
        BotRemote.Disable()
        MW.remoteToken.Clear()
        MW.remoteOwner.SetReadOnly(false), MW.remoteChannel.SetReadOnly(false)
        MW.remoteAllowStart.Enable(true), MW.remoteAllowShot.Enable(true)
        MW.remoteConnect.Enable(true), MW.remoteDisable.Enable(false)
        MW.remoteStatus.SetText(_T("Remote control is off."))
    }

    static RemoteState(gen, state) {
        if (gen != BotRemote.generation || MW.closing)
            return
        switch state {
            case "unavailable":
                MW.DisableRemote()
                MW.remoteStatus.SetText(_T("Remote control disconnected. Check your bot token, intent and channel permissions."))
            case "rate-limited": MW.remoteStatus.SetText(_T("Discord requested a pause. Remote control will wait."))
            case "busy": MW.remoteStatus.SetText(_T("Channel is busy; older commands were skipped. Send a new command."))
            case "connected": MW.remoteStatus.SetText(_T("Remote enabled: !stop / !status, plus !start / !screenshot if allowed above."))
        }
    }

    static OfficialLink() {
        if (OfficialRemote.active || MW.closing)
            return
        MW.officialGeneration += 1
        try {
            if !MW.officialConsent.checked
                throw ValueError()
            Economy.SetEnabled(true)
            OfficialRemote.Link(MW.officialCode.Text, MW.officialGeneration)
        } catch {
            Economy.SetEnabled(false)
            MW.officialStatus.SetText(_T("Check the official connection code and consent. Wait briefly if a previous link is closing."))
            return
        }
        MW.officialCode.Clear()
        MW.officialLinkBtn.Enable(false), MW.officialDisconnect.Enable(true)
        MW.officialCode.Enable(false), MW.officialConsent.Enable(false)
        MW.officialStatus.SetText(_T("Connecting…"))
    }

    static OfficialShutdown() {
        MW.officialGeneration += 1
        Economy.SetEnabled(false)
        OfficialRemote.Close()
        MW.officialCode.Clear()
        MW.officialLinkBtn.Enable(true), MW.officialDisconnect.Enable(false)
        MW.officialConsent.SetChecked(false)
        MW.officialCode.Enable(true), MW.officialConsent.Enable(true)
        MW.officialStatus.SetText(_T("Disconnected. Use /remote unlink to revoke the server record too."))
    }

    static OfficialState(gen, state) {
        if (gen != MW.officialGeneration || MW.closing)
            return
        if (state = "disconnected") {
            MW.OfficialShutdown()
            MW.officialStatus.SetText(_T("Connection ended. Generate a fresh /remote link code to reconnect."))
        } else if (state = "stats-unavailable")
            MW.officialStatus.SetText(_T("Linked. UltBot needs the updated reporting endpoint before statistics can be shared."))
        else
            MW.officialStatus.SetText(_T("Linked. Use /remote status, start, stop or screenshot within your permissions."))
    }

    static RemoteStateName() {
        if (MW.booting || !MW.engineReady || MW.stopFailed)
            return "unavailable"
        return MW.stopPending ? "stopping" : MW.rec.active ? "recording" : MW.run.active ? "running" : "idle"
    }

    ; One handler for the personal bot and the official relay (discord_panel.remote_action).
    static HandleRemote(source, op) {
        official := source = "official"
        allowStart := official ? MW.officialConsent.checked : MW.remoteAllowStart.checked
        allowShot := official ? MW.officialConsent.checked : MW.remoteAllowShot.checked
        ok := false, text := "", result := "{}", png := ""
        switch op {
            case "stop":
                ok := MW.StopRun() = true
                text := ok ? BotRemote.STOP_REPLY : BotRemote.STOP_REFUSED
                result := '{"message":"' (ok ? "Stop requested." : "Stop could not be queued.") '"}'
            case "status":
                ok := true
                state := MW.RemoteStateName()
                text := BotRemote.StatusText(state, MW.run.matches)
                result := '{"running":' (MW.run.active ? "true" : "false") ',"strategy":"' (MW.run.active ? "Selected strategy" : "None")
                    . '","wave":"Unknown","runtime":"Not reported","state":"' (state = "unavailable" ? "unavailable" : MW.run.phase) '","matches":' MW.run.matches '}'
            case "start":
                if (allowStart && !MW.Active && !MW.busy && IsObject(MW.current) && Roblox.Game() && MW.engineReady) {
                    MW.StartRun()
                    ok := MW.run.active
                }
                text := ok ? BotRemote.START_REPLY : BotRemote.START_REFUSED
                result := ok ? '{"message":"Start requested; check the app to confirm."}' : '{"error":"Select a strategy locally, stop other work and open Roblox first."}'
            case "screenshot":
                if (allowShot && MW.RemoteStateName() != "unavailable" && !MW.closing) {
                    png := Roblox.Screenshot()
                    ok := IsObject(png) && png.Size <= 700000
                }
                if !ok
                    png := ""
                text := ok ? BotRemote.SCREENSHOT_REPLY : BotRemote.SCREENSHOT_REFUSED
                result := ok ? '{"message":"Roblox client only."}' : '{"error":"Screenshot unavailable. Keep one Roblox window visible, in front, and uncovered."}'
        }
        if official
            OfficialRemote.Respond(ok, result, png)
        else
            BotRemote.Reply(text, png)
    }

    ; ======================================================================
    ; timers / close
    ; ======================================================================
    static Tick() {
        if MW.closing
            return
        Engine.Tick()
        if MW.launcherWaiting {
            st := Roblox.Poll()
            if (st != "waiting")
                MW.ShowLaunchStatus(st)
        }
        if (MW.job = "tool" && !Engine.ToolsRunning())
            MW.Sync()
        if (MW.stopPending && Engine.phase = "offline" && !Engine.ToolsRunning())
            MW.Sync()
        layout := Docking.Poll()
        if (layout != "" && layout != "pending")
            MW.DockResult(layout)
        MW.ApplySavedDocking()
        Hotkeys.Update()
        MW.UpdateControls()
    }

    static Close() {
        if MW.closing
            return
        if MW.updateReviewing {
            MW.Log("Finish or cancel update review before closing.")
            return
        }
        if MW.rec.draft && !MW.rec.active {
            if (Dialog.Ask(_T("Unsaved recording"), _T("Close and discard the unsaved recording?"), ["Discard", "Cancel"], 2) != "Discard")
                return
        }
        MW.closing := true
        MW.statusLabel.SetText(_T("Stopping engine…"))
        try Store.SaveForm(MW.RecordFormSnapshot())
        GameRecovery.Cancel()
        Passive.Stop()
        BotRemote.Disable()
        OfficialRemote.Close()
        Webhook.Disable()
        Hotkeys.ClearAll()
        if (Engine.phase != "offline" || Engine.ToolsRunning())
            Engine.ForceStop("Engine closed with the app.")
        if Docking.active {
            restoreDeadline := A_TickCount + 450
            while (Docking.Detach() = "pending" && A_TickCount < restoreDeadline)
                Sleep(25)
        }
        if Store.settings["motion"]
            MW.FadeTo(0, 190, () => ExitApp())
        else
            ExitApp()
        SetTimer(() => ExitApp(), -1500)
    }
}
