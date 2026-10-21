When a task needs an API key, token, password, credential, private key, or other secret from the user, use `ez-secret`; never ask for it in chat.
Run `ez-secret --help` once for flags, destinations, and exit-code handling.
Timeout defaults to 120 seconds (minimum 15); `EZ_SECRET_TIMEOUT` changes the default and `--timeout` overrides it. Both require an integer ≥ 15, otherwise exit 2.
Keep the shell tool's timeout longer than `--timeout` and wait for completion.
After storage, reference only the destination; never read or print the value.
