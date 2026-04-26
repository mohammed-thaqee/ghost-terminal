#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  modules/coding.sh  —  Dev environment aliases & helpers    ║
# ╚══════════════════════════════════════════════════════════════╝

# ── C / C++ ───────────────────────────────────────────────────
alias cc='gcc -Wall -Wextra -g'
alias cxx='g++ -Wall -Wextra -g -std=c++17'
alias mk='make -j$(nproc)'

ghost_c_run() {
  # Compile and run a .c file in one step
  local src="${1:?Usage: ghost_c_run <file.c>}"
  local out="${GHOST_TMPDIR}/ghost_bin_$(date +%s)"
  gcc -Wall -Wextra -g -o "$out" "$src" && "$out" "${@:2}"
}
alias crun='ghost_c_run'

# ── Python ────────────────────────────────────────────────────
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv'
alias activate='source ./venv/bin/activate 2>/dev/null || source ./.venv/bin/activate'

ghost_py_run() {
  local src="${1:?Usage: ghost_py_run <file.py>}"
  python3 "$src" "${@:2}"
}
alias pyrun='ghost_py_run'

# ── Java ──────────────────────────────────────────────────────
ghost_java_run() {
  local src="${1:?Usage: ghost_java_run <File.java>}"
  local dir
  dir="$(dirname "$src")"
  javac "$src" && java -cp "$dir" "${1%.java}" "${@:2}"
}
alias jrun='ghost_java_run'

# ── Quick HTTP server ─────────────────────────────────────────
alias serve='python3 -m http.server 8080'

# ── Git shortcuts ─────────────────────────────────────────────
alias gs='git status'
alias ga='git add -A'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --all --decorate'
alias gd='git diff --stat'

# ── Process / system ─────────────────────────────────────────
alias memtop='ps aux --sort=-%mem | head -15'
alias cputop='ps aux --sort=-%cpu | head -15'
alias dirsize='du -sh -- */ 2>/dev/null | sort -h'

# ── Quick file ops ────────────────────────────────────────────
alias ll='ls -lAh --color=auto'
alias la='ls -A --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# ── Scratch file ──────────────────────────────────────────────
ghost_scratch() {
  local ext="${1:-py}"
  local f="${GHOST_TMPDIR}/scratch.${ext}"
  touch "$f"
  "${EDITOR:-nano}" "$f"
  printf '%b  scratch file: %b%s%b\n' "${GH_DIM}" "${GH_CYN}" "$f" "${GH_RST}"
}
alias scratch='ghost_scratch'

# ── Timer ─────────────────────────────────────────────────────
ghost_timer() {
  local secs="${1:?Usage: ghost_timer <seconds>}"
  local start=$SECONDS
  while (( SECONDS - start < secs )); do
    local remaining=$(( secs - (SECONDS - start) ))
    printf '\r%b  ⏱  %d seconds remaining...%b  ' "${GH_YEL}" "$remaining" "${GH_RST}"
    sleep 1
  done
  printf '\r%b  ✔  Timer done!%b                   \n' "${GH_GRN}" "${GH_RST}"
}

# ── Menu ──────────────────────────────────────────────────────
ghost_coding_menu() {
  printf '\n%b  ── Ghost Coding Module ──%b\n\n' "${GH_CYN}${GH_BLD}" "${GH_RST}"
  printf '  %-22s %s\n' "crun <file.c>"     "compile + run C file"
  printf '  %-22s %s\n' "pyrun <file.py>"   "run Python file"
  printf '  %-22s %s\n' "jrun <File.java>"  "compile + run Java"
  printf '  %-22s %s\n' "cc / cxx"          "gcc / g++ with warnings"
  printf '  %-22s %s\n' "mk"                "make -j\$(nproc)"
  printf '  %-22s %s\n' "serve"             "HTTP server on :8080"
  printf '  %-22s %s\n' "scratch [ext]"     "open a tmpfs scratch file"
  printf '  %-22s %s\n' "ghost_timer <n>"   "countdown timer"
  printf '  %-22s %s\n' "gs/ga/gc/gp/gl"   "git shortcuts"
  printf '\n'
}
alias gcode='ghost_coding_menu'

gh_ok "Coding module loaded — type ${GH_MAG}gcode${GH_RST} for commands"
