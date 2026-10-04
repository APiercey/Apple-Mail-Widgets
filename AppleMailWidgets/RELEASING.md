# Release a Mac build

## One-time setup

1. Open Xcode and accept its agreement yourself.
2. Sign in under **Xcode → Settings → Apple Accounts**.
3. Confirm active Apple Developer Program membership.
4. Open **Manage Certificates** and create a **Developer ID Application** certificate.
5. Save notarization credentials in Keychain:

```sh
xcrun notarytool store-credentials AppleMailWidgets
```

- Enter your Apple Account, Team ID, and an app-specific password at the prompts.
- Create the app-specific password in your Apple Account settings.
- Keep passwords and private keys out of chat and Git.

## Prepare a candidate

From the `AppleMailWidgets` directory:

```sh
./release.py prepare 0.1.0 1
```

- Creates an optimized Apple Silicon build in `build/release`.
- Does not install the app or upload anything.
- This candidate is not ready for public distribution.

## Sign and notarize

Use the certificate name shown by `security find-identity -v -p codesigning`:

```sh
export SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
./release.py notarize 0.1.0 1
```

- Builds and signs the app and widget.
- Uploads the app to Apple for notarization.
- Staples the approval ticket and checks Gatekeeper.
- Creates a versioned ZIP and SHA-256 checksum in `dist`.
- Does not publish to GitHub or replace the installed app.

If Apple's check fails or times out, inspect the saved submission ID in `build/release/notary-submission.json`. No release ZIP is produced.

## Before publishing

- Test the signed app on a clean Mac, including Mail permission and background refresh.
- Verify app and widget cache sharing under the distribution signature.
- Complete the separate App Group and background-service production work.
- Attach the notarized ZIP and checksum to a GitHub prerelease.

[Apple's notarization guide](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
