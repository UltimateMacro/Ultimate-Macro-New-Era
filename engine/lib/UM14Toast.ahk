; Isolate TDS's bright green success toast from the map and other HUD text.
UM14_MaskGreenToast(data, stride, width, height) {
    if (!data || !IsInteger(width) || !IsInteger(height) || width < 1 || height < 1
        || width*height > 1000000 || Abs(stride) < width*4)
        return 0
    count := 0
    Loop height {
        p := data+(A_Index-1)*stride
        Loop width {
            color := NumGet(p,0,"UInt")
            g := (color>>8)&255, other := Max((color>>16)&255,color&255)
            ink := g >= 142 && other <= 78 && g-other >= 105
            if ink
                count++
            NumPut("UInt",ink ? 0xFF000000 : 0xFFFFFFFF,p)
            p += 4
        }
    }
    return (count >= 8 && count <= width*height*.38) ? count : 0
}

UM14_MaskGreenToastGdi(bitmap, w, h) {
    if Gdip_LockBits(bitmap,0,0,w,h,&stride,&scan,&bits)
        return false
    try return UM14_MaskGreenToast(scan,stride,w,h)
    finally Gdip_UnlockBits(bitmap,&bits)
}
