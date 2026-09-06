#Requires AutoHotkey v2.0

; Tower Evolution progression and persistence.
; This module has no UI, image-search, webhook, or input side effects.
; XP is stored as progress inside the current level, not lifetime XP.

TowerXPDefinitions() {
    static definitions := [
        { name: "Scout", file: "Scout.png", baseXP: 50, growth: 1.09, maxLevel: 20 },
        { name: "Minigunner", file: "Minigunner.png", baseXP: 50, growth: 1.09, maxLevel: 20 },
        { name: "Crook Boss", file: "Crookboss.png", baseXP: 50, growth: 1.09, maxLevel: 20 },
        { name: "Shotgunner", file: "Shotgunner.png", baseXP: 50, growth: 1.09, maxLevel: 20 },
        { name: "Operator", file: "Operator.png", baseXP: 75, growth: 1.075, maxLevel: 20 },
        { name: "Juggernaut", file: "Juggernaut.png", baseXP: 75, growth: 1.075, maxLevel: 20 },
        { name: "Kingpin", file: "Kingpin.png", baseXP: 75, growth: 1.075, maxLevel: 20 },
        { name: "Enforcer", file: "Enforcer.png", baseXP: 75, growth: 1.075, maxLevel: 20 }
    ]
    return definitions
}

TowerXPStatePath(optionsDir := "") {
    if (optionsDir = "")
        optionsDir := A_AppData "\Ultimate_Macro\Options"
    return optionsDir "\TowerXP.ini"
}

TowerXPSectionName(towerName) {
    return "TowerXP_" RegExReplace(towerName, "[^A-Za-z0-9]+", "_")
}

TowerXPReadInteger(path, section, key, fallback := 0) {
    raw := IniRead(path, section, key, fallback)
    return IsNumber(raw) ? Integer(raw) : Integer(fallback)
}

TowerXPNextRequired(definition, currentLevel) {
    level := Max(0, Integer(currentLevel))
    if (level >= definition.maxLevel)
        return 0
    return Floor(definition.baseXP * (definition.growth ** level))
}

TowerXPAdvance(definition, currentLevel, currentXP, gainedXP := 0) {
    level := Max(0, Min(definition.maxLevel, Integer(currentLevel)))
    xp := Max(0, Integer(currentXP) + Integer(gainedXP))
    levelsGained := 0

    while (level < definition.maxLevel) {
        required := TowerXPNextRequired(definition, level)
        if (xp < required)
            break
        xp -= required
        level += 1
        levelsGained += 1
    }

    if (level >= definition.maxLevel)
        xp := 0

    return {
        level: level,
        xp: xp,
        levelsGained: levelsGained,
        nextRequired: TowerXPNextRequired(definition, level),
        isMax: level >= definition.maxLevel
    }
}

TowerXPStoredStopMode(labelOrValue) {
    value := Trim(String(labelOrValue))
    if (value = "Any selected tower" || value = "Any")
        return "Any"
    if (value = "All selected towers" || value = "All")
        return "All"
    return "Never"
}

TowerXPStopModeLabel(value) {
    value := TowerXPStoredStopMode(value)
    return value = "Any" ? "Any selected tower" : (value = "All" ? "All selected towers" : "Never")
}

TowerXPDefaultConfig() {
    config := { enabled: 0, stopMode: "Never", lastProcessedRun: "", towers: Map() }
    for definition in TowerXPDefinitions() {
        config.towers[definition.name] := {
            tracked: 0,
            level: 0,
            xp: 0,
            stopTarget: 0,
            lastGainedXP: 0,
            lastUpdated: ""
        }
    }
    return config
}

TowerXPReadConfig(statePath) {
    config := TowerXPDefaultConfig()
    if !FileExist(statePath)
        return config

    config.enabled := TowerXPReadInteger(statePath, "Tracker", "Enabled", 0) = 1 ? 1 : 0
    config.stopMode := TowerXPStoredStopMode(IniRead(statePath, "Tracker", "StopMode", "Never"))
    config.lastProcessedRun := IniRead(statePath, "Tracker", "LastProcessedRun", "")

    for definition in TowerXPDefinitions() {
        section := TowerXPSectionName(definition.name)
        row := config.towers[definition.name]
        row.tracked := TowerXPReadInteger(statePath, section, "Tracked", 0) = 1 ? 1 : 0
        row.level := Max(0, Min(definition.maxLevel,
            TowerXPReadInteger(statePath, section, "Level", 0)))
        row.xp := Max(0, TowerXPReadInteger(statePath, section, "XP", 0))
        row.stopTarget := TowerXPReadInteger(statePath, section, "StopTarget", 0) = 1 ? 1 : 0
        row.lastGainedXP := Max(0, TowerXPReadInteger(statePath, section, "LastGainedXP", 0))
        row.lastUpdated := IniRead(statePath, section, "LastUpdated", "")
        normalized := TowerXPAdvance(definition, row.level, row.xp, 0)
        row.level := normalized.level
        row.xp := normalized.xp
    }
    return config
}

