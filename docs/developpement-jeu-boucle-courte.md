# Concevoir et vérifier une évolution de Rugby Legacy

Le résultat attendu est une meilleure décision de manager, une action plus
fluide ou un retour plus lisible dans le jeu. Les outils soutiennent ce résultat.
AGENTS.md, la coordination #591, la carrière Monde, les règles de confidentialité
et la CI restent les références.

## Avant de coder : une fiche de dix lignes au plus

1. **Situation vécue** : où le manager se trouve et ce qui le gêne.
2. **Décision** : ce qu'il doit pouvoir comprendre et choisir.
3. **Arbitrage** : bénéfice, coût ou renoncement, tirés des systèmes existants.
4. **Retour** : ce qu'il verra immédiatement, puis au prochain événement utile.
5. **Preuve** : un scénario observable, ses mesures et les contrôles concernés.

Pour une décision de conception réelle, examiner deux ou trois variantes,
choisir celle qui sert le mieux le jeu et expliquer brièvement le choix. L'accord
permanent de Léo autorise l'implémentation dans le périmètre demandé ; les
questions portent sur les décisions encore ouvertes, pas sur chaque fichier.

Exemple : un titulaire fatigué avant deux matchs rapprochés. Le conseil indique
qui faire souffler, qui entre et les données connues qui motivent le choix.
Le manager peut accepter ou garder sa feuille. Après l'action, le changement
est visible ; au match suivant, le suivi s'appuie sur les faits enregistrés.
Les nombres de simulation restent ceux du moteur : pas de bénéfice inventé pour
rendre un bouton plus séduisant.

## Boucle de travail

1. **Reproduire** avec une carrière `world-champ`, une graine et les commandes
   enregistrées. Garder l'entrée minimale qui provoque le problème.
2. **Itérer sur ce cas** : fonction pure, scène ou composant. Mesurer durée,
   mémoire ou clics si c'est le problème. Réutiliser un point de départ validé
   plutôt que reconstruire la saison à chaque tentative.
3. **Éprouver le comportement** : faire échouer la régression sur le défaut,
   vérifier la correction et un cas voisin (sens inverse, autre résolution,
   refus ou reprise). Garder les assertions de règles et de sécurité.
4. **Jouer et regarder** dans le vrai Godot : saisir les commandes, attendre leur
   réponse, inspecter l'état et les erreurs, capturer les écrans concernés.
   Comparer texte, nombres et contrôles avec le modèle. Une image observée peut
   révéler une incohérence que les assertions actuelles ne couvrent pas.
5. **Intégrer** : tests ciblés, PR en français servant de passation, CI complète,
   reprise de main avant fusion, gate officiel et réception du commit fusionné.

Les vues de contrôle sont adaptées au changement : par exemple 1280×720,
1600×900 et 1920×1080 pour une disposition d'interface ; un clip avec son
marqueur et ses faits pour le match. Énoncer les dimensions et plateformes
réellement essayées. Une recette headless valide ses contrôles, pas l'esthétique.

## Quatre regards dans la même session

- **Conception** : décision intéressante, effort demandé au manager, conséquence
  compréhensible, cohérence avec sa semaine et sa saison.
- **Interface** : information utile d'abord, action accessible, lecture et focus,
  retour immédiat sans gêner la prochaine action.
- **Simulation** : règles, source des données, sauvegarde, comparaison de plusieurs
  graines pour un barème ; un seul match ne mesure pas un équilibrage.
- **Technique** : mesurer la partie lente, corriger sa cause, vérifier le gain et
  l'absence de changement non souhaité.

Les grilles `quick-design`, `ux-review`, `balance-check` et `perf-profile` de
Claude Code Game Studios (#738) complètent ces regards lorsqu'elles sont
disponibles dans le projet. Il n'est pas nécessaire de lancer d'autres agents.
Le modèle et l'effort de la session restent le plafond choisi par Léo.

## Outils et preuves

[Le pont Godot](../tools/godot-agent/README.md) fournit le pilotage et les
captures sur une copie de développement. `replay-choregraphe.cjs` fournit le
rejeu court ; les suites Monde complètes conservent la validation finale.
Les sources de ces choix et leur état de vérification sont enregistrés dans
[les ressources utiles](ressources-utiles.md).

### Regarder un match 3D sans déranger le PC (match filmé)

Sur un PC Windows occupé par quelqu'un, `scripts/match-filme.ps1` filme un vrai
match sans fenêtre, sans son et sans clic :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\match-filme.ps1 -Sortie E:\temp\film -Camera tv -Cadence 3 -Minutes 5
```

Le script prépare une carrière Monde de test dans un profil jetable
(`tools/match-filme/preparer-carriere.cjs`, environ une minute ; `-Export` en
reprend une déjà prête), puis lance le jeu sur un **bureau Windows séparé** : rien
n'apparaît à l'écran ni dans la barre des tâches, le premier plan n'est jamais
pris, le pilote audio est muet (`--audio-driver Dummy`) et le volume du profil à
zéro. L'outil Godot (`tools/match-filme/match_filme.gd`, chargé seulement par
`--script`) donne le coup d'envoi, passe les causeries et enregistre une image
PNG toutes les `-Cadence` secondes (toutes les `-CadenceMoments` secondes, 0,5 par
défaut, autour d'un essai et pendant la sortie des joueurs à la mi-temps et en fin
de match), puis quitte à la fin du match, à la minute
`-Minutes` ou après `-DureeMax` secondes. Ces durées sont du temps de jeu : par
défaut Godot tourne à pas fixe (`--fixed-fps 30 --disable-vsync`), chaque image
avance de 1/30 s de jeu et le film se calcule aussi vite que le PC le permet, avec
les mêmes images qu'en temps réel (`report.json` : `duree_s` en temps de jeu,
`duree_reelle_s` à l'horloge) ; `-TempsReel` revient au film en temps réel et
l'attente du moteur dure en jeu sa durée réelle, comme en partie (`-Attente figee`
la gèle, `-Attente libre` la laisse filer à pas entier). Le dossier contient les images,
`planche.png` (planche-contact), `planche-moments.png` (essais, mi-temps, fin),
`report.json` (minute, score, état, grand moment et luminance de chaque image :
`noires` doit valoir 0 ; `moments` donne la première image de chacun) et `surveillance.json`
(`premier_plan_godot` et `fenetres_visibles_sur_le_bureau_utilisateur` doivent
valoir 0). Une fenêtre hors écran (`--position`) ne suffit pas : Godot la ramène
sur l'écran et prend le premier plan au démarrage. Paramètres complets en tête du
script ; test : `tests/godot-match-filme.cjs`.

Même principe pour tous les écrans de gestion (tour des écrans filmé) :
`scripts\ecrans-filmes.ps1 -Sortie E:\temp\ecrans [-Tailles 1920x1080,1280x720] [-Ecrans bureau,fiche-joueur] [-Export <carriere.json>]`
donne `<ecran>-<largeur>.png`, une planche par taille et `report.json` (écrans en échec, contrôles hors
de l'écran, textes tronqués) ; lanceur commun `scripts/bureau-cache.ps1`, test `tests/godot-ecrans-filmes.cjs`.

Le bilan indique ce qui fonctionne, les fichiers, la PR, les tests et mesures
observés, les vérifications non faites, les limites et la prochaine évolution.
