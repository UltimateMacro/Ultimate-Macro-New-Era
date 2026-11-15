; The 1.4 presentation only. Original 1.3.3.10 controls remain the form model.
; Original automation remains in Main.ahk. Connections have their own module.
class Locale {
    static active := "en"
    static Tr(s, *) => s
    static Heading(s) => s
}
_T(s, *) => s
class Store {
    static settings := Map("motion", true, "themeBackground", true)
}
class Dialog {
    static gui := ""
}

class MW {
    static repeatHelp := "", mapScrollLabel := "", mapScrollHelp := ""
    static gui := "", surface := "", layout := "", pages := [], page := 1
    static events := Map(), exposed := Map(), mirrors := [], sections := []
    static tabs := [], logo := 0, keyboardFocus := "", outputVisible := false
    static booting := false, ready := false, closing := false, compact := false, ultra := false
    static sizeHandler := "", layoutBusy := false, eventsInstalled := false
    static resizeTimer := "", resizeArmed := false, resizeQueued := "", sizeKey := ""
    static syncTimer := "", fadeTimer := "", pageTimer := "", pageShade := 0
    static files := [], visibleFiles := [], selectedPath := "", lastLog := "", logCount := -1
    static topmost := "", nativeTest := false, exitHandler := "", openedOnce := false

    static Bind(ctrl, event, callback) {
        ctrl.OnEvent(event, callback)
        if !MW.events.Has(ctrl.Hwnd)
            MW.events[ctrl.Hwnd] := {control: ctrl, handlers: Map()}
        MW.events[ctrl.Hwnd].handlers[event] := callback
    }

    static Expose(ctrl) => (MW.exposed[ctrl.Hwnd] := true)
    static Has(ctrl, event) => MW.events.Has(ctrl.Hwnd) && MW.events[ctrl.Hwnd].handlers.Has(event)

    static Invoke(ctrl, event := "Click", *) {
        if MW.Has(ctrl, event) && ctrl.Enabled
            MW.events[ctrl.Hwnd].handlers[event].Call(ctrl, 0)
        MW.Sync()
    }

    static Assign(ctrl, value, event := "Change") {
        if !ctrl.Enabled
            return
        if (ctrl.Type = "DropDownList")
            ctrl.Choose(value)
        else
            ctrl.Value := value
        MW.Invoke(ctrl, event)
    }

    static Edit(ctrl, widget) => MW.Assign(ctrl, widget.Text)
    static Choose(ctrl, widget, value) => MW.Assign(ctrl, value)
    static Switch(ctrl, widget, value) => MW.Assign(ctrl, value ? 1 : 0, "Click")

    static ScrollAmountArrow(widget, value) {
        ; The native UpDown has a buddy edit. An arrow press in the painted
        ; spin box must deliver both of the original form's change callbacks.
        ScrollDownAmountUpDown.Value := value
        MW.Assign(ScrollDownAmountCtrl, String(ScrollDownAmountUpDown.Value))
        MW.Invoke(ScrollDownAmountUpDown, "Change")
    }

    static Action(root, ctrl, label := "", kind := "", icon := "") {
        MW.Expose(ctrl)
        widget := root.Add(Button(label != "" ? label : ctrl.Text, ObjBindMethod(MW, "Invoke", ctrl, "Click"), kind, icon))
        MW.mirrors.Push({model: ctrl, view: widget, kind: label = "" ? "buttonText" : "button"})
        return widget
    }

    static Field(root, ctrl, opts := "") {
        MW.Expose(ctrl)
        widget := root.Add(Field(ctrl.Text, "", opts))
        widget.onChange := ObjBindMethod(MW, "Edit", ctrl)
        MW.mirrors.Push({model: ctrl, view: widget, kind: "field"})
        return widget
    }

    static Toggle(root, ctrl, checkbox := false) {
        MW.Expose(ctrl)
        type := checkbox ? Check : Toggle
        widget := root.Add(type(ctrl.Text, ctrl.Value, ObjBindMethod(MW, "Switch", ctrl)))
        MW.mirrors.Push({model: ctrl, view: widget, kind: "toggle"})
        return widget
    }

    static Spin(root, ctrl, lo, hi, suffix := "") {
        MW.Expose(ctrl)
        widget := root.Add(Spin(ctrl.Value, lo, hi, suffix, ObjBindMethod(MW, "Choose", ctrl)))
        MW.mirrors.Push({model: ctrl, view: widget, kind: "spin"})
        return widget
    }

    static Open(show := true) {
        if MW.gui || MW.closing
            return
        ; A legacy hotkey can run as soon as this script is loaded. Don't let
        ; it destroy a half-built view while its controls are still attaching.
        prior := A_IsCritical
        Critical("On")
        try MW.Build(show)
        finally Critical(prior ? prior : "Off")
    }

