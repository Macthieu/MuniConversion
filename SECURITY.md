# Security Policy

## Supported Versions

MuniConversion is currently maintained on the latest `main` branch and the latest tagged release.

## Reporting a Vulnerability

Please do **not** open a public issue for security-sensitive reports.

Send a private report to the maintainer with:

- affected version/tag
- reproduction steps
- impact assessment
- proposed mitigation (if available)

Until a dedicated security contact is added, open a private GitHub security advisory in this repository when possible.

## Scope Notes

MuniConversion is a local desktop utility. Security-sensitive areas include:

- command execution through `Process`
- path handling and file writes
- handling of untrusted document inputs via LibreOffice

Users should run conversions on trusted files and keep LibreOffice updated.
