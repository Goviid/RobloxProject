#!/usr/bin/env bash
# Type-check and lint all Luau code outside Roblox Studio.
# Usage (from repo root, in Git Bash):  bash scripts/check.sh
# Tools are pinned in rokit.toml — run `rokit install` once on a new machine.
set -u
cd "$(dirname "$0")/.."
export PATH="$HOME/.rokit/bin:$PATH"

DEFS=".luau-types/globalTypes.d.luau"
if [ ! -f "$DEFS" ]; then
	echo "Downloading Roblox type definitions..."
	mkdir -p .luau-types
	curl -fsSL -o "$DEFS" \
		https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau || exit 1
fi

rojo sourcemap default.project.json --output sourcemap.json >/dev/null || exit 1

echo "== luau-lsp (types) =="
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions="$DEFS" src
status=$?

if [ "${1:-}" = "--lint" ]; then
	echo "== selene (lint) =="
	selene src || status=1
fi

exit $status
