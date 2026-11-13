# Notes de match enregistrées et utilisées (13 novembre 2026)

Demande de Léo : « Les notes de match doivent servir à quelque chose et être enregistrées. »

## Calcul (native/engine/match-notes.cjs)

Un seul calcul, `moteur().noter(journal, contexte)`, lecture pure du journal du moteur : aucun
tirage, rien n'est écrit. Il sert au direct (note en cours, sur le journal déjà montré) et à la
fin de match (note enregistrée, sur le journal complet) : quand tout a été montré, la note du
direct est exactement la note enregistrée (test `tests/match-notes.cjs`).

Les matchs simulés sans direct (autres rencontres de la journée, match délégué) n'écrivaient pas
de scène dans `l.events`. Le domaine leur tient un journal de faits transitoire (`l.notesJournal`,
non énumérable, jamais sauvegardé), construit par la même fonction du moteur
(`captureMatchAction`) : scores, essais et curseur du générateur sont identiques avec ou sans ce
journal (test dédié).

Échelle 1–10 à une décimale, base 6,5 au coup d'envoi (remplaçant : 6,5 à l'entrée) :

- faits individuels : course (0,03 + mètres/32, plafond 1,1 ; +0,3 pour un franchissement de
  22 m et plus), essai (+1,05), ballon récupéré (+0,28, compte comme plaquage), plaquage (+0,05 ;
  plaqueur nommé par le moteur — fait `tackler` —, sinon déduit de la place défensive, réparti
  entre les avants au contact), plaquage manqué (−0,16 ; −0,15 sur un essai en jeu courant subi),
  réception (+0,06), jeu au pied (+0,04, +0,12 au-delà de 30 m), pénalité réussie (+0,3) ou
  manquée (−0,18), conquête (touche : talonneur et deuxième ligne ; mêlée : première ligne, et
  deuxième ligne à 40 % ; gagnée +0,045 à +0,06, volée +0,07 à +0,08, perdue −0,06 à −0,07),
  carton (jaune −0,8, rouge −2), pénalité concédée (−0,03 avants, −0,012 arrières), faute de main
  (−0,012 collectif) ;
- collectif au prorata des minutes : écart au score (±0,45 au plus) et résultat final (±0,2) ;
- influence : niveau au poste du joueur par rapport à son équipe du jour (±0,35 au plus), pour
  que la note suive aussi la qualité (le moteur désigne une partie des porteurs par rotation) ;
- étalonnage : `note = 6,5 + 3,2 × tanh((0,72 × faits − 0,28 × part + (collectif + influence) × part) / 3,2)`,
  `part` = minutes jouées / 80.

Homme du match : meilleure note parmi ceux qui ont joué 30 minutes ou plus (à égalité : le
vainqueur, puis le plus de faits).

## Enregistrement (`S.matchNotes`, version 2 ; voir aussi « XV type » plus bas)

| Champ | Contenu | Taille |
|---|---|---|
| `joueurs` | tous les joueurs ayant joué : `s` = [matchs, somme des notes ×10, minutes, essais, plaquages, mètres, hommes du match], `f` = 5 dernières notes ×10 | ~95 Ko par saison (mode commun) |
| `detail` | saison en cours, joueurs du club du manager : [semaine, adversaire, compétition, minutes, note ×10, essais, plaquages, mètres, homme du match] (60 au plus) | quelques Ko |
| `passees` | résumé par saison passée : [saison, club, matchs, moyenne ×10, essais, hommes du match], 8 saisons au plus, joueurs encore en jeu seulement | borné |
| `confiance` | effet cumulé de la saison sur la satisfaction (±6) | — |
| `semaine`, `recompenses`, `dernier` | notes de la journée (équipe type), 40 dernières distinctions, dernier match du manager | bornés |

