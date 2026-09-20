import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import '../services/theme_service.dart';
import '../utils/font_utils.dart';

class UpdateDialogHeader extends StatelessWidget {
  final ThemeService themeService;

  const UpdateDialogHeader({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: themeService.isDarkMode
            ? const Color(0xFF333333)
            : const Color(0xFFF5F5F5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF27AE60).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              size: 40,
              color: Color(0xFF27AE60),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '发现新版本',
            style: FontUtils.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: themeService.isDarkMode
                  ? const Color(0xFFFFFFFF)
                  : const Color(0xFF2C2C2C),
            ),
          ),
        ],
      ),
    );
  }
}

class UpdateVersionCards extends StatelessWidget {
  final ThemeService themeService;
  final String currentVersion;
  final String latestVersion;

  const UpdateVersionCards({
    super.key,
    required this.themeService,
    required this.currentVersion,
    required this.latestVersion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeService.isDarkMode
            ? const Color(0xFF333333)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _VersionChip(
            themeService: themeService,
            label: '当前版本',
            version: currentVersion,
            icon: Icons.info_outline_rounded,
            color: themeService.isDarkMode
                ? const Color(0xFF999999)
                : const Color(0xFF666666),
          ),
          Container(
            width: 1,
            height: 40,
            color: themeService.isDarkMode
                ? const Color(0xFF444444)
                : const Color(0xFFDDDDDD),
          ),
          _VersionChip(
            themeService: themeService,
            label: '最新版本',
            version: latestVersion,
            icon: Icons.new_releases_rounded,
            color: const Color(0xFF27AE60),
          ),
        ],
      ),
    );
  }
}

class UpdateReleaseNotes extends StatelessWidget {
  final ThemeService themeService;
  final String notes;

  const UpdateReleaseNotes({
    super.key,
    required this.themeService,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.article_outlined,
              size: 18,
              color: Color(0xFF27AE60),
            ),
            const SizedBox(width: 6),
            Text(
              '更新内容',
              style: FontUtils.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: themeService.isDarkMode
                    ? const Color(0xFFFFFFFF)
                    : const Color(0xFF2C2C2C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: themeService.isDarkMode
                ? const Color(0xFF333333)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GptMarkdown(
                notes,
                style: FontUtils.poppins(
                  fontSize: 14,
                  height: 1.6,
                  color: themeService.isDarkMode
                      ? const Color(0xFFCCCCCC)
                      : const Color(0xFF666666),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class UpdateDownloadStatus extends StatelessWidget {
  final ThemeService themeService;
  final String statusText;
  final bool busy;
  final double? progress;

  const UpdateDownloadStatus({
    super.key,
    required this.themeService,
    required this.statusText,
    required this.busy,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          statusText,
          style: FontUtils.poppins(
            fontSize: 13,
            color: const Color(0xFF27AE60),
          ),
        ),
        if (busy) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            color: const Color(0xFF27AE60),
            backgroundColor: themeService.isDarkMode
                ? const Color(0xFF444444)
                : const Color(0xFFE5E7EB),
          ),
        ],
      ],
    );
  }
}

class _VersionChip extends StatelessWidget {
  final ThemeService themeService;
  final String label;
  final String version;
  final IconData icon;
  final Color color;

  const _VersionChip({
    required this.themeService,
    required this.label,
    required this.version,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: FontUtils.poppins(
            fontSize: 12,
            color: themeService.isDarkMode
                ? const Color(0xFF999999)
                : const Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          version,
          style: FontUtils.poppins(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
