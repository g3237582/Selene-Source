import 'package:flutter_test/flutter_test.dart';
import 'package:selene/utils/auth_cookie.dart';

void main() {
  String cookie(String role) => Uri.encodeComponent('{"role":"$role","username":"a"}');

  test('reads role from auth and from a per-site auth_* cookie', () {
    expect(parseRoleFromCookieHeader('auth=${cookie('owner')}'), 'owner');
    expect(
      parseRoleFromCookieHeader('auth_luna2=${cookie('admin')}; other=1'),
      'admin',
    );
  });

  test('prefers auth_* over a stale auth cookie', () {
    final header = 'auth=${cookie('user')}; auth_luna2=${cookie('owner')}';
    expect(parseRoleFromCookieHeader(header), 'owner');
    expect(
      parseRoleFromCookieHeader(header, preferredName: 'auth'),
      'user',
    );
  });

  test('decodes a double-encoded cookie value', () {
    final once = Uri.encodeComponent('{"role":"admin"}');
    final twice = Uri.encodeComponent(once);
    expect(parseRoleFromCookieHeader('auth_luna2=$twice'), 'admin');
  });

  test('ignores unrelated cookies and invalid payloads', () {
    final encoded = cookie('owner');
    expect(parseRoleFromCookieHeader('author=$encoded; session=abc'), 'user');
    expect(parseRoleFromCookieHeader('auth_luna2=not-json'), 'user');
    expect(parseRoleFromCookieHeader(null), 'user');
    expect(parseRoleFromCookieHeader(''), 'user');
  });
}
