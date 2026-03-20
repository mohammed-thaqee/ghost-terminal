#!/bin/bash

# Ensure script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "[!] Please run using:"
    echo "source <(curl -sL https://raw.githubusercontent.com/mohammed-thaqee/ghost-terminal/main/ghost.sh)"
    exit 1
fi

echo "[*] Initializing Ghost Terminal..."

# =========================
# 👻 GHOST MODE ENABLE
# =========================
enable_ghost_mode() {
    echo "[*] Engaging Ghost Mode..."

    # Clear existing history
    history -c
    history -w

    # Disable history recording
    unset HISTFILE
    export HISTSIZE=0
    export HISTFILESIZE=0
    set +o history

    export HISTCONTROL=ignoreboth
    export HISTIGNORE="*"

    echo "[✔] History wiped and disabled"
}

# =========================
# 🧹 CLEANUP FUNCTION
# =========================
cleanup() {
    echo ""
    echo "[!] Cleaning up session..."

    # Clear history again
    history -c
    history -w

    echo "[✔] Session cleared"
}

# Trap exit signals
trap cleanup EXIT INT TERM

# Activate ghost mode
enable_ghost_mode

# =========================
# 🧠 TEST FUNCTION
# =========================
ghost_test() {
    echo "👻 Ghost Mode is ACTIVE"
}

echo ""
echo "=================================="
echo "   👻 GHOST TERMINAL ACTIVE"
echo "=================================="
echo "[*] Try running commands"
echo "[*] Then type: history"
echo "[*] Type 'exit' to quit"
echo ""
