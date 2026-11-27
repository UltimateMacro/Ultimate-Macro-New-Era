EarningsRewards() => [
    ["coins", "Coins", "Coins.png"], ["gems", "Gems", "Gems.png"], ["playerXP", "XP", "PlayerXP.png"], ["towerXP", "Tower XP", "TowerXP.png"],
    ["spin", "Spin Tickets", "SpinTickets.png"], ["timescale", "Timescale Tickets", "TimescaleTickets.png"]
]

EarningsIcon(file) => A_ScriptDir "\Resources\Gui\Earnings\" file

FarmingEarningsBuild(gui) {
    global FarmEarnings := {page: 1, cards: [], rows: [], items: []}
    view := FarmEarnings
    section := "Earnings"
    for index, reward in EarningsRewards() {
        x := 50 + (index - 1) * 101
        tile := FarmAdd(gui, section, "Text", "x" x " y146 w94 h76 Background202020", "")
        FarmRound(tile.Hwnd)
        FarmAdd(gui, section, "Picture", "x" (x + 35) " y153 w24 h-1 BackgroundTrans", EarningsIcon(reward[3]))
        FarmAdd(gui, section, "Text", "x" x " y180 w94 h17 Center BackgroundTrans", reward[2])
        value := FarmAdd(gui, section, "Text", "x" x " y198 w94 h20 Center BackgroundTrans", "")
        AppearanceFont(value, "s12 Bold cFFFFFF")
        view.cards.Push(value)
    }
    view.period := FarmAdd(gui, section, "DropDownList", "x50 y236 w136 Choose3", ["Last 24 hours", "Last 7 days", "All time"])
    view.sort := FarmAdd(gui, section, "DropDownList", "x194 y236 w140 Choose1", ["Newest", "Coins", "Gems", "XP", "Tower XP", "Spin Tickets", "Timescale Tickets", "Duration"])
    view.period.OnEvent("Change", FarmingEarningsReset)
    view.sort.OnEvent("Change", FarmingEarningsReset)
    refresh := FarmAdd(gui, section, "Button", "x342 y236 w90 h24", "Refresh")
    refresh.OnEvent("Click", FarmingEarningsRender)
    totals := FarmAdd(gui, section, "Button", "x440 y236 w158 h24", "Exact totals")
    totals.OnEvent("Click", FarmingEarningsTotals)
    view.status := FarmAdd(gui, section, "Text", "x50 y269 w590 h20", "")
    Loop 4 {
        slot := A_Index
        y := 292 + (slot - 1) * 46
        bg := FarmAdd(gui, section, "Text", "x50 y" y " w600 h40 Background202020", "")
        FarmRound(bg.Hwnd)
        tag := FarmAdd(gui, section, "Text", "x60 y" (y + 4) " w450 h16 +0x4000 BackgroundTrans", "")
        cells := [], controls := [bg, tag]
        Loop 3 {
            cx := 60 + (A_Index - 1) * 128
            icon := FarmAdd(gui, section, "Picture", "x" cx " y" (y + 21) " w14 h14 BackgroundTrans", EarningsIcon("Coins.png"))
            amount := FarmAdd(gui, section, "Text", "x" (cx + 20) " y" (y + 20) " w106 h16 +0x4000 BackgroundTrans", "")
            cells.Push({icon: icon, amount: amount})
            controls.Push(icon, amount)
        }
        gains := FarmAdd(gui, section, "Text", "x60 y" (y + 20) " w350 h16 BackgroundTrans", "")
        overflow := FarmAdd(gui, section, "Text", "x444 y" (y + 20) " w68 h16 BackgroundTrans", "")
        duration := FarmAdd(gui, section, "Text", "x512 y" (y + 10) " w92 h20 Center BackgroundTrans", "")
        more := FarmAdd(gui, section, "Button", "x610 y" (y + 7) " w32 h26", Chr(0x2026))
        FarmRound(more.Hwnd)
        more.OnEvent("Click", FarmingEarningsMenu.Bind(slot))
        controls.Push(gains, overflow, duration, more)
        view.rows.Push({controls: controls, tag: tag, gains: gains, overflow: overflow, cells: cells, duration: duration})
    }
    view.prev := FarmAdd(gui, section, "Button", "x50 y484 w108 h30", "Previous")
    view.prev.OnEvent("Click", FarmingEarningsPage.Bind(-1))
    view.next := FarmAdd(gui, section, "Button", "x166 y484 w138 h30", "")
    view.next.OnEvent("Click", FarmingEarningsPage.Bind(1))
}

