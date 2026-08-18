#!/bin/sh

PATH=/usr/bin:/bin:/usr/sbin:/sbin
OUTBOX=${D810_OUTBOX_DIR:-/root/d810-outbox}
MIN_FREE_KB=${D810_OUTBOX_MIN_FREE_KB:-8192}
SOURCE=${1:-}
CATEGORY=${2:-misc}

[ -f "$SOURCE" ] || { printf 'source file not found\n' >&2; exit 2; }
case "$CATEGORY" in
  ''|*[!A-Za-z0-9_.-]*) printf 'invalid category\n' >&2; exit 2 ;;
esac

mkdir -p "$OUTBOX" || exit 1
free_kb=$(df -k "$OUTBOX" 2>/dev/null | awk 'NR==2 {print $4}')
case "$free_kb" in
  ''|*[!0-9]*) free_kb=0 ;;
esac
if [ "$free_kb" -lt "$MIN_FREE_KB" ]; then
  printf 'outbox paused: free space %sKB below safety floor %sKB\n' "$free_kb" "$MIN_FREE_KB" >&2
  exit 4
fi
base=$(basename "$SOURCE")
stamp=$(date +%Y%m%d-%H%M%S)
id="${stamp}-$$-${base}"
suffix=0
while [ -e "$OUTBOX/$id.payload" ] || [ -e "$OUTBOX/$id.manifest" ] || [ -e "$OUTBOX/$id.ready" ]; do
  suffix=$((suffix + 1))
  id="${stamp}-$$-$suffix-${base}"
done
payload="$OUTBOX/$id.payload"
manifest="$OUTBOX/$id.manifest"
ready="$OUTBOX/$id.ready"

cp "$SOURCE" "$payload.part" || { rm -f "$payload.part"; exit 1; }
size=$(wc -c < "$payload.part" | tr -d ' ')
sha256=$(sha256sum "$payload.part" | awk '{print $1}')
{
  printf 'id=%s\n' "$id"
  printf 'category=%s\n' "$CATEGORY"
  printf 'name=%s\n' "$base"
  printf 'size=%s\n' "$size"
  printf 'sha256=%s\n' "$sha256"
  printf 'created=%s\n' "$(date +%s)"
  printf 'source=%s\n' "$SOURCE"
} > "$manifest.part" || { rm -f "$payload.part" "$manifest.part"; exit 1; }
mv "$payload.part" "$payload" || exit 1
mv "$manifest.part" "$manifest" || exit 1
: > "$ready" || exit 1
printf '%s\n' "$id"