Migration : une sauvegarde sans `matchNotes` reste valide, l'historique est vide et commence au
match suivant (rien n'est inventé pour le passé). Validation stricte à l'import (échelle,
tailles, types). En fin de saison (`advanceSeason`), le détail devient un résumé.

## Utilisation (effets bornés)

`CD_NOTES_EFFETS=0` (option `notesEffets:false` du worker) garde les notes sans aucun effet :
c'est la mesure d'équilibre ci-dessous.

| Effet | Règle | Bornes |
|---|---|---|
| Moral | satisfaction du joueur du club : +1 si ses 3 dernières notes font 7,2 de moyenne ou plus, −1 si 5,8 ou moins | ±1 par match, ±6 par saison, bornes 20–95 existantes |
| Composition des entraîneurs IA | score de choix de `buildSheet` × (1 + (forme − 6,5) × 0,03), forme = 5 dernières notes (2 au moins) | −3 % à +4 % ; club du manager non concerné |
| Valeur marchande | indemnité `club-transfers.value` × (1 + (moyenne − 6,5) × 0,08), moyenne de saison (5 matchs ; sinon saison passée si 10 matchs) | −8 % à +12 % |
| Intérêt des clubs IA | note estimée (`club-transfers`, `club-directions`) + (moyenne − 6,5) × 2 | −2 à +3 points |
| Exigence salariale | `askingWage` (négociation) × (1 + (moyenne − 6,5) × 0,04) | −4 % à +6 % |
| Sélections nationales | score de forme du sélectionneur (`international-callups`) + (forme − 6,5) × 1,2 (3 notes au moins) | −1,5 à +2 points |
| Progression | jeune de 21 ans au plus, 40 minutes et note ≥ 7,5 : `growPlayer` reçoit (note − 7,3) × 0,02 d'expérience | 0,03 au plus par match (un match ordinaire en donne ~0,12) |
| Distinctions | homme du match (actualité), équipe type de la journée de la compétition du manager, joueur du mois (toutes les 4 journées) et de la saison du club | — |

## Équilibre

Deux saisons simulées par le vrai worker (mode commun, club 29, graine 4242, matchs délégués,
conférences et rendez-vous réglés automatiquement) : `main` (avant), cette branche avec
`CD_NOTES_EFFETS=0` (notes sans effet) et cette branche (effets actifs). Notes = 5 dernières
notes de tous les joueurs ayant joué (≈ 6 000).

| Fin de saison 2 | main | notes sans effet | effets actifs |
|---|---|---|---|
| Moyenne des notes | — | 6,64 | 6,63 |
| Écart-type | — | 0,67 | 0,65 |
| Part ≥ 8 / ≥ 9 | — | 4,6 % / 0,15 % | 3,9 % / 0,17 % |
| Part entre 5,5 et 8 | — | 93 % | 94 % |
| Satisfaction moyenne (club) | 72,85 | 72,85 | 72,26 |
| Valeur marchande moyenne (tous clubs) | 602 810 € | 602 810 € | 608 424 € (+0,9 %) |
| Salaire moyen / club du manager (€/sem.) | 5 987 / 5 409 | 5 987 / 5 409 | 5 985 / 5 340 |
| Niveau moyen | 71,85 | 71,85 | 71,83 |

Sans effet, l'état sportif est identique à `main` (scores, historique, effectifs, salaires,
satisfaction) : seules l'actualité et la boîte du manager diffèrent (distinctions). Les écarts
de la dernière colonne viennent donc des effets voulus, et restent faibles (pas de dérive en
deux saisons). Taille : 95 Ko (saison 1) puis 133 Ko (saison 2, avec résumés) dans une
sauvegarde de 5,7 à 7 Mo.

## XV type : équipe-type de la journée et équipe de la saison (demande de Léo, 13 novembre 2026)

