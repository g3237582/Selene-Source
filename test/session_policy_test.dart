import 'package:flutter_test/flutter_test.dart';
import 'package:selene/services/session_policy.dart';

void main() {
  group('startup restore', () {
    test('keep-login + cookies enters home without waiting for the network', () {
      expect(
        SessionPolicy.shouldEnterHomeWithoutNetwork(
          keepLoggedIn: true,
          hasCookies: true,
        ),
        isTrue,
      );
    });

    test('does not skip login when keep-login is off', () {
      expect(
        SessionPolicy.shouldEnterHomeWithoutNetwork(
          keepLoggedIn: false,
          hasCookies: true,
        ),
        isFalse,
      );
    });

    test('does not skip login when cookies are missing', () {
      expect(
        SessionPolicy.shouldEnterHomeWithoutNetwork(
          keepLoggedIn: true,
          hasCookies: false,
        ),
        isFalse,
      );
    });

    test('keep-login + credentials + no cookies tries auto login', () {
      expect(
        SessionPolicy.shouldAttemptAutoLogin(
          keepLoggedIn: true,
          hasCredentials: true,
          hasCookies: false,
        ),
        isTrue,
      );
    });

    test('does not auto login when keep-login is off', () {
      expect(
        SessionPolicy.shouldAttemptAutoLogin(
          keepLoggedIn: false,
          hasCredentials: true,
          hasCookies: true,
        ),
        isFalse,
      );
    });

    test('skips auto login when cookies already exist', () {
      expect(
        SessionPolicy.shouldAttemptAutoLogin(
          keepLoggedIn: true,
          hasCredentials: true,
          hasCookies: true,
        ),
        isFalse,
      );
    });
  });

  group('401 recovery', () {
    test('refreshes the session when keep-login and credentials exist', () {
      expect(
        SessionPolicy.shouldRefreshOnUnauthorized(
          keepLoggedIn: true,
          hasCredentials: true,
        ),
        isTrue,
      );
    });

    test('does not refresh when keep-login is off', () {
      expect(
        SessionPolicy.shouldRefreshOnUnauthorized(
          keepLoggedIn: false,
          hasCredentials: true,
        ),
        isFalse,
      );
    });

    test('does not refresh when there is no password to re-login', () {
      expect(
        SessionPolicy.shouldRefreshOnUnauthorized(
          keepLoggedIn: true,
          hasCredentials: false,
        ),
        isFalse,
      );
    });

    test('retries the request after a successful refresh', () {
      expect(
        SessionPolicy.decideAfterRefresh(SessionRefreshOutcome.success),
        SessionRecoveryAction.retryAfterRefresh,
      );
    });

    test('keeps the session on transient network or server errors', () {
      expect(
        SessionPolicy.decideAfterRefresh(SessionRefreshOutcome.networkError),
        SessionRecoveryAction.keepSession,
      );
      expect(
        SessionPolicy.decideAfterRefresh(SessionRefreshOutcome.serverError),
        SessionRecoveryAction.keepSession,
      );
    });

    test('logs out only when the server rejects the credentials', () {
      expect(
        SessionPolicy.decideAfterRefresh(SessionRefreshOutcome.rejected),
        SessionRecoveryAction.logout,
      );
    });

    test('logs out when refresh is not possible', () {
      expect(
        SessionPolicy.decideWithoutRefresh(keepLoggedIn: false),
        SessionRecoveryAction.logout,
      );
      expect(
        SessionPolicy.decideWithoutRefresh(keepLoggedIn: true),
        SessionRecoveryAction.logout,
      );
    });
  });
}
