import 'notification_model.dart';

class NotificationPreferences {
  // Student notification preferences
  final bool assignmentNew;
  final bool assignmentDeadlineApproaching;
  final bool assignmentDeadlineToday;
  final bool assignmentOverdue;
  final bool submissionReceived;
  final bool submissionGraded;
  final bool gradeLow;
  final bool gradeHigh;
  final bool levelUp;
  final bool badgeEarned;
  final bool streakReminder;

  // Teacher notification preferences
  final bool studentSubmitted;
  final bool lateSubmission;
  final bool allSubmitted;

  // Parent notification preferences
  final bool parentHomeworkNew;
  final bool parentHomeworkMissed;
  final bool parentGradeLow;
  final bool parentImprovement;

  // General preferences
  final bool enabled; // Master switch
  final int? quietHoursStart; // Hour (0-23) when quiet hours start
  final int? quietHoursEnd; // Hour (0-23) when quiet hours end

  NotificationPreferences({
    // Student defaults: all enabled
    this.assignmentNew = true,
    this.assignmentDeadlineApproaching = true,
    this.assignmentDeadlineToday = true,
    this.assignmentOverdue = true,
    this.submissionReceived = true,
    this.submissionGraded = true,
    this.gradeLow = true,
    this.gradeHigh = true,
    this.levelUp = true,
    this.badgeEarned = true,
    this.streakReminder = true,
    // Teacher defaults: all enabled
    this.studentSubmitted = true,
    this.lateSubmission = true,
    this.allSubmitted = true,
    // Parent defaults: all enabled
    this.parentHomeworkNew = true,
    this.parentHomeworkMissed = true,
    this.parentGradeLow = true,
    this.parentImprovement = true,
    // General defaults
    this.enabled = true,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  Map<String, dynamic> toMap() {
    return {
      'assignmentNew': assignmentNew,
      'assignmentDeadlineApproaching': assignmentDeadlineApproaching,
      'assignmentDeadlineToday': assignmentDeadlineToday,
      'assignmentOverdue': assignmentOverdue,
      'submissionReceived': submissionReceived,
      'submissionGraded': submissionGraded,
      'gradeLow': gradeLow,
      'gradeHigh': gradeHigh,
      'levelUp': levelUp,
      'badgeEarned': badgeEarned,
      'streakReminder': streakReminder,
      'studentSubmitted': studentSubmitted,
      'lateSubmission': lateSubmission,
      'allSubmitted': allSubmitted,
      'parentHomeworkNew': parentHomeworkNew,
      'parentHomeworkMissed': parentHomeworkMissed,
      'parentGradeLow': parentGradeLow,
      'parentImprovement': parentImprovement,
      'enabled': enabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      assignmentNew: map['assignmentNew'] ?? true,
      assignmentDeadlineApproaching: map['assignmentDeadlineApproaching'] ?? true,
      assignmentDeadlineToday: map['assignmentDeadlineToday'] ?? true,
      assignmentOverdue: map['assignmentOverdue'] ?? true,
      submissionReceived: map['submissionReceived'] ?? true,
      submissionGraded: map['submissionGraded'] ?? true,
      gradeLow: map['gradeLow'] ?? true,
      gradeHigh: map['gradeHigh'] ?? true,
      levelUp: map['levelUp'] ?? true,
      badgeEarned: map['badgeEarned'] ?? true,
      streakReminder: map['streakReminder'] ?? true,
      studentSubmitted: map['studentSubmitted'] ?? true,
      lateSubmission: map['lateSubmission'] ?? true,
      allSubmitted: map['allSubmitted'] ?? true,
      parentHomeworkNew: map['parentHomeworkNew'] ?? true,
      parentHomeworkMissed: map['parentHomeworkMissed'] ?? true,
      parentGradeLow: map['parentGradeLow'] ?? true,
      parentImprovement: map['parentImprovement'] ?? true,
      enabled: map['enabled'] ?? true,
      quietHoursStart: map['quietHoursStart'],
      quietHoursEnd: map['quietHoursEnd'],
    );
  }

  NotificationPreferences copyWith({
    bool? assignmentNew,
    bool? assignmentDeadlineApproaching,
    bool? assignmentDeadlineToday,
    bool? assignmentOverdue,
    bool? submissionReceived,
    bool? submissionGraded,
    bool? gradeLow,
    bool? gradeHigh,
    bool? levelUp,
    bool? badgeEarned,
    bool? streakReminder,
    bool? studentSubmitted,
    bool? lateSubmission,
    bool? allSubmitted,
    bool? parentHomeworkNew,
    bool? parentHomeworkMissed,
    bool? parentGradeLow,
    bool? parentImprovement,
    bool? enabled,
    int? quietHoursStart,
    int? quietHoursEnd,
  }) {
    return NotificationPreferences(
      assignmentNew: assignmentNew ?? this.assignmentNew,
      assignmentDeadlineApproaching: assignmentDeadlineApproaching ?? this.assignmentDeadlineApproaching,
      assignmentDeadlineToday: assignmentDeadlineToday ?? this.assignmentDeadlineToday,
      assignmentOverdue: assignmentOverdue ?? this.assignmentOverdue,
      submissionReceived: submissionReceived ?? this.submissionReceived,
      submissionGraded: submissionGraded ?? this.submissionGraded,
      gradeLow: gradeLow ?? this.gradeLow,
      gradeHigh: gradeHigh ?? this.gradeHigh,
      levelUp: levelUp ?? this.levelUp,
      badgeEarned: badgeEarned ?? this.badgeEarned,
      streakReminder: streakReminder ?? this.streakReminder,
      studentSubmitted: studentSubmitted ?? this.studentSubmitted,
      lateSubmission: lateSubmission ?? this.lateSubmission,
      allSubmitted: allSubmitted ?? this.allSubmitted,
      parentHomeworkNew: parentHomeworkNew ?? this.parentHomeworkNew,
      parentHomeworkMissed: parentHomeworkMissed ?? this.parentHomeworkMissed,
      parentGradeLow: parentGradeLow ?? this.parentGradeLow,
      parentImprovement: parentImprovement ?? this.parentImprovement,
      enabled: enabled ?? this.enabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }

  // Check if notification type is enabled
  bool isNotificationTypeEnabled(String notificationType) {
    if (!enabled) return false;

    // Check quiet hours
    if (quietHoursStart != null && quietHoursEnd != null) {
      final now = DateTime.now();
      final currentHour = now.hour;
      if (currentHour >= quietHoursStart! || currentHour < quietHoursEnd!) {
        return false; // In quiet hours
      }
    }

    switch (notificationType) {
      case NotificationModel.typeAssignmentNew:
        return assignmentNew;
      case NotificationModel.typeAssignmentDeadlineApproaching:
        return assignmentDeadlineApproaching;
      case NotificationModel.typeAssignmentDeadlineToday:
        return assignmentDeadlineToday;
      case NotificationModel.typeAssignmentOverdue:
        return assignmentOverdue;
      case NotificationModel.typeSubmissionReceived:
        return submissionReceived;
      case NotificationModel.typeSubmissionGraded:
        return submissionGraded;
      case NotificationModel.typeGradeLow:
        return gradeLow;
      case NotificationModel.typeGradeHigh:
        return gradeHigh;
      case NotificationModel.typeLevelUp:
        return levelUp;
      case NotificationModel.typeBadgeEarned:
        return badgeEarned;
      case NotificationModel.typeStreakReminder:
        return streakReminder;
      case NotificationModel.typeStudentSubmitted:
        return studentSubmitted;
      case NotificationModel.typeLateSubmission:
        return lateSubmission;
      case NotificationModel.typeAllSubmitted:
        return allSubmitted;
      case NotificationModel.typeParentHomeworkNew:
        return parentHomeworkNew;
      case NotificationModel.typeParentHomeworkMissed:
        return parentHomeworkMissed;
      case NotificationModel.typeParentGradeLow:
        return parentGradeLow;
      case NotificationModel.typeParentImprovement:
        return parentImprovement;
      default:
        return true; // Default to enabled for unknown types
    }
  }
}
