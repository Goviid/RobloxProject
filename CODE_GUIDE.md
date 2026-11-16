# Skulls & Roses — Complete Code & Architecture Guide

Welcome to the **Skulls & Roses** project codebase! This document breaks down the entire project structure file by file, explaining what each section does and how the pieces communicate.

---

## 🗺️ Project Architecture Overview

The game follows a **Server-Authoritative** model to prevent cheating in a game where bluffing and hidden cards are central.

```
F:\RobloxProject\
├── CODE_GUIDE.md                  <-- You are here (Living architectural reference)
├── default.project.json           <-- Rojo mapping config (maps files into Studio)
├── src/
│   ├── shared/                    <-- ReplicatedStorage.Shared (Code accessible by both Server and Client)
│   │   ├── Constants.luau         <-- Rules, timers, player count constraints
│   │   ├── Enums.luau             <-- Game states, card types, and player actions
│   │   └── Network.luau           <-- RemoteEvents & RemoteFunctions
│   │
│   ├── server/                    <-- ServerScriptService.Server (Runs strictly on the Roblox Server)
│   │   ├── init.server.luau       <-- Server entry point & player join/leave hooks
│   │   ├── TableBuilder.luau      <-- Builds 3D table arena, standing floor pads, and bot avatars
│   │   ├── Card3DManager.luau     <-- Spawns and flips physical 3D cards/coasters on the table
│   │   ├── PlayerManager.luau     <-- Secret hands, played stacks, scores, seats, bot data
│   │   ├── BotController.luau     <-- AI decision making (bluffing, bidding, revealing)
│   │   └── RoundManager.luau      <-- State machine enforcing all Skull & Roses rules
│   │
│   └── client/                    <-- StarterPlayerScripts.Client (Runs on each player's computer)
│       ├── init.client.luau       <-- Client bootstrapper & network listeners
│       ├── CameraController.luau  <-- 2.5D fixed tabletop camera (LOCOfficial style)
│       └── UI/                    <-- Modular 2D tabletop interface (Theme A: Calavera)
│           ├── StatusBar.luau     <-- Top-right status strip: phase, whose turn, the one turn timer
│           ├── Toast.luau         <-- Short queued event pop-ups above the hand
│           ├── HandBar.luau       <-- Your hand at the bottom, with hover lift
│           ├── ActionBar.luau     <-- Bottom-right panel: only the actions you can take now
│           ├── CardRevealModal.luau<-- Center animated card flip popup (Rose vs Skull)
│           └── CardAnimation.luau <-- Flying card trajectory animation (hand to table)
```

---

## 📂 Detailed File-by-File Breakdown

---

### 1. Shared Modules (`src/shared/`)

#### `Constants.luau`
* **Purpose:** Single source of truth for all game settings, balance numbers, and layout angles.
* **`MIN_PLAYERS / MAX_PLAYERS`**: `2` and `4` (the 3D table has 4 seats).
* **`ENABLE_BOTS`**: Lets the lobby host fill empty seats with bots (on by default, so a solo Studio test plays against 3 bots).
* **`LOBBY_COUNTDOWN = 5`**: Seconds between everyone being ready and the match starting.
* **`POINTS_TO_WIN = 2`**: Standard Skull rule — first player to win 2 rounds wins the whole match.
* **`ROSES_PER_PLAYER = 3` & `SKULLS_PER_PLAYER = 1`**: Starting hand configuration (4 cards total).
* **`TURN_TIMEOUT = 30`**: Seconds allowed per turn (including the skull-penalty pick) before the game takes an automatic action so games never freeze.
* **`MATCH_OVER_DELAY = 30`**: How long the winner screen stays up before a new match starts.
* **`BOT_THINK_DELAY = 3`**: Seconds a bot waits before acting, so humans can follow along.
* **`SEAT_DISTRIBUTIONS`**: Legacy radial seat angles (unused since the 3D table took over seating).

#### `Enums.luau`
* **Purpose:** Centralized dictionary of constants to avoid typos and keep states consistent.
* **`CardType`**: `Rose`, `Skull`, `Unknown` (client placeholder for hidden cards).
* **`GameState`**: `Lobby` &rarr; `Placement` &rarr; `Bidding` &rarr; `Revealing` &rarr; (`Discarding` on a skull hit) &rarr; `RoundEnd` &rarr; `MatchEnd`.
* **`PlayerAction`**: Commands sent by players through `Network.SubmitAction`: `PlaceCard`, `StartBid`, `RaiseBid`, `Pass`, `RevealCard`, `DiscardCard` (`{ cardType }` on own skull, `{ index }` for a blind pick).