FarmingEarningsReset(*) {
    global FarmEarnings
    FarmEarnings.page := 1
    FarmingEarningsRender()
}

FarmingEarningsPage(delta, *) {
    global FarmEarnings
    FarmEarnings.page += delta
    FarmingEarningsRender()
}

FarmingEarningsRender(*) {
    global FarmEarnings
    view := FarmEarnings
    days := view.period.Value = 1 ? 1 : view.period.Value = 2 ? 7 : 0
    cutoff := days ? DateAdd(A_NowUTC, -days, "Days") : ""
    sortKey := ["date", "coins", "gems", "playerXP", "towerXP", "spin", "timescale", "duration"][Max(1, view.sort.Value)]
    items := [], order := "", view.totals := Map()
    Loop Files, EarningsDirectory() "\*.json", "F" {
        try {
            entry := JSON.Parse(FileRead(A_LoopFileFullPath, "UTF-8"))
            if !(entry is Map) || !RegExMatch(entry.Get("date", ""), "^\d{14}$")
                continue
            if days && (entry.Get("kind", "") = "Imported session" || entry["date"] < cutoff)
                continue
            items.Push(entry)
            rank := entry.Get(sortKey, -1)
            order .= Format("{:020}", rank + 1) " " entry["date"] " " items.Length Chr(10)
            for field in ["coins", "gems", "playerXP", "towerXP", "spin", "timescale", "spinUsed", "timescaleUsed", "duration"] {
                if entry.Has(field)
                    view.totals[field] := view.totals.Get(field, 0) + entry[field]
            }
        }
    }
    view.items := []
    for line in StrSplit(Trim(Sort(order, "R")), Chr(10)) {
        if line != ""
            view.items.Push(items[Integer(StrSplit(line, " ")[3])])
    }
    for index, reward in EarningsRewards() {
        key := reward[1]
        view.cards[index].Text := view.totals.Has(key) ? EarningsCompact(view.totals[key]) : Chr(0x2014)
    }
    count := view.items.Length
    view.status.Text := count ? TF("{count} records", Map("count", count)) : TranslateText("No earnings recorded for this period.")
    pageSize := view.rows.Length
    view.page := Min(Max(1, view.page), Max(1, Ceil(count / pageSize)))
    offset := (view.page - 1) * pageSize
    for index, row in view.rows {
        visible := offset + index <= count
        for ctrl in row.controls
            ctrl.Visible := visible
        if !visible
            continue
        entry := view.items[offset + index]
        row.tag.Text := entry.Get("strategy", "") != "" ? entry["strategy"] : TranslateText(entry.Get("kind", "Match"))
        rewards := []
        for reward in EarningsRewards() {
            if entry.Has(reward[1]) && entry[reward[1]] > 0
                rewards.Push(["+" EarningsCompact(entry[reward[1]]) " " TranslateText(reward[2]), reward[3]])
        }
        if entry.Get("spinUsed", 0)
            rewards.Push(["-" EarningsCompact(entry["spinUsed"]) " " TranslateText("Spin Tickets"), "SpinTickets.png"])
        remaining := rewards.Length - 3
        for slot, cell in row.cells {
            cell.icon.Visible := cell.amount.Visible := slot <= rewards.Length
            if slot <= rewards.Length {
                cell.icon.Value := "*w14 *h-1 " EarningsIcon(rewards[slot][2])
                cell.amount.Text := rewards[slot][1]
            }
        }
        row.overflow.Text := remaining > 0 ? TF("+{count} more", Map("count", remaining)) : ""
        row.gains.Visible := rewards.Length = 0
        row.gains.Text := TranslateText("No rewards detected")
        row.duration.Text := entry.Has("duration") ? EarningsDuration(entry["duration"]) : Chr(0x2014)
    }
    view.prev.Visible := view.page > 1
    remaining := count - offset - pageSize
    view.next.Visible := remaining > 0
    view.next.Text := TF("+{count} more", Map("count", Max(0, remaining)))
}

