import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// استدعاء الذكاء الاصطناعي عبر Supabase Edge Function
/// الطلبات تذهب إلى Supabase (يعمل من سوريا) والسيرفر يستدعي Groq
class AIService {
  SupabaseClient get _client => Supabase.instance.client;

  /// إرسال سؤال والحصول على رد النموذج
  /// [prompt] نص السؤال أو الطلب
  /// [systemPrompt] تعليمات للنموذج (اختياري)، افتراضي: مساعد تعليمي بالعربية
  Future<String> chat({
    required String prompt,
    String? systemPrompt,
    String? model,
  }) async {
    try {
      final body = <String, dynamic>{
        'prompt': prompt,
        if (systemPrompt != null) 'systemPrompt': systemPrompt,
        if (model != null) 'model': model,
      };
      final response = await _client.functions.invoke(
        'ai-chat',
        body: body,
      );
      if (response.status != 200) {
        final err = response.data is Map ? (response.data as Map)['error'] : response.data;
        throw err ?? 'خطأ من السيرفر: ${response.status}';
      }
      final data = response.data as Map<String, dynamic>?;
      final text = data?['text'] as String?;
      return text?.trim() ?? '';
    } catch (e) {
      debugPrint('AIService chat error: $e');
      rethrow;
    }
  }

  /// طلب تلميح تعليمي (بدون إعطاء الإجابة المباشرة)
  Future<String> getHint({
    required String subject,
    required String question,
    String? studentAnswer,
  }) async {
    const systemHint = '''
أنت معلم مساعد. مهمتك تقديم تلميح (Hint) فقط للطالب ليتوصل للحل بنفسه.
- لا تعطِ الإجابة النهائية أو الحل الكامل.
- قدّم توجيهاً قصيراً أو خطوة واحدة مقترحة أو سؤالاً يوجه تفكيره.
- اكتب بالعربية.''';
    final prompt = studentAnswer != null && studentAnswer.isNotEmpty
        ? 'المادة: $subject\nالسؤال: $question\nما كتبه الطالب حتى الآن: $studentAnswer\nقدم تلميحاً واحداً فقط.'
        : 'المادة: $subject\nالسؤال: $question\nقدم تلميحاً واحداً يوجه الطالب دون إعطاء الحل.';
    return chat(prompt: prompt, systemPrompt: systemHint);
  }

  /// استخراج النص من صورة باستخدام الذكاء الاصطناعي (Groq Vision)
  /// [imageBase64] الصورة بصيغة base64 (بدون أو مع بادئة data:image/...;base64,)
  Future<String> extractTextFromImage(String imageBase64) async {
    try {
      final body = <String, dynamic>{
        'imageBase64': imageBase64.startsWith('data:')
            ? imageBase64
            : imageBase64,
      };
      final response = await _client.functions.invoke(
        'ai-extract-text',
        body: body,
      );
      if (response.status != 200) {
        final err = response.data is Map
            ? (response.data as Map)['error']
            : response.data;
        throw err ?? 'خطأ من السيرفر: ${response.status}';
      }
      final data = response.data as Map<String, dynamic>?;
      final text = data?['text'] as String?;
      return text?.trim() ?? '';
    } catch (e) {
      debugPrint('AIService extractTextFromImage error: $e');
      rethrow;
    }
  }
}
