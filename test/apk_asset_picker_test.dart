import 'package:flutter_test/flutter_test.dart';
import 'package:selene/update/apk_asset_picker.dart';
import 'package:selene/update/github_release.dart';

GithubReleaseAsset _asset(String name) {
  return GithubReleaseAsset(
    name: name,
    downloadUrl: 'https://example.test/$name',
    size: 10,
  );
}

void main() {
  final releaseAssets = [
    _asset('selene-1.6.11-armv7a.apk'),
    _asset('selene-1.6.11-armv8.apk'),
    _asset('checksums.txt'),
  ];

  test('arm64 devices prefer selene-*-armv8.apk', () {
    final picked = pickApkAsset(releaseAssets, abi: AndroidAbi.arm64);
    expect(picked?.name, 'selene-1.6.11-armv8.apk');
  });

  test('32-bit ARM devices prefer selene-*-armv7a.apk', () {
    final picked = pickApkAsset(releaseAssets, abi: AndroidAbi.armv7);
    expect(picked?.name, 'selene-1.6.11-armv7a.apk');
  });

  test('falls back to the other ABI when the preferred APK is missing', () {
    final onlyArmv7 = [_asset('selene-1.6.11-armv7a.apk')];
    expect(
      pickApkAsset(onlyArmv7, abi: AndroidAbi.arm64)?.name,
      'selene-1.6.11-armv7a.apk',
    );

    final onlyArmv8 = [_asset('selene-1.6.11-armv8.apk')];
    expect(
      pickApkAsset(onlyArmv8, abi: AndroidAbi.armv7)?.name,
      'selene-1.6.11-armv8.apk',
    );
  });

  test('uses the only APK when a single asset exists', () {
    final only = [_asset('selene-1.6.11-universal.apk')];
    expect(
      pickApkAsset(only, abi: AndroidAbi.arm64)?.name,
      'selene-1.6.11-universal.apk',
    );
  });

  test('recognizes Flutter split APK names', () {
    final flutterAssets = [
      _asset('app-armeabi-v7a-release.apk'),
      _asset('app-arm64-v8a-release.apk'),
    ];
    expect(
      pickApkAsset(flutterAssets, abi: AndroidAbi.arm64)?.name,
      'app-arm64-v8a-release.apk',
    );
    expect(
      pickApkAsset(flutterAssets, abi: AndroidAbi.armv7)?.name,
      'app-armeabi-v7a-release.apk',
    );
  });

  test('prefers a selene- named APK when ABI matches both', () {
    final mixed = [
      _asset('app-arm64-v8a-release.apk'),
      _asset('selene-1.6.11-armv8.apk'),
    ];
    expect(
      pickApkAsset(mixed, abi: AndroidAbi.arm64)?.name,
      'selene-1.6.11-armv8.apk',
    );
  });

  test('returns null when no APK assets exist', () {
    expect(pickApkAsset([_asset('notes.md')]), isNull);
    expect(pickApkAsset(const []), isNull);
  });

  test('other ABI prefers armv8 then armv7 then any apk', () {
    expect(
      pickApkAsset(releaseAssets, abi: AndroidAbi.other)?.name,
      'selene-1.6.11-armv8.apk',
    );
  });

  test('parses ABI strings from the platform channel', () {
    expect(parseAndroidAbi('arm64'), AndroidAbi.arm64);
    expect(parseAndroidAbi('armv7'), AndroidAbi.armv7);
    expect(parseAndroidAbi('x86_64'), AndroidAbi.other);
    expect(parseAndroidAbi(null), AndroidAbi.other);
  });
}
