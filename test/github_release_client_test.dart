import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:selene/update/app_version.dart';
import 'package:selene/update/github_release.dart';
import 'package:selene/update/github_release_client.dart';
import 'package:selene/services/version_service.dart';

http.Response _jsonResponse(Object body, [int status = 200]) {
  return http.Response.bytes(
    utf8.encode(body is String ? body : json.encode(body)),
    status,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

Map<String, dynamic> _releaseJson({
  String tag = 'v1.6.12',
  bool draft = false,
  bool prerelease = false,
  List<Map<String, dynamic>>? assets,
  String body = '修复漫画进度',
}) {
  return {
    'tag_name': tag,
    'name': 'Selene $tag',
    'body': body,
    'html_url': 'https://github.com/g3237582/Selene-Source/releases/tag/$tag',
    'draft': draft,
    'prerelease': prerelease,
    'assets': assets ??
        [
          {
            'name': 'selene-1.6.12-armv7a.apk',
            'browser_download_url':
                'https://github.com/g3237582/Selene-Source/releases/download/$tag/selene-1.6.12-armv7a.apk',
            'size': 10,
          },
          {
            'name': 'selene-1.6.12-armv8.apk',
            'browser_download_url':
                'https://github.com/g3237582/Selene-Source/releases/download/$tag/selene-1.6.12-armv8.apk',
            'size': 12,
          },
        ],
  };
}

void main() {
  test('parses /releases/latest and maps it to an update', () async {
    final client = GithubReleaseClient(
      httpClient: MockClient((request) async {
        expect(request.url.toString(), GithubReleaseClient.latestApiUrl);
        expect(request.headers['User-Agent'], 'Selene-Source');
        return _jsonResponse(_releaseJson());
      }),
    );

    final release = await client.fetchLatest();
    expect(release.tagName, 'v1.6.12');
    expect(release.assets.length, 2);

    final result = VersionService.evaluateUpdate(
      currentVersion: '1.6.11',
      release: release,
    );
    expect(result.status, UpdateCheckStatus.available);
    expect(result.info?.latestVersion, '1.6.12');
    expect(result.info?.releaseNotes, contains('漫画进度'));
    expect(AppVersion.normalize(release.tagName), '1.6.12');
  });

  test('falls back to the first non-draft listed release', () async {
    var calls = 0;
    final client = GithubReleaseClient(
      httpClient: MockClient((request) async {
        calls += 1;
        if (request.url.toString() == GithubReleaseClient.latestApiUrl) {
          return _jsonResponse('Not Found', 404);
        }
        expect(request.url.toString(), GithubReleaseClient.listApiUrl);
        return _jsonResponse([
          _releaseJson(tag: 'v1.6.13', draft: true),
          _releaseJson(tag: 'v1.6.12'),
        ]);
      }),
    );

    final release = await client.fetchLatest();
    expect(release.tagName, 'v1.6.12');
    expect(calls, 2);
  });

  test('reports up to date when remote tag is not newer', () {
    final release = GithubRelease.fromJson(_releaseJson(tag: 'v1.6.11'));
    final result = VersionService.evaluateUpdate(
      currentVersion: '1.6.11',
      release: release,
    );
    expect(result.status, UpdateCheckStatus.upToDate);
    expect(result.info, isNull);
  });

  test('uses a friendly error for rate limits and network failures', () async {
    final limited = GithubReleaseClient(
      httpClient: MockClient((request) async {
        return http.Response('rate limited', 403);
      }),
    );
    expect(
      () => limited.fetchLatest(),
      throwsA(isA<UpdateCheckException>().having(
        (error) => error.message,
        'message',
        contains('过于频繁'),
      )),
    );

    final offline = GithubReleaseClient(
      httpClient: MockClient((request) async {
        throw http.ClientException('socket');
      }),
    );
    expect(
      () => offline.fetchLatest(),
      throwsA(isA<UpdateCheckException>().having(
        (error) => error.message,
        'message',
        contains('网络异常'),
      )),
    );
  });
}
