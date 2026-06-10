class ExamAttemptModel {
  final String id;
  final String examId;
  final String studentId;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int currentQuestionOrder;
  final bool isFinished;
  final int scoreAuto;
  final int scoreManual;
  final int scoreFinal;
  /// يمنع منح XP مرتين إن أُعيد استدعاء إنهاء المحاولة
  final bool xpAwarded;

  const ExamAttemptModel({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.startedAt,
    this.finishedAt,
    required this.currentQuestionOrder,
    required this.isFinished,
    required this.scoreAuto,
    required this.scoreManual,
    required this.scoreFinal,
    this.xpAwarded = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'examId': examId,
      'studentId': studentId,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
      'currentQuestionOrder': currentQuestionOrder,
      'isFinished': isFinished,
      'scoreAuto': scoreAuto,
      'scoreManual': scoreManual,
      'scoreFinal': scoreFinal,
      'xpAwarded': xpAwarded,
    };
  }

  factory ExamAttemptModel.fromMap(Map<String, dynamic> map) {
    return ExamAttemptModel(
      id: map['id'] ?? '',
      examId: map['examId'] ?? '',
      studentId: map['studentId'] ?? '',
      startedAt: map['startedAt'] != null ? DateTime.parse(map['startedAt']) : DateTime.now(),
      finishedAt: map['finishedAt'] != null ? DateTime.parse(map['finishedAt']) : null,
      currentQuestionOrder: map['currentQuestionOrder'] ?? 0,
      isFinished: map['isFinished'] ?? false,
      scoreAuto: map['scoreAuto'] ?? 0,
      scoreManual: map['scoreManual'] ?? 0,
      scoreFinal: map['scoreFinal'] ?? 0,
      xpAwarded: map['xpAwarded'] ?? false,
    );
  }

  ExamAttemptModel copyWith({
    String? id,
    String? examId,
    String? studentId,
    DateTime? startedAt,
    DateTime? finishedAt,
    int? currentQuestionOrder,
    bool? isFinished,
    int? scoreAuto,
    int? scoreManual,
    int? scoreFinal,
    bool? xpAwarded,
  }) {
    return ExamAttemptModel(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      studentId: studentId ?? this.studentId,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      currentQuestionOrder: currentQuestionOrder ?? this.currentQuestionOrder,
      isFinished: isFinished ?? this.isFinished,
      scoreAuto: scoreAuto ?? this.scoreAuto,
      scoreManual: scoreManual ?? this.scoreManual,
      scoreFinal: scoreFinal ?? this.scoreFinal,
      xpAwarded: xpAwarded ?? this.xpAwarded,
    );
  }
}
