import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/api_client.dart';
import '../home/home_shell.dart'; // SortTab için
import '../../widgets/common.dart';

enum RFHSort { helpful, newest, trending }

class RFHListScreen extends StatefulWidget {
  const RFHListScreen({super.key});
  @override
  RFHListScreenState createState() => RFHListScreenState();
}

class RFHListScreenState extends State<RFHListScreen> {
  Future<List<dynamic>>? _future;
  String _query = "";
  String? _tagFilter;
  RFHSort _sort = RFHSort.helpful;

  final _searchCtrl = TextEditingController();
  final _me = Supabase.instance.client.auth.currentUser;

  // HomeShell’den arama/sıralama geldiğinde çağrılacak
  void applyExternalFilters({String? query, SortTab? sort}) {
    if (query != null) {
      _query = query;
      _searchCtrl.text = query;
    }
    if (sort != null) {
      switch (sort) {
        case SortTab.helpful:
          _sort = RFHSort.helpful;
          break;
        case SortTab.newest:
          _sort = RFHSort.newest;
          break;
        case SortTab.trending:
          _sort = RFHSort.trending;
          break;
      }
    }
    _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = api.listRFH(q: _query.isEmpty ? null : _query, tag: _tagFilter);
    });
  }

  Future<void> _refresh() async => _load();

  void _onSearchSubmit(String v) {
    _query = v.trim();
    _load();
  }

  List<Map<String, dynamic>> _applySort(List<Map<String, dynamic>> items) {
    final list = [...items];
    switch (_sort) {
      case RFHSort.newest:
        list.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
        break;
      case RFHSort.trending:
        final now = DateTime.now().toUtc();
        int score(Map<String, dynamic> x) {
          final created = DateTime.tryParse(x['created_at'] ?? '')?.toUtc();
          if (created == null) return 0;
          final ageH = now.difference(created).inHours;
          return ageH <= 72 ? (1000 - ageH) : (100 - ageH.clamp(73, 9999));
        }
        list.sort((a, b) => score(b).compareTo(score(a)));
        break;
      case RFHSort.helpful:
        final hasScore = list.any((e) => e.containsKey('score'));
        if (hasScore) {
          list.sort((a, b) => ((b['score'] ?? 0.0) as num).compareTo(((a['score'] ?? 0.0) as num)));
        } else {
          list.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
        }
        break;
    }
    return list;
  }

  // Üst kısım: arama + sıralama + tag filtresi
  Widget _buildHeader(List<Map<String, dynamic>> currentItems) {
    // Dinamik tag listesi (eldeki sonuçlardan)
    final tagSet = <String>{};
    for (final r in currentItems) {
      final ts = (r['tags'] as List?)?.cast<String>() ?? const <String>[];
      tagSet.addAll(ts);
    }
    final tags = tagSet.toList()..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Arama kutusu
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: "Search help requests…",
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: _onSearchSubmit,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: "Clear",
                onPressed: () {
                  _searchCtrl.clear();
                  _onSearchSubmit("");
                },
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Sıralama + Tag filtre
          Row(
            children: [
              SegmentedButton<RFHSort>(
                segments: const [
                  ButtonSegment(value: RFHSort.helpful, label: Text('Helpful'), icon: Icon(Icons.star_rate_outlined)),
                  ButtonSegment(value: RFHSort.newest, label: Text('New'), icon: Icon(Icons.fiber_new_outlined)),
                  ButtonSegment(value: RFHSort.trending, label: Text('Trending'), icon: Icon(Icons.trending_up_outlined)),
                ],
                selected: {_sort},
                onSelectionChanged: (s) => setState(() => _sort = s.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: "Filter by tag",
                onSelected: (v) {
                  _tagFilter = v == 'all' ? null : v;
                  _load();
                },
                itemBuilder: (c) => [
                  const PopupMenuItem(value: 'all', child: Text('All tags')),
                  ...tags.map((t) => PopupMenuItem(value: t, child: Text(t))),
                ],
                child: Chip(
                  label: Text(_tagFilter == null ? "All tags" : _tagFilter!),
                  avatar: const Icon(Icons.filter_list, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // Kart UI
  Widget _rfhCard(Map<String, dynamic> r) {
    final id = r['id']?.toString() ?? '';
    final title = (r['title'] ?? '') as String;
    final body = (r['body'] ?? '') as String;
    final tags = (r['tags'] as List?)?.cast<String>() ?? const <String>[];
    final createdAt = r['created_at'] as String?;
    final views = r['views'] as int?;
    final avgStars = (r['avg_stars'] is num) ? (r['avg_stars'] as num).toDouble() : null;
    final ratingsCount = (r['ratings_count'] is num) ? (r['ratings_count'] as num).toInt() : null;
    final requesterId = r['requester_id']?.toString();
    final isMine = _me != null && requesterId == _me!.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Detaya git, geri dönünce refresh et
          context.push('/rfh/$id').then((_) => _refresh());
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık satırı + menü
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (isMine)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text("Yours", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        Expanded(
                          child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: "More",
                    onSelected: (v) async {
                      if (v == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Delete request?"),
                            content: const Text("This action cannot be undone."),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Delete"),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          final success = await api.deleteRFH(id);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(success ? "Deleted" : "Delete failed")),
                          );
                          if (success) _refresh();
                        }
                      }
                    },
                    itemBuilder: (c) => [
                      if (isMine)
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Gövde özet
              Text(
                body.isEmpty ? "—" : body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.3),
              ),
              const SizedBox(height: 10),

              // Tags
              if (tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: -6,
                  children: [
                    for (final t in tags) Chip(label: Text(t), visualDensity: VisualDensity.compact),
                  ],
                ),
              const SizedBox(height: 10),

              // Metrikler + zaman
              Row(
                children: [
                  if (avgStars != null && ratingsCount != null)
                    Row(
                      children: [
                        const Icon(Icons.star_rate_rounded, size: 18),
                        const SizedBox(width: 4),
                        Text("${avgStars.toStringAsFixed(1)} (${ratingsCount})"),
                      ],
                    ),
                  if (avgStars != null && ratingsCount != null) const SizedBox(width: 12),
                  if (views != null)
                    Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 18),
                        const SizedBox(width: 4),
                        Text(views.toString()),
                      ],
                    ),
                  const Spacer(),
                  if (createdAt != null)
                    Text(
                      _fromNow(createdAt),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fromNow(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return "";
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    return "${diff.inDays}d";
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Help Requests",
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (c, s) {
            if (s.connectionState == ConnectionState.waiting) return const Loading();
            if (s.hasError) return Center(child: Text('Error: ${s.error}'));

            final raw = (s.data ?? const <dynamic>[])
                .cast<Map<String, dynamic>>();
            if (raw.isEmpty) return const Empty("No requests yet.");

            final items = _applySort(raw);

            // Header + list
            return ListView.builder(
              itemCount: items.length + 1,
              itemBuilder: (ctx, i) {
                if (i == 0) return _buildHeader(items);
                return _rfhCard(items[i - 1]);
              },
            );
          },
        ),
      ),
      // FAB artık HomeShell'den geliyor → burada kesinlikle KULLANMIYORUZ (çift FAB olmasın)
    );
  }
}
