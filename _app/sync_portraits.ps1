param(
    [Parameter(Mandatory=$true)][string]$CatalogPath,
    [Parameter(Mandatory=$true)][string]$TowerDir,
    [Parameter(Mandatory=$true)][string]$TowerNames,
    [int]$Force = 0
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$wikiRoot = 'https://tds.fandom.com'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36 UltimateMacroStrategyLab/0.5.5'
New-Item -ItemType Directory -Force -Path $TowerDir | Out-Null
$metaDir = Join-Path $TowerDir 'meta'
New-Item -ItemType Directory -Force -Path $metaDir | Out-Null
$logRoot = Join-Path $env:APPDATA 'Ultimate_Macro\StrategyEditor'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$log = Join-Path $logRoot 'standalone-portrait-sync.log'
Add-Type -AssemblyName System.Drawing

function Log([string]$Text) {
    try { Add-Content -LiteralPath $log -Encoding UTF8 -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $Text) } catch {}
}

function Safe-Key([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    return (($Value.Trim().ToLowerInvariant() -replace '[^a-z0-9]+','-').Trim('-'))
}

function Read-Ini([string]$Path) {
    $result = [ordered]@{}
    $section = $null
    foreach ($raw in Get-Content -LiteralPath $Path) {
        $line = $raw.Trim()
        if (!$line -or $line.StartsWith(';') -or $line.StartsWith('#')) { continue }
        if ($line -match '^\[(.+)\]$') {
            $section = $Matches[1].Trim()
            if (!$result.Contains($section)) { $result[$section] = [ordered]@{} }
            continue
        }
        if ($section -and $line -match '^([^=]+)=(.*)$') {
            $result[$section][$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }
    return $result
}

function Invoke-Wiki([hashtable]$Params) {
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($key in $Params.Keys) {
        $parts.Add(([Uri]::EscapeDataString([string]$key) + '=' + [Uri]::EscapeDataString([string]$Params[$key])))
    }
    $parts.Add('format=json')
    $parts.Add('origin=*')
    $url = $wikiRoot + '/api.php?' + ($parts -join '&')
    try {
        return Invoke-RestMethod -UseBasicParsing -Uri $url -Headers @{
            'User-Agent'=$ua; 'Accept'='application/json'; 'Referer'=$wikiRoot + '/'
        } -TimeoutSec 20
    } catch {
        $tmp = Join-Path $env:TEMP ('sle-wiki-' + [guid]::NewGuid().ToString('N') + '.json')
        try {
            & curl.exe -L --fail --silent --show-error --compressed --connect-timeout 12 --max-time 35 `
                -A $ua -e ($wikiRoot + '/') -H 'Accept: application/json' -o $tmp $url
            if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $tmp)) { throw 'Fandom API unavailable.' }
            return ([IO.File]::ReadAllText($tmp) | ConvertFrom-Json)
        } finally {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }
}

function Normalize-FileTitle([string]$Title) {
    if ([string]::IsNullOrWhiteSpace($Title)) { return $null }
    if ($Title.StartsWith('File:')) { return $Title }
    return 'File:' + $Title
}

function Page-Images([string]$Page) {
    try {
        $r = Invoke-Wiki @{action='query';titles=$Page;prop='images';imlimit='max'}
        $out = New-Object System.Collections.Generic.List[string]
        foreach ($po in $r.query.pages.PSObject.Properties.Value) {
            foreach ($img in @($po.images)) {
                if ($img.title) { $out.Add([string]$img.title) }
            }
        }
        return @($out)
    } catch {
        Log "page-images FAIL $Page :: $($_.Exception.Message)"
        return @()
    }
}

function Search-Files([string]$Query) {
    try {
        $r = Invoke-Wiki @{action='query';list='search';srsearch=$Query;srnamespace='6';srlimit='30'}
        $out = New-Object System.Collections.Generic.List[string]
        foreach ($item in @($r.query.search)) {
            if ($item.title) { $out.Add((Normalize-FileTitle([string]$item.title))) }
        }
        return @($out)
    } catch {
        Log "file-search FAIL $Query :: $($_.Exception.Message)"
        return @()
    }
}

function Primary-Image([string]$Page) {
    try {
        $r = Invoke-Wiki @{action='query';titles=$Page;prop='pageimages';piprop='name'}
        foreach ($po in $r.query.pages.PSObject.Properties.Value) {
            if ($po.pageimage) { return Normalize-FileTitle([string]$po.pageimage) }
        }
    } catch {}
    return $null
}

function Original-Url([string]$FileTitle) {
    $ft = Normalize-FileTitle $FileTitle
    if (!$ft) { return $null }
    $r = Invoke-Wiki @{action='query';titles=$ft;prop='imageinfo';iiprop='url'}
    foreach ($po in $r.query.pages.PSObject.Properties.Value) {
        $ii = @($po.imageinfo)
        if ($ii.Count -gt 0 -and $ii[0].url) {
            $u = [string]$ii[0].url
            if ($u.Contains('?')) { return $u + '&format=original' }
            return $u + '?format=original'
        }
    }
    return $null
}

function Get-Candidates([string]$Tower,[string]$Page) {
    $seen = @{}
    $out = New-Object System.Collections.Generic.List[string]

    function Add-Candidate([string]$Title) {
        $normalized = Normalize-FileTitle $Title
        if (!$normalized) { return }
        $key = $normalized.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { return }
        $seen[$key] = $true
        $out.Add($normalized)
    }

    foreach ($title in @(Page-Images $Page)) { Add-Candidate $title }
    foreach ($title in @(Page-Images ($Page + '/Gallery'))) { Add-Candidate $title }

    foreach ($q in @(
        ('"' + $Tower + '" IconIG'),
        ('"Default ' + $Tower + '"'),
        ($Tower + ' IconIG'),
        ($Tower + ' render')
    )) {
        foreach ($title in @(Search-Files $q)) { Add-Candidate $title }
    }

    foreach ($primary in @((Primary-Image $Page),(Primary-Image ($Page + '/Gallery')))) {
        Add-Candidate $primary
    }
    return @($out)
}

function Rank-Candidates([string]$Tower,[string[]]$Titles) {
    $golden = $Tower -match '^(?i)Golden\s+'
    $towerFull = ($Tower -replace '[^A-Za-z0-9]','').ToLowerInvariant()
    $towerBase = (($Tower -replace '^(?i)Golden\s+','') -replace '[^A-Za-z0-9]','').ToLowerInvariant()

    $ranked = foreach ($title in $Titles) {
        $name = $title -replace '^File:',''
        $flat = ($name -replace '[^A-Za-z0-9]','').ToLowerInvariant()
        $score = 0
        $hasDefault = $name -match '(?i)default'
        $hasIconIG = $name -match '(?i)icon\s*ig|iconig'
        $hasGolden = $name -match '(?i)golden'

        if ($flat.Contains($towerFull)) { $score += 260 }
        elseif ($flat.Contains($towerBase)) { $score += 180 }

        if ($hasIconIG) { $score += 420 }
        if ($hasDefault) { $score += 220 }
        if ($hasDefault -and $hasIconIG) { $score += 520 }
        if ($name -match '(?i)render|portrait|dynamic|static') { $score += 120 }
        if ($name -match '(?i)\.png$') { $score += 55 }
        elseif ($name -match '(?i)\.jpe?g$') { $score += 20 }

        if ($golden) {
            if ($hasGolden) { $score += 330 }
        } elseif ($hasGolden) {
            $score -= 650
        }

        if ($name -match '(?i)old|legacy|unused|outdated|deprecated|beta|concept|development') { $score -= 500 }
        if (!$golden -and $name -match '(?i)skin|crate|plushie|neko|bunny|ducky|pirate|galactic|prime|mage|fallen|blazing|loader|rudolph|lovestriker') { $score -= 360 }
        if ($name -match '(?i)weapon|fist|gun|sound|voice|theme|ost|ogg|gif|emoji|badge|banner|face|ability|upgrade|level[1-9]|arrow|divider|line|button|ui') { $score -= 430 }
        if ($name -match '(?i)thumbnail|promotional|trailer|gameicon|game icon') { $score -= 220 }

        [pscustomobject]@{Title=(Normalize-FileTitle $title);Name=$name;Score=$score}
    }

    return @($ranked | Sort-Object Score -Descending)
}

function Image-Kind([string]$Path) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    $b = [IO.File]::ReadAllBytes($Path)
    if ($b.Length -ge 8 -and $b[0]-eq 0x89 -and $b[1]-eq 0x50 -and $b[2]-eq 0x4E -and $b[3]-eq 0x47) { return 'png' }
    if ($b.Length -ge 3 -and $b[0]-eq 0xFF -and $b[1]-eq 0xD8 -and $b[2]-eq 0xFF) { return 'jpg' }
    if ($b.Length -ge 2 -and $b[0]-eq 0x42 -and $b[1]-eq 0x4D) { return 'bmp' }
    if ($b.Length -ge 12 -and $b[0]-eq 0x52 -and $b[1]-eq 0x49 -and $b[2]-eq 0x46 -and $b[3]-eq 0x46 -and
        $b[8]-eq 0x57 -and $b[9]-eq 0x45 -and $b[10]-eq 0x42 -and $b[11]-eq 0x50) { return 'webp' }
    return ''
}

function Download-Image([string]$Url,[string]$Target) {
    Remove-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Target -Headers @{
            'User-Agent'=$ua;'Accept'='image/png,image/jpeg,image/bmp,*/*;q=0.1';'Referer'=$wikiRoot + '/'
        } -TimeoutSec 35 | Out-Null
    } catch {
        & curl.exe -L --fail --silent --show-error --compressed --connect-timeout 12 --max-time 45 `
            -A $ua -e ($wikiRoot + '/') -H 'Accept: image/png,image/jpeg,image/bmp,*/*;q=0.1' -o $Target $Url
        if ($LASTEXITCODE -ne 0) { throw 'Image download failed.' }
    }
    if (!(Test-Path -LiteralPath $Target) -or (Get-Item -LiteralPath $Target).Length -lt 200) { throw 'Downloaded portrait was empty.' }
    if ((Image-Kind $Target) -eq 'webp') {
        Remove-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
        & curl.exe -L --fail --silent --show-error --compressed --connect-timeout 12 --max-time 45 `
            -A $ua -e ($wikiRoot + '/') -H 'Accept: image/png,image/jpeg,image/bmp,*/*;q=0.01' `
            -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' -o $Target $Url
        if ($LASTEXITCODE -ne 0) { throw 'Original-image retry failed.' }
        if ((Image-Kind $Target) -eq 'webp') {
            Log 'Fandom kept WebP after original-format retry; WebView2 fallback may be used.'
        }
    }
}

function Get-VisualInfo([string]$Path) {
    $img = [System.Drawing.Image]::FromFile($Path)
    $preview = $null
    $g = $null
    try {
        if ($img.Width -lt 32 -or $img.Height -lt 32) { return [pscustomobject]@{Valid=$false;Reason='source too small';Width=$img.Width;Height=$img.Height} }
        $ratio = $img.Width / [double]$img.Height
        if ($ratio -lt 0.24 -or $ratio -gt 4.2) { return [pscustomobject]@{Valid=$false;Reason=('extreme aspect ratio ' + [Math]::Round($ratio,2));Width=$img.Width;Height=$img.Height} }

        $canvas = 128
        $preview = [System.Drawing.Bitmap]::new($canvas,$canvas,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($preview)
        $g.Clear([System.Drawing.Color]::Transparent)
        $scale = [Math]::Min($canvas/[double]$img.Width,$canvas/[double]$img.Height)
        $dw = [Math]::Max(1,[int][Math]::Round($img.Width*$scale))
        $dh = [Math]::Max(1,[int][Math]::Round($img.Height*$scale))
        $dx = [int][Math]::Floor(($canvas-$dw)/2)
        $dy = [int][Math]::Floor(($canvas-$dh)/2)
        $g.DrawImage($img,$dx,$dy,$dw,$dh)

        $minX=$canvas; $minY=$canvas; $maxX=-1; $maxY=-1; $visible=0
        for ($y=0; $y -lt $canvas; $y+=2) {
            for ($x=0; $x -lt $canvas; $x+=2) {
                $a = $preview.GetPixel($x,$y).A
                if ($a -gt 20) {
                    $visible++
                    if ($x -lt $minX) {$minX=$x}; if ($x -gt $maxX) {$maxX=$x}
                    if ($y -lt $minY) {$minY=$y}; if ($y -gt $maxY) {$maxY=$y}
                }
            }
        }
        if ($visible -lt 24 -or $maxX -lt $minX -or $maxY -lt $minY) { return [pscustomobject]@{Valid=$false;Reason='almost empty/transparent';Width=$img.Width;Height=$img.Height} }
        $bboxW = ($maxX-$minX+2)/[double]$canvas
        $bboxH = ($maxY-$minY+2)/[double]$canvas
        if ($bboxW -lt 0.10 -or $bboxH -lt 0.10) { return [pscustomobject]@{Valid=$false;Reason=('visible content too thin ' + [Math]::Round($bboxW,2) + 'x' + [Math]::Round($bboxH,2));Width=$img.Width;Height=$img.Height} }
        return [pscustomobject]@{Valid=$true;Reason='ok';Width=$img.Width;Height=$img.Height;VisibleW=$bboxW;VisibleH=$bboxH}
    } finally {
        if ($g) {$g.Dispose()}
        if ($preview) {$preview.Dispose()}
        if ($img) {$img.Dispose()}
    }
}

function Test-Portrait([string]$Path) {
    try {
        if (!(Test-Path -LiteralPath $Path -PathType Leaf) -or (Get-Item -LiteralPath $Path).Length -lt 300) { return $false }
        $kind = Image-Kind $Path
        if ($kind -eq 'webp') {
            return (Get-Item -LiteralPath $Path).Length -ge 1000
        }
        if ($kind -notin @('png','jpg','bmp')) { return $false }
        $info = Get-VisualInfo $Path
        return [bool]$info.Valid
    } catch { return $false }
}

function Save-Optimized([string]$Source,[string]$Target) {
    $img = [System.Drawing.Image]::FromFile($Source)
    $bmp = $null
    $g = $null
    $tmpOut = $Target + '.tmp.png'
    try {
        $canvas = 256
        $pad = 10
        $usable = $canvas - 2*$pad
        $scale = [Math]::Min($usable/[double]$img.Width,$usable/[double]$img.Height)
        $w = [Math]::Max(1,[int][Math]::Round($img.Width*$scale))
        $h = [Math]::Max(1,[int][Math]::Round($img.Height*$scale))
        $x = [int][Math]::Floor(($canvas-$w)/2); $y=[int][Math]::Floor(($canvas-$h)/2)
        $bmp = [System.Drawing.Bitmap]::new($canvas,$canvas,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.DrawImage($img,$x,$y,$w,$h)
        Remove-Item -LiteralPath $tmpOut -Force -ErrorAction SilentlyContinue
        $bmp.Save($tmpOut,[System.Drawing.Imaging.ImageFormat]::Png)
        if (!(Test-Portrait $tmpOut)) { throw 'Optimized portrait failed visual validation.' }
        Move-Item -LiteralPath $tmpOut -Destination $Target -Force
    } finally {
        if ($g) {$g.Dispose()}
        if ($bmp) {$bmp.Dispose()}
        if ($img) {$img.Dispose()}
        Remove-Item -LiteralPath $tmpOut -Force -ErrorAction SilentlyContinue
    }
}

function Write-Meta([string]$Key,[string]$Tower,[string]$SourceTitle) {
    $path = Join-Path $metaDir ($Key + '.ini')
    $body = @"
[Portrait]
CacheVersion=2
Tower=$Tower
SourceTitle=$SourceTitle
Validated=1
UpdatedAt=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@
    [IO.File]::WriteAllText($path,$body,(New-Object Text.UTF8Encoding($false)))
}

try {
    if (!(Test-Path -LiteralPath $CatalogPath -PathType Leaf)) { throw 'Tower catalog missing.' }
    $ini = Read-Ini $CatalogPath

    $index = @{}
    foreach ($section in $ini.Keys) {
        $entry = $ini[$section]
        $index[(Safe-Key $section)] = $section
        if ($entry.Contains('display')) { $index[(Safe-Key ([string]$entry['display']))] = $section }
        if ($entry.Contains('aliases')) {
            foreach ($a in ([string]$entry['aliases']).Split('|')) {
                $k = Safe-Key $a
                if ($k) { $index[$k] = $section }
            }
        }
    }

    $success = 0
    $requested = @($TowerNames.Split('|') | ForEach-Object {$_.Trim()} | Where-Object {$_} | Select-Object -Unique)
    foreach ($tower in $requested) {
        $key = Safe-Key $tower
        $section = if ($index.ContainsKey($key)) {[string]$index[$key]} else {$tower}
        $entry = if ($ini.Contains($section)) {$ini[$section]} else {$null}
        $page = if ($entry -and $entry.Contains('wikiPage')) {[string]$entry['wikiPage']} else {$tower}
        $base = Join-Path $TowerDir $key
        $target = $base + '.png'

        if (!$Force) {
            $existing = @('.png','.jpg','.jpeg','.bmp','.webp') | ForEach-Object {$base + $_} | Where-Object {Test-Path -LiteralPath $_ -PathType Leaf} | Select-Object -First 1
            if ($existing) {
                if (Test-Portrait $existing) {
                    $success++; Log "portrait CACHE $tower -> $existing"; continue
                }
                Log "portrait INVALID CACHE $tower -> $existing; replacing"
                Remove-Item -LiteralPath $existing -Force -ErrorAction SilentlyContinue
            }
        }

        $download = $base + '.download'
        try {
            $candidates = @(Get-Candidates $tower $page)
            $ranked = @(Rank-Candidates $tower $candidates)
            $chosen = $null
            $finalPath = $null
            $attempts = 0
            foreach ($candidate in $ranked) {
                if ($attempts -ge 12) { break }
                if ($candidate.Score -lt 40 -and $attempts -gt 0) { break }
                $attempts++
                try {
                    $url = Original-Url $candidate.Title
                    if (!$url) { throw 'no original URL' }
                    Download-Image $url $download
                    $kind = Image-Kind $download

                    if ($kind -eq 'webp') {
                        if ($candidate.Score -lt 500) { throw 'WebP fallback rejected because candidate confidence is too low.' }
                        $webpTarget = $base + '.webp'
                        Move-Item -LiteralPath $download -Destination $webpTarget -Force
                        if (!(Test-Portrait $webpTarget)) { throw 'WebP fallback file was not usable.' }
                        $finalPath = $webpTarget
                    } else {
                        if (!(Test-Portrait $download)) {
                            $info = $null
                            try {$info = Get-VisualInfo $download} catch {}
                            $why = if ($info) {[string]$info.Reason} else {'visual validation failed'}
                            throw $why
                        }
                        Save-Optimized $download $target
                        $finalPath = $target
                    }

                    $chosen = [string]$candidate.Title
                    break
                } catch {
                    Log ("portrait candidate REJECT " + $tower + " <- " + $candidate.Title + " score=" + $candidate.Score + " :: " + $_.Exception.Message)
                } finally {
                    Remove-Item -LiteralPath $download -Force -ErrorAction SilentlyContinue
                }
            }

            if (!$chosen -or !$finalPath -or !(Test-Portrait $finalPath)) { throw "No validated portrait candidate found for '$tower' (wiki page '$page')." }
            foreach ($ext in @('.png','.jpg','.jpeg','.bmp','.webp')) {
                $variant = $base + $ext
                if ($variant -ne $finalPath) { Remove-Item -LiteralPath $variant -Force -ErrorAction SilentlyContinue }
            }
            Write-Meta $key $tower $chosen
            $success++
            Log "portrait OK $tower <- $chosen"
        } catch {
            Log ("portrait FAIL " + $tower + " :: " + $_.Exception.Message)
        } finally {
            Remove-Item -LiteralPath $download -Force -ErrorAction SilentlyContinue
        }
    }

    if ($success -lt 1 -and $requested.Count -gt 0) { exit 2 }
    exit 0
} catch {
    Log ("SYNC ERROR :: " + $_.Exception.ToString())
    exit 3
}
