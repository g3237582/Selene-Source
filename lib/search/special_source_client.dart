import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/user_data_service.dart';
import 'special_source_access.dart';
import 'video_search_request.dart';

/// Loads `GET /api/search/special-capability`.
///
/// A 401 or transport failure hides the toggle. This probe does not go through
/// the shared 401 recovery path, so a missing capability does not log the user out.
class SpecialSourceClient {
  final http.Client httpClient;
  final String baseUrl;
  final String? token;
  final String? cookie;

  const SpecialSourceClient({
    required this.httpClient,
    required this.baseUrl,
    this.token,
    this.cookie,
  });

  Future<SpecialSourceCapability> fetchCapability() async {
    final request = VideoSearchRequest.get(
      baseUrl: baseUrl,
      path: VideoSearchRequest.capabilityPath,
      special: false,
      token: token,
      cookie: cookie,
      headers: const {'Accept': 'application/json'},
    );
    final response = await httpClient.get(request.uri, headers: request.headers);
    if (response.statusCode != 200) {
      return SpecialSourceCapability.unavailable;
    }
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map) {
        return SpecialSourceCapability.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      return SpecialSourceCapability.unavailable;
    }
    return SpecialSourceCapability.unavailable;
  }
}

class SpecialSourceGateway {
  final http.Client? httpClient;

  const SpecialSourceGateway({this.httpClient});

  Future<SpecialSourceCapability> load() async {
    if (await UserDataService.getIsLocalMode()) {
      return SpecialSourceCapability.unavailable;
    }
    final baseUrl = await UserDataService.getServerUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      return SpecialSourceCapability.unavailable;
    }
    final cookie = await UserDataService.getCookies();
    final token = VideoSearchRequest.bearerToken(
      storedToken: await UserDataService.getAuthToken(),
      cookie: cookie,
    );
    final owned = httpClient == null;
    final client = httpClient ?? http.Client();
    try {
      return await SpecialSourceClient(
        httpClient: client,
        baseUrl: baseUrl,
        token: token,
        cookie: cookie,
      ).fetchCapability();
    } catch (_) {
      return SpecialSourceCapability.unavailable;
    } finally {
      if (owned) {
        client.close();
      }
    }
  }
}
