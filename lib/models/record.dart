import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

class Record extends Equatable {
  int id;
  String title;
  String text;
  List<int> tagIds;
  String createdAt;
  bool isGenerated;

  Record({
    required this.id,
    required this.title,
    required this.text,
    required this.tagIds,
    required this.createdAt,
    required this.isGenerated,
  });

  // Добавьте метод для сериализации объекта в Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'text': text,
      'tagIds': tagIds.join(','), // Преобразуем список ID тегов в строку
      'createdAt': createdAt,
      'isGenerated': isGenerated ? 1 : 0,
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

    int millisecondsSinceEpoch = map['created_at']; // Replace this with your milliseconds value
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
    String formattedDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);

    return Record(
      id: map['_id'],
      title: map['title'] ?? '',
      text: map['text'] ?? '',
      tagIds: tagIds,
      createdAt: formattedDateTime,
      isGenerated: map['isGenerated'] == 1 ? true : false,
    );
  }

  DateTime get createdAtDate {
    return DateFormat('yyyy-MM-dd HH:mm:ss').parse(createdAt);
  }

  @override
  List<Object?> get props => [
        id,
        title,
        text,
        tagIds,
        createdAt,
        isGenerated,
      ];
}
