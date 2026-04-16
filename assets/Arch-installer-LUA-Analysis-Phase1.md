# 🧭 Arch Hyprland Installer → Lua Migration Analysis (Phase 1)
<span style="color:#7dd3fc">Focus: identify installer scripts that **write Hyprland configs** or invoke writers (Hyprland‑Dots).</span>

---

## 📌 Table of Contents
- [🎯 Scope & Assumptions](#-scope--assumptions)
- [🧩 Hyprland Config Entry Points](#-hyprland-config-entry-points)
- [✍️ Direct Hyprland Config Writers (in this repo)](#️-direct-hyprland-config-writers-in-this-repo)
- [🧪 Indirect Writers via Hyprland‑Dots](#-indirect-writers-via-hyprlanddots)
- [🧰 Other File Writers (non‑Hyprland)](#-other-file-writers-nonhyprland)
- [📟 Runtime‑Only Files (no file writes)](#-runtime-only-files-no-file-writes)
- [📝 Notes / Follow‑ups](#-notes--follow-ups)

---

## 🎯 Scope & Assumptions
<span style="color:#fbbf24">Scope:</span> this repo is an **installer**, not the Hyprland dotfiles themselves. The actual Hyprland config content is pulled from **Hyprland‑Dots** during install.

<span style="color:#a3e635">Out of scope:</span> new Lua syntax.

---

## 🧩 Hyprland Config Entry Points
This repo **does not ship** `hyprland.conf` or other Hyprland config files.

Hyprland configs are installed via **Hyprland‑Dots**:
- `install-scripts/dotfiles-main.sh` clones `Hyprland-Dots` and runs `copy.sh`.

---

## ✍️ Direct Hyprland Config Writers (in this repo)
No direct writes to `~/.config/hypr/*.conf` in this repo.

However, these scripts **create files under** `~/.config/hypr/scripts/`:

### 🩺 System monitors (create Hyprland helper scripts + systemd services)
- `install-scripts/battery-monitor.sh`
  - **Creates:** `~/.config/hypr/scripts/battery-monitor.sh`
  - **Creates:** `~/.config/systemd/user/battery-monitor.service`
  - **How:** `mkdir -p` + `cat >` + `chmod +x`

- `install-scripts/disk-monitor.sh`
  - **Creates:** `~/.config/hypr/scripts/disk-monitor.sh`
  - **Creates:** `~/.config/systemd/user/disk-monitor.service`
  - **How:** `mkdir -p` + `cat >` + `chmod +x`

- `install-scripts/temp-monitor.sh`
  - **Creates:** `~/.config/hypr/scripts/temp-monitor.sh`
  - **Creates:** `~/.config/systemd/user/temp-monitor.service`
  - **How:** `mkdir -p` + `cat >` + `chmod +x`

These do **not** modify Hyprland config files directly, but they install scripts inside the Hyprland config tree.

---

## 🧪 Indirect Writers via Hyprland‑Dots
### 🧩 Hyprland dotfiles installation
- `install-scripts/dotfiles-main.sh`
  - **Clones/Pulls:** `https://github.com/LinuxBeginnings/Hyprland-Dots`
  - **Runs:** `Hyprland-Dots/copy.sh`
  - **Impact:** `copy.sh` is where Hyprland configs (`~/.config/hypr/*.conf`) are actually written.

### 🧭 Main installer entry point
- `install.sh`
  - When `dots` option is selected, it calls `dotfiles-main.sh`.

➡️ **Lua migration impact:** Hyprland‑Dots will need to update writers; Arch installer only delegates to it.

---

## 🧰 Other File Writers (non‑Hyprland)
These scripts write files or change system state, but **not Hyprland configs**:
- `install.sh`, `auto-install.sh`, `uninstall.sh`
- Many `install-scripts/*.sh` (package installs, system configs, SDDM, GTK, etc.)

---

## 📟 Runtime‑Only Files (no file writes)
Based on installer scripts in this repo, the following appear **runtime-only** (no file writes detected):

- `assets/hyprland-install/scripts/install-hyprland-git.sh`
- `assets/hyprland-install/scripts/install-hyprland.sh`
- `install-scripts/00-base.sh`
- `install-scripts/01-hypr-pkgs.sh`
- `install-scripts/02-Final-Check.sh`
- `install-scripts/bluetooth.sh`
- `install-scripts/fonts.sh`
- `install-scripts/hyprland.sh`
- `install-scripts/InputGroup.sh`
- `install-scripts/nvidia_nouveau.sh`
- `install-scripts/pipewire.sh`
- `install-scripts/quickshell.sh`
- `install-scripts/rog.sh`
- `install-scripts/thunar_default.sh`
- `install-scripts/xdph.sh`

---

## 📝 Notes / Follow‑ups
- README instructs editing `~/.config/hypr/UserConfigs/ENVariables.conf` for NVIDIA, but this repo does **not** modify it directly.
- For Lua migration, the actionable config writers remain in **Hyprland‑Dots**.
