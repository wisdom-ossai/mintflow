---
name: Mintflow
description: Personal finance that keeps your money in motion — calm navy, mint action, trustworthy clarity.
colors:
  navy: "#05122B"
  mint: "#2CE683"
  mint-deep: "#1EA35D"
  mint-mid: "#24C974"
  mint-soft: "#B8F5D4"
  mint-wash: "#E8FBF2"
  cream: "#F4F7FB"
  cream-dark: "#E8EDF5"
  ink: "#05122B"
  red: "#E05A40"
  purple: "#7B5CF0"
  blue: "#4A6CF7"
  dark-surface: "#05122B"
  dark-card: "#0A1A38"
  dark-border: "#1A2E4A"
  dark-text: "#FFFFFF"
  dark-muted: "#8BA3C0"
typography:
  display:
    fontFamily: "Poppins"
    fontSize: "32px"
    fontWeight: 400
    lineHeight: 1.2
    letterSpacing: "-0.5px"
  headline:
    fontFamily: "Poppins"
    fontSize: "26px"
    fontWeight: 400
    lineHeight: 1.25
  title:
    fontFamily: "Poppins"
    fontSize: "22px"
    fontWeight: 400
    lineHeight: 1.3
  body:
    fontFamily: "DM Sans"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.6
  label:
    fontFamily: "DM Sans"
    fontSize: "14px"
    fontWeight: 500
    lineHeight: 1.4
  chip:
    fontFamily: "DM Sans"
    fontSize: "11px"
    fontWeight: 600
    lineHeight: 1.3
rounded:
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "28px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "24px"
  xxxl: "32px"
  section: "40px"
components:
  button-primary:
    backgroundColor: "{colors.mint}"
    textColor: "{colors.navy}"
    rounded: "{rounded.lg}"
    padding: "16px 24px"
  button-outlined:
    backgroundColor: "transparent"
    textColor: "{colors.mint}"
    rounded: "{rounded.lg}"
    padding: "16px 24px"
  card:
    backgroundColor: "#FFFFFF"
    textColor: "{colors.ink}"
    rounded: "{rounded.lg}"
  nav-active:
    backgroundColor: "{colors.mint-wash}"
    textColor: "{colors.mint-mid}"
---

# Design System: Mintflow

## Overview

**Creative North Star: "Calm Ledger Light"** *(inferred from `MintflowColors` brand comments — navy + mint, calm, modern, trustworthy; no PRODUCT.md interview yet)*

Mintflow is an Operate-mode personal finance app. The UI should feel like a clear monthly ledger under cool daylight: navy brand chrome for authority, mint for progress and primary action, cream paper for reading. Density stays scannable — one primary task per screen, amounts in Poppins, UI chrome in DM Sans.

Brand expresses through palette, type pairing, and the budget ring — not through glassmorphism, purple glow, or dashboard-stat clutter.

**Key Characteristics:**
- Navy headers / mint CTAs / cream canvases
- Material 3 scaffolding with Mintflow tokens (not Dynamic Color by default — brand-first static schemes)
- Light and dark are first-class `ThemeData` schemes
- Adaptive shell: bottom bar &lt; 840dp, navigation rail ≥ 840dp
- Motion is ease-out only; honor Reduce Motion / disable animations

## Colors

Cool navy–mint system with semantic washes for status and category cues.

