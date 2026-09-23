# mac-bootstrap

First step to set up a DeepReach designer Mac. On a brand-new Mac, open Terminal and run:

```bash
curl -fsSL https://raw.githubusercontent.com/Deepreach/mac-bootstrap/main/bootstrap.sh -o /tmp/dr-bootstrap.sh && bash /tmp/dr-bootstrap.sh
```

It installs the Apple command line tools, Homebrew and the GitHub CLI, logs you in to GitHub, clones the
(private) DeepReach marketplace, and hands over to the real setup script there.

## Why this repo is public

The rest of the setup lives in private repositories, which a blank Mac cannot read before it has a GitHub
login. This file is the one piece that has to be reachable without authentication. It contains **no
credentials and nothing confidential** — only public installer URLs and repository names.

## Do not edit here

The source of truth is `plugins/lovi-designer/scripts/bootstrap.sh` in the private
`Deepreach/agents-marketplace` repository. Change it there, then copy it here in a PR, so both stay
identical.
