import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:findme_flutter/main.dart';

void main() {
  testWidgets('App boots to the sign-in screen when unauthenticated', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FindMeApp()));
    await tester.pumpAndSettle();

    expect(find.text('FINDME'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
