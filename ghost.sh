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
# 🔐 SINGLE SUDO AUTH
# =========================
echo "[*] Requesting elevated access..."
sudo -v

# Keep sudo alive in background
( while true; do sudo -n true; sleep 60; done ) &
SUDO_KEEP_ALIVE_PID=$!

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
# 🎭 CUSTOM PROMPT
# =========================
set_prompt() {
    export PS1="agent@system > "
}

# =========================
# 🧠 TERMINAL SPAWNER
# =========================
spawn_terminal() {
    CMD="$1"

    if command -v gnome-terminal &> /dev/null; then
        gnome-terminal -- bash -c "$CMD"
    elif command -v xterm &> /dev/null; then
        xterm -e "$CMD" &
    else
        eval "$CMD" &
    fi
}

# =========================
# 📦 MODULE INSTALLER (BACKGROUND)
# =========================
install_module() {
    MODULE="$1"

    spawn_terminal "
        echo '[*] Installing $MODULE...';
        bash <(curl -sL $BASE_URL/modules/$MODULE);
        echo '[✔] Done';
        sleep 1
    "
}

# =========================
# 🎬 VISUALS (MAIN TERMINAL)
# =========================
run_visuals_main() {
    clear

    echo "[ OK ] Initializing kernel modules..."
    sleep 0.5
    echo "[ OK ] Establishing secure link..."
    sleep 0.5
    echo "[ OK ] Launching Ghost Interface..."
    sleep 0.5

    # Ensure tools installed (silent)
    sudo apt-get install -y cmatrix figlet lolcat >/dev/null 2>&1

    echo ""
    echo "[*] Loading..."
    sleep 1

    timeout 3s cmatrix -b

    clear

    figlet "AGENT" | lolcat

    echo ""
    echo "[✔] System Ready"
}

# =========================
# 🧹 CLEANUP
# =========================
cleanup() {
    echo ""
    echo "[!] Cleaning up..."

    kill $SUDO_KEEP_ALIVE_PID 2>/dev/null

    history -c
    history -w

    echo "[✔] Session cleared"
}

trap cleanup EXIT INT TERM

# =========================
# 🚀 EXECUTION FLOW
# =========================
enable_ghost_mode
set_prompt

# Spawn installers in background terminals
install_module "visuals.sh"
install_module "oneko.sh"

# Run visuals in MAIN terminal
run_visuals_main

echo ""
echo "[*] Modules installing in background..."
echo "[*] You can continue using this terminal"
