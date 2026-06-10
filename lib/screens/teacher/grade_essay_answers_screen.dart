import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/exam_attempt_answer_model.dart';
import '../../models/exam_attempt_model.dart';
import '../../models/exam_model.dart';
import '../../models/exam_question_model.dart';
import '../../services/exam_service.dart';

class GradeEssayAnswersScreen extends StatefulWidget {
  final ExamModel exam;
  const GradeEssayAnswersScreen({super.key, required this.exam});

  @override
  State<GradeEssayAnswersScreen> createState() => _GradeEssayAnswersScreenState();
}

class _GradeEssayAnswersScreenState extends State<GradeEssayAnswersScreen> {
  final ExamService _examService = ExamService();
  bool _isLoading = true;
  String? _error;
  final List<ExamAttemptModel> _attempts = [];
  final Map<String, int> _answersCountByAttempt = {};
  final Map<String, String> _studentNames = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final attempts = await _examService.getExamAttemptsForTeacher(widget.exam.id);
      final names = await _examService.getStudentNamesForAttempts(attempts);

      final answerCounts = <String, int>{};
      for (final attempt in attempts) {
        final answers = await _examService.getAttemptAnswers(attempt.id);
        answerCounts[attempt.id] = answers.length;
      }

      if (!mounted) return;
      setState(() {
        _attempts
          ..clear()
          ..addAll(attempts);
        _studentNames
          ..clear()
          ..addAll(names);
        _answersCountByAttempt
          ..clear()
          ..addAll(answerCounts);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تسليمات الطلاب', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('حدث خطأ أثناء التحميل: $_error', style: GoogleFonts.cairo()),
                  ),
                )
              : _attempts.isEmpty
                  ? Center(child: Text('لا توجد تسليمات بعد', style: GoogleFonts.cairo()))
                  : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _attempts.length,
                  itemBuilder: (_, i) {
                    final attempt = _attempts[i];
                    final studentName = _studentNames[attempt.studentId] ?? 'طالب';
                    final answersCount = _answersCountByAttempt[attempt.id] ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.person, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(studentName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'عدد الإجابات: $answersCount',
                                    style: GoogleFonts.cairo(color: const Color(0xFF6B7280), fontSize: 13),
                                  ),
                                  Text(
                                    'النتيجة الحالية: ${attempt.scoreFinal}',
                                    style: GoogleFonts.cairo(color: const Color(0xFF6B7280), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AttemptAnswersDetailsScreen(
                                      exam: widget.exam,
                                      attempt: attempt,
                                      studentName: studentName,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  _load();
                                }
                              },
                              child: Text('عرض', style: GoogleFonts.cairo()),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class AttemptAnswersDetailsScreen extends StatefulWidget {
  final ExamModel exam;
  final ExamAttemptModel attempt;
  final String studentName;

  const AttemptAnswersDetailsScreen({
    super.key,
    required this.exam,
    required this.attempt,
    required this.studentName,
  });

  @override
  State<AttemptAnswersDetailsScreen> createState() => _AttemptAnswersDetailsScreenState();
}

class _AttemptAnswersDetailsScreenState extends State<AttemptAnswersDetailsScreen> {
  final ExamService _examService = ExamService();
  bool _isLoading = true;
  String? _error;
  List<ExamQuestionModel> _questions = [];
  List<ExamAttemptAnswerModel> _answers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final questions = await _examService.getExamQuestions(widget.exam.id);
      final answers = await _examService.getAttemptAnswers(widget.attempt.id);
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _answers = answers;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _gradeEssay(ExamQuestionModel question, ExamAttemptAnswerModel answer) async {
    final maxManual = question.isTrueFalse && question.needsJustificationField
        ? (question.justificationPoints > 0 ? question.justificationPoints : question.maxPoints)
        : question.maxPoints;
    final scoreController = TextEditingController(text: answer.manualScore.toString());
    final feedbackController = TextEditingController(text: answer.teacherFeedback ?? '');
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('تعديل تقييم السؤال', style: GoogleFonts.cairo()),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الحد الأعلى: $maxManual', style: GoogleFonts.cairo()),
              const SizedBox(height: 8),
              TextFormField(
                controller: scoreController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الدرجة'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 0 || n > maxManual) {
                    return 'أدخل درجة بين 0 و $maxManual';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: feedbackController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: Text('حفظ', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _examService.gradeEssayAnswer(
      answerId: answer.id,
      score: int.parse(scoreController.text.trim()),
      feedback: feedbackController.text.trim(),
    );
    if (!mounted) return;
    await _examService.finishAttempt(widget.attempt);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final qMap = {for (final q in _questions) q.id: q};
    final sortedAnswers = [..._answers]..sort((a, b) => a.questionOrder.compareTo(b.questionOrder));

    return Scaffold(
      appBar: AppBar(
        title: Text('إجابات ${widget.studentName}', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('حدث خطأ: $_error', style: GoogleFonts.cairo()),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedAnswers.length,
                  itemBuilder: (_, i) {
                    final answer = sortedAnswers[i];
                    final q = qMap[answer.questionId];
                    if (q == null) return const SizedBox.shrink();
                    final gained = answer.autoScore + answer.manualScore;
                    final String answerText;
                    if (q.isEssay) {
                      answerText = answer.essayText ?? '';
                    } else if (q.isTrueFalse) {
                      final si = answer.selectedOptionIndex;
                      final choice = si == null
                          ? 'لم تتم الإجابة'
                          : (si == 0 ? 'صح' : 'خطأ');
                      final jus = (answer.essayText ?? '').trim();
                      answerText =
                          jus.isEmpty ? choice : '$choice\nالتعليل/التصحيح: $jus';
                    } else if (answer.selectedOptionIndex != null &&
                        answer.selectedOptionIndex! >= 0 &&
                        answer.selectedOptionIndex! < q.options.length) {
                      answerText = q.options[answer.selectedOptionIndex!];
                    } else {
                      answerText = 'لم تتم الإجابة';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'س${answer.questionOrder + 1}: ${q.text}',
                                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Text(
                                  '$gained / ${q.maxPoints}',
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'الإجابة: $answerText',
                              style: GoogleFonts.cairo(color: const Color(0xFF374151)),
                            ),
                            if ((answer.teacherFeedback ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'ملاحظة: ${answer.teacherFeedback}',
                                style: GoogleFonts.cairo(color: const Color(0xFF1E3A8A)),
                              ),
                            ],
                            if (q.isEssay ||
                                (q.isTrueFalse &&
                                    q.needsJustificationField &&
                                    (answer.essayText ?? '').trim().isNotEmpty)) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    q.isEssay ? 'سؤال مقالي' : 'تقييم التعليل',
                                    style: GoogleFonts.cairo(color: const Color(0xFF6B7280), fontSize: 13),
                                  ),
                                  const Spacer(),
                                  ElevatedButton(
                                    onPressed: () => _gradeEssay(q, answer),
                                    child: Text('تعديل التقييم', style: GoogleFonts.cairo()),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
