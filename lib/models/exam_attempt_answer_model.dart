class ExamAttemptAnswerModel {
  final String id;
  final String attemptId;
  final String examId;
  final String studentId;
  final String questionId;
  final int questionOrder;
  final int? selectedOptionIndex;
  final String? essayText;
  final bool isAutoCorrect;
  final bool? isCorrect;
  final int autoScore;
  final int manualScore;
  final String? teacherFeedback;
  final DateTime answeredAt;
  final bool timeExpired;

  const ExamAttemptAnswerModel({
    required this.id,
    required this.attemptId,
    required this.examId,
    required this.studentId,
    required this.questionId,
    required this.questionOrder,
    this.selectedOptionIndex,
    this.essayText,
    required this.isAutoCorrect,
    this.isCorrect,
    required this.autoScore,
    required this.manualScore,
    this.teacherFeedback,
    required this.answeredAt,
    required this.timeExpired,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'attemptId': attemptId,
      'examId': examId,
      'studentId': studentId,
      'questionId': questionId,
      'questionOrder': questionOrder,
      'selectedOptionIndex': selectedOptionIndex,
      'essayText': essayText,
      'isAutoCorrect': isAutoCorrect,
      'isCorrect': isCorrect,
      'autoScore': autoScore,
      'manualScore': manualScore,
      'teacherFeedback': teacherFeedback,
      'answeredAt': answeredAt.toIso8601String(),
      'timeExpired': timeExpired,
    };
  }

  factory ExamAttemptAnswerModel.fromMap(Map<String, dynamic> map) {
    return ExamAttemptAnswerModel(
      id: map['id'] ?? '',
      attemptId: map['attemptId'] ?? '',
      examId: map['examId'] ?? '',
      studentId: map['studentId'] ?? '',
      questionId: map['questionId'] ?? '',
      questionOrder: map['questionOrder'] ?? 0,
      selectedOptionIndex: map['selectedOptionIndex'],
      essayText: map['essayText'],
      isAutoCorrect: map['isAutoCorrect'] ?? false,
      isCorrect: map['isCorrect'],
      autoScore: map['autoScore'] ?? 0,
      manualScore: map['manualScore'] ?? 0,
      teacherFeedback: map['teacherFeedback'],
      answeredAt: map['answeredAt'] != null ? DateTime.parse(map['answeredAt']) : DateTime.now(),
      timeExpired: map['timeExpired'] ?? false,
    );
  }

  ExamAttemptAnswerModel copyWith({
    int? manualScore,
    String? teacherFeedback,
  }) {
    return ExamAttemptAnswerModel(
      id: id,
      attemptId: attemptId,
      examId: examId,
      studentId: studentId,
      questionId: questionId,
      questionOrder: questionOrder,
      selectedOptionIndex: selectedOptionIndex,
      essayText: essayText,
      isAutoCorrect: isAutoCorrect,
      isCorrect: isCorrect,
      autoScore: autoScore,
      manualScore: manualScore ?? this.manualScore,
      teacherFeedback: teacherFeedback ?? this.teacherFeedback,
      answeredAt: answeredAt,
      timeExpired: timeExpired,
    );
  }
}
