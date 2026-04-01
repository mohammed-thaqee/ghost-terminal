#!/bin/bash

# Ensure sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "[!] Run using:"
    echo "source <(curl -sL https://raw.githubusercontent.com/mohammed-thaqee/ghost-terminal/main/ghost.sh)"
    exit 1
fi

echo "[*] Initializing Ghost Terminal..."

# =========================
# 🔐 GET SUDO PASSWORD ONCE
# =========================
echo "[*] Enter sudo password:"
read -s SUDO_PASS
echo ""

echo "$SUDO_PASS" | sudo -S -v >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "[✘] Incorrect password"
    unset SUDO_PASS
    return 1
fi

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
}

# =========================
# 🎭 CUSTOM PROMPT
# =========================
set_prompt() {
    export ORIGINAL_PS1="$PS1"
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
# 📊 SIMULATED PROGRESS
# =========================
simulate_progress() {
    packages=("cmatrix" "figlet" "lolcat" "oneko")
    total=${#packages[@]}
    progress=0

    for pkg in "${packages[@]}"; do
        echo "[*] Downloading $pkg..."

        for i in {1..5}; do
            progress=$((progress + (100 / (total * 5))))
            printf "\r[%-50s] %d%%" "$(printf '#%.0s' $(seq 1 $((progress/2))))" "$progress"
            sleep 0.2
        done

        echo -e "\n[✔] $pkg installed"
    done

    echo -e "\n[✔] All packages ready (100%)"
}

# =========================
# 📦 PARALLEL INSTALL
# =========================
parallel_install() {
    echo "[*] Installing dependencies..."

    echo "$SUDO_PASS" | sudo -S apt-get update -y >/dev/null 2>&1

    # Real installs in background
    for pkg in cmatrix figlet lolcat oneko; do
        echo "$SUDO_PASS" | sudo -S apt-get install -y $pkg >/dev/null 2>&1 &
    done

    # Visual installer
    spawn_terminal "
        $(declare -f simulate_progress)
        simulate_progress
        sleep 1
    "

    wait

    echo "[✔] All packages installed"
}

# =========================
# 🐱 ONEKO
# =========================
run_oneko() {
    spawn_terminal "
        oneko -tora;
    "
}

# =========================
# 🎬 VISUALS
# =========================
run_visuals_main() {
    clear

    echo "[ OK ] Initializing kernel modules..."
    sleep 0.5
    echo "[ OK ] Establishing secure link..."
    sleep 0.5
    echo "[ OK ] Launching Ghost Interface..."
    sleep 0.5

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
# 💣 MAYDAY (FULL PURGE)
# =========================
mayday() {
    echo ""
    echo "[!!!] MAYDAY INITIATED"
    echo "[*] Purging system..."

    pkill oneko 2>/dev/null
    kill $INSTALL_PID 2>/dev/null

    echo "$SUDO_PASS" | sudo -S apt-get remove -y cmatrix figlet lolcat oneko >/dev/null 2>&1
    echo "$SUDO_PASS" | sudo -S apt-get autoremove -y >/dev/null 2>&1

    export HISTFILE=~/.bash_history
    export HISTSIZE=1000
    export HISTFILESIZE=2000
    set -o history

    history -c
    history -w

    export PS1="$ORIGINAL_PS1"

    unset SUDO_PASS

    echo "[✔] System restored"
    echo "[✔] No trace remains"

    reset
    clear

    return
}

alias mayday=mayday

# =========================
# 🧹 CLEANUP
# =========================
cleanup() {
    history -c
    history -w
    unset SUDO_PASS
}

trap cleanup EXIT INT TERM

# =========================
# 🚀 EXECUTION FLOW
# =========================
enable_ghost_mode
set_prompt

parallel_install &
INSTALL_PID=$!

# Minimal fallback visuals while installing
echo "[*] Booting system..."
sleep 1

wait $INSTALL_PID

# Now safe to use installed tools
run_visuals_main

run_oneko

echo ""
echo "[✔] System fully operational"
echo "[*] Type 'mayday' for emergency purge"
