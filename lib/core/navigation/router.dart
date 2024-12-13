import 'dart:convert';

import 'package:Chrono/chat_page.dart';
import 'package:Chrono/core/navigation/routes/card_route.dart';
import 'package:Chrono/core/navigation/routes/chat_route.dart';
import 'package:Chrono/core/navigation/routes/health_center_route.dart';
import 'package:Chrono/core/navigation/routes/health_reminder_route.dart';
import 'package:Chrono/core/navigation/routes/home_route.dart';
import 'package:Chrono/features/health_center/presentation/screen/health_center_page.dart';
import 'package:Chrono/features/health_reminder/presentation/screen/health_reminder_page.dart';
import 'package:Chrono/features/start/presentation/screen/start_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/notes/presentation/screen/card_details.dart';
import '../../features/notes/presentation/screen/home_page.dart';

class ChronoRouter {
  final GoRouter router = GoRouter(
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, child) => StartPage(navigationShell: child),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: HomeRoute.name,
                pageBuilder: (context, state) => MaterialPage(child: HomePage()),
                routes: [
                  GoRoute(
                      name: CardRoute.name,
                      path: CardRoute.name,
                      pageBuilder: (context, state) {
                        final id = state.uri.queryParameters[CardRoute.idKeyArg];
                        final title = state.uri.queryParameters[CardRoute.titleKeyArg] ?? '';
                        final text = state.uri.queryParameters[CardRoute.textKeyArg] ?? '';
                        final tags = state.uri.queryParameters[CardRoute.tagsKeyArg] ?? '';
                        final isGenerated =
                            state.uri.queryParameters[CardRoute.isGeneratedKeyArg] ?? '';

                        final parsedId = id == null ? null : int.parse(id);
                        List<int> tagsList = tags == '' ? [] : List<int>.from(jsonDecode(tags));
                        final parsedIsGenerated = isGenerated == 'true' ? true : false;
                        return MaterialPage(
                            child: CardDetailPage(
                          recordId: parsedId,
                          title: title,
                          text: text,
                          recordsTag: tagsList,
                          isGenerated: parsedIsGenerated,
                        ));
                      }),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: HealthCenterRoute.name,
                pageBuilder: (context, state) => const MaterialPage(
                  child: HealthCenterPage(),
                ),
                routes: [
                  GoRoute(
                    name: HealthReminderRoute.name,
                    path: HealthReminderRoute.name,
                    pageBuilder: (context, state) {
                      final id = state.uri.queryParameters[HealthReminderRoute.idKeyArg];
                      return MaterialPage(
                        child: HealthReminderPage(id: id),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ChatRoute.name,
                pageBuilder: (context, state) => MaterialPage(child: ChatPage()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
