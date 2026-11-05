#Requires AutoHotkey v2.0
#Warn All, Off
#NoTrayIcon
#Include engine\lib\UM14Features.ahk

global scenario := "", wheelCount := 0, clicks := [], probes := 0, activeDifficulty := ""
Click(x, y) => clicks.Push([x, y])
MouseMove(*) => 0
SendEvent(keys) {
    global wheelCount
    if (keys != "{WheelDown}")
        throw Error("Unexpected input")
    wheelCount++
}
LogToConsole(*) => 0
UM14_RequireReadyFocus() => 0
UM14_ConnectionSnapshot() => {w:1000, h:700}
UM14_ConnectionSame(*) => scenario != "moved"
UM14_Region(x, y, w, h, *) => {x:x, y:y, w:w, h:h}
UM14_OCRWords(recognized, *) => recognized
UM14_ConnectionOCR(identity, region, *) {
    if (scenario = "heading" && region.x = 210 && region.w = 270)
        return [{text:"SURVIVAL", raw:"Survival", x:240, y:240, w:75, h:13}]
    return []
}
AdvancedImageSearch(path, x, y, w, h, *) {
    global probes
    if (path = "Resources/Survival.png" && scenario = "sidebar")
        return {status:"success", score:.93, x:x+25, y:y+30}
    if (path = "Resources/close.png" && scenario = "heading")
        return {status:"success", score:.95, x:x+30, y:y+30}
    if (path = "Resources/" activeDifficulty ".png") {
        probes++
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
    scenario := "moved", activeDifficulty := "Fallen", seen := false, wheelCount := 0, clicks := []
    Need(!UM14_SelectCurrentMode("Fallen", &seen) && wheelCount = 0 && clicks.Length = 0, "No input when Roblox identity changed")
    FileAppend("PASS: Fallen sidebar, Frost below fold, and moved-window abort`n", "*")
    ExitApp(0)
} catch as e {
    FileAppend("FAIL: " e.Message "`n", "**")
    ExitApp(1)
}
