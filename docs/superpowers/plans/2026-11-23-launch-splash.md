# Launch Splash & Transition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A seamless cold launch: iOS's static frame shows the smoke logo, the SwiftUI splash continues from that exact frame, and the app is revealed through the growing logo shape.

**Architecture:** Static launch screen (Info.plist `UILaunchScreen` image + colour) hands off to a SwiftUI `LaunchSplashView` drawn pixel-identically. A pure `LaunchTiming` policy decides when to reveal; `RootView` drives one `revealed` flag that animates a rounded-square mask over the app plus the splash fading up and out.

**Tech Stack:** SwiftUI (iOS 26, Swift 6), XcodeGen, XCTest, a Swift script for image export, ffmpeg for frame checks.

**Spec:** `docs/superpowers/specs/2026-11-23-launch-splash-design.md`

## Global Constraints

- Keep the current smoke artwork; no new logo, no Lottie/video, no new dependencies.
- Splash visible ≥ 0.6 s and ≤ 1.5 s from first frame; never waits on the network.
- No splash on warm resume (returning from background).
- Exit animates opacity/scale/mask only — no large blurs; critically-damped spring (no overshoot), ~0.6–0.7 s.
- Reduce Motion: no aura, no zoom — 0.25 s cross-fade.
- Splash uses the **system** appearance (what iOS drew), not the app's forced preference, until reveal.
- Lobby palette only: Salt Grey `#E5E5DE`, dark surface `#1C1B16`, Deep Olive `#3D3B2E`, Olive Leaf `#5C6B4A`, Hibiscus `#FF4F8B`.
- Run `cd ios && xcodegen generate` after adding/removing files; never hand-edit `project.pbxproj`.

## Review Focus

- **Forced appearance mismatch:** system dark + app set to Light (or reverse) → splash matches iOS's static frame, then the revealed app shows its own theme with no flash. (Task 3 UI test `testLaunchInDarkSystemWithLightPreference`.)
- **Slow or stuck session restore:** `isRestoring` never flips → app is revealed at 1.5 s anyway. (Task 2 `testRevealCapsAtMaximum`.)
- **Signed-out and first-run paths:** sign-in screen or Welcome screen is what gets revealed, interactive after reveal. (Task 3 `testSignedOutRevealIsInteractive`.)
- **Screen sizes:** logo position on the static frame matches the splash on small and large phones (iPhone 17e and 17 Pro Max). (Task 3 frame check, both sims.)
- **Warm resume:** backgrounding and returning shows no splash. (Task 3 `testNoSplashOnWarmResume`.)

---

### Task 1: Icon and launch assets

**Files:**
- Create: `ios/Brand/scripts/export-launch-assets.swift`
- Modify: `ios/Marquee/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (regenerated)
- Create: `ios/Marquee/Resources/Assets.xcassets/LaunchMark.imageset/` (`LaunchMark@2x.png`, `LaunchMark@3x.png`, `Contents.json`)
- Modify: `ios/Marquee/Resources/Assets.xcassets/LaunchBackground.colorset/Contents.json` (add dark appearance `#1C1B16`)
- Modify: `ios/project.yml` (app `UILaunchScreen`; give `MarqueeUITests` its own `info.path: MarqueeUITests/Info.plist`)

**Interfaces:**
- Produces: asset `LaunchMark` (128 pt square, transparent continuous-corner rounding, radius 0.2237 × side); constant `LaunchMetrics.markSide: CGFloat = 128` consumed by Task 3.

