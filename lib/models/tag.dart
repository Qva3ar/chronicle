import 'package:chrono/db_manager.dart';

class Tag {
  final int id;
  final String name;
  final String? color;

  Tag({
    required this.id,
    required this.name,
    this.color,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json[DatabaseColumns.id],
      name: json[DatabaseColumns.tagName],
      color: json[DatabaseColumns.tagColor],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      DatabaseColumns.id: id,
      DatabaseColumns.tagName: name,
      DatabaseColumns.tagColor: color,
    };
  }

  @override
  String toString() {
    return "name = $name, id = $id"; // Используйте имя тега вместо "Instance of 'Tag'"
  }
}
