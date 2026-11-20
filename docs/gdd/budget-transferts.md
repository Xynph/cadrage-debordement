# Budget de transferts

> **Statut** : proposition (economy-designer puis game-designer, 19/11/2026), à implémenter.
> **Décision d'origine** : Léo, 19/11/2026 — un vrai budget de transferts, distinct de la trésorerie.
> **Décisions complémentaires** : Léo, 19/11/2026 — rallonge demandée au conseil (R3 bis, ex-Q1) et report partiel
> d'une saison à l'autre (R5) ; règle mise à jour par game-designer le même jour.
> **Périmètre** : carrière Monde (world-champ) au budget de saison réaliste (`budgetActif()`), club joué seulement.
> **Rigueur** : `minimal` (project.yaml). Réglages proposés : `native/engine/budget-transferts.json`.

## Vue d'ensemble

En début de saison, le conseil d'administration fixe une **enveloppe de transferts** : la somme que le
manager peut engager en **indemnités de transfert** (accords avec un autre club) et en **primes à la
signature** des recrues. Les salaires n'y entrent pas : ils restent jugés par la masse salariale (plafond de
la ligue, 52 % des recettes, A2R). L'enveloppe se lit en tête des écrans Recrutement et Finances
(« Disponible pour les transferts »). Une offre qui la dépasse est refusée, avec la raison écrite. Les ventes
choisies par le club en rendent une partie. Quand une offre dépasse l'enveloppe mais que la caisse la permettrait, le
manager peut demander au conseil une rallonge du montant manquant ; le président répond aussitôt, et la demande coûte de
la confiance. Un quart du reste non dépensé passe à la saison suivante. L'enveloppe ne peut jamais dépasser ce que la
caisse permet de dépenser sans entamer le matelas du club.

Aujourd'hui (vérifié dans le code) : aucune enveloppe n'existe ; seules la trésorerie (`club().cash`), une
réserve fixe de 400 000 € (marché entre clubs) et, après coup, l'intervention du président
(`president-reprise.cjs`) freinent les achats. Le « transferBudget » de `dist/career-integration.js` est un
calcul d'affichage de l'ancienne interface web (caisse − 300 000 €), jamais enregistré ni lu par Godot.

## Fantasme du joueur

« Le président m'a donné 1,1 M€ pour renforcer l'équipe cette saison. Je sais ce que je peux faire avant
d'ouvrir une négociation : un grand nom, ou trois joueurs de rotation. Si je vends un joueur, j'en récupère
une partie. Il me manque 40 000 € pour le joueur que je veux : je peux aller les demander au président, mais
ça me coûtera un peu de sa confiance. Ce que je n'ai pas dépensé n'est pas perdu : une part revient la saison
prochaine. »

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

Le refus réutilise le chemin existant (raison de devis, `available:false`). Quand c'est l'enveloppe qui bloque et que
la caisse permettrait l'offre, le refus propose en plus une rallonge (R3 bis). Quand c'est la caisse qui bloque, la
raison le dit (« … Une rallonge du conseil ne suffirait pas : la caisse doit rester au-dessus de X € ») et aucune
rallonge n'est proposée.

### R3 bis — Rallonge demandée au conseil (décision de Léo, 19/11/2026)

