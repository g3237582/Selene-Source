import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import 'poster_dhash.dart';

/// Downloads posters and computes dHash values, with a process-wide URL cache.
class PosterHashLoader {
  static const _timeout = Duration(seconds: 4);
  static const _maxInflight = 3;
  static final Map<String, String> cache = {};
  static final Set<String> _inflight = {};

  static Future<void> ensure(
    Iterable<String> urls, {
    required void Function() onUpdate,
  }) async {
    final pending = urls
        .map((url) => url.trim())
        .where(
          (url) =>
              url.isNotEmpty &&
              !cache.containsKey(url) &&
              !_inflight.contains(url),
        )
        .toSet()
        .take(80)
        .toList();
    if (pending.isEmpty) {
      return;
    }

    var next = 0;
    var changed = false;
    Future<void> worker() async {
      while (next < pending.length) {
        final url = pending[next];
        next += 1;
        _inflight.add(url);
        try {
          final hash = await fromUrl(url);
          if (hash != null) {
            cache[url] = hash;
            changed = true;
          }
        } finally {
          _inflight.remove(url);
        }
      }
    }

    await Future.wait(
      List<Future<void>>.generate(
        _maxInflight.clamp(1, pending.length),
        (_) => worker(),
      ),
    );
    if (changed) {
      onUpdate();
    }
  }

  static Future<String?> fromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      return fromBytes(response.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> fromBytes(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        return null;
      }
      return PosterDHash.fromLuma(
        PosterDHash.rgbaToLuma(
          data.buffer.asUint8List(),
          srcWidth: image.width,
          srcHeight: image.height,
        ),
      );
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
    }
  }
}
