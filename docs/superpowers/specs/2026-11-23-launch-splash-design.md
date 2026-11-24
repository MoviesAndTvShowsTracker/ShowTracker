# Launch splash & transition — design

**Date:** 2026-11-23 · **Size:** small change · **Platform:** iOS app (`ios/`)

## Why
The app should feel production-ready ahead of an App Store submission. Launch is
the first impression: today iOS shows a blank grey frame, then the logo pops in,
then the app zooms in. The user keeps the current smoke logo; the work is a
seamless splash and a buttery hand-off into the app.

## Goals
- No visible blink or jump between iOS's static launch frame and the animated splash.
- A calm, natural splash built on the existing smoke artwork.
- A continuous transition into the app, like Apple's icon-to-app zoom.
- Smooth on 120 Hz devices; respects Reduce Motion; matches light and dark.
- Fix the app icon file so it meets Apple's icon guidelines.

## Non-goals
- No new logo or redrawn artwork.
- No animation libraries (Lottie) or video.
- No change to onboarding / sign-in screens beyond being revealed by the transition.

## Anti-goals (would be a failure even if it "works")
- Splash that adds noticeable wait time (it must never wait on the network).
- Bouncy or flashy motion — it should feel quiet, like smoke settling.
- Dropped frames during the hand-off.

## Approaches considered
1. **Condense, then open through the logo** — use the artwork as one image; ambient
   motion while the session restores; exit by revealing the app through the
   logo's shape as it grows. *Chosen:* cheapest, robust, no new dependencies.
2. **Split olive and pink smoke into layers** — more alive, but cutting a painted
   raster into clean layers risks rough edges and several rounds of iteration.
3. **Lottie / video** — richest motion, but adds a library and an asset pipeline.

## Design
**Static launch frame (iOS, before code runs).** Background `LaunchBackground`
(Salt Grey, with a Lobby dark variant `#1C1B16`) plus a `LaunchMark` image centered
on screen. The SwiftUI splash renders the same image at the same size and center
(full-screen, ignoring safe areas), so the first animated frame is pixel-identical.
Because the app may force its own light/dark preference, the splash uses the
*system* appearance until the reveal, matching what iOS drew.

**Ambient (while the saved session restores, local only).** A soft blurred aura in
olive and pink blooms slowly behind the mark (pre-rendered, opacity/scale only), and
the mark eases up a few points with a ~1.02 scale — smoke settling, no bounce.

**Exit / reveal.** The app content appears through a rounded-square window that
grows from the logo's frame to full screen, while the mark scales up and fades and
the content settles from 1.04 → 1. Critically-damped spring (no overshoot),
~0.6–0.7 s. Exit uses only opacity/scale/mask — no large blurs — to hold 120 fps.
The existing `LaunchReveal` modifier is still removed after settle so navigation
transitions aren't fighting a parent transform.

**Timing.** Splash shows at least ~0.6 s from first frame, at most ~1.5 s; if the
session hasn't restored by then, reveal anyway. Warm resumes (returning from
background) show no splash.

**Reduce Motion.** No aura, no zoom: a 0.25 s cross-fade from splash to app.

**App icon fix.** Re-export the same artwork as a full-bleed 1024×1024 square (no
baked rounded tile or white margin); iOS applies the mask. `LaunchMark` is the same
art with transparent, continuous-corner rounding baked in for the static frame.

## Left to the builder
Exact aura colours/opacity, spring constants within the ranges above, the crop
inset used to remove the baked tile from the icon, and image scales (@2x/@3x).

## Verification
Simulator screen recording of cold launch (light + dark + Reduce Motion), frame-step
the hand-off for any jump; install on device and cold-launch.
