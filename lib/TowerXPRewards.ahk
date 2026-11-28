; Reward collection for the one tower selected for the current match.
TowerXPReadReward(settings, state) {
    selected := IniRead(state, "TowerXP", "Active", "")
    matchId := IniRead(state, "TowerXP", "MatchId", "")
    if selected = "" || !RegExMatch(matchId, "i)^[a-f0-9]{32}$")
        return ""
    hwnd := GetRobloxHWND()
    if !hwnd || !WinActive("ahk_id " hwnd)
        return ""
    for definition in TowerXPDefinitions() {
        if definition.name != selected
            continue
        saved := TowerXPSavedProgress(settings, definition)
        if saved.matchId = matchId
            return ""
        WinGetClientPos(&clientX, &clientY, &w, &h, "ahk_id " hwnd)
        template := A_WorkingDir "\Resources\TowerXP\" definition.file
        portrait := Gdip_CreateBitmapFromFile(template)
        if !portrait
            return ""
        path := A_Temp "\UltimateMacroTowerXP-" DllCall("GetCurrentProcessId", "UInt") ".png"
        try {
            Gdip_GetImageDimensions(portrait, &tw, &th)
            crop := Gdip_CloneBitmapArea(portrait, 0, 0, tw, Max(1, Round(th * 0.72)))
            if !crop
                return ""
            try {
                if Gdip_SaveBitmapToFile(crop, path) != 0
                    return ""
            } finally Gdip_DisposeImage(crop)
            hit := AdvImageSearch(path, Round(w * 0.32), Round(h * 0.48), Round(w * 0.205), Round(h * 0.25), 0.65, 1.6, 0.025)
            if hit.status != "success" || hit.score < 0.85 || hit.scale = 0 || InStr(hit.message, "fallback")
                return ""
            hit.x -= clientX, hit.y -= clientY
            for region in TowerXPCropRegions(hit) {
                text := ""
                try {
                    if !WinActive("ahk_id " hwnd)
                        return ""
                    sw := Min(region.w, w - region.x), sh := Min(region.h, h - region.y)
                    if (sw < 10 || sh < 10)
                        continue
                    bitmap := Gdip_BitmapFromScreen((clientX + region.x) "|" (clientY + region.y) "|" sw "|" sh)
                    if (bitmap <= 0)
                        continue
                    try text := OCR.FromBitmap(bitmap, {lang: "en-US", scale: 4, grayscale: true}).Text
                    finally Gdip_DisposeImage(bitmap)
                } catch {
                    continue
                }
                if !RegExMatch(text, "i)\+\s*(\d{1,4})\s*XP\b", &m)
                    continue
                gain := Integer(m[1])
                if gain <= 0
                    continue
                next := TowerXPAdvance(definition, saved.level, saved.xp, gain)
                IniWrite(next.level "," next.xp "," matchId, settings, TowerXPSectionName(selected), "Progress")
                return selected " +" gain " Tower XP · Level " next.level
            }
            return ""
        } finally {
            Gdip_DisposeImage(portrait)
            try FileDelete(path)
        }
    }
    return ""
}
