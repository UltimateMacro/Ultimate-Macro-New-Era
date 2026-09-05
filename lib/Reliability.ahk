#Requires AutoHotkey v2.0

global ReliabilityFaults := Map("drop_click_once", false, "image_failure_once", false,
    "delay_detection_once_ms", 0, "ocr_failure_once", false, "stale_detection_once", false,
    "force_reconnect_failure", false, "force_launch_failure", false, "force_post_action_failure_once", false,
    "force_nested_recovery_once", false, "drop_movement_key_once", false,
    "simulate_stuck_segment_once", false, "focus_loss_once", false,
    "delay_key_release_once", false, "skip_checkpoint_once", false,
    "checkpoint_never_once", false, "stale_checkpoint_once", false,
    "force_navigation_failure_once", false)
global ReliabilityBudgets := Map()
global ReliabilityRecoveryState := { in_progress: false, operation_id: "", depth: 0 }
global ReliabilityPathOperations := Map()

ReliabilityCategoryNames() {
    return ["DETECTION_FAILURE", "STATE_UNKNOWN", "INTERACTION_FAILED", "NAVIGATION_FAILED",
        "TIMEOUT", "GAME_DISCONNECTED", "GAME_FROZEN", "STRATEGY_FAILED", "ENVIRONMENT_INVALID",
        "INTERNAL_ERROR"]
}

; Cheap, evidence-carrying detector for the states currently used by recovery.
; It deliberately reports UNKNOWN when no stable anchor is available.
ReliabilityDetectState() {
    if !GetRobloxHWND()
        return { state: "ROBLOX_CLOSED", confidence: 1.0, evidence: "Roblox window absent" }
    if !getRobloxPos(, , &w, &h)
        return { state: "UNKNOWN", confidence: 0, evidence: "Roblox geometry unavailable" }

    if ImageSearch(&fx, &fy, 0, 0, w, h, "*26 Resources\\Disconnected.png")
        return { state: "DISCONNECTED", confidence: 0.95, evidence: "Disconnected.png" }
    if ImageSearch(&fx, &fy, 0, 0, w, h, "*26 Resources\\disconnected2.png")
        return { state: "DISCONNECTED", confidence: 0.95, evidence: "disconnected2.png" }
    blocker := ReliabilityDetectBlocker(w, h)
    if (blocker.state != "")
        return blocker

    play := ReliabilitySearchTemplate("Play", Round(w * 0.2), Round(h * 0.55), Round(w * 0.7), Round(h * 0.45))
    if (play.status = "success" && play.score > 0.65)
        return { state: "TDS_LOBBY", confidence: play.score, evidence: "Play.png" }

    mapMenu := AdvancedImageSearch("Resources\\map_selection.png", 0, 0, Round(w * 0.55), h)
    if (mapMenu.status = "success" && mapMenu.score > 0.51) {
        for cardName in ["Easy", "Frost", "Molten", "Hardcore", "Voidcore"] {
            cardConflict := ReliabilitySearchTemplate(cardName, Round(w * 0.22), Round(h * 0.06),
                Round(w * 0.62), Round(h * 0.76), 0.5, 1.5)
            if (cardConflict.status = "success" && cardConflict.score >= 0.62) {
                RuntimeLogWarn("state_anchor_conflict", "Map-selection and matchmaking anchors conflict",
                    "map_score=" mapMenu.score "; card=" cardName "; card_score=" cardConflict.score)
                return { state: "UNKNOWN", confidence: 0, evidence: "map_selection + " cardName }
            }
        }
        return { state: "MAP_SELECTION", confidence: mapMenu.score, evidence: "map_selection.png" }
    }

    for cardName in ["Easy", "Frost", "Molten", "Hardcore", "Voidcore"] {
        card := ReliabilitySearchTemplate(cardName, Round(w * 0.22), Round(h * 0.06),
            Round(w * 0.62), Round(h * 0.76), 0.5, 1.5)
        if (card.status = "success" && card.score >= 0.62)
            return { state: "MATCHMAKING", confidence: card.score, evidence: cardName ".png" }
    }

    readyGame := AdvancedImageSearch("Resources\\ready_gs.png", Round(w * 0.25), Round(h * 0.55), Round(w * 0.5), Round(h * 0.45))
    if (readyGame.status = "success" && readyGame.score >= 0.65)
        return { state: "GAME_LOADING", confidence: readyGame.score, evidence: "ready_gs.png" }
    skip := AdvancedImageSearch("Resources\\skip.png", Round(w * 0.55), Round(h * 0.55), Round(w * 0.45), Round(h * 0.45))
    if (skip.status = "success" && skip.score >= 0.65)
        return { state: "IN_GAME", confidence: skip.score, evidence: "skip.png" }

    ready := AdvancedImageSearch("Resources\\Ready.png", Round(w * 0.2), Round(h * 0.55), Round(w * 0.7), Round(h * 0.45))
    if (ready.status = "success" && ready.score >= 0.65)
        return { state: "MAP_VOTING", confidence: ready.score, evidence: "Ready.png" }

    loading := AdvancedImageSearch("Resources\\please_wait.png", 0, 0, w, h)
    if (loading.status = "success" && loading.score >= 0.65)
        return { state: "TDS_LOADING", confidence: loading.score, evidence: "please_wait.png" }

    return { state: "UNKNOWN", confidence: 0, evidence: "No stable state anchor" }
}

