import 'package:flutter/material.dart';

import '../search/search_list_paging.dart';
import '../utils/device_utils.dart';
import '../utils/font_utils.dart';

class SearchPaginationBar extends StatelessWidget {
  final int totalItems;
  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  const SearchPaginationBar({
    super.key,
    required this.totalItems,
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalItems <= 0) {
      return const SizedBox.shrink();
    }

    final canPrev = page > 1;
    final canNext = pageCount > 0 && page < pageCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              SearchListPaging.summaryText(
                totalItems: totalItems,
                page: page,
                pageCount: pageCount,
              ),
              style: FontUtils.poppins(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          _PageButton(
            label: '上一页',
            enabled: canPrev,
            onTap: () => onPageChanged(page - 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$page/$pageCount',
              style: FontUtils.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF27AE60),
              ),
            ),
          ),
          _PageButton(
            label: '下一页',
            enabled: canNext,
            onTap: () => onPageChanged(page + 1),
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _PageButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled && DeviceUtils.isPC()
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Text(
            label,
            style: FontUtils.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: enabled
                  ? const Color(0xFF27AE60)
                  : Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
