import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/storage_helper.dart';
import '../../widgets/common.dart';

class QACreateQuestionScreen extends StatefulWidget {
  const QACreateQuestionScreen({super.key});
  @override
  State<QACreateQuestionScreen> createState() => _QACreateQuestionScreenState();
}

class _QACreateQuestionScreenState extends State<QACreateQuestionScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _tags = TextEditingController(); // örnek metin gösterilecek; ilk tıklamada temizlenecek

  bool _saving = false;
  bool _tagsEditedOnce = false;

  // Görsel kaynaklar: {"kind":"image","url": "..."}
  final List<Map<String, dynamic>> _sources = [];

  // Önerilen etiketler (ChoiceChip)
  final List<String> _suggestedTags = const [
    "flutter",
    "fastapi",
    "supabase",
    "postgres",
    "ui",
    "mobile",
    "auth",
    "storage"
  ];
  final Set<String> _selectedTags = {};

  @override
  void initState() {
    super.initState();
    // Canlı önizleme için alan değiştikçe setState
    _title.addListener(() => setState(() {}));
    _body.addListener(() => setState(() {}));
    _tags.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  // Seçili + yazılmış etiketleri birleştir (unique)
  List<String> _collectTags() {
    final typed = _tags.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final all = <String>{..._selectedTags, ...typed};
    return all.toList();
  }

  Future<void> _addImage() async {
    final url = await pickAndUploadImage(pathRoot: "questions");
    if (url == null) return;
    setState(() => _sources.add({"kind": "image", "url": url}));
  }

  void _removeImageAt(int index) {
    setState(() => _sources.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);

    final payload = {
      "title": _title.text,
      "body": _body.text,
      "tags": _collectTags(),
      "visibility": "public",
      "sources": _sources,
    };

    final id = await api.createQuestion(payload);

    setState(() => _saving = false);
    if (!mounted) return;

    if (id != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Question posted")),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to post question")),
      );
    }
  }

  // ------------ UI Parçaları ------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          const Icon(Icons.help_outline_rounded, size: 18),
          const SizedBox(width: 8),
          Text(
            "Ask a Question",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.send),
            label: Text(_saving ? "Posting..." : "Post"),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: "Title",
                  hintText: "E.g. How to integrate Supabase auth on web?",
                ),
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              // Body
              TextFormField(
                controller: _body,
                decoration: const InputDecoration(
                  labelText: "Body",
                  hintText: "Add details, what you tried, error messages, etc.",
                ),
                maxLines: 6,
              ),
              const SizedBox(height: 12),

              // Tags (metin) + önerilen etiketler
              TextFormField(
                controller: _tags,
                onTap: () {
                  if (!_tagsEditedOnce && _tags.text.isNotEmpty) {
                    // ilk tıklamada alanı temizle (örnek metin yazılıysa)
                    _tags.clear();
                  }
                  _tagsEditedOnce = true;
                },
                decoration: InputDecoration(
                  labelText: "Tags",
                  hintText: "Comma-separated (e.g. flutter, fastapi)",
                  helperText:
                  "Tip: Aşağıdaki önerilerden seçebilir veya kendi etiketlerini yazabilirsin.",
                  suffixIcon: IconButton(
                    tooltip: "Clear",
                    onPressed: () => _tags.clear(),
                    icon: const Icon(Icons.clear),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: -6,
                children: _suggestedTags.map((t) {
                  final sel = _selectedTags.contains(t);
                  return ChoiceChip(
                    label: Text(t),
                    selected: sel,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedTags.add(t);
                        } else {
                          _selectedTags.remove(t);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
              // Image picker + thumbnails grid
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _addImage,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text("Add image"),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _sources.isEmpty
                        ? "No images added"
                        : "${_sources.length} image(s) selected",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_sources.isNotEmpty) _buildImageGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    final imgs = _sources.where((s) => s['kind'] == 'image').toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: imgs.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 110,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (ctx, i) {
        final url = imgs[i]['url'] as String?;
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: url == null
                  ? const ColoredBox(color: Color(0x11000000))
                  : Image.network(url, fit: BoxFit.cover),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: Material(
                elevation: 1,
                shape: const CircleBorder(),
                color: Colors.black54,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    // grid’teki index -> kaynak listesindeki index’ini bul
                    final globalIndex = _sources.indexWhere((m) => m == imgs[i]);
                    if (globalIndex != -1) _removeImageAt(globalIndex);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            )
          ],
        );
      },
    );
  }

  Widget _buildPreviewCard() {
    final title = _title.text.trim();
    final body = _body.text.trim();
    final tags = _collectTags();
    final imgs = _sources.where((s) => s['kind'] == 'image').toList();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık + mini meta
            Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  child: Icon(Icons.person, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  "Preview",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Fake timestamp
                Text(
                  "now",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title.isEmpty ? "Your title will appear here" : title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              body.isEmpty ? "Your details will appear here…" : body,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 10),

            if (imgs.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 170,
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: imgs.length.clamp(0, 3),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisExtent: 170,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemBuilder: (ctx, i) {
                      final url = imgs[i]['url'] as String?;
                      return url == null
                          ? const ColoredBox(color: Color(0x11000000))
                          : Image.network(url, fit: BoxFit.cover);
                    },
                  ),
                ),
              ),

            if (tags.isNotEmpty) const SizedBox(height: 10),
            if (tags.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: -6,
                children: [
                  for (final t in tags)
                    Chip(label: Text(t), visualDensity: VisualDensity.compact),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Ask a Question",
      body: ListView(
        children: [
          _buildHeader(),
          _buildFormCard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Text(
              "Live Preview",
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          _buildPreviewCard(),
        ],
      ),
    );
  }
}
