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
│   ├── first/                     <-- ReplicatedFirst (runs before everything else on the client)
│   │   └── LoadingScreen.client.luau <-- Themed loading screen; hides pop-in until the scene is ready
│   ├── shared/                    <-- ReplicatedStorage.Shared (Code accessible by both Server and Client)
│   │   ├── Constants.luau         <-- Rules, timers, player count constraints
│   │   ├── Enums.luau             <-- Game states, card types, and player actions
│   │   └── Network.luau           <-- RemoteEvents & RemoteFunctions
│   │
│   ├── server/                    <-- ServerScriptService.Server (Runs strictly on the Roblox Server)
│   │   ├── init.server.luau       <-- Table directory: runs one copy of Table/ per table, routes players
│   │   └── Table/                 <-- One game at one table (cloned per table at startup)
│   │       ├── TableContext.luau  <-- Which table this copy is (id, size, origin) and who is at it
│   │       ├── TableBuilder.luau  <-- Builds the 3D table arena, chairs and bot avatars
│   │       ├── Card3DManager.luau <-- Spawns and flips physical 3D cards/coasters on the table
│   │       ├── PlayerManager.luau <-- Secret hands, played stacks, scores, seats, bot data
│   │       ├── BotController.luau <-- AI decision making (bluffing, bidding, revealing)
│   │       ├── LobbyManager.luau  <-- Pre-match lobby: seats, ready check, bots
│   │       └── RoundManager.luau  <-- State machine enforcing all Skull & Roses rules
│   │
│   └── client/                    <-- StarterPlayerScripts.Client (Runs on each player's computer)
│       ├── init.client.luau       <-- Client bootstrapper & network listeners
│       ├── TableView.luau         <-- Which table you joined, its arena and centre
│       ├── CameraController.luau  <-- 2.5D fixed tabletop camera (LOCOfficial style)
│       └── UI/                    <-- Modular 2D tabletop interface (Theme A: Calavera)
│           ├── MainMenu.luau      <-- Title + PLAY, then the table picker
│           ├── UIKit.luau         <-- Shared panel / label / button / row / pop animation for every pop-up
│           ├── StatusBar.luau     <-- Bottom-left status card: phase, whose turn, the one turn timer
│           ├── Toast.luau         <-- Short queued event pop-ups above the hand
│           ├── Hand3D.luau        <-- Your hand as floating 3D cards in front of the camera
│           ├── HandBar.luau       <-- Old 2D hand, no longer used
│           ├── ActionBar.luau     <-- Bottom-right panel: only the actions you can take now
│           ├── CardRevealModal.luau<-- Centre card flip pop-up (Rose vs Skull)
│           ├── DiscardModal.luau  <-- Skull-penalty card picker
│           ├── VictoryModal.luau  <-- Winner screen with countdown and confetti
│           ├── LobbyPanel.luau    <-- Lobby: seats, ready, host bots/start
│           ├── PhaseOverlay.luau  <-- Round intro card and spectating pill
│           └── CardAnimation.luau <-- Flying card trajectory animation (hand to table)
```

---

## 📂 Detailed File-by-File Breakdown

---

### 1. Shared Modules (`src/shared/`)

#### `Constants.luau`
* **Purpose:** Single source of truth for all game settings, balance numbers, and layout angles.
* **`MIN_PLAYERS / MAX_PLAYERS`**: `2` and `6` (`MAX_PLAYERS` is the biggest table; each table's own size is in `TABLES`).
* **`TABLES`**: the tables in every server, shown in the main menu: `Table 1` (4 players) and `Table 2` (6 players). Table N is built `TABLE_SPACING` (300) studs along +X from table 1.
* **`MENU_SPAWN`**: a hidden platform far from the tables where players stand while in the menu.
* **`ENABLE_BOTS`**: Lets the lobby host fill empty seats with bots (on by default, so a solo Studio test plays against 3 bots).
* **`LOBBY_COUNTDOWN = 5`**: Seconds between everyone being ready and the match starting.
* **`POINTS_TO_WIN = 2`**: Standard Skull rule — first player to win 2 rounds wins the whole match.
* **`ROSES_PER_PLAYER = 3` & `SKULLS_PER_PLAYER = 1`**: Starting hand configuration (4 cards total).
* **`TURN_TIMEOUT = 30`**: Seconds allowed per turn (including the skull-penalty pick) before the game takes an automatic action so games never freeze.
* **`MATCH_OVER_DELAY = 30`**: How long the winner screen stays up before a new match starts.
* **`BOT_THINK_DELAY = 3`**: Seconds a bot waits before acting, so humans can follow along.

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
* **Server &rarr; Client Events:** `GameStateChanged`, `CardPlayed`, `BidUpdated`, `CardRevealed`, `CardLost` (sent only to the penalised challenger, with the card type they lost), `Notification`, `GameOver`, `LobbyState` (`{ inLobby, hostId, addBots, seats, maxSeats, waitingCount, countdown, canStart }`), `TableList` (for the menu: `{ id, name, seated, maxPlayers, inMatch }` per table). Every table shares these remotes, so table code sends to its own table's players only (`TableContext.FireAll`), never `FireAllClients`. `GameStateChanged` also carries `isSeated` (false = waiting for the next match) and `discard = { chooserId, victimId, isOwnSkull, cardCount, cards? }` during `Discarding`; `cards` is only sent to a challenger choosing among their own cards.
* **Client &rarr; Server:** `SubmitAction` (function, in-match actions), `RequestState`, `LobbyAction` (`"ToggleReady"`, `"SetAddBots"` host only, `"Start"` host only), `JoinTable` (`tableId`, from the menu), `LeaveTable`, `RequestTables`, `SetCharacterLook` (`"classic"` or `"bean"`, for the sender's whole table, at most once a second). `init.server` routes each one to the player's table.

---

### 2. Server Modules (`src/server/`)

#### Several tables in one server
* Every module in `src/server/Table/` keeps its state at module level, i.e. one game. `init.server` clones the whole `Table` folder once per entry in `Constants.TABLES` (into `ServerStorage.Tables`) and requires each clone separately, so each table has its own lobby, round, players and arena. `TableContext.Configure` runs first in each clone and tells it its id, size (`maxPlayers`) and `origin`.
* Arenas are `Workspace.SkullsArena_<id>` with `TableId` and `Origin` attributes. Each table's `origin` comes from its room in the saved world (`Workspace.World.Room_<id>.Table.TableCenter`, on the floor under the table's middle; see "The saved world"). Seats are laid out in world space by `layoutSeats` (evenly round the table: seat 1 at the front, +Z). Floors are at Y = 0 and table tops at Y = 3.0, so the fixed heights used for cards stay valid.
* To add a table: add an entry to `Constants.TABLES`. A table bigger than 6 also needs bot names in `LobbyManager.BOT_NAMES` and enough `CardArt` sets.

#### `TableContext.luau`
* **Purpose:** This table's `id`, `name`, `maxPlayers`, `origin`, and its members (players who joined it, seated or watching). `FireAll(remote, ...)` / `GetPlayers()` replace `FireAllClients` / `Players:GetPlayers()` in table code. `NotifyChanged()` (called from `LobbyManager.Broadcast`) refreshes the menu's table list.

#### The saved world (0.3)
* The rooms are not built by code at runtime: they are saved in the place (`Workspace.World`), so they load with the place. One tavern room per table: `Room_1` (4 seats, 46×46) at (0, 0, 0) and `Room_2` (6 seats, 52×52) at (300, 0, 0). Each has `Shell` (floor, rug, plank walls, wainscot, posts, beams, ceiling, two night windows, a door), `Table` (round top, edge 7.5 studs from the centre, top at Y = 3.0; `TableCenter` marker; `Chair_<seat>` per seat), `Chandelier` (main light with shadows, plus a soft downlight on the table) and `Decor`.
* Every seat looks across the table at a different wall, so every wall has something on it. Seat 1 (+Z) faces the north wall: fireplace with fire and light, skull plaque, lanterns, firewood. Other walls: barrels, shelves, a side table with books, lanterns beside the windows; Room 2 adds more in the corners for its 6 angles.
* Built by `tools/world/build_world.luau`, run in Studio (Edit mode), then the place is saved. Re-running rebuilds both rooms. Rojo syncs `tools/world` into `ServerStorage.WorldTools` (not run by the game). Detailed props are AI-generated meshes kept in `ServerStorage.WorldProps` (`Fireplace`, `Barrel`, `Lantern`, `SkullPlaque`, `Firewood`, `Chair`, `Books`, `Shelf`, each with its prompt in a `Prompt` attribute); the builder clones and scales them.
* Lighting is in `default.project.json` (Rojo): `Future` technology with shadows, night, a warm ambient bright enough to read the room when a device's graphics level turns local lights off, a soft `Bloom`, and a `Warmth` colour correction. Room lights (chandelier, fire, lanterns) add the mood on top.
* Each client hides its own seat's chair locally (`applySeatView` in `init.client`), since it sits right under the camera.

#### `TableBuilder.luau`
* **Purpose:** Everything at a table that changes during play: the pile mats (round, dark, on the wooden table), seated avatars and bots, held card fans, name tags, counters, turn highlight. The room, table and chairs come from the saved world.
* **Spawn & Positioning:** Players spawn at the menu platform (`init.server`); joining a table seats them (`StandPlayer`) or stands them back from it (`StandSpectator`), anchoring `HumanoidRootPart` with locomotion disabled.
* **Seat figures (character looks):** Everyone at the table, bots and players alike, is shown as one of the game's own characters, `Figure_<seat>` in the arena (built by `spawnFigure`). A seated player's own Roblox avatar stays anchored in the seat but is hidden from everyone (`setCharacterHidden`: parts and decals go transparent, their old values kept in a `ShownTransparency` attribute, and late-loading accessories are hidden as they arrive). It shows again when they become a spectator. Figures carry an `OwnerUserId` attribute (players only, copied onto the `Calavera_` costume), and `init.client` removes its own figure locally. The table has two looks, switched for everyone at it with `TableBuilder.SetLook` (the `SetCharacterLook` remote, from the Look pill). The current look is in the arena's `CharacterLook` attribute, and switching rebuilds every figure and re-deals the held fans:
  * `"classic"` (default): the calavera R15 avatar described below.
  * `"bean"` (`Table/BeanFigure.luau`, a test): a rounded brown capsule of anchored parts sitting on the chair (`BeanFigure.SEAT_RADIUS` 8.2, seat surface at Y 2.05), with stubby arms reaching forward and a sombrero. The sugar-skull face is cut into 9 invisible strips standing round the curve, each a SurfaceGui showing its slice of the art (`ImageRectOffset`, drawn rows 80 to 420 only), so it follows the body instead of floating flat. It holds its cards lower and nearer the table (`HAND_RADIUS` 6.1, `HAND_HEIGHT` 4.1, used by `renderOpponentFannedHand`), so the fan sits between its arms below the face. It has no rig, so reactions are small hops (`BeanFigure.Hop`). An invisible `Head` part carries the name tag and turn dot.
  Either way, the face flowers and sombrero take the seat's card colour (`colorFigure`).
* **Seated Avatars (classic look):** The figures sit in the chairs from the saved world. `setTablePose` turns the rig attachments the joints follow (`AnimationConstraint.Attachment0` on today's R15 rigs; `Motor6D.C0` plus its attachment on older ones; original orientation kept in a `BaseRotation` attribute so it never stacks): elbows bent so the hands hold the card fan from just behind it (they don't poke through), hips and knees bent as if seated; the root doesn't move, so heads keep their height. Any looping animation holds the arms down over the pose, so seated characters play none: the server removes the `Animate` script and sets a `SeatedAtTable` attribute, and `init.client` stops its own character's looping tracks when it sees it. Reactions still play over the pose. Spectators get the pose undone. Classic figures (bots and players) are calavera skeletons: R15 avatars (`Players:CreateHumanoidModelFromDescription`) with skinny proportions (width/depth 0.7) and a big skull head (1.3), warm brown head and hands, a dark suit, a sombrero in a slightly darkened card colour, a skull and sombrero. The default (mesh) head is hidden, because decals stretch over its curves. A `Calavera_Figure_<seat>` model beside the figure holds a classic Roblox head shape (`SpecialMesh` Head, which shows decals flat like a classic face) carrying the sugar-skull decal (`Artwork assets/Bots/skull_face.png`, uploaded as `rbxassetid://94176651222783`; its white flowers are tinted), plus a part-built sombrero, all welded to the hidden head. It sits beside the bot, not inside it, because Roblox's avatar scaling squashed parts inside the character. It is built a frame after the bot is placed, because before the rig settles the welds lock in the wrong height. Face flowers and sombrero take the bot's card colour (re-applied in `SetSeatCardSet` once sets are dealt). Only the root is anchored; they play no idle loop (see the pose above). Falls back to the old dark silhouette if an avatar can't be built.
* **Reactions (`PlayReaction(seat, kind, seconds?)`):** plays one of Roblox's R15 emotes on whoever stands at a seat (bot or player): `Cheer` when a challenger scores, `Shock` on the challenger and `Laugh` on the skull's owner when a skull is hit, `Dance` for the match winner. Called from `RoundManager`; does nothing if the animation can't load.
* **Turn dot:** `createPlayerTag` adds a 10px gold dot just below each name tag (its own `TurnDot` billboard on the head); `HighlightTurn` shows only the active player's.
* **Opponent hands:** each player's card backs are held upright and fanned in front of them at chest height, facing the centre.
* **Deal Animation:** Fanned hand tokens are only rebuilt when a seat's card count changes; tokens a hand gains (cards returning at round start) fly in from the table centre, staggered by seat. Your own 2D hand does the same via `HandBar.UpdateHand(..., deal)`.
* **Pile Counters (`UpdatePileCount`):** A label just past each pile toward the table centre (1.9 studs from the pile's middle, clear of the cards), with the owner's card-back icon and the number of face-down cards. Muted during placement, bold gold during bidding / challenge / card-loss pick, hidden when empty. Clients enlarge it on mouse hover (`HoverScale`).
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
* **Purpose:** Pre-match lobby for one table. Humans who join the table take its seats while in the lobby; anyone joining mid-match (or when the table is full) waits and spectates. Ready check with `LOBBY_COUNTDOWN`; the host (first joined still present) can force-start and toggle bots. Bots fill empty seats at match start and are removed when the match ends (`RoundManager.SetMatchOverHandler(LobbyManager.EnterLobby)`).
* A player leaving mid-match → `RoundManager.OnPlayerLeft`: the round restarts without them, or the last remaining player wins. If only bots are left, the table goes straight back to the lobby (bots removed) instead of playing on empty.

#### `init.server.luau`
* **Purpose:** The table directory. Builds the menu spawn and every table (see "Several tables in one server"), keeps `tableOf[player]`, and routes `JoinTable`, `SubmitAction`, `RequestState`, `LobbyAction` and player leaving to the player's table. Joining sets the player's `TableId` attribute, which switches their client from the menu to the game. Broadcasts `TableList` whenever a table's lobby changes. `LeaveTable` (from the corner Leave pill) takes the player out of the table the same way as leaving the game, clears `TableId` and respawns them on the menu platform (`LoadCharacterAsync`). The player is removed from the table's members before its lobby cleanup, so a reset doesn't seat them again.

---

### 3. Client Modules (`src/client/`)

#### `first/LoadingScreen.client.luau` (ReplicatedFirst)
* **Purpose:** Replaces Roblox's default loading screen with a themed one: a dark screen with a soft dark-rose glow (`Glow` image, tinted), the logo (preloaded first; the text title shows until it has loaded, then it pops in), step text and a progress bar. It that stays up until: the game has loaded, the server has built the table (`workspace` attribute `TableReady`, set in `init.server.luau`), card art and sounds are preloaded (player attribute `ClientReady`, set by `init.client.luau`), and your avatar has spawned. Each step has a timeout and the whole screen is capped at 25 s, then it fades out. Colours and image ids mirror `Theme` because Shared may not have replicated yet.

#### `CameraController.luau`
* **Purpose:** 3D tabletop over-the-shoulder camera elevated behind Seat 1 framing your avatar, the circular table, and opponent bots (LOCOfficial style).
* **Per-Frame Override Lock:** Binds to `RunService.RenderStepped` above standard camera priority (`Enum.RenderPriority.Camera.Value + 20`), dynamically updating `Workspace.CurrentCamera` to prevent Roblox engine hijacking.
* **Cinematic Framing:** Frames the local player's back/shoulders at Seat 1 in the foreground (`Vector3.new(0, 7.6, 15.6)`) looking directly across the table (`Vector3.new(0, 3.2, 0.8)`), keeping table coasters, 3D card stacks, and all standing opponent bots in crystal clear view.
* **Dynamic Polish:** Smooth FOV turn punch on active turn and dramatic screen shake on Skull hits. Avatar remains 100% visible with overhead player billboard tag.

#### `Theme.luau` (shared: `src/shared/Theme.luau`)
* **Purpose:** Theme A (Calavera / Day of the Dead) design tokens, shared by the screen UI and server-built 3D labels.
* **Readability rules:** `Theme.TextSize` (nothing below `Min` = 14), `Theme.Outline(label)` for any text over the 3D scene, `Colors.Backing` for floating label pills. New UI takes colours from `Theme.Colors`, not `Color3.fromRGB` literals.
* `Theme.Images`: uploaded UI images (the menu logo and the corner-pill icons). Their sources are in `Artwork assets/UI`; a changed image has to be uploaded again and its new asset id put here.
* `init.client.luau` adds a `ScreenScale` UIScale that enlarges the UI on big monitors (1.0–1.5×); code placing GUI at raw screen positions must divide by it.
* Defines the warm wood colors (`TableDark`, `TableSurface`), gold filigree accents (`Gold`, `GoldGlow`), crimson velvet (`RosePrimary`), and obsidian charcoal (`SkullPrimary`).

#### `UI/UIKit.luau`
* **Purpose:** The shared look for every pop-up, so they all match. `Panel` (centred, auto-height, dark backing, gold border, vertical layout, hidden until shown), `SetAccent` (border colour, e.g. red for skulls), `Label` with styles `display` / `title` / `heading` / `body` / `muted`, `Button` with kinds `primary` (marigold) / `success` / `danger` / `secondary`, `SetButtonKind`, `SetEnabled`, `Row` (horizontal layout), and `Pop(frame, show)` for the springy show / quick shrink-and-hide.
* Built on it: `ActionBar`, `CardRevealModal`, `DiscardModal`, `VictoryModal`, `LobbyPanel`, `PhaseOverlay`. Build new pop-ups from it rather than hand-styling Instances.

#### `UI/StatusBar.luau`
* **Purpose:** The only match-status display: a fixed-width (280px) card in the bottom-left corner. Line 1 `ROUND n · PHASE` with the turn timer pinned right (red in the last 5 s); line 2 whose turn (gold "YOUR TURN", or "<name>'s turn"); line 3 context (cards on the table, current bid and bidder, flips so far, or who is choosing a lost card; wraps if long); a drain bar along the bottom. Fixed width so it never shifts as text changes, and out of the top of the screen, which belongs to the other players' 3D name tags (far, left and right seats). Roblox's player list is hidden (it only repeated the seat tags). Hidden in the lobby and on the winner screen.

#### `UI/Toast.luau`
* **Purpose:** Short event pop-ups at the bottom centre, just above the hand, one at a time and queued (max 3; a backed-up queue plays faster). Fed by server `Notification`s that matter (bids, skull hits, timeouts, points, wins, passes) and client messages (rejected actions, "you lost a card"). Routine info messages are not shown.

#### `UI/Hand3D.luau`
* **Purpose:** Your hand as oversized round 3D cards floating in a fan at the bottom of your view. The cards are local parts inside the camera (only you see them), repositioned every frame after the camera (`Hand3DLayout`), with a slow bob.
* Hover a card (mouse raycast) to lift and grow it; click or tap it on your turn and it flies to your pile (`SetPileTarget`) while the placement is sent. Cards sit lower when you can't place. Rejected placements restore the hand from the next state.
* Same interface as the old `HandBar` (`Create`, `UpdateHand(hand, isTurn, canPlace, deal, setId)`, `SetVisible`, `ConsumeCard`, `GetSelectedCard`, `GetRemainingCardsCount`); `init.client.luau` requires it in HandBar's place.

#### `UI/HandBar.luau` (unused)
* The previous 2D hand at the bottom of the screen. Kept for reference; switch back by requiring it instead of `Hand3D` in `init.client.luau`.

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
* `SetSeat(seatIndex)` rotates the seat-1 camera setup around the table to face it from the local player's seat (angle taken from `PlayerMat_<seat>` relative to the table's `Origin`); the camera is then moved to that table's centre. In the menu (no table yet) it slowly circles table 1 as a backdrop. `init.client.luau` also applies the pile-outline toggle (`UI/PileOutlines`) and hides your own fanned hand tokens locally.

#### `UI/DiscardModal.luau`
* **Purpose:** Skull penalty picker (UIKit panel, red border), shown only to the chooser; cards lift on hover. State re-syncs don't rebuild an already-open picker. Own skull: the challenger's cards face-up, pick one to lose. Someone else's skull: N face-down cards, the skull owner removes one blindly.

#### `UI/CardRevealModal.luau`
* **Purpose:** Centre-screen card flip pop-up (UIKit panel): "ROSE REVEALED" / "SKULL!", the card face in its owner's art set with a coin-flip animation, and "<name>'s pile · flip n of m". Border turns red on a skull. Hides itself after 2.2 s.

#### `UI/VictoryModal.luau`
* **Purpose:** Winner screen (UIKit panel): crown, "YOU WIN!" / "<name> wins", the reason (first to 2 points, last standing, everyone left), and a "Back to the lobby in Ns" countdown, with a confetti burst on its own layer.

#### `UI/CardAnimation.luau`
* **Purpose:** Flying card physics animation (LOCOfficial style).
* Animates cards physically flying from the bottom floating hand dock onto the 3D table stack with an elastic bounce when played. Called from `init.client.luau` when your placement is confirmed (target = your `PlayerMat_<seat>` projected to screen) and when you lose a card to a skull penalty (flies off the top).

#### `TableView.luau`
* **Purpose:** The player's table on the client: `GetTableId()` (player attribute `TableId`), `GetArena()` (`SkullsArena_<id>`), `GetOrigin()`, `OnJoined(callback)` and `OnLeft(callback)` (each fires every time).

#### `UI/MainMenu.luau`
* **Purpose:** First screen (and where Leave brings you back): the logo (`Theme.Images.Logo`, cut out of the artwork on a transparent background, from `Artwork assets/UI/logo.png`) floating over the dimmed tavern with no panel behind it, the tagline and PLAY, then "Pick a table" with one card per table (`Table 1 (4 Players)`, seats taken, whether a match is on) and JOIN. Sends `JoinTable`, closes when the server sets `TableId`. Drawn over the camera's orbit of table 1.

#### `UI/CornerPill.luau`
* **Purpose:** The top-right corner options. Only a small dim cogwheel shows there; clicking it opens the pills (an icon from `Theme.Images`, white and tinted with the text, plus a short word) in a row to its left and turns the cog into an X, which closes them. The pills (`CornerBar.Pills`) are ordered Look, Piles, Leave, and each one sizes to its text. `setLit` highlights a pill while its setting is on.

#### `UI/LeaveTable.luau`
* **Purpose:** A small dim "Leave" pill (door-and-arrow icon) in the top-right corner, out of the way. It only opens a "Leave this table?" question (STAY / LEAVE); LEAVE sends `LeaveTable`. When `TableId` clears, `init.client` resets its view (hand, camera, seat), rebuilds the game UI hidden and shows the main menu again.

#### `UI/CharacterLook.luau`
* **Purpose:** The test switch between the two character looks: a dim pill left of Piles with a t-shirt icon and the current look ("Classic" / "Bean"). It shows the table's current look (the arena's `CharacterLook` attribute) and asks the server for the other one (`SetCharacterLook`). It changes the look for everyone at the table.

#### `UI/PileOutlines.luau`
* **Purpose:** A small dim "Piles" pill (stacked-cards icon) just left of Leave. It turns the round pile-mat outlines (each mat's `MatGui` SurfaceGui, built disabled by `TableBuilder`) on or off for this player only. Off by default; the choice holds across leaving and rejoining. `init.client` re-applies it whenever you join a table or take a seat.

#### `init.client.luau`
* **Purpose:** Client entry point. Builds the `ScreenGui` (disabled until you join a table), shows the main menu, coordinates all UI components, and binds server events. The first `RequestState` goes out once you've joined.
