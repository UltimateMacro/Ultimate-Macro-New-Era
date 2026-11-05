#Requires AutoHotkey v2.0
#Warn All, Off
#NoTrayIcon
#Include engine\lib\UM14Loadout.ahk

global clicks := [], typed := 0, directText := false, echo := "Sniper", stable := true, pointer := [0,0], rowFixture := false
global inventorySearch := {status:"success",score:.9,x:140,y:110,w:29,h:17}
global inventoryClose := {status:"success",score:.78,x:500,y:50}
AdvancedImageSearch(template,*) => InStr(template,"searchbar") ? inventorySearch.Clone() : inventoryClose.Clone()
Click(x := 0,y := 0,option := "") {
    if (x = "Down")
        return clicks.Push(pointer.Clone())
    if (x != "Up" && option != "Up")
        clicks.Push([x,y])
}
MouseMove(x,y,*) {
    global pointer := [x,y]
}
getRobloxPos(&x := unset,&y := unset,&w := unset,&h := unset) => (x:=0,y:=0,w:=800,h:=600)
UM14_RequireReadyFocus() => 0
UM14_RequireInputPoint(*) => 0
UM14_ConnectionSame(*) => stable
UM14_ConnectionOCR(identity,region,factor := 2,band := "",structured := false) {
    if rowFixture
        return factor = 1.5 ? {Words:[
            {Text:"EQUIP",BoundingRect:{x:100,y:80,w:75,h:24}},
            {Text:"SKINS",BoundingRect:{x:230,y:80,w:75,h:24}}]} : ""
    if !structured
        return echo
    words := [], y := 0
    for line in StrSplit(echo,"`n","`r") {
        x := 0
        for value in StrSplit(line," ") {
            words.Push({Text:value,BoundingRect:{x:x*factor,y:y*factor,w:StrLen(value)*5*factor,h:10*factor}})
            x += StrLen(value)*5+5
        }
        y += 20
    }
    return {Text:echo,Words:words}
}
UM14_ConnectionOCRStage(*) => "success"
LogToConsole(*) => 0
UM14_Viewport(w,h) => w >= 640 && h >= 480
UM14_Region(x,y,w,h,*) => {x:x,y:y,w:w,h:h}
UM14_SearchText(value,pace,direct := false) {
    global typed, directText
    typed++
    directText := direct
}
UM14_Fatal(message) {
    throw Error(message)
}
Need(ok,message) {
    if !ok
        throw Error(message)
}
try {
    identity := {x:0,y:0,w:800,h:600}
    bar := {status:"success",score:.9,x:140,y:110,w:29,h:17}
    close := {status:"success",score:.78,x:500,y:50}
    Need(UM14_InventoryMenuControls(close,bar,identity), "Compact close glyph remains valid with a strong search anchor")
    Need(IsObject(UM14_InventoryPair(identity)), "An already-open inventory is recognized on two observations")
    inventoryClose.score := .5
    Need(!UM14_InventoryPair(identity), "An unrelated panel cannot replace lobby evidence")
    inventoryClose.score := .78
    close.score := .5
    Need(!UM14_InventoryMenuControls(close,bar,identity), "Weak close glyph is not an inventory")
    close.score := .78, bar.score := .3
    Need(!UM14_InventoryMenuControls(close,bar,identity), "Close glyph alone is not an inventory")
    bar.score := .9
    compactQuery := UM14_InventorySearchRegion({status:"success",score:.9,x:16,y:115,w:19,h:11},identity)
    Need(IsObject(compactQuery) && compactQuery.w >= 190 && compactQuery.h >= 27,
        "A small magnifier match does not crop a full compact query")
    row := {x:0,y:0,w:800,h:600}
    label := {Text:"UNEQUIP",BoundingRect:{x:524,y:468,w:78,h:16}}
    skins := {Text:"SKINS",BoundingRect:{x:660,y:468,w:50,h:16}}
    button := UM14_LoadoutButton({Words:[label,skins]},row,1,600)
    Need(IsObject(button) && button.action = "UNEQUIP" && button.x = 563,
        "Minimum-size compact captions keep the exact UNEQUIP and SKINS pair")
    Need(button.stripX = 624, "The whole action row anchors the compact footer")
    Need(!UM14_LoadoutButton({Words:[label]},row,1,600), "A caption without its neighbor cannot authorize equipment")
    rowFixture := true
    Need(IsObject(UM14_ReadActionRow(identity,{x:400,y:400,w:400,h:200})),
        "A bounded second OCR scale recovers an exact action and SKINS pair")
    rowFixture := false
    footer := UM14_ReferenceFooter(identity,{x:559,y:444})
    Need(Abs(footer.x+4*footer.step-727) < 10, "Compact strip probes include the fifth slot")
    wideFooter := UM14_ReferenceFooter({w:1920,h:1009},{x:1266,y:730})
    Need(Abs(wideFooter.x-4*wideFooter.step-1160) < 5
        && Abs(wideFooter.x+4*wideFooter.step-1500) < 5,
        "Wide strip probes include both edge cards, independent of caption width")
    dockFooter := UM14_ReferenceFooter({w:1076,h:993},{y:729,stripX:840})
    Need(dockFooter.x-4*dockFooter.step < 695 && dockFooter.x+4*dockFooter.step > 980,
        "A tall docked client covers its leftmost and fifth card")
    Need(UM14_TitleMatches("Spotlight", "Spotlight Tech", true), "Compact currency HUD may obscure the title ending")
    Need(!UM14_TitleMatches("Spotlight", "Spotlight Tech"), "Wide windows still require the complete title")
    Need(!UM14_TitleMatches("Support", "Spotlight Tech", true) && !UM14_TitleMatches("Sniper", "Spotlight Tech", true),
        "Roles and different titles are not compact title fragments")
    echo := "Exclusive`nSpotlight Tech"
    Need(UM14_ReferenceSelectionText(identity,row,"Spotlight Tech"), "Full compact card caption is accepted with heading context")
    echo := "Advanced`nDJ Booth"
    Need(UM14_ReferenceSelectionText(identity,row,"DJ"), "The strategy's DJ name accepts the exact DJ Booth card caption")
    echo := "DJ"
    Need(UM14_ReferenceSelectionText(identity,row,"DJ"), "The matching search field retains the short DJ name")
    echo := "DJ Booth`nEvolved"
    Need(UM14_ReferenceSelectionText(identity,row,"DJ"), "A flattened text result retains separate caption and category word rows")
    echo := "Support"
    Need(!UM14_ReferenceSelectionText(identity,row,"Spotlight Tech"), "A role is not a card caption")
    echo := "Spotlight Tech`nSpotlight Tech"
    Need(!UM14_ReferenceSelectionText(identity,row,"Spotlight Tech"), "Duplicate caption observations remain ambiguous")
    echo := "Sniper"
    UM14_ReferenceInventorySearch("Sniper",bar,identity)
    Need(typed = 1 && directText && clicks.Length = 3 && clicks[1][1] > bar.x+50
        && clicks[2][1] = clicks[1][1] && clicks[3][2] = Round(600*409/1009),
        "Field focus is repeated safely, then exactly one result is selected")
    clicks := [], typed := 0
    translated := {x:120,y:80,w:800,h:600}
    UM14_ReferenceInventorySearch("Sniper",bar,translated)
    Need(clicks.Length = 3 && clicks[1][1] > 310 && clicks[3][2] = 80+Round(600*409/1009),
        "Input uses the exact physical origin of the pinned capture")
    clicks := [], typed := 0
    UM14_ReferenceInventorySearch("Sniper",bar,identity,true)
    Need(typed = 1 && !directText && clicks.Length = 3, "Retry uses paced entry without duplicate result clicks")
    clicks := [], typed := 0, stable := false, echo := "Sniper"
    refused := false
    try UM14_ReferenceInventorySearch("Sniper",bar,identity)
    catch
        refused := true
    Need(refused && !typed && !clicks.Length, "Changed client receives no search input")
    FileAppend("PASS: reference text entry, compact title/button rows, fifth slot and changed-client refusal`n","*")
    ExitApp(0)
} catch as e {
    FileAppend("FAIL: " e.Message "`n","**")
    ExitApp(1)
}
