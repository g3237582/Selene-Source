/// Pure proxy selection for Windows.
///
/// Dart's [HttpClient] only honors `HTTP(S)_PROXY`. It does not read the
/// WinINet settings at
/// `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings`, so a
/// machine that can reach the server only through the system proxy (Clash /
/// mihomo) fails every direct request. Callers on Windows feed those registry
/// values plus the process environment in here.
class SystemProxyInput {
  final bool proxyEnabled;
  final String proxyServer;
  final String proxyOverride;
  final Map<String, String> environment;

  const SystemProxyInput({
    this.proxyEnabled = false,
    this.proxyServer = '',
    this.proxyOverride = '',
    this.environment = const {},
  });
}

enum ProxyProtocol { http, socks }

class ProxyEndpoint {
  final ProxyProtocol protocol;
  final String host;
  final int port;
  final String? userInfo;

  const ProxyEndpoint({
    required this.protocol,
    required this.host,
    required this.port,
    this.userInfo,
  });

  String get findProxyDirective {
    final token = protocol == ProxyProtocol.socks ? 'SOCKS' : 'PROXY';
    return '$token $hostPort';
  }

  /// mpv's `http-proxy` accepts an HTTP proxy URL only, not SOCKS.
  String? get mpvHttpProxy {
    if (protocol != ProxyProtocol.http) return null;
    final auth = (userInfo == null || userInfo!.isEmpty) ? '' : '$userInfo@';
    final literal = host.contains(':') ? '[$host]' : host;
    return 'http://$auth$literal:$port';
  }

  String get hostPort {
    final literal = host.contains(':') ? '[$host]' : host;
    return '$literal:$port';
  }
}

class WindowsProxyRegistry {
  final bool proxyEnable;
  final String proxyServer;
  final String proxyOverride;

  const WindowsProxyRegistry({
    required this.proxyEnable,
    required this.proxyServer,
    required this.proxyOverride,
  });

  static const disabled = WindowsProxyRegistry(
    proxyEnable: false,
    proxyServer: '',
    proxyOverride: '',
  );

  /// Parses `reg query` stdout. Missing values mean the proxy is off.
  static WindowsProxyRegistry parseRegQuery(String text) {
    String? enable;
    String? server;
    String? override;
    final linePattern = RegExp(
      r'^\s*(ProxyEnable|ProxyServer|ProxyOverride)\s+REG_\S+\s*(.*)$',
    );
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final match = linePattern.firstMatch(rawLine);
      if (match == null) continue;
      final value = (match.group(2) ?? '').trim();
      switch (match.group(1)) {
        case 'ProxyEnable':
          enable = value;
        case 'ProxyServer':
          server = value;
        case 'ProxyOverride':
          override = value;
      }
    }
    return WindowsProxyRegistry(
      proxyEnable: enable != null && proxyEnableIsOn(enable),
      proxyServer: server ?? '',
      proxyOverride: override ?? '',
    );
  }
}

bool proxyEnableIsOn(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.isEmpty) return false;
  if (value.startsWith('0x')) {
    return (int.tryParse(value.substring(2), radix: 16) ?? 0) != 0;
  }
  return (int.tryParse(value) ?? 0) != 0;
}

String? lookupEnv(Map<String, String> environment, String name) {
  final target = name.toUpperCase();
  for (final entry in environment.entries) {
    if (entry.key.toUpperCase() != target) continue;
    final value = entry.value.trim();
    if (value.isEmpty) return null;
    return value;
  }
  return null;
}

/// `PROXY host:port; DIRECT` or `DIRECT`.
///
/// Localhost and private LAN addresses are never proxied. When nothing is
/// configured the result is `DIRECT`, so a machine without a proxy keeps
/// connecting directly.
String resolveFindProxy(Uri uri, SystemProxyInput input) {
  final endpoint = _endpointIfProxied(uri, input);
  if (endpoint == null) return 'DIRECT';
  return '${endpoint.findProxyDirective}; DIRECT';
}

/// mpv `http-proxy` value, or null when this URL should connect directly
/// (no proxy, bypass list, localhost/LAN, or a SOCKS-only proxy).
String? resolveMpvHttpProxy(Uri uri, SystemProxyInput input) {
  return _endpointIfProxied(uri, input)?.mpvHttpProxy;
}

