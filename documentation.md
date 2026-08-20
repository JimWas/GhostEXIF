# GhostEXIF Developer Documentation

## Product overview

GhostEXIF is a SwiftUI iOS application for inspecting, editing, removing, resizing, and exporting photo metadata. It also supports metadata removal for compatible video formats. Media is copied into the app's temporary directory before processing; originals are not overwritten.

The deployment target is iOS 16.6. The app target is `GhostEXIF`, the bundle identifier is `JimWas.GhostEXIF`, and the shared scheme is `GhostEXIF`.

## Project structure

- `GhostEXIFApp.swift`: application entry point.
- `MainMenuView.swift`: branded home screen, onboarding, Photos picker, file importer, settings/privacy entry points, and App Tracking Transparency request.
- `MediaImport.swift`: safe, independent temporary copies of Photos-picker and security-scoped files, plus scoped temporary-media cleanup.
- `SettingsView.swift`: verified Premium purchase/restore controls, reset controls, version display, and JimWas links.
- `PurchaseManager.swift`: StoreKit 2 product loading, cryptographic transaction verification, entitlement refresh, transaction updates, purchasing, and user-initiated restore.
- `PremiumOfferView.swift`: one-time post-onboarding Premium offer with localized price, accurate benefits, purchase/restore actions, and privacy-policy access.
- `AdMobCoordinator.swift`: UMP consent refresh, privacy-options presentation, and one-time Mobile Ads initialization.
- `NativeAdFooter.swift`: native-ad loading and the compact UIKit-backed native creative used on the home screen.
- `EditorView.swift`: inspector, metadata staging, privacy actions, output controls, saving, and sharing.
- `OutputControlViews.swift`: Professional Identity, resolution-resize, and target-file-size forms.
- `MetadataManager.swift`: ImageIO/AVFoundation metadata parsing and media transformations.
- `BatchProcessorView.swift`: multi-item GPS or full-metadata processing.
- `PrivacySupportView.swift`: user-facing privacy and support disclosure.
- `PrivacyInfo.xcprivacy`: application privacy manifest.
- `GhostEXIFTests.swift`: metadata, resizing, file-size, import, and risk-scoring regression tests.

The Xcode project uses a file-system-synchronized source group. New Swift files placed inside `GhostEXIF/GhostEXIF` are included in the app target automatically unless explicitly excluded.

## Editor data flow

`EditorView` maintains a `workingMediaURL`. It starts as the imported temporary copy and changes whenever an operation produces a new file.

1. `MetadataManager.loadMetadata` parses the working file into `fields` and `rawMetadata`.
2. Field edits and identity modes modify the in-memory `fields` collection.
3. `EXEC_EXPORT` calls `applyChanges(to:)`, which writes staged fields into a new image.
4. GPS purge and full wipe create a reversible staged working file, refresh the inspector, and do not save automatically. `UNDO_STAGE` walks backward through staged privacy operations.
5. Resolution and target-size controls create another temporary file, make it the working file, refresh the inspector, and request that Photos save a separate copy.
6. The original imported file and the user's Photos-library original remain unchanged.

Always reload both parsed and raw metadata after replacing `workingMediaURL`. Otherwise the inspector can display metadata from the previous file.

## Identity modes

Identity operations are image-only staged changes. They do not modify pixel content and are written when the user exports.

### Professional

Professional mode lets the user enter:

- IPTC By-line, displayed as `Artist`.
- IPTC Copyright Notice, displayed as `Copyright`.

`applyProfessionalIdentity` adds these editable fields even when the source image did not contain them. Empty values remove the corresponding staged field.

### Ghost Mode

Ghost Mode removes the following staged identity fields:

- TIFF Make
- TIFF Model
- TIFF Software
- IPTC Artist/By-line
- IPTC Copyright Notice

`applyChanges(to:)` explicitly removes these keys from the source dictionaries before rebuilding them from the visible inspector fields. Removing a row from the UI alone is insufficient because ImageIO otherwise preserves the original tag.

