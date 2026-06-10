// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/exam_attempt_model.dart';
import '../../models/exam_model.dart';
import '../../models/exam_question_model.dart';
import '../../services/exam_service.dart';
import 'student_exam_result_screen.dart';

class StudentTakeExamScreen extends StatefulWidget {
  final ExamModel exam;
  final String studentId;
  const StudentTakeExamScreen({
    super.key,
    required this.exam,
    required this.studentId,
  });

  @override
  State<StudentTakeExamScreen> createState() => _StudentTakeExamScreenState();
}

class _StudentTakeExamScreenState extends State<StudentTakeExamScreen> {
  final ExamService _examService = ExamService();
  bool _isLoading = true;
  List<ExamQuestionModel> _questions = [];
  ExamAttemptModel? _attempt;
  int _currentOrder = 0;
  Timer? _timer;
  int _remainingSeconds = 0;
  int? _selectedOption;
  final TextEditingController _essayController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _essayController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final questions = await _examService.getExamQuestions(widget.exam.id);
    ExamAttemptModel attempt =
        await _examService.startAttempt(examId: widget.exam.id, studentId: widget.studentId);
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _attempt = attempt;
      _currentOrder = attempt.currentQuestionOrder;
      _isLoading = false;
    });
    _startQuestionTimer();
  }

  void _startQuestionTimer() {
    _timer?.cancel();
    if (_currentOrder >= _questions.length) return;
    _selectedOption = null;
    _essayController.clear();
    _remainingSeconds = _questions[_currentOrder].timeLimitSec;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _goNext(timeExpired: true);
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
    setState(() {});
  }

  Future<void> _goNext({required bool timeExpired}) async {
    if (_attempt == null || _currentOrder >= _questions.length) return;
    final q = _questions[_currentOrder];

    if (!timeExpired) {
      if (q.isSingleChoice && _selectedOption == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('اختر إجابة', style: GoogleFonts.cairo())),
        );
        return;
      }
      if (q.isTrueFalse && _selectedOption == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدد صح أو خطأ', style: GoogleFonts.cairo())),
        );
        return;
      }
      if (q.needsJustificationField &&
          _selectedOption == 1 &&
          _essayController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('اكتب تعليلاً أو تصحيحاً للعبارة', style: GoogleFonts.cairo()),
          ),
        );
        return;
      }
    }

    String? essayOut;
    if (q.isEssay) {
      essayOut = _essayController.text.trim();
    } else if (q.needsJustificationField && _selectedOption == 1) {
      essayOut = _essayController.text.trim();
    }

    await _examService.submitAnswer(
      attempt: _attempt!,
      question: q,
      selectedOptionIndex: (q.isSingleChoice || q.isTrueFalse) ? _selectedOption : null,
      essayText: essayOut,
      timeExpired: timeExpired,
    );

    if (!mounted) return;
    final nextOrder = _currentOrder + 1;
    if (nextOrder >= _questions.length) {
      await _examService.finishAttempt(_attempt!);
      final updatedAttempt = await _examService.getAttempt(widget.exam.id, widget.studentId);
      final totalPoints = await _examService.getExamTotalPoints(widget.exam.id);
      final answers = await _examService.getAttemptAnswers(_attempt!.id);
      if (!mounted) return;
      final score = updatedAttempt?.scoreFinal ?? 0;
      final result = await Navigator.pushReplacement<bool, bool>(
        context,
        MaterialPageRoute(
          builder: (_) => StudentExamResultScreen(
            exam: widget.exam,
            score: score,
            totalPoints: totalPoints,
            questions: _questions,
            answers: answers,
          ),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, result == true);
      return;
    }
    setState(() => _currentOrder = nextOrder);
    _startQuestionTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_currentOrder >= _questions.length) {
      return Scaffold(body: Center(child: Text('تم إنهاء الاختبار', style: GoogleFonts.cairo())));
    }
    final q = _questions[_currentOrder];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.exam.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF111827)),
              ),
              Text(
                'السؤال ${_currentOrder + 1} من ${_questions.length}',
                style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Padding(
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _questionTypeLabel(q),
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _remainingSeconds <= 15
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                                  : const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _formatTime(_remainingSeconds),
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _remainingSeconds <= 15 ? const Color(0xFFB91C1C) : const Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(99),
                        value: _remainingSeconds / (q.timeLimitSec == 0 ? 1 : q.timeLimitSec),
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _remainingSeconds <= 15 ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'الوقت المتبقي للإجابة على هذا السؤال',
                        style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF6B7280)),
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
                            q.text,
                            style: GoogleFonts.cairo(
                              fontSize: 20,
                              height: 1.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (q.isSingleChoice)
                            ...List.generate(q.options.length, (i) {
                              return _buildOptionCard(
                                optionText: q.options[i],
                                isSelected: _selectedOption == i,
                                onTap: () => setState(() => _selectedOption = i),
                              );
                            })
                          else if (q.isTrueFalse) ...[
                            _buildOptionCard(
                              optionText: 'صح',
                              isSelected: _selectedOption == 0,
                              onTap: () => setState(() {
                                _selectedOption = 0;
                                if (q.needsJustificationField) {
                                  _essayController.clear();
                                }
                              }),
                            ),
                            _buildOptionCard(
                              optionText: 'خطأ',
                              isSelected: _selectedOption == 1,
                              onTap: () => setState(() => _selectedOption = 1),
                            ),
                            if (q.needsJustificationField && _selectedOption == 1) ...[
                              const SizedBox(height: 14),
                              Text(
                                'علّل أو صحّح العبارة خطأ:',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _essayController,
                                maxLines: 6,
                                style: GoogleFonts.cairo(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'اكتب التعليل أو التصحيح...',
                                  hintStyle: GoogleFonts.cairo(color: const Color(0xFF9CA3AF)),
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ] else
                            TextField(
                              controller: _essayController,
                              maxLines: 9,
                              style: GoogleFonts.cairo(fontSize: 16),
                              decoration: InputDecoration(
                                hintText: 'اكتب إجابتك هنا بشكل واضح...',
                                hintStyle: GoogleFonts.cairo(color: const Color(0xFF9CA3AF)),
                                filled: true,
                                fillColor: const Color(0xFFF9FAFB),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _goNext(timeExpired: false),
                    icon: Icon(
                      _currentOrder == _questions.length - 1 ? Icons.check_circle_outline : Icons.arrow_forward_rounded,
                    ),
                    label: Text(
                      _currentOrder == _questions.length - 1 ? 'إنهاء وإرسال' : 'السؤال التالي',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String optionText,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.08) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                optionText,
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  color: const Color(0xFF111827),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _questionTypeLabel(ExamQuestionModel q) {
    if (q.isEssay) return 'مقالي';
    if (q.isSingleChoice) return 'اختياري';
    if (q.isTrueFalse) return 'صح وخطأ';
    return '';
  }
}
