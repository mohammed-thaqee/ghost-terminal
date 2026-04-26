#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  core/dashboard.sh  —  Tmux 3-pane ghost dashboard                 ║
# ║                                                                      ║
# ║  Layout:                                                             ║
# ║  ┌──────────────────────────┬──────────────────┐                    ║
# ║  │  pane 0: live output     │  pane 1: btop    │                    ║
# ║  │  (~65%)                  │  (~35%)          │                    ║
# ║  ├──────────────────────────┴──────────────────┤                    ║
# ║  │  pane 2: interactive prompt  (~25%)         │                    ║
# ║  └──────────────────────────────────────────────┘                   ║
# ║                                                                      ║
# ║  Window 2: monitoring  (gping | btop)                               ║
# ║  Window 3: ops scratch shell                                        ║
# ╚══════════════════════════════════════════════════════════════════════╝

ghost_launch_dashboard() {
  if ! command -v tmux &>/dev/null; then
    gh_warn "tmux not found — skipping dashboard"
    return 1
  fi

  # Resolve paths
  local GHOST_DIR_LOCAL="${GHOST_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)}"
  local SCROLL_SCRIPT="${GHOST_DIR_LOCAL}/visuals/codescroll.sh"
  local TMUX_CONF="${GHOST_TMPDIR}/tmux.conf"

  # Fallback scroll source if codescroll.sh unavailable
  local scroll_cmd
  if [[ -f "$SCROLL_SCRIPT" ]]; then
    scroll_cmd="bash '${SCROLL_SCRIPT}'"
  elif command -v journalctl &>/dev/null; then
    scroll_cmd="journalctl -f --no-pager --output=short-monotonic 2>/dev/null"
  elif [[ -r /var/log/syslog ]]; then
    scroll_cmd="tail -f /var/log/syslog"
  else
    scroll_cmd="watch -n2 'uptime; echo; ps aux --sort=-%cpu | head -15'"
  fi

  # tmux -f flag: use our config without touching ~/.tmux.conf
  local tmux_cmd="tmux"
  [[ -f "$TMUX_CONF" ]] && tmux_cmd="tmux -f '${TMUX_CONF}'"

  local SESSION="ghost"

  # Already inside tmux — build panes in current window
  if [[ -n "${TMUX:-}" ]]; then
    _ghost_build_panes "$scroll_cmd"
    return 0
  fi

  # Existing ghost session — attach
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    gh_warn "Ghost session already running — attaching"
    eval "${tmux_cmd} attach-session -t '${SESSION}'"
    return 0
  fi

  # New session
  eval "${tmux_cmd} new-session -d -s '${SESSION}' \
    -x '$(tput cols)' -y '$(tput lines)'"
  _ghost_build_panes_in_session "$SESSION" "$scroll_cmd" "$tmux_cmd"
  eval "${tmux_cmd} attach-session -t '${SESSION}'"
}

# ── Build panes when already inside tmux ─────────────────────────────

_ghost_build_panes() {
  local scroll_cmd="$1"

  tmux rename-window "ghost"

  # Right pane: btop (35%)
  tmux split-window -h -p 35 "btop 2>/dev/null || htop 2>/dev/null || top"

  # Left pane split — bottom for prompt (25% of total height)
  tmux select-pane -t 0
  tmux split-window -v -p 25

  # Pane 0: scroll / live output
  tmux send-keys -t 0 "${scroll_cmd}" Enter

  # Pane 2: prompt — already interactive, just clear
  tmux select-pane -t 2
  tmux send-keys -t 2 "clear" Enter
}

# ── Build panes in a new named session ───────────────────────────────

_ghost_build_panes_in_session() {
  local session="$1" scroll_cmd="$2" tmux_cmd="${3:-tmux}"

  # ── Window 1: ghost dashboard ─────────────────────────────────────────
  eval "${tmux_cmd} rename-window -t '${session}:1' 'ghost'"

  # Split right → btop (35%)
  eval "${tmux_cmd} split-window -t '${session}:1' -h -p 35 \
    'btop 2>/dev/null || htop 2>/dev/null || top'"

  # Left pane: split bottom → prompt (25%)
  eval "${tmux_cmd} select-pane -t '${session}:1.0'"
  eval "${tmux_cmd} split-window -t '${session}:1.0' -v -p 25"

  # Pane 0: live scroll
  eval "${tmux_cmd} send-keys -t '${session}:1.0' '${scroll_cmd}' Enter"

  # Pane 2: prompt
  eval "${tmux_cmd} select-pane -t '${session}:1.2'"
  eval "${tmux_cmd} send-keys -t '${session}:1.2' \
    \"printf '\\\\033[0;35m[ghost]\\\\033[0m Session active. Type \\\\033[0;35mmayday\\\\033[0m to clean up.\\n'\" \
    Enter"

  # ── Window 2: monitoring ──────────────────────────────────────────────
  eval "${tmux_cmd} new-window -t '${session}:2' -n 'monitor'"
  eval "${tmux_cmd} split-window -t '${session}:2' -h -p 50"

  if command -v gping &>/dev/null; then
    eval "${tmux_cmd} send-keys -t '${session}:2.0' \
      'gping 8.8.8.8 1.1.1.1' Enter"
  else
    eval "${tmux_cmd} send-keys -t '${session}:2.0' \
      'ping 8.8.8.8' Enter"
  fi
  eval "${tmux_cmd} send-keys -t '${session}:2.1' \
    'btop 2>/dev/null || htop 2>/dev/null || top' Enter"

  # ── Window 3: ops scratch ─────────────────────────────────────────────
  eval "${tmux_cmd} new-window -t '${session}:3' -n 'ops'"

  # Focus back on dashboard, interactive pane
  eval "${tmux_cmd} select-window -t '${session}:1'"
  eval "${tmux_cmd} select-pane  -t '${session}:1.2'"
}

# ── Standalone execution ──────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ghost_launch_dashboard
fi
