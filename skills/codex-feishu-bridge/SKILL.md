---
name: codex-feishu-bridge
description: Use when installing, maintaining, troubleshooting, documenting, or packaging a local Codex bridge for Feishu or Lark robots, including multi-bot routing, workspace/thread binding, attachment intake, runtime guards, Windows startup recovery, privacy scans, and public/private release separation.
---

# Codex Feishu Bridge

Use this skill when the user wants Codex to operate as a local Feishu/Lark bridge maintainer: install the bridge, diagnose bot silence, manage multiple router bots, document runtime topology, add Windows guard processes, or prepare a public/private release bundle.

## Core Model

The bridge is local infrastructure:

```text
Feishu message -> local bridge runtime -> Codex app-server -> local bridge runtime -> Feishu reply
```

Treat Feishu as a remote entrance to local Codex threads. The bridge should not be treated as a cloud service unless the user explicitly deploys one.

## First Checks

1. Identify all bridge runtime roots and their `.env` files.
2. Never print or commit secrets. Mask app IDs, app secrets, API keys, session files, and tokens.
3. Check runtime liveness before editing code:
   - bridge `node ... bin/codex-im.js feishu-bot`
   - Codex `app-server`
   - Feishu WebSocket ready logs
4. Check recent logs for these signatures:
   - `Feishu long connection started`
   - `ws client ready`
   - `runtime ready`
   - `INVALID_API_KEY`
   - `Rate limited`
   - `state_*.sqlite` migration warnings
5. If multiple bots exist, keep each runtime isolated with its own:
   - `CODEX_IM_LOCK_FILE`
   - `CODEX_IM_SESSIONS_FILE`
   - `CODEX_IM_LOG_DIR`
   - `CODEX_IM_DEFAULT_WORKSPACE_ID`

## Runtime Roles

Use clear role boundaries:

- Primary Feishu bot: everyday conversation, files, images, audio, and project tasks.
- Router bot: thread switching and "connect to master" flows.
- Extra router bots: parallel entrances only when each has separate Feishu app credentials and separate local state files.
- Disabled bots: keep out of guard configs and menus until explicitly enabled.

## Guard Pattern

For Windows local operation, prefer a two-layer user-session guard:

- Supervisor keeps the guard process alive.
- Guard keeps enabled bridge runtimes alive.
- Startup and HKCU Run can both launch the supervisor when Task Scheduler is unavailable.

Use the bundled scripts in `scripts/` as a public-safe template:

- `feishu_bridge_guard.ps1`
- `feishu_bridge_guard_supervisor.ps1`
- `install_feishu_bridge_guard.ps1`
- `uninstall_feishu_bridge_guard.ps1`

Use `references/sample-runtimes.json` as the runtime config shape.

## Diagnostics

When a bot stops replying:

1. Check whether the bridge runtime process exists.
2. Check whether its lock file points to a live PID.
3. Check whether the latest log has WebSocket ready lines.
4. Check whether Codex app-server is alive.
5. Check model/API health only after the bridge and app-server are alive.
6. Restart missing bridge runtimes through their own `scripts/start-windows.ps1`, not by hand-building node commands.

Do not assume a Feishu message failed just because Codex did not answer. Common layers are:

- Feishu event not received.
- Bridge runtime down.
- Codex app-server down.
- Model provider returning 401, 402, rate limit, or stream disconnect.
- Current thread still running.
- Sessions or state database mismatch.

## Attachment Handling

For production-like bridge work, require explicit support for:

- images as image inputs or image messages
- audio as supported audio files
- normal files as files
- local cache cleanup
- no absolute-path leak in Feishu replies

If a bridge only receives metadata but not file content, mark it as incomplete for primary-bot usage.

## Thread Hygiene

Thread menus should include durable user-facing threads only. Exclude generated bridge noise such as:

- memory-context prompt threads
- temporary `codex-im-turn-*` folders
- `Reply exactly: BRIDGE_OK`
- smoke-test threads

Do not remove important named master/app threads simply because they have warning markers in the UI.

## Public Release Boundary

Read `references/release-boundary.md` before preparing a public bundle.

Public packages may include:

- sanitized README and docs
- generic scripts
- sample configs with placeholders
- tests that use fixtures only

Public packages must not include:

- dot-env files
- real Feishu app IDs or app secrets
- API keys or tokens
- sessions files
- logs
- screenshots
- private memory/wiki contents
- local personal workspace paths
- dependency folders
- generated tarballs unless explicitly intended for release

## References

- `references/runtime-design.md`: architecture and operations model.
- `references/release-boundary.md`: what can and cannot be published.
- `references/sample-runtimes.json`: placeholder runtime config for guard scripts.
