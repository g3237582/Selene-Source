class GithubReleaseAsset {
  final String name;
  final String downloadUrl;
  final int size;

  const GithubReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  factory GithubReleaseAsset.fromJson(Map<String, dynamic> json) {
    return GithubReleaseAsset(
      name: (json['name'] ?? '').toString(),
      downloadUrl: (json['browser_download_url'] ?? '').toString(),
      size: _readInt(json['size']),
    );
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class GithubRelease {
  final String tagName;
  final String name;
  final String body;
  final String htmlUrl;
  final bool draft;
  final bool prerelease;
  final List<GithubReleaseAsset> assets;

  const GithubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.draft,
    required this.prerelease,
    required this.assets,
  });

  factory GithubRelease.fromJson(Map<String, dynamic> json) {
    final rawAssets = json['assets'];
    final assets = <GithubReleaseAsset>[];
    if (rawAssets is List) {
      for (final item in rawAssets) {
        if (item is Map<String, dynamic>) {
          assets.add(GithubReleaseAsset.fromJson(item));
        } else if (item is Map) {
          assets.add(GithubReleaseAsset.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ));
        }
      }
    }
    return GithubRelease(
      tagName: (json['tag_name'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      htmlUrl: (json['html_url'] ?? '').toString(),
      draft: json['draft'] == true,
      prerelease: json['prerelease'] == true,
      assets: assets,
    );
  }
}

class UpdateCheckException implements Exception {
  final String message;

  const UpdateCheckException(this.message);

  @override
  String toString() => message;
}
