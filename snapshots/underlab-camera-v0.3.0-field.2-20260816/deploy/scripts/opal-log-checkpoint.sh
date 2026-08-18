#!/bin/sh

PATH=/usr/bin:/bin:/usr/sbin:/sbin
OUTBOX_ENQUEUE=${D810_LOG_OUTBOX_ENQUEUE:-/usr/bin/opal-outbox-enqueue}
STATE_DIR=${D810_LOG_CHECKPOINT_STATE_DIR:-/root/d810-log-checkpoint}
LOCK_DIR=${D810_LOG_CHECKPOINT_LOCK:-/tmp/d810-log-checkpoint.lock}
FIELD_EVENTS=${D810D_FIELD_EVENT_LOG:-/root/d810-field-events.jsonl}
CAMERA_EVENTS=${D810D_GLOBAL_LOG:-/root/d810-camera-events.log}
WATCH_LOG_DIR=${D810_WATCH_LOG_DIR:-/root/d810-watch-logs}
SESSION_LOG_ROOT=${D810D_SESSION_LOG_ROOT:-/root/d810-sessions}
LIVE_REQUEST=${D810D_SESSION_LIVE_REQUEST:-/tmp/d810-session.live}
DEFER_PERIODIC_WHILE_LIVE=${D810D_DEFER_LOG_CHECKPOINT_WHILE_LIVE:-1}
ALLOW_FORCE_WHILE_LIVE=${D810_LOG_CHECKPOINT_ALLOW_LIVE_FORCE:-0}
DUPLICATE_FORCE=${D810_LOG_CHECKPOINT_DUPLICATE_FORCE:-0}
PENDING=${D810_LOG_CHECKPOINT_PENDING:-/tmp/d810-log-checkpoint.pending}
MODE=${1:-periodic}

case "$MODE" in
  boot|periodic|force) ;;
  *) printf 'invalid checkpoint mode\n' >&2; exit 2 ;;
esac

# Camera work owns CPU, memory and storage while live view is active. A force
# request becomes a pending checkpoint by default; shutdown/recovery callers
# can explicitly opt in when durability is more important than frame cadence.
if [ -e "$LIVE_REQUEST" ]; then
  if [ "$MODE" = "periodic" ] && [ "$DEFER_PERIODIC_WHILE_LIVE" = "1" ]; then
    : > "$PENDING" 2>/dev/null || true
    exit 0
  fi
  if [ "$MODE" = "force" ] && [ "$ALLOW_FORCE_WHILE_LIVE" != "1" ]; then
    : > "$PENDING" 2>/dev/null || true
    printf 'deferred-live\n'
    exit 0
  fi
fi

[ -x "$OUTBOX_ENQUEUE" ] || { printf 'outbox enqueue unavailable\n' >&2; exit 3; }
mkdir "$LOCK_DIR" 2>/dev/null || exit 0
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM HUP
mkdir -p "$STATE_DIR" || exit 1
checkpoint_count=0

state_key() {
  printf '%s' "$1" | sha256sum | awk '{print $1}'
}

checkpoint_file() {
  source=$1
  category=$2
  [ -s "$source" ] || return 0
  hash=$(sha256sum "$source" 2>/dev/null | awk '{print $1}')
  [ -n "$hash" ] || return 1
  key=$(state_key "$source")
  state="$STATE_DIR/$key.state"
  previous=$(sed -n 's/^sha256=//p' "$state" 2>/dev/null | head -n 1)
  if [ "$hash" = "$previous" ] && { [ "$MODE" != "force" ] || [ "$DUPLICATE_FORCE" != "1" ]; }; then
    return 0
  fi
  outbox_id=$("$OUTBOX_ENQUEUE" "$source" "$category") || return 1
  temp="$state.tmp.$$"
  {
    printf 'source=%s\n' "$source"
    printf 'sha256=%s\n' "$hash"
    printf 'outboxId=%s\n' "$outbox_id"
    printf 'checkpointed=%s\n' "$(date +%s)"
  } > "$temp" || return 1
  mv "$temp" "$state" || return 1
  checkpoint_count=$((checkpoint_count + 1))
}

checkpoint_file "$FIELD_EVENTS" field-events
checkpoint_file "$CAMERA_EVENTS" camera-events

for source in "$WATCH_LOG_DIR"/*.jsonl; do
  [ -f "$source" ] || continue
  checkpoint_file "$source" watch-timeline
done

if [ -r "$SESSION_LOG_ROOT/session.seq" ]; then
  session_id=$(cat "$SESSION_LOG_ROOT/session.seq" 2>/dev/null)
  case "$session_id" in
    ''|*[!0-9]*) session_id= ;;
  esac
  if [ -n "$session_id" ]; then
    session_label=$(printf '%03d_session' "$session_id")
    checkpoint_file "$SESSION_LOG_ROOT/$session_label/bridge.log" session-bridge
    checkpoint_file "$SESSION_LOG_ROOT/$session_label/ws.log" session-websocket
  fi
fi

# Avoid a global flash flush when every source already has an identical durable
# checkpoint. This makes repeated force/recovery calls cheap and deterministic.
if [ "$checkpoint_count" -gt 0 ]; then
  sync
fi
rm -f "$PENDING"
