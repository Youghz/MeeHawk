import 'package:app/app.dart';
import 'package:app/data/match_storage.dart';
import 'package:app/domain/match_archive.dart';
import 'package:app/state/archive_provider.dart';
import 'package:app/state/match_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App renders home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await MatchStorage.open();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchStorageProvider.overrideWithValue(storage),
          archiveListProvider.overrideWith(_EmptyArchiveNotifier.new),
        ],
        child: const CrabCoachApp(),
      ),
    );
    await tester.pump();
    expect(find.text('CRABCOACH'), findsOneWidget);
    expect(find.text('NOUVELLE PARTIE'), findsOneWidget);
  });
}

class _EmptyArchiveNotifier extends ArchiveListNotifier {
  @override
  List<MatchArchive> build() => [];
}
