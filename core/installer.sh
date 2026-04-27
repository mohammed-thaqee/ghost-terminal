#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  core/installer.sh  —  Cosmetic package installer                   ║
# ║                                                                      ║
# ║  ONLY installs: cmatrix figlet lolcat oneko                         ║
# ║  zsh is handled by core/binaries.sh as a portable static binary     ║
# ║  These are visual/optional — mayday purges them.                    ║
# ║                                                                      ║
# ║  Daily tools (lsd bat fzf btop) are handled by core/binaries.sh     ║
# ║  as portable static binaries — no apt required.                     ║
# ╚══════════════════════════════════════════════════════════════════════╝

# Only these four — purely cosmetic, all purged by mayday
GHOST_PKGS=(cmatrix figlet lolcat oneko)
export GHOST_PKGS

export GHOST_READY_FLAG="${GHOST_TMPDIR}/.ready"
export GHOST_STATUSDIR="${GHOST_TMPDIR}/pkgstatus"
export GHOST_PIDS=()

# ── Resolve visuals/progress.sh ───────────────────────────────────────
_ghost_get_progress_script() {
  local local_path
  local_path="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/visuals/progress.sh"
  if [[ -f "$local_path" ]]; then
    printf '%s' "$local_path"
    return 0
  fi
  local remote="${GHOST_BASE}/visuals/progress.sh"
  local cached="${GHOST_TMPDIR}/progress.sh"
  if curl -fsSL "$remote" -o "$cached" 2>/dev/null; then
    chmod 700 "$cached"
    printf '%s' "$cached"
    return 0
  fi
  return 1
}

# ── Per-package worker script ─────────────────────────────────────────
# Written to tmpfs as a standalone script — avoids subshell inheritance
# issues and heredoc-in-heredoc quoting problems that caused v1 failures.
_ghost_write_worker() {
  local pkg="$1"
  local worker="${GHOST_TMPDIR}/worker_${pkg}.sh"

  cat > "$worker" <<WORKER
#!/usr/bin/env bash
PKG="${pkg}"
PASSFILE="${GHOST_PASSFILE}"
STATUSFILE="${GHOST_STATUSDIR}/${pkg}"

mark() { printf '%s' "\$1" > "\$STATUSFILE"; }
mark "INSTALLING"

# Fast-path: already installed
if dpkg -s "\$PKG" >/dev/null 2>&1; then
  mark "DONE"
  exit 0
fi

PASS=\$(cat "\$PASSFILE" 2>/dev/null)

run_apt() {
  if [[ "\$PASS" == "__cached__" ]]; then
    sudo apt-get install -y -q "\$PKG" >/dev/null 2>&1
  else
    printf '%s\n' "\$PASS" | sudo -S -v >/dev/null 2>&1
    printf '%s\n' "\$PASS" | sudo -S apt-get install -y -q "\$PKG" >/dev/null 2>&1
  fi
}

if run_apt; then
  mark "DONE"
  exit 0
fi

# One retry after apt lock may have cleared
sleep 4
if run_apt; then
  mark "DONE"
else
  mark "FAILED"
fi
WORKER

  chmod 700 "$worker"
  printf '%s' "$worker"
}

# ── Main installer ────────────────────────────────────────────────────

ghost_install_all() {
  # Skip entirely if no passfile — sudo unavailable
  if [[ ! -f "${GHOST_PASSFILE:-}" ]]; then
    gh_warn "Skipping cosmetic packages — no sudo credential"
    touch "$GHOST_READY_FLAG"
    return 0
  fi

  mkdir -p "$GHOST_STATUSDIR"

  # Pre-seed status files
  local pkg
  for pkg in "${GHOST_PKGS[@]}"; do
    printf 'QUEUED' > "${GHOST_STATUSDIR}/${pkg}"
  done

  # Write env dump for spawned progress window
  # (spawned terminals do not inherit shell variables)
  cat > "${GHOST_TMPDIR}/.env" <<ENV
export GHOST_TMPDIR="${GHOST_TMPDIR}"
export GHOST_STATUSDIR="${GHOST_STATUSDIR}"
export GHOST_PKGS="${GHOST_PKGS[*]}"
export GHOST_READY_FLAG="${GHOST_READY_FLAG}"
ENV
  chmod 600 "${GHOST_TMPDIR}/.env"

  gh_info "Installing cosmetic packages: ${GHOST_PKGS[*]}"

  # Spawn progress window before workers start
  local prog_script
  prog_script="$(_ghost_get_progress_script)"
  if [[ -n "$prog_script" ]]; then
    ghost_spawn_terminal "Ghost :: Package Deployment" \
      "source '${GHOST_TMPDIR}/.env'; bash '${prog_script}'" >/dev/null
  fi

  # Staggered parallel workers (1s apart to avoid apt lock races)
  local worker_pids=() stagger=0 worker
  for pkg in "${GHOST_PKGS[@]}"; do
    worker="$(_ghost_write_worker "$pkg")"
    ( sleep "$stagger"; bash "$worker" ) &
    worker_pids+=($!)
    (( stagger++ ))
  done

  # Wait for all workers
  local pid
  for pid in "${worker_pids[@]}"; do
    wait "$pid" 2>/dev/null
  done

  touch "$GHOST_READY_FLAG"

  # Summary
  printf '\n'
  for pkg in "${GHOST_PKGS[@]}"; do
    local st
    st="$(cat "${GHOST_STATUSDIR}/${pkg}" 2>/dev/null || printf 'UNKNOWN')"
    if [[ "$st" == "DONE" ]]; then
      gh_ok "${pkg}"
    elif dpkg -s "$pkg" >/dev/null 2>&1; then
      gh_ok "${pkg} (already present)"
      printf 'DONE' > "${GHOST_STATUSDIR}/${pkg}"
    else
      gh_warn "${pkg} — ${st}"
    fi
  done
  printf '\n'
}
