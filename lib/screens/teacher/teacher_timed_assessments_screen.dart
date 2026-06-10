import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/exam_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/exam_service.dart';
import 'create_timed_exam_screen.dart';
import 'grade_essay_answers_screen.dart';

String _createTitleForType(String assessmentType) =>
    assessmentType == 'assignment' ? 'إنشاء وظيفة' : 'إنشاء اختبار مؤقت';

class TeacherTimedAssessmentsScreen extends StatefulWidget {
  final String assessmentType; // exam | assignment
  final String titleText;

  const TeacherTimedAssessmentsScreen({
    super.key,
    required this.assessmentType,
    required this.titleText,
  });

  @override
  State<TeacherTimedAssessmentsScreen> createState() => _TeacherTimedAssessmentsScreenState();
}

class _TeacherTimedAssessmentsScreenState extends State<TeacherTimedAssessmentsScreen> {
  final ExamService _examService = ExamService();
  bool _isLoading = true;
  List<ExamModel> _items = [];
  final Map<String, _SubmissionStats> _submissionStatsByExam = {};
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final teacherId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (teacherId == null) return;
    setState(() => _isLoading = true);
    final data = await _examService.getTeacherExams(teacherId, assessmentType: widget.assessmentType);
    final Map<String, _SubmissionStats> statsMap = {};
    for (final exam in data) {
      final studentIds = await _examService.getStudentIdsForExam(exam);
      final attempts = await _examService.getExamAttemptsForTeacher(exam.id);
      final submittedStudentIds = attempts.where((a) => a.isFinished).map((a) => a.studentId).toSet();
      statsMap[exam.id] = _SubmissionStats(
        submittedCount: submittedStudentIds.length,
        totalStudents: studentIds.length,
      );
    }
    if (!mounted) return;
    setState(() {
      _items = data;
      _submissionStatsByExam
        ..clear()
        ..addAll(statsMap);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _selectionMode ? 'تم تحديد ${_selectedIds.length}' : widget.titleText,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: 'إلغاء التحديد',
              icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
              onPressed: () {
                setState(() {
                  _selectionMode = false;
                  _selectedIds.clear();
                });
              },
            ),
            IconButton(
              tooltip: 'حذف المحدد',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _selectedIds.isEmpty ? null : _deleteSelectedItems,
            ),
          ] else ...[
            IconButton(
              tooltip: 'تحديد',
              icon: const Icon(Icons.checklist_rounded, color: Color(0xFF2563EB)),
              onPressed: _items.isEmpty ? null : () => setState(() => _selectionMode = true),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFF2563EB)),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateTimedExamScreen(
                      assessmentType: widget.assessmentType,
                      titleText: _createTitleForType(widget.assessmentType),
                    ),
                  ),
                );
                if (result == true) _load();
              },
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? Center(
                    child: Text('لا توجد عناصر بعد', style: GoogleFonts.cairo(fontSize: 16)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      final stats = _submissionStatsByExam[item.id] ?? const _SubmissionStats();
                      final selected = _selectedIds.contains(item.id);
                      return GestureDetector(
                        onLongPress: () {
                          setState(() {
                            _selectionMode = true;
                            if (selected) {
                              _selectedIds.remove(item.id);
                            } else {
                              _selectedIds.add(item.id);
                            }
                          });
                        },
                        onTap: _selectionMode
                            ? () {
                                setState(() {
                                  if (selected) {
                                    _selectedIds.remove(item.id);
                                  } else {
                                    _selectedIds.add(item.id);
                                  }
                                });
                              }
                            : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFFEFF6FF) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: selected ? Border.all(color: const Color(0xFF2563EB), width: 1.5) : null,
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
                                  if (_selectionMode) ...[
                                    Icon(
                                      selected ? Icons.check_circle : Icons.radio_button_unchecked,
                                      color: selected ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: widget.assessmentType == 'exam'
                                            ? const [Color(0xFF059669), Color(0xFF2563EB)]
                                            : const [Color(0xFF7C3AED), Color(0xFF2563EB)],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      widget.assessmentType == 'exam' ? Icons.quiz : Icons.timer,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: GoogleFonts.cairo(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item.subject,
                                            style: GoogleFonts.cairo(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF2563EB),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'من ${_fmt(item.startAt)} إلى ${_fmt(item.endAt)}',
                                      style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF6B7280)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.how_to_reg_rounded, size: 16, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'التسليم: ${stats.submittedCount} / ${stats.totalStudents}',
                                      style: GoogleFonts.cairo(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1F2937),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (!_selectionMode)
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          final r = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CreateTimedExamScreen(
                                                assessmentType: widget.assessmentType,
                                                titleText: widget.assessmentType == 'assignment'
                                                    ? 'تعديل الوظيفة'
                                                    : 'تعديل الاختبار',
                                                existingExam: item,
                                              ),
                                            ),
                                          );
                                          if (r == true) _load();
                                        },
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: Text(
                                          'تعديل',
                                          style: GoogleFonts.cairo(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF2563EB),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => GradeEssayAnswersScreen(exam: item),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: Text(
                                          'تصحيح الإجابات',
                                          style: GoogleFonts.cairo(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Future<void> _deleteSelectedItems() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف العناصر المحددة', style: GoogleFonts.cairo()),
        content: Text('سيتم حذف ${_selectedIds.length} عناصر. هل تريد المتابعة؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء', style: GoogleFonts.cairo())),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('حذف', style: GoogleFonts.cairo(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    for (final id in _selectedIds) {
      await _examService.deleteExam(id);
    }
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
    _load();
  }

  String _fmt(DateTime d) {
    return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _SubmissionStats {
  final int submittedCount;
  final int totalStudents;

  const _SubmissionStats({
    this.submittedCount = 0,
    this.totalStudents = 0,
  });
}
