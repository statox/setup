#!/usr/bin/env bash

BIN_DIRECTORY="$HOME/.bin"
BIN_PATH="$BIN_DIRECTORY/espanso"

LATEST_RELEASE=$(curl -L -s -H 'Accept: application/json' https://github.com/espanso/espanso/releases/latest)
LATEST_VERSION=$(echo $LATEST_RELEASE | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
ARTIFACT_URL="https://github.com/espanso/espanso/releases/download/$LATEST_VERSION/Espanso-X11.AppImage"
CHECKSUM_URL="https://github.com/espanso/espanso/releases/download/$LATEST_VERSION/Espanso-X11.AppImage.sha256.txt"

new_checksum_response=$(curl -L $CHECKSUM_URL)
new_checksum=$(echo $new_checksum_response | cut -d ' ' -f 1)

if [ -f "$BIN_PATH" ]; then
    echo 'The file already exists'
    current_checksum=$(sha256sum $BIN_PATH | cut -d ' ' -f 1)
    echo $current_checksum

    if [ "$current_checksum" == "$new_checksum" ]; then
        echo 'Latest version already installed. Finished'
        exit 0
    fi
    echo 'Saving old version'
    cp "$BIN_PATH" "$BIN_PATH"_previous
fi

echo 'Installing new version'
curl -L "$ARTIFACT_URL" --output "$BIN_PATH"
chmod +x "$BIN_PATH"

$BIN_PATH service register
$BIN_PATH service start
