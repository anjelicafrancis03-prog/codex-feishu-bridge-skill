param(
  [string] $TaskName = "CodexFeishuBridgeGuard"
)

$ErrorActionPreference = "Stop"

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
  Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
  Write-Output "uninstalled scheduled task: $TaskName"
}

$startupPath = Join-Path ([Environment]::GetFolderPath("Startup")) "$TaskName.cmd"
if (Test-Path -LiteralPath $startupPath) {
  Remove-Item -LiteralPath $startupPath -Force
  Write-Output "removed startup fallback: $startupPath"
}

$runPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
if (Get-ItemProperty -Path $runPath -Name $TaskName -ErrorAction SilentlyContinue) {
  Remove-ItemProperty -Path $runPath -Name $TaskName -Force
  Write-Output "removed HKCU Run fallback: $TaskName"
}
