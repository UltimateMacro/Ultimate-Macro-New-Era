; Read-only access to the Roblox UI instance tree for end-of-match reward checks.
; Offsets are loaded from the NoName Macro client layout when available and are
; rejected when they do not match the running Roblox build.
#Include "*i %A_LineFile%\..\JSON.ahk"

class TDSRobloxMemory {
    static ReadRewards() {
        result := {available: false, coins: 0, gems: 0, exp: 0, error: ""}
        processId := ProcessExist("RobloxPlayerBeta.exe")
        if !processId {
            result.error := "Roblox process is not running"
            return result
        }

        offsets := this.LoadOffsets()
        if !IsObject(offsets) {
            result.error := "Roblox memory offsets are unavailable"
            return result
        }

        processHandle := DllCall("Kernel32\OpenProcess", "UInt", 0x410, "Int", false, "UInt", processId, "Ptr")
        if !processHandle {
            result.error := "Unable to open Roblox for read-only memory access"
            return result
        }

        try {
            processVersion := this.GetProcessVersion(processHandle)
            if (processVersion != "" && offsets.Has("Roblox Version") && processVersion != offsets["Roblox Version"]) {
                ; Offsets version mismatch: automatically attempt to download the latest offsets from offsets.imtheo.lol
                layoutPath := A_AppData "\Ultimate_Macro\client_layout.txt"
                if (this.UpdateOffsetsOnline(layoutPath)) {
                    newOffsets := this.LoadOffsets(true)
                    if (IsObject(newOffsets))
                        offsets := newOffsets
                }
            }

            if (offsets.Has("Roblox Version") && processVersion != "" && processVersion != offsets["Roblox Version"]) {
                result.error := "Roblox build mismatch (Proc: " processVersion ", Off: " offsets["Roblox Version"] ")"
                return result
            }

            moduleBase := this.GetModuleBase(processId)
            if !moduleBase {
                result.error := "Roblox module base was not found"
                return result
            }

            if !offsets.Has("Offsets") {
                result.error := "Offsets section missing in layout file"
                return result
            }
            off := offsets["Offsets"]

            dm := this.GetDataModel(processHandle, moduleBase, off)
            if !dm {
                result.error := "Roblox DataModel was not found"
                return result
            }

            players := this.FindChild(processHandle, dm, "Players", off)
            if !players {
                result.error := "Players service was not found"
                return result
            }

            localPlayer := 0
            if (off.Has("Player") && off["Player"].Has("LocalPlayer"))
                localPlayer := this.ReadPtr(processHandle, players + off["Player"]["LocalPlayer"])
            if !this.IsUserPtr(localPlayer) {
                for pChild in this.ReadChildren(processHandle, players, off) {
                    if this.FindChild(processHandle, pChild, "PlayerGui", off) {
                        localPlayer := pChild
                        break
                    }
                }
            }
            if !this.IsUserPtr(localPlayer) {
                result.error := "LocalPlayer was not found"
                return result
            }

            playerGui := this.FindChild(processHandle, localPlayer, "PlayerGui", off)
            if !playerGui {
                result.error := "PlayerGui was not found"
                return result
            }

            textNodes := this.ReadGuiTexts(processHandle, playerGui, off)
            if (!IsObject(textNodes) || textNodes.Length == 0) {
                result.error := "Could not read text from PlayerGui tree"
                return result
            }

            foundRewards := false
            ; Pass 1: Combined label regex (e.g. "+2,479 Coins", "Coins: 2479")
            for node in textNodes {
                text := node.text
                mCoin := 0, mGem := 0, mExp := 0
                if RegExMatch(text, "i)(?:(?:\+\s*)?(\d[\d,]*)[ \t]*(?:coins?|corns?|colns?|gold)\b|(?:coins?|corns?|colns?|gold)[ \t]*[:=]?[ \t]*(?:\+\s*)?(\d[\d,]*))", &mCoin) {
                    valStr := mCoin[1] != "" ? mCoin[1] : mCoin[2]
                    value := Integer(StrReplace(valStr, ",", ""))
                    if (value > result.coins && !(value >= 1210 && value <= 1220)) {
                        result.coins := value
                        foundRewards := true
                    }
                }
                if RegExMatch(text, "i)(?:(?:\+\s*)?(\d[\d,]*)[ \t]*gems?\b|gems?[ \t]*[:=]?[ \t]*(?:\+\s*)?(\d[\d,]*))", &mGem) {
                    valStr := mGem[1] != "" ? mGem[1] : mGem[2]
                    value := Integer(StrReplace(valStr, ",", ""))
                    if (value > result.gems && value <= 500) {
                        result.gems := value
                        foundRewards := true
                    }
                }
                if RegExMatch(text, "i)(?:(?:\+\s*)?(\d[\d,]*)[ \t]*(?:exp|xp)\b)", &mExp) {
                    value := Integer(StrReplace(mExp[1], ",", ""))
                    if (value > result.exp && value >= 50 && value <= 2500) {
                        result.exp := value
                        foundRewards := true
                    }
                }
            }

            ; Pass 2: Separate labels (amount in node.text, unit in node.name or parentName)
            for node in textNodes {
                text := node.text
                context := node.name . " " . node.parentName
                mNum := 0
                if RegExMatch(text, "^\+?\s*([\d,]+)$", &mNum) {
                    numVal := Integer(StrReplace(mNum[1], ",", ""))
                    if (result.coins == 0 && RegExMatch(context, "i)\b(?:coin|gold)\b") && !(numVal >= 1210 && numVal <= 1220)) {
                        result.coins := numVal
                        foundRewards := true
                    }
                    if (result.gems == 0 && RegExMatch(context, "i)\bgems?\b") && numVal <= 500) {
                        result.gems := numVal
                        foundRewards := true
                    }
                    if (result.exp == 0 && RegExMatch(context, "i)\b(?:exp|xp)\b") && numVal >= 50 && numVal <= 2500) {
                        result.exp := numVal
                        foundRewards := true
                    }
                }
            }

            if (!foundRewards && !this.HasResultHeader(textNodes)) {
                result.error := "Result screen not present in PlayerGui"
                return result
            }

            result.available := true
            return result
        } catch as err {
            result.error := err.Message . " (" . err.Extra . " at line " . err.Line . " in " . err.What . ")"
            return result
        } finally {
            DllCall("Kernel32\CloseHandle", "Ptr", processHandle)
        }
    }

