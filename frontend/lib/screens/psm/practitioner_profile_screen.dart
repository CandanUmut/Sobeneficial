import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/api_client.dart';
import '../../widgets/common.dart';

class PractitionerProfileScreen extends StatefulWidget {
  final String profileId; // id or username (server supports both)
  const PractitionerProfileScreen({super.key, required this.profileId});

  @override
  State<PractitionerProfileScreen> createState() => _PractitionerProfileScreenState();
}

class _PractitionerProfileScreenState extends State<PractitionerProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic>? _bundle; // {profile, stats, offers}
  bool _loading = true;
  String? _error;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await api.getPublicProfile(widget.profileId);
      if (!mounted) return;
      if (res == null) {
        setState(() { _bundle = null; _loading = false; _error = "Not found"; });
      } else {
        setState(() { _bundle = res; _loading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  bool get _isMe {
    final me = _supabase.auth.currentUser?.id ?? "";
    final prof = _bundle?['profile'] as Map<String, dynamic>?;
    return me.isNotEmpty && (prof?['id']?.toString() == me);
  }

  Widget _statTile(String label, String value, {IconData? icon}) {
    return Column(
      children: [
        if (icon != null) Icon(icon, size: 18),
        if (icon != null) const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _offerTile(Map o) {
    final id = o['id'].toString();
    final title = (o['title'] ?? '') as String;
    final fee = (o['fee_type'] ?? '') as String;
    final avg = (o["avg_stars"] is num) ? (o["avg_stars"] as num).toDouble() : 0.0;
    final count = (o["ratings_count"] as num?)?.toInt() ?? 0;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Chip(label: Text(fee), visualDensity: VisualDensity.compact),
            const SizedBox(width: 8),
            const Icon(Icons.star_rate_rounded, size: 18),
            Text("${avg.toStringAsFixed(1)} ($count)"),
          ],
        ),
        trailing: FilledButton(
          onPressed: () => context.pushNamed('psm_offer_detail', pathParameters: {'id': id}),
          child: const Text("View"),
        ),
        onTap: () => context.pushNamed('psm_offer_detail', pathParameters: {'id': id}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) return const AppScaffold(title: "Profile", body: Loading());
    if (_error != null) {
      return AppScaffold(
        title: "Profile",
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("Error: $_error"),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ]),
        ),
      );
    }
    if (_bundle == null) return const AppScaffold(title: "Profile", body: Empty("Not found"));

    final prof = (_bundle!['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final stats = (_bundle!['stats'] as Map?)?.cast<String, dynamic>() ?? {};
    final offers = ((_bundle!['offers'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    final username = (prof['username'] ?? '').toString();
    final display = (prof['display_name'] ?? username).toString();
    final region = (prof['region'] ?? '').toString();
    final langs  = ((prof['languages'] as List?) ?? const []).cast<String>();
    final bio    = (prof['bio'] ?? '').toString();

    final completed = (stats['completed_engagements'] as num?)?.toInt() ?? 0;
    final avg       = (stats['avg_stars'] is num) ? (stats['avg_stars'] as num).toDouble() : 0.0;
    final cnt       = (stats['ratings_count'] as num?)?.toInt() ?? 0;

    return AppScaffold(
      title: display.isEmpty ? "Profile" : display,
      actions: [
        if (_isMe)
          IconButton(
            tooltip: "Edit profile",
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await context.pushNamed('profile_edit');
              if (mounted) _load();
            },
          ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // header card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const CircleAvatar(radius: 22, child: Icon(Icons.person, size: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(display.isEmpty ? "Practitioner" : display,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        if (username.isNotEmpty)
                          Text("@$username", style: const TextStyle(color: Colors.grey)),
                      ],
                    )),
                  ]),
                  const SizedBox(height: 10),
                  if (bio.isNotEmpty) ...[
                    Text(bio, style: const TextStyle(height: 1.4)),
                    const SizedBox(height: 8),
                  ],
                  Wrap(spacing: 6, runSpacing: -6, children: [
                    if (region.isNotEmpty) Chip(label: Text(region), visualDensity: VisualDensity.compact),
                    for (final l in langs) Chip(label: Text(l), visualDensity: VisualDensity.compact),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statTile("Completed", "$completed", icon: Icons.event_available_outlined),
                      _statTile("Rating", "${avg.toStringAsFixed(1)} ($cnt)", icon: Icons.star_rate_rounded),
                    ],
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 12),
            Text("Current offers", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (offers.isEmpty)
              const Card(
                elevation: 0,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text("No active offers yet."),
                ),
              )
            else
              ...offers.map(_offerTile),
          ],
        ),
      ),
    );
  }
}
