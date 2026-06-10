import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../services/assignment_service.dart';
import '../../services/exam_service.dart';
import '../../models/assignment_model.dart';
import '../../models/exam_model.dart';
import '../../models/exam_attempt_model.dart';
import '../../services/student_content_seen_service.dart';
import 'submit_assignment_screen.dart';
import 'student_timed_assessments_screen.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  final VoidCallback? onAssignmentsTabBadgeShouldRefresh;

  const StudentAssignmentsScreen({super.key, this.onAssignmentsTabBadgeShouldRefresh});

  @override
  State<StudentAssignmentsScreen> createState() => _StudentAssignmentsScreenState();
}

class _StudentTimedCompleteRow {
  final ExamModel exam;
  final ExamAttemptModel attempt;
  final int totalPoints;
  _StudentTimedCompleteRow({
    required this.exam,
    required this.attempt,
    required this.totalPoints,
  });
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final ExamService _examService = ExamService();
  List<AssignmentModel> _assignments = [];
  List<_StudentTimedCompleteRow> _completedTimed = [];
  bool _isLoading = true;
  bool _dotTimedExam = false;
  bool _dotTimedWork = false;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  String _hiddenOverduePrefsKey(String studentId) =>
      'student_hidden_overdue_assignments_$studentId';

  Future<void> _persistHiddenOverdue(String studentId, String assignmentId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _hiddenOverduePrefsKey(studentId);
    final list = List<String>.from(prefs.getStringList(key) ?? []);
    if (!list.contains(assignmentId)) {
      list.add(assignmentId);
      await prefs.setStringList(key, list);
    }
  }

  Future<void> _loadAssignments() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    debugPrint('👤 Student user: ${user?.name}');
    debugPrint('📚 Student classIds: ${user?.classIds}');

    if (user == null || user.classIds == null || user.classIds!.isEmpty) {
      debugPrint('⚠️ Student has no classIds');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      debugPrint('🔍 Loading assignments for classes: ${user.classIds}');
      final prefs = await SharedPreferences.getInstance();
      final hiddenOverdue =
          (prefs.getStringList(_hiddenOverduePrefsKey(user.uid)) ?? []).toSet();
      var assignments = await _assignmentService.getStudentAssignments(user.classIds!);
      final now = DateTime.now();
      assignments = assignments.where((a) {
        final overdue = a.deadline.isBefore(now);
        if (!overdue) return true;
        return !hiddenOverdue.contains(a.id);
      }).toList();
      final timedRows = <_StudentTimedCompleteRow>[];
      final attempts = await _examService.getStudentFinishedAttempts(user.uid);
      for (final a in attempts) {
        final ex = await _examService.getExamById(a.examId);
        if (ex == null) continue;
        final tp = await _examService.getExamTotalPoints(ex.id);
        timedRows.add(_StudentTimedCompleteRow(exam: ex, attempt: a, totalPoints: tp));
      }
      timedRows.sort((x, y) {
        final dx = x.attempt.finishedAt ?? x.attempt.startedAt;
        final dy = y.attempt.finishedAt ?? y.attempt.startedAt;
        return dy.compareTo(dx);
      });
      debugPrint('✅ Loaded ${assignments.length} assignments');
      if (mounted) {
        setState(() {
          _assignments = assignments;
          _completedTimed = timedRows;
          _isLoading = false;
        });
        await _refreshAppBarDots();
      }
    } catch (e) {
      debugPrint('❌ Error loading assignments: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshAppBarDots() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?.classIds == null || user!.classIds!.isEmpty) {
      if (mounted) {
        setState(() {
          _dotTimedExam = false;
          _dotTimedWork = false;
        });
      }
      return;
    }
    try {
      final exams = await _examService.getStudentAvailableExams(
        user.classIds!,
        assessmentType: 'exam',
      );
      final works = await _examService.getStudentAvailableExams(
        user.classIds!,
        assessmentType: 'assignment',
      );
      final unseenExam = await StudentContentSeenService.hasUnseenTimedExams(
        user.uid,
        exams.map((e) => e.id),
      );
      final unseenWork = await StudentContentSeenService.hasUnseenTimedAssignments(
        user.uid,
        works.map((e) => e.id),
      );
      if (mounted) {
        setState(() {
          _dotTimedExam = unseenExam;
          _dotTimedWork = unseenWork;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _dotTimedExam = false;
          _dotTimedWork = false;
        });
      }
    }
  }

