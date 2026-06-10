import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/ai_service.dart';
import '../../services/mistake_training_service.dart';
import '../../services/user_service.dart';

class StudentMistakeTrainingScreen extends StatefulWidget {
  final String studentId;
  final List<String> classIds;

  const StudentMistakeTrainingScreen({
    super.key,
    required this.studentId,
    required this.classIds,
  });

  @override
  State<StudentMistakeTrainingScreen> createState() => _StudentMistakeTrainingScreenState();
}

class _PracticeQuestion {
  final String pendingId;
  final String practiceType;
  final String question;
  final List<String> options;
  final int? correctIndex;
  final bool? correctIsTrue;
  final String explanation;
  final String subject;
  final String? essayRubric;
  final String? referenceAnswer;

  const _PracticeQuestion({
    required this.pendingId,
    required this.practiceType,
    required this.question,
    required this.options,
    this.correctIndex,
    this.correctIsTrue,
    required this.explanation,
    required this.subject,
    this.essayRubric,
    this.referenceAnswer,
  });
}

class _StudentMistakeTrainingScreenState extends State<StudentMistakeTrainingScreen> {
  final MistakeTrainingService _mistakeService = MistakeTrainingService();
  final AIService _aiService = AIService();
  final UserService _userService = UserService();

  bool _isLoading = true;
  String? _error;
  String _emptyMessage = 'لا توجد عناصر تحتاج مراجعة';
  List<_PracticeQuestion> _questions = [];
  int _currentIndex = 0;
  int? _selectedIndex;
  bool _answered = false;
  int _correctCount = 0;
  bool _sessionSaved = false;
  int _currentStreakDays = 0;
  final Set<String> _masteredPendingIds = {};
  final TextEditingController _essayController = TextEditingController();
  bool _essayGrading = false;
  String? _essayFeedback;
  int? _essayScore;

  static const int _essayMaxPoints = 10;
  static const double _essayPassRatio = 0.65;

