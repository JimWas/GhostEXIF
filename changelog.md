# Changelog

All notable GhostEXIF changes should be recorded here. Dates use `YYYY-MM-DD`.

## Unreleased

### Added

- Google Mobile Ads 13.6.0 and User Messaging Platform 3.1.0 through Swift Package Manager.
- Consent-gated native test ad at the bottom of the home screen, including AdChoices and ad attribution.
- UMP privacy-options entry point in Settings when required.
- Production GhostEXIF AdMob app and native-ad-unit identifiers.
- App settings screen with a persisted device-local Premium Mode preference.
- Controls to replay the tutorial and reset all GhostEXIF preferences and temporary media cache.
- Direct links to JimWas on X, GitHub, and the web.
- Clear Home button in the editor header, with confirmation before discarding staged privacy operations.
- Reversible staging history and `UNDO_STAGE` for GPS purge and full metadata wipe.
- Functional Professional Identity form for staging IPTC Artist and Copyright tags.
- Functional Ghost Mode for removing camera, software, artist, and copyright identity tags on export.
- In-app explanation of the difference between Professional, Ghost Mode, GPS purge, and full wipe.
- Image resolution resizing with optional aspect-ratio locking.
- Target file-size output that creates the highest-quality JPEG at or below a requested maximum.
- Output-processing progress state and user-facing completion/error messages.
- Regression tests for Professional Identity, Ghost Mode, resolution resizing, and target file size.
- Developer documentation covering architecture, workflows, privacy, testing, and release procedures.

### Changed

- Premium Mode now hides advertising; Standard Mode displays the native ad when consent allows.
- Ad initialization now waits for UMP consent status and ATT resolution.
- Added AdMob application metadata, Google's current SKAdNetwork identifiers, and tracking disclosure.
- Rebranded the home header from `EXIF_MATRIX_v1.0` to `GHOST EXIF by JimWas`.
- Home-screen system and import command labels now stay on one line and scale down on compact widths.
- The home footer now reports Standard or Premium mode.
- GPS purge and full wipe now update the inspector without saving automatically; export commits the chosen staged result.
- The editor uses explicit UIKit window safe-area insets and owns the full-screen layout, preventing its header and footer from entering status-bar or home-indicator regions.
- The editor's left pane scrolls so the added controls remain usable on compact iPhones.
- Identity dictionaries are synchronized from visible staged fields during export instead of silently retaining removed source tags.
- Processed output becomes the active working file and refreshes both parsed and raw metadata.

## 1.0.0 - 2026-07-16

### Added

- Photo and video import from Photos and Files.
- Metadata inspection, raw metadata display, risk assessment, and supported image-field editing.
- GPS-only purge, full metadata wipe, batch processing, Photos save, and share-sheet export.
- On-device privacy/support disclosure and privacy manifest.
- App Tracking Transparency purpose string and post-onboarding permission request in preparation for advertising support.
- Shared Xcode scheme, automated metadata tests, App Store icon, export options, and App Store submission notes.

### Fixed

- Release build failures caused by missing theme symbols and imports.
- Temporary Photos-picker and security-scoped file handling.
- Incorrect image/video Photos save APIs and premature success reporting.
- ImageIO retaining GPS and other source metadata after a purge.
- Full-wipe orientation loss.
- Inspector metadata not refreshing after GPS purge or full wipe.
- Subsequent export reverting to the original file after a privacy operation.
- Editor content overlapping the status bar and home indicator on compact iPhones.
- Nonfunctional edit cancellation and raw-metadata navigation.
