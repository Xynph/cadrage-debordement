# Game Brief: Rugby Legacy 27

<!-- Fiche d'une page (rigueur `minimal`) : remplace le game-concept. Titres en anglais (template CCGS), contenu en français. Non marqué = dit par Léo ou par AGENTS.md/CLAUDE.md ; *(inféré)* = déduit des docs du dépôt ; *(à valider)* = proposition du game-designer. -->

## In your words
Cap de Léo : consolider, rendre le jeu beau, agréable et addictif. Mode Monde uniquement. Tout est vu du point de vue du manager, tutoiement, vocabulaire du club. Bureau « Carnet du club » (ivoire, bordeaux, anthracite) apprécié ; bureau trop chargé et style « copie de FM » rejetés ; Gabi validé.

**Pitch:** Tu diriges un club de rugby à XV : tu prépares ta semaine, tu composes ton XV, tu vis le match en 3D, puis tu assumes les conséquences saison après saison. Chaque décision se lit dans le « Pourquoi » de l'après-match, et Gabi, ton ancien coach bourru, te donne son avis.

**Genre:** Management de rugby à XV (élite adulte), carrière au long cours, mode Monde.

**Controls:** Souris et clavier, PC Windows ; Steam plus tard. Bouton Continuer pour faire avancer le temps ; F1 ouvre Gabi. Lisible dès 1280×720, conçu pour 2560×1440.

**Question:** Est-ce qu'une semaine de manager (décider, lancer, comprendre le résultat) donne envie d'enchaîner « encore une semaine » ?

**Hooks:** (1) Un vrai match 3D que tu as préparé et dont tu comprends l'issue. (2) Gabi, voix bourrue et drôle du rugby. (3) Un club qui a une histoire : rivalités, jeunes formés, saisons qui s'empilent. *(inféré)*

**Intent:** payoff builds *(inféré : carrière sur plusieurs saisons)*.

## Look and references
- Look: bureau comme un carnet de club ; anthracite structurel, ivoire de lecture `#F0F1EC` (cartes `#FCFCF8`, encre `#20282C`), couleur du club en repère stable ; V vert / N ambre / D rouge pour les statuts ; corps dense ~12 px au canvas 2560×1440 ; pictogrammes originaux toujours avec des mots ; panneaux sombres d'ancrage ; match en 3D (caméras tv / tactique / action). Jamais de « fictif » ni « IA » à l'écran.
- Son *(à valider)* : ambiance de stade et de vestiaire, voix de Gabi sobre et à la demande (pas de lecture automatique), retours sonores discrets sur les décisions.
- References: Football Manager (profondeur de gestion, mais PAS son style visuel, rejeté par Léo) ; carnet papier du club (le ton du bureau).
- View: 2D interface + 3D match · Camera: tv, tactique, action.

## First minute
Écran titre sur le stade de nuit, Reprendre ou Nouvelle carrière (division, puis club). Tu arrives au Bureau : prochain match, objectif du conseil, trois priorités, l'avis de Gabi. Premier payoff : tu lances Continuer, tu entres dans le tunnel, le match s'ouvre.

## Challenge
Dès la première semaine, un adversaire à préparer, un groupe avec des blessés et fatigués, un objectif du conseil à tenir. Une défaite coûte du classement, du moral et de la confiance du conseil ; la saison suivante monte en exigence (finances, contrats, jeunes à renouveler).

## Core loop
- Semaine : lire le courrier et le dossier adverse, entraîner, composer le XV et le plan de jeu, gérer contrats et recrutement.
- Match : le vivre en 3D ou à l'entracte 2D, ajuster changements et vitesses.
- Conséquences : « Pourquoi » de l'après-match (leviers), classement, presse, finances ; ça nourrit la semaine suivante.
- Pourquoi rejouer : toujours une prochaine échéance visible (match, contrat, jeune, rivalité).

## Goal & fail state
Mener le club au-delà de l'objectif du conseil, saison après saison (titres, rivalités, jeunes formés). Échec : confiance du conseil perdue, ou club en difficulté financière *(à valider)*. Une session est complète quand un match est joué et compris.

## Features
- [x] Carrière Monde : création, Bureau, Réception, Presse, Calendrier, Classements
- [x] Effectif, fiche joueur, recrutement et contrats, finances, club, formation
- [x] Composition, plan de jeu, préparation, entraînement
- [x] Match 3D, entracte 2D, après-match « Pourquoi »
- [x] Gabi (guide F1, avis au Bureau)
- [ ] Consolidation visuelle et de confort des écrans (cohérence, densité, états vides, clavier)
- [ ] Rythme « encore une semaine » : échéances visibles, retours de décision clairs *(à valider)*
- [ ] Packaging Windows fiable (démarrage, sauvegardes hors dossier du programme)

## Your systems
- Match 3D et entracte · in the slice
- Gestion de la semaine (composition, entraînement, plan de jeu) · in the slice
- Recrutement, contrats, finances · in the slice
- Formation des jeunes, rivalités, histoire du club · in the slice
- Gabi, guide narratif · in the slice

## Keep
- Bureau « Carnet du club » (ivoire, bordeaux, anthracite) · Gabi 3D validé · tutoiement et vocabulaire de manager · lisibilité de l'information sportive avant la décoration.

## Avoid
- Bureau trop chargé (v4) ; imitation de Football Manager ; grandes cartes de téléphone ; décor qui masque une valeur ; mentions « fictif » / « IA » ; jargon technique à l'écran.

## Out of scope
- Anciens modes (France et autres) : mode Monde uniquement.
- Nouvelles fonctionnalités tant que la consolidation n'est pas faite (cap : améliorer l'existant).
- Vraies données (noms, photos, logos) dans le dépôt public : pack Rugby Réel privé, hors jeu de base.
- Multijoueur, mobile, rugby à 7 ou féminin dans cette passe ; seul le XV adulte d'élite.
- Sortie en plein match : arrêt forcé = reprise avant le match.

## Build order
1. Rendre la boucle semaine → match → « Pourquoi » fluide et lisible (c'est le test de l'addiction).
2. Passe de beauté sur les écrans les plus vus : Bureau, Effectif, Composition, Match, Après-match.
3. Cohérence des autres écrans (composants partagés, états vides, focus clavier, 720p).
4. Retours de décision et échéances qui donnent envie de continuer.
5. Paquet Windows reçu sur un chemin déplacé.

---
**Kill condition:** si, après la passe de consolidation, un joueur extérieur ne comprend pas l'issue d'un match sans aide, revoir le « Pourquoi » avant tout autre ajout. *(à valider)*

**Who it's for / what they feel:** fans de management sportif sur PC qui veulent habiter un club et sentir que leurs choix comptent ; sensation de « tout est sous contrôle, mais le match reste incertain ». *(inféré)*

**Games you love / don't:** n'aime pas : Football Manager pour son style visuel (profondeur à garder, habillage non). Autres références non données par Léo.
