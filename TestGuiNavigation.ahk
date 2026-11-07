#Requires AutoHotkey v2.0 64-bit
#Warn All, Off
#NoTrayIcon
#Include Main.ahk

Need(ok, message) {
    if !ok
        throw Error(message)
}

FindReachableImport() {
    found := []
    for widget in MW.TabOrder()
        if (widget is Button && widget.icon = "plus"
            && MW.layout.HitAll(widget.x + widget.w / 2, widget.y + widget.h / 2) == widget)
            found.Push(widget)
    return found
}

FindReachableSearch() {
    for widget in MW.TabOrder()
        if (widget is Field && widget.placeholder = "Search strategies"
            && widget.ctrl && (DllCall("GetWindowLong", "Ptr", widget.ctrl.Hwnd, "Int", -16, "UInt") & 0x10000000)
            && MW.layout.HitAll(widget.x + widget.w / 2, widget.y + widget.h / 2) == widget)
            return widget
    return ""
}

ReplaceSearch(widget, text) {
    ; Replace the selection in the real edit control without desktop input.
    SendMessage(0xB1, 0, -1, widget.ctrl) ; EM_SETSEL
    SendMessage(0xC2, 1, StrPtr(text), widget.ctrl) ; EM_REPLACESEL
    Sleep(-1)
}

