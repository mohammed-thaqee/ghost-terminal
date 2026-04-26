#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  visuals/codescroll.sh  —  Live code/log scroll for dashboard pane  ║
# ║                                                                      ║
# ║  Priority:  1. Live system journal  2. Syslog  3. Simulated feed    ║
# ╚══════════════════════════════════════════════════════════════════════╝

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
CYN='\033[0;36m'; MAG='\033[0;35m'; WHT='\033[1;37m'
DIM='\033[2m';    BLD='\033[1m';    RST='\033[0m'

# ── Try real log sources first ────────────────────────────────────────
if command -v journalctl &>/dev/null; then
  journalctl -f --no-pager --output=short-monotonic 2>/dev/null &
  LOG_PID=$!
  sleep 0.5
  if kill -0 "$LOG_PID" 2>/dev/null; then
    wait "$LOG_PID"
    exit 0
  fi
fi

if [[ -r /var/log/syslog ]]; then
  tail -f /var/log/syslog 2>/dev/null &
  LOG_PID=$!
  sleep 0.5
  if kill -0 "$LOG_PID" 2>/dev/null; then
    wait "$LOG_PID"
    exit 0
  fi
fi

# ── Fallback: simulated kernel/system log stream ──────────────────────
SOURCES=(
  "kernel: EXT4-fs (sda1): re-mounted. Opts: errors=remount-ro"
  "systemd[1]: Starting Network Time Synchronization..."
  "kernel: usb 1-1: new high-speed USB device"
  "sshd[$$]: Server listening on 0.0.0.0 port 22"
  "kernel: NET: Registered PF_INET6 protocol family"
  "systemd[1]: Reached target Graphical Interface"
  "kernel: audit: type=1400 audit($(date +%s).000:1): apparmor=\"ALLOWED\""
  "cron[$$]: (root) CMD (test -x /usr/sbin/anacron || ...)"
  "kernel: [UFW BLOCK] IN=eth0 OUT= MAC=... SRC=10.0.0.1 DST=10.0.0.2"
  "systemd-resolved[$$]: Using DNS server 8.8.8.8 for interface eth0"
  "kernel: perf: interrupt took too long (3016 > 3000), lowering"
  "apt-daily[$$]: Starting 'apt-daily' service..."
)

COLORS=("$CYN" "$GRN" "$YEL" "$MAG" "$WHT" "$DIM$GRN" "$DIM$CYN")

while true; do
  TS="$(date '+%b %d %H:%M:%S')"
  HOST="$(hostname)"
  MSG="${SOURCES[$((RANDOM % ${#SOURCES[@]}))]}"
  COL="${COLORS[$((RANDOM % ${#COLORS[@]}))]}"
  RAND_PID=$((RANDOM % 9000 + 1000))

  printf "${DIM}%s${RST} ${COL}%s${RST} ${DIM}%s[%d]:${RST} %s\n" \
    "$TS" "$HOST" "${MSG%%[*}" "$RAND_PID" "$MSG"

  sleep "$(awk 'BEGIN{printf "%.2f", 0.05 + rand()*0.25}')"
done
