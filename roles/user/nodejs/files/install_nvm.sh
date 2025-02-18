#!/usr/bin/env bash

LATEST_RELEASE=$(curl -L -s -H 'Accept: application/json' https://github.com/nvm-sh/nvm/releases/latest)
LATEST_VERSION=$(echo "$LATEST_RELEASE" | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/nvm-sh/nvm/$LATEST_VERSION/install.sh"

mkdir -p "$HOME/.config/nvm"
curl -o- "$INSTALL_SCRIPT_URL" | bash
