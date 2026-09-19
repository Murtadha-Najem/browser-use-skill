#!/usr/bin/env bash
# browser-use skill installer for macOS and Linux.
# Installs the four browser tools, registers the Chrome DevTools MCP server for Claude Code,
# and copies the skill into ~/.claude/skills. Safe to run again.
#
#   ./install.sh               tools + MCP + skill
#   ./install.sh --skip-skill  tools + MCP only (use this if you installed the skill as a plugin)
#   ./install.sh --skip-mcp    do not register the Chrome DevTools MCP server
set -euo pipefail

SKIP_SKILL=0
SKIP_MCP=0
for arg in "$@"; do
  case "$arg" in
    --skip-skill) SKIP_SKILL=1 ;;
    --skip-mcp)   SKIP_MCP=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

step() { printf '\n== %s\n' "$1"; }
ok()   { printf '   ok: %s\n' "$1"; }
warn() { printf '   warning: %s\n' "$1"; }

step "Checking Node.js"
command -v node >/dev/null || { echo "Node.js 18 or newer is required: https://nodejs.org" >&2; exit 1; }
major=$(node -v | sed 's/^v//; s/\..*//')
[ "$major" -ge 18 ] || { echo "Node.js 18 or newer is required (found $(node -v))." >&2; exit 1; }
ok "node $(node -v)"

step "Installing the browser CLIs"
npm install -g agent-browser @playwright/cli@latest chrome-devtools-mcp@latest dev-browser@latest
ok "agent-browser, playwright-cli, chrome-devtools-mcp, dev-browser"

step "Downloading browsers (about 300 MB, can be slow)"
export PLAYWRIGHT_DOWNLOAD_CONNECTION_TIMEOUT=600000
for tool in dev-browser agent-browser; do
  done_ok=0
  for i in 1 2 3; do
    if "$tool" install; then done_ok=1; break; fi
    warn "$tool install failed (attempt $i of 3)"
  done
  if [ "$done_ok" = 1 ]; then ok "$tool browser ready"; else warn "$tool could not download its browser. Run '$tool install' again later."; fi
done

if [ "$SKIP_MCP" = 0 ]; then
  step "Registering the Chrome DevTools MCP server"
  if command -v claude >/dev/null; then
    if claude mcp list 2>/dev/null | grep -q chrome-devtools; then
      ok "already registered"
    else
      claude mcp add chrome-devtools --scope user -- chrome-devtools-mcp
      ok "registered at user scope as chrome-devtools"
    fi
  else
    warn "Claude Code CLI not found. Register it later with: claude mcp add chrome-devtools --scope user -- chrome-devtools-mcp"
  fi
fi

if [ "$SKIP_SKILL" = 0 ]; then
  step "Installing the skill"
  here="$(cd "$(dirname "$0")" && pwd)"
  mkdir -p "$HOME/.claude/skills/browser-use"
  cp "$here/plugins/browser-use/skills/browser-use/SKILL.md" "$HOME/.claude/skills/browser-use/SKILL.md"
  ok "copied to ~/.claude/skills/browser-use"
fi

step "Done"
echo "   Start a new Claude Code session so the skill and the MCP tools load."
