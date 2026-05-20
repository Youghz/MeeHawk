// Web-only conditional import: this file is never compiled on non-web targets.
// dart:html is deprecated in favor of package:web, but transitioning is out of scope here.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:app/features/match_history/persistence/archive_storage.dart';

Future<void> importMatchesFolder(ArchiveStorage storage) async {
  try {
    final req = await html.HttpRequest.request(
      '/matches/archives.json',
      method: 'GET',
    );
    if (req.status != 200) return;
    final body = req.responseText;
    if (body == null || body.isEmpty) return;
    final imported = ArchiveStorage.decodeAll(body);
    final existingIds = storage.loadAll().map((a) => a.id).toSet();
    for (final archive in imported) {
      if (!existingIds.contains(archive.id)) {
        await storage.upsert(archive);
      }
    }
  } on Object {
    // File absent or server not running — silently skip.
  }
}
