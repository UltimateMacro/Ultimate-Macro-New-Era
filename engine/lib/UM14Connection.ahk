; Local-only disconnect evidence. A template alone never authorizes a restart.
; English game dialogs only; missing/ambiguous text leaves recovery to the user.
UM14_ConnectionSnapshot() {
    global RunningStrategy
    handle := 0
    try {
        if (!RunningStrategy || !UM14_LauncherAlive() || !UM14_SessionCurrent())
            return false
        hwnd := GetRobloxHWND()
        if (!hwnd || DllCall("IsIconic", "Ptr", hwnd))
            return false
        pid := 0
        thread := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "UInt*", &pid, "UInt")
        if (!pid || !thread || StrLower(WinGetProcessName("ahk_id " hwnd)) != "robloxplayerbeta.exe")
            return false
        handle := DllCall("OpenProcess", "UInt", 0x1000, "Int", false, "UInt", pid, "Ptr")
        created := Buffer(8), ended := Buffer(8), kernel := Buffer(8), user := Buffer(8)
        if (!handle || !DllCall("GetProcessTimes", "Ptr", handle, "Ptr", created, "Ptr", ended, "Ptr", kernel, "Ptr", user))
            return false
        root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
        root := root ? root : hwnd
        if (!WinActive("ahk_id " root))
            return false
        UM14_PhysicalDpi()
        WinGetClientPos(&x, &y, &width, &height, "ahk_id " hwnd)
        if (!UM14_Viewport(width, height))
            return false
        freshPid := 0
        freshThread := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "UInt*", &freshPid, "UInt")
        if (freshPid != pid || freshThread != thread || !WinActive("ahk_id " root))
            return false
        key := hwnd "|" pid "|" NumGet(created, 0, "Int64") "|" thread "|" root "|" x "|" y "|" width "|" height
        return {key:key, hwnd:hwnd, root:root, x:x, y:y, w:width, h:height}
    } catch {
        return false
    } finally {
        if (handle)
            DllCall("CloseHandle", "Ptr", handle)
    }
}

UM14_ConnectionSame(expected) {
    actual := UM14_ConnectionSnapshot()
    return IsObject(expected) && IsObject(actual) && expected.key == actual.key
}

UM14_ConnectionDialogText(text) {
    if (Type(text) != "String" || StrLen(text) < 1 || StrLen(text) > 4096)
        return false
    title := false, leave := false, retry := false
    for line in StrSplit(StrReplace(text, "`r", ""), "`n") {
        line := Trim(RegExReplace(StrUpper(line), "\s+", " "))
        if (line == "DISCONNECTED" || line == "CONNECTION LOST")
            title := true
        if (line == "LEAVE")
            leave := true
        if (line == "RECONNECT" || line == "REJOIN" || line == "RETRY")
            retry := true
        if RegExMatch(line, "^(?:LEAVE (?:RECONNECT|REJOIN|RETRY)|(?:RECONNECT|REJOIN|RETRY) LEAVE)$")
            leave := retry := true
    }
    return title && leave && retry
}

UM14_ConnectionOCRStage(value := unset) {
    static stage := "context"
    if IsSet(value) {
        ; Bounded diagnostics only: never retain OCR text or exception messages.
        stage := "context"
        if (Type(value) = "String") {
            switch value {
                case "context", "overlap", "bitmap", "resize", "hbitmap", "ocr", "window", "success":
                    stage := value
            }
        }
    }
    return stage
}

UM14_ConnectionSkipCloaked(queryOk, flags) {
    ; Only positively cloaked (not displayed) windows are irrelevant to capture.
    ; Query failure, unknown bits, layering and click-through are not exemptions.
    return queryOk = true && Type(flags) = "Integer" && flags >= 1 && flags <= 7
}

UM14_ConnectionSkipAlpha(queryOk, alpha, flags) {
    ; A positively queried global alpha of zero makes the entire window
    ; invisible. Per-pixel/colour-key-only/unknown results grant no exemption.
    return queryOk = true && Type(alpha) = "Integer" && alpha = 0
        && Type(flags) = "Integer" && flags >= 0 && flags <= 3 && (flags & 2) != 0
}

