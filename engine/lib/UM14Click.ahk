; Keep mouse-down long enough for a low-FPS client, but only after verifying
; the control again under the stationary pointer.
UM14_HeldClick(identity, x, y, action, dwell := 140, verify := false) {
    UM14_RequireInputPoint(identity, x, y, action)
    MouseMove(x, y, 0)
    Sleep(100)
    if (IsObject(verify) && !verify.Call())
        return false
    UM14_RequireInputPoint(identity, x, y, action)
    MouseGetPos(&cx, &cy)
    if (Abs(cx-x) > 2 || Abs(cy-y) > 2)
        UM14_Fatal(action " input stopped because the pointer moved before the click.")
    Click("Down")
    try Sleep(dwell)
    finally Click("Up")
    return true
}

UM14_ButtonStillAt(original, current, tolerance := 8) {
    return IsObject(current) && Abs(original.x-current.x) <= tolerance && Abs(original.y-current.y) <= tolerance
}
