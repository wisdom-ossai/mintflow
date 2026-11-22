# Mintflow iOS App Store — operator checklist

Code parity for marketed features (goals, debt, OCR, bill reminders, paywall legal links) is in the repo. Complete these **operator** steps before TestFlight → Review.

## 1. Legal URLs (must return 200)

Deploy [website/](../website/) to `mintflow.app`:

- https://mintflow.app/privacy
- https://mintflow.app/terms
- https://mintflow.app/support

## 2. Production API

Follow [DEPLOYMENT.md](DEPLOYMENT.md) Parts 1–2:

- Supabase + Railway with `APP_ENV=production`
- `alembic upgrade head` (includes `0008_goals_debt_ocr`)
- `curl https://api.mintflow.app/health`
- Plaid production approval → `PLAID_ENV=production`

## 3. Firebase + APNs

1. Add iOS app `app.mintflow.ios` in Firebase
2. Download `GoogleService-Info.plist` → `ios/Runner/` (see `.example`)
3. Upload APNs `.p8` in Firebase Cloud Messaging
4. Entitlement `aps-environment` is already set to `production` in `Runner.entitlements`

## 4. Apple Developer + ASC

1. Enroll Apple Developer Program
2. App ID `app.mintflow.ios` with Sign In with Apple + Push Notifications
3. New App: Mintflow · Finance · SKU `mintflow-ios-001`
4. Fill `ios/ExportOptions.plist` `teamID` (replace `YOUR_TEAM_ID`)

## 5. IAP + RevenueCat

App Store Connect subscriptions:

| Product ID | Price |
|------------|-------|
| `mintflow_growth_monthly` | $6.99 |
| `mintflow_growth_annual` | $59 |
| `mintflow_pro_monthly` | $12.99 |
| `mintflow_pro_annual` | $99 |

RevenueCat: entitlements `growth` / `pro`, webhook → `https://api.mintflow.app/v1/subscriptions/webhook`.

Release build:

```bash
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://api.mintflow.app \
  --dart-define=REVENUECAT_IOS_PUBLIC_KEY=appl_YOUR_KEY
```

## 6. TestFlight QA

- Email / Apple / Google signup
- 7-day Pro trial gates
- Plaid link, goals, bills, debt plan, receipt OCR, CSV export
- Sandbox IAP purchase + restore
- Push notification (bill/card)
- Account delete

## 7. Screenshots + metadata

Use description/keywords from DEPLOYMENT.md Part 5.3. Capture real flows only (Dashboard, Goals, Bills, Debt, Onboarding) for 6.7" and 6.5".

## 8. Submit for review

Provide demo account + note: read-only Plaid; subscription terms on paywall; privacy/terms URLs.
