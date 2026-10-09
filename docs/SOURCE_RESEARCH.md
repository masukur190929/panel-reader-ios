# Source research and implementation scope

Checked 9 October 2026. The user selected ManhuaTop and ManhuaUs by sharing a
Kotatsu source-screen screenshot. Similar names exist on other domains; the
shortcuts use these addresses:

| Source | Address | Observed result |
| --- | --- | --- |
| ManhuaTop | https://manhuatop.org/ | Homepage retrieved with website navigation, search and title links |
| ManhuaUs | https://manhuaus.com/ | Homepage retrieved with search, title/chapter links and site bookmark controls |

The sites may change addresses, structure, availability or sign-in requirements.
Users can edit the saved address rather than wait for an app update.

## What the app implements

Ordinary HTTPS website browsing using Apple's WebKit, editable website shortcuts,
one saved resume URL per source, explicit page bookmarks and system URL sharing.
Website cookies and local website storage use a nonpersistent data store, cleared
on browser closure. No manga pages, covers or source logos are bundled. No
Kotatsu parser code was copied. No scraping, script injection, advertisement
removal, anti-bot bypass or automatic chapter downloading was implemented.

The Sources search filters saved names/links and bookmarked page titles. Manga
search, chapter selection and online reading happen through each website's own
interface. They are not native catalogue features of Panel Reader.

## What has not been verified

A documented application API, an app-integration licence and rights-holder
permission could not be verified for either site. ManhuaUs's homepage states
that its information and images are collected from the Internet and that it does
not own them. This is not a grant of manga rights to this project.

The ManhuaTop privacy policy describes browsing information and third-party
advertisers. The ManhuaUs privacy-policy address returned a retrieval error;
do not assume that a similarly named service's policy covers this domain.

Apple's guidelines 5.2.1–5.2.3 require relevant third-party/content permissions,
including permission for third-party services and media downloads. A browser
implementation does not guarantee App Store approval. Confirm the terms with
the service and relevant rights holders before submission, or remove unapproved
bundled source shortcuts from the submitted app. The current links are development
choices based on the user's screenshot, not endorsements or licensed providers.

## Validation

The automated browser UI test uses original local HTML with a visible **OFFLINE
TEST PAGE · ORIGINAL SAMPLE** label. It verifies WebKit rendering, link navigation,
bookmark creation/removal and reopening the bookmarked chapter without contacting
these sites. Its screenshot is a test fixture, not a captured manga website.
Real-device checks of live website loading, search, sign-in and chapter reading
remain necessary before release. The third-party services can restrict access
or stop working independently of this project.

## Primary references

- [ManhuaTop homepage](https://manhuatop.org/)
- [ManhuaTop privacy policy](https://manhuatop.org/privacy-policy/)
- [ManhuaUs homepage](https://manhuaus.com/)
- [Kotatsu Android domain list](https://github.com/KotatsuApp/Kotatsu/blob/devel/app/src/main/AndroidManifest.xml)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple app privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [WebKit website data stores](https://developer.apple.com/documentation/webkit/wkwebsitedatastore)