#### `CardArt.luau`
* **Purpose:** The 8 card art sets (back / skull / rose image IDs, display name, accent colour). `CardArt.Face(setId, cardType)`, `CardArt.Back(setId)`.
* Each player is dealt a random, unique set at match start (`PlayerManager.AssignCardSets`, called from `RoundManager.StartMatch`) and it replicates as `cardSet` in the client state. The set is public; card faces are only applied to a 3D card at reveal time.
* Source art: `Artwork assets/Cards` (8 sheets); cropped 512×512 round PNGs in `Artwork assets/Cards/cropped`.

#### `Network.luau`
* **Purpose:** Manages RemoteEvents and RemoteFunctions automatically in `ReplicatedStorage`.
* **Server &rarr; Client Events:** `GameStateChanged`, `CardPlayed`, `BidUpdated`, `CardRevealed`, `CardLost` (sent only to the penalised challenger, with the card type they lost), `Notification`, `GameOver`, `LobbyState` (`{ inLobby, hostId, addBots, seats, waitingCount, countdown, canStart }`). `GameStateChanged` also carries `isSeated` (false = waiting for the next match) and `discard = { chooserId, victimId, isOwnSkull, cardCount, cards? }` during `Discarding`; `cards` is only sent to a challenger choosing among their own cards.
* **Client &rarr; Server:** `SubmitAction` (function, in-match actions), `RequestState`, `LobbyAction` (`"ToggleReady"`, `"SetAddBots"` host only, `"Start"` host only).

---

### 2. Server Modules (`src/server/`)

#### `TableBuilder.luau`
* **Purpose:** Builds the clean, open 3D tabletop environment with regular bright lighting (LOCOfficial 1-to-1 style).
* **Open Studio Arena:** Clean, spacious warm wood floor (120x120 studs) with a circular center rug and circular mahogany table with rich burgundy felt.
* **Regular Bright Lighting:** Standard Roblox daytime lighting (`Brightness: 2.0`, `ClockTime: 14.0`, `ShadowMap`, natural ambient fill) with zero dark walls or dim gloom.
* **Spawn & Positioning:** Placed an invisible `SpawnLocation` directly at Seat 1 and anchors `HumanoidRootPart` with disabled locomotion so the player never spawns in the middle or slides off.
* **Standing Avatars:** Positions human players and builds stylish custom-suited dummy avatars for bots around the circular table facing inward.
* **Deal Animation:** Fanned hand tokens are only rebuilt when a seat's card count changes; tokens a hand gains (cards returning at round start) fly in from the table centre, staggered by seat. Your own 2D hand does the same via `HandBar.UpdateHand(..., deal)`.
* **Pile Counters (`UpdatePileCount`):** A label beside each pile with the owner's card-back icon and the number of face-down cards. Muted during placement, bold gold during bidding / challenge / card-loss pick, hidden when empty. Clients enlarge it on mouse hover (`HoverScale`).
* **Seat Tags:** Every seat (bots and humans; your own tag is hidden from you) shows name, score pips (`●○ 1/2`), lives as small card shapes (cards left, hand + table) in the player's card colour, an outline gradient from their card colour to gold, and greys out with "ELIMINATED". Driven by `UpdateScore`, `UpdateCardCount(seat, handCount, totalCards)` and `SetEliminated` from `RoundManager.broadcastState`.

#### `Card3DManager.luau`
* **Purpose:** Manages physical oversized 3D cards placed on the table in front of players (LOCOfficial style).
* **3D Physical Stacking:** Spawns physical oversized 3D cylinder cards (2.9 studs wide) on table coasters (3.2 studs wide) in front of each avatar, stacking vertically with rotational jitter.
* **Interactive Flipping:** Equipped with `ClickDetector` so challengers can click physical 3D cards directly on the table.
* **Reveal Animation:** Card lifts +2.5 studs into the air and physically spins 180° to reveal its true face (`🌹 Rose` or `💀 Skull`).
* **Burn (`BurnCard`):** On a skull penalty, a face-down card rises from the challenger's pile, catches fire (Fire + ember particles + glow) and burns away over ~1.6 s. Called from `RoundManager.finishChallengerFailed`; never shows which card was lost.
* **Round Cleanup:** Smooth shrink-and-destroy animation between rounds.

