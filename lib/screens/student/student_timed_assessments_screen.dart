import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/exam_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/exam_service.dart';
import '../../services/student_content_seen_service.dart';
import 'student_take_exam_screen.dart';

class StudentTimedAssessmentsScreen extends StatefulWidget {
  final String assessmentType; // exam | assignment
  final String titleText;
  const StudentTimedAssessmentsScreen({
    super.key,
    required this.assessmentType,
    required this.titleText,
  });

  @override
  State<StudentTimedAssessmentsScreen> createState() => _StudentTimedAssessmentsScreenState();
}

class _StudentTimedAssessmentsScreenState extends State<StudentTimedAssessmentsScreen> {
  final ExamService _examService = ExamService();
  bool _isLoading = true;
  List<ExamModel> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final classIds = user?.classIds ?? [];
    final uid = user?.uid;
    setState(() => _isLoading = true);
    final data = await _examService.getStudentAvailableExams(
      classIds,
      assessmentType: widget.assessmentType,
    );
    if (uid != null && data.isNotEmpty) {
      final ids = data.map((e) => e.id).where((id) => id.isNotEmpty);
      if (widget.assessmentType == 'exam') {
        await StudentContentSeenService.markTimedExamsSeen(uid, ids);
      } else {
        await StudentContentSeenService.markTimedAssignmentsSeen(uid, ids);
      }
    }
    if (!mounted) return;
    setState(() {
      _items = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final studentId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.titleText, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? Center(child: Text('لا يوجد حالياً', style: GoogleFonts.cairo(fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final item = _items[i];
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
                                    gradient: LinearGradient(
                                      colors: widget.assessmentType == 'exam'
                                          ? const [Color(0xFF059669), Color(0xFF2563EB)]
                                          : const [Color(0xFF7C3AED), Color(0xFF2563EB)],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    widget.assessmentType == 'exam' ? Icons.quiz : Icons.timer,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
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
                                          item.subject,
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
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'من ${_fmt(item.startAt)} إلى ${_fmt(item.endAt)}',
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: studentId == null
                                    ? null
                                    : () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => StudentTakeExamScreen(
                                              exam: item,
                                              studentId: studentId,
                                            ),
                                          ),
                                        );
                                        if (result == true) _load();
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  'ابدأ الآن',
                                  style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  String _fmt(DateTime d) {
    return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}
