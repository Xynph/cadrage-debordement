# Calendrier du recrutement (mutations, joueurs libres, pré-contrats)

> **Statut** : implémenté (game-designer, economy-designer, gameplay-programmer, ui-programmer CCGS, 19/11/2026, mode autonome, rigueur `minimal`) ; décisions de Léo du 19/11/2026
> **Mode** : carrière Monde (`world-champ`) uniquement
> **Cap** : consolider — réutiliser la période des mutations et les accords différés de la vente de joueurs (PR #1009)
> **Source** : régime des mutations LNR 2023-24 ([PDF](https://www.techxv.org/IMG/pdf/lnr_-_periode_de_mutations_2023-2024.pdf)), voir `docs/ressources-utiles.md` § « Fenêtres de recrutement et de cession »
> **Liés** : `docs/gdd/vente-joueurs.md`, `docs/gdd/budget-transferts.md`
> **Code** : `native/engine/calendrier-mutations.cjs` + `calendrier-mutations.json` ; période des mutations dans `vente-joueurs.json` (`fenetres`) ; tests `tests/calendrier-mutations.cjs`, `tests/godot-calendrier-mutations.{cjs,gd}`

## 1. Vue d'ensemble

Le recrutement suit le calendrier réel du rugby professionnel français :

| Opération | Quand | Hors période |
|---|---|---|
| Joueur sous contrat d'un autre club (achat) | 1er mai – 30 juin (période des mutations) | accord conclu, exécuté le 1er mai |
| Vente d'un joueur du club (PR #1009) | 1er mai – 30 juin | accord conclu, exécuté le 1er mai |
| Vente imposée (président, prêt de l'actionnaire) | 1er mai – 30 juin | accord conclu, exécuté le 1er mai |
| Joueur sans club (commande `recruit`) | 1er mai – 31 décembre | fermé, réouverture le 1er mai |
| Joueurs supplémentaires | 1er – 31 janvier, **2 par saison** | — |
| Jokers (renforts pris parmi les joueurs sans club, jokers médicaux) | 1er juillet – 31 mars | les espoirs montent (club joué) ; pas de joker médical (clubs gérés) |
| Pré-contrat (joueur à moins de 6 mois de la fin de son contrat) | 1er janvier – 30 juin | arrivée le 1er juillet, sans indemnité |

Chaque refus écrit la raison et la date de réouverture. Les pré-contrats marchent dans les deux sens : le club joué en signe avec des joueurs d'autres clubs, et les autres clubs approchent ses joueurs en fin de contrat (courrier, deux semaines pour proposer une prolongation).

## 2. Fantasme

« On est en février, je ne peux plus signer de joueur libre : il fallait se décider avant le 31 janvier. Mais le talonneur de Pau finit son contrat en juin : je lui fais signer un pré-contrat, il arrivera le 1er juillet sans que je verse un euro à Pau, juste sa prime. Le lendemain, mon directeur sportif m'écrit : Bayonne a approché mon ouvreur. J'ai deux semaines pour le prolonger, sinon il part libre cet été. »

## 3. Règles

1. **Période des mutations** (achats et ventes entre clubs, ventes imposées) : 1er mai – 30 juin, réglée une seule fois dans `vente-joueurs.json` (`fenetres`) pour les deux sens.
   - Achat pendant la période : immédiat (inchangé). Hors période, la négociation (`interclub_negotiate`) ne reçoit que l'offre du manager — les autres clubs n'enchérissent qu'en période ; la clôture (`interclub_auction`) ou l'accord direct (`interclub_transfer`) crée un **accord d'achat** dans la liste des accords de la vente (`S.venteJoueurs.accords`, `sens: 'achat'`). L'indemnité est **engagée** tout de suite sur le budget de transferts (le disponible baisse), la caisse ne bouge pas, le joueur reste à son club.
   - À la première clôture de semaine à partir de l'ouverture, l'accord est revérifié (joueur encore au vendeur, garde d'effectif du vendeur, place dans l'effectif, réserve de 400 000 €) puis exécuté (caisse, ligne « Libération anticipée », arrivée) ; sinon il tombe avec la raison, et l'indemnité engagée revient à l'enveloppe de la même saison.
2. **Joueurs sans club** : ouverts du 1er mai au 31 décembre. En janvier, au plus **2 joueurs supplémentaires** par saison (compteur `S.calendrierMutations.supplementaires`). Du 1er février au 30 avril : fermé. La raison est affichée sur chaque piste (Recrutement, « Vigilance » et bouton grisé) et la commande `recruit` la renvoie.
3. **Jokers** : jusqu'au 31 mars. Club joué : les renforts pris parmi les joueurs sans club pour compléter la feuille (`promote_cover`, club-budget.cjs) ne sont plus possibles du 1er avril au 30 avril (les espoirs montent comme avant) ; clubs gérés : pas de joker médical (club-directions.cjs).
4. **Pré-contrat, club joué → joueur d'un autre club** : possible pour un joueur dont le contrat s'achève cette saison, à moins de 6 mois de son échéance (30 juin), donc à partir du 1er janvier. Commande `precontract_offer` ; le joueur accepte si le salaire atteint sa demande (`askingWage`), durée 1 à 3 saisons (bornée par la fin de carrière). Aucune indemnité pour son club ; seule une **prime à la signature** (2 semaines de salaire, au millier supérieur) est payée tout de suite et **consomme le budget de transferts**. Il reste à son club jusqu'au 30 juin et arrive au **1er juillet** (bascule de saison, avant le départ des joueurs libres).
5. **Pré-contrat, autre club → joueur du club joué** : à la clôture de certaines semaines (tirage déterministe graine + saison + semaine, chance 0,2, au plus 2 par saison), un club dans le besoin au poste approche un des 8 meilleurs joueurs en fin de contrat éligibles. Courrier « precontrat_approche » (lien « Proposer une prolongation » → fiche du joueur, onglet Contrat). Le manager a **14 jours** pour le prolonger (`extend_contract`, ou par l'agent) : l'autre club renonce. Sinon il signe : courrier « precontrat_signe », la presse en parle (fil des transferts), la prolongation et la mise en vente sont refusées (« A signé un pré-contrat avec Y : il part libre le 1er juillet. »), le directeur sportif ne le prolonge pas. Il reste **pleinement professionnel** jusqu'au 30 juin : aucune jauge n'est touchée. Au 1er juillet il rejoint le club, libre, sans indemnité.
6. **Ventes imposées** : la vente du président (reprise, `president-reprise.cjs`) et la vente pour rembourser le prêt de l'actionnaire (`club-owner.cjs`) suivent la période. Hors période, l'accord est conclu tout de suite (le joueur ne peut plus être vendu ailleurs) et exécuté le 1er mai ; le remboursement du prêt se fait à l'exécution. Rien ne revient au budget de transferts, pas de conséquence de vestiaire. Le courrier du président le dit (« Nous sommes hors période des mutations… »).
7. **Clubs gérés** : ils respectent le même calendrier pour ce qui touche le club joué (pas d'enchère hors période, approches en fin de contrat, jokers médicaux jusqu'au 31 mars ; leurs recrutements de joueurs libres ont lieu aux semaines 0 et 13, avant le 31 décembre). **Non fait** : leurs transferts entre eux (club-transfers.cjs, club-directions.cjs, ventes de leur président) restent aux semaines 0 et 13 ; les déplacer en mai-juin change l'équilibre économique de tout le Monde (chantier à part).

## 4. Formules

```
ouvert(jour, périodes)  = ∃ p : p.debut ≤ MM-JJ ≤ p.fin   (période à cheval sur le 1er janvier si debut > fin)
réouverture             = plus proche AAAA-debut > jour
libre(jour, n)          = ouvert(libres) ou (ouvert(supplémentaires) et n < maxParSaison)
anneeFin(contractEnd)   = 2026 + contractEnd            (la saison s va d'août 2025+s à juin 2026+s)
début pré-contrat       = 1er du mois (mois(finContrat) − moisAvantFin + 1) de anneeFin = 1er janvier
arrivée                 = anneeFin-07-01 (bascule de saison)
prime                   = ⌈salaire × primeSemaines / arrondi⌉ × arrondi        ex. 12 345 € → 25 000 €
approche tirée          = FNV(graine:saison:semaine:precontrat) mod 1000 < chanceSemaine × 1000
échéance d'une approche = jour + delaiJours
```

## 5. Cas limites

| Cas | Règle |
|---|---|
| Accord d'achat, le vendeur a vendu le joueur entre-temps | l'accord tombe (« Le joueur ne fait plus partie de l'effectif de X »), indemnité rendue à l'enveloppe |
| Accord d'achat, effectif complet à l'ouverture | l'accord tombe, raison écrite |
| Pré-contrat signé, le joueur a été prolongé ou transféré par son club avant le 1er juillet | le pré-contrat tombe ; la prime est remboursée |
| Approche encore en cours au 1er juillet | il signe et part (pas de prolongation) |
| Prolongation pendant l'approche | l'autre club renonce aussitôt (« X prolonge : Y renonce à le recruter. ») |
| Joueur approché qui arrête sa carrière | jamais approché (moins de 2 saisons de carrière) |
| Changement de club du manager | pré-contrats et accords de l'ancien club tombent sans effet |
| Recrue en janvier par une autre voie (renfort de feuille) | ne compte pas comme joueur supplémentaire |
| Réglage `mode: "saison"` | joueurs libres et jokers ouverts toute la saison (ancien comportement) ; la période des mutations a son propre réglage (`vente-joueurs.json`) |
| Joueurs de complément (plancher de 40 professionnels, `professional-depth.cjs`) | hors calendrier : ce sont des signatures techniques, pas des recrutements |

## 6. Dépendances

| Système | Sens | Contrat |
|---|---|---|
| Vente de joueurs (`docs/gdd/vente-joueurs.md`) | amont | période des mutations (`fenetre`), liste des accords différés (`venteNouvelAccord`, exécution `venteExecuterAccords`), clôture de semaine (approches sous la mémoire des besoins) |
| Budget de transferts (`docs/gdd/budget-transferts.md`) | aval | indemnité d'un accord engagée à la conclusion ; prime de pré-contrat débitée ; ventes imposées sans retour |
| Marché entre clubs (`interclub-market.cjs`) | aval | `window`, `candidates[].pending`, `candidates[].preContract`, négociation sans enchères hors période, `executerAchat` |
| Recrutement libre (`gestion.cjs` `recruit`, `model.market`) | aval | raison de fermeture, compteur des joueurs supplémentaires |
| Prolongations (`extend_contract`, agents `agent_negotiate`, directeur sportif `prolongations-staff.cjs`) | aval | refus pour un joueur parti ; prolongation qui annule une approche |
| Président (`president-reprise.cjs`), actionnaire (`club-owner.cjs`) | aval | ventes imposées différées, textes adaptés |
| Courrier (`club-mail.cjs/json`) | aval | `precontrat_approche` (écran « prolongation »), `precontrat_signe` (fiche) |
| Bascule de saison (`settleContracts`) | aval | pré-contrats exécutés avant le départ des joueurs libres |
| Jokers (`club-budget.cjs` `budgetJoker`, `club-directions.cjs` `medicalJokers`) | aval | fermés après le 31 mars |

## 7. Réglages (`native/engine/calendrier-mutations.json`, lu à chaque calcul)

| Réglage | Valeur | Plage sûre | Effet |
|---|---|---|---|
| `mode` | `fenetres` | `fenetres` / `saison` | calendrier ou tout ouvert |
| `libres.periodes` | 05-01 – 12-31 | dates LNR | joueurs sans club |
| `supplementaires.periodes` / `maxParSaison` | 01-01 – 01-31 / 2 | 0 – 4 | recrues de janvier |
| `jokers.periodes` | 07-01 – 03-31 | dates LNR | renforts et jokers médicaux |
| `preContrats.moisAvantFin` | 6 | 3 – 12 | ouverture des pré-contrats |
| `preContrats.primeSemaines` / `arrondi` | 2 / 1 000 € | 1 – 6 | prime à la signature (même ordre que la prime d'un joueur libre) |
| `preContrats.approches.chanceSemaine` | 0,2 | 0,05 – 0,4 | fréquence des approches |
| `preContrats.approches.maxParSaison` | 2 | 0 – 4 | approches par saison |
| `preContrats.approches.delaiJours` | 14 | 7 – 28 | délai pour prolonger |
| `preContrats.approches.candidats` / `besoinMin` | 8 / 20 | 4 – 12 / 10 – 40 | joueurs visés, besoin du club qui approche |
| `preContrats.approches.majorationSalaire` | 1,1 | 1,0 – 1,3 | salaire chez le nouveau club |
| période des mutations | 05-01 – 06-30 | dates LNR | `vente-joueurs.json`, `fenetres` |

## 8. Critères d'acceptation (tests : `tests/calendrier-mutations.cjs`, `tests/godot-calendrier-mutations.cjs`)

1. Dates : joueurs libres ouverts le 31/12, supplémentaires le 1er et le 31/01 (2 puis refus), fermés du 01/02 au 30/04 avec « réouverture le 1er mai », mutations ouvertes du 01/05 au 30/06, jokers jusqu'au 31/03.
2. Carrière Monde (club 102) : refus de `recruit` hors période avec la raison exacte ; deux joueurs supplémentaires puis refus.
3. Achat hors période : une seule offre (celle du manager), accord avec `deferred`, indemnité engagée sur le budget, caisse et effectif inchangés ; exécuté à l'ouverture (joueur arrivé, ligne de caisse).
4. Vente du président hors période : accord imposé au 1er mai, courrier qui le dit, joueur présent jusque-là ; exécution sans retour au budget.
5. Part d'une vente choisie : 50 % rendus même enveloppe au plafond ; disponible = min(reste, caisse − matelas).
6. Pré-contrat club joué → autre club : refusé avant janvier (raison), signé avec la prime seule (budget et caisse), arrivée à la bascule avec le nouveau contrat, sans indemnité.
7. Approche : courrier, échéance à 14 jours, prolongation qui l'annule ; sans prolongation, il signe (fiche, prolongation et vente refusées, presse) et part libre à la bascule. Tirage identique au rejeu.
8. Performance : clôture de semaine avec approches au plus +1,5 s, sous 15 s.
9. Godot 1280×720 : période écrite dans Recrutement et le marché entre clubs, pré-contrat signé visible, fenêtre « Proposer un pré-contrat » et confirmation W1 (focus sur Annuler), approche sur la fiche, lien « Proposer une prolongation » ; textes ≥ 13 px, aucun chevauchement.

## 9. Contrat moteur / vue

- Commande `precontract_offer {playerId, sellerId, salary, years, confirmed:true}` → `meta.preContract {playerId, sellerId, salary, years, premium, arrival, arrivalLabel, message}`.
- `interclub_auction` / `interclub_transfer` hors période → `meta.interclubTransfer {…, humanWon:true, deferred:true, date, dateLabel}` ; `interclub_negotiate` → `deferred {date, dateLabel, note}`.
- Vue `mutations {available, today, summary, detail, freeAgents{open, supplementary, remaining, max, until, untilLabel, reopens, reopensLabel, reason, note}, interclub{open, reopens, reopensLabel, reason, note}, jokers{open, reopens}, preContracts{arrivals[], departures[], approaches[]}, purchases[]}`.
- `squad[].preContract {state:'approche'|'signe', club, deadline, deadlineLabel, arrival, arrivalLabel, label, short}` (présent seulement pour un joueur approché ou parti) ; `squad[].renewal.reason` dit pourquoi la prolongation est fermée.
- `clubLife.interclubMarket.window`, `candidates[].pending {date, dateLabel, fee}`, `candidates[].preContract {available, reason, salary, premium, premiumWeeks, premiumStep, minYears, maxYears, arrival, arrivalLabel, note, signed?{label,…}}` (joueurs en fin de contrat seulement).
- Godot : `ui/immersive08/recruitment_canvas.gd` (`RecruitmentWindow`), `ui/interclub_market_view.gd` (`InterclubWindow`, `InterclubPreContractFilter`, `InterclubPreContract`, fenêtre et `PreContractConfirmation`), `ui/immersive08/player_canvas.gd` (`PlayerPreContract`), `ui/club_mail.gd` (écran « prolongation »).