    static Build(show) {
        MW.nativeTest := !show
        MW.booting := show
        Gfx.Init()
        g := Gui("-Caption +Resize +MinimizeBox -DPIScale +0x02000000", "Ultimate Macro")
        g.BackColor := Theme.Hex("base"), g.MarginX := 0, g.MarginY := 0
        MW.gui := g
        MW.logo := Gfx.LoadImage(A_ScriptDir "\ui\UltBot.png")
        Backdrop.Load(A_ScriptDir "\ui\AlpineSunset.jpg")
        g.OnEvent("Close", (*) => MW.Invoke(BtnClose))
        if !MW.exitHandler {
            MW.exitHandler := ObjBindMethod(MW, "Dispose")
            OnExit(MW.exitHandler, -1)
        }

        header := HBox()
        header.Add(Spacer(14))
        header.Add(ImageBox(MW.logo, 20))
        header.Add(Spacer(8))
        MW.headerTitle := header.Add(Label("Ultimate Macro"))
        names := ["Run", "Record", "Discord", "Settings", "Tools", "Tutorial", "Changes"]
        for i, name in names {
            if (i != 2)
                MW.Expose(TabCtrl[i > 2 ? i - 1 : i])
            b := header.Add(Button(name, ObjBindMethod(MW, "SelectPage", i), "nav"))
            b.fixedH := 45
            MW.tabs.Push(b)
        }
        MW.compactNav := header.Add(Select(names, 1, (sel, i) => MW.SelectPage(i)))
        MW.compactNav.fixedW := 125
        header.Add(Spacer(16), 1)
        MW.startBtn := MW.Action(header, Tab1_Start, "Start", "accent", "play")
        MW.startBtn.tip := "Start the selected strategy (F1)"
        header.Add(Spacer(7))
        MW.stopBtn := MW.Action(header, Tab1_Stop, "Stop", "stop", "stop")
        MW.stopBtn.tip := "Stop the original macro (F2)"
        header.Add(Spacer(10))
        for spec in [["min", (*) => MW.gui.Minimize()], ["max", (*) => MW.ToggleMaximize()], ["close", (*) => MW.Invoke(BtnClose)]] {
            b := header.Add(Button("", spec[2], "chrome", spec[1]))
            b.fixedW := 30, b.fixedH := 45
            if (spec[1] = "max")
                MW.maxBtn := b
        }
        MW.Expose(BtnMin), MW.Expose(BtnClose), MW.Expose(GuiTitleCtrl) ; native chrome equivalents

        side := VBox(, 10, [14, 16, 11, 12])
        title := HBox(, 6)
        title.Add(Label("Strategies"), 1)
        add := MW.Action(title, Tab1_Btn1, " ", "", "plus")
        add.fixedW := 30, add.tip := "Browse for a strategy"
        side.Add(title)
        MW.search := side.Add(Field("", "Search strategies", {onChange: (*) => MW.RefreshList()}))
        MW.list := side.Add(StrategyList((i) => MW.SelectStrat(i)), 1)
        MW.sidebar := side
        MW.compactStrategies := Select(, 1, (s, i) => MW.SelectStrat(i))
        MW.ultraNav := Select(names, 1, (s, i) => MW.SelectPage(i))

        bar := HBox(, 6, [0, 0, 6, 0])
        MW.outputBtn := bar.Add(Button("Output   Ready.", (*) => MW.ToggleOutput(), "output"), 1)
        MW.outputBtn.fixedH := 32
        MW.outputBar := bar
        status := HBox(, 0, [14, 0, 0, 0])
        status.Add(Label("Idle  ·  " App.RELEASE, "caption"), 1)
        status.Add(ResizeGrip())
        MW.layout := MainLayout(header, MW.ultraNav, MW.compactStrategies, side, bar, status)
        MW.surface := Surface(g, MW.layout)
        MW.surface.background := (sf) => Backdrop.PaintFor(sf, 0, 0)
        MW.surface.overlay := (sf) => MW.booting ? BootStage.Paint(sf) : 0
        MW.header := header
        g.SetFont("s9 c" Theme.Hex("muted"), "Consolas")
        MW.outputEdit := g.Add("Edit", "x0 y0 w10 h10 Hidden ReadOnly Multi -E0x200 +VScroll +0x100 Background" Theme.Hex("panel"))
        DllCall("uxtheme\SetWindowTheme", "Ptr", MW.outputEdit.Hwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)
        Loop names.Length
            MW.pages.Push(MW.NewPage())
        MW.BuildRun(MW.pages[1].root)
        MW.BuildRecord(MW.pages[2].root)
        MW.BuildDiscord(MW.pages[3].root)
        MW.BuildSettings(MW.pages[4].root)
        MW.BuildTools(MW.pages[5].root)
        MW.BuildTutorial(MW.pages[6].root)
        MW.BuildChanges(MW.pages[7].root)
        UltBot.onChange := Dashboard.onChange := UpdateHelper.onChange := ObjBindMethod(MW, "ConnectionChanged")
        MW.ConnectionChanged()
        Loop Files, A_ScriptDir "\Strategies\*.strat"
            MW.files.Push(MW.StratInfo(A_LoopFileFullPath))

        ; Gui creation/control attachment can queue size and paint events.
        ; Install their handlers only when the whole layout tree exists.
        MW.eventsInstalled := true
        UI_Install()
        MW.ready := true
        MW.sizeHandler := ObjBindMethod(MW, "WindowSize")
        g.OnEvent("Size", MW.sizeHandler)
        MW.Sync(true)
        MW.SelectPage(1, false)

        s := Gfx.S
        MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
        w := Min(Round(820*s), r-l), h := Min(Round(560*s), b-t)
        g.Show("Hide x" (l+(r-l-w)//2) " y" (t+(b-t-h)//2) " w" w " h" h)
        if show {
            BootStage.status := "1.3.3.10"
            BootStage.Begin()
            BootStage.Finish()
            WinSetTransparent(0, g)
        }
        MW.OnSize(0, w, h)
        if show {
            g.Show()
            MW.FadeWindow()
            MW.syncTimer := ObjBindMethod(MW, "Sync")
            SetTimer(MW.syncTimer, 180)
            if !MW.openedOnce
                try SoundPlay(A_ScriptDir "\ui\normal.wav")
            MW.openedOnce := true
        }
    }

    static NewPage() {
        g := Gui("-Caption -DPIScale +Parent" MW.gui.Hwnd " +0x02000000")
        g.BackColor := Theme.Hex("base"), g.MarginX := 0, g.MarginY := 0
        root := VBox(, 12, [24, 20, 22, 20])
        sf := Surface(g, root, true)
        sf.offX := 0, sf.offY := 0
        sf.background := (s) => Backdrop.PaintFor(s, s.offX, s.offY)
        sf.overlay := (s) => MW.pageShade ? Gfx.Rect(0, 0, s.lw, s.lh, Alpha(Theme.C("base"), MW.pageShade)) : 0
        return {gui: g, surface: sf, root: root, shown: false}
    }

    static BuildRun(root) {
        MW.strategyTitle := root.Add(Label("Choose a strategy", "title", true))
        MW.meta := root.Add(Label("", "caption", true))
        c := root.Add(Card("Required loadout"))
        MW.loadout := c.Add(Label("", "caption", true))
        c := root.Add(Card("Strategy file"))
        MW.Field(c, Strategy1Ctrl)
        row := c.Add(HBox(, 8))
        MW.Action(row, Tab1_Btn1)
        MW.Action(row, Tab1_Btn2)
        c := root.Add(Card("Strategy cycling · original 1.3.3a"))
        MW.Toggle(c, RotateStrategiesCtrl)
        c.Add(Label("Alternate strategy 1 and strategy 2 between matches. Auto-equip is required and enabled automatically.", "caption", true))
        c.Add(Label("Strategy 2", "caption"))
        MW.Field(c, Strategy2Ctrl)
        row := c.Add(HBox(, 8))
        MW.Action(row, Tab1_Btn3, "Browse strategy 2")
        MW.Action(row, Tab1_Btn4, "Clear strategy 2")
        row := c.Add(HBox(, 8))
        row.Add(Label("Swap after"), 1)
        field := MW.Field(row, SwapAmountCtrl)
        field.fixedW := 84
        sel := MW.RecorderSelect(row, SwapUnitCtrl)
        sel.fixedW := 100
        c := root.Add(Card("Run options"))
        MW.repeatHelp := c.Add(Label("No fixed match-count limit. Use F2 or dashboard stop controls to stop a run.", "caption", true))
        MW.Toggle(c, AutoEquipCtrl)
        MW.Toggle(c, ScrollDownForMapCtrl)
        row := c.Add(HBox(, 8))
        MW.mapScrollLabel := row.Add(Label("Map-list scroll steps"), 1)
        spin := MW.Spin(row, ScrollDownAmountUpDown, 5, 20)
        spin.fixedW := 84
        MW.Expose(ScrollDownAmountCtrl)
        spin.onChange := ObjBindMethod(MW, "Edit", ScrollDownAmountCtrl)
        spin.callback := ObjBindMethod(MW, "ScrollAmountArrow")
        MW.mapScrollHelp := c.Add(Label("5–20 mouse-wheel steps when opening the map/mode list. This does not limit matches.", "caption", true))
        row := c.Add(HBox(, 8))
        row.Add(Label("Timescale"), 1)
        sel := row.Add(Select(["OFF", "1.5x", "2x"], TimeScaleModeCtrl.Value, ObjBindMethod(MW, "Choose", TimeScaleModeCtrl)))
        sel.fixedW := 100
        MW.Expose(TimeScaleModeCtrl)
        MW.mirrors.Push({model: TimeScaleModeCtrl, view: sel, kind: "select"})
        c := root.Add(Card("Strategy modifiers"))
        for i, item in ModifierCheckboxes {
            if Mod(i, 2) = 1
                row := c.Add(HBox(, 12))
            MW.Toggle(row, item.ctrl, true)
            row.items[-1].stretch := 1
        }
        c.Add(Label("Active modifiers", "caption"))
        MW.Field(c, ModifiersTextCtrl)
        MW.Action(c, Tab1_ModSaveBtn)
    }

    static BuildDiscord(root) {
        root.Add(Label("Discord", "title"))
        remote := root.Add(Card("ULT Bot remote control"))
        remote.Add(Label("Run /remote link in Discord and paste the private code here. Only your linked Discord account can check status or stop a run. Start is optional.", "caption", true))
        MW.officialCode := remote.Add(Field("", "Private ULT1 connection code", {password: true, maxLength: 160}))
        MW.officialConsent := remote.Add(Check("Allow status and stop from my Discord account and remember this link on this PC", UltBot.CanUnlink
            , (*) => MW.ConnectionChanged()))
        MW.officialStart := remote.Add(Check("Allow remote Start", UltBot.allowStart, (widget, value) => UltBot.SetAllowStart(value)))
        MW.officialShot := remote.Add(Check("Allow requested screenshots of the foreground Roblox game only", UltBot.allowScreenshot
            , (widget, value) => UltBot.SetAllowScreenshot(value)))
        buttons := remote.Add(HBox(, 8))
        MW.officialLink := buttons.Add(Button("Link UltBot", (*) => MW.LinkUltBot(), "primary"), 1)
        MW.officialUnlink := buttons.Add(Button("Disconnect", (*) => UltBot.Unlink()), 1)
        MW.officialStatus := remote.Add(Label(UltBot.message, "caption", true))
        root.Add(Label("Discord webhook", "title"))
        c := root.Add(Card("Delivery"))
        c.Add(Label("Webhook URL", "caption"))
        MW.Field(c, WebhookLinkCtrl)
        MW.Toggle(c, WebhookEnabledCtrl)
        MW.Toggle(c, WebhookSepatateTriumphScreenshotsCtrl)
        c.Add(Label("Separate Triumph / Loss webhook", "caption"))
        MW.Field(c, WebhookLinkCtrl2)
        c := root.Add(Card("Webhook options"))
        for model in [SendCurrCtrl, DebugLogsCtrl, WebhookScreenshotsCtrl, WebhookTriumphScreenshotsCtrl]
            MW.Toggle(c, model)
        c := root.Add(Card("Webhook mentions"))
        c.Add(Label("User ID", "caption"))
        MW.Field(c, WebhookUserIDCtrl)
        for model in [WebhookPingOnWinCtrl, WebhookPingOnLossCtrl, WebhookPingOnTimescaleCtrl]
            MW.Toggle(c, model)
    }

    static RecorderSelect(root, model) {
        MW.Expose(model)
        view := root.Add(Select(RecorderItems(model), model.Value, ObjBindMethod(MW, "Choose", model)))
        MW.mirrors.Push({model: model, view: view, kind: "select"})
        return view
    }

    static BuildRecord(root) {
        global PlaceTowerKey, UpgradeTowerKey, AlignCameraKey, ChangeDJTrackKey, SellTowerKey
            , DeleteTowerRecordingKey, RecordInputsKey, HoloKey, ChangeTargetsKey
        root.Add(Label("Record a strategy", "title"))
        root.Add(Label("Original 1.3.3a recorder with the 1.3.3.10 replay engine. Join the match first. F places a tower; click a tower indicator to record its upgrades. F2 stops and offers to save.", "caption", true))
        MW.recordStatus := root.Add(Label("Not recording.", "caption", true))
        c := root.Add(Card("Match configuration"))
        c.Add(Label("Map", "caption"))
        MW.RecorderSelect(c, RecMapsD)
        c.Add(Label("Mode", "caption"))
        MW.RecorderSelect(c, RecDiffCtrl)
        c.Add(Label("Required towers (comma-separated)", "caption"))
        MW.Field(c, RecTowersCtrl)
        c := root.Add(Card("Modifiers"))
        for i, name in RecorderItems(RecModifiersCtrl, true) {
            if Mod(i, 2) = 1
                row := c.Add(HBox(, 10))
            row.Add(Check(name, SendMessage(0x187, i - 1, 0, RecModifiersCtrl) > 0, RecorderModifier.Bind(i)), 1)
        }
        c := root.Add(Card("Strategy options"))
        for model in [RecAutoChainCtrl, RecAutoCaravanCtrl, RecAutoDropCtrl, RecAutoSkipCtrl, RecAbilitySpamCtrl]
            MW.Toggle(c, model)
        c := root.Add(Card("Movement"))
        MW.Toggle(c, RecMoveCtrl)
        c.Add(Label("Direction", "caption"))
        MW.RecorderSelect(c, RecMoveDirCtrl)
        c.Add(Label("Duration (ms)", "caption"))
        MW.Field(c, RecMoveDurCtrl)
        c := root.Add(Card("Recording shortcuts"))
        c.Add(Label("Original defaults: F place; Ctrl+U upgrade; Ctrl+T align; Ctrl+D DJ; Ctrl+X sell; Ctrl+B remove recorded tower; Ctrl+Shift+E raw inputs; Ctrl+Alt+H clone; Ctrl+grave target. Ctrl+Z undo. Right-click an indicator to choose its upgrade path.", "caption", true))
        c.Add(Label("Saved recording shortcuts use your existing RecordingHotkeys settings. Raw inputs are accepted only while Roblox is foreground.", "caption", true))
        c.Add(Label("Enter a shortcut such as Ctrl+P or Ctrl+Shift+E, then press Enter or leave the field. Existing scan-code bindings are kept until you change them. F1/F2 stay reserved; conflicting shortcuts are rejected.", "caption", true))
        MW.recordShortcuts := Map()
        for spec in [["PlaceTowerKey", "Place tower"], ["UpgradeTowerKey", "Record upgrade"], ["AlignCameraKey", "Align camera"]
            , ["ChangeDJTrackKey", "DJ track"], ["SellTowerKey", "Sell tower"], ["DeleteTowerRecordingKey", "Remove recorded tower"]
            , ["RecordInputsKey", "Raw inputs"], ["HoloKey", "Clone tower"], ["ChangeTargetsKey", "Change target"]] {
            row := c.Add(HBox(, 8))
            row.Add(Label(spec[2]), 1)
            name := spec[1]
            keyField := row.Add(Field(RecorderShortcutDisplay(%name%), "e.g. Ctrl+P", {fixedW: 180, maxLength: 64}))
            keyField.onCommit := RecorderShortcutCommit.Bind(name)
            MW.recordShortcuts[name] := keyField
        }
        row := root.Add(HBox(, 10))
        MW.recordStart := MW.Action(row, Tab2_Btn1, "Start recording", "primary")
        MW.recordStop := MW.Action(row, Tab2_Btn2, "Stop / save")
    }

    static BuildSettings(root) {
        root.Add(Label("Settings", "title"))
        update := root.Add(Card("Verified updates"))
        MW.updateQuiet := update.Add(Check("Download verified updates quietly when enabled", UpdateHelper.enabled
            , (widget, value) => MW.UpdatePreference(widget, value)))
        update.Add(Label("Installation asks for approval and creates a clean version folder. Your current copy, settings and strategies stay safe; nothing restarts automatically.", "caption", true))
        MW.updateReview := update.Add(Button("Check / review update", (*) => UpdateHelper.Begin(true)))
        MW.updateStatus := update.Add(Label(UpdateHelper.message, "caption", true))
        dash := root.Add(Card("Connect to Dashboard"))
        dash.Add(Label("Pair this PC using the website code. Your dashboard can show activity and device health, start/stop runs, manage strategies, schedule cooldowns and request closing a listed app. Disconnect here to revoke access.", "caption", true))
        MW.dashboardCode := dash.Add(Field("", "Dashboard code (XXXX-XXXX)", {password: true, maxLength: 24}))
        buttons := dash.Add(HBox(, 8))
        MW.dashboardLink := buttons.Add(Button("Connect", (*) => MW.LinkDashboard(), "primary"), 1)
        MW.dashboardUnlink := buttons.Add(Button("Disconnect", (*) => Dashboard.Disconnect()), 1)
        MW.dashboardStatus := dash.Add(Label(Dashboard.message, "caption", true))
        c := root.Add(Card("TDS keybinds"))
        for spec in [["Call of Arms", ChainKeyCtrl], ["Drop the Beat", BeatKeyCtrl], ["Support Caravan", CaravanKeyCtrl]
            , ["Raise the Dead", RaiseDeadKeyCtrl, Tab5_Help12], ["Hologram", HologramKeyCtrl], ["Reposition", RepoKeyCtrl, Tab5_Help11]
            , ["Upgrade", UpgradeTowerGCtrl], ["Bottom upgrade", UpgradeTowerGBCtrl], ["Cancel placement", CancelPlacementKeyCtrl]] {
            row := c.Add(HBox(, 8))
            row.Add(Label(spec[1]), 1)
            MW.Field(row, spec[2], {maxLength: 1, fixedW: 68})
            if spec.Length = 3
                MW.Action(row, spec[3])
        }
        c := root.Add(Card("Macro settings"))
        for spec in [[UseUpgradeHCtrl, Tab5_Help6], [UseRestartBtnCtrl, Tab5_Help4], [UsePlayAgainBtnCtrl, Tab5_Help5], [CheckTheMapCtrl, Tab5_Help7]] {
            row := c.Add(HBox(, 8))
            MW.Toggle(row, spec[1])
            row.items[-1].stretch := 1
            MW.Action(row, spec[2])
        }
        for model in [AutoCloseChatCtrl, UseNumbersForHotbarCtrl, CollectPlaytimeRewardsCtrl, AlwaysOnTopCtrl]
            MW.Toggle(c, model)
        c := root.Add(Card("Timing"))
        c.Add(Label("If 2x misses placements, try 1.5x. If clicks are missed, raise mouse or key delay gradually.", "caption", true))
        for spec in [["Upgrade delay (ms)", UpgradeDelayCtrl, 3], ["Scroll delay (ms)", ScrollDelayCtrl, 4]] {
            row := c.Add(HBox(, 8))
            row.Add(Label(spec[1]), 1)
            MW.Field(row, spec[2], {number: true, maxLength: spec[3], fixedW: 90})
        }
        for spec in [["Mouse speed", MouseSpeedUpDown, 1, 3, ""], ["Mouse delay", MouseDelayUpDown, 3, 75, "ms"], ["Key delay", KeyDelayUpDown, 5, 100, "ms"]] {
            row := c.Add(HBox(, 8))
            row.Add(Label(spec[1]), 1)
            MW.Spin(row, spec[2], spec[3], spec[4], spec[5]).fixedW := 90
        }
        c := root.Add(Card("Private server"))
        MW.Toggle(c, UseVipServerCtrl)
        c.Add(Label("VIP server link", "caption"))
        MW.Field(c, VipLinkCtrl)
    }

    static ClearCode(field) {
        field.Clear()
        if field.ctrl
            try SendMessage(0xCD, 0, 0, field.ctrl) ; EM_EMPTYUNDOBUFFER
    }

    static LinkUltBot() {
        if !UltBot.CanLink || !MW.officialConsent.checked
            return
        code := MW.officialCode.Text
        MW.ClearCode(MW.officialCode)
        UltBot.Link(code, MW.officialStart.checked, MW.officialShot.checked)
    }

    static LinkDashboard() {
        if !Dashboard.CanConnect
            return
        code := MW.dashboardCode.Text
        MW.ClearCode(MW.dashboardCode)
        Dashboard.Connect(code)
    }

    static UpdatePreference(widget, value) {
        if !UpdateHelper.SetEnabled(value)
            widget.SetChecked(UpdateHelper.enabled)
    }

    static ConnectionChanged() {
        prior := A_IsCritical
        Critical("On")
        try MW.UpdateConnectionViews()
        finally Critical(prior ? prior : "Off")
    }

    static UpdateConnectionViews() {
        if !MW.gui || MW.closing
            return
        MW.officialStatus.SetText(UltBot.message)
        MW.officialCode.Enable(UltBot.CanLink)
        MW.officialConsent.Enable(UltBot.CanLink)
        MW.officialLink.Enable(UltBot.CanLink && MW.officialConsent.checked)
        MW.officialUnlink.Enable(UltBot.CanUnlink)
        MW.officialStart.Enable(UltBot.CanLink || UltBot.CanUnlink)
        MW.officialShot.Enable(UltBot.CanLink || UltBot.CanUnlink)
        if UltBot.CanUnlink {
            MW.officialStart.SetChecked(UltBot.allowStart)
            MW.officialShot.SetChecked(UltBot.allowScreenshot)
        }
        MW.dashboardStatus.SetText(Dashboard.message)
        MW.dashboardCode.Enable(Dashboard.CanConnect)
        MW.dashboardLink.Enable(Dashboard.CanConnect)
        MW.dashboardUnlink.Enable(Dashboard.CanDisconnect)
        MW.updateStatus.SetText(UpdateHelper.message)
        MW.updateReview.Enable(!UpdateHelper.checking)
    }

    static BuildTools(root) {
        root.Add(Label("Tools", "title"))
        c := root.Add(Card("Spin wheel"))
        MW.Action(c, Auto_Spin, "Open auto-spin tool")
        c := root.Add(Card("Consumable crates"))
        MW.Action(c, Auto_Consum, "Open consumable tool")
    }

    static BuildTutorial(root) {
        root.Add(Label("Setup tutorial", "title"))
        c := root.Add(Card("Prerequisites"))
        for model in TutorialTab {
            if (model.Type != "Text")
                continue
            if MW.Has(model, "Click")
                MW.Action(c, model)
            else if model.Text != ""
                c.Add(Label(StrReplace(model.Text, "&&", "&"), "caption", true))
        }
        MW.Action(root, version_text, "Check for updates")
    }

    static BuildChanges(root) {
        root.Add(Label("What's changed", "title"))
        row := root.Add(HBox(, 8))
        for spec in [[Change_BtnUp, "Scroll up", -1], [Change_BtnDn, "Scroll down", 1]] {
            MW.Expose(spec[1])
            row.Add(Button(spec[2], ObjBindMethod(MW, "ScrollChanges", spec[1], spec[3])))
        }
        for item in ChangelogCtrls {
            if item.type = "cat" {
                c := root.Add(Card(Trim(item.data.title)))
                continue
            }
            MW.Action(c, item.header)
            detail := c.Add(Label(item.data.cause "`n" item.data.fix, "caption", true))
            detail.visible := item.data.expanded
            MW.sections.Push({data: item.data, detail: detail})
        }
        MW.Action(root, version_text, "Check for updates")
    }

    static ScrollChanges(ctrl, dir, *) {
        MW.Invoke(ctrl)
        sf := MW.pages[7].surface
        sf.ScrollTo(sf.scrollY + dir * 65)
    }

    static StratInfo(path) {
        SplitPath(path, , , , &title)
        name := IniRead(path, "Settings", "title", title)
        mapName := IniRead(path, "Settings", "map", "")
        mode := IniRead(path, "Settings", "difficulty", "")
        towers := IniRead(path, "Settings", "requiredTowers", "")
        return {path: path, title: name, map: mapName, mode: mode, towers: towers}
    }

    static RefreshList(*) {
        if !MW.gui
            return
        selected := Strategy1Ctrl.Text, query := Trim(MW.search.Text), chosen := 0
        src := MW.files.Clone(), rows := [], labels := [], MW.visibleFiles := []
        if selected != "" && FileExist(selected) {
            seen := false
            for item in src
                if item.path = selected
                    seen := true
            if !seen
                try src.Push(MW.StratInfo(selected))
        }
        for item in src {
            if query != "" && !InStr(item.title " " item.map " " item.mode, query)
                continue
            MW.visibleFiles.Push(item)
            rows.Push({item: item, slots: ""})
            labels.Push(item.title)
            if (item.path = selected)
                chosen := rows.Length
        }
        MW.list.SetRows(rows, chosen)
        MW.compactStrategies.SetItems(labels)
        MW.compactStrategies.Choose(chosen)
    }

    static SelectStrat(i, *) {
        if (i >= 1 && i <= MW.visibleFiles.Length)
            MW.Assign(Strategy1Ctrl, MW.visibleFiles[i].path)
    }

    static Sync(force := false, *) {
        prior := A_IsCritical
        Critical("On")
        try MW.SynchronizeView(force)
        finally Critical(prior ? prior : "Off")
    }

    static SynchronizeView(force) {
        if !MW.LayoutReady()
            return
        UpdateStrategyRotationControls()
        Tab2_Btn1.Enabled := !Recording && !RunningStrategy
        Tab2_Btn2.Enabled := Recording
        MW.recordStatus.SetText(Recording ? "Recording · " RecordedSteps.Length " strategy steps" (MacroRecording ? " · raw inputs ON" : "") : "Not recording.")
        for entry in MW.mirrors {
            model := entry.model, view := entry.view
            if (view.enabled != model.Enabled)
                view.Enable(model.Enabled)
            switch entry.kind {
                case "field":
                    if (view.Text != model.Text)
                        view.Text := model.Text
                case "toggle": view.SetChecked(model.Value)
                case "select":
                    if (view.index != model.Value)
                        view.Choose(model.Value)
                case "spin":
                    if (view.Value != model.Value)
                        view.Value := model.Value
                case "buttonText":
                    if (view.text != model.Text)
                        view.SetText(model.Text)
            }
        }
        for row in MW.sections {
            if (row.detail.visible != row.data.expanded) {
                row.detail.visible := row.data.expanded
                MW.pages[7].surface.Relayout()
            }
        }
        top := !!AlwaysOnTop
        if (force || MW.topmost != top) {
            MW.topmost := top
            MW.gui.Opt(top ? "+AlwaysOnTop" : "-AlwaysOnTop")
        }
        path := Strategy1Ctrl.Text
        if (force || MW.selectedPath != path) {
            MW.selectedPath := path
            info := ""
            if (path != "" && FileExist(path))
                try info := MW.StratInfo(path)
            MW.strategyTitle.SetText(IsObject(info) ? info.title : "Choose a strategy")
            MW.meta.SetText(IsObject(info) ? info.map "  ·  " info.mode : "Browse or select a strategy from the list.")
            MW.loadout.SetText(IsObject(info) && info.towers != "" ? StrReplace(info.towers, ",", "`n") : "No loadout selected.")
            MW.RefreshList()
        }
        line := LogLines.Length ? LogLines[-1] : "Ready."
        if (force || line != MW.lastLog || LogLines.Length != MW.logCount) {
            MW.lastLog := line, MW.logCount := LogLines.Length
            MW.outputBtn.SetText("Output   " line)
            body := ""
            for text in LogLines
                body .= text "`r`n"
            MW.outputEdit.Value := body
        }
    }

    static SelectPage(i, animate := true, *) {
        prior := A_IsCritical
        Critical("On")
        try MW.SelectPageView(i, animate)
        finally Critical(prior ? prior : "Off")
    }

    static SelectPageView(i, animate) {
        if (!MW.LayoutReady() || !MW.PageAt(i))
            return
        if (MW.page != i)
            MW.SetKeyboardFocus("")
        MW.page := i
        if (i != 2)
            MW.Invoke(TabCtrl[i > 2 ? i - 1 : i])
        for k, tab in MW.tabs
            tab.SetChecked(k = i)
        MW.compactNav.Choose(i)
        MW.ultraNav.Choose(i)
        MW.PlacePages()
        if animate && !MW.nativeTest && !MW.booting
            MW.FadePage()
    }

    static LayoutReady() => MW.ready && !MW.closing && IsObject(MW.gui) && IsObject(MW.surface) && IsObject(MW.layout)

    static PageAt(index) {
        if (!IsInteger(index) || index < 1 || index > MW.pages.Length || !MW.pages.Has(index))
            return ""
        page := MW.pages[index]
        if (!IsObject(page) || !page.HasOwnProp("surface") || !page.HasOwnProp("gui")
            || !IsObject(page.surface) || !IsObject(page.gui) || !DllCall("IsWindow", "Ptr", page.surface.hwnd))
            return ""
        return page
    }

    static WindowSize(gui, minmax, w, h) {
        if !MW.LayoutReady() || gui != MW.gui || minmax = -1 || w < 1 || h < 1
            return
        MW.resizeQueued := [gui.Hwnd, minmax, w, h]
        if !MW.resizeTimer
            MW.resizeTimer := ObjBindMethod(MW, "FlushResize")
        if !MW.resizeArmed {
            MW.resizeArmed := true
            SetTimer(MW.resizeTimer, -16)
        }
    }

    static FlushResize(*) {
        MW.resizeArmed := false
        queued := MW.resizeQueued, MW.resizeQueued := ""
        if IsObject(queued) && MW.LayoutReady() && MW.gui.Hwnd = queued[1]
            MW.OnSize(queued[2], queued[3], queued[4])
    }

    static OnSize(minmax, w, h) {
        if (minmax = -1 || w < 1 || h < 1 || !MW.LayoutReady() || MW.layoutBusy)
            return
        prior := A_IsCritical
        Critical("On")
        try MW.ApplySize(minmax, w, h)
        finally Critical(prior ? prior : "Off")
    }

    static ApplySize(minmax, w, h) {
        if !MW.LayoutReady()
            return
        key := w "|" h "|" minmax "|" MW.booting "|" MW.outputVisible
        if (key = MW.sizeKey && MW.surface.dc)
            return
        MW.sizeKey := key
        MW.compact := w/Gfx.S < 740, MW.ultra := w/Gfx.S < 520
        for b in MW.tabs
            b.visible := !MW.compact && !MW.booting
        MW.compactNav.visible := MW.compact && !MW.ultra && !MW.booting
        MW.ultraNav.visible := MW.ultra && !MW.booting
        MW.compactStrategies.visible := MW.compact && !MW.booting
        MW.sidebar.visible := !MW.compact && !MW.booting
        MW.headerTitle.visible := MW.booting
        MW.startBtn.visible := !MW.booting, MW.stopBtn.visible := !MW.booting
        MW.startBtn.text := MW.compact ? "" : "Start"
        MW.stopBtn.text := MW.compact ? "" : "Stop"
        MW.outputBar.visible := !MW.booting
        MW.maxBtn.icon := minmax = 1 ? "restore" : "max"
        MW.surface.Resize(w, h)
        MW.PlacePages(false)
        MW.surface.RenderNow()
    }

    static PlacePages(relayout := true) {
        if (!MW.LayoutReady() || MW.surface.pw < 2 || MW.layoutBusy)
            return
        prior := A_IsCritical
        Critical("On")
        MW.layoutBusy := true
        try MW.ApplyPageLayout(relayout)
        finally {
            MW.layoutBusy := false
            Critical(prior ? prior : "Off")
        }
    }

    static ApplyPageLayout(relayout) {
        if !MW.LayoutReady()
            return
        if relayout
            MW.surface.Relayout()
        r := MW.layout.pageRect, s := Gfx.S
        x := Round(r[1]*s), y := Round(r[2]*s), w := Max(1, Round(r[3]*s)), h := Max(1, Round(r[4]*s))
        target := MW.booting ? 0 : MW.page
        pane := MW.PageAt(target)
        if pane {
            moved := pane.surface.offX != x || pane.surface.offY != y
            pane.surface.offX := x, pane.surface.offY := y
            resized := pane.surface.pw != w || pane.surface.ph != h
            if (moved || resized)
                DllCall("SetWindowPos", "Ptr", pane.surface.hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", 0x14)
            if resized
                pane.surface.Resize(w, h)
            else if relayout
                pane.surface.Relayout()
            pane.surface.RenderNow()
            if (!pane.shown && !MW.nativeTest) {
                pane.gui.Show("NA x" x " y" y " w" w " h" h)
                pane.shown := true
            }
        }
        for i, unused in MW.pages {
            other := i != target ? MW.PageAt(i) : ""
            if (other && other.shown) {
                other.gui.Hide()
                other.shown := false
            }
        }
        o := MW.layout.outputRect
        if MW.outputVisible && !MW.booting {
            MW.outputEdit.Move(Round(14*s), Round((o[2]+6)*s), Max(1, Round((o[3]-20)*s)), Max(1, Round((o[4]-10)*s)))
            MW.outputEdit.Visible := true
        } else
            MW.outputEdit.Visible := false
    }

    static ToggleOutput() {
        MW.outputVisible := !MW.outputVisible
        MW.PlacePages()
    }
    static OutputHeight() => MW.surface.lh < 480 ? Min(130, Max(40, Floor((MW.surface.lh-100)/4))) : 130
    static ResizeEditable() => !MW.booting && !MW.closing
    static ToggleMaximize() => WinGetMinMax(MW.gui) = 1 ? MW.gui.Restore() : MW.gui.Maximize()

    static ShowWorkspace() {
        if !MW.LayoutReady()
            return
        prior := A_IsCritical
        Critical("On")
        try {
            if !MW.LayoutReady()
                return
            MW.booting := false
            g := MW.gui
            WinGetClientPos(, , &w, &h, g)
            MW.OnSize(WinGetMinMax(g), w, h)
        } finally Critical(prior ? prior : "Off")
    }

    static FadeWindow() {
        started := A_TickCount
        tick() {
            p := Min(1, (A_TickCount-started)/220)
            if MW.gui
                try WinSetTransparent(Round(245*(1-(1-p)**3)), MW.gui)
            if (p >= 1) {
                SetTimer(tick, 0)
                MW.fadeTimer := ""
            }
        }
        MW.fadeTimer := tick
        SetTimer(tick, 15)
    }

    static FadePage() {
        if MW.pageTimer
            SetTimer(MW.pageTimer, 0)
        started := A_TickCount
        tick() {
            pane := MW.LayoutReady() ? MW.PageAt(MW.page) : ""
            if !pane {
                SetTimer(tick, 0)
                MW.pageTimer := ""
                return
            }
            p := Min(1, (A_TickCount-started)/90)
            MW.pageShade := Round(38*(1-p)**3)
            pane.surface.Invalidate()
            if (p >= 1) {
                SetTimer(tick, 0)
                MW.pageTimer := ""
            }
        }
        MW.pageTimer := tick
        SetTimer(tick, 15)
    }

    static SetKeyboardFocus(w) {
        if MW.keyboardFocus
            MW.keyboardFocus.Invalidate()
        MW.keyboardFocus := w
        if !w
            return
        w.surface.EnsureVisible(w)
        if w is Field
            w.Focus()
        else
            DllCall("SetFocus", "Ptr", w.surface.hwnd)
        w.Invalidate()
    }

    static KeyboardKey(key, hwnd) {
        pane := MW.LayoutReady() && !MW.booting ? MW.PageAt(MW.page) : ""
        if (!pane || (hwnd != MW.gui.Hwnd && !DllCall("IsChild", "Ptr", MW.gui.Hwnd, "Ptr", hwnd)))
            return false
        items := [], current := 0
        for root in [MW.header, MW.ultraNav, MW.compactStrategies, MW.sidebar, pane.root, MW.outputBar]
            root.CollectFocus(items)
        for i, w in items
            if ((w is Field && w.ctrl.Hwnd = hwnd) || (!(w is Field) && w == MW.keyboardFocus && w.surface.hwnd = hwnd)) {
                current := i
                break
            }
        if (key = 9 && items.Length) {
            next := GetKeyState("Shift", "P") ? (current <= 1 ? items.Length : current-1) : (current >= items.Length ? 1 : current+1)
            MW.SetKeyboardFocus(items[next])
            return true
        }
        if (!current || items[current] is Field)
            return false
        w := items[current]
        if (w is StrategyList && (key = 38 || key = 40)) {
            i := Min(w.rows.Length, Max(1, w.index + (key = 38 ? -1 : 1)))
            if i
                w.onSelect.Call(i)
            return true
        }
        if !(w is StrategyList) && (key = 13 || key = 32 || (w is Select && key = 40)) {
            w.OnClick(w.x+w.w/2, w.y+w.h/2)
            return true
        }
        return false
    }

    static Hide() => MW.Dispose()
    static Dispose(*) {
        if !MW.gui || MW.closing
            return 0
        prior := A_IsCritical
        Critical("On")
        try MW.DestroyView()
        finally {
            MW.closing := false
            Critical(prior ? prior : "Off")
        }
        return 0
    }

    static DestroyView() {
        ; Invalidate the live view before destroying any child HWND. Queued
        ; Size/boot callbacks must not see a partially disposed page array.
        MW.ready := false
        MW.closing := true
        if MW.resizeTimer
            SetTimer(MW.resizeTimer, 0)
        MW.resizeQueued := "", MW.resizeArmed := false, MW.sizeKey := ""
        UltBot.onChange := Dashboard.onChange := UpdateHelper.onChange := ""
        g := MW.gui, sf := MW.surface, pages := MW.pages
        MW.gui := "", MW.surface := "", MW.layout := "", MW.pages := [], MW.page := 0
        if MW.sizeHandler
            g.OnEvent("Size", MW.sizeHandler, 0)
        for timer in [MW.syncTimer, MW.fadeTimer, MW.pageTimer, BootStage.timer]
            if timer
                SetTimer(timer, 0)
        try SelectPopup.Close()
        if MW.eventsInstalled {
            UI_Uninstall()
            MW.eventsInstalled := false
        }
        for pane in pages {
            if !IsObject(pane)
                continue
            pane.surface.Destroy()
            pane.gui.Destroy()
        }
        if IsObject(sf)
            sf.Destroy()
        g.Destroy()
        Backdrop.Dispose()
        Backdrop.fast := false
        Gfx.Disposable(MW.logo)
        Gfx.Shutdown()
        ; Keep the original form/event bindings, but never reuse widgets or
        ; child HWNDs from a disposed view when the user opens the tray again.
        MW.mirrors := [], MW.sections := [], MW.tabs := []
        MW.files := [], MW.visibleFiles := [], MW.keyboardFocus := ""
        MW.sizeHandler := "", MW.resizeTimer := "", MW.syncTimer := "", MW.fadeTimer := "", MW.pageTimer := ""
        MW.logo := 0, MW.pageShade := 0, MW.layoutBusy := false, MW.booting := false
        MW.lastLog := "", MW.logCount := -1, MW.topmost := "", MW.outputVisible := false
        return 0
    }
}
