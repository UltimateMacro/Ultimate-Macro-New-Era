; Local-only result accounting, shared with the original watchdog summary.
; No new network operation or mouse movement. Missing OCR stays unknown.

UM14_RecordMatchStats(result) {
    global StateFile, SendCurrenciesEnabled
    if (!(result == "Triumph" || result == "Loss"))
        return false
    ; SendInfo consumes this per-match timestamp, making later legacy calls
    ; no-ops instead of double-counting. The caller holds its own run receipt.
    started := IniRead(StateFile, "State", "TimeWhenStartedPlaying", "")
    if (!RegExMatch(started, "^\d{1,20}$"))
        return false
    if (SendCurrenciesEnabled != "1")
        for name in ["Coins", "Gems", "EXP"]
            IniWrite(0, StateFile, "State", "UM14StatsKnown" name)
    SendInfo(result)
    return true
}

UM14_RewardNumber(text, kind) {
    patterns := Map("Coins", "coins?", "Gems", "gems?", "EXP", "(?:xp|exp)")
    limits := Map("Coins", 5000000, "Gems", 1000000, "EXP", 100000000)
    if (!patterns.Has(kind) || Type(text) != "String" || StrLen(text) > 16384)
        return -1
    ; Refuse malformed grouping, negatives and conflicting duplicate readings.
    pattern := "im)(?:^|[\r\n])\s*\+?\s*((?:\d{1,3}(?:,\d{3})+|\d{1,12}))\s*" patterns[kind] "\b"
    found := -1, position := 1, readings := 0
    while (position <= StrLen(text) && (position := RegExMatch(text, pattern, &item, position))) {
        readings += 1
        if (readings > 32)
            return -1
        value := Integer(StrReplace(item[1], ",", ""))
        if (value > limits[kind] || (found != -1 && found != value))
            return -1
        found := value
        position += Max(1, item.Len(0))
    }
    return found
}

UM14_RewardValue(text, kind) {
    global StateFile
    value := UM14_RewardNumber(text, kind)
    if (value < 0) {
        ; A missed reward cannot be reconstructed later; don't certify the
        ; cumulative partial sum as complete until the next locally started run.
        IniWrite(0, StateFile, "State", "UM14StatsKnown" kind)
        return 0
    }
    return value
}

UM14_ClientRegionBitmap(x, y, width, height) {
    ; Origin/foreground checks prevent collecting an unrelated screen region
    ; when Roblox is docked, moved, minimized or covered by another app.
    hwnd := GetRobloxHWND()
    if (!hwnd || DllCall("IsIconic", "Ptr", hwnd))
        return 0
    root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    if (!WinActive("ahk_id " (root ? root : hwnd)))
        return 0
    UM14_PhysicalDpi()
    WinGetClientPos(&screenX, &screenY, &clientW, &clientH, "ahk_id " hwnd)
    region := UM14_Region(x, y, width, height, clientW, clientH)
    if (!IsObject(region) || region.x != Floor(x) || region.y != Floor(y)
        || region.w != Ceil(width) || region.h != Ceil(height))
        return 0
    return Gdip_BitmapFromScreen((screenX+region.x) "|" (screenY+region.y) "|" region.w "|" region.h)
}
