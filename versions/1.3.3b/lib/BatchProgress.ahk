
BatchGoal(settings, state) {
    currency := IniRead(settings, "FarmingGoal", "Currency", "")
    if IniRead(settings, "FarmingGoal", "Enabled", currency != "") != 1
        return false
    target := IniRead(settings, "FarmingGoal", "Target", 0)
    if !(currency ~= "i)^(Coins|Gems)$") || !IsInteger(target) || target < 1
        return false
    earned := IniRead(state, "State", currency, 0) + 0
    return {currency: currency, target: target + 0, earned: earned, reached: earned >= target}
}

BatchXPSelection(settings) {
    selected := IniRead(settings, "TowerXP", "Selected", "")
    for definition in TowerXPDefinitions() {
        if definition.name = selected
            return definition
    }
    return false
}

BatchXPActiveTower(settings) {
    return IniRead(settings, "TowerXP", "Cycle", 0) = 1 ? TowerXPNext(settings) : BatchXPSelection(settings)
}

BatchXPReached(settings) {
    if IniRead(settings, "TowerXP", "Enabled", 0) = 1 && IniRead(settings, "TowerXP", "Cycle", 0) = 1
        return !BatchXPActiveTower(settings)
    definition := BatchXPSelection(settings)
    return IniRead(settings, "TowerXP", "Enabled", 0) = 1 && definition
        && TowerXPSavedProgress(settings, definition).level >= IniRead(settings, TowerXPSectionName(definition.name), "Target", 20)
}

BatchFinishMatch(settings, state) {
    goal := BatchGoal(settings, state)
    if (goal && goal.reached || BatchXPReached(settings) || IniRead(state, "Batch", "StopAfter", 0) = 1) {
        IniWrite(0, state, "State", "Running")
        IniWrite(0, state, "Batch", "StopAfter")
    }
}