    static LoadOffsets(forceReload := false) {
        static cachedPath := "", cachedModified := "", cachedOffsets := 0
        appDataLayout := A_AppData "\Ultimate_Macro\client_layout.txt"
        nonameLayout := A_AppData "\TowerDefenseMacro\current\runtime\client_layout.txt"
        bundledLayout := A_WorkingDir "\Resources\client_layout.txt"

        layoutPath := FileExist(appDataLayout) ? appDataLayout : (FileExist(nonameLayout) ? nonameLayout : bundledLayout)
        if (!FileExist(layoutPath)) {
            ; If no offsets file exists at all, try downloading it online
            if this.UpdateOffsetsOnline(appDataLayout)
                layoutPath := appDataLayout
            else
                return 0
        }

        modified := FileGetTime(layoutPath, "M")
        if (!forceReload && layoutPath = cachedPath && modified = cachedModified && IsObject(cachedOffsets))
            return cachedOffsets

        try parsed := JSON.parse(FileRead(layoutPath, "UTF-8"))
        catch
            return 0

        if (!parsed.Has("Roblox Version") || !parsed.Has("Offsets"))
            return 0
        cachedPath := layoutPath
        cachedModified := modified
        cachedOffsets := parsed
        return cachedOffsets
    }

    static UpdateOffsetsOnline(targetPath) {
        try {
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("GET", "https://offsets.imtheo.lol/offsets.json", false)
            whr.SetTimeouts(2000, 3000, 3000, 5000)
            whr.Send()
            if (whr.Status = 200) {
                text := whr.ResponseText
                if (InStr(text, "Roblox Version") && InStr(text, "Offsets")) {
                    SplitPath(targetPath, , &outDir)
                    if (outDir != "" && !DirExist(outDir))
                        DirCreate(outDir)
                    if FileExist(targetPath)
                        FileDelete(targetPath)
                    FileAppend(text, targetPath, "UTF-8")
                    return true
                }
            }
        } catch {
        }
        return false
    }

    static GetProcessVersion(processHandle) {
        pathBuffer := Buffer(2048, 0)
        charCount := 1024
        if !DllCall("Kernel32\QueryFullProcessImageNameW", "Ptr", processHandle, "UInt", 0, "Ptr", pathBuffer.Ptr, "UInt*", &charCount, "Int")
            return ""
        imagePath := StrGet(pathBuffer, charCount, "UTF-16")
        return RegExMatch(imagePath, "i)(version-[a-f0-9]{16})", &mVersion) ? StrLower(mVersion[1]) : ""
    }

