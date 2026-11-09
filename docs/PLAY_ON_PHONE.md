# Play Stream Empire on your iPhone

Pick the route that matches what you have. The game needs **iOS 17 or newer**.

## A. You have a Mac (free Apple ID is enough)
1. Install Xcode (Mac App Store) and XcodeGen: `brew install xcodegen`.
2. `git clone` this repo, then in the folder: `xcodegen generate && open StreamEmpire.xcodeproj`.
3. In Xcode: select the **StreamEmpire** target > *Signing & Capabilities* > tick *Automatically manage signing* > choose your **Team** (your Apple ID; add it under Xcode > Settings > Accounts).
   Change the **Bundle Identifier** to something unique, e.g. `com.yourname.streamempire`.
4. Plug in your iPhone, unlock it, tap *Trust*. On the iPhone enable **Settings > Privacy & Security > Developer Mode** (it restarts the phone).
5. Pick your iPhone as the run destination and press **Run**.
6. First launch: **Settings > General > VPN & Device Management** > trust your developer profile.
Free Apple IDs expire the install after **7 days** (just press Run again; your save stays).

## B. Paid Apple Developer account ($99/yr): TestFlight, no Mac needed
Follow `docs/TESTFLIGHT.md`. Builds upload from GitHub Actions; you install through the TestFlight app and each build lasts 90 days.

## C. No Mac, no paid account: sideload the unsigned .ipa
1. GitHub > **Actions** > *Unsigned IPA* > **Run workflow**. When it finishes, download the `StreamEmpire-unsigned-ipa` artifact (a zip containing `StreamEmpire-unsigned.ipa`).
2. Install it with a sideloading tool that signs with your own free Apple ID, e.g. **AltStore** (needs AltServer running on a Windows PC or Mac on the same Wi-Fi) or **Sideloadly** (Windows/Mac, USB).
3. Enable Developer Mode and trust the profile as in route A (steps 4 and 6).
Free-ID installs expire after 7 days; the tools can refresh them.
This route is untested: it depends on third-party tools, which I haven't run.

## Just want to try it without a phone?
Open the project in Xcode and run it on the iPhone **Simulator** (Mac only).

## Your save
The game autosaves to the app's Documents folder. Deleting the app deletes the save. Updating over the top keeps it, unless the save format version changed (the game then starts fresh).
