class AssignmentModel {
  final String id;
  final String title;
  final String subject;
  final String? notes;
  final String assignmentImageUrl; // URL of scanned assignment image
  final String teacherId;
  final List<String> classIds; // List of class IDs
  final DateTime deadline;
  final DateTime createdAt;
  final int totalPoints; // Total points (e.g., 100)

  AssignmentModel({
    required this.id,
    required this.title,
    required this.subject,
    this.notes,
    required this.assignmentImageUrl,
    required this.teacherId,
    required this.classIds,
    required this.deadline,
    required this.createdAt,
    this.totalPoints = 100,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'notes': notes,
      'assignmentImageUrl': assignmentImageUrl,
      'teacherId': teacherId,
      'classIds': classIds,
      'deadline': deadline.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'totalPoints': totalPoints,
    };
  }

  factory AssignmentModel.fromMap(Map<String, dynamic> map) {
    return AssignmentModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      subject: map['subject'] ?? '',
      notes: map['notes'],
      assignmentImageUrl: map['assignmentImageUrl'] ?? '',
      teacherId: map['teacherId'] ?? '',
      classIds: map['classIds'] != null
          ? List<String>.from(map['classIds'])
          : [],
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'])
          : DateTime.now(),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      totalPoints: map['totalPoints'] ?? 100,
    );
  }

  AssignmentModel copyWith({
    String? id,
    String? title,
    String? subject,
    String? notes,
    String? assignmentImageUrl,
    List<String>? classIds,
    DateTime? deadline,
    DateTime? createdAt,
    int? totalPoints,
  }) {
    return AssignmentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      notes: notes ?? this.notes,
      assignmentImageUrl: assignmentImageUrl ?? this.assignmentImageUrl,
      teacherId: teacherId,
      classIds: classIds ?? this.classIds,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      totalPoints: totalPoints ?? this.totalPoints,
    );
  }
}
