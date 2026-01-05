import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

enum ContentSort { newest, topRated, mostViewed }

class ContentListScreen extends StatefulWidget {
  const ContentListScreen({super.key});
  @override
  State<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends State<ContentListScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Feed state
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _items = [];

  // Filters
  final _q = TextEditingController();
  String? _typeFilter; // best_practice / guide / story / comment / ...
  ContentSort _sort = ContentSort.newest;
  Timer? _debounce;

  // Composer (new post)
  final _composer = TextEditingController();
  final _composerTags = <String>[];
  bool _posting = false;

  // Inline reply state (per post)
  final Map<String, TextEditingController> _replyCtrls = {};
  final Set<String> _replying = {}; // ids currently posting reply

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    _composer.dispose();
    for (final c in _replyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // --- Data loading ---------------------------------------------------------

  Future<void> _load({bool initial = false}) async {
    if (initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() {
        _refreshing = true;
        _error = null;
      });
    }

    try {
      final res = await api.listContent(q: _q.text.trim().isEmpty ? null : _q.text.trim());
      final list = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map)) // avoid LinkedMap issues on web
          .toList();

      _all = list;
      _applyFilterAndSort();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  void _applyFilterAndSort() {
    Iterable<Map<String, dynamic>> data = _all;

    if (_typeFilter != null && _typeFilter!.isNotEmpty) {
      data = data.where((e) => (e['type'] ?? '') == _typeFilter);
    }

    // Text search (simple)
    final query = _q.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      data = data.where((e) {
        final title = (e['title'] ?? '').toString().toLowerCase();
        final sum = (e['summary'] ?? '').toString().toLowerCase();
        final body = (e['body'] ?? '').toString().toLowerCase();
        final tags = ((e['tags'] as List?) ?? const [])
            .map((x) => x.toString().toLowerCase())
            .join(' ');
        return title.contains(query) ||
            sum.contains(query) ||
            body.contains(query) ||
            tags.contains(query);
      });
    }

    final items = data.toList();

    int cmpNewest(a, b) =>
        ((b['created_at'] ?? '') as String).compareTo((a['created_at'] ?? '') as String);

    switch (_sort) {
      case ContentSort.newest:
        items.sort(cmpNewest);
        break;
      case ContentSort.topRated:
        final has = items.any((e) => e.containsKey('avg_stars'));
        if (has) {
          items.sort((a, b) =>
              ((b['avg_stars'] ?? 0.0) as num).compareTo((a['avg_stars'] ?? 0.0) as num));
        } else {
          items.sort(cmpNewest);
        }
        break;
      case ContentSort.mostViewed:
        final has = items.any((e) => e.containsKey('views'));
        if (has) {
          items.sort(
                  (a, b) => ((b['views'] ?? 0) as num).compareTo((a['views'] ?? 0) as num));
        } else {
          items.sort(cmpNewest);
        }
        break;
    }

