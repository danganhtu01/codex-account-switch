#!/usr/bin/env bash
#
# uninstall.sh — remove the `codex-switch` command.
#
# Usage:
#   ./uninstall.sh               # remove the installed command (keeps saved accounts)
#   ./uninstall.sh --purge       # also delete saved account profiles (DESTRUCTIVE)
#   BINDIR=/usr/local/bin ./uninstall.sh
#
set -euo pipefail

CMD="codex-switch"
purge=0
BINDIR="${BINDIR:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --purge)   purge=1 ;;
    --bindir)  shift; [ $# -gt 0 ] || { echo "--bindir needs a directory" >&2; exit 1; }
               BINDIR="$1" ;;
    -h|--help)
      sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "uninstall.sh: unknown option '$1'" >&2; exit 1 ;;
  esac
  shift
done

# Candidate locations to clean (explicit BINDIR wins; otherwise check the usual spots).
if [ -n "$BINDIR" ]; then
  CANDIDATES="$BINDIR"
else
  CANDIDATES="${XDG_BIN_HOME:-$HOME/.local/bin} $HOME/bin /usr/local/bin"
fi

removed=0
for dir in $CANDIDATES; do
  target="$dir/$CMD"
  if [ -e "$target" ] || [ -L "$target" ]; then
    rm -f "$target"
    echo "Removed $target"
    removed=1
  fi
done
[ "$removed" -eq 0 ] && echo "No installed '$CMD' command found."

# Saved account profiles (credentials) are kept unless --purge is given.
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
STORE="${CODEX_SWITCH_HOME:-$CODEX_HOME/account-switch}"
if [ "$purge" -eq 1 ]; then
  if [ -d "$STORE" ]; then
    rm -rf "$STORE"
    echo "Purged saved accounts in $STORE"
  fi
else
  if [ -d "$STORE" ]; then
    echo
    echo "Saved accounts kept in: $STORE"
    echo "Delete them too with:   ./uninstall.sh --purge"
  fi
fi

echo "Done."
