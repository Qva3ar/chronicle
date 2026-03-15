import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Widget test harness works (smoke test)', (WidgetTester tester) async {
    await tester.pumpWidget(const TestWidget());
    expect(find.text('smoke'), findsOneWidget);
  });
}

class TestWidget extends StatelessWidget {
  const TestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: Text('smoke'),
    );
  }
}
