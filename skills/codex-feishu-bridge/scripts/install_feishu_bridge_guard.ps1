param(
  [string] $ConfigPath = ".\runtimes.json",
  [string] $TaskName = "CodexFeishuBridgeGuard",
  [int] $IntervalSeconds = 60,
  [switch] $RunNow
)

$ErrorActionPreference = "Stop"

$SupervisorScript = (Resolve-Path (Join-Path $PSScriptRoot "feishu_bridge_guard_supervisor.ps1")).Path
$GuardScript = (Resolve-Path (Join-Path $PSScriptRoot "feishu_bridge_guard.ps1")).Path
$PowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
$ResolvedConfigPath = (Resolve-Path $ConfigPath).Path
$Argument = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$SupervisorScript`" -GuardScript `"$GuardScript`" -ConfigPath `"$ResolvedConfigPath`" -Loop -IntervalSeconds $IntervalSeconds"

function Install-StartupFallback {
  $startupDir = [Environment]::GetFolderPath("Startup")
  New-Item -ItemType Directory -Force -Path $startupDir | Out-Null
  $cmdPath = Join-Path $startupDir "$TaskName.cmd"
  $cmd = @"
@echo off
start "" "$PowerShell" $Argument
"@
  Set-Content -LiteralPath $cmdPath -Value $cmd -Encoding ASCII
  Write-Output "installed startup fallback: $cmdPath"
}

function Install-RunFallback {
  $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
  New-Item -Path $runKey -Force | Out-Null
  New-ItemProperty -Path $runKey -Name $TaskName -Value "`"$PowerShell`" $Argument" -PropertyType String -Force | Out-Null
  Write-Output "installed HKCU Run fallback: $TaskName"
}

try {
  $action = New-ScheduledTaskAction -Execute $PowerShell -Argument $Argument
  $trigger = New-ScheduledTaskTrigger -AtLogOn
  $settings = New-ScheduledTaskSettingsSet `
    -MultipleInstances IgnoreNew `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Seconds 0)

  Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Keep local Codex Feishu bridge runtimes alive." `
    -Force | Out-Null
  Write-Output "installed scheduled task: $TaskName"
} catch {
  Write-Output "scheduled task install failed: $($_.Exception.Message)"
  Install-StartupFallback
  Install-RunFallback
}

if ($RunNow) {
  Start-Process -FilePath $PowerShell -ArgumentList $Argument -WindowStyle Hidden | Out-Null
  Write-Output "started supervisor process"
}
