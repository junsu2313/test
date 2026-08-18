#!/bin/sh

PATH=/usr/bin:/bin:/usr/sbin:/sbin

LOG_DIR=${D810_WATCH_LOG_DIR:-/root/d810-watch-logs}
LOG=${D810_WATCH_LOG:-$LOG_DIR/timeline-$(date +%Y%m%d).jsonl}
STATE=${D810_WATCH_STATE:-/tmp/d810-boot-watch.state}
INTERVAL=${D810_WATCH_INTERVAL:-1}
STATUS_INTERVAL=${D810_WATCH_STATUS_INTERVAL:-2}
HEARTBEAT_INTERVAL=${D810_WATCH_HEARTBEAT_INTERVAL:-10}
CHECKPOINT_INTERVAL=${D810_WATCH_CHECKPOINT_INTERVAL:-60}
CHECKPOINT_SCRIPT=${D810_WATCH_CHECKPOINT_SCRIPT:-/usr/bin/d810-log-checkpoint}
STATUS_SCRIPT=${D810_WATCH_STATUS_SCRIPT:-/www/cgi-bin/status-v21}
CONFIG=${D810_WATCH_CONFIG:-/etc/d810-boot-watch.conf}
LOCK_DIR=${D810_WATCH_LOCK:-/tmp/d810-boot-watch.lock}

acquire_singleton() {
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        printf '%s\n' "$$" > "$LOCK_DIR/pid"
        return 0
    fi
    owner=$(cat "$LOCK_DIR/pid" 2>/dev/null || true)
    if [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null; then
        return 1
    fi
    rm -f "$LOCK_DIR/pid"
    rmdir "$LOCK_DIR" 2>/dev/null || return 1
    mkdir "$LOCK_DIR" 2>/dev/null || return 1
    printf '%s\n' "$$" > "$LOCK_DIR/pid"
}

release_singleton() {
    owner=$(cat "$LOCK_DIR/pid" 2>/dev/null || true)
    [ "$owner" = "$$" ] || return 0
    rm -f "$LOCK_DIR/pid"
    rmdir "$LOCK_DIR" 2>/dev/null || true
}

acquire_singleton || exit 0
trap 'release_singleton' EXIT INT TERM HUP

mkdir -p "$LOG_DIR" "$(dirname "$LOG")"
touch "$LOG" "$STATE"
[ -r "$CONFIG" ] && . "$CONFIG"

now() { date '+%Y-%m-%dT%H:%M:%S%z'; }
uptime_s() { awk '{print $1}' /proc/uptime 2>/dev/null || printf '0'; }

emit() {
    event=$1
    detail=${2:-}
    printf '{"wall":"%s","uptime_s":"%s","event":"%s"%s}\n' \
        "$(now)" "$(uptime_s)" "$event" "$detail" >> "$LOG"
    logger -t d810-boot-watch "$event${detail:+ $detail}"
}

state_get() {
    key=$1
    sed -n "s/^${key}=//p" "$STATE" | tail -n 1
}

state_set() {
    key=$1
    value=$2
    tmp="${STATE}.tmp"
    sed "/^${key}=/d" "$STATE" > "$tmp"
    printf '%s=%s\n' "$key" "$value" >> "$tmp"
    mv "$tmp" "$STATE"
}

station_role() {
    mac=$1
    host=${2:-}
    [ -n "${D810_S10_MAC:-}" ] && [ "$mac" = "$D810_S10_MAC" ] && { printf 's10'; return; }
    [ -n "${D810_DESKTOP_MAC:-}" ] && [ "$mac" = "$D810_DESKTOP_MAC" ] && { printf 'desktop'; return; }
    case "$host" in
        *S10*|*s10*) printf 's10'; return ;;
        *DESKTOP*|*desktop*|*WIN*|*win*) printf 'desktop'; return ;;
    esac
    printf 'unknown'
}

dhcp_name() {
    mac=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    awk -v mac="$mac" 'tolower($2)==mac {print $4; exit}' /tmp/dhcp.leases 2>/dev/null
}

station_snapshot() {
    for iface in $(iw dev 2>/dev/null | awk '$1=="Interface" {print $2}'); do
        iw dev "$iface" station dump 2>/dev/null | awk -v iface="$iface" \
            '$1=="Station" {print iface " " tolower($2)}'
    done
}

service_probe() {
    bridge=0
    ddserver=0
    [ -s /tmp/d810-bridge-v21.pid ] && kill -0 "$(cat /tmp/d810-bridge-v21.pid 2>/dev/null)" 2>/dev/null && bridge=1
    pidof ddserver >/dev/null 2>&1 && ddserver=1
    printf '%s:%s' "$bridge" "$ddserver"
}

camera_probe() {
    result=$(QUERY_STRING=watchdog "$STATUS_SCRIPT" 2>/dev/null || true)
    case "$result" in
        *'"ok":true'*)
            case "$result" in
                *'"cameraDetected":true'*'"transportReady":true'*|*'"transportReady":true'*'"cameraDetected":true'*) printf 'ready'; return ;;
            esac
            ;;
    esac
    case "$result" in
        *'"cameraDetected":true'*) printf 'detected' ;;
        *'bridge_unavailable'*) printf 'bridge_unavailable' ;;
        *) printf 'not_ready' ;;
    esac
}

app_probe() {
    # The UI keeps a WebSocket open to the camera service. This gives us a
    # durable signal that the app reached Opal, without changing the app.
    netstat -tn 2>/dev/null | awk '$4 ~ /:8191$/ && $6 == "ESTABLISHED" {print $5; exit}'
}

pidfile_value() {
    pidfile=$1
    [ -s "$pidfile" ] || { printf '0'; return; }
    pid=$(cat "$pidfile" 2>/dev/null)
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && printf '%s' "$pid" || printf '0'
}

