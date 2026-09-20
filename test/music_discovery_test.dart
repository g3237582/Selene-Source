import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/music_discovery.dart';
import 'package:selene/models/music_track.dart';

void main() {
  test('boards payload maps numbered ranking cards', () {
    final boards = parseMusicBoards({
      'success': true,
      'data': {
        'source': 'kw',
        'list': [
          {'id': '93', 'name': '酷我热歌榜', 'updateFrequency': '每天更新'},
          {'bangid': '', 'name': '无效'},
        ],
      },
    });
    expect(boards, hasLength(1));
    expect(boards.first.id, '93');
    expect(boards.first.source, 'kw');
    expect(boards.first.updateFrequency, '每天更新');
  });

  test('playlist cards keep cover author and song count', () {
    final page = parseMusicPlaylists({
      'data': {
        'source': 'wy',
        'page': 1,
        'total': 40,
        'limit': 20,
        'list': [
          {
            'id': '123',
            'name': '华语流行',
            'pic': 'https://example.com/a.jpg',
            'author': '编辑精选',
            'total': 88,
          },
        ],
      },
    });
    expect(page.items.single.cover, 'https://example.com/a.jpg');
    expect(page.items.single.author, '编辑精选');
    expect(page.items.single.songCount, 88);
    expect(page.hasMore, isTrue);
  });

  test('discovery songs accept lx aliases used by MoonTVPlus', () {
    final page = parseMusicSongs({
      'data': {
        'list': [
          {
            'id': 's1',
            'title': '晴天',
            'singer': '周杰伦',
            'albumName': '叶惠美',
            'pic': 'https://example.com/c.jpg',
            'source': 'wy',
          },
        ],
      },
    });
    expect(page.items.single.songId, 's1');
    expect(page.items.single.name, '晴天');
    expect(page.items.single.artist, '周杰伦');
    expect(page.items.single.cover, 'https://example.com/c.jpg');
  });

  test('same-name board fallback matches 热歌榜 across sources', () {
    final match = findBoardByName(
      const [
        MusicBoard(id: '26', name: '热歌榜', source: 'tx'),
        MusicBoard(id: '27', name: '新歌榜', source: 'tx'),
      ],
      '酷我热歌榜',
    );
    expect(match?.id, '26');
    expect(match?.source, 'tx');
  });

  test('search-style tracks still parse songId and cover', () {
    final track = MusicTrack.fromJson({
      'songId': 'wy_1',
      'name': '七里香',
      'artist': '周杰伦',
      'cover': 'https://example.com/q.jpg',
      'source': 'wy',
    });
    expect(track.songId, 'wy_1');
    expect(track.cover, 'https://example.com/q.jpg');
  });
}
