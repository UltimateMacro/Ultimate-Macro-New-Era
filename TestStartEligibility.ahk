#Requires AutoHotkey v2.0 64-bit
#NoTrayIcon
#Warn All, Off
#Include Main.ahk

class StartEligibilityProbe {
    static launches := []
    static targets := 0

    static Reset(folder, first, second, rotation) {
        Store.root := folder
        Store.settings := Store.Defaults()
        Store.settings["rotation"] := rotation
        Store.settings["slot1"] := first
        Store.settings["slot2"] := second
        MW.booting := false, MW.engineReady := true
        MW.run := {active:false, phase:"idle", matches:0}
        MW.reasonCache := Map(), MW.outputLines := []
        MW.outputEdit := "", MW.outputBtn := ""
        MW.current := Strategy.Inspect(first)
        StartEligibilityProbe.launches := []
        StartEligibilityProbe.targets := 0
    }

    static StartTarget(*) {
        StartEligibilityProbe.targets++
        return 101
    }

    static Launch(_, values, first, second, then) {
        StartEligibilityProbe.launches.Push({first:first, second:second, rotation:values.rotation})
    }

    static Write(path, text) {
        f := FileOpen(path, "w", "UTF-8-RAW")
        try f.Write(text)
        finally f.Close()
    }

    static Need(ok, message) {
        if !ok
            throw Error(message)
    }
}

class StartEligibilityWindow {
    Restore() => 0
}

folder := A_Temp "\UM-StartEligibility-" DllCall("GetCurrentProcessId") "-" A_TickCount
first := folder "\first.strat", second := folder "\second.strat"
try {
    DirCreate(folder)
    ; Start runs normally through its admission checks. These boundaries
    ; ensure no game lookup, foreground input, engine process or UI work.
    MW.gui := StartEligibilityWindow()
    MW.partyEnabled := {checked:false}
    Roblox.DefineProp("Game", {Call: StartEligibilityProbe.StartTarget})
    MW.DefineProp("FocusGame", {Call: (*) => 101})
    MW.DefineProp("ShortcutGame", {Call: StartEligibilityProbe.StartTarget})
    MW.DefineProp("CoversGame", {Call: (*) => false})
    MW.DefineProp("UpdateControls", {Call: (*) => 0})
    Engine.DefineProp("Profile", {Call: (_, opts) => opts})
    Engine.DefineProp("Launch", {Call: ObjBindMethod(StartEligibilityProbe, "Launch")})
    Hotkeys.DefineProp("Update", {Call: (*) => 0})

    ordinary := "[Settings]" Chr(10) "map=Wretched Front" Chr(10) "difficulty=Hardcore" Chr(10)
        . "[Steps]" Chr(10) "SpawnTower(10, 20, 1, 1)" Chr(10)
    unsupported := ordinary "CloneTower(1, 70, 80, 0, NewFarm)" Chr(10)
    failures := []
    for scenario in [{name:"single Start", rotation:false, edit:first, shortcut:false}
        , {name:"rotation slot 1", rotation:true, edit:first, shortcut:true}
        , {name:"rotation slot 2", rotation:true, edit:second, shortcut:false}] {
        StartEligibilityProbe.Write(first, ordinary)
        StartEligibilityProbe.Write(second, ordinary)
        StartEligibilityProbe.Reset(folder, first, second, scenario.rotation)
        StartEligibilityProbe.Need(MW.Reason(Strategy.Inspect(first)) == ""
            && MW.Reason(Strategy.Inspect(second)) == "", "Expected playable cached results")
        StartEligibilityProbe.Write(scenario.edit, unsupported)
        MW.StartRun(scenario.shortcut)
        if (StartEligibilityProbe.launches.Length || StartEligibilityProbe.targets || MW.run.active
            || MW.outputLines.Length != 1 || !InStr(MW.outputLines[1], "cannot assign a custom ID"))
            failures.Push(scenario.name)
    }
    if failures.Length {
        message := "Edited content was not rejected before game lookup:"
        for name in failures
            message .= " " name ";"
        throw Error(message)
    }

    ; A cached denial also cannot reject newly valid bytes. Launch receives
    ; the exact two inspected texts, including their distinct placement.
    StartEligibilityProbe.Write(first, unsupported)
    StartEligibilityProbe.Write(second, ordinary)
    StartEligibilityProbe.Reset(folder, first, second, true)
    StartEligibilityProbe.Need(InStr(MW.Reason(MW.current), "cannot assign a custom ID"), "Expected a cached denial")
    repaired := StrReplace(ordinary, "10, 20", "30, 40")
    StartEligibilityProbe.Write(first, repaired)
    MW.StartRun()
    StartEligibilityProbe.Need(StartEligibilityProbe.launches.Length = 1, "Fresh playable strategy should start")
    launch := StartEligibilityProbe.launches[1]
    StartEligibilityProbe.Need(launch.first == repaired && launch.second == ordinary && IsObject(launch.rotation),
        "Rotation must launch the exact inspected texts in slot order")
    FileAppend("PASS: Start revalidates edited strategy text in single and both rotation slots." Chr(10), "*")
    result := 0
} catch Error as err {
    FileAppend("FAIL: " err.Message Chr(10) err.Stack Chr(10), "**")
    result := 1
} finally {
    if FileExist(first)
        FileDelete(first)
    if FileExist(second)
        FileDelete(second)
    if DirExist(folder)
        DirDelete(folder)
}
ExitApp(result)
