import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import 'parent_profile_screen.dart';
import 'parent_analytics_screen.dart';
import '../shared/notifications_screen.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Create pages list in build() method to access Provider
    final List<Widget> pages = [
      _buildHomeContent(),
      _buildReportsPage(),
      _buildNotificationsPage(),
      const ParentProfileScreen(),
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

  // Home Content Widget
  Widget _buildHomeContent() {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.user?.name ?? 'ولي الأمر';

    return Column(
      children: [
        // Top Header
        _buildHeader(userName),
        
        // Scrollable Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Student Overview Card
                _buildStudentOverviewCard(),
                const SizedBox(height: 24),
                // Performance Summary
                _buildPerformanceSummary(),
                const SizedBox(height: 24),
                // Weak Areas & Alerts
                _buildWeakAreasSection(),
                const SizedBox(height: 24),
                // AI Recommendations
                _buildAIRecommendationsSection(),
                const SizedBox(height: 24),
                // Notifications & Reports
                _buildNotificationsSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportsPage() {
    return const ParentAnalyticsScreen();
  }

  // Placeholder for Notifications Page
  Widget _buildNotificationsPage() {
    return Center(
      child: Text(
        'صفحة التنبيهات',
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
              userName.isNotEmpty ? userName[0] : 'و',
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
                  'مرحبًا، ولي الأمر 👋',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تابع تقدّم ابنك بكل سهولة',
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

  // Student Overview Card
  Widget _buildStudentOverviewCard() {
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
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أحمد محمد',
                      style: GoogleFonts.cairo(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الصف الخامس',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Performance Indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'أداء جيد',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'آخر نشاط: اليوم',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
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
                    'التقدم العام',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  Text(
                    '85%',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: 0.85,
                  minHeight: 12,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Performance Summary Section
  Widget _buildPerformanceSummary() {
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
                title: 'اتجاه الدرجات',
                value: '85%',
                trend: Icons.trending_up,
                color: const Color(0xFF22C55E),
                subtitle: 'تحسن 5% هذا الشهر',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPerformanceCard(
                title: 'إنجاز الواجبات',
                value: '92%',
                trend: Icons.check_circle_outline,
                color: const Color(0xFF22C55E),
                subtitle: '23 من 25 واجب',
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
                  const Icon(Icons.bar_chart, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'توزيع الدرجات',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildGradeBar('الرياضيات', 0.9, const Color(0xFF22C55E)),
              const SizedBox(height: 12),
              _buildGradeBar('العلوم', 0.85, const Color(0xFF22C55E)),
              const SizedBox(height: 12),
              _buildGradeBar('اللغة العربية', 0.75, const Color(0xFFFACC15)),
              const SizedBox(height: 12),
              _buildGradeBar('اللغة الإنجليزية', 0.7, const Color(0xFFFB923C)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceCard({
    required String title,
    required String value,
    required IconData trend,
    required Color color,
    required String subtitle,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                ),
              ),
              Icon(trend, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeBar(String subject, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              subject,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // Weak Areas & Alerts Section
  Widget _buildWeakAreasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'نقاط تحتاج إلى دعم',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111827),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFB923C).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '3',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFB923C),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFB923C).withValues(alpha: 0.3),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFB923C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFB923C), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'المواضيع الضعيفة',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildWeakTopicItem('الكسور', 'صعوبة في العمليات الحسابية'),
              const SizedBox(height: 12),
              _buildWeakTopicItem('الجمع والطرح', 'يحتاج مزيد من التدريب'),
              const SizedBox(height: 12),
              _buildWeakTopicItem('الهندسة', 'فهم أساسي يحتاج تحسين'),
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
                      'يواجه صعوبة في الكسور والجمع',
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

  Widget _buildWeakTopicItem(String topic, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFB923C).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFFB923C),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
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

  // AI Recommendations Section
  Widget _buildAIRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'توصيات الذكاء الاصطناعي',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 16),
        _buildRecommendationCard(
          icon: Icons.fitness_center,
          title: 'تمارين مقترحة',
          description: 'حل 10 تمارين كسور يومياً',
          time: '15 دقيقة',
          color: const Color(0xFF22C55E),
        ),
        const SizedBox(height: 12),
        _buildRecommendationCard(
          icon: Icons.lightbulb_outline,
          title: 'نصيحة التعلم اليومية',
          description: 'راجع دروس الكسور مع أمثلة عملية',
          time: '20 دقيقة',
          color: const Color(0xFF2563EB),
        ),
        const SizedBox(height: 12),
        _buildRecommendationCard(
          icon: Icons.schedule,
          title: 'وقت التحسين المتوقع',
          description: 'مع الممارسة المنتظمة، التحسن متوقع خلال أسبوعين',
          time: '2 أسبوع',
          color: const Color(0xFF7C3AED),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard({
    required IconData icon,
    required String title,
    required String description,
    required String time,
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
          const SizedBox(width: 16),
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
                  description,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  time,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Notifications & Reports Section
  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'التنبيهات والتقارير',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 16),
        _buildNotificationItem(
          icon: Icons.assignment_late,
          title: 'واجبات غير مكتملة',
          subtitle: 'واجب الرياضيات لم يتم تسليمه',
          color: const Color(0xFFFB923C),
        ),
        const SizedBox(height: 12),
        _buildNotificationItem(
          icon: Icons.trending_down,
          title: 'درجات منخفضة',
          subtitle: 'انخفاض في اختبار العلوم',
          color: const Color(0xFFFB923C),
        ),
        const SizedBox(height: 12),
        _buildNotificationItem(
          icon: Icons.emoji_events,
          title: 'إنجاز تحسين',
          subtitle: 'تحسن ملحوظ في اللغة العربية',
          color: const Color(0xFF22C55E),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // TODO: Navigate to weekly report
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.description, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'عرض التقرير الأسبوعي',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String subtitle,
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
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
        ],
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
        unselectedLabelStyle: GoogleFonts.cairo(
          fontSize: 12,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'التقارير',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'التنبيهات',
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
