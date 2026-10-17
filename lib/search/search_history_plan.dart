import 'special_search_history_store.dart';

/// Normal and special video searches keep separate histories.
///
/// The server does not store a special-source keyword. A special post must
/// send `special: true` so the keyword is skipped for normal history and
/// recommendations. The response of that post is the current normal list and
/// must not replace either local list.
class SearchHistoryPlan {
  final String cacheKey;
  final Map<String, dynamic> body;
  final bool applyServerResponseToThisList;
  final bool includeInRecommendations;

  /// Delete/clear of a special keyword must not call the normal history API,
  /// which would remove the same word from normal history.
  final bool mutatesServerHistory;

  const SearchHistoryPlan({
    required this.cacheKey,
    required this.body,
    required this.applyServerResponseToThisList,
    required this.includeInRecommendations,
    required this.mutatesServerHistory,
  });

  factory SearchHistoryPlan.forMode({
    required String keyword,
    required bool special,
  }) {
    if (special) {
      return SearchHistoryPlan(
        cacheKey: SpecialSearchHistoryStore.prefsKey,
        body: {'keyword': keyword, 'special': true},
        applyServerResponseToThisList: false,
        includeInRecommendations: false,
        mutatesServerHistory: false,
      );
    }
    return SearchHistoryPlan(
      cacheKey: 'search_history',
      body: {'keyword': keyword},
      applyServerResponseToThisList: true,
      includeInRecommendations: true,
      mutatesServerHistory: true,
    );
  }
}

/// Special collection sources stay out of the shared resource cache that
/// homepage suggestions and aggregated recommendations read.
class RecommendationSourcePolicy {
  static bool cacheForRecommendations({required bool special}) => !special;
}
