---
target: paywall
total_score: 28
max_score: 32
na_heuristics: 7,10
p0_count: 0
p1_count: 1
target_identity: "file:/Users/user/Desktop/flowra/mintflow_flutter/lib/presentation/screens/subscription/paywall_screen.dart"
target_fingerprint: "sha256:0e25016af6569fffb39980300b130e3d040d5b229fc5b80bc72a3f73655c81c3"
target_path: /Users/user/Desktop/flowra/mintflow_flutter/lib/presentation/screens/subscription/paywall_screen.dart
timestamp: 2026-11-05T07-06-35Z
slug: screens-subscription-paywall-screen-dart-853c4509
---
# Critique — Paywall (`paywall_screen.dart`) — post harden/distill/clarify/polish

Method: design review only (detector not applicable, native platform)
Mode: Persuade · Target: mintflow_flutter/lib/presentation/screens/subscription/paywall_screen.dart

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | CTA/loading clear; plan select still border-only |
| 2 | Match System / Real World | 4 | Benefit subs + garden tiers read clearly |
| 3 | User Control and Freedom | 4 | Close + Seed free exit |
| 4 | Consistency and Standards | 3 | formMax sticky vs contentMax plans; dual “Try again” when RC fails |
| 5 | Error Prevention | 4 | Paid Start gated until package ready |
| 6 | Recognition Rather Than Recall | 3 | 3 teasers always visible; full list on select |
| 7 | Flexibility and Efficiency | n/a | Persuade |
| 8 | Aesthetic and Minimalist Design | 4 | Sticky hierarchy + muted restore/legal |
| 9 | Error Recovery | 3 | Plain recovery; store errors still somewhat generic |
| 10 | Help and Documentation | n/a | Persuade |
| **Total** | | **28/32** | **Good** |

## Design Specificity Verdict

**LLM assessment:** Stronger Mintflow authorship — navy hero, mint rarity CTA, Seed/Growth/Pro with benefit lines and teasers. Still a familiar IAP paywall skeleton, but trust states and compare affordances feel product-owned rather than template-default.

**Deterministic scan:** not applicable (native platform)

**Visual overlays:** not applicable (native platform)

## Overall Impression

Previous P1s are largely closed. Remaining risk is factual: the always-on “7-day Pro trial” line can mislead when Growth is selected.

## What's Working

1. Paid CTA prevention (`Purchases unavailable` / `Plan not available yet` / Try again) protects trust.
2. Teasers on every card remove compare-by-memory.
3. Sticky Start with muted restore/legal keeps Persuade peak clear.

## Priority Issues

### [P1] Trial copy always says “Pro” regardless of selection
- **Why:** Default is Growth; gated Growth features still show “7-day Pro trial,” which can over-promise or confuse entitlement.
- **Fix:** “7-day trial — cancel anytime” or tier-aware trial line.
- **Suggested command:** `/impeccable clarify`

### [P2] Fallback prices can disagree with store strings
- **Why:** Cards may show list `$6.99/mo` while CTA uses store `priceString` (or the reverse while packages resolve).
- **Fix:** Prefer store strings everywhere once offerings load; gray/skeleton prices until then.
- **Suggested command:** `/impeccable harden`

### [P2] Fixed 160px scroll clearance under sticky bar
- **Why:** Large Dynamic Type or localization can clip last plan or leave a gap.
- **Fix:** Measure sticky height or pad with `MediaQuery.viewPadding` + estimated cluster.
- **Suggested command:** `/impeccable adapt`

### [P3] Annual savings said twice (tooltip + green tip)
- **Fix:** Keep the visible tip; drop redundant tooltip or vice versa.
- **Suggested command:** `/impeccable distill`

## Cognitive Load

Checklist: teasers restore recognition; selected full lists still long (1 soft failure). **~1 failure = low.**

## Emotional Journey

Peak: sticky Start with price. Valley closed for RC-down Start tap. Trust line always present helps gated arrivals; Pro-trial wording is the remaining valley.

## Persona Red Flags

**Jordan:** Seed still a peer card — better with “Free forever” + teasers; trial “Pro” wording may scare Growth-intent users.
**Casey:** Sticky CTA + teasers good; 160 spacer + tall feature expand still a scroll tax.
**Riley:** Package-null vs RC-down states labeled; price fallback mismatch still probeable.

## Minor Observations

- Semantics label is name+price only (no “Popular” / teaser summary).
- Banner Try again + CTA Try again duplicate when RC configured but failed.

## Questions to Consider

- Should Seed be a text exit under paid cards instead of a third peer?
- Should trial copy be tier-neutral?
- Is “Save 30%” strong enough without repeating in a tooltip?