### Primary
- **Ledger Navy** (#05122B): Brand chrome, app bars, splash, dark scaffold. Text/icons on it use cream (`onBrand`).
- **Action Mint** (#2CE683): Primary buttons, progress, selected nav. On mint, prefer navy foreground for contrast.

### Secondary
- **Deep Mint** (#1EA35D) / **Mid Mint** (#24C974): Pressed/selected accents and emphasis without leaving the mint family.

### Tertiary
- **Signal Purple** (#7B5CF0), **Info Blue** (#4A6CF7), **Alert Red** (#E05A40): Feature and status accents only — never as page themes.

### Neutral
- **Cool Cream** (#F4F7FB): Page background (light).
- **Card White** (#FFFFFF light / #0A1A38 dark): Elevated surfaces via `MintflowColors.card`.
- **Ink** (#05122B) with opacity steps for secondary/tertiary text.

### Named Rules
**The Mint Rarity Rule.** Mint owns primary actions and progress. Do not flood screens with mint fills.
**The Brand Overlay Rule.** On navy chrome, use `onBrand` / `brandOverlay` — never raw gray or ad-hoc white opacities for new work.
**The Dynamic Color Rule.** Android wallpaper-derived schemes are intentionally out of scope; keep the static navy/mint brand unless product revisits this.

## Typography

**Display Font:** Poppins (amounts, display headlines)
**Body Font:** DM Sans (UI, body, labels)

**Character:** Soft geometric display for money moments; humanist sans for dense UI. Floor **11px** for any readable label/chip (HIG / TalkBack comfort).

### Hierarchy
- **Display** (Poppins 32 / 26 / 22): Screen titles and greetings.
- **Amount** (Poppins 42 / 28 / 20): Currency and ring center values; keep tabular alignment where possible.
- **Body** (DM Sans 16 / 14 / 13): Descriptions and list secondary lines.
- **Label** (DM Sans 14 / 12 / 11): Controls, nav, chips. Prefer sentence case; avoid ALL CAPS micro-labels.

### Named Rules
**The Eleven Point Floor.** No UI text below 11px. Decorative glyphs may be icon-sized, not type-sized under the floor.

## Layout

Phone-first Operate layouts with 20px horizontal page padding on main screens. Spacing scale: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40.

- **Compact (&lt;840):** Material `NavigationBar` (4 destinations) + end-float FAB on Home/Transactions.
- **Expanded (≥840):** `NavigationRail` + content; FAB moves to rail leading.
- Safe areas honored; sheets pad with `viewInsets` for keyboard.
- Orientation unlocked; restructure with breakpoints rather than stretching.

## Elevation & Depth

Mostly flat tonal layering: hairline borders (`ink10` / `darkBorder`) and soft navy-tinted shadows sparingly (e.g. FAB). Prefer border + surface shift over heavy drop shadows.

### Shadow Vocabulary
- **FAB lift** (`0 4px 12px` mint at ~30%): Primary action only.
- Avoid multi-layer neon glows and zero-offset colored halos.

## Shapes

Generous but calm radii: controls `lg` (16), sheets/cards up to `xl`/`xxl` (20–28), filters and tags `pill`. Square corners are not part of this system.

## Components

### Buttons
- **Primary:** Mint fill, navy/cream on-color per theme, 16px vertical padding, `lg` radius.
- **Outlined / Text:** Mint foreground; keep for secondary paths.
- **Loading:** Spinner uses navy on mint (or cream on navy/purple accents) — not raw `Colors.white` in new code.

### Chips / Filters
- Min height 48 for touch; selected = mint fill + navy label; idle = brand overlay on navy chrome or soft fill on page.

### Cards / Containers
- Flat card surface + 1px hairline; `lg`–`xl` radius; internal padding ≥16.

### Inputs / Fields
- Always set `labelText` (programmatic association). Use `mintInputDecoration`. Focus border mint 1.5px. Password visibility controls need tooltips.

### Navigation
- Bottom: Material `NavigationBar` with mint wash indicator (theme-driven).
- Rail: Material `NavigationRail` with mint indicator wash.
- Toggles / confirms: `Switch.adaptive`, `AlertDialog`, `SegmentedButton` — no hand-rolled chrome.

### Signature: Budget Ring
- Navy field, mint arc, Poppins amount. Animate with ease-out; jump to end state when Reduce Motion is on.

## Do's and Don'ts

### Do:
- **Do** use `MintflowColors.*` helpers (`page`, `card`, `textPrimary`, `onBrand`, washes) instead of raw hex in screens.
- **Do** keep touch targets ≥48dp and add tooltips/semantics on icon-only controls.
- **Do** gate decorative motion with `MintMotion` / `MediaQuery.disableAnimationsOf`.

### Don't:
- **Don't** introduce purple-on-white marketing gradients or gold accents (legacy token names map to mint).
- **Don't** lock portrait to hide layout bugs; adapt with breakpoints.
- **Don't** ship unlabeled `GestureDetector` icon hits or visual-only `Label` without `labelText`.
- **Don't** drop type below 11px for badges — use `MintflowTextStyles.chip`.
