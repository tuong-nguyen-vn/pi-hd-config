#!/usr/bin/env bash
# Remove pi-hd-config tooling from ~/.pi/agent.
# Does NOT remove: models.json, settings.json, auth.json, sessions/, bin/,
# trust.json, models-store.json — those are user-owned.
set -euo pipefail
PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"

echo "Removing pi-hd-config tooling from $PI_DIR ..."
rm -f "$PI_DIR/AGENTS.md" \
      "$PI_DIR/agents/oracle.md" \
      "$PI_DIR/agents/search.md" \
      "$PI_DIR/extensions/painter.ts" \
      "$PI_DIR/extensions/view-media.ts" \
      "$PI_DIR/themes/amp.json"
rm -rf "$PI_DIR/extensions/subagent"

# Strip the env block from shell rc files (legacy — current installer uses extensions.json)
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -f "$rc" ] || continue
  if grep -qF "# >>> pi-hd-config >>>" "$rc"; then
    awk '/# >>> pi-hd-config >>>/{f=1;next} /# <<< pi-hd-config <<</{f=0;next} !f' "$rc" > "$rc.tmp" \
      && mv "$rc.tmp" "$rc"
    echo "  stripped legacy env block from $rc"
  fi
done

if [ -f "$PI_DIR/extensions.json" ]; then
  rm -f "$PI_DIR/extensions.json"
  echo "  removed $PI_DIR/extensions.json"
fi

echo "Done. (Kept: models.json, settings.json, auth.json, sessions/, bin/, etc.)"
echo "  To also remove the pi-default-tools package: pi remove git:github.com/jwu/pi-default-tools"
