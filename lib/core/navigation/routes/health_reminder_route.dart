import 'package:Chrono/core/navigation/routes/health_center_route.dart';

class HealthReminderRoute {
  static const String name = 'health_reminder';
  static const idKeyArg = 'id';

  static String getRouteWithArgs(String id) {
    return '${HealthCenterRoute.name}/$name?$idKeyArg=$id';
  }

  static String get navigateRoute => '${HealthCenterRoute.name}/$name';
}
