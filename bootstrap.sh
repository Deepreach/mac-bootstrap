#!/usr/bin/env bash
#
# DeepReach — bootstrap loader for a brand-new Mac.
#
# This is the ONLY file that has to reach the machine before anything else
# exists on it. It contains no credentials and nothing confidential: it
# installs the Apple developer tools, Homebrew and the GitHub CLI, logs the
# user in to GitHub, clones the private marketplace, and hands over to
# scripts/setup-mac.sh, which does the real work.
#
# Published at https://github.com/Deepreach/mac-bootstrap (public, org-owned)
# so a fresh Mac can curl it. This file is the source: change it here, then
# copy it there in a PR. Keep it dumb — the logic lives in the private repo,
# this file only has to keep working.
#
# Usage (two-step form, recommended — keeps the terminal interactive):
#   curl -fsSL <url> -o /tmp/dr-bootstrap.sh && bash /tmp/dr-bootstrap.sh
#
# Piped form also works:
#   curl -fsSL <url> | bash
#
# Overrides: MARKETPLACE_REPO, DEEPREACH_HOME, LOVI_BRANCH

set -euo pipefail

MARKETPLACE_REPO="${MARKETPLACE_REPO:-Deepreach/agents-marketplace}"
DEEPREACH_HOME="${DEEPREACH_HOME:-$HOME/deepreach}"
MARKETPLACE_DIR="$DEEPREACH_HOME/agents-marketplace"
SETUP_SCRIPT="$MARKETPLACE_DIR/plugins/lovi-designer/scripts/setup-mac.sh"

# When run as `curl | bash`, stdin is the script itself: reattach the terminal
# so Homebrew and `gh auth login` can still ask their questions.
if [ ! -t 0 ] && [ -e /dev/tty ]; then exec < /dev/tty; fi

if [ -t 1 ]; then BOLD=$'\033[1m'; BLUE=$'\033[34m'; RED=$'\033[31m'; RESET=$'\033[0m'
else BOLD=""; BLUE=""; RED=""; RESET=""; fi
step() { printf '\n%s▶ %s%s\n' "$BOLD$BLUE" "$*" "$RESET"; }
die()  { printf '\n%s✗ %s%s\n' "$RED$BOLD" "$*" "$RESET" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "This bootstrap is for macOS only."
[ "$(id -u)" != "0" ] || die "Do not run this with sudo — run it as yourself."

step "Apple command line developer tools"
if xcode-select -p >/dev/null 2>&1; then
  echo "  already installed"
else
  echo "  A macOS window will open — click Install, then come back here."
  xcode-select --install >/dev/null 2>&1 || true
  until xcode-select -p >/dev/null 2>&1; do sleep 15; done
  echo "  installed"
fi

step "Homebrew"
if ! command -v brew >/dev/null 2>&1 && [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
if command -v brew >/dev/null 2>&1; then
  echo "  already installed"
else
  echo "  Installing (asks for your Mac password)..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

step "GitHub CLI"
command -v gh >/dev/null 2>&1 || brew install gh

step "GitHub login"
if gh auth status >/dev/null 2>&1; then
  echo "  already logged in as $(gh api user --jq .login 2>/dev/null || echo '?')"
else
  echo "  A browser window will open — log in with your DeepReach GitHub account."
  gh auth login --hostname github.com --git-protocol https --web
fi
gh auth setup-git >/dev/null 2>&1 || true

step "DeepReach marketplace"
mkdir -p "$DEEPREACH_HOME"
if git -C "$MARKETPLACE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$MARKETPLACE_DIR" pull --ff-only --quiet || true
  echo "  already cloned, updated"
else
  gh repo clone "$MARKETPLACE_REPO" "$MARKETPLACE_DIR" \
    || die "Cannot clone $MARKETPLACE_REPO. Ask an admin to add your GitHub account to the DeepReach organisation, then run this again."
fi

[ -f "$SETUP_SCRIPT" ] || die "Setup script not found at $SETUP_SCRIPT — the repository layout changed; ask the tech team."

step "Handing over to the full setup"
exec bash "$SETUP_SCRIPT" "$@"
