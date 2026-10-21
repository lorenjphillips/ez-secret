<h1 align="center">ez-secret</h1>
<p align="center">Let AI coding agents ask you for API keys and passwords without ever seeing them.</p>
<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-555555?style=flat-square" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.9%2B-F05138?style=flat-square" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/license-MIT-426B8A?style=flat-square" alt="MIT license">
  <img src="https://img.shields.io/badge/dependencies-zero-527A55?style=flat-square" alt="Zero dependencies">
</p>
<p align="center"><picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/panel-dark.png">
    <img src=".github/assets/panel-light.png" alt="ez-secret macOS popup asking for an API key" width="380">
</picture></p>

Your agent runs one command. A native macOS popup asks you for the secret and saves it straight to a `.env` file, a file, or the Keychain. The agent only gets back metadata, never the value. Works with Claude Code, Codex, Cursor and any agent that can run a shell command.

- Secret values never appear on stdout.
- Atomic file writes with mode `0600`.
- Apple frameworks only; no network.

## Install

Requires macOS 14+ and Swift 5.9+.

```sh
git clone https://github.com/lorenjphillips/ez-secret.git
cd ez-secret
swift build -c release
mkdir -p ~/.local/bin
install -m 0755 .build/release/ez-secret ~/.local/bin/ez-secret
```

## Usage

```sh
ez-secret --label "API token" --env-file .env --key API_TOKEN
ez-secret --label "API token" --file ~/.api-token
ez-secret --label "API token" --keychain-service my-app --keychain-account default
```

Timeout defaults to 120 seconds (minimum 15). Set `EZ_SECRET_TIMEOUT` to change the default; `--timeout` overrides it. Both require an integer ≥ 15, otherwise exit 2.

Full flag list: `ez-secret --help`. Try it with a fake password: `scripts/demo.sh`.

## Output

Success prints one stdout line: `stored: <destination>, length: <n>, sha256-prefix: <8 hex>`.
Cancellation prints `cancelled`; timeout prints `timeout`. Errors go to stderr.
Exit codes: **0** stored · **1** cancelled · **2** usage error · **3** validation failed · **4** timeout · **5** no GUI session · **6** write/Keychain error.

## Agents

Install the [skill](skills/ez-secret/SKILL.md) from this checkout; keep it in place:

```sh
mkdir -p ~/.claude/skills ~/.codex/skills
ln -s "$PWD/skills/ez-secret" ~/.claude/skills/ez-secret
ln -s "$PWD/skills/ez-secret" ~/.codex/skills/ez-secret
```

Or copy the [instructions](snippets/AGENTS.md) into your `AGENTS.md` or `CLAUDE.md`.

## License

[MIT](LICENSE).
