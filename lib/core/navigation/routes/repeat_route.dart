import 'package:Chrono/core/navigation/routes/health_reminder_route.dart';

class RepeatRoute {
  static const String name = 'repeat';
  static const List<String>? modesKeyArg = [];
  static const List<int>? isSelectedKeyArg = [];

  // static String getRouteWithArgs(List<String> modes, List<int> isSelected) {
  //   print('FROM PAGE DATA\n MODES====$modes\n ISLOADING === $isSelected}');
  //   return '${HealthReminderRoute.navigateRoute}/$name?$modesKeyArg=$modes&$isSelectedKeyArg=$isSelected';
  // }

  static String get navigateRoute => '${HealthReminderRoute.navigateRoute}/$name';
}
