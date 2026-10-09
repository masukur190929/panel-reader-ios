# Start here — Windows to iPhone

Panel Reader is a starter project for an independent iPhone/iPad manga reader.
The name and icon are provisional. This package has not yet been compiled with
Xcode, tested on an iPhone, or submitted to Apple.

## Your first milestone costs nothing

Your public repository is
[masukur190929/panel-reader-ios](https://github.com/masukur190929/panel-reader-ios).
The source and cloud workflows are included there. The first compile and four
library tests passed; the new UI test is awaiting its first run. Follow these
steps to check it and continue development:

1. Open the repository's **Actions** page and choose **Build and test iOS** to
   see the cloud Mac's compilation, library tests and UI test results. Download
   the **reader-ui-previews** artifact for simulator screenshots and a test summary.
2. To edit on Windows, install GitHub Desktop and clone your repository.
3. Edit the Swift files, commit the changes and push to GitHub. A new cloud
   build runs automatically. The cloud workflow discovers new Swift files and
   regenerates the Xcode project automatically; on a Mac, run
   `python3 scripts/generate_project.py` after adding files.
4. Resolve any failed build or simulator checks before purchasing Apple
   membership. A successful cloud build still needs real iPhone testing.

The first workflow does not produce an app you can install on your iPhone.
It proves that the code builds and its automated library checks pass.

## After the cloud build passes

Enroll in the Apple Developer Program, register an app identifier, and create
the app record in App Store Connect. Follow `docs/SIGNING_FROM_WINDOWS.md`
to configure the supplied manual TestFlight upload workflow. You can do the
account and certificate setup from Windows; the cloud Mac performs the build.

Test the app on your iPhone through TestFlight. Then add a permitted online
catalogue, finish the app's branding and store information, and submit for
App Review. Apple decides whether the app is accepted.

## What is included

- PDF and image imports, an original six-page sample, search and favourites.
- Vertical and horizontal reading, saved progress, bookmarks and history.
- An Xcode project and cloud build/test and TestFlight upload workflows.
- Tests for file imports, persistence and preservation of a damaged library,
  plus a UI check of the sample's reading, bookmarking and history flow.

Online sources, CBZ/CBR archives, chapter downloads, tracking-service accounts,
cloud sync and push notifications are follow-up work. This is the foundation,
not a full Kotatsu replacement.
