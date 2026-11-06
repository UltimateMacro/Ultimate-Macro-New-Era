#Requires AutoHotkey v2.0
#Warn All, Off
#NoTrayIcon
#Include engine\lib\UM14Features.ahk
#Include engine\lib\UM14Click.ahk

global scenario := "", wheelCount := 0, clicks := [], probes := 0, activeDifficulty := "", hover := [0, 0]
Click(x, y := unset) {
    if (x = "Up")
        return
    clicks.Push(IsSet(y) ? [x, y] : hover.Clone())
}
MouseMove(x, y, *) {
    global hover := [x, y]
}
MouseGetPos(&x, &y) {
    x := hover[1], y := hover[2]
}
SendEvent(keys) {
    global wheelCount
    if (keys != "{WheelDown 2}")
        throw Error("Unexpected input")
    wheelCount++
}
LogToConsole(*) => 0
UM14_RequireReadyFocus() => 0
UM14_RequireInputPoint(identity,x,y,*) {
    if (!UM14_ConnectionSame(identity) || x < 0 || y < 0 || x >= identity.w || y >= identity.h)
        throw Error("Fixture input point invalid")
}
global SettingsFile := "fixture"
IniRead(file, section, key, fallback := "") => fallback
UM14_Fatal(message) {
    throw Error(message)
}
UM14_ConnectionSnapshot() => scenario = "docked" || scenario = "squad" || scenario = "hardcore" ? {w:1078, h:995}
    : scenario = "horizontal" || scenario = "squad-compact" || scenario = "modifier-compact" ? {w:800, h:600} : {w:1000, h:700}
