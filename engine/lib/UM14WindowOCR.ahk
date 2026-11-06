; Target-HWND OCR for input-transparent compositor overlays. GPLv3 bridge.
; Reuses the bundled source-owned OCR/WinRT implementation, not PrintWindow,
; a title lookup, another process, a desktop screenshot or downloaded code.
#Include "%A_LineFile%\..\UM14Toast.ahk"

UM14_TargetWindowOCR(expected, region, factor, greenToast := false) {
    if (!UM14_ConnectionSame(expected))
        throw Error("Selected game changed before target capture")
    bitmap := UM14_WindowOCR.Capture(expected.hwnd)
    try {
        x := expected.x+region.x-bitmap.x, y := expected.y+region.y-bitmap.y
        if (x < 0 || y < 0 || region.w < 1 || region.h < 1
            || x+region.w > bitmap.w || y+region.h > bitmap.h)
            throw Error("Target capture does not contain the exact client crop")
        width := bitmap.w, height := bitmap.h
        transformed := UM14_WindowOCR.TransformSoftwareBitmap(bitmap,&width,&height,
            factor,0,0,x,y,region.w,region.h)
        try {
            if (greenToast && !UM14_WindowOCR.MaskToast(transformed,width,height))
                return false
            result := UM14_WindowOCR(transformed,{lang:"en-US",scale:1,grayscale:1})
            if (!UM14_ConnectionSame(expected))
                throw Error("Selected game changed during target capture")
            return result ; Raw scaled-CROP words, not FromWindow's client normalization.
        } finally {
            try UM14_WindowOCR.CloseIClosable(transformed)
        }
    } finally {
        try UM14_WindowOCR.CloseIClosable(bitmap)
    }
}

class UM14_WindowOCR extends OCR {
    static MaskToast(bitmap, w, h) {
        ComCall(6,bitmap,"Int*",&format:=0) ; BitmapPixelFormat
        if (format != 87 && format != 30) ; Bgra8 / Rgba8; green channel matches
            return false
        ComCall(15,bitmap,"Int",1,"Ptr*",locked:=ComValue(13,0)) ; ReadWrite
        plane := Buffer(16,0)
        ComCall(7,locked,"Int",0,"Ptr",plane) ; GetPlaneDescription
        start := NumGet(plane,0,"Int"), stride := NumGet(plane,12,"Int")
        if (start < 0 || NumGet(plane,4,"Int") != w || NumGet(plane,8,"Int") != h || stride < w*4)
            return false
        memory := ComObjQuery(locked,"{fbc4dd2a-245b-11e4-af98-689423260cf8}")
        ComCall(6,memory,"Ptr*",ref:=ComValue(13,0))
        access := ComObjQuery(ref,"{5b0d3235-4dba-4d44-865e-8f1d0e4fd04d}")
        ComCall(3,access,"Ptr*",&data:=0,"UInt*",&size:=0)
        try return start+(h-1)*stride+w*4 <= size && data && UM14_MaskGreenToast(data+start,stride,w,h)
        finally {
            access := "", ref := "", memory := "", locked := ""
        }
    }

    static TransformSoftwareBitmap(bitmap,&outputWidth,&outputHeight,scale := 1,
        rotate := 0,flip := 0,x := 0,y := 0,width := 0,height := 0) {
        if (rotate || flip || !IsNumber(scale) || scale < .125 || scale > 4)
            throw Error("Unsupported target bitmap transform")
        stream := this.SoftwareBitmapToRandomAccessStream(bitmap)
        try {
            ComCall(this.Vtbl_GetDecoder.png,this.BitmapDecoderStatics,"Ptr",decoderIID := Buffer(16))
            ComCall(15,this.BitmapDecoderStatics,"Ptr",decoderIID,"Ptr",stream,"Ptr*",decoder := ComValue(13,0))
            this.WaitForAsync(&decoder)
            frame := ComObjQuery(decoder,"{72A49A1C-8081-438D-91BC-94ECFC8185C6}")
            softwareFrame := ComObjQuery(decoder,"{FE287C9A-420C-4963-87AD-691436E08383}")
            ComCall(12,frame,"UInt*",&fullWidth := 0)
            ComCall(13,frame,"UInt*",&fullHeight := 0)
            width := width ? width : fullWidth, height := height ? height : fullHeight
            if (x < 0 || y < 0 || width < 1 || height < 1 || x+width > fullWidth || y+height > fullHeight)
                throw Error("Target bitmap crop is outside the captured window")
            outputWidth := Max(1,Floor(width*scale)),outputHeight := Max(1,Floor(height*scale))
            if (Max(outputWidth,outputHeight) > 2500)
                throw Error("Target bitmap crop exceeds OCR budget")
            transform := this.CreateClass("Windows.Graphics.Imaging.BitmapTransform")
            ; WinRT scales BEFORE cropping. Scale the WHOLE decoded texture,
            ; then select the scaled ROI. Cropped dimensions here lose text.
            ComCall(7,transform,"UInt",Max(1,Floor(fullWidth*scale)))
            ComCall(9,transform,"UInt",Max(1,Floor(fullHeight*scale)))
            bounds := Buffer(16,0)
            NumPut("UInt",Floor(x*scale),"UInt",Floor(y*scale),"UInt",outputWidth,"UInt",outputHeight,bounds)
            ComCall(17,transform,"Ptr",bounds)
            ComCall(8,frame,"UInt*",&pixelFormat := 0)
            ComCall(9,frame,"UInt*",&alpha := 0)
            ComCall(8,softwareFrame,"UInt",pixelFormat,"UInt",alpha,"Ptr",transform,"UInt",0,"UInt",0,"Ptr*",result := ComValue(13,0))
            this.WaitForAsync(&result)
            return result
        } finally {
            try this.CloseIClosable(stream)
        }
    }

