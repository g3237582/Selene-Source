import 'dart:convert';

/// LunaTV names the session cookie per site (`auth`, or `auth_<site>` such as
/// `auth_luna2`). `/api/server-config` exposes that name as `authCookieName`.
/// The stored `Cookie` header already contains the real name, so role display
/// does not depend on a hard-coded `auth` key.
bool isAuthCookieName(String name) {
  final lower = name.toLowerCase();
  return lower == 'auth' || lower.startsWith('auth_');
}

String parseRoleFromCookieHeader(
  String? cookies, {
  String? preferredName,
}) {
  if (cookies == null || cookies.trim().isEmpty) return 'user';
  final map = _parseCookieHeader(cookies);
  final seen = <String>{};
  for (final entry in _authCookieOrder(map, preferredName)) {
    if (!seen.add(entry.key.toLowerCase())) continue;
    if (!isAuthCookieName(entry.key)) continue;
    final role = roleFromAuthCookieValue(entry.value);
    if (role != null) return role;
  }
  return 'user';
}

String? roleFromAuthCookieValue(String raw) {
  try {
    var decoded = raw;
    if (decoded.contains('%')) {
      decoded = Uri.decodeComponent(decoded);
      if (decoded.contains('%')) {
        decoded = Uri.decodeComponent(decoded);
      }
    }
    final data = json.decode(decoded);
    if (data is! Map) return null;
    final role = data['role'];
    if (role is String && role.isNotEmpty) return role;
  } catch (_) {
    return null;
  }
  return null;
}

Map<String, String> _parseCookieHeader(String cookies) {
  final map = <String, String>{};
  for (final cookie in cookies.split(';')) {
    final trimmed = cookie.trim();
    final separator = trimmed.indexOf('=');
    if (separator <= 0) continue;
    final key = trimmed.substring(0, separator).trim();
    final value = trimmed.substring(separator + 1).trim();
    if (key.isEmpty || value.isEmpty) continue;
    map[key] = value;
  }
  return map;
}

List<MapEntry<String, String>> _authCookieOrder(
  Map<String, String> cookies,
  String? preferredName,
) {
  final ordered = <MapEntry<String, String>>[];
  if (preferredName != null && preferredName.trim().isNotEmpty) {
    final preferred = preferredName.trim().toLowerCase();
    for (final entry in cookies.entries) {
      if (entry.key.toLowerCase() == preferred) ordered.add(entry);
    }
  }
  final siteCookies = cookies.entries
      .where((entry) => entry.key.toLowerCase().startsWith('auth_'))
      .toList()
    ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
  ordered.addAll(siteCookies);
  for (final entry in cookies.entries) {
    if (entry.key.toLowerCase() == 'auth') ordered.add(entry);
  }
  return ordered;
}
