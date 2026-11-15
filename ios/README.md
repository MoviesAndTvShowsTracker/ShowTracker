# Marquee iOS

Native SwiftUI client for Marquee (ShowTracker). Targets **iOS 26** for Liquid Glass system chrome. Lobby Light palette: Salt Grey / Deep Olive / Hibiscus Pink — see [DESIGN.md](DESIGN.md).

## Setup

```bash
cd ios
xcodegen generate
open Marquee.xcodeproj
```

Requires Xcode 26+ and an iOS 26 simulator or device.

## API

Default base URL: `http://localhost:5001` (simulator). Run the backend:

```bash
cd backend-server && npm run start:api
```

Override with UserDefaults key `apiBaseURL` (e.g. LAN IP for a physical device, or production URL).

## Google Sign-In

Auth includes a dev ID-token field that posts to `POST /users/google`. For production, add the Google Sign-In iOS SDK (SPM), configure `GIDClientID` in Info.plist to match `GOOGLE_CLIENT_ID` on the API, and replace the placeholder with the SDK button.

## App Store checklist

- [ ] App icon 1024×1024 in `Assets.xcassets/AppIcon`
- [ ] Privacy policy URL (account + diary data)
- [ ] Screenshots on iPhone 6.7" / 6.1"
- [ ] Production `apiBaseURL` (not localhost)
- [ ] Test Reduce Transparency / Reduce Motion
- [ ] Google Sign-In production client IDs

## Regenerate project

After adding Swift files:

```bash
cd ios && xcodegen generate
```
