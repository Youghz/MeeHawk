import 'package:app/features/match_history/persistence/archive_storage.dart';
import 'package:app/features/match_history/persistence/matches_importer_stub.dart'
    if (dart.library.html) 'package:app/features/match_history/persistence/matches_importer_web.dart';

abstract class MatchesImporter {
  static Future<void> importInto(ArchiveStorage storage) =>
      importMatchesFolder(storage);
}