« Équipe de la saison aussi, comme en vrai dans le Top 14 (ils font aussi l'équipe-type de la journée de championnat). »

**Équipe-type de la journée.** À la clôture de chaque journée (`finJournee`), pour chaque championnat dont une rencontre de
saison régulière a été jouée (France : Top 14 « elite » et Pro D2 « accession » ; monde : chaque ligue), que le club du manager y
figure ou non. Quinze joueurs, un par poste : pilier gauche, talonneur, pilier droit, 2 deuxièmes lignes, 3 troisièmes lignes
(ailes et numéro 8), 9, 10, 2 ailiers, 2 centres, arrière, numérotés de 1 à 15 (le numéro 8 revient au joueur inscrit à ce poste). Choix sur la
note du match (joueurs ayant joué 40 minutes ou plus) ; départage déterministe : minutes, essais, puis identifiant. Le joueur de la
journée est la meilleure note du XV. L'entraîneur de la journée est celui du club à la plus large victoire (puis le plus de points
marqués, puis l'identifiant du club) ; son nom vient du personnel de carrière s'il existe, sinon l'écran affiche « Staff du club ».
Actualité : une ligne « XV de la 7e journée · Top 14 » pour le championnat du manager (nombre et noms de ses joueurs présents, sinon
« aucun joueur de … »), plus la distinction `equipe` pour chacun de ses joueurs. Les autres championnats sont enregistrés
(`equipes`) et consultables dans la vue XV type, sans surcharger le fil d'actualité.

**Équipe de la saison.** Choisie à la fin de la saison régulière de chaque championnat (`regulierFini` : plus de journée de
championnat à jouer), donc **avant les phases finales**, sur les seules rencontres de saison régulière (`reg`) : moyenne de saison
avec un minimum de la moitié des journées jouées, puis nombre de sélections en équipe-type de la journée, puis matchs, puis
identifiant. Même composition (un joueur par poste). Un championnat dont la fin de saison régulière n'a pas été vue (reprise d'une
sauvegarde) est rattrapé à `advanceSeason` (`finSaison`). Publiée dans l'actualité (« XV de la saison · Top 14 »), enregistrée dans
`S.matchNotes.saisons` (6 saisons au plus, 40 fiches), distinction `xvsaison` pour les joueurs du manager, et affichée dans la fiche du joueur
(repère de carrière « XV de la saison 2026-2027 · Top 14 », nombre de sélections en XV de la journée).

**Effets** (bornés, coupés par `CD_NOTES_EFFETS=0`) : un lauréat de l'équipe de la saison de l'an dernier ou de la saison en cours gagne
+3 % de valeur marchande et +0,5 point d'intérêt des clubs, dans les mêmes bornes qu'avant (−8 % à +12 % ; −2 à +3 points).

**Sauvegarde.** `S.matchNotes.version` passe à 2 : `reg` {championnat: {joueur: [matchs, somme des notes ×10, minutes, essais,
sélections, groupe de poste, club]}}, `regJ` (journées jouées par championnat), `equipes` (dernière équipe-type de chaque championnat)
et `saisons`. Une sauvegarde en version 1 reste valide : `migrer` ajoute les champs vides au premier usage, rien n'est inventé pour
le passé. `semaine.notes` est vidé à la publication (transitoire). Ordre de grandeur : +40 Ko par saison complète (mode commun).
Rien n'est tiré au hasard et les résultats de match sont inchangés.

**Vue XV type** (`native/godot/ui/equipe_type_view.gd`) : terrain vu de dessus, vertical, quinze cartes en formation (avants en haut,
arrière au fond), joueur mis en avant (cadre or, carte détaillée à gauche), entraîneur en bas, liseré vert sur les joueurs du
manager, compteur de sélections ; pour l'équipe de la saison, moyenne et nombre de matchs. Ouverte depuis l'actualité (vignette
cliquable du fil « Vie du club ») et depuis Compétitions (bouton « XV type »). Écussons et portraits passent par le mécanisme des
packs d'identité comme les autres écrans (`logoPath`, `portraitPath` projetés par identifiant), avec repli sur l'écusson et le
portrait originaux du jeu ; aucune image réelle dans le dépôt.
