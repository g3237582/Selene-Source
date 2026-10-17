import 'dart:convert';

/// Whether the signed-in user can search special collection sources.
class SpecialSourceCapability {
  final bool available;
  final int count;

  const SpecialSourceCapability({
    required this.available,
    required this.count,
  });

  static const unavailable = SpecialSourceCapability(available: false, count: 0);

  factory SpecialSourceCapability.fromJson(Map<String, dynamic> json) {
    final count = json['count'];
    return SpecialSourceCapability(
      available: json['available'] == true,
      count: count is num ? count.toInt() : 0,
    );
  }

  /// The toggle is shown only when the server says the user can use it.
  bool get showToggle => available;
}

class SpecialSourceForbiddenException implements Exception {
  static const message = '无权使用特殊源';
  static const code = 'special_source_forbidden';

  const SpecialSourceForbiddenException();

  @override
  String toString() => message;
}

/// Interprets special-source responses. A 403 JSON body is the whole payload
/// and must not be parsed as an SSE event stream.
class SpecialSourceAccess {
  static bool isForbiddenBody(int? statusCode, Object? body) {
    if (statusCode != 403 || body == null) {
      return false;
    }
    Object? decoded = body;
    if (body is String) {
      if (body.trim().isEmpty) {
        return false;
      }
      try {
        decoded = json.decode(body);
      } catch (_) {
        return false;
      }
    }
    if (decoded is Map) {
      return decoded['code'] == SpecialSourceForbiddenException.code;
    }
    return false;
  }

  static bool opensEventStream(int statusCode, String body) {
    if (isForbiddenBody(statusCode, body)) {
      return false;
    }
    return statusCode == 200;
  }
}
