import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/manga.dart';
import 'package:selene/screens/manga_reader_screen.dart';

const _manga = MangaItem(
  id: 'm1',
  sourceId: 'src',
  sourceName: '源',
  title: '测试漫画',
  cover: '',
);

const _chapter = MangaChapter(
  id: 'c1',
  mangaId: 'm1',
  name: '动画化 (3P)',
);

Widget _readerApp({
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewPadding = const EdgeInsets.only(top: 47, bottom: 34),
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        padding: padding,
        viewPadding: viewPadding,
      ),
      child: const MangaReaderScreen(
        manga: _manga,
        chapters: [_chapter],
        initialChapter: _chapter,
      ),
    ),
  );
}

void main() {
  test('immersive padding still keeps the status-bar and home-indicator inset',
      () {
    final inset = mangaReaderSafeInset(
      padding: EdgeInsets.zero,
      viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
    );
    expect(inset.top, 47);
    expect(inset.bottom, 34);
    expect(inset.left, 0);
    expect(inset.right, 0);
  });

  test('uses the larger of padding and viewPadding on each side', () {
    final inset = mangaReaderSafeInset(
      padding: const EdgeInsets.only(top: 24, left: 8),
      viewPadding: const EdgeInsets.only(top: 47, bottom: 34, right: 12),
    );
    expect(inset.top, 47);
    expect(inset.bottom, 34);
    expect(inset.left, 8);
    expect(inset.right, 12);
  });

  testWidgets(
      'chrome stays below the status bar when immersive padding is zero',
      (tester) async {
    await tester.pumpWidget(_readerApp());
    await tester.pump();

    expect(tester.getTopLeft(find.byIcon(Icons.close)).dy, greaterThanOrEqualTo(47));
    expect(
      tester.getTopLeft(find.textContaining('动画化')).dy,
      greaterThanOrEqualTo(47),
    );
  });

  testWidgets('page viewport insets below the chrome bar and above the home indicator',
      (tester) async {
    await tester.pumpWidget(_readerApp());
    await tester.pump();

    final padding = tester.widget<Padding>(
      find.byKey(MangaReaderKeys.pageViewport),
    );
    expect(
      padding.padding,
      const EdgeInsets.only(top: 47 + mangaReaderChromeBarHeight, bottom: 34),
    );
  });

  testWidgets('chrome also respects a normal (non-immersive) top padding',
      (tester) async {
    await tester.pumpWidget(
      _readerApp(
        padding: const EdgeInsets.only(top: 47, bottom: 34),
        viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
      ),
    );
    await tester.pump();

    expect(tester.getTopLeft(find.byIcon(Icons.close)).dy, greaterThanOrEqualTo(47));
  });
}