ReliabilityDetectBlocker(w, h) {
    if ImageSearch(&fx, &fy, Round(w * 0.18), Round(h * 0.32), Round(w * 0.64), Round(h * 0.55),
        "*50 Resources\\cancel_rejoin.png")
        return { state: "BLOCKER_REJOIN_MODAL", confidence: 0.9, evidence: "cancel_rejoin.png" }
    if ImageSearch(&fx, &fy, Round(w * 0.2), Round(h * 0.32), Round(w * 0.6), Round(h * 0.5),
        "*50 Resources\\notnow.png")
        return { state: "BLOCKER_POPUP", confidence: 0.85, evidence: "notnow.png" }
    if ImageSearch(&fx, &fy, Round(w * 0.2), Round(h * 0.32), Round(w * 0.6), Round(h * 0.5),
        "*50 Resources\\Claim.png")
        return { state: "BLOCKER_REWARD_POPUP", confidence: 0.85, evidence: "Claim.png" }
    ; BLOCKER_MODAL must not be inferred from close.png alone. That generic red
    ; X is also a normal close control on valid lobby/map screens.
    return { state: "", confidence: 0, evidence: "" }
}

ReliabilityIsPlausibleLabel(value) {
    value := Trim(value)
    return (value != "" && StrLen(value) <= 48 && RegExMatch(value, "^[A-Za-z0-9 .'-]+$"))
}

; Prefer the checked-in primary template, then try a supplied UI crop as a
; bounded fallback. Callers still choose the minimum score for their action.
ReliabilitySearchTemplate(name, x, y, w, h, minScale := 0.0, maxScale := 0.0, scaleStep := 0.05) {
    paths := ["Resources\\" name ".png", "Resources\\DetectionVariants\\" name ".png"]
    best := { status: "failure", score: 0, x: 0, y: 0 }
    for path in paths {
        if !FileExist(path)
            continue
        candidate := AdvancedImageSearch(path, x, y, w, h, minScale, maxScale, scaleStep)
        if (candidate.status = "success" && candidate.score > best.score)
            best := candidate
    }
    return best
}

ReliabilityPathBegin(operationId) {
    global ReliabilityPathOperations
    operation := { id: operationId, segment: 1, checkpoint: "", attempts: 0, started: A_TickCount,
        last_checkpoint: 0, failure: "" }
    ReliabilityPathOperations[operationId] := operation
    return operation
}

ReliabilityPathAttempt(operation, segment := 1) {
    operation.segment := segment
    operation.attempts += 1
    return operation.attempts
}

ReliabilityPathCheckpoint(operation, checkpoint) {
    operation.checkpoint := checkpoint
    operation.last_checkpoint := A_TickCount
    operation.attempts := 0
}

ReliabilityPathFailure(operation, reason) {
    operation.failure := reason
    result := ReliabilityFailure("NAVIGATION_FAILED", operation.id, reason)
    result.detected := operation.checkpoint
    result.action := "path segment " operation.segment
    result.retry := operation.attempts
    result.elapsed_ms := A_TickCount - operation.started
    ReliabilityLogFailure(result, "return_failure", "failed")
    return result
}

ReliabilityDetectStableState(expectedStates, samples := 2, timeoutMs := 2500) {
    startTime := A_TickCount
    requiredSamples := Max(2, samples)
    remainingSamples := requiredSamples
    stableState := ""
    stableEvidence := ""
    stableConfidence := 0
    while (A_TickCount - startTime < timeoutMs) {
        sample := ReliabilityDetectState()
        matches := false
        for expected in (expectedStates is Array ? expectedStates : [expectedStates]) {
            if (sample.state = expected)
                matches := true
        }
        if (matches) {
            if (stableState = sample.state && stableEvidence = sample.evidence) {
                remainingSamples -= 1
                stableConfidence := Min(stableConfidence, sample.confidence)
                if (remainingSamples <= 0)
                    return { state: sample.state, confidence: stableConfidence, evidence: sample.evidence,
                        stable: true, elapsed_ms: A_TickCount - startTime }
            } else {
                stableState := sample.state
                stableEvidence := sample.evidence
                stableConfidence := sample.confidence
                remainingSamples := requiredSamples - 1
            }
        } else {
            stableState := ""
            stableEvidence := ""
            stableConfidence := 0
            remainingSamples := requiredSamples
        }
        Sleep(150)
    }
    RuntimeLogWarn("state_stability_timeout", "Expected state was not stable within the bounded window",
        "expected=" (expectedStates is Array ? "multiple" : expectedStates) "; last=" stableState)
    return { state: "UNKNOWN", confidence: 0, evidence: "unstable state", stable: false,
        elapsed_ms: A_TickCount - startTime }
}

