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
# set those up yourself (see Pi's providers.md). Inputs requested (per-tool
# URL + key for painter and view_media) are what those extensions need.
# Painter and view_media are independent — they can point at different proxies.
#
# Usage:
#   ./install.sh                                 # prompt for URL + key per tool
#   PI_PAINTER_KEY=... ./install.sh              # non-interactive (defaults)
#   PI_CODING_AGENT_DIR=/tmp/x ./install.sh      # alt target dir
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
DEFAULT_BASE_URL="https://proxy.tuongnguyen.work/v1"
DEFAULT_TOOLS_PKG="git:github.com/jwu/pi-default-tools"

c_red()   { printf "\033[31m%s\033[0m" "$*"; }
c_green() { printf "\033[32m%s\033[0m" "$*"; }
c_cyan()  { printf "\033[36m%s\033[0m" "$*"; }
c_yellow(){ printf "\033[33m%s\033[0m" "$*"; }
err()  { printf "%s %s\n" "$(c_red '✗')" "$*" >&2; }
ok()   { printf "%s %s\n" "$(c_green '✓')" "$*"; }
info() { printf "%s %s\n" "$(c_cyan '→')" "$*"; }

is_tty() { [ -t 0 ] && [ -t 1 ]; }

# Read $env_var; else reuse from shell rc; else prompt (TTY) with default;
# else fall back to default (non-interactive).
pick_url() {  # $1=label  $2=env_var  $3=default
  local label="$1" env_var="$2" default="${3:-}"
  local val="${!env_var:-}"
  if [ -n "$val" ]; then echo "${val%/}"; return; fi
  if is_tty; then
    read -rp "  ${label} [${default}]: " val
    val="${val:-$default}"
  else
    val="$default"
  fi
  echo "${val%/}"
}

# Read $env_var; else reuse from shell rc; else prompt (TTY); else $3 default.
# Empty + no default → abort (required).
pick_key() {  # $1=label  $2=env_var  $3=default_or_empty
  local label="$1" env_var="$2" default="${3:-}"
  local val="${!env_var:-}"
  if [ -n "$val" ]; then echo "$val"; return; fi
  local existing
  existing="$(grep -hE "^export ${env_var}=" "$HOME/.zshrc" "$HOME/.bashrc" 2>/dev/null \
    | head -1 | sed -E "s/^export ${env_var}=\"?([^\"]*)\"?/\1/" || true)"
  if [ -n "$existing" ]; then
    info "Reusing existing $env_var from shell rc."
    echo "$existing"; return
  fi
  if is_tty; then
    if [ -n "$default" ]; then
      read -rsp "  ${label} $(c_yellow '[Enter = same as painter]'): " val
      echo
      val="${val:-$default}"
    else
      read -rsp "  ${label}: " val
      echo
    fi
  else
    val="$default"
  fi
  # Required-key check (also covers non-interactive with no env + no default)
  if [ -z "$val" ]; then
    err "$env_var is required. Set it via: $env_var=... ./install.sh"
    exit 1
  fi
  echo "$val"
}

# --- 1. Ensure pi is installed -------------------------------------------------
if ! command -v pi >/dev/null 2>&1; then
  info "pi not found — installing @earendil-works/pi-coding-agent globally..."
  if ! command -v npm >/dev/null 2>&1; then
    err "npm is required. Install Node.js first (https://nodejs.org)."; exit 1
  fi
  npm install -g @earendil-works/pi-coding-agent
fi
ok "pi: $(command -v pi)"

# --- 2. Painter config (URL first, then key) ----------------------------------
printf "\n%s\n" "$(c_cyan 'Painter config:')"
PI_PAINTER_BASE_VAL="$(pick_url "Base URL" PI_PAINTER_BASE "$DEFAULT_BASE_URL")"
PI_PAINTER_KEY_VAL="$(pick_key  "API key"  PI_PAINTER_KEY "")"

# --- 3. View-media config (independent — may differ from painter) -------------
printf "\n%s\n" "$(c_cyan 'View-media config (Enter = same as painter):')"
PI_VISION_BASE_VAL="$(pick_url "Base URL" PI_VISION_BASE "$PI_PAINTER_BASE_VAL")"
PI_VISION_KEY_VAL="$(pick_key  "API key"  PI_VISION_KEY "$PI_PAINTER_KEY_VAL")"

# --- 4. Prepare dirs + copy tooling -------------------------------------------
mkdir -p "$PI_DIR"/{agents,extensions/subagent}
info "Copying tooling → $PI_DIR"
cp "$REPO_DIR/AGENTS.md"                "$PI_DIR/AGENTS.md"
cp "$REPO_DIR/agents/"*.md              "$PI_DIR/agents/"
cp "$REPO_DIR/extensions/painter.ts"    "$PI_DIR/extensions/"
cp "$REPO_DIR/extensions/view-media.ts" "$PI_DIR/extensions/"
cp "$REPO_DIR/extensions/subagent/"*    "$PI_DIR/extensions/subagent/"

# --- 5. Install pi-default-tools package (idempotent) -------------------------
if pi list 2>/dev/null | grep -q "pi-default-tools"; then
  ok "pi-default-tools already installed"
else
  info "Installing $DEFAULT_TOOLS_PKG ..."
  pi install "$DEFAULT_TOOLS_PKG" || err "  (skipped: pi install failed)"
fi

# --- 6. Persist per-tool env vars to shell rc ---------------------------------
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
export PI_PAINTER_BASE="$PI_PAINTER_BASE_VAL"
export PI_PAINTER_KEY="$PI_PAINTER_KEY_VAL"
export PI_VISION_BASE="$PI_VISION_BASE_VAL"
export PI_VISION_KEY="$PI_VISION_KEY_VAL"
$m1
EOF
  }
  write_env_block "$HOME/.zshrc"
  write_env_block "$HOME/.bashrc"
  ok "Persisted per-tool env vars to ~/.zshrc and ~/.bashrc"
fi

# --- 7. Summary ---------------------------------------------------------------
echo
ok "Tooling installed:"
echo "    extensions: painter, view_media, subagent"
echo "    agents:     oracle (gpt-5.6-sol), search (gemini-3-flash-agent)"
echo "    package:    pi-default-tools"
echo
echo "  $(c_cyan 'Painter')   → $PI_PAINTER_BASE_VAL"
echo "  $(c_cyan 'View-media') → $PI_VISION_BASE_VAL"
echo
echo "  $(c_cyan 'Provider/model setup is yours:') put a models.json with your"
echo "  providers in $(c_cyan "$PI_DIR/models.json") (see repo for a sample)."
if [ "$PI_DIR" = "$HOME/.pi/agent" ]; then
  echo "  Then: $(c_cyan 'source ~/.zshrc') (or new shell) and run $(c_cyan 'pi')"
fi
