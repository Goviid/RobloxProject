# Skulls & Roses (Roblox)

A multiplayer 2D/2.5D tabletop bluffing game for 2 to 6 players on Roblox, inspired by *Skull & Roses* and styled with Theme A (Calavera / Day of the Dead).

---

## 📖 Project Documentation

* **[Implementation Plan (IMPLEMENTATION_PLAN.md)](IMPLEMENTATION_PLAN.md)** — Core rules, state machine flowcharts, UI layout wireframes, security model, and milestone roadmap.
* **[Code & Architecture Guide (CODE_GUIDE.md)](CODE_GUIDE.md)** — Plain-English walkthrough of every file, module, remote event, and game mechanic.

---

## 🛠️ Getting Started & Local Development

### 1. Build Place File
```bash
rojo build -o "RobloxProject.rbxlx"
```

### 2. Start Live Sync
```bash
rojo serve
```
Then open `RobloxProject.rbxlx` in Roblox Studio, navigate to the **Plugins** tab, and click **Connect** on Rojo.

---

## 📦 Project Structure

```
F:\RobloxProject/
├── IMPLEMENTATION_PLAN.md     # Full design and roadmap
├── CODE_GUIDE.md              # File-by-file code guide
├── default.project.json       # Rojo configuration
├── src/
│   ├── shared/                # Constants, Enums, Network
│   ├── server/                # PlayerManager, RoundManager, BotController, init
│   └── client/                # UI (Theme, HandBar, ActionBar, TableView, NotificationBanner)
```