ReliabilityWaitForTransition(previousState, action, allowedStates, timeoutMs := 8000) {
    startTime := A_TickCount
    while (A_TickCount - startTime < timeoutMs) {
        sample := ReliabilityDetectState()
        allowed := false
        for expected in (allowedStates is Array ? allowedStates : [allowedStates]) {
            if (sample.state = expected)
                allowed := true
        }
        if (allowed && sample.state != previousState) {
            stable := ReliabilityDetectStableState(sample.state, 2, 1800)
            if (stable.stable)
                return { ok: true, state: stable.state, confidence: stable.confidence,
                    evidence: stable.evidence, elapsed_ms: A_TickCount - startTime }
        }
        Sleep(150)
    }
    result := ReliabilityFailure("TIMEOUT", "ReliabilityWaitForTransition", "Expected transition was not verified")
    result.expected := (allowedStates is Array ? "allowed next state" : allowedStates)
    result.detected := previousState
    result.action := action
    result.elapsed_ms := A_TickCount - startTime
    ReliabilityLogFailure(result, "return_failure", "failed")
    return result
}

ReliabilitySuccess(source := "", detected := "", details := "") {
    return { ok: true, category: "", source: source, expected: "", detected: detected, action: "",
        detector: "", confidence: 0, retry: 0, elapsed_ms: 0, message: details }
}

ReliabilityFailure(category, source, message := "", context := "") {
    return { ok: false, category: category, source: source, expected: "", detected: "", action: "",
        detector: "", confidence: 0, retry: 0, elapsed_ms: 0, message: message, context: context }
}

ReliabilityLogFailure(result, recovery := "", finalResult := "") {
    if (!IsObject(result) || result.ok)
        return
    details := "category=" result.category "; source=" result.source "; retry=" result.retry
        . "; elapsed_ms=" result.elapsed_ms
    if (result.expected != "")
        details .= "; expected=" result.expected
    if (result.detected != "")
        details .= "; detected=" result.detected
    if (result.action != "")
        details .= "; action=" result.action
    if (result.detector != "")
        details .= "; detector=" result.detector
    if (result.confidence != 0)
        details .= "; confidence=" result.confidence
    if (recovery != "")
        details .= "; recovery=" recovery
    if (finalResult != "")
        details .= "; final=" finalResult
    ; Reliability results are plain AHK objects, not Maps. Keep the failure
    ; logger safe because it runs while another failure is being reported.
    if (HasProp(result, "context") && result.context != "")
        details .= "; " result.context
    RuntimeLogWarn("reliability_failure", result.message, details)
}

ReliabilityBudget(key, category, limit := 3, windowMs := 120000) {
    global ReliabilityBudgets
    now := A_TickCount
    id := key "|" category
    if (!ReliabilityBudgets.Has(id) || now - ReliabilityBudgets[id].started > windowMs)
        ReliabilityBudgets[id] := { started: now, attempts: 0 }
    ReliabilityBudgets[id].attempts += 1
    return { allowed: ReliabilityBudgets[id].attempts <= limit, attempt: ReliabilityBudgets[id].attempts,
        elapsed_ms: now - ReliabilityBudgets[id].started }
}

ReliabilityFault(name) {
    global ReliabilityFaults
    if (!ReliabilityFaults.Has(name))
        return false
    value := ReliabilityFaults[name]
    if (InStr(name, "_once"))
        ReliabilityFaults[name] := false
    return value
}

ReliabilityShouldDropClick() {
    return ReliabilityFault("drop_click_once")
}

ReliabilityBeginRecovery(operationId) {
    global ReliabilityRecoveryState
    if (ReliabilityRecoveryState.in_progress) {
        RuntimeLogWarn("recovery_reentry_blocked", "Recovery was already in progress",
            "operation=" operationId "; active=" ReliabilityRecoveryState.operation_id "; depth=" ReliabilityRecoveryState.depth)
        return false
    }
    ReliabilityRecoveryState.in_progress := true
    ReliabilityRecoveryState.operation_id := operationId
    ReliabilityRecoveryState.depth := 1
    return true
}

ReliabilityEndRecovery() {
    global ReliabilityRecoveryState
    ReliabilityRecoveryState.in_progress := false
    ReliabilityRecoveryState.operation_id := ""
    ReliabilityRecoveryState.depth := 0
}
