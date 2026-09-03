---
name: mobile-ux-ui
description: Meilleures pratiques UX et UI pour applications mobiles (iOS et Android), incluant les spécificités Flutter. Utilise ce skill chaque fois qu'un utilisateur travaille sur une app mobile — design, audit, amélioration, refonte, wireframes, maquettes, revue d'interface, critique UX, ou toute question liée à l'expérience utilisateur sur mobile. Déclenche aussi quand l'utilisateur mentionne « app mobile », « iOS », « Android », « Flutter », « Dart », « Material Design », « Cupertino », « Human Interface Guidelines », « HIG », « tap target », « thumb zone », « navigation mobile », « onboarding mobile », « responsive mobile », « mobile-first », « widget Flutter », ou cherche à améliorer l'utilisabilité, la rétention ou la conversion d'une app. S'applique aussi aux revues de maquettes Figma ou screenshots d'app existantes.
---

# Mobile UX/UI Best Practices (iOS, Android, Flutter)

Guide complet des meilleures pratiques pour concevoir et améliorer des applications mobiles.

---

## TABLE DES MATIÈRES

1. Principes directeurs
2. Checklist d'audit rapide
3. UX — Navigation
4. UX — Interactions tactiles
5. UX — Formulaires
6. UX — Onboarding
7. UX — Performance et fiabilité
8. UX — Notifications, recherche, mesure
9. UI — Typographie
10. UI — Couleurs et Dark Mode
11. UI — Composants d'interface
12. UI — Iconographie
13. UI — Espacement et layout
14. UI — Animations et transitions
15. UI — Images et média
18. Spécificités Flutter
20. Flutter — Performance UI

---

## 1. Principes directeurs

Trois principes guident toutes les décisions mobile :

1. **Le pouce est roi** — Tout élément interactif fréquent doit être accessible au pouce d'une seule main. La zone de confort est le bas de l'écran.
2. **Chaque écran, un seul objectif** — Ne pas surcharger un écran. Répartir les actions complexes sur plusieurs étapes. Le contenu critique va au-dessus du fold.
3. **La performance est du UX** — Un design magnifique qui prend 5 secondes à charger n'est pas du bon UX. Lazy load, compression, et gestion du mode hors-ligne sont des décisions de design, pas seulement techniques.

---

## 2. Checklist d'audit rapide

Quand on te demande d'auditer ou d'améliorer une app, vérifier ces 10 points en premier :

1. Les tap targets font-ils au minimum 44pt (iOS) / 48dp (Android) ?
2. La navigation principale est-elle en bas de l'écran (thumb zone) ?
3. Les messages d'erreur sont-ils spécifiques et actionnables ?
4. L'onboarding fait-il 5 écrans ou moins ?
5. Le contraste texte/fond respecte-t-il 4.5:1 minimum (WCAG AA) ?
6. Le contenu critique est-il visible sans scroller ?
7. L'app sauvegarde-t-elle l'état lors d'une interruption ?
8. Les formulaires utilisent-ils le bon type de clavier pour chaque champ ?
9. Le Dark Mode est-il supporté correctement ?
10. Les temps de chargement sont-ils sous 3 secondes ?

---

## 3. UX — Navigation

### Thumb Zone (Zone du pouce)
- Les actions principales doivent être dans la zone inférieure de l'écran, accessible au pouce
- La navigation primaire utilise une barre de navigation en bas (bottom tab bar), jamais en haut
- Limiter la navigation principale à 4-5 items maximum pour réduire la charge cognitive
- Éviter les menus dropdown multi-niveaux sur mobile
- Inclure une barre de recherche proéminente pour l'accès rapide

### Gestes et retour arrière
- Respecter les gestes système natifs (swipe back sur iOS, bouton retour Android)
- Ne jamais détourner les gestes standard de la plateforme
- Fournir toujours un moyen visible de revenir en arrière en plus des gestes
- Les gestes custom doivent être découvrables (indice visuel ou tutoriel au premier usage)

### Structure de l'information
- Chaque écran a un seul objectif clair
- Répartir les workflows complexes sur plusieurs étapes avec un indicateur de progression
- Le contenu critique (prix, CTA, infos clés) est au-dessus du fold
- Le contenu secondaire va dans des sections pliables (accordéons)
- Utiliser des titres clairs et une hiérarchie visuelle pour faciliter le scanning

---

## 4. UX — Interactions tactiles

### Tap Targets
- Taille minimale : 44×44 points (iOS) / 48×48 dp (Android)
- Espacement minimum entre tap targets : 8dp pour éviter les erreurs de tap
- Le bout du doigt moyen fait 1.6-2 cm, le pouce fait ~2.5 cm
- Les éléments trop petits sont la cause #1 de frustration dans les analyses de sessions

