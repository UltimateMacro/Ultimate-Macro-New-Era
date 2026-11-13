; Private presentation settings and the bounded strategy library (workspace.py).

class Store {
    static root := "", strategies := "", recordings := "", settingsPath := "", formPath := ""
    static settings := Map(), recovered := false, skipped := [], recordForm := ""
    static DEFAULT_RUNTIME := Map("cancelKey", "Q", "raiseDeadKey", "V", "chainKey", "C", "caravanKey", "J", "beatKey", "B"
        , "hologramKey", "K", "repositionKey", "L", "enforcerVanKey", "N", "upgradeDelayMs", 200
        , "keyDelayMs", 20, "extraUiWait", 0, "preJoinDelay", 0)
    static DEFAULT_BINDINGS := Map("align", "Ctrl+T", "place", "F", "upgrade", "Ctrl+U", "sell", "Ctrl+X"
        , "clone", "Ctrl+Alt+H", "targets", "Ctrl+``", "dj", "Ctrl+D")
    static BINDING_ORDER := ["align", "place", "upgrade", "sell", "clone", "targets", "dj"]
    static BINDING_TITLES := Map("align", "Align camera", "place", "Place tower", "upgrade", "Upgrade tower", "sell", "Sell tower"
        , "clone", "Clone tower", "targets", "Targeting", "dj", "DJ track")
    static RUNTIME_KEYS := ["cancelKey", "raiseDeadKey", "chainKey", "caravanKey", "beatKey", "hologramKey", "repositionKey", "enforcerVanKey"]

    static Init() {
        Store.root := EnvGet("LOCALAPPDATA") "\UltimateMacro14AHK"
        Store.strategies := Store.root "\strategies"
        Store.recordings := Store.root "\recordings"
        Store.settingsPath := Store.root "\presentation.json"
        Store.formPath := Store.root "\record-form.json"
        DirCreate(Store.root)
        DirCreate(Store.strategies)
        DirCreate(Store.recordings)
        Store.Migrate()
        Store.settings := Store.Defaults()
        if FileExist(Store.settingsPath) {
            try {
                if (FileGetSize(Store.settingsPath) > 65536)
                    throw ValueError("Settings size exceeded")
                value := JSON.parse(FileRead(Store.settingsPath, "UTF-8"))
                if !(value is Map)
                    throw ValueError("Invalid presentation settings")
                Store.Accept(value)
            } catch
                Store.recovered := true
        }
        if FileExist(Store.formPath) {
            try {
                if (FileGetSize(Store.formPath) <= 512 * 1024)
                    Store.recordForm := Store.ValidForm(JSON.parse(FileRead(Store.formPath, "UTF-8")))
            }
        }
    }

