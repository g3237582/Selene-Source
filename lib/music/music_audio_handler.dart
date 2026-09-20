import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import '../services/music_player_service.dart';
import '../services/music_service.dart';
import 'music_media_session_controller.dart';
import 'music_now_playing.dart';

class MusicPlayerCommands implements MusicPlaybackCommands {
  MusicPlayerCommands(this._player);

  final MusicPlayerService _player;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> playNext() => _player.playNext();

  @override
  Future<void> playPrevious() => _player.playPrevious();

  @override
  Future<void> stopAndClear() => _player.stopAndClear();

  @override
  Future<void> seek(Duration position) => _player.seek(position);
}

/// MediaSession / MPNowPlaying bridge that delegates playback to media_kit.
class MusicAudioHandler extends BaseAudioHandler
    with SeekHandler
    implements MusicSessionPublisher {
  MusicAudioHandler(this._player)
      : controller = MusicMediaSessionController(
          commands: MusicPlayerCommands(_player),
          publisher: _DeferredPublisher(),
        ) {
    (controller.publisher as _DeferredPublisher).inner = this;
    _player.addListener(_onPlayerChanged);
    _onPlayerChanged();
  }

  final MusicPlayerService _player;
  final MusicMediaSessionController controller;
  String? _artTrackId;
  Uri? _artUri;
  int _artGeneration = 0;
  bool _sessionActive = false;

  void _onPlayerChanged() {
    unawaited(controller.sync(_snapshot()));
  }

  MusicNowPlaying? _snapshot() {
    return MusicNowPlaying.fromPlayer(
      current: _player.current,
      queue: _player.queue,
      queueIndex: _player.queueIndex,
      playing: _player.playing,
      loading: _player.loading,
      position: _player.player.state.position,
      duration: _player.player.state.duration,
    );
  }

  @override
  Future<void> play() => controller.play();

  @override
  Future<void> pause() => controller.pause();

  @override
  Future<void> skipToNext() => controller.skipToNext();

  @override
  Future<void> skipToPrevious() => controller.skipToPrevious();

  @override
  Future<void> seek(Duration position) => controller.seek(position);

  @override
  Future<void> stop() async {
    await controller.stop();
    await super.stop();
  }

  @override
  Future<void> publish(MusicNowPlaying nowPlaying) async {
    _sessionActive = true;
    final presentation = MusicSessionPresentation.from(nowPlaying);
    mediaItem.add(_toMediaItem(nowPlaying, _artUriFor(nowPlaying)));
    playbackState.add(_toPlaybackState(nowPlaying, presentation));
    unawaited(_refreshArtwork(nowPlaying));
  }

  @override
  Future<void> clear() async {
    _artTrackId = null;
    _artUri = null;
    mediaItem.add(null);
    if (!_sessionActive) return;
    _sessionActive = false;
    playbackState.add(PlaybackState(
      processingState: AudioProcessingState.idle,
      playing: false,
      controls: const [],
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 1,
    ));
    await super.stop();
  }

  MediaItem _toMediaItem(MusicNowPlaying nowPlaying, Uri? artUri) {
    return MediaItem(
      id: nowPlaying.id,
      title: nowPlaying.title,
      artist: nowPlaying.displayArtist,
      album: nowPlaying.album.isNotEmpty
          ? nowPlaying.album
          : nowPlaying.sourceLabel,
      artUri: artUri,
      duration: nowPlaying.duration > Duration.zero ? nowPlaying.duration : null,
    );
  }

  PlaybackState _toPlaybackState(
    MusicNowPlaying nowPlaying,
    MusicSessionPresentation presentation,
  ) {
    final controls = [
      for (final control in presentation.controls) _mediaControl(control),
    ];
    return PlaybackState(
      controls: controls,
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: _compactIndices(controls.length),
      processingState: presentation.processing == MusicSessionProcessing.loading
          ? AudioProcessingState.loading
          : AudioProcessingState.ready,
      playing: nowPlaying.playing,
      updatePosition: nowPlaying.position,
      bufferedPosition: nowPlaying.position,
      speed: nowPlaying.playing ? 1.0 : 0.0,
      queueIndex: _player.queueIndex >= 0 ? _player.queueIndex : null,
    );
  }

  MediaControl _mediaControl(MusicSessionControl control) {
    switch (control) {
      case MusicSessionControl.previous:
        return MediaControl.skipToPrevious;
      case MusicSessionControl.play:
        return MediaControl.play;
      case MusicSessionControl.pause:
        return MediaControl.pause;
      case MusicSessionControl.next:
        return MediaControl.skipToNext;
      case MusicSessionControl.stop:
        return MediaControl.stop;
    }
  }

  List<int> _compactIndices(int controlCount) {
    if (controlCount <= 3) {
      return [for (var i = 0; i < controlCount; i++) i];
    }
    // Prefer play/pause + neighboring skip + stop in the compact view.
    return const [0, 1, 2];
  }

  Uri? _artUriFor(MusicNowPlaying nowPlaying) {
    if (_artTrackId == nowPlaying.id) return _artUri;
    return Uri.tryParse(nowPlaying.coverUrl);
  }

  Future<void> _refreshArtwork(MusicNowPlaying nowPlaying) async {
    if (nowPlaying.coverUrl.isEmpty) {
      _artTrackId = nowPlaying.id;
      _artUri = null;
      return;
    }
    if (_artTrackId == nowPlaying.id && _artUri != null) return;
    final generation = ++_artGeneration;
    try {
      final resolved = await MusicService.resolveMediaUrl(nowPlaying.coverUrl);
      if (generation != _artGeneration) return;
      _artTrackId = nowPlaying.id;
      _artUri = Uri.tryParse(resolved);
      final current = _snapshot();
      if (current == null || current.id != nowPlaying.id) return;
      mediaItem.add(_toMediaItem(current, _artUri));
    } catch (error) {
      debugPrint('Music media session artwork skipped: $error');
    }
  }
}

class _DeferredPublisher implements MusicSessionPublisher {
  MusicSessionPublisher? inner;

  @override
  Future<void> publish(MusicNowPlaying nowPlaying) {
    return inner?.publish(nowPlaying) ?? Future.value();
  }

  @override
  Future<void> clear() {
    return inner?.clear() ?? Future.value();
  }
}
