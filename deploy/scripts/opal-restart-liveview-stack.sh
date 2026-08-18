#!/bin/sh
set -eu

lua -e 'assert(loadfile("/www/cgi-bin/d810bridge.lua"))'
lua -e 'assert(loadfile("/www/cgi-bin/d810ws.lua"))'

kill "$(cat /tmp/d810-bridge-v21.pid 2>/dev/null)" 2>/dev/null || true
kill "$(cat /tmp/d810-ws-v21.pid 2>/dev/null)" 2>/dev/null || true
sleep 1

/www/cgi-bin/session-manager
