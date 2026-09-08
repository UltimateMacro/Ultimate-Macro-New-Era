param(
    [string]$StrategyPath = ""
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$localAppData = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { $env:TEMP }
$stateRoot = Join-Path $localAppData 'Ultimate_Macro\StrategyLabEditor'
New-Item -ItemType Directory -Force -Path $stateRoot | Out-Null
$logPath = Join-Path $stateRoot ("bootstrap-{0}.log" -f $PID)

function Write-Log([string]$Message) {
    $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Write-Host $line
    try { [IO.File]::AppendAllText($logPath, $line + [Environment]::NewLine, [Text.Encoding]::UTF8) } catch {}
}

function Download-File([string]$Url, [string]$Destination, [int]$MinimumBytes = 100) {
    $dir = Split-Path -Parent $Destination
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $tmp = $Destination + '.download'
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    $downloaded = $false
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $tmp -TimeoutSec 60
        $downloaded = $true
    } catch {
        Write-Log "Invoke-WebRequest failed for $Url :: $($_.Exception.Message)"
        try {
            if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
                Start-BitsTransfer -Source $Url -Destination $tmp -ErrorAction Stop
                $downloaded = $true
            }
        } catch {
            Write-Log "BITS fallback failed for $Url :: $($_.Exception.Message)"
        }
    }
    if (!$downloaded -or !(Test-Path -LiteralPath $tmp -PathType Leaf) -or (Get-Item -LiteralPath $tmp).Length -lt $MinimumBytes) {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        throw "Could not download required file: $Url"
    }
    Move-Item -LiteralPath $tmp -Destination $Destination -Force
}


function Get-GitBlobSha1([string]$Path) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $bytes = [IO.File]::ReadAllBytes($Path)
    $header = [Text.Encoding]::UTF8.GetBytes(("blob {0}`0" -f $bytes.Length))
    $payload = New-Object byte[] ($header.Length + $bytes.Length)
    [Array]::Copy($header, 0, $payload, 0, $header.Length)
    [Array]::Copy($bytes, 0, $payload, $header.Length, $bytes.Length)
    $sha1 = [Security.Cryptography.SHA1]::Create()
    try {
        return ([BitConverter]::ToString($sha1.ComputeHash($payload))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha1.Dispose()
    }
}

function Test-PinnedGitBlob([string]$Path, [string]$ExpectedBlobSha) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    if ([string]::IsNullOrWhiteSpace($ExpectedBlobSha) -or $ExpectedBlobSha -notmatch '^[0-9a-fA-F]{40}$') {
        throw "Invalid expected Git blob SHA for $Path"
    }
    $actual = Get-GitBlobSha1 $Path
    return $actual -eq $ExpectedBlobSha.ToLowerInvariant()
}

function Get-WebView2Version {
    $guid = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
    $keys = @(
        "HKCU:\Software\Microsoft\EdgeUpdate\Clients\$guid",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\$guid",
        "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$guid"
    )
    foreach ($key in $keys) {
        try {
            $pv = (Get-ItemProperty -LiteralPath $key -Name pv -ErrorAction Stop).pv
            if ($pv -and $pv -ne '0.0.0.0') { return [string]$pv }
        } catch {}
    }
    return $null
}

function Find-AutoHotkeyV2 {
    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($p in @(
        (Join-Path $root '_runtime\AutoHotkey64.exe'),
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey32.exe",
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey.exe",
        "$env:ProgramFiles\AutoHotkey\UX\AutoHotkeyUX.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey.exe",
        "$env:USERPROFILE\Desktop\TDS_Macro\submacros\AutoHotkey64.exe",
        "$env:USERPROFILE\Desktop\Ultimate_Macro\submacros\AutoHotkey64.exe",
        "$env:USERPROFILE\Desktop\Ultimate_Macro\TDS_Macro\submacros\AutoHotkey64.exe"
    )) { if ($p) { $candidates.Add($p) } }

    try {
        Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE 'Desktop') -Directory -ErrorAction Stop |
            Where-Object { $_.Name -match '(?i)(macro|tds)' } |
            ForEach-Object {
                $portable = Join-Path $_.FullName 'submacros\AutoHotkey64.exe'
                if (Test-Path -LiteralPath $portable -PathType Leaf) { $candidates.Add($portable) }
            }
    } catch {}

    try {
        $cmd = Get-Command AutoHotkey64.exe -ErrorAction Stop
        if ($cmd.Source) { $candidates.Add($cmd.Source) }
    } catch {}
    try {
        $cmd = Get-Command AutoHotkey.exe -ErrorAction Stop
        if ($cmd.Source) { $candidates.Add($cmd.Source) }
    } catch {}

    foreach ($p in $candidates | Select-Object -Unique) {
        if (!(Test-Path -LiteralPath $p -PathType Leaf)) { continue }
        try {
            $v = [Diagnostics.FileVersionInfo]::GetVersionInfo($p).FileVersion
            if ($v -and ([version]($v -replace '[^0-9\.].*$','')) -ge [version]'2.0.0') {
                return $p
            }
        } catch {
            if ($p -match '\\v2\\') { return $p }
        }
    }
    return $null
}

