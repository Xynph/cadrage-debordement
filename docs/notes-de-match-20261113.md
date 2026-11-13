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
- ratés : plaquage manqué −0,45 (franchissement subi) et −0,45 sur un essai en jeu courant subi ;
  ballon perdu −0,3 (dernier porteur de l'équipe qui perd le ballon) ; en-avant −0,45 (dernier
  porteur) ; pénalité concédée −0,45 (fautif déduit de la place défensive au contact, sans tirage)
  plus −0,02 avants / −0,008 arrières ; carton jaune −1,4, rouge −2,8 ; tir manqué −0,3 ;
- conquête collective : touche (talonneur, deuxième ligne) et mêlée (première ligne, deuxième
  ligne à 40 %) : +0,045 à +0,06 gagnée, +0,1 à +0,12 volée, −0,09 à −0,1 perdue ;
- collectif au prorata des minutes : écart au score (±0,45) et résultat final (±0,2) ;
- influence : niveau au poste par rapport à l'équipe du jour (±0,35) ;
- poste : décalage par famille de poste (`POSTE`, mesuré sur 3 000 notes) pour que chaque poste
  ait la même moyenne attendue (les troisième ligne ont beaucoup plus de faits que les piliers) ;
- `impact = 1,08 × faits + (collectif + influence − décalage du poste) × part`,
  `note = 6,5 + 3,2 × tanh(impact / 3,2)`, `part` = minutes jouées / 80.

Homme du match (30 minutes au moins) : meilleure performance relative à son poste, impact
rapporté à l'écart-type du poste (mêlé à 25 % d'un écart commun pour ne pas sur-récompenser
les postes à faible dispersion) ; à égalité : la note, le vainqueur, le plus de faits, l'identifiant.

Étalonnage : voir « Équilibre » (mesure en mode Monde du 13 novembre). Le décalage `POSTE` a été
mesuré par l'agent précédent sur 20 journées de l'ancien mode France (3 000 notes) et n'a pas été
re-mesuré en mode Monde.

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

## Matchs internationaux (sélections)

Le moteur international (`international-competitions.cjs`) simule le score seul, sans journal.
Après chaque écriture de la carrière internationale (`international-native.cjs`, `write`), les
rencontres jouées (deux feuilles `appearances` et le score) sont transmises au domaine, qui les
note avec **le même calcul** : un journal réduit aux faits connus — chaque essai du score
attribué à un joueur de façon déterministe (empreinte de la rencontre ; arrières ×3, troisième
ligne ×2, autres ×1) —, le résultat, le niveau au poste et le poste ; titulaires 80 minutes,
remplaçants entrés 25 minutes. Aucun tirage, aucun résultat modifié (tests). Homme du match
désigné de la même façon.

Enregistrement à part du club : `S.matchNotes.selection` = `lignes` (par joueur du monde du jeu,
20 derniers matchs : date, adversaire, compétition, minutes, note ×10, essais, homme du match) et
`vus` (rencontres déjà notées, 400 au plus). Bloc absent = aucun match international noté
(anciennes sauvegardes). Fiche joueur, onglet Performances : bloc « Sélection » (moyenne, forme,
trois dernières rencontres).

Effets, dans les bornes existantes et coupés par `CD_NOTES_EFFETS=0` :
- sélections suivantes : forme en club (3 notes au moins) et forme internationale (5 dernières,
  3 au moins), la sélection pesant 40 % quand les deux existent ; toujours −1,5 à +2 points ;
- valeur marchande : moyenne de saison et moyenne internationale (20 dernières, 3 au moins) à
  25 % ; toujours −8 % à +12 %.

