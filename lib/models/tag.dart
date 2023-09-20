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
      id: json['_id'],
      name: json['name'],
      color: json['color'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
    };
  }

  @override
  String toString() {
    return "name = $name, id = $id"; // Используйте имя тега вместо "Instance of 'Tag'"
  }
}