function Ensure-AutoHotkeyV2 {
    $ahk = Find-AutoHotkeyV2
    if ($ahk) {
        Write-Log "AutoHotkey v2 OK path=$ahk"
        return $ahk
    }

    $runtimeDir = Join-Path $root '_runtime'
    $runtimeExe = Join-Path $runtimeDir 'AutoHotkey64.exe'
    New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null
    $archive = Join-Path $env:TEMP 'StrategyLab-AutoHotkey-2.0.19.zip'
    $expected = '4E0D0E65655066A646A210951320FEAEF0729A3597177131ADAEC4066BEF5869'
    Write-Log 'AutoHotkey v2 not found; downloading pinned portable runtime 2.0.19.'
    Download-File 'https://github.com/AutoHotkey/AutoHotkey/releases/download/v2.0.19/AutoHotkey_2.0.19.zip' $archive 300000
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash
    if ($actual -ne $expected) {
        Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
        throw "Portable AutoHotkey SHA-256 mismatch: expected $expected got $actual"
    }
    $extract = Join-Path $env:TEMP ('StrategyLab-AHK-' + $PID)
    Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -LiteralPath $archive -DestinationPath $extract -Force
    $candidate = Get-ChildItem -LiteralPath $extract -Recurse -Filter 'AutoHotkey64.exe' -File | Select-Object -First 1
    if (!$candidate) { throw 'Portable AutoHotkey64.exe was not found in the pinned archive.' }
    Copy-Item -LiteralPath $candidate.FullName -Destination $runtimeExe -Force
    Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Portable AutoHotkey v2 installed locally path=$runtimeExe"
    return $runtimeExe
}

function Ensure-WebView2 {
    $version = Get-WebView2Version
    if ($version) {
        Write-Log "WebView2 Runtime OK version=$version"
        return
    }

    $installer = Join-Path $env:TEMP 'MicrosoftEdgeWebview2Setup.exe'
    Write-Log 'WebView2 Runtime missing; downloading official Microsoft Evergreen bootstrapper.'
    Download-File 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' $installer 500000
    Write-Log 'Installing WebView2 Runtime silently.'
    $proc = Start-Process -FilePath $installer -ArgumentList '/silent','/install' -Wait -PassThru
    if ($proc.ExitCode -ne 0) { throw "WebView2 installer exited with code $($proc.ExitCode)." }
    Start-Sleep -Seconds 1
    $version = Get-WebView2Version
    if (!$version) { throw 'WebView2 installation finished but the Runtime still could not be detected.' }
    Write-Log "WebView2 Runtime installed version=$version"
}

