#!/usr/bin/env bash
# pi-hd-config — tooling installer
#
# Installs the tooling layer for Pi (~/.pi/agent):
#   - extensions: painter (image gen/edit), view-media (vision), subagent
#   - agents:     oracle (deep reasoning), search (parallel code search)
#   - AGENTS.md:  subagent delegation wiring
#   - package:    pi-default-tools
#
# This installer does NOT touch providers/models.json or settings.json —
# set those up yourself (see Pi's providers.md). The only inputs requested
# (HD_PROXY_KEY, HD_PROXY_URL) are what the painter + view-media extensions
# need to call the proxy.
#
# Usage:
#   ./install.sh                                 # prompt for key + URL
#   HD_PROXY_KEY=... ./install.sh                # non-interactive
#   PI_CODING_AGENT_DIR=/tmp/x ./install.sh      # alt target dir
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
KEY_ENV="HD_PROXY_KEY"
DEFAULT_PROXY_URL="https://proxy.tuongnguyen.work"
DEFAULT_TOOLS_PKG="git:github.com/jwu/pi-default-tools"

c_red()   { printf "\033[31m%s\033[0m" "$*"; }
c_green() { printf "\033[32m%s\033[0m" "$*"; }
c_cyan()  { printf "\033[36m%s\033[0m" "$*"; }
err()  { printf "%s %s\n" "$(c_red '✗')" "$*" >&2; }
ok()   { printf "%s %s\n" "$(c_green '✓')" "$*"; }
info() { printf "%s %s\n" "$(c_cyan '→')" "$*"; }

is_tty() { [ -t 0 ] && [ -t 1 ]; }

# --- 1. Ensure pi is installed -------------------------------------------------
if ! command -v pi >/dev/null 2>&1; then
  info "pi not found — installing @earendil-works/pi-coding-agent globally..."
  if ! command -v npm >/dev/null 2>&1; then
    err "npm is required. Install Node.js first (https://nodejs.org)."; exit 1
  fi
  npm install -g @earendil-works/pi-coding-agent
fi
ok "pi: $(command -v pi)"

# --- 2. HD_PROXY_KEY (required by painter + view-media) -----------------------
get_key() {
  local key="${!KEY_ENV:-}"
  if [ -n "$key" ]; then echo "$key"; return; fi
  local existing
  existing="$(grep -hE "^export ${KEY_ENV}=" "$HOME/.zshrc" "$HOME/.bashrc" 2>/dev/null \
    | head -1 | sed -E "s/^export ${KEY_ENV}=\"?([^\"]*)\"?/\1/" || true)"
  if [ -n "$existing" ]; then
    info "Reusing existing $KEY_ENV from shell rc."
    echo "$existing"; return
  fi
  printf "\n%s\n" "$(c_cyan 'painter/view_media need the proxy API key')"
  read -rsp "Paste key: " key
  echo
  [ -n "$key" ] || { err "Empty key. Abort."; exit 1; }
  echo "$key"
}
KEY="$(get_key)"

# --- 3. HD_PROXY_URL (default = the maintainer's proxy) -----------------------
if [ -n "${HD_PROXY_URL:-}" ]; then
  PROXY_URL="${HD_PROXY_URL%/}"
elif is_tty; then
  read -rp "Proxy base URL [$DEFAULT_PROXY_URL]: " url
  PROXY_URL="${url:-$DEFAULT_PROXY_URL}"
  PROXY_URL="${PROXY_URL%/}"
else
  PROXY_URL="$DEFAULT_PROXY_URL"
fi

# --- 4. Prepare dirs + copy tooling -------------------------------------------
mkdir -p "$PI_DIR"/{agents,extensions/subagent}
info "Copying tooling → $PI_DIR"
cp "$REPO_DIR/AGENTS.md"                "$PI_DIR/AGENTS.md"
cp "$REPO_DIR/agents/"*.md              "$PI_DIR/agents/"
cp "$REPO_DIR/extensions/painter.ts"    "$PI_DIR/extensions/"
cp "$REPO_DIR/extensions/view-media.ts" "$PI_DIR/extensions/"
cp "$REPO_DIR/extensions/subagent/"*    "$PI_DIR/extensions/subagent/"

# If user chose a non-default proxy URL, substitute it in the extensions
# (models.json is intentionally not touched — user manages providers).
if [ "$PROXY_URL" != "$DEFAULT_PROXY_URL" ]; then
  info "Substituting proxy URL → $PROXY_URL (in extensions only)"
  python3 - "$PI_DIR/extensions/painter.ts" "$PI_DIR/extensions/view-media.ts" \
    "$DEFAULT_PROXY_URL" "$PROXY_URL" <<'PY'
import sys
default, chosen = sys.argv[-2], sys.argv[-1]
for path in sys.argv[1:-2]:
    s = open(path).read()
    open(path, "w").write(s.replace(default, chosen))
PY
fi

# --- 5. Install pi-default-tools package (idempotent) -------------------------
if pi list 2>/dev/null | grep -q "pi-default-tools"; then
  ok "pi-default-tools already installed"
else
  info "Installing $DEFAULT_TOOLS_PKG ..."
  pi install "$DEFAULT_TOOLS_PKG" || err "  (skipped: pi install failed)"
fi

# --- 6. Persist env vars to shell rc ------------------------------------------
# Only persist when installing into the real user dir.
if [ "$PI_DIR" = "$HOME/.pi/agent" ]; then
  write_env_block() {
    local rc="$1"; [ -f "$rc" ] || return 0
    local m0="# >>> pi-hd-config >>>"
    local m1="# <<< pi-hd-config <<<"
    if grep -qF "$m0" "$rc"; then
      awk -v s="$m0" -v e="$m1" '$0==s{f=1;next} $0==e{f=0;next} !f' "$rc" > "$rc.tmp" \
        && mv "$rc.tmp" "$rc"
    fi
    cat >> "$rc" <<EOF

$m0
export $KEY_ENV="$KEY"
export HD_PROXY_URL="$PROXY_URL"
$m1
EOF
  }
  write_env_block "$HOME/.zshrc"
  write_env_block "$HOME/.bashrc"
  ok "Persisted $KEY_ENV + HD_PROXY_URL to ~/.zshrc and ~/.bashrc"
fi

# --- 7. Summary ---------------------------------------------------------------
echo
ok "Tooling installed:"
echo "    extensions: painter, view_media, subagent"
echo "    agents:     oracle (gpt-5.6-sol), search (gemini-3-flash-agent)"
echo "    package:    pi-default-tools"
echo
echo "  $(c_cyan 'Provider/model setup is yours:') put a models.json with your"
echo "  providers in $(c_cyan "$PI_DIR/models.json") (see repo for a sample)."
if [ "$PI_DIR" = "$HOME/.pi/agent" ]; then
  echo "  Then: $(c_cyan 'source ~/.zshrc') (or new shell) and run $(c_cyan 'pi')"
fi
