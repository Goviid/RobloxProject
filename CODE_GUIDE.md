# Skulls & Roses — Complete Code & Architecture Guide

Welcome to the **Skulls & Roses** project codebase! This document breaks down the entire project structure file by file, explaining what each section does and how the pieces communicate.

---

## 🗺️ Project Architecture Overview

The game follows a **Server-Authoritative** model to prevent cheating in a game where bluffing and hidden cards are central.

```
F:\RobloxProject\
├── CODE_GUIDE.md             <-- You are here (Living architectural reference)
├── default.project.json      <-- Rojo mapping config (maps files into Studio)
├── src/
│   ├── shared/               <-- ReplicatedStorage.Shared (Code accessible by both Server and Client)
│   │   ├── Constants.luau    <-- Rules, timers, player count constraints
│   │   ├── Enums.luau        <-- Game states, card types, and player actions
│   │   └── Network.luau      <-- RemoteEvents & RemoteFunctions
│   │
│   ├── server/               <-- ServerScriptService.Server (Runs strictly on the Roblox Server)
│   │   ├── init.server.luau  <-- Server entry point & player join/leave hooks
│   │   ├── PlayerManager.luau<-- Secret hands, played stacks, scores, seats, bot data
│   │   ├── BotController.luau<-- AI decision making (bluffing, bidding, revealing)
│   │   └── RoundManager.luau <-- State machine enforcing all Skull & Roses rules
│   │
│   └── client/               <-- StarterPlayerScripts.Client (Runs on each player's computer)
│       └── init.client.luau  <-- UIController, Table layout, Hand bar, Action buttons
```

---

## 📂 Detailed File-by-File Breakdown

---

### 1. `src/shared/Constants.luau`
> **Location:** `ReplicatedStorage.Shared.Constants`  
> **Purpose:** Single source of truth for all game settings, balance numbers, and layout angles.

* **`MIN_PLAYERS / MAX_PLAYERS`**: Set to `2` and `6`.
* **`DEFAULT_TEST_BOTS = 3`**: Automatically generates 3 AI players in Studio so you can test 4-player matches alone.
* **`POINTS_TO_WIN = 2`**: Standard Skull rule — first player to win 2 rounds wins the whole match.
* **`ROSES_PER_PLAYER = 3` & `SKULLS_PER_PLAYER = 1`**: Starting hand configuration (4 cards total).
* **`TURN_TIMEOUT = 15`**: Seconds allowed per turn before the game takes an automatic action (auto-places or auto-passes) so games never freeze.
* **`SEAT_DISTRIBUTIONS`**: Mathematical circle degrees used by the client UI to arrange player pods radially around the table.

---

### 2. `src/shared/Enums.luau`
> **Location:** `ReplicatedStorage.Shared.Enums`  
> **Purpose:** Centralized dictionary of constants to avoid typos and keep states consistent.

* **`CardType`**: 
  * `Rose` — Safe flower card.
  * `Skull` — Dangerous trap card.
  * `Unknown` — Placeholder sent to clients for face-down cards to prevent exploiters from peeking.
* **`GameState`**: The 6 phases of the match:
  * `Lobby` &rarr; `Placement` &rarr; `Bidding` &rarr; `Revealing` &rarr; `RoundEnd` &rarr; `MatchEnd`.
* **`PlayerAction`**: Commands sent by players through `Network.SubmitAction`:
  * `PlaceCard`, `StartBid`, `RaiseBid`, `Pass`, `RevealCard`, `DiscardCard`.

---

### 3. `src/shared/Network.luau`
> **Location:** `ReplicatedStorage.Shared.Network`  
> **Purpose:** Sets up and provides typed access to all RemoteEvents and RemoteFunctions.

* **How it works:** When loaded on the server, it creates a `SkullsNetwork` folder in `ReplicatedStorage` and populates it with remotes. When loaded on the client, it waits for that folder.
* **Server &rarr; Client Events:**
  * `GameStateChanged` — Syncs the public table state, current phase, active player, and current bid.
  * `CardPlayed` — Tells everyone a card was added face-down to a player's stack.
  * `BidUpdated` — Announces a new highest bid.
  * `CardRevealed` — Broadcasts the result when a card is flipped during the Reveal phase.
  * `Notification` — Sends banner messages to client screens ("*Doña Flor raised the bid to 3!*").
  * `GameOver` — Fires when a player reaches 2 points.
