#!/usr/bin/env bash
# Install extensions one by one. Works on all architectures and avoids
# the "Canceled" issue seen when batching --install-extension flags.
# Usage: install-extensions.sh [list-file]
set -uo pipefail

LIST="${1:-$(cd "$(dirname "$0")/.." && pwd)/extensions.txt}"
EXT_DIR="$HOME/.vscode-server/extensions"
COMMIT_DIR="$(ls -d "$HOME"/.vscode-server/bin/*/ 2>/dev/null | head -1)"
CODE="$COMMIT_DIR/bin/code-server"
LOG="$HOME/extension-install.log"
FAILED_FILE="$HOME/extension-install.failed"

[ -x "$CODE" ] || { echo "code-server not found under $HOME/.vscode-server/bin" >&2; exit 1; }
[ -f "$LIST" ] || { echo "extension list not found: $LIST" >&2; exit 1; }

mkdir -p "$EXT_DIR"
: > "$LOG"
: > "$FAILED_FILE"

mapfile -t EXTS < <(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$LIST" | sed '/^$/d')
TOTAL=${#EXTS[@]}
OK=0
SKIP=0
FAIL=0

echo "extensions: $TOTAL"
for i in "${!EXTS[@]}"; do
  ext="${EXTS[$i]}"
  n=$((i + 1))

  if compgen -G "$EXT_DIR/${ext}-*" >/dev/null; then
    echo "[$n/$TOTAL] $ext SKIP"
    SKIP=$((SKIP + 1))
    continue
  fi

  printf '[%d/%d] %s ... ' "$n" "$TOTAL" "$ext"
  success=0
  for attempt in 1 2 3; do
    if timeout 300 "$CODE" --extensions-dir "$EXT_DIR" \
         --install-extension "$ext" --force >>"$LOG" 2>&1; then
      success=1
      break
    fi
    sleep 3
  done

  if [ "$success" -eq 1 ]; then
    echo OK
    OK=$((OK + 1))
  else
    echo FAIL
    FAIL=$((FAIL + 1))
    echo "$ext" >>"$FAILED_FILE"
  fi
done

rm -f "$EXT_DIR/.obsolete" "$EXT_DIR/.init-default-profile-extensions"

echo "extensions done: ok=$OK skip=$SKIP fail=$FAIL total=$TOTAL"
if [ "$FAIL" -gt 0 ]; then
  echo "failed extensions:"
  cat "$FAILED_FILE"
  echo "log: $LOG"
  exit 2
fi
