class MusicTrack {
  final String songId;
  final String source;
  final String songmid;
  final String name;
  final String artist;
  final String album;
  final String cover;
  final String durationText;
  final String hash;
  final String copyrightId;
  final String albumId;

  const MusicTrack({
    required this.songId,
    required this.source,
    required this.name,
    required this.artist,
    this.songmid = '',
    this.album = '',
    this.cover = '',
    this.durationText = '',
    this.hash = '',
    this.copyrightId = '',
    this.albumId = '',
  });

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      songId: (json['songId'] ?? json['id'] ?? '').toString(),
      source: json['source']?.toString() ?? 'wy',
      songmid: (json['songmid'] ?? json['mid'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? '').toString(),
      artist: (json['artist'] ?? json['singer'] ?? '').toString(),
      album: (json['album'] ?? json['albumName'] ?? '').toString(),
      cover: (json['cover'] ?? json['pic'] ?? json['img'] ?? '').toString(),
      durationText: (json['durationText'] ?? json['interval'] ?? '').toString(),
      hash: json['hash']?.toString() ?? '',
      copyrightId: json['copyrightId']?.toString() ?? '',
      albumId: json['albumId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toPlayBody() {
    return {
      'songId': songId,
      'source': source,
      if (songmid.isNotEmpty) 'songmid': songmid,
      'name': name,
      'artist': artist,
      if (album.isNotEmpty) 'album': album,
      if (cover.isNotEmpty) 'cover': cover,
      if (durationText.isNotEmpty) 'durationText': durationText,
      if (hash.isNotEmpty) 'hash': hash,
      if (copyrightId.isNotEmpty) 'copyrightId': copyrightId,
      if (albumId.isNotEmpty) 'albumId': albumId,
    };
  }
}

class MusicPlayResult {
  final MusicTrack song;
  final String streamUrl;
  final String lyric;
  final String translatedLyric;

  const MusicPlayResult({
    required this.song,
    required this.streamUrl,
    this.lyric = '',
    this.translatedLyric = '',
  });
}

const musicSourceLabels = <String, String>{
  'wy': '网易云',
  'kw': '酷我',
  'tx': 'QQ',
  'kg': '酷狗',
  'mg': '咪咕',
};
