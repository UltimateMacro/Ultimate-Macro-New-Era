; The only bridge into the legacy macro. Local buttons and F1/F2 keep using
; their original handlers. Dashboard pairing never calls this adapter.
LegacyConnectionsStart(root, version, remoteVersion := "") {
    DashboardMatch.root := root
    DashboardHealth.output := root "\dashboard-health.json"
    DashboardActivity.dir := root "\Dashboard-Activity-141"
    DashboardRemote.cooldownFile := root "\Dashboard-cooldown.ini"
    UltBot.Init(root, remoteVersion != "" ? remoteVersion : version, LegacyUltBotCommand)
    Dashboard.Init(root, version)
    OnExit(LegacyConnectionsStop)
    UltBot.Restore()
    Dashboard.Restore()
    DashboardRemote.RestoreCooldown()
}

LegacyConnectionsStop(*) {
    UltBot.Stop()
    DashboardActivity.Stop()
    DashboardRemote.Stop()
    Dashboard.Stop()
}

LegacyUltBotCommand(op, perform) {
    switch op {
        case "status":
            file := RunningStrategy ? IniRead(StateFile, "State", "Strategy", "") : Strategy1Path
            SplitPath(file, , , , &name)
            return Map("running", RunningStrategy ? JSON.true : JSON.false
                , "strategy", SubStr(name, 1, 140)
                , "runtime", RunningStrategy && AutorunStartTime > 0 ? FormatRuntime(AutorunStartTime) : "")
        case "start":
            if (RestartLock || RunningStrategy || Recording || MacroRecording || !IsSet(Strategy1Ctrl))
                return Map("error", "The macro is busy. Stop the current run or recording first.")
            file := Trim(Strategy1Ctrl.Value)
            if !RegExMatch(file, "i)\.strat\z") || !FileExist(file) || InStr(FileExist(file), "D")
                return Map("error", "Choose a valid strategy in the macro first.")
            if (IniRead(StateFile, "State", "IsFirstLaunch", "1") = "1")
                return Map("error", "Start the first run locally so you can complete the setup prompts.")
            if perform
                DashboardRemote.StartFromRemote()
            return Map("message", "Start requested using the selected strategy and existing settings.")
        case "stop":
            if !RunningStrategy || RestartLock
                return Map("error", "No strategy is running.")
            if perform
                StopStrategy()
            return Map("message", "Stop requested. The macro will reload and reconnect.")
        default:
            return Map("error", "Unsupported command.")
    }
}
