# design-system/ — archive de handoff

**Ce dossier est un artefact historique. Ce n'est la source de vérité de rien.**

`reference/` contient le handoff de design d'origine : un prototype React interactif,
des wireframes et une spec, produits avant l'implémentation Flutter. Ils sont conservés
pour comprendre *pourquoi* l'app ressemble à ce qu'elle est, pas pour dire à quoi elle
ressemble aujourd'hui.

Le prototype décrit une palette claire, un modèle de gestes et une organisation d'écran
que l'app a depuis dépassés. En cas de désaccord entre `reference/` et le code, **c'est
le code qui a raison** — sans exception.

## Où se trouvent les vraies sources de vérité

| Sujet | Source |
|---|---|
| Couleurs, typo, espacements | `app/lib/core/theme.dart` (classe `MH`) |
| Règles métier | `app/lib/domain/rules/` |
| Gestes du terrain | `app/lib/core/widgets/court/court.dart` |
| Machine à états du score | `app/lib/state/match_provider.dart` |

Aucun de ces fichiers n'a de doublon documentaire ici : le code est commenté, et une
table de couleurs recopiée dans un markdown diverge en quelques semaines — c'est
précisément ce qui est arrivé à la version précédente de ce fichier.
