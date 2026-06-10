class UserModel {
  final String uid;
  final String name;
  final String email;
  final String accountType; // 'student', 'teacher', 'parent'
  final DateTime createdAt;
  final String? profileImage;
  /// ذكر: male | أنثى: female (اختياري للحسابات القديمة)
  final String? gender;
  
  // للطالب
  final String? studentCode;
  final String? parentId;
  
  // للمعلم
  final String? teacherId;
  
  // لولي الأمر
  final String? parentIdField;
  final List<String>? children;
  final int xp; // Experience points for students
  final int level; // Level based on XP
  final List<String>? classIds; // Class IDs for students

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.accountType,
    required this.createdAt,
    this.profileImage,
    this.gender,
    this.studentCode,
    this.parentId,
    this.teacherId,
    this.parentIdField,
    this.children,
    this.xp = 0,
    this.level = 1,
    this.classIds,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'accountType': accountType,
      'createdAt': createdAt.toIso8601String(),
      'profileImage': profileImage,
      'gender': gender,
      'studentCode': studentCode,
      'parentId': parentId,
      'teacherId': teacherId,
      'parentIdField': parentIdField,
      'children': children,
      'xp': xp,
      'level': level,
      'classIds': classIds,
    };
  }

  // Create from Map (from Firestore)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      accountType: map['accountType'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      profileImage: map['profileImage'],
      gender: map['gender'] as String?,
      studentCode: map['studentCode'],
      parentId: map['parentId'],
      teacherId: map['teacherId'],
      parentIdField: map['parentIdField'],
      children: map['children'] != null
          ? List<String>.from(map['children'])
          : null,
      xp: map['xp'] ?? 0,
      level: map['level'] ?? 1,
      classIds: map['classIds'] != null
          ? List<String>.from(map['classIds'])
          : null,
    );
  }

  // Create from Firebase Auth User
  factory UserModel.fromFirebaseUser({
    required String uid,
    required String name,
    required String email,
    required String accountType,
  }) {
    return UserModel(
      uid: uid,
      name: name,
      email: email,
      accountType: accountType,
      createdAt: DateTime.now(),
    );
  }

  // Copy with method for updates
  UserModel copyWith({
    String? name,
    String? email,
    String? profileImage,
    String? gender,
    String? studentCode,
    String? parentId,
    String? teacherId,
    String? parentIdField,
    List<String>? children,
    int? xp,
    int? level,
    List<String>? classIds,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      accountType: accountType,
      createdAt: createdAt,
      profileImage: profileImage ?? this.profileImage,
      gender: gender ?? this.gender,
      studentCode: studentCode ?? this.studentCode,
      parentId: parentId ?? this.parentId,
      teacherId: teacherId ?? this.teacherId,
      parentIdField: parentIdField ?? this.parentIdField,
      children: children ?? this.children,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      classIds: classIds ?? this.classIds,
    );
  }

  // Calculate level from XP
  // Level 1: 1000 XP
  // Level 2: 3000 XP
  // Level 3: 6000 XP
  // Level 4: 12000 XP
  // Level 5: 24000 XP
  // Level 6: 48000 XP
  // Level 7: 96000 XP
  // Level 8: 192000 XP
  // Level 9: 384000 XP
  // Level 10: 768000 XP
  // Pattern: Level N requires 1000 × (3 × 2^(N-2)) for N >= 2, Level 1 requires 1000
  int calculateLevel(int xp) {
    if (xp < 1000) return 1; // Level 1: 0-999 XP
    if (xp < 3000) return 2; // Level 2: 1000-2999 XP
    if (xp < 6000) return 3; // Level 3: 3000-5999 XP
    if (xp < 12000) return 4; // Level 4: 6000-11999 XP
    if (xp < 24000) return 5; // Level 5: 12000-23999 XP
    if (xp < 48000) return 6; // Level 6: 24000-47999 XP
    if (xp < 96000) return 7; // Level 7: 48000-95999 XP
    if (xp < 192000) return 8; // Level 8: 96000-191999 XP
    if (xp < 384000) return 9; // Level 9: 192000-383999 XP
    if (xp < 768000) return 10; // Level 10: 384000-767999 XP
    return 10; // Max level reached
  }
  
  // Get XP required for current level (minimum XP needed)
  int getXPRequiredForLevel(int level) {
    if (level <= 1) return 0;
    if (level == 2) return 1000;
    if (level == 3) return 3000;
    if (level == 4) return 6000;
    if (level == 5) return 12000;
    if (level == 6) return 24000;
    if (level == 7) return 48000;
    if (level == 8) return 96000;
    if (level == 9) return 192000;
    if (level == 10) return 384000;
    return 768000; // Level 11+ (max)
  }
  
  // Get XP required for next level
  int getXPRequiredForNextLevel() {
    if (level >= 10) return 0; // Max level reached
    return getXPRequiredForLevel(level + 1);
  }
  
  // Get XP needed to reach next level (difference)
  int getXPNeededForNextLevel() {
    if (level >= 10) return 0; // Max level reached
    int currentLevelMinXP = getXPRequiredForLevel(level);
    int nextLevelMinXP = getXPRequiredForLevel(level + 1);
    return nextLevelMinXP - currentLevelMinXP;
  }
  
  // Get XP progress to next level (0.0 to 1.0)
  double getXPProgressToNextLevel() {
    if (level >= 10) return 1.0; // Max level reached
    int currentLevelMinXP = getXPRequiredForLevel(level);
    int nextLevelMinXP = getXPRequiredForLevel(level + 1);
    int xpInCurrentLevel = xp - currentLevelMinXP;
    int xpNeededForNextLevel = nextLevelMinXP - currentLevelMinXP;
    return (xpInCurrentLevel / xpNeededForNextLevel).clamp(0.0, 1.0);
  }
}
