import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? profile;
  bool loading = true;
  bool saving = false;
  bool editMode = false;

  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _offers = TextEditingController();
  final _needs = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await api.me(); // backend returns dynamic map
      // normalize it so we don't crash on web
      final normalized =
      raw == null ? null : Map<String, dynamic>.from(raw as Map);

      profile = normalized;

      if (profile != null) {
        _name.text = (profile!['full_name'] ?? '') as String;
        _bio.text = (profile!['bio'] ?? '') as String;

        final offersList =
            (profile!['offers'] as List?)?.map((e) => e.toString()).toList() ??
                const <String>[];
        final needsList =
            (profile!['needs'] as List?)?.map((e) => e.toString()).toList() ??
                const <String>[];

        _offers.text = offersList.join(", ");
        _needs.text = needsList.join(", ");
      }
    } catch (_) {
      // ignore for now; we could show error UI if you want
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);

    final body = {
      "full_name": _name.text.trim(),
      "bio": _bio.text.trim(),
      "offers": _offers.text
          .split(",")
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      "needs": _needs.text
          .split(",")
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    };

    final ok = await api.updateProfile(body);

    if (!mounted) return;

    setState(() => saving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated")),
      );
      setState(() => editMode = false);
      // reload so chips/preview reflect new state
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Update failed")),
      );
    }
  }

  Widget _headerCard(User? user) {
    final email = user?.email ?? "(unknown)";
    final uid = user?.id ?? "(no id)";

    final fullName = _name.text.trim().isEmpty ? email : _name.text.trim();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(
                fullName.isNotEmpty ? fullName[0].toUpperCase() : "?",
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "id: $uid",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: "Sign out",
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Signed out")),
                  );
                }
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String label, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _readOnlySection({
    required String title,
    required IconData icon,
    required String body,
    List<String>? chips,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(title, icon: icon),
            const SizedBox(height: 8),
            if (body.isNotEmpty)
              Text(
                body,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade900,
                  height: 1.4,
                ),
              )
            else
              Text(
                "(not provided)",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            if (chips != null && chips.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: -6,
                children: [
                  for (final c in chips)
                    Chip(
                      label: Text(
                        c,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.blueGrey.withOpacity(.08),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _editSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(title, icon: icon),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const AppScaffold(title: "Profile", body: Loading());
    }

    final user = Supabase.instance.client.auth.currentUser;

    // derive view data from current controllers/profile
    final offersList = _offers.text
        .split(",")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final needsList = _needs.text
        .split(",")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return AppScaffold(
      title: "Profile",
      actions: [
        // toggle edit / save
        if (!editMode)
          IconButton(
            tooltip: "Edit",
            onPressed: () {
              setState(() => editMode = true);
            },
            icon: const Icon(Icons.edit),
          ),
        if (editMode)
          IconButton(
            tooltip: "Save",
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.check),
          ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // top card with avatar / email / logout
            _headerCard(user),
            const SizedBox(height: 16),

            // either read-only cards or editable form cards
            if (!editMode) ...[
              _readOnlySection(
                title: "About you",
                icon: Icons.info_outline,
                body: _bio.text.trim(),
              ),
              const SizedBox(height: 12),
              _readOnlySection(
                title: "What I can offer",
                icon: Icons.volunteer_activism_outlined,
                body: offersList.isEmpty
                    ? ""
                    : "I can help with:",
                chips: offersList,
              ),
              const SizedBox(height: 12),
              _readOnlySection(
                title: "What I need",
                icon: Icons.handshake_outlined,
                body: needsList.isEmpty
                    ? ""
                    : "I'm currently looking for:",
                chips: needsList,
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  "Your profile is private by default.\nWe'll only show what you choose to share.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ] else ...[
              // edit mode UI
              _editSection(
                title: "Basic info",
                icon: Icons.info_outline,
                children: [
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: "Full name / Display name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bio,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: "Short bio (who you are / what you care about)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _editSection(
                title: "I can help with",
                icon: Icons.volunteer_activism_outlined,
                children: [
                  TextField(
                    controller: _offers,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Offers (comma separated)",
                      helperText:
                      "Example: legal aid, trauma support, job search, tutoring",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _editSection(
                title: "I'm looking for",
                icon: Icons.handshake_outlined,
                children: [
                  TextField(
                    controller: _needs,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Needs (comma separated)",
                      helperText:
                      "Example: housing help, therapy slot, cloud credits",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  "This info helps us match you to support and opportunities.\nOnly share what you're comfortable sharing.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ],
        ),
      ),
    );
  }
}
