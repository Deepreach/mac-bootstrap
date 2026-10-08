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
# Overrides: MARKETPLACE_REPO, MARKETPLACE_BRANCH, DEEPREACH_HOME, LOVI_BRANCH
#   MARKETPLACE_BRANCH lets you test a branch of the marketplace before it is
#   merged, e.g. MARKETPLACE_BRANCH=my-branch bash /tmp/dr-bootstrap.sh

set -euo pipefail

MARKETPLACE_REPO="${MARKETPLACE_REPO:-Deepreach/agents-marketplace}"
MARKETPLACE_BRANCH="${MARKETPLACE_BRANCH:-}"
export MARKETPLACE_BRANCH
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

# Homebrew's installer (and Nix's, and Devbox's) runs sudo NON-interactively
# (`sudo -n`) when NONINTERACTIVE is set: it never prompts, it just fails with
# "Insufficient permissions" if no credential is cached. So ask for the
# password here, once, and keep it cached for the long installs that follow.
SUDO_KEEPALIVE_PID=""
ensure_sudo() {
  if sudo -n true 2>/dev/null; then return 0; fi
  if ! id -Gn | tr ' ' '\n' | grep -qx admin; then
    die "Your account ($USER) is not an administrator of this Mac, and this step needs admin rights.
  On a DeepReach Mac managed by Primo, ask the tech team to run the Fleet provisioning —
  it installs these tools without admin rights — then run: dr-setup"
  fi
  echo "  Your Mac password is needed (nothing is shown while you type)."
  sudo -v || die "sudo did not accept the password — run this again."
  if [ -z "$SUDO_KEEPALIVE_PID" ]; then
    # sudo's cache lasts 5 minutes; the installs below take longer. Refresh it
    # until this process (or the setup script it execs into) is gone.
    ( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
    SUDO_KEEPALIVE_PID=$!
  fi
}

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
  ensure_sudo
  echo "  Installing..."
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
  git -C "$MARKETPLACE_DIR" fetch --quiet origin || true
  if [ -n "$MARKETPLACE_BRANCH" ]; then
    git -C "$MARKETPLACE_DIR" checkout --quiet "$MARKETPLACE_BRANCH" || die "No branch '$MARKETPLACE_BRANCH' in $MARKETPLACE_REPO."
  fi
  git -C "$MARKETPLACE_DIR" pull --ff-only --quiet || true
  echo "  already cloned, updated ($(git -C "$MARKETPLACE_DIR" rev-parse --abbrev-ref HEAD))"
else
  if [ -n "$MARKETPLACE_BRANCH" ]; then
    gh repo clone "$MARKETPLACE_REPO" "$MARKETPLACE_DIR" -- --branch "$MARKETPLACE_BRANCH" \
      || die "Cannot clone branch '$MARKETPLACE_BRANCH' of $MARKETPLACE_REPO."
  else
    gh repo clone "$MARKETPLACE_REPO" "$MARKETPLACE_DIR" \
      || die "Cannot clone $MARKETPLACE_REPO. Ask an admin to add your GitHub account to the DeepReach organisation, then run this again."
  fi
fi

[ -f "$SETUP_SCRIPT" ] || die "Setup script not found at $SETUP_SCRIPT.
  The branch checked out ($(git -C "$MARKETPLACE_DIR" rev-parse --abbrev-ref HEAD)) does not carry the lovi-designer plugin yet.
  To test an unmerged branch: MARKETPLACE_BRANCH=<branch> bash $0"

step "Handing over to the full setup"
exec bash "$SETUP_SCRIPT" "$@"
