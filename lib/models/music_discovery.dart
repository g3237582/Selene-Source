import 'music_track.dart';

enum MusicPlaylistKind { board, songlist }

class MusicBoard {
  final String id;
  final String name;
  final String cover;
  final String source;
  final String updateFrequency;

  const MusicBoard({
    required this.id,
    required this.name,
    this.cover = '',
    this.source = 'wy',
    this.updateFrequency = '',
  });

  factory MusicBoard.fromJson(Map<String, dynamic> json, {String fallbackSource = 'wy'}) {
    return MusicBoard(
      id: (json['id'] ?? json['bangid'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? '').toString(),
      cover: (json['cover'] ?? json['img'] ?? json['pic'] ?? '').toString(),
      source: (json['source'] ?? fallbackSource).toString(),
      updateFrequency:
          (json['updateFrequency'] ?? json['description'] ?? '').toString(),
    );
  }
}

class MusicPlaylist {
  final String id;
  final String name;
  final String cover;
  final String source;
  final String author;
  final int songCount;

  const MusicPlaylist({
    required this.id,
    required this.name,
    this.cover = '',
    this.source = 'wy',
    this.author = '',
    this.songCount = 0,
  });

  factory MusicPlaylist.fromJson(
    Map<String, dynamic> json, {
    String fallbackSource = 'wy',
  }) {
    return MusicPlaylist(
      id: (json['id'] ?? json['songlistId'] ?? json['listId'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? '').toString(),
      cover: (json['pic'] ?? json['cover'] ?? json['img'] ?? '').toString(),
      source: (json['source'] ?? fallbackSource).toString(),
      author: (json['author'] ?? '').toString(),
      songCount: _asInt(json['total']),
    );
  }
}

class MusicTag {
  final String id;
  final String name;

  const MusicTag({required this.id, required this.name});

  factory MusicTag.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? json['id'] ?? '').toString();
    return MusicTag(
      id: (json['id'] ?? name).toString(),
      name: name,
    );
  }
}

class MusicSongPage {
  final List<MusicTrack> items;
  final int total;
  final int page;
  final bool hasMore;

  const MusicSongPage({
    required this.items,
    this.total = 0,
    this.page = 1,
    this.hasMore = false,
  });
}

class MusicPlaylistPage {
  final List<MusicPlaylist> items;
  final int total;
  final int page;
  final bool hasMore;

  const MusicPlaylistPage({
    required this.items,
    this.total = 0,
    this.page = 1,
    this.hasMore = false,
  });
}

Map<String, dynamic> musicApiData(Map<String, dynamic> payload) {
  final data = payload['data'];
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  return payload;
}

List<Map<String, dynamic>> musicApiList(Map<String, dynamic> data) {
  final list = data['list'];
  if (list is! List) {
    return const [];
  }
  return list
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

List<MusicBoard> parseMusicBoards(Map<String, dynamic> payload) {
  final data = musicApiData(payload);
  final source = data['source']?.toString() ?? 'wy';
  return musicApiList(data)
      .map((item) => MusicBoard.fromJson(item, fallbackSource: source))
      .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
      .toList();
}

MusicPlaylistPage parseMusicPlaylists(Map<String, dynamic> payload) {
  final data = musicApiData(payload);
  final source = data['source']?.toString() ?? 'wy';
  final items = musicApiList(data)
      .map((item) => MusicPlaylist.fromJson(item, fallbackSource: source))
      .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
      .toList();
  final page = _asInt(data['page'], fallback: 1);
  final total = _asInt(data['total'], fallback: items.length);
  final limit = _asInt(data['limit'], fallback: items.length);
  return MusicPlaylistPage(
    items: items,
    total: total,
    page: page,
    hasMore: total > 0 ? page * (limit > 0 ? limit : items.length) < total : items.length >= 20,
  );
}

MusicSongPage parseMusicSongs(Map<String, dynamic> payload) {
  final data = musicApiData(payload);
  final items = musicApiList(data)
      .map(MusicTrack.fromJson)
      .where((item) => item.songId.isNotEmpty && item.name.isNotEmpty)
      .toList();
  final page = _asInt(data['page'], fallback: 1);
  final total = _asInt(data['total'], fallback: items.length);
  return MusicSongPage(
    items: items,
    total: total,
    page: page,
    hasMore: total > items.length || items.length >= 20,
  );
}

List<MusicTag> parseMusicHotTags(Map<String, dynamic> payload) {
  final data = musicApiData(payload);
  final hot = data['hotTags'];
  if (hot is! List) {
    return const [];
  }
  return hot
      .whereType<Map>()
      .map((item) => MusicTag.fromJson(Map<String, dynamic>.from(item)))
      .where((item) => item.name.isNotEmpty)
      .toList();
}

MusicBoard? findBoardByName(List<MusicBoard> boards, String name) {
  final target = name.trim();
  if (target.isEmpty) {
    return null;
  }
  for (final board in boards) {
    if (board.name.trim() == target) {
      return board;
    }
  }
  for (final board in boards) {
    final current = board.name.trim();
    if (current.contains(target) || target.contains(current)) {
      return board;
    }
  }
  return null;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
