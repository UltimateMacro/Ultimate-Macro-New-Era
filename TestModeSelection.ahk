#Requires AutoHotkey v2.0
#Warn All, Off
#NoTrayIcon
#SingleInstance Off
#Include engine\lib\UM14Features.ahk
#Include engine\lib\UM14Click.ahk

global scenario := "", wheelCount := 0, clicks := [], probes := 0, activeDifficulty := "", hover := [0, 0], dismissedAt := 0
global cancelInputs := 0
Click(x, y := unset) {
    global dismissedAt
    if (x = "Up")
        return
    clicks.Push(IsSet(y) ? [x, y] : hover.Clone())
    if (scenario = "startup-dismiss" && clicks.Length = 3)
        dismissedAt := A_TickCount
}
MouseMove(x, y, *) {
    global hover := [x, y]
}
MouseGetPos(&x, &y) {
    x := hover[1], y := hover[2]
}
Sleep(duration) {
    ; Only the deadline fixtures need wall-clock pacing. Frame-based cases
    ; supply their next observation immediately without waiting on a game.
    if (SubStr(scenario,1,8) = "startup-" || scenario = "green-receipt")
        DllCall("Sleep","UInt",duration)
}
SendEvent(keys) {
    global wheelCount, cancelInputs
    if (keys = "{Q}" && SubStr(scenario,1,10) = "placement-") {
        cancelInputs++
        return
    }
    if (keys != "{WheelDown 2}")
        throw Error("Unexpected input")
    wheelCount++
}
waitForTowerUI(*) => scenario = "placement-open" || (scenario = "placement-late" && cancelInputs = 1)
LogToConsole(*) => 0
UM14_RequireReadyFocus() => 0
UM14_RequireInputPoint(identity,x,y,*) {
    if (!UM14_ConnectionSame(identity) || x < 0 || y < 0 || x >= identity.w || y >= identity.h)
        throw Error("Fixture input point invalid")
}
global SettingsFile := "fixture"
IniRead(file, section, key, fallback := "") => fallback
UM14_Fatal(message) {
    throw Error(message)
}
UM14_ConnectionSnapshot() => scenario = "docked" || scenario = "squad" || scenario = "hardcore" ? {w:1078, h:995,key:"game"}
    : scenario = "horizontal" || scenario = "squad-compact" || scenario = "modifier-compact" || scenario = "compact-reward" ? {w:800, h:600,key:"game"} : {w:1000, h:700,key:"game"}
UM14_ConnectionSame(*) => scenario != "moved"
UM14_ConnectionCaptureClear(*) => scenario != "moved"
UM14_ConnectionOCRStage() => scenario = "ready-uncertain" ? "overlap" : "success"
UM14_LobbyOrInventory() => ((scenario = "startup-stack" || scenario = "startup-retry") && clicks.Length = 2)
    || (scenario = "startup-dismiss" && clicks.Length = 3 && A_TickCount-dismissedAt >= 700)
PixelGetColor(x,y) => (scenario = "startup-stack" && !clicks.Length)
    ? (x = 770 || y = 106 ? 0xF82736 : 0xFFFFFF) : (scenario = "ready-green" || scenario = "ready-uncertain" || scenario = "ready-image" || scenario = "restart" || scenario = "login-reward" || scenario = "compact-reward"
        || scenario = "unrelated-claim" || scenario = "startup-stack" || scenario = "startup-retry"
        || scenario = "startup-stuck" || scenario = "startup-dismiss" || scenario = "reward-hidden-on-hover") ? 0x22CA38
        : (scenario = "map-vip" || scenario = "map-template" || scenario = "map-query" || scenario = "map-query-suffix" || scenario = "map-wrong-screen")
            ? (x = hover[1] ? 0xFFFFFF : 0x203329) : 0xB8A9A7
