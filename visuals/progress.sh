#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  visuals/progress.sh  —  Package deployment progress UI     ║
# ║                                                             ║
# ║  Run standalone in a spawned terminal window.               ║
# ║  Reads status files written by installer workers.           ║
# ║                                                             ║
# ║  Required env (passed via GHOST_TMPDIR):                    ║
# ║    GHOST_STATUSDIR  — directory of per-pkg status files     ║
# ║    GHOST_PKGS       — space-separated package list          ║
# ╚══════════════════════════════════════════════════════════════╝

# ── Restore vars from tmpdir env-dump if not already set ──────
# installer.sh writes a small env file so this script can be
# spawned without inheriting the parent shell's environment.
GHOST_TMPDIR="${GHOST_TMPDIR:-}"

if [[ -z "$GHOST_STATUSDIR" && -n "$GHOST_TMPDIR" ]]; then
  # Try to source env dump written by installer
  [[ -f "${GHOST_TMPDIR}/.env" ]] && source "${GHOST_TMPDIR}/.env"
fi

# Fallback auto-detect: find the newest ghost tmpdir
if [[ -z "$GHOST_STATUSDIR" ]]; then
  GHOST_TMPDIR="$(ls -dt /tmp/.ghost_* 2>/dev/null | head -1)"
  GHOST_STATUSDIR="${GHOST_TMPDIR}/pkgstatus"
fi

# ── Resolve package list ──────────────────────────────────────
if [[ -n "$GHOST_PKGS" ]]; then
  # GHOST_PKGS is a bash array exported as a string — split it
  read -ra PKGS <<< "${GHOST_PKGS[*]:-${GHOST_PKGS}}"
else
  PKGS=(cmatrix figlet lolcat oneko)
fi

STATUSDIR="${GHOST_STATUSDIR:-${GHOST_TMPDIR}/pkgstatus}"
READY_FLAG="${GHOST_TMPDIR}/.ready"

# ── Colours ───────────────────────────────────────────────────
RED='\033[0;31m'  GRN='\033[0;32m'  YEL='\033[1;33m'
CYN='\033[0;36m'  MAG='\033[0;35m'  WHT='\033[1;37m'
DIM='\033[2m'     BLD='\033[1m'     RST='\033[0m'

BAR_WIDTH=44

# ── Draw one progress bar row ─────────────────────────────────
draw_bar() {
  local pct="$1" label="$2" status="$3"
  local filled=$(( pct * BAR_WIDTH / 100 ))
  local empty=$(( BAR_WIDTH - filled ))

  local color="$CYN"
  case "$status" in
    DONE)       color="$GRN" ;;
    FAILED)     color="$RED" ;;
    INSTALLING) color="$YEL" ;;
    QUEUED)     color="$DIM" ;;
  esac

  # Label
  printf "  ${WHT}%-12s${RST} " "$label"
  # Bar
  printf "${DIM}[${RST}${color}"
  printf '%0.s█' $(seq 1 $filled) 2>/dev/null
  printf "${DIM}"
  printf '%0.s░' $(seq 1 $empty)  2>/dev/null
  printf "${RST}${DIM}]${RST}"
  # Percentage
  printf " ${color}${BLD}%3d%%${RST}" "$pct"
  # Status label (fixed width to prevent line-length jitter)
  case "$status" in
    QUEUED)     printf "  ${DIM}· queued     ${RST}" ;;
    INSTALLING) printf "  ${YEL}⟳ deploying  ${RST}" ;;
    DONE)       printf "  ${GRN}✔ complete   ${RST}" ;;
    FAILED)     printf "  ${RED}✘ failed     ${RST}" ;;
  esac
  printf '\n'
}

# ── Header ────────────────────────────────────────────────────
clear
printf "${CYN}${BLD}"
printf '  ╔══════════════════════════════════════════════════════╗\n'
printf '  ║        GHOST  ·  PACKAGE  DEPLOYMENT  UNIT          ║\n'
printf '  ║                Parallel Installer v2.0              ║\n'
printf '  ╚══════════════════════════════════════════════════════╝\n'
printf "${RST}\n"

# ── State ─────────────────────────────────────────────────────
declare -A pct_map status_map

for p in "${PKGS[@]}"; do
  pct_map[$p]=0
  status_map[$p]="QUEUED"
done

# ── all_done helper ───────────────────────────────────────────
all_done() {
  for p in "${PKGS[@]}"; do
    local s="${status_map[$p]}"
    [[ "$s" != "DONE" && "$s" != "FAILED" ]] && return 1
  done
  return 0
}

# ── Animation loop ────────────────────────────────────────────
HEADER_ROWS=7   # lines printed above the bar section

while ! all_done; do
  # Move cursor back up to start of bar section
  tput cup $HEADER_ROWS 0 2>/dev/null || printf '\033[%d;0H' "$HEADER_ROWS"

  for pkg in "${PKGS[@]}"; do
    local_status="$(cat "${STATUSDIR}/${pkg}" 2>/dev/null || printf 'QUEUED')"
    status_map[$pkg]="$local_status"

    case "$local_status" in
      QUEUED)
        pct_map[$pkg]=0
        ;;
      INSTALLING)
        cur=${pct_map[$pkg]}
        if   (( cur <  30 )); then inc=$(( RANDOM % 9 + 4 ))
        elif (( cur <  60 )); then inc=$(( RANDOM % 6 + 2 ))
        elif (( cur <  85 )); then inc=$(( RANDOM % 3 + 1 ))
        elif (( cur <  94 )); then inc=1
        else                       inc=0
        fi
        new=$(( cur + inc ))
        (( new > 94 )) && new=94
        pct_map[$pkg]=$new
        ;;
      DONE)
        pct_map[$pkg]=100
        ;;
      FAILED)
        : # freeze at last pct
        ;;
    esac

    draw_bar "${pct_map[$pkg]}" "$pkg" "$local_status"
  done

  # Summary
  done_count=0
  for p in "${PKGS[@]}"; do
    [[ "${status_map[$p]}" == "DONE" ]] && (( done_count++ ))
  done

  printf '\n'
  printf "  ${DIM}Progress: ${WHT}%d${DIM}/${WHT}%d${DIM} packages complete${RST}          \n" \
    "$done_count" "${#PKGS[@]}"
  printf "  ${DIM}%-10s %s${RST}                    \n" \
    "Timestamp:" "$(date '+%H:%M:%S')"

  sleep 0.20
done

# ── Final render — all bars at 100% ──────────────────────────
tput cup $HEADER_ROWS 0 2>/dev/null || printf '\033[%d;0H' "$HEADER_ROWS"
for pkg in "${PKGS[@]}"; do
  draw_bar 100 "$pkg" "DONE"
done

printf '\n'
printf "  ${GRN}${BLD}✔ All packages deployed successfully.${RST}          \n"
printf "  ${DIM}This window closes in 4 seconds...${RST}              \n"
sleep 4
