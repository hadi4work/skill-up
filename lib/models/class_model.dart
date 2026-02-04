class ClassModel {
  final String id;
  final String name;
  final String section;
  final String teacherId;
  final List<String> studentCodes; // List of student codes
  final DateTime createdAt;

  ClassModel({
    required this.id,
    required this.name,
    required this.section,
    required this.teacherId,
    required this.studentCodes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'section': section,
      'teacherId': teacherId,
      'studentCodes': studentCodes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ClassModel.fromMap(Map<String, dynamic> map) {
    return ClassModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      section: map['section'] ?? '',
      teacherId: map['teacherId'] ?? '',
      studentCodes: map['studentCodes'] != null
          ? List<String>.from(map['studentCodes'])
          : [],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  ClassModel copyWith({
    String? name,
    String? section,
    List<String>? studentCodes,
  }) {
    return ClassModel(
      id: id,
      name: name ?? this.name,
      section: section ?? this.section,
      teacherId: teacherId,
      studentCodes: studentCodes ?? this.studentCodes,
      createdAt: createdAt,
    );
  }
}