1. **Quand** : une offre (prime d'une recrue libre ou indemnité entre clubs) dépasse le **reste** de l'enveloppe, mais
   pas la caisse : reste < offre ≤ caisse − matelas. Sous le refus, un bouton « Demander X € au conseil ».
2. **Combien** : X = offre − reste, arrondi au millier supérieur.
3. **Confirmation** (motif W1 : libellé = action, focus par défaut sur Annuler) : elle annonce l'effet sur la confiance
   (−3 si accordée, −1 si refusée) et le nombre de rallonges déjà accordées.
4. **Réponse immédiate, sans hasard** : accordée si (a) moins de 2 rallonges déjà accordées cette saison, (b) confiance
   du président ≥ 55, (c) X ≤ 50 % de l'enveloppe fixée en début de saison. Sinon refusée, avec la première raison
   manquée, dans cet ordre : « Le président refuse : le conseil a déjà accordé 2 rallonges cette saison. » ; « … sa
   confiance (40/100) est trop basse pour rouvrir l'enveloppe ; il en faut 55. » ; « … 600 000 € dépassent 50 % de
   l'enveloppe fixée en début de saison (500 000 € au plus). »
5. **Effets** : accordée, X s'ajoute à l'enveloppe de la saison (champ `rallonge`) et la confiance baisse de 3 ;
   refusée, la confiance baisse de 1. Chaque demande est comptée (`demandes`, `rallongesAccordees`) et écrite dans les
   nouvelles du club (« Budget de transferts : le conseil accorde une rallonge de X €. » / « Budget de transferts :
   demande de rallonge de X € refusée. Le président refuse : … »).
6. **Après la réponse**, le devis est rafraîchi : accordée, l'offre devient possible ; le disponible reste plafonné par
   caisse − matelas (R6).
7. La rallonge n'est pas une dépense : la caisse ne bouge pas. Elle ne crée pas non plus de dette (≠ prêt de
   l'actionnaire) ; elle ne fait que desserrer l'enveloppe dans la limite de la caisse.

Contrat moteur : commande `transfer_budget_extension {amount, confirmed:true}` (montant entier, multiple de 1 000) ;
réponse dans `meta.transferBudgetExtension = {accordee, montant, message, confiance, coutConfiance}`. La vue
`finance.transferBudget` expose `enveloppe, report, rallonge, depense, reconstitue, reste, caisseLibre, disponible,
matelas, demandes, rallongesAccordees, rallongeMax, rallongeArrondi, rallongeCout{accordee,refusee}, saison` : une
rallonge est possible pour une offre m si `reste < m ≤ caisseLibre` (calcul repris par `ui/transfer_budget.gd`,
`extension_amount`, pour les deux négociations, l'indemnité entre clubs étant modifiable).

### R4 — Ventes : reconstitution partielle

- Une **vente choisie** par le club (offre acceptée, indemnité de formation reçue pour un jeune formé au
  club) rend **50 %** de son montant à l'enveloppe ; le reste renforce la trésorerie.
- Une **vente imposée** ne rend rien à l'enveloppe : vente décidée par le président (reprise), vente pour
  rembourser le prêt de l'actionnaire. Elles servent à renflouer la caisse, pas à racheter.
- **Pas de plafond d'enveloppe** (décision de Léo, 19/11/2026) : la part rendue n'est plus limitée par recettes ×
  plafond ; seule la caisse limite ce qu'on peut dépenser (R6 : disponible = min(reste, caisse − matelas)). Une vente
  conclue hors période des mutations rend sa part au moment de son exécution (`docs/gdd/vente-joueurs.md`).
- Une indemnité d'accord d'achat conclu hors période (`docs/gdd/calendrier-mutations.md`) est engagée sur l'enveloppe
  dès la conclusion ; la prime d'un pré-contrat la consomme à la signature.
- **Argent rendu à la bascule de saison** (décision du 20/11/2026, calendrier des mutations v2) : depuis que les ventes et
  les achats s'exécutent au 1er juillet, la part d'une vente choisie exécutée à la bascule et l'indemnité engagée d'un
  achat qui tombe à la bascule reviennent **entières à l'enveloppe de la saison qui commence** (elles forment son
  reconstitué de départ), jamais à la saison close. Raison : l'argent arrive en juillet, pour le recrutement de la
  nouvelle saison ; le crédité à la saison close ne passait que pour 25 % par le report (R5), donc 12,5 % de la vente au
  lieu de 50 %. Le report (R5) ne compte pas cet argent une seconde fois. Champ technique : `aNouvelleSaison` de
  l'enveloppe close, repris par `budgetTransfertsNeuf` ; test `tests/calendrier-mutations.cjs` « Bascule : part des
  ventes et achats tombés rendus à la nouvelle saison ».

### R5 — D'une saison à l'autre : report partiel (décision de Léo, 19/11/2026)

À l'ouverture de la nouvelle saison, **25 %** du reste non dépensé de la saison qui se termine (enveloppe + report +
rallonge + reconstitué − dépensé) s'ajoute à la nouvelle enveloppe (champ `report`), arrondi au millier inférieur et
plafonné pour que enveloppe neuve + report ≤ recettes × plafond. Dépensé, reconstitué, rallonges et demandes repartent
à 0. **Pas de report** si le club a changé (l'ancienne enveloppe appartient à un autre club) ni si l'enveloppe connue
n'est pas celle de la saison précédente (carrière antérieure). Le reste de l'argent non dépensé reste dans la caisse et
améliore aussi l'enveloppe suivante (facteur trésorerie). Le report apparaît dans la vue et dans l'infobulle
(« Report de la saison passée : X € »).

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
report     = arrondi1k↓( min(partReport × reste(saison précédente), recettes × plafond − enveloppe) )   (même club, sinon 0)

matelas    = max(matelas.fixe, matelas.partReserve × réserve)
caisseLibre= max(0, cash − matelas)
reste      = max(0, enveloppe + report + rallonge + reconstitué − dépensé)
disponible = min(reste, caisseLibre)
reconstitué += partVentes × vente choisie            (sans plafond d'enveloppe, R4 du 19/11/2026)

rallonge demandée X = arrondi1k↑(offre − reste)        si reste < offre ≤ caisseLibre, sinon aucune
accordée  ⇔ rallongesAccordees < maxParSaison  et  confiance ≥ confianceMin  et  X ≤ partEnveloppe × enveloppe
accordée : rallonge += X ; confiance −= coutAccordee      refusée : confiance −= coutRefusee
```

Variables : `offre` = prime ou indemnité refusée (€) ; `rallonge` = somme des rallonges accordées dans la saison
(0 → 2 × 50 % de l'enveloppe) ; `report` (0 → recettes × plafond − enveloppe) ; `confiance` = `S.trust` (0–100).
Exemple (Castres, enveloppe 480 000 €, dépensé 440 000 €, caisse 3,7 M€, matelas 1,89 M€, confiance 72) : offre
de 85 500 € → reste 40 000 €, X = 46 000 € ≤ 240 000 €, accordée ; confiance 69 ; reste 86 000 €, l'offre passe.
Fin de saison avec 200 000 € non dépensés : report de 50 000 € sur l'enveloppe suivante.

Valeurs proposées (`native/engine/budget-transferts.json`) :

| Clé | Valeur | Plage sûre |
| --- | --- | --- |
| `taux.elite` (Top 14) | 0,015 | 0,010 – 0,025 |
| `taux.accession` (Pro D2) | 0,015 | 0,010 – 0,025 |
| `taux.defaut` (autres championnats) | 0,015 | 0,010 – 0,025 |
| `ambition.mecene` / `entreprise` / `association` | 1,3 / 1,0 / 0,7 | 0,5 – 1,6 |
| `confiance.min` / `confiance.max` (confiance 0 → 100) | 0,75 / 1,25 | 0,6 – 1,4 |
| `tresorerie.min` / `tresorerie.max` (caisse / réserve) | 0,5 / 1,5 | 0,3 – 2 |
| `plancher` / `plafond` (part des recettes) | 0,005 / 0,04 | 0,003 – 0,008 / 0,03 – 0,06 |
| `matelas.fixe` / `matelas.partReserve` | 400 000 € / 0,5 | 300 k – 600 k / 0,3 – 0,8 |
| `partVentes` | 0,5 | 0,25 – 0,75 |
| `rallonge.confianceMin` (seuil de confiance) | 55 | 40 – 70 |
| `rallonge.partEnveloppe` (part de l'enveloppe fixée) | 0,5 | 0,2 – 0,75 |
| `rallonge.maxParSaison` | 2 | 1 – 3 |
| `rallonge.coutAccordee` / `coutRefusee` (points de confiance) | 3 / 1 | 1 – 5 / 0 – 3 |
| `rallonge.arrondi` | 1 000 € | 1 000 – 10 000 € |
| `partReport` | 0,25 | 0 – 0,5 |

Exemple (Castres Tarn Rugby, Top 14, carrière Monde neuve) : recettes 29,6 M€, entreprise actionnaire,
confiance 72, caisse 3,7 M€, réserve 3,78 M€ → 29,6 M × 0,015 × 1,0 × 1,11 × 0,98 ≈ 483 000, soit **480 000 €** ;
caisse − matelas = 3,7 M − 1,89 M = 1,81 M€ (non limitant).

## Calibrage sur données réelles (19/11/2026)

Source : section « Économie réelle des transferts en rugby (19/11/2026) » de
[`docs/ressources-utiles.md`](../ressources-utiles.md). Faits retenus : (1) aucune source publique ne donne un « budget
transferts » alloué par un conseil ni une dépense annuelle de recrutement hors salaires ; (2) les rachats de contrat se
négocient de gré à gré, sans barème, et se situent surtout entre **100 et 500 k€** (clause libératoire du cas Jaminet :
450 k€ ; Nu'u, Colomiers → Vannes : ≈ 300 k€ estimés) ; (3) le **record connu** est Kolbe, Toulouse → Toulon, ≈ **1,8 M€** ;
(4) un club de Top 14 dépense en réalité **0 à 2 rachats par saison** ; (5) budgets réels : Top 14 de 26 M€ (Vannes) à
60,3 M€ (Toulouse), Pro D2 de 5,5 M€ (Aurillac) à 20 M€ (Provence Rugby), moyenne 11 M€ ; (6) de nombreux clubs sont
déficitaires, donc peu de marge. Conséquence : `taux.elite` 0,020 → **0,015** (médiane Top 14 de 1,16 M€ à 855 k€,
soit 6 à 7 rachats médians) et `plafond` 0,06 → **0,04** (maximum Top 14 de 1,84 M€ à 1,39 M€, sous le record réel de
1,8 M€). Les montants de presse sont des estimations ; recoupement avec le Livre 4 LNR encore à faire.

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
| **Enveloppe, confiance 72** min / médiane / max (recalibrée 19/11/2026) | 240 k / **855 k** / 1,39 M€ | 80 k / **160 k** / 300 k€ |
| Enveloppe, confiance 20 → 95 (médiane) | 0,66 → 0,94 M€ | 120 k → 180 k€ |

(Avant le calibrage : Top 14 310 k / 1,16 M / 1,84 M€, taux 0,020, plafond 6 % ; Pro D2 inchangé, son taux de
0,015 et le plancher n'ont pas bougé.)

Lecture :

1. **Pouvoir d'achat** : Top 14 médian ≈ 6,6 indemnités médianes ou 2,2 du 90ᵉ centile par saison ; Pro D2
   médian ≈ 4 médianes ou 1,6 du 90ᵉ centile. Le joueur le plus cher n'est accessible qu'aux clubs riches et
   ambitieux. Les primes de joueurs libres (1 000 à 11 000 €) ne sont presque jamais bloquées. **Sain**, et plus
   proche du réel (voir « Calibrage sur données réelles »).
2. **Pas de club à zéro** : la majorité des Pro D2 démarre sous sa réserve ; une règle « caisse − réserve »
   leur aurait donné 0 €. Le plancher (0,5 % des recettes) et le matelas à demi-réserve leur laissent
   80 à 300 k€. **Sain.**
3. **Écart entre clubs** : ×6 en Top 14, ×4 en Pro D2 — la hiérarchie se voit sans écraser les petits. **Sain.**
4. **Confiance** : −22 % / +10 % autour de la médiane Top 14 (confiance 20 / 95) ; lisible, pas assez fort pour être un levier à farmer (fixée une
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
- **Montants** : arrondis à 10 000 € pour l'enveloppe ; au millier pour rallonge et report ; dépensé et reconstitué
  à l'euro.
- **Rallonge, caisse limitante** : offre > caisse − matelas : pas de bouton ; la raison dit que la caisse limite. Si le
  reste dépasse déjà caisse − matelas, la commande est refusée (« Pas de rallonge possible : c'est la caisse qui
  limite… ») sans rien écrire (ni confiance, ni compteur).
- **Rallonge pendant un match** : refusée (« Le conseil ne se réunit pas pendant un match. »).
- **Rallonge demandée puis non utilisée** : elle reste dans l'enveloppe ; 25 % de ce qui n'est pas dépensé passe à la
  saison suivante comme le reste.
- **Demandes répétées** : chaque refus coûte 1 point ; le plafond de 2 rallonges accordées limite l'usage ; la
  confirmation affiche le compteur pour éviter une demande perdue d'avance.
- **Enveloppe refixée dans la même saison** (réouverture des comptes) : le report déjà calculé est gardé.
- **Sauvegarde antérieure** (sans `report`, `rallonge`, `demandes`, `rallongesAccordees`) : champs lus comme 0.

## Dépendances

| Système | Sens | Lien |
| --- | --- | --- |
| Budget de saison (`club-budget.cjs` : recettes, réserve, propriétaire, ouverture) | amont | entrées de la formule ; l'enveloppe est fixée après `budgetOuvrir` |
| Confiance du président (`S.trust`) | amont et aval | facteur confiance ; seuil de la rallonge ; une demande la baisse (−3 / −1) |
| Nouvelles du club (`news`) | aval | une ligne par demande de rallonge |
| Recrutement de joueurs libres (`gestion.cjs` commande `recruit`, `dist/economy.js` `confirmContract`) | aval | refus + débit de l'enveloppe |
| Marché entre clubs (`interclub-market.cjs` : `interclub_negotiate`, `interclub_auction`, `interclub_transfer`) | aval | refus + débit |
| Reprise du président (`president-reprise.cjs`) | interface | un achat dans l'enveloppe ne déclenche plus la reprise ; ses ventes ne rendent rien |
| Prêt de l'actionnaire (`club-owner.cjs`) | interface | sa vente forcée ne rend rien |
| Indemnités de formation (`formation-fees.cjs`) | aval | reçues : +50 % ; versées : consomment |
| Calendrier du recrutement (`docs/gdd/calendrier-mutations.md`) | aval | accord d'achat différé : indemnité engagée à la conclusion (rendue s'il tombe) ; prime de pré-contrat débitée à la signature |
| Écrans Recrutement et Finances (Godot) | aval | lisent `finance.transferBudget` |
| Fiches UX `design/ux/09-recrutement.md` §6.1, §8, §13 ; `design/ux/17-finances.md` §7, §13 | aval | répond aux questions ouvertes « budget de recrutement » |

## Réglages (tuning knobs)

Tous dans `native/engine/budget-transferts.json` (aucune valeur en dur) : `taux` par division,
`ambition` par type de propriétaire, `confiance.min/max`, `tresorerie.min/max`, `plancher`, `plafond`,
`matelas.fixe`, `matelas.partReserve`, `partVentes`, `arrondi` (10 000), `rallonge.*` (seuil de confiance, part de
l'enveloppe, nombre par saison, coûts en confiance, arrondi), `partReport`. Plages sûres : tableau des Formules.
Rallonge : `confianceMin` et `coutAccordee` règlent combien le manager peut forcer la main du conseil ; `partReport`
règle la récompense de l'économie (0 = ancienne règle sans report). Levier principal pour durcir ou assouplir le marché : `taux` ; pour accentuer la hiérarchie entre
clubs : `ambition` ; pour récompenser la gestion : `tresorerie.max`.

## Critères d'acceptation

1. Carrière Monde neuve (Top 14) : l'en-tête Recrutement affiche « Disponible pour les transferts » avec un
   montant égal à `finance.transferBudget.disponible`, entre `plancher` et `plafond` des recettes du club (0,5 % et 4 %
   aujourd'hui).
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
10. Offre refusée par l'enveloppe, caisse suffisante : la négociation (joueur libre ou entre clubs) montre « Demander
    X € au conseil » avec X = offre − reste arrondi au millier supérieur ; la confirmation a le focus sur Annuler et
    annonce l'effet sur la confiance.
11. Confiance ≥ 55, X ≤ 50 % de l'enveloppe fixée, moins de 2 rallonges accordées : accordée ; `rallonge` += X ;
    confiance −3 ; une ligne dans les nouvelles ; le devis rafraîchi rend l'offre possible.
12. Confiance 40 : refusée avec « Le président refuse : sa confiance (40/100)… » ; confiance −1 ; `demandes` +1 ;
    `rallonge` inchangée. Même chose au-delà de 50 % de l'enveloppe, ou après 2 rallonges accordées.
13. Caisse limitante : aucun bouton ; la commande est refusée sans rien modifier.
14. Passage de saison : `report` = 25 % du reste non dépensé (millier inférieur), plafonné ; affiché dans la vue et
    l'infobulle (« Report de la saison passée : X € ») ; rallonges et demandes remises à 0.
15. Changement de club : `report` = 0.

## Questions ouvertes

- **Q1** — *Résolue* (Léo, 19/11/2026) : rallonge demandée au conseil, voir R3 bis.
- **Q2** — Vente volontaire d'un joueur depuis Godot (accepter une offre) : nécessaire pour que R4 prenne
  tout son sens ; chantier distinct.
- **Q3** — Faut-il exposer l'enveloppe des clubs gérés (fiche club, presse) ? Non pour l'instant.
- **Q4** — Pistes de la recherche réelle (19/11/2026), à arbitrer : (a) indemnité de rachat plafonnée aux **salaires
  restants du contrat** du joueur ; (b) joueur **en fin de contrat** : arrivée sans indemnité, seule la prime consomme
  l'enveloppe ; (c) **seuil LNR de 350 k€** au-delà duquel l'indemnité entre dans le salary cap du club d'accueil (à
  recouper avec le Livre 4 officiel avant de coder).