TowerXPValidateConfig(config) {
    trackedCount := 0
    stopTargetCount := 0

    for definition in TowerXPDefinitions() {
        if !config.towers.Has(definition.name)
            return { ok: false, message: "Missing settings for " definition.name "." }

        row := config.towers[definition.name]
        if (!IsNumber(row.level) || Integer(row.level) < 0 || Integer(row.level) > definition.maxLevel)
            return { ok: false, message: definition.name " level must be from 0 to " definition.maxLevel "." }
        if (!IsNumber(row.xp) || Integer(row.xp) < 0)
            return { ok: false, message: definition.name " XP must be a non-negative whole number." }

        level := Integer(row.level)
        xp := Integer(row.xp)
        if (level >= definition.maxLevel && xp != 0)
            return { ok: false, message: definition.name " XP must be 0 at max level." }
        if (level < definition.maxLevel && xp >= TowerXPNextRequired(definition, level))
            return { ok: false, message: definition.name " XP must be below the next-level requirement." }

        if (row.tracked)
            trackedCount += 1
        if (row.stopTarget) {
            if (!row.tracked)
                return { ok: false, message: definition.name " must be tracked before it can be a stop target." }
            stopTargetCount += 1
        }
    }

    if (config.enabled && trackedCount = 0)
        return { ok: false, message: "Select at least one tower before enabling tracking." }
    if (TowerXPStoredStopMode(config.stopMode) != "Never" && stopTargetCount = 0)
        return { ok: false, message: "Select at least one stop target or choose Never." }
    return { ok: true, message: "" }
}

TowerXPPersistConfig(config, statePath) {
    validation := TowerXPValidateConfig(config)
    if (!validation.ok)
        throw Error(validation.message)

    SplitPath(statePath, , &stateDir)
    if !DirExist(stateDir)
        DirCreate(stateDir)

    IniWrite(1, statePath, "Tracker", "SchemaVersion")
    IniWrite(config.enabled ? 1 : 0, statePath, "Tracker", "Enabled")
    IniWrite(TowerXPStoredStopMode(config.stopMode), statePath, "Tracker", "StopMode")
    if (config.HasOwnProp("lastProcessedRun"))
        IniWrite(config.lastProcessedRun, statePath, "Tracker", "LastProcessedRun")

    for definition in TowerXPDefinitions() {
        row := config.towers[definition.name]
        section := TowerXPSectionName(definition.name)
        IniWrite(row.tracked ? 1 : 0, statePath, section, "Tracked")
        IniWrite(Integer(row.level), statePath, section, "Level")
        IniWrite(Integer(row.xp), statePath, section, "XP")
        IniWrite(row.stopTarget ? 1 : 0, statePath, section, "StopTarget")
        IniWrite(row.HasOwnProp("lastGainedXP") ? Integer(row.lastGainedXP) : 0,
            statePath, section, "LastGainedXP")
        IniWrite(row.HasOwnProp("lastUpdated") ? row.lastUpdated : "",
            statePath, section, "LastUpdated")
    }
    return true
}

TowerXPMigrateLegacy(settingsFile, statePath) {
    if FileExist(statePath)
        return false

    legacyEnabled := IniRead(settingsFile, "TowerXP", "Enabled", "__tower_xp_missing__")
    if (legacyEnabled = "__tower_xp_missing__")
        return false

    config := TowerXPDefaultConfig()
    config.enabled := IsNumber(legacyEnabled) && Integer(legacyEnabled) = 1 ? 1 : 0
    config.stopMode := TowerXPStoredStopMode(IniRead(settingsFile, "TowerXP", "StopMode", "Never"))
    for definition in TowerXPDefinitions() {
        section := TowerXPSectionName(definition.name)
        row := config.towers[definition.name]
        row.tracked := TowerXPReadInteger(settingsFile, section, "Tracked", 0) = 1 ? 1 : 0
        row.level := Max(0, Min(definition.maxLevel,
            TowerXPReadInteger(settingsFile, section, "Level", 0)))
        row.xp := row.level >= definition.maxLevel ? 0 : Max(0,
            TowerXPReadInteger(settingsFile, section, "XP", 0))
        row.stopTarget := TowerXPReadInteger(settingsFile, section, "StopTarget", 0) = 1 ? 1 : 0
        row.lastGainedXP := Max(0, TowerXPReadInteger(settingsFile, section, "LastGainedXP", 0))
        row.lastUpdated := IniRead(settingsFile, section, "LastUpdated", "")
    }

    try {
        TowerXPPersistConfig(config, statePath)
        return true
    } catch Error {
        return false
    }
}

TowerXPEnabled(statePath, legacySettingsFile := "") {
    if (legacySettingsFile != "")
        TowerXPMigrateLegacy(legacySettingsFile, statePath)
    return TowerXPReadInteger(statePath, "Tracker", "Enabled", 0) = 1
}

; A run key prevents one Triumph screen from being counted twice if watchdog
; recovery briefly relaunches while the results UI is still visible.
TowerXPGetRunKey(runtimeStateFile) {
    sessionStart := IniRead(runtimeStateFile, "State", "StartTime", "")
    runCount := IniRead(runtimeStateFile, "State", "CurrentRunCount", "")
    playStart := IniRead(runtimeStateFile, "State", "TimeWhenStartedPlaying", "")
    if (sessionStart = "" && runCount = "" && playStart = "")
        return ""
    return sessionStart "|" runCount "|" playStart
}

