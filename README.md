# Panel Reader for iOS

An independent SwiftUI reader starter for iPhone and iPad. Created for
Masukur Rahman on 9 October 2026. Requires iOS/iPadOS 17 or later.

**Start with [START_HERE.md](START_HERE.md).** Windows users can edit the files
and use the included GitHub Actions workflow to build on a cloud Mac.

[Public repository](https://github.com/masukur190929/panel-reader-ios) ·
[Cloud build results](https://github.com/masukur190929/panel-reader-ios/actions)

## Current status

The source is public. The [first cloud build](https://github.com/masukur190929/panel-reader-ios/actions/runs/37899679994)
passed on 9 October 2026 using Xcode 26.6 and an iPhone simulator. All four
library tests passed. The project now includes a UI test for opening the sample,
reading, bookmarking and history; its first run is pending. Screenshots and a
test summary are exported as the `reader-ui-previews` Actions artifact.

Real-device testing and signed distribution have not run. The app is not on
TestFlight or the App Store. Apple accounts and signing certificates are not
configured.

## Features implemented in the source

| Feature | Scope |
| --- | --- |
| Library | Original sample, PDF import and image-batch import |
| Organisation | Search, favourites, delete confirmation |
| Reading | Vertical/horizontal modes; PDFKit zoom; image centre zoom |
| State | Saved page, bookmarks and history on the device |
| iPad | Adaptive library grid and iPad orientations |
| Online integration | Original provider protocol; no live source implemented |

Images are sorted by natural filename order. Multiple PDFs create separate
books; several images create one book. Mixed PDF/image selections are rejected.
Imported files are copied into app storage, so the original may be removed
without losing the imported copy. File imports currently run on the main actor;
large batches need background processing and thumbnail caching before release.
Metadata is saved atomically. A damaged index is preserved and made read-only
instead of being silently overwritten.

## Build on a Mac

Open `PanelReader.xcodeproj`, select the PanelReader scheme and run on an iPhone
simulator. No external Swift package or project-generator tool is required.
If you add source files, regenerate the project with:

```bash
python3 scripts/generate_project.py
```

For command-line tests:

```bash
PANEL_SIMULATOR_ID=$(python3 scripts/choose_simulator.py)
xcodebuild test -project PanelReader.xcodeproj -scheme PanelReader \
  -destination "platform=iOS Simulator,id=$PANEL_SIMULATOR_ID" \
  CODE_SIGNING_ALLOWED=NO
```

## Build from Windows

The `Build and test iOS` workflow uses a standard `macos-26` GitHub-hosted
runner. Such standard runners are free for public repositories. Test result
artifacts are retained for five days; artifact storage has separate allowances.
A private repository has different included-minute and billing limits.

The automatic workflow is unsigned and requires no Apple membership. It runs
only simulator tests. The **manual** `Upload to TestFlight` workflow needs an
Apple Developer account, distribution certificate, matching profile, API key
and app record. See [the Windows signing guide](docs/SIGNING_FROM_WINDOWS.md).
Uploading to TestFlight does not automatically publish an App Store listing.

## Code ownership and content

This starter is an independent implementation. No Kotatsu source code, parsers,
logos or manga were copied into it. The original code and geometric sample are
provided under the included MIT licence. Referenced GitHub Actions have their
own licences. The provisional app name has not been checked for availability.

Kotatsu's GPL-3.0 licence does not automatically apply to this independently
written project. If you later incorporate Kotatsu code or another GPL component,
reassess the resulting licence obligations and App Store distribution before
shipping. Changing the language of copied code does not remove its licence.

`PanelReader/Sources/MangaSource.swift` defines the catalogue integration
contract. A future provider should supply documented permission to use its
service/content. Implement search, chapters and page retrieval; then add
download/caching services and a browsing interface. The App Store version
should include only integrations permitted by the service and rights holders.

## Next release work

1. Confirm the UI test and review simulator screenshots, then test on a real iPhone.
2. Finish reader usability: zoom/pan, right-to-left reading and progress under
   fast scrolling, orientation changes and large-file imports.
3. Select an authorised online provider and implement real browsing/chapters.
4. Add CBZ support and background downloads if needed; assess each dependency.
5. Confirm the name, bundle identifier, icon and content age rating.
6. Prepare screenshots, support contact, privacy policy, app privacy answers and
   source permissions. The current code has no analytics or network requests.
7. Submit through App Store Connect; resolve Apple's review feedback.

## Primary references (checked 9 October 2026)

- [GitHub-hosted runner availability](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
- [Apple membership options](https://developer.apple.com/support/compare-memberships/)
- [Apple TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- [App Review Guidelines, including 5.2](https://developer.apple.com/app-store/review/guidelines/)
- [Certificate handling on GitHub Mac runners](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)
- [Apple-Actions certificate importer](https://github.com/Apple-Actions/import-codesign-certs)
- [Apple-Actions TestFlight uploader](https://github.com/Apple-Actions/upload-testflight-build)
