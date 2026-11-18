#!/usr/bin/env bash
# Sets the kernel read-ahead of a mounted filesystem.
#
# Usage: set-read-ahead.sh <mountpoint> <kb>
#
# The read-ahead of a FUSE mount (SSHFS) belongs to the mount's backing
# device info, /sys/class/bdi/<major:minor>/read_ahead_kb. Its default,
# 128 KB, is fixed when the filesystem is mounted, so it has to be set
# again after every mount. `mountpoint -d` gives the major:minor.
#
# BDI_ROOT overrides /sys/class/bdi (tests).
set -euo pipefail

mount_path=${1:?usage: set-read-ahead.sh <mountpoint> <kb>}
kb=${2:?usage: set-read-ahead.sh <mountpoint> <kb>}
bdi_root=${BDI_ROOT:-/sys/class/bdi}

if [[ ! $kb =~ ^[0-9]+$ ]]; then
    echo "read-ahead must be a number of KB, got '$kb'" >&2
    exit 1
fi

if ! bdi=$(mountpoint -d "$mount_path"); then
    echo "$mount_path is not mounted" >&2
    exit 1
fi

read_ahead_file="$bdi_root/$bdi/read_ahead_kb"
if [[ ! -f $read_ahead_file ]]; then
    echo "no read-ahead setting for $mount_path ($read_ahead_file)" >&2
    exit 1
fi

echo "$kb" > "$read_ahead_file"
echo "$mount_path: read_ahead_kb=$(cat "$read_ahead_file")"
