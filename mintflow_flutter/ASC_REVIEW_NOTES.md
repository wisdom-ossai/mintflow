# App Store Connect — Review Notes (paste into ASC)

**App:** Mintflow (`app.mintflow.ios`)  
**Category:** Finance / Personal Finance

## Demo account

Provide a Seed + Growth/Pro account (or leave trial active):

- Email: `[fill before submit]`
- Password: `[fill before submit]`

Trial accounts unlock Pro for 7 days with no card.

## How to exercise key features

1. Sign in → complete onboarding if prompted.
2. **Budget ring / transactions** — Home and Transactions tabs.
3. **Plaid** — Linked accounts → Connect bank (sandbox or production). Credentials stay with Plaid; Mintflow is read-only and cannot move money.
4. **Goals** — Profile → Goals → Add goal → Contribute.
5. **Bills** — Profile → Bills (reminders fire ~3 days before due_day via push when FCM is configured).
6. **Debt plan (Pro)** — Profile → Debt plan → Avalanche/Snowball → Build plan (requires credit card balances).
7. **Receipt OCR (Pro)** — Profile → Scan receipt → Camera/Gallery.
8. **CSV export (Pro)** — Settings → Export.
9. **Subscriptions** — Paywall shows prices, restore, Privacy/Terms links. Server trial is separate from optional StoreKit offers.
10. **Account deletion** — Profile → Privacy & security → Delete account.

## Privacy / legal URLs

- Privacy: https://mintflow-api.up.railway.app/privacy
- Terms: https://mintflow-api.up.railway.app/terms
- Support: https://mintflow-api.up.railway.app/support

(Custom domain `mintflow.app` can replace these once DNS is attached.)

## Encryption

ITSAppUsesNonExemptEncryption = false (standard HTTPS only).
