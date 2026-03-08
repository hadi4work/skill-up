import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:textify/textify.dart';

/// خدمة استخراج النص من الصور (OCR) باستخدام Textify محلياً
/// تدعم النص الرقمي الواضح. للعربية أو الخط اليدوي يمكن استخدام استخراج النص بالذكاء الاصطناعي.
class OcrService {
  Textify? _textify;
  bool _initDone = false;

  Future<Textify> _getTextify() async {
    if (_textify != null && _initDone) return _textify!;
    _textify = Textify();
    _textify!.applyDictionary = true;
    await _textify!.init();
    _initDone = true;
    return _textify!;
  }

  Future<ui.Image> _fileToUiImage(File file) async {
    final bytes = await file.readAsBytes();
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(Uint8List.fromList(bytes), (ui.Image img) {
      if (!completer.isCompleted) completer.complete(img);
    });
    return completer.future;
  }

  /// استخراج النص من ملف صورة (محلي - Textify)
  Future<String> processImageFromFile(File imageFile) async {
    if (!imageFile.existsSync()) {
      throw 'ملف الصورة غير موجود';
    }
    try {
      final ui.Image image = await _fileToUiImage(imageFile);
      final textify = await _getTextify();
      final String text = await textify.getTextFromImage(image: image);
      image.dispose();
      return text.trim();
    } catch (e) {
      debugPrint('OCR processImageFromFile error: $e');
      rethrow;
    }
  }

  /// استخراج النص من صورة عبر رابط (تحميل مؤقت ثم المعالجة)
  Future<String> processImageFromUrl(String imageUrl) async {
    if (imageUrl.isEmpty) throw 'رابط الصورة فارغ';
    File? tempFile;
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw 'فشل تحميل الصورة: ${response.statusCode}';
      }
      final dir = await getTemporaryDirectory();
      final ext = path.extension(Uri.parse(imageUrl).path);
      final name =
          'ocr_${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.jpg' : ext}';
      tempFile = File(path.join(dir.path, name));
      await tempFile.writeAsBytes(response.bodyBytes);
      return await processImageFromFile(tempFile);
    } finally {
      try {
        if (tempFile != null && tempFile.existsSync()) {
          tempFile.deleteSync();
        }
      } catch (_) {}
    }
  }

  /// تحرير الموارد
  void dispose() {
    _textify = null;
    _initDone = false;
  }
}
