import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/assignment_service.dart';
import '../../services/class_service.dart';
import '../../services/notification_service.dart';
import '../../models/assignment_model.dart';
import 'teacher_profile_screen.dart';
import 'create_class_screen.dart';
import 'create_assignment_screen.dart';
import 'teacher_assignments_screen.dart';
import 'grade_submissions_screen.dart';
import 'incomplete_assignments_screen.dart';
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
  List<AssignmentModel> _recentAssignments = [];
  bool _isLoadingAssignments = false;

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
    return Selector<AuthProvider, String?>(
      selector: (_, authProvider) => authProvider.user?.name,
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, userName, _) {
        return Column(
      children: [
        // Top Header
        _buildHeader(userName ?? 'المعلم'),
        
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

  // Placeholder for Analytics Page
  Widget _buildAnalyticsPage() {
    return Center(
      child: Text(
        'صفحة التحليلات',
        style: GoogleFonts.cairo(fontSize: 24),
      ),
    );
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
                  'مرحبًا، أستاذ $userName 👋',
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
                  // TODO: Navigate to analytics
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
                      onPressed: () {
                        // TODO: Edit assignment - navigate to edit screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('ميزة التعديل قريباً', style: GoogleFonts.cairo()),
                            backgroundColor: Colors.orange,
                          ),
                        );
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
                value: '85%',
                icon: Icons.trending_up,
                color: const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'معدل الإنجاز',
                value: '78%',
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
              _buildMistakeItem('حل المعادلات الخطية', 12),
              const SizedBox(height: 8),
              _buildMistakeItem('الكسور العشرية', 8),
              const SizedBox(height: 8),
              _buildMistakeItem('العمليات الحسابية', 5),
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
                      'أغلب الطلاب يواجهون صعوبة في الكسور',
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
          items: ['الكسور', 'الهندسة', 'المعادلات'],
          icon: Icons.trending_down,
          color: const Color(0xFFFB923C),
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          title: 'تمارين مقترحة',
          items: ['ورقة عمل الكسور', 'تمارين الهندسة'],
          icon: Icons.lightbulb_outline,
          color: const Color(0xFF22C55E),
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          title: 'طلاب يحتاجون متابعة',
          items: ['أحمد محمد', 'فاطمة علي', 'خالد سعيد'],
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
          subtitle: '5 طلاب يحتاجون متابعة',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFFB923C),
          action: 'إرسال تنبيه',
        ),
        const SizedBox(height: 12),
        _buildAlertCard(
          title: 'واجبات غير مكتملة',
          subtitle: '3 واجبات لم يتم تسليمها',
          icon: Icons.assignment_late,
          color: const Color(0xFF2563EB),
          action: 'إرسال تنبيه',
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
            onPressed: () {
              // TODO: Send alert
            },
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
