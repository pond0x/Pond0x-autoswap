## 🔽 Download

-## Download
**Windows EXE:**  
[⬇️ Get Pond0x Autoswap](https://github.com/<owner>/<repo>/releases/latest/download/pondx_autoswap_v2.exe)

> No AutoHotkey needed for the EXE. Windows 10/11.

- **Direct link (always the latest):**  
  https://github.com/pond0x/Pond0x-autoswap/releases/latest/download/pondx_autoswap_v2.ahk

> Requires **Windows 10/11** and **[AutoHotkey v2](https://www.autohotkey.com/)** (not v1).

## 🚀 Quick Start

1) Install **AutoHotkey v2**.  
2) Download `pondx_autoswap_v2.ahk` (link above) and double-click it.
3) Open **pond0x.com/swap/solana** in a desktop browser (100% zoom), connect your wallet.
4) In the control panel:
   - Capture points:
     - **Ctrl+Alt+1** → Amount box  
     - **Ctrl+Alt+2** → Swap / Swap Again button  
     - **Ctrl+Alt+3** → Reverse (↕) button (for round-trip mode)  
     - **Ctrl+Alt+4** → Wallet Confirm button
   - Set delays:
     - **Swap → Wallet confirm:** e.g. `900–1600 ms`
     - **Wallet confirm → Swap Again:** e.g. `800–1400 ms`
     - **Swap Again → next Swap:** e.g. `600–1100 ms`
   - (Optional) Type amounts per leg (USDC⇄USDT or SOL⇄USDC)
5) Click **Start** (or press **Ctrl+Alt+S**).  
   Use **Ctrl+Alt+P** to pause, **Ctrl+Alt+Q** to quit.

## ✅ Tips

- Keep browser zoom at **100%** so captured coordinates match.
- If the wallet confirm window sometimes lags, increase *Swap→Wallet* delay.
- HUD shows total swaps, last amounts, and next ETA; drag it anywhere.
- CSV logs saved to `logs/` (if enabled).

## 🔒 Integrity

SHA-256 of the current release is shown on the **Releases** page next to the asset.
