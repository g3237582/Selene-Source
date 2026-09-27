import 'dart:io';

import 'package:flutter/foundation.dart';

import 'proxy_rules.dart';

/// Installs WinINet + environment proxy settings for every Dart [HttpClient].
///
/// No-op off Windows, so Android, iOS, and macOS keep their existing clients.
class WindowsSystemProxy {
  static SystemProxyInput _input = const SystemProxyInput();

  static Future<void> install() async {
    if (!Platform.isWindows) return;
    final registry = await _readRegistry();
    _input = SystemProxyInput(
      proxyEnabled: registry.proxyEnable,
      proxyServer: registry.proxyServer,
      proxyOverride: registry.proxyOverride,
      environment: Map<String, String>.from(Platform.environment),
    );
    HttpOverrides.global = _WindowsProxyHttpOverrides();
    final sample = resolveFindProxy(
      Uri.parse('https://example.com/'),
      _input,
    );
    debugPrint(
      'Windows proxy for HTTPS: $sample '
      '(ProxyEnable=${registry.proxyEnable}, '
      'ProxyServer=${registry.proxyServer})',
    );
  }

  static String findProxy(Uri uri) {
    try {
      return resolveFindProxy(uri, _input);
    } catch (error, stack) {
      debugPrint('Windows proxy resolve failed: $error\n$stack');
      return 'DIRECT';
    }
  }

  /// Value for mpv `http-proxy`. Empty keeps a direct connection.
  static String mpvHttpProxyFor(Uri uri) {
    try {
      return resolveMpvHttpProxy(uri, _input) ?? '';
    } catch (error, stack) {
      debugPrint('Windows mpv proxy resolve failed: $error\n$stack');
      return '';
    }
  }

  static Future<WindowsProxyRegistry> _readRegistry() async {
    try {
      final result = await Process.run(
        'reg',
        [
          'query',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        ],
      );
      if (result.exitCode != 0) {
        debugPrint(
          'Windows proxy registry query failed (${result.exitCode}): '
          '${result.stderr}',
        );
        return WindowsProxyRegistry.disabled;
      }
      return WindowsProxyRegistry.parseRegQuery(result.stdout.toString());
    } catch (error, stack) {
      debugPrint('Windows proxy registry read failed: $error\n$stack');
      return WindowsProxyRegistry.disabled;
    }
  }
}

class _WindowsProxyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = WindowsSystemProxy.findProxy;
    return client;
  }
}
