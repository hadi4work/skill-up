import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/exam_attempt_answer_model.dart';
import '../../models/exam_model.dart';
import '../../models/exam_question_model.dart';

class StudentExamResultScreen extends StatelessWidget {
  final ExamModel exam;
  final int score;
  final int totalPoints;
  final List<ExamQuestionModel> questions;
  final List<ExamAttemptAnswerModel> answers;

  const StudentExamResultScreen({
    super.key,
    required this.exam,
    required this.score,
    required this.totalPoints,
    required this.questions,
    required this.answers,
  });

  String _message(double ratio) {
    if (ratio >= 0.85) return 'رائع جدا! أداؤك ممتاز، استمر هكذا.';
    if (ratio >= 0.6) return 'جيد جدا! تقدّمك واضح، واصل التدريب.';
    return 'ليس سيئا أبدا، كل محاولة تقرّبك من الأفضل.';
  }

  Color _statusColor(double ratio) {
    if (ratio >= 0.85) return const Color(0xFF059669);
    if (ratio >= 0.6) return const Color(0xFF2563EB);
    return const Color(0xFFD97706);
  }

  static String _typeLabelForQuestion(ExamQuestionModel? q) {
    if (q == null) return '';
    if (q.isEssay) return 'مقالي';
    if (q.isSingleChoice) return 'اختياري';
    if (q.isTrueFalse) return 'صح وخطأ';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final ratio = totalPoints == 0 ? 0.0 : score / totalPoints;
    final color = _statusColor(ratio);
    final qMap = {for (final q in questions) q.id: q};
    final sortedAnswers = [...answers]..sort((a, b) => a.questionOrder.compareTo(b.questionOrder));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('نتيجة الاختبار', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exam.title, style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(exam.subject, style: GoogleFonts.cairo(color: const Color(0xFF6B7280))),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'نتيجتك: $score / $totalPoints',
                      style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                    ),
                    const Spacer(),
                    Text(
                      '${(ratio * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w800, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _message(ratio),
                  style: GoogleFonts.cairo(fontSize: 15, color: const Color(0xFF374151)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('تفصيل العلامات لكل سؤال', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...sortedAnswers.map((a) {
            final q = qMap[a.questionId];
            final questionTitle = q?.text ?? 'سؤال';
            final gained = a.autoScore + a.manualScore;
            final max = q?.maxPoints ?? 0;
            final typeLabel = _typeLabelForQuestion(q);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'س${a.questionOrder + 1} - $typeLabel',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '$gained / $max',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: const Color(0xFF111827)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(questionTitle, style: GoogleFonts.cairo(color: const Color(0xFF374151))),
                  if ((a.teacherFeedback ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'ملاحظة المصحح: ${a.teacherFeedback}',
                        style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF1E3A8A)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('العودة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
