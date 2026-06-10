import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/assignment_service.dart';
import '../../services/class_service.dart';
import '../../services/exam_service.dart';
import '../../models/assignment_model.dart';
import '../../models/class_model.dart';
import '../../models/exam_attempt_model.dart';
import '../../models/exam_model.dart';
import '../../models/submission_model.dart';
import 'student_class_ranking_screen.dart';

class StudentAnalyticsScreen extends StatefulWidget {
  const StudentAnalyticsScreen({super.key});

  @override
  State<StudentAnalyticsScreen> createState() => _StudentAnalyticsScreenState();
}

class _TimedGradeRow {
  final ExamModel exam;
  final ExamAttemptModel attempt;
  final int totalPoints;
  _TimedGradeRow({required this.exam, required this.attempt, required this.totalPoints});
}

class _StudentAnalyticsScreenState extends State<StudentAnalyticsScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final ExamService _examService = ExamService();
  final ClassService _classService = ClassService();
  List<SubmissionModel> _submissions = [];
  List<AssignmentModel> _assignments = [];
  List<_TimedGradeRow> _timedGrades = [];
  bool _loading = true;
  List<ClassModel> _myClasses = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      List<AssignmentModel> assignments = [];
      if (user.classIds != null && user.classIds!.isNotEmpty) {
        assignments = await _assignmentService.getStudentAssignments(user.classIds!);
      }
      final submissions = await _assignmentService.getSubmissionsByStudentId(user.uid);
      final timed = <_TimedGradeRow>[];
      final attempts = await _examService.getStudentFinishedAttempts(user.uid);
      for (final a in attempts) {
        final ex = await _examService.getExamById(a.examId);
        if (ex == null) continue;
        final tp = await _examService.getExamTotalPoints(ex.id);
        timed.add(_TimedGradeRow(exam: ex, attempt: a, totalPoints: tp));
      }

      final classes = <ClassModel>[];
      for (final classId in user.classIds ?? const <String>[]) {
        final c = await _classService.getClassById(classId);
        if (c != null) classes.add(c);
      }
      classes.sort((a, b) => a.name.compareTo(b.name));

      if (mounted) {
        setState(() {
          _assignments = assignments;
          _submissions = submissions;
          _timedGrades = timed;
          _myClasses = classes;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('StudentAnalytics load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('يجب تسجيل الدخول')),
      );
    }

    final graded = _submissions.where((s) => s.isGraded && s.grade != null).toList();
    AssignmentModel? getAssignment(String id) {
      try {
        return _assignments.firstWhere((a) => a.id == id);
      } catch (_) {
        return null;
      }
    }
    final percents = <double>[];
    for (final s in graded) {
      final a = getAssignment(s.assignmentId);
      if (a != null && a.totalPoints > 0) percents.add((s.grade! / a.totalPoints) * 100);
    }
    for (final t in _timedGrades) {
      if (t.totalPoints > 0) percents.add((t.attempt.scoreFinal / t.totalPoints) * 100);
    }
    final avgPercent =
        percents.isEmpty ? 0.0 : percents.reduce((a, b) => a + b) / percents.length;
    final evaluatedCount = graded.length + _timedGrades.length;
    final submittedTotal = _submissions.length + _timedGrades.length;
    final progress = user.getXPProgressToNextLevel();
    final xpNeeded = user.getXPNeededForNextLevel();
    final xpInLevel = user.level >= 10
        ? 0
        : user.xp - user.getXPRequiredForLevel(user.level);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تحليلاتي',
                        style: GoogleFonts.cairo(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تقدمك ونقاط قوتك',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 16),
                      _buildLevelCard(user.level, user.xp, progress, xpInLevel, xpNeeded),
                      const SizedBox(height: 20),
                      _buildSectionTitle('ملخص الأداء'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              'واجبات مُسلّمة',
                              '$submittedTotal',
                              Icons.upload_file,
                              const Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statCard(
                              'تم تقييمها',
                              '$evaluatedCount',
                              Icons.grade,
                              const Color(0xFF22C55E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _statCard(
                        'متوسط الدرجات',
                        '${avgPercent.toStringAsFixed(0)}%',
                        Icons.trending_up,
                        const Color(0xFF7C3AED),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('صفوفي'),
                      const SizedBox(height: 8),
                      Text(
                        'اضغط على صف لعرض ترتيب الطلاب ضمنه',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMyClassesList(context, user.uid),
                      const SizedBox(height: 24),
                      _buildSectionTitle('آخر الدرجات'),
                      const SizedBox(height: 12),
                      _buildMergedRecentGrades(getAssignment),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyClassesList(BuildContext context, String studentId) {
    if (_myClasses.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
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
        child: Center(
          child: Text(
            'لم تُضف إلى أي صف بعد',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: const Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    return Column(
      children: _myClasses.map((c) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            shadowColor: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => StudentClassRankingScreen(
                      classModel: c,
                      currentStudentId: studentId,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.groups_outlined,
                        color: Color(0xFF2563EB),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          if (c.section.isNotEmpty)
                            Text(
                              'الشعبة: ${c.section}',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          Text(
                            '${c.studentCodes.length} طالب',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_left,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLevelCard(int level, int xp, double progress, int xpInLevel, int xpNeeded) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.emoji_events, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المستوى $level',
                    style: GoogleFonts.cairo(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$xp نقطة خبرة',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (level < 10) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'التقدم للمستوى ${level + 1}',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                Text(
                  '$xpInLevel / $xpNeeded XP',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'وصلت للمستوى الأعلى! 🎉',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF111827),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentGradeTile({
    required String title,
    required String subtitle,
    required double percent,
    IconData leadingIcon = Icons.assignment,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: percent >= 60
                  ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                  : const Color(0xFFFB923C).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              leadingIcon,
              color: percent >= 60 ? const Color(0xFF22C55E) : const Color(0xFFFB923C),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: percent >= 60 ? const Color(0xFF22C55E) : const Color(0xFFFB923C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMergedRecentGrades(AssignmentModel? Function(String) getAssignment) {
    final graded = _submissions.where((s) => s.isGraded && s.grade != null).toList();
    final entries = <({DateTime at, Widget tile})>[];

    for (final s in graded) {
      final a = getAssignment(s.assignmentId);
      final percent = a != null && a.totalPoints > 0 ? (s.grade! / a.totalPoints * 100) : 0.0;
      final at = s.gradedAt ?? s.submittedAt;
      entries.add((
        at: at,
        tile: _recentGradeTile(
          title: a?.title ?? 'واجب',
          subtitle: a?.subject ?? '',
          percent: percent,
          leadingIcon: Icons.assignment_turned_in,
        ),
      ));
    }

    for (final t in _timedGrades) {
      final percent = t.totalPoints > 0 ? (t.attempt.scoreFinal / t.totalPoints * 100) : 0.0;
      final at = t.attempt.finishedAt ?? t.attempt.startedAt;
      entries.add((
        at: at,
        tile: _recentGradeTile(
          title: t.exam.title,
          subtitle: t.exam.subject,
          percent: percent,
          leadingIcon: Icons.assignment_turned_in,
        ),
      ));
    }

    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
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
        child: Center(
          child: Text(
            'لا توجد درجات مسجّلة بعد',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: const Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    entries.sort((a, b) => b.at.compareTo(a.at));
    return Column(
      children: entries.take(10).map((e) => e.tile).toList(),
    );
  }
}
