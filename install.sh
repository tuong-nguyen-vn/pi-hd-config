#!/usr/bin/env bash
# pi-hd-config installer
# Bootstraps a Pi (~/.pi/agent) setup with HD proxy providers,
# extensions (painter, view-media, subagent), and agents (oracle, search).
#
# Usage:
#   ./install.sh                     # prompt for key
#   HD_PROXY_KEY=... ./install.sh    # non-interactive
#   PI_CODING_AGENT_DIR=/tmp/x ./install.sh   # alt target dir
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
KEY_ENV="HD_PROXY_KEY"

c_red()   { printf "\033[31m%s\033[0m" "$*"; }
c_green() { printf "\033[32m%s\033[0m" "$*"; }
c_cyan()  { printf "\033[36m%s\033[0m" "$*"; }
err()  { printf "%s %s\n" "$(c_red '✗')" "$*" >&2; }
ok()   { printf "%s %s\n" "$(c_green '✓')" "$*"; }
info() { printf "%s %s\n" "$(c_cyan '→')" "$*"; }

# --- 1. Ensure pi is installed -------------------------------------------------
if ! command -v pi >/dev/null 2>&1; then
  info "pi not found — installing @earendil-works/pi-coding-agent globally..."
  if ! command -v npm >/dev/null 2>&1; then
    err "npm is required. Install Node.js first (https://nodejs.org)."; exit 1
  fi
  npm install -g @earendil-works/pi-coding-agent
fi
ok "pi: $(command -v pi)"

# --- 2. Get API key -----------------------------------------------------------
get_key() {
  local key="${!KEY_ENV:-}"
  if [ -n "$key" ]; then
    echo "$key"; return
  fi
  # Reuse from existing shell rc if present
  local existing
  existing="$(grep -hE "^export ${KEY_ENV}=" "$HOME/.zshrc" "$HOME/.bashrc" 2>/dev/null | head -1 | sed -E "s/^export ${KEY_ENV}=\"?([^\"]*)\"?/\1/" || true)"
  if [ -n "$existing" ]; then
    info "Reusing existing $KEY_ENV from shell rc."
    echo "$existing"; return
  fi
  printf "\n%s\n" "$(c_cyan 'Need your HD proxy API key (from https://proxy.tuongnguyen.work)')"
  read -rsp "Paste key: " key
  echo
  [ -n "$key" ] || { err "Empty key. Abort."; exit 1; }
  echo "$key"
}
KEY="$(get_key)"

# --- 3. Prepare target dirs ---------------------------------------------------
mkdir -p "$PI_DIR"/{agents,extensions/subagent,prompts,sessions}

# --- 4. Copy resources --------------------------------------------------------
info "Copying config → $PI_DIR"
cp "$REPO_DIR/models.json"              "$PI_DIR/models.json"
cp "$REPO_DIR/settings.json"            "$PI_DIR/settings.json"
cp "$REPO_DIR/AGENTS.md"                "$PI_DIR/AGENTS.md"
cp "$REPO_DIR/agents/"*.md              "$PI_DIR/agents/"
cp "$REPO_DIR/extensions/painter.ts"    "$PI_DIR/extensions/"
cp "$REPO_DIR/extensions/view-media.ts" "$PI_DIR/extensions/"
cp "$REPO_DIR/extensions/subagent/"*    "$PI_DIR/extensions/subagent/"

# --- 5. Persist HD_PROXY_KEY to shell rc --------------------------------------
# Only persist when installing into the real user dir (skip for test dirs).
if [ "$PI_DIR" = "$HOME/.pi/agent" ]; then
  write_env_block() {
    local rc="$1"; [ -f "$rc" ] || return 0
    local m0="# >>> pi-hd-config >>>"
    local m1="# <<< pi-hd-config <<<"
    if grep -qF "$m0" "$rc"; then
      awk -v s="$m0" -v e="$m1" '$0==s{f=1;next} $0==e{f=0;next} !f' "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"
    fi
    cat >> "$rc" <<EOF

$m0
export $KEY_ENV="$KEY"
$m1
EOF
  }
  write_env_block "$HOME/.zshrc"
  write_env_block "$HOME/.bashrc"
  ok "Persisted $KEY_ENV to ~/.zshrc and ~/.bashrc"
fi
# Export for this process so verification works
export "$KEY_ENV=$KEY"

# --- 6. Fetch the pi-default-tools package ------------------------------------
info "Fetching pi-default-tools package..."
pi update pi-default-tools >/dev/null 2>&1 || pi update >/dev/null 2>&1 || true

# --- 7. Verify ----------------------------------------------------------------
info "Verifying: calling glm-5.2 via the new config..."
if pi -p --provider hd-claude --model glm-5.2 --no-tools --thinking off "reply with exactly: ok" 2>&1 | tail -3 | grep -q "ok"; then
  ok "Install successful."
  echo
  echo "  Next: $(c_cyan 'source ~/.zshrc')  (or open a new shell)"
  echo "  Then: $(c_cyan 'pi')"
  exit 0
else
  err "Verification call failed."
  err "Check: $KEY_ENV is set, proxy reachable, key valid."
  exit 1
fi