ProxyEndpoint? _endpointIfProxied(Uri uri, SystemProxyInput input) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' &&
      scheme != 'https' &&
      scheme != 'ws' &&
      scheme != 'wss') {
    return null;
  }
  if (uri.host.isEmpty || shouldBypassProxy(uri, input)) return null;
  return endpointFor(uri, input);
}

ProxyEndpoint? endpointFor(Uri uri, SystemProxyInput input) {
  final scheme = _proxyScheme(uri);
  final fromEnv = endpointFromEnvironment(scheme, input.environment);
  if (fromEnv != null) return fromEnv;
  if (!input.proxyEnabled) return null;
  return endpointFromProxyServer(scheme, input.proxyServer);
}

String _proxyScheme(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'https' || scheme == 'wss') return 'https';
  return 'http';
}

ProxyEndpoint? endpointFromEnvironment(
  String scheme,
  Map<String, String> environment,
) {
  final specificName = scheme == 'https' ? 'HTTPS_PROXY' : 'HTTP_PROXY';
  final specific = lookupEnv(environment, specificName);
  // A lone HTTP_PROXY is commonly intended for HTTPS CONNECT as well.
  final raw = specific ??
      (scheme == 'https' ? lookupEnv(environment, 'HTTP_PROXY') : null);
  if (raw == null) return null;
  return parseProxyEndpoint(raw);
}

ProxyEndpoint? endpointFromProxyServer(String scheme, String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (!trimmed.contains('=')) {
    return parseProxyEndpoint(trimmed);
  }

  final map = <String, String>{};
  for (final part in trimmed.split(';')) {
    final index = part.indexOf('=');
    if (index <= 0) continue;
    final key = part.substring(0, index).trim().toLowerCase();
    final value = part.substring(index + 1).trim();
    if (key.isEmpty || value.isEmpty) continue;
    map[key] = value;
  }

  final specific = map[scheme];
  if (specific != null) {
    return parseProxyEndpoint(specific);
  }
  if (scheme == 'https' && map['http'] != null) {
    return parseProxyEndpoint(map['http']!);
  }
  final socks = map['socks'] ?? map['socks5'];
  if (socks != null) {
    return parseProxyEndpoint(socks, defaultProtocol: ProxyProtocol.socks);
  }
  return null;
}

ProxyEndpoint? parseProxyEndpoint(
  String raw, {
  ProxyProtocol defaultProtocol = ProxyProtocol.http,
}) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  if (value.contains('://')) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return null;
    final scheme = uri.scheme.toLowerCase();
    final protocol =
        scheme.startsWith('socks') ? ProxyProtocol.socks : ProxyProtocol.http;
    final port = uri.hasPort ? uri.port : (protocol == ProxyProtocol.socks ? 1080 : 80);
    return ProxyEndpoint(
      protocol: protocol,
      host: uri.host,
      port: port,
      userInfo: uri.userInfo.isEmpty ? null : uri.userInfo,
    );
  }

  var host = value;
  int? port;
  if (value.startsWith('[')) {
    final end = value.indexOf(']');
    if (end <= 1) return null;
    host = value.substring(1, end);
    if (end + 2 <= value.length && value[end + 1] == ':') {
      port = int.tryParse(value.substring(end + 2));
    }
  } else {
    final colon = value.lastIndexOf(':');
    if (colon > 0) {
      host = value.substring(0, colon);
      port = int.tryParse(value.substring(colon + 1));
    }
  }
  if (host.isEmpty) return null;
  return ProxyEndpoint(
    protocol: defaultProtocol,
    host: host,
    port: port ?? (defaultProtocol == ProxyProtocol.socks ? 1080 : 80),
  );
}

bool shouldBypassProxy(Uri uri, SystemProxyInput input) {
  if (isLocalOrLanHost(uri.host)) return true;
  for (final pattern in bypassPatterns(input)) {
    if (proxyPatternMatches(uri.host, uri.port, pattern)) return true;
  }
  return false;
}

