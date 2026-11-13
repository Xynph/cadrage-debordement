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

Étalonnage (6 142 notes, 20 journées simulées) : moyenne 6,62, écart-type 1,02, 11,5 % ≥ 8,
2,0 % ≥ 9, 10,3 % < 5,5 ; écart-type d'un même joueur sur ses matchs : 1,05. Hommes du match
(140) : avants 50 %, arrières 50 % ; troisième ligne aile 21 % (deux postes), ailier 17 % (deux
postes), centre 14 % (deux postes), deuxième ligne 9 %, demi de mêlée 9 %, numéro 8 6 %,
pilier gauche 6 %, arrière 5 %, ouvreur 5 %, pilier droit 5 %, talonneur 3 %.

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
