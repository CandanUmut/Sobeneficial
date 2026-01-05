import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

class ContentCreateScreen extends StatefulWidget {
  const ContentCreateScreen({super.key});
  @override
  State<ContentCreateScreen> createState() => _ContentCreateScreenState();
}

class _ContentCreateScreenState extends State<ContentCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _body = TextEditingController();
  final _tags = TextEditingController(text: "leadership");
  final _coverUrl = TextEditingController(); // demo: opsiyonel kapak görseli URL

  String _type = "guide";
  String _evidence = "n_a";
  String _visibility = "public";
  String _language = "tr";
  bool _saving = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);

    final payload = {
      "type": _type,
      "title": _title.text.trim(),
      "summary": _summary.text.trim(),
      "body": _body.text.trim(),
      "evidence": _evidence,
      "visibility": _visibility,
      "language": _language,
      "sources": _coverUrl.text.trim().isNotEmpty
          ? [
        {"kind": "image", "url": _coverUrl.text.trim()}
      ]
          : [],
      "tags": _tags.text
          .split(",")
          .map((e) => e.trim().replaceAll(" ", "-"))
          .where((e) => e.isNotEmpty)
          .toList(),
    };

    final id = await api.createContent(payload);
    setState(() => _saving = false);

    if (!mounted) return;
    if (id != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Content created")));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Create failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "New Content",
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _form,
                child: ListView(
                  children: [
                    // Üsttaki hızlı alanlar (type/evidence/visibility/lang)
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _type,
                            decoration: const InputDecoration(
                              labelText: "Type",
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: "best_practice", child: Text("Best Practice")),
                              DropdownMenuItem(value: "guide", child: Text("Guide")),
                              DropdownMenuItem(value: "story", child: Text("Story")),
                              DropdownMenuItem(value: "case_study", child: Text("Case Study")),
                              DropdownMenuItem(value: "video", child: Text("Video (link in body)")),
                              DropdownMenuItem(value: "material", child: Text("Material / Resource")),
                            ],
                            onChanged: (v) => setState(() => _type = v ?? "guide"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _evidence,
                            decoration: const InputDecoration(
                              labelText: "Evidence",
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: "n_a", child: Text("N/A")),
                              DropdownMenuItem(value: "experience", child: Text("Experience")),
                              DropdownMenuItem(value: "observational", child: Text("Observational")),
                              DropdownMenuItem(value: "study", child: Text("Study")),
                              DropdownMenuItem(value: "meta_analysis", child: Text("Meta Analysis")),
                            ],
                            onChanged: (v) => setState(() => _evidence = v ?? "n_a"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _visibility,
                            decoration: const InputDecoration(
                              labelText: "Visibility",
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: "public", child: Text("Public")),
                              DropdownMenuItem(value: "members", child: Text("Members")),
                              DropdownMenuItem(value: "private", child: Text("Private")),
                            ],
                            onChanged: (v) => setState(() => _visibility = v ?? "public"),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: "Title",
                        hintText: "e.g., 7 Habits for Leadership in Tech Teams",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _summary,
                      decoration: const InputDecoration(
                        labelText: "Summary",
                        hintText: "Short abstract (1–2 sentences)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Demo: kapak görseli (opsiyonel URL)
                    TextFormField(
                      controller: _coverUrl,
                      decoration: const InputDecoration(
                        labelText: "Cover image URL (optional)",
                        hintText: "https://…/image.png",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _body,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: "Body",
                        hintText: "Long form content, links, etc.",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _tags,
                      decoration: const InputDecoration(
                        labelText: "Tags (comma-separated)",
                        hintText: "leadership, career, flutter",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: const Icon(Icons.check),
                      label: Text(_saving ? "Saving…" : "Create"),
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
