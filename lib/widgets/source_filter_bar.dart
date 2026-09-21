import 'package:flutter/material.dart';

import '../utils/font_utils.dart';

class SourceFilterOption {
  final String id;
  final String name;

  const SourceFilterOption({required this.id, required this.name});
}

/// Horizontal chip row: 全源 plus each enabled source.
class SourceFilterBar extends StatelessWidget {
  static const allSourcesLabel = '全源';

  final List<SourceFilterOption> sources;
  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final Color textColor;

  const SourceFilterBar({
    super.key,
    required this.sources,
    required this.selectedId,
    required this.onSelected,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: sources.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final source = isAll ? null : sources[index - 1];
          final selected = isAll ? selectedId == null : source!.id == selectedId;
          return ChoiceChip(
            label: Text(isAll ? allSourcesLabel : source!.name),
            selected: selected,
            onSelected: (_) => onSelected(isAll ? null : source!.id),
            selectedColor: const Color(0xFF27ae60),
            labelStyle: FontUtils.poppins(
              fontSize: 12,
              color: selected ? Colors.white : textColor,
            ),
          );
        },
      ),
    );
  }
}
