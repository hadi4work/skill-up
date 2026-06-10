import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/class_model.dart';
import '../../models/exam_attempt_model.dart';
import '../../models/submission_model.dart';
import '../../models/user_model.dart';
import '../../services/assignment_service.dart';
import '../../services/exam_service.dart';
import '../../services/user_service.dart';

/// ترتيب جميع طلاب صف معيّن بناءً على واجبات واختبارات هذا الصف فقط.
class StudentClassRankingScreen extends StatefulWidget {
  final ClassModel classModel;
  final String currentStudentId;

  const StudentClassRankingScreen({
    super.key,
    required this.classModel,
    required this.currentStudentId,
  });

  @override
  State<StudentClassRankingScreen> createState() => _StudentClassRankingScreenState();
}

class _RankEntry {
  final String studentId;
  final String name;
  final double? avgPercent;

  _RankEntry({
    required this.studentId,
    required this.name,
    required this.avgPercent,
  });

  bool get hasGrade => avgPercent != null;
}

class _StudentClassRankingScreenState extends State<StudentClassRankingScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final ExamService _examService = ExamService();
  final UserService _userService = UserService();
  bool _loading = true;
  List<_RankEntry> _rows = [];

  static const Color _goldBorder = Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final classId = widget.classModel.id;
      final assignments =
          await _assignmentService.getStudentAssignments([classId]);
      final classAssignments =
          assignments.where((a) => a.classIds.contains(classId)).toList();

      final Map<String, UserModel?> studentByCode = {};
      for (final code in widget.classModel.studentCodes) {
        studentByCode[code] = await _userService.getUserByStudentCode(code);
      }
      final classStudentIds =
          studentByCode.values.whereType<UserModel>().map((u) => u.uid).toSet();

      final Map<String, List<double>> studentPercents = {};

      for (final assignment in classAssignments) {
        final subs =
            await _assignmentService.getAssignmentSubmissions(assignment.id);
        final classSubs =
            subs.where((s) => classStudentIds.contains(s.studentId)).toList();
        for (final SubmissionModel s in classSubs) {
          if (!s.isGraded || s.grade == null || assignment.totalPoints <= 0) {
            continue;
          }
          final p = (s.grade! / assignment.totalPoints) * 100;
          studentPercents.putIfAbsent(s.studentId, () => []).add(p);
        }
      }

      final exams =
          await _examService.getPublishedExamsForStudentClasses([classId]);
      for (final exam in exams) {
        if (!exam.classIds.contains(classId)) continue;
        final total = await _examService.getExamTotalPoints(exam.id);
        if (total <= 0) continue;
        final attempts = await _examService.getExamAttemptsForTeacher(exam.id);
        for (final ExamAttemptModel a in attempts) {
          if (!a.isFinished || !classStudentIds.contains(a.studentId)) {
            continue;
          }
          final p = (a.scoreFinal / total) * 100;
          studentPercents.putIfAbsent(a.studentId, () => []).add(p);
        }
      }

      final entries = <_RankEntry>[];
      for (final code in widget.classModel.studentCodes) {
        final u = studentByCode[code];
        if (u == null) {
          entries.add(
            _RankEntry(
              studentId: '',
              name: 'طالب ($code)',
              avgPercent: null,
            ),
          );
          continue;
        }
        final list = studentPercents[u.uid];
        final avg = list == null || list.isEmpty
            ? null
            : list.reduce((a, b) => a + b) / list.length;
        entries.add(
          _RankEntry(studentId: u.uid, name: u.name, avgPercent: avg),
        );
      }

      entries.sort((a, b) {
        if (a.hasGrade && b.hasGrade) {
          final c = b.avgPercent!.compareTo(a.avgPercent!);
          if (c != 0) return c;
          return a.name.compareTo(b.name);
        }
        if (a.hasGrade && !b.hasGrade) return -1;
        if (!a.hasGrade && b.hasGrade) return 1;
        return a.name.compareTo(b.name);
      });

      if (mounted) {
        setState(() {
          _rows = entries;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('StudentClassRanking load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle =
        widget.classModel.section.isNotEmpty
            ? '${widget.classModel.name} — ${widget.classModel.section}'
            : widget.classModel.name;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'ترتيب الصف',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الترتيب حسب متوسط أدائك في واجبات واختبارات هذا الصف فقط',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_rows.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'لا يوجد طلاب مسجّلون في هذا الصف',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    )
                  else
                    ..._rows.asMap().entries.map((e) {
                      final rank = e.key + 1;
                      final row = e.value;
                      final isMe =
                          row.studentId.isNotEmpty &&
                          row.studentId == widget.currentStudentId;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isMe ? _goldBorder : const Color(0xFFE5E7EB),
                            width: isMe ? 2.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text(
                              _medal(rank),
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '#$rank',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                row.name + (isMe ? ' (أنت)' : ''),
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w600,
                                  color: isMe
                                      ? const Color(0xFF92400E)
                                      : const Color(0xFF111827),
                                ),
                              ),
                            ),
                            Text(
                              row.hasGrade
                                  ? '${row.avgPercent!.toStringAsFixed(0)}%'
                                  : '—',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                color: row.hasGrade
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  String _medal(int rank) {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '🏅';
  }
}
