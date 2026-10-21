When a task needs an API key, token, password, credential, private key, or other secret from the user, use `ez-secret`; never ask for it in chat.
Run `ez-secret --help` once for flags, destinations, and exit-code handling.
Keep the shell tool's timeout longer than `--timeout` and wait for completion.
After storage, reference only the destination; never read or print the value.
