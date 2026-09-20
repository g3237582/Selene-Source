import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/paged_list.dart';

/// Virtualized catalog list/grid that keeps its scroll position while the
/// next page is in flight. The loading footer is isolated from item rebuilds.
class PagedCatalogScroll extends StatefulWidget {
  const PagedCatalogScroll({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.hasMore,
    required this.onLoadMore,
    this.loadingMore = false,
    this.loadingMoreListenable,
    this.gridDelegate,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
    this.empty,
    this.findChildIndexCallback,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final bool loadingMore;
  final ValueListenable<bool>? loadingMoreListenable;
  final SliverGridDelegate? gridDelegate;
  final EdgeInsetsGeometry padding;
  final Widget? empty;
  final ChildIndexGetter? findChildIndexCallback;

  @override
  State<PagedCatalogScroll> createState() => _PagedCatalogScrollState();
}

class _PagedCatalogScrollState extends State<PagedCatalogScroll> {
  late final ScrollController _controller = ScrollController();

  bool get _isBusy =>
      widget.loadingMoreListenable?.value ?? widget.loadingMore;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    widget.loadingMoreListenable?.addListener(_onBusyChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void didUpdateWidget(covariant PagedCatalogScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadingMoreListenable != widget.loadingMoreListenable) {
      oldWidget.loadingMoreListenable?.removeListener(_onBusyChanged);
      widget.loadingMoreListenable?.addListener(_onBusyChanged);
    }
    if (oldWidget.itemCount != widget.itemCount ||
        oldWidget.hasMore != widget.hasMore ||
        oldWidget.loadingMore != widget.loadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    }
  }

  @override
  void dispose() {
    widget.loadingMoreListenable?.removeListener(_onBusyChanged);
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onBusyChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  void _onScroll() {
    if (!mounted) {
      return;
    }
    handlePagedScroll(
      _controller,
      hasMore: widget.hasMore,
      isBusy: _isBusy,
      onLoadMore: widget.onLoadMore,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 0) {
      return widget.empty ?? const SizedBox.shrink();
    }

    return CustomScrollView(
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      cacheExtent: 280,
      slivers: [
        SliverPadding(
          padding: widget.padding,
          sliver: widget.gridDelegate == null
              ? SliverList(
                  delegate: _itemDelegate(),
                )
              : SliverGrid(
                  gridDelegate: widget.gridDelegate!,
                  delegate: _itemDelegate(),
                ),
        ),
        SliverToBoxAdapter(
          child: widget.loadingMoreListenable == null
              ? PagedCatalogLoadFooter(visible: widget.loadingMore)
              : ValueListenableBuilder<bool>(
                  valueListenable: widget.loadingMoreListenable!,
                  builder: (context, loading, _) {
                    return PagedCatalogLoadFooter(visible: loading);
                  },
                ),
        ),
      ],
    );
  }

  SliverChildBuilderDelegate _itemDelegate() {
    return SliverChildBuilderDelegate(
      widget.itemBuilder,
      childCount: widget.itemCount,
      findChildIndexCallback: widget.findChildIndexCallback,
      addAutomaticKeepAlives: false,
    );
  }
}

class PagedCatalogLoadFooter extends StatelessWidget {
  const PagedCatalogLoadFooter({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox(height: 24);
    }
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(height: 8),
          Text(
            '加载中…',
            style: TextStyle(fontSize: 12, color: Color(0xFF7f8c8d)),
          ),
        ],
      ),
    );
  }
}