- [ ] **Step 1: Write the check** — `swift ios/Brand/scripts/export-launch-assets.swift --check` asserts: AppIcon is 1024×1024, no alpha, corner pixel (2,2) is **not** white (`r+g+b < 2.9`); `LaunchMark@3x.png` is 384×384 with alpha 0 at (1,1) and alpha 1 at (192,192).
- [ ] **Step 2: Run it** — Expected: FAIL on "AppIcon corner is white".
- [ ] **Step 3: Implement export** — script reads the original `ios/Brand/AppIcon-1024.png` (keep it as the untouched source), finds the baked tile's bounding box (first non-white rows/cols), crops inward by 7% of the tile side to drop its rounded corners, resizes to 1024 (AppIcon, opaque), and to 256/384 px with a continuous rounded-rect alpha mask (LaunchMark @2x/@3x).
- [ ] **Step 4: Wire launch screen** — in `project.yml` app `info.properties.UILaunchScreen`: `UIColorName: LaunchBackground`, `UIImageName: LaunchMark`, `UIImageRespectsSafeAreaInsets: false`; move UI-test target to its own plist path. Run `xcodegen generate`; confirm `Marquee/Info.plist` contains `UIImageName` and `CFBundlePackageType` is `APPL`, not `BNDL`.
- [ ] **Step 5: Verify** — `--check` passes; build succeeds; cold-launch in the simulator and take `xcrun simctl io booted screenshot` within the first 0.3 s: logo centered on Salt Grey (the old splash still runs after it until Task 3).
- [ ] **Step 6: Commit** — `git commit -m "Ship full-bleed app icon and logo on the static launch screen."`

### Task 2: Launch timing policy (unit-tested)

**Files:**
- Create: `ios/Marquee/App/LaunchTiming.swift`
- Create: `ios/MarqueeTests/LaunchTimingTests.swift`
- Modify: `ios/project.yml` (add `MarqueeTests` `bundle.unit-test` target, host `Marquee`; add to scheme test targets)

**Interfaces:**
- Produces: `enum LaunchTiming { static let minimum: TimeInterval = 0.6; static let maximum: TimeInterval = 1.5; static func revealDelay(elapsed: TimeInterval, restored: Bool) -> TimeInterval? }` — returns seconds to wait before revealing, or `nil` meaning "keep waiting for restore".

- [ ] **Step 1: Write failing tests** in `LaunchTimingTests`:
  - `testWaitsForMinimumWhenRestoredEarly`: `revealDelay(elapsed: 0.2, restored: true) == 0.4` (accuracy 0.001)
  - `testRevealsImmediatelyAfterMinimum`: `revealDelay(elapsed: 0.9, restored: true) == 0`
  - `testKeepsWaitingWhileRestoring`: `revealDelay(elapsed: 0.9, restored: false) == nil`
  - `testRevealCapsAtMaximum`: `revealDelay(elapsed: 1.5, restored: false) == 0` and `revealDelay(elapsed: 3, restored: false) == 0`
- [ ] **Step 2: Run** — `xcodebuild test -scheme Marquee -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:MarqueeTests` → FAIL (`LaunchTiming` undefined).
- [ ] **Step 3: Implement** `LaunchTiming.revealDelay` per the signature.
- [ ] **Step 4: Run** — same command → PASS (4 tests).
- [ ] **Step 5: Commit** — `git commit -m "Add launch timing policy with a 0.6–1.5 s window."`

### Task 3: Splash view, reveal transition, RootView wiring

**Files:**
- Create: `ios/Marquee/App/LaunchSplash.swift` — `LaunchSplashView`, `LaunchRevealMask`, `LaunchMetrics`
- Modify: `ios/Marquee/App/RootView.swift:12-60,143-187` — replace `launchSplash`, `LaunchReveal`, and `playHandoff()`
- Create: `ios/MarqueeUITests/LaunchSplashTests.swift`

**Interfaces:**
- Consumes: asset `LaunchMark`; `LaunchMetrics.markSide`; `LaunchTiming.revealDelay(elapsed:restored:)`.
- Produces: `struct LaunchSplashView: View { var revealed: Bool }`; `struct LaunchRevealMask: ViewModifier { var revealed: Bool; var settled: Bool }`; splash root has `accessibilityIdentifier("launch.splash")` while visible.