* **Client &rarr; Server Function:**
  * `SubmitAction` — The single secure channel where players send their choices (`PlaceCard`, `Pass`, etc.).

---

### 4. `src/server/PlayerManager.luau`
> **Location:** `ServerScriptService.Server.PlayerManager`  
> **Purpose:** Handles all player state, seat assignments, scores, and **secret hands**.

* **Anti-Cheat Isolation (`PlayerData.hand` & `PlayerData.playedStack`):**
  * Stored strictly in memory on the server.
  * When a player plays a card, the card type is added to `playedStack` secretly.
* **`AddPlayer()` / `AddBot()`**:
  * Automatically assigns the next available seat (1 through 6).
  * Deals the starting hand (3 Roses + 1 Skull).
* **`DestroyCard(userId)`**:
  * When a challenger hits a skull, this permanently deletes 1 card from their collection.
  * If a player has 0 cards remaining in their hand and stack, sets `isEliminated = true`.
* **`GetClientState(forUserId)`**:
  * Strips out secret cards before sending state across the network!
  * Every player sees how many cards opponents have in their stack, but **only you** receive your own secret cards.

---

### 5. `src/server/BotController.luau`
> **Location:** `ServerScriptService.Server.BotController`  
> **Purpose:** AI engine for computer players during solo testing.

* **`DecidePlacementAction()`**:
  * 75% chance to play a Rose, 25% chance to bluff with a Skull.
  * If a bot has placed 2+ roses on its own pile and no skull, it has a 40% chance to boldly start a bid!
* **`DecideBiddingAction()`**:
  * Counts its own roses. If it didn't place a skull, it calculates a reasonable risk limit and raises the bid.
  * If the bid exceeds its confidence threshold, it passes.
* **`DecideCardToReveal()`**:
  * Enforces the mandatory rule: **A challenger MUST flip all cards in their own stack first.**
  * Once its own stack is clear, it randomly picks an opponent's stack.

---

### 6. `src/server/RoundManager.luau`
> **Location:** `ServerScriptService.Server.RoundManager`  
> **Purpose:** The referee and state machine that runs the match.

* **`StartRound(leaderId)`**:
  * Returns unplayed cards back to hands, resets stacks, and sets the active player to the round leader.
* **Turn Timer & Auto-Pass (`startTurnTimer` & `onTurnTimeout`)**:
  * Starts a 15-second countdown on every turn.
  * If the player does not act, automatically plays a card, passes, or reveals a card so the game keeps moving.
* **`HandlePlayerAction()` — Phase Logic:**
  1. **Placement:** Ensures every player places at least 1 card before bids can start.
  2. **Bidding:** Checks that every new bid is strictly higher than the last and does not exceed the total cards on the table. When all opponents pass, designates the highest bidder as the **Challenger**.
  3. **Revealing:** Flips cards one by one:
     * If a **Skull** is flipped: Triggers `onChallengerFailed()`. The challenger loses 1 card, and the skull owner becomes the next round leader.
     * If a **Rose** is flipped: Checks if the bid target is reached. If yes, awards 1 point and checks for a 2-point match victory!

---

### 7. `src/server/init.server.luau`
> **Location:** `ServerScriptService.Server`  
> **Purpose:** Bootstrapper that ties the server together.

* Binds `Network.SubmitAction.OnServerInvoke` to `RoundManager.HandlePlayerAction`.
* Listens to `Players.PlayerAdded` and `Players.PlayerRemoving`.
* If you test solo in Studio, it automatically calls `spawnTestBots(3)` (*Doña Flor, El Bandido, Don Diego*) and kicks off the first round automatically!

---

## 🚀 What's Coming in Milestone 2 (Client UI)

* `src/client/UI/HandBar.luau` — Interactive 2D cards on the bottom of your screen (clickable 3 Roses + 1 Skull).
* `src/client/UI/TableView.luau` — Table layout showing all player pods, card stacks, and 2-point score coasters.
* `src/client/UI/ActionBar.luau` — Contextual buttons: `[Place Card]`, `[Raise Bid (+1)]`, `[Pass]`.
* `src/client/UI/NotificationBanner.luau` — Animated banner for turn timers and announcements.