#### `PlayerManager.luau`
* **Purpose:** Handles all player state, seat assignments, scores, and **secret hands**.
* **Anti-Cheat Isolation:** Hands and played stacks are stored only in memory on the server.
* **`GetClientState(forUserId)`:** Strips out secret cards before sending state across the network so no client can peek at face-down cards.

#### `BotController.luau`
* **Purpose:** AI engine for computer players during solo testing.
* **`DecidePlacementAction()`:** 75% chance to play Rose, 25% chance to bluff with a Skull.
* **`DecideBiddingAction()`:** Calculates calculated risk based on its own placed roses and passes when unsafe.
* **`DecideCardToReveal()`:** Flips its own stack first (mandatory rule), then picks an opponent's stack.
* **`DecideDiscard()`:** Skull penalty. Own skull: usually loses a Rose and keeps its Skull (50/50 when down to 1 Rose + Skull). Blind pick from another challenger: random index.

#### `RoundManager.luau`
* **Purpose:** The referee and state machine that runs the match.
* **Phases:** Handles mandatory 1st card placement, bidding ladder, and the reveal phase.
* **Skull Penalties:** A skull hit enters `Discarding`; the chooser (challenger on own skull, otherwise the skull owner) becomes the active player and picks the card via `DiscardCard`. The challenger's cards are shuffled once into `pendingDiscard.cards` so a blind index maps to a hidden card. Then leadership goes to the skull owner (or the challenger on own skull).
* **Turn Timer:** `TURN_TIMEOUT` (30s) with automatic auto-place / auto-pass / random-discard fallback.
* **Match End (`declareMatchWinner`):** Reached by scoring `POINTS_TO_WIN` or by being the last player with cards left. Fires `GameOver(winnerId, reason, duration)`, holds `MatchEnd` for `MATCH_OVER_DELAY`, then resets the match.

#### `LobbyManager.luau`
* **Purpose:** Pre-match lobby. Humans take seats 1–4 while in the lobby; anyone joining mid-match (or when the table is full) waits and spectates. Ready check with `LOBBY_COUNTDOWN`; the host (first joined still present) can force-start and toggle bots. Bots fill empty seats at match start and are removed when the match ends (`RoundManager.SetMatchOverHandler(LobbyManager.EnterLobby)`).
* A player leaving mid-match → `RoundManager.OnPlayerLeft`: the round restarts without them, or the last remaining player wins.

#### `init.server.luau`
* **Purpose:** Bootstrapper that ties the server together.
* Builds the table, binds `SubmitAction` / `RequestState`, and routes player join/leave to `LobbyManager`.

---

### 3. Client Modules (`src/client/`)

#### `CameraController.luau`
* **Purpose:** 3D tabletop over-the-shoulder camera elevated behind Seat 1 framing your avatar, the circular table, and opponent bots (LOCOfficial style).
* **Per-Frame Override Lock:** Binds to `RunService.RenderStepped` above standard camera priority (`Enum.RenderPriority.Camera.Value + 20`), dynamically updating `Workspace.CurrentCamera` to prevent Roblox engine hijacking.
* **Cinematic Framing:** Frames the local player's back/shoulders at Seat 1 in the foreground (`Vector3.new(0, 7.6, 15.6)`) looking directly across the table (`Vector3.new(0, 3.2, 0.8)`), keeping table coasters, 3D card stacks, and all standing opponent bots in crystal clear view.
* **Dynamic Polish:** Smooth FOV turn punch on active turn and dramatic screen shake on Skull hits. Avatar remains 100% visible with overhead player billboard tag.

