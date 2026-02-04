class NotificationModel {
  final String id;
  final String userId; // User ID (Student, Teacher, or Parent)
  final String title;
  final String body;
  final String type; // Notification type (see NotificationType constants)
  final String? assignmentId;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt; // Timestamp when notification was read
  final String priority; // 'high', 'default', 'low'
  final String? actionType; // Navigation action type
  final Map<String, dynamic>? metadata; // Additional data

  // Notification type constants
  static const String typeAssignmentNew = 'assignment_new';
  static const String typeAssignmentDeadlineApproaching = 'assignment_deadline_approaching';
  static const String typeAssignmentDeadlineToday = 'assignment_deadline_today';
  static const String typeAssignmentOverdue = 'assignment_overdue';
  static const String typeSubmissionReceived = 'submission_received';
  static const String typeSubmissionGraded = 'submission_graded';
  static const String typeGradeLow = 'grade_low';
  static const String typeGradeHigh = 'grade_high';
  static const String typeLevelUp = 'level_up';
  static const String typeBadgeEarned = 'badge_earned';
  static const String typeStreakReminder = 'streak_reminder';
  static const String typeStudentSubmitted = 'student_submitted';
  static const String typeLateSubmission = 'late_submission';
  static const String typeAllSubmitted = 'all_submitted';
  static const String typeParentHomeworkNew = 'parent_homework_new';
  static const String typeParentHomeworkMissed = 'parent_homework_missed';
  static const String typeParentGradeLow = 'parent_grade_low';
  static const String typeParentImprovement = 'parent_improvement';
  static const String typeClassAdded = 'class_added';
  static const String typeIncompleteAssignment = 'incomplete_assignment';

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.assignmentId,
    required this.createdAt,
    this.isRead = false,
    this.readAt,
    this.priority = 'default',
    this.actionType,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'assignmentId': assignmentId,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'priority': priority,
      'actionType': actionType,
      'metadata': metadata,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? '',
      assignmentId: map['assignmentId'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
      readAt: map['readAt'] != null
          ? DateTime.parse(map['readAt'])
          : null,
      priority: map['priority'] ?? 'default',
      actionType: map['actionType'],
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
    );
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    String? assignmentId,
    DateTime? createdAt,
    bool? isRead,
    DateTime? readAt,
    String? priority,
    String? actionType,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      assignmentId: assignmentId ?? this.assignmentId,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      priority: priority ?? this.priority,
      actionType: actionType ?? this.actionType,
      metadata: metadata ?? this.metadata,
    );
  }
}
