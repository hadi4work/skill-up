class ExamQuestionModel {
  final String id;
  final int order;
  /// مقالي | اختياري (من متعدد) | صح وخطأ
  final String type; // 'essay' | 'single_choice' | 'true_false'
  final String text;
  final int timeLimitSec;
  final List<String> options;
  final int? correctOptionIndex;
  /// إجمالي علامة السؤال (يُحسب عند الحفظ من أجزاء صح/خطأ والتعليل إن وُجد)
  final int maxPoints;
  final String? rubric;

  // ——— صح وخطأ ———
  /// إن كانت العبارة صحيحة فالإجابة الصحيحة «صح»، وإلا «خطأ»
  final bool? correctIsTrue;
  /// إن فُعّل: عندما تكون العبارة **خطأ** (الصحيح = خطأ) يُطلب من الطالب تعليل/تصحيح نصي
  final bool justifyIfStatementFalse;
  /// علامة جزء صح/خطأ
  final int trueFalsePoints;
  /// علامة جزء التعليل (تُقيَّم آلياً حسب السلم عند تفعيل التعليل)
  final int justificationPoints;
  /// سلم تقييم التعليل؛ إن وُفر يُفضّل على [rubric] لجزء التعليل
  final String? justificationRubric;
  /// نص التصحيح/التعليل المرجعي من المعلم؛ يُعتمد أساساً لتقييم تعليل الطالب آلياً
  final String? expectedJustification;

  const ExamQuestionModel({
    required this.id,
    required this.order,
    required this.type,
    required this.text,
    required this.timeLimitSec,
    this.options = const [],
    this.correctOptionIndex,
    required this.maxPoints,
    this.rubric,
    this.correctIsTrue,
    this.justifyIfStatementFalse = false,
    this.trueFalsePoints = 0,
    this.justificationPoints = 0,
    this.justificationRubric,
    this.expectedJustification,
  });

  bool get isEssay => type == 'essay';
  bool get isSingleChoice => type == 'single_choice';
  bool get isTrueFalse => type == 'true_false';

  /// حقل التعليل يظهر فقط عندما الإجابة الصحيحة للعبارة هي «خطأ»
  bool get needsJustificationField =>
      isTrueFalse && justifyIfStatementFalse && correctIsTrue == false;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order': order,
      'type': type,
      'text': text,
      'timeLimitSec': timeLimitSec,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'maxPoints': maxPoints,
      'rubric': rubric,
      'correctIsTrue': correctIsTrue,
      'justifyIfStatementFalse': justifyIfStatementFalse,
      'trueFalsePoints': trueFalsePoints,
      'justificationPoints': justificationPoints,
      'justificationRubric': justificationRubric,
      'expectedJustification': expectedJustification,
    };
  }

  factory ExamQuestionModel.fromMap(Map<String, dynamic> map) {
    return ExamQuestionModel(
      id: map['id'] ?? '',
      order: map['order'] ?? 0,
      type: map['type'] ?? 'essay',
      text: map['text'] ?? '',
      timeLimitSec: map['timeLimitSec'] ?? 60,
      options: map['options'] != null ? List<String>.from(map['options']) : const [],
      correctOptionIndex: map['correctOptionIndex'],
      maxPoints: map['maxPoints'] ?? 1,
      rubric: map['rubric'],
      correctIsTrue: map['correctIsTrue'] as bool?,
      justifyIfStatementFalse: map['justifyIfStatementFalse'] ?? false,
      trueFalsePoints: (map['trueFalsePoints'] as num?)?.toInt() ?? 0,
      justificationPoints: (map['justificationPoints'] as num?)?.toInt() ?? 0,
      justificationRubric: map['justificationRubric'] as String?,
      expectedJustification: map['expectedJustification'] as String?,
    );
  }

  ExamQuestionModel copyWith({
    String? id,
    int? order,
    String? type,
    String? text,
    int? timeLimitSec,
    List<String>? options,
    int? correctOptionIndex,
    int? maxPoints,
    String? rubric,
    bool? correctIsTrue,
    bool? justifyIfStatementFalse,
    int? trueFalsePoints,
    int? justificationPoints,
    String? justificationRubric,
    String? expectedJustification,
  }) {
    return ExamQuestionModel(
      id: id ?? this.id,
      order: order ?? this.order,
      type: type ?? this.type,
      text: text ?? this.text,
      timeLimitSec: timeLimitSec ?? this.timeLimitSec,
      options: options ?? this.options,
      correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
      maxPoints: maxPoints ?? this.maxPoints,
      rubric: rubric ?? this.rubric,
      correctIsTrue: correctIsTrue ?? this.correctIsTrue,
      justifyIfStatementFalse: justifyIfStatementFalse ?? this.justifyIfStatementFalse,
      trueFalsePoints: trueFalsePoints ?? this.trueFalsePoints,
      justificationPoints: justificationPoints ?? this.justificationPoints,
      justificationRubric: justificationRubric ?? this.justificationRubric,
      expectedJustification: expectedJustification ?? this.expectedJustification,
    );
  }
}
