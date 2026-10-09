# App Store release plan

The source is public and the unsigned simulator build works. This independent
reader currently supports PDF and image imports. Normal App Store installation
requires a signed release reviewed by Apple.

## Your next account step

Membership is deferred while development continues. The current cloud simulator
workflow requires no Apple membership. Enroll when the app is ready for a signed
TestFlight build; a normal Apple Account is sufficient for now.

Check whether you already have an active Apple Developer Program membership.
Use an existing team if you have one. Otherwise, enroll through Apple's website
on Windows or the Apple Developer app on your iPhone. Apple lists 99 USD per
year, with regional prices shown at enrollment. Complete identity verification,
review the agreements and make payment yourself. Individual membership lists
your legal name as the App Store seller.

Keep credentials and signing files out of chat and the public repository.
The signing guide explains the repository Secrets used by the cloud workflow.

## Development and testing

1. Review **Actions → Build and test iOS** and the **reader-ui-previews** artifact.
2. Choose the final app name and a unique bundle identifier. Replace the
   distribution placeholder `com.example.panelreader`.
3. Follow [SIGNING_FROM_WINDOWS.md](SIGNING_FROM_WINDOWS.md) to register the app,
   create signing credentials and configure the manual TestFlight workflow.
4. Upload after the automatic checks pass. Install through TestFlight and test
   on your real iPhone and iPad.
5. Check imports from Files, long books, damaged files, rotation, zoom,
   bookmarks, history, deletion and accessibility. The simulator UI test
   covers the original sample flow, not every imported document.

## Product work before public release

- Background file imports, cached cover thumbnails, right-to-left horizontal
  pages, page buttons and bookmark jumping are implemented. Verify these on
  real devices and improve image zoom/pan before release.
- Decide whether the first release is an import reader or includes an online
  catalogue. Online browsing needs a permitted provider, chapter/page retrieval,
  download handling and UI. The existing provider protocol is a starting point.
- Implement archive support if CBZ is part of the promised release.
- Confirm branding, support contact, age rating and app privacy answers.
- Review [PRIVACY_POLICY_DRAFT.md](PRIVACY_POLICY_DRAFT.md), publish the final
  policy and add easily accessible privacy/support links inside the app.
- Adjust [APP_STORE_METADATA_DRAFT.md](APP_STORE_METADATA_DRAFT.md) to the
  actual signed build and capture its final screenshots.

## Submission

Complete the App Store Connect record, select the tested build and submit it
to App Review. Address feedback before release. A successful cloud build or
TestFlight upload does not make the app publicly available in the store.

## Primary references

- [Membership and regional fees](https://developer.apple.com/help/account/membership/program-enrollment)
- [Enrollment on iPhone](https://developer.apple.com/help/account/membership/enrolling-in-the-app)
- [App privacy information](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

Checked 9 October 2026.
