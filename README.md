# 👻 Ghost Hacker Terminal

> *Single-command ephemeral hacker shell for Ubuntu/Debian lab environments*

---

## Deploy in One Command

```bash
source <(curl -sL https://raw.githubusercontent.com/<YOU>/<REPO>/main/ghost.sh)
```

Or locally:

```bash
source ghost.sh
```

> **Must be sourced (`source` / `.`), not executed (`bash ghost.sh`).**  
> This is enforced by the script — it will refuse to run otherwise.

---

## What Happens

```
┌─────────────────────────────────────────────────────────────────┐
│  source ghost.sh                                                │
│                                                                 │
│  1. Boot sequence animation (BIOS-style typewriter)             │
│  2. Sudo password prompt (once, cached in tmpfs)                │
│  3. Parallel install: cmatrix figlet lolcat oneko               │
│     └─► Spawns separate terminal with animated progress bars    │
│  4. cmatrix runs briefly in its own terminal window             │
│  5. figlet + lolcat ASCII banner printed to main terminal       │
│  6. oneko launched (follows your cursor)                        │
│  7. Prompt switched → [ghost] agent@system:~$                   │
│  8. Shell history wiped and disabled for session                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Cleanup: `mayday`

Type `mayday` at any time to trigger **full cleanup**:

```
[1/7] Terminating spawned processes (cmatrix, oneko, etc.)
[2/7] Uninstalling ghost packages (apt remove)
[3/7] Shredding tmpfs artefacts (rm -rf /tmp/.ghost_*)
[4/7] Restoring history subsystem
[5/7] Restoring original shell prompt
[6/7] Purging all ghost functions & variables from shell
[7/7] Clearing terminal + wiping history buffer
      → reset + clear
```

After `mayday`, the shell returns to its original state as if nothing happened.

---

## Architecture

```
ghost.sh
├── _ghost_boot_sequence        Boot animation (typewriter effect)
├── _ghost_acquire_sudo         One-time sudo prompt, caches in tmpfs
├── _ghost_install_all_packages Parallel apt workers + spawns progress terminal
├── _ghost_write_progress_script  Writes animated progress bar script to tmpfs
├── _ghost_run_cmatrix          Opens cmatrix in new terminal window
├── _ghost_show_banner          figlet + lolcat banner
├── _ghost_launch_oneko         Spawns oneko
├── _ghost_suppress_history     Disables + wipes shell history
├── _ghost_set_prompt           Sets [ghost] agent@system prompt
└── mayday                      Full cleanup & self-destruct
```

### Key Design Decisions

| Feature | Implementation |
|---|---|
| Sourced execution | `(return 0 2>/dev/null)` guard at top |
| Password security | Stored in `chmod 600` file under `mktemp -d` |
| Parallel install | One `apt-get install` background worker per package |
| Progress sync | Workers write `INSTALLING`/`DONE`/`FAILED` status files; progress terminal polls them |
| Terminal detection | Probes gnome-terminal → xterm → konsole → xfce4 → lxterminal |
| Race-condition safety | `_GHOST_READY_FLAG` touch file; main waits up to 120s |
| History suppression | `HISTFILE=/dev/null`, `HISTSIZE=0`, `set +o history` |
| No-trace cleanup | All state in `/tmp/.ghost_XXXXXX` tmpfs dir, wiped by `mayday` |

---

## Requirements

- Ubuntu 20.04+ or Debian 11+ (any derivative)
- `bash` 4+
- `apt-get` (standard on Debian/Ubuntu)
- `sudo` access
- For graphical features: a running X11/Wayland display (`$DISPLAY` set) and any supported terminal emulator

> The script degrades gracefully — if no graphical terminal is found, progress runs in-process and cmatrix/oneko are skipped.

---

## Packages Installed

| Package | Role |
|---|---|
| `cmatrix` | Matrix rain animation in spawned terminal |
| `figlet` | ASCII art banner generator |
| `lolcat` | Rainbow colour pipe for banner |
| `oneko` | Cat that chases your cursor |

All four are removed by `mayday`.

---

## Customising the Identity

Edit the top of `ghost.sh`:

```bash
_GHOST_IDENTITY="agent@system"   # change to whatever you want
```

---

## File Layout (Tmpfs)

```
/tmp/.ghost_XXXXXX/
├── .sp              # sudo password (chmod 600), wiped at cleanup
├── .ready           # flag touched when all packages installed
├── progress.sh      # animated progress bar script
└── pkgstatus/
    ├── cmatrix      # QUEUED / INSTALLING / DONE / FAILED
    ├── figlet
    ├── lolcat
    └── oneko
```

Everything under `/tmp/.ghost_*/` is removed by `mayday`.

---

## Safety Notes

- The script **never writes credentials to disk** outside the protected tmpfs directory.
- Sudo password is unset from shell variables immediately after writing to the protected file.
- `mayday` unsets every function and variable the script ever exported.
- History is suppressed from the very first line of `_ghost_main`.
