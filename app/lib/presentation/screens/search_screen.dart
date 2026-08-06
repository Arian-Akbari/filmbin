import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../providers/core_providers.dart';
import '../providers/search_provider.dart';
import '../widgets/poster_card.dart';
import '../widgets/state_views.dart';

/// Sections 5.5 and 5.6 — search by name, then narrow it down by genre, year,
/// kind and the people involved.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(searchControllerProvider).filters.query;
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Endless list: fetch the next page a little before the bottom (section 8.1).
  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      ref.read(searchControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _openFilters() async {
    final applied = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FilterSheet(filters: ref.read(searchControllerProvider).filters),
    );
    if (applied != null) {
      ref.read(searchControllerProvider.notifier).applyFilters(applied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final notifier = ref.read(searchControllerProvider.notifier);
    final activeFilters = state.filters.activeFilterCount;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      onChanged: notifier.onQueryChanged,
                      onSubmitted: (_) => notifier.search(),
                      decoration: InputDecoration(
                        hintText: 'نام فیلم یا سریال…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: state.filters.query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _controller.clear();
                                  notifier.clear();
                                },
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Badge(
                    isLabelVisible: activeFilters > 0,
                    label: Text(Formatters.digits('$activeFilters')),
                    child: IconButton.filledTonal(
                      tooltip: 'پالایه‌ها',
                      onPressed: _openFilters,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ),
                ],
              ),
            ),
            if (state.stale)
              const OfflineBanner(
                message: 'نتیجه‌ها از حافظهٔ محلی است — سرویس IMDb پاسخ نداد.',
              ),
            if (state.hasSearched && state.total > 0 && !state.loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${Formatters.count(state.total)} نتیجه',
                    style: context.text.labelSmall,
                  ),
                ),
              ),
            Expanded(
              child: _Results(state: state, scroll: _scroll),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.state, required this.scroll});

  final SearchState state;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading) return const ListSkeleton();

    if (state.error != null) {
      return ErrorView(
        error: state.error!,
        onRetry: () => ref.read(searchControllerProvider.notifier).search(),
      );
    }

    if (!state.hasSearched) {
      return const EmptyView(
        icon: Icons.travel_explore_rounded,
        message: 'دنبال چه می‌گردی؟',
        hint: 'نام اثر را بنویس یا با پالایه‌ها بگرد — مثلاً «درام ۲۰۲۰ به بعد».',
      );
    }

    if (state.isEmpty) {
      return const EmptyView(
        icon: Icons.search_off_rounded,
        message: 'چیزی پیدا نشد.',
        hint: 'املای نام را بررسی کن یا پالایه‌ها را کمی باز کن.',
      );
    }

    return ListView.separated(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: state.results.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => Divider(height: 18, color: context.colors.outline),
      itemBuilder: (context, index) {
        if (index >= state.results.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
          );
        }
        final title = state.results[index];
        return TitleRow(title: title, onTap: () => context.push('/title/${title.imdbId}'));
      },
    );
  }
}

