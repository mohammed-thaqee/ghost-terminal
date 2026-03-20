#!/bin/bash

echo "[*] Visual module starting..."

# Install tools
sudo apt-get update -y >/dev/null 2>&1
sudo apt-get install -y cmatrix figlet lolcat >/dev/null 2>&1

# Boot sequence
clear
echo "[ OK ] Initializing system..."
sleep 0.5
echo "[ OK ] Loading modules..."
sleep 0.5
echo "[ OK ] Starting interface..."
sleep 0.5

# Matrix effect
timeout 5s cmatrix -b

clear

# Banner
figlet "GHOST" | lolcat

echo ""
echo "[✔] Visual module complete"

sleep 5
