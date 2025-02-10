#!/usr/bin/env bash
#NOTE FOR WINDOWS USERS
#1.This script is written for linux so if using the vscode terminal on windows, make sure to set it to WSL terminal so it can run bash scripts.
#2. Make sure to have the xdg-open command installed on your system. If not, you can install it by running sudo apt-get install wslu
#3. Make sure to have the zip command installed on your system. If not, you can install it by running sudo apt-get install zip
#run in wsl terminal in this directory with 'bash create_extension.bash'

#Executing this script will zip the extension folder, rename it to extension.aseprite-extension, and double click it to prompt the install it in Aseprite.
printf "Creating extension.aseprite-extension\n"
zip -r extension.aseprite-extension extension
printf "Opening extension.aseprite-extension\n"
#if linux use xdg-open if windows use explorer
wslview extension.aseprite-extension
