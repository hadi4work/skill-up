import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/assignment_model.dart';
import '../../models/class_model.dart';
import '../../models/submission_model.dart';
import '../../models/user_model.dart';
import '../../services/assignment_service.dart';
import '../../services/user_service.dart';

class TeacherClassAnalyticsScreen extends StatefulWidget {
  final ClassModel classModel;
  final List<AssignmentModel> assignments;

  const TeacherClassAnalyticsScreen({
    super.key,
    required this.classModel,
    required this.assignments,
  });

  @override
  State<TeacherClassAnalyticsScreen> createState() => _TeacherClassAnalyticsScreenState();
}

class _TeacherClassAnalyticsScreenState extends State<TeacherClassAnalyticsScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final UserService _userService = UserService();
  bool _loading = true;
  double _avgGradePercent = 0;
  double _completionRate = 0;
  List<_StudentRankItem> _studentRankings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final classAssignments = widget.assignments.where((a) => a.classIds.contains(widget.classModel.id)).toList();

      final Map<String, UserModel?> studentByCode = {};
      for (final code in widget.classModel.studentCodes) {
        studentByCode[code] = await _userService.getUserByStudentCode(code);
      }
      final classStudentIds = studentByCode.values.whereType<UserModel>().map((u) => u.uid).toSet();

      int expected = classAssignments.length * widget.classModel.studentCodes.length;
      int actual = 0;
      int gradedCount = 0;
      double gradesSum = 0;
      final Map<String, List<double>> studentPercents = {};

      for (final assignment in classAssignments) {
        final submissions = await _assignmentService.getAssignmentSubmissions(assignment.id);
        final classSubs = submissions.where((s) => classStudentIds.contains(s.studentId)).toList();
        actual += classSubs.length;

        for (final SubmissionModel s in classSubs) {
          if (!s.isGraded || s.grade == null || assignment.totalPoints <= 0) continue;
          final p = (s.grade! / assignment.totalPoints) * 100;
          gradesSum += p;
          gradedCount += 1;
          studentPercents.putIfAbsent(s.studentId, () => []).add(p);
        }
      }

      final rankings = <_StudentRankItem>[];
      for (final code in widget.classModel.studentCodes) {
        final u = studentByCode[code];
        if (u == null) {
          rankings.add(
            _StudentRankItem(studentId: '', name: 'طالب ($code)', avgPercent: null),
          );
          continue;
        }
        final list = studentPercents[u.uid];
        final avg = list == null || list.isEmpty
            ? null
            : list.reduce((a, b) => a + b) / list.length;
        rankings.add(
          _StudentRankItem(studentId: u.uid, name: u.name, avgPercent: avg),
        );
      }
      rankings.sort((a, b) {
        if (a.hasGrade && b.hasGrade) {
          final c = b.avgPercent!.compareTo(a.avgPercent!);
          if (c != 0) return c;
          return a.name.compareTo(b.name);
        }
        if (a.hasGrade && !b.hasGrade) return -1;
        if (!a.hasGrade && b.hasGrade) return 1;
        return a.name.compareTo(b.name);
      });

      if (!mounted) return;
      setState(() {
        _avgGradePercent = gradedCount == 0 ? 0 : gradesSum / gradedCount;
        _completionRate = expected == 0 ? 0 : (actual / expected) * 100;
        _studentRankings = rankings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'تحليلات ${widget.classModel.name}',
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
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'متوسط الصف: ${_avgGradePercent.toStringAsFixed(0)}% • معدل الإنجاز: ${_completionRate.toStringAsFixed(0)}%',
                      style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ترتيب الطلاب',
                    style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (widget.classModel.studentCodes.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('لا يوجد طلاب في هذا الصف', style: GoogleFonts.cairo()),
                    )
                  else
                    ..._studentRankings.asMap().entries.map((e) {
                      final rank = e.key + 1;
                      final s = e.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text(_medal(rank), style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            Text('#$rank', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(s.name, style: GoogleFonts.cairo())),
                            Text(
                              s.hasGrade
                                  ? '${s.avgPercent!.toStringAsFixed(0)}%'
                                  : '—',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                color: s.hasGrade
                                    ? const Color(0xFF111827)
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

class _StudentRankItem {
  final String studentId;
  final String name;
  final double? avgPercent;

  _StudentRankItem({
    required this.studentId,
    required this.name,
    required this.avgPercent,
  });

  bool get hasGrade => avgPercent != null;
}