UM14_ConnectionOwnerHint(baseName) {
    ; Diagnostic basename classification only, NOT ownership/authentication.
    ; It never grants a capture, click, process action or overlay exemption.
    if (Type(baseName) != "String" || StrLen(baseName) > 80)
        return "other"
    switch StrLower(baseName) {
        case "ultimatemacro.exe":
            return "macro-gui"
        case "ultimatemacro.legacyhost.exe":
            return "legacy-host"
        case "ultimatemacro.engine.exe":
            return "python-worker"
    }
    return "other"
}

UM14_ConnectionOCROverlap(value := unset) {
    static detail := "none"
    if IsSet(value) {
        detail := "none"
        if (Type(value) = "String" && RegExMatch(value,
            "^(?:none|kind=(?:engine|game|other) owner=(?:macro-gui|legacy-host|python-worker|other) cloakKnown=[01] cloaked=[0-7] layered=[01] transparent=[01] alphaKnown=[01] alpha=(?:[0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]) flags=[0-3] x=[0-9]{1,4} y=[0-9]{1,4} w=[0-9]{1,4} h=[0-9]{1,4})$"))
            detail := value
    }
    return detail
}

UM14_ConnectionOverlapDetail(kind, cloakKnown, cloaked, exStyle, ox, oy, ow, oh, expected, alphaKnown := false, alpha := 0, flags := 0, owner := "other") {
    ; Only a relation category, style booleans and client-clipped bounds leave
    ; this function. Never a title, class, process name, PID or window handle.
    if (kind != "engine" && kind != "game" && kind != "other")
        return "none"
    if (owner != "macro-gui" && owner != "legacy-host" && owner != "python-worker" && owner != "other")
        owner := "other"
    left := Max(0,Min(expected.w,Floor(ox-expected.x)))
    top := Max(0,Min(expected.h,Floor(oy-expected.y)))
    right := Max(left,Min(expected.w,Ceil(ox+ow-expected.x)))
    bottom := Max(top,Min(expected.h,Ceil(oy+oh-expected.y)))
    return ("kind=" kind " owner=" owner " cloakKnown=" (cloakKnown ? 1 : 0) " cloaked=" (cloaked >= 0 && cloaked <= 7 ? cloaked : 0)
        " layered=" ((exStyle & 0x80000) ? 1 : 0) " transparent=" ((exStyle & 0x20) ? 1 : 0)
        " alphaKnown=" (alphaKnown ? 1 : 0) " alpha=" Max(0,Min(255,Round(alpha))) " flags=" (flags >= 0 && flags <= 3 ? flags : 0)
        " x=" left " y=" top " w=" (right-left) " h=" (bottom-top))
}

UM14_ConnectionCaptureClear(expected, region, allowTargetOnly := false, &targetOnly := false) {
    targetOnly := false
    UM14_ConnectionOCRStage("overlap")
    UM14_ConnectionOCROverlap("none")
    other := DllCall("GetWindow", "Ptr", expected.root, "UInt", 3, "Ptr")
    limit := 0
    while (other && limit < 256) {
        limit += 1
        if (DllCall("IsWindowVisible", "Ptr", other) && !DllCall("IsIconic", "Ptr", other)) {
            cloaked := 0, cloakKnown := false
            try {
                cloakKnown := DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", other, "UInt", 14, "UInt*", &cloaked, "UInt", 4, "Int") = 0
            } catch {
                cloakKnown := false
            }
            if (!UM14_ConnectionSkipCloaked(cloakKnown,cloaked)) {
                WinGetPos(&ox, &oy, &ow, &oh, "ahk_id " other)
                if (ox < expected.x+region.x+region.w && ox+ow > expected.x+region.x
                    && oy < expected.y+region.y+region.h && oy+oh > expected.y+region.y) {
                    exStyle := DllCall("GetWindowLongPtr", "Ptr", other, "Int", -20, "Ptr")
                    alphaKnown := false, alpha := 0, flags := 0, colorKey := 0
                    if (exStyle & 0x80000) {
                        try {
                            alphaKnown := DllCall("GetLayeredWindowAttributes", "Ptr", other, "UInt*", &colorKey, "UChar*", &alpha, "UInt*", &flags, "Int") != 0
                        } catch {
                            alphaKnown := false
                        }
                        if (!alphaKnown)
                            alpha := 0, flags := 0
                    }
                    if (!UM14_ConnectionSkipAlpha(alphaKnown,alpha,flags)) {
                        ; A layered WS_EX_TRANSPARENT window passes mouse input
                        ; to the game, but can still contaminate a DESKTOP image.
                        ; Permit it ONLY when the caller uses HWND-targeted WGC.
                        ; All other overlapping windows remain a refusal.
                        if (allowTargetOnly && (exStyle & 0x80020) = 0x80020) {
                            targetOnly := true
                            other := DllCall("GetWindow", "Ptr", other, "UInt", 3, "Ptr")
                            continue
                        }
                        otherPid := 0, gamePid := 0
                        DllCall("GetWindowThreadProcessId", "Ptr", other, "UInt*", &otherPid, "UInt")
                        DllCall("GetWindowThreadProcessId", "Ptr", expected.hwnd, "UInt*", &gamePid, "UInt")
                        kind := otherPid && otherPid = DllCall("GetCurrentProcessId", "UInt") ? "engine" : (otherPid && otherPid = gamePid ? "game" : "other")
                        owner := "other"
                        try owner := UM14_ConnectionOwnerHint(WinGetProcessName("ahk_id " other))
                        UM14_ConnectionOCROverlap(UM14_ConnectionOverlapDetail(kind,cloakKnown,cloaked,exStyle,ox,oy,ow,oh,expected,alphaKnown,alpha,flags,owner))
                        return false
                    }
                }
            }
        }
        other := DllCall("GetWindow", "Ptr", other, "UInt", 3, "Ptr")
    }
    return !other
}

