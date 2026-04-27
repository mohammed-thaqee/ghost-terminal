#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  core/binaries.sh  —  Portable binary manager                       ║
# ║                                                                      ║
# ║  Fetches lsd, bat, fzf, btop as static binaries into               ║
# ║  $GHOST_TMPDIR/bin/ and prepends to $PATH.                          ║
# ║                                                                      ║
# ║  Priority:                                                           ║
# ║    1. USB/local  → $GHOST_DIR/bin/<tool>                            ║
# ║    2. Cached     → $GHOST_TMPDIR/bin/<tool>  (already fetched)      ║
# ║    3. Network    → GitHub releases API → download → cache           ║
# ║    4. System     → already installed on the machine                 ║
# ║    5. Absent     → skip, warn, session continues                    ║
# ║                                                                      ║
# ║  Nothing is ever written outside $GHOST_TMPDIR.                     ║
# ╚══════════════════════════════════════════════════════════════════════╝

# ── Tool definitions ──────────────────────────────────────────────────
# Each entry: NAME|GITHUB_REPO|ASSET_PATTERN|BINARY_IN_ARCHIVE
# ASSET_PATTERN is an awk regex matched against the asset filename list
# BINARY_IN_ARCHIVE is the path inside the extracted archive ('' = direct)

declare -A _BIN_REPO _BIN_PATTERN _BIN_INNER _BIN_EXTRACT

_BIN_REPO[fzf]="junegunn/fzf"
_BIN_PATTERN[fzf]="linux_amd64\\.tar\\.gz$"
_BIN_INNER[fzf]="fzf"
_BIN_EXTRACT[fzf]="tar"

_BIN_REPO[bat]="sharkdp/bat"
_BIN_PATTERN[bat]="x86_64-unknown-linux-musl\\.tar\\.gz$"
_BIN_INNER[bat]="bat-*/bat"
_BIN_EXTRACT[bat]="tar"

_BIN_REPO[lsd]="lsd-rs/lsd"
_BIN_PATTERN[lsd]="x86_64-unknown-linux-musl\\.tar\\.gz$"
_BIN_INNER[lsd]="lsd-*/lsd"
_BIN_EXTRACT[lsd]="tar"

_BIN_REPO[btop]="aristocratsoftech/btop"
_BIN_PATTERN[btop]="x86_64-linux-musl\\.tbz$"
_BIN_INNER[btop]="btop/bin/btop"
_BIN_EXTRACT[btop]="tar"

# zsh — portable shell, core dependency
# romkatv/zsh-bin provides fully static musl builds
_BIN_REPO[zsh]="romkatv/zsh-bin"
_BIN_PATTERN[zsh]="zsh-[0-9].*-linux-x86_64\.tar\.gz$"
_BIN_INNER[zsh]="usr/bin/zsh"
_BIN_EXTRACT[zsh]="tar"

# Tool display order
# zsh first — session cannot start without it
_GHOST_BIN_TOOLS=(zsh fzf bat lsd btop)

# ── Helpers ───────────────────────────────────────────────────────────

_bin_log()  { printf "${GH_CYN}[BIN  ]${GH_RST} %s\n" "$*"; }
_bin_ok()   { printf "${GH_GRN}[ OK  ]${GH_RST} %s\n" "$*"; }
_bin_warn() { printf "${GH_YEL}[WARN ]${GH_RST} %s\n" "$*"; }
_bin_skip() { printf "${GH_DIM}[SKIP ]${GH_RST} %s\n" "$*"; }

_bin_fetch_latest_url() {
  # Returns the download URL for the latest release asset matching pattern
  # Usage: _bin_fetch_latest_url <repo> <pattern>
  local repo="$1" pattern="$2"
  local api_url="https://api.github.com/repos/${repo}/releases/latest"

  curl -fsSL "$api_url" 2>/dev/null \
    | grep '"browser_download_url"' \
    | awk -F'"' '{print $4}' \
    | grep -E "$pattern" \
    | head -1
}

