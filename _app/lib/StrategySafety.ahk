#Requires AutoHotkey v2.0

; Defensive .strat decoder/validator for the standalone WebView editor.
; This is intentionally UI-agnostic: the recovered alpha UI remains unchanged while
; file safety matches the hardened Strategy Lab 0.5 editor contract.

global SLE_StrategyMaxBytes := 5 * 1024 * 1024
global SLE_StrategyMaxPlacements := 5000
global SLE_StrategyCoordinateEnvelope := 10000

SLE_StrategyHasNul(text) {
    Loop StrLen(text) {
        if (Ord(SubStr(text, A_Index, 1)) = 0)
            return true
    }
    return false
}

SLE_StrategyTrimTerminalNuls(text) {
    removed := 0
    while (StrLen(text) > 0) {
        if (Ord(SubStr(text, -1, 1)) != 0)
            break
        text := SubStr(text, 1, StrLen(text) - 1)
        removed += 1
    }
    return {Text: text, Removed: removed}
}

SLE_StrategyGuessUtf16(raw) {
    sampleSize := Min(raw.Size, 4096)
    pairCount := Floor(sampleSize / 2)
    if (pairCount < 4)
        return ""

    evenZeros := 0
    oddZeros := 0
    Loop pairCount {
        offset := (A_Index - 1) * 2
        if (NumGet(raw, offset, "UChar") = 0)
            evenZeros += 1
        if (NumGet(raw, offset + 1, "UChar") = 0)
            oddZeros += 1
    }

    threshold := Max(4, Floor(pairCount * 0.35))
    if (oddZeros >= threshold && oddZeros > evenZeros * 2)
        return "LE"
    if (evenZeros >= threshold && evenZeros > oddZeros * 2)
        return "BE"
    return ""
}

SLE_StrategyDecodeUtf16BE(raw, offset := 0) {
    byteCount := raw.Size - offset
    if (byteCount <= 0)
        return ""
    if (Mod(byteCount, 2) != 0)
        throw Error("UTF-16BE strategy has an odd byte count and appears truncated.")

    swapped := Buffer(byteCount + 2, 0)
    pairCount := Floor(byteCount / 2)
    Loop pairCount {
        src := offset + (A_Index - 1) * 2
        dst := (A_Index - 1) * 2
        NumPut("UChar", NumGet(raw, src + 1, "UChar"), swapped, dst)
        NumPut("UChar", NumGet(raw, src, "UChar"), swapped, dst + 1)
    }
    return StrGet(swapped, pairCount, "UTF-16")
}

SLE_StrategyReadFile(path) {
    if (path = "" || !FileExist(path))
        throw Error("Strategy file does not exist.")

    raw := FileRead(path, "RAW")
    if (raw.Size <= 0)
        return {Text: "", Encoding: "UTF-8-RAW", TerminalNuls: 0}

    b0 := raw.Size >= 1 ? NumGet(raw, 0, "UChar") : -1
    b1 := raw.Size >= 2 ? NumGet(raw, 1, "UChar") : -1
    b2 := raw.Size >= 3 ? NumGet(raw, 2, "UChar") : -1
    encoding := ""
    text := ""

    if (raw.Size >= 3 && b0 = 0xEF && b1 = 0xBB && b2 = 0xBF) {
        text := FileRead(path, "UTF-8")
        encoding := "UTF-8"
    } else if (raw.Size >= 2 && b0 = 0xFF && b1 = 0xFE) {
        text := FileRead(path, "UTF-16")
        encoding := "UTF-16"
    } else if (raw.Size >= 2 && b0 = 0xFE && b1 = 0xFF) {
        text := SLE_StrategyDecodeUtf16BE(raw, 2)
        ; AutoHotkey's standard writer is UTF-16LE. Normalize the uncommon BE format
        ; to UTF-8 on an intentional save instead of silently corrupting it.
        encoding := "UTF-8"
    } else {
        guess := SLE_StrategyGuessUtf16(raw)
        if (guess = "LE") {
            text := FileRead(path, "UTF-16-RAW")
            encoding := "UTF-16-RAW"
        } else if (guess = "BE") {
            text := SLE_StrategyDecodeUtf16BE(raw)
            encoding := "UTF-8"
        } else {
            text := FileRead(path, "UTF-8-RAW")
            encoding := "UTF-8-RAW"
            if InStr(text, Chr(0xFFFD)) {
                ansi := FileRead(path, "CP0")
                if !InStr(ansi, Chr(0xFFFD)) {
                    text := ansi
                    encoding := "CP0"
                }
            }
        }
    }

    trimmed := SLE_StrategyTrimTerminalNuls(text)
    text := trimmed.Text
    if SLE_StrategyHasNul(text)
        throw Error("Strategy contains embedded NUL bytes inside its text and cannot be edited safely.")

    return {Text: text, Encoding: encoding, TerminalNuls: trimmed.Removed}
}

SLE_LoadValidatedStrategy(path) {
    global SLE_StrategyMaxBytes, SLE_StrategyMaxPlacements, SLE_StrategyCoordinateEnvelope

    if (path = "" || !FileExist(path))
        throw Error("Strategy file does not exist.")
    SplitPath(path,,, &ext)
    if (StrLower(ext) != "strat")
        throw Error("Only .strat files can be opened in Strategy Lab.")

    size := FileGetSize(path)
    if (size <= 0)
        throw Error("Strategy file is empty.")
    if (size > SLE_StrategyMaxBytes)
        throw Error("Strategy file is larger than the 5 MB editor safety limit.")

    loaded := SLE_StrategyReadFile(path)
    text := loaded.Text
    if !RegExMatch(text, "im)^\s*\[Steps\]\s*$")
        throw Error("Strategy does not contain a [Steps] section.")

    calibrationOnly := RegExMatch(text, "im)^\s*strategyLabMode\s*=\s*sandbox-calibration\s*$")
    spawnCount := 0
    suspicious := 0
    for rawLine in StrSplit(StrReplace(text, "`r"), "`n") {
        line := Trim(rawLine)
        if !RegExMatch(line, "i)^SpawnTower\(")
            continue
        spawnCount += 1
        if (spawnCount > SLE_StrategyMaxPlacements)
            throw Error("Strategy contains more than 5,000 SpawnTower placements.")
        if !RegExMatch(line, "i)^SpawnTower\(\s*(-?\d+)\s*,\s*(-?\d+)", &m)
            throw Error("Strategy contains a SpawnTower line the visual editor cannot parse safely.")
        x := Integer(m[1])
        y := Integer(m[2])
        if (Abs(x) > SLE_StrategyCoordinateEnvelope || Abs(y) > SLE_StrategyCoordinateEnvelope)
            suspicious += 1
    }

    if (spawnCount = 0 && !calibrationOnly)
        throw Error("No SpawnTower placements were found in [Steps].")
    if (suspicious > 0)
        throw Error("Strategy contains placement coordinates outside the editor safety envelope.")

    return {
        Text: text,
        Encoding: loaded.Encoding,
        TerminalNuls: loaded.TerminalNuls,
        Size: size,
        Placements: spawnCount,
        CalibrationOnly: calibrationOnly
    }
}
