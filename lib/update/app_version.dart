/// Semantic-ish comparison for app / GitHub release tags.
class AppVersion {
  const AppVersion._();

  /// Strips a leading `v`/`V` and surrounding whitespace.
  static String normalize(String raw) {
    var value = raw.trim();
    if (value.length >= 2 &&
        (value.startsWith('v') || value.startsWith('V')) &&
        _isDigit(value.codeUnitAt(1))) {
      value = value.substring(1);
    } else if (value.length == 1 &&
        (value == 'v' || value == 'V')) {
      value = '';
    }
    return value;
  }

  /// Whether [latest] should be offered as an update over [current].
  static bool isNewer(String current, String latest) {
    return compare(latest, current) > 0;
  }

  /// Compares two version tags. Returns negative if [a] < [b].
  static int compare(String a, String b) {
    final left = _parse(a);
    final right = _parse(b);
    final length = left.parts.length > right.parts.length
        ? left.parts.length
        : right.parts.length;
    for (var i = 0; i < length; i++) {
      final av = i < left.parts.length ? left.parts[i] : 0;
      final bv = i < right.parts.length ? right.parts[i] : 0;
      if (av != bv) {
        return av.compareTo(bv);
      }
    }
    if (left.prerelease.isEmpty && right.prerelease.isNotEmpty) {
      return 1;
    }
    if (left.prerelease.isNotEmpty && right.prerelease.isEmpty) {
      return -1;
    }
    return left.prerelease.compareTo(right.prerelease);
  }

  static _ParsedVersion _parse(String raw) {
    var value = normalize(raw);
    final plus = value.indexOf('+');
    if (plus >= 0) {
      value = value.substring(0, plus);
    }
    var prerelease = '';
    final dash = value.indexOf('-');
    if (dash >= 0) {
      prerelease = value.substring(dash + 1);
      value = value.substring(0, dash);
    }
    if (value.isEmpty) {
      return _ParsedVersion(const [], prerelease);
    }
    final parts = value.split('.').map((segment) {
      return int.tryParse(segment) ?? 0;
    }).toList();
    return _ParsedVersion(parts, prerelease);
  }

  static bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;
}

class _ParsedVersion {
  final List<int> parts;
  final String prerelease;

  const _ParsedVersion(this.parts, this.prerelease);
}
