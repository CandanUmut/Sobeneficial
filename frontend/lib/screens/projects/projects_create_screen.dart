import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

class ProjectsCreateScreen extends StatefulWidget {
  const ProjectsCreateScreen({super.key});
  @override
  State<ProjectsCreateScreen> createState() => _ProjectsCreateScreenState();
}

class _ProjectsCreateScreenState extends State<ProjectsCreateScreen> {
  final _form = GlobalKey<FormState>();

  // core fields
  final _title = TextEditingController();
  final _pitch = TextEditingController(); // short "why this matters"
  final _desc = TextEditingController();  // longer "what we're doing"
  final _contact = TextEditingController(); // discord / link / email
  final _region = TextEditingController(text: "Remote / Global");

  // chips-style editable lists for roles & tags
  final List<String> _roles = ["founder", "flutter-dev"];
  final List<String> _tags = ["ai-ml"];

  // extra signals
  bool _remoteOk = true;
  double _urgency = 0.7; // 0 -> exploring, 1 -> active now
  String _visibility = "public"; // future proof if you want "private"

  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _pitch.dispose();
    _desc.dispose();
    _contact.dispose();
    _region.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);

    // build payload in a backwards-compatible way:
    // backend currently expects:
    //  title, description, needed_roles, tags, visibility
    //
    // we also send "meta" with the new goodies
    final payload = <String, dynamic>{
      "title": _title.text.trim(),
      "description": _desc.text.trim(),
      "needed_roles": _roles.where((e) => e.trim().isNotEmpty).toList(),
      "tags": _tags.where((e) => e.trim().isNotEmpty).toList(),
      "visibility": _visibility,
      "meta": {
        "pitch": _pitch.text.trim(),
        "contact": _contact.text.trim(),
        "region": _region.text.trim(),
        "remote_ok": _remoteOk,
        "urgency": _urgency, // 0..1
      }
    };

    final id = await api.createProject(payload);

    setState(() => _saving = false);

    if (!mounted) return;

    if (id != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Project created")),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to create project")),
      );
    }
  }

  // helper: ask user for a new chip value (role or tag)
  Future<void> _addChip({
    required String title,
    required List<String> target,
  }) async {
    final ctrl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "e.g. backend-dev / fundraising / outreach",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, ctrl.text.trim()),
            child: const Text("Add"),
          ),
        ],
      ),
    );
    if (v != null && v.isNotEmpty) {
      setState(() {
        if (!target.contains(v)) target.add(v);
      });
    }
  }

  Widget _chipEditor({
    required String label,
    required String helper,
    required List<String> values,
    required VoidCallback onAdd,
    Color? chipColor,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 4),
            Text(helper,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                )),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: -6,
              children: [
                for (int i = 0; i < values.length; i++)
                  InputChip(
                    label: Text(values[i]),
                    backgroundColor: chipColor,
                    onDeleted: () {
                      setState(() {
                        values.removeAt(i);
                      });
                    },
                    deleteIcon: const Icon(Icons.close, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text("Add"),
                  onPressed: onAdd,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Start a Project",
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // === 1. WHAT ARE YOU BUILDING? ===
              _sectionHeader("Project basics", icon: Icons.lightbulb_outline),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _title,
                        decoration: const InputDecoration(
                          labelText: "Project name",
                          hintText: "e.g. Refugee Legal Aid Network",
                        ),
                        validator: (v) =>
                        v == null || v.trim().isEmpty
                            ? "Required"
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _pitch,
                        decoration: const InputDecoration(
                          labelText: "One-line mission",
                          hintText:
                          "Short call to action. Why does this matter?",
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _desc,
                        decoration: const InputDecoration(
                          labelText: "What are you building?",
                          hintText:
                          "What's the problem, who are you helping, what do you need help doing right now?",
                        ),
                        maxLines: 5,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // === 2. HELP WANTED ===
              _sectionHeader("Who are you looking for?",
                  icon: Icons.groups_2_outlined),
              const SizedBox(height: 8),
              _chipEditor(
                label: "Open roles",
                helper:
                "What kind of people do you need? (designer, outreach lead, Flutter dev, etc.)",
                values: _roles,
                onAdd: () => _addChip(
                  title: "Add role",
                  target: _roles,
                ),
              ),
              const SizedBox(height: 12),
              _chipEditor(
                label: "Topics / tags",
                helper:
                "What areas does this touch? (ai-ml, mental-health, housing, climate...)",
                values: _tags,
                onAdd: () => _addChip(
                  title: "Add tag",
                  target: _tags,
                ),
                chipColor: Colors.blue.withOpacity(.08),
              ),

              const SizedBox(height: 24),

              // === 3. LOGISTICS ===
              _sectionHeader("Logistics & reach",
                  icon: Icons.travel_explore_outlined),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Remote-friendly"),
                        subtitle: const Text(
                            "People can contribute from anywhere"),
                        value: _remoteOk,
                        onChanged: (v) => setState(() => _remoteOk = v),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _region,
                        decoration: const InputDecoration(
                          labelText: "Region / base",
                          hintText: "e.g. Istanbul, Berlin, Remote / Global",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _contact,
                        decoration: const InputDecoration(
                          labelText: "Contact / link",
                          hintText:
                          "Discord, WhatsApp group link, email, etc.",
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // === 4. TIMELINE / URGENCY ===
              _sectionHeader("How active is this?",
                  icon: Icons.speed_rounded),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _urgency < 0.3
                                  ? "Exploring / brainstorming"
                                  : (_urgency < 0.7
                                  ? "In progress"
                                  : "Actively building now"),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            "${(_urgency * 100).round()}%",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _urgency,
                        onChanged: (v) =>
                            setState(() => _urgency = v),
                        min: 0,
                        max: 1,
                        divisions: 10,
                        label: _urgency < 0.3
                            ? "Exploring"
                            : (_urgency < 0.7
                            ? "Building"
                            : "Live / urgent"),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // === 5. VISIBILITY ===
              _sectionHeader("Visibility", icon: Icons.lock_open),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                "Public",
                                style: TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: const Text(
                                  "Anyone on the platform can discover this project."),
                              value: "public",
                              groupValue: _visibility,
                              onChanged: (v) =>
                                  setState(() => _visibility = v ?? "public"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                "Private (soft)",
                                style: TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: const Text(
                                  "Only people with the direct link can see details."),
                              value: "private",
                              groupValue: _visibility,
                              onChanged: (v) =>
                                  setState(() => _visibility = v ?? "private"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // === 6. SUBMIT ===
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(_saving ? "Saving..." : "Create project"),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
