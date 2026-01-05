import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({super.key});
  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // raw data from API (normalized to List<Map<String,dynamic>>)
  List<Map<String, dynamic>> _all = [];
  // filtered view
  List<Map<String, dynamic>> _items = [];

  // ui state
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  // local apply memory so we can instantly reflect "Applied"
  final Set<String> _applied = {};

  // filters
  final _q = TextEditingController();
  String? _activeTag;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

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
      final res = await api.listProjects();
      // api.listProjects() is expected to return a List<dynamic> of maps.
      // We normalize for web so we don't get LinkedMap type errors.
      final normalized = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      _all = normalized;
      _applyFilters();
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

  void _applyFilters() {
    final text = _q.text.trim().toLowerCase();
    final tag = _activeTag;

    final filtered = _all.where((proj) {
      // text match in title or description
      final title = (proj['title'] ?? '').toString().toLowerCase();
      final desc = (proj['description'] ?? '').toString().toLowerCase();
      final matchText = text.isEmpty || title.contains(text) || desc.contains(text);

      // tag filter
      if (tag == null) return matchText;
      final tagsList = (proj['tags'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          const <String>[];
      final matchTag = tagsList.contains(tag);
      return matchText && matchTag;
    }).toList();

    setState(() {
      _items = filtered;
    });
  }

  void _debouncedSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _applyFilters();
    });
  }

  Future<void> _applyToProject(Map<String, dynamic> proj) async {
    final id = proj['id']?.toString();
    if (id == null) return;
    if (_applied.contains(id)) return;

    // optimistic lock
    setState(() {
      _applied.add(id);
    });

    final ok = await api.applyProject(id, "Interested!");
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Applied (if recruiting)")),
      );
    } else {
      // revert if backend rejected
      setState(() {
        _applied.remove(id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not apply")),
      );
    }
  }

  // build pills row of unique tags from _all
  Widget _tagsRow() {
    // grab all unique tags
    final tags = <String>{};
    for (final p in _all) {
      final list = (p['tags'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          const <String>[];
      tags.addAll(list);
    }
    final tagList = tags.toList()..sort();

    if (tagList.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: 4),
          for (final t in tagList)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(t),
                selected: _activeTag == t,
                onSelected: (sel) {
                  setState(() {
                    _activeTag = sel ? t : null;
                  });
                  _applyFilters();
                },
              ),
            ),
        ],
      ),
    );
  }

  // individual project card
  Widget _projectCard(Map<String, dynamic> p) {
    final id = p['id']?.toString() ?? '';
    final title = (p['title'] ?? '') as String;
    final desc = (p['description'] ?? '') as String? ?? '';
    final owner = (p['owner_username'] ?? '') as String? ?? 'unknown';
    final createdAt = p['created_at']?.toString() ?? '';
    final roles = (p['needed_roles'] as List?)
        ?.map((e) => e.toString())
        .toList() ??
        const <String>[];
    final tags = (p['tags'] as List?)
        ?.map((e) => e.toString())
        .toList() ??
        const <String>[];

    // some heuristics for "is it still open"
    final isOpen = (p['visibility'] ?? 'public') == 'public' &&
        (p['status'] ?? 'open') != 'closed';

    final appliedAlready = _applied.contains(id);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header row: avatar + title + call to action
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  child: Text(
                    owner.isNotEmpty ? owner[0].toUpperCase() : "?",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? "(untitled project)" : title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "by $owner",
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        createdAt.isEmpty ? "" : "posted $createdAt",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: (!isOpen || appliedAlready)
                      ? null
                      : () => _applyToProject(p),
                  child: Text(
                    !isOpen
                        ? "Closed"
                        : appliedAlready
                        ? "Applied"
                        : "I'm in",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // description
            if (desc.isNotEmpty)
              Text(
                desc,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade900,
                  height: 1.4,
                ),
              ),

            if (desc.isNotEmpty) const SizedBox(height: 12),

            // roles row
            if (roles.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.group_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: -6,
                      children: [
                        for (final r in roles)
                          Chip(
                            label: Text(
                              r,
                              style: const TextStyle(fontSize: 12),
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                            padding:
                            const EdgeInsets.symmetric(horizontal: 6),
                            labelPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // tags row
            if (tags.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sell_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: -6,
                      children: [
                        for (final t in tags)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeTag = t;
                              });
                              _applyFilters();
                            },
                            child: Chip(
                              label: Text(
                                t,
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor:
                              Colors.blueGrey.withOpacity(.08),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                              padding:
                              const EdgeInsets.symmetric(horizontal: 6),
                              labelPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: _q,
      decoration: InputDecoration(
        hintText: "Search projects or ideas…",
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onChanged: _debouncedSearch,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const AppScaffold(title: "Projects", body: Loading());
    }

    if (_error != null) {
      return AppScaffold(
        title: "Projects",
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text("Error loading projects:\n$_error"),
          ),
        ),
      );
    }

    return AppScaffold(
      title: "Projects",
      body: RefreshIndicator(
        onRefresh: () => _load(initial: false),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // search + filters
            _searchBar(),
            const SizedBox(height: 12),
            _tagsRow(),
            const SizedBox(height: 12),

            if (_refreshing)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),

            if (_items.isEmpty)
              const Empty(
                "Nothing matches yet.\nTry clearing filters or check back soon.",
              )
            else
            // list of cards
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final p = _items[i];
                  return _projectCard(p);
                },
              ),

            const SizedBox(height: 24),
            Center(
              child: Text(
                "Projects are community-led. Be kind. Be reliable. 💚",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