Limite : faute de journal, une note internationale ne reflète que les essais, le résultat, le
niveau et le poste (dispersion plus faible qu'en club).

## Équilibre

Mesure du 13 novembre (barème recalibré), **mode Monde** (`world-champ`, club 102, graine 4242,
matchs délégués, conférences et rendez-vous réglés automatiquement), vrai worker, effets actifs.
La mesure ne couvre que **5 semaines de la première saison** (17 août – 21 septembre 2026 :
2 035 matchs notés tous championnats du monde confondus, 60 923 notes de joueurs ayant joué
40 minutes ou plus) : le harnais de mesure est resté bloqué ensuite sur un match du manager en
cours (« Aucun nouveau match disponible »), puis a été arrêté à l'échéance. Les deux saisons demandées n'ont pas été simulées ; la colonne « sans effet » a été
interrompue par manque de mémoire. Les chiffres de l'ancien mode France (ancien barème) ne sont
plus comparables et ont été retirés.

| Notes (≥ 40 min) | Cible | Mesure Monde |
|---|---|---|
| Moyenne | 6,5–6,7 | 6,55 |
| Écart-type global | — | 1,16 |
| Part ≥ 8 | 10–15 % | 13,5 % |
| Part ≥ 9 | 2–4 % | 2,7 % |
| Part < 5,5 | ~10 % | **16,5 %** (trop) |
| Écart-type d'un même joueur (4 matchs et plus) | 0,8–1,0 | **0,66** (fenêtre courte : 4 à 5 matchs, biais vers le bas) |

Toutes minutes confondues (remplaçants compris) : moyenne 6,54, écart-type 1,01, ≥ 8 : 10 %,
≥ 9 : 1,9 %, < 5,5 : 12,5 %.

Hommes du match (2 035) : avants 46 %, arrières 54 %. Par famille : troisième ligne 27,2 % (trois
places, ≈ 9 % chacune), ailier 22,4 % (deux places, ≈ 11 %), centre 12,5 % (≈ 6 %), deuxième ligne
12 % (≈ 6 %), demi de mêlée 9,4 %, ouvreur 6 %, pilier 5,1 % (≈ 2,5 %), arrière 3,6 %,
talonneur 1,7 %. Aucune place au-dessus de 20 % ; talonneur et arrière sont sous-représentés.

Fin de mesure (21 septembre, saison 1, effets actifs) : satisfaction moyenne du club 65,4 ; valeur
marchande moyenne (tous clubs) 486 612 € ; salaire moyen 4 769 €/sem. (club du manager 3 687) ;
niveau moyen 68,9 ; taille de `S.matchNotes` 140 Ko. Les effets restent dans leurs bornes par
construction (tests « Effets bornés ») ; sur 5 semaines, aucun écart notable ne peut être établi
sans la colonne de référence.

Limites et suite :
- la queue basse est trop épaisse (16,5 % < 5,5) : réduire le poids du plaquage manqué
  (−0,45) et de la pénalité concédée (−0,45), ou rapprocher le décalage `POSTE` des avants, puis
  re-mesurer ;
- re-mesurer `POSTE` en mode Monde (mesuré en mode France) ;
- les matchs internationaux (WIP) reçoivent `familles` : le décalage de poste (jusqu'à −2 pour
  une troisième ligne) s'applique alors à un journal réduit aux essais et fait baisser fortement
  les avants ; à neutraliser pour les sélections ;
- deux saisons complètes avec et sans effets restent à simuler.

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

**Vue XV type** (`native/godot/ui/equipe_type_view.gd`), façon visuel « XV de la journée » publié chaque semaine pour le Top 14,
en carte à partager 1920×1080 opaque (le jeu ne transparaît pas) :
- en-tête « XV DE LA 7E JOURNÉE · TOP 14 » ou « XV DE LA SAISON 2026-2027 · TOP 14 », saison, critère, nombre de clubs représentés ;
- terrain vu de dessus, vertical (en-buts, poteaux, 22 m, 10 m, médiane, tirets des 5 et 15 m), quinze cartes en formation :
  piliers et talonneur devant, deuxième ligne, troisième ligne (6, 8, 7), charnière 9-10, ailiers 11 et 14 sur les côtés,
  centres 12-13, arrière au fond ;
- chaque carte : fenêtre aux couleurs du club (dégradé et bandes obliques), portrait, numéro dans un disque aux couleurs du club,
  pastille de note (barème de couleur partagé : vert 7 et plus, or 6 à 7, rouge sous 6), écusson, nom, puis « 3e sélection »
  (journée, en or à partir de la 3e) ou « 17 matchs » (saison) et sigle du club ; infobulle détaillée ;
- joueur de la journée (meilleure moyenne pour la saison) : carte agrandie (×1,15), cadre et halo or, bandeau « ★ JOUEUR DE LA
  JOURNÉE », et grande fiche à gauche (portrait 250 px sur les couleurs du club, note, compteur de sélections) ;
- entraîneur de la journée sous la fiche (écusson, nom, club, écart) ; liseré et halo verts sur les joueurs du club du manager,
  rappelés par leur nom ; légende de lecture à droite.
Ouverte depuis l'actualité (vignette cliquable du fil « Vie du club ») et depuis Compétitions (bouton « XV type »). Écussons et
portraits passent par le mécanisme des packs d'identité comme les autres écrans (`G.crest` / `G.portrait` : `logoPath`, `portraitPath`
projetés par identifiant), avec repli sur l'écusson et le portrait originaux du jeu ; aucune image réelle dans le dépôt.
Test : `tests/godot-equipe-type.cjs` (ouverture par les deux entrées, 15 cartes avec portrait, écusson et note, aucune carte qui
en chevauche une autre en tenant compte de l'agrandissement, une seule vedette, écusson du jeu sans pack, logo du pack avec un pack
de test).
