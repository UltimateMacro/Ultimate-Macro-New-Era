#Requires AutoHotkey v2.0
#Warn All, Off
#NoTrayIcon
#Include engine\lib\UM14Geometry.ahk
Need(ok,message) {
    if !ok
        throw Error(message)
}
try {
    engineSource := FileRead(A_ScriptDir "\engine\UM14Engine.ahk", "UTF-8")
    Need(RegExMatch(engineSource, "s)ScaleX\(baseX, Width := 1920\) \{[^}]+return UM14_Scale\(baseX, currentWidth, Width\)"),
        "The HUD entry point remains wired to ordinary pixel scaling")
    Need(InStr(engineSource,"return UM14_WorldX(baseX, currentWidth, currentHeight, Width, sourceHeight)"),
        "The strategy world entry point uses the aspect-aware conversion")
    upgradeSource := SubStr(engineSource, InStr(engineSource,"UpgradeTower(towerID, skipOpen :="))
    Need(RegExMatch(upgradeSource, "s)if \(!skipOpen && LastOpenedTowerID != towerID\).*?UM14_ClearPlacementPanel\(\).*?Click\(targetX, targetY\)"),
        "Switching upgrade targets closes the old panel before clicking a map point it might cover")
    sellSource := SubStr(engineSource, InStr(engineSource,"SellTower(towerID) {"))
    Need(InStr(sellSource,"UM14_ClearPlacementPanel()") < InStr(sellSource,"Click(targetX, targetY)")
        && InStr(sellSource,"HasOwnProp(" Chr(34) "hwnd" Chr(34) ")"),
        "Selling establishes the same menu boundary and tolerates towers without a recording window")
    for x in [545,592,609,629,984,1025,1157,1246]
        Need(UM14_WorldX(x,1920,1009,1920,1009) = x, "The verified full-size coordinates stay unchanged")
    Need(UM14_WorldX(584,1076,993,1920,1009) = 168,
        "Docking retains the Farm's world-space horizontal offset instead of compressing it onto the path")
    Need(UM14_WorldX(960,1076,993,1920,1009) = 538,
        "The recorded view centre maps to the current view centre")
    Need(UM14_WorldX(584,800,599,1920,1009) = 177, "A 4:3 window uses vertical FOV for world X")
    Need(UM14_WorldX(592,2500,1009,1920,1009) = 882, "An ultrawide view translates the world centre without stretching the map")
    Need(UM14_WorldX(400,800,600,800,600) = 400
        && UM14_WorldX(200,800,600,800,600) = 200, "Explicit recorder geometry remains an identity at its original size")
    Need(UM14_WorldX(300,800,600,0,0) = 300
        && UM14_WorldX(300,800,600,1600,0) = 150, "Legacy raw-coordinate modes retain their documented behavior")
    Need(UM14_WorldX(0,240,1009,1920,1009) < 0, "Offscreen world points are not silently clamped to the wrong terrain")
    Need(UM14_Scale(592,1076,1920) = 332, "HUD scaling is deliberately unchanged")
    Need(UM14_PlacementRadius(1,1009) = 5 && UM14_PlacementRadius(4,1009) = 20
        && UM14_PlacementRadius(1024,1009) = 20 && UM14_PlacementRadius(4,504) = 10,
        "A blocked tile only retries locally, with no exponential travel across the map")
    FileAppend("World-coordinate regressions passed.`n", "*")
    ExitApp(0)
} catch Error as err {
    FileAppend(err.Message "`n" err.Stack "`n", "*")
    ExitApp(1)
}
