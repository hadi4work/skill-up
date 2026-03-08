import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// تخزين الصور في Supabase Storage (يعمل من سوريا) - Firebase يبقى للـ Auth و Firestore
class StorageService {
  static const String _bucket = SupabaseConfig.storageBucket;

  SupabaseClient get _client => Supabase.instance.client;

  /// رفع صورة الواجب → يُرجع رابط عام من Supabase
  Future<String> uploadAssignmentImage(File imageFile, String assignmentId) async {
    try {
      final path =
          'assignments/$assignmentId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from(_bucket).upload(
            path,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = _client.storage.from(_bucket).getPublicUrl(path);
      return url;
    } catch (e) {
      debugPrint('Error uploading assignment image: $e');
      throw 'حدث خطأ أثناء رفع صورة الواجب: $e';
    }
  }

  /// رفع صورة التسليم → يُرجع رابط عام من Supabase
  Future<String> uploadSubmissionImage(File imageFile, String submissionId) async {
    try {
      final path =
          'submissions/$submissionId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from(_bucket).upload(
            path,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = _client.storage.from(_bucket).getPublicUrl(path);
      return url;
    } catch (e) {
      debugPrint('Error uploading submission image: $e');
      throw 'حدث خطأ أثناء رفع صورة الحل: $e';
    }
  }

  /// حذف صورة (يدعم روابط Supabase فقط؛ روابط Firebase القديمة تُتجاهل)
  Future<void> deleteImage(String imageUrl) async {
    try {
      final path = _pathFromSupabaseUrl(imageUrl);
      if (path == null) return;
      await _client.storage.from(_bucket).remove([path]);
    } catch (e) {
      debugPrint('Error deleting image: $e');
    }
  }

  /// استخراج المسار من رابط Supabase العام
  /// مثال: .../object/public/images/assignments/xxx/1.jpg → assignments/xxx/1.jpg
  String? _pathFromSupabaseUrl(String imageUrl) {
    const prefix = '/object/public/$_bucket/';
    final i = imageUrl.indexOf(prefix);
    if (i == -1) return null;
    return imageUrl.substring(i + prefix.length);
  }
}
