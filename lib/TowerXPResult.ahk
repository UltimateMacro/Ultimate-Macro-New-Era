#Requires AutoHotkey v2.0

; Read-only Triumph reward scanner. This module never clicks, moves the mouse,
; sends keys, launches programs, or changes the active Roblox UI.

TowerXPEmptyResult() {
    return {
        enabled: false,
        detected: 0,
        summary: "",
        stopTriggered: false,
        stopMessage: "",
        duplicate: false,
        diagnostics: []
    }
}

TowerXPEnsurePortraitTemplate(definition, resourcesDir, cacheDir) {
    sourcePath := resourcesDir "\TowerXP\" definition.file
    if !FileExist(sourcePath)
        return ""
    if !DirExist(cacheDir)
        DirCreate(cacheDir)

    targetPath := cacheDir "\" RegExReplace(definition.name, "[^A-Za-z0-9]+", "_") "_portrait.png"
    rebuild := !FileExist(targetPath)
    if (!rebuild) {
        try rebuild := FileGetTime(sourcePath, "M") > FileGetTime(targetPath, "M")
    }
    if (!rebuild)
        return targetPath

    sourceBitmap := Gdip_CreateBitmapFromFile(sourcePath)
    if (!sourceBitmap)
        return ""
    Gdip_GetImageDimensions(sourceBitmap, &sourceW, &sourceH)
    portraitH := Max(1, Round(sourceH * 0.72))
    portraitBitmap := Gdip_CloneBitmapArea(sourceBitmap, 0, 0, sourceW, portraitH)
    Gdip_DisposeImage(sourceBitmap)
    if (!portraitBitmap)
        return ""
    try Gdip_SaveBitmapToFile(portraitBitmap, targetPath, 100)
    Gdip_DisposeImage(portraitBitmap)
    return FileExist(targetPath) ? targetPath : ""
}

TowerXPReadRewardAmount(candidate) {
    robloxHwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
    if (!robloxHwnd)
        robloxHwnd := WinExist("Roblox ahk_exe ApplicationFrameHost.exe")
    if (!robloxHwnd)
        return { amount: 0, detail: "Roblox window unavailable" }

    samples := []
    lastError := ""
    regions := TowerXPCropRegions(candidate)
    for region in regions {
        ocrBitmap := 0
        ocrText := ""
        try {
            ocrBitmap := OCR.CreateHBitmap(region.x, region.y, region.w, region.h,
                { hWnd: robloxHwnd, onlyClientArea: 1, mode: 2 }, 4)
            ocrText := OCR.FromBitmap(ocrBitmap, { lang: "en-US", grayscale: true }).Text
        } catch Error as err {
            lastError := err.Message
        } finally {
            ; OCR.CreateHBitmap returns an owning OCR.IBase wrapper. Let its
            ; destructor release the HBITMAP/DC; DeleteObject would be invalid.
            ocrBitmap := 0
        }

        amount := TowerXPParseRewardAmount(ocrText)
        if (amount > 0) {
            return { amount: amount, detail: region.anchor "/" region.profile }
        }
        cleanText := Trim(StrReplace(StrReplace(ocrText, "`r", " "), "`n", " "))
        if (cleanText != "")
            samples.Push(cleanText)
    }

    detail := ""
    for index, sample in samples
        detail .= (index > 1 ? " | " : "") sample
    if (detail = "")
        detail := lastError != "" ? "OCR error: " lastError : "empty OCR result"
    return { amount: 0, detail: detail }
}

