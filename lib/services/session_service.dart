import 'dart:convert';

import 'package:http/http.dart' as http;

import 'session_policy.dart';
import 'user_data_service.dart';

enum SessionRecoveryResult {
  refreshed,
  transientFailure,
  loggedOut,
}

/// Owns cookie refresh and 401 recovery on top of [UserDataService].
class SessionService {
  static const Duration _timeout = Duration(seconds: 30);
  static Future<SessionRecoveryResult>? _inFlightRecovery;

  static void resetForTest() {
    _inFlightRecovery = null;
  }

  static Future<bool> canRestoreSession() async {
    return SessionPolicy.shouldEnterHomeWithoutNetwork(
      keepLoggedIn: await UserDataService.getKeepLoggedIn(),
      hasCookies: await UserDataService.isLoggedIn(),
    );
  }

  static Future<bool> shouldAttemptAutoLogin() async {
    return SessionPolicy.shouldAttemptAutoLogin(
      keepLoggedIn: await UserDataService.getKeepLoggedIn(),
      hasCredentials: await UserDataService.hasAutoLoginData(),
      hasCookies: await UserDataService.isLoggedIn(),
    );
  }

  /// Re-login with the stored password and replace cookies on success.
  static Future<SessionRefreshOutcome> refreshSession() async {
    try {
      final serverUrl = await UserDataService.getServerUrl();
      final username = await UserDataService.getUsername();
      final password = await UserDataService.getPassword();
      if (serverUrl == null ||
          serverUrl.isEmpty ||
          username == null ||
          username.isEmpty ||
          password == null ||
          password.isEmpty) {
        return SessionRefreshOutcome.rejected;
      }

      String baseUrl = serverUrl.trim();
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/login'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final cookies = parseSetCookieHeader(response.headers['set-cookie']);
        await UserDataService.saveUserData(
          serverUrl: baseUrl,
          username: username,
          password: password,
          cookies: cookies,
        );
        return SessionRefreshOutcome.success;
      }

      if (response.statusCode == 401) {
        return SessionRefreshOutcome.rejected;
      }

      return SessionRefreshOutcome.serverError;
    } catch (_) {
      return SessionRefreshOutcome.networkError;
    }
  }

  /// Shared by every authenticated request that receives 401.
  ///
  /// Concurrent 401s reuse one in-flight refresh so a brief outage cannot
  /// stampede `/api/login` or race cookie writes.
  static Future<SessionRecoveryResult> recoverFromUnauthorized({
    Future<SessionRefreshOutcome> Function()? refresh,
  }) {
    final inFlight = _inFlightRecovery;
    if (inFlight != null) {
      return inFlight;
    }

    late final Future<SessionRecoveryResult> future;
    future = _recoverFromUnauthorized(refresh: refresh).whenComplete(() {
      if (identical(_inFlightRecovery, future)) {
        _inFlightRecovery = null;
      }
    });
    _inFlightRecovery = future;
    return future;
  }

  static Future<SessionRecoveryResult> _recoverFromUnauthorized({
    Future<SessionRefreshOutcome> Function()? refresh,
  }) async {
    final keepLoggedIn = await UserDataService.getKeepLoggedIn();
    final hasCredentials = await UserDataService.hasAutoLoginData();

    if (!SessionPolicy.shouldRefreshOnUnauthorized(
      keepLoggedIn: keepLoggedIn,
      hasCredentials: hasCredentials,
    )) {
      await UserDataService.clearPasswordAndCookies();
      return SessionRecoveryResult.loggedOut;
    }

    final outcome = await (refresh ?? refreshSession)();
    switch (SessionPolicy.decideAfterRefresh(outcome)) {
      case SessionRecoveryAction.retryAfterRefresh:
        return SessionRecoveryResult.refreshed;
      case SessionRecoveryAction.keepSession:
        return SessionRecoveryResult.transientFailure;
      case SessionRecoveryAction.logout:
        await UserDataService.clearPasswordAndCookies();
        return SessionRecoveryResult.loggedOut;
    }
  }

  /// Same cookie parsing the login screen already uses.
  static String parseSetCookieHeader(String? setCookieHeaders) {
    if (setCookieHeaders == null || setCookieHeaders.isEmpty) {
      return '';
    }
    final cookieParts = setCookieHeaders.split(';');
    if (cookieParts.isEmpty) {
      return '';
    }
    return cookieParts[0].trim();
  }
}
