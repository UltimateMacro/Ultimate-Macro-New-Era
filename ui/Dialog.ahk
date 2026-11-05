; Themed modal dialogs: questions (QMessageBox), first-use terms and language choice.

class Dialog {
    static current := "", result := "", gui := "", surface := "", defaultButton := "", cancelButton := ""

    static DarkTitle(hwnd) {
        v := Buffer(4, 0)
        NumPut("Int", 1, v)
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 20, "Ptr", v, "UInt", 4)
    }

    ; Builds a modal window around `root`; returns once it closes.
    static Run(title, root, width, owner := 0, defaultText := "", cancelText := "") {
        s := Gfx.S
        g := Gui("-MinimizeBox -MaximizeBox -DPIScale" (owner ? " +Owner" owner : ""), title)
        g.BackColor := Theme.Hex("base")
        if (owner && (WinGetExStyle("ahk_id " owner) & 0x8))
            g.Opt("+AlwaysOnTop")
        surf := Surface(g, root)
        h := Min(root.Measure(width), A_ScreenHeight / s - 80)
        Dialog.DarkTitle(g.Hwnd)
        prev := [Dialog.gui, Dialog.surface, Dialog.defaultButton, Dialog.cancelButton, Dialog.result]
        Dialog.gui := g, Dialog.surface := surf, Dialog.result := "", Dialog.defaultButton := defaultText, Dialog.cancelButton := cancelText
        g.OnEvent("Close", (*) => (Dialog.result := Dialog.result = "" ? cancelText : Dialog.result, g.Hide(), 0))
        g.OnEvent("Escape", (*) => (Dialog.result := cancelText, g.Hide()))
        pw := Round(width * s), ph := Round(h * s)
        if owner {
            try {
                WinGetPos(&ox, &oy, &ow, &oh, "ahk_id " owner)
                g.Show("Hide w" pw " h" ph)
                WinGetPos(, , &dw, &dh, g)
                g.Show("x" (ox + (ow - dw) // 2) " y" (oy + (oh - dh) // 2) " w" pw " h" ph)
            } catch
                g.Show("w" pw " h" ph " Center")
            try WinSetEnabled(0, "ahk_id " owner)
        } else
            g.Show("w" pw " h" ph " Center")
        surf.Resize(pw, ph)
        WinWaitClose(g)
        while WinExist("ahk_id " g.Hwnd) && DllCall("IsWindowVisible", "Ptr", g.Hwnd)
            Sleep(30)
        result := Dialog.result
        if owner {
            try WinSetEnabled(1, "ahk_id " owner)
            try WinActivate("ahk_id " owner)
        }
        surf.Destroy()
        try g.Destroy()
        Dialog.gui := prev[1], Dialog.surface := prev[2], Dialog.defaultButton := prev[3], Dialog.cancelButton := prev[4]
        Dialog.result := prev[5]
        return result
    }

    static Choose(text, *) {
        Dialog.result := text
        if Dialog.gui
            Dialog.gui.Hide()
    }

    ; QMessageBox.question equivalent. defaultIndex marks the safe default.
    static Ask(title, message, buttons := ["OK"], cancelIndex := 0) {
        root := VBox(, 18, [22, 20, 22, 18])
        root.Add(Label(message, "", true))
        row := HBox(, 8)
        row.Add(Spacer(0), 1)
        cancel := cancelIndex ? buttons[cancelIndex] : buttons[buttons.Length]
        ; The safe default (QMessageBox default button) carries the accent, never a destructive choice.
        for i, b in buttons
            row.Add(Button(_T(b), Dialog.Choose.Bind(Dialog, b), b == cancel ? "accent" : ""))
        root.Add(row)
        return Dialog.Run(title, root, 440, MW.gui ? MW.gui.Hwnd : 0, cancel, cancel)
    }

    static Key(vk) {
        if !Dialog.gui
            return false
        if (vk = 0x0D && Dialog.defaultButton != "") {
            Dialog.Choose(Dialog.defaultButton)
            return true
        }
        return false
    }
}

class FirstUse {
    static TERMS_URL := "https://ultmacro.xyz/terms/"
    static PRIVACY_URL := "https://ultmacro.xyz/privacy/"
    static POLICY_REVISION := "2026-10-22"

    ; Explicit acknowledgement before the workspace opens (first_use.py).
    static Terms() {
        root := VBox(, 16, [24, 24, 24, 18])
        root.Add(Label(_T("Welcome to Ultimate Macro"), "title", true))
        root.Add(Label(_T("Before you begin, please review the Terms and Privacy Policy."), "subtitle", true))
        links := HBox(, 8)
        links.Add(Button(_T("Terms ↗"), (*) => Run(FirstUse.TERMS_URL)), 1)
        links.Add(Button(_T("Privacy ↗"), (*) => Run(FirstUse.PRIVACY_URL)), 1)
        root.Add(links)
        cont := Button(_T("Continue"), Dialog.Choose.Bind(Dialog, "Continue"), "accent")
        cont.Enable(false)
        consent := root.Add(Check(_T("I agree to the terms and acknowledge the privacy policy."), false, (c, v) => (cont.Enable(v), cont.kind := v ? "accent" : "")))
        root.Add(Spacer(4))
        root.Add(cont)
        exitRow := HBox(, 8)
        exitRow.Add(Spacer(0), 1)
        exitRow.Add(Button(_T("Exit"), Dialog.Choose.Bind(Dialog, "Exit")))
        root.Add(exitRow)
        if (Dialog.Run("Ultimate Macro 1.4", root, 460, 0, "", "Exit") != "Continue" || !consent.checked)
            return false
        Store.settings["policyRevision"] := FirstUse.POLICY_REVISION
        try Store.Save()
        return true
    }

    static Language() {
        root := VBox(, 14, [24, 24, 24, 18])
        root.Add(Label(_T("Language"), "title", true))
        root.Add(Label(_T("Choose the interface language."), "subtitle", true))
        root.Add(Label(_T("Community translations may not cover every new feature. Missing text stays in English. This changes the macro interface only, not Roblox or strategy files."), "caption", true))
        sel := root.Add(Select())
        for item in Locale.Available()
            sel.AddItem(item.name " (" item.code ")", item.code)
        sel.ChooseValue(Store.settings["language"]) || sel.Choose(1)
        actions := HBox(, 8)
        actions.Add(Button(_T("Exit"), Dialog.Choose.Bind(Dialog, "Exit")))
        actions.Add(Spacer(0), 1)
        actions.Add(Button(_T("Continue"), Dialog.Choose.Bind(Dialog, "Continue"), "accent"))
        root.Add(actions)
        if (Dialog.Run("Ultimate Macro · Language", root, 500, 0, "Continue", "Exit") != "Continue")
            return false
        Store.settings["language"] := sel.Value, Store.settings["languageChosen"] := true
        try Store.Save()
        Locale.Set(sel.Value)
        return true
    }
}

; Read-only, allowlisted import of 1.3.x / 1.4 preferences (legacy_profile.py).
class LegacyProfile {
    static FLAGS := Map("alwaysontop", "topmost", "autoequip", "autoEquip")
    static KEYS := Map("cancelplacement", "cancelKey", "raisethedead", "raiseDeadKey", "chain", "chainKey", "caravan", "caravanKey"
        , "beat", "beatKey", "hologram", "hologramKey", "repo", "repositionKey")
    static RECORD := Map("aligncamerakey", "align", "placetowerkey", "place", "upgradetowerkey", "upgrade", "selltowerkey", "sell"
        , "holokey", "clone", "changetargetskey", "targets", "changedjtrackkey", "dj")

    static Hotkey(value) {
        value := Trim(value)
        if (StrLen(value) > 16)
            throw ValueError()
        mods := [], i := 1, names := Map("^", "Ctrl", "!", "Alt", "+", "Shift")
        while (i <= StrLen(value) && InStr("^!+", SubStr(value, i, 1))) {
            m := names[SubStr(value, i, 1)]
            if InArray(mods, m)
                throw ValueError()
            mods.Push(m), i += 1
        }
        key := SubStr(value, i)
        if (key = "vkC0")
            key := "``"
        else if !RegExMatch(key, "i)^(?:[A-Za-z0-9]|F(?:[1-9]|1[0-2]))$")
            throw ValueError()
        out := ""
        for m in mods
            out .= m "+"
        return out StrUpper(key)
    }

    static Read(path, current) {
        SplitPath(path, , , &ext)
        ext := StrLower(ext)
        if (ext != "json" && ext != "tds" && ext != "ump")
            throw ValueError("Choose a legacy profile or settings file")
        if (FileGetSize(path) > 1024 * 1024)
            throw ValueError("Profile exceeds the size limit")
        raw := FileRead(path, "RAW")
        b0 := raw.Size >= 2 ? NumGet(raw, 0, "UShort") : 0
        text := (b0 = 0xFEFF || b0 = 0xFFFE) ? FileRead(path, "UTF-16") : FileRead(path, "UTF-8")
        sections := Map()
        if (ext = "json" || ext = "ump") {
            v := JSON.parse(text)
            if !(v is Map)
                throw ValueError()
            ver := "", secs := ""
            versionKey := ext = "ump" ? "formatversion" : "schemaversion"
            settingsKey := ext = "ump" ? "settings" : "sections"
            if (ext = "ump" && (!v.Has("application") || v["application"] != "Ultimate Macro"))
                throw ValueError("Not an Ultimate Macro profile")
            for k, x in v {
                if (StrLower(k) = versionKey)
                    ver := x
                if (StrLower(k) = settingsKey)
                    secs := x
            }
            if (ver != 1 || !(secs is Map))
                throw ValueError("Unsupported profile version")
            for name, entries in secs {
                m := Map()
                if (entries is Map)
                    for k, x in entries
                        m[StrLower(k)] := x
                sections[StrLower(name)] := m
            }
        } else {
            cur := ""
            Loop Parse text, "`n", "`r" {
                line := Trim(A_LoopField)
                if (line = "" || SubStr(line, 1, 1) = ";")
                    continue
                if (SubStr(line, 1, 1) = "[" && SubStr(line, -1) = "]") {
                    cur := StrLower(Trim(SubStr(line, 2, -1)))
                    if (cur = "" || sections.Has(cur))
                        throw ValueError("Ambiguous profile sections")
                    sections[cur] := Map()
                } else if (InStr(line, "=") && cur != "") {
                    eq := InStr(line, "=")
                    k := StrLower(Trim(SubStr(line, 1, eq - 1)))
                    if (k = "" || sections[cur].Has(k))
                        throw ValueError("Ambiguous profile fields")
                    sections[cur][k] := Trim(SubStr(line, eq + 1))
                }
            }
        }
        cand := Store.CopyMap(current)
        runtime := Store.CopyMap(cand["runtime"]), bindings := Store.CopyMap(cand["recordBindings"])
        imported := 0, skipped := 0, pending := 0, rotation := ""
        for section, entries in sections {
            for key, value in entries {
                try {
                    if !(value is String) && !IsNumber(value)
                        throw ValueError()
                    value := Trim(String(value))
                    if (section = "options" && LegacyProfile.FLAGS.Has(key)) {
                        if (value != "0" && value != "1")
                            throw ValueError()
                        cand[LegacyProfile.FLAGS[key]] := value = "1"
                    } else if (section = "options" && key = "rotatestrategies") {
                        if (value != "0" && value != "1")
                            throw ValueError()
                        rotation := value = "1"
                        continue
                    } else if (section = "options" && (key = "swapamount" || key = "upgradedelay")) {
                        if !RegExMatch(value, "^\+?\d{1,3}$")
                            throw ValueError()
                        n := Integer(value)
                        if (key = "swapamount") {
                            if (n < 1 || n > 999)
                                throw ValueError()
                            cand["rotationAmount"] := n
                        } else {
                            runtime["upgradeDelayMs"] := Max(20, n)
                            pending += 1
                            continue
                        }
                    } else if (section = "options" && key = "swapunit") {
                        if (value !== "Runs" && value !== "Minutes")
                            throw ValueError()
                        cand["rotationUnit"] := value
                    } else if (section = "hotkeys" && LegacyProfile.KEYS.Has(key)) {
                        if !RegExMatch(value, "^[A-Za-z0-9]$")
                            throw ValueError()
                        runtime[LegacyProfile.KEYS[key]] := StrUpper(value)
                        pending += 1
                        continue
                    } else if (section = "recordinghotkeys" && LegacyProfile.RECORD.Has(key)) {
                        bindings[LegacyProfile.RECORD[key]] := LegacyProfile.Hotkey(value)
                        pending += 1
                        continue
                    } else
                        throw ValueError()
                    imported += 1
                } catch
                    skipped += 1
            }
        }
        if pending {
            try {
                runtime := Store.ValidRuntime(runtime)
                bindings := Store.ValidBindings(bindings, runtime)
                cand["runtime"] := runtime, cand["recordBindings"] := bindings
                imported += pending
            } catch
                skipped += pending
        }
        ; Rotation needs two validated slots; legacy paths are never followed.
        if (rotation != "") {
            if (rotation && (cand["slot1"] = "" || cand["slot2"] = ""))
                skipped += 1
            else {
                cand["rotation"] := rotation
                if rotation
                    cand["autoEquip"] := true, cand["repeat"] := true
                imported += 1
            }
        }
        return {candidate: cand, imported: imported, skipped: skipped}
    }
}
