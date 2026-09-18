import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BottomNavItem {
  final String id;
  final IconData icon;
  final String label;

  const BottomNavItem({
    required this.id,
    required this.icon,
    required this.label,
  });

  static const List<BottomNavItem> videoDefaults = [
    BottomNavItem(id: 'home', icon: LucideIcons.house, label: '首页'),
    BottomNavItem(id: 'movie', icon: LucideIcons.video, label: '电影'),
    BottomNavItem(id: 'tv', icon: LucideIcons.tv, label: '剧集'),
    BottomNavItem(id: 'anime', icon: LucideIcons.cat, label: '动漫'),
    BottomNavItem(id: 'show', icon: LucideIcons.clover, label: '综艺'),
    BottomNavItem(id: 'live', icon: LucideIcons.radio, label: '直播'),
  ];
}

class FeatureFlags {
  final bool musicEnabled;
  final bool suwayomiEnabled;
  final bool booksEnabled;

  const FeatureFlags({
    this.musicEnabled = false,
    this.suwayomiEnabled = false,
    this.booksEnabled = false,
  });

  static const FeatureFlags disabled = FeatureFlags();

  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    return FeatureFlags(
      musicEnabled: json['MusicEnabled'] == true,
      suwayomiEnabled: json['SuwayomiEnabled'] == true,
      booksEnabled: json['BooksEnabled'] == true,
    );
  }

  List<String> get extraTabIds => [
        if (suwayomiEnabled) 'manga',
        if (booksEnabled) 'books',
        if (musicEnabled) 'music',
      ];

  List<BottomNavItem> buildNavItems() {
    return [
      ...BottomNavItem.videoDefaults,
      if (suwayomiEnabled)
        const BottomNavItem(
          id: 'manga',
          icon: LucideIcons.bookImage,
          label: '漫画',
        ),
      if (booksEnabled)
        const BottomNavItem(
          id: 'books',
          icon: LucideIcons.bookOpen,
          label: '电子书',
        ),
      if (musicEnabled)
        const BottomNavItem(
          id: 'music',
          icon: LucideIcons.music,
          label: '音乐',
        ),
    ];
  }
}
