/// Request building for LunaTV video search, including special collection sources.
///
/// The login `token` is already URL-encoded JSON. It must be sent verbatim as
/// `Authorization: Bearer <token>` and must not be decoded or re-encoded.
class VideoSearchRequest {
  static const capabilityPath = '/api/search/special-capability';
  static const searchPath = '/api/search';
  static const wsPath = '/api/search/ws';
  static const suggestionsPath = '/api/search/suggestions';
  static const resourcesPath = '/api/search/resources';
  static const historyPath = '/api/searchhistory';

  final Uri uri;
  final Map<String, String> headers;

  const VideoSearchRequest({
    required this.uri,
    required this.headers,
  });

  static Map<String, String> queryParameters({
    String? query,
    required bool special,
  }) {
    final params = <String, String>{};
    if (query != null) {
      params['q'] = query;
    }
    if (special) {
      params['special'] = '1';
    }
    return params;
  }

  static VideoSearchRequest get({
    required String baseUrl,
    required String path,
    String? query,
    required bool special,
    String? token,
    String? cookie,
    Map<String, String>? headers,
  }) {
    final params = queryParameters(query: query, special: special);
    final uri = Uri.parse(baseUrl).replace(
      path: path,
      queryParameters: params.isEmpty ? null : params,
    );
    final built = <String, String>{
      'Accept': 'application/json',
      ...?headers,
    };
    if (cookie != null && cookie.isNotEmpty) {
      built['Cookie'] = cookie;
    }
    if (token != null && token.isNotEmpty) {
      built['Authorization'] = 'Bearer $token';
    }
    return VideoSearchRequest(uri: uri, headers: built);
  }

  /// Prefer the login response `token`. Fall back to the `auth` cookie value
  /// without decoding it; both are the same URL-encoded JSON.
  static String? bearerToken({String? storedToken, String? cookie}) {
    if (storedToken != null && storedToken.isNotEmpty) {
      return storedToken;
    }
    return tokenFromAuthCookie(cookie);
  }

  static String? tokenFromAuthCookie(String? cookies) {
    if (cookies == null || cookies.isEmpty) {
      return null;
    }
    for (final part in cookies.split(';')) {
      final trimmed = part.trim();
      const prefix = 'auth=';
      if (trimmed.startsWith(prefix) && trimmed.length > prefix.length) {
        return trimmed.substring(prefix.length);
      }
    }
    return null;
  }

  /// Returns the `token` field exactly as the login JSON provided it.
  static String? readLoginToken(Object? decodedBody) {
    if (decodedBody is! Map) {
      return null;
    }
    final token = decodedBody['token'];
    if (token is String && token.isNotEmpty) {
      return token;
    }
    return null;
  }
}
