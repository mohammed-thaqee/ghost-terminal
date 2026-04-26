#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  core/sudo.sh  —  One-time sudo acquisition                         ║
# ║  Credential stored chmod-600 in $GHOST_TMPDIR/.sp (tmpfs only)      ║
# ╚══════════════════════════════════════════════════════════════════════╝

export GHOST_PASSFILE="${GHOST_TMPDIR}/.sp"

ghost_acquire_sudo() {
  # Already cached from a previous sudo call this session?
  if sudo -n true 2>/dev/null; then
    printf '__cached__' > "$GHOST_PASSFILE"
    chmod 600 "$GHOST_PASSFILE"
    gh_ok "Elevated access already cached"
    return 0
  fi

  printf '\n%b[AUTH]%b Elevated access needed for cosmetic packages.\n' \
    "${GH_YEL}${GH_BLD}" "${GH_RST}"
  printf '  %bStored once in tmpfs — auto-wiped on mayday.%b\n\n' \
    "${GH_DIM}" "${GH_RST}"

  local attempts=0 _pass
  while (( attempts < 3 )); do
    IFS= read -rsp "$(printf '%b%s%b %bpassword:%b ' \
      "${GH_CYN}" "${GHOST_IDENTITY}" "${GH_RST}" \
      "${GH_DIM}" "${GH_RST}")" _pass
    printf '\n'

    if printf '%s\n' "$_pass" | sudo -S true 2>/dev/null; then
      printf '%s' "$_pass" > "$GHOST_PASSFILE"
      chmod 600 "$GHOST_PASSFILE"
      unset _pass
      gh_ok "Access granted — credential in tmpfs"
      return 0
    fi

    unset _pass
    (( attempts++ ))
    gh_err "Authentication failed (${attempts}/3)"
    sleep 0.5
  done

  gh_warn "Skipping sudo — cosmetic packages unavailable"
  return 1
}
