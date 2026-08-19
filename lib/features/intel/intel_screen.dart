import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/relative_time.dart';
import '../../theme/tokens.dart';
import 'intel_repository.dart';

final intelRepositoryProvider = Provider((ref) => IntelRepository());

const _categories = [
  (key: null, label: 'All'),
  (key: 'politics', label: 'Politics'),
  (key: 'business', label: 'Business'),
  (key: 'markets', label: 'Markets'),
  (key: 'security', label: 'Security'),
];

const _topicTypes = [
  (key: 'region', label: 'Region', icon: '🌍'),
  (key: 'company', label: 'Company', icon: '🏢'),
  (key: 'keyword', label: 'Keyword', icon: '🔎'),
];

final _selectedCategoryProvider = StateProvider<String?>((ref) => null);

class IntelData {
  final List<NewsItem> items;
  final List<WatchTopic> topics;
  IntelData({required this.items, required this.topics});
}

final intelDataProvider = FutureProvider.autoDispose<IntelData>((ref) async {
  final category = ref.watch(_selectedCategoryProvider);
  final repo = ref.read(intelRepositoryProvider);
  final results = await Future.wait([repo.fetchNewsItems(category: category), repo.fetchWatchTopics()]);
  return IntelData(items: results[0] as List<NewsItem>, topics: results[1] as List<WatchTopic>);
});

({String label, Color barColor, double pct}) _sentimentInfo(num? sentiment) {
  if (sentiment == null) return (label: 'Unrated', barColor: AppColors.ink3, pct: 50);
  final pct = ((sentiment.toDouble() + 1) / 2 * 100).roundToDouble();
  if (sentiment > 0.25) return (label: 'Positive', barColor: AppColors.good, pct: pct);
  if (sentiment < -0.25) return (label: 'Negative', barColor: AppColors.critical, pct: pct);
  return (label: 'Neutral', barColor: AppColors.ink3, pct: pct);
}

/// Ported 1:1 from findme_app/app/(app)/intel.tsx -- news feed with category filters,
/// a headline ticker, and a personal watchlist. The mockup's auto-scrolling ticker
/// animation isn't replicated (same call as the Map tab skipping the canvas globe
/// zoom) -- this is a plain horizontal scroll instead of a looping animation.
class IntelScreen extends ConsumerStatefulWidget {
  const IntelScreen({super.key});

  @override
  ConsumerState<IntelScreen> createState() => _IntelScreenState();
}

class _IntelScreenState extends ConsumerState<IntelScreen> {
  bool _addingTopic = false;
  String _newTopicType = 'region';
  final _newTopicValue = TextEditingController();
  String? _topicError;

  Future<void> _submitTopic() async {
    if (_newTopicValue.text.trim().isEmpty) {
      setState(() => _topicError = 'Enter a value first.');
      return;
    }
    setState(() => _topicError = null);
    try {
      await ref.read(intelRepositoryProvider).addWatchTopic(_newTopicType, _newTopicValue.text.trim());
      _newTopicValue.clear();
      setState(() => _addingTopic = false);
      ref.invalidate(intelDataProvider);
    } catch (e) {
      setState(() => _topicError = 'Failed to add topic.');
    }
  }

