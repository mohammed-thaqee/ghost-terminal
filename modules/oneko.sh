#!/bin/bash

echo "[*] oneko module starting..."

# Install oneko
sudo apt-get update -y >/dev/null 2>&1
sudo apt-get install -y oneko >/dev/null 2>&1

# Run oneko
oneko -tora &

echo "[✔] oneko running"

# Keep terminal alive briefly
sleep 10
