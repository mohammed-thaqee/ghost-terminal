#!/bin/bash

sudo apt-get update -y >/dev/null 2>&1
sudo apt-get install -y oneko >/dev/null 2>&1

oneko -tora &
