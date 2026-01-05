import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/api_client.dart';

class RFHDetailScreen extends StatefulWidget {
  final String id;
  const RFHDetailScreen({super.key, required this.id});

  @override
  State<RFHDetailScreen> createState() => _RFHDetailScreenState();
}

class _RFHDetailScreenState extends State<RFHDetailScreen> {
  // Ana RFH
  Map<String, dynamic>? _rfh;
  // Önerilen eşleşmeler
  List<dynamic> _matches = [];
  // Yorumlar
  List<Map<String, dynamic>> _comments = [];

  // Metrikler
  double? _avgStars;
  int? _ratingsCount;

  // UI durumları
  bool _loading = true;
  bool _posting = false;

  // Yorum ekleme
  final _commentCtrl = TextEditingController();
  final _me = Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    final rr = await api.getRFH(widget.id);
    final mm = await api.matchRFH(widget.id);
    // view kaydı (fire-and-forget)
    // ignore: unawaited_futures
    api.addView('rfh', widget.id);

    // Yorumları çek
    final cc = await api.listComments('rfh', widget.id);

    setState(() {
      _rfh = rr;
      _matches = mm;
      _comments = cc.cast<Map<String, dynamic>>();
      _avgStars = (rr?['avg_stars'] is num) ? (rr?['avg_stars'] as num).toDouble() : null;
      _ratingsCount = (rr?['ratings_count'] is num) ? (rr?['ratings_count'] as num).toInt() : null;
      _loading = false;
    });
  }

  Future<void> _rate(int s) async {
    final ok = await api.rate('rfh', widget.id, s);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? "Thanks for rating $s★" : "Rating failed")),
    );
    await _loadAll();
  }

  Future<void> _addComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _posting = true);
    final ok = await api.createComment('rfh', widget.id, body);
    if (!mounted) return;
    setState(() => _posting = false);
    if (ok) {
      _commentCtrl.clear();
      // sadece yorumları yeniden çek (daha hızlı his)
      final cc = await api.listComments('rfh', widget.id);
      if (!mounted) return;
      setState(() => _comments = cc.cast<Map<String, dynamic>>());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment failed')),
      );
    }
  }

  // --------- UI Helpers ---------

  Widget _metaRow() {
    final tags = (_rfh?['tags'] as List?)?.cast<String>() ?? const <String>[];
    final anon = (_rfh?['anonymous'] ?? false) as bool;
    final createdAt = _rfh?['created_at'] as String?;

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (anon)
          const Chip(
            avatar: Icon(Icons.visibility_off, size: 16),
            label: Text("Anonymous"),
            visualDensity: VisualDensity.compact,
          ),
        if (tags.isNotEmpty)
          ...tags.map((t) => Chip(label: Text(t), visualDensity: VisualDensity.compact)),
        if (createdAt != null)
          Chip(
            avatar: const Icon(Icons.schedule, size: 16),
            label: Text(_fromNow(createdAt)),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _authorRow() {
    final requesterId = _rfh?['requester_id']?.toString();
    final isMine = _me != null && requesterId == _me!.id;

    final name = _rfh?['requester_name'] ??
        _rfh?['requester_username'] ??
        (requesterId != null ? _shortId(requesterId) : "Unknown");
    final avatarUrl = _rfh?['requester_avatar_url']; // varsa backend’ten gelir

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundImage: (avatarUrl is String && avatarUrl.isNotEmpty)
              ? NetworkImage(avatarUrl)
              : null,
          child: (avatarUrl == null || avatarUrl.toString().isEmpty)
              ? Text(name.toString().substring(0, 1).toUpperCase())
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          name.toString(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (isMine) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text("You", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          )
        ],
      ],
    );
  }

  Widget _metricsAndRate() {
    return Row(
      children: [
        if (_avgStars != null && _ratingsCount != null)
          Row(
            children: [
              const Icon(Icons.star_rate_rounded),
              const SizedBox(width: 4),
              Text("${_avgStars!.toStringAsFixed(1)} (${_ratingsCount})"),
            ],
          ),
        const Spacer(),
        _MiniStarRater(onRate: _rate),
      ],
    );
  }

  Widget _helpersCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Suggested Helpers", style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_matches.isEmpty) const Text("No matches yet."),
            for (final m in _matches)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text((m['helper_id'] ?? '').toString()),
                subtitle: Text("Score: ${(m['score'] ?? 0).toString()}"),
                trailing: FilledButton.tonal(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Contact flow is TODO')),
                    );
                  },
                  child: const Text("Contact"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _commentsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Comments", style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (_comments.isEmpty)
              Text(
                "No comments yet. Be the first!",
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            for (final c in _comments) _commentTile(c),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: "Write a comment…",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _posting ? null : _addComment,
                  child: _posting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text("Send"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _commentTile(Map<String, dynamic> c) {
    final body = (c['body'] ?? '').toString();
    final createdAt = c['created_at']?.toString();
    final name = c['author_name'] ??
        c['author_username'] ??
        _shortId(c['author_id']?.toString() ?? "");
    final avatarUrl = c['author_avatar_url'];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundImage: (avatarUrl is String && avatarUrl.isNotEmpty)
            ? NetworkImage(avatarUrl)
            : null,
        child: (avatarUrl == null || avatarUrl.toString().isEmpty)
            ? Text(name.toString().substring(0, 1).toUpperCase())
            : null,
      ),
      title: Row(
        children: [
          Expanded(child: Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.w600))),
          if (createdAt != null)
            Text(
              _fromNow(createdAt),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
        ],
      ),
      subtitle: Text(body),
    );
  }

  static String _shortId(String id) {
    if (id.isEmpty) return "user";
    if (id.length <= 8) return id;
    return "${id.substring(0, 4)}…${id.substring(id.length - 4)}";
  }

  static String _fromNow(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return "";
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    return "${diff.inDays}d";
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
          title: const Text("Loading"),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_rfh == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
          title: const Text("Not found"),
        ),
        body: const Center(child: Text("RFH not found")),
      );
    }

    final title = (_rfh!['title'] ?? 'Help Request') as String;
    final body = (_rfh!['body'] ?? '') as String;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          // Paylaş / rapor vs ileride
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Kapak kartı (yazar + meta + gövde + rating)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _authorRow(),
                  const SizedBox(height: 10),
                  _metaRow(),
                  const Divider(height: 24),
                  Text(body, style: const TextStyle(fontSize: 16, height: 1.4)),
                  const SizedBox(height: 12),
                  _metricsAndRate(),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // Eşleşen yardımcılar
            _helpersCard(),
            const SizedBox(height: 12),

            // Yorumlar
            _commentsCard(),
          ],
        ),
      ),
    );
  }
}

class _MiniStarRater extends StatefulWidget {
  final Future<void> Function(int stars) onRate;
  const _MiniStarRater({required this.onRate});

  @override
  State<_MiniStarRater> createState() => _MiniStarRaterState();
}

class _MiniStarRaterState extends State<_MiniStarRater> {
  int _hover = 0;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    Widget star(int i) {
      final filled = i <= _hover;
      return IconButton(
        iconSize: 22,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        onPressed: _busy
            ? null
            : () async {
          setState(() => _busy = true);
          try {
            await widget.onRate(i);
          } finally {
            if (mounted) setState(() => _busy = false);
          }
        },
        onHover: (h) => setState(() => _hover = h ? i : 0),
        icon: Icon(filled ? Icons.star : Icons.star_border),
        tooltip: '$i star',
      );
    }

    return Row(children: [
      const Text("Rate:  "),
      for (var i = 1; i <= 5; i++) star(i),
    ]);
  }
}
