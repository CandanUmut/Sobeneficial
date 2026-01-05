import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

class EventsCreateScreen extends StatefulWidget {
  const EventsCreateScreen({super.key});
  @override
  State<EventsCreateScreen> createState() => _EventsCreateScreenState();
}

class _EventsCreateScreenState extends State<EventsCreateScreen> {
  final _form = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController(text: "https://meet.example.com/room");
  final _capacity = TextEditingController(text: "100");
  final _tags = TextEditingController();
  final _coverImage = TextEditingController();

  String _type = "webinar";        // course | webinar | workshop
  String _visibility = "public";   // public | private
  DateTime _starts = DateTime.now().add(const Duration(days: 1, hours: 1));

  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _location.dispose();
    _capacity.dispose();
    _tags.dispose();
    _coverImage.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    // pick date
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _starts,
    );
    if (d == null) return;

    // pick time
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _starts.hour, minute: _starts.minute),
    );
    if (t == null) return;

    setState(() {
      _starts = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  String _fmtDT(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return "$dd.$mm.$yyyy  $hh:$min";
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);

    final tagsList = _tags.text
        .split(",")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final payload = {
      "title": _title.text.trim(),
      "description": _desc.text.trim(),
      "type": _type,
      "starts_at": _starts.toUtc().toIso8601String(),
      "location": _location.text.trim(),
      "capacity": int.tryParse(_capacity.text.trim()),
      "tags": tagsList,
      "visibility": _visibility,
      "cover_image": _coverImage.text.trim().isEmpty
          ? null
          : _coverImage.text.trim(),
    };

    final id = await api.createEvent(payload);

    setState(() => _saving = false);

    if (!mounted) return;

    if (id != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Event created")),
      );
      // After create, go to event detail if you have a route for it.
      // Otherwise you can Navigator.pop(context).
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(eventId: id),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Create failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "New Event",
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: ListView(
            children: [
              // Title
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: "Title",
                  hintText: "Example: Mental Health Support Circle (TR)",
                ),
                validator: (v) =>
                v == null || v.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _desc,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Description",
                  hintText:
                  "What is this about? Who is it for? Do people need to prepare anything?",
                ),
              ),
              const SizedBox(height: 12),

              // Type
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: "Format",
                  helperText: "How should people think about this event?",
                ),
                items: const [
                  DropdownMenuItem(
                    value: "course",
                    child: Text("Course / Series"),
                  ),
                  DropdownMenuItem(
                    value: "webinar",
                    child: Text("Webinar / Talk"),
                  ),
                  DropdownMenuItem(
                    value: "workshop",
                    child: Text("Workshop / Interactive"),
                  ),
                ],
                onChanged: (v) => setState(() => _type = v ?? "webinar"),
              ),
              const SizedBox(height: 12),

              // Date & Time picker
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Starts at",
                    helperText: "Tap to change date & time",
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule),
                      const SizedBox(width: 8),
                      Text(_fmtDT(_starts)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Location / link
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: "Location / Join link",
                  helperText:
                  "Physical address or a meeting link. We'll show this only to attendees.",
                ),
                validator: (v) =>
                v == null || v.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),

              // Capacity
              TextFormField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Capacity",
                  helperText:
                  "Max seats / attendees you want to handle comfortably.",
                ),
              ),
              const SizedBox(height: 12),

              // Tags
              TextFormField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: "Tags",
                  helperText:
                  "Comma separated, e.g. 'refugee support, trauma, legal rights'",
                ),
              ),
              const SizedBox(height: 12),

              // Cover image
              TextFormField(
                controller: _coverImage,
                decoration: const InputDecoration(
                  labelText: "Cover image URL (optional)",
                  helperText:
                  "We'll show this as a banner image in the event detail.",
                ),
              ),
              const SizedBox(height: 12),

              // Visibility
              DropdownButtonFormField<String>(
                value: _visibility,
                decoration: const InputDecoration(
                  labelText: "Visibility",
                  helperText:
                  "Public events are visible to everyone. Private ones might be invite-only.",
                ),
                items: const [
                  DropdownMenuItem(
                    value: "public",
                    child: Text("Public - visible to all"),
                  ),
                  DropdownMenuItem(
                    value: "private",
                    child: Text("Private - share link manually"),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _visibility = v ?? "public"),
              ),
              const SizedBox(height: 24),

              // Submit
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: const Icon(Icons.check),
                label: Text(_saving ? "Saving..." : "Create Event"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// NOTE: this uses EventDetailScreen below
class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}


class _EventDetailScreenState extends State<EventDetailScreen> {
  Map<String, dynamic>? _event;
  bool _loading = true;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmtDT(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return "$dd.$mm.$yyyy  $hh:$min";
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ev = await api.getEvent(widget.eventId);
      if (!mounted) return;
      if (ev == null) {
        setState(() {
          _event = null;
          _loading = false;
          _error = "Not found";
        });
        return;
      }
      setState(() {
        _event = ev;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _join() async {
    if (_joining) return;
    setState(()=>_joining=true);
    final ok = await api.rsvpEvent(widget.eventId);
    if (!mounted) return;
    setState(()=>_joining=false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You're in! We'll share join details when it's time.")),
      );
      _load(); // refresh attending_count
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("RSVP failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        title: "Event",
        body: Loading(),
      );
    }

    if (_error != null) {
      return AppScaffold(
        title: "Event",
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text("Error: $_error"),
          ),
        ),
      );
    }

    if (_event == null) {
      return const AppScaffold(
        title: "Event",
        body: Empty("Not found"),
      );
    }

    final e = _event!;
    final title = (e["title"] ?? "") as String;
    final desc = (e["description"] ?? "") as String? ?? "";
    final type = (e["type"] ?? "") as String? ?? "";
    final startsIso = (e["starts_at"] ?? "") as String;
    final startsDT = DateTime.tryParse(startsIso)?.toLocal();
    final loc = (e["location"] ?? "") as String? ?? "";
    final capacity = (e["capacity"] as num?)?.toInt() ?? 0;
    final going = (e["attending_count"] as num?)?.toInt() ?? 0;
    final cover = (e["cover_image"] ?? "") as String? ?? "";
    final visibility = (e["visibility"] ?? "") as String? ?? "public";
    final tags = (e["tags"] as List?)?.cast<String>() ?? const [];

    final host = (e["host"] ?? {}) as Map<String,dynamic>;
    final hostName = (host["full_name"] ?? host["username"] ?? "") as String? ?? "";
    final hostRegion = (host["region"] ?? "") as String? ?? "";
    final hostLangs = (host["languages"] as List?)?.cast<String>() ?? const [];
    final hostAvg = (host["avg_stars"] is num) ? (host["avg_stars"] as num).toDouble() : 0.0;
    final hostCnt = (host["ratings_count"] as num?)?.toInt() ?? 0;
    final hostVerified = (host["verified"] ?? false) as bool;

    return AppScaffold(
      title: title,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // cover / hero
            if (cover.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16/9,
                  child: Image.network(
                    cover,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade300,
                      child: const Center(child: Icon(Icons.image_not_supported)),
                    ),
                  ),
                ),
              ),
            if (cover.isNotEmpty) const SizedBox(height: 16),

            // core info card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // title + visibility
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(visibility),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // type chip, date/time, capacity/going
                    Wrap(
                      spacing: 8,
                      runSpacing: -6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (type.isNotEmpty)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.category, size: 16),
                            label: Text(type),
                          ),
                        if (startsDT != null)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.schedule, size: 16),
                            label: Text(_fmtDT(startsDT)),
                          ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.people_outline, size: 16),
                          label: Text("$going / $capacity going"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    if (desc.isNotEmpty)
                      Text(
                        desc,
                        style: const TextStyle(height: 1.4),
                      ),
                    const SizedBox(height: 12),

                    if (tags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: -6,
                        children: [
                          for (final t in tags)
                            Chip(
                              label: Text(t),
                              visualDensity: VisualDensity.compact,
                            )
                        ],
                      ),

                    const SizedBox(height: 16),
                    // Location note
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            loc.isNotEmpty
                                ? loc
                                : "Location will be shared privately with attendees.",
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // host / organizer trust block
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      child: Text(
                        hostName.isNotEmpty
                            ? hostName[0].toUpperCase()
                            : "?",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  hostName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (hostVerified) ...[
                                const Icon(Icons.verified, size: 16, color: Colors.green),
                                const SizedBox(width: 4),
                                const Text(
                                  "Verified",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (hostRegion.isNotEmpty || hostLangs.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: -6,
                              children: [
                                if (hostRegion.isNotEmpty)
                                  Chip(
                                    label: Text(hostRegion),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                for (final l in hostLangs)
                                  Chip(
                                    label: Text(l),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.star_rate_rounded, size: 16),
                              const SizedBox(width: 4),
                              Text("${hostAvg.toStringAsFixed(1)} ($hostCnt)"),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "This organizer has offered community help. "
                                "Their rating is from verified beneficiaries.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // RSVP / join button
            FilledButton.icon(
              onPressed: _joining ? null : _join,
              icon: const Icon(Icons.event_available),
              label: Text(_joining ? "Joining..." : "RSVP / Join"),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
