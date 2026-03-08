import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../services/assignment_service.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';
import '../../models/assignment_model.dart';
import '../../models/submission_model.dart';
import '../image_viewer_screen.dart';
import '../ai_assistant_screen.dart';

class SubmitAssignmentScreen extends StatefulWidget {
  final AssignmentModel assignment;

  const SubmitAssignmentScreen({
    super.key,
    required this.assignment,
  });

  @override
  State<SubmitAssignmentScreen> createState() => _SubmitAssignmentScreenState();
}

class _SubmitAssignmentScreenState extends State<SubmitAssignmentScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final StorageService _storageService = StorageService();
  final UserService _userService = UserService();
  final ImagePicker _picker = ImagePicker();
  
  File? _solutionImage;
  bool _isLoading = false;
  SubmissionModel? _existingSubmission;

  @override
  void initState() {
    super.initState();
    _checkExistingSubmission();
  }

  Future<void> _checkExistingSubmission() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentId = authProvider.user?.uid;

    if (studentId == null) return;

    try {
      final submission = await _assignmentService.getStudentSubmission(
        widget.assignment.id,
        studentId,
      );
      if (mounted) {
        setState(() {
          _existingSubmission = submission;
        });
      }
    } catch (e) {
      debugPrint('Error checking submission: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _solutionImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء اختيار الصورة: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitAssignment() async {
    if (_solutionImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى التقاط صورة الحل', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if submission already exists
    if (_existingSubmission != null) {
      // Update existing submission
      await _updateSubmission();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null || user.studentCode == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Create submission first to get ID
      SubmissionModel newSubmission = SubmissionModel(
        id: '',
        assignmentId: widget.assignment.id,
        studentId: user.uid,
        studentCode: user.studentCode!,
        submissionImageUrl: '',
        submittedAt: DateTime.now(),
        xpEarned: 5, // 5 XP for submission
      );

      String submissionId = await _assignmentService.submitAssignment(newSubmission);

      // Upload image
      String imageUrl = await _storageService.uploadSubmissionImage(
        _solutionImage!,
        submissionId,
      );

      // Update submission with image URL
      await _assignmentService.updateSubmission(submissionId, {
        'submissionImageUrl': imageUrl,
      });

      // Add 5 XP to student for submission (only for new submissions)
      await _userService.addXP(user.uid, 5);
      
      // Refresh user profile in AuthProvider to update XP/Level
      await authProvider.refreshUser();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إرسال الواجب بنجاح! حصلت على 5 XP',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
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

  Future<void> _updateSubmission() async {
    if (_solutionImage == null || _existingSubmission == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Delete old image from storage if exists
      if (_existingSubmission!.submissionImageUrl.isNotEmpty) {
        try {
          await _storageService.deleteImage(_existingSubmission!.submissionImageUrl);
        } catch (e) {
          debugPrint('Error deleting old image: $e');
          // Continue even if deletion fails
        }
      }

      // Upload new image
      String imageUrl = await _storageService.uploadSubmissionImage(
        _solutionImage!,
        _existingSubmission!.id,
      );

      // Update submission with new image URL and update submittedAt
      await _assignmentService.updateSubmission(_existingSubmission!.id, {
        'submissionImageUrl': imageUrl,
        'submittedAt': DateTime.now().toIso8601String(),
        // Reset grading status if it was graded (allow re-submission after grading)
        'isGraded': false,
        'grade': null,
        'gradedAt': null,
      });

      // Refresh existing submission
      await _checkExistingSubmission();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحديث الحل بنجاح',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحديث الحل: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'حل الواجب',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Assignment Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.assignment.title,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'المادة: ${widget.assignment.subject}',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الموعد النهائي: ${_formatDate(widget.assignment.deadline)}',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Existing Submission Info
              if (_existingSubmission != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _existingSubmission!.isGraded
                        ? Colors.green[50]
                        : Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _existingSubmission!.isGraded
                            ? Icons.check_circle
                            : Icons.access_time,
                        color: _existingSubmission!.isGraded
                            ? Colors.green
                            : Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _existingSubmission!.isGraded
                                  ? 'تم التصحيح'
                                  : 'تم الإرسال - في انتظار التصحيح',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            if (_existingSubmission!.isGraded) ...[
                              const SizedBox(height: 4),
                              Text(
                                'العلامة: ${_existingSubmission!.grade}/${widget.assignment.totalPoints}',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'XP المكتسب: ${_existingSubmission!.xpEarned}',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  color: const Color(0xFF22C55E),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Assignment Image (Questions)
              if (widget.assignment.assignmentImageUrl.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'صورة الأسئلة',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AIAssistantScreen(
                              subject: widget.assignment.subject,
                              question: widget.assignment.title +
                                  (widget.assignment.notes != null
                                      ? '\n${widget.assignment.notes}'
                                      : ''),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.lightbulb_outline, size: 20),
                      label: Text(
                        'تلميح من الذكاء الاصطناعي',
                        style: GoogleFonts.cairo(fontSize: 13),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ImageViewerScreen(
                          imageUrl: widget.assignment.assignmentImageUrl,
                          title: widget.assignment.title,
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
                        widget.assignment.assignmentImageUrl,
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
                const SizedBox(height: 24),
              ],
              // Solution Image
              Text(
                _existingSubmission != null ? 'صورة الحل الحالية' : 'صورة الحل',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              // Show existing submission image if available
              if (_existingSubmission != null &&
                  _existingSubmission!.submissionImageUrl.isNotEmpty &&
                  _solutionImage == null) ...[
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ImageViewerScreen(
                          imageUrl: _existingSubmission!.submissionImageUrl,
                          title: 'الحل الحالي',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _existingSubmission!.submissionImageUrl,
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
                const SizedBox(height: 12),
                Text(
                  'اضغط على الصورة أعلاه لعرضها بالحجم الكامل، أو التقط صورة جديدة لتحديث الحل',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _solutionImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _solutionImage!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.camera_alt,
                              size: 48,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _existingSubmission != null
                                  ? 'اضغط للتقاط صورة جديدة لتحديث الحل'
                                  : 'اضغط للتقاط صورة الحل',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),
              // Submit/Update Button
              if (_existingSubmission == null || !_existingSubmission!.isGraded)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitAssignment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _existingSubmission != null
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _existingSubmission != null
                                ? 'تحديث الحل'
                                : 'إرسال الحل',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
