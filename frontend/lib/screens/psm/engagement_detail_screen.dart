import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

class EngagementDetailScreen extends StatefulWidget {
  final String id;
  const EngagementDetailScreen({super.key, required this.id});
  @override
  State<EngagementDetailScreen> createState() => _EngagementDetailScreenState();
}

class _EngagementDetailScreenState extends State<EngagementDetailScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic>? E;
  bool loading = true;
  String? _error;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; _error = null; });
    try {
      final r = await api.getEngagement(widget.id);
      setState(() { E = r; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { loading = false; });
    }
  }

  String _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return "-";
    try {
      final dt = DateTime.parse(iso).toLocal();
      return "${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}";
    } catch (_) {
      return iso;
    }
  }

  String _two(int n) => n < 10 ? "0$n" : "$n";

  IconData _iconFor(String action) {
    switch (action) {
      case 'accept': return Icons.check_circle_outline;
      case 'schedule': return Icons.schedule;
      case 'complete': return Icons.flag_circle_outlined;
      case 'cancel': return Icons.cancel_outlined;
      default: return Icons.bolt;
    }
  }

  Color _stateColor(String s) {
    switch (s) {
      case 'scheduled': return Colors.indigo;
      case 'accepted': return Colors.blueGrey;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  Future<void> _schedule() async {
    if (_busy) return;
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
    final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute).toUtc().toIso8601String();

    setState(() => _busy = true);
    final ok = await api.updateEngagement(widget.id, {"action":"schedule","scheduled_at": dt});
    setState(() => _busy = false);

    if (ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Scheduled")),
      );
      _load();
    }
  }

  Future<void> _complete() async {
    if (_busy) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Complete engagement?"),
        content: const Text("Mark this engagement as completed."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Complete")),
        ],
      ),
    );
    if (yes != true) return;

    setState(() => _busy = true);
    final ok = await api.updateEngagement(widget.id, {"action":"complete"});
    setState(() => _busy = false);

    if (ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completed")),
      );
      _load();
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    String? reason;
    await showDialog(
      context: context,
      builder: (_) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text("Cancel engagement"),
          content: TextField(controller: c, decoration: const InputDecoration(hintText: "Reason (optional)")),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Close")),
            FilledButton(onPressed: () { reason = c.text; Navigator.pop(context); }, child: const Text("OK")),
          ],
        );
      },
    );

    setState(() => _busy = true);
    final ok = await api.updateEngagement(widget.id, {"action":"cancel","reason":reason ?? ""});
    setState(() => _busy = false);

    if (ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cancelled")),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (loading) return const AppScaffold(title: "Engagement", body: Loading());
    if (_error != null) {
      return AppScaffold(
        title: "Engagement",
        body: Center(child: Text("Error: $_error")),
      );
    }
    if (E == null) return const AppScaffold(title: "Engagement", body: Empty("Not found"));

    final state = (E!["state"] ?? "accepted") as String;
    final prac = (E!["practitioner_username"] ?? "") as String? ?? "";
    final req = (E!["requester_username"] ?? "") as String? ?? "";
    final scheduledAt = (E!["scheduled_at"] ?? "") as String?;
    final audit = (E!["audit"] as List?) ?? const [];

    return AppScaffold(
      title: "Engagement",
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(state),
                        labelStyle: const TextStyle(color: Colors.white),
                        backgroundColor: _stateColor(state),
                        visualDensity: VisualDensity.compact,
                      ),
                      const Spacer(),
                      if (_busy) const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.medical_information_outlined),
                    title: const Text("Practitioner"),
                    subtitle: Text(prac.isEmpty ? "-" : prac),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: const Text("Requester"),
                    subtitle: Text(req.isEmpty ? "-" : req),
                  ),
                  if (scheduledAt != null && scheduledAt.isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: const Text("Scheduled at"),
                      subtitle: Text(_fmt(scheduledAt)),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            const Text("Timeline", style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (audit.isEmpty)
              const Text("—")
            else
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    for (final a in audit.reversed)
                      ListTile(
                        dense: true,
                        leading: Icon(_iconFor("${a["action"]}")),
                        title: Text("${a["action"] ?? ""}"),
                        subtitle: Text(_fmt(a["at"]?.toString())),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _busy ? null : _schedule,
                  child: const Text("Schedule"),
                ),
                FilledButton.tonal(
                  onPressed: _busy ? null : _complete,
                  child: const Text("Complete"),
                ),
                TextButton(
                  onPressed: _busy ? null : _cancel,
                  child: const Text("Cancel"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
