import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/assignment_service.dart';
import '../../services/exam_service.dart';
import '../../services/ai_service.dart';
import '../../models/assignment_model.dart';

import '../login_screen.dart';

import 'edit_profile_screen.dart';
import 'personal_info_screen.dart';
import 'privacy_security_screen.dart';
import 'notification_settings_screen.dart';
import 'student_qr_code_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final ExamService _examService = ExamService();
  final AIService _aiService = AIService();

  bool _loadingData = true;
  int _trainingStreakDays = 0;
  int _submittedAssignments = 0;
  int _gradedAssignments = 0;
  int _improvedMistakes = 0;
  int _finishedAttempts = 0;
  double _avgPercent = 0;
  double _correctRatePercent = 0;
  List<String> _strongSubjects = [];
  List<String> _weakSubjects = [];
  String _aiInsight = 'يتم تجهيز تحليل الذكاء الاصطناعي...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileAnalytics();
    });
  }

  Future<void> _loadProfileAnalytics() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) {
      setState(() => _loadingData = false);
      return;
    }

    setState(() => _loadingData = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final streak =
          (userDoc.data()?['mistakeTrainingStreakDays'] as num?)?.toInt() ?? 0;

      List<AssignmentModel> assignments = [];
      if (user.classIds != null && user.classIds!.isNotEmpty) {
        assignments = await _assignmentService.getStudentAssignments(
          user.classIds!,
        );
      }
      final submissions = await _assignmentService.getSubmissionsByStudentId(
        user.uid,
      );
      final graded = submissions
          .where((s) => s.isGraded && s.grade != null)
          .toList();

      final assignmentById = {for (final a in assignments) a.id: a};
      final Map<String, List<double>> percentBySubject = {};
      double sumPercent = 0;
      for (final s in graded) {
        final a = assignmentById[s.assignmentId];
        if (a == null || a.totalPoints <= 0) continue;
        final percent = (s.grade! / a.totalPoints) * 100;
        sumPercent += percent;
        percentBySubject.putIfAbsent(a.subject, () => []).add(percent);
      }
      final avgPercent = graded.isEmpty
          ? 0.0
          : (sumPercent / graded.length).toDouble();

      final subjectAverages = percentBySubject.entries.map((e) {
        final avg = (e.value.reduce((a, b) => a + b) / e.value.length)
            .toDouble();
        return MapEntry<String, double>(e.key, avg);
      }).toList();
      subjectAverages.sort((a, b) => b.value.compareTo(a.value));
      final strong = subjectAverages.take(3).map((e) => e.key).toList();
      final weak = subjectAverages.reversed.take(3).map((e) => e.key).toList();

      final attempts = await _examService.getStudentFinishedAttempts(user.uid);
      int totalAnswers = 0;
      int totalCorrect = 0;
      int improvedMistakes = 0;
      for (final attempt in attempts) {
        final answers = await _examService.getAttemptAnswers(attempt.id);
        for (final a in answers) {
          totalAnswers += 1;
          final gained = a.autoScore + a.manualScore;
          if ((a.isAutoCorrect && a.isCorrect == true) ||
              (!a.isAutoCorrect && gained > 0)) {
            totalCorrect += 1;
          }
          if (gained > 0 && gained <= 1) {
            improvedMistakes += 1;
          }
        }
      }
      final correctRate = totalAnswers == 0
          ? 0.0
          : ((totalCorrect / totalAnswers) * 100).toDouble();

      final aiInsight = await _buildAIInsight(
        avgPercent: avgPercent,
        correctRate: correctRate,
        streak: streak,
        strongSubjects: strong,
        weakSubjects: weak,
        submittedAssignments: submissions.length,
        gradedAssignments: graded.length,
      );

      if (!mounted) return;
      setState(() {
        _trainingStreakDays = streak;
        _submittedAssignments = submissions.length;
        _gradedAssignments = graded.length;
        _avgPercent = avgPercent;
        _strongSubjects = strong;
        _weakSubjects = weak;
        _finishedAttempts = attempts.length;
        _correctRatePercent = correctRate;
        _improvedMistakes = improvedMistakes;
        _aiInsight = aiInsight;
        _loadingData = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingData = false);
    }
  }

  Future<String> _buildAIInsight({
    required double avgPercent,
    required double correctRate,
    required int streak,
    required List<String> strongSubjects,
    required List<String> weakSubjects,
    required int submittedAssignments,
    required int gradedAssignments,
  }) async {
    final prompt =
        '''
قدّم توصية تعليمية قصيرة جدا (سطر أو سطرين) لطالب بناءً على البيانات التالية:
- متوسط الدرجات: ${avgPercent.toStringAsFixed(0)}%
- نسبة الإجابات الصحيحة بالاختبارات: ${correctRate.toStringAsFixed(0)}%
- السلسلة اليومية: $streak
- المواد القوية: ${strongSubjects.isEmpty ? 'غير متاحة' : strongSubjects.join('، ')}
- المواد الضعيفة: ${weakSubjects.isEmpty ? 'غير متاحة' : weakSubjects.join('، ')}
- الواجبات المسلمة: $submittedAssignments
- الواجبات المصححة: $gradedAssignments
اكتب بالعربية، تحفيزي وعملي، بدون إطالة.''';
    try {
      final text = await _aiService.chat(prompt: prompt);
      return text.trim().isEmpty
          ? 'استمر يوميًا على تدريب نقاط الضعف مع مراجعة الأخطاء.'
          : text.trim();
    } catch (_) {
      return 'استمر يوميًا على تدريب نقاط الضعف مع مراجعة الأخطاء.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.user?.name ?? 'الطالب';
    final studentCode = authProvider.user?.studentCode ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'الملف الشخصي',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              );
              if (result == true) {
                // Profile will refresh automatically via Provider
                // If needed, you can trigger a refresh in AuthProvider
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header Section
            _buildProfileHeader(context, userName, studentCode),

            // Progress Overview Card
            _buildProgressOverview(),

            // Achievements & Badges
            _buildAchievementsSection(authProvider.user?.xp ?? 0),

            // Learning Statistics
            _buildLearningStatistics(),

            // Strengths & Weaknesses
            _buildStrengthsWeaknesses(),

            // Settings Section
            _buildSettingsSection(context, authProvider),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Profile Header Section
  Widget _buildProfileHeader(
    BuildContext context,
    String userName,
    String studentCode,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF22C55E), Color(0xFF2563EB)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Column(
        children: [
          // Profile Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                userName.isNotEmpty ? userName[0] : 'ط',
                style: GoogleFonts.cairo(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF22C55E),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Full Name
          Text(
            userName,
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'طالب',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Student Code with Copy and QR Code Buttons
          if (studentCode.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'كود الطالب: $studentCode',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: studentCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم نسخ الكود بنجاح',
                            style: GoogleFonts.cairo(),
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.copy,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentQRCodeScreen(
                            studentCode: studentCode,
                            studentName: userName,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.qr_code,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'لا يوجد كود طالب',
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          const SizedBox(height: 12),
          // Motivational Subtitle
          Text(
            'رحلة التعلّم مستمرة 🚀',
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  // Progress Overview Card
  Widget _buildProgressOverview() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        if (user == null) {
          return const SizedBox.shrink();
        }

        final int currentXP = user.xp;
        final int currentLevel = user.level;

        // Get XP required for current and next level
        final int currentLevelMinXP = _getXPRequiredForLevel(currentLevel);
        final int nextLevelMinXP = currentLevel >= 10
            ? currentXP
            : _getXPRequiredForLevel(currentLevel + 1);
        final int xpInCurrentLevel = currentXP - currentLevelMinXP;
        final int xpNeededForNextLevel = currentLevel >= 10
            ? 0
            : (nextLevelMinXP - currentLevelMinXP);
        final double progress = currentLevel >= 10
            ? 1.0
            : (xpInCurrentLevel / xpNeededForNextLevel).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
              Text(
                'تقدّمك التعليمي',
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 20),
              // Current Level
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المستوى الحالي',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            color: Color(0xFFFACC15),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'المستوى $currentLevel',
                            style: GoogleFonts.cairo(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'إجمالي النقاط',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Color(0xFFFACC15),
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${currentXP.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} XP',
                            style: GoogleFonts.cairo(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currentLevel >= 10
                            ? 'وصلت للمستوى الأعلى! 🎉'
                            : 'التقدم إلى المستوى ${currentLevel + 1}',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        currentLevel >= 10
                            ? '$currentXP XP'
                            : '$xpInCurrentLevel / $xpNeededForNextLevel XP',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF22C55E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Learning Streak
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFB923C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Text(
                      '$_trainingStreakDays أيام متتالية من التعلّم',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Achievements & Badges Section
  Widget _buildAchievementsSection(int xp) {
    final badges = <_ProfileBadge>[
      _ProfileBadge(
        Icons.rocket_launch,
        'بداية قوية',
        _submittedAssignments >= 1,
        const Color(0xFF60A5FA),
      ),
      _ProfileBadge(
        Icons.local_fire_department,
        '3 أيام مستمرة',
        _trainingStreakDays >= 3,
        const Color(0xFFF97316),
      ),
      _ProfileBadge(
        Icons.whatshot,
        '7 أيام مستمرة',
        _trainingStreakDays >= 7,
        const Color(0xFFEA580C),
      ),
      _ProfileBadge(Icons.star, 'ألف XP', xp >= 1000, const Color(0xFFFACC15)),
      _ProfileBadge(
        Icons.quiz,
        'منجز الاختبارات',
        _finishedAttempts >= 3,
        const Color(0xFF818CF8),
      ),
      _ProfileBadge(
        Icons.workspace_premium,
        '5 درجات ممتازة',
        _avgPercent >= 85 && _gradedAssignments >= 5,
        const Color(0xFF22C55E),
      ),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الإنجازات',
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: badges
                  .map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildBadge(b.icon, b.title, b.unlocked, b.color),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String title, bool unlocked, Color color) {
    return GestureDetector(
      onTap: unlocked
          ? () {
              // TODO: Show tooltip
            }
          : null,
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unlocked ? color.withValues(alpha: 0.1) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unlocked ? color : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: unlocked ? color : Colors.grey[400], size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: unlocked ? const Color(0xFF111827) : Colors.grey[400],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Learning Statistics Section
  Widget _buildLearningStatistics() {
    final avgText = '${_avgPercent.toStringAsFixed(0)}%';
    final correctText = '${_correctRatePercent.toStringAsFixed(0)}%';
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إحصائيات التعلّم',
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.assignment_turned_in,
                  title: 'الواجبات المكتملة',
                  value: '$_submittedAssignments',
                  color: const Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.check_circle,
                  title: 'نسبة الإجابات الصحيحة',
                  value: correctText,
                  color: const Color(0xFF22C55E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.access_time,
                  title: 'الاختبارات المنجزة',
                  value: '$_finishedAttempts',
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.trending_up,
                  title: 'الأخطاء المحسّنة',
                  value: '$_improvedMistakes',
                  color: const Color(0xFFFB923C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            icon: Icons.grade,
            title: 'متوسط الدرجات',
            value: avgText,
            color: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
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
          Icon(icon, color: color, size: 24),
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

  // Strengths & Weaknesses Section
  Widget _buildStrengthsWeaknesses() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Color(0xFF7C3AED),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'تحليل الذكاء الاصطناعي',
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Strengths
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'نقاط القوة',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    (_strongSubjects.isNotEmpty
                            ? _strongSubjects
                            : ['لا توجد بيانات كافية'])
                        .map((s) => _buildChip(s, const Color(0xFF22C55E)))
                        .toList(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Weak Areas
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المناطق الضعيفة',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    (_weakSubjects.isNotEmpty
                            ? _weakSubjects
                            : ['لا توجد بيانات كافية'])
                        .map((s) => _buildChip(s, const Color(0xFFFB923C)))
                        .toList(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // AI Insight
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFF7C3AED),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _loadingData ? 'يتم تحليل بياناتك...' : _aiInsight,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // Settings Section
  Widget _buildSettingsSection(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'الإعدادات',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111827),
              ),
            ),
          ),
          _buildSettingItem(
            icon: Icons.person_outline,
            title: 'المعلومات الشخصية',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PersonalInfoScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          _buildSettingItem(
            icon: Icons.notifications_outlined,
            title: 'الإشعارات',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          _buildSettingItem(
            icon: Icons.language,
            title: 'اللغة',
            onTap: () {
              // TODO: Navigate to language settings
            },
          ),
          const Divider(height: 1),
          _buildSettingItem(
            icon: Icons.lock_outline,
            title: 'الخصوصية والأمان',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacySecurityScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          _buildSettingItem(
            icon: Icons.help_outline,
            title: 'المساعدة والدعم',
            onTap: () {
              // TODO: Navigate to help
            },
          ),
          const Divider(height: 1),
          _buildSettingItem(
            icon: Icons.delete_forever_outlined,
            title: 'حذف الحساب',
            textColor: Colors.red,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('حذف الحساب', style: GoogleFonts.cairo()),
                  content: Text(
                    'سيتم حذف الحساب نهائياً من النظام ولا يمكن التراجع. هل تريد المتابعة؟',
                    style: GoogleFonts.cairo(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('إلغاء', style: GoogleFonts.cairo()),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        'حذف نهائي',
                        style: GoogleFonts.cairo(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;

              try {
                await authProvider.deleteAccount();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString(), style: GoogleFonts.cairo()),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          const Divider(height: 1),
          _buildSettingItem(
            icon: Icons.logout,
            title: 'تسجيل الخروج',
            textColor: Colors.red,
            onTap: () async {
              // Show confirmation dialog
              bool? confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('تسجيل الخروج', style: GoogleFonts.cairo()),
                  content: Text(
                    'هل أنت متأكد من تسجيل الخروج؟',
                    style: GoogleFonts.cairo(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('إلغاء', style: GoogleFonts.cairo()),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        'تسجيل الخروج',
                        style: GoogleFonts.cairo(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await authProvider.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? const Color(0xFF6B7280)),
      title: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor ?? const Color(0xFF111827),
        ),
      ),
      trailing: Icon(
        Icons.arrow_back_ios,
        size: 16,
        color: textColor ?? const Color(0xFF6B7280),
      ),
      onTap: onTap,
    );
  }

  // Helper function to get XP required for a level
  int _getXPRequiredForLevel(int level) {
    if (level <= 1) return 0;
    if (level == 2) return 1000;
    if (level == 3) return 3000;
    if (level == 4) return 6000;
    if (level == 5) return 12000;
    if (level == 6) return 24000;
    if (level == 7) return 48000;
    if (level == 8) return 96000;
    if (level == 9) return 192000;
    if (level == 10) return 384000;
    return 768000; // Level 11+ (max)
  }
}

class _ProfileBadge {
  final IconData icon;
  final String title;
  final bool unlocked;
  final Color color;

  _ProfileBadge(this.icon, this.title, this.unlocked, this.color);
}
