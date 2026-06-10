// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/class_model.dart';
import '../../models/exam_model.dart';
import '../../models/exam_question_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/class_service.dart';
import '../../services/exam_service.dart';
import 'edit_exam_question_screen.dart';

class CreateTimedExamScreen extends StatefulWidget {
  final String assessmentType; // exam | assignment
  final String titleText;
  /// عند التمرير: تعديل اختبار/وظيفة موجودة
  final ExamModel? existingExam;

  const CreateTimedExamScreen({
    super.key,
    this.assessmentType = 'exam',
    this.titleText = 'إنشاء اختبار',
    this.existingExam,
  });

  @override
  State<CreateTimedExamScreen> createState() => _CreateTimedExamScreenState();
}

class _CreateTimedExamScreenState extends State<CreateTimedExamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _notesController = TextEditingController();

  final ClassService _classService = ClassService();
  final ExamService _examService = ExamService();

  DateTime? _startAt;
  DateTime? _endAt;
  bool _isLoading = false;
  final List<String> _selectedClassIds = [];
  List<ClassModel> _classes = [];
  final List<ExamQuestionModel> _questions = [];
  String? _editingExamId;
  bool _wasPublishedAtOpen = false;
  bool _hydrating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadClasses();
      await _hydrateExistingExam();
    });
  }

  bool get _isEditing => _editingExamId != null;

  Future<void> _hydrateExistingExam() async {
    final e = widget.existingExam;
    if (e == null || !mounted) return;
    setState(() => _hydrating = true);
    try {
      _editingExamId = e.id;
      _wasPublishedAtOpen = e.isPublished;
      _titleController.text = e.title;
      _subjectController.text = e.subject;
      _notesController.text = e.notes ?? '';
      _selectedClassIds
        ..clear()
        ..addAll(e.classIds);
      _startAt = e.startAt;
      _endAt = e.endAt;
      final qs = await _examService.getExamQuestions(e.id);
      if (!mounted) return;
      setState(() {
        _questions
          ..clear()
          ..addAll(qs);
      });
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل البيانات: $err', style: GoogleFonts.cairo())),
        );
      }
    } finally {
      if (mounted) setState(() => _hydrating = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _questionTypeLabel(ExamQuestionModel q) {
    if (q.isEssay) return 'مقالي';
    if (q.isSingleChoice) return 'اختياري';
    if (q.isTrueFalse) return 'صح وخطأ';
    return q.type;
  }

  Future<void> _loadClasses() async {
    final teacherId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (teacherId == null) return;
    final classes = await _classService.getTeacherClasses(teacherId);
    if (!mounted) return;
    setState(() => _classes = classes);
  }

  Future<void> _pickDateTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (!mounted || time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startAt = dt;
      } else {
        _endAt = dt;
      }
    });
  }

  Future<void> _addOrEditQuestion({ExamQuestionModel? editing, int? index}) async {
    final newQ = await Navigator.push<ExamQuestionModel>(
      context,
      MaterialPageRoute(
        builder: (_) => EditExamQuestionScreen(
          initial: editing,
          order: index ?? _questions.length,
        ),
      ),
    );
    if (newQ == null) return;

    setState(() {
      if (editing != null && index != null) {
        _questions[index] = newQ;
      } else {
        _questions.add(newQ);
      }
      _normalizeOrder();
    });
  }

  void _normalizeOrder() {
    for (int i = 0; i < _questions.length; i++) {
      _questions[i] = _questions[i].copyWith(order: i);
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF2563EB)) : null,
      labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w600),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }

  Future<void> _saveAndPublish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('اختر صفا واحدا على الأقل', style: GoogleFonts.cairo())));
      return;
    }
    if (_startAt == null || _endAt == null || !_endAt!.isAfter(_startAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدد وقت البداية والنهاية بشكل صحيح', style: GoogleFonts.cairo())));
      return;
    }
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('أضف سؤالا واحدا على الأقل', style: GoogleFonts.cairo())));
      return;
    }
    final teacherId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (teacherId == null) return;

    setState(() => _isLoading = true);
    try {
      if (_isEditing && _editingExamId != null) {
        final id = _editingExamId!;
        final hasFinished = await _examService.examHasFinishedAttempts(id);
        await _examService.updateExamMeta(id, {
          'title': _titleController.text.trim(),
          'subject': _subjectController.text.trim(),
          'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          'classIds': _selectedClassIds,
          'startAt': _startAt!.toIso8601String(),
          'endAt': _endAt!.toIso8601String(),
        });
        if (!hasFinished) {
          await _examService.replaceExamQuestions(id, _questions);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم حفظ العنوان والمواعيد فقط — لا يمكن تغيير الأسئلة بعد وجود محاولات مكتملة.',
                style: GoogleFonts.cairo(),
              ),
            ),
          );
        }
        if (!_wasPublishedAtOpen) {
          await _examService.publishExam(id);
        }
      } else {
        final exam = ExamModel(
          id: '',
          teacherId: teacherId,
          subject: _subjectController.text.trim(),
          title: _titleController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          classIds: _selectedClassIds,
          startAt: _startAt!,
          endAt: _endAt!,
          isPublished: false,
          createdAt: DateTime.now(),
          questionCount: _questions.length,
          status: 'draft',
          assessmentType: widget.assessmentType,
        );
        final examId = await _examService.createExam(exam, _questions);
        await _examService.publishExam(examId);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحفظ: $e', style: GoogleFonts.cairo()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.titleText, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      ),
      body: _hydrating
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
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
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: _inputDecoration(
                      label: widget.assessmentType == 'assignment'
                          ? 'عنوان الوظيفة'
                          : 'عنوان الاختبار',
                      icon: Icons.title,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل العنوان' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subjectController,
                    decoration: _inputDecoration(
                      label: 'اسم المادة',
                      icon: Icons.book_outlined,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل المادة' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: _inputDecoration(
                      label: 'ملاحظة للطلاب قبل الدخول',
                      hint: 'مثال: اقرأ السؤال بدقة قبل الإجابة',
                      icon: Icons.sticky_note_2_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
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
              child: Wrap(
                spacing: 8,
                children: _classes
                    .map(
                      (c) => FilterChip(
                        label: Text('${c.name} ${c.section}', style: GoogleFonts.cairo()),
                        selected: _selectedClassIds.contains(c.id),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedClassIds.add(c.id);
                            } else {
                              _selectedClassIds.remove(c.id);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDateTime(true),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        _startAt == null ? 'وقت البداية' : 'بداية: ${_startAt!.day}/${_startAt!.month} ${_startAt!.hour}:${_startAt!.minute.toString().padLeft(2, '0')}',
                        style: GoogleFonts.cairo(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDateTime(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        _endAt == null ? 'وقت النهاية' : 'نهاية: ${_endAt!.day}/${_endAt!.month} ${_endAt!.hour}:${_endAt!.minute.toString().padLeft(2, '0')}',
                        style: GoogleFonts.cairo(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('الأسئلة', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _addOrEditQuestion(),
                  icon: const Icon(Icons.add),
                  label: Text('إضافة سؤال', style: GoogleFonts.cairo()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _questions.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _questions.removeAt(oldIndex);
                  _questions.insert(newIndex, item);
                  _normalizeOrder();
                });
              },
              itemBuilder: (context, index) {
                final q = _questions[index];
                return Container(
                  key: ValueKey('q_$index'),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: ListTile(
                    title: Text(
                      'س${index + 1}: ${q.text}',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${_questionTypeLabel(q)} - ${q.timeLimitSec} ثانية - ${q.maxPoints} علامة',
                      style: GoogleFonts.cairo(color: const Color(0xFF4B5563)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _addOrEditQuestion(editing: q, index: index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _questions.removeAt(index);
                              _normalizeOrder();
                            });
                          },
                        ),
                        const Icon(Icons.drag_handle),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveAndPublish,
              icon: _isLoading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.publish),
              label: Text(
                _isLoading
                    ? 'جارٍ الحفظ...'
                    : _isEditing
                        ? 'حفظ التعديلات'
                        : 'حفظ ونشر',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
