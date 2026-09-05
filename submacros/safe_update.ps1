param(
    [Parameter(Mandatory = $true)][string]$DownloadUrl,
    [Parameter(Mandatory = $true)][string]$MacroDir,
    [Parameter(Mandatory = $true)][string]$ExpectedSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedVersion,
    [int]$WaitPid = 0,
    [string]$LogDir = '',
    [switch]$SelfDelete,
    [switch]$NonInteractive,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Normalize-VersionLabel([string]$Version) {
    if ([string]::IsNullOrWhiteSpace($Version)) { return '' }
    return (($Version.Trim()) -replace '^[vV]', '')
}

function Assert-ChildPath([string]$Child, [string]$Parent, [string]$Label) {
    $childFull = [IO.Path]::GetFullPath($Child)
    $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $childFull.StartsWith($parentFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label must stay inside $Parent; resolved path was $childFull."
    }
}

function Assert-InstallRoot([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $volumeRoot = [IO.Path]::GetPathRoot($full)
    if ($full.TrimEnd('\', '/') -eq $volumeRoot.TrimEnd('\', '/')) {
        throw "Refusing to update a filesystem root: $full"
    }
    $full = $full.TrimEnd('\', '/')
    if (-not (Test-Path -LiteralPath $full -PathType Container)) {
        throw "Macro directory not found: $full"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $full 'Main.ahk') -PathType Leaf)) {
        throw "Refusing to update a directory that does not contain Main.ahk: $full"
    }
    if (Test-Path -LiteralPath (Join-Path $full '.git')) {
        throw 'A .git entry was detected. Automatic update is disabled for developer checkouts; use Git instead.'
    }
    return $full
}

function Assert-DownloadUrl([string]$Value) {
    $uri = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri)) {
        throw 'The release supplied an invalid download URL.'
    }
    $official = $uri.Scheme -eq 'https' -and $uri.Host -eq 'github.com' -and
        $uri.AbsolutePath.StartsWith('/DarksenDev/tds-macro/releases/download/', [StringComparison]::OrdinalIgnoreCase)
    $loopbackTest = $uri.Scheme -eq 'http' -and $uri.IsLoopback
    if (-not ($official -or $loopbackTest)) {
        throw "Untrusted update URL rejected: $Value"
    }
}

function Normalize-Sha256([string]$Value) {
    $expected = $Value.Trim().ToLowerInvariant()
    if ($expected.StartsWith('sha256:')) { $expected = $expected.Substring(7) }
    if ($expected -notmatch '^[0-9a-f]{64}$') {
        throw 'A valid SHA-256 release digest is required for automatic updates.'
    }
    return $expected
}

function Assert-SafeZip([string]$Path, [string]$DestinationRoot) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $destinationPrefix = [IO.Path]::GetFullPath($DestinationRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        if ($archive.Entries.Count -gt 20000) {
            throw "Update archive contains too many entries: $($archive.Entries.Count)."
        }

        [Int64]$expandedBytes = 0
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName.Replace('\', '/')
            if ([string]::IsNullOrWhiteSpace($name)) { continue }
            if ($name.StartsWith('/') -or $name.Contains(':') -or ($name -split '/') -contains '..') {
                throw "Unsafe archive entry rejected: $($entry.FullName)"
            }

            $unixType = (($entry.ExternalAttributes -shr 16) -band 0xF000)
            if ($unixType -eq 0xA000) {
                throw "Symbolic-link archive entry rejected: $($entry.FullName)"
            }

            $target = [IO.Path]::GetFullPath((Join-Path $DestinationRoot $name))
            if (-not $target.StartsWith($destinationPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Archive entry escapes the staging directory: $($entry.FullName)"
            }

            $expandedBytes += $entry.Length
            if ($expandedBytes -gt 536870912) {
                throw 'Update archive expands beyond the 512 MiB safety limit.'
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}

function Resolve-PayloadRoot([string]$Stage) {
    $mainFiles = @(Get-ChildItem -LiteralPath $Stage -Filter 'Main.ahk' -File -Recurse)
    if ($mainFiles.Count -ne 1) {
        throw "Update package must contain exactly one Main.ahk; found $($mainFiles.Count)."
    }
    return $mainFiles[0].Directory.FullName
}

function Assert-RuntimePayload([string]$Root) {
    $required = @(
        'Main.ahk',
        'lib\Gdip_All.ahk',
        'lib\Gdip_ImageSearch.ahk',
        'lib\HyperSleep.ahk',
        'lib\ImageSearch\ImageSearch.ahk',
        'lib\OCR.ahk',
        'lib\JSON.ahk',
        'lib\Roblox.ahk',
        'lib\Discord.ahk',
        'lib\auto_settings.ahk',
        'submacros\updater.ahk',
        'submacros\update.bat',
        'submacros\safe_update.ps1',
        'submacros\watchdog.ahk',
        'Resources\ready_gs.png'
    )

    foreach ($relative in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $relative) -PathType Leaf)) {
            throw "Update package is incomplete. Missing: $relative"
        }
    }
}