UM14_ConnectionWordText(result, region, band, factor) {
    if (!IsObject(result) || !IsObject(region) || !IsObject(band) || !IsNumber(factor) || factor <= 0)
        return ""
    for key in ["x","y","w","h","minH"]
        if (!band.HasOwnProp(key) || Type(band.%key%) != "Integer" || band.%key% < 0 || band.%key% > 8192)
            return ""
    if (band.w < 1 || band.h < 1 || band.minH < 1 || band.minH > band.h || band.x < region.x || band.y < region.y
        || band.x+band.w > region.x+region.w || band.y+band.h > region.y+region.h)
        return ""
    text := "", count := 0, candidates := [], anchor := ""
    for word in result.Words {
        count += 1
        if (count > 512 || Type(word.Text) != "String" || StrLen(word.Text) > 128)
            return ""
        bounds := word.BoundingRect
        for key in ["x","y","w","h"]
            if (!IsNumber(bounds.%key%) || bounds.%key% < 0 || bounds.%key% > 8192)
                return ""
        x := region.x+bounds.x/factor, y := region.y+bounds.y/factor
        right := x+bounds.w/factor, bottom := y+bounds.h/factor
        ; One client pixel accounts for integer OCR box rounding only. Require
        ; the WHOLE word in the band; no word substrings or role-name stripping.
        if (bounds.w > 0 && bounds.h/factor >= band.minH && x >= band.x-1 && y >= band.y-1
            && right <= band.x+band.w+1 && bottom <= band.y+band.h+1) {
            candidate := {text:word.Text,x:x,y:y,h:bounds.h/factor,cy:(y+bottom)/2}
            candidates.Push(candidate)
            if (!IsObject(anchor) || candidate.y < anchor.y)
                anchor := candidate
        }
    }
    if (!IsObject(anchor))
        return ""
    ; The selected detail title is the uppermost LARGE text row. The smaller
    ; role row cannot become a title if title OCR is missing (e.g. Support).
    ; Group complete same-baseline words, then restore their left-to-right order.
    selected := []
    for candidate in candidates {
        if (Abs(candidate.cy-anchor.cy) > Max(candidate.h,anchor.h)*.55)
            continue
        position := 1
        while (position <= selected.Length && selected[position].x < candidate.x)
            position += 1
        selected.InsertAt(position,candidate)
        if (selected.Length > 16)
            return ""
    }
    for candidate in selected
        text .= (text = "" ? "" : " ") candidate.text
    if (StrLen(text) > 256)
        return ""
    return text
}

