# TDS Modified Macro (IlMlN Edition)

An enhanced, high-performance AutoHotkey v2 macro for **Tower Defense Simulator (Roblox)**, built on Darksen's Ultimate Macro with quality-of-life improvements, optimized game detection, and automated updates.

---

## Features

- **Automated Strategy Execution**: Run `.strat` files with accurate timing, ability casting, and upgrade paths.
- **In-App Modifier Controls**: Toggle strategy modifiers (Glass, Hidden, Exploding, etc.) directly in the GUI with real-time file synchronization.
- **Direct Timescale Switching**: Switch between OFF, 1.5x, and 2x speed straight from the Main tab.
- **Automated Settings Persistence**: All toggles, input values, and keybinds save automatically in the background.
- **Map List Navigation**: Configurable lobby scroll-down for reliable detection of lower-tier maps (e.g. Molten).
- **Discord Webhook Reporting**: Post-match statistics, memory and OCR cross-checked reward recognition (coins, gems, exp), and Discord user mention alerts.
- **In-App Setup Tutorial**: Dedicated tutorial tab covering essential Windows, Roblox, and TDS configuration requirements with 1-click Windows settings shortcuts.
- **One-Click Auto-Updater**: Checks GitLab tags for updates on startup or on click, preserving local settings and statistics.

---

## Requirements

- **OS**: Windows 10 / 11 (64-bit)
- **Display Scaling**: 100% recommended in Windows display settings
- **AutoHotkey v2**: Included in `submacros/AutoHotkey64.exe` (no separate installation required)
- **Roblox**: Fullscreen or windowed mode

---

## Getting Started

1. Download the latest release:
   - **[Direct Download ZIP (v1.3.3.10)](https://gitlab.com/IlMlN/tds-modified-macro/-/archive/v1.3.3.10/tds-modified-macro-v1.3.3.10.zip)** (Recommended)
   - Or download from [GitLab Releases](https://gitlab.com/IlMlN/tds-modified-macro/-/releases).
2. Extract the archive into a permanent folder (do not run directly from inside a `.zip`).
3. Run **`Main.ahk`** (or execute via `submacros/AutoHotkey64.exe`).
4. Select your `.strat` file under **Strategy** in the **Main** tab.
5. (Optional) Configure Discord Webhook notifications in the **Discord** tab.
6. Press **F1** to start, or **F2** to stop.

---

## Hotkeys

| Key | Action |
| :--- | :--- |
| **F1** | Start active strategy |
| **F2** | Stop strategy execution |

---

## Updates

- **Automatic**: The macro checks GitLab for updates 1.5 seconds after launch. If a new release is available, an update prompt will appear.
- **Manual**: Click the version string in the bottom-left corner of the GUI to check immediately.
- **Safety**: Updating preserves `Settings.ini` and personal run statistics (`State.ini`).

---

## Notes & Security

- Personal configuration (Discord webhooks, user IDs, private server links) is stored in `Settings.ini` and excluded from git tracking.
- Strategy files are stored in the `Strategies/` folder.
