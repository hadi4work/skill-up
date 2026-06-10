import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/assignment_service.dart';
import '../../services/class_service.dart';
import '../../services/notification_service.dart';
import '../../services/ai_service.dart';
import '../../services/user_service.dart';
import '../../models/assignment_model.dart';
import '../../models/submission_model.dart';
import '../../models/user_model.dart';
import 'teacher_profile_screen.dart';
import 'create_class_screen.dart';
import 'create_assignment_screen.dart';
import 'teacher_assignments_screen.dart';
import 'grade_submissions_screen.dart';
import 'incomplete_assignments_screen.dart';
import 'low_performance_students_screen.dart';
import 'teacher_analytics_screen.dart';
import '../shared/notifications_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  int _currentIndex = 0;
  final AssignmentService _assignmentService = AssignmentService();
  final ClassService _classService = ClassService();
  final AIService _aiService = AIService();
  final NotificationService _notificationService = NotificationService();
  final UserService _userService = UserService();
  List<AssignmentModel> _recentAssignments = [];
  bool _isLoadingAssignments = false;
  bool _isLoadingDashboard = false;
  double _avgGradesPercent = 0;
  double _completionRatePercent = 0;
  int _lowPerformanceStudentsCount = 0;
  int _incompleteAssignmentsCount = 0;
  List<MapEntry<String, int>> _commonMistakes = [];
  List<String> _weakSubjects = [];
  List<String> _exerciseSuggestions = [];
  List<String> _studentsNeedFollowUp = [];
  String _aiClassInsight = 'لا توجد معلومات كافية الآن';
  bool _sendingIncompleteAlerts = false;

  @override
  Widget build(BuildContext context) {
    // Create pages list in build() method to access Provider
    final List<Widget> pages = [
      _buildHomeContent(),
      _buildAssignmentsPage(),
      _buildAnalyticsPage(),
      const TeacherProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentAssignments();
      _loadDashboardStats();
    });
  }

  Future<void> _loadRecentAssignments() async {
    if (_isLoadingAssignments) return;
    
    setState(() {
      _isLoadingAssignments = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final teacherId = authProvider.user?.uid;

    if (teacherId == null) {
      setState(() {
        _isLoadingAssignments = false;
      });
      return;
    }

    try {
      final assignments = await _assignmentService.getTeacherAssignments(teacherId);
      if (mounted) {
        setState(() {
          _recentAssignments = assignments.take(3).toList(); // Show only 3 most recent
          _isLoadingAssignments = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading assignments: $e');
      if (mounted) {
        setState(() {
          _isLoadingAssignments = false;
        });
      }
    }
  }

  Future<void> _loadDashboardStats() async {
    if (_isLoadingDashboard) return;
    final teacherId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (teacherId == null) return;

    setState(() => _isLoadingDashboard = true);
    try {
      final assignments = await _assignmentService.getTeacherAssignments(teacherId);
      if (assignments.isEmpty) {
        if (!mounted) return;
        setState(() {
          _avgGradesPercent = 0;
          _completionRatePercent = 0;
          _lowPerformanceStudentsCount = 0;
          _incompleteAssignmentsCount = 0;
          _commonMistakes = [];
          _weakSubjects = [];
          _exerciseSuggestions = [];
          _studentsNeedFollowUp = [];
          _aiClassInsight = 'لا توجد بيانات كافية بعد. ابدأ بإضافة واجبات وتقييمها.';
          _isLoadingDashboard = false;
        });
        return;
      }

      int expectedSubmissions = 0;
      int actualSubmissions = 0;
      int gradedCount = 0;
      double gradePercentSum = 0;
      int incompleteAssignments = 0;
      final Map<String, List<double>> subjectPercents = {};
      final Map<String, List<double>> studentPercents = {};

      for (final assignment in assignments) {
        final submissions = await _assignmentService.getAssignmentSubmissions(assignment.id);
        actualSubmissions += submissions.length;
        int totalStudentsForAssignment = 0;
        for (final classId in assignment.classIds) {
          final classModel = await _classService.getClassById(classId);
          if (classModel != null) totalStudentsForAssignment += classModel.studentCodes.length;
        }
        expectedSubmissions += totalStudentsForAssignment;
        if (submissions.length < totalStudentsForAssignment) {
          incompleteAssignments += 1;
        }

        for (final SubmissionModel s in submissions) {
          if (!s.isGraded || s.grade == null || assignment.totalPoints <= 0) continue;
          final percent = (s.grade! / assignment.totalPoints) * 100;
          gradePercentSum += percent;
          gradedCount += 1;
          subjectPercents.putIfAbsent(assignment.subject, () => []).add(percent);
          studentPercents.putIfAbsent(s.studentId, () => []).add(percent);
        }
      }

      final avgGrades = gradedCount == 0 ? 0.0 : gradePercentSum / gradedCount;
      final completionRate = expectedSubmissions == 0 ? 0.0 : (actualSubmissions / expectedSubmissions) * 100;

      final weakSubjectsEntries = subjectPercents.entries.map((e) {
        final avg = e.value.reduce((a, b) => a + b) / e.value.length;
        return MapEntry(e.key, avg);
      }).toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      final weakSubjects = weakSubjectsEntries.take(3).map((e) => e.key).toList();

      final commonMistakes = weakSubjectsEntries
          .take(3)
          .map((e) => MapEntry(e.key, e.value.round()))
          .toList();

      final lowStudents = studentPercents.entries.where((e) {
        final avg = e.value.reduce((a, b) => a + b) / e.value.length;
        return avg < 60;
      }).toList();
      final lowCount = lowStudents.length;
      final followUp = lowStudents.take(3).map((e) => 'طالب (${e.key.substring(0, e.key.length > 6 ? 6 : e.key.length)})').toList();

      final exerciseSuggestions = weakSubjects.isEmpty
          ? <String>[]
          : weakSubjects.map((s) => 'تمارين علاجية في $s').toList();

      // Call AI only when data is sufficient, to reduce token usage
      final bool hasEnoughDataForAI =
          gradedCount >= 5 &&
          assignments.length >= 2 &&
          (weakSubjects.isNotEmpty || lowCount > 0);

      final aiInsight = hasEnoughDataForAI
          ? await _buildTeacherAIInsight(
              avgGrades: avgGrades,
              completionRate: completionRate,
              weakSubjects: weakSubjects,
              lowStudentsCount: lowCount,
            )
          : 'لا توجد معلومات كافية الآن';

      if (!mounted) return;
      setState(() {
        _avgGradesPercent = avgGrades;
        _completionRatePercent = completionRate;
        _incompleteAssignmentsCount = incompleteAssignments;
        _commonMistakes = commonMistakes;
        _weakSubjects = weakSubjects;
        _exerciseSuggestions = exerciseSuggestions;
        _lowPerformanceStudentsCount = lowCount;
        _studentsNeedFollowUp = followUp;
        _aiClassInsight = aiInsight;
        _isLoadingDashboard = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingDashboard = false);
    }
  }

  Future<String> _buildTeacherAIInsight({
    required double avgGrades,
    required double completionRate,
    required List<String> weakSubjects,
    required int lowStudentsCount,
  }) async {
    final prompt = '''
أنت مساعد تربوي للمعلم. أعطِ توصية قصيرة جدا (سطر أو سطرين) بالعربية بناء على:
- متوسط الدرجات: ${avgGrades.toStringAsFixed(0)}%
- معدل التسليم: ${completionRate.toStringAsFixed(0)}%
- المواد الضعيفة: ${weakSubjects.isEmpty ? 'غير متاح' : weakSubjects.join('، ')}
- عدد الطلاب الذين يحتاجون متابعة: $lowStudentsCount
اجعلها عملية ومباشرة.''';
    try {
      final text = await _aiService.chat(prompt: prompt);
      return text.trim().isEmpty ? 'ركز هذا الأسبوع على تدريب نقاط الضعف ومتابعة المتأخرين.' : text.trim();
    } catch (_) {
      return 'ركز هذا الأسبوع على تدريب نقاط الضعف ومتابعة المتأخرين.';
    }
  }

  Future<void> _deleteAssignment(String assignmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف', style: GoogleFonts.cairo()),
        content: Text(
          'هل أنت متأكد من حذف هذا الواجب؟ لا يمكن التراجع عن هذا الإجراء.',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('حذف', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _assignmentService.deleteAssignment(assignmentId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حذف الواجب بنجاح', style: GoogleFonts.cairo()),
              backgroundColor: Colors.green,
            ),
          );
          _loadRecentAssignments();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ: $e', style: GoogleFonts.cairo()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Home Content Widget
  Widget _buildHomeContent() {
    return Selector<AuthProvider, (String?, String?)>(
      selector: (_, authProvider) =>
          (authProvider.user?.name, authProvider.user?.gender),
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, data, _) {
        final userName = data.$1;
        final gender = data.$2;
        return Column(
      children: [
        // Top Header
        _buildHeader(userName ?? 'المعلم', gender),
        
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
                  // Quick Actions Section
                  _buildQuickActionsSection(),
                  const SizedBox(height: 24),
                  // Assignments Overview
                  _buildAssignmentsOverview(),
                  const SizedBox(height: 24),
                  // Class Performance Analytics
                  _buildPerformanceAnalytics(),
                  const SizedBox(height: 24),
                  // AI Insights & Recommendations
                  _buildAIInsightsSection(),
                  const SizedBox(height: 24),
                  // Notifications & Alerts
                  _buildNotificationsSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
      },
    );
  }

  // Assignments Page
  Widget _buildAssignmentsPage() {
    return const TeacherAssignmentsScreen();
  }

  Widget _buildAnalyticsPage() {
    return const TeacherAnalyticsScreen();
  }

  String _teacherGreetingLine(String userName, String? gender) {
    if (gender == 'female') {
      return 'أهلاً، آنسة $userName 👋';
    }
    return 'مرحبًا، أستاذ $userName 👋';
  }

  // Header with greeting and icons
  Widget _buildHeader(String userName, String? gender) {
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
              userName.isNotEmpty ? userName[0] : 'م',
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
                  _teacherGreetingLine(userName, gender),
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'إدارة ذكية للواجبات وأداء الطلاب',
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
                      builder: (context) => const NotificationsScreen(),
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

  // Quick Actions Section
  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إجراءات سريعة',
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
              child: _buildQuickActionCard(
                icon: Icons.add_circle_outline,
                title: 'إنشاء واجب\nجديد',
                color: const Color(0xFF2563EB),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateAssignmentScreen(),
                    ),
                  );
                  if (result == true) {
                    _loadRecentAssignments();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.analytics_outlined,
                title: 'عرض تحليلات\nالفصل',
                color: const Color(0xFF7C3AED),
                onTap: () {
                  // Already on analytics tab when tapping from home; switch tab
                  setState(() => _currentIndex = 2);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.people_outline,
                title: 'إدارة\nالطلاب',
                color: const Color(0xFF22C55E),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateClassScreen(),
                    ),
                  );
                  if (result == true) {
                    // Refresh if needed
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              color.withValues(alpha: 0.8),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Assignments Overview Section
  Widget _buildAssignmentsOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الواجبات والاختبارات',
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
                'لا توجد واجبات',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          )
        else
          ..._recentAssignments.map((assignment) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAssignmentCardFromModel(assignment),
              )),
      ],
    );
  }

  Widget _buildAssignmentCardFromModel(AssignmentModel assignment) {
    return FutureBuilder<Map<String, int>>(
      future: _getAssignmentStats(assignment),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        int submissionCount = snapshot.data?['submissions'] ?? 0;
        int totalStudents = snapshot.data?['totalStudents'] ?? 0;
        final progress = totalStudents > 0 ? submissionCount / totalStudents : 0.0;
        
        final now = DateTime.now();
        final isOverdue = assignment.deadline.isBefore(now);
        final daysUntilDeadline = assignment.deadline.difference(now).inDays;
        
        String deadlineText;
        if (isOverdue) {
          deadlineText = 'منتهي';
        } else if (daysUntilDeadline == 0) {
          deadlineText = 'ينتهي اليوم';
        } else if (daysUntilDeadline == 1) {
          deadlineText = 'ينتهي غداً';
        } else {
          deadlineText = 'ينتهي بعد $daysUntilDeadline أيام';
        }

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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment.title,
                          style: GoogleFonts.cairo(
                            fontSize: 16,
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
                            if (isOverdue) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'منتهي',
                                  style: GoogleFonts.cairo(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Deadline and Submissions
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    deadlineText,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: isOverdue ? Colors.red : const Color(0xFF6B7280),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.people, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '$submissionCount / $totalStudents طالب سلم',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                ),
              ),
              const SizedBox(height: 16),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GradeSubmissionsScreen(
                              assignment: assignment,
                            ),
                          ),
                        ).then((_) {
                          _loadRecentAssignments();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'عرض',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateAssignmentScreen(
                              assignment: assignment,
                            ),
                          ),
                        );
                        if (result == true) _loadRecentAssignments();
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF7C3AED)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'تعديل',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _deleteAssignment(assignment.id);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'حذف',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
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

  Future<Map<String, int>> _getAssignmentStats(AssignmentModel assignment) async {
    int submissionCount = 0;
    int totalStudents = 0;

    try {
      // Get submission count
      submissionCount = await _assignmentService.getSubmissionCount(assignment.id);

      // Calculate total students from all classes
      for (String classId in assignment.classIds) {
        final classModel = await _classService.getClassById(classId);
        if (classModel != null) {
          totalStudents += classModel.studentCodes.length;
        }
      }
    } catch (e) {
      debugPrint('Error getting assignment stats: $e');
    }

    return {
      'submissions': submissionCount,
      'totalStudents': totalStudents,
    };
  }

  // Class Performance Analytics Section
  Widget _buildPerformanceAnalytics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'أداء الفصل',
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
                title: 'متوسط الدرجات',
                value: '${_avgGradesPercent.toStringAsFixed(0)}%',
                icon: Icons.trending_up,
                color: const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'معدل الإنجاز',
                value: '${_completionRatePercent.toStringAsFixed(0)}%',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF2563EB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
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
                  const Icon(Icons.error_outline, color: Color(0xFFFB923C), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'الأخطاء الشائعة',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_commonMistakes.isEmpty)
                Text(
                  'لا توجد بيانات كافية بعد',
                  style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF6B7280)),
                )
              else
                ..._commonMistakes.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildMistakeItem(e.key, e.value),
                    )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF7C3AED).withValues(alpha: 0.1),
                const Color(0xFF2563EB).withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.psychology, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تحليل الذكاء الاصطناعي',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _aiClassInsight,
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
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
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
              fontSize: 28,
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

  Widget _buildMistakeItem(String topic, int count) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFFFB923C),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            topic,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: const Color(0xFF111827),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFB923C).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count طالب',
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFB923C),
            ),
          ),
        ),
      ],
    );
  }

  // AI Insights & Recommendations Section
  Widget _buildAIInsightsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تحليلات الذكاء الاصطناعي',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 16),
        _buildInsightCard(
          title: 'المواضيع الضعيفة',
          items: _weakSubjects.isEmpty ? ['لا توجد بيانات كافية بعد'] : _weakSubjects,
          icon: Icons.trending_down,
          color: const Color(0xFFFB923C),
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          title: 'تمارين مقترحة',
          items: _exerciseSuggestions.isEmpty ? ['لا توجد اقتراحات حالياً'] : _exerciseSuggestions,
          icon: Icons.lightbulb_outline,
          color: const Color(0xFF22C55E),
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          title: 'طلاب يحتاجون متابعة',
          items: _studentsNeedFollowUp.isEmpty ? ['لا يوجد حالياً'] : _studentsNeedFollowUp,
          icon: Icons.person_outline,
          color: const Color(0xFF2563EB),
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required String title,
    required List<String> items,
    required IconData icon,
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
          Row(
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
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
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
                          fontSize: 14,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // Notifications & Alerts Section
  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'التنبيهات',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 16),
        _buildAlertCard(
          title: 'أداء منخفض',
          subtitle: '$_lowPerformanceStudentsCount طلاب يحتاجون متابعة',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFFB923C),
          action: 'فتح القائمة',
          onActionPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LowPerformanceStudentsScreen(),
              ),
            );
          },
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LowPerformanceStudentsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildAlertCard(
          title: 'واجبات غير مكتملة',
          subtitle: '$_incompleteAssignmentsCount واجبات لم يتم تسليمها بالكامل',
          icon: Icons.assignment_late,
          color: const Color(0xFF2563EB),
          action: _sendingIncompleteAlerts ? 'جاري الإرسال...' : 'إرسال تنبيه',
          onActionPressed: _sendingIncompleteAlerts ? null : _sendIncompleteAssignmentAlerts,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const IncompleteAssignmentsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAlertCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String action,
    VoidCallback? onActionPressed,
    VoidCallback? onTap,
  }) {
    Widget card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onActionPressed,
            style: TextButton.styleFrom(
              backgroundColor: color.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              action,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }

  Future<void> _sendIncompleteAssignmentAlerts() async {
    setState(() => _sendingIncompleteAlerts = true);
    try {
      final teacherId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
      if (teacherId == null) return;

      final assignments = await _assignmentService.getTeacherAssignments(teacherId);
      int sent = 0;

      for (final assignment in assignments) {
        final subs = await _assignmentService.getAssignmentSubmissions(assignment.id);
        final submittedIds = subs.map((s) => s.studentId).toSet();
        final targetStudents = <UserModel>[];

        for (final classId in assignment.classIds) {
          final classModel = await _classService.getClassById(classId);
          if (classModel == null) continue;
          for (final code in classModel.studentCodes) {
            final st = await _userService.getUserByStudentCode(code);
            if (st != null && !targetStudents.any((x) => x.uid == st.uid)) {
              targetStudents.add(st);
            }
          }
        }

        for (final st in targetStudents) {
          if (submittedIds.contains(st.uid)) continue;
          await _notificationService.sendIncompleteAssignmentNotification(
            studentId: st.uid,
            assignmentId: assignment.id,
            assignmentTitle: assignment.title,
            assignmentSubject: assignment.subject,
          );
          sent += 1;
          if ((st.parentId ?? '').isNotEmpty) {
            await _notificationService.sendParentHomeworkMissedNotification(
              parentId: st.parentId!,
              childName: st.name,
              assignmentId: assignment.id,
              assignmentTitle: assignment.title,
              assignmentSubject: assignment.subject,
            );
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال تنبيهات الواجبات غير المكتملة إلى $sent طالب', style: GoogleFonts.cairo()),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إرسال التنبيهات: $e', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingIncompleteAlerts = false);
    }
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
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: const Color(0xFF6B7280),
        selectedLabelStyle: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.cairo(
          fontSize: 12,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'الواجبات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'التحليلات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'الملف الشخصي',
          ),
        ],
      ),
    );
  }
}
