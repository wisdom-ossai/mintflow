import 'dart:io';

import 'package:dio/dio.dart';

/// Maps Dio / network failures to calm, user-facing copy.
/// Never surface raw [SocketException] / Dio dump strings in the UI.
String friendlyAuthError(Object error) {
  if (error is DioException) {
    return _fromDio(error);
  }
  return _fromNetworkOrUnknown(error);
}

String _fromDio(DioException e) {
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError) {
    return _networkMessage;
  }

  final status = e.response?.statusCode;
  final detail = _extractDetail(e.response?.data);

  if (status == 401) {
    if (detail != null && detail.toLowerCase().contains('password')) {
      return 'Email or password is incorrect.';
    }
    return 'Email or password is incorrect.';
  }
  if (status == 409) {
    return 'An account with this email already exists. Try signing in.';
  }
  if (status == 400) {
    if (detail != null && detail.isNotEmpty && detail.length <= 160) {
      return detail;
    }
    return 'Please check your details and try again.';
  }
  if (status == 422) {
    if (detail != null && detail.isNotEmpty && detail.length <= 160) {
      return detail;
    }
    return 'Please check your details and try again.';
  }
  if (status == 429) {
    return 'Too many attempts. Please wait a moment and try again.';
  }
  if (status != null && status >= 500) {
    return 'Something went wrong on our side. Please try again shortly.';
  }

  if (detail != null &&
      detail.isNotEmpty &&
      detail.length <= 160 &&
      !_looksLikeNetwork(detail.toLowerCase())) {
    return detail;
  }

  return _fromNetworkOrUnknown(e);
}

String? _extractDetail(dynamic data) {
  if (data == null) return null;
  if (data is String) return data.trim();
  if (data is Map) {
    final detail = data['detail'];
    if (detail is String) return detail.trim();
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] != null) {
        return first['msg'].toString();
      }
      return first.toString();
    }
    final message = data['message'];
    if (message is String) return message.trim();
  }
  return null;
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
    'We couldn’t reach Mintflow’s servers. Check your internet connection, '
    'or try again in a moment.';
