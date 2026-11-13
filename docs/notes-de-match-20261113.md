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

Barème recalibré le 13 novembre (demande de Léo : notes trop serrées, homme du match trop
souvent troisième ligne). Valeurs dans `B` (match-notes.cjs) :

- grosses performances : essai +1,5 ; course 0,03 + mètres/24 (plafond 1,5) et +0,6 pour un
  franchissement de 22 m et plus ; ballon récupéré +0,65 (compte comme plaquage) ; plaquage
  +0,08 (+0,05 s'il stoppe net, gain < 2 m) ; jeu au pied de 30 m et plus +0,3 ; 50:22 +0,5 ;
  pénalité réussie +0,4 ; conquête volée +0,35 au voleur ;
- ratés : plaquage manqué −0,32 (franchissement subi) et −0,45 sur un essai en jeu courant subi ;
  ballon perdu −0,3 (dernier porteur de l'équipe qui perd le ballon) ; en-avant −0,45 (dernier
  porteur) ; pénalité concédée −0,32 (fautif déduit de la place défensive au contact, sans tirage)
  plus −0,02 avants / −0,008 arrières ; carton jaune −1,4, rouge −2,8 ; tir manqué −0,3 ;
- conquête collective : touche (talonneur, deuxième ligne) et mêlée (première ligne, deuxième
  ligne à 40 %) : +0,045 à +0,06 gagnée, +0,1 à +0,12 volée, −0,09 à −0,1 perdue ;
- collectif au prorata des minutes : écart au score (±0,45) et résultat final (±0,2) ;
- influence : niveau au poste par rapport à l'équipe du jour (±0,35) ;
- poste : décalage par famille de poste (`POSTE`, mesuré sur 3 000 notes) pour que chaque poste
  ait la même moyenne attendue (les troisième ligne ont beaucoup plus de faits que les piliers) ;
- `impact = 1,08 × faits + (collectif + influence − décalage du poste) × part`,
  `note = 6,5 + 3,2 × tanh(impact / 3,2)` (un impact négatif compte pour 0,8 : plancher relevé),
  `part` = minutes jouées / 80.

Homme du match (30 minutes au moins) : meilleure performance relative à son poste, impact
rapporté à l'écart-type du poste (mêlé à 25 % d'un écart commun pour ne pas sur-récompenser
les postes à faible dispersion) ; à égalité : la note, le vainqueur, le plus de faits, l'identifiant.

Étalonnage : voir « Équilibre » (mesure en mode Monde du 13 novembre). Le décalage `POSTE` a été
mesuré sur 20 journées de l'ancien mode France (3 000 notes) et n'a pas été re-mesuré en mode Monde.

## Enregistrement (`S.matchNotes`, version 1)

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

## Matchs internationaux (sélections)

Le moteur international (`international-competitions.cjs`) simule le score seul, sans journal.
Après chaque écriture de la carrière internationale (`international-native.cjs`, `write`), les
rencontres jouées (deux feuilles `appearances` et le score) sont transmises au domaine
(`enregistrerSelection`), qui les note avec **le même calcul** : un journal réduit aux faits
connus — chaque essai du score attribué à un joueur de façon déterministe (empreinte de la
rencontre ; arrières ×3, troisième ligne ×2, autres ×1) —, le résultat et le niveau au poste ;
titulaires 80 minutes, remplaçants entrés 25 minutes. Aucun tirage, aucun résultat modifié (tests).

