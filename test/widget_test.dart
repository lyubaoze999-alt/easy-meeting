import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Chinese product copy renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('会议纪要'))),
    );
    expect(find.text('会议纪要'), findsOneWidget);
  });
}