    static WaitForAsync(&obj) {
        info := ComObjQuery(obj, this.IID_IAsyncInfo)
        deadline := A_TickCount+2000
        try {
            Loop {
                ComCall(7, info, "UInt*", &status := 0)
                if (status != 0) {
                    if (status != 1)
                        throw Error("Target capture asynchronous operation failed")
                    break
                }
                if (A_TickCount >= deadline) {
                    try ComCall(9, info) ; IAsyncInfo.Cancel; never adopt late data.
                    throw Error("Target capture asynchronous deadline exceeded")
                }
                Sleep(10)
            }
            ComCall(8, obj, "Ptr*", value := this.IBase())
            obj := value
        } finally {
            try ComCall(10, info) ; IAsyncInfo.Close, including failed operations.
        }
    }

    static Capture(hwnd) {
        static initialized := false, device := 0, context := 0, direct := 0, pools := 0, interop := 0, itemIID := 0
        if (!initialized) {
            DllCall("LoadLibrary", "Str", "D3D11")
            if (DllCall("D3D11\D3D11CreateDevice", "Ptr", 0, "Int", 1, "Ptr", 0, "UInt", 0x20,
                "Ptr", 0, "UInt", 0, "UInt", 7, "Ptr*", device := ComValue(13,0), "Ptr*", 0,
                "Ptr*", context := ComValue(13,0), "Int") != 0)
                throw Error("Target capture device unavailable")
            dxgi := ComObjQuery(device, "{54ec77fa-1377-44e6-8c32-88fd5f44c84c}")
            if (DllCall("D3D11\CreateDirect3D11DeviceFromDXGIDevice", "Ptr", dxgi,
                "Ptr*", graphics := ComValue(13,0), "Int") != 0)
                throw Error("Target capture graphics bridge unavailable")
            direct := ComObjQuery(graphics, "{A37624AB-8D5F-4650-9D3E-9EAE3D9BC670}")
            pools := this.CreateClass("Windows.Graphics.Capture.Direct3D11CaptureFramePool", "{7784056a-67aa-4d53-ae54-1088d5a8ca21}")
            statics := this.CreateClass("Windows.Graphics.Capture.GraphicsCaptureItem", "{A87EBEA5-457C-5788-AB47-0CF1D3637E74}")
            interop := ComObjQuery(statics, "{3628E81B-3CAC-4C60-B7F4-23CE0E0C3356}")
            itemIID := this.CLSIDFromString("{79c3f95b-31f7-4ec2-a464-632ef5d30760}")
            initialized := true
        }
        rect := Buffer(16,0)
        if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 9, "Ptr", rect, "UInt", 16, "Int") != 0)
            throw Error("Target capture bounds unavailable")
        x := NumGet(rect,0,"Int"), y := NumGet(rect,4,"Int")
        width := NumGet(rect,8,"Int")-x, height := NumGet(rect,12,"Int")-y
        if (width < 1 || height < 1 || width > 8192 || height > 8192 || width*height > 25000000)
            throw Error("Target capture bounds exceed budget")
        pool := session := frame := surface := 0
        try {
            ComCall(6, pools, "Ptr", direct, "Int", 87, "Int", 2, "Int64", (height << 32)|width,
                "Ptr*", pool := ComValue(13,0))
            ; IGraphicsCaptureItemInterop.CreateForWindow: the exact pinned HWND.
            if (ComCall(3, interop, "Ptr", hwnd, "Ptr", itemIID, "Ptr*", item := ComValue(13,0), "UInt") != 0)
                throw Error("Target capture item unavailable")
            ComCall(10, pool, "Ptr", item, "Ptr*", session := ComValue(13,0))
            try {
                cursor := ComObjQuery(session, "{2c39ae40-7d2e-5044-804e-8b6799d4cf9e}")
                ComCall(7, cursor, "Int", 0)
            }
            ; Keep Windows' normal capture indicator; no security setting or
            ; unrelated window is hidden/modified to make capture succeed.
            ComCall(6, session)
            deadline := A_TickCount+1500
            Loop {
                ComCall(7, pool, "Ptr*", frame := ComValue(13,0))
                if (frame.Ptr)
                    break
                if (A_TickCount >= deadline)
                    throw Error("Target capture frame deadline exceeded")
                Sleep(10) ; Pump the owning STA instead of an unbounded busy spin.
            }
            ComCall(6, frame, "Ptr*", surface := ComValue(13,0))
            ComCall(11, this.SoftwareBitmapStatics, "Ptr", surface, "Ptr*", bitmap := ComValue(13,0))
            this.WaitForAsync(&bitmap)
            bitmap.x := x, bitmap.y := y, bitmap.w := width, bitmap.h := height
            return bitmap
        } finally {
            ; Interfaces share session ownership: close each actual object only
            ; once; COM values themselves release their interface references.
            for value in [surface, frame, session, pool]
                if (IsObject(value) && value.Ptr)
                    try this.CloseIClosable(value)
        }
    }
}
