import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chrono/main.dart' show ignoreDisplayFeatures;

/// Some devices report a display feature spanning the full screen height, which
/// makes Flutter confine dialogs and bottom sheets to one side of it. Without
/// [ignoreDisplayFeatures] the settings popups render at half width or less,
/// wrapping text mid-word.
void main() {
  const screenWidth = 360.0;
  const screenHeight = 800.0;

  Widget app({required bool applyFix}) {
    return MaterialApp(
      builder: applyFix ? ignoreDisplayFeatures : null,
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AlertDialog(
                    title: Text('Sunrise correction'),
                    content: Text('If the calculated times differ.'),
                  ),
                ),
                child: const Text('dialog'),
              ),
              ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const SizedBox(height: 200),
                ),
                child: const Text('sheet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<(Rect dialog, Rect sheet)> openPopups(WidgetTester tester) async {
    await tester.tap(find.text('dialog'));
    await tester.pumpAndSettle();
    final dialog = tester.getRect(
      find
          .descendant(of: find.byType(AlertDialog), matching: find.byType(Material))
          .first,
    );
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('sheet'));
    await tester.pumpAndSettle();
    final sheet = tester.getRect(find.byType(BottomSheet));
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();

    return (dialog, sheet);
  }

  void useFoldedScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(screenWidth * 3, screenHeight * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.view.displayFeatures = <DisplayFeature>[
      const DisplayFeature(
        bounds: Rect.fromLTRB(
          screenWidth / 2,
          0,
          screenWidth / 2,
          screenHeight,
        ),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureHalfOpened,
      ),
    ];
    addTearDown(tester.view.reset);
  }

  testWidgets('a full-height display feature squashes popups by default',
      (tester) async {
    useFoldedScreen(tester);
    await tester.pumpWidget(app(applyFix: false));

    final (dialog, sheet) = await openPopups(tester);

    expect(dialog.right, lessThanOrEqualTo(screenWidth / 2));
    expect(sheet.width, screenWidth / 2);
  });

  testWidgets('ignoreDisplayFeatures gives popups the whole screen',
      (tester) async {
    useFoldedScreen(tester);
    await tester.pumpWidget(app(applyFix: true));

    final (dialog, sheet) = await openPopups(tester);

    // Material's standard dialog inset is 40 per side.
    expect(dialog.width, screenWidth - 80);
    expect(dialog.center.dx, screenWidth / 2);
    expect(sheet.width, screenWidth);
  });
}
