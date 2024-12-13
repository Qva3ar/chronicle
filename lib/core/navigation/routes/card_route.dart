import 'package:Chrono/core/navigation/routes/home_route.dart';

class CardRoute {
  static const String name = 'card';
  static const int? idKeyArg = 0;
  static const String titleKeyArg = 'title';
  static const String textKeyArg = 'text';
  static const List<int>? tagsKeyArg = [];
  static const bool isGeneratedKeyArg = false;

  static String getRouteWithArgs(
      int? id, String title, String text, List<int>? tags, bool isGenerated) {
    final buffer = StringBuffer(
        '${HomeRoute.name}$name?$titleKeyArg=$title&$textKeyArg=$text&$isGeneratedKeyArg=$isGenerated');
    if (id != null) {
      buffer.write('&$idKeyArg=$id');
    }
    if (tags != null) {
      buffer.write('&$tagsKeyArg=$tags');
    }
    return buffer.toString();
  }
}
