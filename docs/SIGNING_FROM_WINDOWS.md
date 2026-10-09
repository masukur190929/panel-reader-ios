# Signing and TestFlight from Windows

Do this after the first cloud build succeeds. You need paid Apple Developer
membership and permission to administer the app in App Store Connect. Account
setup can be done in a Windows browser; GitHub's Mac runner compiles and signs.
These steps prepare a new certificate and profile; they do not revoke existing
ones. Keep private keys and certificate files out of the public repository.

## 1. Register the app

In Apple Developer **Certificates, Identifiers & Profiles**, register an
explicit app identifier such as `com.yourname.panelreader`. Choose your own
unique identifier. This starter needs no additional capabilities.

In App Store Connect, create a new iOS app record using that identifier.
The provisional display name is **Panel Reader**; choose an available name.
Record your Apple Developer Team ID for later.

## 2. Create a distribution certificate

Use a Windows installation of OpenSSL. In Git Bash or another shell with
OpenSSL available, run these inside the repository:

```bash
mkdir -p .signing
openssl genrsa -out .signing/distribution.key 2048
openssl req -new -key .signing/distribution.key \
  -out .signing/CertificateSigningRequest.certSigningRequest \
  -subj '/CN=PanelReader Distribution'
```

On Apple's certificate page, create an **Apple Distribution** certificate
using that CSR. Download its `.cer` file into `.signing/distribution.cer`.
Convert it into a password-protected signing identity:

```bash
openssl x509 -inform DER -in .signing/distribution.cer \
  -out .signing/distribution.pem
openssl pkcs12 -export -inkey .signing/distribution.key \
  -in .signing/distribution.pem -out .signing/distribution.p12
```

The second command asks for an export password. Choose a non-empty password;
the workflow expects it in a GitHub secret. Store these files and the password
securely; `.gitignore` excludes them from this repository.

## 3. Create a provisioning profile

On Apple's profiles page, create an **App Store Connect** distribution profile
for the exact app identifier and the distribution certificate you just created.
Download it into `.signing/app.mobileprovision`. A development or Ad Hoc profile
will not work for this upload workflow.

## 4. Create an App Store Connect API key

In App Store Connect, open **Users and Access → Integrations → App Store Connect
API**. Create a team API key with the **App Manager** role, following Apple's
available account permissions. Download its `AuthKey_….p8` file and retain the
key ID and issuer ID. The TestFlight uploader uses this API key.

## 5. Configure GitHub

Open your repository's **Settings → Secrets and variables → Actions**.
Create these repository variables:

| Variable | Value |
| --- | --- |
| `BUNDLE_ID` | The exact registered app identifier |
| `APPLE_TEAM_ID` | Your Apple Developer Team ID |
| `APPSTORE_ISSUER_ID` | Your App Store Connect issuer ID |
| `APPSTORE_API_KEY_ID` | The API key ID |

Create these repository secrets:

| Secret | Value |
| --- | --- |
| `APPSTORE_CERTIFICATES_FILE_BASE64` | Base64 encoding of `distribution.p12` |
| `APPSTORE_CERTIFICATES_PASSWORD` | Its export password |
| `APPSTORE_PROFILE_BASE64` | Base64 encoding of `app.mobileprovision` |
| `APPSTORE_API_PRIVATE_KEY` | Complete text of the `.p8` file |

For example, PowerShell can place a base64 value on your clipboard without
printing it into a terminal log:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path '.signing/distribution.p12'))) | Set-Clipboard
```

Paste that into the certificate secret. Repeat using the profile's path for
the profile secret. The `.p8` secret takes the original file's text, including
its BEGIN/END lines, rather than a base64 encoding.

## 6. Upload and test

After **Build and test iOS** passes on `main`, open **Actions → Upload to
TestFlight → Run workflow**. Select `main`. It creates a signed archive,
exports an IPA and uploads it to Apple. It does not make an App Store release.

Wait for processing in App Store Connect. Fill in any required testing or
export-compliance information. Add yourself as an internal tester when your
account role permits it, or configure external testing and submit for beta
review. Install Apple's TestFlight app on your iPhone to test the build.

## 7. Submit to the App Store

Finish device testing, online source permissions, branding, screenshots, the
support/privacy pages, age rating and app privacy answers. Choose the processed
build in App Store Connect and submit it for review. Keep improving the app
until Apple's feedback is resolved. TestFlight builds expire after 90 days.

The signed workflow has been prepared but has not yet been executed. Its first
run may require adjustments for your certificate, account or runner image.
