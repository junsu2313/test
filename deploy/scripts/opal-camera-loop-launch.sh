#!/bin/sh

COUNT=${1:-10}
RUN_ROOT=${D810_TEST_RUN_ROOT:-/root/d810-test-runs}
mkdir -p "$RUN_ROOT"
launch_log="$RUN_ROOT/launch-$(date +%Y%m%d-%H%M%S).log"
printf '%s\n' "$launch_log" > "$RUN_ROOT/latest-launch-log"
exec /usr/bin/d810-camera-loop-runner "$COUNT" >> "$launch_log" 2>&1
