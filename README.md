# GhostEXIF

GhostEXIF is a privacy-focused iOS metadata editor for inspecting, removing, editing, resizing, and exporting photo and video metadata entirely on-device.

## Features

- Import photos and videos from Photos, Files, or an external file URL.
- Inspect structured EXIF, TIFF, GPS, and IPTC metadata.
- Stage editable metadata and undo GPS purge or complete metadata-wipe operations.
- Apply Professional Identity or Ghost Mode identity changes.
- Resize image resolution while optionally preserving aspect ratio.
- Create JPEG output at or below a requested maximum file size.
- Batch-purge GPS or all supported metadata.
- Export through the system share sheet or save a new copy to Photos.
- Keep selected media and all transformations on-device.
- Display a consent-gated AdMob native ad in Standard Mode; Premium Mode hides ads.

## Requirements

- Xcode 16 or newer
- iOS 16.6 or newer
- A physical iPhone is recommended for ATT, UMP, Photos, and AdMob testing.

## Build

Open `GhostEXIF.xcodeproj`, select the `GhostEXIF` scheme, configure the signing team, and run on an iPhone.

Command-line Release verification:

```sh
xcodebuild \
  -project GhostEXIF.xcodeproj \
  -scheme GhostEXIF \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Privacy and advertising

GhostEXIF never sends selected photos or videos to an advertising or analytics service. Standard Mode uses Google Mobile Ads and User Messaging Platform. Ad requests wait for UMP consent status and ATT resolution. Review `documentation.md` before changing advertising, privacy-manifest, or App Store disclosure behavior.

The repository contains production AdMob identifiers. Register development phones as test devices in AdMob before loading or interacting with live inventory.

## Documentation

- [Developer documentation](documentation.md)
- [Changelog](changelog.md)