_bin_install_one() {
  local tool="$1"
  local dest="${GHOST_TMPDIR}/bin/${tool}"
  local tmpwork="${GHOST_TMPDIR}/bin/.work_${tool}"

  # ── Priority 1: USB/local carry ──────────────────────────────────────
  if [[ -n "${GHOST_DIR:-}" && -f "${GHOST_DIR}/bin/${tool}" ]]; then
    cp "${GHOST_DIR}/bin/${tool}" "$dest"
    chmod 755 "$dest"
    _bin_ok "${tool} ← USB"
    return 0
  fi

  # ── Priority 2: already in tmpdir (session resumed or re-sourced) ────
  if [[ -x "$dest" ]]; then
    _bin_skip "${tool} already in session bin"
    return 0
  fi

  # ── Priority 3: network fetch ─────────────────────────────────────────
  if command -v curl &>/dev/null; then
    local repo="${_BIN_REPO[$tool]}"
    local pattern="${_BIN_PATTERN[$tool]}"
    local inner="${_BIN_INNER[$tool]}"
    local extract="${_BIN_EXTRACT[$tool]}"

    local url
    url="$(_bin_fetch_latest_url "$repo" "$pattern")"

    if [[ -n "$url" ]]; then
      local archive="${tmpwork}.archive"
      mkdir -p "$tmpwork"

      if curl -fsSL "$url" -o "$archive" 2>/dev/null; then
        case "$extract" in
          tar)
            tar -xf "$archive" -C "$tmpwork" 2>/dev/null
            # inner may contain glob like "bat-*/bat" — use find
            local binary
            binary=$(find "$tmpwork" -path "*/${inner#*/}" -type f 2>/dev/null \
                     | head -1)
            # fallback: direct match
            [[ -z "$binary" ]] && binary="${tmpwork}/${inner}"
            if [[ -f "$binary" ]]; then
              cp "$binary" "$dest"
              chmod 755 "$dest"
              rm -rf "$tmpwork" "$archive"
              _bin_ok "${tool} ← network (${repo})"
              return 0
            fi
            ;;
        esac
      fi
      rm -rf "$tmpwork" "$archive" 2>/dev/null
    fi
  fi

  # ── Priority 4: system install ────────────────────────────────────────
  local sys_bin
  # bat is installed as batcat on Ubuntu/Debian
  if [[ "$tool" == "bat" ]]; then
    sys_bin=$(command -v batcat 2>/dev/null || command -v bat 2>/dev/null)
  else
    sys_bin=$(command -v "$tool" 2>/dev/null)
  fi

  if [[ -n "$sys_bin" ]]; then
    # Symlink system binary into our bin dir so PATH priority works cleanly
    ln -sf "$sys_bin" "$dest"
    _bin_ok "${tool} ← system (${sys_bin})"
    return 0
  fi

  # ── Priority 5: absent ────────────────────────────────────────────────
  _bin_warn "${tool} unavailable — continuing without it"
  return 1
}

# ── Main entry point ──────────────────────────────────────────────────

ghost_setup_binaries() {
  local bindir="${GHOST_TMPDIR}/bin"
  mkdir -p "$bindir"

  # Prepend to PATH immediately so anything installed becomes available
  case ":${PATH}:" in
    *":${bindir}:"*) ;;
    *) export PATH="${bindir}:${PATH}" ;;
  esac

  _bin_log "Resolving portable binaries..."

  local tool
  for tool in "${_GHOST_BIN_TOOLS[@]}"; do
    _bin_install_one "$tool"
  done

  # bat quirk: if we got batcat from system, alias it
  if [[ -x "${bindir}/bat" ]] || command -v bat &>/dev/null; then
    : # fine
  elif command -v batcat &>/dev/null; then
    ln -sf "$(command -v batcat)" "${bindir}/bat"
  fi

  printf '\n'
}
