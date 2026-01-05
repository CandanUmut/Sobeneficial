import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/api_client.dart';
import '../../widgets/common.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _form = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // We build fields dynamically from /profiles/me so we don’t send unknown keys.
  final Map<String, dynamic> _me = {};
  final _username = TextEditingController();
  final _display  = TextEditingController();
  final _bio      = TextEditingController();
  final _region   = TextEditingController();
  final _languages = TextEditingController(); // comma separated

  bool get _hasDisplay => _me.containsKey('display_name');
  bool get _hasBio     => _me.containsKey('bio');
  bool get _hasRegion  => _me.containsKey('region');
  bool get _hasLangs   => _me.containsKey('languages');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await api.getMyProfile();
      if (!mounted) return;
      if (res == null) {
        setState(() { _loading = false; _error = "Profile not found"; });
        return;
      }
      _me.clear();
      _me.addAll(res);
      _username.text = (res['username'] ?? '').toString();
      _display.text  = (res['display_name'] ?? '').toString();
      _bio.text      = (res['bio'] ?? '').toString();
      _region.text   = (res['region'] ?? '').toString();
      final langs = ((res['languages'] as List?) ?? const []).cast<String>();
      _languages.text = langs.join(', ');
      setState(() { _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _saving = true; });

    final Map<String, dynamic> payload = {};

    // Only send fields the backend is likely to accept (and only if changed).
    // username is almost guaranteed to exist
    if (_username.text.trim() != (_me['username'] ?? '').toString()) {
      payload['username'] = _username.text.trim();
    }
    if (_hasDisplay && _display.text.trim() != (_me['display_name'] ?? '').toString()) {
      payload['display_name'] = _display.text.trim();
    }
    if (_hasBio && _bio.text.trim() != (_me['bio'] ?? '').toString()) {
      payload['bio'] = _bio.text.trim();
    }
    if (_hasRegion && _region.text.trim() != (_me['region'] ?? '').toString()) {
      payload['region'] = _region.text.trim();
    }
    if (_hasLangs) {
      final cur = (( _me['languages'] as List? ) ?? const []).cast<String>().join(', ');
      if (_languages.text.trim() != cur) {
        final langs = _languages.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        payload['languages'] = langs;
      }
    }

    if (payload.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nothing to update")));
        setState(() => _saving = false);
      }
      return;
    }

    try {
      final ok = await api.updateMyProfile(payload);
      if (!mounted) return;
      if (ok != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated")));
        Navigator.pop(context); // go back to profile view
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Update failed")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppScaffold(title: "Edit Profile", body: Loading());
    if (_error != null) {
      return AppScaffold(
        title: "Edit Profile",
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

    return AppScaffold(
      title: "Edit Profile",
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(labelText: "Username"),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
              ),
              if (_hasDisplay) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _display,
                  decoration: const InputDecoration(labelText: "Display name"),
                ),
              ],
              if (_hasBio) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bio,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: "Bio"),
                ),
              ],
              if (_hasRegion) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _region,
                  decoration: const InputDecoration(labelText: "Region (e.g., TR-Istanbul)"),
                ),
              ],
              if (_hasLangs) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _languages,
                  decoration: const InputDecoration(labelText: "Languages (comma separated)"),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(_saving ? "Saving..." : "Save"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
