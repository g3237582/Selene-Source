import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/book.dart';
import '../models/book_file.dart';
import 'api_service.dart';
import 'session_service.dart';
import 'user_data_service.dart';

class BookFileService {
  static const Duration _timeout = Duration(seconds: 90);

  static Future<BookReadManifest> getManifest({
    required BookItem book,
    required BookChaptersNotApplicable hints,
    BookReadManifest? previous,
  }) async {
    final plan = BookFileOpenPlan.from(
      book: book,
      hints: hints,
      manifest: previous,
    );
    final response = await ApiService.post<Map<String, dynamic>>(
      plan.manifestEndpoint,
      body: plan.manifestBody,
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
    if (!response.success || response.data == null) {
      throw Exception(response.message ?? '获取电子书清单失败');
    }
    return BookReadManifest.fromJson(response.data!);
  }

  static Future<Uint8List> downloadFile({
    required BookItem book,
    required BookChaptersNotApplicable hints,
    BookReadManifest? manifest,
  }) async {
    final plan = BookFileOpenPlan.from(
      book: book,
      hints: hints,
      manifest: manifest,
    );
    final endpoint = plan.fileUrl.isNotEmpty ? plan.fileUrl : plan.fileEndpoint;
    final bytes = plan.fileUrl.isNotEmpty
        ? await _authorizedBytes('GET', endpoint)
        : await _authorizedBytes('POST', endpoint, body: plan.fileBody);
    if (bytes.isEmpty) {
      throw Exception('电子书文件为空');
    }
    return bytes;
  }

  static Future<Uint8List> _authorizedBytes(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    Future<http.Response> send() async {
      final url = await _absoluteUrl(endpoint);
      final headers = await _headers(jsonBody: body != null);
      if (method == 'POST') {
        return http
            .post(
              Uri.parse(url),
              headers: headers,
              body: body == null ? null : json.encode(body),
            )
            .timeout(_timeout);
      }
      return http.get(Uri.parse(url), headers: headers).timeout(_timeout);
    }

    var response = await send();
    if (response.statusCode == 401) {
      final recovery = await SessionService.recoverFromUnauthorized();
      if (recovery == SessionRecoveryResult.refreshed) {
        response = await send();
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = '下载电子书失败: ${response.statusCode}';
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map) {
          message = decoded['error']?.toString() ??
              decoded['message']?.toString() ??
              message;
        }
      } catch (_) {}
      throw Exception(message);
    }
    return response.bodyBytes;
  }

  static Future<String> _absoluteUrl(String endpoint) async {
    final trimmed = endpoint.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final baseUrl = await UserDataService.getServerUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception('服务器地址未配置，请先登录');
    }
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$cleanBase$path';
  }

  static Future<Map<String, String>> _headers({required bool jsonBody}) async {
    final headers = <String, String>{
      'Accept': '*/*',
      if (jsonBody) 'Content-Type': 'application/json',
    };
    final cookies = await UserDataService.getCookies();
    if (cookies != null && cookies.isNotEmpty) {
      headers['Cookie'] = cookies;
    }
    return headers;
  }
}
