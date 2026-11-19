# Budget de transferts

> **Statut** : proposition (economy-designer puis game-designer, 19/11/2026), à implémenter.
> **Décision d'origine** : Léo, 19/11/2026 — un vrai budget de transferts, distinct de la trésorerie.
> **Périmètre** : carrière Monde (world-champ) au budget de saison réaliste (`budgetActif()`), club joué seulement.
> **Rigueur** : `minimal` (project.yaml). Réglages proposés : `native/engine/budget-transferts.json`.

## Vue d'ensemble

En début de saison, le conseil d'administration fixe une **enveloppe de transferts** : la somme que le
manager peut engager en **indemnités de transfert** (accords avec un autre club) et en **primes à la
signature** des recrues. Les salaires n'y entrent pas : ils restent jugés par la masse salariale (plafond de
la ligue, 52 % des recettes, A2R). L'enveloppe se lit en tête des écrans Recrutement et Finances
(« Disponible pour les transferts »). Une offre qui la dépasse est refusée, avec la raison écrite. Les ventes
choisies par le club en rendent une partie. L'enveloppe ne peut jamais dépasser ce que la caisse permet de
dépenser sans entamer le matelas du club.

Aujourd'hui (vérifié dans le code) : aucune enveloppe n'existe ; seules la trésorerie (`club().cash`), une
réserve fixe de 400 000 € (marché entre clubs) et, après coup, l'intervention du président
(`president-reprise.cjs`) freinent les achats. Le « transferBudget » de `dist/career-integration.js` est un
calcul d'affichage de l'ancienne interface web (caisse − 300 000 €), jamais enregistré ni lu par Godot.

## Fantasme du joueur

« Le président m'a donné 1,1 M€ pour renforcer l'équipe cette saison. Je sais ce que je peux faire avant
d'ouvrir une négociation : un grand nom, ou trois joueurs de rotation. Si je vends un joueur, j'en récupère
une partie. Si je gère bien et que la confiance monte, l'enveloppe de la saison prochaine sera plus large. »

Le manager arbitre ; il ne découvre plus après la signature que le président lui reprend la main.

## Règles détaillées

### R1 — Qui fixe l'enveloppe, et quand