    setState(() => _items = items);
  }

  Future<void> _refresh() => _load(initial: false);

  // --- Helpers --------------------------------------------------------------

  static String _fromNow(String? iso) {
    if (iso == null) return "";
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return "";
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    return "${diff.inDays}d";
  }

  String _autoTitleFrom(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return "Note";
    final words = trimmed.split(RegExp(r'\s+'));
    final take = words.take(8).join(' ');
    return take + (words.length > 8 ? "…" : "");
  }

  void _debouncedSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _applyFilterAndSort());
  }

  // --- Composer (new post) --------------------------------------------------

  Widget _composerBox() {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("What's happening?",
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _composer,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: "Share a thought, link, or resource…",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: -6,
              children: [
                for (final t in _composerTags)
                  InputChip(
                    label: Text(t),
                    onDeleted: () {
                      setState(() => _composerTags.remove(t));
                    },
                  ),
                ActionChip(
                  avatar: const Icon(Icons.tag, size: 16),
                  label: const Text("Add tag"),
                  onPressed: () async {
                    final tag = await showDialog<String>(
                      context: context,
                      builder: (_) {
                        final c = TextEditingController();
                        return AlertDialog(
                          title: const Text("Add tag"),
                          content: TextField(
                            controller: c,
                            decoration:
                            const InputDecoration(hintText: "e.g. mental-health"),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel"),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(context, c.text.trim()),
                              child: const Text("Add"),
                            ),
                          ],
                        );
                      },
                    );
                    if (tag != null && tag.isNotEmpty) {
                      setState(() => _composerTags.add(tag.replaceAll(' ', '-')));
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: "Search feed…",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    controller: _q,
                    onChanged: _debouncedSearch,
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: "Filter type",
                  onSelected: (v) =>
                      setState(() => _typeFilter = v == 'all' ? null : v),
                  itemBuilder: (c) => const [
                    PopupMenuItem(value: 'all', child: Text('All types')),
                    PopupMenuItem(value: 'story', child: Text('Story / Post')),
                    PopupMenuItem(value: 'guide', child: Text('Guide')),
                    PopupMenuItem(value: 'best_practice', child: Text('Best Practice')),
                    PopupMenuItem(value: 'case_study', child: Text('Case Study')),
                    PopupMenuItem(value: 'video', child: Text('Video')),
                    PopupMenuItem(value: 'material', child: Text('Material')),
                    PopupMenuItem(value: 'comment', child: Text('Comments')),
                  ],
                  child: Chip(
                    label: Text(_typeFilter == null ? "All types" : _typeFilter!),
                    avatar: const Icon(Icons.tune, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<ContentSort>(
                  segments: const [
                    ButtonSegment(
                        value: ContentSort.newest,
                        label: Text("Newest"),
                        icon: Icon(Icons.fiber_new_outlined)),
                    ButtonSegment(
                        value: ContentSort.topRated,
                        label: Text("Top"),
                        icon: Icon(Icons.star_rate_outlined)),
                    ButtonSegment(
                        value: ContentSort.mostViewed,
                        label: Text("Views"),
                        icon: Icon(Icons.visibility_outlined)),
                  ],
                  selected: {_sort},
                  onSelectionChanged: (s) {
                    setState(() => _sort = s.first);
                    _applyFilterAndSort();
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _posting ? null : _submitPost,
                icon: _posting
                    ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(_posting ? "Posting…" : "Post"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPost() async {
    final text = _composer.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Write something first")));
      return;
    }
    setState(() => _posting = true);

    try {
      final payload = {
        "type": "story", // tweet-like
        "title": _autoTitleFrom(text),
        "summary": "",
        "body": text,
        "evidence": "n_a",
        "visibility": "public",
        "language": "tr",
        "tags": _composerTags,
        "sources": [],
      };
      final id = await api.createContent(payload);
      if (id != null) {
        _composer.clear();
        _composerTags.clear();
        // Reload feed; optionally, prepend optimistically
        await _load(initial: false);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Posted")));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Post failed")));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  // --- Item (tweet) ---------------------------------------------------------

  Widget _contentCard(Map<String, dynamic> x) {
    final id = x['id']?.toString() ?? '';
    final type = (x['type'] ?? '') as String;
    final title = (x['title'] ?? '') as String;
    final body = (x['body'] ?? '') as String? ?? '';
    final createdAt = x['created_at'] as String?;
    final tags = (x['tags'] as List?)?.cast<String>() ?? const <String>[];
    final user = (x['owner_username'] ?? '') as String? ?? '';
    final views = x['views'] as int?;
    final avgStars = (x['avg_stars'] is num) ? (x['avg_stars'] as num).toDouble() : null;
    final ratingsCount =
    (x['ratings_count'] is num) ? (x['ratings_count'] as num).toInt() : null;

    // Optional image cover from sources
    String? cover;
    final sources = x['sources'];
    if (sources is List && sources.isNotEmpty) {
      final first = sources.first;
      if (first is Map && (first['kind'] == 'image') && first['url'] is String) {
        cover = first['url'] as String;
      }
    }

    // Replies (if backend already returns them inside list):
    // We treat anything with parent_id == id as a reply; this works
    // if your API returns comments in the same list. If not, the inline
    // replies will still work for new comments we post (optimistic),
    // and you can wire a dedicated endpoint later.
    final replies = _all
        .where((e) => (e['parent_id']?.toString() ?? '') == id)
        .toList()
      ..sort((a, b) =>
          ((a['created_at'] ?? '') as String).compareTo((b['created_at'] ?? '') as String));

    _replyCtrls.putIfAbsent(id, () => TextEditingController());

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: avatar + name + time
            Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  child: Icon(Icons.person, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user.isEmpty ? "member" : user,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  _fromNow(createdAt),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),

            if (body.isNotEmpty)
              Text(
                body,
                style: const TextStyle(height: 1.35, fontSize: 14.5),
              ),

            if (cover != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(cover, fit: BoxFit.cover),
                ),
              ),
            ],

            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: -6,
                children: [
                  for (final t in tags)
                    ActionChip(
                      label: Text(t),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        _q.text = t;
                        _applyFilterAndSort();
                      },
                    ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Action row: views • stars • reply • share
            Row(
              children: [
                if (views != null) ...[
                  const Icon(Icons.visibility_outlined, size: 18),
                  const SizedBox(width: 4),
                  Text(views.toString()),
                  const SizedBox(width: 12),
                ],
                if (avgStars != null && ratingsCount != null) ...[
                  const Icon(Icons.star_rate_rounded, size: 18),
                  const SizedBox(width: 4),
                  Text("${avgStars.toStringAsFixed(1)} ($ratingsCount)"),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      await api.rate('content', id, 5); // quick-like as ★5
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Thanks for the like!")),
                        );
                        _load(initial: false);
                      }
                    },
                    child: const Text("Like"),
                  ),
                ] else
                  TextButton(
                    onPressed: () async {
                      await api.rate('content', id, 5);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Thanks for the like!")),
                        );
                        _load(initial: false);
                      }
                    },
                    child: const Text("Like"),
                  ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.mode_comment_outlined, size: 18),
                  label: Text("Replies (${replies.length})"),
                  onPressed: () async {
                    // focus reply box
                    await Future<void>.delayed(const Duration(milliseconds: 50));
                    final c = _replyCtrls[id]!;
                    if (c.text.isEmpty) c.text = "";
                    setState(() {}); // ensure reply box visible (we show it always below)
                  },
                ),
                IconButton(
                  tooltip: "Copy link",
                  icon: const Icon(Icons.link),
                  onPressed: () async {
                    await api.addView('content', id); // best-effort
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Link copied (TODO deep link)")),
                    );
                  },
                ),
              ],
            ),

            // Replies list (simple thread)
            if (replies.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final r in replies)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.subdirectory_arrow_right, size: 18),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (r['owner_username'] ?? 'member').toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (r['body'] ?? '').toString(),
                              style: const TextStyle(fontSize: 13.5, height: 1.35),
                            ),
                            Text(
                              _fromNow(r['created_at']?.toString()),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            // Reply composer
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyCtrls[id],
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Reply to ${user.isEmpty ? 'this post' : user}…",
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _replying.contains(id)
                      ? null
                      : () => _submitReply(parentId: id),
                  child:
                  Text(_replying.contains(id) ? "..." : "Reply", style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReply({required String parentId}) async {
    final c = _replyCtrls[parentId]!;
    final text = c.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Write a reply first")));
      return;
    }

    setState(() => _replying.add(parentId));
    try {
      final payload = {
        "type": "comment",
        "title": "",
        "summary": "",
        "body": text,
        "evidence": "n_a",
        "visibility": "public",
        "language": "tr",
        "tags": [],
        "sources": [],
        "parent_id": parentId, // ← backend: store as foreign key to content.id
      };
      final id = await api.createContent(payload);
      if (id != null) {
        // Optimistically add to local list so thread shows instantly
        _all.add({
          "id": id,
          "type": "comment",
          "title": "",
          "summary": "",
          "body": text,
          "parent_id": parentId,
          "owner_username": "you",
          "created_at": DateTime.now().toUtc().toIso8601String(),
          "tags": const [],
          "sources": const [],
        });
        c.clear();
        _applyFilterAndSort();
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Replied")));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Reply failed")));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _replying.remove(parentId));
    }
  }

  // --- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const AppScaffold(title: "Community", body: Loading());
    }
    if (_error != null) {
      return AppScaffold(
        title: "Community",
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text("Error: $_error"),
          ),
        ),
      );
    }

    return AppScaffold(
      title: "Community",
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: _items.isEmpty ? 2 : _items.length + 1,
          itemBuilder: (ctx, i) {
            if (i == 0) return _composerBox();
            if (_refreshing) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: LinearProgressIndicator(minHeight: 2),
              );
            }
            if (_items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Empty("No posts yet. Be the first to share something!"),
              );
            }
            return _contentCard(_items[i - 1]);
          },
        ),
      ),
    );
  }
}
