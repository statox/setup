#!/usr/bin/env bats

setup() {
    DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
    SCRIPT="${DIR}/../set-read-ahead.sh"

    # Fake sysfs with one bdi, and a fake `mountpoint` first in PATH
    export BDI_ROOT="${BATS_TEST_TMPDIR}/bdi"
    mkdir -p "${BDI_ROOT}/0:397"
    echo 128 > "${BDI_ROOT}/0:397/read_ahead_kb"

    STUB_BIN="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "${STUB_BIN}"
    export PATH="${STUB_BIN}:${PATH}"
}

# Fake `mountpoint -d` printing $1 as the device, or failing when $1 is empty
stub_mountpoint() {
    if [ -n "$1" ]; then
        printf '#!/bin/sh\necho %s\n' "$1" > "${STUB_BIN}/mountpoint"
    else
        printf '#!/bin/sh\necho "$2 is not a mountpoint" >&2\nexit 32\n' > "${STUB_BIN}/mountpoint"
    fi
    chmod +x "${STUB_BIN}/mountpoint"
}

@test "writes kb to the mount's bdi" {
    stub_mountpoint 0:397
    run "$SCRIPT" /mnt/x 4096
    [ "$status" -eq 0 ]
    [ "$(cat "${BDI_ROOT}/0:397/read_ahead_kb")" = "4096" ]
}

@test "fails when the path is not a mountpoint" {
    stub_mountpoint ""
    run "$SCRIPT" /mnt/x 4096
    [ "$status" -ne 0 ]
    [[ "$output" == *"/mnt/x"* ]]
    [ "$(cat "${BDI_ROOT}/0:397/read_ahead_kb")" = "128" ]
}

@test "fails when the bdi file is missing" {
    stub_mountpoint 0:999
    run "$SCRIPT" /mnt/x 4096
    [ "$status" -ne 0 ]
    [ ! -e "${BDI_ROOT}/0:999/read_ahead_kb" ]
}

@test "fails on missing kb" {
    stub_mountpoint 0:397
    run "$SCRIPT" /mnt/x
    [ "$status" -ne 0 ]
    [ "$(cat "${BDI_ROOT}/0:397/read_ahead_kb")" = "128" ]
}

@test "fails on non-numeric kb" {
    stub_mountpoint 0:397
    run "$SCRIPT" /mnt/x abc
    [ "$status" -ne 0 ]
    [ "$(cat "${BDI_ROOT}/0:397/read_ahead_kb")" = "128" ]
}
