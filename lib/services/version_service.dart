import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../update/apk_asset_picker.dart';
import '../update/apk_installer.dart';
import '../update/app_version.dart';
import '../update/github_release.dart';
import '../update/github_release_client.dart';

enum UpdateCheckStatus { available, upToDate, failed }

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final VersionInfo? info;
  final String? errorMessage;
  final String currentVersion;

  const UpdateCheckResult({
    required this.status,
    required this.currentVersion,
    this.info,
    this.errorMessage,
  });

  factory UpdateCheckResult.available(VersionInfo info) {
    return UpdateCheckResult(
      status: UpdateCheckStatus.available,
      currentVersion: info.currentVersion,
      info: info,
    );
  }

  factory UpdateCheckResult.upToDate(String currentVersion) {
    return UpdateCheckResult(
      status: UpdateCheckStatus.upToDate,
      currentVersion: currentVersion,
    );
  }

  factory UpdateCheckResult.failed(String message, {String currentVersion = ''}) {
    return UpdateCheckResult(
      status: UpdateCheckStatus.failed,
      currentVersion: currentVersion,
      errorMessage: message,
    );
  }
}

class VersionInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String htmlUrl;
  final List<GithubReleaseAsset> assets;

  const VersionInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.htmlUrl,
    this.assets = const [],
  });

  String get releasePageUrl {
    if (htmlUrl.isNotEmpty) {
      return htmlUrl;
    }
    return VersionService.getReleaseUrl(latestVersion);
  }

  GithubReleaseAsset? pickAssetFor(AndroidAbi abi) {
    return pickApkAsset(assets, abi: abi);
  }
}

enum UpdateInstallStatus { launched, needsPermission, unsupported, noAsset }

class VersionService {
  static const String githubRepoUrl = GithubReleaseClient.repoUrl;
  static const String githubApiUrl = GithubReleaseClient.latestApiUrl;
  static const String _lastPromptKey = 'last_version_check';
  static const String _lastApiCheckKey = 'last_version_api_check';
  static const String _dismissedVersionKey = 'dismissed_version';
  static const Duration autoCheckInterval = Duration(hours: 12);
  static const Duration promptInterval = Duration(hours: 24);

  static GithubReleaseClient _client = GithubReleaseClient();
  static Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(minutes: 5),
    headers: const {
      'User-Agent': GithubReleaseClient.userAgent,
      'Accept': 'application/octet-stream',
    },
    followRedirects: true,
  ));

  /// Visible for tests.
  static void debugOverride({
    GithubReleaseClient? client,
    Dio? dio,
  }) {
    if (client != null) {
      _client = client;
    }
    if (dio != null) {
      _dio = dio;
    }
  }

  static UpdateCheckResult evaluateUpdate({
    required String currentVersion,
    required GithubRelease release,
  }) {
    final latestVersion = AppVersion.normalize(release.tagName);
    if (AppVersion.isNewer(currentVersion, latestVersion)) {
      return UpdateCheckResult.available(
        VersionInfo(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          releaseNotes: release.body,
          htmlUrl: release.htmlUrl,
          assets: release.assets,
        ),
      );
    }
    return UpdateCheckResult.upToDate(currentVersion);
  }

  /// Queries GitHub Releases and compares with the running app version.
  static Future<UpdateCheckResult> checkForUpdate({
    String? currentVersion,
    GithubReleaseClient? client,
  }) async {
    var resolvedCurrent = currentVersion ?? '';
    try {
      if (resolvedCurrent.isEmpty) {
        final packageInfo = await PackageInfo.fromPlatform();
        resolvedCurrent = packageInfo.version;
      }
      final release = await (client ?? _client).fetchLatest();
      return evaluateUpdate(
        currentVersion: resolvedCurrent,
        release: release,
      );
    } on UpdateCheckException catch (error) {
      return UpdateCheckResult.failed(
        error.message,
        currentVersion: resolvedCurrent,
      );
    } catch (error) {
      return UpdateCheckResult.failed(
        '检查更新失败，请稍后重试',
        currentVersion: resolvedCurrent,
      );
    }
  }

  static String getReleaseUrl(String version) {
    final tag = version.startsWith('v') ? version : 'v$version';
    return '$githubRepoUrl/releases/tag/$tag';
  }

  static Future<bool> shouldRunAutoCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_lastApiCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - lastCheck >= autoCheckInterval.inMilliseconds;
  }

  static Future<void> markAutoCheckRan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastApiCheckKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 检查是否应该显示更新提示（避免频繁提示）
  static Future<bool> shouldShowUpdatePrompt(String version) async {
    final prefs = await SharedPreferences.getInstance();

    final dismissedVersion = prefs.getString(_dismissedVersionKey);
    if (dismissedVersion == version) {
      return false;
    }

    final lastCheck = prefs.getInt(_lastPromptKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastCheck < promptInterval.inMilliseconds) {
      return false;
    }

    await prefs.setInt(_lastPromptKey, now);
    return true;
  }

  static Future<void> dismissVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, version);
  }

  static Future<void> clearDismissedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedVersionKey);
  }

  static Future<File> downloadApk({
    required GithubReleaseAsset asset,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
    Directory? directory,
  }) async {
    final dir = directory ?? await getTemporaryDirectory();
    final safeName = asset.name.replaceAll(RegExp(r'[/\\]'), '_');
    final file = File('${dir.path}/$safeName');
    if (await file.exists() &&
        asset.size > 0 &&
        await file.length() == asset.size) {
      onProgress?.call(asset.size, asset.size);
      return file;
    }

    await _dio.download(
      asset.downloadUrl,
      file.path,
      cancelToken: cancelToken,
      onReceiveProgress: onProgress,
      options: Options(
        headers: const {
          'User-Agent': GithubReleaseClient.userAgent,
          'Accept': 'application/octet-stream',
        },
      ),
    );
    return file;
  }

  static Future<({UpdateInstallStatus status, File? file})> downloadAndInstall(
    VersionInfo info, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
    AndroidAbi? abi,
  }) async {
    if (!ApkInstaller.supportsInAppInstall) {
      return (status: UpdateInstallStatus.unsupported, file: null);
    }

    final resolvedAbi =
        abi ?? parseAndroidAbi(await ApkInstaller.preferredAbi());
    final asset = info.pickAssetFor(resolvedAbi);
    if (asset == null) {
      return (status: UpdateInstallStatus.noAsset, file: null);
    }

    final file = await downloadApk(
      asset: asset,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    final installStatus = await ApkInstaller.install(file.path);
    if (installStatus == 'needs_permission') {
      return (status: UpdateInstallStatus.needsPermission, file: file);
    }
    return (status: UpdateInstallStatus.launched, file: file);
  }

  static Future<UpdateInstallStatus> installExisting(File file) async {
    if (!ApkInstaller.supportsInAppInstall) {
      return UpdateInstallStatus.unsupported;
    }
    final installStatus = await ApkInstaller.install(file.path);
    if (installStatus == 'needs_permission') {
      return UpdateInstallStatus.needsPermission;
    }
    return UpdateInstallStatus.launched;
  }
}