pidof_value() {
    pidof "$1" 2>/dev/null | awk '{print $1}'
}

nikon_usb_count() {
    count=0
    for vendor_file in /sys/bus/usb/devices/*/idVendor; do
        [ -r "$vendor_file" ] || continue
        [ "$(cat "$vendor_file" 2>/dev/null)" = "04b0" ] && count=$((count + 1))
    done
    printf '%s' "$count"
}

memory_available_kb() {
    awk '$1=="MemAvailable:" {print $2; found=1; exit} END {if (!found) print 0}' /proc/meminfo 2>/dev/null
}

heartbeat() {
    stations_value=$(state_get stations)
    station_count=$(printf '%s' "$stations_value" | awk -F'|' '{count=NF-1; if (count < 0) count=0; print count}')
    ddserver_pid=$(pidof_value ddserver)
    web_pid=$(pidof_value nginx)
    [ -n "$web_pid" ] || web_pid=$(pidof_value uhttpd)
    emit heartbeat ',"stations":'"$station_count"',"ddserver_pid":'"${ddserver_pid:-0}"',"bridge_pid":'"$(pidfile_value /tmp/d810-bridge-v21.pid)"',"websocket_pid":'"$(pidfile_value /tmp/d810-ws-v21.pid)"',"frame_refresh_pid":'"$(pidfile_value /tmp/d810-live-v21-refresh.pid)"',"runtime_guardian_pid":'"$(pidfile_value /tmp/d810-runtime-guardian.pid)"',"stack_guardian_pid":'"$(pidfile_value /tmp/d810-stack-guardian.pid)"',"session_health_pid":'"$(pidfile_value /tmp/d810-session-health.pid)"',"battery_worker_pid":'"$(pidfile_value /tmp/d810-battery-worker.pid)"',"web_pid":'"${web_pid:-0}"',"camera":"'"${last_camera:-unknown}"'","app":"'"${last_app:-}"'","nikon_usb":'"$(nikon_usb_count)"',"mem_available_kb":'"$(memory_available_kb)"
}

emit boot_started ',"pid":"'"$$"'"'
if [ -x "$CHECKPOINT_SCRIPT" ]; then
    if "$CHECKPOINT_SCRIPT" boot; then
        emit log_recovery_checkpoint_complete
    else
        emit log_recovery_checkpoint_failed
    fi
fi

last_stations=''
last_service=''
last_camera=''
last_app=''
status_tick=0
heartbeat_tick=0
checkpoint_tick=0

while :; do
    stations=$(station_snapshot | sort | tr '\n' '|')
    old_stations=$(state_get stations)
    printf '%s' "$stations" | tr '|' '\n' | while read -r row; do
        [ -n "$row" ] || continue
        iface=${row%% *}
        mac=${row##* }
        printf '%s' "$old_stations" | tr '|' '\n' | grep -F " $mac" >/dev/null 2>&1 && continue
        host=$(dhcp_name "$mac")
        role=$(station_role "$mac" "$host")
        emit wifi_station_connected ',"iface":"'"$iface"'","mac":"'"$mac"'","role":"'"$role"'","dhcp":"'"${host:-}"'"'
    done
    printf '%s' "$old_stations" | tr '|' '\n' | while read -r row; do
        [ -n "$row" ] || continue
        mac=${row##* }
        printf '%s' "$stations" | tr '|' '\n' | grep -F " $mac" >/dev/null 2>&1 && continue
        emit wifi_station_disconnected ',"mac":"'"$mac"'","role":"'"$(station_role "$mac" "$(dhcp_name "$mac")")"'"'
    done
    state_set stations "$stations"

    service=$(service_probe)
    if [ "$service" != "${last_service:-}" ]; then
        case "$service" in
            1:1) emit service_ready ',"bridge":true,"ddserver":true' ;;
            *)
                if [ -n "${last_service:-}" ]; then
                    emit service_not_ready ',"value":"'"$service"'"'
                else
                    emit service_not_ready ',"value":"'"$service"'","initial":true'
                fi
                ;;
        esac
        last_service=$service
    fi

    status_tick=$((status_tick + 1))
    heartbeat_tick=$((heartbeat_tick + 1))
    checkpoint_tick=$((checkpoint_tick + 1))
    if [ "$status_tick" -ge "$STATUS_INTERVAL" ]; then
        camera=$(camera_probe)
        if [ "$camera" != "${last_camera:-}" ]; then
            case "$camera" in
                ready) emit camera_ready ',"probe":"status-v21"' ;;
                detected) emit camera_detected ',"probe":"status-v21"' ;;
                *)
                    if [ -n "${last_camera:-}" ]; then
                        emit camera_not_ready ',"state":"'"$camera"'"'
                    else
                        emit camera_not_ready ',"state":"'"$camera"'","initial":true'
                    fi
                    ;;
            esac
            last_camera=$camera
        fi
        app=$(app_probe)
        if [ -n "$app" ] && [ -z "${last_app:-}" ]; then
            emit app_connected ',"peer":"'"$app"'"'
        elif [ -z "$app" ] && [ -n "${last_app:-}" ]; then
            emit app_disconnected
        fi
        last_app=$app
        status_tick=0
    fi
    if [ "$heartbeat_tick" -ge "$HEARTBEAT_INTERVAL" ]; then
        heartbeat
        heartbeat_tick=0
    fi
    if [ "$checkpoint_tick" -ge "$CHECKPOINT_INTERVAL" ]; then
        if [ -x "$CHECKPOINT_SCRIPT" ]; then
            "$CHECKPOINT_SCRIPT" periodic || emit log_checkpoint_failed
        fi
        checkpoint_tick=0
    fi
    sleep "$INTERVAL"
done
