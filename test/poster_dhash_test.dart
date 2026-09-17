import 'package:flutter_test/flutter_test.dart';
import 'package:selene/search/poster_dhash.dart';

void main() {
  group('PosterDHash', () {
    test('hashes identical luma as the same value', () {
      final luma = List<int>.generate(72, (index) => (index % 9) * 28);
      expect(PosterDHash.fromLuma(luma), PosterDHash.fromLuma(List<int>.from(luma)));
    });

    test('keeps a small hamming distance after a mild luma change', () {
      final left = List<int>.generate(72, (index) => (index % 9) * 28);
      final right = List<int>.from(left);
      right[10] = 255;
      expect(
        PosterDHash.hamming(
          PosterDHash.fromLuma(left),
          PosterDHash.fromLuma(right),
        ),
        lessThanOrEqualTo(PosterDHash.matchDistance),
      );
    });

    test('treats inverted luma as a different picture', () {
      final left = List<int>.generate(72, (index) => (index % 9) * 28);
      final right = left.map((value) => 255 - value).toList();
      expect(
        PosterDHash.hamming(
          PosterDHash.fromLuma(left),
          PosterDHash.fromLuma(right),
        ),
        greaterThan(PosterDHash.matchDistance),
      );
    });
  });
}
