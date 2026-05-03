# codex-feishu-bridge-skill

Skill and companion scripts for operating a local Codex-to-Feishu/Lark bridge.

This package is a public-ready handoff bundle. It does not include real app IDs, app secrets, API keys, sessions, logs, screenshots, or local private workspace data.

## What It Provides

- A Codex skill for installing, maintaining, diagnosing, and documenting a local Feishu/Lark bridge for Codex.
- A generic PowerShell guard that keeps multiple bridge runtimes alive.
- A supervisor that restarts the guard if the guard exits.
- Public references for architecture, privacy boundaries, and release checks.

## Directory

```text
skills/codex-feishu-bridge/
  SKILL.md
  agents/openai.yaml
  scripts/
  references/
docs/articles/
  codex-feishu-bridge-skill-release.md
docs/images/
  codex-feishu-bridge-skill/
```

## Install The Skill

With the Agent Skills CLI:

```powershell
npx skills add https://github.com/anjelicafrancis03-prog/codex-feishu-bridge-skill --skill "codex-feishu-bridge"
```

Or copy `skills/codex-feishu-bridge` into your local Codex skills directory.

## Guard Script Template

Copy and edit the sample config:

```powershell
Copy-Item .\skills\codex-feishu-bridge\references\sample-runtimes.json .\runtimes.json
```

Then run a one-shot status check:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\skills\codex-feishu-bridge\scripts\feishu_bridge_guard.ps1 `
  -ConfigPath .\runtimes.json `
  -Once `
  -Status
```

Install the Windows login guard only after replacing placeholders with your own local bridge runtime paths:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\skills\codex-feishu-bridge\scripts\install_feishu_bridge_guard.ps1 `
  -ConfigPath .\runtimes.json `
  -RunNow
```

## Validate

```powershell
python <codex-home>\skills\.system\skill-creator\scripts\quick_validate.py <repo-root>\skills\codex-feishu-bridge
```

PowerShell syntax check:

```powershell
$files = Get-ChildItem .\skills\codex-feishu-bridge\scripts -Filter *.ps1
foreach ($f in $files) {
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors) > $null
  if ($errors) { throw "$($f.Name) has parse errors" }
}
```

## Privacy

Before publishing, verify that the bundle contains no:

- dot-env files
- dependency folders
- logs
- sessions
- real app IDs or secrets
- API keys or tokens
- private local paths
- screenshots or user chat exports
- packaged build artifacts

## Article Draft

See `docs/articles/codex-feishu-bridge-skill-release.md`.

The article includes sanitized screenshots that show the bridge acting as a near-desktop thread entrance from Feishu/Lark. Thread IDs, local paths, avatars, and attachment previews are redacted.
