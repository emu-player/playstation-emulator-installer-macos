# 🎮 Sony Emulators Installer for macOS (PS1 • PS2 • PS3)

A **one-command, fully automated, bulletproof installer** for the main Sony console emulators on **macOS**, compatible with **Intel** and **Apple Silicon (M1/M2/M3)**.

This script installs:
- **PS1** → PCSX (fallback to Mednafen)
- **PS2** → PCSX2
- **PS3** → RPCS3  

It also handles **Homebrew**, **all dependencies**, **directory setup**, **environment variables**, **automatic fixes**, and **BIOS / firmware guidance**, with **detailed logs and recovery mechanisms**.

---

## ✨ Features

✔ One-command installation  
✔ Intel & Apple Silicon support  
✔ Automatic Rosetta 2 detection & installation  
✔ Homebrew auto-install & update  
✔ Full dependency management (SDL2, Qt6, FFmpeg, etc.)  
✔ Emulator auto-install (PCSX / PCSX2 / RPCS3)  
✔ Automatic directory structure creation  
✔ BIOS & firmware detection with guides  
✔ Apple Silicon specific fixes  
✔ Verbose output with color-coded logs  
✔ Error-tolerant (does not stop on common failures)  
✔ Safe, repeatable, and idempotent  

---

## 🖥️ Supported Systems

- **macOS** (tested from macOS 11+)
- **Intel (x86_64)**
- **Apple Silicon (ARM64)**

---

## 🚀 Installation (One Command)

```bash
chmod +x install_sony_emulators.sh && ./install_sony_emulators.sh
