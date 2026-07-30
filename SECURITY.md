# Security Policy

## Supported versions

Security fixes are provided for the latest published release.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting feature or a private
security advisory for this repository. Do not disclose an unpatched
vulnerability in a public issue.

Include affected versions, reproduction steps, impact, and any suggested fix.
You can expect an acknowledgement within seven days.

## Security design

- The app has no third-party package dependencies.
- Network destinations are fixed at compile time and use HTTPS.
- Remote responses are decoded as data and never rendered as HTML.
- Cookies and persistent URL caching are disabled.
- Response sizes and incident text lengths are bounded.
- Release credentials and signing certificates are never stored in the repo.
