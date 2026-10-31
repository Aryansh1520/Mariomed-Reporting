#!/usr/bin/env bash
# Local dev only. Starts My Mariomed on Linux with hot reload and opens it on workspace 1.
#
#   scripts/run-linux.sh          start the app, or hot reload it if it is already running
#   scripts/run-linux.sh restart  full restart, for changes hot reload cannot apply
#   scripts/run-linux.sh stop     stop the running app
#
# The API must be running: docker compose up -d
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/mobile"
STATE="${XDG_RUNTIME_DIR:-/tmp}/mymariomed-dev"
FIFO="$STATE/stdin"
LOG="$STATE/flutter.log"
PIDFILE="$STATE/pid"
export PATH="$HOME/develop/flutter/bin:$PATH"

is_running() { [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

send() { printf '%s\n' "$1" > "$FIFO"; }

case "${1:-start}" in
  stop)
    if is_running; then send q; sleep 2; fi
    pkill -x field_sales_app 2>/dev/null || true
    rm -f "$PIDFILE"
    echo "My Mariomed stopped"
    exit 0
    ;;
  restart)
    if is_running; then send R; echo "full restart sent"; exit 0; fi
    ;;
  start)
    if is_running; then send r; echo "hot reload sent"; exit 0; fi
    ;;
  *) echo "usage: $0 [start|restart|stop]"; exit 1 ;;
esac

# Nothing is running: start a flutter session that reads commands from a FIFO.
mkdir -p "$STATE"
rm -f "$FIFO"; mkfifo "$FIFO"
pkill -x field_sales_app 2>/dev/null || true
cd "$MOBILE"
# Holds the FIFO open for writing, so flutter keeps reading commands.
exec 3<>"$FIFO"
nohup flutter run -d linux \
  --dart-define=API_BASE_URL=http://localhost:8200/api/v1 \
  < "$FIFO" > "$LOG" 2>&1 &
echo $! > "$PIDFILE"

# Move the window to workspace 1 as soon as it appears, without switching to it.
for _ in $(seq 1 120); do
  if hyprctl clients -j | grep -q '"class": "com.mariomed.mymariomed"'; then
    hyprctl dispatch movetoworkspacesilent "1,class:com.mariomed.mymariomed" >/dev/null
    echo "My Mariomed started on workspace 1 (hot reload enabled)"
    exit 0
  fi
  sleep 1
done
echo "build is still running; check $LOG"