    ; Carry a profile, personal strategies and recordings over from the Python 1.4 app once.
    static Migrate() {
        old := EnvGet("LOCALAPPDATA") "\UltimateMacro14Python"
        marker := Store.root "\migrated.flag"
        if (FileExist(marker) || !DirExist(old))
            return
        try {
            if (FileExist(old "\presentation.json") && !FileExist(Store.settingsPath))
                FileCopy(old "\presentation.json", Store.settingsPath)
            if (FileExist(old "\record-form.json") && !FileExist(Store.formPath))
                FileCopy(old "\record-form.json", Store.formPath)
            for pair in [["strategies", Store.strategies], ["recordings", Store.recordings]] {
                Loop Files old "\" pair[1] "\*.strat" {
                    if !FileExist(pair[2] "\" A_LoopFileName)
                        FileCopy(A_LoopFileFullPath, pair[2] "\" A_LoopFileName)
                }
            }
            FileAppend("Imported settings and strategies from the Python 1.4 app.`n", marker, "UTF-8")
        } catch {
            ; Retry next launch; existing destination files are never overwritten.
            Store.recovered := true
        }
    }

    static Defaults() {
        s := Map("topmost", true, "autoEquip", true, "autoCloseChat", true, "repeat", true, "motion", true, "dockRoblox", false, "policyRevision", ""
            , "halloween", false, "halloweenSounds", true, "appearanceRevision", 5, "language", "en", "languageChosen", false
            , "updatePrompts", true, "themeBackground", true, "windowOpacity", 96
            , "slot1", "", "slot2", "", "rotation", false, "rotationAmount", 1, "rotationUnit", "Runs", "timeScaleMode", "OFF"
            , "runtime", Store.CopyMap(Store.DEFAULT_RUNTIME), "recordBindings", Store.CopyMap(Store.DEFAULT_BINDINGS)
            , "legacyOptions", Map("scrollModeList", false, "scrollAmount", 5, "scrollDelayMs", 1000))
        return s
    }

    static CopyMap(m) {
        out := Map()
        for k, v in m
            out[k] := (v is Map) ? Store.CopyMap(v) : v
        return out
    }

    static IsBool(v) => (v == 0 || v == 1) && !(v is String)

    ; Validate field by field; one bad value keeps its own default (B165).
    static Accept(value) {
        s := Store.settings
        bad := () => (Store.recovered := true)
        for k in value
            if !s.Has(k) && k != "adsAllowed" && k != "adsConsentRevision"
                bad()
        if value.Has("language") {
            if Locale.Valid(value["language"])
                s["language"] := value["language"]
            else
                s["language"] := "en", s["languageChosen"] := false
        }
        if value.Has("languageChosen")
            s["languageChosen"] := Store.IsBool(value["languageChosen"]) ? !!value["languageChosen"] : false
        for key in ["topmost", "autoEquip", "autoCloseChat", "repeat", "motion", "dockRoblox", "halloween", "halloweenSounds", "updatePrompts", "themeBackground", "rotation"] {
            if !value.Has(key)
                continue
            if Store.IsBool(value[key])
                s[key] := !!value[key]
            else
                bad()
        }
        if value.Has("windowOpacity") {
            v := value["windowOpacity"]
            if (IsInteger(v) && v >= 90 && v <= 100)
                s["windowOpacity"] := Integer(v)
            else
                bad()
        }
        for key in ["slot1", "slot2"]
            if (value.Has(key) && value[key] is String && StrLen(value[key]) <= 32768)
                s[key] := value[key]
        if value.Has("rotationAmount") {
            v := value["rotationAmount"]
            if (IsInteger(v) && v >= 1 && v <= 999)
                s["rotationAmount"] := Integer(v)
            else
                bad()
        }
        if (value.Has("rotationUnit") && (value["rotationUnit"] == "Runs" || value["rotationUnit"] == "Minutes"))
            s["rotationUnit"] := value["rotationUnit"]
        if (value.Has("policyRevision") && (value["policyRevision"] == "" || value["policyRevision"] == FirstUse.POLICY_REVISION))
            s["policyRevision"] := value["policyRevision"]
        if value.Has("timeScaleMode") {
            if InArray(["OFF", "1.5x", "2x"], value["timeScaleMode"])
                s["timeScaleMode"] := value["timeScaleMode"]
            else
                bad()
        }
        if value.Has("legacyOptions") {
            try s["legacyOptions"] := Store.ValidLegacy(value["legacyOptions"])
            catch
                bad()
        }
        if value.Has("runtime") {
            try s["runtime"] := Store.ValidRuntime(value["runtime"])
            catch
                bad()
        }
        defaults := Store.CopyMap(Store.DEFAULT_BINDINGS)
        for k, v in s["runtime"]
            if (v == "F")
                defaults["place"] := "Ctrl+F"
        ok := false
        if value.Has("recordBindings") {
            try {
                s["recordBindings"] := Store.ValidBindings(value["recordBindings"], s["runtime"])
                ok := true
            } catch
                bad()
        }
        if !ok {
            try s["recordBindings"] := Store.ValidBindings(defaults, s["runtime"])
            catch {
                s["runtime"] := Store.CopyMap(Store.DEFAULT_RUNTIME)
                s["recordBindings"] := Store.CopyMap(Store.DEFAULT_BINDINGS)
                bad()
            }
        }
        if !value.Has("appearanceRevision")
            s["halloween"] := false
        ; Move the previous AHK default pair to the shipped Qt appearance.
        if (value.Has("appearanceRevision") && value["appearanceRevision"] = 4
            && !s["themeBackground"] && s["windowOpacity"] = 98)
            s["themeBackground"] := true, s["windowOpacity"] := 96
        s["appearanceRevision"] := 5
        if s["rotation"]
            s["autoEquip"] := true, s["repeat"] := true
    }

    static ValidLegacy(v) {
        if !(v is Map) || !v.Has("scrollModeList") || !v.Has("scrollAmount") || !v.Has("scrollDelayMs")
            throw ValueError("Invalid legacy compatibility options")
        a := v["scrollAmount"], d := v["scrollDelayMs"]
        if !Store.IsBool(v["scrollModeList"]) || !IsInteger(a) || a < 5 || a > 20 || !IsInteger(d) || d < 0 || d > 5000
            throw ValueError("Invalid legacy scroll bounds")
        return Map("scrollModeList", !!v["scrollModeList"], "scrollAmount", Integer(a), "scrollDelayMs", Integer(d))
    }

    ; runtime_settings.validate_runtime_settings
    static ValidRuntime(v) {
        if !(v is Map)
            throw ValueError("Invalid gameplay settings")
        out := Map(), seen := Map()
        for key in Store.RUNTIME_KEYS {
            if !v.Has(key) {
                if (key = "enforcerVanKey") {
                    out[key] := "N"
                    continue
                }
                throw ValueError("Invalid gameplay settings")
            }
            k := v[key]
            if !(k is String) || !RegExMatch(k, "^[A-Za-z0-9]$")
                throw ValueError("Invalid gameplay key")
            k := StrUpper(k)
            if seen.Has(k)
                throw ValueError("Duplicate gameplay key")
            seen[k] := 1
            out[key] := k
        }
        d := v.Has("upgradeDelayMs") ? v["upgradeDelayMs"] : ""
        if !IsInteger(d) || d < 20 || d > 999
            throw ValueError("Invalid upgrade delay")
        out["upgradeDelayMs"] := Integer(d)
        for key, range in Map("keyDelayMs", [20, 250], "extraUiWait", [0, 90], "preJoinDelay", [0, 60]) {
            value := v.Has(key) ? v[key] : Store.DEFAULT_RUNTIME[key]
            if !IsInteger(value) || value < range[1] || value > range[2]
                throw ValueError("Invalid gameplay delay")
            out[key] := Integer(value)
        }
        return out
    }

    ; record_bindings.binding -> [canonical, mask, vk]
    static Binding(value) {
        if !(value is String) || StrLen(value) > 40
            throw ValueError("Invalid recording shortcut")
        parts := []
        for p in StrSplit(StrUpper(Trim(value)), "+")
            parts.Push(Trim(p))
        if (parts.Length && parts[parts.Length] = "" && SubStr(Trim(value), -1) = "+")
            throw ValueError("Use a letter, digit or F1-F12")
        key := parts.Pop(), mods := Map()
        for m in parts {
            if !InArray(["CTRL", "ALT", "SHIFT"], m) || mods.Has(m)
                throw ValueError("Invalid shortcut modifiers")
            mods[m] := 1
        }
        if RegExMatch(key, "^[A-Z0-9]$")
            vk := Ord(key)
        else if (key = "``")
            vk := 0xC0
        else if RegExMatch(key, "^F([1-9]|1[0-2])$", &fm)
            vk := 0x6F + Integer(fm[1])
        else
            throw ValueError("Use a letter, digit or F1-F12")
        mask := (mods.Has("ALT") ? 1 : 0) | (mods.Has("CTRL") ? 2 : 0) | (mods.Has("SHIFT") ? 4 : 0)
        canon := ""
        for name in ["Ctrl", "Alt", "Shift"]
            if mods.Has(StrUpper(name))
                canon .= name "+"
        return [canon key, mask, vk]
    }

    static ValidBindings(v, runtime := "") {
        if !(v is Map)
            throw ValueError("Invalid recording shortcuts")
        for k in v
            if !Store.DEFAULT_BINDINGS.Has(k)
                throw ValueError("Invalid recording shortcuts")
        reserved := Map()
        for chord in ["0|112", "0|113", "0|119", "1|115", "2|67", "2|86", "2|65", "2|90", "2|89", "2|83", "2|66", "6|69"]
            reserved[chord] := 1
        Loop 5
            reserved["2|" (0x30 + A_Index)] := 1
        if IsObject(runtime)
            for name, key in runtime
                if (SubStr(name, -3) = "Key")
                    reserved["0|" Ord(StrUpper(key))] := 1
        out := Map()
        for action in Store.BINDING_ORDER {
            if !v.Has(action)
                throw ValueError("Invalid recording shortcuts")
            b := Store.Binding(v[action])
            chord := b[2] "|" b[3]
            if reserved.Has(chord)
                throw ValueError("Shortcut is reserved or already in use")
            reserved[chord] := 1
            out[action] := b[1]
        }
        return out
    }

    ; "Ctrl+Alt+H" -> "^!h" (legacy AutoHotkey syntax for Settings.tds).
    static AhkHotkey(binding) {
        b := Store.Binding(binding), out := ""
        if (b[2] & 2)
            out .= "^"
        if (b[2] & 1)
            out .= "!"
        if (b[2] & 4)
            out .= "+"
        key := SubStr(b[1], InStr(b[1], "+", , -1) + 1)
        if (key = "``")
            return out "vkC0"
        return out (StrLen(key) = 1 ? StrLower(key) : key)
    }

    static Save() {
        s := Store.settings
        text := JSON.stringify(Store.ForJson(s))
        if (StrPut(text, "UTF-8") > 65536)
            throw ValueError("Presentation settings exceed reload bound")
        AtomicWrite(Store.settingsPath, text)
    }

    ; Booleans stay JSON booleans so the Python app could still read the profile.
    static ForJson(m) {
        static bools := ["topmost", "autoEquip", "autoCloseChat", "repeat", "motion", "dockRoblox", "halloween", "halloweenSounds", "languageChosen"
            , "updatePrompts", "themeBackground", "rotation", "scrollModeList", "adsAllowed"]
        out := Map()
        for k, v in m {
            if (v is Map)
                out[k] := Store.ForJson(v)
            else if InArray(bools, k)
                out[k] := v ? JSON.true : JSON.false
            else
                out[k] := v
        }
        return out
    }

    static SaveForm(value) {
        value := Store.ValidForm(value)
        AtomicWrite(Store.formPath, JSON.stringify(Store.ForJson(value), 0, ""))
        Store.recordForm := value
    }

    static ValidForm(v) {
        if !(v is Map) || !v.Has("schema") || v["schema"] != 1
            throw ValueError("Invalid recording form")
        out := Map("schema", 1)
        for pair in [["map", 32767], ["towers", 255], ["name", 64], ["action", 512]] {
            if !v.Has(pair[1]) || !(v[pair[1]] is String) || StrLen(v[pair[1]]) > pair[2]
                throw ValueError("Recording form text exceeds widget bound")
            out[pair[1]] := v[pair[1]]
        }
        if !v.Has("mode") || !InArray(Engine.MODES, v["mode"]) || !v.Has("slot") || !InArray(["1", "2", "3", "4", "5"], String(v["slot"]))
            throw ValueError("Invalid recording form selection")
        out["mode"] := v["mode"], out["slot"] := String(v["slot"])
        flags := Map()
        src := (v.Has("flags") && v["flags"] is Map) ? v["flags"] : Map()
        for f in ["auto_chain", "auto_caravan", "auto_beat", "auto_skip", "ability_spam"]
            flags[f] := src.Has(f) ? !!src[f] : false
        out["flags"] := flags
        for f in ["passiveUpgrades", "passiveSales", "passiveInputs"]
            out[f] := v.Has(f) ? !!v[f] : false
        mods := []
        if (v.Has("modifiers") && v["modifiers"] is Array)
            for m in v["modifiers"]
                if InArray(Strategy.LEGACY_MODIFIERS, m)
                    mods.Push(m)
        out["modifiers"] := mods
        return out
    }

    ; ---- library ----------------------------------------------------------
    static Library() {
        items := [], seen := Map(), skipped := []
        seen.CaseSense := false
        for folder in [App.assets "\strategies", App.engine "\Resources\Strats", Store.strategies, Store.recordings] {
            if !DirExist(folder)
                continue
            files := []
            Loop Files folder "\*.strat"
                files.Push(A_LoopFileFullPath)
            SortStrings(files)
            for path in files {
                if (items.Length >= 2000)
                    break
                if seen.Has(path)
                    continue
                seen[path] := 1
                try
                    items.Push(Strategy.Inspect(path))
                catch {
                    SplitPath(path, &name)
                    if (skipped.Length < 50)
                        skipped.Push(name)
                }
            }
        }
        Store.skipped := skipped
        return items
    }

    static SafeName(name) {
        if !(name is String) || !RegExMatch(name, "^[A-Za-z0-9][A-Za-z0-9 _()-]{0,63}$")
            throw ValueError("Invalid recording name")
        if RegExMatch(name, "i)^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:[ .]|$)")
            throw ValueError("Reserved Windows filename")
        if (SubStr(name, -1) = " ")
            throw ValueError("Trailing spaces are not allowed")
        return name
    }

    static ImportStem(stem) {
        cleaned := RegExReplace(stem, "[^A-Za-z0-9 _()-]", "_")
        cleaned := RTrim(SubStr(RegExReplace(cleaned, "^[^A-Za-z0-9]+"), 1, 64))
        try return Store.SafeName(cleaned)
        catch
            return "Strategy"
    }

    ; Write "stem.strat", else "stem (2).strat" ... never overwrites.
    static WriteNew(folder, stem, text, reuseIdentical := false) {
        stem := Store.SafeName(stem)
        Loop 999 {
            suffix := A_Index = 1 ? "" : " (" A_Index ")"
            name := Store.SafeName(RTrim(SubStr(stem, 1, 64 - StrLen(suffix))) suffix)
            target := folder "\" name ".strat"
            if FileExist(target) {
                if reuseIdentical {
                    try {
                        if (Strategy.ReadText(target) == StrReplace(StrReplace(text, "`r`n", "`n"), "`r", "`n"))
                            return target
                    }
                }
                continue
            }
            AtomicWrite(target, text)
            return target
        }
        throw Error("No free strategy name")
    }

    static ImportStrategy(source) {
        item := Strategy.Inspect(source)
        SplitPath(source, , , , &stem)
        return Store.WriteNew(Store.strategies, Store.ImportStem(stem), item.text, true)
    }

    static SaveRecording(name, text) {
        Strategy.Parse(text)
        return Store.WriteNew(Store.recordings, name, text)
    }
}

; UTF-8 (no BOM) write through a temporary file and an atomic replace.
AtomicWrite(path, text, encoding := "UTF-8-RAW") {
    SplitPath(path, , &dir)
    DirCreate(dir)
    tmp := dir "\.um14-" A_TickCount "-" Random(1000, 9999) ".tmp"
    f := FileOpen(tmp, "w", encoding)
    if !f
        throw OSError("Could not write " path)
    f.Write(text)
    f.Close()
    if !DllCall("MoveFileExW", "WStr", tmp, "WStr", path, "UInt", 0x1 | 0x8) {
        try FileDelete(tmp)
        throw OSError("Could not replace " path)
    }
}

SortStrings(arr) {
    n := arr.Length
    Loop n - 1 {
        i := A_Index
        Loop n - i {
            j := A_Index
            if (StrCompare(arr[j], arr[j + 1]) > 0)
                t := arr[j], arr[j] := arr[j + 1], arr[j + 1] := t
        }
    }
    return arr
}
