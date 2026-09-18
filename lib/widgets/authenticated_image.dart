import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/user_data_service.dart';

class AuthenticatedImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  const AuthenticatedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  State<AuthenticatedImage> createState() => _AuthenticatedImageState();
}

class _AuthenticatedImageState extends State<AuthenticatedImage> {
  static final Map<String, Uint8List> _cache = {};
  static const int _maxCacheEntries = 48;

  Uint8List? _bytes;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _load();
    }
  }

  Future<void> _load() async {
    final url = widget.url.trim();
    if (url.isEmpty) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }

    final cached = _cache[url];
    if (cached != null) {
      setState(() {
        _bytes = cached;
        _loading = false;
        _failed = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _failed = false;
    });

    try {
      final resolved = await _resolve(url);
      final cookies = await UserDataService.getCookies();
      final response = await http.get(
        resolved,
        headers: {
          if (cookies != null && cookies.isNotEmpty) 'Cookie': cookies,
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('image ${response.statusCode}');
      }
      final bytes = response.bodyBytes;
      _remember(url, bytes);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<Uri> _resolve(String pathOrUrl) async {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return Uri.parse(pathOrUrl);
    }
    final baseUrl = await UserDataService.getServerUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception('missing server url');
    }
    final cleanBase =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = pathOrUrl.startsWith('/') ? pathOrUrl : '/$pathOrUrl';
    return Uri.parse('$cleanBase$cleanPath');
  }

  void _remember(String key, Uint8List bytes) {
    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = bytes;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_failed || _bytes == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const ColoredBox(
          color: Color(0xFF2c3e50),
          child: Icon(Icons.broken_image_outlined, color: Colors.white54),
        ),
      );
    }
    final image = Image.memory(
      _bytes!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      gaplessPlayback: true,
    );
    if (widget.width == null && widget.height == null) {
      return SizedBox.expand(child: image);
    }
    return image;
  }
}
