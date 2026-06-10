import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/assignment_service.dart';
import '../../services/class_service.dart';
import '../../services/user_service.dart';
import '../../models/assignment_model.dart';
import '../../models/class_model.dart';
import '../../models/submission_model.dart';
import '../../models/user_model.dart';
import 'teacher_class_analytics_screen.dart';

class TeacherAnalyticsScreen extends StatefulWidget {
  const TeacherAnalyticsScreen({super.key});

  @override
  State<TeacherAnalyticsScreen> createState() => _TeacherAnalyticsScreenState();
}

class _TeacherAnalyticsScreenState extends State<TeacherAnalyticsScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final ClassService _classService = ClassService();
  final UserService _userService = UserService();
  List<AssignmentModel> _assignments = [];
  List<ClassModel> _classes = [];
  bool _loading = true;
  int _totalStudents = 0;
  int _totalSubmissions = 0;
  double _avgGradePercent = 0;
  List<_ClassRankItem> _classRankings = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final teacherId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (teacherId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final assignments = await _assignmentService.getTeacherAssignments(teacherId);
      final classes = await _classService.getTeacherClasses(teacherId);
      int totalStudents = 0;
      int totalSubmissions = 0;
      int gradedCount = 0;
      double sumGradePercent = 0;
      final classRankings = <_ClassRankItem>[];

      for (final c in classes) {
        totalStudents += c.studentCodes.length;
      }

      // Build per-class ranking
      for (final c in classes) {
        final details = await _buildClassDetails(c, assignments);
        classRankings.add(
          _ClassRankItem(
            classModel: c,
            avgPercent: details.avgGradePercent,
            completionRate: details.completionRate,
            studentsCount: c.studentCodes.length,
          ),
        );
      }
      classRankings.sort((a, b) => b.avgPercent.compareTo(a.avgPercent));

      for (final a in assignments) {
        final subs = await _assignmentService.getAssignmentSubmissions(a.id);
        totalSubmissions += subs.length;
        final graded = subs.where((s) => s.isGraded && s.grade != null).toList();
        gradedCount += graded.length;
        for (final s in graded) {
          sumGradePercent += (s.grade! / a.totalPoints) * 100;
        }
      }
      if (mounted) {
        setState(() {
          _assignments = assignments;
          _classes = classes;
          _totalStudents = totalStudents;
          _totalSubmissions = totalSubmissions;
          _avgGradePercent = gradedCount > 0 ? sumGradePercent / gradedCount : 0;
          _classRankings = classRankings;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('TeacherAnalytics load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<_ClassDetails> _buildClassDetails(ClassModel c, List<AssignmentModel> assignments) async {
    final classAssignments = assignments.where((a) => a.classIds.contains(c.id)).toList();
    if (classAssignments.isEmpty) {
      return _ClassDetails(
        classId: c.id,
        avgGradePercent: 0,
        completionRate: 0,
        studentRankings: [],
      );
    }

    int expectedSubmissions = classAssignments.length * c.studentCodes.length;
    int actualSubmissions = 0;
    int gradedCount = 0;
    double gradesSum = 0;
    final Map<String, List<double>> studentPercents = {};
    final Map<String, UserModel?> studentByCode = {};

    for (final code in c.studentCodes) {
      studentByCode[code] = await _userService.getUserByStudentCode(code);
    }
    final Set<String> classStudentIds = studentByCode.values.whereType<UserModel>().map((u) => u.uid).toSet();

    for (final a in classAssignments) {
      final subs = await _assignmentService.getAssignmentSubmissions(a.id);
      final classSubs = subs.where((s) => classStudentIds.contains(s.studentId)).toList();
      actualSubmissions += classSubs.length;
      for (final SubmissionModel s in classSubs) {
        if (!s.isGraded || s.grade == null || a.totalPoints <= 0) continue;
        final p = (s.grade! / a.totalPoints) * 100;
        gradedCount += 1;
        gradesSum += p;
        studentPercents.putIfAbsent(s.studentId, () => []).add(p);
      }
    }

    final studentRankings = studentPercents.entries.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      final user = studentByCode.values.whereType<UserModel>().firstWhere(
            (u) => u.uid == e.key,
            orElse: () => UserModel(
              uid: e.key,
              name: 'طالب',
              email: '',
              accountType: 'student',
              createdAt: DateTime.now(),
            ),
          );
      return _StudentRankItem(studentId: e.key, name: user.name, avgPercent: avg);
    }).toList()
      ..sort((a, b) => b.avgPercent.compareTo(a.avgPercent));

    return _ClassDetails(
      classId: c.id,
      avgGradePercent: gradedCount == 0 ? 0 : gradesSum / gradedCount,
      completionRate: expectedSubmissions == 0 ? 0 : (actualSubmissions / expectedSubmissions) * 100,
      studentRankings: studentRankings,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        'التحليلات',
                        style: GoogleFonts.cairo(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'نظرة شاملة على أداء الصفوف والواجبات',
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
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('ملخص الواجبات'),
                      const SizedBox(height: 12),
                      _buildAssignmentsList(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('أداء الصفوف'),
                      const SizedBox(height: 12),
                      _buildClassesList(),
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

  Widget _buildSummaryCards() {
    final completionRate = _totalStudents > 0
        ? ((_totalSubmissions / (_assignments.length * _totalStudents).clamp(1, double.infinity)) * 100).clamp(0.0, 100.0)
        : 0.0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                'إجمالي الواجبات',
                '${_assignments.length}',
                Icons.assignment_outlined,
                const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'الصفوف',
                '${_classes.length}',
                Icons.groups_outlined,
                const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                'معدل التسليم',
                '${completionRate.toStringAsFixed(0)}%',
                Icons.check_circle_outline,
                const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'متوسط الدرجات',
                '${_avgGradePercent.toStringAsFixed(0)}%',
                Icons.trending_up,
                const Color(0xFF0EA5E9),
              ),
            ),
          ],
        ),
      ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: const Color(0xFF6B7280),
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

  Widget _buildAssignmentsList() {
    if (_assignments.isEmpty) {
      return _emptyCard('لا توجد واجبات بعد');
    }
    return Column(
      children: _assignments.take(10).map((a) => _assignmentTile(a)).toList(),
    );
  }

  Widget _assignmentTile(AssignmentModel a) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _assignmentStats(a),
      builder: (context, snapshot) {
        final subs = snapshot.data?['submissions'] ?? 0;
        final total = snapshot.data?['totalStudents'] ?? 0;
        final rate = total > 0 ? (subs / total).clamp(0.0, 1.0) : 0.0;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      a.title,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      a.subject,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'التسليمات: $subs / $total',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(rate * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: rate,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _assignmentStats(AssignmentModel a) async {
    int total = 0;
    for (final id in a.classIds) {
      final c = await _classService.getClassById(id);
      if (c != null) total += c.studentCodes.length;
    }
    final subs = await _assignmentService.getAssignmentSubmissions(a.id);
    return {'submissions': subs.length, 'totalStudents': total};
  }

  Widget _buildClassesList() {
    if (_classes.isEmpty) {
      return _emptyCard('لا توجد صفوف بعد');
    }
    return Column(
      children: _classRankings.asMap().entries.map((entry) {
        final rankIndex = entry.key + 1;
        final item = entry.value;
        final c = item.classModel;
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
          child: InkWell(
            onTap: () async {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeacherClassAnalyticsScreen(
                    classModel: c,
                    assignments: _assignments,
                  ),
                ),
              );
            },
            child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.class_, color: Color(0xFF7C3AED), size: 24),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$rankIndex',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.studentsCount} طالب • ${item.avgPercent.toStringAsFixed(0)}%',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                c.section,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _emptyCard(String text) {
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
          text,
          style: GoogleFonts.cairo(
            fontSize: 14,
            color: const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _ClassRankItem {
  final ClassModel classModel;
  final double avgPercent;
  final double completionRate;
  final int studentsCount;

  _ClassRankItem({
    required this.classModel,
    required this.avgPercent,
    required this.completionRate,
    required this.studentsCount,
  });
}

class _StudentRankItem {
  final String studentId;
  final String name;
  final double avgPercent;

  _StudentRankItem({
    required this.studentId,
    required this.name,
    required this.avgPercent,
  });
}

class _ClassDetails {
  final String classId;
  final double avgGradePercent;
  final double completionRate;
  final List<_StudentRankItem> studentRankings;

  _ClassDetails({
    required this.classId,
    required this.avgGradePercent,
    required this.completionRate,
    required this.studentRankings,
  });
}