#### `Theme.luau` (shared: `src/shared/Theme.luau`)
* **Purpose:** Theme A (Calavera / Day of the Dead) design tokens, shared by the screen UI and server-built 3D labels.
* **Readability rules:** `Theme.TextSize` (nothing below `Min` = 14), `Theme.Outline(label)` for any text over the 3D scene, `Colors.Backing` for floating label pills. New UI takes colours from `Theme.Colors`, not `Color3.fromRGB` literals.
* `init.client.luau` adds a `ScreenScale` UIScale that enlarges the UI on big monitors (1.0–1.5×); code placing GUI at raw screen positions must divide by it.
* Defines the warm wood colors (`TableDark`, `TableSurface`), gold filigree accents (`Gold`, `GoldGlow`), crimson velvet (`RosePrimary`), and obsidian charcoal (`SkullPrimary`).

#### `UI/StatusBar.luau`
* **Purpose:** The only match-status display: one pill in the top-right corner (the top centre stays clear for the far player's 3D name tag; Roblox's player list is hidden to make room) with `ROUND n · PHASE`, whose turn (gold "YOUR TURN" for you), the single turn timer (drain bar under the pill, red in the last 5 s), and one line of context (cards on the table, current bid and bidder, flips so far, or who is choosing a lost card). Hidden in the lobby and on the winner screen.

#### `UI/Toast.luau`
* **Purpose:** Short event pop-ups at the bottom centre, just above the hand, one at a time and queued (max 3; a backed-up queue plays faster). Fed by server `Notification`s that matter (bids, skull hits, timeouts, points, wins, passes) and client messages (rejected actions, "you lost a card"). Routine info messages are not shown.

#### `UI/HandBar.luau`
* **Purpose:** Oversized 2D floating card hand at the bottom of the screen (LOCOfficial style).
* Large, chunky cards (140x195px) with giant 🌹 and 💀 icons, tactile spring hover elevation, and gold glowing selection border.
* Never disappears when count reaches 0—gracefully dims to maintain tactile hand presence.

#### `UI/ActionBar.luau`
* **Purpose:** Bottom-right panel, only on your turn and only with what you can do now: placement hint (+ bid stepper and **BID N** once bidding is allowed), bidding stepper with **RAISE TO N** and **PASS**, and **FLIP MY PILE** / **FLIP ANY PILE** during the challenge. The bid stepper keeps your choice across re-syncs within a turn.

#### `UI/LobbyPanel.luau`
* **Purpose:** Lobby screen rendered from `LobbyState`: seat list with ready status, READY toggle, and host-only BOTS ON/OFF and START buttons.

#### `UI/PhaseOverlay.luau`
* **Purpose:** Round intro card ("ROUND 3 · X starts", shown ~2s when a round's placement begins) and a status pill while not playing (eliminated, or waiting for a seat).

#### `AudioController.luau`
* **Purpose:** All client sound effects, from one `SOUND_CONFIGS` table of verified Audio asset IDs (see `HANDOVER.md` §6.2 for sources and the attribution the card-flip sound needs).
* **Cues (wired in `init.client.luau`):** card place / flip / rose / skull, point scored, victory, your-turn pop, ticks over the last 5 s of your turn and during the lobby countdown, match-start bell, elimination, and an error buzz when the server rejects an action.

#### `CameraController.luau` (per-seat view)
* `SetSeat(seatIndex)` rotates the seat-1 camera setup around the table to face it from the local player's seat (angle taken from `PlayerMat_<seat>`). `init.client.luau` also relabels your own mat "YOUR PILE" and hides your own fanned hand tokens locally.

#### `UI/DiscardModal.luau`
* **Purpose:** Skull penalty picker, shown only to the chooser. Own skull: the challenger's cards face-up, pick one to lose. Someone else's skull: N face-down cards, the skull owner removes one blindly.

#### `UI/CardRevealModal.luau`
* **Purpose:** Center-screen card flip popup.
* Plays an animated card reveal popup whenever a card is flipped by the challenger, showing the card face (`🌹 Rose` or `💥 Skull!`), who owned it, and current bet progress.

#### `UI/CardAnimation.luau`
* **Purpose:** Flying card physics animation (LOCOfficial style).
* Animates cards physically flying from the bottom floating hand dock onto the 3D table stack with an elastic bounce when played. Called from `init.client.luau` when your placement is confirmed (target = your `PlayerMat_<seat>` projected to screen) and when you lose a card to a skull penalty (flies off the top).

#### `init.client.luau`
* **Purpose:** Client entry point. Builds the `ScreenGui`, coordinates all UI components, and binds server events.
