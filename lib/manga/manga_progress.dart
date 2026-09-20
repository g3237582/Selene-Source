import '../models/manga.dart';

class MangaResumeTarget {
  final MangaChapter chapter;
  final int pageIndex;

  const MangaResumeTarget({
    required this.chapter,
    required this.pageIndex,
  });
}

int clampMangaPageIndex({
  required int pageIndex,
  required int pageCount,
}) {
  if (pageCount <= 0) {
    return pageIndex < 0 ? 0 : pageIndex;
  }
  if (pageIndex < 0) {
    return 0;
  }
  if (pageIndex >= pageCount) {
    return pageCount - 1;
  }
  return pageIndex;
}

MangaResumeTarget? resolveMangaResume({
  required List<MangaChapter> chapters,
  MangaReadRecord? record,
}) {
  if (record == null || chapters.isEmpty) {
    return null;
  }
  var index = chapters.indexWhere((chapter) => chapter.id == record.chapterId);
  if (index < 0 && record.chapterName.isNotEmpty) {
    index = chapters.indexWhere((chapter) => chapter.name == record.chapterName);
  }
  if (index < 0) {
    return null;
  }
  final chapter = chapters[index];
  final pageCount = chapter.pageCount > 0 ? chapter.pageCount : record.pageCount;
  return MangaResumeTarget(
    chapter: chapter,
    pageIndex: clampMangaPageIndex(
      pageIndex: record.pageIndex,
      pageCount: pageCount,
    ),
  );
}

String mangaProgressLabel(MangaReadRecord record) {
  final chapter = record.chapterName.trim();
  final pageText = record.pageCount > 0
      ? '${record.pageIndex + 1}/${record.pageCount}'
      : '第${record.pageIndex + 1}页';
  if (chapter.isEmpty) {
    return pageText;
  }
  return '$chapter · $pageText';
}

String mangaContinueLabel(MangaReadRecord record) {
  return '继续阅读 ${mangaProgressLabel(record)}';
}

MangaReadRecord? findMangaProgress(
  List<MangaReadRecord> history,
  String sourceId,
  String mangaId,
) {
  for (final record in history) {
    if (record.sourceId == sourceId && record.mangaId == mangaId) {
      return record;
    }
  }
  return null;
}

List<MangaReadRecord> mergeMangaHistory({
  required List<MangaReadRecord> remote,
  required List<MangaReadRecord> local,
}) {
  final merged = <String, MangaReadRecord>{};
  for (final record in [...remote, ...local]) {
    final existing = merged[record.shelfKey];
    if (existing == null || record.saveTime >= existing.saveTime) {
      merged[record.shelfKey] = record;
    }
  }
  return merged.values.toList()
    ..sort((a, b) => b.saveTime.compareTo(a.saveTime));
}
