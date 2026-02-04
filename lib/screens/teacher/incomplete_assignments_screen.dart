import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/assignment_service.dart';
import '../../services/class_service.dart';
import '../../services/user_service.dart';
import '../../services/notification_service.dart';
import '../../models/assignment_model.dart';

class IncompleteAssignmentsScreen extends StatefulWidget {
  const IncompleteAssignmentsScreen({super.key});

  @override
  State<IncompleteAssignmentsScreen> createState() =>
      _IncompleteAssignmentsScreenState();
}

class _IncompleteAssignmentsScreenState
    extends State<IncompleteAssignmentsScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final ClassService _classService = ClassService();
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();
  
  List<AssignmentModel> _assignments = [];
  Map<String, List<StudentInfo>> _incompleteStudents = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIncompleteAssignments();
  }

  Future<void> _loadIncompleteAssignments() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final teacherId = authProvider.user?.uid;

    if (teacherId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Get all teacher assignments
      final assignments = await _assignmentService.getTeacherAssignments(teacherId);
      
      Map<String, List<StudentInfo>> incompleteMap = {};

      for (var assignment in assignments) {
        // Get all students in classes
        Set<String> allStudentCodes = {};
        for (String classId in assignment.classIds) {
          final classModel = await _classService.getClassById(classId);
          if (classModel != null) {
            allStudentCodes.addAll(classModel.studentCodes);
          }
        }

        // Get students who submitted
        final submissions = await _assignmentService.getAssignmentSubmissions(assignment.id);
        Set<String> submittedStudentIds = submissions.map((s) => s.studentId).toSet();

        // Find students who didn't submit
        List<StudentInfo> incomplete = [];
        for (String studentCode in allStudentCodes) {
          final student = await _userService.getUserByStudentCode(studentCode);
          if (student != null && !submittedStudentIds.contains(student.uid)) {
            incomplete.add(StudentInfo(
              uid: student.uid,
              name: student.name,
              studentCode: studentCode,
              parentId: student.parentId,
            ));
          }
        }

        if (incomplete.isNotEmpty) {
          incompleteMap[assignment.id] = incomplete;
        }
      }

      if (mounted) {
        setState(() {
          _assignments = assignments;
          _incompleteStudents = incompleteMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading incomplete assignments: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendNotificationToStudent(
    String assignmentId,
    StudentInfo student,
  ) async {
    try {
      final assignment = _assignments.firstWhere((a) => a.id == assignmentId);
      
      // Send notification to student
      await _notificationService.sendIncompleteAssignmentNotification(
        studentId: student.uid,
        assignmentId: assignmentId,
        assignmentTitle: assignment.title,
        assignmentSubject: assignment.subject,
      );

      // Send notification to parent if exists
      if (student.parentId != null && student.parentId!.isNotEmpty) {
        await _notificationService.sendIncompleteAssignmentNotification(
          studentId: student.parentId!,
          assignmentId: assignmentId,
          assignmentTitle: assignment.title,
          assignmentSubject: assignment.subject,
          studentName: student.name,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              student.parentId != null && student.parentId!.isNotEmpty
                  ? 'تم إرسال التنبيه للطالب وولي الأمر'
                  : 'تم إرسال التنبيه للطالب',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
          ),
        );
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
          'الواجبات غير المكتملة',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _incompleteStudents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green[400]),
                      const SizedBox(height: 16),
                      Text(
                        'جميع الواجبات مكتملة',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadIncompleteAssignments,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _incompleteStudents.length,
                    itemBuilder: (context, index) {
                      final assignmentId = _incompleteStudents.keys.elementAt(index);
                      final assignment = _assignments.firstWhere(
                        (a) => a.id == assignmentId,
                        orElse: () => _assignments.first,
                      );
                      final students = _incompleteStudents[assignmentId]!;

                      return _buildAssignmentCard(assignment, students);
                    },
                  ),
                ),
    );
  }

  Widget _buildAssignmentCard(AssignmentModel assignment, List<StudentInfo> students) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'الطلاب الذين لم يسلموا الواجب (${students.length})',
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          ...students.map((student) => _buildStudentItem(assignment.id, student)),
        ],
      ),
    );
  }

  Widget _buildStudentItem(String assignmentId, StudentInfo student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF2563EB),
            child: Text(
              student.name.isNotEmpty ? student.name[0] : 'ط',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'كود: ${student.studentCode}',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _sendNotificationToStudent(assignmentId, student),
            icon: const Icon(Icons.send, size: 16),
            label: Text(
              'إرسال تنبيه',
              style: GoogleFonts.cairo(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StudentInfo {
  final String uid;
  final String name;
  final String studentCode;
  final String? parentId;

  StudentInfo({
    required this.uid,
    required this.name,
    required this.studentCode,
    this.parentId,
  });
}
