#!/usr/bin/env bash
#
# install.sh — install the `codex-switch` command.
#
# Usage:
#   ./install.sh                 # install to ~/.local/bin (default)
#   ./install.sh --prefix DIR    # install the binary into DIR/bin (or DIR if it ends in /bin)
#   BINDIR=/usr/local/bin ./install.sh
#   ./install.sh --symlink       # symlink instead of copy (good for `git pull` updates)
#
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SRC_DIR/bin/codex-switch"
CMD="codex-switch"

symlink=0
BINDIR="${BINDIR:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --symlink)   symlink=1 ;;
    --prefix)    shift; [ $# -gt 0 ] || { echo "--prefix needs a directory" >&2; exit 1; }
                 case "$1" in */bin) BINDIR="$1" ;; *) BINDIR="$1/bin" ;; esac ;;
    --bindir)    shift; [ $# -gt 0 ] || { echo "--bindir needs a directory" >&2; exit 1; }
                 BINDIR="$1" ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "install.sh: unknown option '$1'" >&2; exit 1 ;;
  esac
  shift
done

[ -f "$SRC" ] || { echo "install.sh: cannot find $SRC" >&2; exit 1; }

# Default install location: ~/.local/bin (no sudo needed).
if [ -z "$BINDIR" ]; then
  BINDIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
fi

mkdir -p "$BINDIR"
DEST="$BINDIR/$CMD"

if [ "$symlink" -eq 1 ]; then
  ln -sf "$SRC" "$DEST"
  echo "Linked  $DEST -> $SRC"
else
  cp "$SRC" "$DEST"
  echo "Installed $DEST"
fi
chmod +x "$SRC" "$DEST" 2>/dev/null || true

# PATH sanity check.
case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *)
    echo
    echo "NOTE: $BINDIR is not on your PATH. Add this to your shell profile:"
    echo "      export PATH=\"$BINDIR:\$PATH\""
    ;;
esac

echo
echo "Done. Next steps:"
echo "  1) codex login            # authenticate your first Codex account"
echo "  2) $CMD add <name>   # save it (e.g. '$CMD add work')"
echo "  3) $CMD --help       # full usage"