Ghost Mode does not remove GPS or capture date. Use `PURGE_GPS` or `WIPE_ALL` for those privacy operations.

## Image output controls

### Resolution resizing

`resizeImage(from:width:height:)`:

- Accepts dimensions from 1 through 12,000 pixels.
- Bakes the source orientation into the pixels.
- Uses high-quality Core Graphics interpolation.
- Preserves the current metadata state, except the now-unnecessary orientation tag.
- Uses the source image container type and extension.

The UI locks the original aspect ratio by default. The user can unlock it to request an exact width and height, which may stretch the image.

### Target file size

`imageMatchingFileSize(from:targetBytes:)` creates the highest-quality JPEG that is at or below the requested maximum size.

The algorithm binary-searches JPEG quality between 0.35 and 0.95. If compression alone cannot meet the target, it progressively reduces pixel dimensions and tries again. Because image encoders produce discrete results, this feature treats the requested size as a maximum rather than promising an exact byte count.

Target-size output:

- Supports images only.
- Always produces JPEG.
- Composites transparency over white.
- Preserves the current metadata state where JPEG supports it.
- Accepts targets from 10 KB through 100 MB in the UI.

## Metadata removal

- `PURGE_GPS` removes the ImageIO GPS dictionary or video location metadata.
- `WIPE_ALL` rewrites image pixels without source metadata, or exports video with an empty metadata collection.
- Both privacy commands are staged rather than immediately saved. The user can inspect the result, export it, or press `UNDO_STAGE` to restore the previous file and inspector snapshot. Multiple operations create multiple undo steps.
- Structural properties such as dimensions, color model, and encoder-generated JPEG/EXIF fields can still appear after a full wipe. These describe the encoded image and are not retained personal metadata.
- Full image wipes bake orientation into the pixels before discarding the orientation tag.

## Saving and sharing

`saveToPhotos(url:)` uses the appropriate Photos creation API for an image or video and awaits the Photos completion callback. The UI reports success only after Photos confirms the save.

`EXEC_EXPORT` presents the system share sheet. For images it first writes staged editable metadata. For videos, field editing is intentionally disabled because the current implementation does not rewrite arbitrary video fields.

## Privacy and advertising

Photo and video processing is local. Media is not sent to an advertising service.

The app integrates Google Mobile Ads 13.6.0 and User Messaging Platform 3.1.0 through Swift Package Manager. Standard Mode displays a native test ad at the bottom of the home screen; Premium Mode suppresses it.

The launch sequence is intentionally ordered:

1. Complete onboarding, including the advertising disclosure.
2. Show the one-time Premium offer unless it has already been shown or a verified Premium entitlement exists.
3. Request the current UMP consent status and present any required consent form.
4. Resolve App Tracking Transparency on that first run when its status is still undetermined.
5. Initialize Google Mobile Ads only when UMP reports that ads may be requested.
6. Load one native ad without automatic failure retries.

Settings exposes `MANAGE_AD_PRIVACY` whenever UMP requires a persistent privacy-options entry point. The app privacy manifest declares tracking because personalized advertising may be used when authorized, and lists the Google ad-serving domains used for that tracking. Google SDK privacy manifests are embedded through the package dependency.

`Info.plist` currently uses the production GhostEXIF AdMob identifiers:

- App ID: `ca-app-pub-3057383894764696~7253254732`
- Native unit: `ca-app-pub-3057383894764696/1169539607`

Never test or click this live unit unless the physical device is explicitly configured as a test device in AdMob. For UI development, temporarily use Google's native demo unit `ca-app-pub-3940256099942544/3986624511`. Keep the SKAdNetwork list synchronized with Google's current published list.

Before release, update the public privacy policy and App Store Connect App Privacy answers to disclose Google and any configured mediation partners. Selected media is never passed into an ad request.