Behaviour (values from spec):
- Splash: full-screen (`ignoresSafeArea`), background `LaunchBackground` resolved with the **system** trait (`UITraitCollection.current.userInterfaceStyle` captured at init), `Image("LaunchMark")` 128×128 centered — identical to the static frame.
- Ambient (not under Reduce Motion): pre-rendered aura = two `Circle`s (olive `#5C6B4A` @ 0.35, hibiscus @ 0.28) blurred once (radius 40), animated only by opacity 0→1 and scale 0.85→1 over 1.2 s `.smooth`; mark offset y 0→−4 and scale 1→1.02 with the same curve.
- Reveal: `withAnimation(.spring(response: 0.65, dampingFraction: 1))` sets `revealed = true`: app masked by a `RoundedRectangle(cornerRadius: 0.2237 × side, style: .continuous)` whose side grows from 128 to the screen diagonal × 1.05, centered; app content scale 1.04→1; splash scale 1→1.35 and opacity 1→0. `settled = true` 0.75 s later removes the mask modifier entirely.
- Reduce Motion: `withAnimation(.easeOut(duration: 0.25))` opacity-only swap; no aura, no mask, no scale.
- Timing loop in `RootView.task`: poll `LaunchTiming.revealDelay(elapsed:restored: !auth.isRestoring)` on `onChange(of: auth.isRestoring)` and a 1.5 s fallback `Task.sleep`; whichever reveals first wins, guarded by `revealed`.
- Warm resume: splash state lives in `RootView` `@State`, which survives backgrounding — no extra work, but covered by test.

- [ ] **Step 1: Write failing UI tests** in `LaunchSplashTests`:
  - `testSplashRevealsWithinCap`: launch; `app.otherElements["launch.splash"]` exists within 0.5 s; then `waitForNonExistence(timeout: 2.0)` is true.
  - `testSignedOutRevealIsInteractive`: launch with `-uiTesting` (signed-out path); after splash gone, `app.buttons.firstMatch.isHittable` is true.
  - `testNoSplashOnWarmResume`: after reveal, `XCUIDevice.shared.press(.home)`, `app.activate()`; `launch.splash` does not exist after 0.3 s.
  - `testLaunchInDarkSystemWithLightPreference`: set `app.launchArguments += ["-marquee.appearance", "light"]` (UserDefaults argument domain for `AppPreferences.Keys.appearance`) with the simulator in dark mode (`xcrun simctl ui booted appearance dark` in the test plan pre-action, or set via `XCUIDevice.shared.appearance = .dark`); screenshot at first frame of splash has mean centre-edge pixel luminance < 0.2 (dark), and after reveal the app background luminance > 0.8 (light).
- [ ] **Step 2: Run** — `xcodebuild test ... -only-testing:MarqueeUITests/LaunchSplashTests` → FAIL (no `launch.splash`).
- [ ] **Step 3: Implement** `LaunchSplash.swift` and the `RootView` changes above; delete the old `launchSplash`/`LaunchReveal`; keep `AmbientBlobs` fading in with `revealed`.
- [ ] **Step 4: Run** — same command → PASS (4 tests); `MarqueeTests` still PASS.
- [ ] **Step 5: Frame check for jumps** — on iPhone 17e and 17 Pro Max sims: `xcrun simctl io booted recordVideo /tmp/launch.mov` around `xcrun simctl launch booted com.jimil.marquee`; `ffmpeg -i /tmp/launch.mov -vf fps=60 /tmp/f%03d.png`; compare the last static-launch frame and first splash frame — logo bounding box differs by ≤ 1 px and no blank frame between them; step through the reveal frames for any jump or flash. Repeat light, dark, Reduce Motion.
- [ ] **Step 6: Commit** — `git commit -m "Seamless launch: splash continues the static frame and reveals the app through the logo."`

### Task 4: Device verification

- [ ] **Step 1:** Build for the iPhone (`xcodebuild -scheme Marquee -destination 'platform=iOS,id=00008160-00093C2C0ED0000A' -allowProvisioningUpdates build`), install and cold-launch via `xcrun devicectl`.
- [ ] **Step 2:** On device, check: home-screen icon shows no inner tile/white border; cold launch has no blink; reveal is smooth. Report what was seen.
