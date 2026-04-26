import 'package:app/app.dart';
import 'package:app/features/match/persistence/match_storage.dart';
import 'package:app/features/match/persistence/match_storage_provider.dart';
import 'package:app/features/match_history/persistence/archive_storage.dart';
import 'package:app/features/match_history/persistence/archive_storage_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App renders home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await MatchStorage.open();
    final archiveStorage = await ArchiveStorage.open();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchStorageProvider.overrideWithValue(storage),
          archiveStorageProvider.overrideWithValue(archiveStorage),
        ],
        child: const MeeHawkApp(),
      ),
    );
    expect(find.text('MeeHawk'), findsOneWidget);
    expect(find.text('Beach volley — scoring live'), findsOneWidget);
    expect(find.text('Nouvelle partie'), findsOneWidget);
  });
}
