; Typed 1.3.3a strategy grammar (strategy.py). Data only: never evaluated as code.
; The engine applies its own checks again before any input is sent.

class Strategy {
    static MAX_BYTES := 2 * 1024 * 1024, MAX_STEPS := 20000
    static IDENT := "[A-Za-z0-9][A-Za-z0-9 _'-]{0,47}"
    static KEY := "(?:[A-Za-z][A-Za-z0-9]{0,23}|[0-9!#$%&()*+,\-./:<=>?@\[\\\]^_|~])"
    static GAME_KEYS := ["1", "2", "3", "4", "5", "W", "A", "S", "D", "Q", "E", "R", "T", "F", "Z", "X", "C", "V", "B", "J", "K", "L", "N", "Space", "Left", "Right", "Up", "Down", "Shift"]
    static LEGACY_MODIFIERS := ["Broke", "Exploding", "Flying", "Fog", "Glass", "Healthy", "Hidden", "Inflation", "Jailed", "Limitation", "Committed", "Quarantine", "Speedy", "Foggy", "Armored", "Regeneration", "Slow", "Strong"]
    static _rules := ""

    static Rules() {
        if IsObject(Strategy._rules)
            return Strategy._rules
        I := Strategy.IDENT, K := Strategy.KEY
        r := [
            ["SpawnTower", "(\d{1,5})\s*,\s*(\d{1,5})\s*,\s*([1-9])\s*,\s*(" I ")"],
            ["UpgradeTower", "(" I ")\s*(?:,\s*(false|true)\s*)?(?:,\s*(\d{1,3})\s*)?(?:,\s*(\d{1,2})\s*)?(?:,\s*(\d{1,2})\s*)?"],
            ["CloneTower", "(" I ")\s*,\s*(\d{1,5})\s*,\s*(\d{1,5})\s*(?:,\s*(\d{1,7})\s*(?:,\s*(" I ")\s*)?)?"],
            ["EnforcerReposition", "(" I ")\s*,\s*(" I ")\s*,\s*(\d{1,5})\s*,\s*(\d{1,5})"],
            ["ToggleAutoskip", "\s*"],
            ["ChangeTargets", "(" I ")\s*,\s*([A-Za-z][A-Za-z ]{0,23})"],
            ["ActivateRaiseTheDead", "(\d{1,7})?"],
            ["ActivateEnforcerVan", "(\d{1,7})?"],
            ["BrawlerReposition", "(" I ")\s*,\s*(\d{1,5})\s*,\s*(\d{1,5})"],
            ["SetDJTrack", "`"?([A-Za-z]{1,16})`"?"],
            ["Click", "(\d{1,5})\s*,\s*(\d{1,5})\s*(?:,\s*`"?(Left|Right)`"?\s*)?"],
            ["Send", "`"(" K ")`"\s*,\s*hold:=(\d{1,6})"],
            ["Sleep", "(\d{1,7})"],
            ["SellTower", "(" I ")"],
            ["InputKey", "`"([1-5WASDQERTFZXCVBJKLN]|Space|Left|Right|Up|Down|Shift)`"\s*,\s*`"(down|up)`""],
            ["InputButton", "(\d{1,4})\s*,\s*(\d{1,4})\s*,\s*`"(Left|Right)`"\s*,\s*`"(down|up)`""],
            ["InputMove", "(\d{1,4})\s*,\s*(\d{1,4})"],
            ["InputWheel", "(\d{1,4})\s*,\s*(\d{1,4})\s*,\s*(-?\d{1,2})"],
            ["UseConsumable", "`"([A-Za-z][A-Za-z0-9 _'-]{0,47})`"\s*(?:,\s*(\d{1,4})\s*,\s*(\d{1,4}))?"]
        ]
        out := []
        for item in r
            out.Push([item[1], "i)^" item[1] "\s*\(\s*" item[2] "\s*\)$"])
        Strategy._rules := out
        return out
    }

    static StripComment(line) {
        quoted := false
        Loop Parse line {
            if (A_LoopField = '"')
                quoted := !quoted
            else if (A_LoopField = ";" && !quoted)
                return Trim(SubStr(line, 1, A_Index - 1))
        }
        return Trim(line)
    }

    ; Returns {metadata: Map(section -> Map(key -> value)), steps: [{op, args, line}]} or throws.
    static Parse(text) {
        if (StrPut(text, "UTF-8") - 1 > Strategy.MAX_BYTES)
            throw ValueError("Strategy exceeds 2 MiB")
        meta := Map(), steps := [], section := ""
        meta.CaseSense := false
        if (SubStr(text, 1, 1) = Chr(0xFEFF))
            text := SubStr(text, 2)
        text := StrReplace(StrReplace(text, "`r`n", "`n"), "`r", "`n")
        Loop Parse text, "`n" {
            number := A_Index
            line := Strategy.StripComment(Trim(A_LoopField))
            if (line = "")
                continue
            if (SubStr(line, 1, 1) = "[" && SubStr(line, -1) = "]") {
                section := StrLower(Trim(SubStr(line, 2, -1)))
                if !meta.Has(section) {
                    m := Map()
                    m.CaseSense := false
                    meta[section] := m
                }
                continue
            }
            if (section != "steps") {
                eq := InStr(line, "=")
                if (section = "" || !eq || Trim(SubStr(line, 1, eq - 1)) = "")
                    throw ValueError("Invalid metadata at line " number)
                meta[section][StrLower(Trim(SubStr(line, 1, eq - 1)))] := Trim(SubStr(line, eq + 1))
                continue
            }
            if RegExMatch(line, "i)^-{5,}(?:\s*\(\s*(?:Alignment|Steps)\s*\))?$")
                continue
            if (steps.Length >= Strategy.MAX_STEPS)
                throw ValueError("Too many steps")
            if RegExMatch(line, "i)^Commander\s*:=\s*true$") {
                steps.Push({op: "Commander", args: [], line: number})
                continue
            }
            matched := false
            for rule in Strategy.Rules() {
                if !RegExMatch(line, rule[2], &m)
                    continue
                matched := true
                name := rule[1], args := []
                Loop m.Count
                    args.Push(m[A_Index])
                switch name {
                    case "UpgradeTower":
                        count := args[3] = "" ? 1 : Integer(args[3])
                        path := args[4] = "" ? 0 : Integer(args[4])
                        if (count < 1 || count > 999)
                            throw ValueError("Invalid upgrade count at line " number)
                        if (path > 2)
                            throw ValueError("Invalid upgrade path at line " number)
                        args := [args[1], StrLower(args[2]) = "true", count, path, args[5] = "" ? 4 : Integer(args[5])]
                    case "Sleep", "ActivateRaiseTheDead", "ActivateEnforcerVan":
                        args := [args[1] = "" ? 0 : Integer(args[1])]
                    case "InputKey":
                        key := ""
                        for k in Strategy.GAME_KEYS
                            if (k = args[1])
                                key := k
                        if (key = "")
                            throw ValueError("Unsupported game key")
                        args := [key, StrLower(args[2])]
                    case "InputButton", "InputMove", "InputWheel":
                        x := Integer(args[1]), y := Integer(args[2])
                        if (Max(x, y) > 8191)
                            throw ValueError("Input point outside bounds")
                        if (name = "InputButton")
                            args := [x, y, StrTitle(args[3]), StrLower(args[4])]
                        else if (name = "InputWheel") {
                            c := Integer(args[3])
                            if (Abs(c) < 1 || Abs(c) > 60)
                                throw ValueError("Invalid wheel count")
                            args := [x, y, c]
                        } else
                            args := [x, y]
                    case "SpawnTower":
                        args := [Integer(args[1]), Integer(args[2]), Integer(args[3]), args[4]]
                    case "CloneTower":
                        out := [args[1], Integer(args[2]), Integer(args[3]), args[4] = "" ? 0 : Integer(args[4])]
                        if (args.Length >= 5 && args[5] != "")
                            out.Push(args[5])
                        args := out
                }
                steps.Push({op: name, args: args, line: number})
                break
            }
            if !matched
                throw ValueError("Unsupported or unsafe step at line " number)
        }
        if (!steps.Length || !meta.Has("settings") || !meta["settings"].Has("map") || meta["settings"]["map"] = ""
            || !meta["settings"].Has("difficulty") || meta["settings"]["difficulty"] = "")
            throw ValueError("Map, difficulty and steps are required")
        return {metadata: meta, steps: steps}
    }

    static Setting(parsed, key, default := "") {
        s := parsed.metadata.Has("settings") ? parsed.metadata["settings"] : Map()
        return s.Has(key) ? s[key] : default
    }

    ; workspace.strategy_text: UTF-8, UTF-16 BOM, or the ANSI that 1.3.3a FileAppend wrote.
    static ReadText(path) {
        SplitPath(path, , , &ext)
        if (StrLower(ext) != "strat")
            throw ValueError("Choose a regular .strat file.")
        if (FileGetSize(path) > Strategy.MAX_BYTES)
            throw ValueError("Strategy exceeds 2 MiB.")
        raw := FileRead(path, "RAW")
        b0 := raw.Size >= 1 ? NumGet(raw, 0, "UChar") : 0, b1 := raw.Size >= 2 ? NumGet(raw, 1, "UChar") : 0
        if ((b0 = 0xFF && b1 = 0xFE) || (b0 = 0xFE && b1 = 0xFF))
            text := FileRead(path, "UTF-16")
        else if Strategy.IsUtf8(raw)
            text := FileRead(path, "UTF-8")
        else
            text := FileRead(path, "CP1252")
        text := StrReplace(StrReplace(text, "`r`n", "`n"), "`r", "`n")
        if (SubStr(text, 1, 1) = Chr(0xFEFF))
            text := SubStr(text, 2)
        Strategy.Parse(text)
        return text
    }

    static IsUtf8(buf) {
        i := 0, n := buf.Size
        if (n >= 3 && NumGet(buf, 0, "UChar") = 0xEF && NumGet(buf, 1, "UChar") = 0xBB && NumGet(buf, 2, "UChar") = 0xBF)
            return true
        while (i < n) {
            c := NumGet(buf, i, "UChar")
            if (c < 0x80) {
                i += 1
                continue
            }
            len := (c >= 0xF0 && c <= 0xF4) ? 4 : (c >= 0xE0) ? 3 : (c >= 0xC2 && c <= 0xDF) ? 2 : 0
            if (!len || i + len > n)
                return false
            Loop len - 1 {
                if ((NumGet(buf, i + A_Index, "UChar") & 0xC0) != 0x80)
                    return false
            }
            i += len
        }
        return true
    }

    ; LibraryItem: {path, title, map, mode, steps, text}
    static Inspect(path) {
        text := Strategy.ReadText(path)
        parsed := Strategy.Parse(text)
        SplitPath(path, , , , &stem)
        info := parsed.metadata.Has("info") ? parsed.metadata["info"] : Map()
        title := (info.Has("title") && info["title"] != "") ? info["title"] : stem
        return {path: path, title: SubStr(title, 1, 128), map: SubStr(Strategy.Setting(parsed, "map"), 1, 80)
            , mode: SubStr(Strategy.Setting(parsed, "difficulty"), 1, 80), steps: parsed.steps.Length, text: text, parsed: parsed}
    }

    ; Display declared loadout only; never proof of ownership or equipment.
    static RequiredLoadout(item) {
        try {
            raw := Strategy.Setting(item.parsed, "requiredtowers")
            names := []
            for n in StrSplit(raw, ",") {
                n := Trim(n)
                if (n != "")
                    names.Push(n)
            }
            seen := Map()
            seen.CaseSense := true
            if (names.Length > 5)
                throw ValueError()
            for n in names {
                if (seen.Has(n) || StrLen(n) > 48 || RegExMatch(n, "[\x00-\x1F]"))
                    throw ValueError()
                seen[n] := 1
            }
            if !names.Length
                return _T("Not set in this strategy.")
            out := ""
            for i, n in names
                out .= (i > 1 ? "`n" : "") i ". " n
            return out
        } catch
            return _T("Incompatible loadout metadata: expected up to 5 distinct tower names.")
    }

    ; modifier_names.parse_modifier_names
    static ModifierNames(value) {
        static ref := Map("glass", "Glass", "gla", "Glass", "gl", "Glass", "hidden", "Hidden", "hid", "Hidden", "hi", "Hidden"
            , "exploding", "Exploding", "exp", "Exploding", "ex", "Exploding", "limitation", "Limitation", "lim", "Limitation", "li", "Limitation"
            , "committed", "Committed", "com", "Committed", "co", "Committed", "flying", "Flying", "fly", "Flying", "fl", "Flying"
            , "foggy", "Foggy", "fog", "Foggy", "fo", "Foggy", "armored", "Armored", "arm", "Armored", "ar", "Armored"
            , "regeneration", "Regeneration", "reg", "Regeneration", "re", "Regeneration", "slow", "Slow", "slo", "Slow", "sl", "Slow"
            , "speedy", "Speedy", "spe", "Speedy", "sp", "Speedy", "strong", "Strong", "str", "Strong", "st", "Strong"
            , "explo", "Exploding", "limit", "Limitation", "hidd", "Hidden", "commited", "Committed"
            , "bro", "Broke", "br", "Broke", "hea", "Healthy", "he", "Healthy"
            , "inf", "Inflation", "in", "Inflation", "qua", "Quarantine", "qu", "Quarantine")
        if (StrLen(value) > 1024)
            throw ValueError("Invalid match modifiers")
        if (Trim(value) = "")
            return []
        parts := StrSplit(value, ",")
        if (parts.Length > 32)
            throw ValueError("Invalid match modifiers")
        names := [], seen := Map()
        for p in parts {
            p := Trim(p)
            if !RegExMatch(p, "^[A-Za-z][A-Za-z0-9 -]{0,47}$")
                throw ValueError("Invalid match modifiers")
            n := ref.Has(StrLower(p)) ? ref[StrLower(p)] : p
            if seen.Has(StrLower(n))
                throw ValueError("Invalid match modifiers")
            seen[StrLower(n)] := 1
            names.Push(n)
        }
        return names
    }

    ; hybrid_client.strategy_requirement: what the AutoHotkey engine can play.
    static Requirement(item) {
        parsed := item.parsed
        Strategy.ValidateRecordedInputs(parsed)
        mods := Strategy.Setting(parsed, "modifiers")
        if (mods != "") {
            names := Strategy.ModifierNames(mods)
            for n in names
                if !InArray(Strategy.LEGACY_MODIFIERS, n)
                    throw ValueError("This strategy requires modifiers that the current engine cannot select and verify.")
        }
        for s in parsed.steps
            if (s.op = "UseConsumable")
                throw ValueError("This strategy uses consumables that the current engine cannot select and verify.")
        return ""
    }

    static ValidateRecordedInputs(parsed) {
        uses := false
        for s in parsed.steps
            if (SubStr(s.op, 1, 5) = "Input") {
                uses := true
                break
            }
        if !uses
            return false
        meta := parsed.metadata.Has("do not edit") ? parsed.metadata["do not edit"] : Map()
        try {
            w := Integer(meta["width"]), h := Integer(meta["height"])
        } catch
            throw ValueError("Strategy coordinates or recorded window dimensions do not match the game.")
        if ((meta.Has("coordinatespace") ? meta["coordinatespace"] : "") != "client-v1" || Min(w, h) < 320 || Max(w, h) > 8192)
            throw ValueError("Strategy coordinates or recorded window dimensions do not match the game.")
        for key in ["autochain", "autocaravan", "autodropthebeat", "autoskip", "abilityspam", "moveenabled"] {
            v := Strategy.Setting(parsed, key, "OFF")
            if !(v = "OFF" || v = "0" || v = "")
                throw ValueError("Check strategy abilities, movement, map and difficulty settings.")
        }
        held := Map()
        for s in parsed.steps {
            if (s.op = "Sleep")
                continue
            if !InArray(["InputKey", "InputButton", "InputMove", "InputWheel"], s.op)
                throw ValueError("The strategy uses an operation this engine cannot run.")
            if (s.op != "InputKey" && !(s.args[1] < w && s.args[2] < h))
                throw ValueError("Strategy coordinates or recorded window dimensions do not match the game.")
            if (s.op = "InputKey" || s.op = "InputButton") {
                name := s.op = "InputKey" ? s.args[1] : s.args[3]
                edge := s.op = "InputKey" ? s.args[2] : s.args[4]
                id := s.op "|" name
                if (edge = "down") {
                    if held.Has(id)
                        throw ValueError("Duplicate recorded down edge")
                    held[id] := 1
                } else {
                    if !held.Has(id)
                        throw ValueError("Unpaired recorded up edge")
                    held.Delete(id)
                }
            }
        }
        if held.Count
            throw ValueError("Recorded input ends with held controls")
        return true
    }

    ; ---- recorded draft editing (recording.Recording.list_towers / delete_tower) ----
    static ListTowers(text) {
        ids := [], seen := Map()
        seen.CaseSense := true
        for s in Strategy.Parse(text).steps {
            if (s.op = "SpawnTower")
                id := s.args[4]
            else if (s.op = "CloneTower" && s.args.Length = 5)
                id := s.args[5]
            else
                continue
            if seen.Has(id)
                continue
            seen[id] := 1
            if (ids.Length = 512)
                return {ids: ids, truncated: true}
            ids.Push(id)
        }
        return {ids: ids, truncated: false}
    }

    ; Returns the set of [Steps] line numbers removed for tower_id and its dependent clones.
    static DeletionLines(text, towerId) {
        steps := Strategy.Parse(text).steps
        affected := Map()
        affected.CaseSense := true
        found := false
        for s in steps
            if ((s.op = "SpawnTower" && s.args[4] == towerId) || (s.op = "CloneTower" && s.args.Length = 5 && s.args[5] == towerId))
                found := true
        if !found
            throw ValueError("Recorded tower not found")
        affected[towerId] := 1
        for s in steps
            if (s.op = "CloneTower" && s.args.Length = 5 && affected.Has(s.args[1]))
                affected[s.args[5]] := 1
        lines := Map()
        for s in steps {
            hit := (s.op = "SpawnTower" && affected.Has(s.args[4]))
                || (s.op = "CloneTower" && s.args.Length = 5 && affected.Has(s.args[5]))
                || (InArray(["UpgradeTower", "SellTower", "CloneTower", "BrawlerReposition", "ChangeTargets"], s.op) && affected.Has(s.args[1]))
                || (s.op = "EnforcerReposition" && (affected.Has(s.args[1]) || affected.Has(s.args[2])))
                || (s.op = "SetDJTrack" && affected.Has("DJ"))
            if hit
                lines[s.line] := 1
        }
        return lines
    }

    static DeleteTower(text, towerId) {
        lines := Strategy.DeletionLines(text, towerId)
        text := StrReplace(text, "`r`n", "`n")
        out := ""
        Loop Parse text, "`n" {
            if !lines.Has(A_Index)
                out .= A_LoopField "`n"
        }
        return RTrim(out, "`n") "`n"
    }
}

InArray(arr, value) {
    for v in arr
        if (v == value)
            return true
    return false
}

StrTitle(s) => StrUpper(SubStr(s, 1, 1)) StrLower(SubStr(s, 2))