  Future<void> _removeTopic(String id) async {
    try {
      await ref.read(intelRepositoryProvider).removeWatchTopic(id);
    } finally {
      ref.invalidate(intelDataProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(intelDataProvider);
    final category = ref.watch(_selectedCategoryProvider);

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('🛰️ Global Intel Feed', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                  Row(
                    children: [
                      SizedBox(width: 6, height: 6, child: DecoratedBox(decoration: BoxDecoration(color: AppColors.good, shape: BoxShape.circle))),
                      SizedBox(width: 5),
                      Text('LIVE', style: TextStyle(color: AppColors.ink3, fontSize: 10, fontFamily: 'monospace', letterSpacing: 0.6)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(intelDataProvider),
                child: data.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  error: (e, _) => ListView(children: [
                    Padding(padding: const EdgeInsets.all(24), child: Text('Could not load: $e', style: const TextStyle(color: AppColors.ink3))),
                  ]),
                  data: (d) => ListView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
                    children: [
                      if (d.items.isNotEmpty) _Ticker(items: d.items.take(8).toList()),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in _categories)
                            _FilterChip(
                              label: c.label,
                              active: category == c.key,
                              onTap: () => ref.read(_selectedCategoryProvider.notifier).state = c.key,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (d.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No intel yet -- the news ingest endpoint runs safely as a no-op until a real NEWS_API_KEY is configured.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.ink3, fontSize: 12, height: 1.4),
                          ),
                        )
                      else
                        for (final n in d.items) _NewsCard(item: n),
                      const SizedBox(height: 18),
                      const Text('YOUR WATCHLIST', style: TextStyle(color: AppColors.ink3, fontSize: 11, letterSpacing: 1)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final t in d.topics)
                            _WatchlistChip(
                              icon: _topicTypes.firstWhere((tt) => tt.key == t.topicType, orElse: () => _topicTypes[2]).icon,
                              value: t.value,
                              onTap: () => _removeTopic(t.id),
                            ),
                          _AddChip(active: _addingTopic, onTap: () => setState(() => _addingTopic = !_addingTopic)),
                        ],
                      ),
                      if (_addingTopic) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (final tt in _topicTypes)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _TypePill(
                                    label: '${tt.icon} ${tt.label}',
                                    active: _newTopicType == tt.key,
                                    onTap: () => setState(() => _newTopicType = tt.key),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newTopicValue,
                                decoration: InputDecoration(
                                  hintText: _newTopicType == 'region' ? 'e.g. Ukraine' : _newTopicType == 'company' ? 'e.g. Acme Corp' : 'e.g. semiconductors',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(onPressed: _submitTopic, child: const Text('Add')),
                          ],
                        ),
                        if (_topicError != null) ...[
                          const SizedBox(height: 6),
                          Text(_topicError!, style: const TextStyle(color: AppColors.critical, fontSize: 11.5)),
                        ],
                      ] else if (d.topics.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'Nothing watched yet -- add a region, company, or keyword to flag it here when it shows up in the feed.',
                            style: TextStyle(color: AppColors.ink3, fontSize: 12, height: 1.4),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ticker extends StatelessWidget {
  final List<NewsItem> items;
  const _Ticker({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 22),
        itemBuilder: (context, i) {
          final n = items[i];
          return Center(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(color: AppColors.ink2, fontSize: 11, fontFamily: 'monospace'),
                children: [
                  TextSpan(text: n.category.toUpperCase(), style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
                  TextSpan(text: ' -- ${n.headline}'),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : Colors.transparent,
          border: Border.all(color: active ? AppColors.accent : AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(label, style: TextStyle(color: active ? const Color(0xFF04101F) : AppColors.ink2, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem item;
  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final sent = _sentimentInfo(item.sentiment);
    final tag = AppColors.newsCategory(switch (item.category) {
      'politics' => NewsCategory.politics,
      'business' => NewsCategory.business,
      'markets' => NewsCategory.markets,
      _ => NewsCategory.security,
    });
    return InkWell(
      onTap: item.url != null ? () => launchUrl(Uri.parse(item.url!), mode: LaunchMode.externalApplication) : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 7),
              decoration: BoxDecoration(color: tag.bg, borderRadius: BorderRadius.circular(5)),
              child: Text(item.category, style: TextStyle(color: tag.fg, fontSize: 9.5, fontFamily: 'monospace', letterSpacing: 0.4)),
            ),
            const SizedBox(height: 6),
            Text(item.headline, style: const TextStyle(color: AppColors.ink, fontSize: 13, height: 1.3)),
            if (item.summary != null) ...[
              const SizedBox(height: 4),
              Text(item.summary!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.ink3, fontSize: 11.5, height: 1.3)),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 4,
                      decoration: BoxDecoration(color: AppColors.hair, borderRadius: BorderRadius.circular(2)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (sent.pct / 100).clamp(0, 1),
                        child: DecoratedBox(decoration: BoxDecoration(color: sent.barColor, borderRadius: BorderRadius.circular(2))),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(sent.label, style: TextStyle(color: sent.barColor, fontSize: 10.5, fontFamily: 'monospace')),
                  ],
                ),
                Text('${item.source} · ${relativeTime(item.publishedAt)}', style: const TextStyle(color: AppColors.ink3, fontSize: 10.5, fontFamily: 'monospace')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchlistChip extends StatelessWidget {
  final String icon;
  final String value;
  final VoidCallback onTap;
  const _WatchlistChip({required this.icon, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text('$icon $value ✕', style: const TextStyle(color: AppColors.ink2, fontSize: 11, fontFamily: 'monospace')),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _AddChip({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(border: Border.all(color: AppColors.accent), borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Text(active ? 'Cancel' : '+ Add', style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TypePill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.accentDim : Colors.transparent,
          border: Border.all(color: active ? AppColors.accent : AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(label, style: TextStyle(color: active ? AppColors.accent : AppColors.ink2, fontSize: 11, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}
