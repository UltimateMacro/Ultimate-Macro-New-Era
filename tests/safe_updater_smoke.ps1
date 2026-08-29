$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$safeUpdater = Join-Path $repoRoot 'submacros\safe_update.ps1'
$systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $systemTemp ('UltimateMacro-updater-test-' + [guid]::NewGuid().ToString('N'))
$serveDir = Join-Path $tempRoot 'serve'
$payload = Join-Path $tempRoot 'payload'
$badInstall = Join-Path $tempRoot 'bad-install'
$goodInstall = Join-Path $tempRoot 'good-install'
$gitInstall = Join-Path $tempRoot 'git-install'
$unsafeInstall = Join-Path $tempRoot 'unsafe-install'
$logDir = Join-Path $tempRoot 'logs'
$server = $null

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Read-Trimmed([string]$Path) {
    return (Get-Content -LiteralPath $Path -Raw).Trim()
}

function Initialize-Install([string]$Path, [string]$Marker) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    'ver := "old"' | Set-Content -Encoding UTF8 (Join-Path $Path 'Main.ahk')
    $Marker | Set-Content -Encoding UTF8 (Join-Path $Path 'original.txt')
}

function Invoke-SafeUpdater(
    [string]$Install,
    [string]$Url,
    [string]$Hash,
    [string]$Version
) {
    & $script:shell.Source -NoLogo -NoProfile -ExecutionPolicy Bypass -File $safeUpdater `
        -DownloadUrl $Url -MacroDir $Install -ExpectedSha256 $Hash `
        -ExpectedVersion $Version -LogDir $logDir -NonInteractive -NoLaunch | Out-Host
    return $LASTEXITCODE
}

$tempPrefix = $systemTemp.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
Assert-True ([IO.Path]::GetFullPath($tempRoot).StartsWith(
    $tempPrefix, [StringComparison]::OrdinalIgnoreCase
)) 'Updater smoke-test root escaped the system temporary directory.'

