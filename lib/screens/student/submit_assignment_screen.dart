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
import '../../services/student_content_seen_service.dart';
import '../image_viewer_screen.dart';

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

  static const double _thumbHeight = 168;

  /// انتهى الموعد النهائي (لا تسليم جديد ولا تحديث للحل).
  bool get _isPastDeadline =>
      widget.assignment.deadline.isBefore(DateTime.now());

  bool get _canEditSolution =>
      (_existingSubmission == null || !_existingSubmission!.isGraded) &&
      !_isPastDeadline;

  @override
  void initState() {
    super.initState();
    _checkExistingSubmission();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = Provider.of<AuthProvider>(context, listen: false).user?.uid;
      if (uid != null) {
        StudentContentSeenService.markAssignmentSeen(uid, widget.assignment.id);
      }
    });
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
    if (!_canEditSolution) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _existingSubmission?.isGraded == true
                  ? 'لا يمكن تعديل الحل بعد تصحيح المعلم'
                  : 'انتهى الموعد النهائي ولا يمكن تعديل الحل',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
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

    if (_isPastDeadline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'انتهى الموعد النهائي ولا يمكن إرسال أو تحديث الحل',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_existingSubmission != null) {
      if (!_canEditSolution) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _existingSubmission!.isGraded
                  ? 'لا يمكن تعديل الحل بعد تصحيح المعلم'
                  : 'انتهى الموعد النهائي ولا يمكن تحديث الحل',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
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
      SubmissionModel newSubmission = SubmissionModel(
        id: '',
        assignmentId: widget.assignment.id,
        studentId: user.uid,
        studentCode: user.studentCode!,
        submissionImageUrl: '',
        submittedAt: DateTime.now(),
        xpEarned: 5,
      );

      String submissionId = await _assignmentService.submitAssignment(newSubmission);

      String imageUrl = await _storageService.uploadSubmissionImage(
        _solutionImage!,
        submissionId,
      );

      await _assignmentService.updateSubmission(submissionId, {
        'submissionImageUrl': imageUrl,
      });

      await _userService.addXP(user.uid, 5);

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
    if (_isPastDeadline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'انتهى الموعد النهائي ولا يمكن تحديث الحل',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    if (_existingSubmission!.isGraded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لا يمكن تعديل الحل بعد تصحيح المعلم',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_existingSubmission!.submissionImageUrl.isNotEmpty) {
        try {
          await _storageService.deleteImage(_existingSubmission!.submissionImageUrl);
        } catch (e) {
          debugPrint('Error deleting old image: $e');
        }
      }

      String imageUrl = await _storageService.uploadSubmissionImage(
        _solutionImage!,
        _existingSubmission!.id,
      );

      await _assignmentService.updateSubmission(_existingSubmission!.id, {
        'submissionImageUrl': imageUrl,
        'submittedAt': DateTime.now().toIso8601String(),
      });

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

  void _openAssignmentImage() {
    if (widget.assignment.assignmentImageUrl.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ImageViewerScreen(
          imageUrl: widget.assignment.assignmentImageUrl,
          title: widget.assignment.title,
          aiExtractSubject: widget.assignment.subject,
          aiExtractAssignmentTitle: widget.assignment.title,
        ),
      ),
    );
  }

  void _openSolutionImage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ImageViewerScreen(
          imageUrl: url,
          title: 'صورة الحل',
        ),
      ),
    );
  }

  void _openLocalSolutionPreview() {
    if (_solutionImage == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'معاينة الحل',
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 18),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(_solutionImage!, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbShell({required VoidCallback? onTap, required Widget child}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: _thumbHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAssignmentImage = widget.assignment.assignmentImageUrl.isNotEmpty;
    final solutionUrl = _existingSubmission?.submissionImageUrl ?? '';
    final hasSavedSolution = solutionUrl.isNotEmpty;

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
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              if (_isPastDeadline) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, color: Color(0xFFB45309), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'انتهى الموعد النهائي لهذا الواجب — يمكنك عرض الأسئلات والحل المُرسل فقط دون تعديل.',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: const Color(0xFF92400E),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
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
                const SizedBox(height: 20),
              ],
              Text(
                'الصور',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'اضغط على أي معاينة لفتحها بالحجم الكامل. لاستخراج نص الأسئلة استخدم «استخراج النص» من شاشة العرض.',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'أسئلة الواجب',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _thumbShell(
                            onTap: hasAssignmentImage ? _openAssignmentImage : null,
                            child: hasAssignmentImage
                                ? Image.network(
                                    widget.assignment.assignmentImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Center(
                                      child: Icon(Icons.image, size: 40, color: Colors.grey[400]),
                                    ),
                                  )
                                : Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        'لا توجد صورة',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          color: const Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _existingSubmission != null ? 'حلك' : 'معاينة الحل',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _thumbShell(
                            onTap: _solutionImage != null
                                ? _openLocalSolutionPreview
                                : (hasSavedSolution
                                    ? () => _openSolutionImage(solutionUrl)
                                    : null),
                            child: _solutionImage != null
                                ? Image.file(
                                    _solutionImage!,
                                    fit: BoxFit.cover,
                                  )
                                : hasSavedSolution
                                    ? Image.network(
                                        solutionUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Center(
                                          child: Icon(Icons.image, size: 40, color: Colors.grey[400]),
                                        ),
                                      )
                                    : Center(
                                        child: Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 40,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (hasSavedSolution &&
                  _solutionImage == null &&
                  _canEditSolution) ...[
                const SizedBox(height: 8),
                Text(
                  'استخدم الزر أدناه لتصوير حل جديد وتحديث التسليم.',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: const Color(0xFF6B7280),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (_existingSubmission != null &&
                  _existingSubmission!.isGraded) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    'تم قفل الحل بعد تصحيح المعلم.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
              if (_canEditSolution) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.camera_alt, size: 20),
                      label: Text(
                        _existingSubmission != null
                            ? 'تغيير صورة الحل'
                            : 'التقاط صورة الحل',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    if (_solutionImage != null)
                      TextButton.icon(
                        onPressed: () => setState(() => _solutionImage = null),
                        icon: const Icon(Icons.close, size: 18),
                        label: Text(
                          'إزالة المعاينة',
                          style: GoogleFonts.cairo(),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              if (_canEditSolution &&
                  (_existingSubmission == null || !_existingSubmission!.isGraded))
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (_isLoading || _solutionImage == null) ? null : _submitAssignment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _existingSubmission != null
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
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
