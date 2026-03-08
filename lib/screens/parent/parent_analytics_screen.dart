import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/assignment_service.dart';
import '../../services/user_service.dart';
import '../../models/user_model.dart';
import '../../models/assignment_model.dart';
import '../../models/submission_model.dart';

class ParentAnalyticsScreen extends StatefulWidget {
  const ParentAnalyticsScreen({super.key});

  @override
  State<ParentAnalyticsScreen> createState() => _ParentAnalyticsScreenState();
}

class _ParentAnalyticsScreenState extends State<ParentAnalyticsScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final UserService _userService = UserService();
  List<UserModel> _children = [];
  Map<String, List<SubmissionModel>> _submissionsByChild = {};
  Map<String, List<AssignmentModel>> _assignmentsByChild = {};
  bool _loading = true;

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
    final childIds = user.children;
    if (childIds == null || childIds.isEmpty) {
      setState(() {
        _children = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      List<UserModel> children = [];
      final subsMap = <String, List<SubmissionModel>>{};
      final assignMap = <String, List<AssignmentModel>>{};
      for (final id in childIds) {
        final profile = await _userService.getUserProfile(id);
        if (profile != null && profile.accountType == 'student') {
          children.add(profile);
          final subs = await _assignmentService.getSubmissionsByStudentId(id);
          subsMap[id] = subs;
          if (profile.classIds != null && profile.classIds!.isNotEmpty) {
            final assign = await _assignmentService.getStudentAssignments(profile.classIds!);
            assignMap[id] = assign;
          } else {
            assignMap[id] = [];
          }
        }
      }
      if (mounted) {
        setState(() {
          _children = children;
          _submissionsByChild = subsMap;
          _assignmentsByChild = assignMap;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('ParentAnalytics load error: $e');
      if (mounted) setState(() => _loading = false);
    }
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
                        'التقارير والتحليلات',
                        style: GoogleFonts.cairo(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'متابعة تقدّم أبنائك',
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
              else if (_children.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 16),
                      ..._children.map((child) => _buildChildCard(child)),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'لا يوجد أبناء مرتبطين',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'اربط حساب ابنك من إعدادات الملف الشخصي لمتابعة تقاريره وتقدّمه هنا.',
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildCard(UserModel child) {
    final submissions = _submissionsByChild[child.uid] ?? [];
    final assignments = _assignmentsByChild[child.uid] ?? [];
    final graded = submissions.where((s) => s.isGraded && s.grade != null).toList();
    double avgPercent = 0;
    if (graded.isNotEmpty) {
      double sum = 0;
      for (final s in graded) {
        try {
          final a = assignments.firstWhere((x) => x.id == s.assignmentId);
          sum += (s.grade! / a.totalPoints) * 100;
        } catch (_) {}
      }
      avgPercent = sum / graded.length;
    }
    final totalExpected = assignments.length;
    final submittedCount = submissions.length;
    final completionPercent = totalExpected > 0
        ? ((submittedCount / totalExpected) * 100).clamp(0.0, 100.0)
        : 0.0;
    final progress = child.getXPProgressToNextLevel();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with name and level
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: Text(
                    child.name.isNotEmpty ? child.name[0] : '؟',
                    style: GoogleFonts.cairo(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.name,
                        style: GoogleFonts.cairo(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'المستوى ${child.level} • ${child.xp} XP',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Progress to next level
          if (child.level < 10)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'التقدم للمستوى ${child.level + 1}',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ملخص الأداء',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _miniStat(
                        'التسليمات',
                        '$submittedCount / ${assignments.length}',
                        Icons.assignment_turned_in,
                        const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _miniStat(
                        'المقيّمة',
                        '${graded.length}',
                        Icons.grade,
                        const Color(0xFF22C55E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _miniStat(
                        'معدل الإنجاز',
                        '${completionPercent.toStringAsFixed(0)}%',
                        Icons.pie_chart_outline,
                        const Color(0xFF7C3AED),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _miniStat(
                        'متوسط الدرجات',
                        '${avgPercent.toStringAsFixed(0)}%',
                        Icons.trending_up,
                        const Color(0xFF0EA5E9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
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
}
