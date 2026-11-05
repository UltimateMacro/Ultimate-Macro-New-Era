; Bounded, offline, presentation-only community language catalogs (localization.py).
; Catalogs contain plain strings only. Missing entries keep the English UI text.
; Engine requests, strategy contents, hotkeys and game names are never translated.

class Locale {
    static active := "en", table := Map(), catalogs := ""

    static Folder => App.assets "\locales"

    static Available() {
        if IsObject(Locale.catalogs)
            return Locale.catalogs
        out := [{code: "en", name: "English", path: ""}]
        found := []
        Loop Files Locale.Folder "\*.json" {
            if (A_Index > 64)
                break
            try {
                cat := Locale.Read(A_LoopFileFullPath)
                found.Push({code: cat.code, name: cat.name, path: A_LoopFileFullPath})
            }
        }
        ; Sort by native name (case-insensitive), then code.
        Loop found.Length - 1 {
            i := A_Index
            Loop found.Length - i {
                j := A_Index
                a := found[j], b := found[j + 1]
                if (StrCompare(a.name, b.name) > 0 || (StrCompare(a.name, b.name) = 0 && StrCompare(a.code, b.code) > 0))
                    found[j] := b, found[j + 1] := a
            }
        }
        for item in found
            out.Push(item)
        Locale.catalogs := out
        return out
    }

    static Valid(code) => (code is String) && RegExMatch(code, "^[a-z]{2,3}(?:-[A-Za-z0-9]{2,8}){0,3}$")

    static Read(path) {
        if (FileGetSize(path) > 512 * 1024)
            throw ValueError("Language catalog exceeds its size limit.")
        data := JSON.parse(FileRead(path, "UTF-8"))
        if (!(data is Map) || !data.Has("schema") || data["schema"] != 1 || !data.Has("locale")
            || !Locale.Valid(data["locale"]) || data["locale"] = "en" || !data.Has("nativeName")
            || !data.Has("translations") || !(data["translations"] is Map))
            throw ValueError("Invalid language catalog identity.")
        SplitPath(path, , , , &stem)
        if (stem != data["locale"])
            throw ValueError("Invalid language catalog identity.")
        entries := data["translations"]
        if (entries.Count < 1 || entries.Count > 2048)
            throw ValueError("Invalid language catalog entries.")
        table := Map()
        table.CaseSense := true
        for source, translated in entries {
            if !(translated is String) || StrLen(translated) > 8192 || Trim(translated) = ""
                throw ValueError("Invalid language catalog text.")
            ; Translators may move placeholders and F-keys, never add/remove them.
            if (Locale.Tokens(source) != Locale.Tokens(translated))
                throw ValueError("Language catalog changes a placeholder or shortcut.")
            table[source] := translated
        }
        return {code: data["locale"], name: data["nativeName"], table: table}
    }

    static Tokens(text) {
        list := []
        pos := 1
        while (pos := RegExMatch(text, "\{[^{}]*\}|%(?:\d+\$)?[sdif]|%\d+|\bF(?:[1-9]|1[0-9]|2[0-4])\b", &m, pos)) {
            list.Push(m[0])
            pos += StrLen(m[0])
        }
        ; order-insensitive comparison
        Loop list.Length - 1 {
            i := A_Index
            Loop list.Length - i {
                j := A_Index
                if (StrCompare(list[j], list[j + 1], true) > 0)
                    t := list[j], list[j] := list[j + 1], list[j + 1] := t
            }
        }
        s := ""
        for t in list
            s .= t "`n"
        return s
    }

    static Set(code) {
        Locale.active := "en", Locale.table := Map()
        Locale.table.CaseSense := true
        for item in Locale.Available() {
            if (item.code = code && item.path != "") {
                try {
                    cat := Locale.Read(item.path)
                    Locale.active := cat.code, Locale.table := cat.table
                }
                break
            }
        }
        return Locale.active
    }

    ; translate(text, source=None)
    static Tr(text, source := "") {
        if !(text is String)
            return text
        if Locale.table.Has(text)
            return Locale.table[text]
        key := (source = "") ? text : source
        return Locale.table.Has(key) ? Locale.table[key] : text
    }

    ; translate_heading(text, uppercase=False): case-insensitive unique match.
    static Heading(text) {
        if Locale.table.Has(text)
            return Locale.table[text]
        found := "", count := 0
        for source, value in Locale.table {
            if (source = text) {
                if (value !== found)
                    count += 1, found := value
            }
        }
        if (count = 1)
            return found
        return StrUpper(SubStr(text, 1, 1)) StrLower(SubStr(text, 2))
    }
}

; Short aliases used by the window code.
_T(text, source := "") => Locale.Tr(text, source)
