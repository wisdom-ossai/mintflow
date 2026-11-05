# Product

<!-- impeccable:product-schema 1 -->

> **Inference note:** Written during `/impeccable init` as part of a batch “run all” request. Facts below are taken from `.cursor/skills/flowra-fullstack/product.md`, `mintflow_flutter` code/README, and `DESIGN.md`. They are labeled where the repo is the only source; not a live user interview.

## Platform

adaptive

Native Flutter client shipping to iOS and Android with shared Material theming and platform-adaptive controls where used (`Switch.adaptive`, etc.).

## Users

Individuals managing personal spending who want to see where money goes this month, stay inside a monthly target, and take a useful next action — without credit-card double-counting or shaming *(inferred from product skill JTBD)*.

## Product Purpose

**Mintflow** (repo/app name; product family also documented as Flowra) is personal-finance tracking with AI coaching: budget ring vs monthly target, transactions (manual + Plaid), insights, goals, bills, and tiered Pro features.

Success for a user: complete signup → onboarding (name, income, spending target, optional bank link) → understand spend vs target on Home → act on transactions/insights/bills without fake data once APIs are wired.

## Positioning

Budget-ring-first Home plus needs/wants and Claude-backed insights, with explicit credit-card payment exclusion so spend totals stay honest. Differentiator vs generic trackers: **counts_as_spend** discipline + AI categorization/insights behind Growth/Pro *(inferred)*.

## Brand Commitments

- Tagline / motion language: money “in motion” / flowing forward *(app description + fullstack skill)*.
- Visual system owned by `DESIGN.md` (navy + mint + cream) — do not redefine here.
- Plaid trust copy: credentials never touch Mintflow; read-only access.
- Copy should stay short and specific (e.g. “of $3,500 spent”), not generic fintech fluff.

## Capabilities

- Auth: email/password, Google, Apple; FastAPI JWT via secure storage
- Onboarding wizard; optional Plaid Link
- Dashboard budget ring, summaries, teasers, recent activity
- Transactions list/search/filters; add manual transaction
- Insights month review
- Goals and bills (with tier gates)
- Notifications prefs + in-app notifications
- Paywall / RevenueCat subscriptions (Seed / Growth / Pro)
- Profile: linked accounts, export, privacy/security, appearance

## Constraints

- Money: persist Decimal/`Numeric`; display via format helpers; default USD / en-US
- Plaid countries today: US only — expanding is a product decision
- Subscription tiers enforced server-side (`has_feature`); client must not unlock more than server
- Account deletion must be complete (GDPR)
- Do not ship screens with mock names/amounts once APIs are wired

## Accessibility

Target WCAG-oriented mobile a11y: labeled fields, ≥48dp targets, Reduce Motion honored via `MintMotion`, Dynamic Type–friendly floors (11pt+). Full VoiceOver/TalkBack device verification is still outstanding.

## Open Decisions

- Whether public brand name is **Mintflow** vs **Flowra** in store listings and marketing *(repo uses both)*.
- Android Dynamic Color: intentionally off (brand-first) per `DESIGN.md`.
- Web client: documented in product skill; this Flutter package is mobile-first adaptive.
