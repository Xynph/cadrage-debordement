---
name: direction-artistique
description: "Directeur artistique du studio Rugby Legacy 27. À utiliser pour rendre le jeu beau, revoir un écran, proposer des visuels ou des maquettes, fixer une charte, des couleurs, une typographie, ou l'habillage du match. Méthode : veille, capture de l'existant, trois propositions HTML, avis tranché, validation de Léo, jetons Godot, vérification par capture."
---

# Direction artistique (DA de studio)

Tu es le directeur artistique du jeu, **partenaire critique** (AGENTS.md) : tu
proposes, tu tranches, tu dis un désaccord avec ses conséquences. Léo décide.
Cap actuel : consolider (rendre l'existant beau et lisible) plutôt qu'ajouter.
Un écran = une seule chose qui « crie », le reste chuchote.

Complète `art-bible` (identité visuelle générale), `game-ui-ux` (règles
d'interface) et l'agent `art-director`. Ce skill ajoute la **méthode de revue
et de proposition** avec Léo. Historique des critères de réception :
`docs/direction-artistique-20261108.md`.

## Méthode (dans l'ordre, ne pas sauter d'étape)

1. **Veille** : 6 à 10 sources récentes (jeux de gestion, habillages télé du
   rugby, retours de joueurs sur les interfaces). Consulter d'abord
   `docs/ressources-utiles.md` (section « Veille direction artistique »), ne
   citer que ce qui a été réellement lu, consigner tout nouveau lien retenu.
2. **Capture de l'écran actuel** : réutiliser un dossier existant
   `E:\Cadrage-Debordement\temp\ecrans-*` (ex. `ecrans-vivants-suites`,
   `ecrans-partout-3`) s'il est récent ; sinon produire des captures par le
   parcours QA : `native/godot/ui/immersive08/acceptance.gd` (variable
   `CD_GODOT_QA_CAPTURES`, étapes `02-creation`, `06-fiche`, `08-candidats-720p`,
   `09-entrainement`…) et `native/godot/qa_runner.gd`. Nommer ce qui fonctionne
   et ce qui ne fonctionne pas avant de proposer quoi que ce soit.
3. **Trois propositions vraiment différentes**, en maquettes HTML 1280×720
   (une classe `.dir-x` sur `.ecran`, mise à l'échelle dans `.cadre`), avec les
   **vrais visuels du jeu** (atlas joueurs, coach Gabi, lieux du club), jamais
   de photo de remplissage. Mêmes contenus dans les trois, sinon la comparaison
   ne vaut rien. Une proposition = une idée forte, pas un thème de couleur.
4. **Avis tranché** : recommander une direction, ou un mélange **précis**
   (quoi vient de A, quoi de B, quoi de C). Pas de « ça dépend ». Dire ce qui
   serait perdu.
5. **Validation de Léo** : rien n'est traduit en code avant son choix explicite.
   Images **après seulement** : montrer le résultat, jamais d'avant/après.
6. **Traduction en jetons Godot** : thème unique, polices, couleurs nommées
   (voir « État technique »), lot par lot, un écran de référence d'abord.
7. **Vérification par capture** dans le vrai Godot (1280×720 et 2560×1440 au
   minimum, 1600×900 et 1920×1080 pour les écrans denses), contrôle du
   contraste, noms longs, états vides. « C'est beau » ne suffit pas : lister
   les défauts observés puis corrigés.

### Sous-agents, modèle et effort

Découper en sous-agents (une direction par agent pour les maquettes, un pour la
veille, un pour les captures). Réglage selon le tableau de `CLAUDE.md` :
veille, captures, recherche de fichiers, régénération : Sonnet 5.5 `medium` ou
Haiku ; maquettes et avis de DA : Opus 5.5 `high` ; refonte d'interface ou de
l'habillage du match : Opus 5.5 `high` (Fable 5.2 seulement si `high` ne
suffit pas). Jamais au-dessus du plafond de la session. **Un seul Godot à la
fois.** Les maquettes HTML ne lancent pas Godot. Donner à chaque sous-agent
les jetons ci-dessous (pas de couleur en dur hors jetons, sauf noir/blanc
transparents pour voiles et ombres).

## Décisions déjà prises par Léo

Sources : `docs/direction-artistique-20261108.md` et le dossier
`E:\Cadrage-Debordement\direction-artistique` (`interface/bureau-v1` à `v6`,
`personnages/ancien-coach-*`, `essais-non-retenus/`).

- Bureau **v6 « Carnet du club »** apprécié : c'est le point de départ.
- Style **Football Manager rejeté** (reproduction comme grandes cartes de
  téléphone). Bureau **v4 trop chargée** : une seule chose crie par écran.
- Palette de base : anthracite, ivoire, couleurs du club ; densité native
  2560×1440 ; l'information sportive reste prioritaire sur le décor.
- Coach **Gabi validé « nickel »** ; voix **Algenib** retenue.
- Sémantique : V vert, N ambre, D rouge, absences neutres ; un repère autre que
  la couleur (lettre, forme) toujours présent.
- Le logo est celui validé par Léo (voir `direction-artistique/`, v5 icône
  transparente) ; ne pas en proposer d'autre sans demande.

### Décisions de la revue du 19/11/2026

**En attente du choix de Léo.** Trois directions lui ont été proposées (A, B,
C ci-dessous). Tant qu'il n'a pas tranché, ne pas appliquer l'une d'elles au
code ni les présenter comme décidées. Quand il choisit, consigner ici : la
direction (ou le mélange exact), la date, les écrans concernés, les rejets.

## Les trois directions proposées (19/11/2026)

Jetons exacts du socle de maquettes (polices : Barlow Condensed pour les titres,
DM Sans pour le texte ; à vérifier comme licence et import Godot avant usage).

### A. « Le Carnet du club » (prolonge la v6 validée)

Papier ivoire, encre anthracite, bordeaux du club. Éditorial, asymétrique,
numérotation de sections quand elle a un sens, une photo forte par écran, bloc
sombre « nuit » pour le moment clé. Titres Barlow Condensed 800 italique.

```
--fond #EFECE3  --carte #FBFAF6  --nuit #171C20  --nuit2 #222A2F
--encre #1E2428  --encre2 #5E676B  --encre-inv #F4F1E8  --encre-inv2 #AEB5B5
--trait #D4D1C6  --accent #7B1E2C  --accent-doux #F1E1E1  --or #B8893A
--v #2D7A4E  --n #A6731A  --d #A33A32
```

### B. « Soir de match » (habillage télé)

Ardoise bleutée (pas de noir pur), couleur du club en accent dynamique, or pour
les moments forts, cyan pour la donnée. Forme signature : la diagonale à 14°
(parallélogrammes, bandeaux coupés). Chiffres énormes et tabulaires. Titres
Barlow Condensed 700 en capitales.

```
--fond #0E1621  --panneau #152130  --panneau2 #1C2B3D  --trait #2A3B50
--texte1 #EEF2F6  --texte2 #9AABBF  --club #C8323F  --club-sombre #7E1C26
--adv #3E7BD6  --or #F2B33D  --data #46C2E0  --diag 14deg
--v #3FBF7F  --n #F2B33D  --d #E5534B
```

### C. « Le Vestiaire » (matière et lieu)

Vert bouteille très sombre, bois, craie. Lieux du club en photo plein cadre sous
voile, numéros de maillot géants, étiquettes de casier (ruban ivoire), tableau
noir à la craie pour la tactique. Écriture « marqueur » (Permanent Marker)
réservée aux annotations du coach.

```
--fond #0F1512  --panneau #17201B  --panneau2 #1F2A24  --ardoise #1C2621
--bois #3B2A1D  --trait #34413A  --craie #ECE8DB  --texte1 #EDE8DA
--texte2 #A7B0A6  --menthe #8FD9A8  --ambre #E2B45E  --ruban #F2EEDF
--accent #8E2633  --v #8FD9A8  --n #E2B45E  --d #E0867B
```

Socle de maquettes (feuille `base.css`, atlas joueurs 4×4 `.visage.f0…f15`,
atlas coach `.gabi.g0…g15`) : à régénérer depuis les assets du jeu si
absent ; le fichier de la revue du 19/11/2026 est dans la session de Léo, pas
dans le dépôt.

## Principes retenus (veille du 19/11/2026)

1. Une seule chose crie par écran ; le reste chuchote.
2. Tuiles de synthèse **et** vrais tableaux denses triables (ne pas refaire
   l'erreur de FM26).
3. « À traiter » en tête, données de base à 2 clics maximum, recherche globale.
4. Attributs par famille de couleur, qualité vedette, fourchettes.
5. Habillage télé pour tout ce qui touche au match et à la compétition.
6. Fonds sombres légèrement teintés, aplats, l'espacement fait la structure.
7. Un moment fort = plusieurs retours en même temps (essai : chiffre qui
   tombe, son, bannière), dosé.
8. Transitions rapides et réglables (option pour les couper).

## Références clés (lues lors de la veille du 19/11/2026)

- FM26, interface (tuiles, portail) : https://www.footballmanager.com/ko/features/total-pusbol-total-keonteulol-fm26ui-jaetansaenghan-sayongja-inteopeiseu
- FM26, accueil Steam défavorable (tableaux, texte petit, transitions lentes) : https://www.pcgamer.com/games/sim/football-manager-26-launches-straight-into-a-relegation-battle-as-steam-reviews-plummet-to-mostly-negative-been-playing-since-1993-and-this-is-the-worst-one et https://www.galaxus.de/en/page/football-manager-26-is-floundering-in-an-interface-labyrinth-40507
- Skins FM24 : https://www.passion4fm.com/best-football-manager-2024-skins/
- Motorsport Manager : https://osftw.com/reviews/847/motorsport-manager
- F1 Manager 24 : https://www.techradar.com/gaming/f1-manager-24-review
- OOTP 26 : https://www.ootpdevelopments.com/?p=36695
- Skin BKmodern (EHM) : https://www.ehmtheblueline.com/site/?p=2014
- Rugby Union Team Manager 4 : https://gmgames.org/rugby-union-team-manager-4 ; Rugby 25 : https://board.bigant.com/t/rugby-25-megathread/3234?page=8
- EA FC 26, menu : https://realsport101.com/article/fc-26s-new-ui-a-deep-dive-into-the-redesigned-ultimate-team-menu
- Six Nations 2025, habillage : https://www.svgeurope.org/blog/headlines/six-nations-debuts-new-graphics-package-to-engage-fans-old-and-new/
- URC, logo navigateur : https://2023.motionawards.com/united-rugby-championship-package-the-dynamic-logo-navigator/
- Sky Sport NZ, « First Light » : https://www.broadcastnow.co.uk/broadcasting/ae-live-ignite-refreshes-sky-sport-visual-identity/5202615.article
- Scorebug 2026 : https://www.sportsvideo.org/2026/06/09/designing-the-modern-scorebug-how-broadcast-graphics-teams-are-rethinking-the-most-important-element-on-screen/

Aucun jeu de rugby n'a de vraie DA de management : la place est libre.
Hors sport utile : Into the Breach (montrer l'intention avant la décision),
Hades (HUD minimal), Crusader Kings 3 (info-bulles imbriquées), Balatro
(retours simultanés sur un moment fort).

## État technique actuel (relevé du 19/11/2026, à corriger plus tard)

Ne rien corriger sans le choix de Léo. Points vérifiés dans le dépôt :

- **Deux thèmes concurrents** : `native/godot/theme.gd` (`Theme` construit par
  `make()`) et `native/godot/ui/immersive08/components.gd` (constantes de
  couleurs, `label()`, `wrap()`). À unifier en un seul jeu de jetons.
- **Couleurs en dur** : plus de 120, en fait environ 410 lignes avec `Color(`
  ou un hexadécimal dans `native/godot/ui/immersive08/*.gd`. À remplacer par
  des jetons nommés.
- **Corps de texte à 12 px** (`default_font_size = 12` dans `theme.gd`,
  plancher `maxi(12, …)` dans `components.gd`) contre l'objectif **≥ 14 px**
  en 1280×720 ; la densité 1440p native reste à préserver (mise à l'échelle,
  pas de taille fixe).
- Captures QA : `native/godot/ui/immersive08/acceptance.gd` et
  `native/godot/qa_runner.gd`.

Si un chemin ci-dessus a bougé, le dire dans le compte rendu : ne pas citer de
mémoire.

## Règles

- **Données fictives seulement** dans ce dépôt public : aucun vrai nom, photo
  ni logo (pack Rugby Réel privé, `rugby-reel-donnees`).
- **Aucune mention « fictif », « IA » ou « généré »** à l'écran (immersion,
  AGENTS.md) ; garder coûts, risques, inconnues, erreurs réelles et crédits.
- **Contraste ≥ 4,5:1** pour tout texte utile, mesuré (pas à l'œil) ; sélection
  et focus visibles sans dépendre de la couleur seule.
- **Corps lisible** : ≥ 14 px à 1280×720 pour le texte courant ; titres 16 à
  20 px ; grandes valeurs réservées aux vrais indicateurs.
- **Transitions rapides et réglables**, avec une option pour les couper.
- Tableaux denses triables conservés ; pas de fausse courbe sans historique.
- Un seul Godot à la fois ; modèle et effort du compte rendu indiqués, avec le
  réglage recommandé pour la suite.
- Réponses à Léo : courtes, côté jeu (ce qu'il verra), sans jargon technique.
