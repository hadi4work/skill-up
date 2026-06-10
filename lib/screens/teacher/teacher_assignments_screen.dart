import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/assignment_service.dart';
import '../../models/assignment_model.dart';
import 'create_assignment_screen.dart';
import 'grade_submissions_screen.dart';
import 'teacher_timed_assessments_screen.dart';

class TeacherAssignmentsScreen extends StatefulWidget {
  const TeacherAssignmentsScreen({super.key});

  @override
  State<TeacherAssignmentsScreen> createState() => _TeacherAssignmentsScreenState();
}

class _TeacherAssignmentsScreenState extends State<TeacherAssignmentsScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  List<AssignmentModel> _assignments = [];
  bool _isLoading = true;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
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
      final assignments = await _assignmentService.getTeacherAssignments(teacherId);
      if (mounted) {
        setState(() {
          _assignments = assignments;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _selectionMode ? 'تم تحديد ${_selectedIds.length}' : 'الواجبات',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: 'إلغاء التحديد',
              icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
              onPressed: () {
                setState(() {
                  _selectionMode = false;
                  _selectedIds.clear();
                });
              },
            ),
            IconButton(
              tooltip: 'حذف المحدد',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _selectedIds.isEmpty ? null : _deleteSelectedAssignments,
            ),
          ] else ...[
            IconButton(
              tooltip: 'تحديد',
              icon: const Icon(Icons.checklist_rounded, color: Color(0xFF2563EB)),
              onPressed: _assignments.isEmpty
                  ? null
                  : () {
                      setState(() => _selectionMode = true);
                    },
            ),
          ],
          IconButton(
            tooltip: 'الاختبارات المؤقتة',
            icon: const Icon(Icons.quiz, color: Color(0xFF059669)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TeacherTimedAssessmentsScreen(
                    assessmentType: 'exam',
                    titleText: 'الاختبارات المؤقتة',
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'الوظائف المؤقتة',
            icon: const Icon(Icons.timer, color: Color(0xFF7C3AED)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TeacherTimedAssessmentsScreen(
                    assessmentType: 'assignment',
                    titleText: 'الوظائف المؤقتة',
                  ),
                ),
              );
            },
          ),
          if (!_selectionMode)
            IconButton(
              icon: const Icon(Icons.add, color: Color(0xFF2563EB)),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateAssignmentScreen(),
                  ),
                );
                if (result == true) {
                  _loadAssignments();
                }
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAssignments,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _assignments.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد واجبات',
                                style: GoogleFonts.cairo(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _assignments.length,
                    itemBuilder: (context, index) {
                      return _buildAssignmentCard(_assignments[index]);
                    },
                  ),
      ),
    );
  }

  Future<void> _deleteSelectedAssignments() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف الواجبات المحددة', style: GoogleFonts.cairo()),
        content: Text('سيتم حذف ${_selectedIds.length} واجبات. هل تريد المتابعة؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء', style: GoogleFonts.cairo())),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('حذف', style: GoogleFonts.cairo(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    for (final id in _selectedIds) {
      await _assignmentService.deleteAssignment(id);
    }
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
    _loadAssignments();
  }

  Widget _buildAssignmentCard(AssignmentModel assignment) {
    return FutureBuilder<int>(
      future: _assignmentService.getSubmissionCount(assignment.id),
      builder: (context, snapshot) {
        int submissionCount = snapshot.data ?? 0;
        
        final selected = _selectedIds.contains(assignment.id);
        return GestureDetector(
          onLongPress: () {
            setState(() {
              _selectionMode = true;
              if (selected) {
                _selectedIds.remove(assignment.id);
              } else {
                _selectedIds.add(assignment.id);
              }
            });
          },
          onTap: _selectionMode
              ? () {
                  setState(() {
                    if (selected) {
                      _selectedIds.remove(assignment.id);
                    } else {
                      _selectedIds.add(assignment.id);
                    }
                  });
                }
              : null,
          child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: selected ? Border.all(color: const Color(0xFF2563EB), width: 1.5) : null,
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
                  if (_selectionMode) ...[
                    Icon(
                      selected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: selected ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 10),
                  ],
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
                        Row(
                          children: [
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
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'الموعد النهائي: ${_formatDate(assignment.deadline)}',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.people, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '$submissionCount طالب سلم',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_selectionMode)
                Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GradeSubmissionsScreen(
                              assignment: assignment,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'تصحيح ($submissionCount)',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ));
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
