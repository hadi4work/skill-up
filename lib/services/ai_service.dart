import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

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
    List<Map<String, String>>? history,
  }) async {
    try {
      final normalizedHistory = (history ?? const [])
          .where((m) => (m['role'] == 'user' || m['role'] == 'assistant') && (m['content'] ?? '').trim().isNotEmpty)
          .map((m) => {
                'role': m['role']!.trim(),
                'content': m['content']!.trim(),
              })
          .toList();
      final body = <String, dynamic>{
        'prompt': prompt,
        if (systemPrompt != null) 'systemPrompt': systemPrompt,
        if (model != null) 'model': model,
        if (normalizedHistory.isNotEmpty) 'history': normalizedHistory,
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
    List<Map<String, String>>? history,
  }) async {
    const systemHint = '''
أنت معلم مساعد. مهمتك شرح طريقة الحل بأسلوب تعليمي تدريجي.
- ابدأ بتوجيه واضح، ويمكنك تقديم خطوات حل مختصرة.
- لا تجعل الإجابة غامضة أو عامة فقط؛ قدّم منهجية عملية.
- لا تعطِ الحل النهائي مباشرة إلا إذا طلبه الطالب بوضوح.
- اكتب بالعربية.''';
    final prompt = studentAnswer != null && studentAnswer.isNotEmpty
        ? 'المادة: $subject\nالسؤال: $question\nما كتبه الطالب حتى الآن: $studentAnswer\nقدم تلميحاً واحداً فقط.'
        : 'المادة: $subject\nالسؤال: $question\nقدم تلميحاً واحداً يوجه الطالب دون إعطاء الحل.';
    return chat(
      prompt: prompt,
      systemPrompt: systemHint,
      history: history,
    );
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

  /// تصحيح إجابة مقالية بحسب سلم التصحيح وإرجاع درجة + ملاحظات
  Future<Map<String, dynamic>> gradeEssayAnswer({
    required String subject,
    required String question,
    required String rubric,
    required int maxPoints,
    required String studentAnswer,
  }) async {
    const systemPrompt = '''
أنت مصحح اختبارات دقيق.
المطلوب: إرجاع JSON فقط بدون أي نص إضافي بالشكل:
{"score": <number>, "feedback": "<short_arabic_feedback>"}
قواعد:
- score يجب أن يكون رقم صحيح بين 0 و maxPoints
- اعتمد حصراً على سلم التصحيح
- feedback مختصر ومباشر''';

    final prompt = '''
المادة: $subject
السؤال: $question
سلم التصحيح: $rubric
الدرجة القصوى: $maxPoints
إجابة الطالب: $studentAnswer
أعد JSON فقط.''';

    final text = await chat(prompt: prompt, systemPrompt: systemPrompt);

    try {
      final cleaned = text.trim();
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final jsonPart = cleaned.substring(start, end + 1);
        final parsed = json.decode(jsonPart) as Map<String, dynamic>;
        int score = (parsed['score'] as num?)?.round() ?? 0;
        if (score < 0) score = 0;
        if (score > maxPoints) score = maxPoints;
        final feedback = (parsed['feedback'] ?? '').toString().trim();
        return {
          'score': score,
          'feedback': feedback.isEmpty ? 'إجابة جيدة، راجع النقاط المطلوبة لرفع الدرجة.' : feedback,
        };
      }
    } catch (_) {}

    return {
      'score': 0,
      'feedback': 'تعذر تقييم الإجابة تلقائياً، تمت إعطاء درجة أولية 0 وتحتاج مراجعة المعلم.',
    };
  }

  /// إنشاء أسئلة تدريب قصيرة (اختيار من متعدد) اعتماداً على أخطاء الطالب.
  /// يعيد قائمة JSON من العناصر بالشكل:
  /// {"question":"...", "options":["...","...","...","..."], "correctIndex":1, "explanation":"..."}
  Future<List<Map<String, dynamic>>> generateMistakePracticeQuestions({
    required List<String> mistakeSeeds,
    required List<String> weakSubjects,
    int count = 8,
  }) async {
    const systemPrompt = '''
أنت مولّد أسئلة تدريب تعليمي بأسلوب Duolingo.
مهمتك إنتاج أسئلة قصيرة من نوع اختيار من متعدد فقط، مع تصحيح فوري.
أعد JSON فقط بدون أي نص إضافي بالشكل:
{"questions":[{"question":"...","options":["...","...","...","..."],"correctIndex":0,"explanation":"..."}]}
القواعد:
- اللغة العربية
- عدد الأسئلة = count
- الخيارات 4 لكل سؤال
- correctIndex بين 0 و 3
- explanation جملة قصيرة جدا
- الأسئلة تكون مشابهة للأخطاء/المواضيع الضعيفة
- لا تكرر نفس السؤال''';

    final seedsText = mistakeSeeds.isEmpty ? 'لا توجد أخطاء مفصلة، ركّز على الأساسيات.' : mistakeSeeds.join('\n- ');
    final subjectsText = weakSubjects.isEmpty ? 'عام' : weakSubjects.join('، ');

    final prompt = '''
المواضيع الضعيفة: $subjectsText
أخطاء/نقاط بحاجة تدريب:
- $seedsText
عدد الأسئلة المطلوب: $count
أعد JSON فقط.''';

    try {
      final text = await chat(prompt: prompt, systemPrompt: systemPrompt);
      final parsed = _extractJsonObject(text);
      final list = parsed['questions'];
      if (list is List) {
        final normalized = <Map<String, dynamic>>[];
        for (final item in list) {
          if (item is! Map) continue;
          final q = (item['question'] ?? '').toString().trim();
          final optionsRaw = item['options'];
          final options = optionsRaw is List ? optionsRaw.map((e) => e.toString()).take(4).toList() : <String>[];
          int correctIndex = (item['correctIndex'] as num?)?.toInt() ?? 0;
          if (q.isEmpty || options.length != 4) continue;
          if (correctIndex < 0 || correctIndex > 3) correctIndex = 0;
          normalized.add({
            'question': q,
            'options': options,
            'correctIndex': correctIndex,
            'explanation': (item['explanation'] ?? '').toString().trim(),
          });
        }
        if (normalized.isNotEmpty) return normalized.take(count).toList();
      }
    } catch (e) {
      debugPrint('AIService generateMistakePracticeQuestions error: $e');
    }

    return _fallbackPracticeQuestions(weakSubjects: weakSubjects, count: count);
  }

  /// اختبار تدريبي: نفس عدد عناصر [seeds]، إعادة صياغة وربما تغيير نوع السؤال مع الحفاظ على الإجابة الصحيحة.
  Future<List<Map<String, dynamic>>> generateMistakeRetestPack({
    required List<Map<String, dynamic>> seeds,
    required List<String> weakSubjects,
  }) async {
    if (seeds.isEmpty) return [];
    final fallback = _fallbackRetestPackFromSeeds(seeds);
    try {
      final seedsJson = json.encode(seeds);
      const systemPrompt = '''
أنت مصمم اختبارات تعليمي عربي.
تستقبل JSON لقائمة أخطاء الطالب؛ لكل عنصر يوجد id فريد.
المطلوب: مصفوفة items بنفس العدد ونفس ترتيب المدخلات ونفس قيم id حرفياً.

لكل عنصر أخرج سؤالاً واحداً:
- outputType واحد من: single_choice أو true_false أو essay
- يمكنك تغيير النوع عن originalType إذا حسّن التدريب، لكن المعنى والإجابة الصحيحة يجب أن يبقيا مكافئين للبيانات.
- single_choice: options من 2 إلى 4 نصوص عربية، وcorrectIndex (0..length-1).
- true_false: question جملة يقرر الطالب صحتها؛ correctIsTrue (true إذا الجملة صحيحة فعلاً).
- essay: question نص السؤال؛ essayRubric سلم تقييم قصير؛ referenceAnswer إجابة نموذجية قصيرة للمقارنة.

أعد JSON فقط بهذا الشكل:
{"items":[{"id":"...","outputType":"single_choice","question":"...","options":["",""],"correctIndex":0,"correctIsTrue":null,"explanation":"...","essayRubric":null,"referenceAnswer":null}]}
لا تضف مفاتيح أخرى. لا تترك options فارغة لنوع single_choice.
''';

      final prompt = '''
المواضيع الضعيفة: ${weakSubjects.isEmpty ? 'عام' : weakSubjects.join('، ')}
المدخلات (JSON):
$seedsJson

عدد العناصر المطلوب في items: ${seeds.length}
احفظ نفس ترتيب المصفوفة ونفس id لكل عنصر.
أعد JSON فقط.
''';

      final text = await chat(prompt: prompt, systemPrompt: systemPrompt);
      final parsed = _extractJsonObject(text);
      final list = parsed['items'];
      if (list is! List || list.length != seeds.length) {
        return fallback;
      }
      final out = <Map<String, dynamic>>[];
      for (var i = 0; i < seeds.length; i++) {
        final seed = seeds[i];
        final sid = seed['id']?.toString() ?? '';
        final item = list[i];
        if (item is! Map) return fallback;
        final mid = item['id']?.toString() ?? '';
        if (mid != sid) return fallback;
        final raw = Map<dynamic, dynamic>.from(item);
        out.add(Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v))));
      }
      final normalized = _normalizeRetestItems(out, seeds);
      if (normalized.length == seeds.length) return normalized;
    } catch (e) {
      debugPrint('AIService generateMistakeRetestPack error: $e');
    }
    return fallback;
  }

  List<Map<String, dynamic>> _fallbackRetestPackFromSeeds(List<Map<String, dynamic>> seeds) {
    return _normalizeRetestItems(
      seeds.map((s) {
        final id = s['id']?.toString() ?? '';
        final t = s['originalType']?.toString() ?? 'single_choice';
        if (t == 'true_false') {
          return {
            'id': id,
            'outputType': 'true_false',
            'question': s['questionText']?.toString() ?? '',
            'options': <String>[],
            'correctIndex': null,
            'correctIsTrue': s['correctIsTrue'] == true,
            'explanation': 'نفس فكرة سؤال صح/خطأ السابق.',
            'essayRubric': null,
            'referenceAnswer': null,
          };
        }
        if (t == 'essay' || t == 'assignment_weak') {
          return {
            'id': id,
            'outputType': 'essay',
            'question': s['questionText']?.toString() ?? '',
            'options': <String>[],
            'correctIndex': null,
            'correctIsTrue': null,
            'explanation': 'أعد صياغة إجابتك بشكل أوضح.',
            'essayRubric':
                (s['rubric'] ?? 'اذكر الفكرة الأساسية باختصار مع مثال أو تعريف إن لزم.').toString(),
            'referenceAnswer': 'راجع الملاحظات والشرح في الحصة.',
          };
        }
        final opts = List<String>.from(s['options'] as List? ?? []);
        final safe = opts.where((e) => e.toString().trim().isNotEmpty).map((e) => e.toString()).toList();
        while (safe.length < 2) {
          safe.addAll(['خيار ${safe.length + 1}', 'خيار ${safe.length + 2}']);
        }
        final ci = (s['correctOptionIndex'] as num?)?.toInt() ?? 0;
        final bounded = ci.clamp(0, safe.length - 1);
        return {
          'id': id,
          'outputType': 'single_choice',
          'question': s['questionText']?.toString() ?? '',
          'options': safe.take(4).toList(),
          'correctIndex': bounded,
          'correctIsTrue': null,
          'explanation': 'نفس المفهوم الذي أخطأت فيه.',
          'essayRubric': null,
          'referenceAnswer': null,
        };
      }).toList(),
      seeds,
    );
  }

  List<Map<String, dynamic>> _normalizeRetestItems(
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> seeds,
  ) {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length && i < seeds.length; i++) {
      final m = Map<String, dynamic>.from(items[i]);
      final seed = seeds[i];
      final id = seed['id']?.toString() ?? m['id']?.toString() ?? '';
      m['id'] = id;
      var ot = (m['outputType'] ?? 'single_choice').toString().trim();
      if (ot != 'single_choice' && ot != 'true_false' && ot != 'essay') {
        ot = 'single_choice';
      }
      m['outputType'] = ot;
      m['question'] = (m['question'] ?? seed['questionText'] ?? '').toString().trim();
      if (m['question'].isEmpty) {
        m['question'] = seed['questionText']?.toString() ?? 'سؤال';
      }
      m['explanation'] = (m['explanation'] ?? '').toString().trim();
      if (m['explanation'].isEmpty) m['explanation'] = 'أحسنت أو راجع الشرح.';

      if (ot == 'single_choice') {
        var opts = (m['options'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
        opts = opts.where((e) => e.trim().isNotEmpty).toList();
        if (opts.length < 2) {
          opts = List<String>.from(seed['options'] as List? ?? []);
          opts = opts.where((e) => e.toString().trim().isNotEmpty).map((e) => e.toString()).toList();
        }
        while (opts.length < 2) {
          opts.add('خيار');
        }
        if (opts.length > 4) opts = opts.sublist(0, 4);
        m['options'] = opts;
        var ci = (m['correctIndex'] as num?)?.toInt() ?? 0;
        if (ci < 0 || ci >= opts.length) {
          ci = ((seed['correctOptionIndex'] as num?)?.toInt() ?? 0).clamp(0, opts.length - 1);
        }
        m['correctIndex'] = ci;
        m['correctIsTrue'] = null;
        m['essayRubric'] = null;
        m['referenceAnswer'] = null;
      } else if (ot == 'true_false') {
        m['options'] = <String>[];
        if (m['correctIsTrue'] is! bool) {
          m['correctIsTrue'] = seed['correctIsTrue'] == true;
        }
        m['correctIndex'] = null;
        m['essayRubric'] = null;
        m['referenceAnswer'] = null;
      } else {
        m['options'] = <String>[];
        m['correctIndex'] = null;
        m['correctIsTrue'] = null;
        m['essayRubric'] = (m['essayRubric'] ?? seed['rubric'] ?? 'اذكر الفكرة الأساسية بوضوح.')
            .toString()
            .trim();
        m['referenceAnswer'] = (m['referenceAnswer'] ?? '').toString().trim();
        if (m['referenceAnswer'].isEmpty) {
          m['referenceAnswer'] = 'إجابة تتضمن المفاهيم الصحيحة دون الحاجة لنص حرفي.';
        }
      }
      out.add(m);
    }
    return out;
  }

  Map<String, dynamic> _extractJsonObject(String text) {
    final cleaned = text.trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      return {'questions': []};
    }
    final jsonPart = cleaned.substring(start, end + 1);
    final parsed = json.decode(jsonPart);
    if (parsed is Map<String, dynamic>) return parsed;
    return {'questions': []};
  }

  List<Map<String, dynamic>> _fallbackPracticeQuestions({
    required List<String> weakSubjects,
    required int count,
  }) {
    final topic = weakSubjects.isNotEmpty ? weakSubjects.first : 'المهارات الأساسية';
    final bank = <Map<String, dynamic>>[
      {
        'question': 'في تدريب $topic، ما أفضل طريقة لرفع الدرجة؟',
        'options': ['الحفظ فقط', 'الممارسة اليومية مع مراجعة الخطأ', 'ترك الأسئلة الصعبة', 'التخمين العشوائي'],
        'correctIndex': 1,
        'explanation': 'الممارسة مع مراجعة الأخطاء هي الأفضل.',
      },
      {
        'question': 'بعد إجابة خاطئة، ما الخطوة الأصح؟',
        'options': ['تجاهلها', 'قراءة سبب الخطأ ثم حل سؤال مشابه', 'تغيير المادة', 'إيقاف الدراسة'],
        'correctIndex': 1,
        'explanation': 'تحليل الخطأ ثم إعادة المحاولة يحسن الأداء.',
      },
      {
        'question': 'ما الهدف من التدريب بدون وقت؟',
        'options': ['السرعة فقط', 'الفهم العميق وتثبيت المفهوم', 'إنهاء أكبر عدد', 'تجاوز الأسئلة'],
        'correctIndex': 1,
        'explanation': 'التركيز يكون على الفهم لا السرعة.',
      },
    ];
    final out = <Map<String, dynamic>>[];
    for (int i = 0; i < count; i++) {
      out.add(bank[i % bank.length]);
    }
    return out;
  }
}