TowerXPProcessTriumph(foundX, foundY, clientW, clientH, statePath, legacySettingsFile,
    runtimeStateFile, resourcesDir) {
    result := TowerXPEmptyResult()
    if !TowerXPEnabled(statePath, legacySettingsFile)
        return result
    result.enabled := true

    runKey := TowerXPGetRunKey(runtimeStateFile)
    if TowerXPWasRunProcessed(statePath, runKey) {
        result.duplicate := true
        result.diagnostics.Push("Triumph already processed for this run; progression left unchanged.")
        return result
    }

    config := TowerXPReadConfig(statePath)
    searchRegion := TowerXPResultSearchRegion(clientW, clientH)
    searchX := searchRegion.x
    searchY := searchRegion.y
    searchW := searchRegion.w
    searchH := searchRegion.h
    cacheDir := A_AppData "\Ultimate_Macro\TowerXPTemplates"
    candidates := []

    for definition in TowerXPDefinitions() {
        if (!config.towers[definition.name].tracked)
            continue
        templatePath := TowerXPEnsurePortraitTemplate(definition, resourcesDir, cacheDir)
        if (templatePath = "") {
            result.diagnostics.Push("Missing default-skin template for " definition.name ".")
            continue
        }
        match := AdvImageSearch(templatePath, searchX, searchY, searchW, searchH, 0.65, 1.6, 0.025)
        if (match.status = "success" && match.score >= 0.80) {
            candidates.Push({
                definition: definition,
                x: match.x,
                y: match.y,
                w: match.w,
                h: match.h,
                score: match.score
            })
        } else if (match.status = "success" && match.score >= 0.68) {
            result.diagnostics.Push("Ignored uncertain " definition.name " portrait at " Round(match.score * 100) "% confidence.")
        }
    }

    ; Card borders are similar. If multiple templates land on one card, keep
    ; only the strongest match so the same reward cannot update two towers.
    accepted := []
    while (candidates.Length > 0) {
        bestIndex := 1
        Loop candidates.Length {
            if (candidates[A_Index].score > candidates[bestIndex].score)
                bestIndex := A_Index
        }
        candidate := candidates.RemoveAt(bestIndex)
        overlaps := false
        for existing in accepted {
            distance := Sqrt(((candidate.x - existing.x) ** 2) + ((candidate.y - existing.y) ** 2))
            if (distance < Max(candidate.w, existing.w) * 0.65) {
                overlaps := true
                break
            }
        }
        if (!overlaps)
            accepted.Push(candidate)
    }

    readings := []
    directAmounts := []
    for candidate in accepted {
        reading := TowerXPReadRewardAmount(candidate)
        readings.Push({ candidate: candidate, amount: reading.amount, detail: reading.detail })
        if (reading.amount > 0)
            directAmounts.Push(reading.amount)
        else
            result.diagnostics.Push("Could not read " candidate.definition.name " XP: " reading.detail)
    }

    sharedRewardXP := TowerXPConsensusAmount(directAmounts, 2)
    summaries := []
    for reading in readings {
        gainedXP := reading.amount
        usedConsensus := false
        if (gainedXP <= 0 && sharedRewardXP > 0) {
            gainedXP := sharedRewardXP
            usedConsensus := true
        }
        if (gainedXP <= 0)
            continue

        definition := reading.candidate.definition
        row := config.towers[definition.name]
        progress := TowerXPAdvance(definition, row.level, row.xp, gainedXP)
        row.level := progress.level
        row.xp := progress.xp
        row.lastGainedXP := gainedXP
        row.lastUpdated := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        status := progress.isMax ? "MAX" : progress.xp "/" progress.nextRequired
        summaries.Push(definition.name " +" gainedXP (usedConsensus ? " (confirmed shared reward)" : "")
            " -> L" progress.level " " status)
        result.detected += 1
    }

    for index, summary in summaries
        result.summary .= (index > 1 ? " | " : "") summary

    if (result.detected > 0) {
        config.lastProcessedRun := runKey
        TowerXPPersistConfig(config, statePath)
        stopEvaluation := TowerXPEvaluateStopRule(config)
        result.stopTriggered := stopEvaluation.triggered
        result.stopMessage := stopEvaluation.message
    } else {
        result.diagnostics.Push("No confident tracked-tower reward was read; progression was not changed.")
    }
    return result
}
