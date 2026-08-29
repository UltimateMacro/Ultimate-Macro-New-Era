param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repoRoot = Split-Path -Parent $PSScriptRoot
$dependencies = @(
    @{
        Name = 'Descolada OCR 2.0.0'
        Destination = 'lib/OCR.ahk'
        Url = 'https://raw.githubusercontent.com/Descolada/OCR/15154d1477eb21ade15dc82a62594053face757f/Lib/OCR.ahk'
        GitBlob = '8b143a4df95e4a447389434c4f75017235339a44'
        Sha256 = 'ed348c0be111692c4ffeb9dcc8a9f524c575d48d7f81c8bcd96b882bb7375124'
    },
    @{
        Name = 'thqby JSON 1.0.7'
        Destination = 'lib/JSON.ahk'
        Url = 'https://raw.githubusercontent.com/thqby/ahk2_lib/4d1fe28493bcb665d7fcccce1289ed9a36df4ff0/JSON.ahk'
        GitBlob = 'd384f62d611ffdbd16e4fcfb97fc32ec4e4e41d5'
        Sha256 = '1d215d4acb9c6ac6205c1f586cc0868b72c0d557a77890e89b83a1960c9498e2'
    }
)

function Get-GitBlobHash([string]$Path) {
    $git = Get-Command git -ErrorAction Stop
    $hash = & $git.Source hash-object -- $Path
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($hash)) {
        throw "git hash-object failed for $Path"
    }
    return $hash.Trim().ToLowerInvariant()
}

function Assert-DependencyHash([string]$Path, [hashtable]$Dependency) {
    $actualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    if ($actualSha256 -ne $Dependency.Sha256) {
        throw "SHA-256 verification failed for $($Dependency.Name). Expected $($Dependency.Sha256), got $actualSha256."
    }

    $actualBlob = Get-GitBlobHash $Path
    if ($actualBlob -ne $Dependency.GitBlob) {
        throw "Git blob verification failed for $($Dependency.Name). Expected $($Dependency.GitBlob), got $actualBlob."
    }
}

foreach ($dependency in $dependencies) {
    $destination = Join-Path $repoRoot $dependency.Destination

    if (Test-Path -LiteralPath $destination -PathType Leaf) {
        try {
            Assert-DependencyHash $destination $dependency
            Write-Host "[OK] $($dependency.Name) already matches the pinned source."
            continue
        }
        catch {
            if (-not $Force) {
                throw "$($dependency.Destination) exists but is not the pinned dependency. Review it or rerun with -Force to replace it. $($_.Exception.Message)"
            }
        }
    }

    $parent = Split-Path -Parent $destination
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $temporary = Join-Path ([IO.Path]::GetTempPath()) (
        'ultimate-macro-dependency-' + [guid]::NewGuid().ToString('N') + '.tmp'
    )

    try {
        Write-Host "Downloading $($dependency.Name) from its immutable upstream revision..."
        Invoke-WebRequest -UseBasicParsing -Uri $dependency.Url -OutFile $temporary
        Assert-DependencyHash $temporary $dependency
        Move-Item -LiteralPath $temporary -Destination $destination -Force
        Write-Host "[OK] $($dependency.Destination)"
    }
    finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host 'Pinned source dependencies are synchronized.'
