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

Widget _scrollerApp({
  required Size viewport,
  required Size page,
}) {
  return MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: viewport.width,
        height: viewport.height,
        child: MangaReaderPageScroller(
          child: SizedBox(
            key: const Key('manga-page-body'),
            width: page.width,
            height: page.height,
            child: const ColoredBox(color: Colors.red),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('content inset is the safe inset plus the top chrome bar', () {
    final inset = mangaReaderContentInset(
      safeInset: const EdgeInsets.only(top: 47, bottom: 34, left: 8),
    );
    expect(inset.top, 47 + mangaReaderChromeBarHeight);
    expect(inset.bottom, 34);
    expect(inset.left, 8);
    expect(inset.right, 0);
  });

  test('short page is vertically centered in the display rect', () {
    expect(
      mangaReaderPageTopOffset(pageHeight: 200, displayHeight: 600),
      200,
    );
  });

  test('tall page is pinned to the top of the display rect', () {
    expect(
      mangaReaderPageTopOffset(pageHeight: 900, displayHeight: 600),
      0,
    );
  });

  test('page that exactly fills the display rect stays at the top', () {
    expect(
      mangaReaderPageTopOffset(pageHeight: 600, displayHeight: 600),
      0,
    );
  });

  testWidgets('short page widget is vertically centered in the scroller',
      (tester) async {
    const viewport = Size(390, 600);
    const page = Size(390, 200);
    await tester.pumpWidget(
      _scrollerApp(viewport: viewport, page: page),
    );
    await tester.pump();

    final rect = tester.getRect(find.byKey(const Key('manga-page-body')));
    expect(rect.top, closeTo((viewport.height - page.height) / 2, 0.5));
    expect(rect.height, page.height);
  });

  testWidgets('tall page widget top is clamped to the content rect top',
      (tester) async {
    const viewport = Size(390, 400);
    const page = Size(390, 800);
    await tester.pumpWidget(
      _scrollerApp(viewport: viewport, page: page),
    );
    await tester.pump();

    final rect = tester.getRect(find.byKey(const Key('manga-page-body')));
    expect(rect.top, closeTo(0, 0.5));
    expect(rect.height, page.height);
  });

  testWidgets('reader page viewport starts at the bottom of the chrome bar',
      (tester) async {
    await tester.pumpWidget(_readerApp());
    await tester.pump();

    final chromeBottom =
        tester.getBottomLeft(find.byKey(MangaReaderKeys.chromeBar)).dy;
    final padding = tester.widget<Padding>(
      find.byKey(MangaReaderKeys.pageViewport),
    );
    final inset = padding.padding.resolve(TextDirection.ltr);
    expect(inset.top, closeTo(chromeBottom, 0.5));
    expect(chromeBottom, greaterThan(47));
  });
}
