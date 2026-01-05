// lib/services/storage_helper.dart
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String BUCKET_AVATARS = 'avatars';
const String BUCKET_CONTENT = 'content-media'; // ⬅️ use your real bucket name

final _supabase = Supabase.instance.client;

/// Pick an image and upload to content-media.
/// Returns a public URL (if the bucket has public read); otherwise a signed URL.
Future<String?> pickAndUploadImage({
  String pathRoot = 'questions',
  bool publicRead = true, // set false if your bucket is private
}) async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true, // important on web
  );
  if (picked == null || picked.files.isEmpty) return null;

  final file = picked.files.single;
  final bytes = file.bytes;
  if (bytes == null) return null;

  final ext = _ext(file.name) ?? 'jpg';
  final contentType = lookupMimeType(file.name) ?? 'image/$ext';
  final filename = '${DateTime.now().millisecondsSinceEpoch}.$ext';
  final objectPath = '$pathRoot/$filename';

  await _supabase.storage
      .from(BUCKET_CONTENT)
      .uploadBinary(objectPath, bytes, fileOptions: FileOptions(contentType: contentType));

  if (publicRead) {
    return _supabase.storage.from(BUCKET_CONTENT).getPublicUrl(objectPath);
  } else {
    final signed = await _supabase.storage.from(BUCKET_CONTENT).createSignedUrl(objectPath, 3600);
    return signed;
  }
}

Future<String?> uploadAvatar(Uint8List bytes, {bool publicRead = true}) async {
  final userId = _supabase.auth.currentUser?.id ?? 'anon';
  final key = 'avatars/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
  await _supabase.storage
      .from(BUCKET_AVATARS)
      .uploadBinary(key, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
  return publicRead
      ? _supabase.storage.from(BUCKET_AVATARS).getPublicUrl(key)
      : (await _supabase.storage.from(BUCKET_AVATARS).createSignedUrl(key, 3600));
}

String? _ext(String name) {
  final i = name.lastIndexOf('.');
  if (i < 0 || i == name.length - 1) return null;
  return name.substring(i + 1).toLowerCase();
}