function Ensure-WebViewToo {
    $vendor = Join-Path $root 'vendor\WebViewToo'
    $commit = '53fc321984d1ad9665038950f5ef4cedd1face35'
    $base = "https://raw.githubusercontent.com/The-CoDingman/WebViewToo/$commit/Lib"
    $files = @(
        @{ Rel='WebViewToo.ahk'; Min=20000; Blob='8442f936c5abdc3ff1e8105f4814574c9d92777d'; Url="$base/WebViewToo.ahk" },
        @{ Rel='WebView2.ahk'; Min=50000; Blob='e1e6bcd328310c017d28a984fc8c1fed680ace3b'; Url="$base/WebView2.ahk" },
        @{ Rel='ComVar.ahk'; Min=1000; Blob='fc55eb5e3db5189558015aace92deae92c5a9862'; Url="$base/ComVar.ahk" },
        @{ Rel='Promise.ahk'; Min=5000; Blob='cbd61b590a3a3e8828d6c472dbc685631f6e4459'; Url="$base/Promise.ahk" },
        @{ Rel='32bit\WebView2Loader.dll'; Min=50000; Blob='7c736daeb14378ec8994dacd284c74130ee97559'; Url="$base/32bit/WebView2Loader.dll" },
        @{ Rel='64bit\WebView2Loader.dll'; Min=50000; Blob='c757cca2fd65e95b1dc7e65d9f113ec9233a0415'; Url="$base/64bit/WebView2Loader.dll" }
    )

    New-Item -ItemType Directory -Force -Path $vendor,(Join-Path $vendor '32bit'),(Join-Path $vendor '64bit') | Out-Null
    foreach ($file in $files) {
        $dest = Join-Path $vendor $file.Rel
        $sizeOk = (Test-Path -LiteralPath $dest -PathType Leaf) -and ((Get-Item -LiteralPath $dest).Length -ge $file.Min)
        $valid = $sizeOk -and (Test-PinnedGitBlob $dest $file.Blob)
        if ($valid) { continue }
        if (Test-Path -LiteralPath $dest -PathType Leaf) {
            $actual = Get-GitBlobSha1 $dest
            Write-Log "Replacing invalid pinned dependency $($file.Rel) blob=$actual expected=$($file.Blob)"
            Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
        }
        Write-Log "Fetching pinned WebViewToo dependency $($file.Rel)"
        Download-File $file.Url $dest $file.Min
        if (!(Test-PinnedGitBlob $dest $file.Blob)) {
            $actual = Get-GitBlobSha1 $dest
            Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
            throw "Pinned WebViewToo integrity check failed for $($file.Rel): expected $($file.Blob), got $actual"
        }
    }
    $licensePath = Join-Path $vendor 'LICENSE.WebViewToo.txt'
    if (!(Test-Path -LiteralPath $licensePath -PathType Leaf)) {
        try { Download-File "https://raw.githubusercontent.com/The-CoDingman/WebViewToo/$commit/LICENSE" $licensePath 500 } catch {
            Write-Log "Could not download separate WebViewToo LICENSE file; source headers still contain the MIT notice."
        }
    }
    Write-Log 'WebViewToo dependency set OK.'
}

function Ensure-AppFiles {
    foreach ($rel in @('StrategyEditorHost.ahk','ui\index.html','ui\styles.css','ui\app.js','data\towers.ini','data\maps.ini','capture_roblox.ps1','sync_portraits.ps1','self_test.ps1','calibration\sandbox_replay.ahk')) {
        $path = Join-Path $root $rel
        if (!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -lt 20) {
            throw "Strategy Lab Editor package is incomplete: missing $rel"
        }
    }
}

function Invoke-StrategyLabSelfTest([string]$AhkPath) {
    $script = Join-Path $root 'self_test.ps1'
    if (!(Test-Path -LiteralPath $script -PathType Leaf)) { throw 'self_test.ps1 is missing.' }
    $argLine = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $script + '" -Root "' + $root + '" -AhkPath "' + $AhkPath + '" -Quiet'
    Write-Log 'Running pre-launch syntax and contract self-test.'
    $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $argLine -Wait -PassThru -WindowStyle Hidden
    if ($proc.ExitCode -ne 0) {
        Write-Host ''
        Write-Host 'Pre-launch validation found a problem. Detailed diagnostics:' -ForegroundColor Yellow
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $script -Root $root -AhkPath $AhkPath
        throw 'Strategy Lab pre-launch self-test failed. Nothing was launched.'
    }
    Write-Log 'Pre-launch self-test OK.'
}

try {
    Write-Log 'BEGIN Strategy Lab Editor 0.5 alpha.5.5.1 bootstrap'
    Ensure-AppFiles
    $ahk = Ensure-AutoHotkeyV2
    Ensure-WebView2
    Ensure-WebViewToo
    Invoke-StrategyLabSelfTest $ahk

    $hostScript = Join-Path $root 'StrategyEditorHost.ahk'
    $args = @('"' + $hostScript + '"')
    if (![string]::IsNullOrWhiteSpace($StrategyPath)) {
        $resolved = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($StrategyPath.Trim('"')))
        $args += '--strategy'
        $args += '"' + $resolved + '"'
    }

    Write-Log "Launching editor with $ahk"
    Start-Process -FilePath $ahk -ArgumentList $args -WorkingDirectory $root
} catch {
    Write-Log "FAILED :: $($_.Exception.Message)"
    Write-Host ''
    Write-Host 'Strategy Lab Editor could not start:' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Log: $logPath" -ForegroundColor DarkGray
    Read-Host 'Press Enter to close'
    exit 1
}
