import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});
  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen>
    with TickerProviderStateMixin {
  late TabController _tab;
  List<dynamic> _sent = [];
  List<dynamic> _received = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
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

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await api.myRequests(box: "sent");
    final r = await api.myRequests(box: "received");
    setState(() { _sent = s; _received = r; _loading = false; });
  }

  Widget _item(Map r, {required bool received}) {
    final title = (r["offer_title"] ?? "") as String;
    final status = (r["status"] ?? "open") as String;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(title),
        subtitle: Text((r["message"] ?? "") as String),
        trailing: received
            ? PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == "accept") {
              final offerId = r["offer_id"].toString(); // present in r.*
              final slots = await api.listOfferSlots(offerId);
              final open = slots.where((s) {
                final st = (s["status"] ?? "open").toString();
                final cap = (s["capacity"] ?? 1) as int;
                final res = (s["reserved"] ?? 0) as int;
                return st == "open" && res < cap;
              }).toList();

              String? chosen;
              if (open.isNotEmpty) {
                await showDialog(
                  context: context,
                  builder: (_) {
                    return AlertDialog(
                      title: const Text("Select a time"),
                      content: SizedBox(
                        width: 420,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: open.length,
                          itemBuilder: (_, i) {
                            final s = open[i];
                            return ListTile(
                              leading: const Icon(Icons.schedule),
                              title: Text(_fmtSlot(
                                s["start_at"], s["end_at"], s["capacity"], s["reserved"],
                              )),
                              onTap: () { chosen = s["id"].toString(); Navigator.pop(context); },
                            );
                          },
                        ),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
                      ],
                    );
                  },
                );
              }

              final body = chosen == null
                  ? {"action": "accept"}
                  : {"action": "accept", "slot_id": chosen};

              final resp = await api.updateRequestWithResponse(r["id"].toString(), body);
              if (resp != null) _load();
            } else if (v == "decline") {
              String? reason;
              await showDialog(context: context, builder: (_) {
                final c = TextEditingController();
                return AlertDialog(
                  title: const Text("Decline reason"),
                  content: TextField(controller: c, decoration: const InputDecoration(hintText: "Optional")),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                    FilledButton(onPressed: () { reason = c.text; Navigator.pop(context); }, child: const Text("OK")),
                  ],
                );
              });
              final ok = await api.updateRequest(r["id"].toString(), {"action": "decline", "reason": reason ?? ""});
              if (ok) _load();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: "accept", child: Text("Accept")),
            PopupMenuItem(value: "decline", child: Text("Decline")),
          ],
        )
            : (status == "open"
            ? TextButton(
          onPressed: () async {
            final ok = await api.updateRequest(r["id"].toString(), {"action": "withdraw"});
            if (ok) _load();
          },
          child: const Text("Withdraw"),
        )
            : Text(status)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "My Requests",
      body: _loading
          ? const Loading()
          : Column(
        children: [
          TabBar(controller: _tab, tabs: const [Tab(text: "Sent"), Tab(text: "Received")]),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _sent.isEmpty
                      ? const Empty("No sent requests")
                      : ListView(children: _sent.map((e) => _item(e as Map, received: false)).toList()),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _received.isEmpty
                      ? const Empty("No received requests")
                      : ListView(children: _received.map((e) => _item(e as Map, received: true)).toList()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
