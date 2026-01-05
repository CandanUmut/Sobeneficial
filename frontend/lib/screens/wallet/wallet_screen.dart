import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  Future<void> _load() async {
    final d = await api.walletMe();
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final account = _data?['account'] as Map<String, dynamic>? ?? {};
    final txns = (_data?['txns'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final bal = (account['balance'] ?? 0).toString();

    return Scaffold(
      appBar: AppBar(title: const Text("Wallet")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined),
                  const SizedBox(width: 12),
                  const Text("Balance", style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text("$bal", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("About TimeCoin (demo)", style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                  "Topluluk içi takdir için bir demo puan sistemi. Cevap/Yardım gibi katkılar ödüllendirilebilir. "
                      "Ayrıca içerik sahiplerine küçük bahşişler gönderilebilir.",
                ),
                const SizedBox(height: 12),
                // Not: Top-up/faucet backend'i eklersek burada buton konur.
                FilledButton.tonal(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Top-up (demo faucet) yakında")),
                    );
                  },
                  child: const Text("Top-up (soon)"),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          const Text("Recent Activity", style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (txns.isEmpty)
            const Text("No transactions yet.")
          else
            ...txns.map((t) {
              final a = t['amount'] ?? 0;
              final from = (t['from_user'] ?? '') as String;
              final to = (t['to_user'] ?? '') as String;
              final me = account['user_id'] as String?;
              final outgoing = (me != null && me == from);
              final ts = (t['created_at'] ?? '').toString().replaceAll('T', ' ').split('.').first;
              final reason = (t['reason'] ?? '').toString();
              return ListTile(
                leading: Icon(outgoing ? Icons.arrow_upward : Icons.arrow_downward),
                title: Text(outgoing ? "Sent $a" : "Received $a"),
                subtitle: Text("$reason  •  $ts"),
                trailing: Text(outgoing ? "to $to" : "from $from"),
              );
            }),
        ],
      ),
    );
  }
}
