import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'github_release.dart';

/// Fetches public GitHub Releases for this fork. No token is used.
class GithubReleaseClient {
  static const String owner = 'g3237582';
  static const String repo = 'Selene-Source';
  static const String userAgent = 'Selene-Source';
  static const String repoUrl = 'https://github.com/$owner/$repo';
  static const String latestApiUrl =
      'https://api.github.com/repos/$owner/$repo/releases/latest';
  static const String listApiUrl =
      'https://api.github.com/repos/$owner/$repo/releases';

  final http.Client _http;
  final Duration timeout;

  GithubReleaseClient({
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 12),
  }) : _http = httpClient ?? http.Client();

  Map<String, String> get _headers => const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': userAgent,
        'X-GitHub-Api-Version': '2022-11-28',
      };

  Future<GithubRelease> fetchLatest() async {
    try {
      final latest = await _getJson(latestApiUrl);
      if (latest is Map<String, dynamic>) {
        final release = GithubRelease.fromJson(latest);
        if (!release.draft) {
          return release;
        }
      }
    } on UpdateCheckException catch (error) {
      if (!_isNotFound(error)) {
        rethrow;
      }
    }

    final listed = await _getJson(listApiUrl);
    if (listed is! List) {
      throw const UpdateCheckException('无法获取最新版本信息');
    }
    for (final item in listed) {
      if (item is! Map) {
        continue;
      }
      final release = GithubRelease.fromJson(
        item.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (!release.draft) {
        return release;
      }
    }
    throw const UpdateCheckException('暂无可用的发布版本');
  }

  bool _isNotFound(UpdateCheckException error) {
    return error.message.contains('404');
  }

  Future<Object?> _getJson(String url) async {
    http.Response response;
    try {
      response = await _http
          .get(Uri.parse(url), headers: _headers)
          .timeout(timeout);
    } on TimeoutException {
      throw const UpdateCheckException('网络异常，检查更新失败');
    } on http.ClientException {
      throw const UpdateCheckException('网络异常，检查更新失败');
    } on IOException {
      throw const UpdateCheckException('网络异常，检查更新失败');
    }

    if (response.statusCode == 200) {
      try {
        return json.decode(response.body);
      } catch (_) {
        throw const UpdateCheckException('版本信息解析失败');
      }
    }
    if (response.statusCode == 403) {
      throw const UpdateCheckException('GitHub 请求过于频繁，请稍后再试');
    }
    if (response.statusCode == 404) {
      throw const UpdateCheckException('未找到发布信息（404）');
    }
    throw UpdateCheckException('检查更新失败（${response.statusCode}）');
  }
}