    static GetModuleBase(processId) {
        snapshot := DllCall("Kernel32\CreateToolhelp32Snapshot", "UInt", 0x18, "UInt", processId, "Ptr")
        if (!snapshot || snapshot = -1)
            return 0

        try {
            entry := Buffer(1080, 0)
            NumPut("UInt", entry.Size, entry, 0)
            if !DllCall("Kernel32\Module32FirstW", "Ptr", snapshot, "Ptr", entry.Ptr, "Int")
                return 0
            loop {
                moduleName := StrGet(entry.Ptr + 48, 256, "UTF-16")
                if (StrLower(moduleName) = "robloxplayerbeta.exe")
                    return NumGet(entry, 24, "Ptr")
                NumPut("UInt", entry.Size, entry, 0)
                if !DllCall("Kernel32\Module32NextW", "Ptr", snapshot, "Ptr", entry.Ptr, "Int")
                    break
            }
            return 0
        } finally {
            DllCall("Kernel32\CloseHandle", "Ptr", snapshot)
        }
    }

    static GetDataModel(processHandle, moduleBase, offsets) {
        if offsets.Has("FakeDataModel") {
            fakeOffsets := offsets["FakeDataModel"]
            fake := this.ReadPtr(processHandle, moduleBase + fakeOffsets["Pointer"])
            if this.IsUserPtr(fake) {
                dm := this.ReadPtr(processHandle, fake + fakeOffsets["RealDataModel"])
                if this.IsUserPtr(dm)
                    return dm
            }
        }

        if offsets.Has("VisualEngine") {
            visualOffsets := offsets["VisualEngine"]
            visual := this.ReadPtr(processHandle, moduleBase + visualOffsets["Pointer"])
            if this.IsUserPtr(visual) {
                fake := this.ReadPtr(processHandle, visual + visualOffsets["FakeDataModel"])
                if this.IsUserPtr(fake) {
                    realDmOffset := offsets.Has("FakeDataModel") ? offsets["FakeDataModel"]["RealDataModel"] : 504
                    dm := this.ReadPtr(processHandle, fake + realDmOffset)
                    if this.IsUserPtr(dm)
                        return dm
                }
            }
        }
        return 0
    }

    static FindChild(processHandle, parent, targetName, offsets) {
        for child in this.ReadChildren(processHandle, parent, offsets) {
            if (StrLower(this.ReadInstanceName(processHandle, child, offsets)) = StrLower(targetName))
                return child
        }
        return 0
    }

    static ReadGuiTexts(processHandle, root, offsets) {
        texts := []
        visited := Map()
        stack := [{address: root, depth: 0, parentName: ""}]
        nodesRead := 0
        instanceOffsets := offsets.Has("Instance") ? offsets["Instance"] : Map()
        guiTextOffset := (offsets.Has("GuiObject") && offsets["GuiObject"].Has("Text")) ? offsets["GuiObject"]["Text"] : 3640

        while (stack.Length && nodesRead < 15000) {
            item := stack.Pop()
            address := item.address
            if (item.depth > 24 || !this.IsUserPtr(address) || visited.Has(address))
                continue
            visited[address] := true
            nodesRead += 1

            nodeName := this.ReadInstanceName(processHandle, address, offsets)
            className := this.ReadClassName(processHandle, address, offsets)
            if (className = "TextLabel" || className = "TextButton" || className = "TextBox" || className = "") {
                text := this.ReadRobloxString(processHandle, address + guiTextOffset)
                if (text = "") {
                    textPtr := this.ReadPtr(processHandle, address + guiTextOffset)
                    if this.IsUserPtr(textPtr)
                        text := this.ReadRobloxString(processHandle, textPtr)
                }
                if (text != "")
                    texts.Push({text: text, name: nodeName, parentName: item.parentName})
            }

            children := this.ReadChildren(processHandle, address, offsets)
            for child in children
                stack.Push({address: child, depth: item.depth + 1, parentName: nodeName})
        }
        return texts
    }

    static ReadChildren(processHandle, instance, offsets) {
        if !offsets.Has("Instance")
            return []
        instanceOffsets := offsets["Instance"]
        vectorAddress := instance + instanceOffsets["ChildrenStart"]
        endOffset := instanceOffsets["ChildrenEnd"]
        start := this.ReadPtr(processHandle, vectorAddress)
        finish := this.ReadPtr(processHandle, vectorAddress + endOffset)
        children := this.ReadChildrenSpan(processHandle, start, finish)
        if (children.Length)
            return children

        vector := start
        if this.IsUserPtr(vector) {
            start := this.ReadPtr(processHandle, vector)
            finish := this.ReadPtr(processHandle, vector + endOffset)
            return this.ReadChildrenSpan(processHandle, start, finish)
        }
        return []
    }

