# Changelog

All notable changes to this project will be documented in this file.

## [1.0.2] - 2026-03-11

### Fixed

- GitHub Actions release workflow parsing issue:
  - removed direct `secrets.*` usage inside `if:` expressions
  - switched to `env`-based conditions
- Manual (`workflow_dispatch`) release runs on non-tag refs now succeed:
  - upload generated ZIP as workflow artifact
  - skip GitHub Release publication unless ref is a tag

## [1.0.1] - 2026-03-11

### Added

- Local macOS distribution scripts:
  - `scripts/release/build_dist.sh`
  - `scripts/release/sign_notarize.sh`
- GitHub Actions release workflow:
  - `.github/workflows/release-macos.yml`
- Distribution documentation:
  - `docs/MACOS_DISTRIBUTION.md`
  - `docs/APPLE_SECRETS_SETUP.md`

### Changed

- `README.md` and `docs/BUILD_AND_RELEASE.md` updated for signed/notarized `.app` delivery flow
- `.gitignore` updated to ignore local `dist/` artifacts

## [1.0.0] - 2026-03-11

### Added

- Stable baseline of MuniConvert as a macOS SwiftUI batch conversion utility
- Strong UX guardrails before real conversion (preconditions, clear blockers, enriched confirmation)
- Profile workflow improvements:
  - extended built-in profile set (including OpenDocument and inverse legacy conversions)
  - profile quick search
  - active profile summary
- Expanded unit test coverage:
  - scanner/path utilities
  - ViewModel blockers/profile logic
- GitHub repository health files:
  - SECURITY policy
  - issue templates
  - pull request template
- Build/release operational guide in `docs/BUILD_AND_RELEASE.md`

### Changed

- CI now validates both build and test (`swift build` + `swift test`)
- Overall project readiness improved for open-source maintenance and repeatable releases

## [0.3.0] - 2026-03-11

### Added

- New built-in profiles:
  - DOCX -> DOC
  - XLSX -> XLS
  - PPTX -> PPT
  - ODT -> PDF
  - ODS -> PDF
  - ODP -> PDF
- Profile quick search field in the Conversion section
- Live profile summary (source filter, target extension, LibreOffice format)

### Changed

- README updated with the extended profile set
- Profile selection UX improved for larger profile lists

## [0.2.0] - 2026-03-11

### Added

- Stronger UI hierarchy with section cards and clearer action placement
- Improved progress messaging during scan/conversion
- End-of-run summary with explicit run state (ready/running/completed/cancelled/failed)
- UX guardrails before real conversion:
  - explicit blockers when prerequisites are missing
  - sensitive settings recap
  - richer confirmation message
  - persistent simulation indicator

### Changed

- Results area now highlights key counters and run status more clearly
- Conversion flow messaging clarified for non-technical users

## [0.1.1] - 2026-03-11

### Added

- Unit tests for scanner and path/collision logic
- Test support utilities for temporary file tree setup
- CI step running `swift test` on GitHub Actions

### Changed

- README updated to mention `swift build` + `swift test` CI checks

## [0.1.0] - 2026-03-11

### Added

- Initial MVP of MuniConvert
- SwiftUI macOS UI with folder selection, conversion profile selection, logs and stats
- Recursive/non-recursive file scan with strict extension filtering
- Temporary/system file exclusion (`~$*`, `.DS_Store`, hidden files option)
- LibreOffice detection and test
- Conversion execution via `Process` (`soffice --headless`)
- Dry run mode
- Collision policies (skip, overwrite, auto-rename)
- Log export to `.txt`
- Persistent user settings
- GPLv3 licensing and GitHub-ready repository files
