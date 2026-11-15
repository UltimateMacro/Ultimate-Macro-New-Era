; Original hidden 1.3.3a form models; the 1.4 Record page mirrors these.
; tab 2 - RECORD ===========================

MainGui.SetFont("s10 w400 c3A86FF", "Segoe UI")
global Tab2_Title := MainGui.Add("Text", "x30 y95  w200 h22 Hidden", "Configuration")
global Tab2_Line1 := MainGui.Add("Progress", "x30 y118 w640 h1  Hidden Background333333", 0)

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab2_Lbl1 := MainGui.Add("Text", "x30 y145 w80 h20 Hidden", "Map:")
MainGui.SetFont("s9 w400 cFFFFFF")
global RecMapsD := MainGui.Add("DropDownList", "x80 y142 w220 Hidden vRecMaps", [ ; WARNING: These are all the supported maps for this macro. If a map is not listed here, it is unsupported
    "Abandoned City", "Area 52", "Autumn Falling", 
    "Badlands II", "Black Spot Exchange", "Candy Valley", "Cataclysm", "Chess Board", 
    "Construction Crazy", "Coral Deep", "Crossroads", "Crystal Cave", 
    "Cyber City", "Dead Ahead", "Derelict Outpost", "Deserted Village", "Dusty Bridges", 
    "Enchanted Forest", "Farm Lands", "Forest Camp", "Forgetten Docks", "Four Seasons", 
    "Fungi Island", "Grass Isle", "Happy Home of Robloxia", "Harbor", "Honey Valley", 
    "Hot Spot", "Iceville", "Infernal Abyss", "Lay By", "Lighthaos", "Marshlands", "Mason Arch", "Medieval Times", "Meltdown", 
    "Midnight Issue", "Moon Base", "Musaceae Kingdom", "Necropolis", "Nether", "Night Station", 
    "Northern Lights", "Outskirts Commune", "Pier Pressure", "Pizza Party", "Polluted Wasteland II", 
    "Portland", "Retro Crossroads", "Retro Lighthouse", "Retro Rocket Arena", "Retro Stained Temple", 
    "Retro The Heights", "Retro Zone", "Rocket Arena", "Ruby Escort", "Sacred Mountains", 
    "Sky Islands", "Simplicity", "Space City", "Spring Fever", "Stained Temple", "Sugar Rush", 
    "The Heavens", "The Heights", "Toyboard", "Tropical Industries", "Tropical Isles", "U-Turn", 
    "Unknown Garden", "Winter Abyss", "Winter Bridges", "Winter Stronghold", "Wrecked Battlefield", 
    "Wrecked Battlefield II", "Wretched Front"
])

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab2_Lbl2 := MainGui.Add("Text", "x320 y145 w80 h20 Hidden", "Mode:")
MainGui.SetFont("s9 w400 cFFFFFF")
global RecDiffCtrl := MainGui.Add("DropDownList", "x380 y142 w220 Hidden vRecDifficulty", [
    "Easy", "Casual", "Intermediate", "Molten", "Fallen", "Frost", 
    "Hardcore", "Voidcore", "Pizza Party", "Badlands II", "Polluted Wasteland II"
])

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab2_Lbl3 := MainGui.Add("Text", "x30 y235 w80 h20 Hidden", "Modifiers:")
MainGui.SetFont("s9 w400 c000000")

global RecModifiersCtrl := MainGui.Add("ListBox", "x110 y232 w220 h200 Multi Hidden vRecModifiers", [
    "Broke", "Exploding", "Flying", "Fog", "Glass", 
    "Healthy", "Hidden", "Inflation", "Jailed", "Limitation", 
    "Committed", "Quarantine", "Speedy"
])

MainGui.SetFont("s9 w400 cAAAAAA", "Segoe UI")
global Tab2_Info2 := MainGui.Add("Text", "x20 w60 y275 BackgroundTrans Hidden", "Hold CTRL to deselect/select multiple modifiers.")

MainGui.SetFont("s9 w400 cAAAAAA")
global Tab2_Lbl4 := MainGui.Add("Text", "x30 y185 w80 h20 Hidden", "Towers:")
MainGui.SetFont("s9 w400 c000000")
global RecTowersCtrl := MainGui.Add("Edit", "x80 y182 w220 h22 Hidden vRecRequiredTowers", requiredTowers)