UM14_ConnectionOCR(expected, region, scale := 0, band := "", structured := false) {
    bitmap := 0, resized := 0, hBitmap := 0
    UM14_ConnectionOCRStage("context")
    UM14_ConnectionOCROverlap("none")
    try {
        if (!UM14_ConnectionSame(expected))
            return ""
        ; Same bounded visible-overlap check before capture and after OCR.
        targetOnly := false
        if (!UM14_ConnectionCaptureClear(expected,region,true,&targetOnly))
            return ""
        UM14_ConnectionOCRStage("context")
        if (!UM14_ConnectionSame(expected))
            return ""
        UM14_ConnectionOCRStage("bitmap")
        if (!IsNumber(scale) || (scale != 0 && (scale < .125 || scale > 4.0)))
            return ""
        factor := Min(scale = 0 ? 2.0 : scale, 2500/Max(region.w,region.h))
        if (targetOnly) {
            UM14_ConnectionOCRStage("window")
            recognized := UM14_TargetWindowOCR(expected,region,factor)
        } else {
            bitmap := Gdip_BitmapFromScreen((expected.x+region.x) "|" (expected.y+region.y) "|" region.w "|" region.h)
            if (!bitmap)
                return ""
            UM14_ConnectionOCRStage("resize")
            resized := Gdip_ResizeBitmap(bitmap, Max(1,Round(region.w*factor)), Max(1,Round(region.h*factor)), 7)
            if (!resized)
                return ""
            UM14_ConnectionOCRStage("hbitmap")
            hBitmap := Gdip_CreateHBITMAPFromBitmap(resized)
            if (!hBitmap)
                return ""
            UM14_ConnectionOCRStage("ocr")
            recognized := OCR.FromBitmap(hBitmap, {lang:"en-US", scale:1, grayscale:1})
        }
        text := IsObject(band) ? UM14_ConnectionWordText(recognized,region,band,factor) : recognized.Text
        UM14_ConnectionOCRStage("context")
        if (!UM14_ConnectionSame(expected))
            return ""
        if (StrLen(text) > 4096) {
            UM14_ConnectionOCRStage("ocr")
            return ""
        }
        afterTargetOnly := false
        if (!UM14_ConnectionCaptureClear(expected,region,targetOnly,&afterTargetOnly))
            return ""
        UM14_ConnectionOCRStage("context")
        if (!UM14_ConnectionSame(expected))
            return ""
        UM14_ConnectionOCRStage("success")
        ; Internal callers may inspect whole-word rectangles, but only AFTER
        ; the same capture/overlap/identity checks as the ordinary text path.
        return structured ? recognized : text
    } catch {
        return ""
    } finally {
        if (hBitmap)
            DeleteObject(hBitmap)
        if (resized)
            Gdip_DisposeImage(resized)
        if (bitmap)
            Gdip_DisposeImage(bitmap)
    }
}

UM14_DisconnectObservation() {
    expected := UM14_ConnectionSnapshot()
    if (!IsObject(expected))
        return false
    ; Stay above the legacy console's bottom-right strip; never exempt another
    ; window/process from the overlap guard merely to make OCR succeed.
    region := UM14_Region(Round(expected.w*.2), Round(expected.h*.15), Round(expected.w*.6), Round(expected.h*.6), expected.w, expected.h)
    if (!IsObject(region))
        return false
    for image in ["Resources/Disconnected.png", "Resources/disconnected2.png"] {
        result := AdvancedImageSearch(image, region.x, region.y, region.w, region.h)
        if (!UM14_ConnectionSame(expected))
            return false
        if (result.status != "success" || result.score < .86)
            continue
        if (result.x < region.x || result.x >= region.x+region.w || result.y < region.y || result.y >= region.y+region.h)
            continue
        text := UM14_ConnectionOCR(expected, region)
        if (!UM14_ConnectionSame(expected) || !UM14_ConnectionDialogText(text))
            return false
        return {identity:expected, observed:A_TickCount, x:result.x, y:result.y, template:image}
    }
    return false
}

UM14_DisconnectPair(first, second) {
    if (!IsObject(first) || !IsObject(second) || first.identity.key != second.identity.key || first.template != second.template)
        return false
    elapsed := second.observed-first.observed
    tolerance := Max(4, Ceil(first.identity.h/1009*4))
    return elapsed >= 400 && elapsed <= 6000 && Abs(first.x-second.x) <= tolerance && Abs(first.y-second.y) <= tolerance
}

UM14_VerifiedDisconnect() {
    try {
        first := UM14_DisconnectObservation()
        if (!IsObject(first))
            return false
        Sleep(450)
        second := UM14_DisconnectObservation()
        if (!UM14_DisconnectPair(first, second) || !UM14_ConnectionSame(second.identity))
            return false
    } catch {
        return false
    }
    return true
}
