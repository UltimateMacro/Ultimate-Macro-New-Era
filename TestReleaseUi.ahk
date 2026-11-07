#Requires AutoHotkey v2.0
#Warn All, Off
#NoTrayIcon
#Include Main.ahk

Need(ok, message) {
    if !ok
        throw Error(message)
}
class UiProbe {
    text := "", rows := []
    SetText(value) => this.text := value
    SetRows(value, *) => this.rows := value
    EnsureVisible(*) => 0
}
try {
    Store.settings := Store.Defaults()
    Need(InStr(MW.RecordingGuide({active:false,draft:false}),"Record as you play before starting"),
        "Idle recording explains normal play opt-in")
    Need(InStr(MW.RecordingGuide({active:true,aligned:false}),Store.settings["recordBindings"]["align"]),
        "Before capture, show the current camera alignment shortcut")
    Need(InStr(MW.RecordingGuide({active:true,aligned:true,passive:true}),"Play normally")
        && InStr(MW.RecordingGuide({active:true,aligned:true,passive:false}),"Regular clicks alone"),
        "Active capture guidance distinguishes supported inputs from shortcut recording")
    timing := Store.DEFAULT_RUNTIME.Clone()
    timing.Delete("extraUiWait"), timing.Delete("preJoinDelay"), timing.Delete("keyDelayMs")
    timing := Store.ValidRuntime(timing)
    Need(timing["extraUiWait"] = 0 && timing["preJoinDelay"] = 0 && timing["keyDelayMs"] = 20,
        "Existing profiles keep the default timing after migration")
    timing["extraUiWait"] := 91
    rejected := false
    try Store.ValidRuntime(timing)
    catch
        rejected := true
    Need(rejected, "Out-of-range UI wait cannot reach the engine")
    popup := PopupList({labels:["OFF","1.5x","2x"],index:3},28)
    popup.h := 84
    popup.Scroll(1)
    Need(popup.Rows() = 3 && popup.top = 0,
        "A fully visible three-choice popup cannot hide its first option")
    toolkitSource := FileRead(A_ScriptDir "\ui\Toolkit.ahk", "UTF-8")
    popupSource := SubStr(toolkitSource, InStr(toolkitSource,"class SelectPopup"))
    Need(InStr(popupSource,"surf.Resize(pw, ph)") < InStr(popupSource,"list.Scroll(Max(0, sel.index"),
        "Dropdown scroll is clamped only after its real height is arranged")
    Need(!GameRecovery.CandidateStable("",1000) && !GameRecovery.CandidateStable("window-a|800x599",1000)
        && !GameRecovery.CandidateStable("window-a|800x599",2999)
        && GameRecovery.CandidateStable("window-a|800x599",3000),
        "Replacement game geometry must settle before docking")
    Need(!GameRecovery.CandidateStable("window-a|1076x993",3100)
        && !GameRecovery.CandidateStable("window-b|1076x993",5100)
        && !GameRecovery.CandidateStable("",7100),
        "A resize, replacement window or missing client resets readiness")
    Need(GameRecovery.LayoutMatches(1,[10,20,800,600],1,[0,0,1920,1040])
        && GameRecovery.LayoutMatches(0,[10,20,800,600],0,[11,20,800,600])
        && !GameRecovery.LayoutMatches(0,[10,20,800,600],0,[10,20,1078,995])
        && !GameRecovery.LayoutMatches(1,[10,20,800,600],0,[10,20,800,600]),
        "Undocked relaunch preserves maximized mode or the confirmed windowed bounds")
    for row in Engine.Schema() {
        if (row[1] = "Options" && row[2] = "MouseDelay")
            Need(row[3] = "10", "mouse timing matches the modified reference")
        if (row[1] = "Options" && row[2] = "KeyDelay")
            Need(row[3] = "20", "key timing matches the modified reference")
    }
    items := [{path:"first",title:"First"},{path:"second",title:"Second"},
        {path:"third",title:"Third"},{path:"fourth",title:"Fourth"}]
    MW.reasonCache := Map("first","","second","","third","","fourth","")
    s := Map("slot1","first","slot2","fourth")
    Need(MW.RotationReason(s,items) = "", "two valid slots in a library with more than two items")
    s["slot2"] := "missing"
    Need(MW.RotationReason(s,items) != "", "missing slot disables Start without throwing")
    s.Delete("slot2")
    Need(MW.RotationReason(s,items) != "", "a missing key cannot read slot3")
    s["slot2"] := "fourth"
    MW.reasonCache["fourth"] := "unsupported test strategy"
    Need(MW.RotationReason(s,items) = "unsupported test strategy", "the second slot retains its validation")
    Store.settings["slot1"] := "first", Store.settings["slot2"] := "fourth"
    MW.items := items, MW.visibleItems := items, MW.current := items[1]
    MW.loadoutCache := Map("first","one","fourth","four")
    MW.slotNames := [UiProbe(),UiProbe()], MW.slotLoadouts := [UiProbe(),UiProbe()]
    MW.slotButtons := [UiProbe(),UiProbe()], MW.list := UiProbe()
    MW.RefreshSlots()
    Need(MW.slotNames[1].text = "First" && MW.slotNames[2].text = "Fourth" && MW.list.rows.Length = 4,
        "slot captions and library rows retain explicit slot indices")
    UI_Install()
    UI_Uninstall()
    FileAppend("PASS: dropdown bounds, strategy rotation and release UI`n","*")
    ExitApp(0)
} catch as e {
    FileAppend("FAIL: " e.Message "`n","**")
    ExitApp(1)
}