MainGui.SetFont("s9 w400 cAAAAAA", "Segoe UI")
global Tab2_Info1 := MainGui.Add("Text", "x320 y173 BackgroundTrans Hidden", "Enter towers for your strategy using comma after every tower.`nMinigunner, Ranger, Commander, DJ, Military Base for example.`nType G Whatever if the tower you using NEEDS to be golden.")

MainGui.Add("Progress", "x360 y232 w320 h1 Hidden Background333333 vTab2_Line2", 0)
global Tab2_Line2 := MainGui["Tab2_Line2"]

MainGui.SetFont("s9 w400 cFFFFFF", "Segoe UI")
global RecAutoChainCtrl := MainGui.Add("Checkbox", "x360 y255 Hidden vRecAutoChain Checked" (autoChain="ON"?1:0), "Use Call of Arms")
global RecAutoCaravanCtrl := MainGui.Add("Checkbox", "x490 y255 Hidden vRecAutoCaravan Checked" (autoCaravan="ON"?1:0), "Use Support Caravan")
global RecAutoDropCtrl := MainGui.Add("Checkbox", "x360 y275 Hidden vRecAutoDropTheBeat Checked" (autoDropTheBeat="ON"?1:0), "Use Drop the Beat")

MainGui.Add("Progress", "x360 y300 w320 h1 Hidden Background333333 vTab2_Line3", 0)
global Tab2_Line3 := MainGui["Tab2_Line3"]
global RecAutoSkipCtrl := MainGui.Add("Checkbox", "x360 y315 h20 Hidden vRecAutoSkip", "Auto Skip Waves")
global RecAbilitySpamCtrl := MainGui.Add("Checkbox", "x490 y315 h20 Hidden vRecAbilitySpam", "Abilities Spam")
global Tab2_Info := MainGui.Add("Link", "x360 y360 w320 h100 Hidden", "
(
There you can create your own strategy and save it into a file. Watch the tutorial here: <a href="https://www.youtube.com/watch?v=j8Y5qHBaYOs&feature=youtu.be">https://www.youtube.com/watch?v=j8Y5qHBaYOs&feature=youtu.be</a>. I recommend using the timescale ticket when recording complex strategies.
)")
MW.Bind(RecAutoSkipCtrl, "Click", RecordToggleAutoskip)

global RecMoveCtrl := MainGui.Add("Checkbox", "x30 y452 w60 h20 Hidden vRecMoveEnabled Checked" (MoveEnabled?1:0), "Move")
MainGui.SetFont("s9 w400 cAAAAAA")
global DIRECTIONTEXTCtrl := MainGui.Add("Text", "x100 y452 w45 Hidden", "Direction")
MainGui.SetFont("s9 w400 cFFFFFF")
global RecMoveDirCtrl := MainGui.Add("DropDownList", "x160 y450 w45 Hidden Choose1 vRecMoveDirection", ["W", "A", "S", "D"])
MainGui.SetFont("s9 w400 cAAAAAA")
global Tab2_Txt4 := MainGui.Add("Text", "x220 y452 Hidden", "Duration (ms):")
MainGui.SetFont("s9 w400 c000000")
global RecMoveDurCtrl := MainGui.Add("Edit", "x310 y450 w50 h22 Hidden vRecMoveDuration", 1000)

MainGui.SetFont("s11 w400 cFFFFFF", "Segoe UI")
global Tab2_Btn1 := MainGui.Add("Text", "x30  y500 w300 h40 Center Background0e0e0f +Border 0x200 Hidden", "Start Recording")
MW.Bind(Tab2_Btn1, "Click", RecorderStart)
MainGui.SetFont("s11 w400 c808080", "Segoe UI")
global Tab2_Btn2 := MainGui.Add("Text", "x340 y500 w330 h40 Center Background0e0e0f +Border 0x200 Hidden", "Stop")
MW.Bind(Tab2_Btn2, "Click", StopRecord)

HoverEffect.Push(Tab2_Btn1)
