; Match-boundary evidence shared by the engine/guard. No text-keyword OCR.
; A result must coexist with a post-match control in two fresh observations.
UM14_MatchScreenEvidence(result, width, height, search := "") {
    if ((result != "Triumph" && result != "Loss") || width < 240 || height < 240 || width > 8192 || height > 8192)
        return false
    if (!IsObject(search))
        search := AdvancedImageSearch
    results := result == "Loss" ? ["Resources/YouLost.png"] : ["Resources/triumph.png", "Resources/PlayAgain.png"]
    resultSeen := false
    for image in results {
        found := search.Call(image, width * 0.2, height * 0.2, width * 0.6, height * 0.7)
        if (found.status == "success" && found.score > 0.7) {
            resultSeen := true
            break
        }
    }
    if (!resultSeen)
        return false
    for image in ["Resources/PlayAgain.png", "Resources/Restart.png", "Resources/Restart2.png"] {
        found := search.Call(image, width * 0.2, height * 0.5, width * 0.6, height * 0.4)
        if (found.status == "success" && found.score > 0.7)
            return true
    }
    return false
}

; Pure reducer for inert tests. Time is only stability/expiry, never match proof.
UM14_ObserveMatchResult(previous, result, evidence, tick, matchRun) {
    if (!evidence || !RegExMatch(matchRun, "^[a-f0-9]{32}$") || (result != "Triumph" && result != "Loss"))
        return {ready:false, result:"", first:0, run:""}
    if (!IsObject(previous) || previous.result != result || previous.run != matchRun
        || tick < previous.first || tick - previous.first > 3000)
        return {ready:false, result:result, first:tick, run:matchRun}
    return {ready:tick - previous.first >= 350, result:result, first:previous.first, run:matchRun}
}

UM14_ValidMatchCompletion(marker, session, matchRun) {
    if (!RegExMatch(session, "^[a-f0-9]{32}$") || !RegExMatch(matchRun, "^[a-f0-9]{32}$"))
        return ""
    if (marker == session "|" matchRun "|Triumph")
        return "Triumph"
    if (marker == session "|" matchRun "|Loss")
        return "Loss"
    return ""
}
