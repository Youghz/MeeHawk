/// Which half of the court a team occupies. The enum values are the storage
/// keys used in JSON snapshots — keep them stable.
enum TeamSide {
  e1,
  e2;

  TeamSide get other => this == e1 ? e2 : e1;
  String get key => name;

  static TeamSide fromKey(String k) => switch (k) {
        'e1' => e1,
        'e2' => e2,
        _ => throw ArgumentError('Unknown TeamSide key: $k'),
      };
}
