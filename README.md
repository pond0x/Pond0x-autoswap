# PondX Autoswap (AHK v2)

AutoHotkey v2 helper for round-trip micro-swaps on **pond0x.com** with a draggable HUD, control panel, and adjustable timing.

## 🔽 Download
- **[Get the latest .ahk](../../releases/latest/download/pondx_autoswap_v2.ahk)**  
- Requires **Windows 10/11** and **AutoHotkey v2** (https://www.autohotkey.com)

## ✅ What it does
- Round-trip flow (A→B → Reverse → B→A)
- Control Panel: set **swap amounts**, **delays** (Swap→Wallet, Wallet→SwapAgain, SwapAgain→Swap), **cooldowns**
- Wallet confirm: supports Phantom/Backpack/Solfare/OKX/Rabby (title match)
- Draggable **HUD**: shows swaps, next ETA, current leg
- Safety: random jitter, max trips per session, pause/resume hotkeys
- Logging: optional CSV

## 🚀 Quick Start
1. Install **AutoHotkey v2**.
2. Download the `.ahk` from the link above and **double-click** it.  
   Look for the green **H** in the tray and the **Control Panel** window.
3. Open **pond0x.com/swap/solana** (100% zoom) and connect your wallet.
4. In the Control Panel:
   - Pick pair (e.g., **USDC ↔ USDT** or **SOL ↔ USDC**).
   - Click **Capture Amount** then **type box** (Ctrl+Alt+1).
   - Click **Capture Swap** then **Swap / Swap Again** (Ctrl+Alt+2).
   - Click **Capture Reverse** then the **reverse ↕ button** (Ctrl+Alt+3).
   - Click **Capture Wallet** then **Confirm** in your wallet (Ctrl+Alt+4).
5. Set your **delays** and **amount ranges**, then press **Start**.

## ⌨️ Hotkeys
- **Ctrl+Alt+S** — Start / resume  
- **Ctrl+Alt+P** — Pause  
- **Ctrl+Alt+Q** — Quit  
- **Ctrl+Alt+1..4** — Capture Amount / Swap / Reverse / Wallet  
- **Ctrl+Alt+H** — Toggle HUD

## 🧠 Tips
- Use **USDC↔USDT** (or **SOL↔USDC**) and keep page zoom at **100%**.
- If wallet confirm is late, increase **Swap→Wallet delay** (ms).  
- If confirm is too early, use **“wait for wallet title”** option and/or add **jitter**.
- For boost counting, prefer **stablecoin round-trips** and space swaps with sensible cooldowns.

## 🛠 Troubleshooting
- _HUD doesn’t move:_ it’s draggable—grab the title bar.
- _Hotkeys don’t work:_ ensure AHK v2 (not v1), and the script is running (green H).
- _Wallet not detected:_ enable the specific wallet in settings or type a custom **window title**.
- _Clicks off-target:_ recapture points at **100% zoom** and keep the window maximized.
