# PondX Autoswap (AHK v2)

AutoHotkey v2 helper for round-trip micro-swaps on pond0x (A→B → Reverse → B→A) with a draggable HUD, control panel, wallet-confirm timing, CSV logging, session breaks, and safety limits.

> **Requires:** Windows 10/11 • AutoHotkey **v2** (not v1) • a supported wallet (Phantom/Solflare/Backpack…)

## ✨ Features
- Round-trip flow with **Reverse** click
- **Control Panel**: set amounts, Swap→Confirm delay, Reverse→Swap delay, cooldowns
- **HUD**: live swaps, trips, direction, next ETA
- **Wallet confirm**: detects Phantom/Backpack/Solflare/OKX/Rabby
- **CSV logging** to `logs/`
- **Session breaks** after N trips + **max trips** cutoff
- Hotkeys for quick capture/controls

## 🔧 Setup
1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Open your DEX page (e.g. `pond0x.com/swap/solana`). Keep zoom at **100%**.
3. Run `pondx_autoswap.ahk` (double-click).
4. In the Control Panel click:
   - **Capture Amount**, **Capture Swap**, **Capture Reverse**, **Capture Wallet** (hover each UI target then click the button).
5. Set amounts (start with **0.25–0.40** per leg) and timings (e.g., Swap→Confirm **2200–3500 ms**).
6. Press **Start** (or `Ctrl+Alt+S`).

## ⌨️ Hotkeys
- Capture: `Ctrl+Alt+1` Amount • `Ctrl+Alt+2` Swap • `Ctrl+Alt+3` Reverse • `Ctrl+Alt+4` Wallet  
- Control: `Ctrl+Alt+S` Start • `Ctrl+Alt+P` Pause/Resume • `Ctrl+Alt+H` HUD • `Ctrl+Alt+O` Panel • `Ctrl+Alt+Q` Quit

## 📝 Tips
- If confirms are slow: increase Swap→Confirm wait (e.g., 2500–4200 ms).
- If counted rate is low: increase per-leg amounts (e.g., 0.40–0.80) and keep cooldown ≥10s.
- Use session breaks to avoid soft rate-limits.

## ⚠️ Disclaimer
This tool automates clicks/keystrokes. **Use at your own risk.** Ensure your usage complies with the website’s Terms of Service and your local laws. The authors provide **no warranty** and are **not responsible** for any loss.

## 📜 License
MIT — see [LICENSE](./LICENSE).