function Assert-PayloadVersion([string]$Root, [string]$Expected) {
    $expectedNormalized = Normalize-VersionLabel $Expected
    if ($expectedNormalized -notmatch '^\d+(?:\.\d+){1,3}(?:[-+][0-9A-Za-z.-]+)?$') {
        throw "Invalid expected release version: $Expected"
    }

    $text = Get-Content -LiteralPath (Join-Path $Root 'Main.ahk') -Raw
    $match = [regex]::Match($text, '(?m)^\s*ver\s*:=\s*"([^"]+)"')
    if (-not $match.Success) {
        throw 'Update package Main.ahk does not declare a version.'
    }

    $actual = Normalize-VersionLabel $match.Groups[1].Value
    if ($actual -ne $expectedNormalized) {
        throw "Update package version mismatch. Release=$expectedNormalized, Main.ahk=$actual."
    }
}

function Preserve-ExistingStrategies([string]$InstallRoot, [string]$Destination) {
    $source = Join-Path $InstallRoot 'Resources\Strats'
    if (-not (Test-Path -LiteralPath $source -PathType Container)) { return 0 }
    $strats = @(Get-ChildItem -LiteralPath $source -Filter '*.strat' -File)
    if ($strats.Count -eq 0) { return 0 }

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    foreach ($strat in $strats) {
        Copy-Item -LiteralPath $strat.FullName -Destination (Join-Path $Destination $strat.Name) -Force
    }
    return $strats.Count
}

function Get-ConflictCopyPath([string]$TargetDir, [string]$FileName, [string]$VersionLabel) {
    $safeVersion = [regex]::Replace($VersionLabel, '[^A-Za-z0-9._-]', '_')
    $base = [IO.Path]::GetFileNameWithoutExtension($FileName)
    $ext = [IO.Path]::GetExtension($FileName)
    $candidate = Join-Path $TargetDir ($base + '.release-' + $safeVersion + $ext)
    $index = 1
    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path $TargetDir ($base + '.release-' + $safeVersion + '.' + $index + $ext)
        $index++
    }
    return $candidate
}

function Restore-PreservedStrategies([string]$PreservedDir, [string]$InstallRoot, [string]$VersionLabel) {
    if (-not (Test-Path -LiteralPath $PreservedDir -PathType Container)) { return 0 }
    $targetDir = Join-Path $InstallRoot 'Resources\Strats'
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    $conflicts = 0

    foreach ($oldStrat in Get-ChildItem -LiteralPath $PreservedDir -Filter '*.strat' -File) {
        $target = Join-Path $targetDir $oldStrat.Name
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            Copy-Item -LiteralPath $oldStrat.FullName -Destination $target -Force
            continue
        }

        $oldHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $oldStrat.FullName).Hash
        $newHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash
        if ($oldHash -eq $newHash) { continue }

        $releaseCopy = Get-ConflictCopyPath $targetDir $oldStrat.Name $VersionLabel
        Copy-Item -LiteralPath $target -Destination $releaseCopy -Force
        Copy-Item -LiteralPath $oldStrat.FullName -Destination $target -Force
        $conflicts++
    }
    return $conflicts
}

function Show-UpdateError([string]$Message) {
    if ($NonInteractive) {
        Write-Error $Message -ErrorAction Continue
        return
    }
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Windows.Forms.MessageBox]::Show(
            $Message, 'Ultimate Macro update failed',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
    catch { Write-Error $Message -ErrorAction Continue }
}

$installMoved = $false
$workRoot = ''
$tempRoot = ''
$backupDir = ''
$preservedStrategyCount = 0
$strategyConflictCount = 0

