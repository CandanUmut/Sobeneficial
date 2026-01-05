import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});
  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // raw list from API (normalized to proper Map<String,dynamic>)
  List<Map<String, dynamic>> _all = [];
  // filtered view for UI
  List<Map<String, dynamic>> _items = [];

  // ui state
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  // filters
  final _q = TextEditingController();
  String? _typeFilter; // webinar / workshop / ...
  bool _onlyUpcoming = true;
  Timer? _debounce;

  // optimistic enroll memory
  final Set<String> _enrolled = {};

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
      final res = await api.listEvents();
      // api.listEvents() should return List<dynamic>
      // We normalize so JS runtimes don't explode with LinkedMap.
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
    final query = _q.text.trim().toLowerCase();
    final tFilter = _typeFilter;
    final upcomingOnly = _onlyUpcoming;

    final now = DateTime.now();

    final filtered = _all.where((ev) {
      // text search
      final title = (ev['title'] ?? '').toString().toLowerCase();
      final desc = (ev['description'] ?? '').toString().toLowerCase();
      final loc = (ev['location'] ?? '').toString().toLowerCase();
      final matchText = query.isEmpty ||
          title.contains(query) ||
          desc.contains(query) ||
          loc.contains(query);

      // type filter
      if (tFilter != null && tFilter.isNotEmpty) {
        final et = (ev['type'] ?? '').toString();
        if (et != tFilter) return false;
      }

      // upcoming filter
      if (upcomingOnly) {
        final startsIso = ev['starts_at']?.toString();
        if (startsIso != null) {
          final dt = DateTime.tryParse(startsIso);
          if (dt != null && dt.isBefore(now)) {
            return false;
          }
        }
      }

      return matchText;
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

  // Try to join / enroll for an event
  Future<void> _joinEvent(Map<String, dynamic> ev) async {
    final id = ev['id']?.toString();
    if (id == null) return;
    if (_enrolled.contains(id)) return; // already joined locally

    // optimistic lock
    setState(() {
      _enrolled.add(id);
    });

    final ok = await api.enrollEvent(id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You're in (if seats available)!")),
      );
    } else {
      // rollback
      setState(() {
        _enrolled.remove(id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't enroll")),
      );
    }
  }

  // Human-friendly time range / date chip
  Widget _whenChip(Map<String, dynamic> ev) {
    final raw = ev['starts_at']?.toString() ?? "";
    final dt = DateTime.tryParse(raw);
    if (dt == null) {
      return Chip(
        label: Text("When: TBA"),
        visualDensity: VisualDensity.compact,
      );
    }
    final local = dt.toLocal();
    final datePart =
        "${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}";
    final timePart =
        "${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: const Icon(Icons.schedule, size: 16),
      label: Text("$datePart • $timePart"),
    );
  }

  String _capacityText(Map<String, dynamic> ev) {
    final cap = ev['capacity'];
    final current = ev['enrolled_count'];
    if (cap == null) return "No limit";
    final capNum = (cap is num) ? cap.toInt() : int.tryParse("$cap");
    final curNum =
    (current is num) ? current.toInt() : int.tryParse("$current") ?? 0;
    if (capNum == null) {
      return "No limit (${curNum} joined)";
    }
    final left = capNum - curNum;
    return left > 0
        ? "$curNum / $capNum seats • $left left"
        : "$curNum / $capNum seats • full";
  }

  // single event card
  Widget _eventCard(Map<String, dynamic> ev) {
    final id = ev['id']?.toString() ?? '';
    final title = (ev['title'] ?? '') as String;
    final desc = (ev['description'] ?? '') as String? ?? '';
    final kind = (ev['type'] ?? '') as String? ?? 'event';
    final where = (ev['location'] ?? '') as String? ?? '';
    final tags = (ev['tags'] as List?)
        ?.map((e) => e.toString())
        .toList() ??
        const <String>[];

    final isPast = () {
      final raw = ev['starts_at']?.toString();
      final dt = raw == null ? null : DateTime.tryParse(raw);
      if (dt == null) return false;
      return dt.isBefore(DateTime.now());
    }();

    final full = _capacityText(ev).contains("full");
    final already = _enrolled.contains(id);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: type + join button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // left side info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // title
                      Text(
                        title.isEmpty ? "(untitled)" : title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // kind + capacity
                      Row(
                        children: [
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar:
                            const Icon(Icons.category_outlined, size: 16),
                            label: Text(kind),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.people_outline, size: 16),
                            label: Text(_capacityText(ev)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // date/time chip
                      _whenChip(ev),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // CTA button
                FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: (isPast || full || already)
                      ? null
                      : () => _joinEvent(ev),
                  child: Text(
                    isPast
                        ? "Ended"
                        : full
                        ? "Full"
                        : already
                        ? "Joined"
                        : "Join",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Description
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

            // Where / location line
            if (where.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      where,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),

            if (where.isNotEmpty) const SizedBox(height: 12),

            // tags row
            if (tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: -6,
                children: [
                  for (final t in tags)
                    Chip(
                      label: Text(
                        t,
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      labelPadding:
                      const EdgeInsets.symmetric(horizontal: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // top search bar
  Widget _searchBar() {
    return TextField(
      controller: _q,
      decoration: InputDecoration(
        hintText: "Search events, topics, or location…",
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onChanged: _debouncedSearch,
    );
  }

  // filter row: type dropdown + upcoming toggle
  Widget _filterRow() {
    // gather distinct event types from _all
    final types = <String>{};
    for (final e in _all) {
      final t = (e['type'] ?? '').toString();
      if (t.isNotEmpty) types.add(t);
    }
    final typeList = types.toList()..sort();

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // type filter
        DropdownButton<String>(
          value: _typeFilter,
          hint: const Text("Any Type"),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text("Any Type"),
            ),
            for (final t in typeList)
              DropdownMenuItem(
                value: t,
                child: Text(t),
              ),
          ],
          onChanged: (v) {
            setState(() {
              _typeFilter = v;
            });
            _applyFilters();
          },
        ),

        // upcoming toggle
        FilterChip(
          label: const Text("Upcoming only"),
          selected: _onlyUpcoming,
          onSelected: (v) {
            setState(() {
              _onlyUpcoming = v;
            });
            _applyFilters();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const AppScaffold(
        title: "Events",
        body: Loading(),
      );
    }

    if (_error != null) {
      return AppScaffold(
        title: "Events",
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text("Error loading events:\n$_error"),
          ),
        ),
      );
    }

    return AppScaffold(
      title: "Events",
      body: RefreshIndicator(
        onRefresh: () => _load(initial: false),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _searchBar(),
            const SizedBox(height: 12),
            _filterRow(),
            const SizedBox(height: 12),

            if (_refreshing)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),

            if (_items.isEmpty)
              const Empty(
                "No events match your filters.\nCheck back later or clear filters.",
              )
            else
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final ev = _items[i];
                  return _eventCard(ev);
                },
              ),

            const SizedBox(height: 24),
            Center(
              child: Text(
                "We host learning spaces, not doomscroll pits.\nBe kind, be safe, help each other. 💚",
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
