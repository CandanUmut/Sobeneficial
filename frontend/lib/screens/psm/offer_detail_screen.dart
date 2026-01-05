import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../widgets/common.dart';
import 'request_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfferDetailScreen extends StatefulWidget {
  final String id;
  const OfferDetailScreen({super.key, required this.id});

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic>? _offer;
  List<Map<String, dynamic>> _related = const [];
  bool _loading = true;
  String? _error;

  // Supabase
  final _supabase = Supabase.instance.client;
  bool get _isSignedIn => _supabase.auth.currentSession != null;

  // Gifts
  Future<Map<String, dynamic>>? _giftStatsF;
  bool _gifting = false;

  // AI bottom sheet state
  bool _aiLoading = false;
  Map<String, dynamic>? _ai;

  // local rating UI
  bool _ratingInFlight = false;

  // Slots
  Future<List<Map<String, dynamic>>>? _slotsF;

  // NEW — calendar state
  DateTime _calendarStart = DateTime.now();
  DateTime? _selectedDay; // null => show all; non-null => filter to that day
  final int _calendarDays = 14; // two weeks scroller

  // NEW — reviews state
  Future<List<Map<String, dynamic>>>? _reviewsF;
  String? _eligibleEngagementId; // keep null unless you wire eligibility

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(_calendarStart.year, _calendarStart.month, _calendarStart.day);
    _load(initial: true);
  }

  Future<void> _load({bool initial = false}) async {
    if (initial) setState(() { _loading = true; _error = null; });

    try {
      final o = await api.getOffer(widget.id);
      if (!mounted) return;
      if (o == null) {
        setState(() {
          _offer = null;
          _loading = false;
          _related = const [];
          _slotsF = null;
          _reviewsF = null;
        });
        return;
      }
      setState(() {
        _offer = o;
        _slotsF = api.listOfferSlots(widget.id);           // keep existing API
        _giftStatsF = api.giftStats(widget.id);            // unchanged
        _reviewsF   = api.getOfferReviews(widget.id);      // new (non-breaking if present)
        // if you later know a completed engagement for current user:
        // _eligibleEngagementId = o['can_review_eng_id']; // example
      });
      // Fire and forget
      unawaited(_tryLogView());
      await _loadRelated();
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _tryLogView() async {
    try {
      // Best-effort; ignore if not implemented
      await api.addView('offer', widget.id);
    } catch (_) {}
  }

  Future<void> _loadRelated() async {
    try {
      final o = _offer!;
      final String? type = (o['type'] as String?);
      final List tags = (o['tags'] as List?) ?? const [];
      final firstTag = tags.isEmpty ? null : tags.first.toString();

      final res = await api.listOffers(
        type: type,
        tag: firstTag,
        sort: 'rating',
        page: 1,
        pageSize: 6,
      );

      final items = (res['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      setState(() {
        _related = items.where((e) => e['id'].toString() != widget.id).toList();
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _refreshGiftStats() async {
    if (!mounted) return;
    setState(() {
      _giftStatsF = api.giftStats(widget.id);
    });
  }

  Future<void> _useSponsoredSeat() async {
    if (!_isSignedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in first")),
      );
      context.pushNamed('signin');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => RequestDialog(
        offerId: widget.id,
        useGift: true, // tells backend to consume a sponsored seat
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Request sent with sponsored seat")),
      );
      await _refreshGiftStats();
    }
  }

  String _fmtNum(num? v, {int digits = 1}) {
    if (v == null) return '0';
    return v.toStringAsFixed(digits);
  }

  // slot formatter (unchanged)
  String _fmtSlot(dynamic startIso, dynamic endIso, dynamic cap, dynamic res) {
    final s = DateTime.tryParse(startIso?.toString() ?? "");
    final e = DateTime.tryParse(endIso?.toString() ?? "");
    if (s == null || e == null) return "—";
    final dur = e.difference(s).inMinutes;
    final left = (cap is num && res is num) ? (cap - res) : null;
    final hh = s.toLocal().toString().substring(0, 16).replaceFirst('T', '  ');
    return left == null ? "$hh (${dur}m)" : "$hh (${dur}m, $left left)";
  }

  Future<void> _rate(int stars) async {
    if (_ratingInFlight) return;
    setState(() => _ratingInFlight = true);
    try {
      await api.rate('offer', widget.id, stars);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Thanks! You rated $stars ★")),
      );
      await _load(initial: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Rating failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _ratingInFlight = false);
    }
  }

  // ---- Gift section (unchanged behavior, polished) ----
  Widget _giftSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _giftStatsF,
      builder: (ctx, snap) {
        final waiting = snap.connectionState == ConnectionState.waiting;
        final available = (snap.data?['available'] as num?)?.toInt() ?? 0;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.favorite_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: waiting
                      ? const LinearProgressIndicator()
                      : Text(
                    available > 0
                        ? "$available sponsored seat${available == 1 ? '' : 's'} available"
                        : "No sponsored seats available yet",
                  ),
                ),
                TextButton.icon(
                  onPressed: _gifting || _offer == null
                      ? null
                      : () async {
                    await _openGiftDialogOnDetail(
                      offerId: _offer!['id'].toString(),
                      title: (_offer!['title'] ?? '') as String,
                    );
                  },
                  icon: _gifting
                      ? const SizedBox.square(
                      dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.volunteer_activism_outlined),
                  label: Text(_gifting ? "Processing..." : "Gift support"),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: (_offer == null || waiting || available <= 0)
                      ? null
                      : _useSponsoredSeat,
                  child: const Text("Use seat"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // helper for the gift dialog (your updated version)
  Future<void> _openGiftDialogOnDetail({required String offerId, required String title}) async {
    int available = 0;
    bool loading  = true;
    bool posting  = false;

    final unitsCtrl = TextEditingController(text: '1');
    final noteCtrl  = TextEditingController();

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
                      ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
        setState(() => _giftStatsF = api.giftStats(offerId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Thanks! Your sponsored seat(s) are now available.")),
        );
      }
    });
  }

  // Ratings (unchanged)
  Widget _stars(num avg, int count) {
    final avgD = (avg is num) ? avg.toDouble() : 0.0;
    final c = (count is num) ? count.toInt() : 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          IconButton(
            tooltip: "Rate $i",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            icon: Icon(
              i <= avgD.round() ? Icons.star_rounded : Icons.star_border_rounded,
              size: 22,
            ),
            onPressed: _ratingInFlight ? null : () => _rate(i),
          ),
        const SizedBox(width: 6),
        Text("${_fmtNum(avgD)} ($c)"),
      ],
    );
  }

  Future<void> _openAI() async {
    if (_aiLoading) return;
    setState(() { _aiLoading = true; _ai = null; });
    try {
      final o = _offer!;
      final topic = (o["type"] ?? "other").toString();
      final res = await api.aiAnswer(question: "General guidance", topicTag: topic);
      if (!mounted) return;
      setState(() => _ai = res);
      await showModalBottomSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) {
          final r = _ai;
          if (r == null) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final orgs = (r["verified_orgs"] as List?) ?? const [];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("AI (beta)", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                Text(r["answer"] ?? ""),
                const SizedBox(height: 10),
                if ((r["handoff_note"] as String?)?.isNotEmpty == true)
                  Text(r["handoff_note"], style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                for (final v in orgs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text("• ${v["title"]} (${v["region"] ?? "-"})  ★ ${_fmtNum((v["avg_stars"] ?? 0) as num)}"),
                  ),
                const SizedBox(height: 10),
                const Text("AI (beta): not professional advice.", style: TextStyle(fontSize: 12)),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI error: $e")));
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _copyToClipboard(String text, {String hint = "Copied"}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hint)));
  }

  Widget _relatedStrip() {
    if (_related.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text("Similar offers", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _related.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final o = _related[i];
              final id = o["id"].toString();
              final title = (o["title"] ?? "") as String;
              final fee = (o["fee_type"] ?? "") as String;
              final avg = (o["avg_stars"] is num) ? (o["avg_stars"] as num).toDouble() : 0.0;
              final count = (o["ratings_count"] as num?)?.toInt() ?? 0;
              return SizedBox(
                width: 260,
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.pushNamed('psm_offer_detail', pathParameters: {'id': id}),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Row(
                            children: [
                              Chip(label: Text(fee), visualDensity: VisualDensity.compact),
                              const Spacer(),
                              const Icon(Icons.star_rate_rounded, size: 18),
                              const SizedBox(width: 4),
                              Text("${_fmtNum(avg)} ($count)"),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ======== NEW: Calendar header + filtered slots section (non-breaking) ========

  bool _isSameDayLocal(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _calendarHeader() {
    final start = DateTime(_calendarStart.year, _calendarStart.month, _calendarStart.day);
    final days = List<DateTime>.generate(_calendarDays, (i) => start.add(Duration(days: i)));
    const wd = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: 64,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          scrollDirection: Axis.horizontal,
          itemCount: days.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final d = days[i];
            final isSel = _selectedDay != null && _isSameDayLocal(_selectedDay!, d);
            return ChoiceChip(
              selected: isSel,
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(wd[(d.weekday + 6) % 7], style: TextStyle(fontSize: 11, color: isSel ? Colors.white : null)),
                  const SizedBox(height: 2),
                  Text("${d.day}", style: TextStyle(fontWeight: FontWeight.w600, color: isSel ? Colors.white : null)),
                ],
              ),
              onSelected: (_) => setState(() => _selectedDay = d),
            );
          },
        ),
      ),
    );
  }

  Widget _slotsSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _slotsF,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          );
        }
        final slots = snap.data ?? const [];
        // open slots
        var open = slots.where((s) {
          final st = (s["status"] ?? "open").toString();
          final cap = (s["capacity"] ?? 1) as int;
          final res = (s["reserved"] ?? 0) as int;
          return st == "open" && res < cap;
        }).toList();

        // filter by selected day (local)
        if (_selectedDay != null) {
          open = open.where((s) {
            final start = DateTime.tryParse(s["start_at"]?.toString() ?? "");
            if (start == null) return false;
            final local = start.toLocal();
            return _isSameDayLocal(local, _selectedDay!);
          }).toList();
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Select a time", style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _calendarHeader(),
              const SizedBox(height: 8),
              if (open.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text("No open times for the selected day."),
                ),
              if (open.isNotEmpty)
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    for (final s in open)
                      ActionChip(
                        label: Text(_fmtSlot(s["start_at"], s["end_at"], s["capacity"], s["reserved"])),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => RequestDialog(
                              offerId: _offer!["id"].toString(),
                              preselectedSlot: s,
                            ),
                          );
                          if (ok == true && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Request sent for selected time")),
                            );
                          }
                        },
                      ),
                  ],
                ),
            ]),
          ),
        );
      },
    );
  }

  // ======== NEW: Reviews panel (reads now; write when eligibleEngagementId is set) ========

  Future<void> _refreshReviews() async {
    setState(() => _reviewsF = api.getOfferReviews(widget.id));
  }

  Widget _reviewsSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reviewsF,
      builder: (ctx, snap) {
        final waiting = snap.connectionState == ConnectionState.waiting;
        final items = snap.data ?? const [];

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  Text("Reviews", style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (_eligibleEngagementId != null)
                    FilledButton.icon(
                      onPressed: waiting ? null : _openCreateReviewDialog,
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text("Write a review"),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (waiting) const LinearProgressIndicator(),
              if (!waiting && items.isEmpty) const Text("No reviews yet."),
              if (!waiting && items.isNotEmpty)
                ...items.map((r) => ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text("${r['reviewer_username'] ?? 'User'} • ${r['stars']} ⭐"),
                  subtitle: Text((r['comment'] ?? '').toString()),
                  dense: true,
                )),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _openCreateReviewDialog() async {
    if (_eligibleEngagementId == null) return;
    final txt = TextEditingController();
    int stars = 5;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Write a review"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<int>(
              value: stars,
              items: [1,2,3,4,5].map((v) => DropdownMenuItem(value: v, child: Text("$v ⭐"))).toList(),
              onChanged: (v){ if (v != null) stars = v; },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: txt,
              decoration: const InputDecoration(hintText: "How was your session?"),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text("Cancel")),
          FilledButton(onPressed: ()=>Navigator.pop(context,true), child: const Text("Submit")),
        ],
      ),
    );

    if (ok != true) return;

    final res = await api.createReview(
      engagementId: _eligibleEngagementId!,
      stars: stars,
      comment: txt.text.trim(),
    );

    if (!mounted) return;
    if (res == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Review failed (only one per completed session).")),
      );
      return;
    }
    await _refreshReviews();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thanks for your feedback!")));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) return const AppScaffold(title: "Offer", body: Loading());
    if (_error != null) {
      return AppScaffold(
        title: "Offer",
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text("Error: $_error"),
          ),
        ),
      );
    }
    if (_offer == null) return const AppScaffold(title: "Offer", body: Empty("Not found"));

    final o = _offer!;
    final title = (o["title"] ?? "") as String;
    final desc = (o["description"] ?? "") as String? ?? "";
    final tags = (o["tags"] as List?)?.cast<String>() ?? const <String>[];
    final langs = (o["languages"] as List?)?.cast<String>() ?? const <String>[];
    final fee = (o["fee_type"] ?? "") as String;
    final region = (o["region"] ?? "") as String? ?? "";
    final avg = (o["avg_stars"] is num) ? (o["avg_stars"] as num).toDouble() : 0.0;
    final count = (o["ratings_count"] as num?)?.toInt() ?? 0;
    final views = (o["views"] as num?)?.toInt() ?? 0;
    final owner = (o["owner_username"] ?? "") as String? ?? "";

    return AppScaffold(
      title: title,
      actions: [
        IconButton(
          tooltip: "Copy link",
          icon: const Icon(Icons.link),
          onPressed: () => _copyToClipboard("app://psm/offers/${widget.id}", hint: "Offer link copied"),
        ),
        IconButton(
          tooltip: "AI (beta)",
          icon: _aiLoading
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.air),
          onPressed: _aiLoading ? null : _openAI,
        ),
        IconButton(
          tooltip: "My Requests",
          icon: const Icon(Icons.inbox_outlined),
          onPressed: () => context.pushNamed('psm_requests'),
        ),
        // TIP: after you add the profile route, you can add a "View profile" icon here.
      ],
      body: RefreshIndicator(
        onRefresh: () => _load(initial: false),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Top info card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Chip(label: Text(fee), visualDensity: VisualDensity.compact),
                      const SizedBox(width: 8),
                      if (region.isNotEmpty)
                        ActionChip(
                          label: Text(region),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _copyToClipboard(region, hint: "Region copied"),
                        ),
                      const Spacer(),
                      const Icon(Icons.remove_red_eye_outlined, size: 18),
                      const SizedBox(width: 4),
                      Text("$views"),
                      const SizedBox(width: 10),
                      _stars(avg, count),
                    ]),
                    const SizedBox(height: 10),
                    if (owner.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.verified_user_outlined, size: 16),
                          const SizedBox(width: 6),
                          Text(owner, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    if (owner.isNotEmpty) const SizedBox(height: 6),
                    if (desc.isNotEmpty) Text(desc, style: const TextStyle(height: 1.4)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: -6,
                      children: [
                        for (final t in tags) Chip(label: Text(t), visualDensity: VisualDensity.compact),
                        for (final l in langs) Chip(label: Text(l), visualDensity: VisualDensity.compact),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Gift (sponsored seats)
            const SizedBox(height: 12),
            _giftSection(),

            // Calendar + slots (filtered)
            const SizedBox(height: 12),
            _slotsSection(),

            // Fallback request button
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => RequestDialog(offerId: o["id"].toString()),
                );
                if (ok == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Request sent")),
                  );
                }
              },
              icon: const Icon(Icons.send),
              label: const Text("Open Request"),
            ),

            // Reviews
            const SizedBox(height: 12),
            _reviewsSection(),

            // Related items
            _relatedStrip(),
          ],
        ),
      ),
    );
  }
}
