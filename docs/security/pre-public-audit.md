# Pre-public audit — 2026-10-21

Purpose: decide whether this repository can be made public without exposing
credentials or personal data. Scope: the full git history (64 commits), all
local refs, and the working tree. The remote never had anything but `main`.

## Automated scan

- `gitleaks 8.30.1`
- `gitleaks git --log-opts=--all --redact --no-banner` → **no leaks found**
  (53 commits reachable, ~438 KB)
- `gitleaks dir --redact --no-banner .` → **no leaks found** (~540 KB)

## Manual checks

- suspicious file names in history (`.env`, `.gh`, `.ssh`, `id_*`, `*.pem`,
  `*.key`, credentials/tokens): **none**
- token/key patterns in every patch (`ghp_`, `github_pat_`, `AKIA`, private-key
  blocks, `xox*`, `AIza*`, `sk-`): **none**
- blobs larger than 200 KB: **none**
- only intended binary/document artifacts: none

## Residual notes

- Historical `STATE.md`/`LESSONS.md` entries mention the workspace auth path
  (`/workspace/.github-env`) and the public account handle. This is an
  operational path, not a credential; the current docs are generalized. It stays
  in history and is not sensitive.
- The audit is point-in-time. Public repositories require secret scanning and
  push protection to stay clean; both are enabled after the switch.
- The GitHub noreply address is used for commits; no personal address is tracked.

## Decision

Make the repository public, then apply branch protection (`protect.sh`) and
enable secret scanning + push protection. Keep `main-guard` as a second check.
Projects using the kit remain private: a public tool does not expose their data.
