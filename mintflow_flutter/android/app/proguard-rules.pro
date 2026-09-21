# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Plaid Link
-keep class com.plaid.** { *; }
-dontwarn com.plaid.**

# RevenueCat / Play Billing
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**
-keep class com.android.billingclient.** { *; }

# Firebase + Play Services (FCM, Google Sign-In)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# flutter_secure_storage / JNI
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}
