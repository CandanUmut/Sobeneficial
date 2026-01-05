// lib/screens/qa/qa_list_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

class QAListScreen extends StatefulWidget {
  const QAListScreen({super.key});
  @override
  State<QAListScreen> createState() => _QAListScreenState();
}

class _QAListScreenState extends State<QAListScreen> {
  late Future<List<dynamic>> _f;

  @override
  void initState() {
    super.initState();
    _f = api.listQuestions();
  }

  String _fromNow(String? iso) {
    if (iso == null) return "";
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return "";
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    return "${diff.inDays}d";
  }

  Future<void> _refresh() async {
    setState(() => _f = api.listQuestions());
    await _f;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Q&A",
      body: FutureBuilder(
        future: _f,
        builder: (c, s) {
          if (!s.hasData) return const Loading();
          final items = (s.data as List).cast<Map<String, dynamic>>();
          if (items.isEmpty) return const Empty("No questions yet.");
          final myId = Supabase.instance.client.auth.currentUser?.id;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final x = items[i];
                final ownerId = (x['asker_id'] ?? '').toString();
                final isOwner = myId != null && myId == ownerId;
                final avatar = (x['asker_avatar_url'] ?? '') as String;
                final username = (x['asker_username'] ?? x['asker_full_name'] ?? 'user').toString();

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      // TODO: question detail screen varsa push et
                      // context.push('/qa/${x['id']}');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: avatar + username + time + menu
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                child: avatar.isEmpty ? const Icon(Icons.person, size: 18) : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text("@$username",
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              Text(_fromNow(x['created_at'] as String?),
                                  style: const TextStyle(color: Colors.grey)),
                              if (isOwner)
                                PopupMenuButton<String>(
                                  itemBuilder: (c) => const [
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 18),
                                          SizedBox(width: 8),
                                          Text("Delete"),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (v) async {
                                    if (v == 'delete') {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text("Delete question?"),
                                          content: const Text("This cannot be undone."),
                                          actions: [
                                            TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text("Cancel")),
                                            FilledButton(onPressed: ()=>Navigator.pop(context, true), child: const Text("Delete")),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        final done = await api.deleteQuestion(x['id']);
                                        if (!mounted) return;
                                        if (done) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("Deleted")),
                                          );
                                          await _refresh();
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("Delete failed")),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            (x['title'] ?? '').toString(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          if ((x['body'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              (x['body'] ?? '').toString(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(height: 1.4),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: -8,
                            children: [
                              if (x['avg_stars'] != null && (x['ratings_count'] ?? 0) > 0)
                                Chip(
                                  avatar: const Icon(Icons.star_rate_rounded, size: 18),
                                  label: Text("${(x['avg_stars'] as num).toStringAsFixed(1)} • ${x['ratings_count']}"),
                                  visualDensity: VisualDensity.compact,
                                ),
                              Chip(
                                avatar: const Icon(Icons.remove_red_eye, size: 18),
                                label: Text("${x['views'] ?? 0}"),
                                visualDensity: VisualDensity.compact,
                              ),
                              for (final t in ((x['tags'] as List?) ?? const <dynamic>[]))
                                Chip(label: Text(t.toString()), visualDensity: VisualDensity.compact),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
