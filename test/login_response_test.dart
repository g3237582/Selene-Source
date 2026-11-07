import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:selene/search/video_search_request.dart';
import 'package:selene/services/login_response.dart';
import 'package:selene/services/session_policy.dart';
import 'package:selene/services/session_service.dart';
import 'package:selene/services/user_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single percent-encoded JSON. This is the Bearer token and must stay encoded.
const _token = '%7B%22role%22%3A%22user%22%2C%22username%22%3A%22alice%22%7D';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SessionService.resetForTest();
  });

  test('auth_luna is a bearer fallback and is not decoded', () {
    final cookieValue = Uri.encodeComponent(_token);
    expect(cookieValue, isNot(_token));
    expect(cookieValue, contains('%25'));

    expect(
      VideoSearchRequest.tokenFromAuthCookie('auth_luna=$cookieValue; theme=dark'),
      cookieValue,
    );
    expect(
      VideoSearchRequest.tokenFromAuthCookie('auth=$_token'),
      _token,
    );
    expect(
      VideoSearchRequest.bearerToken(
        storedToken: _token,
        cookie: 'auth_luna=$cookieValue',
      ),
      _token,
    );
    expect(
      VideoSearchRequest.tokenFromAuthCookie('auth_luna=$cookieValue'),
      isNot(contains('{')),
    );
  });

  test('LunaTV 200 with ok, percent-encoded token and auth_luna enters home', () {
    final cookieValue = Uri.encodeComponent(_token);
    final body = json.encode({
      'ok': true,
      'token': _token,
      'auth': {
        'role': 'user',
        'username': 'alice',
        'timestamp': 1761300000000,
        'tokenId': 'tid',
        'refreshToken': 'rt',
        'refreshExpires': 1766400000000,
        'signature': 'ab' * 32,
      },
    });
    final setCookie =
        'auth_luna=$cookieValue; Path=/; Expires=Sat, 24 Dec 2026 12:39:26 GMT; SameSite=lax';

    final result = LoginResponse.interpret(
      statusCode: 200,
      readBody: () => body,
      readSetCookie: () => setCookie,
    );

    expect(result.enterHome, isTrue);
    expect(result.token, _token);
    expect(result.token, isNot(contains('{')));
    expect(result.cookies, 'auth_luna=$cookieValue');
    expect(result.cookies, isNot(contains('Path=')));
    expect(result.cookies, isNot(contains('Expires=')));
  });

  test('a throwing Set-Cookie read does not block a valid body token', () {
    final result = LoginResponse.interpret(
      statusCode: 200,
      readBody: () => json.encode({'ok': true, 'token': _token}),
      readSetCookie: () => throw StateError('set-cookie blew up'),
    );

    expect(result.enterHome, isTrue);
    expect(result.token, _token);
    expect(result.cookies, isEmpty);
  });

  test('cookie text that Cookie.fromSetCookieValue rejects still yields the body token', () {
    const rawCookie = 'auth_luna={"role":"user"}; Path=/; SameSite=lax';
    expect(
      () => Cookie.fromSetCookieValue(rawCookie),
      throwsFormatException,
    );

    final result = LoginResponse.parse(
      statusCode: 200,
      body: json.encode({'ok': true, 'token': _token}),
      setCookieHeader: rawCookie,
    );

    expect(result.enterHome, isTrue);
    expect(result.token, _token);
  });

  test('explicit ok false stays on the login screen', () {
    final result = LoginResponse.parse(
      statusCode: 200,
      body: json.encode({'ok': false, 'error': '用户名或密码错误'}),
      setCookieHeader: null,
    );

    expect(result.enterHome, isFalse);
    expect(result.message, '用户名或密码错误');
    expect(result.token, isEmpty);
  });

  test('a stored bearer token counts as logged in when Set-Cookie was empty', () async {
    await UserDataService.saveUserData(
      serverUrl: 'https://relay.example',
      username: 'alice',
      password: 'secret',
      cookies: '',
      authToken: _token,
    );

    expect(await UserDataService.getAuthToken(), _token);
    expect(await UserDataService.isLoggedIn(), isTrue);
    expect(await UserDataService.getAuthToken(), isNot(contains('{')));
  });

  test('refreshSession stores the LunaTV token verbatim', () async {
    final cookieValue = Uri.encodeComponent(_token);
    await UserDataService.saveUserData(
      serverUrl: 'https://relay.example',
      username: 'alice',
      password: 'secret',
      cookies: '',
    );

    http.BaseRequest? captured;
    final outcome = await http.runWithClient(
      () => SessionService.refreshSession(),
      () => MockClient((request) async {
        captured = request;
        return http.Response(
          json.encode({
            'ok': true,
            'token': _token,
            'auth': {'role': 'user', 'username': 'alice'},
          }),
          200,
          headers: {
            'content-type': 'application/json',
            'set-cookie':
                'auth_luna=$cookieValue; Path=/; Expires=Sat, 24 Dec 2026 12:39:26 GMT; SameSite=lax',
          },
        );
      }),
    );

    expect(outcome, SessionRefreshOutcome.success);
    expect(captured?.url.path, '/api/login');
    expect(await UserDataService.getAuthToken(), _token);
    expect(await UserDataService.getAuthToken(), isNot(contains('{')));
    expect(await UserDataService.getCookies(), 'auth_luna=$cookieValue');
  });
}
