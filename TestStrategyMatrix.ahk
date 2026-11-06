#Requires AutoHotkey v2.0
#Warn All, Off
#Include Main.ahk
#Include engine\lib\UM14Features.ahk

Need(ok, reason) {
    if !ok
        throw Error(reason)
}

CheckOption(ini, key, value, label) {
    Need(InStr("`r`n" ini, "`r`n" key "=" value "`r`n"), label ": " key " did not reach the engine")
}

try {
    items := Store.Library(), profiles := 0, count := 0
    Need(items.Length >= 7 && !Store.skipped.Length, "A shipped strategy is missing or skipped")
    for item in items {
        Strategy.Requirement(item)
        Need(InArray(Engine.MODES,item.mode), item.title ": unsupported mode")
        Need(InArray(Engine.MAPS,item.map), item.title ": unsupported map")
        Need(IniRead(item.path,"Settings","map") = item.map && IniRead(item.path,"Settings","difficulty") = item.mode,
            item.title ": launcher and legacy INI disagree on map or mode")
        towers := StrSplit(Strategy.Setting(item.parsed,"requiredtowers"),",")
        for step in item.parsed.steps {
            if (step.op = "SpawnTower")
                Need(step.args[3] <= towers.Length && Trim(towers[step.args[3]]) != "", item.title ": missing declared tower slot at line " step.line)
            count++
        }
        for mode in ["OFF","1.5x","2x"] {
            for dock in [false,true] {
                for equip in [false,true] {
                    for repeat in [false,true] {
                        for high in [false,true] {
                            Store.settings := Store.Defaults(), Store.recovered := false
                            runtime := Store.CopyMap(Store.DEFAULT_RUNTIME)
                            runtime["upgradeDelayMs"] := high ? 999 : 20, runtime["keyDelayMs"] := high ? 250 : 20
                            runtime["extraUiWait"] := high ? 90 : 0, runtime["preJoinDelay"] := high ? 60 : 0
                            settings := Map("appearanceRevision",5,"dockRoblox",dock,"autoEquip",equip,"repeat",repeat,
                                "timeScaleMode",mode,"runtime",runtime,"motion",!high,"themeBackground",!high,"topmost",high,
                                "halloween",high,"halloweenSounds",high,"windowOpacity",high ? 90 : 100,"updatePrompts",high,
                                "legacyOptions",Map("scrollModeList",high,"scrollAmount",high ? 20 : 5,"scrollDelayMs",high ? 5000 : 0))
                            Store.Accept(settings)
                            Need(!Store.recovered && Store.settings["dockRoblox"] = dock && Store.settings["motion"] = !high
                                && Store.settings["themeBackground"] = !high && Store.settings["windowOpacity"] = settings["windowOpacity"]
                                && Store.settings["updatePrompts"] = high, item.title ": profile values were lost")
                            ini := Engine.RenderIni(Engine.Profile(MW.RunOptions(false)),["Options","Hotkeys","RecordingHotkeys"])
                            for key, value in Map("AutoEquip",equip,"Repeat",repeat,"TimeScaleMode",mode,"ScrollDownForMap",high,
                                "ScrollDownAmount",high ? 20 : 5,"ScrollDelay",high ? 5000 : 0,"UpgradeDelay",runtime["upgradeDelayMs"],
                                "KeyDelay",runtime["keyDelayMs"],"ExtraUiWait",runtime["extraUiWait"],"PreJoinDelay",runtime["preJoinDelay"])
                                CheckOption(ini,key,value,item.title)
                            profiles++
                        }
                    }
                }
            }
        }
        for unit in ["Runs","Minutes"] {
            Store.settings := Store.Defaults(), Store.recovered := false
            Store.Accept(Map("rotation",true,"autoEquip",false,"repeat",false,"rotationAmount",2,"rotationUnit",unit))
            opts := MW.RunOptions(false), opts.rotation := {amount:Store.settings["rotationAmount"],unit:unit}
            ini := Engine.RenderIni(Engine.Profile(opts),["Options"])
            for key, value in Map("RotateStrategies",1,"SwapUnit",unit,"SwapAmount",2,"AutoEquip",1,"Repeat",1)
                CheckOption(ini,key,value,item.title)
            profiles++
        }
    }
    semi := Chr(59)
    Need(UM14_RecordedStepLine(semi " UpgradeTower(1)") = "", "Commented upgrade is not executable")
    Need(UM14_RecordedStepLine("SpawnTower(1,2,3,id) " semi " UpgradeTower(id)") = "SpawnTower(1,2,3,id)",
        "Trailing comment cannot execute a different operation")
    quoted := 'Example("a' semi 'b")'
    Need(UM14_RecordedStepLine(quoted " " semi " note") = quoted, "Quoted semicolons are preserved")
    batch := UM14_UpgradeBatch(["UpgradeTower(a, false, 1, 1, 4)","UpgradeTower(a, false, 2, 1, 4)",
        "UpgradeTower(a, false, 1, 2, 4)","UpgradeTower(a, true, 1, 2, 4)"],1)
    Need(IsObject(batch) && batch.count = 3 && batch.next = 3 && batch.path = 1, "Only identical upgrade paths batch")
    batch := UM14_UpgradeBatch(["UpgradeTower(a, false, 1, 2, 4)","UpgradeTower(a, true, 1, 2, 4)"],1)
    Need(batch.next = 2 && !batch.skip, "Do not swallow the next upgrade's skip-open flag")
    for unsupported in ["ActivateEnforcerVan()","EnforcerReposition(a,b,1,2)","CloneTower(a,1,2,0,newID)","SpawnTower(1,2,6,id)"] {
        parsed := Strategy.Parse("[Settings]`nMap=Dead Ahead`nDifficulty=Easy`n[Steps]`n" unsupported)
        rejected := false
        try Strategy.Requirement({parsed:parsed})
        catch ValueError
            rejected := true
        Need(rejected,"Unimplemented action was accepted: " unsupported)
    }
    FileAppend("PASS: " items.Length " bundled strategies, " count " steps and " profiles " strategy/profile configurations`n","*")
    ExitApp(0)
} catch as e {
    FileAppend("FAIL: " e.Message " (line " e.Line ")`n","**")
    ExitApp(1)
}
