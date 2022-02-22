#!/usr/bin/env bash

BIN_DIRECTORY="$HOME/.bin"
BIN_PATH="$BIN_DIRECTORY/usql"

LATEST_RELEASE=$(curl -L -s -H 'Accept: application/json' https://github.com/xo/usql/releases/latest)
LATEST_VERSION=$(echo $LATEST_RELEASE | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
ARTIFACT_URL="https://github.com/xo/usql/releases/download/$LATEST_VERSION/usql-0.9.5-linux-amd64.tar.bz2"

if [ -f "$BIN_PATH" ]; then
    echo 'The file already exists'
else
    echo 'Installing new version'
    curl -L "$ARTIFACT_URL" --output /tmp/usql.tar.bz2
    tar -xf /tmp/usql.tar.bz2 -C "$BIN_DIRECTORY"
    chmod +x "$BIN_PATH"
fi
