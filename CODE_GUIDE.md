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
│   │   ├── PlayerManager.luau     <-- Secret hands, played stacks, scores, seats, bot data
│   │   ├── BotController.luau     <-- AI decision making (bluffing, bidding, revealing)
│   │   └── RoundManager.luau      <-- State machine enforcing all Skull & Roses rules
│   │
│   └── client/                    <-- StarterPlayerScripts.Client (Runs on each player's computer)
│       ├── init.client.luau       <-- Client bootstrapper & network listeners
│       └── UI/                    <-- Modular 2D tabletop interface (Theme A: Calavera)
│           ├── Theme.luau         <-- Color palette, typography, gold filigree styling
│           ├── NotificationBanner.luau <-- Top announcement banner & 15s turn timer bar
│           ├── HandBar.luau       <-- Bottom tray with 4 cards (Roses & Skull)
│           ├── ActionBar.luau     <-- Contextual buttons ([Place Card], [Bid], [Pass])
│           └── TableView.luau     <-- Circular 2-6 player table with stacks & score gems
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

#### `UI/Theme.luau`
* **Purpose:** Theme A (Calavera / Day of the Dead) design tokens.
* Defines the warm wood colors (`TableDark`, `TableSurface`), gold filigree accents (`Gold`, `GoldGlow`), crimson velvet (`RosePrimary`), and obsidian charcoal (`SkullPrimary`).

#### `UI/NotificationBanner.luau`
* **Purpose:** Top-center game announcement banner and animated turn timer bar.
* Features smooth slide/bounce animations and a depleting progress bar for the 15-second turn countdown.

#### `UI/HandBar.luau`
* **Purpose:** Bottom card tray showing your available cards (3 Roses + 1 Skull).
* Features hover elevation (+10px bounce), gold glowing borders on selection, and count badges. Dims when placing is not allowed.

#### `UI/ActionBar.luau`
* **Purpose:** Bottom-right contextual action buttons.
* Dynamically switches between `[Place Card]` (during placement), `[Start/Raise Bid]` with a +/- number stepper, and `[Pass]` (during bidding).

#### `UI/TableView.luau`
* **Purpose:** The 2D tabletop view supporting 2 to 6 players radially.
* Displays player names, stack height (stacked coaster tokens), 2-point score gems, turn highlight glow rings, and clickable stacks for the challenger during the reveal phase.

#### `init.client.luau`
* **Purpose:** Client entry point. Builds the `ScreenGui`, coordinates all UI components, and binds server events.
