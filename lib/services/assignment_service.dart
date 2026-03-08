import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/assignment_model.dart';
import '../models/submission_model.dart';
import 'notification_service.dart';
import 'class_service.dart';
import 'user_service.dart';

class AssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _assignmentsCollection = 'assignments';
  final String _submissionsCollection = 'submissions';
  final NotificationService _notificationService = NotificationService();
  final ClassService _classService = ClassService();
  final UserService _userService = UserService();

  // Create a new assignment
  Future<String> createAssignment(AssignmentModel assignment) async {
    try {
      DocumentReference docRef = await _firestore
          .collection(_assignmentsCollection)
          .add(assignment.toMap());
      // Update the assignment with its ID
      await docRef.update({'id': docRef.id});

      // Create notifications for students
      AssignmentModel assignmentWithId = assignment.copyWith(id: docRef.id);
      try {
        await _notificationService.createAssignmentNotifications(
          assignmentWithId,
        );
      } catch (e) {
        debugPrint('Error creating notifications: $e');
        // Don't throw error, just log it - assignment was created successfully
      }

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating assignment: $e');
      throw 'حدث خطأ أثناء إنشاء الواجب: $e';
    }
  }

  // Get all assignments for a teacher
  Future<List<AssignmentModel>> getTeacherAssignments(String teacherId) async {
    try {
      try {
        QuerySnapshot querySnapshot = await _firestore
            .collection(_assignmentsCollection)
            .where('teacherId', isEqualTo: teacherId)
            .orderBy('createdAt', descending: true)
            .get();

        List<AssignmentModel> assignments = querySnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Ensure ID is set
          return AssignmentModel.fromMap(data);
        }).toList();
        debugPrint(
          '✅ Found ${assignments.length} assignments for teacher $teacherId',
        );
        return assignments;
      } catch (e) {
        debugPrint('⚠️ OrderBy failed, trying without orderBy: $e');
        QuerySnapshot querySnapshot = await _firestore
            .collection(_assignmentsCollection)
            .where('teacherId', isEqualTo: teacherId)
            .get();

        List<AssignmentModel> assignments = querySnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Ensure ID is set
          return AssignmentModel.fromMap(data);
        }).toList();
        assignments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        debugPrint(
          '✅ Found ${assignments.length} assignments for teacher $teacherId (without orderBy)',
        );
        return assignments;
      }
    } catch (e) {
      debugPrint('❌ Error getting teacher assignments: $e');
      throw 'حدث خطأ أثناء جلب الواجبات: $e';
    }
  }

  // Get assignments for a student (based on their classes)
  Future<List<AssignmentModel>> getStudentAssignments(
    List<String> classIds,
  ) async {
    try {
      if (classIds.isEmpty) {
        debugPrint('⚠️ Student has no classIds');
        return [];
      }
      debugPrint('📚 Getting assignments for classes: $classIds');

      try {
        QuerySnapshot querySnapshot = await _firestore
            .collection(_assignmentsCollection)
            .where('classIds', arrayContainsAny: classIds)
            .orderBy('deadline', descending: false)
            .get();

        List<AssignmentModel> assignments = querySnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Ensure ID is set
          return AssignmentModel.fromMap(data);
        }).toList();
        debugPrint('✅ Found ${assignments.length} assignments for student');
        return assignments;
      } catch (e) {
        debugPrint('⚠️ OrderBy failed, trying without orderBy: $e');
        QuerySnapshot querySnapshot = await _firestore
            .collection(_assignmentsCollection)
            .where('classIds', arrayContainsAny: classIds)
            .get();

        List<AssignmentModel> assignments = querySnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Ensure ID is set
          return AssignmentModel.fromMap(data);
        }).toList();
        assignments.sort((a, b) => a.deadline.compareTo(b.deadline));
        debugPrint(
          '✅ Found ${assignments.length} assignments for student (without orderBy)',
        );
        return assignments;
      }
    } catch (e) {
      debugPrint('❌ Error getting student assignments: $e');
      throw 'حدث خطأ أثناء جلب الواجبات: $e';
    }
  }

  // Get assignment by ID
  Future<AssignmentModel?> getAssignmentById(String assignmentId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_assignmentsCollection)
          .doc(assignmentId)
          .get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Ensure ID is set
        return AssignmentModel.fromMap(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting assignment: $e');
      throw 'حدث خطأ أثناء جلب الواجب: $e';
    }
  }

  // Update assignment
  Future<void> updateAssignment(
    String assignmentId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection(_assignmentsCollection)
          .doc(assignmentId)
          .update(data);
    } catch (e) {
      debugPrint('Error updating assignment: $e');
      throw 'حدث خطأ أثناء تحديث الواجب: $e';
    }
  }

  // Submit assignment (student)
  // Note: This should only be called for new submissions
  // For updates, use updateSubmission instead
  Future<String> submitAssignment(SubmissionModel submission) async {
    try {
      // Check if submission already exists
      final existingSubmission = await getStudentSubmission(
        submission.assignmentId,
        submission.studentId,
      );

      if (existingSubmission != null) {
        throw 'تم إرسال الحل مسبقاً. يمكنك تحديثه فقط.';
      }

      DocumentReference docRef = await _firestore
          .collection(_submissionsCollection)
          .add(submission.toMap());
      await docRef.update({'id': docRef.id});

      // Get assignment details
      final assignment = await getAssignmentById(submission.assignmentId);
      if (assignment != null) {
        // Send notification to student
        await _notificationService.sendSubmissionReceivedNotification(
          studentId: submission.studentId,
          assignmentId: submission.assignmentId,
          assignmentTitle: assignment.title,
        );

        // Send notification to teacher
        final isLate = submission.submittedAt.isAfter(assignment.deadline);
        final student = await _userService.getUserProfile(submission.studentId);
        if (student != null) {
          await _notificationService.sendStudentSubmittedNotification(
            teacherId: assignment.teacherId,
            studentName: student.name,
            assignmentId: submission.assignmentId,
            assignmentTitle: assignment.title,
            isLate: isLate,
          );
        }

        // Check if all students submitted
        final allSubmissions = await getAssignmentSubmissions(
          submission.assignmentId,
        );
        final totalStudents = await _getTotalStudentsCount(assignment.classIds);
        if (allSubmissions.length >= totalStudents) {
          await _notificationService.sendAllSubmittedNotification(
            teacherId: assignment.teacherId,
            assignmentId: submission.assignmentId,
            assignmentTitle: assignment.title,
            totalStudents: totalStudents,
          );
        }
      }

      return docRef.id;
    } catch (e) {
      debugPrint('Error submitting assignment: $e');
      throw 'حدث خطأ أثناء إرسال الواجب: $e';
    }
  }

  // Helper method to get total students count in classes
  Future<int> _getTotalStudentsCount(List<String> classIds) async {
    int total = 0;
    for (String classId in classIds) {
      final classModel = await _classService.getClassById(classId);
      if (classModel != null) {
        total += classModel.studentCodes.length;
      }
    }
    return total;
  }

  // Update submission
  Future<void> updateSubmission(
    String submissionId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection(_submissionsCollection)
          .doc(submissionId)
          .update(data);
    } catch (e) {
      debugPrint('Error updating submission: $e');
      throw 'حدث خطأ أثناء تحديث الحل: $e';
    }
  }

  // Get submissions for an assignment
  Future<List<SubmissionModel>> getAssignmentSubmissions(
    String assignmentId,
  ) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_submissionsCollection)
          .where('assignmentId', isEqualTo: assignmentId)
          .orderBy('submittedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map(
            (doc) =>
                SubmissionModel.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting submissions: $e');
      throw 'حدث خطأ أثناء جلب الحلول: $e';
    }
  }

  // Get student's submission for an assignment
  Future<SubmissionModel?> getStudentSubmission(
    String assignmentId,
    String studentId,
  ) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_submissionsCollection)
          .where('assignmentId', isEqualTo: assignmentId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return SubmissionModel.fromMap(
          querySnapshot.docs.first.data() as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error getting student submission: $e');
      throw 'حدث خطأ أثناء جلب الحل: $e';
    }
  }

  // Grade submission
  Future<void> gradeSubmission(
    String submissionId,
    int grade,
    int totalPoints,
  ) async {
    try {
      // Get submission details
      final submissionDoc = await _firestore
          .collection(_submissionsCollection)
          .doc(submissionId)
          .get();

      if (!submissionDoc.exists) {
        throw 'الحل غير موجود';
      }

      final submissionData = submissionDoc.data()!;
      final String studentId = submissionData['studentId'] as String;
      final String assignmentId = submissionData['assignmentId'] as String;

      // Get assignment details
      final assignment = await getAssignmentById(assignmentId);
      if (assignment == null) {
        throw 'الواجب غير موجود';
      }

      // Calculate XP: 5 for submission + grade points
      int xpEarned = 5 + grade;

      await _firestore
          .collection(_submissionsCollection)
          .doc(submissionId)
          .update({
            'grade': grade,
            'gradedAt': DateTime.now().toIso8601String(),
            'isGraded': true,
            'xpEarned': xpEarned,
          });

      // Send notification to student
      await _notificationService.sendSubmissionGradedNotification(
        studentId: studentId,
        assignmentId: assignmentId,
        assignmentTitle: assignment.title,
        grade: grade,
        totalPoints: totalPoints,
      );

      // Send notification to parent if linked
      final student = await _userService.getUserProfile(studentId);
      if (student != null && student.parentId != null) {
        final percentage = (grade / totalPoints) * 100;
        if (percentage < 60) {
          await _notificationService.sendParentGradeLowNotification(
            parentId: student.parentId!,
            childName: student.name,
            assignmentId: assignmentId,
            assignmentTitle: assignment.title,
            grade: grade,
            totalPoints: totalPoints,
          );
        } else if (percentage >= 90) {
          await _notificationService.sendParentImprovementNotification(
            parentId: student.parentId!,
            childName: student.name,
            assignmentId: assignmentId,
            assignmentTitle: assignment.title,
            grade: grade,
            totalPoints: totalPoints,
          );
        }
      }
    } catch (e) {
      debugPrint('Error grading submission: $e');
      throw 'حدث خطأ أثناء تصحيح الواجب: $e';
    }
  }

  // Get all submissions by a student (for analytics)
  Future<List<SubmissionModel>> getSubmissionsByStudentId(String studentId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_submissionsCollection)
          .where('studentId', isEqualTo: studentId)
          .get();

      final list = querySnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final map = Map<String, dynamic>.from(data);
            map['id'] = doc.id;
            return SubmissionModel.fromMap(map);
          })
          .toList();
      list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return list;
    } catch (e) {
      debugPrint('Error getting submissions by student: $e');
      return [];
    }
  }

  // Get submission count for an assignment
  Future<int> getSubmissionCount(String assignmentId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_submissionsCollection)
          .where('assignmentId', isEqualTo: assignmentId)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting submission count: $e');
      return 0;
    }
  }

  // Delete assignment
  Future<void> deleteAssignment(String assignmentId) async {
    try {
      await _firestore
          .collection(_assignmentsCollection)
          .doc(assignmentId)
          .delete();
      debugPrint('✅ Assignment $assignmentId deleted successfully');
    } catch (e) {
      debugPrint('Error deleting assignment: $e');
      throw 'حدث خطأ أثناء حذف الواجب: $e';
    }
  }
}
