import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/screens/manga_reader_screen.dart';

void main() {
  test('tapping the left third goes to the previous page', () {
    expect(mangaReaderTapZone(10, 300), MangaReaderTapZone.previous);
    expect(mangaReaderTapZone(99, 300), MangaReaderTapZone.previous);
  });

  test('tapping the right third goes to the next page', () {
    expect(mangaReaderTapZone(201, 300), MangaReaderTapZone.next);
    expect(mangaReaderTapZone(299, 300), MangaReaderTapZone.next);
  });

  test('tapping the center third toggles chrome', () {
    expect(mangaReaderTapZone(150, 300), MangaReaderTapZone.chrome);
  });

  test('next page inside a chapter stays in the chapter', () {
    final turn = resolveMangaReaderTurn(
      pageIndex: 1,
      pageCount: 5,
      chapterIndex: 2,
      chapterCount: 4,
      delta: 1,
    );
    expect(turn.pageIndex, 2);
    expect(turn.chapterOffset, 0);
    expect(turn.openAtEnd, isFalse);
  });

  test('previous page inside a chapter stays in the chapter', () {
    final turn = resolveMangaReaderTurn(
      pageIndex: 1,
      pageCount: 5,
      chapterIndex: 2,
      chapterCount: 4,
      delta: -1,
    );
    expect(turn.pageIndex, 0);
    expect(turn.chapterOffset, 0);
  });

  test('next page on the last page opens the next chapter at the first page', () {
    final turn = resolveMangaReaderTurn(
      pageIndex: 4,
      pageCount: 5,
      chapterIndex: 2,
      chapterCount: 4,
      delta: 1,
    );
    expect(turn.pageIndex, isNull);
    expect(turn.chapterOffset, 1);
    expect(turn.openAtEnd, isFalse);
  });

  test('previous page on the first page opens the previous chapter at the last page', () {
    final turn = resolveMangaReaderTurn(
      pageIndex: 0,
      pageCount: 5,
      chapterIndex: 2,
      chapterCount: 4,
      delta: -1,
    );
    expect(turn.pageIndex, isNull);
    expect(turn.chapterOffset, -1);
    expect(turn.openAtEnd, isTrue);
  });

  test('next page on the last page of the last chapter does nothing', () {
    final turn = resolveMangaReaderTurn(
      pageIndex: 2,
      pageCount: 3,
      chapterIndex: 3,
      chapterCount: 4,
      delta: 1,
    );
    expect(turn.chapterOffset, 0);
    expect(turn.pageIndex, isNull);
  });

  test('vertical overscroll does not turn pages', () {
    expect(
      mangaReaderOverscrollTurnDelta(
        axis: Axis.vertical,
        overscroll: -20,
        fromDrag: true,
        pageIndex: 0,
        pageCount: 5,
      ),
      isNull,
    );
  });

  test('horizontal overscroll on the first page goes to the previous page', () {
    expect(
      mangaReaderOverscrollTurnDelta(
        axis: Axis.horizontal,
        overscroll: -20,
        fromDrag: true,
        pageIndex: 0,
        pageCount: 5,
      ),
      -1,
    );
  });

  test('previous page on the first page of the first chapter does nothing', () {
    final turn = resolveMangaReaderTurn(
      pageIndex: 0,
      pageCount: 3,
      chapterIndex: 0,
      chapterCount: 4,
      delta: -1,
    );
    expect(turn.chapterOffset, 0);
    expect(turn.pageIndex, isNull);
  });
}
