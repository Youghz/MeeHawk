# Parité Dart ↔ Python

`annotator/core.py` est un port ligne à ligne de `app/lib/state/match_provider.dart`.
Rien n'empêchait cette parité de dériver silencieusement : ce dossier la rend testable.

## Comment ça marche

`scenario.json` est une liste d'actions de scoring, dans un vocabulaire que les deux
implémentations comprennent. Chaque camp rejoue exactement la même liste et sérialise
l'état final avec son propre codec. Les deux JSON doivent être identiques.

```
scenario.json ──┬──> MatchNotifier (Dart)  ──> MatchCodec.toJson  ──┐
                │                                                   ├──> doivent être égaux
                └──> MatchAnnotator (Py)   ──> MatchCodec.to_json ──┘
```

`expected_state.json` est le golden : régénéré par le test Dart, vérifié par les deux.

## Lancer les tests

```bash
cd app && flutter test test/parity_test.dart
uv run --project annotator pytest annotator/tests/test_parity.py
```

Régénérer le golden après un changement de règle **intentionnel** :

```bash
cd app && UPDATE_PARITY_GOLDEN=1 flutter test test/parity_test.dart
```

Puis relancer le test Python : s'il échoue, le port n'a pas suivi.

## Les deux écarts assumés

Le scénario les contourne explicitement — ce ne sont pas des bugs, mais des choix
d'interface différents pour le même modèle :

| Situation | Dart (app interactive) | Python (agent) |
|---|---|---|
| L'équipe gagnante prend le service pour la première fois du set | ouvre `PickServerPopup`, attend `pickFirstServer(id)` | assigne automatiquement `nextServerIndex[winner]` |
| Un set se termine | ouvre `SetEndPopup`, attend `startNextSet()` | enchaîne sur le set suivant |

Le harnais Dart applique la règle du Python (même joueur, même enchaînement) pour que
la comparaison porte sur les règles de jeu, pas sur le mode d'interaction.

## Ajouter un cas

Ajouter les actions dans `scenario.json`, régénérer le golden, relancer les deux tests.
Un scénario qui ne touche jamais une règle ne la protège pas — viser les cas tordus :
4e touche, ace de service, faute de service, undo à travers une fin de set, bloc suivi
d'une reprise par le même joueur.
