import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/manga.dart';
import 'package:selene/services/local_mode_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

MangaReadRecord _record({
  String mangaId = 'm1',
  int pageIndex = 4,
  int saveTime = 100,
}) {
  return MangaReadRecord(
    title: '海贼王',
    cover: 'cover.png',
    sourceId: 'manga-src',
    sourceName: '漫画源',
    mangaId: mangaId,
    chapterId: 'ch-10',
    chapterName: '第10话',
    pageIndex: pageIndex,
    pageCount: 20,
    saveTime: saveTime,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves a manga record and reads it back after a restart', () async {
    await LocalModeStorageService.saveMangaReadRecord(_record());

    final restored = await LocalModeStorageService.getMangaReadRecords();
    expect(restored, hasLength(1));
    expect(restored.single.mangaId, 'm1');
    expect(restored.single.chapterId, 'ch-10');
    expect(restored.single.pageIndex, 4);
    expect(restored.single.pageCount, 20);
  });

  test('replaces the previous progress for the same manga', () async {
    await LocalModeStorageService.saveMangaReadRecord(_record(pageIndex: 2));
    await LocalModeStorageService.saveMangaReadRecord(
      _record(pageIndex: 9, saveTime: 200),
    );

    final restored = await LocalModeStorageService.getMangaReadRecords();
    expect(restored, hasLength(1));
    expect(restored.single.pageIndex, 9);
  });

  test('looks up one manga without losing other records', () async {
    await LocalModeStorageService.saveMangaReadRecord(_record(mangaId: 'a'));
    await LocalModeStorageService.saveMangaReadRecord(_record(mangaId: 'b', pageIndex: 1));

    final found = await LocalModeStorageService.getMangaReadRecord('manga-src+b');
    expect(found?.pageIndex, 1);
    expect(await LocalModeStorageService.getMangaReadRecords(), hasLength(2));
  });
}
