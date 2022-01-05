#!/bin/bash

# Arch Linux Installer #1 by Franjo Pusticki
# --------------------------------------------------------

# SET KEYMAP
loadkeys croat

# SET TIME
timedatectl set-timezone Europe/Zagreb
timedatectl set-ntp true

# INTERNET
read -p "Do you want to connect to wifi? (y/n): " wifi
if [ "$wifi" = "y" ]
then
  iwctl device list
  read -p "Enter you wifi network name: " mynetwork
  iwctl station wlan0 connect "$mynetwork"
else
  sleep 1
fi
