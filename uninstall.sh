#!/usr/bin/env bash
# Remove pi-hd-config resources from ~/.pi/agent.
# Does NOT delete: auth.json, sessions/, trust.json, models-store.json, bin/.
set -euo pipefail
PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"

echo "Removing pi-hd-config resources from $PI_DIR ..."
rm -f "$PI_DIR/models.json" \
      "$PI_DIR/settings.json" \
      "$PI_DIR/AGENTS.md" \
      "$PI_DIR/agents/oracle.md" \
      "$PI_DIR/agents/search.md" \
      "$PI_DIR/extensions/painter.ts" \
      "$PI_DIR/extensions/view-media.ts"
rm -rf "$PI_DIR/extensions/subagent"

# Strip the env block from shell rc files
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -f "$rc" ] || continue
  if grep -qF "# >>> pi-hd-config >>>" "$rc"; then
    awk '/# >>> pi-hd-config >>>/{f=1;next} /# <<< pi-hd-config <<</{f=0;next} !f' "$rc" > "$rc.tmp" \
      && mv "$rc.tmp" "$rc"
    echo "  stripped env block from $rc"
  fi
done

echo "Done. (Kept: auth.json, sessions/, models-store.json, bin/, trust.json)"
