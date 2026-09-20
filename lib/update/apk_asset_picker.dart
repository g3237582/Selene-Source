import 'github_release.dart';

enum AndroidAbi { arm64, armv7, other }

AndroidAbi parseAndroidAbi(String? raw) {
  switch (raw) {
    case 'arm64':
      return AndroidAbi.arm64;
    case 'armv7':
      return AndroidAbi.armv7;
    default:
      return AndroidAbi.other;
  }
}

bool _isApk(GithubReleaseAsset asset) {
  return asset.name.toLowerCase().endsWith('.apk') &&
      asset.downloadUrl.isNotEmpty;
}

bool _isArm64Name(String name) {
  return name.contains('armv8') ||
      name.contains('arm64-v8a') ||
      name.contains('arm64');
}

bool _isArmv7Name(String name) {
  return name.contains('armv7a') ||
      name.contains('armeabi-v7a') ||
      (name.contains('armv7') && !name.contains('armv8'));
}

int _seleneRank(GithubReleaseAsset asset) {
  return asset.name.toLowerCase().startsWith('selene') ? 0 : 1;
}

GithubReleaseAsset? _firstMatch(
  List<GithubReleaseAsset> assets,
  bool Function(String name) predicate,
) {
  final matches = assets.where((asset) {
    return predicate(asset.name.toLowerCase());
  }).toList()
    ..sort((a, b) => _seleneRank(a).compareTo(_seleneRank(b)));
  if (matches.isEmpty) {
    return null;
  }
  return matches.first;
}

/// Picks the APK that best matches the running Android ABI.
///
/// Preference order:
/// - arm64: `selene-*-armv8.apk` / `*arm64*`
/// - armv7: `selene-*-armv7a.apk` / `*armeabi-v7a*`
/// Falls back to the other ABI, then any `.apk`.
GithubReleaseAsset? pickApkAsset(
  List<GithubReleaseAsset> assets, {
  AndroidAbi abi = AndroidAbi.other,
}) {
  final apks = assets.where(_isApk).toList();
  if (apks.isEmpty) {
    return null;
  }
  if (apks.length == 1) {
    return apks.first;
  }

  final arm64 = _firstMatch(apks, _isArm64Name);
  final armv7 = _firstMatch(apks, _isArmv7Name);

  switch (abi) {
    case AndroidAbi.arm64:
      return arm64 ?? armv7 ?? apks.first;
    case AndroidAbi.armv7:
      return armv7 ?? arm64 ?? apks.first;
    case AndroidAbi.other:
      return arm64 ?? armv7 ?? apks.first;
  }
}
