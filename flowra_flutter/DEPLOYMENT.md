# Flowra — Deployment Guide

Step-by-step from zero to live on Railway, App Store, and Google Play.

---

## Overview

| Platform           | Service          | Status                                       |
| ------------------ | ---------------- | -------------------------------------------- |
| Backend API        | Railway          | Dockerfile deploy                            |
| Database + Auth    | Supabase         | Managed cloud                                |
| iOS app            | App Store        | TestFlight → Production                      |
| Android app        | Google Play      | Internal → Production                        |
| Web app            | Firebase Hosting | Auto-deploy                                  |
| Push notifications | Firebase FCM     | Configured in Firebase Console               |
| Subscriptions      | RevenueCat       | Products in App Store Connect + Play Console |

---

## Part 1 — Supabase setup

### 1.1 Create project

1. Go to [supabase.com](https://supabase.com) → New project
2. Name: `flowra-production`
3. Region: `us-east-1` (closest to Railway default)
4. Save your database password securely

### 1.2 Get API keys

Dashboard → Settings → API

```
SUPABASE_URL            = https://your-project-id.supabase.co
SUPABASE_ANON_KEY       = eyJ...  (safe to use in Flutter app)
SUPABASE_SERVICE_ROLE_KEY = eyJ...  (backend only — never in Flutter)
```

### 1.3 Get database URL

Dashboard → Settings → Database → Connection string → URI

Copy the URI and replace `postgresql://` with `postgresql+asyncpg://`:

```
DATABASE_URL = postgresql+asyncpg://postgres:YOUR_PASSWORD@db.your-project-id.supabase.co:5432/postgres
```

### 1.4 Enable Auth providers

Dashboard → Authentication → Providers

Enable:

- Email (on by default)
- Google (add OAuth credentials from Google Cloud Console)
- Apple (add credentials from Apple Developer portal)

### 1.5 Run Alembic migrations

```bash
cd flowra-backend
cp .env.example .env
# Fill in SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, DATABASE_URL

pip install -r requirements.txt
alembic upgrade head
python scripts/seed_categories.py
```

### 1.6 Apply Row Level Security

Copy the contents of `scripts/supabase_rls.sql` and paste into:
Supabase Dashboard → SQL Editor → New query → Run

---

## Part 2 — Railway (Backend API)

### 2.1 Create Railway project

1. Go to [railway.app](https://railway.app) → New project → Deploy from GitHub repo
2. Select your repo
3. Choose the `flowra-backend` directory as root

### 2.2 Set environment variables

Railway Dashboard → Your service → Variables → Add all from `.env.example`:

```
APP_ENV                   = production
SECRET_KEY                = (generate: python3 -c "import secrets; print(secrets.token_hex(32))")
ALLOWED_ORIGINS           = https://flowra.app,https://www.flowra.app
SUPABASE_URL              = (from Supabase)
SUPABASE_ANON_KEY         = (from Supabase)
SUPABASE_SERVICE_ROLE_KEY = (from Supabase)
DATABASE_URL              = (from Supabase)
PLAID_CLIENT_ID           = (from Plaid dashboard)
PLAID_SECRET              = (start with sandbox secret)
PLAID_ENV                 = sandbox
ANTHROPIC_API_KEY         = (from console.anthropic.com)
FIREBASE_CREDENTIALS_PATH = /app/firebase-credentials.json
REVENUECAT_WEBHOOK_SECRET = (from RevenueCat)
STRIPE_SECRET_KEY         = (from Stripe)
SENTRY_DSN                = (from Sentry)
```

### 2.3 Add firebase-credentials.json

Railway → Your service → Variables → Raw Editor

Add as a file mount (Railway supports file variables):

```
FIREBASE_CREDENTIALS = (paste entire JSON contents)
```

Then update your startup script to write it:

```bash
echo "$FIREBASE_CREDENTIALS" > /app/firebase-credentials.json
```

Or use Railway's volume mount feature for the JSON file.

### 2.4 Custom domain

Railway → Your service → Settings → Domains → Add custom domain

Add: `api.flowra.app`

Point DNS CNAME at Railway's provided hostname.

### 2.5 Verify deployment

```bash
curl https://api.flowra.app/health
# Expected: {"status":"ok","version":"1.0.0","env":"production"}

curl https://api.flowra.app/docs
# Expected: Flowra Swagger UI (disabled in production — 404 is correct)
```

### 2.6 Plaid production

After building and testing with sandbox:

1. Apply for Plaid production access at dashboard.plaid.com
2. Submit your app screenshots + privacy policy URL
3. Plaid reviews within 1–3 business days
4. Once approved, update `PLAID_ENV=production` and `PLAID_SECRET` in Railway

---

## Part 3 — Firebase (Push Notifications + Web Hosting)

### 3.1 Create Firebase project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. New project → `flowra-app`
3. Disable Google Analytics (optional for privacy)

### 3.2 Add apps

**Android:**

- Package name: `app.flowra.android`
- Download `google-services.json` → `flowra-flutter/android/app/`

**iOS:**

- Bundle ID: `app.flowra.ios`
- Download `GoogleService-Info.plist` → `flowra-flutter/ios/Runner/`

**Web:**

- App nickname: `flowra-web`
- Copy the config snippet for later

### 3.3 Enable Cloud Messaging

Firebase Console → Cloud Messaging → Enable

For iOS push notifications:

1. Apple Developer → Certificates → Push Notification key (`.p8`)
2. Firebase Console → Project Settings → Cloud Messaging → iOS → Upload APNs key

### 3.4 Get service account key

Firebase Console → Project Settings → Service Accounts → Generate new private key

Save as `firebase-credentials.json` — this goes to Railway (see Part 2.3).

### 3.5 Web hosting (optional)

```bash
npm install -g firebase-tools
firebase login
firebase init hosting --project flowra-app

# firebase.json
{
  "hosting": {
    "public": "flowra-flutter/build/web",
    "ignore": ["firebase.json", "**/.*"],
    "rewrites": [{"source": "**", "destination": "/index.html"}],
    "headers": [{"source": "**/*.js", "headers": [{"key": "Cache-Control", "value": "max-age=31536000"}]}]
  }
}
```

---

## Part 4 — RevenueCat (Subscriptions)

### 4.1 Create RevenueCat project

1. [app.revenuecat.com](https://app.revenuecat.com) → New project → `flowra`
2. Add iOS app (Bundle ID: `app.flowra.ios`)
3. Add Android app (Package: `app.flowra.android`)

### 4.2 Create products in stores

**App Store Connect:**

- `flowra_growth_monthly` — $6.99/month — "Growth monthly"
- `flowra_growth_annual` — $59.00/year — "Growth annual"
- `flowra_pro_monthly` — $12.99/month — "Pro monthly"
- `flowra_pro_annual` — $99.00/year — "Pro annual"

**Google Play Console:**
Same product IDs and prices in Subscriptions section.

### 4.3 Configure entitlements in RevenueCat

RevenueCat → Entitlements:

- `growth` — attach Growth monthly + Growth annual products
- `pro` — attach Pro monthly + Pro annual products

### 4.4 Get API keys

RevenueCat → Project Settings → API Keys:

```
REVENUECAT_IOS_PUBLIC_KEY     = appl_xxxx
REVENUECAT_ANDROID_PUBLIC_KEY = goog_xxxx
```

Add to Flutter `.env` file.

### 4.5 Configure webhook

RevenueCat → Integrations → Webhooks → Add endpoint:

```
URL:    https://api.flowra.app/v1/subscriptions/webhook
Secret: (generate and add to Railway as REVENUECAT_WEBHOOK_SECRET)
```

---

## Part 5 — iOS App Store submission

### 5.1 Apple Developer account

1. enroll.developer.apple.com → Individual ($99/year)
2. Wait 24–48 hours for approval

### 5.2 App Store Connect setup

1. appstoreconnect.apple.com → Apps → New App
2. Bundle ID: `app.flowra.ios`
3. SKU: `flowra-ios-001`
4. Fill in:
   - App name: Flowra
   - Primary language: English
   - Category: Finance
   - Sub-category: Personal Finance

### 5.3 App metadata (prepare before submission)

**Screenshots required (all sizes):**

- iPhone 6.7" (1290×2796): Dashboard, Goals, Bills, Debt plan, Onboarding
- iPhone 6.5" (1242×2688): Same 5 screens
- iPad Pro 12.9" (2048×2732): Same 5 screens (if supporting iPad)

**App description (App Store):**

```
Flowra — Your money, flowing forward.

Track every dollar. Hit your savings goals. Pay off debt faster.

Flowra is the personal finance app that goes beyond tracking — it coaches you.

WHAT FLOWRA DOES:
• Automatically imports transactions from 10,000+ US banks via Plaid
• Categorizes every expense using AI — needs vs wants
• Tracks your monthly spending against a budget
• Helps you save toward named goals (emergency fund, car, house, travel)
• Tracks every bill and reminds you 3 days before it's due
• Builds you a personalized debt payoff plan (snowball or avalanche)
• Delivers monthly AI insights written in plain English

PRIVACY FIRST:
Flowra is read-only. It cannot move money or modify your accounts. Your banking
credentials never pass through Flowra — they stay with Plaid, the same
technology used by major US banks.

PLANS:
• Seed — Free forever. Manual entry, basic tracking.
• Growth — $6.99/month. Bank sync, AI insights, goals, bills.
• Pro — $12.99/month. Debt payoff plan, unlimited accounts, receipt OCR.

Start with a 7-day free trial of all Pro features. No card required.
```

**Keywords:** budget, spending tracker, expense tracker, savings goals, debt payoff, personal finance, money manager, bill tracker

**Privacy policy URL:** https://flowra.app/privacy

**Support URL:** https://flowra.app/support

### 5.4 Age rating

Content Descriptions → all "None" → Finance apps → 4+

### 5.5 Privacy nutrition labels

Data Used to Track You: None
Data Linked to You:

- Contact Info (email) — App functionality
- Financial Info (transactions) — App functionality

Data Not Linked to You:

- Usage Data (analytics) — Analytics

### 5.6 Build and upload

```bash
cd flowra-flutter

# Build
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://api.flowra.app

# Open Xcode and upload via Organizer
open ios/Runner.xcworkspace
# Product → Archive → Distribute App → App Store Connect → Upload
```

Or use CI pipeline (see `.github/workflows/flutter.yml`).

### 5.7 Submit for review

App Store Connect → Your app → Submit for Review

Review typically takes 1–3 business days.

**Common rejection reasons for finance apps:**

- Missing privacy policy link → Add to app settings screen
- Plaid credentials screen not explained → Add explanation text
- Subscription terms not clear → Ensure trial terms shown at upgrade prompt

---

## Part 6 — Google Play submission

### 6.1 Google Play Console

1. play.google.com/console → Create app
2. Package name: `app.flowra.android`
3. App category: Finance
4. One-time $25 registration fee

### 6.2 Store listing

Same description and screenshots as iOS. Additional requirements:

- Feature graphic: 1024×500 PNG
- Short description (80 chars): "AI-powered finance tracker. Goals, bills, debt payoff."
- Privacy policy URL: https://flowra.app/privacy

### 6.3 Data safety section

Play Console → Store presence → Data safety

Fill out accurately:

- Data collected: Name, email address, financial transactions
- Data shared: No data shared with third parties
- Security practices: Data encrypted in transit, users can request deletion

### 6.4 App signing

Play Console → Setup → App signing → Let Google manage signing key (recommended)

### 6.5 Build and upload

```bash
cd flowra-flutter

# Generate keystore (first time only)
keytool -genkey -v \
  -keystore android/app/flowra.jks \
  -alias flowra \
  -keyalg RSA -keysize 2048 -validity 10000

# Write key.properties
cat > android/key.properties << EOF
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=flowra
storeFile=flowra.jks
EOF

# Build AAB
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.flowra.app

# Output: build/app/outputs/bundle/release/app-release.aab
```

Upload to Play Console → Production → Releases → Create new release → Upload AAB.

### 6.6 Release tracks

Start with Internal testing (immediate, up to 100 testers) → Closed testing → Open testing → Production.

---

## Part 7 — GitHub Secrets

Add these to your GitHub repository (Settings → Secrets → Actions):

### Backend secrets

```
RAILWAY_TOKEN              Railway API token (railway.app → Account → Tokens)
```

### Flutter secrets

```
SUPABASE_URL               https://your-project.supabase.co
SUPABASE_ANON_KEY          eyJ...
API_BASE_URL               https://api.flowra.app

# Android signing
KEYSTORE_BASE64            base64 -i android/app/flowra.jks | pbcopy
KEYSTORE_STORE_PASSWORD    your-store-password
KEYSTORE_KEY_PASSWORD      your-key-password
GOOGLE_PLAY_SERVICE_ACCOUNT  (JSON from Play Console service account)

# iOS signing
IOS_CERT_BASE64            base64 of .p12 distribution certificate
IOS_CERT_PASSWORD          certificate password
APPSTORE_ISSUER_ID         from App Store Connect → Users → Keys
APPSTORE_KEY_ID            from App Store Connect → Users → Keys
APPSTORE_PRIVATE_KEY       .p8 key content from App Store Connect

# Firebase
FIREBASE_SERVICE_ACCOUNT   JSON from Firebase Console → Service Accounts
```

---

## Part 8 — Pre-launch checklist

### Security

- [ ] All `.env` files in `.gitignore` and NOT committed
- [ ] `firebase-credentials.json` in `.gitignore`
- [ ] `android/key.properties` in `.gitignore`
- [ ] `android/app/flowra.jks` in `.gitignore`
- [ ] Supabase RLS policies applied and verified
- [ ] `APP_ENV=production` in Railway
- [ ] Swagger docs disabled in production (`/docs` returns 404)
- [ ] HTTPS enforced (Railway handles this automatically)

### Legal (required before launch)

- [ ] Privacy policy live at `https://flowra.app/privacy`
- [ ] Terms of service live at `https://flowra.app/terms`
- [ ] Legal review completed by fintech-aware lawyer
- [ ] CCPA compliance verified (right to delete account works)
- [ ] Plaid production access approved

### Functionality

- [ ] Signup → onboarding → dashboard flow tested end-to-end
- [ ] Plaid bank connection tested with real sandbox bank
- [ ] Transaction auto-categorization working (Claude API live)
- [ ] Push notifications tested on real iOS and Android devices
- [ ] RevenueCat subscription flow tested (use sandbox environment)
- [ ] Monthly insight generation tested
- [ ] Savings goal creation and contribution working
- [ ] Bill tracker with notifications working
- [ ] Account deletion (GDPR) tested and confirmed cascade works

### Stores

- [ ] iOS screenshots uploaded (6.7", 6.5")
- [ ] Android screenshots uploaded (phone + tablet)
- [ ] App descriptions finalized
- [ ] Privacy nutrition labels (iOS) filled accurately
- [ ] Data safety section (Android) filled accurately
- [ ] Age rating set to 4+
- [ ] Support URL active
- [ ] Privacy policy URL active

### Monitoring

- [ ] Sentry DSN configured and receiving errors
- [ ] Railway health check passing
- [ ] PostHog receiving events from production app

---

## Post-launch — day one operations

```bash
# Check API health
curl https://api.flowra.app/health

# Monitor Railway logs (real-time)
railway logs --tail --service flowra-api

# Run database migration (if needed)
railway run --service flowra-api alembic upgrade head

# Check Supabase for auth issues
# Supabase Dashboard → Authentication → Users

# Check Sentry for errors
# sentry.io → flowra project → Issues

# Trigger manual Plaid sync (if needed)
curl -X POST https://api.flowra.app/v1/accounts/plaid/sync/{account_id} \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## Estimated first-week costs

| Service                  | Cost           |
| ------------------------ | -------------- |
| Railway Starter          | $5/month       |
| Supabase Free            | $0             |
| Firebase Spark           | $0             |
| Claude API (light usage) | ~$5            |
| Plaid Sandbox            | $0             |
| **Total**                | **~$10/month** |

Costs scale only when users connect real bank accounts (Plaid Production) and generate AI insights at volume.