    static ReadChildrenSpan(processHandle, start, finish) {
        if (!this.IsUserPtr(start) || !this.IsUserPtr(finish) || finish <= start)
            return []
        byteCount := finish - start
        if (byteCount > 65536)
            return []

        step := (Mod(byteCount, 16) == 0 && byteCount >= 16) ? 16 : A_PtrSize
        count := byteCount // step
        if (count < 1 || count > 4096)
            return []

        memBuf := Buffer(byteCount, 0)
        bytesRead := 0
        if !DllCall("Kernel32\ReadProcessMemory", "Ptr", processHandle, "Ptr", start, "Ptr", memBuf.Ptr, "UPtr", byteCount, "UPtr*", &bytesRead, "Int") || bytesRead != byteCount
            return []

        children := []
        loop count {
            child := NumGet(memBuf, (A_Index - 1) * step, "Ptr")
            if this.IsUserPtr(child)
                children.Push(child)
        }
        return children
    }

    static ReadInstanceName(processHandle, instance, offsets) {
        if !offsets.Has("Instance")
            return ""
        instanceOffsets := offsets["Instance"]
        nameObj := instance + instanceOffsets["NameContainer"]
        name := this.ReadRobloxString(processHandle, nameObj)
        if (name != "")
            return name

        container := this.ReadPtr(processHandle, nameObj)
        if this.IsUserPtr(container) {
            nameObj := container + instanceOffsets["Name"]
            name := this.ReadRobloxString(processHandle, nameObj)
            if (name != "")
                return name
            namePtr := this.ReadPtr(processHandle, nameObj)
            if this.IsUserPtr(namePtr)
                return this.ReadRobloxString(processHandle, namePtr)
        }
        return ""
    }

    static ReadClassName(processHandle, instance, offsets) {
        if !offsets.Has("Instance")
            return ""
        instanceOffsets := offsets["Instance"]
        descriptor := this.ReadPtr(processHandle, instance + instanceOffsets["ClassDescriptor"])
        if !this.IsUserPtr(descriptor)
            return ""
        classNameObj := descriptor + instanceOffsets["ClassName"]
        name := this.ReadRobloxString(processHandle, classNameObj)
        if (name != "")
            return name
        namePtr := this.ReadPtr(processHandle, classNameObj)
        if this.IsUserPtr(namePtr)
            return this.ReadRobloxString(processHandle, namePtr)
        return ""
    }

    static ReadRobloxString(processHandle, stringObject) {
        if !this.IsUserPtr(stringObject)
            return ""
        length := this.ReadInt(processHandle, stringObject + 0x10)
        if (length < 1 || length > 2048)
            return ""

        dataAddress := length > 15 ? this.ReadPtr(processHandle, stringObject) : stringObject
        if !this.IsUserPtr(dataAddress)
            return ""
        memBuf := Buffer(length + 1, 0)
        bytesRead := 0
        if !DllCall("Kernel32\ReadProcessMemory", "Ptr", processHandle, "Ptr", dataAddress, "Ptr", memBuf.Ptr, "UPtr", length, "UPtr*", &bytesRead, "Int") || bytesRead != length
            return ""
        return StrGet(memBuf, length, "UTF-8")
    }

    static ReadPtr(processHandle, address) {
        if !this.IsUserPtr(address)
            return 0
        memBuf := Buffer(A_PtrSize, 0)
        bytesRead := 0
        if !DllCall("Kernel32\ReadProcessMemory", "Ptr", processHandle, "Ptr", address, "Ptr", memBuf.Ptr, "UPtr", A_PtrSize, "UPtr*", &bytesRead, "Int") || bytesRead != A_PtrSize
            return 0
        return NumGet(memBuf, 0, "Ptr")
    }

    static ReadInt(processHandle, address) {
        if !this.IsUserPtr(address)
            return 0
        memBuf := Buffer(4, 0)
        bytesRead := 0
        if !DllCall("Kernel32\ReadProcessMemory", "Ptr", processHandle, "Ptr", address, "Ptr", memBuf.Ptr, "UPtr", 4, "UPtr*", &bytesRead, "Int") || bytesRead != 4
            return 0
        return NumGet(memBuf, 0, "Int")
    }

    static IsUserPtr(address) => address >= 0x10000 && address <= 0x00007FFFFFFFFFFF

    static HasResultHeader(nodes) {
        for item in nodes {
            text := IsObject(item) ? item.text : item
            name := IsObject(item) ? item.name : ""
            if RegExMatch(text, "i)\btriumph\b|\byou\s+lost\b|\bdefeat(?:ed)?\b") || RegExMatch(name, "i)\btriumph\b|\bdefeat\b|\bgameover\b")
                return true
        }
        return false
    }
}
