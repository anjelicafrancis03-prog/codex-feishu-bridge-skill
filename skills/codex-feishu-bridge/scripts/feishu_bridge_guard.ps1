param(
  [string] $ConfigPath = ".\runtimes.json",
  [switch] $Loop,
  [switch] $Once,
  [switch] $Status,
  [int] $IntervalSeconds = 60,
  [int] $RetentionDays = 14,
  [int] $MaxLogMb = 10
)

$ErrorActionPreference = "Stop"

function Resolve-ExpandedPath {
  param([string] $PathText)
  return [Environment]::ExpandEnvironmentVariables($PathText)
}

function Read-Config {
  if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Missing runtime config: $ConfigPath"
  }
  return Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
}

function Read-DotEnvValue {
  param([string] $FilePath, [string] $Name)
  if (-not (Test-Path -LiteralPath $FilePath)) { return "" }
  $prefix = "$Name="
  $line = Get-Content -LiteralPath $FilePath -ErrorAction SilentlyContinue |
    Where-Object { $_.StartsWith($prefix) } |
    Select-Object -First 1
  if (-not $line) { return "" }
  return $line.Substring($prefix.Length).Trim().Trim('"').Trim("'")
}

function Test-PidAlive {
  param([int] $PidValue)
  if ($PidValue -le 0) { return $false }
  try {
    Get-Process -Id $PidValue -ErrorAction Stop | Out-Null
    return $true
  } catch {
    return $false
  }
}

function Write-GuardLog {
  param([string] $LogFile, [string] $Level, [string] $Message, [hashtable] $Data = @{})
  $dir = Split-Path -Parent $LogFile
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $entry = [ordered]@{
    time = (Get-Date).ToString("o")
    level = $Level
    message = $Message
  }
  foreach ($key in $Data.Keys) { $entry[$key] = $Data[$key] }
  Add-Content -LiteralPath $LogFile -Value ($entry | ConvertTo-Json -Compress -Depth 8) -Encoding UTF8
  Write-Output "[$Level] $Message"
}

function Rotate-Log {
  param([string] $LogDir, [string] $LogFile)
  New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
  $cutoff = (Get-Date).AddDays(-[Math]::Abs($RetentionDays))
  Get-ChildItem -LiteralPath $LogDir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff } |
    Remove-Item -Force -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $LogFile) {
    $file = Get-Item -LiteralPath $LogFile
    if ($file.Length -gt ([int64]$MaxLogMb * 1024 * 1024)) {
      $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
      Move-Item -LiteralPath $LogFile -Destination (Join-Path $LogDir "guard-$stamp.jsonl") -Force
    }
  }
}

function Get-RuntimeLockFile {
  param($Runtime)
  $root = Resolve-ExpandedPath ([string]$Runtime.root)
  $envPath = Join-Path $root ".env"
  $lockFile = Read-DotEnvValue -FilePath $envPath -Name "CODEX_IM_LOCK_FILE"
  if ([string]::IsNullOrWhiteSpace($lockFile)) {
    return Join-Path $env:USERPROFILE ".codex-im\bridge.lock"
  }
  return Resolve-ExpandedPath $lockFile
}

function Get-RuntimeStatus {
  param($Runtime)
  $root = Resolve-ExpandedPath ([string]$Runtime.root)
  $startScript = Join-Path $root "scripts\start-windows.ps1"
  $pidValue = $null
  $lockFile = ""
  $lockExists = $false
  $alive = $false
  $enabled = [bool]$Runtime.enabled
  $stateName = "missing"

  if (-not $enabled) {
    $stateName = "disabled"
  } elseif (-not (Test-Path -LiteralPath $root)) {
    $stateName = "root-missing"
  } elseif (-not (Test-Path -LiteralPath $startScript)) {
    $stateName = "start-script-missing"
  }

  if ($stateName -in @("disabled", "root-missing", "start-script-missing")) {
    return [pscustomobject]@{
      name = $Runtime.name
      role = $Runtime.role
      enabled = $enabled
      state = $stateName
      root = $root
      startScript = $startScript
      lockFile = $lockFile
      pid = $pidValue
    }
  }

  $lockFile = Get-RuntimeLockFile -Runtime $Runtime
  $lockExists = Test-Path -LiteralPath $lockFile

  if ($lockExists) {
    try {
      $state = Get-Content -LiteralPath $lockFile -Raw | ConvertFrom-Json
      if ($null -ne $state.pid) {
        $pidValue = [int]$state.pid
        $alive = Test-PidAlive -PidValue $pidValue
      }
    } catch {
      $alive = $false
    }
  }

  if ($lockExists -and $alive) {
    $stateName = "running"
  } elseif ($lockExists -and -not $alive) {
    $stateName = "stale-lock"
  }

  [pscustomobject]@{
    name = $Runtime.name
    role = $Runtime.role
    enabled = $enabled
    state = $stateName
    root = $root
    startScript = $startScript
    lockFile = $lockFile
    pid = $pidValue
  }
}

function Invoke-GuardCheck {
  $config = Read-Config
  $logDir = Resolve-ExpandedPath ([string]$config.logDir)
  if ([string]::IsNullOrWhiteSpace($logDir)) {
    $logDir = Join-Path $env:USERPROFILE ".codex-im\guard-logs"
  }
  $logFile = Join-Path $logDir "guard.jsonl"
  Rotate-Log -LogDir $logDir -LogFile $logFile

  $results = @()
  foreach ($runtime in $config.runtimes) {
    $statusObject = Get-RuntimeStatus -Runtime $runtime
    $results += $statusObject

    if (-not $statusObject.enabled -or $statusObject.state -eq "running") {
      continue
    }

    if ($statusObject.state -eq "stale-lock") {
      Remove-Item -LiteralPath $statusObject.lockFile -Force -ErrorAction SilentlyContinue
      Write-GuardLog -LogFile $logFile -Level "warn" -Message "removed stale lock" -Data @{
        name = $statusObject.name
        lockFile = $statusObject.lockFile
      }
    }

    if (@("missing", "stale-lock") -contains $statusObject.state) {
      $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $statusObject.startScript 2>&1 | Out-String
      Write-GuardLog -LogFile $logFile -Level "warn" -Message "runtime start invoked" -Data @{
        name = $statusObject.name
        output = $output.Trim()
      }
    }
  }

  $enabled = @($results | Where-Object { $_.enabled })
  Write-GuardLog -LogFile $logFile -Level "info" -Message "guard check completed" -Data @{
    enabled = $enabled.Count
    running = @($enabled | Where-Object { $_.state -eq "running" }).Count
    disabled = @($results | Where-Object { -not $_.enabled }).Count
  }

  return $results
}

do {
  $results = Invoke-GuardCheck
  if ($Status) {
    $results | Format-Table name, role, enabled, state, pid, lockFile -AutoSize
  }
  if ($Once -or -not $Loop) { break }
  Start-Sleep -Seconds ([Math]::Max(10, $IntervalSeconds))
} while ($true)
