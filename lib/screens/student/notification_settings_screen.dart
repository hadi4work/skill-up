import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/notification_preferences_model.dart';
import '../../models/notification_model.dart';
import '../../services/user_service.dart';
import '../../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();

  NotificationPreferences? _preferences;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    if (userId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final user = await _userService.getUserProfile(userId);
      if (user != null) {
        // Load preferences from user document
        // For now, use default preferences
        setState(() {
          _preferences = NotificationPreferences();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      setState(() {
        _preferences = NotificationPreferences();
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    if (_preferences == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    if (userId == null) return;

    try {
      await _userService.updateUserProfile(
        userId,
        {'notificationPreferences': _preferences!.toMap()},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ الإعدادات بنجاح', style: GoogleFonts.cairo()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ الإعدادات', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testNotification() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    if (userId == null) return;

    try {
      // Create a test notification
      await _notificationService.createTestNotification(
        userId: userId,
        title: '🔔 إشعار تجريبي',
        body: 'هذا إشعار تجريبي للتحقق من الإعدادات',
        type: NotificationModel.typeAssignmentNew,
        priority: 'default',
        actionType: 'test',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إرسال إشعار تجريبي', style: GoogleFonts.cairo()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending test notification: $e');
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

  @override
  Widget build(BuildContext context) {
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
          'إعدادات الإشعارات',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _preferences == null
              ? const Center(child: Text('حدث خطأ'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Master Switch
                      _buildMasterSwitch(),
                      const SizedBox(height: 16),

                      // Student Notifications Section
                      _buildSectionHeader('إشعارات الطالب'),
                      _buildNotificationToggle(
                        'واجبات جديدة',
                        _preferences!.assignmentNew,
                        (value) {
                          setState(() {
                            _preferences = _preferences!.copyWith(
                              assignmentNew: value,
                            );
                          });
                          _savePreferences();
                        },
                      ),
                      _buildNotificationToggle(
                        'اقتراب الموعد النهائي',
                        _preferences!.assignmentDeadlineApproaching,
                        (value) {
                          setState(() {
                            _preferences = _preferences!.copyWith(
                              assignmentDeadlineApproaching: value,
                            );
                          });
                          _savePreferences();
                        },
                      ),
                      _buildNotificationToggle(
                        'الموعد النهائي اليوم',
                        _preferences!.assignmentDeadlineToday,
                        (value) {
                          setState(() {
                            _preferences = _preferences!.copyWith(
                              assignmentDeadlineToday: value,
                            );
                          });
                          _savePreferences();
                        },
                      ),
                      _buildNotificationToggle(
                        'واجبات منتهية',
                        _preferences!.assignmentOverdue,
                        (value) {
                          setState(() {
                            _preferences = _preferences!.copyWith(
                              assignmentOverdue: value,
                            );
                          });
                          _savePreferences();
                        },
                      ),
                      _buildNotificationToggle(
                        'تأكيد التسليم',
                        _preferences!.submissionReceived,
                        (value) {
                          setState(() {
                            _preferences = _preferences!.copyWith(
                              submissionReceived: value,
                            );
                          });
                          _savePreferences();
                        },
                      ),
                      _buildNotificationToggle(
                        'نتائج التصحيح',
                        _preferences!.submissionGraded,
                        (value) {
                          setState(() {
                            _preferences = _preferences!.copyWith(
                              submissionGraded: value,
                            );
                          });
                          _savePreferences();
                        },
                      ),
                      _buildNotificationToggle(
                        'علامات منخفضة',
                        _preferences!.gradeLow,
                        (value) {
                          setState(() {
                            _preferences = _preferences!.copyWith(
                              gradeLow: value,
                            );
                          });
                          _savePreferences();
                        },
                      ),
                      _buildNotificationToggle(
                        'علامات عالية',
                        _preferences!.gradeHigh,
                        (value) {
                          setState(() {
                            _preferences = _preferences!.copyWith(
                              gradeHigh: value,
                            );
                          });
                          _savePreferences();
                        },
                      ),
                      _buildNotificationToggle(
                        'ارتفاع المستوى',
                        _preferences!.levelUp,
                        (value) {
                          setState(() {
                            _preferences = _preferences!.copyWith(
                              levelUp: value,
                            );
                          });
                          _savePreferences();
                        },
                      ),
                      _buildNotificationToggle(
                        'الإنجازات',
                        _preferences!.badgeEarned,
                        (value) {
                          setState(() {
                            _preferences = _preferences!.copyWith(
                              badgeEarned: value,
                            );
                          });
                          _savePreferences();
                        },
                      ),
                      _buildNotificationToggle(
                        'تذكير السلسلة',
                        _preferences!.streakReminder,
                        (value) {
                          setState(() {
                            _preferences = _preferences!.copyWith(
                              streakReminder: value,
                            );
                          });
                          _savePreferences();
                        },
                      ),

                      const SizedBox(height: 24),

                      // Test Notification Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _testNotification,
                            icon: const Icon(Icons.notifications_active),
                            label: Text(
                              'إرسال إشعار تجريبي',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMasterSwitch() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
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
          const Icon(Icons.notifications, color: Color(0xFF2563EB), size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تفعيل الإشعارات',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'إيقاف/تشغيل جميع الإشعارات',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _preferences?.enabled ?? true,
            onChanged: (value) {
              setState(() {
                _preferences = _preferences!.copyWith(enabled: value);
              });
              _savePreferences();
            },
            activeTrackColor: const Color(0xFF2563EB),
            activeThumbColor: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationToggle(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 16,
                color: const Color(0xFF111827),
              ),
            ),
          ),
          Switch(
            value: value && (_preferences?.enabled ?? true),
            onChanged: (_preferences?.enabled ?? true) ? onChanged : null,
            activeTrackColor: const Color(0xFF2563EB),
            activeThumbColor: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }
}
