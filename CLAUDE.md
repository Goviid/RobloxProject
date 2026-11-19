# Skulls & Roses — Claude Code notes

Multiplayer bluffing card game for Roblox (2–6 players, human + bots), Day of the Dead / Calavera theme.

## Read first
- `CODE_GUIDE.md` — file-by-file architecture and remote events (keep it updated when modules change)
- `HANDOVER.md` — rules as implemented, game flow, known state
- `IMPLEMENTATION_PLAN.md` — rules, state machine, milestone roadmap

## Hard rules
- Every file is Luau with `--!strict`. Keep it that way; no `--!nonstrict` escapes.
- **Server-authoritative.** Hidden information (hands, stacks, skull positions) lives only on the server. Clients send intents via `src/shared/Network.luau`; the server validates everything. Never trust or send secret state to clients.
- **Zero external dependencies** (no Wally packages). Use Roblox services only.
- Sync with Rojo (`default.project.json`): `src/shared` → ReplicatedStorage.Shared, `src/server` → ServerScriptService.Server, `src/client` → StarterPlayerScripts.Client, `src/first/LoadingScreen.client.luau` → ReplicatedFirst.
- 0.3 work happens on the `v0.3` branch in this folder (`F:\RobloxProject-v0.3`, a git worktree). It started on 2026-11-19 as an exact copy of 0.2.
- 0.2 lives on `claude-assisted` in `F:\RobloxProject` (tag `v0.2-pre-alpha` marks an earlier 0.2 release). `main` is the stable base (`v1.0-base-game`).
- Run `rojo serve` from the folder of the version you're working on (both use port 34872, so only one at a time).
- The earlier, dropped 0.3 prototype (void world, standing avatars) is kept only on the local branch `v0.3-old-prototype`.

## Checking code (no Studio needed)
- `bash scripts/check.sh` — type-checks `src/` with luau-lsp + Roblox definitions. Add `--lint` to also run selene.
- Run it after every change. `bash scripts/check.sh --lint` is clean (0 type diagnostics, 0 selene warnings as of 2026-11-15); keep it that way.
- Tools are pinned in `rokit.toml` (`rokit install` on a new machine).
- Claude can't playtest. Runtime behaviour (multiplayer, bots, 3D table, UI) must be verified by the user in Studio — say what to test.

## Roblox Studio MCP (built-in server, `Roblox_Studio`)
- Connects to whichever place is open in Studio (the "Skulls & Roses" place, synced by Rojo).
- **Never edit scripts through MCP** — Rojo overwrites them. All code changes go through `src/`.
- Use MCP to read the hierarchy, run checks and inspect runtime state. Ask before running anything that changes the place; prefer doing state-changing tests during a playtest.
- The third-party "MCP Server" plugin (Chrrxs `robloxstudio-mcp`) is used by Antigravity. Leave it installed; its `ConnectFail` lines in Output are expected when Antigravity isn't running.

## Knowledge graph (Graphify)
- `graphify-out/graph.json` is committed. **Don't explore by reading every file.** To orient or answer cross-module questions, query the graph first (`python -m graphify query "<question>"`, or `path` / `explain`), then read only the files and line ranges it points to.
- After a feature lands, run `python scripts/graph_update.py` and commit the graph as a separate commit. Don't use plain `graphify update` / `/graphify . --update`: graphify parses `.luau` with the Lua grammar and drops symbols after Luau type syntax. The script feeds it a Lua-compatible copy (line numbers unchanged). `--full` re-extracts everything; `--check` lists files that still fail to parse.

## The 3D world (0.3)
- The rooms live in the place file (`Workspace.World`), not in `src/`. Rojo doesn't touch them. Build or change them with `tools/world/build_world.luau` in Studio (Edit mode), check the view from each seat, then save the place. See CODE_GUIDE "The saved world".
- Floors at Y = 0 and table tops at Y = 3.0 must stay that way: card and seat heights in code depend on it.

## Known issues (as of 2026-11-19)
- Each server runs two tables (`Constants.TABLES`: 4 and 6 seats), picked from the main menu. The small Leave pill (top right) takes a player back to the menu.
