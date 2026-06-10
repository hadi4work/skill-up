import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/assignment_service.dart';
import '../../services/notification_service.dart';
import '../../services/exam_service.dart';
import '../../services/mistake_training_service.dart';
import '../../services/student_content_seen_service.dart';
import '../../services/user_service.dart';
import '../../models/assignment_model.dart';
import '../../models/notification_model.dart';
import 'student_profile_screen.dart';
import 'student_assignments_screen.dart';
import 'student_analytics_screen.dart';
import 'student_mistake_training_screen.dart';
import 'notifications_screen.dart';
import 'submit_assignment_screen.dart';
import '../ai_assistant_screen.dart';
import '../../widgets/swipe_to_delete_notification.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _currentIndex = 0;
  final AssignmentService _assignmentService = AssignmentService();
  final ExamService _examService = ExamService();
  List<AssignmentModel> _recentAssignments = [];
  List<String> _strongSubjects = [];
  List<String> _weakSubjects = [];
  double _avgPercent = 0;
  int _needsReviewCount = 0;
  int _trainingStreakDays = 0;
  List<_HomeBadge> _earnedBadges = [];
  String _aiRecommendation = 'استمر بالحل وستظهر التوصيات هنا.';
  bool _isLoadingAssignments = false;
  final Set<String> _pendingDeletedNotificationIds = {};
  bool _assignmentsTabBadge = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentAssignments();
    });
  }

  Future<void> _loadRecentAssignments() async {
    if (_isLoadingAssignments) return;

    setState(() {
      _isLoadingAssignments = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    debugPrint('👤 Student user: ${user?.name}');
    debugPrint('📚 Student classIds: ${user?.classIds}');

    if (user == null) {
      if (mounted) setState(() => _isLoadingAssignments = false);
      return;
    }

    if (user.classIds == null || user.classIds!.isEmpty) {
      debugPrint('⚠️ Student has no classIds');
      try {
        final mistakeSvc = MistakeTrainingService();
        final userSvc = UserService();
        final mastered = await userSvc.getMistakeTrainingMasteredIds(user.uid);
        final disc = await mistakeSvc.discoverMistakeItems(
          studentId: user.uid,
          classIds: [],
          excludeIds: mastered,
        );
        await userSvc.syncMistakeTrainingPending(user.uid, disc);
        final pending = await userSvc.getMistakeTrainingPending(user.uid);
        if (mounted) {
          setState(() {
            _needsReviewCount = pending.length;
            _isLoadingAssignments = false;
            _assignmentsTabBadge = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isLoadingAssignments = false;
            _assignmentsTabBadge = false;
          });
        }
      }
      return;
    }

    try {
      debugPrint('🔍 Loading assignments for classes: ${user.classIds}');
      final assignments = await _assignmentService.getStudentAssignments(
        user.classIds!,
      );
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final submissions = await _assignmentService.getSubmissionsByStudentId(
        user.uid,
      );
      final finishedAttempts = await _examService.getStudentFinishedAttempts(user.uid);
      final assignmentById = {for (final a in assignments) a.id: a};
      final graded = submissions
          .where((s) => s.isGraded && s.grade != null)
          .toList();

      final Map<String, List<double>> percentBySubject = {};
      double avgPercent = 0;
      if (graded.isNotEmpty) {
        double sum = 0;
        for (final s in graded) {
          final assignment = assignmentById[s.assignmentId];
          if (assignment == null || assignment.totalPoints <= 0) continue;
          final percent = (s.grade! / assignment.totalPoints) * 100;
          sum += percent;
          percentBySubject.putIfAbsent(assignment.subject, () => []).add(percent);
        }
        avgPercent = sum / graded.length;
      }

      final mistakeSvc = MistakeTrainingService();
      final userSvc = UserService();
      final mastered = await userSvc.getMistakeTrainingMasteredIds(user.uid);
      final discovered = await mistakeSvc.discoverMistakeItems(
        studentId: user.uid,
        classIds: user.classIds!,
        excludeIds: mastered,
      );
      await userSvc.syncMistakeTrainingPending(user.uid, discovered);
      final pendingReview = await userSvc.getMistakeTrainingPending(user.uid);
      final needsReviewCount = pendingReview.length;

      final subjectAverageEntries = percentBySubject.entries.map((entry) {
        final values = entry.value;
        final avg = values.reduce((a, b) => a + b) / values.length;
        return MapEntry(entry.key, avg);
      }).toList();
      subjectAverageEntries.sort((a, b) => b.value.compareTo(a.value));
      final strongSubjects = subjectAverageEntries.take(2).map((e) => e.key).toList();
      final weakSubjects = subjectAverageEntries.reversed.take(2).map((e) => e.key).toList();
      final streakDays = (userDoc.data()?['mistakeTrainingStreakDays'] as num?)?.toInt() ?? 0;
      int highGradesCount = 0;
      for (final s in graded) {
        final assignment = assignmentById[s.assignmentId];
        if (assignment == null || assignment.totalPoints <= 0) continue;
        final percent = (s.grade! / assignment.totalPoints) * 100;
        if (percent >= 85) highGradesCount += 1;
      }
      final earnedBadges = _buildEarnedBadges(
        xp: user.xp,
        streakDays: streakDays,
        submittedCount: submissions.length,
        gradedCount: graded.length,
        highGradesCount: highGradesCount,
        finishedAttemptsCount: finishedAttempts.length,
      );

      String recommendation;
      if (graded.isEmpty) {
        recommendation = 'ابدأ بتسليم الواجبات المصححة لتظهر توصيات أدق.';
      } else if (avgPercent >= 85) {
        recommendation = 'أداء ممتاز! حافظ على مستواك ودرّب زملاءك في ${strongSubjects.isNotEmpty ? strongSubjects.first : 'موادك القوية'}.';
      } else if (weakSubjects.isNotEmpty) {
        recommendation = 'ركّز هذا الأسبوع على ${weakSubjects.join(' و ')} لتحسين النتائج.';
      } else {
        recommendation = 'استمر بالممارسة اليومية لرفع متوسط الأداء.';
      }

      debugPrint('✅ Loaded ${assignments.length} assignments');
      bool tabBadge = false;
      try {
        final unseenA = await StudentContentSeenService.hasUnseenAssignments(
          user.uid,
          assignments.map((a) => a.id),
        );
        final exams = await _examService.getStudentAvailableExams(
          user.classIds!,
          assessmentType: 'exam',
        );
        final works = await _examService.getStudentAvailableExams(
          user.classIds!,
          assessmentType: 'assignment',
        );
        final unseenE = await StudentContentSeenService.hasUnseenTimedExams(
          user.uid,
          exams.map((e) => e.id),
        );
        final unseenW = await StudentContentSeenService.hasUnseenTimedAssignments(
          user.uid,
          works.map((e) => e.id),
        );
        tabBadge = unseenA || unseenE || unseenW;
      } catch (_) {
        tabBadge = false;
      }

      if (mounted) {
        setState(() {
          // Show only upcoming assignments (not overdue) and limit to 3
          final now = DateTime.now();
          _recentAssignments = assignments
              .where((a) => a.deadline.isAfter(now))
              .take(3)
              .toList();
          _strongSubjects = strongSubjects;
          _weakSubjects = weakSubjects;
          _avgPercent = avgPercent;
          _needsReviewCount = needsReviewCount;
          _trainingStreakDays = streakDays;
          _earnedBadges = earnedBadges;
          _aiRecommendation = recommendation;
          _assignmentsTabBadge = tabBadge;
          debugPrint(
            '📋 Showing ${_recentAssignments.length} recent assignments',
          );
          _isLoadingAssignments = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading assignments: $e');
      if (mounted) {
        setState(() {
          _isLoadingAssignments = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Create pages list in build() method to access Provider
    final List<Widget> pages = [
      _buildHomeContent(),
      _buildAssignmentsPage(),
      _buildAnalyticsPage(),
      const StudentProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: IndexedStack(index: _currentIndex, children: pages),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // Home Content Widget
  Widget _buildHomeContent() {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.user?.name ?? 'الطالب';

    return Column(
      children: [
        // Top Header
        _buildHeader(userName),

        // Scrollable Content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadRecentAssignments,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Progress & Gamification Section
                  _buildProgressSection(),
                  const SizedBox(height: 16),
                  // AI Assistant quick access
                  _buildAIAssistantCard(),
                  const SizedBox(height: 24),
                  // Current Assignments Section
                  _buildAssignmentsSection(),
                  const SizedBox(height: 24),
                  // Learning from Mistakes Section
                  _buildMistakesSection(),
                  const SizedBox(height: 24),
                  // Performance Summary
                  _buildPerformanceSection(),
                  const SizedBox(height: 24),
                  // Notifications Preview
                  _buildNotificationsSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Assignments Page
  Widget _buildAssignmentsPage() {
    return StudentAssignmentsScreen(
      onAssignmentsTabBadgeShouldRefresh: _refreshAssignmentsTabBadge,
    );
  }

  Future<void> _refreshAssignmentsTabBadge() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null || user.classIds == null || user.classIds!.isEmpty) {
      if (mounted) setState(() => _assignmentsTabBadge = false);
      return;
    }
    try {
      final assignments = await _assignmentService.getStudentAssignments(
        user.classIds!,
      );
      final unseenA = await StudentContentSeenService.hasUnseenAssignments(
        user.uid,
        assignments.map((a) => a.id),
      );
      final exams = await _examService.getStudentAvailableExams(
        user.classIds!,
        assessmentType: 'exam',
      );
      final works = await _examService.getStudentAvailableExams(
        user.classIds!,
        assessmentType: 'assignment',
      );
      final unseenE = await StudentContentSeenService.hasUnseenTimedExams(
        user.uid,
        exams.map((e) => e.id),
      );
      final unseenW = await StudentContentSeenService.hasUnseenTimedAssignments(
        user.uid,
        works.map((e) => e.id),
      );
      final tabBadge = unseenA || unseenE || unseenW;
      if (mounted) setState(() => _assignmentsTabBadge = tabBadge);
    } catch (_) {
      if (mounted) setState(() => _assignmentsTabBadge = false);
    }
  }

  Widget _buildAnalyticsPage() {
    return const StudentAnalyticsScreen();
  }

  // Header with greeting and icons
  Widget _buildHeader(String userName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF2563EB),
            child: Text(
              userName.isNotEmpty ? userName[0] : 'ط',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Greeting Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحبًا، $userName 👋',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'لنواصل التعلم الذكي اليوم',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          // Notification Bell
          StreamBuilder<int>(
            stream: NotificationService().getUnreadCountStream(
              Provider.of<AuthProvider>(context).user?.uid ?? '',
            ),
            builder: (context, snapshot) {
              int unreadCount = snapshot.data ?? 0;
              return IconButton(
                icon: Stack(
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFF111827),
                      size: 28,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StudentNotificationsScreen(),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // Progress & Gamification Section
  Widget _buildProgressSection() {
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
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نقاط الخبرة',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
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
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Level Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Color(0xFFFACC15),
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'المستوى $currentLevel',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      Text(
                        currentLevel >= 10
                            ? '$currentXP XP'
                            : '$xpInCurrentLevel / $xpNeededForNextLevel XP',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF22C55E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Streak and Badges
              Row(
                children: [
                  // Streak
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 4),
                        Text(
                          '$_trainingStreakDays ${_trainingStreakDays == 1 ? 'يوم' : 'أيام'}',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Badges
                  Expanded(
                    child: Row(
                      children: [
                        _buildBadgeIcon(0),
                        const SizedBox(width: 8),
                        _buildBadgeIcon(1),
                        const SizedBox(width: 8),
                        _buildBadgeIcon(2),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadgeIcon(int index) {
    final badge = index < _earnedBadges.length ? _earnedBadges[index] : null;
    final isEarned = badge != null;
    final icon = badge?.icon ?? Icons.lock_outline_rounded;
    final color = badge?.color ?? const Color(0xFF9CA3AF);
    final label = badge?.title ?? 'وسام مقفل';
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isEarned ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Tooltip(
        message: label,
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  List<_HomeBadge> _buildEarnedBadges({
    required int xp,
    required int streakDays,
    required int submittedCount,
    required int gradedCount,
    required int highGradesCount,
    required int finishedAttemptsCount,
  }) {
    final all = <_HomeBadge>[
      _HomeBadge(
        id: 'starter',
        title: 'بداية قوية',
        icon: Icons.rocket_launch_rounded,
        color: const Color(0xFF60A5FA),
        earned: submittedCount >= 1,
      ),
      _HomeBadge(
        id: 'streak3',
        title: 'ملتزم 3 أيام',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFF97316),
        earned: streakDays >= 3,
      ),
      _HomeBadge(
        id: 'streak7',
        title: 'ملتزم 7 أيام',
        icon: Icons.whatshot_rounded,
        color: const Color(0xFFEA580C),
        earned: streakDays >= 7,
      ),
      _HomeBadge(
        id: 'xp1000',
        title: 'ألف XP',
        icon: Icons.star_rounded,
        color: const Color(0xFFFACC15),
        earned: xp >= 1000,
      ),
      _HomeBadge(
        id: 'quiz3',
        title: 'منجز الاختبارات',
        icon: Icons.quiz_rounded,
        color: const Color(0xFF818CF8),
        earned: finishedAttemptsCount >= 3,
      ),
      _HomeBadge(
        id: 'high5',
        title: '5 درجات ممتازة',
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFF22C55E),
        earned: highGradesCount >= 5 && gradedCount >= 5,
      ),
    ];

    final earned = all.where((b) => b.earned).toList();
    if (earned.isEmpty) return [];
    // عرض أهم 3 أوسمة مكتسبة
    return earned.take(3).toList();
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

  Widget _buildAIAssistantCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AIAssistantScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF7C3AED).withValues(alpha: 0.15),
              const Color(0xFF2563EB).withValues(alpha: 0.15),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.psychology,
                color: Color(0xFF7C3AED),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مساعد الذكاء الاصطناعي',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'اسأل أو اطلب تلميحاً للواجبات',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }

  // Current Assignments Section
  Widget _buildAssignmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'واجباتك الحالية',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111827),
              ),
            ),
            if (_recentAssignments.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 1; // Navigate to assignments page
                  });
                },
                child: Text(
                  'عرض الكل',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingAssignments)
          const Center(child: CircularProgressIndicator())
        else if (_recentAssignments.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'لا توجد واجبات حالية',
                style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[600]),
              ),
            ),
          )
        else
          ..._recentAssignments.map(
            (assignment) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildAssignmentCardFromModel(assignment),
            ),
          ),
      ],
    );
  }

  Widget _buildAssignmentCardFromModel(AssignmentModel assignment) {
    final now = DateTime.now();
    final isOverdue = assignment.deadline.isBefore(now);
    final daysUntilDeadline = assignment.deadline.difference(now).inDays;

    String dueDateText;
    String status;
    Color statusColor;

    if (isOverdue) {
      dueDateText = 'منتهي';
      status = 'منتهي';
      statusColor = Colors.red;
    } else if (daysUntilDeadline == 0) {
      dueDateText = 'ينتهي اليوم';
      status = 'Due Today';
      statusColor = const Color(0xFFFB923C);
    } else if (daysUntilDeadline == 1) {
      dueDateText = 'غداً';
      status = 'Due Soon';
      statusColor = const Color(0xFFFACC15);
    } else {
      dueDateText = 'بعد $daysUntilDeadline أيام';
      status = 'Pending';
      statusColor = const Color(0xFF6B7280);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                SubmitAssignmentScreen(assignment: assignment),
          ),
        ).then((result) async {
          await _refreshAssignmentsTabBadge();
          if (result == true) {
            await _loadRecentAssignments();
          }
        });
      },
      child: Container(
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
        child: Row(
          children: [
            // Subject Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.book, color: Colors.white),
            ),
            const SizedBox(width: 12),
            // Subject Info
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'الموعد النهائي: $dueDateText',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: const Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Learning from Mistakes Section
  Widget _buildMistakesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF22C55E).withValues(alpha: 0.1),
            const Color(0xFF2563EB).withValues(alpha: 0.1),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'التعلّم من الأخطاء',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_needsReviewCount ${_needsReviewCount == 1 ? 'عنصر' : 'عناصر'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'تحتاج إلى مراجعة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: InkWell(
                  onTap: () {
                    final user = Provider.of<AuthProvider>(context, listen: false).user;
                    if (user == null) return;
                    if (_needsReviewCount == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'ممتاز! لا توجد أخطاء تحتاج مراجعة حالياً.',
                            style: GoogleFonts.cairo(),
                          ),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                      return;
                    }
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentMistakeTrainingScreen(
                          studentId: user.uid,
                          classIds: user.classIds ?? const [],
                        ),
                      ),
                    ).then((_) {
                      if (mounted) _loadRecentAssignments();
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.analytics, color: Colors.white, size: 20),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'أعد المحاولة',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.tips_and_updates,
                  color: Color(0xFF7C3AED),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _weakSubjects.isEmpty
                        ? 'لا توجد مواضيع ضعيفة واضحة حاليًا'
                        : 'المواضيع الضعيفة: ${_weakSubjects.join('، ')}',
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

  // Performance Summary Section
  Widget _buildPerformanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ملخص الأداء',
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
              child: _buildPerformanceCard(
                title: 'نقاط القوة',
                icon: Icons.trending_up,
                color: const Color(0xFF22C55E),
                items: _strongSubjects.isNotEmpty ? _strongSubjects : ['لا توجد بيانات كافية'],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPerformanceCard(
                title: 'المناطق الضعيفة',
                icon: Icons.trending_down,
                color: const Color(0xFFFACC15),
                items: _weakSubjects.isNotEmpty ? _weakSubjects : ['لا توجد بيانات كافية'],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () {
            setState(() => _currentIndex = 2);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
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
            child: Row(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'توصية الذكاء الاصطناعي',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _aiRecommendation,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_avgPercent.toStringAsFixed(0)}%',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    Text(
                      'متوسطك',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
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
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Notifications Preview Section
  Widget _buildNotificationsSection() {
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.user?.uid;

    if (userId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<NotificationModel>>(
      stream: NotificationService().getUserNotifications(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final notifications = snapshot.data ?? [];
        final recentNotifications = notifications
            .where((n) => !_pendingDeletedNotificationIds.contains(n.id))
            .take(2)
            .toList();

        if (recentNotifications.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'الإشعارات',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const StudentNotificationsScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'عرض الكل',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recentNotifications.map(
              (notification) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SwipeToDeleteNotification(
                  notificationId: notification.id,
                  onDismissed: () {
                    setState(() => _pendingDeletedNotificationIds.add(notification.id));
                    NotificationService()
                        .deleteNotification(notification.id)
                        .catchError((_) {
                      if (mounted) {
                        setState(() =>
                            _pendingDeletedNotificationIds.remove(notification.id));
                      }
                    });
                  },
                  child: _buildNotificationItem(
                    icon: Icons.assignment,
                    title: notification.title,
                    subtitle: notification.body,
                    color: const Color(0xFF2563EB),
                    isRead: notification.isRead,
                    onTap: () async {
                      if (!notification.isRead) {
                        await NotificationService().markAsRead(notification.id);
                      }
                      if (mounted &&
                          notification.type == 'assignment' &&
                          notification.assignmentId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const StudentAssignmentsScreen(),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    bool isRead = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead ? Colors.grey[200]! : Colors.blue[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Bottom Navigation Bar
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 1) {
            _refreshAssignmentsTabBadge();
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: const Color(0xFF6B7280),
        selectedLabelStyle: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.cairo(fontSize: 12),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.assignment),
                if (_assignmentsTabBadge)
                  PositionedDirectional(
                    top: -2,
                    end: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'الواجبات',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.analytics),
            label: 'التحليلات',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: 'الملف الشخصي',
          ),
        ],
      ),
    );
  }
}

class _HomeBadge {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final bool earned;

  const _HomeBadge({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.earned,
  });
}
