import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/book.dart';
import 'package:selene/models/manga.dart';
import 'package:selene/models/music_discovery.dart';
import 'package:selene/models/music_track.dart';
import 'package:selene/search/all_source_search.dart';
import 'package:selene/services/books_service.dart';
import 'package:selene/services/manga_service.dart';
import 'package:selene/services/music_service.dart';

void main() {
  group('source labels for aggregated home cards', () {
    test('manga withSource fills blank source fields from the queried source', () {
      const item = MangaItem(
        id: '1',
        sourceId: '',
        sourceName: '',
        title: '海贼王',
        cover: '',
      );
      const source = MangaSource(id: 'mh', name: '漫画源A');

      final labeled = item.withSource(source);
      expect(labeled.sourceId, 'mh');
      expect(labeled.sourceName, '漫画源A');
      expect(labeled.title, '海贼王');
    });

    test('manga withSource keeps an explicit source name from the API', () {
      const item = MangaItem(
        id: '1',
        sourceId: 'mh',
        sourceName: '官方名',
        title: '海贼王',
        cover: '',
      );

      final labeled = item.withSource(const MangaSource(id: 'mh', name: '漫画源A'));
      expect(labeled.sourceName, '官方名');
    });

    test('book withSource fills blank source fields from the queried source', () {
      const item = BookItem(
        id: '1',
        sourceId: '',
        sourceName: '',
        title: '三体',
        author: '刘慈欣',
      );

      final labeled = item.withSource(
        const BookSource(id: 'wol', name: 'Wol.moe', catalogSupported: true),
      );
      expect(labeled.sourceId, 'wol');
      expect(labeled.sourceName, 'Wol.moe');
    });
  });

  group('recommend source selection', () {
    test('manga recommendSourceIds drops blank ids', () {
      expect(
        MangaService.recommendSourceIds(const [
          MangaSource(id: 'a', name: 'A'),
          MangaSource(id: '', name: '空'),
          MangaSource(id: 'a', name: '重复'),
          MangaSource(id: 'b', name: 'B'),
        ]),
        ['a', 'b'],
      );
    });

    test('music discovery uses every known source when aggregating', () {
      expect(
        MusicService.discoverySourceIds(),
        musicSourceLabels.keys.toList(),
      );
      expect(
        MusicService.discoverySourceIds(const ['wy', '', 'wy', 'tx']),
        ['wy', 'tx'],
      );
    });
  });

  group('music aggregated home subtitles', () {
    test('board subtitle prefixes the source label in 全源 mode', () {
      expect(
        musicBoardSubtitle(
          const MusicBoard(
            id: '1',
            name: '热歌榜',
            source: 'wy',
            updateFrequency: '每天更新',
          ),
          showSource: true,
        ),
        '网易云 · 每天更新',
      );
      expect(
        musicBoardSubtitle(
          const MusicBoard(
            id: '1',
            name: '热歌榜',
            source: 'wy',
            updateFrequency: '每天更新',
          ),
          showSource: false,
        ),
        '每天更新',
      );
    });

    test('playlist subtitle prefixes the source label in 全源 mode', () {
      expect(
        musicPlaylistSubtitle(
          const MusicPlaylist(
            id: '1',
            name: '华语流行',
            source: 'tx',
            author: '编辑精选',
            songCount: 88,
          ),
          showSource: true,
        ),
        'QQ · 编辑精选 · 88 首',
      );
    });
  });

  group('aggregated home empty and error copy', () {
    test('recommend empty labels stay Chinese and source-aware', () {
      expect(
        AllSourceSearch.homeEmptyLabel(kind: AllSourceHomeKind.manga),
        '暂无推荐漫画',
      );
      expect(
        AllSourceSearch.homeEmptyLabel(kind: AllSourceHomeKind.book),
        '暂无推荐书籍',
      );
      expect(
        AllSourceSearch.homeEmptyLabel(kind: AllSourceHomeKind.musicBoard),
        '暂无排行榜',
      );
      expect(
        AllSourceSearch.homeEmptyLabel(kind: AllSourceHomeKind.musicPlaylist),
        '暂无推荐歌单',
      );
    });

    test('single-source music empty copy stays source-specific', () {
      expect(
        AllSourceSearch.homeEmptyLabel(
          kind: AllSourceHomeKind.musicBoard,
          allSources: false,
        ),
        '当前音源暂无排行榜数据',
      );
      expect(
        AllSourceSearch.homeEmptyLabel(
          kind: AllSourceHomeKind.musicPlaylist,
          allSources: false,
        ),
        '当前音源暂无推荐歌单数据',
      );
    });
  });

  group('books catalog home page resolution', () {
    test('homeCatalogResult uses auto-followed entries and next href', () {
      const root = BookCatalog(
        entries: [
          BookItem(id: 'nav', sourceId: 'wol', sourceName: 'Wol', title: '反馈'),
        ],
        navigation: [
          BookNavLink(title: '最近更新', href: 'last-update.xml'),
        ],
      );
      const followed = BookCatalog(
        entries: [
          BookItem(
            id: '1',
            sourceId: 'wol',
            sourceName: 'Wol',
            title: '三体',
            author: '刘慈欣',
          ),
        ],
        nextHref: 'page-2.xml',
      );

      final page = BooksService.homeCatalogResult(
        root: root,
        followed: followed,
        selectedHref: 'last-update.xml',
      );
      expect(page.items.single.title, '三体');
      expect(page.hasMore, isTrue);
      expect(page.nextToken, 'page-2.xml');
    });
  });
}
