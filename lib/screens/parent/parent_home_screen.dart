import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/assignment_model.dart';
import '../../models/notification_model.dart';
import '../../models/submission_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/assignment_service.dart';
import '../../services/notification_service.dart';
import '../../services/user_service.dart';
import '../teacher/qr_scanner_screen.dart';
import 'parent_profile_screen.dart';
import 'parent_analytics_screen.dart';
import '../shared/notifications_screen.dart';
import '../../widgets/swipe_to_delete_notification.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  int _currentIndex = 0;
  final AssignmentService _assignmentService = AssignmentService();
  final NotificationService _notificationService = NotificationService();
  final UserService _userService = UserService();
  bool _loadingHome = true;
  bool _linkingChild = false;
  List<UserModel> _children = [];
  String? _selectedChildId;
  final Map<String, List<SubmissionModel>> _submissionsByChild = {};
  final Map<String, List<AssignmentModel>> _assignmentsByChild = {};
  final Set<String> _pendingDeletedNotificationIds = {};

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final providerSelectedId =
        Provider.of<AuthProvider>(context).parentSelectedChildId;
    if (providerSelectedId != _selectedChildId) {
      _selectedChildId = providerSelectedId;
    }
  }

  Future<void> _loadHomeData() async {
    final parent = Provider.of<AuthProvider>(context, listen: false).user;
    if (parent == null) {
      if (mounted) {
        setState(() {
          _loadingHome = false;
          _children = [];
        });
      }
      return;
    }

    setState(() => _loadingHome = true);
    final linkedValues = parent.children ?? [];
    if (linkedValues.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingHome = false;
          _children = [];
          _submissionsByChild.clear();
          _assignmentsByChild.clear();
        });
      }
      return;
    }

    try {
      final children = <UserModel>[];
      final submissionsByChild = <String, List<SubmissionModel>>{};
      final assignmentsByChild = <String, List<AssignmentModel>>{};

      for (final value in linkedValues) {
        try {
          UserModel? student = await _userService
              .getUserProfile(value)
              .timeout(const Duration(seconds: 10));
          student ??= await _userService
              .getUserByStudentCode(value)
              .timeout(const Duration(seconds: 10));
          if (student == null || student.accountType != 'student') continue;

          children.add(student);
          final submissions = await _assignmentService
              .getSubmissionsByStudentId(student.uid)
              .timeout(const Duration(seconds: 10));
          submissionsByChild[student.uid] = submissions;

          if (student.classIds != null && student.classIds!.isNotEmpty) {
            final assignments = await _assignmentService
                .getStudentAssignments(student.classIds!)
                .timeout(const Duration(seconds: 10));
            assignmentsByChild[student.uid] = assignments;
          } else {
            assignmentsByChild[student.uid] = [];
          }
        } catch (_) {
          continue;
        }
      }

      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final providerSelectedId = authProvider.parentSelectedChildId;
      String? resolvedSelectedId;
      if (children.isNotEmpty) {
        resolvedSelectedId = (providerSelectedId != null &&
                children.any((c) => c.uid == providerSelectedId))
            ? providerSelectedId
            : children.first.uid;
      }
      if (providerSelectedId != resolvedSelectedId) {
        await authProvider.setParentSelectedChildId(resolvedSelectedId);
      }
      setState(() {
        _children = children;
        _selectedChildId = resolvedSelectedId;
        _submissionsByChild
          ..clear()
          ..addAll(submissionsByChild);
        _assignmentsByChild
          ..clear()
          ..addAll(assignmentsByChild);
        _loadingHome = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHome = false);
    } finally {
      if (!mounted) return;
      if (_loadingHome) {
        setState(() => _loadingHome = false);
      }
    }
  }

  Future<void> _scanAndLinkChild() async {
    final parent = Provider.of<AuthProvider>(context, listen: false).user;
    if (parent == null || _linkingChild) return;

    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => QRScannerScreen(
          onCodeScanned: (_) {},
        ),
      ),
    );
    if (!mounted || scannedCode == null || scannedCode.trim().isEmpty) return;

    try {
      setState(() => _linkingChild = true);
      await _userService.linkParentToStudent(parent.uid, scannedCode.trim());
      await Provider.of<AuthProvider>(context, listen: false).refreshUser();
      await _loadHomeData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم ربط الابن بنجاح',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _linkingChild = false);
    }
  }

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
    final aggregated = _aggregateHomeData();

    return Column(
      children: [
        // Top Header
        _buildHeader(userName),
        
        // Scrollable Content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadHomeData,
            child: _loadingHome
                ? const Center(child: CircularProgressIndicator())
                : _children.isEmpty
                    ? _buildNoChildrenState()
                    : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildStudentOverviewCard(aggregated),
                        const SizedBox(height: 24),
                        _buildPerformanceSummary(aggregated),
                        const SizedBox(height: 24),
                        _buildWeakAreasSection(aggregated),
                        const SizedBox(height: 24),
                        _buildAIRecommendationsSection(aggregated),
                        const SizedBox(height: 24),
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

  Widget _buildReportsPage() {
    return const ParentAnalyticsScreen();
  }

  // Placeholder for Notifications Page
  Widget _buildNotificationsPage() {
    final userId = Provider.of<AuthProvider>(context).user?.uid;
    if (userId == null) {
      return Center(
        child: Text(
          'المستخدم غير موجود',
          style: GoogleFonts.cairo(fontSize: 18),
        ),
      );
    }

    Future<void> onPullRefresh() async {
      await _notificationService.deleteOldReadNotifications();
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
              Expanded(
                child: Text(
                  'التنبيهات',
                  style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await _notificationService.markAllAsRead(userId);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تحديد الكل كمقروء', style: GoogleFonts.cairo()),
                    ),
                  );
                },
                child: Text(
                  'تحديد الكل كمقروء',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<NotificationModel>>(
            stream: _notificationService.getUserNotifications(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'تعذر تحميل التنبيهات',
                    style: GoogleFonts.cairo(color: const Color(0xFF6B7280)),
                  ),
                );
              }

              final notifications = snapshot.data ?? [];
              final visible = notifications
                  .where((n) => !_pendingDeletedNotificationIds.contains(n.id))
                  .toList();
              if (visible.isEmpty) {
                return RefreshIndicator(
                  onRefresh: onPullRefresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: 420,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 70, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد إشعارات حالياً',
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'سيظهر هنا كل جديد يخص الأبناء',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: onPullRefresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    return _buildParentNotificationCard(visible[index]);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildParentNotificationCard(NotificationModel notification) {
    final iconData = _notificationIcon(notification.type);
    final iconColor = notification.isRead
        ? const Color(0xFF6B7280)
        : const Color(0xFF7C3AED);

    return SwipeToDeleteNotification(
      notificationId: notification.id,
      onDismissed: () {
        setState(() => _pendingDeletedNotificationIds.add(notification.id));
        _notificationService.deleteNotification(notification.id).catchError((_) {
          if (mounted) {
            setState(() => _pendingDeletedNotificationIds.remove(notification.id));
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : const Color(0xFFF3F4FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notification.isRead
                ? const Color(0xFFE5E7EB)
                : const Color(0xFFDBEAFE),
          ),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            if (!notification.isRead) {
              await _notificationService.markAsRead(notification.id);
            }
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: iconColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ),
                        if (!notification.isRead)
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
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatNotificationDate(notification.createdAt),
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _notificationIcon(String type) {
    switch (type) {
      case NotificationModel.typeParentHomeworkNew:
        return Icons.assignment_turned_in_outlined;
      case NotificationModel.typeParentHomeworkMissed:
        return Icons.assignment_late_outlined;
      case NotificationModel.typeParentGradeLow:
        return Icons.trending_down_rounded;
      case NotificationModel.typeParentImprovement:
        return Icons.trending_up_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatNotificationDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes <= 0) return 'الآن';
        return 'منذ ${difference.inMinutes} دقيقة';
      }
      return 'منذ ${difference.inHours} ساعة';
    }
    if (difference.inDays == 1) return 'أمس';
    if (difference.inDays < 7) return 'منذ ${difference.inDays} أيام';
    return '${date.day}/${date.month}/${date.year}';
  }

  // Header with greeting and icons
  Widget _buildHeader(String userName) {
    final selectedChild = _selectedChild;
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
      child: Column(
        children: [
          Row(
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
                      'مرحبًا، $userName 👋',
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedChild == null
                          ? 'اربط أبناءك عبر Scan للمتابعة'
                          : 'تتابع الآن: ${selectedChild.name}',
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
          if (_children.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _showChildrenPicker,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF2563EB),
                      child: Text(
                        (selectedChild?.name.isNotEmpty ?? false)
                            ? selectedChild!.name[0]
                            : 'ط',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        selectedChild?.name ?? 'اختر الابن',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showChildrenPicker() {
    if (_children.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'اختر الابن',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._children.map(
                  (child) => ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF2563EB),
                      child: Text(
                        child.name.isNotEmpty ? child.name[0] : 'ط',
                        style: GoogleFonts.cairo(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      child.name,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: child.uid == _selectedChildId
                        ? const Icon(Icons.check_circle, color: Color(0xFF22C55E))
                        : null,
                    onTap: () {
                      setState(() => _selectedChildId = child.uid);
                      Provider.of<AuthProvider>(context, listen: false)
                          .setParentSelectedChildId(child.uid);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Student Overview Card
  Widget _buildStudentOverviewCard(_ParentHomeStats stats) {
    final selectedChild = _selectedChild;
    final headerName = selectedChild?.name ?? 'لا يوجد أبناء مرتبطين';

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
                      headerName,
                      style: GoogleFonts.cairo(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _children.isEmpty
                          ? 'قم بالربط عبر Scan'
                          : 'الحساب النشط الآن',
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
                    const Icon(Icons.qr_code_scanner, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _linkingChild ? 'جاري الإضافة...' : 'Scan لإضافة ابن',
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
              InkWell(
                onTap: _linkingChild ? null : _scanAndLinkChild,
                child: Text(
                  'إضافة الآن',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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
                    '${stats.avgPercent.toStringAsFixed(0)}%',
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
                  value: (stats.avgPercent / 100).clamp(0.0, 1.0),
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
  Widget _buildPerformanceSummary(_ParentHomeStats stats) {
    final selectedChild = _selectedChild;
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
                value: '${stats.avgPercent.toStringAsFixed(0)}%',
                trend: stats.avgPercent >= 70
                    ? Icons.trending_up
                    : Icons.trending_down,
                color: stats.avgPercent >= 70
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFFB923C),
                subtitle: selectedChild == null ? 'لا توجد بيانات' : 'متوسط الابن المحدد',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPerformanceCard(
                title: 'إنجاز الواجبات',
                value: '${stats.completionPercent.toStringAsFixed(0)}%',
                trend: Icons.check_circle_outline,
                color: const Color(0xFF2563EB),
                subtitle: '${stats.submittedCount} من ${stats.expectedCount} واجب',
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
              if (stats.subjectAverages.isEmpty)
                Text(
                  'لا توجد بيانات كافية لتوزيع المواد حالياً',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                  ),
                )
              else
                ...stats.subjectAverages.entries.take(4).map((entry) {
                  final value = (entry.value / 100).clamp(0.0, 1.0);
                  final color = entry.value >= 80
                      ? const Color(0xFF22C55E)
                      : entry.value >= 60
                          ? const Color(0xFFFACC15)
                          : const Color(0xFFFB923C);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildGradeBar(entry.key, value, color),
                  );
                }),
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
  Widget _buildWeakAreasSection(_ParentHomeStats stats) {
    final weakSubjects = stats.weakSubjects;
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
                '${weakSubjects.length}',
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
              if (weakSubjects.isEmpty)
                _buildWeakTopicItem('لا توجد نقاط ضعف واضحة', 'استمروا بهذا الأداء الممتاز')
              else
                ...weakSubjects.map((subject) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildWeakTopicItem(
                        subject,
                        'يحتاج متابعة إضافية في ${subject.toLowerCase()}',
                      ),
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
                      stats.aiInsight,
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
  Widget _buildAIRecommendationsSection(_ParentHomeStats stats) {
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
          description: stats.recommendationOne,
          time: '15 دقيقة',
          color: const Color(0xFF22C55E),
        ),
        const SizedBox(height: 12),
        _buildRecommendationCard(
          icon: Icons.lightbulb_outline,
          title: 'نصيحة التعلم اليومية',
          description: stats.recommendationTwo,
          time: '20 دقيقة',
          color: const Color(0xFF2563EB),
        ),
        const SizedBox(height: 12),
        _buildRecommendationCard(
          icon: Icons.schedule,
          title: 'وقت التحسين المتوقع',
          description: stats.etaText,
          time: stats.etaChip,
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
          subtitle: 'يمكنك مراجعة تفاصيل التأخر من صفحة التقارير',
          color: const Color(0xFFFB923C),
        ),
        const SizedBox(height: 12),
        _buildNotificationItem(
          icon: Icons.trending_down,
          title: 'درجات منخفضة',
          subtitle: 'تابع المواد الأضعف وابدأ خطة دعم مبكرة',
          color: const Color(0xFFFB923C),
        ),
        const SizedBox(height: 12),
        _buildNotificationItem(
          icon: Icons.emoji_events,
          title: 'إنجاز تحسين',
          subtitle: 'شجّع ابنك على الاستمرار للحصول على نتائج أفضل',
          color: const Color(0xFF22C55E),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              setState(() => _currentIndex = 1);
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

  UserModel? get _selectedChild {
    if (_children.isEmpty) return null;
    final providerSelectedId =
        Provider.of<AuthProvider>(context, listen: false).parentSelectedChildId;
    final effectiveId = providerSelectedId ?? _selectedChildId;
    if (effectiveId == null) return _children.first;
    for (final child in _children) {
      if (child.uid == effectiveId) return child;
    }
    return _children.first;
  }

  Widget _buildNoChildrenState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        height: 420,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.family_restroom, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 18),
            Text(
              'لا يوجد أبناء مرتبطين',
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'قم بربط الأبناء لعرض الأداء والتحليلات هنا.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _linkingChild ? null : _scanAndLinkChild,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(
                _linkingChild ? 'جاري الربط...' : 'Scan للربط',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ParentHomeStats _aggregateHomeData() {
    final selectedChild = _selectedChild;
    if (selectedChild == null) {
      return const _ParentHomeStats.empty();
    }

    int totalExpected = 0;
    int totalSubmitted = 0;
    double gradeSum = 0;
    int gradeCount = 0;
    final Map<String, List<double>> bySubject = {};

    final assignments = _assignmentsByChild[selectedChild.uid] ?? [];
    final submissions = _submissionsByChild[selectedChild.uid] ?? [];

    totalExpected += assignments.length;
    totalSubmitted += submissions.length;

    for (final submission in submissions) {
      if (!submission.isGraded || submission.grade == null) continue;
      AssignmentModel? assignment;
      try {
        assignment = assignments.firstWhere((a) => a.id == submission.assignmentId);
      } catch (_) {
        assignment = null;
      }
      if (assignment == null || assignment.totalPoints <= 0) continue;
      final percent = (submission.grade! / assignment.totalPoints) * 100;
      gradeSum += percent;
      gradeCount++;
      bySubject.putIfAbsent(assignment.subject, () => []).add(percent);
    }

    final avgPercent = gradeCount > 0 ? (gradeSum / gradeCount) : 0.0;
    final completionPercent = totalExpected > 0
        ? ((totalSubmitted / totalExpected) * 100).clamp(0.0, 100.0)
        : 0.0;

    final subjectAverages = <String, double>{};
    bySubject.forEach((subject, values) {
      if (values.isEmpty) return;
      final avg = values.reduce((a, b) => a + b) / values.length;
      subjectAverages[subject] = avg;
    });

    final sortedSubjects = subjectAverages.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final weakSubjects = sortedSubjects.take(3).map((e) => e.key).toList();

    final aiInsight = weakSubjects.isEmpty
        ? 'لا توجد معلومات كافية الآن'
        : 'أكثر المواد التي تحتاج دعم: ${weakSubjects.join('، ')}';
    final recommendationOne = weakSubjects.isEmpty
        ? 'استمر على نفس الوتيرة مع مراجعة سريعة يومية'
        : 'خصص تدريبًا يوميًا قصيرًا في ${weakSubjects.first}';
    final recommendationTwo = completionPercent < 70
        ? 'ركّز على إنهاء الواجبات في موعدها لرفع المستوى'
        : 'استمر في المتابعة الأسبوعية للحفاظ على الأداء';
    final etaText = avgPercent >= 80
        ? 'المستوى ممتاز، المتوقع استمرار التحسن مع نفس الخطة'
        : 'مع الالتزام والمراجعة اليومية، التحسن واضح خلال 2-3 أسابيع';
    final etaChip = avgPercent >= 80 ? 'جاهز' : '2-3 أسابيع';

    return _ParentHomeStats(
      avgPercent: avgPercent,
      completionPercent: completionPercent,
      submittedCount: totalSubmitted,
      expectedCount: totalExpected,
      subjectAverages: subjectAverages,
      weakSubjects: weakSubjects,
      aiInsight: aiInsight,
      recommendationOne: recommendationOne,
      recommendationTwo: recommendationTwo,
      etaText: etaText,
      etaChip: etaChip,
    );
  }
}

class _ParentHomeStats {
  final double avgPercent;
  final double completionPercent;
  final int submittedCount;
  final int expectedCount;
  final Map<String, double> subjectAverages;
  final List<String> weakSubjects;
  final String aiInsight;
  final String recommendationOne;
  final String recommendationTwo;
  final String etaText;
  final String etaChip;

  const _ParentHomeStats({
    required this.avgPercent,
    required this.completionPercent,
    required this.submittedCount,
    required this.expectedCount,
    required this.subjectAverages,
    required this.weakSubjects,
    required this.aiInsight,
    required this.recommendationOne,
    required this.recommendationTwo,
    required this.etaText,
    required this.etaChip,
  });

  const _ParentHomeStats.empty()
      : avgPercent = 0,
        completionPercent = 0,
        submittedCount = 0,
        expectedCount = 0,
        subjectAverages = const {},
        weakSubjects = const [],
        aiInsight = 'لا توجد معلومات كافية الآن',
        recommendationOne = 'قم بربط الأبناء عبر Scan للبدء',
        recommendationTwo = 'بعد الربط ستظهر التوصيات تلقائياً',
        etaText = 'بمجرد وصول بيانات كافية سيظهر توقّع التحسن',
        etaChip = 'قريباً';
}