## Settings and local storage

The gear button on the home-screen header opens `SettingsView`.

- Premium is the non-consumable StoreKit product `JimWas.GhostEXIF.premium`. `PurchaseManager` accepts only verified transactions for that exact identifier, listens for transaction updates, refreshes `Transaction.currentEntitlements` at launch, and hides advertising only while that entitlement is active and not revoked.
- The purchase button uses StoreKit's localized `displayPrice`. `RESTORE_PURCHASES` is the explicit user action that calls `AppStore.sync()` before re-reading entitlements.
- Create the product in App Store Connect with the exact identifier `JimWas.GhostEXIF.premium`, complete its price/localization/review metadata, and submit it with the app version. A missing or mismatched product remains unavailable in the UI.
- `hasCompletedTutorial` is also stored with `@AppStorage`. Resetting it dismisses Settings and presents onboarding again.
- Reset All removes the app's UserDefaults domain and calls `MediaFileStore.clearTemporaryMediaFiles()`. It does not revoke or erase an App Store entitlement; StoreKit restores that verified state.
- Temporary cleanup deletes the `GhostEXIFImports` folder and legacy UUID-named image/video outputs in the app's own temporary directory. It never accesses or deletes Photos-library originals.
- App Tracking Transparency authorization belongs to iOS and cannot be reset programmatically. Users change it in the system Settings app.

External links in Settings point to `x.com/JimWashkau`, `github.com/jimwas`, and `JimWashkau.com`.

## Building and testing

From the repository root:

```sh
xcodebuild \
  -project GhostEXIF/GhostEXIF.xcodeproj \
  -scheme GhostEXIF \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing
```

Release archive:

```sh
xcodebuild \
  -project GhostEXIF/GhostEXIF.xcodeproj \
  -scheme GhostEXIF \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath Build/GhostEXIF.xcarchive \
  archive
```

Run tests against an available simulator by replacing the destination ID:

```sh
xcodebuild \
  -project GhostEXIF/GhostEXIF.xcodeproj \
  -scheme GhostEXIF \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  -parallel-testing-enabled NO \
  test
```

The local simulator service has previously stalled while initiating XCTest. `build-for-testing` still verifies that the app and test bundle compile and link. If launch stalls, restart CoreSimulator or use a fresh simulator before treating it as an application failure.

## Release checklist

- Increment `CURRENT_PROJECT_VERSION` for every uploaded build.
- Confirm version and build numbers in the archived `Info.plist`.
- Run metadata, resize, target-size, and orientation tests.
- Test image and video import from both Photos and Files.
- Test Photos save denial, approval, and limited-library configurations.
- Test the editor on a compact iPhone with the status bar and home indicator visible.
- Test the home screen at large Accessibility text sizes and confirm its command labels remain on one line.
- Test tutorial reset and full settings/cache reset, including relaunch behavior.
- Verify the 1024-pixel icon has no alpha channel.
- Review ATT, AdMob, privacy manifest, privacy policy, and App Store privacy answers together.
- Confirm the production AdMob identifiers and configure UMP messages in AdMob Privacy & messaging.
- Create and submit the non-consumable `JimWas.GhostEXIF.premium` in App Store Connect, then test purchase, cancel, pending approval, restore, refund/revocation, reinstall, and offline launch with sandbox accounts on physical devices.
- Exercise consent-required, consent-not-required, ATT-allowed, and ATT-denied paths on physical devices using test ads.
- Archive using an Apple Distribution identity and App Store provisioning profile.
- Test the uploaded build through TestFlight on a physical device.

## Known limitations

- Resolution and target-size controls currently support images only.
- Target-size output is JPEG and may be smaller than the requested maximum.
- Arbitrary video metadata editing is not implemented.
- Batch processing supports metadata removal, not identity staging or resizing.
- Very large images can require significant memory because ImageIO/Core Graphics decodes pixel buffers during rewriting.
