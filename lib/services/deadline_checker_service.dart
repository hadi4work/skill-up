import 'package:flutter/foundation.dart';
import 'assignment_service.dart';
import 'notification_service.dart';
import 'user_service.dart';
import 'class_service.dart';

class DeadlineCheckerService {
  final AssignmentService _assignmentService = AssignmentService();
  final NotificationService _notificationService = NotificationService();
  final UserService _userService = UserService();
  final ClassService _classService = ClassService();

  // Check deadlines for all students and send notifications
  // Note: This is a simplified version. In production, use Cloud Functions
  Future<void> checkDeadlines() async {
    try {
      debugPrint('🔍 Checking assignment deadlines...');
      // This method is a placeholder for future Cloud Functions implementation
      // For now, deadlines are checked per student when they log in
      debugPrint('✅ Deadline check completed');
    } catch (e) {
      debugPrint('❌ Error checking deadlines: $e');
    }
  }

  // Check deadlines for a specific student
  Future<void> checkStudentDeadlines(String studentId) async {
    try {
      debugPrint('🔍 Checking deadlines for student: $studentId');

      final user = await _userService.getUserProfile(studentId);
      if (user == null || user.classIds == null || user.classIds!.isEmpty) {
        debugPrint('⚠️ Student has no classes');
        return;
      }

      final assignments = await _assignmentService.getStudentAssignments(
        user.classIds!,
      );

      final now = DateTime.now();

      for (var assignment in assignments) {
        final daysUntilDeadline = assignment.deadline.difference(now).inDays;
        final hoursUntilDeadline = assignment.deadline.difference(now).inHours;

        // Check if deadline is approaching (1 day before)
        if (daysUntilDeadline == 1 && hoursUntilDeadline <= 24) {
          // Check if notification was already sent (in production, track this)
          await _notificationService.sendDeadlineApproachingNotification(
            studentId: studentId,
            assignmentId: assignment.id,
            assignmentTitle: assignment.title,
            assignmentSubject: assignment.subject,
            deadline: assignment.deadline,
          );
        }

        // Check if deadline is today
        if (daysUntilDeadline == 0 && hoursUntilDeadline > 0) {
          await _notificationService.sendDeadlineTodayNotification(
            studentId: studentId,
            assignmentId: assignment.id,
            assignmentTitle: assignment.title,
            assignmentSubject: assignment.subject,
          );
        }

        // Check if overdue
        if (assignment.deadline.isBefore(now)) {
          // Check if student has submitted
          final submission = await _assignmentService.getStudentSubmission(
            assignment.id,
            studentId,
          );

          if (submission == null) {
            // Student hasn't submitted - send overdue notification
            await _notificationService.sendOverdueNotification(
              studentId: studentId,
              assignmentId: assignment.id,
              assignmentTitle: assignment.title,
              assignmentSubject: assignment.subject,
            );
          }
        }
      }

      debugPrint('✅ Deadline check completed for student: $studentId');
    } catch (e) {
      debugPrint('❌ Error checking student deadlines: $e');
    }
  }

  // Check deadlines for all students in a class
  Future<void> checkClassDeadlines(String classId) async {
    try {
      debugPrint('🔍 Checking deadlines for class: $classId');

      final classModel = await _classService.getClassById(classId);
      if (classModel == null) {
        debugPrint('⚠️ Class not found');
        return;
      }

      for (String studentCode in classModel.studentCodes) {
        final student = await _userService.getUserByStudentCode(studentCode);
        if (student != null) {
          await checkStudentDeadlines(student.uid);
        }
      }

      debugPrint('✅ Deadline check completed for class: $classId');
    } catch (e) {
      debugPrint('❌ Error checking class deadlines: $e');
    }
  }
}
