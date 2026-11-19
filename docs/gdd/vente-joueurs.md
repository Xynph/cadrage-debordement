# Vente de joueurs

> **Statut** : proposé (economy-designer → game-designer → ux-designer CCGS, 19/11/2026, mode autonome, rigueur `minimal`)
> **Mode** : carrière Monde (`world-champ`) uniquement
> **Cap** : consolider — brancher le mécanisme de vente déjà présent dans le moteur, ne rien inventer de lourd
> **Liés** : `docs/gdd/budget-transferts.md` (PR #1001, R4 « ventes : reconstitution partielle »), fiches UX 07, 08, 09, 05

## 1. Vue d'ensemble

Le manager peut **proposer un joueur aux autres clubs**, recevoir leurs **offres**, puis **accepter**, **demander plus** (une fois) ou **refuser**. Une vente fait entrer l'indemnité dans la caisse du club et, si le budget de transferts existe, en rend la moitié à l'enveloppe de recrutement.

Le moteur contient déjà tout le mécanisme (héritage de l'interface web) et il **tourne déjà** en carrière Monde : la mise en liste reste simplement inaccessible depuis Godot. Le chantier consiste à l'exposer (commandes, vue, écrans, courrier), avec trois corrections : garde d'effectif minimum, coût de calcul, et vocabulaire.

### Carte de l'existant (vérifiée le 19/11/2026, `main` 8637395)

| Élément | Où | Ce qu'il fait |
|---|---|---|
| Mise en liste | `dist/economy.js:446` `toggleListing` | `S.economy.listings[id]=true` ; retrait = efface aussi les offres du joueur. Refus si `saleBlocked` ou match en cours (`economyLocked`, l.313) |
| Blocages | `dist/economy.js:350` `saleBlocked` | espoir (`academy-`/`youth-`) de moins de 20 ans ; recrue arrivée cette saison depuis moins de 3 journées |
| Valeur | `dist/economy.js:349` `transferValue` | `(note au poste − 45)² × 330` × âge (< 25 : 1,2 ; > 31 : 0,65) × fin de contrat cette saison 0,65 × marge de potentiel (≤ +20 %) × blessé 0,8 ; plancher 20 000 €, arrondi 10 000 € |
| Génération des offres | `dist/economy.js:447` `economyWeek` | une fois par semaine de jeu, pour chaque joueur listé **sans offre en cours** : montant = valeur × (0,78 à 1,02), aléa **déterministe** `seedHash(id+semaine)` ; acheteurs = tous les clubs du Monde (115) ayant la caisse et une place pro, triés par **besoin au poste** (`recruitmentNeeds`) puis écart de niveau ; l'acheteur est tiré parmi les 3 premiers (même graine). Une seule offre à la fois par joueur |
| Appel | `native/engine/world-career.cjs:474` → `dist/game.js:44` `refreshMarket` → `economyWeek` | à la clôture de chaque semaine (après le match) et au début de saison (l.410, 482) |
| Expiration | `economyWeek` | `expires = semaine + 1` : l'offre vaut pour la semaine en cours et la suivante, puis disparaît |
| Contre-proposition | `dist/economy.js:450-467` `counterSale` | +5, +10 ou +15 %, **une seule fois** ; plafond acheteur = min(caisse − 350 000 €, offre × (1,08 + besoin/500)) ; au-delà, l'acheteur **retire son offre** |
| Acceptation | `dist/economy.js:468` `acceptSale` | caisse vendeur +montant, acheteur −montant ; joueur transféré (contrat prolongé à au moins saison+1, salaire inchangé) ; ligne de caisse « Vente : Nom » ; actualité « X rejoint Y pour Z » ; retiré de la liste, feuille et réserves réparées (`repairSheet`) |
| Refus | `dist/economy.js:469` `declineSale` | efface l'offre ; une nouvelle peut venir la semaine suivante |
| Fin de saison | `dist/economy.js:470` `settleContracts` ; `dist/manager-mobility.js:79` | offres et liste vidées |
| Offres spontanées | — | **aucune** : seuls les joueurs listés reçoivent des offres ; les clubs gérés (`club-transfers.cjs`, `club-directions.cjs`) n'achètent jamais au club joué |
| Ventes imposées | `president-reprise.cjs:126,171`, `club-owner.cjs:131-140` | passent par `acceptSale` (offre fabriquée) ; seuls usages natifs aujourd'hui |
| Garde d'effectif | `interclub-market.cjs:17,30-31` | existe pour le **vendeur IA** (37 pros minimum en Monde, 2 joueurs par famille, 2 piliers de chaque côté) mais **pas** dans `acceptSale` |
| Godot | — | aucune commande (`gestion.cjs`), aucun champ de vue (`model.cjs`), aucun courrier, aucun écran |

Sonde Monde (club 102, cadence hebdomadaire, `testVm`) : un joueur listé reçoit une offre à la clôture de la semaine (ex. valeur 70 000 €, offre 60 000 € de Dax, valable 2 semaines). **Défaut bloquant** : `economyWeek` coûte ≈ **4,3 s par joueur listé** (le tri appelle `recruitmentNeeds` à chaque comparaison sur 115 clubs) ; `finish_round` passe de 2,8 s à 7,3 s avec un joueur listé et **dépasse la limite de 15 s** avec trois.

## 2. Fantasme

« Je fais le ménage dans mon groupe : ce talonneur de 32 ans ne joue plus, je le mets sur le marché. Deux semaines plus tard, Dax en propose 60 000 €. Je demande 10 % de plus, ils acceptent, je signe : la moitié revient dans mon enveloppe de recrutement et je vais chercher le jeune dont j'ai besoin. »

## 3. Règles détaillées

1. **Mettre en vente** : depuis la fiche joueur ou l'Effectif, « Proposer aux autres clubs ». Refusé, raison écrite, si : match en cours ; espoir de moins de 20 ans ; recrue de moins de 3 journées ; joueur prêté. Le retrait de la liste efface l'offre en cours.
2. **Offres** : à chaque clôture de semaine, chaque joueur listé sans offre en cours peut en recevoir **une** (formule §4). Pas d'acheteur solvable avec une place : pas d'offre, le joueur reste listé. Pas d'offre spontanée pour un joueur non listé (rien dans le moteur ; hors périmètre).
3. **Courrier** : chaque nouvelle offre dépose un courrier en Réception (nature « info », ne bloque pas « Continuer ») avec un lien vers Recrutement › Offres reçues.
4. **Réponses** : *Accepter* (confirmation), *Demander plus* (+5, +10 ou +15 %, une seule fois par offre ; l'acheteur relève ou se retire), *Refuser*. Sans réponse, l'offre expire à la fin de la semaine suivante.
5. **Garde d'effectif** (nouveau, reprise de `interclub-market.cjs`) : vente refusée si l'effectif pro tombe sous **37** ou s'il reste moins de 2 joueurs de la famille de poste (2 piliers de chaque côté). La raison est affichée sur l'offre, avant le clic.
6. **JIFF** : pas de blocage (quota moyen sur la saison, par feuille) ; la confirmation indique « Tu garderas n JIFF » si le joueur est JIFF.
7. **Fenêtre** : ventes possibles toute la saison, hors match en cours (comme le marché entre clubs actuel). Le moteur ne modélise pas de fenêtre légale (voir question Q2).
8. **Budget de transferts** (#1001, R4) : une vente acceptée par le manager est une **vente choisie** → 50 % du montant reviennent à l'enveloppe (plafonnée) ; ventes du président ou du prêt de l'actionnaire : rien.
9. **Vestiaire** : aucune réaction existante dans le moteur ; aucune ajoutée (cap « consolider »).
10. **Changement de saison** : liste et offres vidées ; le manager doit relister.

## 4. Formules

```
valeur      = transferValue(p)                       // §1, inchangée
offre       = arrondi10k(valeur × (0,78 + (seedHash(id+semaine) mod 25)/100))
acheteur    = top3[seedHash(id+semaine) mod min(3, n)] des clubs (caisse ≥ offre, place pro > 0)
              triés par besoin au poste ↓, |niveau club − note| ↑, id ↑
relance     = ceil10k(offre × (1 + pct/100)), pct ∈ {5, 10, 15}
plafond     = floor10k(min(caisse acheteur − 350 000, offre × (1,08 + besoin/500)))
              relance > plafond ou > caisse → offre retirée
retour budget = min(0,5 × montant, place sous le plafond de l'enveloppe)   // #1001
```

Exemple : valeur 70 000 €, `seedHash mod 25 = 8` → offre arrondi10k(70 000 × 0,86) = 60 000 € ; relance +10 % → 70 000 € ; acheteur de besoin 20 et caisse 2 M€ → plafond floor10k(min(1 650 000, 60 000 × 1,12)) = 60 000 € → **retrait**. Relance +5 % → 70 000 € aussi (ceil10k de 63 000) → retrait : avec une petite offre, demander plus fait souvent fuir l'acheteur. Avec besoin 60 : plafond floor10k(60 000 × 1,20) = 70 000 → 70 000 € accepté.

Correction de coût (sans effet sur le résultat) : calculer `besoin(club, joueur)` **une fois par club et par joueur listé** avant le tri (mémo), au lieu de deux appels par comparaison. Résultat identique, graine identique.

## 5. Cas limites

| Cas | Règle |
|---|---|
| Joueur blessé listé | valeur × 0,8 ; vente permise |
| Joueur dans le XV ou la feuille | vente permise ; feuille réparée, message « Vérifie ta feuille à 23 » |
| Acheteur n'a plus la caisse au moment d'accepter | offre « Plus disponible », raison écrite, effacée |
| Offre relevée puis refusée | effacée ; une nouvelle offre peut venir la semaine suivante (graine différente) |
| Vente imposée par le président en cours | ses offres fabriquées passent avant ; un joueur déjà vendu disparaît de la liste |
| Joueur listé puis bloqué (prêt, retour de blessure) | reste listé, pas d'offre tant que bloqué |
| Garde 37 atteinte | « Accepter » grisé : « Tu dois garder au moins 37 joueurs professionnels » |
| Changement de club du manager (mobilité) | liste et offres vidées (`manager-mobility.js:79`) |

## 6. Dépendances

| Système | Sens | Contrat |
|---|---|---|
| `dist/economy.js` (mise en liste, offres, réponses) | amont | réutilisé tel quel, appelé par de nouvelles commandes natives |
| `interclub-market.cjs` `releasePolicy` | amont | même seuil d'effectif minimum (37 en Monde) |
| Budget de transferts (#1001) | aval | enrobe `acceptSale` : +50 % à l'enveloppe ; ventes imposées via `budgetTransfertsImposee` |
| `president-reprise.cjs`, `club-owner.cjs` | voisins | inchangés ; leurs ventes restent imposées |
| `club-mail.cjs` / `club-mail.json` | aval | nouveau type de courrier « offre reçue » |
| Finances | aval | ligne de caisse « Vente : Nom » déjà écrite |

## 7. Réglages

| Réglage | Valeur | Plage sûre |
|---|---|---|
| Fourchette d'offre (× valeur) | 0,78 – 1,02 | 0,70 – 1,10 |
| Relances permises | +5 / +10 / +15 %, une fois | — |
| Réserve de caisse de l'acheteur | 350 000 € | 200 000 – 500 000 € |
| Durée d'une offre | semaine en cours + 1 | 1 – 2 semaines |
| Effectif minimum après vente | 37 | 35 – 40 |
| Recrue revendable après | 3 journées | 2 – 6 |
| Espoir vendable à partir de | 20 ans | 19 – 21 |

## 8. Critères d'acceptation

1. Carrière Monde : un joueur mis en vente reçoit au moins une offre en 3 semaines (club 102, graine 4242) ; l'offre apparaît dans la vue et un courrier arrive en Réception.
2. Accepter : caisse +montant, joueur chez l'acheteur, ligne « Vente : Nom », feuille valide ou réparée ; avec #1001 : enveloppe +50 %.
3. Demander plus : une seule fois ; l'acheteur relève ou retire, message écrit dans les deux cas.
4. Refus et expiration effacent l'offre ; changement de saison vide liste et offres.
5. Effectif à 37 : acceptation refusée, raison visible avant le clic.
6. Trois joueurs listés : la clôture de semaine reste sous 15 s (même moyenne qu'à vide ± 1 s) ; offres identiques avant/après la correction de coût.
7. Espoir < 20 ans, recrue < 3 journées : « Proposer aux autres clubs » grisé avec la raison.

## 9. Plan d'implémentation (après fusion de #1001)

- **Moteur** : nouveau module `native/engine/vente-joueurs.cjs` (chargé par `worker.cjs`) : mémo de `recruitmentNeeds` pendant `economyWeek` (correction de coût), garde d'effectif (`releasePolicy` d'`interclub-market.cjs`), projection de vue, dépôt du courrier après `refreshMarket`.
- **Commandes** (`gestion.cjs`) : `sale_list {playerId, listed}` ; `sale_answer {offerId, action:'accept'|'counter'|'decline', percent?:5|10|15, confirmed:true pour accept}`. Appellent `counterSale` / `acceptSale` / `declineSale` (pas `toggleListing`, qui fait `toast`/`render`).
- **Vue** (`model.cjs`) : `squad.players[].sale {listed, value, blocked, offerId}` ; `market.sales {listed:[…], offers:[{id, playerId, name, pos, age, buyerId, buyer, league, fee, value, lastWeek, countered, accept:{available, reason}, budgetReturn}]}`.
- **Courrier** : type `offre_transfert` dans `club-mail.json` (nature info, lien Recrutement › Offres reçues).
- **Godot** : `ui/player_canvas.gd` (carte Contrat), `ui/immersive08/squad_canvas.gd` + `ui/socle/ecran_effectif.gd` (panneau, colonne Marché), `ui/immersive08/recruitment_canvas.gd` (onglet Offres reçues + confirmation), `ui/club_mail.gd` / `immersive08/reception_canvas.gd` (lien du courrier).
- **Tests** : `tests/vente-joueurs.cjs` (Monde world-champ, `hebdomadaire`, `testVm`) — critères 1-7 ; `tests/godot-vente-joueurs.cjs/.gd` sur le modèle de `godot-sante-financiere`. `tests/sale-negotiation.cjs` reste hérité (harnais `start(0)`, pas Monde).
- **Collision #1001** : `gestion.cjs`, `model.cjs`, `worker.cjs`, `recruitment_canvas.gd`, fiches 09 et 17 : partir de `main` après sa fusion.
