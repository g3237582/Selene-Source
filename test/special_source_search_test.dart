import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:selene/search/search_history_plan.dart';
import 'package:selene/search/special_search_history_store.dart';
import 'package:selene/search/special_source_access.dart';
import 'package:selene/search/special_source_client.dart';
import 'package:selene/search/video_search_request.dart';
import 'package:selene/search/video_search_session.dart';
import 'package:selene/search/video_source_mode.dart';
import 'package:selene/services/local_mode_storage_service.dart';
import 'package:selene/services/page_cache_service.dart';
import 'package:selene/services/sse_search_service.dart';
import 'package:selene/services/user_data_service.dart';
import 'package:selene/widgets/video_source_mode_switch.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _token = '%7B%22role%22%3A%22user%22%2C%22username%22%3A%22alice%22%7D';

http.Response _json(Object body, [int status = 200]) {
  return http.Response.bytes(
    utf8.encode(body is String ? body : json.encode(body)),
    status,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PageCacheService().clearAllCache();
    await UserDataService.saveIsLocalMode(false);
  });

  group('request building', () {
    test('normal video search omits special and keeps the bearer token verbatim', () {
      final request = VideoSearchRequest.get(
        baseUrl: 'https://relay.example',
        path: VideoSearchRequest.searchPath,
        query: '繁花',
        special: false,
        token: _token,
      );

      expect(request.uri.path, '/api/search');
      expect(request.uri.queryParameters['q'], '繁花');
      expect(request.uri.queryParameters.containsKey('special'), isFalse);
      expect(request.headers['Authorization'], 'Bearer $_token');
      expect(request.headers['Authorization'], isNot(contains('{')));
    });

    test('special=1 is added to search, websocket, suggestions and resources', () {
      for (final path in [
        VideoSearchRequest.searchPath,
        VideoSearchRequest.wsPath,
        VideoSearchRequest.suggestionsPath,
        VideoSearchRequest.resourcesPath,
      ]) {
        final request = VideoSearchRequest.get(
          baseUrl: 'https://relay.example/ignored',
          path: path,
          query: path == VideoSearchRequest.resourcesPath ? null : '繁花',
          special: true,
          token: _token,
          cookie: 'auth=$_token',
        );
        expect(request.uri.path, path, reason: path);
        expect(request.uri.queryParameters['special'], '1', reason: path);
        if (path != VideoSearchRequest.resourcesPath) {
          expect(request.uri.queryParameters['q'], '繁花', reason: path);
        }
        expect(request.headers['Authorization'], 'Bearer $_token');
        expect(request.headers['Cookie'], 'auth=$_token');
      }
    });

    test('capability probe does not send special=1', () {
      final request = VideoSearchRequest.get(
        baseUrl: 'https://relay.example',
        path: VideoSearchRequest.capabilityPath,
        special: false,
        token: _token,
      );
      expect(request.uri.path, '/api/search/special-capability');
      expect(request.uri.queryParameters.containsKey('special'), isFalse);
      expect(request.headers['Authorization'], 'Bearer $_token');
    });

    test('login token is stored exactly as returned and cookie fallback does not decode it', () {
      final body = json.decode(json.encode({'ok': true, 'token': _token}));
      expect(VideoSearchRequest.readLoginToken(body), _token);

      expect(VideoSearchRequest.tokenFromAuthCookie('auth=$_token; theme=dark'), _token);
      expect(
        VideoSearchRequest.bearerToken(storedToken: _token, cookie: 'auth=other'),
        _token,
      );
      expect(
        VideoSearchRequest.bearerToken(storedToken: null, cookie: 'auth=$_token'),
        _token,
      );
    });

    test('special websocket search sends special=1 and the raw bearer token', () async {
      SharedPreferences.setMockInitialValues({
        'server_url': 'https://relay.example',
        'cookies': 'auth=$_token',
        'auth_token': _token,
      });
      http.BaseRequest? captured;
      final service = SSESearchService(
        clientFactory: () => MockClient((request) async {
          captured = request;
          return http.Response('', 200, headers: {
            'content-type': 'text/event-stream',
          });
        }),
      );

      await service.startSearch('繁花', special: true);
      expect(captured, isNotNull);
      expect(captured!.url.path, '/api/search/ws');
      expect(captured!.url.queryParameters['q'], '繁花');
      expect(captured!.url.queryParameters['special'], '1');
      expect(captured!.headers['Authorization'], 'Bearer $_token');
      await service.stopSearch();
    });

    test('normal websocket search does not send special', () async {
      SharedPreferences.setMockInitialValues({
        'server_url': 'https://relay.example',
        'cookies': 'auth=$_token',
        'auth_token': _token,
      });
      http.BaseRequest? captured;
      final service = SSESearchService(
        clientFactory: () => MockClient((request) async {
          captured = request;
          return http.Response('', 200, headers: {
            'content-type': 'text/event-stream',
          });
        }),
      );

      await service.startSearch('繁花');
      expect(captured!.url.queryParameters.containsKey('special'), isFalse);
      await service.stopSearch();
    });
  });

  group('capability gating', () {
    test('shows the toggle only when available is true and defaults to normal', () async {
      final available = await _loadCapability(
        status: 200,
        body: {'available': true, 'count': 53},
      );
      final mode = VideoSearchModeState()..applyCapability(available);
      expect(mode.toggleVisible, isTrue);
      expect(mode.special, isFalse);
      expect(available.count, 53);

      final hidden = await _loadCapability(
        status: 200,
        body: {'available': false, 'count': 0},
      );
      mode
        ..special = true
        ..applyCapability(hidden);
      expect(mode.toggleVisible, isFalse);
      expect(mode.special, isFalse);
    });

    test('a count without available does not show the toggle', () {
      final mode = VideoSearchModeState()
        ..applyCapability(
          const SpecialSourceCapability(available: false, count: 53),
        );
      expect(mode.toggleVisible, isFalse);
    });

    test('401 and transport failure hide the toggle', () async {
      final unauthorized = await _loadCapability(
        status: 401,
        body: {'error': 'Unauthorized'},
      );
      expect(unauthorized.available, isFalse);

      SharedPreferences.setMockInitialValues({
        'server_url': 'https://relay.example',
        'auth_token': _token,
      });
      final failed = await SpecialSourceGateway(
        httpClient: MockClient((request) async {
          throw http.ClientException('offline');
        }),
      ).load();
      expect(failed.available, isFalse);
    });

    test('login or server change hides the toggle until capability is checked again', () {
      final mode = VideoSearchModeState()
        ..applyCapability(
          const SpecialSourceCapability(available: true, count: 53),
        );
      mode.special = true;
      expect(
        const VideoSearchSession(
          serverUrl: 'https://relay.example',
          username: 'alice',
          localMode: false,
        ).differsFrom(
          const VideoSearchSession(
            serverUrl: 'https://guanlingqian.com',
            username: 'alice',
            localMode: false,
          ),
        ),
        isTrue,
      );

      mode.onSessionChanged();
      expect(mode.toggleVisible, isFalse);
      expect(mode.special, isFalse);
    });

    test('local mode never exposes special sources', () async {
      SharedPreferences.setMockInitialValues({
        'server_url': 'https://relay.example',
        'auth_token': _token,
        'is_local_mode': true,
      });
      await UserDataService.saveIsLocalMode(true);
      var called = false;
      final capability = await SpecialSourceGateway(
        httpClient: MockClient((request) async {
          called = true;
          return _json({'available': true, 'count': 53});
        }),
      ).load();
      expect(called, isFalse);
      expect(capability.available, isFalse);
    });
  });

  group('403 handling', () {
    test('special_source_forbidden does not open SSE and falls back to normal', () async {
      const body = '{"error":"无权使用特殊源","code":"special_source_forbidden"}';
      expect(SpecialSourceAccess.isForbiddenBody(403, body), isTrue);
      expect(SpecialSourceAccess.opensEventStream(403, body), isFalse);
      expect(SpecialSourceAccess.isForbiddenBody(403, '{"error":"nope"}'), isFalse);
      expect(SpecialSourceAccess.opensEventStream(200, 'data: {"type":"start"}'), isTrue);

      SharedPreferences.setMockInitialValues({
        'server_url': 'https://guanlingqian.com',
        'cookies': 'auth=$_token',
        'auth_token': _token,
      });
      final service = SSESearchService(
        clientFactory: () => MockClient((request) async {
          expect(request.url.queryParameters['special'], '1');
          return _json(
            {'error': '无权使用特殊源', 'code': 'special_source_forbidden'},
            403,
          );
        }),
      );

      await expectLater(
        service.startSearch('繁花', special: true),
        throwsA(isA<SpecialSourceForbiddenException>()),
      );
      expect(service.isConnected, isFalse);

      final mode = VideoSearchModeState()
        ..applyCapability(
          const SpecialSourceCapability(available: true, count: 1),
        );
      mode.special = true;
      final rerun = mode.onSpecialForbidden();
      expect(rerun, isTrue);
      expect(mode.special, isFalse);
      expect(mode.toggleVisible, isFalse);
      expect(mode.notice, '无权使用特殊源');
      await service.stopSearch();
    });
  });

  group('history separation', () {
    test('special history post is marked and is not applied to normal history', () {
      final special = SearchHistoryPlan.forMode(keyword: '繁花', special: true);
      final normal = SearchHistoryPlan.forMode(keyword: '繁花', special: false);

      expect(special.body, {'keyword': '繁花', 'special': true});
      expect(normal.body.containsKey('special'), isFalse);
      expect(special.cacheKey, isNot(normal.cacheKey));
      expect(normal.cacheKey, 'search_history');
      expect(special.applyServerResponseToThisList, isFalse);
      expect(special.includeInRecommendations, isFalse);
      expect(special.mutatesServerHistory, isFalse);
      expect(normal.includeInRecommendations, isTrue);
      expect(
        RecommendationSourcePolicy.cacheForRecommendations(special: true),
        isFalse,
      );
    });

    test('local special history stays out of normal history', () async {
      SharedPreferences.setMockInitialValues({});
      await LocalModeStorageService.addSearchHistory('普通词');
      await SpecialSearchHistoryStore.add('特殊词');

      expect(await LocalModeStorageService.getSearchHistory(), ['普通词']);
      expect(await SpecialSearchHistoryStore.read(), ['特殊词']);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('local_mode_search_history'), isNot(contains('特殊词')));
      expect(prefs.getString(SpecialSearchHistoryStore.prefsKey), contains('特殊词'));
      expect(
        prefs.getString(SpecialSearchHistoryStore.prefsKey),
        isNot(contains('普通词')),
      );
    });

    testWidgets('page cache keeps special keywords out of normal history', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await UserDataService.saveIsLocalMode(true);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));
      final cache = PageCacheService();
      cache.clearAllCache();

      await cache.addSearchHistory('普通', context);
      await cache.addSearchHistory('特殊', context, special: true);

      final normal = await cache.getSearchHistory(context);
      final special = await cache.getSearchHistory(context, special: true);
      expect(normal.data, ['普通']);
      expect(special.data, ['特殊']);
      expect(cache.getCache<List<String>>('search_history'), isNot(contains('特殊')));

      await cache.deleteSearchHistory('特殊', context, special: true);
      expect((await cache.getSearchHistory(context, special: true)).data, isEmpty);
      expect((await cache.getSearchHistory(context)).data, ['普通']);

      await cache.clearSearchHistory(context, special: true);
      expect((await cache.getSearchHistory(context)).data, ['普通']);
    });
  });

  testWidgets('source switch exposes 普通源 and 特殊源', (tester) async {
    bool? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoSourceModeSwitch(
            special: false,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('普通源'), findsOneWidget);
    expect(find.text('特殊源'), findsOneWidget);
    await tester.tap(find.text('特殊源'));
    expect(selected, isTrue);
    await tester.tap(find.text('普通源'));
    expect(selected, isFalse);
  });
}

Future<SpecialSourceCapability> _loadCapability({
  required int status,
  required Object body,
}) async {
  SharedPreferences.setMockInitialValues({
    'server_url': 'https://relay.example',
    'username': 'alice',
    'auth_token': _token,
    'cookies': 'auth=$_token',
  });
  return SpecialSourceGateway(
    httpClient: MockClient((request) async {
      expect(request.url.path, '/api/search/special-capability');
      expect(request.headers['Authorization'], 'Bearer $_token');
      expect(request.url.queryParameters.containsKey('special'), isFalse);
      return _json(body, status);
    }),
  ).load();
}
