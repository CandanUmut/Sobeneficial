import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class RequestDialog extends StatefulWidget {
  final String offerId;

  /// If not null, we show the chosen slot and skip preferred-times UI.
  /// Backend reservation still happens on ACCEPT; creation just carries the intent.
  final Map<String, dynamic>? preselectedSlot; // {id, start_at, end_at, capacity, reserved, ...}

  /// When true, we ask backend to consume a sponsored seat (gift) immediately.
  final bool useGift;

  const RequestDialog({
    super.key,
    required this.offerId,
    this.preselectedSlot,
    this.useGift = false,
  });

  @override
  State<RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<RequestDialog> {
  final _form = GlobalKey<FormState>();
  final _msg = TextEditingController();
  final List<Map<String, String>> _times = []; // {"start":"...Z","end":"...Z"}
  bool _saving = false;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  String _fmtSlot(dynamic startIso, dynamic endIso, dynamic cap, dynamic res) {
    final s = DateTime.tryParse(startIso?.toString() ?? "");
    final e = DateTime.tryParse(endIso?.toString() ?? "");
    if (s == null || e == null) return "—";
    final dur = e.difference(s).inMinutes;
    final left = (cap is num && res is num) ? (cap - res) : null;
    final hh = s.toLocal().toString().substring(0, 16).replaceFirst('T', '  ');
    return left == null ? "$hh (${dur}m)" : "$hh (${dur}m, $left left)";
  }

  Future<void> _addSlot() async {
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
    final start = DateTime(d.year, d.month, d.day, t.hour, t.minute).toUtc();
    final end = start.add(const Duration(minutes: 45));
    setState(() => _times.add({"start": start.toIso8601String(), "end": end.toIso8601String()}));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);

    String? id;
    try {
      // For creation we don't lock a slot; the owner confirms a slot when accepting.
      // If a preselected slot exists, we simply skip preferred-times UI here.
      id = await api.createOfferRequest(
        offerId: widget.offerId,
        message: _msg.text,
        preferredTimes: widget.preselectedSlot != null ? const [] : _times,
        useGift: widget.useGift, // ← consume a sponsored seat if requested
      );
    } catch (_) {
      id = null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;
    Navigator.pop(context, id != null);
  }

  @override
  Widget build(BuildContext context) {
    final hasPreselected = widget.preselectedSlot != null;

    return AlertDialog(
      title: Text(widget.useGift ? "Use Sponsored Session" : "Open Request"),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasPreselected)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.event_available),
                  title: const Text("Selected time"),
                  subtitle: Text(_fmtSlot(
                    widget.preselectedSlot!["start_at"],
                    widget.preselectedSlot!["end_at"],
                    widget.preselectedSlot!["capacity"],
                    widget.preselectedSlot!["reserved"],
                  )),
                ),
              TextFormField(
                controller: _msg,
                decoration: const InputDecoration(labelText: "Message"),
                maxLines: 3,
                validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 10),

              // Preferred times UI only if there's no preselected slot.
              if (!hasPreselected) ...[
                Row(children: [
                  const Text("Preferred times"),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addSlot,
                    icon: const Icon(Icons.add),
                    label: const Text("Add"),
                  ),
                ]),
                if (_times.isEmpty)
                  const Align(alignment: Alignment.centerLeft, child: Text("—")),
                for (int i = 0; i < _times.length; i++)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.schedule),
                    title: Text("${_times[i]["start"]} → ${_times[i]["end"]}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _times.removeAt(i)),
                    ),
                  ),
              ],

              if (widget.useGift)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "A sponsored seat will be used for this request.",
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? "Sending..." : "Send"),
        ),
      ],
    );
  }
}