List<String> bypassPatterns(SystemProxyInput input) {
  return [
    ..._splitBypass(input.proxyOverride, const [';']),
    ..._splitBypass(lookupEnv(input.environment, 'NO_PROXY') ?? '', const [
      ',',
      ';',
      ' ',
      '\t',
    ]),
  ];
}

List<String> _splitBypass(String raw, List<String> separators) {
  if (raw.trim().isEmpty) return const [];
  final pattern = RegExp('[${separators.map(RegExp.escape).join()}]');
  return raw
      .split(pattern)
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}

bool isLocalOrLanHost(String host) {
  var value = host.trim().toLowerCase();
  if (value.startsWith('[') && value.endsWith(']') && value.length >= 2) {
    value = value.substring(1, value.length - 1);
  }
  final zone = value.indexOf('%');
  if (zone >= 0) value = value.substring(0, zone);
  if (value.isEmpty ||
      value == 'localhost' ||
      value.endsWith('.localhost') ||
      value.endsWith('.local')) {
    return true;
  }
  if (!value.contains('.') && !value.contains(':')) return true;

  final ipv4 = _parseIpv4(value);
  if (ipv4 != null) return _isPrivateIpv4(ipv4);
  if (value.contains(':')) return _isLocalIpv6(value);
  return false;
}

bool proxyPatternMatches(String host, int port, String pattern) {
  var value = pattern.trim().toLowerCase();
  if (value.isEmpty) return false;
  if (value == '*') return true;
  if (value == '<local>') {
    return !host.contains('.') && !host.contains(':');
  }
  // Modern Windows uses this to say loopback should still be proxied.
  // Localhost is always direct for this app, so the token adds no bypass.
  if (value == '<-loopback>') return false;

  final schemeSeparator = value.indexOf('://');
  if (schemeSeparator >= 0) {
    value = value.substring(schemeSeparator + 3);
  }

  int? patternPort;
  if (value.startsWith('[')) {
    final end = value.indexOf(']');
    if (end > 1) {
      if (end + 2 <= value.length && value[end + 1] == ':') {
        patternPort = int.tryParse(value.substring(end + 2));
      }
      value = value.substring(1, end);
    }
  } else if (!value.startsWith('.')) {
    final colon = value.lastIndexOf(':');
    if (colon > 0 && int.tryParse(value.substring(colon + 1)) != null) {
      patternPort = int.parse(value.substring(colon + 1));
      value = value.substring(0, colon);
    }
  }
  if (patternPort != null && patternPort != port) return false;

  final normalizedHost = host.toLowerCase();
  if (value.startsWith('.')) {
    final suffix = value.substring(1);
    return normalizedHost == suffix || normalizedHost.endsWith('.$suffix');
  }
  final escaped = RegExp.escape(value).replaceAll(r'\*', '.*').replaceAll(r'\?', '.');
  return RegExp('^$escaped\$').hasMatch(normalizedHost);
}

List<int>? _parseIpv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return null;
  final bytes = <int>[];
  for (final part in parts) {
    if (part.isEmpty || part.length > 3) return null;
    final number = int.tryParse(part);
    if (number == null || number < 0 || number > 255) return null;
    bytes.add(number);
  }
  return bytes;
}

bool _isPrivateIpv4(List<int> bytes) {
  final a = bytes[0];
  final b = bytes[1];
  if (a == 0 || a == 10 || a == 127) return true;
  if (a == 169 && b == 254) return true;
  if (a == 172 && b >= 16 && b <= 31) return true;
  if (a == 192 && b == 168) return true;
  return false;
}

bool _isLocalIpv6(String host) {
  final value = host.toLowerCase();
  if (value == '::' || value == '::1') return true;
  if (value.startsWith('::ffff:')) {
    final mapped = _parseIpv4(value.substring('::ffff:'.length));
    if (mapped != null) return _isPrivateIpv4(mapped);
  }
  final head = value.split(':').first;
  final first = int.tryParse(head, radix: 16);
  if (first == null) return false;
  if (first >= 0xfe80 && first <= 0xfebf) return true;
  if (first >= 0xfc00 && first <= 0xfdff) return true;
  return false;
}
