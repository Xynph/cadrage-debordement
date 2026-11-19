# Vente de joueurs

> **Statut** : implémenté (game-designer + gameplay-programmer + ui-programmer CCGS, 19/11/2026, mode autonome, rigueur `minimal`) ; décisions de Léo du 19/11/2026 intégrées (offres spontanées, période des mutations LNR)
> **Mode** : carrière Monde (`world-champ`) uniquement
> **Cap** : consolider — brancher le mécanisme de vente déjà présent dans le moteur, ne rien inventer de lourd
> **Liés** : `docs/gdd/budget-transferts.md` (PR #1001, R4 « ventes : reconstitution partielle »), fiches UX 07, 08, 09, 05
> **Code** : `native/engine/vente-joueurs.cjs` + `vente-joueurs.json` (réglages), commandes dans `gestion.cjs`, vue dans `model.cjs`, courriers dans `club-mail.json` ; Godot `ui/player_sales_view.gd` ; tests `tests/vente-joueurs.cjs`, `tests/godot-vente-joueurs.{cjs,gd}`

## 1. Vue d'ensemble

Le manager peut **proposer un joueur aux autres clubs**, recevoir leurs **offres** — et, sans rien proposer, des **offres spontanées** pour ses meilleurs joueurs — puis **accepter**, **demander plus** (une fois) ou **refuser**. Une vente fait entrer l'indemnité dans la caisse du club et, si le budget de transferts existe, en rend la moitié à l'enveloppe de recrutement.

Fidèle au règlement LNR, une cession ne se **conclut** que pendant la **période des mutations** (1er mai – 30 juin). Le reste de l'année, on propose, on reçoit des offres et on négocie ; une offre acceptée devient un **accord conclu, effectif au 1er mai** : le joueur reste au club et joue jusque-là, l'argent et le départ arrivent à l'ouverture.

Le moteur contenait déjà le mécanisme (héritage de l'interface web) et il tournait déjà en carrière Monde : la mise en liste restait simplement inaccessible depuis Godot. Le chantier l'expose (commandes, vue, écrans, courrier), avec quatre corrections : garde d'effectif, coût de calcul, vocabulaire, période des mutations.

### Carte de l'existant (vérifiée le 19/11/2026, `main` 8637395)

| Élément | Où | Ce qu'il fait |
|---|---|---|
| Mise en liste | `dist/economy.js:446` `toggleListing` | `S.economy.listings[id]=true` ; retrait = efface aussi les offres du joueur. Refus si `saleBlocked` ou match en cours (`economyLocked`, l.313). **Non appelé** par Godot (fait `toast`/`render`) : `sale_list` le remplace |
| Blocages | `dist/economy.js:350` `saleBlocked` | espoir (`academy-`/`youth-`) de moins de 20 ans ; recrue arrivée cette saison depuis moins de 3 journées |
| Valeur | `dist/economy.js:349` `transferValue` | `(note au poste − 45)² × 330` × âge (< 25 : 1,2 ; > 31 : 0,65) × fin de contrat cette saison 0,65 × marge de potentiel (≤ +20 %) × blessé 0,8 ; plancher 20 000 €, arrondi 10 000 € |
| Génération des offres | `dist/economy.js:447` `economyWeek` | une fois par semaine de jeu, pour chaque joueur listé **sans offre en cours** : montant = valeur × (0,78 à 1,02), aléa **déterministe** `seedHash(id+semaine)` ; acheteurs = tous les clubs du Monde (115) ayant la caisse et une place pro, triés par **besoin au poste** (`recruitmentNeeds`) puis écart de niveau ; l'acheteur est tiré parmi les 3 premiers (même graine). Une seule offre à la fois par joueur |
| Appel | `native/engine/world-career.cjs:474` → `dist/game.js:44` `refreshMarket` → `economyWeek` | à la clôture de chaque semaine (après le match) et au début de saison (l.410, 482) |
| Expiration | `economyWeek` | `expires = semaine + 1` : l'offre vaut pour la semaine en cours et la suivante, puis disparaît |
| Contre-proposition | `dist/economy.js:450-467` `counterSale` | +5, +10 ou +15 %, une seule fois, arrondi 10 000 €, joueurs listés seulement. **Remplacé** côté natif par `venteRepondre` (arrondi au millier, valable aussi pour une offre spontanée) |
| Acceptation | `dist/economy.js:468` `acceptSale` | caisse vendeur +montant, acheteur −montant ; joueur transféré (contrat prolongé à au moins saison+1, salaire inchangé) ; ligne de caisse « Vente : Nom » ; actualité ; retiré de la liste, feuille réparée (`repairSheet`). Enrobé par `budget-transferts.cjs` (+50 % à l'enveloppe) |
| Refus | `dist/economy.js:469` `declineSale` | efface l'offre (réimplémenté sans `render`) |
| Fin de saison | `dist/economy.js:470` `settleContracts` ; `dist/manager-mobility.js:79` | offres et liste vidées |
| Plancher d'effectif | `native/engine/professional-depth.cjs`, `worker.cjs` (après chaque commande hors match) | chaque club est complété à **40** professionnels par des joueurs de complément : une vente du club joué est suivie de la signature d'un joueur de complément tant que l'effectif est sous 40 |
| Ventes imposées | `president-reprise.cjs:126,171`, `club-owner.cjs:131-140` | passent par `acceptSale` (offre fabriquée) ; inchangées |
| Garde d'effectif | `interclub-market.cjs:13-17,29-30` `releasePolicy` | 37 pros minimum en Monde, 2 joueurs par famille, 2 piliers de chaque côté ; exportée et réutilisée par la vente |

Mesure avant correction (club 102, cadence hebdomadaire, `testVm`) : un joueur listé faisait passer `finish_round` de 2,5 s à 7,7 s (`economyWeek` ≈ 5 s par joueur listé : le tri appelait `recruitmentNeeds` deux fois par comparaison sur 115 clubs) ; trois joueurs dépassaient la limite de 15 s. Après correction : 5 joueurs proposés + une offre spontanée = +0,6 s (4,3 s → 4,9 s).

## 2. Fantasme

« Je fais le ménage dans mon groupe : ce talonneur de 32 ans ne joue plus, je le mets sur le marché. Deux semaines plus tard, Dax en propose 60 000 €. Je demande 10 % de plus, ils acceptent : on est en octobre, l'accord est conclu, il partira au 1er mai. D'ici là il reste avec nous ; au printemps, l'argent tombe et la moitié revient dans mon enveloppe de recrutement. Et un matin, Bayonne fait une offre que je n'attendais pas pour mon ouvreur… »

## 3. Règles détaillées

1. **Mettre en vente** : depuis la fiche joueur (onglet Contrat), l'Effectif (panneau du joueur) ou la boîte « Offres reçues » (retrait). Refusé, raison écrite, si : match en cours ; espoir de moins de 20 ans ; recrue de moins de 3 journées ; joueur prêté ou appelé du centre ; vente déjà conclue pour lui. Le retrait de la liste efface l'offre en cours (pas une offre spontanée).
2. **Offres** : à chaque clôture de semaine, chaque joueur listé sans offre en cours peut en recevoir **une** (formule §4). Pas d'acheteur solvable avec une place : pas d'offre, le joueur reste listé.
3. **Offres spontanées** (décision de Léo, 19/11/2026) : à la clôture de certaines semaines (tirage déterministe, graine de la carrière + saison + semaine, au plus `maxParSaison` par saison), un club fait une offre pour un des **meilleurs joueurs non proposés** (par note au poste), s'il en a le **besoin au poste** (≥ `besoinMin`) et la caisse ; montant **au-dessus de la valeur** (×1,05 à ×1,30), car le club ne cherche pas à vendre. Jamais pour un joueur bloqué (règle 1) ni si la garde d'effectif l'interdit. Mêmes réponses.
4. **Courrier** : chaque nouvelle offre dépose un courrier « offre_transfert » en Réception (nature « info », ne bloque pas « Continuer ») avec le lien « Ouvrir · Offres reçues » (Recrutement, boîte ouverte).
5. **Réponses** : *Accepter* (confirmation), *Demander plus* (+5, +10 ou +15 %, une seule fois par offre, **arrondi au millier** ; l'acheteur relève ou se retire, message écrit dans les deux cas), *Refuser*. Sans réponse, l'offre expire à la fin de la semaine suivante.
6. **Garde d'effectif** (reprise de `interclub-market.cjs`) : vente refusée si l'effectif pro tombe sous **37** ou s'il reste moins de 2 joueurs de la famille de poste (2 piliers de chaque côté). La raison est affichée sur l'offre, avant le clic. En pratique, le plancher de 40 (joueurs de complément) la rend rare ; elle protège surtout les postes.
7. **JIFF** : pas de blocage (quota moyen sur la saison, par feuille) ; la confirmation indique « Tu garderas n JIFF dans l'effectif » si le joueur compte pour le quota.
8. **Période des mutations** (décision de Léo, 19/11/2026, fidèle au règlement LNR — régime des mutations 2023-24, [source](https://www.techxv.org/IMG/pdf/lnr_-_periode_de_mutations_2023-2024.pdf)) : les cessions de joueurs sous contrat entre clubs ne se concluent que **du 1er mai au 30 juin** (dates dans `vente-joueurs.json`). Pendant la période : exécution immédiate. Hors période : on propose, on reçoit (offres listées et spontanées) et on négocie ; « Accepter » conclut un **accord effectif à l'ouverture** :
   - le joueur reste au club et joue jusque-là ; état « vente en attente » sur la fiche, l'Effectif et dans Offres reçues ; il ne peut plus être proposé ni recevoir d'offre ;
   - à la première clôture de semaine à partir de l'ouverture : la garde d'effectif et les moyens de l'acheteur sont **revérifiés** ; si tout passe, la vente est exécutée (caisse, départ, budget +50 %) avec le courrier « vente_executee » ; sinon l'accord **tombe** avec le courrier « vente_annulee » qui dit pourquoi ;
   - un accord d'un ancien club (changement de club du manager) disparaît sans effet.
   Le réglage `fenetres.mode = "saison"` rétablit l'ancien comportement (vente immédiate toute la saison hors match).
9. **Budget de transferts** (#1001, R4) : une vente acceptée par le manager est une **vente choisie** → 50 % du montant reviennent à l'enveloppe (sans plafond d'enveloppe depuis le 19/11/2026, seule la caisse limite le disponible), au moment de l'exécution ; ventes du président ou du prêt de l'actionnaire : rien. Elles suivent aussi la période des mutations (hors période : accord imposé exécuté au 1er mai, voir `docs/gdd/calendrier-mutations.md`).
10. **Conséquences d'un départ important** (décision de Léo, 19/11/2026) : légères, au départ effectif du joueur (immédiat ou à l'ouverture), sur des jauges **déjà présentes** ; annoncées dans la confirmation (« Ce départ touchera le vestiaire… »), valeurs dans `vente-joueurs.json` (`consequences`), déterministes :
    - coéquipiers liés au joueur par un duo positif (`S.v70Relations`, liens du vestiaire) : satisfaction −4 (bornes 20–95) ;
    - le joueur est le **leader du vestiaire** (`CDRelationsV70.leader`) : moral du groupe −2 (bornes 25–98) ;
    - le joueur est un **cadre** (leader, ou parmi les 3 meilleurs de l'effectif par note au poste) : confiance des supporters −2 (`S.pressRelations.fanTrust`) ;
    - la caisse était **sous la réserve** du club (budget de saison) : confiance du président +2 (`S.trust`).
    Le moteur n'a **ni capitaine ni statut « joueur emblématique »** : le leader du vestiaire et les meilleurs joueurs en tiennent lieu ; aucune réaction de la presse (articles) n'est générée. Les ventes imposées (président, actionnaire) n'ont pas ces conséquences.
11. **Changement de saison** : liste et offres vidées ; le manager doit relister. Les accords conclus restent (ils s'exécutent au 1er mai, toujours dans la saison où ils ont été conclus).

## 4. Formules

```
valeur      = transferValue(p)                       // §1, inchangée
offre       = arrondi10k(valeur × (0,78 + (seedHash(id+semaine) mod 25)/100))
acheteur    = top3[seedHash(id+semaine) mod min(3, n)] des clubs (caisse ≥ offre, place pro > 0)
              triés par besoin au poste ↓, |niveau club − note| ↑, id ↑
relance     = ceil1k(offre × (1 + pct/100)), pct ∈ {5, 10, 15}
plafond     = floor1k(min(caisse acheteur − 350 000, offre × (1,08 + besoin/500)))
              relance > plafond ou > caisse → offre retirée
spontanée   = semaine tirée : FNV(graine:saison:semaine:spontanee) mod 1000 < chanceSemaine × 1000,
              semaine ≥ semaineMin, et moins de maxParSaison semaines tirées avant elle dans la saison
              joueur  = candidats[(h + k) mod n], candidats = meilleurs non proposés (note au poste ↓, id), k = 0, 1…
              montant = arrondi10k(valeur × (1,05 + (h mod 26)/100)), h = seedHash(graine:saison:semaine:joueur)
              acheteur = top3[h mod min(3, n)] des clubs (caisse ≥ montant + 350 000, place, besoin ≥ 20)
retour budget = 0,5 × montant   // #1001, R4 sans plafond (19/11/2026)
date d'effet  = prochaine ouverture de période (1er mai) si l'acceptation tombe hors période
```

Exemple : valeur 70 000 €, `seedHash mod 25 = 8` → offre arrondi10k(70 000 × 0,86) = 60 000 € ; relance +10 % → 66 000 € ; acheteur de besoin 20 et caisse 2 M€ → plafond floor1k(min(1 650 000, 60 000 × 1,12)) = 67 000 € → **accepté à 66 000 €**. Relance +15 % → 69 000 € > 67 000 € → **retrait**. Avec besoin 60 : plafond 72 000 € → +15 % accepté.

Offres spontanées avec les réglages par défaut (chance 0,14 par semaine dès la semaine 3, plafond 4) : environ 3 à 4 par saison.

Correction de coût (sans effet sur le résultat) : pendant `economyWeek`, `recruitmentNeeds(club)` est calculé **une fois par club** (mémo, liste rendue jamais modifiée par ses lecteurs) au lieu de deux appels par comparaison. Résultat identique caractère pour caractère (test d'égalité sur une semaine avec offre spontanée), graine identique.

## 5. Cas limites

| Cas | Règle |
|---|---|
| Joueur blessé listé | valeur × 0,8 ; vente permise |
| Joueur dans le XV ou la feuille | vente permise ; feuille réparée, message « Vérifie ta feuille à 23 » ; la confirmation le rappelle |
| Acheteur n'a plus la caisse au moment d'accepter | « Accepter » grisé : « Plus disponible : X n'a plus les moyens ou plus de place dans son effectif. » |
| Offre relevée puis refusée | effacée ; une nouvelle offre peut venir la semaine suivante (graine différente) |
| Vente imposée par le président en cours | ses offres fabriquées passent avant ; un joueur déjà vendu disparaît de la liste |
| Joueur listé puis bloqué (prêt, retour de blessure) | reste listé, pas d'offre tant que bloqué |
| Garde 37 atteinte | « Accepter » grisé : « Tu dois garder au moins 37 joueurs professionnels. » |
| Effectif sous 40 après la vente | le club signe un joueur de complément (plancher existant) ; la confirmation l'annonce |
| Accord hors période, effectif ou acheteur changés avant le 1er mai | revérifiés à l'exécution ; l'accord tombe, courrier « vente_annulee » avec la raison, le joueur reste |
| Joueur sous accord transféré autrement (président) avant le 1er mai | l'accord tombe : « Le joueur ne fait plus partie de l'effectif. » |
| Changement de club du manager (mobilité) | liste et offres vidées (`manager-mobility.js:79`) ; accords de l'ancien club abandonnés |

## 6. Dépendances

| Système | Sens | Contrat |
|---|---|---|
| `dist/economy.js` (liste, offres, acceptation) | amont | `economyWeek`, `acceptSale`, `saleBlocked`, `transferValue` réutilisés ; `toggleListing`, `counterSale`, `declineSale` remplacés côté natif (pas de `toast`/`render`, arrondi au millier) |
| `interclub-market.cjs` `releasePolicy` | amont | même seuil d'effectif minimum (37 en Monde) ; exporté par le domaine |
| `professional-depth.cjs` | voisin | plancher de 40 après chaque commande : annoncé dans la confirmation |
| Budget de transferts (#1001) | aval | enrobe `acceptSale` : +50 % à l'enveloppe ; ventes imposées via `budgetTransfertsImposee` |
| `president-reprise.cjs`, `club-owner.cjs` | voisins | ventes imposées soumises à la période des mutations (accord imposé `imposee:true`, exécuté au 1er mai ; prêt remboursé à l'exécution) — `docs/gdd/calendrier-mutations.md` |
| `club-mail.cjs` / `club-mail.json` | aval | catégorie « transferts », courriers « offre_transfert », « vente_executee », « vente_annulee » (nature info) |
| Finances | aval | ligne de caisse « Vente : Nom » déjà écrite |
| Vestiaire (`relations-duos-v70.js`, satisfaction), presse et supporters (`S.pressRelations`), président (`S.trust`) | aval | conséquences légères d'un départ important (§3 règle 10), bornes identiques aux réponses du courrier |
| **Calendrier du recrutement** (`docs/gdd/calendrier-mutations.md`) | aval | réutilise la période (`fenetres`) et la liste des accords (`venteNouvelAccord`, sens « achat », ventes imposées) ; un joueur qui a signé un pré-contrat ailleurs ne peut plus être proposé ; les approches de pré-contrat tournent dans `economyWeek` sous la même mémoire des besoins |

## 7. Réglages (`native/engine/vente-joueurs.json`, lu à chaque calcul)

| Réglage | Valeur | Plage sûre | Effet |
|---|---|---|---|
| `relances.pourcents` | 5 / 10 / 15 | — | hausses proposées, une fois par offre |
| `relances.arrondi` | 1 000 € | 1 000 – 10 000 € | arrondi d'une relance |
| `relances.reserveAcheteur` | 350 000 € | 200 000 – 500 000 € | caisse que l'acheteur garde |
| `relances.margeBase` / `margeBesoin` | 1,08 / 500 | 1,03 – 1,15 / 300 – 800 | jusqu'où l'acheteur suit |
| `spontanees.chanceSemaine` | 0,14 | 0,05 – 0,25 | fréquence des offres spontanées |
| `spontanees.maxParSaison` | 4 | 1 – 8 | plafond par saison |
| `spontanees.semaineMin` | 3 | 1 – 10 | pas d'offre spontanée en tout début de saison |
| `spontanees.candidats` | 6 | 3 – 10 | joueurs convoités (les meilleurs) |
| `spontanees.besoinMin` | 20 | 10 – 40 | besoin au poste de l'acheteur |
| `spontanees.fourchette` | ×1,05 – ×1,30 | ×1,00 – ×1,50 | montant au-dessus de la valeur |
| `consequences.satisfactionProches` | −4 | −8 – 0 | satisfaction des coéquipiers liés (duo positif) |
| `consequences.moralGroupeLeader` | −2 | −3 – 0 | moral du groupe si le leader part |
| `consequences.supportersCadre` | −2 | −3 – 0 | confiance des supporters si un cadre part |
| `consequences.confiancePresident` | +2 | 0 – +3 | si la vente renfloue une caisse sous la réserve |
| `consequences.meilleurs` | 3 | 2 – 5 | joueurs comptés comme cadres (note au poste) |
| `fenetres.mode` | `fenetres` | `fenetres` / `saison` | période des mutations ou vente toute la saison |
| `fenetres.periodes` | 1er mai – 30 juin | dates LNR | périodes où une cession se conclut |
| Fourchette d'une offre listée (× valeur) | 0,78 – 1,02 | 0,70 – 1,10 | `dist/economy.js`, inchangé |
| Durée d'une offre | semaine en cours + 1 | 1 – 2 semaines | `dist/economy.js`, inchangé |
| Effectif minimum après vente | 37 | 35 – 40 | `interclub-market.cjs` |
| Recrue revendable après | 3 journées | 2 – 6 | `dist/economy.js` |
| Espoir vendable à partir de | 20 ans | 19 – 21 | `dist/economy.js` |

## 8. Critères d'acceptation (tests : `tests/vente-joueurs.cjs`, `tests/godot-vente-joueurs.cjs`)

1. Carrière Monde (club 102, graine 4242) : un joueur mis en vente reçoit une offre à la clôture de la semaine ; l'offre apparaît dans la vue (`sales.offers`, `squad[].sale.offerId`) et un courrier « offre_transfert » arrive en Réception (nature info, sans arrêt).
2. Accepter pendant la période : caisse +montant, joueur chez l'acheteur, ligne « Vente : Nom », enveloppe +50 %. Hors période : accord en attente (caisse et effectif inchangés), exécuté à l'ouverture avec les mêmes effets ; accord qui tombe (garde ou moyens de l'acheteur) : le joueur reste, courrier avec la raison.
3. Demander plus : montant au millier, une seule fois ; l'acheteur relève ou retire, message écrit dans les deux cas.
4. Refus et expiration effacent l'offre ; changement de saison vide liste et offres.
5. Effectif à 37 : acceptation refusée, raison visible avant le clic.
6. Coût : clôture de semaine avec 5 joueurs proposés + une offre spontanée au plus **+1,5 s** par rapport à la même clôture sans liste (hebdomadaire et `advance_day` journalier), toujours sous 15 s ; offres identiques avec et sans mémo.
7. Recrue < 3 journées : « Proposer aux autres clubs » grisé avec la raison écrite.
8. Offre spontanée : joueur non proposé parmi les meilleurs, acheteur dans le besoin, montant ≥ valeur × 1,05.
9. Départ du leader du vestiaire, caisse sous la réserve : conséquences annoncées dans l'offre (`consequences`), puis appliquées à la vente (satisfaction du coéquipier lié −4, moral −2, supporters −2, président +2) ; un joueur sans lien ni statut : aucune.
10. Godot 1280×720 : textes ≥ 13 px, aucun chevauchement, confirmation au libellé d'action avec le focus sur Annuler.

## 9. Implémentation (19/11/2026)

- **Moteur** : `native/engine/vente-joueurs.cjs` (chargé par `worker.cjs` après le budget de transferts) : enrobe `economyWeek` (mémo des besoins, exécution des accords échus, offre spontanée), garde d'effectif (`releasePolicy` exporté par `interclub-market.cjs`), état `S.venteJoueurs = {version:1, seq, accords[], evenements[]}` (accords en attente, événements pour le courrier), projection de vue.
- **Commandes** (`gestion.cjs`, liste blanche `COMMANDS` de `worker.cjs`, écriture) : `sale_list {playerId, listed}` → `meta.saleList {playerId, listed, message}` ; `sale_answer {offerId, action:'accept'|'counter'|'decline', percent?:5|10|15, confirmed:true pour accept}` → `meta.saleAnswer {offerId, action, playerId, fee, raised?, deferred?, date?, budgetReturn?, squadSize?, message}`. Paramètres validés (clés exactes, types), raison écrite en cas de refus.
- **Vue** (`model.cjs`) : `squad[].sale {listed, value, blocked, offerId, pending}` ; `sales {available, listed[], offers[{id, playerId, name, pos, age, salary, buyerId, buyer, fee, value, lastWeek, weeksLeft, spontaneous, listed, countered, onSheet, accept{available, reason}, counter{available, reason, percents}, budgetReturn, cashAfter, squadAfter, fillers, jiff, consequences[], deferred{date, dateLabel, note}|null}], pending[], window{mode, open, reopens, reopensLabel, reason, periods}, minimum, squadSize}`.
- **Courrier** : catégorie « transferts » (écran « ventes ») et types `offre_transfert`, `vente_executee`, `vente_annulee` dans `club-mail.json`.
- **Godot** : `ui/player_sales_view.gd` (boîte « Offres reçues » et confirmation W1), `ui/immersive08/recruitment_canvas.gd` (bouton `OpenPlayerSales`), `ui/immersive08/player_canvas.gd` (carte « Marché des transferts » de l'onglet Contrat, état dans la carte Contrat), `ui/immersive08/squad_canvas.gd` et `ui/squad_views.gd` (dossier du joueur dans l'Effectif), `ui/contract_review.gd` (vue Contrats : statut et encart), `ui/socle/ecran_effectif.gd` (colonne Marché, carte contrat), `ui/club_mail.gd` (lien « ventes »).
- `tests/sale-negotiation.cjs` reste hérité (harnais `start(0)`, pas Monde).

## 10. Questions ouvertes

- **Q1** (tranchée le 19/11/2026) : offres spontanées dès ce chantier.
- **Q2** (tranchée le 19/11/2026) : période des mutations LNR pour la vente ; le réglage `fenetres` reste.
- **Q3** (tranchée le 19/11/2026) : les ventes imposées suivent la période des mutations (`docs/gdd/calendrier-mutations.md`).
- **Q4** (tranchée le 19/11/2026) : calendrier du recrutement et pré-contrats, `docs/gdd/calendrier-mutations.md`.
- **Q5** : le plancher de 40 professionnels (joueurs de complément signés automatiquement) rend la garde de 37 presque inatteignable ; faut-il l'aligner ?
