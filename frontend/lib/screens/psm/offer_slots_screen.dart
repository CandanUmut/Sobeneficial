import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

class OfferSlotsScreen extends StatefulWidget {
  final String offerId;
  const OfferSlotsScreen({super.key, required this.offerId});

  @override
  State<OfferSlotsScreen> createState() => _OfferSlotsScreenState();
}

class _OfferSlotsScreenState extends State<OfferSlotsScreen> {
  List<Map<String, dynamic>> _slots = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final l = await api.listOfferSlots(widget.offerId);
    setState(() { _slots = l; _loading = false; });
  }

  Future<void> _add() async {
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
    final start = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    final end = start.add(const Duration(minutes: 45));
    await api.createOfferSlot(
      offerId: widget.offerId,
      startAtIso: start.toUtc().toIso8601String(),
      endAtIso: end.toUtc().toIso8601String(),
      capacity: 1,
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Manage slots",
      body: _loading
          ? const Loading()
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (_, i) {
          final s = _slots[i];
          final txt =
              "${s["start_at"]} → ${s["end_at"]} • cap ${s["capacity"]} • res ${s["reserved"]} • ${s["status"]}";
          return ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(txt),
            trailing: IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip: "Cancel slot",
              onPressed: (s["status"] == "cancelled")
                  ? null
                  : () async {
                await api.cancelOfferSlot(
                  offerId: widget.offerId,
                  slotId: s["id"].toString(),
                );
                _load();
              },
            ),
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: _slots.length,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
    );
  }
}
