# Marquee iOS — Design System

**Direction:** Lobby Light  
**Product:** Personal film & TV watch diary  
**Platform:** Native SwiftUI, **iOS 26** minimum (Liquid Glass on system chrome — no older deployment target)

## Brand triad (locked)

| Role | Name | Hex | Use |
|------|------|-----|-----|
| Ground | Salt Grey | `#E5E5DE` | Light canvas, soft surfaces behind glass |
| Ink | Deep Olive | `#3D3B2E` | Primary text, icons, dark chrome |
| Accent | Hibiscus Pink | `#FF4F8B` | CTAs, mark/rate only |
| Leaf | Olive Leaf | `#5C6B4A` | Dark-mode olive / progress / completed |

Deep Olive must be **visible** as brand green (chips, hero panels, kickers, avatars) — not only body text. Web layout is inspiration; prefer native iOS patterns when better.

## Derived tokens

### Light

| Token | Value |
|-------|--------|
| `surface` | `#E5E5DE` |
| `surfaceElevated` | `#F3F3EE` |
| `ink` | `#3D3B2E` |
| `inkMuted` | Deep Olive @ 55% |
| `accent` | `#FF4F8B` |
| `onAccent` | `#FFFFFF` |

### Dark

| Token | Value |
|-------|--------|
| `surface` | `#1C1B16` |
| `surfaceElevated` | `#2A281F` |
| `ink` | `#E5E5DE` |
| `inkMuted` | Salt Grey @ 55% |
| `accent` | `#FF4F8B` |
| `onAccent` | `#FFFFFF` |

## Typography

- UI: **SF Pro** (system) only
- Brand wordmark: logo asset moments only — no decorative display fonts in chrome

## Materials (Liquid Glass)

- Glass on **chrome only**: tab bar, toolbars, sheets, search field, FABs
- Never glass on poster tiles, list rows, or full-screen backgrounds
- `.regular` over Salt Grey content; `.clear` over rich media heroes (dim if needed)
- Group nearby custom glass in `GlassEffectContainer`

## Motion

- Micro-interactions: 100–250ms, interruptible springs
- Shared morph only for mark / rate / continue
- Respect Reduce Motion

## Anti-slop

- No Butter Yellow, Acid Citron, Haze Lavender, purple/indigo gradients
- No second accent; hibiscus is actions only (not pink borders on cards)
- No glow stacks, emoji decoration, or dashboard stat strips in the first viewport
- Prefer system `TabView`, `ToolbarItem`, `sheet`, `searchable`

## Signature moment

Continue Watching rail — next-episode CTA with hibiscus + confident mark spring; everything else Salt/Olive quiet.

## Logo

**Mark:** Theater-facade **M** (two pillars + peak, like a marquee canopy) with **three hibiscus marquee bulbs**. Salt ground, olive stroke. Not a film strip, clapper, or play button.

Assets in `ios/Brand/` (SVG mark, dark, lockup) + AppIcon / `MarqueeMark` in Assets. SwiftUI: `BrandMark`.

## Screen map

| Tab | Screens |
|-----|---------|
| Home | Dashboard, continue, week recap, watchlist rails |
| Films | Landing → Movie detail |
| TV | Landing → Show detail → episodes → Continue → Library |
| Search | Multi / film / TV |
| You | Profile, lists, stats, settings |
