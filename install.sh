#!/usr/bin/env bash
# Install the skills in this repo for Claude Code and/or Codex.
#
#   ./install.sh              # both agents, symlinked
#   ./install.sh --claude     # Claude Code only
#   ./install.sh --codex      # Codex only
#   ./install.sh --copy       # copy instead of symlink
#   ./install.sh --uninstall  # remove what this script installed
set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
SRC="$REPO/skills"

WANT_CLAUDE=0 WANT_CODEX=0 MODE=link ACTION=install
for a in "$@"; do
  case "$a" in
    --claude) WANT_CLAUDE=1 ;;
    --codex) WANT_CODEX=1 ;;
    --copy) MODE=copy ;;
    --uninstall) ACTION=uninstall ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done
if [ "$WANT_CLAUDE" -eq 0 ] && [ "$WANT_CODEX" -eq 0 ]; then
  WANT_CLAUDE=1 WANT_CODEX=1
fi

# Claude Code reads ~/.claude/skills; Codex reads ~/.agents/skills.
TARGETS=""
[ "$WANT_CLAUDE" -eq 1 ] && TARGETS="$TARGETS $HOME/.claude/skills"
[ "$WANT_CODEX" -eq 1 ] && TARGETS="$TARGETS $HOME/.agents/skills"

for skill in "$SRC"/*/; do
  [ -f "$skill/SKILL.md" ] || continue
  name=$(basename "$skill")
  for dir in $TARGETS; do
    dest="$dir/$name"
    if [ "$ACTION" = uninstall ]; then
      if [ -L "$dest" ] || [ -d "$dest" ]; then
        rm -rf "$dest"
        echo "removed $dest"
      fi
      continue
    fi
    mkdir -p "$dir"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      echo "replacing existing $dest"
      rm -rf "$dest"
    fi
    if [ "$MODE" = link ]; then
      ln -s "${skill%/}" "$dest"
      echo "linked  $dest -> ${skill%/}"
    else
      cp -R "${skill%/}" "$dest"
      echo "copied  $dest"
    fi
  done
done

[ "$ACTION" = uninstall ] && exit 0

cat <<'EOF'

Installed. Verify discovery:
  Claude Code   restart, then type /db-erd
  Codex         restart, then /skills

Project-scoped install instead of user-scoped:
  Claude Code   cp -R skills/db-erd <project>/.claude/skills/
  Codex         cp -R skills/db-erd <project>/.agents/skills/
EOF
