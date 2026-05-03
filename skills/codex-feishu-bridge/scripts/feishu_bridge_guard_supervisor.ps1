param(
  [string] $GuardScript,
  [string] $ConfigPath = ".\runtimes.json",
  [switch] $Loop,
  [switch] $Once,
  [switch] $Status,
  [int] $IntervalSeconds = 60
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($GuardScript)) {
  $GuardScript = Join-Path $PSScriptRoot "feishu_bridge_guard.ps1"
}

function Get-GuardProcesses {
  Get-CimInstance Win32_Process |
    Where-Object {
      $_.Name -eq "powershell.exe" -and
      $_.ProcessId -ne $PID -and
      $_.CommandLine -and
      $_.CommandLine -like "*$GuardScript*" -and
      $_.CommandLine -like "*-Loop*"
    }
}

function Start-GuardLoop {
  $powerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
  Start-Process `
    -FilePath $powerShell `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $GuardScript, "-ConfigPath", $ConfigPath, "-Loop", "-IntervalSeconds", "$IntervalSeconds") `
    -WindowStyle Hidden | Out-Null
  Write-Output "[warn] guard loop started"
}

do {
  if (-not (Test-Path -LiteralPath $GuardScript)) {
    throw "Missing guard script: $GuardScript"
  }

  $guards = @(Get-GuardProcesses)
  if ($guards.Count -eq 0) {
    Start-GuardLoop
    Start-Sleep -Seconds 2
    $guards = @(Get-GuardProcesses)
  }

  if ($Status) {
    $guards | Select-Object ProcessId,Name,CommandLine | Format-Table -Wrap -AutoSize
  }

  if ($Once -or -not $Loop) { break }
  Start-Sleep -Seconds ([Math]::Max(10, $IntervalSeconds))
} while ($true)
