#Requires AutoHotkey v2.0

; Tower Evolution progression shared by the main UI and result watchdog.
; CurrentXP is XP already earned inside the current level, not lifetime XP.
TowerXPDefinitions() {
    static definitions := [
        {name: "Scout",       file: "Scout.png",       baseXP: 50, growth: 1.09,  maxLevel: 20},
        {name: "Minigunner",  file: "Minigunner.png",  baseXP: 50, growth: 1.09,  maxLevel: 20},
        {name: "Crook Boss",  file: "Crookboss.png",   baseXP: 50, growth: 1.09,  maxLevel: 20},
        {name: "Shotgunner",  file: "Shotgunner.png",  baseXP: 50, growth: 1.09,  maxLevel: 20},
        {name: "Operator",    file: "Operator.png",    baseXP: 75, growth: 1.075, maxLevel: 20},
        {name: "Juggernaut",  file: "Juggernaut.png",  baseXP: 75, growth: 1.075, maxLevel: 20},
        {name: "Kingpin",     file: "Kingpin.png",     baseXP: 75, growth: 1.075, maxLevel: 20},
        {name: "Enforcer",    file: "Enforcer.png",    baseXP: 75, growth: 1.075, maxLevel: 20}
    ]
    return definitions
}

TowerXPSectionName(towerName) {
    return "TowerXP_" RegExReplace(towerName, "[^A-Za-z0-9]+", "_")
}

TowerXPNextRequired(definition, currentLevel) {
    currentLevel := Integer(currentLevel)
    if (currentLevel >= definition.maxLevel)
        return 0
    return Floor(definition.baseXP * (definition.growth ** currentLevel))
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

    return {level: level, xp: xp, levelsGained: levelsGained,
        nextRequired: TowerXPNextRequired(definition, level), isMax: level >= definition.maxLevel}
}

; Every tower shown on one Triumph result receives the same tower-XP reward.
; Return a value only when the successful OCR readings have one clear winner;
; ties stay unresolved so a bad reading can never silently invent progression.
TowerXPConsensusAmount(amounts) {
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
    return (bestCount > 0 && !tied) ? bestAmount : 0
}

TowerXPCropRegions(candidate) {
    anchors := [
        {x: candidate.x, y: candidate.y, name: "center"},
        {x: candidate.x + Round(candidate.w / 2), y: candidate.y + Round(candidate.h / 2), name: "top-left"}
    ]
    profiles := [
        {x: -0.55, y: 0.16, w: 1.10, h: 0.72, name: "focused"},
        {x: -0.72, y: 0.05, w: 1.44, h: 1.15, name: "wide-low"},
        {x: -0.72, y: 0.38, w: 1.44, h: 0.82, name: "text-band"}
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
            if (seen.Has(key))
                continue
            seen[key] := true
            regions.Push(region)
        }
    }
    return regions
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
; Progression helpers and reward templates adapted from Kronox Edition (GPL-3.0).
; https://github.com/kronoxhellstorm/tds-macro-kronox/tree/e2f73c0b24dd5e91fb078d097f72ba3e04985e8c

TowerXPNumber(file, section, key, fallback := 0, maxValue := 1000000) {
    raw := IniRead(file, section, key, fallback)
    return RegExMatch(raw, "^\d{1,9}$") ? Min(Integer(raw), maxValue) : fallback
}

TowerXPSavedProgress(file, definition) {
    section := TowerXPSectionName(definition.name)
    raw := IniRead(file, section, "Progress", "")
    if !RegExMatch(raw, "^(\d{1,2}),(\d{1,6}),([a-zA-Z0-9-]*)$", &m)
        return {level: 0, xp: 0, matchId: ""}
    progress := TowerXPAdvance(definition, Integer(m[1]), Integer(m[2]))
    progress.matchId := m[3]
    return progress
}

TowerXPNext(settings) {
    for definition in TowerXPDefinitions() {
        section := TowerXPSectionName(definition.name)
        if IniRead(settings, section, "Tracked", 0) != 1
            continue
        progress := TowerXPSavedProgress(settings, definition)
        if progress.level < TowerXPNumber(settings, section, "Target", 20, 20)
            return definition
    }
    return false
}

TowerXPBuildLoadout(towers, selected) {
    result := "", abstractSlots := 0
    seen := Map()
    seen.CaseSense := "Off"
    for raw in StrSplit(towers, ",") {
        tower := Trim(raw)
        if tower = "Abstract" {
            abstractSlots++
            tower := selected
        }
        if (tower = "" || seen.Has(tower))
            return ""
        seen[tower] := true
        result .= (result = "" ? "" : ", ") tower
    }
    return abstractSlots = 1 ? result : ""
}

TimescaleBudgetAllows(balance, reserve, cap, used) {
    return balance > reserve && (cap = 0 || used < cap)
}