  Widget _appBarIconWithDot({
    required IconData icon,
    required Color color,
    required String tooltip,
    required bool showDot,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: color),
          if (showDot)
            PositionedDirectional(
              top: 0,
              end: 0,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final studentId = auth.user?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'الواجبات',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
        actions: [
          _appBarIconWithDot(
            tooltip: 'الاختبارات',
            icon: Icons.quiz,
            color: const Color(0xFF059669),
            showDot: _dotTimedExam,
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const StudentTimedAssessmentsScreen(
                    assessmentType: 'exam',
                    titleText: 'الاختبارات المتاحة',
                  ),
                ),
              ).whenComplete(() {
                widget.onAssignmentsTabBadgeShouldRefresh?.call();
                _refreshAppBarDots();
              });
            },
          ),
          _appBarIconWithDot(
            tooltip: 'الوظائف المؤقتة',
            icon: Icons.timer,
            color: const Color(0xFF7C3AED),
            showDot: _dotTimedWork,
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const StudentTimedAssessmentsScreen(
                    assessmentType: 'assignment',
                    titleText: 'وظائف مؤقتة متاحة',
                  ),
                ),
              ).whenComplete(() {
                widget.onAssignmentsTabBadgeShouldRefresh?.call();
                _refreshAppBarDots();
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAssignments,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_completedTimed.isNotEmpty) ...[
                    Text(
                      'مكتمل: وظائف واختبارات مؤقتة',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._completedTimed.map(_buildTimedCompletedCard),
                    const SizedBox(height: 20),
                  ],
                  if (_assignments.isEmpty && _completedTimed.isEmpty)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.45,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد واجبات',
                              style: GoogleFonts.cairo(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    if (_assignments.isNotEmpty) ...[
                      Text(
                        'الواجبات',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'لا توجد واجبات عادية حالياً',
                          style: GoogleFonts.cairo(fontSize: 14, color: const Color(0xFF6B7280)),
                        ),
                      ),
                    ..._assignments.map(
                      (a) => _buildAssignmentCard(a, studentId),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildTimedCompletedCard(_StudentTimedCompleteRow row) {
    final ex = row.exam;
    final a = row.attempt;
    final total = row.totalPoints;
    final pct = total > 0 ? (a.scoreFinal / total * 100).clamp(0.0, 100.0) : 0.0;
    final isAssignment = ex.assessmentType == 'assignment';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isAssignment ? const Color(0xFF7C3AED) : const Color(0xFF059669))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isAssignment ? Icons.timer : Icons.quiz,
              color: isAssignment ? const Color(0xFF7C3AED) : const Color(0xFF059669),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ex.title,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Text(
                  '${ex.subject} • ${isAssignment ? 'وظيفة مؤقتة' : 'اختبار مؤقت'}',
                  style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${a.scoreFinal} / $total',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
              ),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(AssignmentModel assignment, String studentId) {
    final bool isOverdue = assignment.deadline.isBefore(DateTime.now());

    final card = Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.book, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.title,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            assignment.subject,
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isOverdue)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'منتهي',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (assignment.notes != null && assignment.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                assignment.notes!,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'الموعد النهائي: ${_formatDate(assignment.deadline)}',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (context) => SubmitAssignmentScreen(
                      assignment: assignment,
                    ),
                  ),
                );
                widget.onAssignmentsTabBadgeShouldRefresh?.call();
                await _refreshAppBarDots();
                if (result == true && mounted) {
                  _loadAssignments();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isOverdue ? 'عرض الواجب' : 'حل الواجب',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!isOverdue || studentId.isEmpty) {
      return card;
    }

    return Dismissible(
      key: ValueKey<String>('assignment_dismiss_${assignment.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'إخفاء',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
          ],
        ),
      ),
      onDismissed: (_) async {
        await _persistHiddenOverdue(studentId, assignment.id);
        if (mounted) {
          setState(() {
            _assignments = _assignments.where((e) => e.id != assignment.id).toList();
          });
        }
      },
      child: card,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
