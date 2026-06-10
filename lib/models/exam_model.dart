class ExamModel {
  final String id;
  final String teacherId;
  final String subject;
  final String title;
  final String? notes;
  final List<String> classIds;
  final DateTime startAt;
  final DateTime endAt;
  final bool isPublished;
  final DateTime createdAt;
  final int questionCount;
  final String status; // draft | published | closed
  final String assessmentType; // exam | assignment

  const ExamModel({
    required this.id,
    required this.teacherId,
    required this.subject,
    required this.title,
    this.notes,
    required this.classIds,
    required this.startAt,
    required this.endAt,
    required this.isPublished,
    required this.createdAt,
    required this.questionCount,
    required this.status,
    this.assessmentType = 'exam',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'subject': subject,
      'title': title,
      'notes': notes,
      'classIds': classIds,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'isPublished': isPublished,
      'createdAt': createdAt.toIso8601String(),
      'questionCount': questionCount,
      'status': status,
      'assessmentType': assessmentType,
    };
  }

  factory ExamModel.fromMap(Map<String, dynamic> map) {
    return ExamModel(
      id: map['id'] ?? '',
      teacherId: map['teacherId'] ?? '',
      subject: map['subject'] ?? '',
      title: map['title'] ?? '',
      notes: map['notes'],
      classIds: map['classIds'] != null ? List<String>.from(map['classIds']) : const [],
      startAt: map['startAt'] != null ? DateTime.parse(map['startAt']) : DateTime.now(),
      endAt: map['endAt'] != null ? DateTime.parse(map['endAt']) : DateTime.now(),
      isPublished: map['isPublished'] ?? false,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      questionCount: map['questionCount'] ?? 0,
      status: map['status'] ?? 'draft',
      assessmentType: map['assessmentType'] ?? 'exam',
    );
  }

  ExamModel copyWith({
    String? id,
    String? teacherId,
    String? subject,
    String? title,
    String? notes,
    List<String>? classIds,
    DateTime? startAt,
    DateTime? endAt,
    bool? isPublished,
    DateTime? createdAt,
    int? questionCount,
    String? status,
    String? assessmentType,
  }) {
    return ExamModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      subject: subject ?? this.subject,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      classIds: classIds ?? this.classIds,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      questionCount: questionCount ?? this.questionCount,
      status: status ?? this.status,
      assessmentType: assessmentType ?? this.assessmentType,
    );
  }
}
