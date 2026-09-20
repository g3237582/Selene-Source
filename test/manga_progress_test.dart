import 'package:flutter_test/flutter_test.dart';
import 'package:selene/manga/manga_progress.dart';
import 'package:selene/models/manga.dart';

MangaChapter _chapter({
  required String id,
  String name = '',
  int pageCount = 0,
}) {
  return MangaChapter(
    id: id,
    mangaId: 'm1',
    name: name,
    pageCount: pageCount,
  );
}

MangaReadRecord _record({
  String chapterId = 'c2',
  String chapterName = '第2话',
  int pageIndex = 3,
  int pageCount = 12,
  int saveTime = 100,
  String mangaId = 'm1',
  String sourceId = 'src',
}) {
  return MangaReadRecord(
    title: '测试漫画',
    cover: 'cover.png',
    sourceId: sourceId,
    sourceName: '源',
    mangaId: mangaId,
    chapterId: chapterId,
    chapterName: chapterName,
    pageIndex: pageIndex,
    pageCount: pageCount,
    saveTime: saveTime,
  );
}

void main() {
  final chapters = [
    _chapter(id: 'c1', name: '第1话', pageCount: 10),
    _chapter(id: 'c2', name: '第2话', pageCount: 12),
    _chapter(id: 'c3', name: '第3话', pageCount: 8),
  ];

  group('clampMangaPageIndex', () {
    test('keeps a page inside the chapter', () {
      expect(
        clampMangaPageIndex(pageIndex: 3, pageCount: 12),
        3,
      );
    });

    test('clamps a page past the end of the chapter', () {
      expect(
        clampMangaPageIndex(pageIndex: 40, pageCount: 12),
        11,
      );
    });

    test('clamps a negative page to zero', () {
      expect(
        clampMangaPageIndex(pageIndex: -2, pageCount: 12),
        0,
      );
    });
  });

  group('resolveMangaResume', () {
    test('returns null when there is no record', () {
      expect(
        resolveMangaResume(chapters: chapters, record: null),
        isNull,
      );
    });

    test('resumes the saved chapter and page', () {
      final resume = resolveMangaResume(
        chapters: chapters,
        record: _record(),
      );
      expect(resume, isNotNull);
      expect(resume!.chapter.id, 'c2');
      expect(resume.pageIndex, 3);
    });

    test('falls back to the chapter name when the id changed', () {
      final resume = resolveMangaResume(
        chapters: chapters,
        record: _record(chapterId: 'old-id', chapterName: '第3话', pageIndex: 1),
      );
      expect(resume, isNotNull);
      expect(resume!.chapter.id, 'c3');
      expect(resume.pageIndex, 1);
    });

    test('returns null when the saved chapter is gone', () {
      expect(
        resolveMangaResume(
          chapters: chapters,
          record: _record(chapterId: 'missing', chapterName: '已删除'),
        ),
        isNull,
      );
    });

    test('clamps the saved page to the live chapter length', () {
      final resume = resolveMangaResume(
        chapters: chapters,
        record: _record(pageIndex: 99, pageCount: 12),
      );
      expect(resume!.pageIndex, 11);
    });
  });

  group('mangaProgressLabel', () {
    test('shows chapter name and page progress', () {
      expect(mangaProgressLabel(_record()), '第2话 · 4/12');
    });

    test('shows a page-only label when the chapter name is empty', () {
      expect(
        mangaProgressLabel(_record(chapterName: '', pageCount: 0, pageIndex: 2)),
        '第3页',
      );
    });

    test('builds a continue-reading label', () {
      expect(mangaContinueLabel(_record()), '继续阅读 第2话 · 4/12');
    });
  });

  group('mergeMangaHistory', () {
    test('keeps the newer record for the same manga', () {
      final remote = _record(pageIndex: 1, saveTime: 10);
      final local = _record(pageIndex: 7, saveTime: 20);
      final merged = mergeMangaHistory(remote: [remote], local: [local]);
      expect(merged, hasLength(1));
      expect(merged.single.pageIndex, 7);
    });

    test('keeps remote-only and local-only records', () {
      final remote = _record(mangaId: 'remote', saveTime: 5);
      final local = _record(mangaId: 'local', saveTime: 8);
      final merged = mergeMangaHistory(remote: [remote], local: [local]);
      expect(merged.map((item) => item.mangaId), ['local', 'remote']);
    });

    test('sorts records by saveTime descending', () {
      final older = _record(mangaId: 'a', saveTime: 1);
      final newer = _record(mangaId: 'b', saveTime: 9);
      final merged = mergeMangaHistory(remote: [older], local: [newer]);
      expect(merged.first.mangaId, 'b');
    });
  });

  group('MangaReadRecord json', () {
    test('round-trips the fields needed to resume reading', () {
      final original = _record(saveTime: 123456);
      final restored = MangaReadRecord.fromJson(original.toJson());
      expect(restored.shelfKey, 'src+m1');
      expect(restored.chapterId, 'c2');
      expect(restored.pageIndex, 3);
      expect(restored.pageCount, 12);
      expect(restored.saveTime, 123456);
    });
  });

  group('findMangaProgress', () {
    test('finds the record for a manga', () {
      final history = [
        _record(mangaId: 'other'),
        _record(mangaId: 'm1', pageIndex: 6),
      ];
      expect(findMangaProgress(history, 'src', 'm1')?.pageIndex, 6);
    });
  });
}
