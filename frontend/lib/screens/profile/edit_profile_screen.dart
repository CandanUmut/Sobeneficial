import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_client.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _f = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _display = TextEditingController();
  final _bio = TextEditingController();
  final _region = TextEditingController();
  final _langs = TextEditingController();       // comma-separated
  final _specs = TextEditingController();       // comma-separated
  String? _avatarUrl;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await api.getMyProfile();
    setState(() {
      _username.text = (me?['username'] ?? '') as String;
      _display.text = (me?['display_name'] ?? '') as String;
      _bio.text = (me?['bio'] ?? '') as String;
      _region.text = (me?['region'] ?? '') as String;
      _avatarUrl = (me?['avatar_url'] ?? '') as String;
      _langs.text = ((me?['languages'] as List?)?.join(', ') ?? '');
      _specs.text = ((me?['specialties'] as List?)?.join(', ') ?? '');
      _loading = false;
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (x == null) return;
    final file = File(x.path);
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final path = "avatars/$uid-${DateTime.now().millisecondsSinceEpoch}.jpg";
    await Supabase.instance.client.storage.from('public').upload(path, file, fileOptions: const FileOptions(upsert: true));
    final publicUrl = Supabase.instance.client.storage.from('public').getPublicUrl(path);
    setState(()=> _avatarUrl = publicUrl);
  }

  Future<void> _save() async {
    if (!_f.currentState!.validate()) return;
    setState(()=> _saving = true);
    final patch = {
      "username": _username.text.trim().isEmpty ? null : _username.text.trim(),
      "display_name": _display.text.trim().isEmpty ? null : _display.text.trim(),
      "bio": _bio.text.trim().isEmpty ? null : _bio.text.trim(),
      "region": _region.text.trim().isEmpty ? null : _region.text.trim(),
      "avatar_url": _avatarUrl,
      "languages": _langs.text.split(',').map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList(),
      "specialties": _specs.text.split(',').map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList(),
    };
    final updated = await api.updateMyProfile(patch);
    setState(()=> _saving = false);
    if (updated == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not save profile (username may be taken).")),
      );
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile saved")));
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text("Edit profile")),
      body: Form(
        key: _f,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty ? NetworkImage(_avatarUrl!) : null,
                  child: _avatarUrl == null || _avatarUrl!.isEmpty ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _pickAndUploadAvatar,
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text("Change photo"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _username, decoration: const InputDecoration(labelText: "Username")),
            const SizedBox(height: 8),
            TextFormField(controller: _display, decoration: const InputDecoration(labelText: "Display name")),
            const SizedBox(height: 8),
            TextFormField(controller: _region, decoration: const InputDecoration(labelText: "Region")),
            const SizedBox(height: 8),
            TextFormField(controller: _langs, decoration: const InputDecoration(labelText: "Languages (comma-separated)")),
            const SizedBox(height: 8),
            TextFormField(controller: _specs, decoration: const InputDecoration(labelText: "Specialties (comma-separated)")),
            const SizedBox(height: 8),
            TextFormField(controller: _bio, maxLines: 4, decoration: const InputDecoration(labelText: "Bio")),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
              label: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