PixelSearch(&px,&py,x,y,right,bottom,color,*) {
    px := x+1, py := y+1
    return (scenario = "green-receipt" || scenario = "other-map-receipt") && color = 0x00EC00
}
UM14_Region(x, y, w, h, *) => {x:x, y:y, w:w, h:h}
UM14_OCRWords(recognized, *) => IsObject(recognized) ? recognized : []
UM14_ConnectionOCR(identity, region, factor := 0, *) {
    if (SubStr(scenario,1,10) = "placement-") {
        if (region.y = Round(identity.h*.935)) {
            if (scenario = "placement-ambiguous")
                return "1/50 2/50"
            if (scenario = "placement-unchanged")
                return "0 / 50"
            return cancelInputs ? "1 / 50" : "0 / 50"
        }
        if (factor = 3.2)
            return scenario = "placement-other" ? "Another Tower Elf Camp Lv. 0" : "Your Tower Elf Camp Lv. 0"
    }
    if (scenario = "hardcore" && region.x = Floor(identity.w*.3307))
        return "Wretched`nFront"
    if (scenario = "items" && factor = 3.0)
        return [{text:"ITEMS",raw:"Items",x:85,y:320,w:40,h:14}]
    if (scenario = "lobby" && region.x = 250 && region.y = 462)
        return [{text:"PLAY",raw:"PLAY",x:450,y:640,w:50,h:16}]
    if ((scenario = "startup-stack" && !clicks.Length) || scenario = "wrong-news") {
        if (region.x = Round(identity.w*.015))
            return "Lobby All Updates Current Version"
        if (region.x = Round(identity.w*.29) && scenario != "wrong-news")
            return "Time Dilator Update Log: New tower"
    }
    if (scenario = "login-reward" || scenario = "compact-reward" || scenario = "unrelated-claim"
        || scenario = "reward-nongreen" || scenario = "startup-retry" || scenario = "startup-stuck" || scenario = "startup-dismiss"
        || (scenario = "startup-stack" && clicks.Length = 1) || (scenario = "reward-hidden-on-hover" && !hover[1])) {
        if (region.x = Round(identity.w*.18) && scenario != "unrelated-claim")
            return "Rewards Rewards scale with your login streak! Day 1 Day 2 x75 Day 3 Day 4 Day 5"
        y := scenario = "compact-reward" ? 574 : 560
        if (region.x = Round(identity.w*.33) && y >= region.y && y+13 <= region.y+region.h)
            return [{text:"CLAIM",raw:"CLAIM",x:Round(identity.w/2)-25,y:y,w:50,h:13}]
        if (scenario = "startup-dismiss" && region.x = 710 && clicks.Length = 2)
            return [{text:"LOGIN",raw:"Login",x:830,y:53,w:40,h:10}]
    }
    if (scenario = "map-purchase" && region.x = 220 && region.y = 154)
        return "Buy Robux and item VIP"
    if (scenario = "map-template" && region.y > 220 && region.y < 240)
        return "All Maps Easy Normal Hard Insane"
    if (scenario = "other-map-receipt" && region.x = 230)
        return "Map changed to Cataclysm"
    if (scenario = "map-receipt-suffix" && region.x = 230)
        return "Map changed to Dead Ahead Annex"
    if (scenario = "map-receipt-mixed" && region.x = 230)
        return {Text:"Map changed to Dead Ahead HUD title", Lines:[{Text:"Map changed to Dead Ahead"},{Text:"HUD title"}]}
    if (scenario = "map-vip" || scenario = "map-query" || scenario = "map-query-suffix" || scenario = "map-wrong-screen") {
        if (region.x = 290 && scenario != "map-wrong-screen")
            return "Vote For A Map"
        if (region.x = 240 && scenario = "map-query")
            return "A Dead Ahead"
        if (region.x = 240 && scenario = "map-query-suffix")
            return "Dead Ahead Annex"
        if (region.x = 120) {
            if (scenario = "map-vip" || scenario = "map-wrong-screen")
                return [{text:"SEARCH",x:250,y:213,w:46,h:13},{text:"FOR",x:300,y:213,w:22,h:13},
                    {text:"MAPS",x:326,y:213,w:32,h:13}]
        }
        if (region.x = 230 && scenario = "map-query")
            return "Map changed to Dead Ahead"
        if (region.y >= 300 && scenario = "map-query")
            return "Dead Ahead"
    }
    if ((scenario = "ready-green" || scenario = "ready-uncertain" || scenario = "ready-nongreen")
        && region.x = 290 && !clicks.Length && (scenario != "ready-green" || hover[1] != 500))
        return [{text:"READY",raw:"READY",x:480,y:145,w:40,h:16}]
    if (scenario = "easy" && region.x = 210 && region.w = 620) {
        captions := []
        if (hover[1] != 320)
            captions.Push({text:"EASY",raw:"Easy",x:300,y:200,w:40,h:14})
        if (hover[1] != 525)
            captions.Push({text:"CASUAL",raw:"Casual",x:500,y:200,w:50,h:14})
        return captions
    }
    if (scenario = "map-prompt" && region.x = 190 && region.w = 620)
        return "E Override Map"
    if (scenario = "squad-compact") {
        if (region.y = 15)
            return "Choose a Squad...`nSelect the maximum..."
        if (region.x = 176 && region.y = 234)
            return "Solo"
    }
    if (scenario = "horizontal" && region.y = 33) {
        if (region.x = 264)
            return [{text:"SURVIVAL",raw:"Survival",x:275,y:45,w:40,h:10}]
        if (region.x = 332)
            return [{text:"STORY",raw:"Story",x:348,y:45,w:28,h:10}]
    }
    if (scenario = "squad") {
        if (region.y = Round(identity.h*.025))
            return [{text:"SQUAD...",raw:"Squad...",x:500,y:49,w:49,h:16}]
        if (region.x = Round(identity.w*.19) && region.y = Round(identity.h*.34))
            return [{text:"SOLO",raw:"Solo",x:264,y:480,w:31,h:14}]
    }
    if (scenario = "modifier" && hover[2] = Round(identity.h*.945))
        return [{text:"ADD", x:32, y:615, w:18, h:9},
            {text:"MODIFIER", x:54, y:615, w:43, h:9}]
    if (scenario = "modifier-compact" && region.w >= 220 && hover[2] = Round(identity.h*.98))
        return [{text:"ADD",x:43,y:550,w:22,h:10},
            {text:"MODIFIER",x:70,y:550,w:68,h:10}]
    if (region.y = 0 && (region.w = 270 || region.w = 431 || region.w = 320)
        && (scenario = "heading" || scenario = "easy" || scenario = "sidebar" || scenario = "docked" || scenario = "horizontal"))
        return [{text:"SURVIVAL", raw:"Survival", x:region.x+30, y:scenario = "heading" ? 240 : 22, w:75, h:13}]
    if (scenario = "hardcore-title" && region.x = 210 && region.w = 310)
        return [{text:"HARDCORE",raw:"Hardcore",x:225,y:340,w:67,h:16},
            {text:"HARDCORE",raw:"Hardcore",x:225,y:362,w:60,h:12}]
    if (scenario = "locked-voidcore" && region.x = 520 && region.w = 310)
        return "Complete Hardcore to unlock."
    if (scenario = "all-mode-captions" && (region.x = 210 || region.x = 520))
        return [{text:StrUpper(activeDifficulty),raw:activeDifficulty,x:region.x+30,y:230,w:65,h:15}]
    return []
}
AdvancedImageSearch(path, x, y, w, h, *) {
    global probes
    if (scenario = "map-template" && path = "Resources/searchbar.png")
        return {status:"success",score:.91,x:310,y:220,w:125,h:13}
    if (path = "Resources/close.png" && ((scenario = "startup-stack" && !clicks.Length && hover[1] != 770) || scenario = "wrong-news"))
        return {status:"success",score:.96,x:x+110,y:y+60}
    if (scenario = "restart" && path = "Resources/Restart.png" && !clicks.Length && hover[1] != 220)
        return {status:"success", score:.94, x:x+220, y:y+90,w:90,h:23}
    if ((scenario = "ready-image" || scenario = "ready-uncertain") && path = "Resources/ready_gs.png" && !clicks.Length)
        return {status:"success",score:.90,x:500,y:153}
    if (path = "Resources/Ready.png" && (scenario = "modifier" || scenario = "modifier-compact" || scenario = "map-prompt"))
        return {status:"success", score:.9, x:x+100, y:y+50}
    if (path = "Resources/Survival.png" && (scenario = "sidebar" || scenario = "easy" || scenario = "misleading-easy-art"))
        return {status:"success", score:.93, x:x+25, y:y+30}
    if (path = "Resources/Easy.png" && (scenario = "easy" || scenario = "misleading-easy-art"))
        return {status:"success",score:.99,x:525,y:207}
    if (path = "Resources/Survival.png" && scenario = "docked" && x <= 58 && x+w > 58)
        return {status:"success", score:.93, x:58, y:295}
    if (path = "Resources/close.png" && scenario = "heading")
        return {status:"success", score:.95, x:x+30, y:y+30}
    if (path = "Resources/" activeDifficulty ".png" && scenario != "easy") {
        probes++
        if (scenario = "docked")
            return wheelCount && x <= 899 && x+w > 899
                ? {status:"success", score:.9, x:899, y:725}
                : {status:"failed", score:0, x:0, y:0}
        if (scenario = "horizontal")
            return wheelCount && x <= 724 && x+w > 724
                ? {status:"success", score:.9, x:724, y:511}
                : {status:"failed", score:0, x:0, y:0}
        if (wheelCount >= 1)
            return {status:"success", score:.9, x:x+90, y:y+90}
    }
    return {status:"failed", score:0, x:0, y:0}
}
Need(ok, text) {
    if !ok
        throw Error(text)
}
try {
    scenario := "restart"
    Need(UM14_ClickResult("Restart.png","Restart") && clicks.Length = 1 && clicks[1][1] = 273,
        "Restart is rechecked after hover, clicked once, then verified gone")
    clicks := []
    Need(UM14_BestRestart({status:"failed",score:.99},{status:"success",score:.71}) = "Restart2.png",
        "A failed template cannot beat a valid Restart match")
    Need(UM14_MapCaption("Wretched`nFront", "Wretched Front")
        && !UM14_MapCaption("Wrecked Battlefield", "Wretched Front")
        && !UM14_MapCaption("Wretched Frontier", "Wretched Front"), "Exact map words do not match a different map")
    scenario := "hardcore"
    Need(UM14_HardcoreMapSlot("Wretched Front") = 2 && !UM14_HardcoreMapSlot("Wrecked Battlefield"),
        "Hardcore captions come from the stable game client, including a wrapped docked caption")
    scenario := "moved"
    Need(!UM14_HardcoreMapSlot("Wretched Front"), "No map choice from a moved or inactive game")
    Need(!UM14_MapImageVerified({status:"success",score:.7},"Hardcore")
        && !UM14_MapImageVerified({status:"error",score:.99},"Hardcore")
        && UM14_MapImageVerified({status:"success",score:.9},"Hardcore"),
        "A weak unrelated terrain match cannot confirm a Hardcore map")
    Need(UM14_InputRootMatches(123,123) && !UM14_InputRootMatches(124,123)
        && !UM14_InputRootMatches(0,0), "Only the selected game root may receive pointer input")
    scenario := "lobby"
    play := UM14_LobbyPlay()
    Need(IsObject(play) && play.x = 475 && play.y = 648 && !clicks.Length,
        "Lobby Play recognition falls back to a verified live label without clicking or relaunching")
    scenario := "moved"
    Need(!UM14_LobbyPlay(), "Lobby recognition rejects a changed client")
    scenario := "unrelated-claim", clicks := []
    Need(!UM14_StartupOverlay(UM14_ConnectionSnapshot()) && !clicks.Length,
        "Claim text without the Login Rewards heading gets no click")
    scenario := "reward-nongreen"
    overlay := UM14_StartupOverlay(UM14_ConnectionSnapshot())
    Need(IsObject(overlay) && !IsObject(overlay.button) && !clicks.Length,
        "Plain Claim text with no green button cannot receive input")
    scenario := "wrong-news"
    Need(!UM14_StartupOverlay(UM14_ConnectionSnapshot()) && !clicks.Length,
        "One heading and a red X are not enough to close the Update Log")
    scenario := "reward-hidden-on-hover", hover := [0,0]
    ctx := UM14_ConnectionSnapshot(), overlay := UM14_StartupOverlay(ctx)
    Need(IsObject(overlay.button) && !UM14_ClickStartupOverlay(ctx,overlay) && !clicks.Length,
        "A different screen under the pointer never receives a Claim click")
    for size in ["login-reward","compact-reward"] {
        scenario := size, clicks := []
        ctx := UM14_ConnectionSnapshot(), overlay := UM14_StartupOverlay(ctx)
        Need(IsObject(overlay.button) && UM14_ClickStartupOverlay(ctx,overlay) && clicks.Length = 1
            && clicks[1][1] = ctx.w/2 && (size != "compact-reward" || clicks[1][2] > ctx.h*.95),
            "Verified Claim is clickable in the " size " viewport")
    }
    scenario := "startup-stack", clicks := [], hover := [0,0]
    Need(UM14_WaitSetupLobby(5000) && clicks.Length = 2 && clicks[1][1] = 770 && clicks[2][1] = 500,
        "Close update notes before claiming a reward underneath")
    scenario := "startup-retry", clicks := []
    Need(UM14_WaitSetupLobby(5000) && clicks.Length = 2,
        "One missed press gets exactly one independently verified retry")
    scenario := "startup-stuck", clicks := [], stopped := false
    try UM14_WaitSetupLobby(3900)
    catch as e
        stopped := InStr(e.Message,"Login Rewards is still open")
    Need(stopped && clicks.Length = 2, "An unchanged reward never gets a third press or a relaunch")
    scenario := "startup-dismiss", clicks := []
    Need(UM14_WaitSetupLobby(3500) && clicks.Length = 3 && clicks[3][1] = 850 && clicks[3][2] < 53,
        "A late verified Login dismiss gets time to transition instead of triggering an immediate timeout")
    clicks := []
    scenario := "map-purchase", blocked := false
    try UM14_MapOverrideSearch(UM14_ConnectionSnapshot())
    catch as e
        blocked := InStr(e.Message,"purchase prompt")
    Need(blocked && !clicks.Length && !UM14_MapPurchaseText("Current map vote"),
        "A Roblox purchase prompt never becomes a map-search click")
    scenario := "map-wrong-screen"
    Need(!UM14_MapOverrideSearch(UM14_ConnectionSnapshot()), "Search text outside the map vote is not a field")
    scenario := "map-vip", ctx := UM14_ConnectionSnapshot()
    field := UM14_MapOverrideSearch(ctx)
    Need(IsObject(field) && field.x > 358 && field.y = 220, "Map search clicks inside the dark field, away from its label")
    hover := [field.x,field.y]
    Need(UM14_ButtonStillAt(field,UM14_MapOverrideSearch(ctx)), "The live I-beam cannot hide the whole textbox")
    scenario := "map-template"
    current := UM14_MapOverrideSearch(ctx)
    Need(IsObject(current) && current.x > 372 && current.y = 220,
        "Unreadable outlined title/placeholder can use the map filter tabs plus two stable search images")
    scenario := "map-query-suffix"
    Need(!UM14_MapOverrideCard(ctx,field,"Dead Ahead"), "A different query cannot select a map card")
    scenario := "map-query"
    card := UM14_MapOverrideCard(ctx,field,"Dead Ahead")
    Need(IsObject(card) && card.x < field.x && card.y > field.y && UM14_MapOverrideReceipt(ctx,"Dead Ahead") = "changed",
        "A verified filtered card is followed by the matching TDS receipt")
    Need(UM14_MapHoveredCardName(ctx,card,field,"Dead Ahead") && !UM14_MapHoveredCardName(ctx,card,field,"Dead Ahead Annex"),
        "The hovered tile's title confirms only the exact selected map")
    scenario := "green-receipt"
    Need(UM14_MapOverrideReceipt(ctx,"Dead Ahead",field,true,0) = "changed",
        "Fresh green receipt can confirm a verified tile with the search closed")
    Need(UM14_MapOverrideReceipt(ctx,"Dead Ahead",field,true,1,160) = "", "Existing green pixels cannot confirm a click")
    scenario := "other-map-receipt"
    Need(UM14_MapOverrideReceipt(ctx,"Dead Ahead",field,true,0) = "different", "A receipt for a different map overrides the green cue")
    scenario := "map-receipt-suffix"
    Need(UM14_MapOverrideReceipt(ctx,"Dead Ahead",field,true,0) = "different", "A longer map name sharing the requested prefix is still different")
    scenario := "map-receipt-mixed"
    Need(UM14_MapOverrideReceipt(ctx,"Dead Ahead",field,true,0) = "changed", "A separate HUD line cannot be mistaken for a map-name suffix")
    scenario := "ready-nongreen"
    Need(!UM14_ReadyButton(UM14_ConnectionSnapshot()) && !clicks.Length,
        "Plain Ready text without its button background is not clickable")
    scenario := "ready-green", hover := [0,0]
    ctx := UM14_ConnectionSnapshot(), button := UM14_ReadyButton(ctx)
    Need(IsObject(button) && UM14_ClickMatchReady(ctx,button) && clicks.Length = 1 && clicks[1][1] = 536,
        "Green Ready is rechecked off the caption and accepted on two readable frames")
    scenario := "ready-uncertain", clicks := []
    ctx := UM14_ConnectionSnapshot(), button := UM14_ReadyButton(ctx)
    Need(IsObject(button) && !UM14_ClickMatchReady(ctx,button) && clicks.Length = 1,
        "A capture failure after Ready does not count as a transition or cause a blind retry")
    scenario := "placement-open", cancelInputs := 0
    Need(UM14_ConfirmPlacementPanel(UM14_ConnectionSnapshot(),"Q") && cancelInputs = 0,
        "A fresh placement panel is accepted without closing it or clicking again")
    scenario := "placement-late", cancelInputs := 0
    Need(UM14_ConfirmPlacementPanel(UM14_ConnectionSnapshot(),"Q") && cancelInputs = 1,
        "A delayed panel still uses the legacy cancel-and-confirm path once")
    scenario := "placement-failed", cancelInputs := 0
    Need(!UM14_ConfirmPlacementPanel(UM14_ConnectionSnapshot(),"Q") && cancelInputs = 1,
        "No panel is not accepted as a placement")
    scenario := "placement-proof", cancelInputs := 0, clicks := [], panelOpen := true
    ctx := UM14_ConnectionSnapshot(), before := UM14_PlacementCounter(ctx)
    Need(IsObject(before) && before.used = 0 && before.cap = 50,
        "Capture the actual tower counter before selecting the slot")
    Need(UM14_ConfirmPlacementPanel(ctx,"Q",320,310,before,&panelOpen) && !panelOpen
        && cancelInputs = 1 && clicks.Length = 1 && clicks[1][1] = 320 && clicks[1][2] = 310,
        "A new owned tower is reselected once, with no second purchase or false open-panel flag")
    for mode in ["placement-other", "placement-unchanged", "placement-ambiguous"] {
        scenario := mode, cancelInputs := 1, clicks := []
        Need(!UM14_NewPlacementProof(ctx,320,310,before) && !clicks.Length,
            "Reject tower proof without an unambiguous new count and own tooltip")
    }
    clicks := []
    scenario := "items"
    item := UM14_MenuWordPair({w:1000,h:700},{x:0,y:250,w:168,h:130},"ITEMS",false,false,3.0)
    Need(IsObject(item) && item.x = 105 && !clicks.Length,
        "A current Items label uses two exact observations at the requested scale")
    scenario := "easy", activeDifficulty := "Easy"
    Need(UM14_SelectCurrentMode("Easy", &seen) && clicks.Length = 2 && clicks[2][1] = 354,
        "Easy never aliases to Casual and its label remains visible under hover")
    clicks := [], activeDifficulty := "Casual"
    Need(UM14_SelectCurrentMode("Casual", &seen) && clicks.Length = 2 && clicks[2][1] = 564,
        "Casual retains its own card")
    scenario := "misleading-easy-art", clicks := []
    Need(!UM14_ModeCard(UM14_ConnectionSnapshot(),{x:210,y:70,w:620,h:588},"Easy") && !clicks.Length,
        "A misleading high-score Easy image is not enough without the Easy caption")
    Need(!UM14_SelectCurrentMode("Easy",&seen) && !seen && clicks.Length = 1,
        "An Event page without a verified Survival section gets only the tab click")
    scenario := "hardcore-title"
    card := UM14_ModeCard(UM14_ConnectionSnapshot(),{x:210,y:70,w:620,h:588},"Hardcore")
    Need(IsObject(card) && card.y = 348, "Hardcore title wins only over its smaller aligned subtitle")
    scenario := "locked-voidcore", clicks := [], stopped := false
    try UM14_ModeCard(UM14_ConnectionSnapshot(),{x:210,y:70,w:620,h:588},"Voidcore")
    catch Error as err
        stopped := InStr(err.Message,"Voidcore is locked")
    Need(stopped && !clicks.Length, "A locked Voidcore card explains the requirement without clicking")
    scenario := "all-mode-captions"
    for mode in ["Easy", "Casual", "Intermediate", "Molten", "Fallen", "Frost", "Hardcore", "Voidcore"] {
        activeDifficulty := mode
        card := UM14_ModeCard(UM14_ConnectionSnapshot(),{x:210,y:70,w:620,h:588},mode)
        Need(IsObject(card) && card.x = (mode = "Voidcore" ? 583 : 273), "Select the exact title for " mode)
        other := mode = "Casual" ? "Easy" : "Casual"
        Need(!UM14_ModeCard(UM14_ConnectionSnapshot(),{x:210,y:70,w:620,h:588},other), "Do not alias " mode " to " other)
    }
    clicks := [], wheelCount := 0, probes := 0
    scenario := "sidebar", activeDifficulty := "Fallen"
    Need(UM14_SelectCurrentMode("Fallen", &seen) && seen, "Fallen selected after seeing sidebar icon")
    Need(wheelCount = 1 && clicks.Length = 2 && probes >= 3, "Fallen uses bounded scroll and two sightings")
    scenario := "heading", activeDifficulty := "Frost", wheelCount := 0, clicks := [], probes := 0
    Need(UM14_SelectCurrentMode("Frost", &seen) && seen, "Frost selected when below the heading")
    Need(wheelCount = 1 && clicks.Length = 1 && probes >= 3, "Frost heading path avoids a blind sidebar click")
    scenario := "docked", activeDifficulty := "Frost", wheelCount := 0, clicks := [], probes := 0
    Need(UM14_SelectCurrentMode("Frost", &seen) && seen, "Frost selected in the docked full-width menu")
    Need(clicks.Length = 2 && clicks[1][1] = 58 && clicks[2][1] = 899 && wheelCount = 1,
        "Docked sidebar and far-right card are both in bounds")
    scenario := "horizontal", wheelCount := 0, clicks := [], probes := 0
    Need(UM14_SelectCurrentMode("Frost", &seen) && seen, "Frost selected in an 800x600 client")
    Need(clicks.Length = 2 && clicks[1][1] = 295 && clicks[2][1] = 724 && wheelCount = 1,
        "Small horizontal tabs are confirmed before scrolling or clicking")
    scenario := "squad"
    solo := UM14_SquadCard("Solo")
    Need(IsObject(solo) && solo.x = 280 && solo.y = 487, "Docked Solo label is verified under the squad heading")
    Need(!UM14_SquadCard("Duo"), "Do not click the wrong squad card")
    scenario := "squad-compact"
    solo := UM14_SquadCard("Solo")
    Need(IsObject(solo) && solo.x = 252 && solo.y = 273, "Compact squad uses exact text when word boxes are missing")
    Need(!UM14_SquadCard("Duo"), "Compact fallback rejects a different squad label")
    scenario := "map-prompt"
    Need(IsObject(UM14_MapOverridePrompt()), "Visible map-vote controls and exact Override Map label verify the prompt")
    scenario := "no-vote"
    Need(!UM14_MapOverridePrompt(), "No map override input outside the vote screen")
    scenario := "moved", activeDifficulty := "Fallen", seen := false, wheelCount := 0, clicks := []
    Need(!UM14_SelectCurrentMode("Fallen", &seen) && wheelCount = 0 && clicks.Length = 0, "No input when Roblox identity changed")
    scenario := "modifier", clicks := [], hover := [0, 0]
    UM14_OpenModifierMenu()
    Need(clicks.Length = 1 && clicks[1][1] = 29 && clicks[1][2] = Round(700*.945),
        "Modifier tooltip verifies the icon position rather than clicking the label")
    scenario := "modifier-compact", clicks := [], hover := [0,0]
    UM14_OpenModifierMenu()
    Need(clicks.Length = 1 && clicks[1][1] = 23 && clicks[1][2] = 588,
        "Compact modifier tooltip keeps the whole caption and still clicks only its verified hover point")
    scenario := "no-vote", clicks := [], hover := [0, 0]
    rejected := false
    try UM14_OpenModifierMenu()
    catch as e {
        rejected := InStr(e.Message, "Map vote screen")
    }
    Need(rejected && !clicks.Length && hover[1] = 0, "No modifier input without the vote screen")
    FileAppend("PASS: verified startup overlays, mode selection, Ready, map and modifier guards`n", "*")
    ExitApp(0)
} catch as e {
    FileAppend("FAIL: " e.Message "`n", "**")
    ExitApp(1)
}
