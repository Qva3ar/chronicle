import 'package:intl/intl.dart';

class Record {
  int id;
  String title;
  String text;
  List<int> tagIds;
  String createdAt;

  Record({
    required this.id,
    required this.title,
    required this.text,
    required this.tagIds,
    required this.createdAt,
  });

  // Добавьте метод для сериализации объекта в Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'text': text,
      'tagIds': tagIds.join(','), // Преобразуем список ID тегов в строку
      'createdAt': createdAt,
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
    ;

    int millisecondsSinceEpoch =
        map['created_at']; // Replace this with your milliseconds value
    DateTime dateTime =
        DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
    String formattedDateTime =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);

    return Record(
      id: map['_id'],
      title: map['title'] ?? '',
      text: map['text'] ?? '',
      tagIds: tagIds,
      createdAt: formattedDateTime,
    );
  }
}
