#!/bin/sh

PATH=/usr/bin:/bin:/usr/sbin:/sbin
LOCK=/tmp/tailscale-sta-trigger.lock
STA_DEVICE=${D810_TAILSCALE_STA_DEVICE:-wlan-sta0}
CONTROL_PLANE=${D810_TAILSCALE_CONTROL_PLANE:-controlplane.tailscale.com}

[ "${ACTION:-}" = ifup ] || exit 0
[ -e "/sys/class/net/$STA_DEVICE" ] || exit 0
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT INT TERM

pidof tailscaled >/dev/null 2>&1 && exit 0
ip route show default | grep -q '^default ' || exit 0
nslookup "$CONTROL_PLANE" >/dev/null 2>&1 || exit 0
command -v nc >/dev/null 2>&1 || exit 0
command -v timeout >/dev/null 2>&1 || exit 0
timeout -t 3 nc "$CONTROL_PLANE" 443 </dev/null >/dev/null 2>&1 || exit 0

logger -t tailscale-sta "STA and Tailscale control plane ready; starting tailscaled"
/etc/init.d/tailscaled start >/dev/null 2>&1 || \
  logger -t tailscale-sta "tailscaled start failed"
