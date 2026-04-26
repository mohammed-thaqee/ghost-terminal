# ╔══════════════════════════════════════════════════════════════════════╗
# ║  env/zshrc  —  Ghost Terminal Zsh Configuration                     ║
# ║                                                                      ║
# ║  This file is NEVER copied to ~/.zshrc.                             ║
# ║  It is deployed to $GHOST_TMPDIR/.zshrc at session start.           ║
# ║  Zsh reads it because $ZDOTDIR=$GHOST_TMPDIR is set before exec.    ║
# ╚══════════════════════════════════════════════════════════════════════╝

# ── Powerlevel10k instant prompt ──────────────────────────────────────
# Must be near the very top, before any output
if [[ -r "${GHOST_TMPDIR}/.p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${GHOST_TMPDIR}/.p10k-instant-prompt-${(%):-%n}.zsh"
elif [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ── Colour helpers (re-export for zsh phase) ──────────────────────────
# These were exported by ghost.sh bash phase but re-declare for safety
export GH_RED='\033[0;31m'  GH_GRN='\033[0;32m'  GH_YEL='\033[1;33m'
export GH_CYN='\033[0;36m'  GH_MAG='\033[0;35m'  GH_WHT='\033[1;37m'
export GH_DIM='\033[2m'     GH_BLD='\033[1m'      GH_RST='\033[0m'

# ── Oh My Zsh ─────────────────────────────────────────────────────────
# Priority: tmpdir copy (carried/cloned) → system install
if [[ -d "${GHOST_TMPDIR}/oh-my-zsh" ]]; then
  export ZSH="${GHOST_TMPDIR}/oh-my-zsh"
elif [[ -d "${HOME}/.oh-my-zsh" ]]; then
  export ZSH="${HOME}/.oh-my-zsh"
fi

if [[ -n "${ZSH:-}" && -f "${ZSH}/oh-my-zsh.sh" ]]; then
  ZSH_THEME="powerlevel10k/powerlevel10k"

  plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    fzf
    sudo
    copypath
    dirhistory
    colored-man-pages
    command-not-found
  )

  # Disable Oh My Zsh auto-update (we're in a session, not a permanent install)
  zstyle ':omz:update' mode disabled

  source "${ZSH}/oh-my-zsh.sh"
else
  # Oh My Zsh not available — minimal fallback prompt
  autoload -Uz compinit && compinit 2>/dev/null
  autoload -Uz colors && colors 2>/dev/null
fi

# ── PATH: session bin dir first ───────────────────────────────────────
[[ -d "${GHOST_TMPDIR}/bin" ]] && \
  case ":${PATH}:" in
    *":${GHOST_TMPDIR}/bin:"*) ;;
    *) export PATH="${GHOST_TMPDIR}/bin:${PATH}" ;;
  esac

# ── Environment ───────────────────────────────────────────────────────
export EDITOR="${EDITOR:-nano}"
export VISUAL="${VISUAL:-nano}"

# Use bat as pager if available
if command -v bat &>/dev/null; then
  export PAGER="bat --paging=always"
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export BAT_THEME="TwoDark"
fi

# fzf colours and options (Tokyo Night palette)
export FZF_DEFAULT_OPTS="
  --height=40% --layout=reverse --border=rounded
  --color=fg:#c0caf5,bg:#1a1b26,hl:#bb9af7
  --color=fg+:#c0caf5,bg+:#292e42,hl+:#7dcfff
  --color=info:#7aa2f7,prompt:#7dcfff,pointer:#f7768e
  --color=marker:#9ece6a,spinner:#9ece6a,header:#9ece6a"
export FZF_DEFAULT_COMMAND='find . -type f -not -path "*/\.git/*" 2>/dev/null'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# fzf keybindings and completion (from session bin or system)
_fzf_base="${GHOST_TMPDIR}/fzf"
if [[ -f "${_fzf_base}/shell/key-bindings.zsh" ]]; then
  source "${_fzf_base}/shell/key-bindings.zsh"
  source "${_fzf_base}/shell/completion.zsh"
elif [[ -f "/usr/share/doc/fzf/examples/key-bindings.zsh" ]]; then
  source "/usr/share/doc/fzf/examples/key-bindings.zsh"
fi

# ── History — fully suppressed for ghost sessions ─────────────────────
unset HISTFILE
export HISTSIZE=0
export HISTFILESIZE=0
export SAVEHIST=0
setopt NO_HIST_SAVE      2>/dev/null
setopt NO_INC_APPEND_HISTORY 2>/dev/null
setopt HIST_IGNORE_ALL_DUPS  2>/dev/null

# ── Autosuggestions ───────────────────────────────────────────────────
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#565f89,bold"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
bindkey '^ ' autosuggest-accept      # Ctrl+Space accepts

# ── Syntax highlighting ───────────────────────────────────────────────
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)
typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=cyan,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=magenta,bold'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=red,bold'
ZSH_HIGHLIGHT_STYLES[path]='fg=white,underline'

# ── Completion ────────────────────────────────────────────────────────
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ── Zsh options ───────────────────────────────────────────────────────
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt CORRECT
setopt COMPLETE_IN_WORD
setopt NO_BEEP
setopt INTERACTIVE_COMMENTS    # allow # comments in interactive shell

