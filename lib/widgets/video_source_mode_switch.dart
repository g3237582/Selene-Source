import 'package:flutter/material.dart';

import '../utils/font_utils.dart';

/// 普通源 / 特殊源 selector for the video search page.
class VideoSourceModeSwitch extends StatelessWidget {
  final bool special;
  final ValueChanged<bool> onChanged;
  final bool dark;

  const VideoSourceModeSwitch({
    super.key,
    required this.special,
    required this.onChanged,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip(
          label: '普通源',
          selected: !special,
          onTap: () => onChanged(false),
        ),
        const SizedBox(width: 8),
        _chip(
          label: '特殊源',
          selected: special,
          onTap: () => onChanged(true),
        ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final background = selected
        ? const Color(0xFF27ae60)
        : (dark ? const Color(0xFF1e1e1e) : Colors.white);
    final foreground = selected
        ? Colors.white
        : (dark ? const Color(0xFFb0b0b0) : const Color(0xFF2c3e50));
    final border = selected
        ? const Color(0xFF27ae60)
        : (dark ? const Color(0xFF333333) : const Color(0xFFdfe6e9));
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: FontUtils.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
