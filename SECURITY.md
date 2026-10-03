# Security Policy

## Supported Versions

Only the latest release of countersign-skills is supported with security fixes. Please update
before reporting an issue you have not reproduced on the latest release.

## Reporting a Vulnerability

Report vulnerabilities privately through GitHub's private vulnerability reporting:
[report a vulnerability](https://github.com/Gord1y/countersign-skills/security/advisories/new).
Do not open a public issue for a security report.

In scope:

- The installer scripts: `install.sh`, `update.sh`, `uninstall.sh` and `lib.sh`.
- `bin/` and the scripts shipped inside skills.
- The defaults in `claude/settings.json`: the sandbox, the permissions and the auto-mode trust.

Please include:

- The version or commit, and the OS
- The agent involved (Claude Code, Codex or Antigravity) and its version
- Steps to reproduce, and what you expected instead
- The impact you believe the issue has

## What happens next

You will get an acknowledgement of the report. Confirmed vulnerabilities are fixed in a patch
release; you are welcome to be credited in the release notes if you would like, and welcome to
stay anonymous otherwise.
