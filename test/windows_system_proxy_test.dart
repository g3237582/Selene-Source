import 'package:flutter_test/flutter_test.dart';
import 'package:selene/net/proxy_rules.dart';

void main() {
  const clashRegistry = '''
HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings
    ProxyEnable    REG_DWORD    0x1
    ProxyServer    REG_SZ    127.0.0.1:7897
    ProxyOverride    REG_SZ    <local>
''';

  SystemProxyInput clashInput() {
    final registry = WindowsProxyRegistry.parseRegQuery(clashRegistry);
    return SystemProxyInput(
      proxyEnabled: registry.proxyEnable,
      proxyServer: registry.proxyServer,
      proxyOverride: registry.proxyOverride,
    );
  }

  test('reads WinINet ProxyEnable, ProxyServer, and ProxyOverride', () {
    final registry = WindowsProxyRegistry.parseRegQuery(clashRegistry);
    expect(registry.proxyEnable, isTrue);
    expect(registry.proxyServer, '127.0.0.1:7897');
    expect(registry.proxyOverride, '<local>');
  });

  test('disabled ProxyEnable does not use a saved ProxyServer', () {
    final registry = WindowsProxyRegistry.parseRegQuery('''
    ProxyEnable    REG_DWORD    0x0
    ProxyServer    REG_SZ    127.0.0.1:7897
''');
    final input = SystemProxyInput(
      proxyEnabled: registry.proxyEnable,
      proxyServer: registry.proxyServer,
    );
    expect(
      resolveFindProxy(Uri.parse('https://relay.guanlingqian.com/api/login'), input),
      'DIRECT',
    );
  });

  test('system proxy is used for the public server and skipped for LAN', () {
    final input = clashInput();
    expect(
      resolveFindProxy(Uri.parse('https://relay.guanlingqian.com/api/login'), input),
      'PROXY 127.0.0.1:7897; DIRECT',
    );
    expect(
      resolveMpvHttpProxy(Uri.parse('https://relay.guanlingqian.com/play.m3u8'), input),
      'http://127.0.0.1:7897',
    );
    for (final url in [
      'http://127.0.0.1:8080/stream',
      'http://localhost/video',
      'http://192.168.1.8/live',
      'http://10.1.2.3/a',
      'http://172.16.5.5/a',
      'http://nas/share',
      'http://printer.local/status',
    ]) {
      expect(resolveFindProxy(Uri.parse(url), input), 'DIRECT', reason: url);
      expect(resolveMpvHttpProxy(Uri.parse(url), input), isNull, reason: url);
    }
  });

  test('no configured proxy stays direct', () {
    const input = SystemProxyInput();
    expect(
      resolveFindProxy(Uri.parse('https://relay.guanlingqian.com/'), input),
      'DIRECT',
    );
    expect(
      resolveMpvHttpProxy(Uri.parse('https://relay.guanlingqian.com/'), input),
      isNull,
    );
  });

  test('per-scheme ProxyServer selects http and https separately', () {
    const input = SystemProxyInput(
      proxyEnabled: true,
      proxyServer: 'http=127.0.0.1:7897;https=10.0.0.8:8443;socks=127.0.0.1:7896',
    );
    expect(
      resolveFindProxy(Uri.parse('https://example.com/a'), input),
      'PROXY 10.0.0.8:8443; DIRECT',
    );
    expect(
      resolveFindProxy(Uri.parse('http://example.com/a'), input),
      'PROXY 127.0.0.1:7897; DIRECT',
    );
  });

  test('scheme-qualified proxy URL and socks-only mpv fallback', () {
    const httpUrl = SystemProxyInput(
      proxyEnabled: true,
      proxyServer: 'https=http://127.0.0.1:7897',
    );
    expect(
      resolveMpvHttpProxy(Uri.parse('https://example.com/v'), httpUrl),
      'http://127.0.0.1:7897',
    );

    const socksOnly = SystemProxyInput(
      proxyEnabled: true,
      proxyServer: 'socks=socks5://127.0.0.1:7896',
    );
    expect(
      resolveFindProxy(Uri.parse('https://example.com/v'), socksOnly),
      'SOCKS 127.0.0.1:7896; DIRECT',
    );
    expect(resolveMpvHttpProxy(Uri.parse('https://example.com/v'), socksOnly), isNull);
  });

  test('HTTP_PROXY and HTTPS_PROXY override WinINet, NO_PROXY bypasses', () {
    final input = SystemProxyInput(
      proxyEnabled: true,
      proxyServer: '127.0.0.1:1',
      environment: const {
        'https_proxy': 'http://127.0.0.1:7897',
        'NO_PROXY': 'bypass.example, .internal',
      },
    );
    expect(
      resolveFindProxy(Uri.parse('https://relay.guanlingqian.com/api/login'), input),
      'PROXY 127.0.0.1:7897; DIRECT',
    );
    expect(
      resolveFindProxy(Uri.parse('https://bypass.example/x'), input),
      'DIRECT',
    );
    expect(
      resolveFindProxy(Uri.parse('https://api.internal/x'), input),
      'DIRECT',
    );
  });

  test('ProxyOverride wildcards bypass matching hosts', () {
    const input = SystemProxyInput(
      proxyEnabled: true,
      proxyServer: '127.0.0.1:7897',
      proxyOverride: '*.example.com;corp.example:443',
    );
    expect(
      resolveFindProxy(Uri.parse('https://cdn.example.com/a'), input),
      'DIRECT',
    );
    expect(
      resolveFindProxy(Uri.parse('https://corp.example/a'), input),
      'DIRECT',
    );
    expect(
      resolveFindProxy(Uri.parse('http://corp.example/a'), input),
      'PROXY 127.0.0.1:7897; DIRECT',
    );
  });
}
