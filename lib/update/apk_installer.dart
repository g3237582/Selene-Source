import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only APK install / ABI helpers via a platform channel.
class ApkInstaller {
  static const MethodChannel channel = MethodChannel('selene/apk_installer');

  static bool get supportsInAppInstall =>
      !kIsWeb && Platform.isAndroid;

  static Future<String> preferredAbi() async {
    if (!supportsInAppInstall) {
      return 'other';
    }
    try {
      final abi = await channel.invokeMethod<String>('getPreferredAbi');
      if (abi == null || abi.isEmpty) {
        return 'other';
      }
      return abi;
    } catch (_) {
      return 'other';
    }
  }

  static Future<bool> canInstallPackages() async {
    if (!supportsInAppInstall) {
      return false;
    }
    try {
      final result = await channel.invokeMethod<bool>('canInstallPackages');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns `started` or `needs_permission`.
  static Future<String> install(String filePath) async {
    if (!supportsInAppInstall) {
      throw const PlatformException(
        code: 'unsupported',
        message: '自动安装仅支持 Android 构建',
      );
    }
    final result = await channel.invokeMethod<String>(
      'installApk',
      {'path': filePath},
    );
    return result ?? 'started';
  }
}