FarmingEarningsMenu(slot, *) {
    global FarmEarnings
    index := (FarmEarnings.page - 1) * FarmEarnings.rows.Length + slot
    if !FarmEarnings.items.Has(index)
        return
    rowMenu := Menu()
    rowMenu.Add(TranslateText("View details"), FarmingEarningsDetails.Bind(FarmEarnings.items[index], false))
    rowMenu.Show()
}

FarmingEarningsTotals(*) {
    global FarmEarnings
    FarmingEarningsDetails(FarmEarnings.totals, true)
}

FarmingEarningsDetails(entry, totals := false, *) {
    global MainGui
    title := TranslateText(totals = true ? "Exact totals" : "Earnings details")
    details := Gui("+Owner" MainGui.Hwnd " +ToolWindow", title)
    details.BackColor := "181818"
    details.MarginX := 20, details.MarginY := 16
    details.SetFont("s13 Bold cFFFFFF", "Segoe UI")
    details.Add("Text", "w424", title)
    details.SetFont("s10 Norm cD4D9E2", "Segoe UI")
    if totals != true {
        if entry.Has("matches")
            details.Add("Text", "w424", FormatTime(entry["date"], "yyyy-MM-dd HH:mm") "  |  " entry["matches"] " " TranslateText("matches"))
        else if entry.Get("kind", "") != "Imported session"
            details.Add("Text", "w424", FormatTime(entry["date"], "yyyy-MM-dd HH:mm") (entry.Get("kind", "") = "Imported match" ? "" : " UTC"))
        for field, label in Map("strategy", "Strategy", "preset", "Last applied preset", "map", "Map", "difficulty", "Difficulty", "result", "Result")
            details.Add("Text", "w424", TranslateText(label) ": " (entry.Get(field, "") != "" ? entry[field] : TranslateText("Unknown")))
        if entry.Get("tower", "") != ""
            details.Add("Text", "w424", TranslateText("Tower") ": " entry["tower"])
    }
    details.Add("Text", "w424", TranslateText("Duration") ": " (entry.Has("duration") ? EarningsDuration(entry["duration"]) : TranslateText("Unknown")))
    for reward in EarningsRewards() {
        details.Add("Picture", "xm y+8 w20 h-1", EarningsIcon(reward[3]))
        details.Add("Text", "x+8 yp w392", TranslateText(reward[2]) ": " (entry.Has(reward[1]) ? EarningsExact(entry[reward[1]]) : TranslateText("Unknown")))
    }
    for field, label in Map("spinUsed", "Spin Tickets used", "timescaleUsed", "Timescale Tickets used")
        details.Add("Text", "xm w424", TranslateText(label) ": " (entry.Has(field) ? EarningsExact(entry[field]) : TranslateText("Unknown")))
    close := details.Add("Button", "xm y+12 w112 h30 Default", TranslateText("Close"))
    close.OnEvent("Click", (*) => details.Destroy())
    details.OnEvent("Escape", (*) => details.Destroy())
    details.OnEvent("Close", (*) => details.Destroy())
    details.Show()
}

EarningsCompact(amount) {
    for unit in [[1000000000, "B"], [1000000, "M"], [1000, "K"]] {
        if amount >= unit[1] {
            value := Round(amount / unit[1], 1)
            if value >= 1000 && unit[2] != "B"
                return unit[2] = "K" ? "1M" : "1B"
            return RTrim(RTrim(Format("{:.1f}", value), "0"), ".") unit[2]
        }
    }
    return String(amount)
}

EarningsExact(amount) => RegExReplace(String(amount), "\B(?=(\d{3})+$)", ".")

EarningsDuration(seconds) {
    seconds := Max(0, Integer(seconds))
    return (seconds >= 3600 ? seconds // 3600 "h " : "")
        . (seconds >= 60 ? Mod(seconds // 60, 60) "m " : "") Mod(seconds, 60) "s"
}
