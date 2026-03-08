import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/assignment_service.dart';
import '../../services/notification_service.dart';
import '../../models/assignment_model.dart';
import '../../models/notification_model.dart';
import 'student_profile_screen.dart';
import 'student_assignments_screen.dart';
import 'student_analytics_screen.dart';
import 'notifications_screen.dart';
import 'submit_assignment_screen.dart';
import '../ai_assistant_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _currentIndex = 0;
  final AssignmentService _assignmentService = AssignmentService();
  List<AssignmentModel> _recentAssignments = [];
  bool _isLoadingAssignments = false;

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

    if (user == null || user.classIds == null || user.classIds!.isEmpty) {
      debugPrint('⚠️ Student has no classIds');
      if (mounted) {
        setState(() {
          _isLoadingAssignments = false;
        });
      }
      return;
    }

    try {
      debugPrint('🔍 Loading assignments for classes: ${user.classIds}');
      final assignments = await _assignmentService.getStudentAssignments(
        user.classIds!,
      );
      debugPrint('✅ Loaded ${assignments.length} assignments');
      if (mounted) {
        setState(() {
          // Show only upcoming assignments (not overdue) and limit to 3
          final now = DateTime.now();
          _recentAssignments = assignments
              .where((a) => a.deadline.isAfter(now))
              .take(3)
              .toList();
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
    return const StudentAssignmentsScreen();
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
                          '7 أيام',
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
                        _buildBadgeIcon(Icons.military_tech, Colors.amber),
                        const SizedBox(width: 8),
                        _buildBadgeIcon(Icons.workspace_premium, Colors.purple),
                        const SizedBox(width: 8),
                        _buildBadgeIcon(Icons.emoji_events, Colors.blue),
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

  Widget _buildBadgeIcon(IconData icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
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
        ).then((result) {
          if (result == true) {
            _loadRecentAssignments();
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
              Text(
                'التعلّم من الأخطاء',
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '5 أسئلة',
                      style: GoogleFonts.cairo(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'تحتاج إلى مراجعة',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.refresh, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'أعد المحاولة',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
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
                    'المواضيع الضعيفة: الجبر، الهندسة',
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
                items: ['الجبر', 'الفيزياء'],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPerformanceCard(
                title: 'المناطق الضعيفة',
                icon: Icons.trending_down,
                color: const Color(0xFFFACC15),
                items: ['الهندسة', 'الكيمياء'],
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
                      'ركز على حل المزيد من أسئلة الهندسة',
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
        final recentNotifications = notifications.take(2).toList();

        if (recentNotifications.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الإشعارات',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
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
            icon: const Icon(Icons.assignment),
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
