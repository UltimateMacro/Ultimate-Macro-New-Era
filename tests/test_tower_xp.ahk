#Requires AutoHotkey v2.0
#Include "%A_LineFile%\..\..\lib\TowerXP.ahk"

AssertTowerXP(condition, message) {
    if !condition
        throw Error(message)
}

WriteTowerXPResult(path, message) {
    fileObj := FileOpen(path, "w", "UTF-8")
    if !IsObject(fileObj)
        throw Error("Could not create result file")
    fileObj.Write(message)
    fileObj.Close()
}

ReportTowerXPResult(message, exitCode, resultPath) {
    if (resultPath != "")
        WriteTowerXPResult(resultPath, message)
    else
        FileAppend(message "`n", "*")
    ExitApp(exitCode)
}

resultPath := A_Args.Length >= 1 ? A_Args[1] : ""
testRoot := A_Temp "\UltimateMacro-tower-xp-test-" DllCall("kernel32\GetCurrentProcessId", "UInt") "-" A_TickCount
tempPrefix := RTrim(A_Temp, "\/") "\"

try {
    AssertTowerXP(InStr(testRoot, tempPrefix) = 1, "Fixture root escaped the system temp directory")
    DirCreate(testRoot)

    definitions := TowerXPDefinitions()
    AssertTowerXP(definitions.Length = 8, "Tower definition count changed unexpectedly")
    scout := definitions[1]
    operator := definitions[5]
    AssertTowerXP(TowerXPNextRequired(scout, 0) = 50, "Scout level 0 requirement is wrong")
    AssertTowerXP(TowerXPNextRequired(operator, 0) = 75, "Operator level 0 requirement is wrong")

    scoutTotal := 0
    operatorTotal := 0
    Loop 20 {
        scoutTotal += TowerXPNextRequired(scout, A_Index - 1)
        operatorTotal += TowerXPNextRequired(operator, A_Index - 1)
    }
    AssertTowerXP(scoutTotal = 2549, "Standard evolution curve total changed")
    AssertTowerXP(operatorTotal = 3238, "Advanced evolution curve total changed")

    boundary := TowerXPAdvance(scout, 0, 49, 1)
    AssertTowerXP(boundary.level = 1 && boundary.xp = 0, "Exact level boundary did not advance")
    maxed := TowerXPAdvance(operator, 0, 0, operatorTotal)
    AssertTowerXP(maxed.level = 20 && maxed.xp = 0 && maxed.isMax,
        "Full progression did not stop cleanly at level 20")

    AssertTowerXP(TowerXPConsensusAmount([36]) = 0,
        "One OCR reading must not be copied to a missing tower")
    AssertTowerXP(TowerXPConsensusAmount([36, 36]) = 36,
        "Two agreeing OCR readings did not form consensus")
    AssertTowerXP(TowerXPConsensusAmount([36, 36, 40, 40]) = 0,
        "Tied OCR readings must remain unresolved")
    AssertTowerXP(TowerXPParseRewardAmount("+234 XP") = 234,
        "Tower reward parser rejected a normal result")
    AssertTowerXP(TowerXPParseRewardAmount("t36 xP") = 36,
        "Tower reward parser rejected expected OCR substitutions")
    AssertTowerXP(TowerXPParseRewardAmount("135 player XP") = 0,
        "Tower reward parser accepted unrelated player XP text")

    fullRegion := TowerXPResultSearchRegion(1920, 1009)
    AssertTowerXP(fullRegion.x <= 300 && fullRegion.y <= 550
        && fullRegion.x + fullRegion.w >= 675 && fullRegion.y + fullRegion.h >= 730,
        "Full-size result search band does not cover the reward cards")
    compactRegion := TowerXPResultSearchRegion(845, 648)
    AssertTowerXP(compactRegion.x <= 100 && compactRegion.y <= 304
        && compactRegion.x + compactRegion.w >= 464 && compactRegion.y + compactRegion.h >= 484,
        "Compact result search band does not cover the reward cards")

    config := TowerXPDefaultConfig()
    config.enabled := 1
    invalid := TowerXPValidateConfig(config)
    AssertTowerXP(!invalid.ok, "Enabled tracker accepted an empty tower selection")

    config.towers["Juggernaut"].tracked := 1
    config.towers["Juggernaut"].level := 19
    config.towers["Juggernaut"].xp := 10
    config.towers["Juggernaut"].stopTarget := 1
    config.stopMode := "Any"
    valid := TowerXPValidateConfig(config)
    AssertTowerXP(valid.ok, "Valid Juggernaut tracker settings were rejected")

    statePath := testRoot "\TowerXP.ini"
    TowerXPPersistConfig(config, statePath)
    loaded := TowerXPReadConfig(statePath)
    AssertTowerXP(loaded.enabled = 1 && loaded.towers["Juggernaut"].level = 19
        && loaded.towers["Juggernaut"].xp = 10,
        "Tower XP settings did not round-trip")

    stopBefore := TowerXPEvaluateStopRule(loaded)
    AssertTowerXP(!stopBefore.triggered, "Stop rule triggered before the target was maxed")
    loaded.towers["Juggernaut"].level := 20
    loaded.towers["Juggernaut"].xp := 0
    stopAfter := TowerXPEvaluateStopRule(loaded)
    AssertTowerXP(stopAfter.triggered, "Any-target stop rule did not trigger at level 20")

    runKey := "session|7|playing"
    AssertTowerXP(!TowerXPWasRunProcessed(statePath, runKey), "Fresh run was marked as processed")
    TowerXPMarkRunProcessed(statePath, runKey)
    AssertTowerXP(TowerXPWasRunProcessed(statePath, runKey), "Processed run key was not persisted")

    resaved := TowerXPReadConfig(statePath)
    resaved.towers["Juggernaut"].xp := 11
    TowerXPPersistConfig(resaved, statePath)
    AssertTowerXP(TowerXPWasRunProcessed(statePath, runKey),
        "Saving tracker settings cleared the processed-run key")

    ReportTowerXPResult("Tower XP behavioral fixtures: PASS", 0, resultPath)
} catch Error as err {
    ReportTowerXPResult("Tower XP behavioral fixtures: FAIL - " err.Message, 1, resultPath)
} finally {
    if DirExist(testRoot) && InStr(testRoot, tempPrefix) = 1
        DirDelete(testRoot, true)
}
