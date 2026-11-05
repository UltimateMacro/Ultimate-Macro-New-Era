#Requires AutoHotkey v2.0
#Warn All, Off
#NoTrayIcon
#Include engine\lib\UM14Features.ahk

global scenario := "", wheelCount := 0, clicks := [], probes := 0, activeDifficulty := "", hover := [0, 0]
Click(x, y) => clicks.Push([x, y])
MouseMove(x, y) {
    global hover := [x, y]
}
MouseGetPos(&x, &y) {
    x := hover[1], y := hover[2]
}
SendEvent(keys) {
    global wheelCount
    if (keys != "{WheelDown}")
        throw Error("Unexpected input")
    wheelCount++
}
LogToConsole(*) => 0
UM14_RequireReadyFocus() => 0
UM14_Fatal(message) {
    throw Error(message)
}
UM14_ConnectionSnapshot() => scenario = "docked" || scenario = "squad" ? {w:1078, h:995} : {w:1000, h:700}
UM14_ConnectionSame(*) => scenario != "moved"
UM14_Region(x, y, w, h, *) => {x:x, y:y, w:w, h:h}
UM14_OCRWords(recognized, *) => recognized
UM14_ConnectionOCR(identity, region, *) {
    if (scenario = "squad") {
        if (region.y = Round(identity.h*.08))
            return [{text:"SQUAD",raw:"Squad",x:500,y:135,w:49,h:16}]
        if (region.x = Round(identity.w*.19) && region.y = Round(identity.h*.34))
            return [{text:"SOLO",raw:"Solo",x:264,y:480,w:31,h:14}]
    }
    if (scenario = "modifier" && hover[2] = Round(identity.h*.945))
        return [{text:"ADD", x:32, y:615, w:18, h:9},
            {text:"MODIFIER", x:54, y:615, w:43, h:9}]
    if (scenario = "heading" && region.x = 210 && region.w = 270)
        return [{text:"SURVIVAL", raw:"Survival", x:240, y:240, w:75, h:13}]
    return []
}
AdvancedImageSearch(path, x, y, w, h, *) {
    global probes
    if (path = "Resources/Ready.png" && scenario = "modifier")
        return {status:"success", score:.9, x:x+100, y:y+50}
    if (path = "Resources/Survival.png" && scenario = "sidebar")
        return {status:"success", score:.93, x:x+25, y:y+30}
    if (path = "Resources/Survival.png" && scenario = "docked" && x <= 58 && x+w > 58)
        return {status:"success", score:.93, x:58, y:295}
    if (path = "Resources/close.png" && scenario = "heading")
        return {status:"success", score:.95, x:x+30, y:y+30}
    if (path = "Resources/" activeDifficulty ".png") {
        probes++
        if (scenario = "docked")
            return wheelCount && x <= 899 && x+w > 899
                ? {status:"success", score:.9, x:899, y:725}
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
    scenario := "squad"
    solo := UM14_SquadCard("Solo")
    Need(IsObject(solo) && solo.x = 280 && solo.y = 487, "Docked Solo label is verified under the squad heading")
    Need(!UM14_SquadCard("Duo"), "Do not click the wrong squad card")
    scenario := "moved", activeDifficulty := "Fallen", seen := false, wheelCount := 0, clicks := []
    Need(!UM14_SelectCurrentMode("Fallen", &seen) && wheelCount = 0 && clicks.Length = 0, "No input when Roblox identity changed")
    scenario := "modifier", clicks := [], hover := [0, 0]
    UM14_OpenModifierMenu()
    Need(clicks.Length = 1 && clicks[1][1] = 29 && clicks[1][2] = Round(700*.945),
        "Modifier tooltip verifies the icon position rather than clicking the label")
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
