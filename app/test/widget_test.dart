import 'package:app/app.dart';
import 'package:app/features/auth/auth_providers.dart';
import 'package:app/features/match/persistence/match_storage.dart';
import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/persistence/archive_storage_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App renders home screen when signed in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await MatchStorage.open();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchStorageProvider.overrideWithValue(storage),
          // Bypass Firebase Auth — simulate a signed-in user.
          authStateProvider.overrideWith(
            (_) => Stream.value(_FakeUser()),
          ),
          // Bypass Firestore in unit tests — no Firebase initialized.
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

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'test-uid';

  @override
  String? get photoURL => null;
}
