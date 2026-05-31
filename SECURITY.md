# Security Policy

## Supported Versions

claudeclaw-plus-container is released as a single rolling Docker image
(`ghcr.io/paulmeier/claudeclaw-plus-container:latest`). Only the most recent published
release is supported with security fixes. Tagged releases are cut from `main`
via release-please; pin to a specific tag if you need reproducibility, but be
aware that older tags will not receive backports.

| Version  | Supported          |
| -------- | ------------------ |
| `latest` | :white_check_mark: |
| Older    | :x:                |

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Report vulnerabilities privately via GitHub's
[Private Vulnerability Reporting](https://github.com/paulmeier/claudeclaw-plus-container/security/advisories/new):

1. Go to the repository's **Security** tab.
2. Click **Report a vulnerability**.
3. Fill out the advisory form with as much detail as you can — affected
   versions, reproduction steps, impact, and any suggested mitigation.

If you cannot use GitHub's advisory flow, email **longish.physic0h@icloud.com**
with the subject line `[claudeclaw-plus-container] Security report` and the same
information.

### What to expect

- **Acknowledgement:** within 5 business days.
- **Initial assessment:** within 14 days, including whether the report is
  accepted, declined, or needs more information.
- **Fix and disclosure:** for accepted reports, we aim to ship a patched
  release and publish a coordinated GitHub Security Advisory within 90 days
  of the original report. We will keep you updated throughout.

If a report is declined, we will explain why. If accepted, we will credit you
in the published advisory unless you request otherwise.
