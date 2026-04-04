import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/app.dart';

void main() {
  testWidgets('App renders with tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MeeHawkApp()));
    expect(find.text('MeeHawk'), findsOneWidget);
    expect(find.text('Manual Analysis'), findsOneWidget);
    expect(find.text('Video Analysis'), findsOneWidget);
  });
}
