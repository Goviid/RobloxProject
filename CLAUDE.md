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
- Sync with Rojo (`default.project.json`): `src/shared` → ReplicatedStorage.Shared, `src/server` → ServerScriptService.Server, `src/client` → StarterPlayerScripts.Client.
- Work happens on the `claude-assisted` branch. `main` is the stable base (`v1.0-base-game`).

## Checking code (no Studio needed)
- `bash scripts/check.sh` — type-checks `src/` with luau-lsp + Roblox definitions. Add `--lint` to also run selene.
- Run it after every change. Don't introduce new diagnostics; fix existing ones in files you touch.
- Tools are pinned in `rokit.toml` (`rokit install` on a new machine).
- Claude can't playtest. Runtime behaviour (multiplayer, bots, 3D table, UI) must be verified by the user in Studio — say what to test.

## Knowledge graph (Graphify)
- `graphify-out/graph.json` is committed. Use `/graphify query`, `path`, `explain` for cross-module questions.
- After a feature lands, run `/graphify . --update` and commit the graph as a separate commit.

## Known issues (as of 2026-11-15)
- `PlayerManager.DestroyCard` is always called with `nil` from `RoundManager.onChallengerFailed`, so the lost card is random. Players should choose (own skull) / skull owner picks blindly (other's skull).
- `TableBuilder.Build()` takes no args but `init.server.luau` calls `Build("Table")` / `Build("Void")`; there is no real Void mode.
- `CardAnimation.PlayCardFly` works but is never called.
- `scripts/check.sh` reports ~66 pre-existing diagnostics, mostly nil-safety on `FindFirstChild`/`WaitForChild` results (ActionBar, HandBar, Network, Card3DManager, BotController).
