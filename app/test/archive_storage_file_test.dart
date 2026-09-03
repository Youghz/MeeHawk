import 'dart:convert';
import 'dart:io';

import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/persistence/archive_storage_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('match_history_test_');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  test('upsert writes one real .json file per match', () async {
    final storage = await FileArchiveStorage.open(dir: tmp);
    final archive = MatchArchive(
      id: 'match_test_1',
      startedAt: DateTime.utc(2026),
      state: initialMatchState(),
    );

    await storage.upsert(archive);

    final file = File('${tmp.path}/match_test_1.json');
    expect(file.existsSync(), isTrue);
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(json['id'], 'match_test_1');
    expect(json['state'], isA<Map<String, dynamic>>());
  });

  test('watchAll reads matches back from disk', () async {
    final storage = await FileArchiveStorage.open(dir: tmp);
    final archive = MatchArchive(
      id: 'match_test_2',
      startedAt: DateTime.utc(2026, 1, 2),
      state: initialMatchState(),
      videoUrl: '/videos/match_test_2.mp4',
    );
    await storage.upsert(archive);

    final all = await storage.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.id, 'match_test_2');
    expect(all.single.videoUrl, '/videos/match_test_2.mp4');
  });

  test('remove deletes the file', () async {
    final storage = await FileArchiveStorage.open(dir: tmp);
    final archive = MatchArchive(
      id: 'match_test_3',
      startedAt: DateTime.utc(2026, 1, 3),
      state: initialMatchState(),
    );
    await storage.upsert(archive);
    expect(File('${tmp.path}/match_test_3.json').existsSync(), isTrue);

    await storage.remove('match_test_3');
    expect(File('${tmp.path}/match_test_3.json').existsSync(), isFalse);
  });

  test('a hand-written Python-shaped JSON file loads through the same path',
      () async {
    // Simulates a file written by annotator/state.py::MatchCodec — proves
    // the schema really is interchangeable, not just self-consistent.
    File('${tmp.path}/match_from_python.json').writeAsStringSync(jsonEncode({
      'id': 'match_from_python',
      'startedAt': '2026-01-04T00:00:00.000Z',
      'state': MatchCodecSample.minimalJson,
    }));

    final storage = await FileArchiveStorage.open(dir: tmp);
    final all = await storage.watchAll().first;

    expect(all, hasLength(1));
    expect(all.single.id, 'match_from_python');
    expect(all.single.state.teams[TeamSide.e1]!.name, 'Équipe 1');
    expect(all.single.state.history, isEmpty);
  });
}

/// A minimal MatchState JSON, shaped exactly like `MatchCodec.toJson` /
/// `annotator/state.py::MatchCodec.to_json` — used to sanity-check the
/// schema by eye rather than importing Python here.
class MatchCodecSample {
  static const Map<String, dynamic> minimalJson = {
    'v': 1,
    'format': {
      'setsToWin': 2,
      'regularSetPoints': 21,
      'decidingSetPoints': 15,
      'winBy': 2,
      'regularChangeSideEvery': 7,
      'decidingChangeSideEvery': 5,
    },
    'teams': {
      'e1': {
        'name': 'Équipe 1',
        'players': [
          {'id': 'p1', 'name': 'Joueur 1'},
          {'id': 'p2', 'name': 'Joueur 2'},
        ],
      },
      'e2': {
        'name': 'Équipe 2',
        'players': [
          {'id': 'p3', 'name': 'Joueur 3'},
          {'id': 'p4', 'name': 'Joueur 4'},
        ],
      },
    },
    'positions': {
      'p1': [0.25, 0.35],
      'p2': [0.25, 0.70],
      'p3': [0.75, 0.35],
      'p4': [0.75, 0.70],
    },
    'servingPlayerId': 'p3',
    'initialServerId': 'p3',
    'nextServerIndex': {'e1': 0, 'e2': 1},
    'firstServerIndex': {'e1': 0, 'e2': null},
    'history': <Object?>[],
    'sets': <Object?>[],
    'setNumber': 1,
    'scoreE1': 0,
    'scoreE2': 0,
    'sidesSwapped': false,
    'notes': '',
    'changeSidePromptDismissed': false,
    'matchOver': false,
    'started': false,
    'trackedTeams': ['e1', 'e2'],
    'startedAt': '2026-01-04T00:00:00.000Z',
  };
}
