import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/feature_flags.dart';

void main() {
  group('FeatureFlags.fromJson', () {
    test('parses site-level extras and ignores missing keys', () {
      final flags = FeatureFlags.fromJson({
        'MusicEnabled': true,
        'SuwayomiEnabled': true,
        'BooksEnabled': false,
      });

      expect(flags.musicEnabled, isTrue);
      expect(flags.suwayomiEnabled, isTrue);
      expect(flags.booksEnabled, isFalse);
      expect(flags.extraTabIds, ['manga', 'music']);
    });

    test('treats unknown payloads as disabled', () {
      final flags = FeatureFlags.fromJson({'MusicEnabled': 'yes'});
      expect(flags.extraTabIds, isEmpty);
    });
  });

  group('FeatureFlags.buildNavItems', () {
    test('keeps the original six video tabs then appends extras', () {
      const flags = FeatureFlags(
        suwayomiEnabled: true,
        booksEnabled: true,
        musicEnabled: true,
      );
      final ids = flags.buildNavItems().map((item) => item.id).toList();
      expect(ids, [
        'home',
        'movie',
        'tv',
        'anime',
        'show',
        'live',
        'manga',
        'books',
        'music',
      ]);
    });

    test('does not change video tab order when extras are off', () {
      final ids =
          FeatureFlags.disabled.buildNavItems().map((item) => item.id).toList();
      expect(ids, ['home', 'movie', 'tv', 'anime', 'show', 'live']);
    });
  });
}
