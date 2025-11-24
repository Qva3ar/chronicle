import 'package:chrono/db_manager.dart';

class Record {
  int id;
  String title;
  String text;
  List<int> tagIds;
  int createdAt;
  String recordType;
  int? goalId;
  int? routineId;
  bool isLocked;

  Record({
    required this.id,
    required this.title,
    required this.text,
    required this.tagIds,
    required this.createdAt,
    this.recordType = 'regular',
    this.goalId,
    this.routineId,
    this.isLocked = false,
  });

  // Добавьте метод для сериализации объекта в Map
  Map<String, dynamic> toMap() {
    return {
      DatabaseColumns.id: id,
      DatabaseColumns.recordTitle: title,
      DatabaseColumns.recordText: text,
      'tagIds': tagIds.join(','), // Преобразуем список ID тегов в строку
      DatabaseColumns.recordCreatedAt: createdAt,
      DatabaseColumns.recordType: recordType,
      DatabaseColumns.recordGoalId: goalId,
      DatabaseColumns.recordRoutineId: routineId,
      DatabaseColumns.recordIsLocked: isLocked ? 1 : 0,
    };
  }

  // Добавьте фабричный метод для создания объекта Record из Map
  factory Record.fromMap(Map<String, dynamic> map) {
    List<int> tagIds = [];
    if (map['tags'] != null) {
      tagIds = (map['tags'] as String)
          .replaceAll('[', '')
          .replaceAll(']', '')
          .split(',')
          .where((element) => element.isNotEmpty)
          .map((e) => int.parse(e))
          .toList();
    }

    return Record(
      id: map[DatabaseColumns.id],
      title: map[DatabaseColumns.recordTitle] ?? '',
      text: map[DatabaseColumns.recordText] ?? '',
      tagIds: tagIds,
      createdAt: map[DatabaseColumns.recordCreatedAt],
      recordType: map[DatabaseColumns.recordType] ?? 'regular',
      goalId: map[DatabaseColumns.recordGoalId],
      routineId: map[DatabaseColumns.recordRoutineId],
      isLocked: (map[DatabaseColumns.recordIsLocked] ?? 0) == 1,
    );
  }

  DateTime get createdAtDate {
    return DateTime.fromMillisecondsSinceEpoch(createdAt);
  }
}
