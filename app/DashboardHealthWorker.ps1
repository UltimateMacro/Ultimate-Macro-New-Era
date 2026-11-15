param(
  [Parameter(Mandatory = $true)][int]$ParentPid,
  [Parameter(Mandatory = $true)][string]$OutputPath
)

$ErrorActionPreference = 'SilentlyContinue'
$blockedNames = @('System', 'Idle', 'Registry', 'smss', 'csrss', 'wininit', 'services', 'lsass', 'svchost', 'winlogon', 'dwm', 'fontdrvhost')
$processorCount = [Math]::Max(1, [Environment]::ProcessorCount)
$previous = @{}
$previousAt = [DateTime]::UtcNow
$parentProcess = Get-Process -Id $ParentPid -ErrorAction Stop
# Keep this exact process handle; a recycled PID must not keep the worker alive.
[void]$parentProcess.Handle

function Get-ProcessSamples {
  $map = @{}
  foreach ($process in (Get-Process -ErrorAction SilentlyContinue)) {
    if ($process.Id -le 4 -or $process.Id -eq $PID -or $process.Id -eq $ParentPid -or $blockedNames -contains $process.ProcessName) { continue }
    try {
      $start = $process.StartTime.ToLocalTime().ToString('yyyyMMddHHmmss')
      $map[[string]$process.Id] = [pscustomobject]@{
        pid = [int]$process.Id
        name = [string]$process.ProcessName
        cpuSeconds = [double]$process.CPU
        memoryBytes = [long]$process.WorkingSet64
        startedAt = $start
      }
    } catch {}
  }
  return $map
}

function Add-LhmJsonTemperatures {
  param($Node, [string]$HardwarePath, [System.Collections.Generic.List[object]]$Values)
  if ($null -eq $Node -or $Values.Count -ge 4) { return }

  $text = [string]$Node.Text
  $path = "$HardwarePath $text".Trim()
  $isCpuHardware = $path -match '(?i)\bCPU\b|processor|intel.*core|amd.*ryzen|\bryzen\b'
  $isCpuLabel = $text -match '(?i)^CPU\s*(Package|Core)|^Core\s*#?\d+|^Core Max$|Tctl/Tdie|^CCD\d+.*(Temperature|Tctl)'
  if ($Node.Type -eq 'Temperature' -and ($isCpuLabel -or $isCpuHardware -and $text -match '(?i)^Package$|^Core\s*#?\d+|^Core Max$')) {
    $raw = [string]$Node.Value
    if ($raw -match '[-+]?\d+(?:\.\d+)?') {
      $celsius = [double]::NaN
      if ([double]::TryParse($Matches[0], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$celsius) -and $celsius -ge 0 -and $celsius -lt 130) {
        $label = if ($text -match '(?i)^CPU') { $text } elseif ($text -match '(?i)^Core') { "CPU $text" } elseif ($text -match '(?i)^Package') { 'CPU Package' } else { $text }
        $Values.Add([pscustomobject]@{ label = $label; celsius = [Math]::Round($celsius, 1); source = 'LibreHardwareMonitor' })
      }
    }
  }

  foreach ($child in @($Node.Children)) {
    Add-LhmJsonTemperatures -Node $child -HardwarePath $path -Values $Values
    if ($Values.Count -ge 4) { break }
  }
}

function Get-Temperatures {
  $values = [System.Collections.Generic.List[object]]::new()

  # Prefer LibreHardwareMonitor's local JSON API. Recent releases have had
  # broken WMI sensor output, while data.json exposes the live sensor tree.
  try {
    $tree = Invoke-RestMethod -Uri 'http://127.0.0.1:8085/data.json' -TimeoutSec 2 -ErrorAction Stop
    Add-LhmJsonTemperatures -Node $tree -HardwarePath '' -Values $values
  } catch {}

  # Retain compatibility with older LibreHardwareMonitor and OpenHardwareMonitor builds.
  if ($values.Count -eq 0) {
    foreach ($namespace in @('root\LibreHardwareMonitor', 'root\OpenHardwareMonitor')) {
      try {
        $sensors = Get-CimInstance -Namespace $namespace -ClassName Sensor -ErrorAction Stop |
          Where-Object { $_.SensorType -eq 'Temperature' -and $_.Name -match 'CPU Package|CPU Core' -and $_.Value -ge 0 -and $_.Value -lt 130 } |
          Select-Object -First 4
        foreach ($sensor in $sensors) {
          $values.Add([pscustomobject]@{ label = [string]$sensor.Name; celsius = [Math]::Round([double]$sensor.Value, 1); source = 'LibreHardwareMonitor' })
        }
        if ($values.Count -gt 0) { break }
      } catch {}
    }
  }

  return ,$values.ToArray()
}

while ($true) {
  if ($parentProcess.HasExited) { break }
  Start-Sleep -Seconds 15
  if ($parentProcess.HasExited) { break }

  $now = [DateTime]::UtcNow
  $elapsed = [Math]::Max(1, ($now - $previousAt).TotalSeconds)
  $current = Get-ProcessSamples
  $processes = @()
  foreach ($key in $current.Keys) {
    $item = $current[$key]
    $cpu = 0
    if ($previous.ContainsKey($key)) {
      $cpu = [Math]::Max(0, [Math]::Min(100, (($item.cpuSeconds - $previous[$key].cpuSeconds) / ($elapsed * $processorCount)) * 100))
    }
    $processes += [pscustomobject]@{
      pid = $item.pid; name = $item.name; cpuPercent = [Math]::Round($cpu, 1)
      memoryBytes = $item.memoryBytes; startedAt = $item.startedAt
    }
  }
  $previous = $current
  $previousAt = $now

  $cpuPercent = $null
  try {
    $cpuRow = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop | Select-Object -First 1
    $cpuPercent = [Math]::Max(0, [Math]::Min(100, [double]$cpuRow.PercentProcessorTime))
  } catch {}

  $memoryUsed = $null
  $memoryTotal = $null
  try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $memoryTotal = [long]$os.TotalVisibleMemorySize * 1KB
    $memoryUsed = $memoryTotal - ([long]$os.FreePhysicalMemory * 1KB)
  } catch {}

  $gpuPercent = $null
  try {
    $engines = Get-CimInstance -ClassName Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop
    if ($engines) { $gpuPercent = [Math]::Max(0, [Math]::Min(100, [Math]::Round(($engines | Measure-Object UtilizationPercentage -Sum).Sum, 1))) }
  } catch {}

  $top = @($processes | Sort-Object @{Expression='cpuPercent';Descending=$true}, @{Expression='memoryBytes';Descending=$true} | Select-Object -First 8)
  $health = [pscustomobject]@{
    sampledAt = $now.ToString('o')
    cpuPercent = $cpuPercent
    memoryUsedBytes = $memoryUsed
    memoryTotalBytes = $memoryTotal
    gpuPercent = $gpuPercent
    temperatures = (Get-Temperatures)
    processes = $top
  }
  try {
    $json = ConvertTo-Json -InputObject $health -Depth 5 -Compress
    $tempPath = "$OutputPath.tmp"
    [IO.File]::WriteAllText($tempPath, $json, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tempPath -Destination $OutputPath -Force
  } catch {}
}
