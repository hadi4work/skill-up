class SubmissionModel {
  final String id;
  final String assignmentId;
  final String studentId;
  final String studentCode;
  final String submissionImageUrl; // URL of scanned solution image
  final DateTime submittedAt;
  final int? grade; // Grade given by teacher (null if not graded yet)
  final DateTime? gradedAt;
  final bool isGraded;
  final int xpEarned; // XP earned (5 for submission + grade points)

  SubmissionModel({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.studentCode,
    required this.submissionImageUrl,
    required this.submittedAt,
    this.grade,
    this.gradedAt,
    this.isGraded = false,
    this.xpEarned = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'assignmentId': assignmentId,
      'studentId': studentId,
      'studentCode': studentCode,
      'submissionImageUrl': submissionImageUrl,
      'submittedAt': submittedAt.toIso8601String(),
      'grade': grade,
      'gradedAt': gradedAt?.toIso8601String(),
      'isGraded': isGraded,
      'xpEarned': xpEarned,
    };
  }

  factory SubmissionModel.fromMap(Map<String, dynamic> map) {
    return SubmissionModel(
      id: map['id'] ?? '',
      assignmentId: map['assignmentId'] ?? '',
      studentId: map['studentId'] ?? '',
      studentCode: map['studentCode'] ?? '',
      submissionImageUrl: map['submissionImageUrl'] ?? '',
      submittedAt: map['submittedAt'] != null
          ? DateTime.parse(map['submittedAt'])
          : DateTime.now(),
      grade: map['grade'],
      gradedAt: map['gradedAt'] != null
          ? DateTime.parse(map['gradedAt'])
          : null,
      isGraded: map['isGraded'] ?? false,
      xpEarned: map['xpEarned'] ?? 0,
    );
  }

  SubmissionModel copyWith({
    String? submissionImageUrl,
    int? grade,
    DateTime? gradedAt,
    bool? isGraded,
    int? xpEarned,
  }) {
    return SubmissionModel(
      id: id,
      assignmentId: assignmentId,
      studentId: studentId,
      studentCode: studentCode,
      submissionImageUrl: submissionImageUrl ?? this.submissionImageUrl,
      submittedAt: submittedAt,
      grade: grade ?? this.grade,
      gradedAt: gradedAt ?? this.gradedAt,
      isGraded: isGraded ?? this.isGraded,
      xpEarned: xpEarned ?? this.xpEarned,
    );
  }
}
