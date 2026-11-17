// AURA Player widget test
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_player/app.dart';

void main() {
  testWidgets('AuraApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AuraApp()));
    expect(find.text('AURA Player'), findsWidgets);
  });
}
