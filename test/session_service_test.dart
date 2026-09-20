import 'package:flutter_test/flutter_test.dart';
import 'package:selene/services/session_policy.dart';
import 'package:selene/services/session_service.dart';
import 'package:selene/services/user_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SessionService.resetForTest();
  });

  Future<void> seedSession({
    bool keepLoggedIn = true,
    bool withCookies = true,
    bool withPassword = true,
  }) async {
    await UserDataService.saveKeepLoggedIn(keepLoggedIn);
    await UserDataService.saveUserData(
      serverUrl: 'https://example.com',
      username: 'alice',
      password: withPassword ? 'secret' : '',
      cookies: withCookies ? 'auth=token' : '',
    );
    if (!withPassword) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('password');
    }
    if (!withCookies) {
      await UserDataService.clearCookies();
    }
  }

  test('keep-login defaults to on for existing installs', () async {
    expect(await UserDataService.getKeepLoggedIn(), isTrue);
  });

  test('persists the keep-login toggle', () async {
    await UserDataService.saveKeepLoggedIn(false);
    expect(await UserDataService.getKeepLoggedIn(), isFalse);
    await UserDataService.saveKeepLoggedIn(true);
    expect(await UserDataService.getKeepLoggedIn(), isTrue);
  });

  test('clearCookies keeps username, password, and server url', () async {
    await seedSession();
    await UserDataService.clearCookies();

    expect(await UserDataService.getCookies(), isNull);
    expect(await UserDataService.getServerUrl(), 'https://example.com');
    expect(await UserDataService.getUsername(), 'alice');
    expect(await UserDataService.getPassword(), 'secret');
  });

  test('manual logout still clears password and cookies only', () async {
    await seedSession();
    await UserDataService.clearPasswordAndCookies();

    expect(await UserDataService.getCookies(), isNull);
    expect(await UserDataService.getPassword(), isNull);
    expect(await UserDataService.getServerUrl(), 'https://example.com');
    expect(await UserDataService.getUsername(), 'alice');
  });

  test('can restore a session across restarts when keep-login is on', () async {
    await seedSession();
    expect(await SessionService.canRestoreSession(), isTrue);
  });

  test('does not restore a session when keep-login is off', () async {
    await seedSession(keepLoggedIn: false);
    expect(await SessionService.canRestoreSession(), isFalse);
  });

  test('401 with keep-login retries after a successful refresh', () async {
    await seedSession();
    var refreshCalls = 0;

    final result = await SessionService.recoverFromUnauthorized(
      refresh: () async {
        refreshCalls += 1;
        return SessionRefreshOutcome.success;
      },
    );

    expect(result, SessionRecoveryResult.refreshed);
    expect(refreshCalls, 1);
    expect(await UserDataService.getCookies(), 'auth=token');
    expect(await UserDataService.getPassword(), 'secret');
  });

  test('401 with a network error does not wipe the session', () async {
    await seedSession();

    final result = await SessionService.recoverFromUnauthorized(
      refresh: () async => SessionRefreshOutcome.networkError,
    );

    expect(result, SessionRecoveryResult.transientFailure);
    expect(await UserDataService.getCookies(), 'auth=token');
    expect(await UserDataService.getPassword(), 'secret');
    expect(await UserDataService.getServerUrl(), 'https://example.com');
  });

  test('401 with rejected credentials clears password and cookies only', () async {
    await seedSession();

    final result = await SessionService.recoverFromUnauthorized(
      refresh: () async => SessionRefreshOutcome.rejected,
    );

    expect(result, SessionRecoveryResult.loggedOut);
    expect(await UserDataService.getCookies(), isNull);
    expect(await UserDataService.getPassword(), isNull);
    expect(await UserDataService.getServerUrl(), 'https://example.com');
    expect(await UserDataService.getUsername(), 'alice');
  });

  test('401 with keep-login off logs out without refreshing', () async {
    await seedSession(keepLoggedIn: false);
    var refreshCalls = 0;

    final result = await SessionService.recoverFromUnauthorized(
      refresh: () async {
        refreshCalls += 1;
        return SessionRefreshOutcome.success;
      },
    );

    expect(result, SessionRecoveryResult.loggedOut);
    expect(refreshCalls, 0);
    expect(await UserDataService.getCookies(), isNull);
    expect(await UserDataService.getPassword(), isNull);
  });

  test('concurrent 401s share one in-flight refresh', () async {
    await seedSession();
    var refreshCalls = 0;

    Future<SessionRefreshOutcome> refresh() async {
      refreshCalls += 1;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return SessionRefreshOutcome.success;
    }

    final results = await Future.wait([
      SessionService.recoverFromUnauthorized(refresh: refresh),
      SessionService.recoverFromUnauthorized(refresh: refresh),
    ]);

    expect(results, [
      SessionRecoveryResult.refreshed,
      SessionRecoveryResult.refreshed,
    ]);
    expect(refreshCalls, 1);
  });
}
