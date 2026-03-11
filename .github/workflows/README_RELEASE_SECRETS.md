# Release Workflow Secrets

This helper file documents the required secrets for `.github/workflows/release-macos.yml`.

See full setup in `docs/APPLE_SECRETS_SETUP.md`.

Required secrets for signed/notarized release:

- APPLE_CERTIFICATE_BASE64
- APPLE_CERTIFICATE_PASSWORD
- APPLE_CODESIGN_IDENTITY
- KEYCHAIN_PASSWORD
- APPLE_ID
- APPLE_APP_SPECIFIC_PASSWORD
- APPLE_TEAM_ID
