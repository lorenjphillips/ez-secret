#!/bin/zsh
set -u
bin=${EZ_SECRET_BIN:-$(command -v ez-secret || echo ~/.local/bin/ez-secret)}
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

echo "Agent runs: ez-secret --label 'DEMO: type any fake password' --file <tmp>/demo-password --min-length 8 --no-digest --timeout 120"
out=$("$bin" --label "DEMO: type any fake password (e.g. not-a-real-pw), nothing is kept" \
  --file "$dir/demo-password" --min-length 8 --no-digest --timeout 120 "$@")
code=$?

echo "Agent sees stdout: ${out:-<empty>}"
echo "Agent sees exit:   $code"
if [[ -f $dir/demo-password ]]; then
  echo "File on disk:      mode $(stat -f %Lp "$dir/demo-password"), $(stat -f %z "$dir/demo-password") bytes (value not shown)"
fi
echo "Cleaned up $dir"
