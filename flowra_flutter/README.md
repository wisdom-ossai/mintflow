# Flowra — Flutter Frontend

> Your money, flowing forward.

Cross-platform Flutter app (iOS · Android · Web) for the Flowra personal finance platform.

---

## Project structure

```
lib/
├── core/
│   ├── theme/         app_theme.dart       — Flowra design system (colors, typography, theme)
│   ├── router/        app_router.dart      — GoRouter with auth guards + bottom nav shell
│   └── utils/         format.dart          — Currency, date, and debt formatting helpers
├── data/
│   ├── models/        models.dart          — All domain models (User, Transaction, Goal, Bill, Debt...)
│   └── datasources/   api_client.dart      — Dio HTTP client with auth interceptor + all API methods
└── presentation/
    └── screens/
        ├── dashboard/    dashboard_screen.dart
        ├── goals/        goals_screen.dart
        └── bills/        bills_screen.dart + debt_plan_screen.dart
```

---

## Prerequisites

- Flutter 3.x (`flutter --version`)
- Dart 3.3+
- Xcode 15+ (iOS builds)
- Android Studio / Android SDK 34+
- Node.js (for Firebase CLI)

---

## Setup

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Generate code (models, routes)

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Configure environment

Create a `.env` file in the project root:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

For compile-time API URL (recommended for production):

```bash
flutter run --dart-define=API_BASE_URL=https://api.flowra.app
```

### 4. Firebase setup

1. Create a Firebase project at console.firebase.google.com
2. Add iOS and Android apps
3. Download `google-services.json` → `android/app/`
4. Download `GoogleService-Info.plist` → `ios/Runner/`
5. Enable Cloud Messaging in the Firebase console

### 5. Fonts

Download and place in `assets/fonts/`:

- `Poppins-Regular.ttf`
- `Poppins-Italic.ttf`
- `DMSans-Light.ttf`
- `DMSans-Regular.ttf`
- `DMSans-Medium.ttf`

Get them from [Google Fonts](https://fonts.google.com/specimen/Poppins) and [DM Sans](https://fonts.google.com/specimen/DM+Sans).

---

## Running the app

```bash
# iOS simulator
flutter run -d ios

# Android emulator
flutter run -d android

# Web
flutter run -d chrome

# With specific API URL
flutter run --dart-define=API_BASE_URL=http://localhost:8000 -d ios
```

---

## Building for release

### Android (Play Store)

```bash
# Generate keystore (first time only)
keytool -genkey -v -keystore flowra.jks -alias flowra -keyalg RSA -keysize 2048 -validity 10000

# Build app bundle
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.flowra.app

# Output: build/app/outputs/bundle/release/app-release.aab
```

Configure signing in `android/app/build.gradle`:

```groovy
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
```

### iOS (App Store)

```bash
# Build IPA
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://api.flowra.app

# Open in Xcode for signing and upload
open ios/Runner.xcworkspace
```

Required in Xcode:

- Set Bundle ID: `app.flowra.ios`
- Set Team to your Apple Developer account
- Enable Push Notifications capability
- Enable Associated Domains: `applinks:flowra.app`

### Web (Vercel / Firebase Hosting)

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.flowra.app \
  --web-renderer canvaskit

# Deploy to Firebase
firebase deploy --only hosting
```

---

## RevenueCat setup

1. Create a RevenueCat project at app.revenuecat.com
2. Add iOS and Android apps
3. Create 3 products in each store matching:
   - `flowra_growth_monthly` — $6.99/month
   - `flowra_growth_annual` — $59/year
   - `flowra_pro_monthly` — $12.99/month
   - `flowra_pro_annual` — $99/year
4. Add API keys to `.env`:
   ```env
   REVENUECAT_IOS_KEY=appl_xxxx
   REVENUECAT_ANDROID_KEY=goog_xxxx
   ```

---

## Architecture notes

### State management

The app uses **flutter_bloc** (BLoC pattern). Each screen has a corresponding Cubit:

- `DashboardCubit` — loads summary, insight, upcoming bills
- `TransactionsCubit` — paginated transaction list with filters
- `GoalsCubit` — goals list + AI suggestions
- `BillsCubit` — bills + payments for current month
- `DebtCubit` — debt overview + plan generation

### Data flow

```
Screen → BLoC/Cubit → Repository → ApiClient → FastAPI backend
                    ↘ FlowraCache (shared_preferences) for offline support
```

### Local caching — why not Hive?

`hive_generator >=1.0.1` requires `build ^2.0.0` but `build_runner >=2.4.0`
requires `build ^4.0.0` — they are fundamentally incompatible and cannot be
resolved. Hive was removed and replaced with `shared_preferences` +
`FlowraCache` (a thin TTL wrapper in `lib/data/datasources/local_cache.dart`).

`shared_preferences` is maintained by the Flutter team, requires zero codegen,
and is more than sufficient for Flowra's caching needs (dashboard summaries,
goals, bills, user profile). Sensitive data (JWT token) stays in
`flutter_secure_storage` as before.

### Auth flow

1. User signs in via Supabase Auth (email or Google/Apple)
2. Supabase JWT stored in FlutterSecureStorage
3. ApiClient injects JWT on every request via `_AuthInterceptor`
4. GoRouter redirect checks `Supabase.instance.client.auth.currentSession`
5. On 401 response, token is cleared and user redirected to login

### Offline support

- Dashboard summary cached in Hive for 15 minutes
- Transaction list first page cached for immediate display
- Goals and bills cached for offline viewing
- Write operations (create transaction, mark bill paid) queued if offline

---

## Testing

```bash
# Unit tests
flutter test

# Integration tests (requires running device)
flutter test integration_test/

# Widget tests
flutter test test/widget/
```

---

## Design tokens

All design decisions are in `lib/core/theme/app_theme.dart`:

| Token               | Value            |
| ------------------- | ---------------- |
| Primary green       | `#2EAD6A`        |
| Dark green          | `#0A2E1C`        |
| Gold                | `#EDB93A`        |
| Cream               | `#FAFAF7`        |
| Heading font        | DM Serif Display |
| Body font           | DM Sans          |
| Card radius         | 16px             |
| Phone corner radius | 40px             |

---

## Deployment checklist

- [ ] `.env` configured with production Supabase keys
- [ ] Firebase `google-services.json` and `GoogleService-Info.plist` in place
- [ ] Fonts in `assets/fonts/`
- [ ] `dart run build_runner build` completed
- [ ] Android keystore configured in `key.properties`
- [ ] iOS bundle ID set to `app.flowra.ios`
- [ ] Push Notifications capability enabled in Xcode
- [ ] RevenueCat products created and keys configured
- [ ] `API_BASE_URL` set to production Railway URL
- [ ] Privacy Policy URL set in app settings screens
