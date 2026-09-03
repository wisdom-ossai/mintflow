import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowra_flutter/core/theme/app_theme.dart';

void main() {
  testWidgets('Mintflow theme smoke — MaterialApp builds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FlowraTheme.light,
        home: const Scaffold(
          body: Center(child: Text('Mintflow')),
        ),
      ),
    );
    expect(find.text('Mintflow'), findsOneWidget);
  });
}