TowerXPWasRunProcessed(statePath, runKey) {
    if (runKey = "")
        return false
    return IniRead(statePath, "Tracker", "LastProcessedRun", "") = runKey
}

TowerXPMarkRunProcessed(statePath, runKey) {
    if (runKey != "")
        IniWrite(runKey, statePath, "Tracker", "LastProcessedRun")
}

; A missing card may inherit the common reward only when at least two direct
; OCR readings agree. A single card never fabricates another tower's XP.
TowerXPConsensusAmount(amounts, minimumAgreement := 2) {
    counts := Map()
    for rawAmount in amounts {
        if (!IsNumber(rawAmount))
            continue
        amount := Integer(rawAmount)
        if (amount <= 0)
            continue
        counts[amount] := counts.Has(amount) ? counts[amount] + 1 : 1
    }

    bestAmount := 0
    bestCount := 0
    tied := false
    for amount, count in counts {
        if (count > bestCount) {
            bestAmount := amount
            bestCount := count
            tied := false
        } else if (count = bestCount) {
            tied := true
        }
    }
    return (bestCount >= minimumAgreement && !tied) ? bestAmount : 0
}

TowerXPParseRewardAmount(ocrText) {
    if RegExMatch(ocrText, "i)[+t]?\s*(\d[\d,.]*)\s*[xX*][pP]", &xpMatch)
        return Integer(StrReplace(StrReplace(xpMatch[1], ",", ""), ".", ""))
    return 0
}

TowerXPCropRegions(candidate) {
    ; Image backends can report the match point as the center or top-left.
    ; Cover both interpretations, and keep a lower crop for bottom-row cards.
    anchors := [
        { x: candidate.x, y: candidate.y, name: "center" },
        { x: candidate.x + Round(candidate.w / 2), y: candidate.y + Round(candidate.h / 2), name: "top-left" }
    ]
    profiles := [
        { x: -0.55, y: 0.16, w: 1.10, h: 0.72, name: "focused" },
        { x: -0.72, y: 0.05, w: 1.44, h: 1.15, name: "wide-low" },
        { x: -0.72, y: 0.38, w: 1.44, h: 0.82, name: "text-band" }
    ]
    regions := []
    seen := Map()
    for anchor in anchors {
        for profile in profiles {
            region := {
                x: Max(0, Round(anchor.x + (candidate.w * profile.x))),
                y: Max(0, Round(anchor.y + (candidate.h * profile.y))),
                w: Max(40, Round(candidate.w * profile.w)),
                h: Max(40, Round(candidate.h * profile.h)),
                anchor: anchor.name,
                profile: profile.name
            }
            key := region.x ":" region.y ":" region.w ":" region.h
            if seen.Has(key)
                continue
            seen[key] := true
            regions.Push(region)
        }
    }
    return regions
}

TowerXPResultSearchRegion(clientW, clientH) {
    ; Result detection can be confirmed by either the TRIUMPH title near the
    ; top of the panel or the Play Again button below it. Do not derive the
    ; reward-card area from either anchor: their Y positions are on opposite
    ; sides of the cards. This client-relative band covers the reward panel at
    ; supported window sizes while excluding the right-side macro console.
    width := Max(1, Integer(clientW))
    height := Max(1, Integer(clientH))
    left := Round(width * 0.07)
    top := Round(height * 0.32)
    right := Round(width * 0.66)
    bottom := Round(height * 0.84)
    return {
        x: left,
        y: top,
        w: Max(1, right - left),
        h: Max(1, bottom - top)
    }
}

TowerXPEvaluateStopRule(config) {
    stopMode := TowerXPStoredStopMode(config.stopMode)
    if (stopMode = "Never")
        return { triggered: false, message: "" }

    targets := []
    maxTargets := []
    for definition in TowerXPDefinitions() {
        row := config.towers[definition.name]
        if (!row.tracked || !row.stopTarget)
            continue
        targets.Push(definition.name)
        if (Integer(row.level) >= definition.maxLevel)
            maxTargets.Push(definition.name)
    }
    if (targets.Length = 0)
        return { triggered: false, message: "" }

    triggered := stopMode = "Any" ? maxTargets.Length > 0 : maxTargets.Length = targets.Length
    if (!triggered)
        return { triggered: false, message: "" }

    names := ""
    source := stopMode = "Any" ? maxTargets : targets
    for index, name in source
        names .= (index > 1 ? ", " : "") name
    message := stopMode = "Any" ? names " reached level 20" : "all selected towers reached level 20 (" names ")"
    return { triggered: true, message: message }
}

TowerXPStatusText(statePath) {
    config := TowerXPReadConfig(statePath)
    if (!config.enabled)
        return "Tower XP tracker: Off"
    tracked := 0
    for definition in TowerXPDefinitions() {
        if (config.towers[definition.name].tracked)
            tracked += 1
    }
    return "Tower XP tracker: On - " tracked " tower" (tracked = 1 ? "" : "s")
}
