import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/exam_question_model.dart';

class EditExamQuestionScreen extends StatefulWidget {
  final ExamQuestionModel? initial;
  final int order;

  const EditExamQuestionScreen({
    super.key,
    this.initial,
    required this.order,
  });

  @override
  State<EditExamQuestionScreen> createState() => _EditExamQuestionScreenState();
}

class _EditExamQuestionScreenState extends State<EditExamQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _textController;
  late final TextEditingController _timeController;
  late final TextEditingController _pointsController;
  late final TextEditingController _rubricController;
  late final TextEditingController _tfPointsController;
  late final TextEditingController _justifyPointsController;
  late final TextEditingController _justificationRubricController;
  late final TextEditingController _expectedJustificationController;
  late final List<TextEditingController> _optionsControllers;
  String _qType = 'essay';
  int _correctIndex = 0;
  /// عدد خانات الخيارات الظاهرة: من 2 إلى 4
  int _optionSlotCount = 2;
  bool _tfCorrectIsTrue = true;
  bool _justifyIfStatementFalse = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _qType = initial?.type ?? 'essay';
    _correctIndex = initial?.correctOptionIndex ?? 0;
    _textController = TextEditingController(text: initial?.text ?? '');
    _timeController = TextEditingController(text: (initial?.timeLimitSec ?? 60).toString());
    _pointsController = TextEditingController(text: (initial?.maxPoints ?? 1).toString());
    _rubricController = TextEditingController(text: initial?.rubric ?? '');
    _tfPointsController = TextEditingController(
      text: (initial?.trueFalsePoints ?? 1).toString(),
    );
    _justifyPointsController = TextEditingController(
      text: (initial?.justificationPoints ?? 1).toString(),
    );
    _justificationRubricController = TextEditingController(
      text: initial?.justificationRubric ?? '',
    );
    _expectedJustificationController = TextEditingController(
      text: initial?.expectedJustification ?? '',
    );
    _optionsControllers = List.generate(
      4,
      (i) => TextEditingController(
        text: initial != null && i < initial.options.length ? initial.options[i] : '',
      ),
    );
    if (initial != null && initial.type == 'single_choice') {
      _optionSlotCount = initial.options.length.clamp(2, 4);
    }
    if (initial != null && initial.type == 'true_false') {
      _tfCorrectIsTrue = initial.correctIsTrue ?? true;
      _justifyIfStatementFalse = initial.justifyIfStatementFalse;
      if (initial.trueFalsePoints > 0) {
        _tfPointsController.text = initial.trueFalsePoints.toString();
      }
      if (initial.justificationPoints > 0) {
        _justifyPointsController.text = initial.justificationPoints.toString();
      }
      if ((initial.expectedJustification ?? '').isNotEmpty) {
        _expectedJustificationController.text = initial.expectedJustification!;
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _timeController.dispose();
    _pointsController.dispose();
    _rubricController.dispose();
    _tfPointsController.dispose();
    _justifyPointsController.dispose();
    _justificationRubricController.dispose();
    _expectedJustificationController.dispose();
    for (final c in _optionsControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// حذف الخيار الثالث أو الرابع (الفهرس 2 أو 3) بإزاحة المحتوى وتصحيح الإجابة الصحيحة.
  void _removeOptionAt(int index) {
    assert(_optionSlotCount > 2);
    assert(index >= 2 && index < _optionSlotCount);
    setState(() {
      if (_optionSlotCount == 4 && index == 2) {
        _optionsControllers[2].text = _optionsControllers[3].text;
        _optionsControllers[3].clear();
        _optionSlotCount = 3;
        if (_correctIndex == 2) {
          _correctIndex = 0;
        } else if (_correctIndex == 3) {
          _correctIndex = 2;
        }
      } else if (_optionSlotCount == 4 && index == 3) {
        _optionsControllers[3].clear();
        _optionSlotCount = 3;
        if (_correctIndex == 3) _correctIndex = 0;
      } else if (_optionSlotCount == 3 && index == 2) {
        _optionsControllers[2].clear();
        _optionSlotCount = 2;
        if (_correctIndex == 2) _correctIndex = 0;
      }
      _correctIndex = _correctIndex.clamp(0, _optionSlotCount - 1);
    });
  }

  Widget _buildChoiceOptionField(BuildContext context, int i) {
    final field = TextFormField(
      controller: _optionsControllers[i],
      decoration: _inputDecoration(
        label: 'الخيار ${i + 1}${i < 2 ? ' *' : ''}',
        icon: Icons.radio_button_checked,
      ),
      validator: (v) {
        if (i < 2 && (v == null || v.trim().isEmpty)) {
          return 'مطلوب';
        }
        return null;
      },
    );
    if (i < 2) return field;

    final rtl = Directionality.of(context) == TextDirection.rtl;
    final deleteBg = Container(
      alignment: rtl ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      padding: const EdgeInsetsDirectional.only(start: 20, end: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 28),
    );

    // يجب أن يتغيّر المفتاح عند تغيّر عدد الخانات وإلا يبقى Dismissible «مُزالاً» بنفس المفتاح في الشجرة.
    return Dismissible(
      key: ValueKey('choice_${_optionSlotCount}_$i'),
      direction: rtl ? DismissDirection.endToStart : DismissDirection.startToEnd,
      // إن وُجد secondaryBackground يجب أن يكون background غير null (assert في Flutter).
      background: deleteBg,
      secondaryBackground: rtl ? deleteBg : null,
      confirmDismiss: (_) async => true,
      onDismissed: (_) => _removeOptionAt(i),
      child: field,
    );
  }

  List<String> _collectChoiceOptions() {
    final raw = <String>[];
    for (var i = 0; i < _optionSlotCount; i++) {
      raw.add(_optionsControllers[i].text.trim());
    }
    var last = -1;
    for (var i = 0; i < raw.length; i++) {
      if (raw[i].isNotEmpty) last = i;
    }
    if (last < 1) return <String>[];
    final slice = raw.sublist(0, last + 1);
    if (slice.any((e) => e.isEmpty)) return <String>[];
    return slice;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (_qType == 'single_choice') {
      final opts = _collectChoiceOptions();
      if (opts.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('أدخل خيارين على الأقل', style: GoogleFonts.cairo()),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (opts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('أدخل خيارين متتاليين دون فراغ بينهما', style: GoogleFonts.cairo()),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_correctIndex < 0 || _correctIndex >= opts.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('اختر إجابة صحيحة ضمن الخيارات المدخلة', style: GoogleFonts.cairo()),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final pts = int.parse(_pointsController.text.trim());
      final q = ExamQuestionModel(
        id: widget.initial?.id ?? '',
        order: widget.order,
        type: 'single_choice',
        text: _textController.text.trim(),
        timeLimitSec: int.parse(_timeController.text.trim()),
        maxPoints: pts,
        rubric: _rubricController.text.trim().isEmpty ? null : _rubricController.text.trim(),
        options: opts,
        correctOptionIndex: _correctIndex,
      );
      Navigator.pop(context, q);
      return;
    }

    if (_qType == 'true_false') {
      final tfPts = int.parse(_tfPointsController.text.trim());
      final jPts = int.parse(_justifyPointsController.text.trim());
      if (tfPts <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('أدخل علامة صحيحة لجزء صح/خطأ', style: GoogleFonts.cairo()),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final needsJustify = _justifyIfStatementFalse && !_tfCorrectIsTrue;
      if (needsJustify && jPts <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('أدخل علامة لتقييم التعليل', style: GoogleFonts.cairo()),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final rubMain = _rubricController.text.trim();
      final rubJust = _justificationRubricController.text.trim();
      final expectedJust = _expectedJustificationController.text.trim();
      final total = tfPts + (needsJustify ? jPts : 0);
      final q = ExamQuestionModel(
        id: widget.initial?.id ?? '',
        order: widget.order,
        type: 'true_false',
        text: _textController.text.trim(),
        timeLimitSec: int.parse(_timeController.text.trim()),
        maxPoints: total,
        rubric: rubMain.isEmpty ? null : rubMain,
        options: const [],
        correctOptionIndex: null,
        correctIsTrue: _tfCorrectIsTrue,
        justifyIfStatementFalse: _justifyIfStatementFalse,
        trueFalsePoints: tfPts,
        justificationPoints: needsJustify ? jPts : 0,
        justificationRubric: rubJust.isEmpty ? null : rubJust,
        expectedJustification: needsJustify ? expectedJust : null,
      );
      Navigator.pop(context, q);
      return;
    }

    // essay
    final qEssay = ExamQuestionModel(
      id: widget.initial?.id ?? '',
      order: widget.order,
      type: 'essay',
      text: _textController.text.trim(),
      timeLimitSec: int.parse(_timeController.text.trim()),
      maxPoints: int.parse(_pointsController.text.trim()),
      rubric: _rubricController.text.trim(),
      options: const [],
    );
    Navigator.pop(context, qEssay);
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(isEdit ? 'تعديل سؤال' : 'إضافة سؤال', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      ),
      body: Form(
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _qType,
                    isExpanded: true,
                    decoration: _inputDecoration(label: 'نوع السؤال', icon: Icons.category_outlined),
                    items: const [
                      DropdownMenuItem(value: 'essay', child: Text('مقالي')),
                      DropdownMenuItem(value: 'single_choice', child: Text('اختياري')),
                      DropdownMenuItem(value: 'true_false', child: Text('صح وخطأ')),
                    ],
                    onChanged: (v) => setState(() => _qType = v ?? 'essay'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _textController,
                    maxLines: 3,
                    decoration: _inputDecoration(
                      label: 'نص السؤال',
                      hint: _qType == 'true_false' ? 'عبارة يحدد الطالب هل هي صحيحة أم لا' : null,
                      icon: Icons.help_outline,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل نص السؤال' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _timeController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(label: 'وقت السؤال (ثانية)', icon: Icons.timer_outlined),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'أدخل وقتا صحيحا';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  if (_qType == 'essay' || _qType == 'single_choice') ...[
                    TextFormField(
                      controller: _pointsController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        label: 'علامة السؤال',
                        icon: Icons.star_outline,
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n <= 0) return 'أدخل علامة صحيحة';
                        return null;
                      },
                    ),
                  ],
                  if (_qType == 'true_false') ...[
                    TextFormField(
                      controller: _tfPointsController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        label: 'علامة جزء صح / خطأ',
                        icon: Icons.toggle_on_outlined,
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n <= 0) return 'أدخل علامة صحيحة';
                        return null;
                      },
                    ),
                    if (_justifyIfStatementFalse && !_tfCorrectIsTrue) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _justifyPointsController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          label: 'علامة تعليل/تصحيح العبارة',
                          icon: Icons.edit_note_outlined,
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'أدخل علامة صحيحة';
                          return null;
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _rubricController,
                    maxLines: 3,
                    decoration: _inputDecoration(
                      label: _qType == 'single_choice' ? 'سلم التصحيح (اختياري)' : 'سلم التصحيح',
                      hint: 'المعايير التي يعتمد عليها التصحيح',
                      icon: Icons.rule_outlined,
                    ),
                    validator: (v) {
                      if (_qType == 'essay' && (v == null || v.trim().isEmpty)) {
                        return 'أدخل سلم التصحيح';
                      }
                      return null;
                    },
                  ),
                  if (_qType == 'true_false') ...[
                    const SizedBox(height: 14),
                    DropdownButtonFormField<bool>(
                      value: _tfCorrectIsTrue,
                      isExpanded: true,
                      decoration: _inputDecoration(
                        label: 'الإجابة الصحيحة للعبارة',
                        icon: Icons.fact_check_outlined,
                      ),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('العبارة صحيحة')),
                        DropdownMenuItem(value: false, child: Text('العبارة خاطئة')),
                      ],
                      onChanged: (v) => setState(() => _tfCorrectIsTrue = v ?? true),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'طلب تعليل عند كون العبارة خاطئة',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'يظهر للطالب حقل نص عندما تكون الإجابة الصحيحة «خطأ»، ليكتب التصحيح أو التعليل',
                        style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF6B7280)),
                      ),
                      value: _justifyIfStatementFalse,
                      activeThumbColor: const Color(0xFF2563EB),
                      onChanged: (on) => setState(() => _justifyIfStatementFalse = on),
                    ),
                    if (_justifyIfStatementFalse && !_tfCorrectIsTrue) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _expectedJustificationController,
                        maxLines: 6,
                        decoration: _inputDecoration(
                          label: 'التصحيح أو التعليل المرجعي *',
                          hint:
                              'اكتب الصياغة الصحيحة أو ما يجب أن يذكره الطالب؛ الذكاء الاصطناعي يقارن تعليل الطالب بهذا النص',
                          icon: Icons.article_outlined,
                        ),
                        validator: (v) {
                          if (_justifyIfStatementFalse &&
                              !_tfCorrectIsTrue &&
                              (v == null || v.trim().isEmpty)) {
                            return 'أدخل النص المرجعي لتقييم التعليل';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _justificationRubricController,
                        maxLines: 3,
                        decoration: _inputDecoration(
                          label: 'معايير تقييم إضافية (اختياري)',
                          hint: 'مثال: ذكر السبب، استخدام المصطلح الصحيح...',
                          icon: Icons.grading_outlined,
                        ),
                      ),
                    ],
                  ],
                  if (_qType == 'single_choice') ...[
                    const SizedBox(height: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'الخيارات (اثنان إلزاميان، يمكن إضافة ثالث ورابع)',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'اسحب الخيار الثالث أو الرابع نحو اليمين لحذفه مباشرة.',
                          style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF6B7280)),
                        ),
                        if (_optionSlotCount < 4)
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton.icon(
                              onPressed: () => setState(() => _optionSlotCount++),
                              icon: const Icon(Icons.add, size: 20),
                              label: Text('خيار إضافي', style: GoogleFonts.cairo()),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (int i = 0; i < _optionSlotCount; i++) ...[
                      _buildChoiceOptionField(context, i),
                      const SizedBox(height: 8),
                    ],
                    DropdownButtonFormField<int>(
                      value: _correctIndex.clamp(0, _optionSlotCount - 1),
                      isExpanded: true,
                      decoration: _inputDecoration(label: 'الإجابة الصحيحة', icon: Icons.check_circle_outline),
                      items: [
                        for (int i = 0; i < _optionSlotCount; i++)
                          DropdownMenuItem(value: i, child: Text('الخيار ${i + 1}')),
                      ],
                      onChanged: (v) => setState(() => _correctIndex = v ?? 0),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('حفظ السؤال', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
