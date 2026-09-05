param(
    [string[]]$ScriptPath = @(
        'Main.ahk',
        'submacros/watchdog.ahk',
        'submacros/auto_coa.ahk',
        'submacros/auto_open_consumable.ahk',
        'submacros/auto_spin.ahk',
        'tests/test_auto_settings.ahk'
    )
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repoRoot = Split-Path -Parent $PSScriptRoot
$version = '2.0.26'
$archiveSha256 = '43522aa3122a57784ac5db30abf85c2244475c36acd7796e2c993355f9e926ae'
$downloadUrl = "https://github.com/AutoHotkey/AutoHotkey/releases/download/v$version/AutoHotkey_$version.zip"
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$workRoot = Join-Path $tempRoot ('UltimateMacro-ahk-validate-' + [guid]::NewGuid().ToString('N'))
$archivePath = Join-Path $workRoot 'AutoHotkey.zip'
$extractPath = Join-Path $workRoot 'AutoHotkey'

if (-not ([IO.Path]::GetFullPath($workRoot) + [IO.Path]::DirectorySeparatorChar).StartsWith(
    $tempRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to use a validation work directory outside the system temp root: $workRoot"
}

function Assert-SafeZip([string]$Path) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName.Replace('\', '/')
            if ([string]::IsNullOrWhiteSpace($name)) { continue }
            if ($name.StartsWith('/') -or $name -match '^[A-Za-z]:' -or ($name -split '/') -contains '..') {
                throw "Unsafe AutoHotkey archive entry rejected: $($entry.FullName)"
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}

try {
    New-Item -ItemType Directory -Force -Path $workRoot, $extractPath | Out-Null
    Invoke-WebRequest -UseBasicParsing -Uri $downloadUrl -OutFile $archivePath

    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToLowerInvariant()
    if ($actualHash -ne $archiveSha256) {
        throw "AutoHotkey archive hash mismatch. Expected $archiveSha256, got $actualHash."
    }

    Assert-SafeZip $archivePath
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath
    $autoHotkey = Join-Path $extractPath 'AutoHotkey64.exe'
    if (-not (Test-Path -LiteralPath $autoHotkey -PathType Leaf)) {
        throw 'Verified AutoHotkey archive did not contain AutoHotkey64.exe.'
    }

    foreach ($script in $ScriptPath) {
        $resolvedScript = [IO.Path]::GetFullPath((Join-Path $repoRoot $script))
        if (-not (Test-Path -LiteralPath $resolvedScript -PathType Leaf)) {
            throw "AHK validation target does not exist: $resolvedScript"
        }

        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $autoHotkey
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        [void]$startInfo.ArgumentList.Add('/ErrorStdOut=UTF-8')
        [void]$startInfo.ArgumentList.Add('/Validate')
        [void]$startInfo.ArgumentList.Add($resolvedScript)

        $process = [Diagnostics.Process]::Start($startInfo)
        if (-not $process.WaitForExit(15000)) {
            $process.Kill($true)
            throw "AutoHotkey validation timed out for $script."
        }
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()

        if ($stdout) { Write-Host $stdout.TrimEnd() }
        if ($stderr) { Write-Host $stderr.TrimEnd() }
        if ($process.ExitCode -ne 0) {
            throw "AutoHotkey validation failed for $script with exit code $($process.ExitCode)."
        }
        Write-Host "AutoHotkey validation: PASS ($script)"
    }

    $behavioralScript = [IO.Path]::GetFullPath((Join-Path $repoRoot 'tests/test_auto_settings.ahk'))
    $behavioralInfo = [Diagnostics.ProcessStartInfo]::new()
    $behavioralInfo.FileName = $autoHotkey
    $behavioralInfo.WorkingDirectory = $repoRoot
    $behavioralInfo.UseShellExecute = $false
    $behavioralInfo.CreateNoWindow = $true
    $behavioralInfo.RedirectStandardOutput = $true
    $behavioralInfo.RedirectStandardError = $true
    [void]$behavioralInfo.ArgumentList.Add('/ErrorStdOut=UTF-8')
    [void]$behavioralInfo.ArgumentList.Add($behavioralScript)
    $behavioralResult = Join-Path $workRoot 'auto-settings-result.txt'
    [void]$behavioralInfo.ArgumentList.Add($behavioralResult)

    $behavioralProcess = [Diagnostics.Process]::Start($behavioralInfo)
    if (-not $behavioralProcess.WaitForExit(30000)) {
        $behavioralProcess.Kill($true)
        throw 'Auto Settings behavioral fixtures timed out under AutoHotkey 2.0.26.'
    }
    $behavioralStdout = $behavioralProcess.StandardOutput.ReadToEnd()
    $behavioralStderr = $behavioralProcess.StandardError.ReadToEnd()
    if ($behavioralStdout) { Write-Host $behavioralStdout.TrimEnd() }
    if ($behavioralStderr) { Write-Host $behavioralStderr.TrimEnd() }
    $behavioralMessage = if (Test-Path -LiteralPath $behavioralResult -PathType Leaf) {
        (Get-Content -LiteralPath $behavioralResult -Raw).Trim()
    }
    else { '' }
    if ($behavioralProcess.ExitCode -ne 0 -or $behavioralMessage -ne 'Auto Settings behavioral fixtures: PASS') {
        throw "Auto Settings behavioral fixtures failed under AutoHotkey 2.0.26 with exit code $($behavioralProcess.ExitCode)."
    }
    Write-Host 'AutoHotkey behavioral fixtures: PASS (2.0.26)'
}
finally {
    if (Test-Path -LiteralPath $workRoot) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