### Feedback tactile
- Chaque tap doit produire un retour visuel immédiat (changement d'état, animation, ripple)
- Utiliser les vibrations haptiques pour confirmer les actions critiques
- Les états désactivés doivent être visuellement distincts (opacité réduite, couleur grisée)
- Prévoir les états : default, pressed, focused, disabled, loading

### Scroll et pull-to-refresh
- Les listes longues doivent supporter le scroll infini ou la pagination
- Implémenter pull-to-refresh pour le contenu dynamique
- Afficher un skeleton screen pendant le chargement plutôt qu'un spinner

---

## 5. UX — Formulaires

### Réduire la friction
- Demander le strict minimum d'informations
- Utiliser le bon type de clavier pour chaque champ : email → clavier email, téléphone → pavé numérique, URL → clavier URL, nombre → clavier numérique
- Activer l'auto-complétion et l'autofill quand c'est possible
- Remplir par défaut les valeurs connues (pays basé sur la locale, etc.)

### Validation et erreurs
- Valider inline en temps réel, pas seulement à la soumission
- Messages d'erreur spécifiques et actionnables : « Le mot de passe doit contenir au moins 8 caractères » et non « Erreur de validation »
- Positionner le message d'erreur directement sous le champ concerné
- Ne jamais vider un champ en cas d'erreur — préserver la saisie
- Scroller automatiquement vers le premier champ en erreur

### Labels et placeholders
- Utiliser des labels flottants (qui se déplacent au-dessus du champ lors du focus)
- Ne jamais utiliser le placeholder comme seul label — il disparaît à la saisie

---

## 6. UX — Onboarding

- Maximum 5 écrans pour l'onboarding initial
- Permettre de sauter (skip) à tout moment
- Expliquer la valeur, pas les fonctionnalités (« Économisez 2h/semaine » plutôt que « Fonctionnalité de rappels »)
- Demander les permissions (notifications, localisation, caméra) en contexte, pas au lancement
- Progressive disclosure : montrer les fonctionnalités avancées au fil du temps
- L'onboarding idéal se fait en utilisant l'app, pas en regardant des slides

---

## 7. UX — Performance et fiabilité

### Vitesse
- Temps de chargement initial cible : sous 3 secondes
- Compresser les images et assets
- Lazy load le contenu hors écran
- Les transitions/animations doivent être à 60fps minimum

### Gestion du hors-ligne et des interruptions
- Sauvegarder l'état agressivement — un appel téléphonique ne doit pas faire perdre un brouillon
- Designer pour la connectivité intermittente — cache local, file d'attente d'actions
- Afficher clairement l'état de connectivité quand c'est pertinent
- Permettre les opérations de base hors-ligne quand c'est possible

### Loading states
- Skeleton screens > spinners > écrans vides
- Les actions longues doivent montrer une progression (barre ou pourcentage)
- Prévoir un timeout gracieux avec message clair et option de réessayer

---

## 8. UX — Notifications, recherche, mesure

### Notifications
- Demander la permission en contexte, pas au premier lancement
- Expliquer la valeur avant de demander
- Offrir un contrôle granulaire des types de notifications
- Les notifications in-app (toasts, banners) ne doivent pas bloquer le contenu

### Recherche
- Recherche facilement accessible (icône visible ou barre proéminente)
- Suggestions et auto-complétion pendant la saisie
- Historique de recherches récentes
- Gestion gracieuse des 0 résultats avec suggestions alternatives

### Mesure et validation
- Tester sur de vrais appareils, pas seulement des émulateurs
- Tester sur des appareils milieu de gamme, pas seulement les flagship
- A/B tester les changements significatifs
- 5 utilisateurs suffisent pour découvrir ~85% des problèmes d'utilisabilité (Nielsen Norman Group)
- Prioriser les correctifs par impact × fréquence

---

## 9. UI — Typographie

### Tailles et lisibilité
- Taille minimum du texte body : 16pt / 16sp
- Hiérarchie claire avec au maximum 3-4 niveaux (H1, H2, H3, body)
- Interlignage (line-height) : 1.4-1.6× la taille de la police pour le texte courant
- Longueur de ligne idéale : 30-40 caractères par ligne sur mobile

### Choix de police
- Polices système par défaut pour maximiser la performance et la lisibilité native : SF Pro (iOS), Roboto (Android)
- Supporter Dynamic Type (iOS) / tailles de texte accessibles (Android) pour laisser l'utilisateur ajuster la taille

### Hiérarchie et contraste typographique
- Différencier les niveaux par taille, poids (regular, semibold, bold) et couleur
- Éviter d'utiliser uniquement la couleur pour indiquer l'importance — combiner avec taille/poids
- Le texte secondaire peut utiliser une opacité réduite (ex: 60%) plutôt qu'un gris fixe

---

## 10. UI — Couleurs et Dark Mode

### Système de couleurs
- Définir un système de couleurs sémantiques (primary, secondary, error, success, warning, surface, background)
- Utiliser des design tokens / CSS variables pour la cohérence
- Couleur dominante avec accents ciblés — maximum 3-4 couleurs principales + neutres

### Contraste et accessibilité
- Ratio de contraste minimum texte/fond : 4.5:1 (WCAG AA) pour le texte normal
- Ratio minimum pour les gros textes (18pt+ ou 14pt bold) : 3:1
- Ratio minimum pour les éléments interactifs : 3:1 contre l'arrière-plan
- Tester avec des simulateurs de daltonisme (~8% des hommes sont daltoniens)
- Ne jamais utiliser uniquement la couleur pour transmettre de l'information

### Dark Mode
- Standard attendu sur iOS et Android — ne pas simplement inverser les couleurs
- Réduire la saturation des couleurs en mode sombre
- Éviter le blanc pur (#FFFFFF) sur fond sombre — utiliser un blanc légèrement cassé
- Élévation en Dark Mode = tons de surface plus clairs (pas de shadow)
- Surface de base : ~#121212 ou équivalent, pas du noir pur (#000000)

---

## 11. UI — Composants d'interface

### Boutons
- Bouton principal (CTA) : visuellement proéminent, une seule action principale par écran
- Hiérarchie : filled (primaire) > outlined (secondaire) > text (tertiaire)
- Minimum 44pt/48dp de hauteur
- Label = verbe d'action clair (« Confirmer la commande » plutôt que « OK »)

### Cards et conteneurs
- Cards regroupent du contenu lié — image, titre, description, action
- Padding intérieur : 16dp minimum, espacement entre cards : 8-16dp
- Une card = un sujet, une action principale

### Listes
- Hauteur de ligne minimum : 48dp pour les listes tactiles
- Dividers légers entre les éléments
- Swipe actions pour les actions secondaires (supprimer, archiver)

### Bottom sheets et modales
- Préférer les bottom sheets aux modales plein écran pour les actions contextuelles
- Les modales bloquantes sont réservées aux confirmations critiques
- Toujours fournir un moyen clair de fermer (bouton X, swipe down, tap outside)

### Toasts et snackbars
- Pour les confirmations non-critiques et messages temporaires
- Positionnés en bas de l'écran, au-dessus de la navigation
- Auto-dismiss après 3-5 secondes, peuvent inclure une action (« Annuler »)

---

## 12. UI — Iconographie

- Utiliser les icônes système quand elles existent (SF Symbols sur iOS, Material Icons sur Android)
- Taille minimale des icônes : 24×24dp
- Les icônes seules doivent être accompagnées d'un label textuel quand la signification est ambiguë
- Cohérence du style : ne pas mélanger outlined et filled dans le même contexte
- État actif/inactif clair pour les icônes de navigation

---

## 13. UI — Espacement et layout

### Grille et marges
- Marge latérale minimale : 16dp du bord de l'écran
- Système d'espacement basé sur un multiple de 4 ou 8 (4, 8, 12, 16, 24, 32, 48)
- Espacement cohérent — même rythme vertical dans toute l'app

### Safe areas
- Respecter les safe areas (notch, barre d'état, barre de navigation, indicateur home)
- Ne jamais placer de contenu interactif derrière le notch ou la barre système
- Tester sur les différentes tailles d'écran y compris avec encoche

### Orientation
- Concevoir d'abord en portrait — c'est l'usage principal
- Si l'app supporte le landscape, adapter le layout (pas juste étirer)

---

## 14. UI — Animations et transitions

### Principes
- Animations rapides : 200-500ms max pour la plupart des transitions
- Chaque animation a un but : guider l'attention, montrer la relation entre éléments, confirmer une action
- Performance : 60fps minimum, préférer les animations GPU (transform, opacity)
- Respecter « Réduire les animations » (prefers-reduced-motion / accessibilité système)

### Patterns courants
- Transition entre écrans : slide horizontal pour la navigation hiérarchique
- Apparition de contenu : fade in + léger slide up
- Loading : skeleton screen avec pulsation subtile
- Confirmation : micro-animation (checkmark, confetti pour les succès)

---

## 15. UI — Images et média

- Définir des dimensions fixes pour éviter le layout shift au chargement
- Utiliser des placeholders (blur, couleur dominante) pendant le chargement
- Supporter les formats modernes (WebP, AVIF) pour réduire la taille
- Les images informatives doivent avoir un texte alternatif (alt text)
- Les vidéos ne doivent jamais jouer automatiquement avec le son

---


## 16. Spécificités Flutter

### Architecture et organisation du code UI

#### Séparation des couches
- Séparer l'app en UI layer et data layer
- Ne pas mettre de logique métier dans les widgets UI — séparer via un state management (BLoC, Riverpod, Provider, Cubit)
- Garder les widgets petits et composables — composition over inheritance


### Widgets et bonnes pratiques

#### Widgets réutilisables
- Réutiliser les widgets existants de Material/Cupertino avant de créer des custom
- Créer des widgets réutilisables pour les patterns qui se répètent dans l'app
- Préférer les petits widgets composables aux gros widgets monolithiques
- Utiliser `const` constructors pour les widgets statiques — améliore les performances de rebuild

#### ThemeData centralisé
- Définir un thème unique via `ThemeData` (Material) ou `CupertinoThemeData` (Cupertino)
- Utiliser `TextTheme` pour centraliser les styles typographiques
- Définir les couleurs via `ColorScheme.fromSeed()` ou des couleurs custom
- Supporter le thème sombre via `ThemeMode.system`
- Ne jamais hardcoder les couleurs ou tailles de texte dans les widgets — toujours référencer le thème

```dart
// Bon : référencer le thème
Text('Hello', style: Theme.of(context).textTheme.bodyLarge)

// Mauvais : hardcoder
Text('Hello', style: TextStyle(fontSize: 16, color: Colors.black))
```

### Responsive design en Flutter

#### Widgets responsive essentiels
- `MediaQuery` : obtenir les dimensions de l'écran et les préférences d'accessibilité
- `LayoutBuilder` : adapter le layout selon les contraintes du parent
- `Expanded` / `Flexible` : répartir l'espace dans les `Row` et `Column`
- `FractionallySizedBox` : dimensionner en pourcentage du parent
- `AspectRatio` : maintenir les proportions

#### Breakpoints recommandés
- Compact (< 600dp) : layout phone, single column
- Medium (600-839dp) : layout tablette, list-detail possible
- Expanded (840dp+) : multi-pane, navigation rail
- Utiliser les `WindowSizeClass` ou définir des breakpoints custom via `MediaQuery`

#### Ne jamais hardcoder les dimensions
```dart
// Bon : responsive
SizedBox(width: MediaQuery.of(context).size.width * 0.9)

// Mauvais : hardcodé
SizedBox(width: 350)
```

#### Gestion de l'orientation
- `OrientationBuilder` pour adapter le layout
- `PageStorageKey` pour préserver la position de scroll lors d'un changement d'orientation

### Formulaires Flutter

- Utiliser `TextInputType.emailAddress`, `.phone`, `.number`, `.url` pour chaque champ
- Activer `autofillHints` pour l'auto-complétion système
- `TextFormField` avec `validator` pour la validation inline
- `FocusNode` pour gérer le focus entre les champs (next field on submit)
- Wrapper les formulaires dans un `Form` widget avec une `GlobalKey<FormState>` pour la validation globale


## 20. Flutter — Performance UI

### La règle fondamentale
Flutter rend chaque frame en ~16ms (60fps) ou ~8ms (120fps). Si le UI rebuild trop ou fait du travail lourd sur le main thread, le budget de frame est dépassé et l'utilisateur perçoit du lag.

### Minimiser les rebuilds (cause #1 de jank)
- Découper les gros widgets en petits widgets — seul le widget qui change se rebuild
- Utiliser `const` constructors pour tout widget statique
- Ne jamais faire de logique lourde dans `build()` — le déplacer dans le state management
- Si seul un compteur change, ne pas rebuild tout l'écran
- Utiliser `RepaintBoundary` pour isoler les zones qui se repeignent souvent

### Listes performantes
- Ne jamais utiliser `Column` avec 200+ children — utiliser `ListView.builder` qui crée les widgets à la demande (lazy loading)
- Pour les layouts complexes de scroll, préférer les `Slivers`
- `CachedNetworkImage` pour le cache d'images réseau

### Widget tree léger
- Préférer `const SizedBox` à `Container` vide
- Utiliser `Clip` widgets seulement quand nécessaire (le clipping est coûteux)
- Choisir les layout widgets intentionnellement — chaque widget a un coût de layout

### Animations performantes
- Les animations ne doivent jamais bloquer le UI thread
- Préférer les animations basées sur `transform` et `opacity` (composées sur le GPU)
- Utiliser `AnimatedBuilder` ou `TweenAnimationBuilder` plutôt que `setState` dans une boucle d'animation
- Impeller (nouveau moteur de rendu Flutter) réduit le jank et améliore la fluidité des animations

### Images
- Compresser et redimensionner les images côté serveur
- Utiliser `CachedNetworkImage` pour éviter les rechargements réseau
- Définir `cacheWidth` / `cacheHeight` sur les `Image` pour réduire la consommation mémoire
- Lazy load les images hors écran

