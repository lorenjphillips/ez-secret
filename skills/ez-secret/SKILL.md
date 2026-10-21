---
name: ez-secret
description: Use when you need an API key, token, password or other secret from the user, instead of asking them to paste it in chat.
---

Use `ez-secret` to collect secrets from the user; never ask for them in chat.
Run `ez-secret --help` once for flags and exit-code handling.

Choose one destination the consuming program supports:

- `.env`: use `--env-file` and `--key`; ensure the file is gitignored and untracked.
- Raw file: use `--file` for a consumer that accepts a secret file path.
- Keychain: use `--keychain-service` and `--keychain-account` for a Keychain-aware consumer.

For a project that loads a gitignored `.env`:

```sh
ez-secret --label "OpenAI API key for local eval runs" \
  --env-file ./.env --key OPENAI_API_KEY --validate-prefix sk- --timeout 540
```

The command blocks until the user answers; keep the shell tool's timeout longer
than `--timeout` and wait for completion (0 requires an indefinite wait).
After storage, reference the destination; never read the value back into agent
context with `cat`, `echo`, `printenv`, `security -w`, or other value-displaying commands.
