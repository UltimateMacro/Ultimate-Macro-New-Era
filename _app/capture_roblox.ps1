param(
    [Parameter(Mandatory=$true)][int]$X,
    [Parameter(Mandatory=$true)][int]$Y,
    [Parameter(Mandatory=$true)][int]$Width,
    [Parameter(Mandatory=$true)][int]$Height,
    [Parameter(Mandatory=$true)][string]$Target
)

$ErrorActionPreference = 'Stop'
if ($Width -lt 100 -or $Height -lt 100) { throw 'Roblox client rectangle is too small.' }
$dir = Split-Path -Parent $Target
if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$tmp = $Target + '.capture.tmp.png'
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue

Add-Type -AssemblyName System.Drawing
try {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class SLEDpi {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
}
'@ -ErrorAction Stop
    # PER_MONITOR_AWARE_V2. Keeps CopyFromScreen in the same physical-pixel space as the
    # AutoHotkey client rectangle on scaled/multi-monitor desktops.
    [void][SLEDpi]::SetProcessDpiAwarenessContext([IntPtr](-4))
} catch {}

$bmp = $null
$g = $null
try {
    $bmp = [Drawing.Bitmap]::new($Width, $Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($X, $Y, 0, 0, [Drawing.Size]::new($Width, $Height), [Drawing.CopyPixelOperation]::SourceCopy)
    $bmp.Save($tmp, [Drawing.Imaging.ImageFormat]::Png)
} finally {
    if ($g) { $g.Dispose() }
    if ($bmp) { $bmp.Dispose() }
}

if (!(Test-Path -LiteralPath $tmp -PathType Leaf) -or (Get-Item -LiteralPath $tmp).Length -lt 1000) {
    throw 'Lossless Roblox capture was not created.'
}
Move-Item -LiteralPath $tmp -Destination $Target -Force
Write-Output $Target