; Build real widgets and dispatch local callbacks with the top-level HWND hidden.
; Do not install hotkeys or click controls that launch Roblox or contact a service.
try {
    Store.root := A_Temp "\UM-HiddenGui-" DllCall("GetCurrentProcessId", "UInt")
    Store.strategies := Store.root "\strategies"
    Store.recordings := Store.root "\recordings"
    Store.settings := Store.Defaults()
    Store.settings["motion"] := false
    Store.settings["updatePrompts"] := false
    Gfx.Init()
    UI_Install()
    MW.Build()
    BootStage.Begin()
    MW.gui.Show("Hide w" Round(820 * Gfx.S) " h" Round(560 * Gfx.S))
    MW.SelectPage(1)
    MW.CheckEngine(true)
    Need(!MW.booting && MW.engineReady && MW.startBtn.visible && MW.stopBtn.visible
        && !MW.stopBtn.IsEnabled() && MW.outputBar.visible, "Idle startup publishes the toolbar and does not enable Stop")
    for index, tab in MW.tabs {
        Need(tab.visible && tab.IsEnabled(), "Wide navigation exposes tab " index)
        tab.OnClick(0, 0)
        Need(MW.page = index && tab.checked && MW.pages[index].shown, "Click opens the correct page: " index)
    }
    MW.Log("QA isolated output witness")
    MW.outputBtn.OnClick(0, 0)
    Need(MW.outputVisible && InStr(MW.outputEdit.Value, "QA isolated output witness"), "Output reveals the full local log")
    MW.outputBtn.OnClick(0, 0)
    Need(!MW.outputVisible, "Output toggles shut")
    wideImport := FindReachableImport()
    Need(wideImport.Length = 1, "Wide layout has one mouse- and keyboard-reachable Import Strategy button")
    firstPath := Store.strategies "\Alpha original.strat"
    secondPath := Store.strategies "\Beta Lab.strat"
    MW.items := [{path:firstPath, title:"Same title", map:"Example", mode:"Easy", steps:2}
        , {path:secondPath, title:"Same title", map:"Example", mode:"Easy", steps:2}]
    MW.loadoutCache := Map(firstPath, "Scout", secondPath, "Scout")
    MW.reasonCache := Map(firstPath, "", secondPath, "")
    MW.FilterLibrary()
    wideSearch := FindReachableSearch()
    Need(IsObject(wideSearch), "Wide layout has an editable strategy search")
    ReplaceSearch(wideSearch, "Alpha")
    Need(MW.visibleItems.Length = 1 && MW.current.path = firstPath, "Wide search filters by filename")
    MW.OnSize(0, Round(560 * Gfx.S), Round(500 * Gfx.S))
    Need(MW.compactNav.visible && !MW.tabs[1].visible, "Compact mode exposes the navigation dropdown")
    compactImport := FindReachableImport()
    Need(compactImport.Length = 1, "Compact layout keeps Import Strategy reachable after hiding the sidebar")
    Need(compactImport[1].callback == wideImport[1].callback, "Both sizes invoke the same strategy import action")
    compactSearch := FindReachableSearch()
    Need(IsObject(compactSearch) && compactSearch.Text == "Alpha" && MW.current.path = firstPath,
        "Narrowing keeps the active search visible and editable")
    ReplaceSearch(compactSearch, "Beta Lab")
    Need(MW.compactStrategies.Count = 1 && MW.current.path = secondPath, "Editing the compact search filters its strategy picker")
    MW.compactNav.Choose(4, true)
    Need(MW.page = 5 && MW.pages[5].shown, "Compact Tools selection routes to Tools")
    MW.compactNav.Choose(6, true)
    Need(MW.page = 4 && MW.pages[4].shown, "Compact Discord selection routes to Discord")
    name := "same-long-filename-prefix-shared-across-strategies Lab.strat"
    shortened := Gfx.Elide(name, Gfx.Font(13), 130, true)
    Need(SubStr(shortened, 1, 1) = "…" && InStr(shortened, "Lab.strat"), "Narrow library keeps the distinguishing filename suffix")
    MW.OnSize(0, Round(460 * Gfx.S), Round(500 * Gfx.S))
    Need(MW.ultraNav.visible && FindReachableImport().Length = 1, "Ultra-compact layout also exposes Import Strategy")
    Need(FindReachableSearch() == compactSearch, "Ultra-compact layout keeps the search editable")
    ReplaceSearch(compactSearch, "")
    Need(MW.compactStrategies.Count = 2 && MW.current.path = secondPath, "Clearing compact search restores the library without changing selection")
    ReplaceSearch(compactSearch, "Beta Lab")
    MW.OnSize(0, Round(820 * Gfx.S), Round(560 * Gfx.S))
    restoredImport := FindReachableImport()
    Need(restoredImport.Length = 1 && restoredImport[1] == wideImport[1], "Widening restores the sidebar import route")
    Need(FindReachableSearch() == wideSearch && wideSearch.Text == "Beta Lab" && MW.list.rows.Length = 1
        && MW.current.path = secondPath, "Widening restores the same active query, result and selection")
    Need(MW.HasOwnProp("featureFindBtn") && MW.featureFindBtn.IsEnabled(),
        "The workspace exposes a separate feature finder")
    for width in [820, 560, 460] {
        MW.OnSize(0, Round(width * Gfx.S), Round(500 * Gfx.S))
        featureBtn := MW.featureFindBtn
        Need(MW.layout.HitAll(featureBtn.x + featureBtn.w/2, featureBtn.y + featureBtn.h/2) == featureBtn,
            "Feature finder is reachable at " width)
    }
    finder := MW.ShowFeatureFinder(false)
    finder.query.Value := "servidor privado"
    MW.FilterFeatureFinder(finder)
    Need(finder.rows.Length = 1 && !PrivateServer.Enabled, "Feature search accepts Spanish aliases without toggling settings")
    MW.OpenFeatureMatch(finder)
    Need(MW.page = 6 && !PrivateServer.Enabled && MW.current.path = secondPath, "Opening a result only reveals its control")
    finder := MW.ShowFeatureFinder(false)
    finder.query.Value := "exportar perfil"
    MW.FilterFeatureFinder(finder)
    Need(finder.rows.Length = 1, "Feature search finds an Advanced Settings control")
    MW.OpenFeatureMatch(finder)
    Need(MW.page = 6 && MW.moreFrame.visible && !MW.featureFinder,
        "Opening an advanced result expands Settings without running its action")
    finder := MW.ShowFeatureFinder(false)
    finder.query.Value := "irrelevant nonsense"
    MW.FilterFeatureFinder(finder)
    MW.OpenFeatureMatch(finder)
    Need(!finder.rows.Length && MW.featureFinder == finder && MW.page = 6, "No-match Enter leaves the workspace unchanged")
    MW.CloseFeatureFinder(finder)
    finder := MW.ShowFeatureFinder(false)
    finder.query.Value := "atajos"
    MW.FilterFeatureFinder(finder)
    MW.OpenFeatureMatch(finder)
    Need(MW.page = 6 && MW.keyboardFocus == MW.bindingInputs["align"],
        "Recording shortcuts reveals and focuses the actual binding")
    MW.SelectPage(1)
    MW.reasonCache[secondPath] := "QA cached denial"
    MW.UpdateControls()
    Need(MW.startBtn.IsEnabled(), "Cached denial does not stop the mouse from rechecking Start")
    ReplaceSearch(wideSearch, "")
    firstPath := Store.strategies "\Same.strat"
    secondPath := Store.recordings "\Same.strat"
    MW.items := [{path:firstPath, title:"Same title", map:"Example", mode:"Easy", steps:2}
        , {path:secondPath, title:"Same title", map:"Example", mode:"Easy", steps:2}]
    MW.loadoutCache := Map(firstPath, "Scout", secondPath, "Scout")
    MW.reasonCache := Map(firstPath, "", secondPath, "")
    MW.FilterLibrary()
    Need(MW.list.rows[1].caption != MW.list.rows[2].caption
        && InStr(MW.list.rows[1].caption, "Same.strat") && InStr(MW.list.rows[2].caption, "Same.strat"),
        "Same filenames from different library roots remain distinguishable")
    FileAppend("PASS: native startup, navigation, compact import and synchronized strategy search, Output and filename suffix.`n", "*")
    ExitApp(0)
} catch as e {
    FileAppend("FAIL: " e.Message "`n" e.Stack "`n", "**")
    ExitApp(1)
}