# ── Key bindings ──────────────────────────────────────────────────────
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[^[[C' forward-word
bindkey '^[^[[D' backward-word
bindkey '^H'  backward-kill-word

# ════════════════════════════════════════════════════════════════════════
#  ALIASES
# ════════════════════════════════════════════════════════════════════════

# ── Navigation ────────────────────────────────────────────────────────
command -v lsd &>/dev/null && {
  alias ls='lsd'
  alias ll='lsd -lAh --git'
  alias la='lsd -A'
  alias lt='lsd --tree --depth=2'
} || {
  alias ll='ls -lAh --color=auto'
  alias la='ls -A --color=auto'
}

command -v bat &>/dev/null && {
  alias cat='bat --paging=never'
  alias less='bat --paging=always'
}

alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# ── System ────────────────────────────────────────────────────────────
command -v btop &>/dev/null && alias top='btop'
alias df='df -h'
alias du='du -sh'
alias free='free -h'
alias ports='ss -tulnp'
alias conns='ss -tnp'
alias myip='curl -s ifconfig.me && echo'
alias localnet='ip -br a'

# ── Dev ───────────────────────────────────────────────────────────────
alias py='python3'
alias pip='pip3'
alias gs='git status'
alias ga='git add -A'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --all --decorate'
alias gd='git diff --stat'
alias mk='make -j$(nproc)'
alias serve='python3 -m http.server 8080'

# ── Ghost ─────────────────────────────────────────────────────────────
alias ghack='ghost_hacking_menu 2>/dev/null || printf "Load ghost.sh first\n"'
alias gcode='ghost_coding_menu  2>/dev/null || printf "Load ghost.sh first\n"'

# ════════════════════════════════════════════════════════════════════════
#  FZF HELPERS
# ════════════════════════════════════════════════════════════════════════

# File open with bat preview
fopen() {
  local file
  file=$(find . -type f 2>/dev/null \
    | fzf --preview 'bat --color=always --line-range :100 {} 2>/dev/null || cat {}' \
          --preview-window=right:60%:wrap)
  [[ -n "$file" ]] && "${EDITOR:-nano}" "$file"
}

# cd with fzf
fcd() {
  local dir
  dir=$(find . -type d 2>/dev/null \
    | fzf --preview 'ls --color=always {} 2>/dev/null')
  [[ -n "$dir" ]] && cd "$dir"
}

# Kill process with fzf
fkill() {
  local pid
  pid=$(ps aux \
    | fzf --header='Select process to kill' --header-lines=1 \
    | awk '{print $2}')
  [[ -n "$pid" ]] && kill -9 "$pid" \
    && printf '%b[KILL]%b PID %s terminated\n' \
       "${GH_RED}" "${GH_RST}" "$pid"
}

# Git branch checkout with fzf
fgb() {
  local branch
  branch=$(git branch --all 2>/dev/null \
    | grep -v HEAD \
    | fzf --preview 'git log --oneline --graph --color=always {}' \
    | sed 's/remotes\/origin\///' | tr -d ' *')
  [[ -n "$branch" ]] && git checkout "$branch"
}

# fzf history search (override Ctrl+R)
fhist() {
  print -z "$(fc -l 1 2>/dev/null \
    | fzf --tac --no-sort \
    | sed 's/ *[0-9]* *//')"
}

# ════════════════════════════════════════════════════════════════════════
#  GHOST MODULE INIT  (runs once per session, not per pane)
# ════════════════════════════════════════════════════════════════════════

_ghost_zsh_init() {
  # GHOST_ZSHRC_INIT flag prevents re-running on every new tmux pane
  [[ -n "${GHOST_ZSHRC_INIT:-}" ]] && return 0
  export GHOST_ZSHRC_INIT=1

  # Load ghost modules (already loaded in bash phase, but reload
  # ensures functions are available in the zsh environment)
  local _ghost_module_loader="${GHOST_TMPDIR}/mod_ghost_loader.sh"

  if [[ -n "${GHOST_DIR:-}" ]]; then
    # Load from local files
    for _mod in hacking coding; do
      local _mod_file="${GHOST_DIR}/modules/${_mod}.sh"
      [[ -f "$_mod_file" ]] && source "$_mod_file" 2>/dev/null || true
    done
  fi

  # Show banner on first interactive shell
  if [[ -o interactive ]]; then
    # Small pause so p10k prompt renders first
    sleep 0.1
    ghost_show_banner 2>/dev/null || true
    _ghost_print_commands
  fi
}

_ghost_print_commands() {
  printf '%b  %-22s%b %s\n' \
    "${GH_DIM}" "mayday"                 "${GH_RST}" "— full cleanup and self-destruct"
  printf '%b  %-22s%b %s\n' \
    "${GH_DIM}" "ghost_launch_dashboard" "${GH_RST}" "— open tmux 3-pane dashboard"
  printf '%b  %-22s%b %s\n' \
    "${GH_DIM}" "ghack"                  "${GH_RST}" "— hacking module commands"
  printf '%b  %-22s%b %s\n' \
    "${GH_DIM}" "gcode"                  "${GH_RST}" "— coding module commands"
  printf '%b  %-22s%b %s\n' \
    "${GH_DIM}" "fopen / fcd / fkill"   "${GH_RST}" "— fzf file, directory, process"
  printf '\n'
}

# Run init for first interactive shell
[[ -o interactive ]] && _ghost_zsh_init

# ── Powerlevel10k config ──────────────────────────────────────────────
# Looks in ZDOTDIR ($GHOST_TMPDIR) first, then home
if [[ -f "${GHOST_TMPDIR}/.p10k.zsh" ]]; then
  source "${GHOST_TMPDIR}/.p10k.zsh"
elif [[ -f "${HOME}/.p10k.zsh" ]]; then
  source "${HOME}/.p10k.zsh"
fi
