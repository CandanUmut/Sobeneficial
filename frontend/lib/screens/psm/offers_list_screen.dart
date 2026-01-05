// lib/screens/psm/offers_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../widgets/common.dart';

class OffersListScreen extends StatefulWidget {
  const OffersListScreen({super.key});
  @override
  State<OffersListScreen> createState() => _OffersListScreenState();
}

class _OffersListScreenState extends State<OffersListScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _q = TextEditingController();
  final _scroll = ScrollController();

  // filters
  String? _type, _fee, _region, _lang, _tag;
  String _sort = 'new';
  bool _onlySponsored = false; // “With sponsor seats” toggle

  // paging
  int _page = 1;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  String? _error;

  Map<String, dynamic> _data = {
    "items": <Map<String, dynamic>>[],
    "page": 1,
    "page_size": 20,
    "total": 0
  };

  // per-offer inline calendar / hours state
  // selected day key per offer (YYYY-MM-DD) and cached week fetch
  final Map<String, String?> _expandedDayKey = {};
  final Map<String, DateTime> _weekStart = {}; // Monday (local) for each offer’s current window
  final Map<String, Future<List<Map<String, dynamic>>>?> _weekFuture = {};

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _q.dispose();
    super.dispose();
  }

  // ---------------- helpers ----------------

  void _maybeLoadMore() {
    if (_loadingMore || _loadingInitial) return;
    final max = _scroll.position.maxScrollExtent;
    final pos = _scroll.position.pixels;
    if (pos >= max - 200) _loadMore();
  }

  void _debouncedSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _load(reset: true);
    });
  }

  void _applyTag(String tag) {
    setState(() => _tag = tag);
    _load(reset: true);
  }

  void _applyQuickType(String? t) {
    setState(() => _type = t);
    _load(reset: true);
  }

  String _hm(DateTime dt) {
    final h = dt.toLocal().hour.toString().padLeft(2, '0');
    final m = dt.toLocal().minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  String _dateYMD(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _dayKey(DateTime d) => _dateYMD(d); // local date

  DateTime _mondayOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  void _ensureWeekLoaded(Map offer, {int deltaWeeks = 0}) {
    final id = offer['id'].toString();
    final start = _weekStart[id] ?? _mondayOf(DateTime.now());
    final newStart = _mondayOf(start.add(Duration(days: 7 * deltaWeeks)));
    _weekStart[id] = DateTime(newStart.year, newStart.month, newStart.day); // strip time

    // fetch 14 days (current + next week) for smooth paging; UI shows 7 at a time
    final from = _dateYMD(_weekStart[id]!);
    final to = _dateYMD(_weekStart[id]!.add(const Duration(days: 14)));
    _weekFuture[id] = api.listOfferSlots(id, fromIso: from, toIso: to);

    // collapse previously expanded day when paging
    _expandedDayKey[id] = null;
  }

  Map<String, List<Map<String, dynamic>>> _groupSlotsByDay(List<Map<String, dynamic>> slots) {
    // group *unique* open slots by YYYY-MM-DD (local)
    final byDay = <String, List<Map<String, dynamic>>>{};
    final seen = <String>{};

    for (final s in slots) {
      final stIso = (s['start_at'] ?? '').toString();
      final enIso = (s['end_at'] ?? '').toString();
      final id = (s['id']?.toString() ?? '');
      final dedupeKey = id.isNotEmpty ? id : '$stIso|$enIso';

      // keep only open & not full
      final status = (s['status'] ?? 'open').toString();
      final cap = (s['capacity'] as num?)?.toInt() ?? 1;
      final res = (s['reserved'] as num?)?.toInt() ?? 0;
      if (status != 'open' || res >= cap) continue;

      if (!seen.add(dedupeKey)) continue; // de-dupe

      final st = DateTime.tryParse(stIso);
      if (st == null) continue;
      final key = _dayKey(st.toLocal());
      (byDay[key] ??= []).add(s);
    }

    // sort each day’s slots by start_at
    for (final list in byDay.values) {
      list.sort((a, b) => (a['start_at'] as String).compareTo(b['start_at'] as String));
    }
    return byDay;
  }

  Future<void> _openGiftDialog(Map offer) async {
    final offerId = offer['id'].toString();
    final title = (offer['title'] ?? '') as String;

    int available = 0;
    bool loading = true;
    bool posting = false;

    final unitsCtrl = TextEditingController(text: '1');
    final noteCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: !posting,
      builder: (ctx) {
        if (loading) {
          api.giftStats(offerId).then((m) {
            if (!mounted) return;
            available = (m['available'] as num?)?.toInt() ?? 0;
            loading = false;
            (ctx as Element).markNeedsBuild();
          });
        }

        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text("Sponsor a session"),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    loading
                        ? const LinearProgressIndicator()
                        : Text("Currently available sponsored seats: $available"),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "How many seats to sponsor?",
                        hintText: "e.g., 1",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: "Note (optional)",
                        hintText: "Shown to the recipient(s)",
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: posting ? null : () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                FilledButton.icon(
                  onPressed: (posting || loading)
                      ? null
                      : () async {
                    final u = int.tryParse(unitsCtrl.text.trim());
                    if (u == null || u <= 0) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter a valid positive number.")),
                      );
                      return;
                    }
                    setState(() => posting = true);
                    final ok = await api.createGift(
                      offerId: offerId,
                      units: u,
                      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                    );
                    setState(() => posting = false);
                    if (!mounted) return;

                    if (ok) {
                      Navigator.pop(ctx, true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Sponsoring failed. Please try again.")),
                      );
                    }
                  },
                  icon: posting
                      ? const SizedBox.square(
                      dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.volunteer_activism_outlined),
                  label: const Text("Confirm"),
                ),
              ],
            );
          },
        );
      },
    ).then((created) async {
      if (created == true && mounted) {
        await _load(reset: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Thanks! Your sponsored seat(s) are now available.")),
        );
      }
    });
  }

  // ---------------- Data loading ----------------

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _error = null;
      if (reset) {
        _page = 1;
        _loadingInitial = true;
      }
    });

    try {
      // Ask for more inline slots so we can highlight multiple days on each card
      final res = await api.listOffersWithNextSlots(
        q: _q.text.trim().isEmpty ? null : _q.text.trim(),
        type: _type,
        tag: _tag,
        fee: _fee,
        region: _region,
        lang: _lang,
        page: _page,
        pageSize: 20,
        sort: _sort,
        limitSlots: 12, // gives enough variety across days
      );

      // Optionally filter client-side for “only sponsored”
      Map<String, dynamic> next = res;
      if (_onlySponsored) {
        final items = (res['items'] as List? ?? const [])
            .where((e) => ((e as Map)['gifts_available'] as num? ?? 0) > 0)
            .toList();
        next = {
          ...res,
          'items': items,
          'page': _page,
          'total': items.length, // reflect filtered count
        };
      }

      setState(() {
        if (_page == 1) {
          _data = next;
          _expandedDayKey.clear();
          _weekStart.clear();
          _weekFuture.clear();
        } else {
          final merged = [
            ...(_data["items"] as List),
            ...(next["items"] as List),
          ];
          _data = {...next, "items": merged, "page": _page};
        }
      });
    } catch (e) {
      // Fallback to legacy list if needed
      try {
        final res = await api.listOffers(
          q: _q.text.trim().isEmpty ? null : _q.text.trim(),
          type: _type,
          tag: _tag,
          fee: _fee,
          region: _region,
          lang: _lang,
          page: _page,
          pageSize: 20,
          sort: _sort,
        );
        Map<String, dynamic> next = res;
        if (_onlySponsored) {
          final items = (res['items'] as List? ?? const [])
              .where((e) => ((e as Map)['gifts_available'] as num? ?? 0) > 0)
              .toList();
          next = {...res, 'items': items, 'page': _page, 'total': items.length};
        }
        setState(() {
          if (_page == 1) {
            _data = next;
            _expandedDayKey.clear();
            _weekStart.clear();
            _weekFuture.clear();
          } else {
            final merged = [
              ...(_data["items"] as List),
              ...(next["items"] as List),
            ];
            _data = {...next, "items": merged, "page": _page};
          }
        });
      } catch (e2) {
        setState(() => _error = e2.toString());
      }
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final total = _data["total"] as int? ?? 0;
    final items = (_data["items"] as List?)?.length ?? 0;
    if (items >= total) return;

    setState(() => _loadingMore = true);
    _page += 1;
    await _load();
    if (mounted) setState(() => _loadingMore = false);
  }

  // ---------------- Widgets ----------------

  Widget _quickTypeChips() {
    final types = <(String? value, String label, IconData icon)>[
      (null, "All", Icons.all_inclusive),
      ("legal", "Legal", Icons.gavel_outlined),
      ("psychological", "Psych", Icons.psychology_alt_outlined),
      ("career", "Career", Icons.work_outline),
      ("it", "IT", Icons.memory_outlined),
      ("finance", "Finance", Icons.attach_money_outlined),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          for (final t in types)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.$3, size: 16),
                    const SizedBox(width: 6),
                    Text(t.$2),
                  ],
                ),
                selected: _type == t.$1,
                onSelected: (_) => _applyQuickType(t.$1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filters(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: _q,
            decoration: InputDecoration(
              hintText: "Search offers…",
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: _debouncedSearch,
            onSubmitted: (_) => _load(reset: true),
          ),
        ),
        DropdownButton<String>(
          value: _type,
          hint: const Text("Type"),
          items: const [
            DropdownMenuItem(value: "legal", child: Text("Legal")),
            DropdownMenuItem(value: "psychological", child: Text("Psychological")),
            DropdownMenuItem(value: "career", child: Text("Career")),
            DropdownMenuItem(value: "it", child: Text("IT Counseling")),
            DropdownMenuItem(value: "finance", child: Text("Finance Counseling")),
            DropdownMenuItem(value: "other", child: Text("Other")),
          ],
          onChanged: (v) => setState(() {
            _type = v;
            _load(reset: true);
          }),
        ),
        DropdownButton<String>(
          value: _fee,
          hint: const Text("Fee"),
          items: const [
            DropdownMenuItem(value: "free", child: Text("Free")),
            DropdownMenuItem(value: "paid", child: Text("Paid")),
            DropdownMenuItem(value: "sliding", child: Text("Sliding")),
          ],
          onChanged: (v) => setState(() {
            _fee = v;
            _load(reset: true);
          }),
        ),
        DropdownButton<String>(
          value: _lang,
          hint: const Text("Language"),
          items: const [
            DropdownMenuItem(value: "en", child: Text("English")),
            DropdownMenuItem(value: "tr", child: Text("Turkish")),
          ],
          onChanged: (v) => setState(() {
            _lang = v;
            _load(reset: true);
          }),
        ),
        DropdownButton<String>(
          value: _sort,
          items: const [
            DropdownMenuItem(value: "new", child: Text("Newest")),
            DropdownMenuItem(value: "rating", child: Text("Top Rated")),
            DropdownMenuItem(value: "popular", child: Text("Popular")),
          ],
          onChanged: (v) => setState(() {
            _sort = v ?? 'new';
            _load(reset: true);
          }),
        ),
        FilterChip(
          label: const Text("With sponsor seats"),
          selected: _onlySponsored,
          onSelected: (v) {
            setState(() => _onlySponsored = v);
            _load(reset: true);
          },
        ),
        if (_tag != null)
          InputChip(
            label: Text("tag: $_tag"),
            onDeleted: () {
              setState(() => _tag = null);
              _load(reset: true);
            },
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  // WEEK PAGER + DAY CHIPS + COUNTS
  Widget _offerDateStrip(Map offer) {
    final id = offer['id'].toString();

    // Kick off the initial week load (safe inside build via post-frame)
    if (_weekFuture[id] == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _ensureWeekLoaded(offer));
      });
    }

    final selectedKey = _expandedDayKey[id];
    String dow(DateTime d) => const ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][d.weekday - 1];

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _weekFuture[id],
        builder: (ctx, snap) {
          final loading = snap.connectionState == ConnectionState.waiting;
          final error = snap.hasError;
          final data = snap.data ?? const <Map<String, dynamic>>[];
          final start = _weekStart[id] ?? _mondayOf(DateTime.now());
          final dayKeys = List.generate(7, (i) => _dayKey(start.add(Duration(days: i))));

          // Build counts of open slots per day
          final byDay = _groupSlotsByDay(data);
          final counts = {for (final k in dayKeys) k: (byDay[k]?.length ?? 0)};

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: "Previous week",
                    icon: const Icon(Icons.chevron_left),
                    onPressed: loading ? null : () => setState(() => _ensureWeekLoaded(offer, deltaWeeks: -1)),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (int i = 0; i < 7; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Builder(builder: (_) {
                                final d = start.add(Duration(days: i));
                                final key = _dayKey(d);
                                final count = counts[key] ?? 0;
                                final selected = selectedKey == key;
                                final disabled = !loading && count == 0;

                                return ChoiceChip(
                                  selected: selected,
                                  onSelected: disabled
                                      ? null
                                      : (_) => setState(() => _expandedDayKey[id] = key),
                                  label: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(dow(d), style: const TextStyle(fontSize: 11)),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text("${d.day}", style: const TextStyle(fontWeight: FontWeight.w600)),
                                          const SizedBox(width: 4),
                                          if (!loading && count > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(10),
                                                color: Colors.green.withOpacity(.12),
                                              ),
                                              child: Text("$count", style: const TextStyle(fontSize: 11)),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: "Next week",
                    icon: const Icon(Icons.chevron_right),
                    onPressed: loading ? null : () => setState(() => _ensureWeekLoaded(offer, deltaWeeks: 1)),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    onPressed: () =>
                        context.pushNamed('psm_offer_detail', pathParameters: {'id': id}),
                    child: const Text("All times"),
                  ),
                ],
              ),
              if (loading) const LinearProgressIndicator(),
              if (error) const Text("Couldn’t load times right now."),
            ],
          );
        },
      ),
    );
  }

  // HOURS EXPANDER (uses week cache + dedupe)
  Widget _offerHoursExpander(Map offer) {
    final id = offer['id'].toString();
    final selectedKey = _expandedDayKey[id];
    final future = _weekFuture[id];
    if (selectedKey == null || future == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator();
          }
          final data = snap.data ?? const <Map<String, dynamic>>[];
          final byDay = _groupSlotsByDay(data);
          final slots = byDay[selectedKey] ?? const <Map<String, dynamic>>[];

          if (slots.isEmpty) {
            return const Text("No open times for this day.");
          }

          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in slots)
                InputChip(
                  label: Text(() {
                    final st = DateTime.tryParse((s["start_at"] ?? "").toString());
                    final en = DateTime.tryParse((s["end_at"] ?? "").toString());
                    if (st == null || en == null) return "—";
                    return "${_hm(st)}–${_hm(en)}";
                  }()),
                  onPressed: () => context.pushNamed('psm_offer_detail', pathParameters: {'id': id}),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _ownerRow(Map o) {
    final owner = (o["owner_username"] ?? "") as String;
    final ownerId = (o["owner_id"]?.toString() ?? "");
    final navKey = ownerId.isNotEmpty ? ownerId : (owner.isNotEmpty ? owner : "");
    if (navKey.isEmpty) {
      return Row(children: const [
        CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
        SizedBox(width: 6),
        Text("practitioner"),
      ]);
    }
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.pushNamed('profile', pathParameters: {'id': navKey}),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
          SizedBox(width: 6),
          // Name text inserted by parent (we keep icon layout tight)
        ],
      ),
    );
  }

  Widget _card(Map o) {
    final id = o["id"].toString();
    final title = (o["title"] ?? "") as String;
    final owner = (o["owner_username"] ?? "") as String;
    final fee = (o["fee_type"] ?? "") as String;
    final tags = (o["tags"] as List?)?.cast<String>() ?? const <String>[];
    final langs = (o["languages"] as List?)?.cast<String>() ?? const <String>[];
    final region = (o["region"] ?? "") as String;
    final avg = (o["avg_stars"] is num) ? (o["avg_stars"] as num).toDouble() : 0.0;
    final count = (o["ratings_count"] as num?)?.toInt() ?? 0;
    final views = (o["views"] as num?)?.toInt() ?? 0;
    final donated = (o["gifts_available"] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.pushNamed('psm_offer_detail', pathParameters: {'id': id}),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.verified_user_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Chip(label: Text(fee), visualDensity: VisualDensity.compact),
              const SizedBox(width: 6),
              if (donated > 0)
                Tooltip(
                  message: "Sponsored seats available",
                  child: Chip(
                    avatar: const Icon(Icons.favorite_outline, size: 16),
                    label: Text("$donated"),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            if (region.isNotEmpty || langs.isNotEmpty)
              Wrap(spacing: 6, runSpacing: -6, children: [
                if (region.isNotEmpty) Chip(label: Text(region), visualDensity: VisualDensity.compact),
                for (final l in langs) Chip(label: Text(l), visualDensity: VisualDensity.compact),
              ]),
            if (region.isNotEmpty || langs.isNotEmpty) const SizedBox(height: 6),
            if (tags.isNotEmpty)
              Wrap(spacing: 6, runSpacing: -6, children: [
                for (final t in tags)
                  ActionChip(label: Text(t), onPressed: () => _applyTag(t), visualDensity: VisualDensity.compact),
              ]),

            // >>> Calendar strip + hours (demo-ready)
            _offerDateStrip(o),
            _offerHoursExpander(o),

            const SizedBox(height: 8),
            Row(children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final ownerId = (o["owner_id"]?.toString() ?? "");
                        final navKey = ownerId.isNotEmpty
                            ? ownerId
                            : ((o["owner_username"]?.toString() ?? "").isNotEmpty
                            ? o["owner_username"].toString()
                            : "");
                        if (navKey.isNotEmpty) {
                          context.pushNamed('profile', pathParameters: {'id': navKey});
                        }
                      },
                      child: Text(owner.isEmpty ? "practitioner" : owner,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  if ((o["owner_id"]?.toString() ?? "").isNotEmpty ||
                      (o["owner_username"]?.toString() ?? "").isNotEmpty) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.open_in_new, size: 14),
                  ],
                ],
              ),
              const Spacer(),
              const Icon(Icons.remove_red_eye_outlined, size: 18),
              const SizedBox(width: 4),
              Text("$views"),
              const SizedBox(width: 10),
              const Icon(Icons.star_rate_rounded, size: 18),
              const SizedBox(width: 4),
              Text("${avg.toStringAsFixed(1)} ($count)"),
            ]),
            if (donated > 0) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _openGiftDialog(o),
                  icon: const Icon(Icons.volunteer_activism_outlined),
                  label: const Text("Gift support"),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final items = (_data["items"] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final total = (_data["total"] as num?)?.toInt() ?? 0;

    return AppScaffold(
      title: "Counseling Offers",
      actions: [
        IconButton(
          tooltip: "My Requests",
          icon: const Icon(Icons.inbox_outlined),
          onPressed: () => context.pushNamed('psm_requests'),
        ),
        IconButton(
          tooltip: "Create Offer",
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => context.pushNamed('psm_offer_new'),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loadingInitial
              ? const Loading()
              : _error != null
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Error: $_error"),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _load(reset: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                ),
              ],
            ),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _quickTypeChips(),
              const SizedBox(height: 8),
              _filters(context),
              const SizedBox(height: 8),
              if (total > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    "$total result${total == 1 ? '' : 's'}",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              Expanded(
                child: items.isEmpty
                    ? const Empty("No offers found")
                    : ListView.builder(
                  controller: _scroll,
                  itemCount: items.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(8),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _card(items[i]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
