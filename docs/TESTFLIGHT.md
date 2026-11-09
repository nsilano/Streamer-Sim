# TestFlight setup

Everything here is prepared but **has not been run**: it needs your Apple Developer account.

## One-time setup
1. **Apple Developer Program** membership (paid). Note your **Team ID** (developer.apple.com > Membership).
2. **Pick a bundle ID** you own. The default is `com.nsilano.streamempire` (`project.yml` > `PRODUCT_BUNDLE_IDENTIFIER`
   and `bundleIdPrefix`). Change both to something unique to you, then register it under
   Certificates, Identifiers & Profiles > Identifiers.
3. **Create the app record** in App Store Connect > Apps > + > New App, using that bundle ID.
   The name "Stream Empire" is a working title and may already be taken: change `CFBundleDisplayName`
   in `project.yml` if you rename it.
4. **Create an App Store Connect API key** (Users and Access > Integrations > App Store Connect API, role *App Manager*).
   Download the `.p8` once. Note the **Key ID** and **Issuer ID**.
5. Add these **repository secrets** (GitHub > Settings > Secrets and variables > Actions):

   | Secret | Value |
   |---|---|
   | `APPLE_TEAM_ID` | your 10-character Team ID |
   | `ASC_KEY_ID` | API key ID |
   | `ASC_ISSUER_ID` | API issuer ID |
   | `ASC_KEY_P8_BASE64` | `base64 -i AuthKey_XXXX.p8` output |

## Uploads are manual only
The `TestFlight` workflow no longer runs on push. To upload a build, open GitHub > Actions > *TestFlight* > **Run workflow**
(it must be on the default branch). Nothing uploads unless you do that.

## Uploading a build
- **From GitHub:** Actions > *TestFlight* > Run workflow. It generates the project with XcodeGen, archives with
  cloud-managed signing, and uploads. The build number is the workflow run number.
- **From a Mac:**
  ```
  brew install xcodegen && xcodegen generate
  open StreamEmpire.xcodeproj   # set your Team under Signing & Capabilities
  # Product > Archive > Distribute App > App Store Connect > Upload
  ```

## After upload
- Builds appear in App Store Connect > TestFlight after processing (~10-30 min).
- Fill in *Test Information* and the export-compliance answers (the app sets `ITSAppUsesNonExemptEncryption = false`).
- Add internal testers (immediate) or an external group (needs a short Beta App Review).

## Pre-flight checklist
- [ ] Bundle ID and display name are yours
- [ ] App icon is the 1024x1024 `AppIcon.png` (no transparency); replace with final art if desired
- [ ] Version (`MARKETING_VERSION`) bumped for each public build; build number auto-increments in the workflow
- [ ] Game has been played on a real device (the CI only builds and unit-tests)
