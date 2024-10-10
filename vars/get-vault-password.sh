#!/usr/bin/env bash

# Get the password for vars/secrets.yml.enc from Dashlane
# Requires dcli installed and logged

dcli note 'statox-setup secret file' | head -1
