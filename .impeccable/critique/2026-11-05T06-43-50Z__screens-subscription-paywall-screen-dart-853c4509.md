---
target: paywall
total_score: 24
max_score: 32
na_heuristics: 7,10
p0_count: 0
p1_count: 2
target_identity: "file:/Users/user/Desktop/flowra/mintflow_flutter/lib/presentation/screens/subscription/paywall_screen.dart"
target_fingerprint: "sha256:e93882799b8e5d926b23a544c19254e30a9df2160b061922180bd8e7102164ce"
target_path: /Users/user/Desktop/flowra/mintflow_flutter/lib/presentation/screens/subscription/paywall_screen.dart
timestamp: 2026-11-05T06-43-50Z
slug: screens-subscription-paywall-screen-dart-853c4509
closed: true
---
# Critique — Paywall (`paywall_screen.dart`)

Method: design review only (detector not applicable, native platform)
Mode: Persuade · Target: mintflow_flutter/lib/presentation/screens/subscription/paywall_screen.dart

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Loading/purchase spinners + snackbars; plan select lacks stronger confirmation beyond border |
| 2 | Match System / Real World | 3 | Seed/Growth/Pro garden metaphor fits; “Most popular” duplicated as sub + chip |
| 3 | User Control and Freedom | 4 | Close + Seed “Continue with free” are clear exits |
| 4 | Consistency and Standards | 3 | Tokens/Material solid; sticky formMax vs contentMax plans is intentional but sharp |
| 5 | Error Prevention | 2 | Start stays tappable when RC unavailable → snackbar after intent |
| 6 | Recognition Rather Than Recall | 2 | Features only on selected plan — comparing tiers forces memory |
| 7 | Flexibility and Efficiency | n/a | Persuade surface |
| 8 | Aesthetic and Minimalist Design | 3 | Clean navy/mint; sticky cluster packs CTA + restore + legal tightly |
| 9 | Error Recovery | 3 | Plain-language banners/snackbars + Try again; store errors sometimes generic |
| 10 | Help and Documentation | n/a | Persuade surface (legal line is IAP disclosure, not help) |
| **Total** | | **24/32** | **Good** |

## Design Specificity Verdict

**LLM assessment:** Authored enough to feel Mintflow — navy chrome, mint CTA rarity, Seed/Growth/Pro naming, feature-gated headlines. Structure is still a familiar App Store paywall (period toggle → three cards → sticky Start). Opportunity: make Growth the optical hero (not just “Popular” chip) and tie trial/trust copy to gated-feature arrivals.

**Deterministic scan:** not applicable (native platform)

**Visual overlays:** not applicable (native platform)

## Overall Impression

Decision path is clear after the layout pass: headline → period → plans → sticky Start. Biggest gap is trust + prevention when billing isn’t ready, and comparison friction when features hide behind selection.

## What's Working

1. **Sticky mint CTA** keeps the Persuade peak action in the thumb zone with live price in the label.
2. **Feature-aware defaults** (Growth vs Pro) + progressive feature reveal reduce noise on first glance.
3. **Brand chrome** (navy header, cream type, mint action) matches Calm Ledger Light without purple-glow SaaS tropes.

## Priority Issues

### [P1] Start remains active when purchases aren’t available
- **Why:** User commits intent, then hits a red snackbar — breaks high-stakes trust.
- **Fix:** Disable primary CTA (or swap to “Try again”) when `!_rcConfigured`; keep restore disabled as today.
- **Suggested command:** `/impeccable harden`

### [P1] Plan comparison requires recall
- **Why:** Only the selected card expands features (7–9 bullets). Switching Seed ↔ Growth forces remembering prior lists.
- **Fix:** Show a short “includes” teaser on unselected cards (3 bullets) or a compare strip; keep full list on selected.
- **Suggested command:** `/impeccable distill` or `/impeccable layout`

### [P2] High-stakes arrivals lose trial reassurance
- **Why:** Trial line only when `feature == null`. Gated-feature users (highest intent) see urgency without the cancel-anytime cushion.
- **Fix:** Always show a one-line trust cue under the headline (trial and/or cancel anytime).
- **Suggested command:** `/impeccable clarify`

### [P2] Sticky footer hierarchy is flat
- **Why:** 4px between Start and Restore; legal sits in the same cluster — tertiary actions compete with the peak.
- **Fix:** 8–12px above restore; mute restore further; keep legal as true fine print.
- **Suggested command:** `/impeccable polish`

### [P3] “Most popular” said twice on Growth
- **Why:** `plan.sub` and Popular chip repeat the same claim.
- **Fix:** Sub → benefit line (“Bank sync + AI insights”); keep one Popular mark.
- **Suggested command:** `/impeccable clarify`

## Cognitive Load

Checklist failures: **chunking** (7–9 features when selected), **working memory** (cross-plan compare). **2 failures = moderate.** Decision points: period (2) OK; plans (3) OK; CTA (1) OK.

## Emotional Journey

Peak: sticky Start with price. Valley: RC-unavailable path still invites Start. End: success snackbar → dashboard is strong; cancel is silent (good). Gated-feature path under-reassures.

## Persona Red Flags

**Jordan (First-Timer):** Three garden-named tiers without a one-line “who it’s for”; Seed as a card can read like a paid option until the CTA flips to “Continue with free.”

**Casey (Distracted Mobile):** Sticky CTA helps thumb reach; long selected feature lists push scroll before commit; restore+legal crowd the bottom.

**Riley (Stress Tester):** Start when RC down; package-null snackbar after selecting a paid plan; annual $/mo math uses fallback list prices when store string missing — possible mismatch with displayed store price.

## Minor Observations

- Price `fontSize: 18` override bypasses type scale.
- `credit_utilization` forces Pro select but has no `_featureCopy` entry → generic headline.
- Fixed `SizedBox(height: 160)` scroll clear is brittle vs measuring sticky height.

## Questions to Consider

- What if unselected plans showed three “includes” bullets so Growth wins on sight, not only after tap?
- Should a failed store load replace the CTA entirely with retry, instead of a snackbar after tap?
- Does Seed belong as a peer card, or as a text exit under the paid tiers?
