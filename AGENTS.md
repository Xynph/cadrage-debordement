# Cadrage Débordement

## Cycle de travail

GitHub est la référence pour le code et l’avancement. À chaque reprise,
vérifier le `main` de [Xynph/cadrage-debordement](https://github.com/Xynph/cadrage-debordement)
et les PR pertinentes avant de modifier une copie locale.

Les producteurs travaillent sur des branches distinctes et des périmètres
compatibles. La description de la PR est la passation. Le
[cycle court](docs/developpement-parallele.md) précise quand signaler une
collision, quels tests consigner et comment préparer la reprise.

Léo a donné son accord de principe aux intégrations ordinaires le 2 novembre
2026. Un seul intégrateur arbitre et applique les protections serveur et le
[gate officiel déployé](docs/chat-release-gate.md), avec toute autorisation
qu’il exige. Aucun push direct sur `main`.

Expliquer brièvement chaque phase à Léo en français, puis avancer dans le
périmètre autorisé. Rendre le résultat, le lien de la PR et la prochaine étape
concrète.

## Contraintes produit

- Avant de modifier un match, un effectif, la discipline ou une compétition,
  lire [les références du rugby](docs/rugby-rules-reference.md). Fixer la
  saison simulée et vérifier les lois officielles et les dispositions
  françaises applicables. Distinguer règles, abstractions volontaires et
  points non vérifiés. Écarter par défaut les variantes amateurs, jeunes et à
  sept du XV adulte d’élite. La réussite des tests ne suffit pas à établir
  la conformité aux règles.
- Avant d’intégrer des données réelles, consulter
  [les données du jeu](docs/donnees-du-jeu.md). Présenter la trésorerie fictive
  comme telle.
- Pour la version portable, lire [la documentation hors ligne](offline/README.md).
  Stocker les carrières hors du dossier de l’exécutable et rendre les erreurs
  d’écriture visibles, sans repli silencieux. Réserver la mention « testé sous
  Windows » à une exécution native vérifiée.
