import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

bool get isAppleSignInPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

class AppleAuthPayload {
  const AppleAuthPayload({
    required this.identityToken,
    this.email,
    this.fullName,
  });

  final String identityToken;
  final String? email;
  final String? fullName;
}

Future<String> googleIdToken() async {
  final serverClientId = (dotenv.env['GOOGLE_CLIENT_ID'] ?? '').trim();
  final iosClientId = (dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '').trim();
  final googleSignIn = GoogleSignIn(
    clientId: iosClientId.isEmpty ? null : iosClientId,
    serverClientId: serverClientId.isEmpty ? null : serverClientId,
    scopes: const ['email', 'profile'],
  );
  final googleUser = await googleSignIn.signIn();
  if (googleUser == null) {
    throw const GoogleSignInCanceled();
  }
  final auth = await googleUser.authentication;
  final idToken = auth.idToken;
  if (idToken == null || idToken.isEmpty) {
    throw Exception(
      'Google Sign-In did not return an ID token. '
      'Set GOOGLE_CLIENT_ID to the Web OAuth client ID in .env.',
    );
  }
  return idToken;
}

Future<AppleAuthPayload> appleIdentity() async {
  final available = await SignInWithApple.isAvailable();
  if (!available) {
    throw Exception('Sign in with Apple is not available on this device.');
  }
  final credential = await SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
  );
  final token = credential.identityToken;
  if (token == null || token.isEmpty) {
    throw Exception('Apple did not return an identity token.');
  }
  final parts = <String>[
    if ((credential.givenName ?? '').trim().isNotEmpty)
      credential.givenName!.trim(),
    if ((credential.familyName ?? '').trim().isNotEmpty)
      credential.familyName!.trim(),
  ];
  return AppleAuthPayload(
    identityToken: token,
    email: credential.email,
    fullName: parts.isEmpty ? null : parts.join(' '),
  );
}

class GoogleSignInCanceled implements Exception {
  const GoogleSignInCanceled();
}
