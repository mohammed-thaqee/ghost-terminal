#!/bin/bash

# Ensure sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "[!] Run using:"
    echo "source <(curl -sL https://raw.githubusercontent.com/mohammed-thaqee/ghost-terminal/main/ghost.sh)"
    exit 1
fi

BASE_URL="https://raw.githubusercontent.com/mohammed-thaqee/ghost-terminal/main"

echo "[*] Initializing Ghost Terminal..."

# =========================
# 👻 GHOST MODE
# =========================
enable_ghost_mode() {
    history -c
    history -w

    unset HISTFILE
    export HISTSIZE=0
    export HISTFILESIZE=0
    set +o history

    export HISTCONTROL=ignoreboth
    export HISTIGNORE="*"

    echo "[✔] Ghost mode active"
}

# =========================
# 🧠 TERMINAL DETECTOR
# =========================
spawn_terminal() {
    CMD="$1"

    if command -v gnome-terminal &> /dev/null; then
        gnome-terminal -- bash -c "$CMD; exec bash"
    elif command -v xterm &> /dev/null; then
        xterm -e "$CMD" &
    else
        echo "[!] No supported terminal found. Running inline..."
        eval "$CMD" &
    fi
}

# =========================
# 📦 MODULE LOADER
# =========================
run_module() {
    MODULE_NAME="$1"

    spawn_terminal "bash <(curl -sL $BASE_URL/modules/$MODULE_NAME)"
}

# =========================
# 🚀 EXECUTION
# =========================
enable_ghost_mode

echo "[*] Launching modules..."

# Run modules in parallel terminals
run_module "visuals.sh"
run_module "oneko.sh"

echo "[✔] All modules launched"
echo "[✔] You can continue using this terminal"
