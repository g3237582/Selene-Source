/// Difference hash (dHash) for poster images.
///
/// Input is a 9x8 luma grid. Adjacent pixels in each row become 64 bits.
class PosterDHash {
  static const int width = 9;
  static const int height = 8;
  static const int matchDistance = 10;

  static String fromLuma(List<int> luma) {
    if (luma.length != width * height) {
      throw ArgumentError.value(luma.length, 'luma.length', 'expected 72');
    }
    final bits = StringBuffer();
    for (var row = 0; row < height; row++) {
      for (var col = 0; col < width - 1; col++) {
        final left = luma[row * width + col];
        final right = luma[row * width + col + 1];
        bits.write(left > right ? '1' : '0');
      }
    }
    return _bitsToHex(bits.toString());
  }

  static List<int> rgbaToLuma(
    List<int> rgba, {
    required int srcWidth,
    required int srcHeight,
  }) {
    final luma = List<int>.filled(width * height, 0);
    if (srcWidth <= 0 || srcHeight <= 0 || rgba.length < srcWidth * srcHeight * 4) {
      return luma;
    }
    for (var row = 0; row < height; row++) {
      final srcY = ((row * srcHeight) / height).floor().clamp(0, srcHeight - 1);
      for (var col = 0; col < width; col++) {
        final srcX = ((col * srcWidth) / width).floor().clamp(0, srcWidth - 1);
        final index = (srcY * srcWidth + srcX) * 4;
        luma[row * width + col] =
            (0.299 * rgba[index] + 0.587 * rgba[index + 1] + 0.114 * rgba[index + 2])
                .round()
                .clamp(0, 255);
      }
    }
    return luma;
  }

  static int hamming(String left, String right) {
    if (left.length != right.length || left.isEmpty) {
      return 64;
    }
    var distance = 0;
    for (var offset = 0; offset < left.length; offset += 8) {
      final end = offset + 8 > left.length ? left.length : offset + 8;
      final a = int.parse(left.substring(offset, end), radix: 16);
      final b = int.parse(right.substring(offset, end), radix: 16);
      distance += _bitCount(a ^ b);
    }
    return distance;
  }

  static bool isMatch(String left, String right) {
    return hamming(left, right) <= matchDistance;
  }

  static String _bitsToHex(String bits) {
    final buffer = StringBuffer();
    for (var offset = 0; offset < bits.length; offset += 4) {
      buffer.write(int.parse(bits.substring(offset, offset + 4), radix: 2)
          .toRadixString(16));
    }
    return buffer.toString();
  }

  static int _bitCount(int value) {
    var count = 0;
    var current = value;
    while (current != 0) {
      current &= current - 1;
      count += 1;
    }
    return count;
  }
}
