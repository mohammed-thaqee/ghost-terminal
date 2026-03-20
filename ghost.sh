#!/bin/bash

echo "[*] Ghost Terminal Loaded in Current Shell"
echo "[*] This session is now controlled"

# Simple proof it works
export GHOST_ACTIVE=true

ghost_test() {
    echo "Ghost Mode Active: $GHOST_ACTIVE"
}

echo "[✔] Type 'ghost_test' to verify"