UM14_ConnectionSame(*) => scenario != "moved"
UM14_Region(x, y, w, h, *) => {x:x, y:y, w:w, h:h}
UM14_OCRWords(recognized, *) => IsObject(recognized) ? recognized : []
UM14_ConnectionOCR(identity, region, factor := 0, *) {
    if (scenario = "hardcore" && region.x = Floor(identity.w*.3307))
        return "Wretched`nFront"
    if (scenario = "items" && factor = 3.0)
        return [{text:"ITEMS",raw:"Items",x:85,y:320,w:40,h:14}]
    if (scenario = "lobby" && region.x = 250 && region.y = 462)
        return [{text:"PLAY",raw:"PLAY",x:450,y:640,w:50,h:16}]
    if (scenario = "easy" && region.x = 210 && region.w = 620)
        return [{text:"EASY",raw:"Easy",x:300,y:200,w:40,h:14},
            {text:"CASUAL",raw:"Casual",x:500,y:200,w:50,h:14}]
    if (scenario = "map-prompt" && region.x = 270 && region.w = 460)
        return "Override Map"
    if (scenario = "squad-compact") {
        if (region.y = 15)
            return "Choose a Squad...`nSelect the maximum..."
        if (region.x = 176 && region.y = 234)
            return "Solo"
    }
    if (scenario = "horizontal" && region.y = 33) {
        if (region.x = 264)
            return [{text:"SURVIVAL",raw:"Survival",x:275,y:45,w:40,h:10}]
        if (region.x = 332)
            return [{text:"STORY",raw:"Story",x:348,y:45,w:28,h:10}]
    }
    if (scenario = "squad") {
        if (region.y = Round(identity.h*.025))
            return [{text:"SQUAD...",raw:"Squad...",x:500,y:49,w:49,h:16}]
        if (region.x = Round(identity.w*.19) && region.y = Round(identity.h*.34))
            return [{text:"SOLO",raw:"Solo",x:264,y:480,w:31,h:14}]
    }
    if (scenario = "modifier" && hover[2] = Round(identity.h*.945))
        return [{text:"ADD", x:32, y:615, w:18, h:9},
            {text:"MODIFIER", x:54, y:615, w:43, h:9}]
    if (scenario = "modifier-compact" && region.w >= 220 && hover[2] = Round(identity.h*.98))
        return [{text:"ADD",x:43,y:550,w:22,h:10},
            {text:"MODIFIER",x:70,y:550,w:68,h:10}]
    if (scenario = "heading" && region.x = 210 && region.w = 270)
        return [{text:"SURVIVAL", raw:"Survival", x:240, y:240, w:75, h:13}]
    return []
}
AdvancedImageSearch(path, x, y, w, h, *) {
    global probes
    if (scenario = "restart" && path = "Resources/Restart.png" && !clicks.Length)
        return {status:"success", score:.94, x:x+220, y:y+90}
    if (path = "Resources/Ready.png" && (scenario = "modifier" || scenario = "modifier-compact" || scenario = "map-prompt"))
        return {status:"success", score:.9, x:x+100, y:y+50}
    if (path = "Resources/Survival.png" && (scenario = "sidebar" || scenario = "easy"))
        return {status:"success", score:.93, x:x+25, y:y+30}
    if (path = "Resources/Survival.png" && scenario = "docked" && x <= 58 && x+w > 58)
        return {status:"success", score:.93, x:58, y:295}
    if (path = "Resources/close.png" && scenario = "heading")
        return {status:"success", score:.95, x:x+30, y:y+30}
    if (path = "Resources/" activeDifficulty ".png" && scenario != "easy") {
        probes++
        if (scenario = "docked")
            return wheelCount && x <= 899 && x+w > 899
                ? {status:"success", score:.9, x:899, y:725}
                : {status:"failed", score:0, x:0, y:0}
        if (scenario = "horizontal")
            return wheelCount && x <= 724 && x+w > 724
                ? {status:"success", score:.9, x:724, y:511}
                : {status:"failed", score:0, x:0, y:0}
        if (wheelCount >= 1)
            return {status:"success", score:.9, x:x+90, y:y+90}
    }
    return {status:"failed", score:0, x:0, y:0}
}
Need(ok, text) {
    if !ok
        throw Error(text)
}
try {
    scenario := "restart"
    Need(UM14_ClickResult("Restart.png","Restart") && clicks.Length = 1,
        "Restart is rechecked after hover, clicked once, then verified gone")
    clicks := []
    Need(UM14_BestRestart({status:"failed",score:.99},{status:"success",score:.71}) = "Restart2.png",
        "A failed template cannot beat a valid Restart match")
    Need(UM14_MapCaption("Wretched`nFront", "Wretched Front")
        && !UM14_MapCaption("Wrecked Battlefield", "Wretched Front")
        && !UM14_MapCaption("Wretched Frontier", "Wretched Front"), "Exact map words do not match a different map")
    scenario := "hardcore"
    Need(UM14_HardcoreMapSlot("Wretched Front") = 2 && !UM14_HardcoreMapSlot("Wrecked Battlefield"),
        "Hardcore captions come from the stable game client, including a wrapped docked caption")
    scenario := "moved"
    Need(!UM14_HardcoreMapSlot("Wretched Front"), "No map choice from a moved or inactive game")
    Need(!UM14_MapImageVerified({status:"success",score:.7},"Hardcore")
        && !UM14_MapImageVerified({status:"error",score:.99},"Hardcore")
        && UM14_MapImageVerified({status:"success",score:.9},"Hardcore"),
        "A weak unrelated terrain match cannot confirm a Hardcore map")
    Need(UM14_InputRootMatches(123,123) && !UM14_InputRootMatches(124,123)
        && !UM14_InputRootMatches(0,0), "Only the selected game root may receive pointer input")
    scenario := "lobby"
    play := UM14_LobbyPlay()
    Need(IsObject(play) && play.x = 475 && play.y = 648 && !clicks.Length,
        "Lobby Play recognition falls back to a verified live label without clicking or relaunching")
    scenario := "moved"
    Need(!UM14_LobbyPlay(), "Lobby recognition rejects a changed client")
    scenario := "items"
    item := UM14_MenuWordPair({w:1000,h:700},{x:0,y:250,w:168,h:130},"ITEMS",false,false,3.0)
    Need(IsObject(item) && item.x = 105 && !clicks.Length,
        "A current Items label uses two exact observations at the requested scale")
    scenario := "easy", activeDifficulty := "Easy"
    Need(UM14_SelectCurrentMode("Easy", &seen) && clicks.Length = 2 && clicks[2][1] = 320,
        "Easy never aliases to Casual")
    clicks := [], activeDifficulty := "Casual"
    Need(UM14_SelectCurrentMode("Casual", &seen) && clicks.Length = 2 && clicks[2][1] = 525,
        "Casual retains its own card")
    clicks := [], wheelCount := 0, probes := 0
    scenario := "sidebar", activeDifficulty := "Fallen"
    Need(UM14_SelectCurrentMode("Fallen", &seen) && seen, "Fallen selected after seeing sidebar icon")
    Need(wheelCount = 1 && clicks.Length = 2 && probes >= 3, "Fallen uses bounded scroll and two sightings")
    scenario := "heading", activeDifficulty := "Frost", wheelCount := 0, clicks := [], probes := 0
    Need(UM14_SelectCurrentMode("Frost", &seen) && seen, "Frost selected when below the heading")
    Need(wheelCount = 1 && clicks.Length = 1 && probes >= 3, "Frost heading path avoids a blind sidebar click")
    scenario := "docked", activeDifficulty := "Frost", wheelCount := 0, clicks := [], probes := 0
    Need(UM14_SelectCurrentMode("Frost", &seen) && seen, "Frost selected in the docked full-width menu")
    Need(clicks.Length = 2 && clicks[1][1] = 58 && clicks[2][1] = 899 && wheelCount = 1,
        "Docked sidebar and far-right card are both in bounds")
    scenario := "horizontal", wheelCount := 0, clicks := [], probes := 0
    Need(UM14_SelectCurrentMode("Frost", &seen) && seen, "Frost selected in an 800x600 client")
    Need(clicks.Length = 2 && clicks[1][1] = 295 && clicks[2][1] = 724 && wheelCount = 1,
        "Small horizontal tabs are confirmed before scrolling or clicking")
    scenario := "squad"
    solo := UM14_SquadCard("Solo")
    Need(IsObject(solo) && solo.x = 280 && solo.y = 487, "Docked Solo label is verified under the squad heading")
    Need(!UM14_SquadCard("Duo"), "Do not click the wrong squad card")
    scenario := "squad-compact"
    solo := UM14_SquadCard("Solo")
    Need(IsObject(solo) && solo.x = 252 && solo.y = 273, "Compact squad uses exact text when word boxes are missing")
    Need(!UM14_SquadCard("Duo"), "Compact fallback rejects a different squad label")
    scenario := "map-prompt"
    Need(IsObject(UM14_MapOverridePrompt()), "Visible map-vote controls and exact Override Map label verify the prompt")
    scenario := "no-vote"
    Need(!UM14_MapOverridePrompt(), "No map override input outside the vote screen")
    scenario := "moved", activeDifficulty := "Fallen", seen := false, wheelCount := 0, clicks := []
    Need(!UM14_SelectCurrentMode("Fallen", &seen) && wheelCount = 0 && clicks.Length = 0, "No input when Roblox identity changed")
    scenario := "modifier", clicks := [], hover := [0, 0]
    UM14_OpenModifierMenu()
    Need(clicks.Length = 1 && clicks[1][1] = 29 && clicks[1][2] = Round(700*.945),
        "Modifier tooltip verifies the icon position rather than clicking the label")
    scenario := "modifier-compact", clicks := [], hover := [0,0]
    UM14_OpenModifierMenu()
    Need(clicks.Length = 1 && clicks[1][1] = 23 && clicks[1][2] = 588,
        "Compact modifier tooltip keeps the whole caption and still clicks only its verified hover point")
    scenario := "no-vote", clicks := [], hover := [0, 0]
    rejected := false
    try UM14_OpenModifierMenu()
    catch as e {
        rejected := InStr(e.Message, "Map vote screen")
    }
    Need(rejected && !clicks.Length && hover[1] = 0, "No modifier input without the vote screen")
    FileAppend("PASS: Fallen, Frost, moved-window abort, and guarded modifier hover`n", "*")
    ExitApp(0)
} catch as e {
    FileAppend("FAIL: " e.Message "`n", "**")
    ExitApp(1)
}