  Future<void> _playCorrectSound() async {
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> _playWrongSound() async {
    await SystemSound.play(SystemSoundType.alert);
  }

  Future<void> _playFinishSound() async {
    await SystemSound.play(SystemSoundType.click);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await SystemSound.play(SystemSoundType.click);
  }

  @override
  void dispose() {
    _essayController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadTraining();
  }

  Future<void> _loadTraining() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _emptyMessage = 'لا توجد عناصر تحتاج مراجعة';
      _questions = [];
      _currentIndex = 0;
      _selectedIndex = null;
      _answered = false;
      _correctCount = 0;
      _sessionSaved = false;
      _masteredPendingIds.clear();
      _essayController.clear();
      _essayGrading = false;
      _essayFeedback = null;
      _essayScore = null;
    });

    try {
      final mastered = await _userService.getMistakeTrainingMasteredIds(widget.studentId);
      final discovered = await _mistakeService.discoverMistakeItems(
        studentId: widget.studentId,
        classIds: widget.classIds,
        excludeIds: mastered,
      );
      await _userService.syncMistakeTrainingPending(widget.studentId, discovered);

      final pending = await _userService.getMistakeTrainingPending(widget.studentId);
      if (pending.isEmpty) {
        if (!mounted) return;
        setState(() {
          _emptyMessage =
              'ممتاز! لا توجد لديك أخطاء تحتاج مراجعة حالياً — أحسنت 💪';
          _isLoading = false;
        });
        await _loadCurrentStreak();
        return;
      }

      final weakSubjects = pending
          .map((e) => e['subject']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .take(5)
          .toList();

      final pack = await _aiService.generateMistakeRetestPack(
        seeds: pending,
        weakSubjects: weakSubjects.toList(),
      );

      final built = <_PracticeQuestion>[];
      for (var i = 0; i < pending.length && i < pack.length; i++) {
        final seed = pending[i];
        final item = pack[i];
        final id = seed['id']?.toString() ?? '';
        final subject = seed['subject']?.toString() ?? 'عام';
        final ot = item['outputType']?.toString() ?? 'single_choice';

        if (ot == 'essay') {
          built.add(
            _PracticeQuestion(
              pendingId: id,
              practiceType: 'essay',
              question: item['question']?.toString() ?? '',
              options: const [],
              explanation: item['explanation']?.toString() ?? '',
              subject: subject,
              essayRubric: item['essayRubric']?.toString(),
              referenceAnswer: item['referenceAnswer']?.toString(),
            ),
          );
        } else if (ot == 'true_false') {
          built.add(
            _PracticeQuestion(
              pendingId: id,
              practiceType: 'true_false',
              question: item['question']?.toString() ?? '',
              options: const [],
              correctIsTrue: item['correctIsTrue'] == true,
              explanation: item['explanation']?.toString() ?? '',
              subject: subject,
            ),
          );
        } else {
          final opts = List<String>.from(item['options'] as List? ?? []);
          final ci = (item['correctIndex'] as num?)?.toInt() ?? 0;
          built.add(
            _PracticeQuestion(
              pendingId: id,
              practiceType: 'single_choice',
              question: item['question']?.toString() ?? '',
              options: opts,
              correctIndex: ci.clamp(0, opts.isEmpty ? 0 : opts.length - 1),
              explanation: item['explanation']?.toString() ?? '',
              subject: subject,
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _questions = built;
        _isLoading = false;
      });
      await _loadCurrentStreak();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCurrentStreak() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.studentId).get();
      final data = doc.data() ?? <String, dynamic>{};
      final streak = (data['mistakeTrainingStreakDays'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      setState(() {
        _currentStreakDays = streak;
      });
    } catch (_) {}
  }

  bool _isMcCorrect(_PracticeQuestion q) => _selectedIndex != null && _selectedIndex == q.correctIndex;

  bool _isTfCorrect(_PracticeQuestion q) {
    if (_selectedIndex == null || q.correctIsTrue == null) return false;
    final studentSaysTrue = _selectedIndex == 0;
    return studentSaysTrue == q.correctIsTrue;
  }

  Future<void> _submitMcOrTf() async {
    if (_selectedIndex == null || _answered || _questions.isEmpty) return;
    final q = _questions[_currentIndex];
    bool ok = false;
    if (q.practiceType == 'single_choice') {
      ok = _isMcCorrect(q);
    } else if (q.practiceType == 'true_false') {
      ok = _isTfCorrect(q);
    } else {
      return;
    }
    setState(() {
      _answered = true;
      if (ok) {
        _correctCount += 1;
        _masteredPendingIds.add(q.pendingId);
      }
    });
    if (ok) {
      await _playCorrectSound();
    } else {
      await _playWrongSound();
    }
    if (ok && q.pendingId.isNotEmpty) {
      try {
        await _userService.removeMistakeTrainingResolved(
          widget.studentId,
          [q.pendingId],
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذر حفظ إزالة العنصر: $e', style: GoogleFonts.cairo()),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  Future<void> _submitEssay() async {
    final q = _questions[_currentIndex];
    if (q.practiceType != 'essay' || _answered || _essayGrading) return;
    final text = _essayController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('اكتب إجابة قبل التحقق', style: GoogleFonts.cairo())),
      );
      return;
    }

    setState(() {
      _essayGrading = true;
      _essayFeedback = null;
      _essayScore = null;
    });

    try {
      final rubric = (q.essayRubric ?? '').trim().isEmpty
          ? 'قيم مدى وضوح الإجابة وصحتها الفكرية بالنسبة للسؤال.'
          : q.essayRubric!.trim();
      final refAns = (q.referenceAnswer ?? '').trim();
      final combinedRubric =
          '$rubric\nإجابة مرجعية مختصرة (لا تنسخها حرفياً للطالب): $refAns';

      final graded = await _aiService.gradeEssayAnswer(
        subject: q.subject,
        question: q.question,
        rubric: combinedRubric,
        maxPoints: _essayMaxPoints,
        studentAnswer: text,
      );
      final score = (graded['score'] as num?)?.round() ?? 0;
      final pass = score >= (_essayMaxPoints * _essayPassRatio).ceil();
      if (!mounted) return;
      setState(() {
        _essayGrading = false;
        _answered = true;
        _essayScore = score;
        _essayFeedback = graded['feedback']?.toString();
        if (pass) {
          _correctCount += 1;
          _masteredPendingIds.add(q.pendingId);
        }
      });
      if (pass) {
        await _playCorrectSound();
      } else {
        await _playWrongSound();
      }
      if (pass && q.pendingId.isNotEmpty) {
        try {
          await _userService.removeMistakeTrainingResolved(
            widget.studentId,
            [q.pendingId],
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تعذر حفظ إزالة العنصر: $e', style: GoogleFonts.cairo()),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _essayGrading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر التحقق: $e', style: GoogleFonts.cairo())),
      );
    }
  }

  void _next() {
    if (_currentIndex >= _questions.length - 1) return;
    setState(() {
      _currentIndex += 1;
      _selectedIndex = null;
      _answered = false;
      _essayController.clear();
      _essayFeedback = null;
      _essayScore = null;
    });
  }

  Future<void> _finishTrainingSession() async {
    if (_sessionSaved) {
      if (mounted) Navigator.pop(context);
      return;
    }
    try {
      if (_masteredPendingIds.isNotEmpty) {
        await _userService.removeMistakeTrainingResolved(
          widget.studentId,
          _masteredPendingIds.toList(),
        );
      }

      final result = await _userService.recordMistakeTrainingSession(
        uid: widget.studentId,
        totalQuestions: _questions.length,
        correctAnswers: _correctCount,
      );
      await _playFinishSound();
      _sessionSaved = true;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('نتيجة التدريب', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إجابات صحيحة: $_correctCount / ${_questions.length}', style: GoogleFonts.cairo()),
              if (_masteredPendingIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'تمت إزالة ${_masteredPendingIds.length} عنصراً من قائمة المراجعة.',
                  style: GoogleFonts.cairo(color: const Color(0xFF059669), fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 8),
              Text('XP المكتسب: +${result.gainedXP}', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('السلسلة اليومية: ${result.streakDays} يوم', style: GoogleFonts.cairo()),
              const SizedBox(height: 6),
              Text('المستوى الحالي: ${result.newLevel}', style: GoogleFonts.cairo()),
              if (result.streakIncreased) ...[
                const SizedBox(height: 8),
                Text('🔥 رائع! تم الحفاظ على السلسلة اليومية.', style: GoogleFonts.cairo(color: const Color(0xFFB45309))),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ممتاز', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ نتيجة التدريب: $e', style: GoogleFonts.cairo())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('التعلّم من الأخطاء', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _loadTraining,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('تعذر تحميل التدريب: $_error', style: GoogleFonts.cairo()),
                  ),
                )
              : _questions.isEmpty
                  ? Center(child: Text(_emptyMessage, style: GoogleFonts.cairo(fontSize: 16)))
                  : _buildTrainingBody(),
    );
  }

  String _typeChip(_PracticeQuestion q) {
    switch (q.practiceType) {
      case 'essay':
        return 'مقالي';
      case 'true_false':
        return 'صح وخطأ';
      default:
        return 'اختياري';
    }
  }

  Widget _buildTrainingBody() {
    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;
    final isLast = _currentIndex == _questions.length - 1;
    final bool isCorrect = q.practiceType == 'essay'
        ? (_essayScore != null && _essayScore! >= (_essayMaxPoints * _essayPassRatio).ceil())
        : q.practiceType == 'true_false'
            ? _isTfCorrect(q)
            : _isMcCorrect(q);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              'سؤال ${_currentIndex + 1}/${_questions.length}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _typeChip(q),
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '🔥 $_currentStreakDays',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: const Color(0xFFB45309)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '✅ $_correctCount',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: const Color(0xFF16A34A)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(99),
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.question,
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (q.practiceType == 'single_choice')
                      ...List.generate(q.options.length, (i) {
                        return _optionTile(
                          label: q.options[i],
                          index: i,
                          correctIndex: q.correctIndex ?? 0,
                        );
                      }),
                    if (q.practiceType == 'true_false') ...[
                      _optionTile(
                        label: 'صح',
                        index: 0,
                        correctIndex: q.correctIsTrue == true ? 0 : 1,
                      ),
                      _optionTile(
                        label: 'خطأ',
                        index: 1,
                        correctIndex: q.correctIsTrue == true ? 0 : 1,
                      ),
                    ],
                    if (q.practiceType == 'essay') ...[
                      TextField(
                        controller: _essayController,
                        maxLines: 8,
                        readOnly: _answered,
                        style: GoogleFonts.cairo(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'اكتب إجابتك...',
                          hintStyle: GoogleFonts.cairo(color: const Color(0xFF9CA3AF)),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                    if (_answered) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                              : const Color(0xFFDC2626).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCorrect ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCorrect ? 'إجابة مقبولة ✓' : 'ما زال يحتاج مراجعة',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isCorrect ? const Color(0xFF166534) : const Color(0xFF991B1B),
                              ),
                            ),
                            if (q.practiceType == 'essay' && _essayScore != null) ...[
                              const SizedBox(height: 4),
                              Text('الدرجة: $_essayScore / $_essayMaxPoints', style: GoogleFonts.cairo()),
                            ],
                            if ((_essayFeedback ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(_essayFeedback!, style: GoogleFonts.cairo(fontSize: 13)),
                            ],
                            if (!isCorrect && q.explanation.isNotEmpty)
                              Text(q.explanation, style: GoogleFonts.cairo(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _buildBottomButton(q, isLast, isCorrect),
          ),
        ],
      ),
    );
  }

  Widget _optionTile({
    required String label,
    required int index,
    required int correctIndex,
  }) {
    final q = _questions[_currentIndex];
    final selected = _selectedIndex == index;
    final showCorrect = _answered && index == correctIndex;
    final showWrong = _answered && selected && index != correctIndex;
    final borderColor = showCorrect
        ? const Color(0xFF16A34A)
        : showWrong
            ? const Color(0xFFDC2626)
            : selected
                ? const Color(0xFF2563EB)
                : const Color(0xFFE5E7EB);
    final bg = showCorrect
        ? const Color(0xFF16A34A).withValues(alpha: 0.09)
        : showWrong
            ? const Color(0xFFDC2626).withValues(alpha: 0.09)
            : selected
                ? const Color(0xFF2563EB).withValues(alpha: 0.09)
                : const Color(0xFFF9FAFB);

    return InkWell(
      onTap: (_answered || q.practiceType == 'essay') ? null : () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(
              showCorrect
                  ? Icons.check_circle
                  : showWrong
                      ? Icons.cancel
                      : selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
              color: showCorrect
                  ? const Color(0xFF16A34A)
                  : showWrong
                      ? const Color(0xFFDC2626)
                      : selected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: GoogleFonts.cairo(fontSize: 15))),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton(_PracticeQuestion q, bool isLast, bool isCorrect) {
    if (q.practiceType == 'essay' && !_answered) {
      return ElevatedButton(
        onPressed: _essayGrading ? null : _submitEssay,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _essayGrading
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text('تحقق من الإجابة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      );
    }
    if (!_answered && q.practiceType != 'essay') {
      return ElevatedButton(
        onPressed: _selectedIndex == null ? null : () => _submitMcOrTf(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('تحقق من الإجابة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      );
    }
    return ElevatedButton(
      onPressed: isLast ? _finishTrainingSession : _next,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        isLast ? 'إنهاء التدريب' : 'السؤال التالي',
        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
      ),
    );
  }
}
