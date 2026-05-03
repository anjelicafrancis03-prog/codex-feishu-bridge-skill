# Public Release Boundary

## Public OK

- Generic bridge architecture.
- Placeholder dot-env example files.
- Generic runtime guard scripts.
- Sanitized troubleshooting notes.
- Fixture-based tests.
- Public README and license.

## Private Only

- Real Feishu app IDs.
- Real Feishu app secrets.
- OpenAI-compatible API keys.
- Provider-specific private endpoints if not meant for public disclosure.
- Sessions files.
- Logs.
- Local user names.
- Local workspace paths.
- Screenshots or chat exports.
- Private note vault or memory bridge content.
- Any package generated from a dirty local runtime without a privacy scan.

## Release Split

Use a public repository for generic bridge and skill code.

Use a private repository, private note, or local-only handoff for:

- actual runtime list
- exact local paths
- app credential mapping
- operating history
- personal maintenance runbooks

## Final Scan Ideas

Search for:

```text
Feishu secret environment variable names
OpenAI-compatible API key environment variable names
OpenAI secret-key prefixes
cli_
dot-env files
sessions
logs
Windows user application-data paths
user home paths
private note vault names
token
secret
```
