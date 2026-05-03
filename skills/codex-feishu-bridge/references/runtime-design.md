# Runtime Design

## Purpose

The bridge turns Feishu or Lark into a remote entrance for local Codex.

```text
Feishu/Lark user message
-> local bridge runtime
-> local Codex app-server
-> bridge reply renderer
-> Feishu/Lark card or message
```

## Recommended Local Topology

- One primary bot for normal conversation and file/media handling.
- One router bot for thread switching.
- Optional extra router bots only when each has isolated state and credentials.
- One guard process for bridge runtimes.
- One supervisor process for the guard.

## Isolation Rules

Each runtime needs its own:

- app credentials
- lock file
- sessions file
- log directory
- workspace ID

Never run two bridge processes against the same Feishu app and the same sessions file.

## Health Signals

Healthy startup logs usually include:

- `client ready`
- `Feishu long connection started`
- `feishu-bot runtime ready`
- `ws client ready`

Healthy runtime state usually includes:

- bridge node process exists
- Codex app-server process exists
- lock file PID is live
- no active fatal provider error

## Known Limits

A user-session guard cannot survive:

- machine power loss
- user not logged in
- disabled Startup and HKCU Run policies
- network outage
- Feishu platform outage
- invalid model provider credentials
- incompatible Codex state database migrations