try {
    $MacroDir = Assert-InstallRoot $MacroDir
    Assert-DownloadUrl $DownloadUrl
    $expectedHash = Normalize-Sha256 $ExpectedSha256

    $parentDir = Split-Path -Parent $MacroDir
    $macroName = Split-Path -Leaf $MacroDir
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $workRoot = Join-Path $tempRoot ('UltimateMacro-update-' + [guid]::NewGuid().ToString('N'))
    Assert-ChildPath $workRoot $tempRoot 'Updater work directory'
    $zipPath = Join-Path $workRoot 'update.zip'
    $stageDir = Join-Path $workRoot 'stage'
    $preservedStratsDir = Join-Path $workRoot 'preserved-strats'
    $backupDir = Join-Path $parentDir ('.' + $macroName + '.backup-' + $stamp)

    New-Item -ItemType Directory -Force -Path $workRoot, $stageDir | Out-Null
    $preservedStrategyCount = Preserve-ExistingStrategies $MacroDir $preservedStratsDir

    Write-Host 'Downloading Ultimate Macro update...'
    Invoke-WebRequest -UseBasicParsing -Uri $DownloadUrl -OutFile $zipPath
    if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf) -or (Get-Item -LiteralPath $zipPath).Length -lt 1024) {
        throw 'Downloaded update is missing or unexpectedly small.'
    }

    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        throw "SHA-256 mismatch. Expected $expectedHash but downloaded $actualHash. Existing installation was not touched."
    }
    Write-Host "Checksum verified: $actualHash"

    Assert-SafeZip $zipPath $stageDir
    Expand-Archive -LiteralPath $zipPath -DestinationPath $stageDir
    $payloadRoot = Resolve-PayloadRoot $stageDir
    Assert-RuntimePayload $payloadRoot
    Assert-PayloadVersion $payloadRoot $ExpectedVersion

    if ($WaitPid -gt 0) {
        Write-Host "Waiting for macro process $WaitPid to exit..."
        try { Wait-Process -Id $WaitPid -Timeout 30 -ErrorAction Stop }
        catch { Start-Sleep -Seconds 2 }
    }

    if (Test-Path -LiteralPath $backupDir) {
        throw "Backup path already exists: $backupDir"
    }

    Write-Host "Creating rollback backup: $backupDir"
    Move-Item -LiteralPath $MacroDir -Destination $backupDir
    $installMoved = $true

    New-Item -ItemType Directory -Path $MacroDir | Out-Null
    Get-ChildItem -LiteralPath $payloadRoot -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $MacroDir -Recurse -Force
    }

    Assert-RuntimePayload $MacroDir
    Assert-PayloadVersion $MacroDir $ExpectedVersion
    $strategyConflictCount = Restore-PreservedStrategies $preservedStratsDir $MacroDir $ExpectedVersion

    if ([string]::IsNullOrWhiteSpace($LogDir)) {
        $LogDir = Join-Path $env:APPDATA 'Ultimate_Macro\Logs'
    }
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    @(
        "Version=$ExpectedVersion",
        "Backup=$backupDir",
        "Installed=$(Get-Date -Format o)",
        "PreservedStrategies=$preservedStrategyCount",
        "StrategyConflicts=$strategyConflictCount"
    ) | Set-Content -Encoding UTF8 (Join-Path $LogDir 'last-update-backup.txt')

    if (-not $NoLaunch) {
        $mainAhk = Join-Path $MacroDir 'Main.ahk'
        $mainExe = Join-Path $MacroDir 'ultimate_macro.exe'
        if (Test-Path -LiteralPath $mainAhk) {
            Start-Process -FilePath $mainAhk -WorkingDirectory $MacroDir
        }
        elseif (Test-Path -LiteralPath $mainExe) {
            Start-Process -FilePath $mainExe -WorkingDirectory $MacroDir
        }
        else {
            throw 'Update installed, but no launchable Main.ahk or ultimate_macro.exe was found.'
        }
    }

    Write-Host 'Update installed successfully.'
    Write-Host "Rollback backup kept at: $backupDir"
}
catch {
    $message = $_.Exception.Message
    if ($installMoved) {
        try {
            Write-Host 'Restoring previous installation...'
            if (Test-Path -LiteralPath $MacroDir) {
                Remove-Item -LiteralPath $MacroDir -Recurse -Force
            }
            if (Test-Path -LiteralPath $backupDir) {
                Move-Item -LiteralPath $backupDir -Destination $MacroDir
            }
            $message += "`r`n`r`nThe previous installation was restored."
        }
        catch {
            $message += "`r`n`r`nAutomatic rollback also failed: $($_.Exception.Message)`r`nBackup path: $backupDir"
        }
    }

    Show-UpdateError $message
    exit 1
}
finally {
    if ($workRoot -and (Test-Path -LiteralPath $workRoot)) {
        Assert-ChildPath $workRoot $tempRoot 'Updater cleanup directory'
        Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($SelfDelete -and $PSCommandPath) {
        $scriptPath = [IO.Path]::GetFullPath($PSCommandPath)
        $scriptName = Split-Path -Leaf $scriptPath
        Assert-ChildPath $scriptPath ([IO.Path]::GetTempPath()) 'Updater self-delete path'
        if ($scriptName -notlike 'UltimateMacro_safe_update_*.ps1') {
            throw "Refusing to self-delete an unexpected script path: $scriptPath"
        }
        Remove-Item -LiteralPath $scriptPath -Force -ErrorAction SilentlyContinue
    }
}