/// Section 5.6 — the filter sheet. Nothing is applied until «اعمال» is tapped,
/// so playing with the chips never fires a request.
class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key, required this.filters});

  final SearchFilters filters;

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late SearchFilters _draft = widget.filters;
  late final TextEditingController _person = TextEditingController(text: widget.filters.person);

  static const _sorts = <String, String>{
    'popularity': 'محبوب‌ترین',
    'rating': 'بیشترین امتیاز',
    'newest': 'تازه‌ترین',
    'title': 'الفبایی',
  };

  @override
  void dispose() {
    _person.dispose();
    super.dispose();
  }

  void _toggleGenre(String genre) {
    final genres = [..._draft.genres];
    genres.contains(genre) ? genres.remove(genre) : genres.add(genre);
    setState(() => _draft = _draft.copyWith(genres: genres));
  }

  Future<void> _pickYears() async {
    final now = DateTime.now().year;
    final range = await showDialog<RangeValues>(
      context: context,
      builder: (context) => _YearRangeDialog(
        from: _draft.yearFrom ?? 1950,
        to: _draft.yearTo ?? now,
        maxYear: now + 2,
      ),
    );
    if (range == null) return;
    setState(
      () => _draft = _draft.copyWith(yearFrom: range.start.round(), yearTo: range.end.round()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.94,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                Text('پالایش نتیجه‌ها', style: context.text.titleLarge),
                const SizedBox(height: 18),
                _Label('نوع اثر'),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('همه'),
                      selected: _draft.kind == null,
                      onSelected: (_) =>
                          setState(() => _draft = _draft.copyWith(clearKind: true)),
                    ),
                    ChoiceChip(
                      label: const Text('فیلم'),
                      selected: _draft.kind == 'movie',
                      onSelected: (_) =>
                          setState(() => _draft = _draft.copyWith(kind: 'movie')),
                    ),
                    ChoiceChip(
                      label: const Text('سریال'),
                      selected: _draft.kind == 'series',
                      onSelected: (_) =>
                          setState(() => _draft = _draft.copyWith(kind: 'series')),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _Label('ژانر'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: kGenres.entries.map((entry) {
                    return FilterChip(
                      label: Text(entry.value),
                      selected: _draft.genres.contains(entry.key),
                      onSelected: (_) => _toggleGenre(entry.key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                _Label('سال ساخت'),
                OutlinedButton.icon(
                  onPressed: _pickYears,
                  icon: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(
                    _draft.yearFrom == null && _draft.yearTo == null
                        ? 'هر سالی'
                        : '${Formatters.digits('${_draft.yearFrom ?? 1900}')} تا '
                              '${Formatters.digits('${_draft.yearTo ?? DateTime.now().year}')}',
                  ),
                ),
                if (_draft.yearFrom != null || _draft.yearTo != null)
                  TextButton(
                    onPressed: () => setState(() => _draft = _draft.copyWith(clearYears: true)),
                    child: const Text('حذف بازهٔ سال'),
                  ),
                const SizedBox(height: 20),
                _Label('بازیگر یا کارگردان'),
                _PersonField(
                  controller: _person,
                  onSelected: (name) => setState(() => _draft = _draft.copyWith(person: name)),
                ),
                const SizedBox(height: 20),
                _Label('ترتیب'),
                Wrap(
                  spacing: 8,
                  children: _sorts.entries.map((entry) {
                    return ChoiceChip(
                      label: Text(entry.value),
                      selected: _draft.sort == entry.key,
                      onSelected: (_) =>
                          setState(() => _draft = _draft.copyWith(sort: entry.key)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _person.clear();
                        setState(() => _draft = SearchFilters(query: _draft.query));
                      },
                      child: const Text('پاک کردن'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_draft.copyWith(person: _person.text.trim())),
                      child: const Text('اعمال پالایه‌ها'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Autocomplete over the IMDb name index (section 5.6).
class _PersonField extends ConsumerWidget {
  const _PersonField({required this.controller, required this.onSelected});

  final TextEditingController controller;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Autocomplete<PersonSuggestion>(
      displayStringForOption: (person) => person.name,
      optionsBuilder: (value) async {
        if (value.text.trim().length < 2) return const <PersonSuggestion>[];
        try {
          return await ref.read(titlesRepositoryProvider).people(value.text.trim());
        } catch (_) {
          return const <PersonSuggestion>[];
        }
      },
      onSelected: (person) {
        controller.text = person.name;
        onSelected(person.name);
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmit) {
        textController.text = controller.text;
        return TextField(
          controller: textController,
          focusNode: focusNode,
          textDirection: TextDirection.ltr,
          onChanged: (value) => controller.text = value,
          decoration: const InputDecoration(
            hintText: 'مثلاً Christopher Nolan',
            prefixIcon: Icon(Icons.person_search_rounded),
          ),
        );
      },
      optionsViewBuilder: (context, onSelect, options) => Align(
        alignment: AlignmentDirectional.topStart,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 340),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: options
                  .map(
                    (person) => ListTile(
                      dense: true,
                      title: Text(person.name, textDirection: TextDirection.ltr),
                      subtitle: person.professions.isEmpty
                          ? null
                          : Text(person.professions.join('، ')),
                      onTap: () => onSelect(person),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _YearRangeDialog extends StatefulWidget {
  const _YearRangeDialog({required this.from, required this.to, required this.maxYear});

  final int from;
  final int to;
  final int maxYear;

  @override
  State<_YearRangeDialog> createState() => _YearRangeDialogState();
}

class _YearRangeDialogState extends State<_YearRangeDialog> {
  late RangeValues _values = RangeValues(widget.from.toDouble(), widget.to.toDouble());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('بازهٔ سال ساخت'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${Formatters.digits('${_values.start.round()}')} تا '
            '${Formatters.digits('${_values.end.round()}')}',
            style: context.text.titleMedium,
          ),
          RangeSlider(
            values: _values,
            min: 1900,
            max: widget.maxYear.toDouble(),
            divisions: widget.maxYear - 1900,
            labels: RangeLabels(
              Formatters.digits('${_values.start.round()}'),
              Formatters.digits('${_values.end.round()}'),
            ),
            onChanged: (values) => setState(() => _values = values),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('انصراف')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_values),
          child: const Text('تأیید'),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: context.text.titleMedium),
    );
  }
}
