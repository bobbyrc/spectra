import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/data.dart';

part 'cards_filter.g.dart';

/// How the library list is ordered.
enum CardsSort {
  /// Newest change first — the repository's own order.
  recent,

  /// By name, case-insensitively.
  name,
}

/// Sentinel distinguishing "leave the folder alone" from "clear it" in
/// [CardsFilter.copyWith], since null is itself a valid folder.
const Object _unsetFolder = Object();

/// What the library list is showing (spec 7.7 step 4's minimum: search,
/// folders, sort).
final class CardsFilter {
  const CardsFilter({
    this.query = '',
    this.folder,
    this.sort = CardsSort.recent,
  });

  /// Case-insensitive substring, matched against the name and the folder.
  final String query;

  /// An exact folder, or null for every folder.
  final String? folder;

  final CardsSort sort;

  CardsFilter copyWith({
    String? query,
    Object? folder = _unsetFolder,
    CardsSort? sort,
  }) => CardsFilter(
    query: query ?? this.query,
    folder: identical(folder, _unsetFolder) ? this.folder : folder as String?,
    sort: sort ?? this.sort,
  );
}

/// Pure, so the rule is tested without a widget or a database.
List<SavedCard> filterCards(List<SavedCard> cards, CardsFilter filter) {
  final String needle = filter.query.trim().toLowerCase();
  final List<SavedCard> matched = cards.where((SavedCard c) {
    if (filter.folder != null && c.folder != filter.folder) return false;
    if (needle.isEmpty) return true;
    return c.name.toLowerCase().contains(needle) ||
        (c.folder?.toLowerCase().contains(needle) ?? false);
  }).toList();
  matched.sort(switch (filter.sort) {
    CardsSort.recent => (SavedCard a, SavedCard b) => b.updatedAt.compareTo(
      a.updatedAt,
    ),
    CardsSort.name => (
      SavedCard a,
      SavedCard b,
    ) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  });
  return matched;
}

/// The folders in use, alphabetical, for the filter control.
List<String> foldersOf(List<SavedCard> cards) =>
    cards.map((SavedCard c) => c.folder).whereType<String>().toSet().toList()
      ..sort();

@riverpod
class CardsFilterState extends _$CardsFilterState {
  @override
  CardsFilter build() => const CardsFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  /// Null means "every folder"; the sentinel in [CardsFilter.copyWith] is
  /// what makes that expressible.
  void setFolder(String? folder) => state = state.copyWith(folder: folder);

  void setSort(CardsSort sort) => state = state.copyWith(sort: sort);
}
