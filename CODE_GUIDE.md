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
│           ├── Theme.luau         <-- Color palette, typography, gold filigree styling
│           ├── NotificationBanner.luau <-- Top announcement banner & 15s turn timer bar
│           ├── HandBar.luau       <-- Floating squircle cards at bottom with hover lift
│           ├── ActionBar.luau     <-- Contextual buttons ([Place Card], [Bid], [Pass])
│           ├── TableView.luau     <-- Circular 2-6 player table with avatar heads & turn halos
│           ├── CardRevealModal.luau<-- Center animated card flip popup (Rose vs Skull)
│           └── CardAnimation.luau <-- Flying card trajectory animation (hand to table)
```

---

## 📂 Detailed File-by-File Breakdown

---

### 1. Shared Modules (`src/shared/`)

#### `Constants.luau`
* **Purpose:** Single source of truth for all game settings, balance numbers, and layout angles.
* **`MIN_PLAYERS / MAX_PLAYERS`**: Set to `2` and `6`.
* **`DEFAULT_TEST_BOTS = 3`**: Automatically generates 3 AI players in Studio so you can test 4-player matches alone.
* **`POINTS_TO_WIN = 2`**: Standard Skull rule — first player to win 2 rounds wins the whole match.
* **`ROSES_PER_PLAYER = 3` & `SKULLS_PER_PLAYER = 1`**: Starting hand configuration (4 cards total).
* **`TURN_TIMEOUT = 15`**: Seconds allowed per turn before the game takes an automatic action (auto-places or auto-passes) so games never freeze.
* **`SEAT_DISTRIBUTIONS`**: Mathematical circle degrees used by `TableView.luau` to arrange player pods radially around the table.

#### `Enums.luau`
* **Purpose:** Centralized dictionary of constants to avoid typos and keep states consistent.
* **`CardType`**: `Rose`, `Skull`, `Unknown` (client placeholder for hidden cards).
* **`GameState`**: `Lobby` &rarr; `Placement` &rarr; `Bidding` &rarr; `Revealing` &rarr; `RoundEnd` &rarr; `MatchEnd`.
* **`PlayerAction`**: Commands sent by players through `Network.SubmitAction`: `PlaceCard`, `StartBid`, `RaiseBid`, `Pass`, `RevealCard`.

#### `Network.luau`
* **Purpose:** Manages RemoteEvents and RemoteFunctions automatically in `ReplicatedStorage`.
* **Server &rarr; Client Events:** `GameStateChanged`, `CardPlayed`, `BidUpdated`, `CardRevealed`, `Notification`, `GameOver`.
* **Client &rarr; Server Function:** `SubmitAction`.

---

### 2. Server Modules (`src/server/`)

#### `TableBuilder.luau`
* **Purpose:** Builds the clean, open 3D tabletop environment with regular bright lighting (LOCOfficial 1-to-1 style).
* **Open Studio Arena:** Clean, spacious warm wood floor (120x120 studs) with a circular center rug and circular mahogany table with rich burgundy felt.
* **Regular Bright Lighting:** Standard Roblox daytime lighting (`Brightness: 2.0`, `ClockTime: 14.0`, `ShadowMap`, natural ambient fill) with zero dark walls or dim gloom.
* **Spawn & Positioning:** Placed an invisible `SpawnLocation` directly at Seat 1 and anchors `HumanoidRootPart` with disabled locomotion so the player never spawns in the middle or slides off.
* **Standing Avatars:** Positions human players and builds stylish custom-suited dummy avatars for bots around the circular table facing inward.

#### `Card3DManager.luau`
* **Purpose:** Manages physical 3D cards placed on the table in front of players (LOCOfficial style).
* **3D Physical Stacking:** Spawns physical 3D round cylinder cards on table coasters in front of each avatar, stacking vertically with rotational jitter.
* **Interactive Flipping:** Equipped with `ClickDetector` so challengers can click physical 3D cards directly on the table.
* **Reveal Animation:** Card lifts +2.2 studs into the air and physically spins 180° to reveal its true face (`🌹 Rose` or `💀 Skull`).
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

#### `RoundManager.luau`
* **Purpose:** The referee and state machine that runs the match.
* **Phases:** Handles mandatory 1st card placement, bidding ladder, and the reveal phase.
* **Skull Penalties:** When a skull is hit, destroys 1 card and passes leadership to the skull owner.
* **Turn Timer:** 15-second timer with automatic auto-place or auto-pass fallback.

#### `init.server.luau`
* **Purpose:** Bootstrapper that ties the server together.
* Connects player join/leave hooks, binds `SubmitAction`, and spawns test bots (*Doña Flor, El Bandido, Don Diego*) for instant solo testing.

---

### 3. Client Modules (`src/client/`)

#### `CameraController.luau`
* **Purpose:** Fixed 2.5D scriptable camera locked above the 3D table (LOCOfficial style).
* **Per-Frame Override Lock:** Binds to `RunService.RenderStepped` above standard camera priority to prevent Roblox's built-in `CameraModule` from hijacking camera control upon character spawn.
* **Cinematic Framing:** Frames the player's back/shoulders at Seat 1, keeping the circular table, all opponent avatars, and 3D card stacks clearly visible.
* **Dynamic Polish:** Smooth FOV turn punch on active turn and dramatic screen shake on Skull hits.

#### `UI/Theme.luau`
* **Purpose:** Theme A (Calavera / Day of the Dead) design tokens.
* Defines the warm wood colors (`TableDark`, `TableSurface`), gold filigree accents (`Gold`, `GoldGlow`), crimson velvet (`RosePrimary`), and obsidian charcoal (`SkullPrimary`).

#### `UI/NotificationBanner.luau`
* **Purpose:** Top-center game announcement banner and animated turn timer bar.
* Features smooth slide/bounce animations and a depleting progress bar for the 15-second turn countdown.

#### `UI/HandBar.luau`
* **Purpose:** Floating squircle card dock at the bottom of the screen (LOCOfficial style).
* Features spring hover elevation, gold glowing borders on selection, and count badges. Dims when placing is not allowed.

#### `UI/ActionBar.luau`
* **Purpose:** Bottom-right contextual action buttons.
* Dynamically switches between `[Place Card]` (during placement), `[Start/Raise Bid]` with a +/- number stepper, and `[Pass]` (during bidding).

#### `UI/TableView.luau`
* **Purpose:** Sleek LOCOfficial Top HUD Status Badge & Compact Player Strip.
* Pinned neatly at the top of the screen to leave the center 3D table completely unobstructed. Shows player names, avatars, stack counts, score gems, and active turn halos.
* Allows challengers to click player pills (or the physical 3D table cards) to reveal cards.

#### `UI/CardRevealModal.luau`
* **Purpose:** Center-screen card flip popup.
* Plays an animated card reveal popup whenever a card is flipped by the challenger, showing the card face (`🌹 Rose` or `💥 Skull!`), who owned it, and current bet progress.

#### `UI/CardAnimation.luau`
* **Purpose:** Flying card physics animation (LOCOfficial style).
* Animates cards physically flying from the bottom floating hand dock onto the 3D table stack with an elastic bounce when played.

#### `init.client.luau`
* **Purpose:** Client entry point. Builds the `ScreenGui`, coordinates all UI components, and binds server events.
