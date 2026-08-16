import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps Supabase / network failures to calm, user-facing copy.
/// Never surface raw [ClientException] / [SocketException] strings in the UI.
String friendlyAuthError(Object error) {
  if (error is AuthException) {
    return _fromAuthException(error);
  }
  return _fromNetworkOrUnknown(error);
}

String _fromAuthException(AuthException e) {
  final raw = '${e.message} ${e.statusCode ?? ''} ${e.runtimeType}'.toLowerCase();

  if (_looksLikeNetwork(raw) || _looksLikeNetwork(e.message)) {
    return _networkMessage;
  }

  final message = e.message.trim();
  if (message.isEmpty) {
    return 'Something went wrong. Please try again.';
  }

  // Common Auth API messages — keep specific when safe for the user.
  final lower = message.toLowerCase();
  if (lower.contains('invalid login credentials') ||
      lower.contains('invalid email or password')) {
    return 'Email or password is incorrect.';
  }
  if (lower.contains('user already registered') ||
      lower.contains('already been registered')) {
    return 'An account with this email already exists. Try signing in.';
  }
  if (lower.contains('email not confirmed')) {
    return 'Please confirm your email before signing in.';
  }
  if (lower.contains('password') && lower.contains('least')) {
    return message; // usually already clear
  }
  if (lower.contains('rate limit') || lower.contains('too many')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }

  // Avoid dumping nested exception dumps that Auth sometimes wraps.
  if (message.contains('ClientException') ||
      message.contains('SocketException') ||
      message.contains('Failed host lookup') ||
      message.length > 160) {
    return _networkMessage;
  }

  return message;
}

String _fromNetworkOrUnknown(Object error) {
  final text = error.toString().toLowerCase();
  if (error is SocketException ||
      error is HttpException ||
      _looksLikeNetwork(text)) {
    return _networkMessage;
  }
  return 'Something went wrong. Please try again.';
}

bool _looksLikeNetwork(String text) {
  return text.contains('socketexception') ||
      text.contains('clientexception') ||
      text.contains('failed host lookup') ||
      text.contains('nodename nor servname') ||
      text.contains('network is unreachable') ||
      text.contains('connection refused') ||
      text.contains('connection reset') ||
      text.contains('timed out') ||
      text.contains('timeout') ||
      text.contains('xmlhttprequest error') ||
      text.contains('failed to fetch');
}

const _networkMessage =
    'We couldn’t reach Flowra’s servers. Check your internet connection, '
    'or try again in a moment.';
