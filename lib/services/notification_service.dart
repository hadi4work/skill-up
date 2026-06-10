import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../models/assignment_model.dart';
import '../models/exam_model.dart';
import 'class_service.dart';
import 'user_service.dart';
import 'push_dispatch_service.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'notifications';
  final ClassService _classService = ClassService();
  final UserService _userService = UserService();

  Future<void> _dispatchPushForNotification({
    required String notificationId,
    required NotificationModel notification,
  }) async {
    await PushDispatchService.instance.tryDispatchRemotePush(
      notificationId: notificationId,
      userId: notification.userId,
      title: notification.title,
      body: notification.body,
      type: notification.type,
      priority: notification.priority,
      actionType: notification.actionType,
      assignmentId: notification.assignmentId,
      metadata: notification.metadata,
    );
  }

  Future<void> createExamNotifications(ExamModel exam) async {
    try {
      List<String> studentIds = [];
      for (String classId in exam.classIds) {
        final classModel = await _classService.getClassById(classId);
        if (classModel == null) continue;
        for (String studentCode in classModel.studentCodes) {
          final student = await _userService.getUserByStudentCode(studentCode);
          if (student != null && !studentIds.contains(student.uid)) {
            studentIds.add(student.uid);
          }
        }
      }

      for (final studentId in studentIds) {
        final notification = NotificationModel(
          id: '',
          userId: studentId,
          title: '📝 لديك اختبار جديد: ${exam.subject}',
          body:
              '${exam.title} - الموعد: ${exam.startAt.day}/${exam.startAt.month}/${exam.startAt.year} ${exam.startAt.hour}:${exam.startAt.minute.toString().padLeft(2, '0')} - يرجى عدم التأخير',
          type: NotificationModel.typeExamNew,
          createdAt: DateTime.now(),
          priority: 'high',
          actionType: 'view_exam',
          metadata: {
            'examId': exam.id,
            'assessmentType': exam.assessmentType,
            'startAt': exam.startAt.toIso8601String(),
            'endAt': exam.endAt.toIso8601String(),
          },
        );
        final docRef = await _firestore.collection(_collection).add(notification.toMap());
        await docRef.update({'id': docRef.id});
        await _dispatchPushForNotification(
          notificationId: docRef.id,
          notification: notification,
        );
      }
    } catch (e) {
      debugPrint('Error creating exam notifications: $e');
    }
  }

  // Create notification for new assignment
  Future<void> createAssignmentNotifications(AssignmentModel assignment) async {
    try {
      debugPrint('🔔 Creating notifications for assignment: ${assignment.id}');
      debugPrint('📋 Assignment classIds: ${assignment.classIds}');

      // Get all students in the selected classes
      List<String> studentIds = [];

      for (String classId in assignment.classIds) {
        debugPrint('🔍 Getting class: $classId');
        final classModel = await _classService.getClassById(classId);
        if (classModel != null) {
          debugPrint(
            '✅ Found class: ${classModel.name} with ${classModel.studentCodes.length} students',
          );
          // Get student IDs from student codes
          for (String studentCode in classModel.studentCodes) {
            final student = await _userService.getUserByStudentCode(
              studentCode,
            );
            if (student != null && !studentIds.contains(student.uid)) {
              studentIds.add(student.uid);
              debugPrint('✅ Added student: ${student.name} (${student.uid})');
            } else if (student == null) {
              debugPrint('⚠️ Student not found for code: $studentCode');
            }
          }
        } else {
          debugPrint('❌ Class not found: $classId');
        }
      }

      debugPrint('📊 Total students to notify: ${studentIds.length}');

      // Create notification for each student
      for (String studentId in studentIds) {
        NotificationModel notification = NotificationModel(
          id: '',
          userId: studentId,
          title: '📘 لديك واجب جديد في مادة ${assignment.subject}',
          body: assignment.title,
          type: NotificationModel.typeAssignmentNew,
          assignmentId: assignment.id,
          createdAt: DateTime.now(),
          priority: 'default',
          actionType: 'view_assignment',
          metadata: {'subject': assignment.subject},
        );

        DocumentReference docRef = await _firestore
            .collection(_collection)
            .add(notification.toMap());
        await docRef.update({'id': docRef.id});
        debugPrint('✅ Created notification for student: $studentId');
        await _dispatchPushForNotification(
          notificationId: docRef.id,
          notification: notification,
        );
      }

      debugPrint(
        '✅ Created ${studentIds.length} notifications for assignment ${assignment.id}',
      );
    } catch (e) {
      debugPrint('❌ Error creating notifications: $e');
      throw 'حدث خطأ أثناء إنشاء الإشعارات: $e';
    }
  }

  // Get user notifications
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            final map = Map<String, dynamic>.from(data);
            // دائماً استخدم معرف المستند من Firestore لضمان الحذف والسحب يعمل لكل الأدوار.
            map['id'] = doc.id;
            return NotificationModel.fromMap(map);
          }).toList(),
        );
  }

  /// حذف إشعار من Firestore (مثلاً بعد سحب البطاقة).
  Future<void> deleteNotification(String notificationId) async {
    if (notificationId.isEmpty) return;
    try {
      await _firestore.collection(_collection).doc(notificationId).delete();
      debugPrint('✅ Deleted notification $notificationId');
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
      rethrow;
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection(_collection).doc(notificationId).update({
        'isRead': true,
        'readAt': DateTime.now()
            .toIso8601String(), // Store read timestamp for deletion
      });
      debugPrint('✅ Marked notification $notificationId as read');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  // Mark all unread notifications for a user as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final unreadSnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadSnapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      final nowIso = DateTime.now().toIso8601String();
      for (final doc in unreadSnapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': nowIso,
        });
      }
      await batch.commit();
      debugPrint('✅ Marked all notifications as read for user $userId');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  // Delete old read notifications (called periodically)
  Future<void> deleteOldReadNotifications() async {
    try {
      final fiveMinutesAgo = DateTime.now().subtract(
        const Duration(minutes: 5),
      );

      // Get all read notifications
      QuerySnapshot readNotifications = await _firestore
          .collection(_collection)
          .where('isRead', isEqualTo: true)
          .get();

      int deletedCount = 0;
      List<Future<void>> deleteTasks = [];

      for (var doc in readNotifications.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final readAt = data['readAt'];

        if (readAt != null) {
          final readAtTime = DateTime.parse(readAt);
          if (readAtTime.isBefore(fiveMinutesAgo)) {
            deleteTasks.add(doc.reference.delete());
            deletedCount++;
          }
        } else {
          // If readAt doesn't exist but isRead is true, check createdAt
          // This handles old notifications that were marked as read before we added readAt
          // Only delete if notification is older than 5 minutes (assumed to be read)
          final createdAt = data['createdAt'];
          if (createdAt != null) {
            final createdAtTime = DateTime.parse(createdAt);
            if (createdAtTime.isBefore(fiveMinutesAgo)) {
              deleteTasks.add(doc.reference.delete());
              deletedCount++;
            }
          }
        }
      }

      // Execute all deletions in parallel
      if (deleteTasks.isNotEmpty) {
        await Future.wait(deleteTasks);
        debugPrint('✅ Deleted $deletedCount old read notifications');
      }
    } catch (e) {
      debugPrint('❌ Error deleting old read notifications: $e');
    }
  }

  // Get unread count
  Future<int> getUnreadCount(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  // Stream for unread count
  Stream<int> getUnreadCountStream(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Send notification for incomplete assignment
  Future<void> sendIncompleteAssignmentNotification({
    required String studentId,
    required String assignmentId,
    required String assignmentTitle,
    required String assignmentSubject,
    String? studentName,
  }) async {
    try {
      String title;
      String body;

      if (studentName != null) {
        // Notification for parent
        title = 'تنبيه لولي الأمر - الطالب $studentName';
        body =
            'الطالب $studentName لم يسلم واجب $assignmentSubject: $assignmentTitle';
      } else {
        // Notification for student
        title = 'تنبيه: واجب غير مكتمل';
        body = 'لم تقم بتسليم واجب $assignmentSubject: $assignmentTitle';
      }

      NotificationModel notification = NotificationModel(
        id: '',
        userId: studentId,
        title: title,
        body: body,
        type: NotificationModel.typeIncompleteAssignment,
        assignmentId: assignmentId,
        createdAt: DateTime.now(),
        priority: 'high',
        actionType: 'view_assignment',
        metadata: studentName != null ? {'childName': studentName} : null,
      );

      DocumentReference docRef = await _firestore
          .collection(_collection)
          .add(notification.toMap());
      await docRef.update({'id': docRef.id});
      await _dispatchPushForNotification(
        notificationId: docRef.id,
        notification: notification,
      );

      debugPrint('✅ Sent incomplete assignment notification to $studentId');
    } catch (e) {
      debugPrint('Error sending incomplete assignment notification: $e');
      throw 'حدث خطأ أثناء إرسال التنبيه: $e';
    }
  }

  // Helper method to create and save notification (public for testing)
  Future<void> createTestNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? assignmentId,
    String priority = 'default',
    String? actionType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final NotificationModel notification = NotificationModel(
        id: '',
        userId: userId,
        title: title,
        body: body,
        type: type,
        assignmentId: assignmentId,
        createdAt: DateTime.now(),
        priority: priority,
        actionType: actionType,
        metadata: metadata,
      );

      final DocumentReference docRef = await _firestore
          .collection(_collection)
          .add(notification.toMap());
      await docRef.update({'id': docRef.id});
      await _dispatchPushForNotification(
        notificationId: docRef.id,
        notification: notification,
      );

      debugPrint('✅ Created notification: $type for user: $userId');
    } catch (e) {
      debugPrint('❌ Error creating notification: $e');
    }
  }

  // ========== STUDENT NOTIFICATIONS ==========

  // Deadline approaching (1 day before)
  Future<void> sendDeadlineApproachingNotification({
    required String studentId,
    required String assignmentId,
    required String assignmentTitle,
    required String assignmentSubject,
    required DateTime deadline,
  }) async {
    await createTestNotification(
      userId: studentId,
      title: '⏰ تبقّى يوم واحد لتسليم الواجب',
      body: '$assignmentSubject: $assignmentTitle',
      type: NotificationModel.typeAssignmentDeadlineApproaching,
      assignmentId: assignmentId,
      priority: 'high',
      actionType: 'view_assignment',
      metadata: {'deadline': deadline.toIso8601String()},
    );
  }

  // Deadline today
  Future<void> sendDeadlineTodayNotification({
    required String studentId,
    required String assignmentId,
    required String assignmentTitle,
    required String assignmentSubject,
  }) async {
    await createTestNotification(
      userId: studentId,
      title: '⚠️ اليوم آخر موعد لتسليم الواجب',
      body: '$assignmentSubject: $assignmentTitle',
      type: NotificationModel.typeAssignmentDeadlineToday,
      assignmentId: assignmentId,
      priority: 'high',
      actionType: 'view_assignment',
    );
  }

  // Overdue
  Future<void> sendOverdueNotification({
    required String studentId,
    required String assignmentId,
    required String assignmentTitle,
    required String assignmentSubject,
  }) async {
    await createTestNotification(
      userId: studentId,
      title: '❗ لم يتم تسليم الواجب في الوقت المحدد',
      body: '$assignmentSubject: $assignmentTitle',
      type: NotificationModel.typeAssignmentOverdue,
      assignmentId: assignmentId,
      priority: 'high',
      actionType: 'view_assignment',
    );
  }

  // Submission received
  Future<void> sendSubmissionReceivedNotification({
    required String studentId,
    required String assignmentId,
    required String assignmentTitle,
  }) async {
    await createTestNotification(
      userId: studentId,
      title: '✅ تم استلام واجبك بنجاح',
      body: assignmentTitle,
      type: NotificationModel.typeSubmissionReceived,
      assignmentId: assignmentId,
      priority: 'default',
      actionType: 'view_assignment',
    );
  }

  // Submission graded
  Future<void> sendSubmissionGradedNotification({
    required String studentId,
    required String assignmentId,
    required String assignmentTitle,
    required int grade,
    required int totalPoints,
  }) async {
    await createTestNotification(
      userId: studentId,
      title: '📊 تم تصحيح واجبك',
      body: '$assignmentTitle - العلامة: $grade/$totalPoints',
      type: NotificationModel.typeSubmissionGraded,
      assignmentId: assignmentId,
      priority: 'default',
      actionType: 'view_assignment',
      metadata: {'grade': grade, 'totalPoints': totalPoints},
    );

    // Send low/high score notification
    final percentage = (grade / totalPoints) * 100;
    if (percentage < 60) {
      await sendLowScoreNotification(
        studentId: studentId,
        assignmentId: assignmentId,
        assignmentTitle: assignmentTitle,
        grade: grade,
        totalPoints: totalPoints,
      );
    } else if (percentage >= 90) {
      await sendHighScoreNotification(
        studentId: studentId,
        assignmentId: assignmentId,
        assignmentTitle: assignmentTitle,
        grade: grade,
        totalPoints: totalPoints,
      );
    }
  }

  // Low score
  Future<void> sendLowScoreNotification({
    required String studentId,
    required String assignmentId,
    required String assignmentTitle,
    required int grade,
    required int totalPoints,
  }) async {
    await createTestNotification(
      userId: studentId,
      title: '🔍 تحتاج إلى تحسين بعض النقاط',
      body: '$assignmentTitle - العلامة: $grade/$totalPoints',
      type: NotificationModel.typeGradeLow,
      assignmentId: assignmentId,
      priority: 'default',
      actionType: 'view_assignment',
      metadata: {'grade': grade, 'totalPoints': totalPoints},
    );
  }

  // High score
  Future<void> sendHighScoreNotification({
    required String studentId,
    required String assignmentId,
    required String assignmentTitle,
    required int grade,
    required int totalPoints,
  }) async {
    await createTestNotification(
      userId: studentId,
      title: '🌟 أداء رائع! استمر',
      body: '$assignmentTitle - العلامة: $grade/$totalPoints',
      type: NotificationModel.typeGradeHigh,
      assignmentId: assignmentId,
      priority: 'default',
      actionType: 'view_assignment',
      metadata: {'grade': grade, 'totalPoints': totalPoints},
    );
  }

  // Level up
  Future<void> sendLevelUpNotification({
    required String studentId,
    required int newLevel,
  }) async {
    await createTestNotification(
      userId: studentId,
      title: '🚀 وصلت إلى المستوى $newLevel',
      body: 'تهانينا! استمر في التقدم',
      type: NotificationModel.typeLevelUp,
      priority: 'high',
      actionType: 'view_profile',
      metadata: {'level': newLevel},
    );
  }

  // Badge earned (future feature)
  Future<void> sendBadgeEarnedNotification({
    required String studentId,
    required String badgeName,
  }) async {
    await createTestNotification(
      userId: studentId,
      title: '🏆 حصلت على إنجاز جديد',
      body: badgeName,
      type: NotificationModel.typeBadgeEarned,
      priority: 'default',
      actionType: 'view_profile',
      metadata: {'badgeName': badgeName},
    );
  }

  // Streak reminder
  Future<void> sendStreakReminderNotification({
    required String studentId,
    required int streakDays,
  }) async {
    await createTestNotification(
      userId: studentId,
      title: '🔥 لا تقطع سلسلة التعلّم اليوم',
      body: 'لديك $streakDays أيام متتالية',
      type: NotificationModel.typeStreakReminder,
      priority: 'low',
      actionType: 'view_home',
      metadata: {'streakDays': streakDays},
    );
  }

  // ========== TEACHER NOTIFICATIONS ==========

  // Student submitted
  Future<void> sendStudentSubmittedNotification({
    required String teacherId,
    required String studentName,
    required String assignmentId,
    required String assignmentTitle,
    required bool isLate,
  }) async {
    final title = isLate
        ? '⏰ طالب سلّم الواجب متأخرًا'
        : '📥 طالب جديد سلّم الواجب';
    final type = isLate
        ? NotificationModel.typeLateSubmission
        : NotificationModel.typeStudentSubmitted;

    await createTestNotification(
      userId: teacherId,
      title: title,
      body: '$studentName - $assignmentTitle',
      type: type,
      assignmentId: assignmentId,
      priority: 'default',
      actionType: 'view_submissions',
      metadata: {'studentName': studentName, 'isLate': isLate},
    );
  }

  // All students submitted
  Future<void> sendAllSubmittedNotification({
    required String teacherId,
    required String assignmentId,
    required String assignmentTitle,
    required int totalStudents,
  }) async {
    await createTestNotification(
      userId: teacherId,
      title: '✅ جميع الطلاب سلّموا الواجب',
      body: '$assignmentTitle - $totalStudents طالب',
      type: NotificationModel.typeAllSubmitted,
      assignmentId: assignmentId,
      priority: 'default',
      actionType: 'view_submissions',
      metadata: {'totalStudents': totalStudents},
    );
  }

  // ========== PARENT NOTIFICATIONS ==========

  // New homework for child
  Future<void> sendParentHomeworkNewNotification({
    required String parentId,
    required String childName,
    required String assignmentId,
    required String assignmentTitle,
    required String assignmentSubject,
  }) async {
    await createTestNotification(
      userId: parentId,
      title: '📘 واجب جديد للطالب $childName',
      body: 'المادة: $assignmentSubject - الواجب: $assignmentTitle',
      type: NotificationModel.typeParentHomeworkNew,
      assignmentId: assignmentId,
      priority: 'default',
      actionType: 'view_assignment',
      metadata: {'childName': childName, 'subject': assignmentSubject},
    );
  }

  // Child missed homework
  Future<void> sendParentHomeworkMissedNotification({
    required String parentId,
    required String childName,
    required String assignmentId,
    required String assignmentTitle,
    required String assignmentSubject,
  }) async {
    await createTestNotification(
      userId: parentId,
      title: '❗ تنبيه: $childName لم يسلم واجباً',
      body: 'المادة: $assignmentSubject - الواجب: $assignmentTitle',
      type: NotificationModel.typeParentHomeworkMissed,
      assignmentId: assignmentId,
      priority: 'high',
      actionType: 'view_assignment',
      metadata: {'childName': childName, 'subject': assignmentSubject},
    );
  }

  // Child low score
  Future<void> sendParentGradeLowNotification({
    required String parentId,
    required String childName,
    required String assignmentId,
    required String assignmentTitle,
    required int grade,
    required int totalPoints,
  }) async {
    await createTestNotification(
      userId: parentId,
      title: '📉 تنبيه أداء للطالب $childName',
      body: '$assignmentTitle - الدرجة: $grade/$totalPoints',
      type: NotificationModel.typeParentGradeLow,
      assignmentId: assignmentId,
      priority: 'default',
      actionType: 'view_assignment',
      metadata: {
        'childName': childName,
        'grade': grade,
        'totalPoints': totalPoints,
      },
    );
  }

  // Child improvement
  Future<void> sendParentImprovementNotification({
    required String parentId,
    required String childName,
    required String assignmentId,
    required String assignmentTitle,
    required int grade,
    required int totalPoints,
  }) async {
    await createTestNotification(
      userId: parentId,
      title: '🌱 تحسّن واضح للطالب $childName',
      body: '$assignmentTitle - الدرجة: $grade/$totalPoints',
      type: NotificationModel.typeParentImprovement,
      assignmentId: assignmentId,
      priority: 'default',
      actionType: 'view_assignment',
      metadata: {
        'childName': childName,
        'grade': grade,
        'totalPoints': totalPoints,
      },
    );
  }
}
