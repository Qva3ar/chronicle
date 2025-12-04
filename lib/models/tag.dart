import 'package:chrono/db_manager.dart';

class Tag {
  final int id;
  final String name;
  final String? color;
  final bool isSystem;

  Tag({
    required this.id,
    required this.name,
    this.color,
    this.isSystem = false,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json[DatabaseColumns.id],
      name: json[DatabaseColumns.tagName],
      color: json[DatabaseColumns.tagColor],
      isSystem: (json[DatabaseColumns.tagIsSystem] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      DatabaseColumns.id: id,
      DatabaseColumns.tagName: name,
      DatabaseColumns.tagColor: color,
      DatabaseColumns.tagIsSystem: isSystem ? 1 : 0,
    };
  }

  @override
  String toString() {
    return "name = $name, id = $id"; // Используйте имя тега вместо "Instance of 'Tag'"
  }
}