1. Le conseil fixe l'enveloppe **une fois par saison**, à l'ouverture des comptes de la saison
   (création de carrière et passage de saison, juste après l'ouverture du budget de saison).
2. Elle dépend de quatre éléments déjà connus du club :
   - ses **recettes de la saison** (taille du club et division) ;
   - l'**ambition du propriétaire** : mécène, entreprise actionnaire ou association (trait stable du club) ;
   - la **confiance du président** dans le manager au moment de la décision ;
   - l'**état de la caisse** par rapport à la réserve que le club se fixe.
3. Une fois fixée, l'enveloppe ne bouge plus de la saison (une victoire ou une défaite ne la change pas) ;
   seules les dépenses, les ventes et la caisse disponible font varier le **disponible**.

### R2 — Ce qui consomme l'enveloppe

| Dépense | Consomme l'enveloppe ? | Pourquoi |
| --- | --- | --- |
| Indemnité versée à un autre club (accord direct ou enchère gagnée) | Oui | cœur du budget de transferts |
| Prime à la signature d'une recrue (joueur libre) | Oui | dépense ponctuelle d'arrivée |
| Prime de prolongation (joueur déjà au club, y compris par l'agent) | **Non** | garder ses joueurs ne doit jamais être bloqué par les arrivées ; la prime reste payée sur la trésorerie |
| Salaires (recrues comprises) | Non | jugés par la masse salariale |
| Renforts d'urgence (feuille à 23), staff, centre, travaux | Non | autres budgets |

### R3 — Dépassement : refus avec raison écrite

Une dépense qui dépasse le **disponible** est refusée avant toute signature :
« Hors budget de transferts : il reste 240 000 € sur l'enveloppe de 1 160 000 € fixée par le conseil. »
Le refus apparaît **avant** l'envoi de l'offre (bouton grisé + raison), comme les refus actuels
(« Trésorerie insuffisante », « Effectif complet »), et le moteur le vérifie à nouveau à la signature.

Choix : refus, pas de demande au conseil. Raisons : le cap du projet est de consolider ; un refus réutilise le
chemin existant (raison de devis, `available:false`), sans nouvel écran ni nouveau courrier ; une rallonge du
conseil ferait doublon avec la reprise du président et le prêt de l'actionnaire. La rallonge reste une piste
ultérieure (question ouverte Q1).

### R4 — Ventes : reconstitution partielle

- Une **vente choisie** par le club (offre acceptée, indemnité de formation reçue pour un jeune formé au
  club) rend **50 %** de son montant à l'enveloppe ; le reste renforce la trésorerie.
- Une **vente imposée** ne rend rien à l'enveloppe : vente décidée par le président (reprise), vente pour
  rembourser le prêt de l'actionnaire. Elles servent à renflouer la caisse, pas à racheter.
- Le reconstitué est plafonné : l'enveloppe totale de la saison (initiale + reconstitué) ne dépasse jamais
  le plafond R6.

### R5 — D'une saison à l'autre

L'enveloppe est **remise à zéro** à chaque saison, sans report explicite. L'argent non dépensé n'est pas
perdu : il reste dans la caisse, ce qui améliore l'état de la caisse face à la réserve, donc l'enveloppe
suivante (facteur trésorerie). Un manager économe est récompensé sans mécanisme de report à expliquer.

### R6 — Jamais plus que la caisse

À tout moment : **disponible = min(enveloppe restante, caisse − matelas)**, jamais négatif, où le matelas
vaut le plus grand de 400 000 € et la moitié de la réserve du club. Si la saison tourne mal (déficit, amende),
le disponible baisse tout seul avec la caisse, même si l'enveloppe n'est pas entamée.

Conséquence voulue : un achat dans l'enveloppe laisse toujours la caisse au-dessus de la moitié de la
réserve. Il ne doit donc plus déclencher la reprise du président (règle d'interface entre systèmes,
voir Dépendances) : le conseil ne peut pas valider une dépense puis la sanctionner.

### R7 — Carrières existantes

À la première lecture dans une carrière déjà en cours (pas d'enveloppe enregistrée, ou enveloppe d'une
autre saison ou d'un autre club), l'enveloppe est calculée **à la volée** avec la caisse, la confiance et le
propriétaire du moment, dépenses de la saison à 0. Aucune sauvegarde n'est réécrite à l'ouverture.

### R8 — Changement de club

Si le manager change de club, l'enveloppe de l'ancien club n'est pas transférée : la règle R7 recalcule celle
du nouveau club.

## Formules

```
recettes   = recettes annuelles du club (club-budget.cjs, recettes(forces))
taux       = taux[division]              (défaut taux.defaut)
ambition   = ambition[typePropriétaire]  (mecene / entreprise / association)
confiance  = confiance.min + (confiance.max − confiance.min) × S.trust / 100
caisse     = clamp(cash / réserve, tresorerie.min, tresorerie.max)

brut       = recettes × taux × ambition × confiance × caisse
enveloppe  = arrondi10k( clamp(brut, recettes × plancher, recettes × plafond) )

matelas    = max(matelas.fixe, matelas.partReserve × réserve)
disponible = max(0, min(enveloppe + reconstitué − dépensé, cash − matelas))
reconstitué += partVentes × vente choisie, tant que enveloppe + reconstitué ≤ recettes × plafond
```

Valeurs proposées (`native/engine/budget-transferts.json`) :

| Clé | Valeur | Plage sûre |
| --- | --- | --- |
| `taux.elite` (Top 14) | 0,020 | 0,012 – 0,030 |
| `taux.accession` (Pro D2) | 0,015 | 0,010 – 0,025 |
| `taux.defaut` (autres championnats) | 0,015 | 0,010 – 0,025 |
| `ambition.mecene` / `entreprise` / `association` | 1,3 / 1,0 / 0,7 | 0,5 – 1,6 |
| `confiance.min` / `confiance.max` (confiance 0 → 100) | 0,75 / 1,25 | 0,6 – 1,4 |
| `tresorerie.min` / `tresorerie.max` (caisse / réserve) | 0,5 / 1,5 | 0,3 – 2 |
| `plancher` / `plafond` (part des recettes) | 0,005 / 0,06 | 0,003 – 0,08 |
| `matelas.fixe` / `matelas.partReserve` | 400 000 € / 0,5 | 300 k – 600 k / 0,3 – 0,8 |
| `partVentes` | 0,5 | 0,25 – 0,75 |

Exemple (Castres Tarn Rugby, Top 14, carrière Monde neuve) : recettes 29,6 M€, entreprise actionnaire,
confiance 72, caisse 3,7 M€, réserve 3,78 M€ → 29,6 M × 0,02 × 1,0 × 1,11 × 0,98 ≈ **640 000 €** ;
caisse − matelas = 3,7 M − 1,89 M = 1,81 M€ (non limitant).

## Balance-check (méthode /balance-check, domaine Économie)

**Données lues (FOUND)** : `native/engine/league-economy.cjs` (recettes, plafonds), `club-budget.cjs`
(réserve, propriétaires), `interclub-market.cjs` (indemnité demandée), carrière Monde neuve créée par
`tests/helpers/carriere-monde.cjs` (graine 4242, club 9 puis 20), sondes en lecture seule.
**ABSENT** : registre `design/registry/entities.yaml`, historique de parties longues (dépenses réelles de
managers sur plusieurs saisons) → la dynamique pluri-saison est **NOT ASSESSED — NO DATA**.

Chiffres d'une carrière neuve (30 clubs Top 14 + Pro D2) :

| | Top 14 (14 clubs) | Pro D2 (16 clubs) |
| --- | --- | --- |
| Recettes annuelles min / médiane / max | 21,4 / 32,9 / 46,0 M€ | 6,1 / 10,6 / 15,2 M€ |
| Caisse de départ min / médiane / max | 2,5 / 4,8 / 7,5 M€ | 2,0 / 2,7 / 3,6 M€ |
| Réserve min / médiane / max | 3,0 / 3,8 / 5,1 M€ | 1,5 / 3,1 / 3,8 M€ |
| Caisse − réserve (médiane) | +1,36 M€ | **−0,26 M€** |
| Indemnité demandée par joueur, médiane / p90 / max | 130 k / 390 k / 620 k€ | 40 k / 100 k / 250 k€ |
| **Enveloppe proposée, confiance 72** min / médiane / max | 310 k / **1,16 M** / 1,84 M€ | 80 k / **160 k** / 300 k€ |
| Enveloppe, confiance 20 → 95 (médiane) | 0,89 → 1,28 M€ | 120 k → 170 k€ |

Lecture :

1. **Pouvoir d'achat** : Top 14 médian ≈ 9 indemnités médianes ou 3 du 90ᵉ centile par saison ; Pro D2
   médian ≈ 4 médianes ou 1,6 du 90ᵉ centile. Le joueur le plus cher n'est accessible qu'aux clubs riches et
   ambitieux. Les primes de joueurs libres (1 000 à 11 000 €) ne sont presque jamais bloquées. **Sain.**
2. **Pas de club à zéro** : la majorité des Pro D2 démarre sous sa réserve ; une règle « caisse − réserve »
   leur aurait donné 0 €. Le plancher (0,5 % des recettes) et le matelas à demi-réserve leur laissent
   80 à 300 k€. **Sain.**
3. **Écart entre clubs** : ×6 en Top 14, ×4 en Pro D2 — la hiérarchie se voit sans écraser les petits. **Sain.**
4. **Confiance** : ±20 % autour de la médiane ; lisible, pas assez fort pour être un levier à farmer (fixée une
   fois par saison). **Sain.**
5. **Boucle achat-revente** : achat à la valeur, vente à 78–102 % de la valeur, 50 % rendus → perte nette à
   chaque tour ; revente bloquée trois journées ; les clubs gérés n'achètent pas au club joué. **Pas de
   stratégie dégénérée.**
6. **Conflit détecté** (bloquant si non traité) : aujourd'hui un achat qui passe la caisse sous la réserve
   déclenche la reprise du président. Pour Castres (caisse 3,7 M€ < réserve 3,78 M€ dès la création), toute
   dépense de 380 k€ ou plus de son enveloppe le déclencherait. → R6 : un achat dans l'enveloppe ne
   déclenche plus la reprise.
7. **Masse salariale** : reste le vrai goulot (Castres : 8,6 M€ pour un plafond de 10,7 M€) ; l'enveloppe
   ne la contourne pas. **Sain.**
8. **Ventes** : le jeu Godot n'offre aujourd'hui **aucune vente choisie** par le manager (pas de commande
   d'acceptation d'offre ; seules les ventes du président, du prêt de l'actionnaire et les indemnités de
   formation existent). R4 ne jouera donc qu'avec les indemnités de formation tant qu'une vente volontaire
   n'existe pas. **À signaler, pas bloquant.**

**Verdict : ÉQUILIBRÉ SOUS CONDITIONS** — (a) exempter de la reprise du président les achats dans
l'enveloppe ; (b) vérifier après implémentation, sur trois saisons simulées, que la caisse médiane des clubs
joués Pro D2 ne passe pas sous la moitié de la réserve. Dynamique pluri-saison : NOT ASSESSED — NO DATA.

## Cas limites

- **Caisse sous le matelas** (saison déficitaire) : disponible = 0 ; raison « La caisse ne permet plus de
  transfert : elle doit rester au-dessus de X € ».
- **Confiance à 0** : facteur 0,75, jamais zéro ; le plancher garantit un minimum.
- **Club sans réserve lisible** (budget de saison illisible) : réserve = matelas fixe ; facteur trésorerie
  calculé sur ce matelas.
- **Carrière sans budget de saison** (`budgetActif()` faux : anciennes carrières non marquées) : pas
  d'enveloppe, règles actuelles inchangées ; l'écran affiche « Trésorerie disponible ».
- **Enchère entre clubs** : l'offre du manager ne peut pas dépasser son disponible ; s'il perd l'enchère,
  rien n'est consommé.
- **Négociation ouverte avant le passage de saison** : la discussion est déjà close par le passage de saison
  (`settleContracts` vide les discussions) ; rien à reporter.
- **Changement de club en cours de carrière** : R8.
- **Indemnité de formation versée par le club joué** (il recrute un jeune formé ailleurs) : elle fait partie
  du coût d'arrivée ; elle consomme l'enveloppe.
- **Dividende ou prêt de l'actionnaire à l'ouverture** : l'enveloppe est fixée **après** l'ouverture des
  comptes (dividende déjà sorti de la caisse).
- **Montants** : arrondis à 10 000 € pour l'enveloppe ; dépensé et reconstitué à l'euro.

## Dépendances

| Système | Sens | Lien |
| --- | --- | --- |
| Budget de saison (`club-budget.cjs` : recettes, réserve, propriétaire, ouverture) | amont | entrées de la formule ; l'enveloppe est fixée après `budgetOuvrir` |
| Confiance du président (`S.trust`) | amont | facteur confiance |
| Recrutement de joueurs libres (`gestion.cjs` commande `recruit`, `dist/economy.js` `confirmContract`) | aval | refus + débit de l'enveloppe |
| Marché entre clubs (`interclub-market.cjs` : `interclub_negotiate`, `interclub_auction`, `interclub_transfer`) | aval | refus + débit |
| Reprise du président (`president-reprise.cjs`) | interface | un achat dans l'enveloppe ne déclenche plus la reprise ; ses ventes ne rendent rien |
| Prêt de l'actionnaire (`club-owner.cjs`) | interface | sa vente forcée ne rend rien |
| Indemnités de formation (`formation-fees.cjs`) | aval | reçues : +50 % ; versées : consomment |
| Écrans Recrutement et Finances (Godot) | aval | lisent `finance.transferBudget` |
| Fiches UX `design/ux/09-recrutement.md` §6.1, §8, §13 ; `design/ux/17-finances.md` §7, §13 | aval | répond aux questions ouvertes « budget de recrutement » |

## Réglages (tuning knobs)

Tous dans `native/engine/budget-transferts.json` (aucune valeur en dur) : `taux` par division,
`ambition` par type de propriétaire, `confiance.min/max`, `tresorerie.min/max`, `plancher`, `plafond`,
`matelas.fixe`, `matelas.partReserve`, `partVentes`, `arrondi` (10 000). Plages sûres : tableau des
Formules. Levier principal pour durcir ou assouplir le marché : `taux` ; pour accentuer la hiérarchie entre
clubs : `ambition` ; pour récompenser la gestion : `tresorerie.max`.

## Critères d'acceptation

1. Carrière Monde neuve (Top 14) : l'en-tête Recrutement affiche « Disponible pour les transferts » avec un
   montant égal à `finance.transferBudget.disponible`, entre 0,5 % et 6 % des recettes du club.
2. Une offre (joueur libre ou accord entre clubs) dont l'indemnité ou la prime dépasse le disponible est
   refusée avant signature, avec une raison qui cite le reste et l'enveloppe ; la trésorerie et l'effectif
   sont inchangés.
3. Une recrue signée dans l'enveloppe baisse le disponible exactement de la prime ou de l'indemnité ; une
   prolongation ne le baisse pas.
4. `disponible ≤ caisse − matelas` à tout moment, y compris après une perte de trésorerie sans achat.
5. Un achat dans l'enveloppe ne déclenche pas la reprise du président.
6. Une indemnité de formation reçue rend 50 % au disponible ; une vente du président ne rend rien.
7. Passage de saison : nouvelle enveloppe calculée, dépensé et reconstitué remis à 0.
8. Sauvegarde d'une carrière antérieure (sans enveloppe) : l'enveloppe est calculée à la première lecture,
   sans erreur ni réécriture de la sauvegarde à l'ouverture.
9. Changer les valeurs du JSON change l'enveloppe sans modifier le code.

## Questions ouvertes

- **Q1** — Rallonge du conseil en cours de saison (demande motivée, effet sur la confiance) : plus tard, si
  le refus sec frustre en partie.
- **Q2** — Vente volontaire d'un joueur depuis Godot (accepter une offre) : nécessaire pour que R4 prenne
  tout son sens ; chantier distinct.
- **Q3** — Faut-il exposer l'enveloppe des clubs gérés (fiche club, presse) ? Non pour l'instant.
