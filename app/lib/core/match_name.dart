const _adjectives = [
  'Agile', 'Brave', 'Calme', 'Doux', 'Fier',
  'Grand', 'Hardi', 'Intrépide', 'Jovial', 'Leste',
  'Malin', 'Noble', 'Puissant', 'Rapide', 'Sage',
  'Tenace', 'Vif', 'Zélé', 'Futé', 'Robuste',
];

const _animals = [
  'Aigle', 'Baleine', 'Condor', 'Dauphin', 'Élan',
  'Faucon', 'Guépard', 'Héron', 'Ibis', 'Jaguar',
  'Koala', 'Lion', 'Morse', 'Narval', 'Orque',
  'Puma', 'Requin', 'Serval', 'Tigre', 'Vautour',
];

String matchCodeName(String id) {
  var hash = 0;
  for (final c in id.codeUnits) {
    hash = (hash * 31 + c) & 0x7fffffff;
  }
  final adj = _adjectives[hash % _adjectives.length];
  final animal = _animals[(hash ~/ _adjectives.length) % _animals.length];
  return '$adj $animal';
}
