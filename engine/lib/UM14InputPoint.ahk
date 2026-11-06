UM14_RequireInputPoint(identity, x, y, action := "Inventory") {
    if !UM14_ConnectionSame(identity)
        UM14_Fatal(action " input stopped because Roblox changed or lost focus.")
    if (x < 0 || y < 0 || x >= identity.w || y >= identity.h)
        UM14_Fatal(action " input point is outside the verified Roblox client.")
    point := (identity.x+x) & 0xFFFFFFFF | ((identity.y+y) << 32)
    under := DllCall("WindowFromPoint","Int64",point,"Ptr")
    root := under ? DllCall("GetAncestor","Ptr",under,"UInt",2,"Ptr") : 0
    if !UM14_InputRootMatches(root ? root : under,identity.root)
        UM14_Fatal(action " input is covered by another window or pinned overlay. Move or close it, then retry. No click was sent.")
}
