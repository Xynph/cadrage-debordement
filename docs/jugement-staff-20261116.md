# Jugement du staff, sang-froid et confiance — 16/11/2026

Décision de Léo (16/11, 19h13), inspirée de Football Manager : les choix de joueurs
proposés par le staff ne sont pas « parfaits », pour que le manager ait de vraies
raisons de les corriger. Suite de [consignes individuelles](consignes-individuelles-20261116.md) (#796).

## Lots

| Lot | Contenu | État |
| --- | --- | --- |
| 1 (cette PR) | Jugement du staff sur les rôles de #796 (buteur, secours, jeu au pied d'occupation), sang-froid caché (but et touche décisifs), confiance du buteur, fenêtre « Tireurs et lanceur » | fait |
| 2 | Même jugement pour la composition proposée/déléguée (`buildSheet`, `autoLineup`, feuilles de l'IA) et les remplacements du staff (`aiSubs`, match délégué), confiance généralisée (lanceur) | à faire |

Le lanceur reste le talonneur en jeu (choix de poste, pas de jugement : aucun staff
réel ne fait lancer un autre joueur).

## Règles

**Qui juge.** Pour chaque club, carrières du staff (`S.staffCareer`, niveaux 45-85) :
entraîneur dont la fonction couvre le secteur (arrières, attaque, jeu au pied → But et
Jeu au pied ; avants, mêlée, touche → Touche), à défaut l'adjoint, à défaut
l'entraîneur le mieux noté ; sans carrières du staff, un jugement moyen (niveau 60).
Les 116 clubs du Monde jugent avec un membre réel de leur staff. Les clubs de l'IA
suivent exactement la même règle avec leur propre staff.

**Erreur d'estimation.** Fixe pour chaque couple (membre du staff, joueur, attribut) :
empreinte, pas tirage. Elle ne bouge pas d'un match à l'autre, ne consomme aucun tirage
et change seulement quand le membre du staff change (recrutement, départ).

**Sang-froid (caché).** Trait « grands matchs » des joueurs de la base (`hiddenTraitsV2.bigMatches`,
41-80, médiane 61, jusqu'ici sans effet) ; joueurs sans trait (jeunes, profondeur) :
valeur fixe tirée de l'identité, même répartition (46-76, médiane 61). Il pèse
seulement dans les **moments décisifs** : à partir de la 70e minute, au plus 7 points
d'écart (score compté avec l'essai pour une transformation) — tir au but et lancer en
touche de l'équipe qui lance.

**Révélation.** Observations par joueur (`S.staffJudgement.vu`) : +1 pour chaque joueur
sur le terrain à la fin d'un match du club du manager qui a connu un moment décisif,
+1 par tir ou lancer décisif pris, +3 par rapport d'observation. 2, 5 et 10
observations donnent une fourchette de 11, 9 puis 5 points, calculée par la mécanique
de la connaissance des joueurs (`nativeKnowledge.interval` : stable, vraie valeur
dedans, jamais centrée dessus).

**Pas de contradiction manager / staff.** Le manager voit les vraies notes de ses
joueurs (connaissance « club ») ; le staff affiche son **avis** à côté quand il s'en
écarte. Pour le sang-froid, le staff du manager ne sait que ce que le club a vu : il
raisonne sur le milieu de la fourchette affichée (médiane tant qu'elle est inconnue),
jamais sur la vraie valeur. Un club de l'IA, qui connaît ses joueurs depuis plus
longtemps, perçoit le sang-froid avec l'erreur de son staff doublée (asymétrie assumée :
l'IA n'a pas de fiches à afficher).

**Confiance (visible).** Par joueur, au but (`S.staffJudgement.confiance`, bornée à ±20).
Après chaque tir, elle bouge de la surprise : réussite `+6 × (1 − chance)`, échec
`−6 × chance` (10 au lieu de 6 dans un moment décisif). Un buteur qui réussit ce qu'on
attend de lui reste en moyenne à 0. À chaque match de son club, elle revient d'un cran
vers 0 (×0,75, arrondie au dixième, 0 sous 0,5). Libellés : En pleine confiance (≥ 8),
En confiance (≥ 3), Normale, Fragile (> −8), En perte de confiance.

## Formules

- Amplitude : `A(niveau) = 1,5 + 8,5 × (85 − niveau) / 40`, bornée à [1,5 ; 10].
- Erreur : `A × (u1 + u2 − 1)`, u1 et u2 les deux moitiés de l'empreinte FNV de
  `staff|joueur|attribut` (répartition triangulaire, ±A).
- Valeur perçue (choix du staff) : `attribut + erreur` ; au but en plus
  `confiance / 3 + (sang-froid perçu − 61) × 0,15` (0,15 : part des tirs décisifs).
- Valeur réelle (mesures) : même formule avec la vraie note et le vrai sang-froid.
- Réussite au but (avant la courbe « essais réalistes ») : `+ confiance × 0,002
  + (sang-froid − 61) × 0,008` en moment décisif.
- Touche décisive : `+ (sang-froid du lanceur − 61) × 0,003` à la probabilité de gagner son lancer.
- Jeu au pied d'occupation : l'écart se mesure désormais au **meilleur botteur réel**
  des arrières (`min(0, Pied botteur − Pied meilleur) × 0,25 m`), lanceur désigné ou choix du staff.

## Réglages (données)

`STAFF_JUDGEMENT` dans `dist/match-actions.js` : `niveau` (45, 85, défaut 60), `erreur`
(10 → 1,5), `sangFroid` (neutre 61, but 0,008, touche 0,003, choix 0,15, erreurIA 2),
`decisif` (70e minute, 7 points), `confiance` (borne 20, écart 6, écart décisif 10,
retour 0,75, but 0,002, jugement 1/3), `revelation` (paliers 2/5/10, largeurs 11/9/5,
rapport 3). Interrupteur `STAFF_JUDGEMENT_RULES`.

## Compatibilité

- Règles copiées au coup d'envoi (`l.staffJudgementVersion = 1`) : une rencontre
  commencée avant garde le choix d'avant (meilleur « But » réel) et aucun effet de
  confiance ni de sang-froid.
- Sauvegardes : `S.staffJudgement` facultatif (absent = tout le monde à 0, rien de vu) ;
  validé par `saves.js` (confiance réelle bornée, observations 0-99). Aucune migration
  nécessaire, aucune perte. Joueurs partis de tous les effectifs nettoyés après chaque
  match du club du manager.
- Désignations du manager (#796) inchangées : un rôle désigné ignore le jugement.

## Mesures (IA contre IA, carrière world-champ club 102, affiches de la semaine hors club du manager)

Choix du staff contredits par le meilleur choix réel (116 clubs, XV de l'IA) :

| Staff | Buteur contredit | Écart moyen (pts But) | Jeu au pied contredit |
| --- | --- | --- | --- |
| Faible (45) | 7,8 % | 5,4 | 42 % |
| Réel du club | 4,3 % | 3,4 | — |
| Excellent (85) | 0 % | 0 | 10 % |

Le meilleur et le deuxième buteur d'un XV sont séparés de 12 points en médiane : même un
staff faible ne confond que des buteurs proches (crédible ; personne ne fait buter un
pilier). Le levier fréquent est le jeu au pied et, surtout, ce que le staff ne voit pas
(sang-froid, confiance).

300 affiches par cas, graines appariées :

| Côté 0 | Réussite au but | Points | Encaissés | Tirs décisifs, sang-froid bas (< 57) / moyen / haut (> 65) |
| --- | --- | --- | --- | --- |
| Règles coupées (avant) | 69,7 % | 27,9 | 24,0 | — |
| Staff faible | 69,6 % | 28,0 | 23,9 | 56 % / 73 % / 72 % |
| Staff réel | 69,8 % | 28,1 | 24,0 | 58 % / 73 % / 73 % |
| Staff excellent | 70,0 % | 28,1 | 24,1 | 61 % / 72 % / 72 % |

Pas de bouleversement des résultats globaux ; écart net de sang-froid dans les fins de
match serrées. Confiance après 9 semaines : moyenne 0,1, 10e-90e centiles −7,8 / +6,6.

## Critères d'acceptation

`tests/jugement-staff.cjs` : erreur fixe et décroissante, choix imparfaits plus
fréquents avec un staff faible, fenêtre (avis, confiance, fourchettes 11/9/5), confiance
(surprise, borne, retour, sauvegarde), anciennes rencontres, mesures déterministes.
`tests/godot-consignes-individuelles.gd` : affichage des détails dans la fenêtre.

## Lot 3 — avis du staff sur la feuille de match (17/11/2026)

Deux faiblesses du lot 2 : les erreurs d'un staff faible étaient presque invisibles et le manager ne voyait
pas l'avis de son staff.

- **Cause de l'invisibilité** : `native/engine/position-aptitudes.cjs` réattribuait la première ligne
  (`reserveFront`), les postes 4 à 15 (algorithme hongrois) et le banc avec les vraies notes, effaçant la
  perception du staff. La perception (erreur + penchant) s'ajoute désormais à ces trois attributions, pour la
  feuille du club du manager seulement (`staffSheetJudges`). Clubs de l'IA inchangés.
- **Penchant du staff** (`STAFF_JUDGEMENT.composition`) : sous le niveau 70, chaque membre a un penchant stable
  tiré de son identité, l'expérience (âge) ou la forme récente (notes de match), de poids croissant quand le
  niveau baisse (7 points au niveau 45). L'expérience pèse ×1,5 avant un derby ou contre un adversaire plus
  fort. Même erreur d'une semaine à l'autre ; la feuille reste toujours valide (seul l'ordre de préférence change).
- **Apprentissage** : `S.staffJudgement.connu[joueur] = [membre, matchs]` ; chaque match joué au moins 20 minutes
  sous les ordres du membre qui le juge réduit erreur et penchant de 6 %, jusqu'à 40 %. Un nouveau membre repart
  de zéro. Champ facultatif de la sauvegarde (validé dans `saves.js`).
- **Moteur versionné** : `staffJudgementSubs` passe à 2 au coup d'envoi (remplacements du staff avec penchant et
  apprentissage) ; une rencontre commencée en version 1 garde `perceivedFitV1`.
- **Avis affiché** : `staffSheetAdvice()` → `selection.staffAdvice` (projection), au plus 4 postes où le staff
  composerait autrement (écart perçu ≥ 1,5 point), avec la raison qui pèse le plus : fraîcheur, forme,
  expérience, adversaire ou niveau. Écran Composition : bandeau « Avis du staff » dans le briefing, repère « ! »
  et texte complet en info-bulle sur le poste. Le staff peut se tromper : c'est sa perception.

Mesures (12 staffs par niveau, club 102, `tests/avis-staff-feuille.cjs`) : staff à 45 → 4,3 titulaires
différents de l'optimum, 0,7 en première ligne, 14 points de note au poste perdus sur le XV (≈ 1,5 %) ; staff
à 85 → aucun en première ligne, 0,3 point perdu (permutations de valeur égale). Après dix matchs sous ses
ordres, le staff faible ne perd plus que 3,9 points.
