import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  Stream<List<NotificationModel>>? _notificationsStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;
      if (userId != null) {
        setState(() {
          _notificationsStream = _notificationService.getUserNotifications(userId);
        });
        // Delete old read notifications when screen opens
        _notificationService.deleteOldReadNotifications();
      }
    });
  }

  Future<void> _refreshNotifications() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    if (userId != null) {
      // Delete old read notifications before refreshing
      await _notificationService.deleteOldReadNotifications();
      // Force refresh by recreating the stream
      setState(() {
        _notificationsStream = _notificationService.getUserNotifications(userId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.user?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('المستخدم غير موجود')),
      );
    }

    if (_notificationsStream == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'الإشعارات',
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF111827),
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'الإشعارات',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNotifications,
        child: StreamBuilder<List<NotificationModel>>(
          stream: _notificationsStream,
          key: const ValueKey('notifications_list_stream'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'حدث خطأ: ${snapshot.error}',
                      style: GoogleFonts.cairo(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshNotifications,
                      child: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
                    ),
                  ],
                ),
              );
            }

            final notifications = snapshot.data ?? [];

            if (notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد إشعارات',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'اسحب للأسفل للتحديث',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                return _buildNotificationCard(notifications[index]);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    // Determine icon based on notification type
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case NotificationModel.typeAssignmentNew:
      case NotificationModel.typeAssignmentDeadlineApproaching:
      case NotificationModel.typeAssignmentDeadlineToday:
      case NotificationModel.typeAssignmentOverdue:
        iconData = Icons.assignment;
        iconColor = const Color(0xFF2563EB);
        break;
      case NotificationModel.typeSubmissionReceived:
      case NotificationModel.typeSubmissionGraded:
        iconData = Icons.check_circle;
        iconColor = const Color(0xFF22C55E);
        break;
      case NotificationModel.typeGradeLow:
      case NotificationModel.typeGradeHigh:
        iconData = Icons.grade;
        iconColor = const Color(0xFFFACC15);
        break;
      case NotificationModel.typeLevelUp:
        iconData = Icons.emoji_events;
        iconColor = const Color(0xFF7C3AED);
        break;
      case NotificationModel.typeBadgeEarned:
        iconData = Icons.military_tech;
        iconColor = const Color(0xFFFB923C);
        break;
      case NotificationModel.typeStudentSubmitted:
      case NotificationModel.typeLateSubmission:
      case NotificationModel.typeAllSubmitted:
        iconData = Icons.upload_file;
        iconColor = const Color(0xFF2563EB);
        break;
      case NotificationModel.typeParentHomeworkNew:
      case NotificationModel.typeParentHomeworkMissed:
      case NotificationModel.typeParentGradeLow:
      case NotificationModel.typeParentImprovement:
        iconData = Icons.family_restroom;
        iconColor = const Color(0xFF7C3AED);
        break;
      default:
        iconData = Icons.notifications;
        iconColor = const Color(0xFF6B7280);
    }

    return Container(
      key: ValueKey(notification.id),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead ? Colors.grey[200]! : Colors.blue[200]!,
          width: notification.isRead ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          if (!notification.isRead) {
            await _notificationService.markAsRead(notification.id);
          }

          // Handle navigation based on actionType
          if (notification.actionType != null && mounted) {
            // Navigation logic can be added here based on actionType
            // For now, we'll just mark as read
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                iconData,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
                      fontSize: 14,
                      color: const Color(0xFF6B7280),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(notification.createdAt),
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'الآن';
        }
        return 'منذ ${difference.inMinutes} دقيقة';
      }
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
