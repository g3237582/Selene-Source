import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../search/video_search_request.dart';

/// 一次登录 HTTP 响应该怎么处理。
///
/// LunaTV 成功时状态码是 200，正文是
/// `{"ok":true,"token":"<percent-encoded JSON>","auth":{...}}`。
/// `token` 已经是百分号编码，必须原样保存，不能 `Uri.decode`。
/// `Set-Cookie` 的名字是 `auth_luna`（旧服务是 `auth`），并且 `Expires`
/// 里带逗号。读 cookie 失败不能把整次登录变成「网络异常」。
class LoginResponse {
  const LoginResponse({
    required this.enterHome,
    required this.token,
    required this.cookies,
    this.message,
  });

  final bool enterHome;

  /// 响应体里的 token；没有时才是 cookie 里的原文。空字符串表示这次没有令牌。
  final String token;

  /// `name=value` 列表，不含 Path / Expires。读失败时为空。
  final String cookies;

  /// 不进入首页时给用户看的提示。
  final String? message;

  /// 分别读取正文和 Set-Cookie。任何一边抛错都只记日志，另一边仍可用。
  static LoginResponse interpret({
    required int statusCode,
    required String Function() readBody,
    required String? Function() readSetCookie,
  }) {
    String? body;
    try {
      body = readBody();
    } catch (error, stack) {
      _log('读取登录响应体失败', error, stack);
    }

    String? setCookie;
    try {
      setCookie = readSetCookie();
    } catch (error, stack) {
      _log('读取 Set-Cookie 失败', error, stack);
    }

    return parse(
      statusCode: statusCode,
      body: body,
      setCookieHeader: setCookie,
    );
  }

  static LoginResponse parse({
    required int statusCode,
    String? body,
    String? setCookieHeader,
  }) {
    final cookies = cookieHeaderToPairs(setCookieHeader);
    switch (statusCode) {
      case 200:
        final decoded = _decode(body);
        if (decoded is Map && decoded['ok'] == false) {
          final error = decoded['error'];
          final message = error is String && error.isNotEmpty
              ? error
              : '用户名或密码错误';
          return LoginResponse(
            enterHome: false,
            token: '',
            cookies: '',
            message: message,
          );
        }
        final bodyToken = VideoSearchRequest.readLoginToken(decoded);
        final token = bodyToken ??
            VideoSearchRequest.tokenFromAuthCookie(cookies) ??
            '';
        return LoginResponse(
          enterHome: true,
          token: token,
          cookies: cookies,
        );
      case 401:
        return const LoginResponse(
          enterHome: false,
          token: '',
          cookies: '',
          message: '用户名或密码错误',
        );
      case 500:
        return const LoginResponse(
          enterHome: false,
          token: '',
          cookies: '',
          message: '服务器错误',
        );
      default:
        return const LoginResponse(
          enterHome: false,
          token: '',
          cookies: '',
          message: '网络异常',
        );
    }
  }

  /// 从可能被逗号拼在一起的 Set-Cookie 里取出 `name=value`。
  ///
  /// 不使用 `Cookie.fromSetCookieValue`：引号、空格或非 ASCII 会抛
  /// FormatException，而登录只需要把原文留下来。
  static String cookieHeaderToPairs(String? setCookieHeaders) {
    try {
      if (setCookieHeaders == null || setCookieHeaders.isEmpty) {
        return '';
      }
      final pairs = <String>[];
      for (final cookie in setCookieHeaders.split(_setCookieBoundary)) {
        final pair = cookie.split(';').first.trim();
        final separator = pair.indexOf('=');
        if (separator <= 0) {
          continue;
        }
        final name = pair.substring(0, separator).trim();
        if (name.isEmpty || _attributeNames.contains(name.toLowerCase())) {
          continue;
        }
        pairs.add(pair);
      }
      return pairs.join('; ');
    } catch (error, stack) {
      _log('解析 Set-Cookie 失败', error, stack);
      return '';
    }
  }

  static Object? _decode(String? body) {
    if (body == null || body.isEmpty) {
      return null;
    }
    try {
      return json.decode(body);
    } catch (error, stack) {
      _log('解析登录 JSON 失败', error, stack);
      return null;
    }
  }

  static void _log(String where, Object error, StackTrace stack) {
    final raw = error.toString();
    final brief = raw.length <= 180 ? raw : '${raw.substring(0, 180)}…';
    debugPrint('$where: $brief');
    debugPrint('$stack');
  }

  static const _attributeNames = {
    'path',
    'expires',
    'max-age',
    'domain',
    'samesite',
    'secure',
    'httponly',
    'priority',
    'partitioned',
  };

  /// 逗号后面紧跟 `name=` 才是下一枚 cookie。Expires 日期里的逗号不能切开。
  static final RegExp _setCookieBoundary = RegExp(
    "[ \\t]*,[ \\t]*(?=[!#\$%&'*+\\-.0-9A-Z^_`a-z|~]+=)",
  );
}