**Pas de décalage de poste** : le décalage `POSTE` est étalonné sur un journal complet (les avants
y ont beaucoup de plaquages et de conquêtes qui compensent). Appliqué à un journal réduit aux
essais, il aurait sous-noté tous les avants (jusqu'à −2 points pour une troisième ligne). Le
contexte porte donc `journalReduit: true` : pas de décalage ni d'écart-type de poste ; à niveau
égal et sans essai, un pilier, un talonneur et un ailier ont la même note (test dédié).
**Homme du match** désigné aussi pour ces matchs (au moins 30 minutes ; à égalité de performance :
la note, le vainqueur, le plus de faits, l'identifiant) : le marqueur d'un essai l'emporte à niveau
égal. Un journal complet n'existe pas pour ces rencontres, d'où cette approximation.

Enregistrement à part du club : `S.matchNotes.selection` = `lignes` (par joueur du monde du jeu,
**10 derniers matchs** : date, adversaire, compétition, minutes, note ×10, essais, homme du match) et
`vus` (rencontres déjà notées, 400 au plus). Bloc absent = aucun match international noté
(anciennes sauvegardes). Fiche joueur, onglet Performances : panneau « Sélection » (moyenne et
forme sur les dix dernières sélections, nombre d'hommes du match, trois dernières rencontres ;
« Aucun match international noté. » sinon).

Effets, dans les bornes existantes et coupés par `CD_NOTES_EFFETS=0` :
- sélections suivantes : forme en club (3 notes au moins) et forme internationale (5 dernières,
  3 au moins), la sélection pesant 40 % quand les deux existent ; toujours −1,5 à +2 points ;
- valeur marchande : moyenne de saison et moyenne internationale (10 dernières, 3 au moins) à
  25 % ; toujours −8 % à +12 %.

Limite : faute de journal, une note internationale ne reflète que les essais, le résultat et le
niveau (dispersion plus faible qu'en club).

## Sauvegarde en mode Monde : tables par joueur

La validation générique de la sauvegarde (`safeTree`, `dist/saves.js`) refuse toute table de plus de
2 000 clés (hors `interclubWorld.pairs`). Le Monde compte plus de 5 000 joueurs : dès la deuxième
journée, `matchNotes.joueurs` dépassait 2 000 joueurs notés et **la journée suivante échouait**
(« Le fichier contient des données de carrière incohérentes », commande `advance_day`). Les tables
par joueur de `matchNotes` (`joueurs`, `passees`, `detail`, `selection.lignes`) sont désormais admises
jusqu'au nombre de joueurs du monde plus 2 000 ; au-delà, refus (test).

## Libellés

- Effectif : colonne **« MOY. »** (tri « Moyenne »), infobulle de l'en-tête et de chaque pastille :
  « Moyenne de la saison en cours » ; colonne FORME : cinq dernières notes.
- Fiche joueur, « Performances de la saison » : **« MOYENNE SAISON · N matchs »**, infobulle « Moyenne de
  la saison en cours sur N matchs (notes de 1 à 10, 6,5 au coup d'envoi) ».
(Test Godot : `RosterColumnNote` = « MOY. », `FullPlayerNoteMatches` = « MOYENNE SAISON · N matchs ».)

## Tests en mode Monde

Consigne de Léo : plus aucun test dans l'ancien mode France ; seul `world-champ` est autorisé. Les tests
`match-notes` et `godot-notes-match` n'ont plus `CD_MODES_HERITES` ni `france-harness` : le domaine est
testé dans une VM minimale (`domaine()`), les carrières sont des carrières Monde ouvertes par
`tests/helpers/carriere-monde.cjs` avec les mêmes commandes publiques que le jeu. Les échecs
« rencontre hors calendrier » et « Aucun nouveau match disponible » d'un agent précédent **ne sont pas
un bug du moteur** : ce sont des gestes de cadence manquants. Le Monde se joue de deux façons :

1. **cadence hebdomadaire** (sans l'option `dailyCalendar`, celle des autres tests Monde de main,
   p. ex. `youth-matches-worker`) : `begin_match`, `delegate` (ou le direct), `finish_round`, la semaine
   suivante s'ouvre d'elle-même ; une semaine sans match se clôt par `finish_round` ; c'est la plus
   rapide (carrière prête en ~50 s) ;
2. **cadence journalière du jeu** (`dailyCalendar`, presse obligatoire, carrière internationale) :
   le calendrier avance jour par jour (`advance_day` avec `fromDate = meta.calendarToday`) ;
   `begin_match` n'est possible que le jour de la rencontre (`meta.calendarCadence.matchReady`, sinon
   « Le coup d'envoi est disponible le jour de la rencontre ») ; les rendez-vous obligatoires
   (presse, conseil, médical) se règlent avant chaque pas (`settleClubMeetings`) ; la semaine se clôt
   par les `advance_day` suivants. **À vérifier** : après un match *direct* joué en cadence journalière,
`clubLife.matchNotes.dernier` est encore `null` juste après la causerie d'après-match (en cadence
hebdomadaire il est rempli) ; constaté une fois (test direct, 400 s), non creusé faute de temps. Les
matchs délégués en cadence journalière sont bien notés (mesure d'équilibre, 319 matchs). Si
l'enregistrement du direct n'arrive qu'au pas suivant, c'est voulu ; sinon c'est un défaut du moteur
Monde journalier à isoler.

Les helpers `jusquAuMatch`, `jouerLeMatch`, `jusquALaSemaineSuivante` et `jouer` suivent cette
cadence ; `ouvrir({ hebdomadaire: true })` choisit la première. Contraintes de la machine : un Monde
complet pèse 1,3 à 1,7 Go de mémoire (un worker tué par manque de mémoire ne laisse aucun message,
code 137) et ~120 Mo de profil sur disque ; chaque `import` crée une copie de sécurité (limite de 8
copies ou 256 Mio) : au plus trois imports par test.

Le test « aucun résultat changé » compare deux carrières Monde de même graine, l'une avec l'option
`notes:false` du worker (domaine des notes absent : pas de journal transitoire, pas de notes de
sélection), effets coupés des deux côtés : mêmes résultats de toute la journée et même curseur du
générateur.

## Équilibre

Mesure du 13 novembre, **mode Monde** (`world-champ`, club 102, graine 4242, effets coupés
(`notesEffets:false`), matchs délégués, rendez-vous réglés, calendrier avancé jour par jour) : **319
matchs** de toutes les compétitions du monde (17 août – 2 novembre 2026, 6 matchs du manager), **9 551
notes** de joueurs ayant joué 40 minutes ou plus (13 962 toutes minutes confondues). Les variantes du
barème sont évaluées sur **les mêmes matchs** dans la même simulation (le calcul est pur : aucun
tirage, aucun résultat modifié) en substituant temporairement les valeurs de `B`. Une première série
(362 matchs, 7 variantes sur le plaquage manqué et la pénalité) a donné les mêmes colonnes « avant »
(17,4 % sous 5,5).

Recalibrage de la queue basse (16,5–17,5 % de notes sous 5,5 pour une cible d'environ 10 %) :
plaquage manqué −0,45 → **−0,32**, pénalité concédée −0,45 → **−0,32**, et plancher relevé :
un impact négatif compte pour **0,8** avant la compression (`B.negatif`). Alléger seulement le plaquage
manqué et la pénalité ne suffisait pas (15,8 % avec −0,32, 14,8 % avec −0,25) : la queue vient de
la dispersion des troisième ligne, deuxième ligne, ouvreurs et arrières, pas seulement de ces
deux faits.

| Notes (≥ 40 min, 9 551) | Cible | Avant | **Après** |
|---|---|---|---|
| Moyenne | 6,5–6,7 | 6,56 | **6,68** |
| Écart-type | — | 1,18 | **1,07** |
| Part ≥ 8 | 10–15 % | 14,1 % | **14,4 %** |
| Part ≥ 9 | 2–4 % | 2,8 % | **2,8 %** |
| Part < 5,5 | ~10 % | 17,5 % | **10,8 %** |

Toutes minutes confondues (13 962) : moyenne 6,55 → 6,65, écart-type 1,02 → 0,93, ≥ 8 : 10,4 % → 10,6 %,
≥ 9 : 1,9 % → 2,0 %, < 5,5 : 12,9 % → 7,9 %. Variantes essayées (part < 5,5, moyenne) : −0,32/−0,32 seul
15,8 % (6,61) ; avec `negatif` 0,85 : 11,9 % (6,66) ; **0,8 : 10,8 % (6,68)** ; 0,75 : 9,4 % (6,70) ;
0,7 : 8,1 % (6,72) ; −0,38/−0,38 avec 0,8 : 11,5 % (6,66). Les parts ≥ 8 et ≥ 9 ne bougent pas (côté
positif intact) ; la moyenne monte de 0,12.

Par famille de poste (avant → après) :

| Poste | < 5,5 avant | < 5,5 après | Moyenne | Hommes du match |
|---|---|---|---|---|
| Pilier | 8,0 % | 3,9 % | 6,46 → 6,54 | 8,5 % |
| Talonneur | 20,0 % | 4,2 % | 6,42 → 6,76 | 3,8 % |
| Deuxième ligne | 21,9 % | 13,2 % | 6,40 → 6,53 | 5,0 % |
| Troisième ligne | 22,9 % | 17,0 % | 6,66 → 6,75 | 23,2 % |
| Demi de mêlée | 14,9 % | 10,8 % | 6,74 → 6,80 | 8,8 % |
| Ouvreur | 21,9 % | 13,9 % | 6,46 → 6,55 | 7,8 % |
| Ailier | 8,0 % | 5,3 % | 6,78 → 6,84 | 22,3 % |
| Centre | 15,8 % | 9,7 % | 6,62 → 6,69 | 17,9 % |
| Arrière | 26,0 % | 15,3 % | 6,42 → 6,69 | 2,8 % |

Homme du match (319, inchangé par le recalibrage : il se calcule sur l'impact relatif au poste, avant
l'échelle) : avants 40 % / arrières 60 %. Troisième ligne 23,2 % (3 places sur 15 : 20 % attendus),
ailier 22,3 % (2 places : 13 % attendus, **trop**), centre 17,9 % (13 % attendus, un peu trop),
pilier 8,5 %, demi de mêlée 8,8 %, ouvreur 7,8 %, deuxième ligne 5,0 % (13 % attendus, **trop peu**),
talonneur 3,8 % (7 % attendus), arrière 2,8 % (7 % attendus, **trop peu**). Aucune place au-dessus
de 25 %.

Limites et suite :
- la queue reste épaisse pour les troisième ligne (17 %), les arrières et les ouvreurs (14–15 %) : leur
  écart-type est le plus fort (1,2 à 1,4) ; piste : écart-type par poste dans l'échelle plutôt qu'un
  plancher commun ;
- homme du match : ailiers et centres sur-représentés, deuxième ligne et arrières sous-représentés :
  l'écart-type de poste (`POSTE`) reste celui de l'ancien mode France et n'a pas été re-mesuré en
  Monde (le décalage de moyenne, lui, donne des moyennes par poste entre 6,5 et 6,8) ;
- écart-type d'un même joueur (cible 0,8–1,0) : non mesuré cette fois (fenêtre de 6 semaines) ;
- les effets (satisfaction, valeur, intérêt, salaire, compositions) ne sont pas mesurés ici
  (effets coupés) ; deux saisons complètes avec et sans effets restent à simuler ;
- fenêtre courte : début de saison seulement (6 matchs du manager), compétitions encore en
  poules ; à refaire sur une saison complète.
