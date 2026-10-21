# Security policy

## Reporting a vulnerability

Do not open a public issue for a vulnerability. Use GitHub's private
vulnerability reporting (**Security → Advisories → Report a vulnerability**) or
contact the maintainer, [@V4inwald](https://github.com/V4inwald).

Include the affected commit or version, a reproduction, and the impact. This is
a personal project: there is no bug bounty and no guaranteed response time, but
reports are read.

## Scope

The devloop scripts, git hooks, GitHub workflows, installer and templates in
this repository. The projects that install the kit are out of scope: report
issues in those repositories to their own maintainers.

## Secrets

Never commit tokens, keys, credentials or personal data. The gate, `policy.sh`,
branch protection and GitHub secret scanning are defence in depth, not a
guarantee. If a secret is committed, rotate it first, then rewrite history —
revoking the credential is the only reliable remediation.