try {
    New-Item -ItemType Directory -Force -Path $serveDir, $payload | Out-Null

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
        'submacros\updater.ahk',
        'submacros\update.bat',
        'submacros\watchdog.ahk',
        'Resources\ready_gs.png'
    )

    foreach ($relative in $required) {
        $path = Join-Path $payload $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
        if ($relative -eq 'Main.ahk') {
            'ver := "1.2.3"' | Set-Content -Encoding UTF8 $path
        }
        else {
            "test payload: $relative" | Set-Content -Encoding UTF8 $path
        }
    }
    Copy-Item -LiteralPath $safeUpdater -Destination (Join-Path $payload 'submacros\safe_update.ps1') -Force
    'new installation marker' | Set-Content -Encoding UTF8 (Join-Path $payload 'new.txt')

    $payloadStrats = Join-Path $payload 'Resources\Strats'
    New-Item -ItemType Directory -Force -Path $payloadStrats | Out-Null
    'release-only' | Set-Content -Encoding UTF8 (Join-Path $payloadStrats 'release-only.strat')
    'same-version' | Set-Content -Encoding UTF8 (Join-Path $payloadStrats 'same.strat')
    'RELEASE VERSION' | Set-Content -Encoding UTF8 (Join-Path $payloadStrats 'conflict.strat')
    [IO.File]::WriteAllBytes(
        (Join-Path $payload 'filler.dat'),
        (0..8191 | ForEach-Object { [byte](Get-Random -Minimum 0 -Maximum 256) })
    )

    $zip = Join-Path $serveDir 'TDS_Macro.zip'
    Compress-Archive -Path (Join-Path $payload '*') -DestinationPath $zip -Force
    $goodHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $unsafeZip = Join-Path $serveDir 'unsafe.zip'
    $unsafeArchive = [IO.Compression.ZipFile]::Open($unsafeZip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $entry = $unsafeArchive.CreateEntry('../escape.txt')
        $writer = [IO.StreamWriter]::new($entry.Open())
        try { $writer.Write(('unsafe' * 300)) } finally { $writer.Dispose() }

        $fillerEntry = $unsafeArchive.CreateEntry('filler.dat')
        $fillerStream = $fillerEntry.Open()
        try {
            [byte[]]$randomBytes = 0..4095 | ForEach-Object {
                [byte](Get-Random -Minimum 0 -Maximum 256)
            }
            $fillerStream.Write($randomBytes, 0, $randomBytes.Length)
        }
        finally { $fillerStream.Dispose() }
    }
    finally { $unsafeArchive.Dispose() }
    $unsafeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $unsafeZip).Hash.ToLowerInvariant()

    Initialize-Install $badInstall 'original bad install'
    Initialize-Install $goodInstall 'original good install'
    Initialize-Install $gitInstall 'developer checkout'
    Initialize-Install $unsafeInstall 'unsafe archive install'
    New-Item -ItemType Directory -Force -Path (Join-Path $gitInstall '.git') | Out-Null

    $badStrats = Join-Path $badInstall 'Resources\Strats'
    $goodStrats = Join-Path $goodInstall 'Resources\Strats'
    New-Item -ItemType Directory -Force -Path $badStrats, $goodStrats | Out-Null
    'bad-install-user-strat' | Set-Content -Encoding UTF8 (Join-Path $badStrats 'user-only.strat')
    'USER ONLY' | Set-Content -Encoding UTF8 (Join-Path $goodStrats 'user-only.strat')
    'same-version' | Set-Content -Encoding UTF8 (Join-Path $goodStrats 'same.strat')
    'USER VERSION' | Set-Content -Encoding UTF8 (Join-Path $goodStrats 'conflict.strat')

    $port = Get-Random -Minimum 18000 -Maximum 24000
    $server = Start-Process -FilePath python -ArgumentList @(
        '-m', 'http.server', "$port", '--bind', '127.0.0.1', '--directory', $serveDir
    ) -PassThru -WindowStyle Hidden
    $url = "http://127.0.0.1:$port/TDS_Macro.zip"
    $unsafeUrl = "http://127.0.0.1:$port/unsafe.zip"

    $ready = $false
    1..20 | ForEach-Object {
        if ($ready) { return }
        try {
            Invoke-WebRequest -UseBasicParsing -Method Head -Uri $url -TimeoutSec 1 | Out-Null
            $ready = $true
        }
        catch { Start-Sleep -Milliseconds 150 }
    }
    Assert-True $ready 'Local updater test HTTP server did not start.'

    $script:shell = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $script:shell) { $script:shell = Get-Command powershell.exe -ErrorAction Stop }

    $missingExit = Invoke-SafeUpdater $badInstall $url '' '1.2.3'
    Assert-True ($missingExit -ne 0) 'Missing-checksum update unexpectedly succeeded.'
    Assert-True (Test-Path -LiteralPath (Join-Path $badInstall 'original.txt')) 'Missing-checksum test modified the installation.'

    $selfDeletingUpdater = Join-Path $tempRoot 'UltimateMacro_safe_update_smoke.ps1'
    Copy-Item -LiteralPath $safeUpdater -Destination $selfDeletingUpdater
    & $script:shell.Source -NoLogo -NoProfile -ExecutionPolicy Bypass -File $selfDeletingUpdater `
        -DownloadUrl $url -MacroDir $badInstall -ExpectedSha256 ('0' * 64) `
        -ExpectedVersion '1.2.3' -LogDir $logDir -NonInteractive -NoLaunch -SelfDelete | Out-Host
    $selfDeleteExit = $LASTEXITCODE
    Assert-True ($selfDeleteExit -ne 0) 'Self-delete failure-path update unexpectedly succeeded.'
    Assert-True (-not (Test-Path -LiteralPath $selfDeletingUpdater)) 'Temporary updater script was not self-deleted.'

    $badExit = Invoke-SafeUpdater $badInstall $url ('0' * 64) '1.2.3'
    Assert-True ($badExit -ne 0) 'Bad-checksum update unexpectedly succeeded.'
    Assert-True (Test-Path -LiteralPath (Join-Path $badInstall 'original.txt')) 'Bad-checksum test modified the installation.'
    Assert-True ((Read-Trimmed (Join-Path $badStrats 'user-only.strat')) -eq 'bad-install-user-strat') 'Bad-checksum test modified a strategy.'

    $versionExit = Invoke-SafeUpdater $badInstall $url $goodHash '9.9.9'
    Assert-True ($versionExit -ne 0) 'Version-mismatch update unexpectedly succeeded.'
    Assert-True (Test-Path -LiteralPath (Join-Path $badInstall 'original.txt')) 'Version-mismatch test modified the installation.'

    $gitExit = Invoke-SafeUpdater $gitInstall $url $goodHash '1.2.3'
    Assert-True ($gitExit -ne 0) 'Developer-checkout update unexpectedly succeeded.'
    Assert-True (Test-Path -LiteralPath (Join-Path $gitInstall 'original.txt')) 'Developer-checkout test modified the installation.'

    $unsafeExit = Invoke-SafeUpdater $unsafeInstall $unsafeUrl $unsafeHash '1.2.3'
    Assert-True ($unsafeExit -ne 0) 'Path-traversal archive unexpectedly succeeded.'
    Assert-True (Test-Path -LiteralPath (Join-Path $unsafeInstall 'original.txt')) 'Unsafe-archive test modified the installation.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $tempRoot 'escape.txt'))) 'Unsafe archive escaped staging.'

    $goodExit = Invoke-SafeUpdater $goodInstall $url $goodHash '1.2.3'
    Assert-True ($goodExit -eq 0) "Valid update failed with exit code $goodExit."
    Assert-True (Test-Path -LiteralPath (Join-Path $goodInstall 'new.txt')) 'New payload was not installed.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $goodInstall 'original.txt'))) 'Old payload leaked into replacement.'

    $installedStrats = Join-Path $goodInstall 'Resources\Strats'
    Assert-True ((Read-Trimmed (Join-Path $installedStrats 'user-only.strat')) -eq 'USER ONLY') 'User-only strategy changed.'
    Assert-True ((Read-Trimmed (Join-Path $installedStrats 'release-only.strat')) -eq 'release-only') 'Release strategy was lost.'
    Assert-True ((Read-Trimmed (Join-Path $installedStrats 'same.strat')) -eq 'same-version') 'Identical strategy changed.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $installedStrats 'same.release-1.2.3.strat'))) 'Identical strategy created a conflict copy.'
    Assert-True ((Read-Trimmed (Join-Path $installedStrats 'conflict.strat')) -eq 'USER VERSION') 'User strategy did not win a conflict.'
    $releaseConflict = Join-Path $installedStrats 'conflict.release-1.2.3.strat'
    Assert-True ((Read-Trimmed $releaseConflict) -eq 'RELEASE VERSION') 'Release conflict copy was not preserved.'

    $leaf = Split-Path -Leaf $goodInstall
    $backups = @(Get-ChildItem -LiteralPath $tempRoot -Directory -Filter ".$leaf.backup-*")
    Assert-True ($backups.Count -eq 1) "Expected one rollback backup; found $($backups.Count)."
    Assert-True (Test-Path -LiteralPath (Join-Path $backups[0].FullName 'original.txt')) 'Rollback backup is incomplete.'
    Assert-True (Test-Path -LiteralPath (Join-Path $logDir 'last-update-backup.txt')) 'Backup location log was not written.'

    Write-Host 'safe updater smoke test: PASS'
}
finally {
    if ($server -and -not $server.HasExited) {
        Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $tempRoot) {
        Assert-True ([IO.Path]::GetFullPath($tempRoot).StartsWith(
            $tempPrefix, [StringComparison]::OrdinalIgnoreCase
        )) 'Refusing to clean an updater test path outside the system temporary directory.'
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
