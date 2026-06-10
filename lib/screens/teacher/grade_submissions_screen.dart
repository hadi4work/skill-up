import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/assignment_service.dart';
import '../../services/user_service.dart';
import '../../models/assignment_model.dart';
import '../../models/submission_model.dart';
import '../image_viewer_screen.dart';

class GradeSubmissionsScreen extends StatefulWidget {
  final AssignmentModel assignment;

  const GradeSubmissionsScreen({
    super.key,
    required this.assignment,
  });

  @override
  State<GradeSubmissionsScreen> createState() => _GradeSubmissionsScreenState();
}

class _GradeSubmissionsScreenState extends State<GradeSubmissionsScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final UserService _userService = UserService();
  List<SubmissionModel> _submissions = [];
  final Map<String, String> _studentNameById = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final submissions = await _assignmentService.getAssignmentSubmissions(widget.assignment.id);
      final ids = submissions.map((s) => s.studentId).toSet();
      final names = <String, String>{..._studentNameById};
      for (final id in ids) {
        if (names.containsKey(id)) continue;
        try {
          final u = await _userService.getUserProfile(id);
          names[id] = (u?.name ?? '').trim().isNotEmpty ? u!.name : 'طالب';
        } catch (_) {
          names[id] = 'طالب';
        }
      }
      if (mounted) {
        setState(() {
          _submissions = submissions;
          _studentNameById
            ..clear()
            ..addAll(names);
          _isLoading = false;
        });
      }
    } catch (e) {
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

  String _displayStudentName(SubmissionModel submission) {
    return _studentNameById[submission.studentId] ?? 'طالب';
  }

  Future<void> _gradeSubmission(SubmissionModel submission) async {
    final TextEditingController gradeController = TextEditingController();
    final studentLabel = _displayStudentName(submission);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تصحيح الواجب', style: GoogleFonts.cairo()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'الطالب: $studentLabel',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: gradeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'العلامة (من ${widget.assignment.totalPoints})',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: GoogleFonts.cairo(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          TextButton(
            onPressed: () {
              if (gradeController.text.isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: Text('حفظ', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );

    if (confirmed == true && gradeController.text.isNotEmpty) {
      try {
        int grade = int.parse(gradeController.text);
        if (grade < 0 || grade > widget.assignment.totalPoints) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'العلامة يجب أن تكون بين 0 و ${widget.assignment.totalPoints}',
                  style: GoogleFonts.cairo(),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Grade submission
        await _assignmentService.gradeSubmission(
          submission.id,
          grade,
          widget.assignment.totalPoints,
        );

        // Add XP to student
        await _userService.addXP(submission.studentId, 5 + grade);
        
        // Note: Student's AuthProvider will update automatically when they refresh
        // The XP and level are saved in Firestore, so the student will see the update
        // when they navigate back to home screen or refresh

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تصحيح الواجب بنجاح', style: GoogleFonts.cairo()),
              backgroundColor: Colors.green,
            ),
          );
          _loadSubmissions();
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
          'تصحيح الواجبات',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _submissions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد حلول مرفوعة',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _submissions.length,
                  itemBuilder: (context, index) {
                    return _buildSubmissionCard(_submissions[index]);
                  },
                ),
    );
  }

  Widget _buildSubmissionCard(SubmissionModel submission) {
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
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayStudentName(submission),
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تاريخ التسليم: ${_formatDate(submission.submittedAt)}',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (submission.isGraded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${submission.grade}/${widget.assignment.totalPoints}',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Image preview
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageViewerScreen(
                    imageUrl: submission.submissionImageUrl,
                    title: 'صورة الحل',
                  ),
                ),
              );
            },
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  submission.submissionImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Icon(Icons.image, size: 48, color: Colors.grey[400]),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!submission.isGraded)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _gradeSubmission(submission),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'تصحيح',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
                  const SizedBox(width: 8),
                  Text(
                    'تم التصحيح - XP المكتسب: ${submission.xpEarned}',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
