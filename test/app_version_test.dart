import 'package:flutter_test/flutter_test.dart';
import 'package:selene/update/app_version.dart';

void main() {
  group('AppVersion.normalize', () {
    test('strips a leading v and surrounding spaces', () {
      expect(AppVersion.normalize(' v1.6.11 '), '1.6.11');
      expect(AppVersion.normalize('V1.6.11'), '1.6.11');
    });

    test('leaves a bare version unchanged', () {
      expect(AppVersion.normalize('1.6.11'), '1.6.11');
    });
  });

  group('AppVersion.isNewer', () {
    test('detects a newer patch, minor, or extra segment', () {
      expect(AppVersion.isNewer('1.6.10', '1.6.11'), isTrue);
      expect(AppVersion.isNewer('1.6.11', '1.7.0'), isTrue);
      expect(AppVersion.isNewer('1.6.11', '1.6.11.1'), isTrue);
    });

    test('treats equal versions as not newer, including v prefix and missing patch', () {
      expect(AppVersion.isNewer('1.6.11', 'v1.6.11'), isFalse);
      expect(AppVersion.isNewer('v1.6.11', '1.6.11'), isFalse);
      expect(AppVersion.isNewer('1.6', '1.6.0'), isFalse);
      expect(AppVersion.isNewer('1.6.11', '1.6.11'), isFalse);
    });

    test('does not treat an older remote tag as an update', () {
      expect(AppVersion.isNewer('2.0.0', '1.9.9'), isFalse);
      expect(AppVersion.isNewer('1.6.11', '1.6.10'), isFalse);
    });

    test('treats a release as newer than the same version with a prerelease suffix', () {
      expect(AppVersion.isNewer('1.6.11-beta', '1.6.11'), isTrue);
      expect(AppVersion.isNewer('1.6.11', '1.6.11-beta'), isFalse);
    });

    test('ignores build metadata after +', () {
      expect(AppVersion.isNewer('1.6.11+2160', '1.6.11+2161'), isFalse);
      expect(AppVersion.isNewer('1.6.11+2161', '1.6.12+1'), isTrue);
    });

    test('does not throw on empty or non-numeric tags', () {
      expect(AppVersion.isNewer('', '1.0.0'), isTrue);
      expect(AppVersion.isNewer('1.0.0', ''), isFalse);
      expect(AppVersion.isNewer('release', 'nightly'), isFalse);
    });
  });
}
