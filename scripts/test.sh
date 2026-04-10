#!/usr/bin/env bash
# Run the reg-rs regression test suite for sw-cor24-forth
set -euo pipefail
reg-rs run -p tf24a --parallel "$@"
