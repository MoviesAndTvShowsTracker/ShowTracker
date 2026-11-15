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

## Config

Copy `.env.example` to `.env` in this folder. `.env` is gitignored.

```
API_BASE_URL=https://marquee-4kjw.onrender.com
GOOGLE_CLIENT_ID=your_web_oauth_client_id.apps.googleusercontent.com
```

## Google Sign-In

The iOS client ID lives in `GoogleService-Info.plist`. The web client ID stays `GOOGLE_CLIENT_ID` (also `GIDServerClientID`) so the API can verify the ID token.

Add `GOOGLE_IOS_CLIENT_ID` on Render if you want the API to accept iOS-audience tokens as well as web ones.

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
