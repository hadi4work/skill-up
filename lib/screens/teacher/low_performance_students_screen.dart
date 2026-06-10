import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/assignment_model.dart';
import '../../models/submission_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/assignment_service.dart';
import '../../services/notification_service.dart';
import '../../services/user_service.dart';

class LowPerformanceStudentsScreen extends StatefulWidget {
  const LowPerformanceStudentsScreen({super.key});

  @override
  State<LowPerformanceStudentsScreen> createState() => _LowPerformanceStudentsScreenState();
}

class _LowPerformanceStudentsScreenState extends State<LowPerformanceStudentsScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();

  bool _loading = true;
  List<_LowStudentRow> _rows = [];
  final Set<String> _sending = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final teacherId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (teacherId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final assignments = await _assignmentService.getTeacherAssignments(teacherId);
      final Map<String, List<double>> studentPercents = {};
      final Map<String, UserModel?> users = {};

      for (final AssignmentModel assignment in assignments) {
        final subs = await _assignmentService.getAssignmentSubmissions(assignment.id);
        for (final SubmissionModel s in subs) {
          if (!s.isGraded || s.grade == null || assignment.totalPoints <= 0) continue;
          final p = (s.grade! / assignment.totalPoints) * 100;
          studentPercents.putIfAbsent(s.studentId, () => []).add(p);
        }
      }

      final rows = <_LowStudentRow>[];
      for (final entry in studentPercents.entries) {
        final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
        if (avg >= 60) continue;
        users[entry.key] ??= await _userService.getUserProfile(entry.key);
        final user = users[entry.key];
        if (user == null) continue;
        rows.add(
          _LowStudentRow(
            studentId: user.uid,
            studentName: user.name,
            parentId: user.parentId,
            avgPercent: avg,
          ),
        );
      }
      rows.sort((a, b) => a.avgPercent.compareTo(b.avgPercent));
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _sendAlert(_LowStudentRow row) async {
    setState(() => _sending.add(row.studentId));
    try {
      await _notificationService.createTestNotification(
        userId: row.studentId,
        title: '📉 تنبيه: الأداء الحالي يحتاج دعم',
        body: 'متوسطك الحالي منخفض. راجع الأخطاء وحاول حل تمارين إضافية.',
        type: 'teacher_low_performance_alert',
        priority: 'high',
        actionType: 'view_analytics',
      );
      if ((row.parentId ?? '').isNotEmpty) {
        await _notificationService.createTestNotification(
          userId: row.parentId!,
          title: '📉 تنبيه أداء: ${row.studentName}',
          body: 'الطالب ${row.studentName} يحتاج دعماً إضافياً في الدراسة حالياً. الرجاء المتابعة.',
          type: 'parent_low_performance_alert',
          priority: 'high',
          actionType: 'view_child_analytics',
          metadata: {'childName': row.studentName},
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (row.parentId ?? '').isNotEmpty
                ? 'تم إرسال التنبيه للطالب وولي الأمر'
                : 'تم إرسال التنبيه للطالب',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إرسال التنبيه: $e', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending.remove(row.studentId));
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
        title: Text('طلاب بحاجة متابعة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? Center(
                  child: Text(
                    'لا يوجد حالياً طلاب بأداء منخفض',
                    style: GoogleFonts.cairo(fontSize: 16, color: const Color(0xFF6B7280)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rows.length,
                    itemBuilder: (_, i) {
                      final row = _rows[i];
                      final sending = _sending.contains(row.studentId);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFFFB923C).withValues(alpha: 0.15),
                              child: Text(
                                row.studentName.isNotEmpty ? row.studentName[0] : 'ط',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row.studentName,
                                    style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'المتوسط: ${row.avgPercent.toStringAsFixed(0)}%',
                                    style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF6B7280)),
                                  ),
                                  Text(
                                    (row.parentId ?? '').isNotEmpty ? 'ولي الأمر مرتبط' : 'لا يوجد ولي أمر مرتبط',
                                    style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: sending ? null : () => _sendAlert(row),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFB923C),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: sending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text('إرسال تنبيه', style: GoogleFonts.cairo(fontSize: 12)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _LowStudentRow {
  final String studentId;
  final String studentName;
  final String? parentId;
  final double avgPercent;

  _LowStudentRow({
    required this.studentId,
    required this.studentName,
    required this.parentId,
    required this.avgPercent,
  });
}
