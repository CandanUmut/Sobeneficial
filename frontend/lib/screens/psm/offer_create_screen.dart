import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../widgets/common.dart';
import 'offer_detail_screen.dart';

const bool kPsmDemoMode = true; // <— TURN OFF later

class OfferCreateScreen extends StatefulWidget {
  const OfferCreateScreen({super.key});
  @override
  State<OfferCreateScreen> createState() => _OfferCreateScreenState();
}

class _OfferCreateScreenState extends State<OfferCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _tags = TextEditingController(); // comma-separated
  final _region = TextEditingController(text: "TR-Istanbul");
  final _otherLangs = TextEditingController(); // optional, comma-separated

  String _type = 'legal';
  String _fee = 'free';
  bool _en = true, _tr = true;

  bool _checking = true, _allowed = false, _saving = false;

  // Draft slots (created before the offer exists)
  final List<Map<String, dynamic>> _initialSlots = []; // {start_at, end_at, capacity}
  int _slotDurationMin = 45;
  int _defaultCapacity = 1;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _tags.dispose();
    _region.dispose();
    _otherLangs.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final ok = await api.canCreateOffer();
    if (!mounted) return;
    setState(() {
      _allowed = ok;
      _checking = false;
    });
  }

  // ---------- Slots helpers ----------

  Future<void> _addDraftSlot() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      initialDate: now,
    );
    if (d == null) return;

    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t == null) return;

    final startLocal = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    final endLocal = startLocal.add(Duration(minutes: _slotDurationMin));
    final slot = {
      "start_at": startLocal.toUtc().toIso8601String(),
      "end_at": endLocal.toUtc().toIso8601String(),
      "capacity": _defaultCapacity,
    };
    setState(() => _initialSlots.add(slot));
  }

  void _removeDraftSlot(int i) => setState(() => _initialSlots.removeAt(i));

  String _fmtSlotRow(Map s) {
    final sIso = s["start_at"]?.toString() ?? "";
    final eIso = s["end_at"]?.toString() ?? "";
    final cap = (s["capacity"] as num?)?.toInt() ?? 1;
    final sd = DateTime.tryParse(sIso)?.toLocal();
    final ed = DateTime.tryParse(eIso)?.toLocal();
    if (sd == null || ed == null) return "—";
    final dur = ed.difference(sd).inMinutes;
    final hh =
        "${sd.year.toString().padLeft(4, '0')}-${sd.month.toString().padLeft(2, '0')}-${sd.day.toString().padLeft(2, '0')} "
        "${sd.hour.toString().padLeft(2, '0')}:${sd.minute.toString().padLeft(2, '0')}";
    return "$hh  (${dur}m, cap $cap)";
  }

  Future<void> _openBulkSlotsDialog() async {
    final now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, now.day);
    DateTime endDate = startDate.add(const Duration(days: 13)); // default 2 weeks
    TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 16, minute: 0);
    int intervalMin = _slotDurationMin;
    int cap = _defaultCapacity;

    // Weekdays selection: 1=Mon..7=Sun (DateTime.weekday)
    final sel = <int>{1, 2, 3, 4, 5}; // Mon–Fri by default

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text("Bulk add availability"),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date range
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Start date"),
                        subtitle: Text("${startDate.toLocal()}".substring(0, 10)),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today_outlined),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              firstDate: now,
                              lastDate: now.add(const Duration(days: 180)),
                              initialDate: startDate,
                            );
                            if (d != null) setLocal(() => startDate = d);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text("End date"),
                        subtitle: Text("${endDate.toLocal()}".substring(0, 10)),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today_outlined),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              firstDate: startDate,
                              lastDate: now.add(const Duration(days: 180)),
                              initialDate: endDate,
                            );
                            if (d != null) setLocal(() => endDate = d);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Time range
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Start time"),
                        subtitle: Text("${startTime.format(context)}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.access_time),
                          onPressed: () async {
                            final t = await showTimePicker(context: context, initialTime: startTime);
                            if (t != null) setLocal(() => startTime = t);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text("End time"),
                        subtitle: Text("${endTime.format(context)}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.access_time),
                          onPressed: () async {
                            final t = await showTimePicker(context: context, initialTime: endTime);
                            if (t != null) setLocal(() => endTime = t);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Interval & capacity
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: intervalMin,
                        decoration: const InputDecoration(labelText: "Slot length"),
                        items: const [
                          DropdownMenuItem(value: 15, child: Text("15 min")),
                          DropdownMenuItem(value: 30, child: Text("30 min")),
                          DropdownMenuItem(value: 45, child: Text("45 min")),
                          DropdownMenuItem(value: 60, child: Text("60 min")),
                        ],
                        onChanged: (v) => setLocal(() => intervalMin = v ?? intervalMin),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: cap,
                        decoration: const InputDecoration(labelText: "Capacity"),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text("1")),
                          DropdownMenuItem(value: 2, child: Text("2")),
                          DropdownMenuItem(value: 3, child: Text("3")),
                          DropdownMenuItem(value: 4, child: Text("4")),
                          DropdownMenuItem(value: 5, child: Text("5")),
                        ],
                        onChanged: (v) => setLocal(() => cap = v ?? cap),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Weekdays
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final w in [
                        (1, "Mon"),
                        (2, "Tue"),
                        (3, "Wed"),
                        (4, "Thu"),
                        (5, "Fri"),
                        (6, "Sat"),
                        (7, "Sun"),
                      ])
                        FilterChip(
                          label: Text(w.$2),
                          selected: sel.contains(w.$1),
                          onSelected: (v) => setLocal(() {
                            if (v) {
                              sel.add(w.$1);
                            } else {
                              sel.remove(w.$1);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            FilledButton.icon(
              icon: const Icon(Icons.playlist_add_check),
              label: const Text("Generate"),
              onPressed: () {
                // Generate slots
                final List<Map<String, dynamic>> gen = [];
                DateTime cursor = DateTime(startDate.year, startDate.month, startDate.day);
                final last = DateTime(endDate.year, endDate.month, endDate.day);

                while (!cursor.isAfter(last)) {
                  if (sel.contains(cursor.weekday)) {
                    final start = DateTime(cursor.year, cursor.month, cursor.day, startTime.hour, startTime.minute);
                    final end = DateTime(cursor.year, cursor.month, cursor.day, endTime.hour, endTime.minute);
                    DateTime cur = start;
                    while (cur.add(Duration(minutes: intervalMin)).isBefore(end) ||
                        cur.add(Duration(minutes: intervalMin)).isAtSameMomentAs(end)) {
                      gen.add({
                        "start_at": cur.toUtc().toIso8601String(),
                        "end_at": cur.add(Duration(minutes: intervalMin)).toUtc().toIso8601String(),
                        "capacity": cap,
                      });
                      cur = cur.add(Duration(minutes: intervalMin));
                    }
                  }
                  cursor = cursor.add(const Duration(days: 1));
                }

                setState(() => _initialSlots.addAll(gen));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Added ${gen.length} slot${gen.length == 1 ? '' : 's'}.")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Submit ----------

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);

    final langs = <String>[];
    if (_en) langs.add('en');
    if (_tr) langs.add('tr');
    final extra = _otherLangs.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    langs.addAll(extra);

    // 1) Create the offer (keeps your API signature intact)
    final id = await api.createOffer(
      type: _type,
      title: _title.text.trim(),
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      tags: _tags.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      feeType: _fee,
      languages: langs,
      region: _region.text.trim().isEmpty ? null : _region.text.trim(),
      availability: {
        "next_available_at": DateTime.now().toUtc().toIso8601String(),
      },
    );

    if (!mounted) return;
    if (id == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Create failed")));
      return;
    }

    // 2) Create any draft slots
    int created = 0;
    for (final s in _initialSlots) {
      final sid = await api.createOfferSlot(
        offerId: id,
        startAtIso: s["start_at"].toString(),
        endAtIso: s["end_at"].toString(),
        capacity: (s["capacity"] as num?)?.toInt() ?? 1,
      );
      if (sid != null) created++;
    }

    setState(() => _saving = false);

    // 3) Next steps bottom sheet
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Offer created", style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(created > 0
                ? "We added $created time slot${created == 1 ? '' : 's'}."
                : "Add your availability so people can book directly."),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.push("/psm/offers/$id/slots"),
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text("Manage slots"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.pushNamed('psm_offer_detail', pathParameters: {'id': id}),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text("View offer"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    // 4) Finally move to the detail (keeps your prior behavior)
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OfferDetailScreen(id: id)),
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    if (_checking) return const AppScaffold(title: "New Offer", body: Loading());

    final locked = !_allowed && !kPsmDemoMode;
    if (locked) {
      return AppScaffold(
        title: "New Offer",
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.lock_outline, size: 36),
              SizedBox(height: 12),
              Text(
                "You don’t have permission to create professional offers.\n"
                    "Please verify your profile as an organization or practitioner.",
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ),
      );
    }

    final banner = (!_allowed && kPsmDemoMode)
        ? Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text("Demo mode: role check bypassed (not for production)."),
    )
        : const SizedBox.shrink();

    return AppScaffold(
      title: "New Offer",
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              banner,

              // ===== Basics =====
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Basics", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _type,
                      decoration: const InputDecoration(labelText: "Type"),
                      items: const [
                        DropdownMenuItem(value: "legal", child: Text("Legal")),
                        DropdownMenuItem(value: "psychological", child: Text("Psychological")),
                        DropdownMenuItem(value: "career", child: Text("Career")),
                        DropdownMenuItem(value: "it", child: Text("IT Counseling")),
                        DropdownMenuItem(value: "finance", child: Text("Finance Counseling")),
                        DropdownMenuItem(value: "other", child: Text("Other")),
                      ],
                      onChanged: (v) => setState(() => _type = v ?? 'legal'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: "Title",
                        hintText: "e.g., Free immigration consultation",
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _desc,
                      decoration: const InputDecoration(
                        labelText: "Description",
                        hintText: "What’s included, who it’s for, how the session works…",
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _tags,
                      decoration: const InputDecoration(
                        labelText: "Tags (comma separated)",
                        hintText: "e.g., immigration, family-law",
                      ),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 8),

              // ===== Audience & fees =====
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Audience & Fees", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _fee,
                      decoration: const InputDecoration(labelText: "Fee"),
                      items: const [
                        DropdownMenuItem(value: "free", child: Text("Free")),
                        DropdownMenuItem(value: "paid", child: Text("Paid")),
                        DropdownMenuItem(value: "sliding", child: Text("Sliding scale")),
                      ],
                      onChanged: (v) => setState(() => _fee = v ?? 'free'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _region,
                      decoration: const InputDecoration(
                        labelText: "Region",
                        hintText: "e.g., TR-Istanbul",
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text("Languages"),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, children: [
                      FilterChip(
                        label: const Text("English"),
                        selected: _en,
                        onSelected: (v) => setState(() => _en = v),
                      ),
                      FilterChip(
                        label: const Text("Turkish"),
                        selected: _tr,
                        onSelected: (v) => setState(() => _tr = v),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _otherLangs,
                      decoration: const InputDecoration(
                        labelText: "Other languages (optional, comma separated)",
                        hintText: "e.g., ar, ru",
                      ),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 12),

              // ===== Quick availability (optional) =====
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(
                      children: [
                        const Text("Quick availability (optional)",
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        DropdownButton<int>(
                          value: _slotDurationMin,
                          items: const [
                            DropdownMenuItem(value: 15, child: Text("15m")),
                            DropdownMenuItem(value: 30, child: Text("30m")),
                            DropdownMenuItem(value: 45, child: Text("45m")),
                            DropdownMenuItem(value: 60, child: Text("60m")),
                          ],
                          onChanged: (v) => setState(() => _slotDurationMin = v ?? 45),
                        ),
                        const SizedBox(width: 6),
                        DropdownButton<int>(
                          value: _defaultCapacity,
                          items: const [
                            DropdownMenuItem(value: 1, child: Text("cap 1")),
                            DropdownMenuItem(value: 2, child: Text("cap 2")),
                            DropdownMenuItem(value: 3, child: Text("cap 3")),
                            DropdownMenuItem(value: 4, child: Text("cap 4")),
                            DropdownMenuItem(value: 5, child: Text("cap 5")),
                          ],
                          onChanged: (v) => setState(() => _defaultCapacity = v ?? 1),
                        ),
                        const SizedBox(width: 6),
                        TextButton.icon(
                          onPressed: _addDraftSlot,
                          icon: const Icon(Icons.add),
                          label: const Text("Add slot"),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: _openBulkSlotsDialog,
                          icon: const Icon(Icons.playlist_add),
                          label: const Text("Bulk add"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_initialSlots.isEmpty)
                      const Text("No slots added. You can add them now or later on the offer page."),
                    if (_initialSlots.isNotEmpty)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _initialSlots.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = _initialSlots[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.schedule),
                            title: Text(_fmtSlotRow(s)),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => _removeDraftSlot(i),
                            ),
                          );
                        },
                      ),
                  ]),
                ),
              ),

              const SizedBox(height: 12),

              // ===== Preview =====
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Preview", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(_title.text.isEmpty ? "— Untitled offer —" : _title.text,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: -6,
                      children: [
                        Chip(label: Text(_fee), visualDensity: VisualDensity.compact),
                        if (_region.text.trim().isNotEmpty)
                          Chip(label: Text(_region.text.trim()), visualDensity: VisualDensity.compact),
                        if (_en) Chip(label: const Text("en"), visualDensity: VisualDensity.compact),
                        if (_tr) Chip(label: const Text("tr"), visualDensity: VisualDensity.compact),
                        for (final l in _otherLangs.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty))
                          Chip(label: Text(l), visualDensity: VisualDensity.compact),
                        for (final t in _tags.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty))
                          Chip(label: Text(t), visualDensity: VisualDensity.compact),
                      ],
                    ),
                    if (_desc.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(_desc.text.trim(), maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                  ]),
                ),
              ),

              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(_saving ? "Saving..." : "Create Offer"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
