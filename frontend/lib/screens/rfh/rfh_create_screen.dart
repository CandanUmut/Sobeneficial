import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

class RFHCreateScreen extends StatefulWidget {
  const RFHCreateScreen({super.key});
  @override
  State<RFHCreateScreen> createState() => _RFHCreateScreenState();
}

class _RFHCreateScreenState extends State<RFHCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _tags = TextEditingController(text: "addiction, mentoring");
  String _language = "tr";
  String _sensitivity = "normal";
  bool _anon = false;
  bool _saving = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final id = await api.createRFH({
      "title": _title.text.trim(),
      "body": _body.text.trim(),
      "tags": _tags.text
          .split(",")
          .map((e) => e.trim().replaceAll(" ", "-"))
          .where((e) => e.isNotEmpty)
          .toList(),
      "anonymous": _anon,
      "sensitivity": _sensitivity,
      "language": _language,
    });
    setState(() => _saving = false);
    if (!mounted) return;
    if (id != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request created")));
      context.go('/rfh/$id');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Create failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "New Help Request",
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _form,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: "Title",
                        hintText: "e.g., Need mentorship for Flutter career roadmap",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _body,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: "Details",
                        hintText: "Describe the problem, context, goals…",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _tags,
                      decoration: const InputDecoration(
                        labelText: "Tags (comma-separated)",
                        hintText: "addiction, mentoring, flutter",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _language,
                            decoration: const InputDecoration(
                              labelText: "Language",
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: "tr", child: Text("Turkish")),
                              DropdownMenuItem(value: "en", child: Text("English")),
                            ],
                            onChanged: (v) => setState(() => _language = v ?? "tr"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _sensitivity,
                            decoration: const InputDecoration(
                              labelText: "Sensitivity",
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: "normal", child: Text("Normal")),
                              DropdownMenuItem(value: "sensitive", child: Text("Sensitive")),
                            ],
                            onChanged: (v) => setState(() => _sensitivity = v ?? "normal"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    SwitchListTile.adaptive(
                      value: _anon,
                      onChanged: (v) => setState(() => _anon = v),
                      title: const Text("Anonymous"),
                      subtitle: const Text("Hide your profile from public view for this request."),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _submit,
                            icon: const Icon(Icons.check),
                            label: Text(_saving ? "Saving…" : "Create"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
