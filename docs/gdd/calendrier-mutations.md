# Calendrier du recrutement (mutations, joueurs libres, pré-contrats)

> **Statut** : implémenté (game-designer, economy-designer, gameplay-programmer, ui-programmer CCGS, 19/11/2026, mode autonome, rigueur `minimal`) ; décisions de Léo du 19/11/2026 ; **v2 (19/11/2026, soir)** : clubs gérés au même calendrier, compensations d'agrément, indemnité plafonnée aux salaires restants, fin du plancher de 40 pour le club joué (§ 3 bis, 3 ter, 3 quater)
> **Mode** : carrière Monde (`world-champ`) uniquement
> **Cap** : consolider — réutiliser la période des mutations et les accords différés de la vente de joueurs (PR #1009)
> **Source** : régime des mutations LNR 2023-24 ([PDF](https://www.techxv.org/IMG/pdf/lnr_-_periode_de_mutations_2023-2024.pdf)), voir `docs/ressources-utiles.md` § « Fenêtres de recrutement et de cession »
> **Liés** : `docs/gdd/vente-joueurs.md`, `docs/gdd/budget-transferts.md`
> **Code** : `native/engine/calendrier-mutations.cjs` + `calendrier-mutations.json` ; période des mutations dans `vente-joueurs.json` (`fenetres`) ; tests `tests/calendrier-mutations.cjs`, `tests/godot-calendrier-mutations.{cjs,gd}`

## 1. Vue d'ensemble

Le recrutement suit le calendrier réel du rugby professionnel français :

| Opération | Quand | Hors période |
|---|---|---|
| Joueur sous contrat d'un autre club (achat) | accord conclu **toute l'année** ; mai-juin = temps fort (période des mutations, autres clubs en concurrence) | le joueur arrive toujours au **1er juillet** (bascule de saison) |
| Vente d'un joueur du club (PR #1009) | accord conclu toute l'année | départ au 1er juillet |
| Vente imposée (président, prêt de l'actionnaire) | accord conclu tout de suite | départ au 1er juillet |
| Joueur sans club (commande `recruit`) | 1er mai – 31 décembre | fermé, réouverture le 1er mai |
| Joueurs supplémentaires | 1er – 31 janvier, **2 par saison** | — |
| Jokers (renforts pris parmi les joueurs sans club, jokers médicaux) | 1er juillet – 31 mars | les espoirs montent (club joué) ; pas de joker médical (clubs gérés) |
| Pré-contrat (joueur à moins de 6 mois de la fin de son contrat) | 1er janvier – 30 juin | arrivée le 1er juillet, sans indemnité |

Chaque refus écrit la raison et la date de réouverture. Les pré-contrats marchent dans les deux sens : le club joué en signe avec des joueurs d'autres clubs, et les autres clubs approchent ses joueurs en fin de contrat (courrier, deux semaines pour proposer une prolongation).

## 2. Fantasme

« On est en février, je ne peux plus signer de joueur libre : il fallait se décider avant le 31 janvier. Mais le talonneur de Pau finit son contrat en juin : je lui fais signer un pré-contrat, il arrivera le 1er juillet sans que je verse un euro à Pau, juste sa prime. Le lendemain, mon directeur sportif m'écrit : Bayonne a approché mon ouvreur. J'ai deux semaines pour le prolonger, sinon il part libre cet été. »

## 3. Règles

1. **Période des mutations** (achats et ventes entre clubs, ventes imposées) : 1er mai – 30 juin, réglée une seule fois dans `vente-joueurs.json` (`fenetres`) pour les deux sens. **v2 (décision de Léo du 19/11/2026, soir) : comme au football, on négocie et on conclut toute l'année, mais le joueur n'arrive qu'au mercato suivant, c'est-à-dire au 1er juillet (bascule de saison), pour tous les clubs, club joué compris.** Plus aucun transfert immédiat, même en mai-juin : une recrue ne renforce pas son nouveau club pour les phases finales. L'accord est revérifié et exécuté à la bascule (avant les prolongations automatiques et le départ des joueurs libres), comme un pré-contrat. Un joueur dont le contrat s'achève cette saison ne s'achète plus : seulement le pré-contrat (à partir du 1er janvier). Le texte ci-dessous (v1) reste vrai sauf la date d'exécution.
   - (v1) Achat pendant la période : immédiat. Hors période, la négociation (`interclub_negotiate`) ne reçoit que l'offre du manager — les autres clubs n'enchérissent qu'en période ; la clôture (`interclub_auction`) ou l'accord direct (`interclub_transfer`) crée un **accord d'achat** dans la liste des accords de la vente (`S.venteJoueurs.accords`, `sens: 'achat'`). L'indemnité est **engagée** tout de suite sur le budget de transferts (le disponible baisse), la caisse ne bouge pas, le joueur reste à son club.
   - À la première clôture de semaine à partir de l'ouverture, l'accord est revérifié (joueur encore au vendeur, garde d'effectif du vendeur, place dans l'effectif, réserve de 400 000 €) puis exécuté (caisse, ligne « Libération anticipée », arrivée) ; sinon il tombe avec la raison, et l'indemnité engagée revient à l'enveloppe de la même saison (v2 : un accord qui tombe à la bascule du 1er juillet la rend à l'enveloppe de la saison qui commence, comme la part des ventes exécutées ce jour-là, `budget-transferts.md` R4).
2. **Joueurs sans club** : ouverts du 1er mai au 31 décembre. En janvier, au plus **2 joueurs supplémentaires** par saison (compteur `S.calendrierMutations.supplementaires`). Du 1er février au 30 avril : fermé. La raison est affichée sur chaque piste (Recrutement, « Vigilance » et bouton grisé) et la commande `recruit` la renvoie.
3. **Jokers** : jusqu'au 31 mars. Club joué : les renforts pris parmi les joueurs sans club pour compléter la feuille (`promote_cover`, club-budget.cjs) ne sont plus possibles du 1er avril au 30 avril (les espoirs montent comme avant) ; clubs gérés : pas de joker médical (club-directions.cjs).
4. **Pré-contrat, club joué → joueur d'un autre club** : possible pour un joueur dont le contrat s'achève cette saison, à moins de 6 mois de son échéance (30 juin), donc à partir du 1er janvier. Commande `precontract_offer` ; le joueur accepte si le salaire atteint sa demande (`askingWage`), durée 1 à 3 saisons (bornée par la fin de carrière). Aucune indemnité pour son club ; seule une **prime à la signature** (2 semaines de salaire, au millier supérieur) est payée tout de suite et **consomme le budget de transferts**. Il reste à son club jusqu'au 30 juin et arrive au **1er juillet** (bascule de saison, avant le départ des joueurs libres). **Plafond : 3 pré-contrats signés par saison au plus** (`preContrats.maxParSaison`, comptés sur la saison de signature ; un pré-contrat qui tombe ensuite ne compte plus). Au-delà, la commande est refusée et la piste grisée : « Tu as déjà signé 3 pré-contrats cette saison (3 au plus) : les suivants attendront la saison prochaine. » (la raison de date garde la priorité). Raison chiffrée (relevé du 20/11/2026) : 89 % des joueurs éligibles valent plus de 1,2 × un an de salaire demandé, et la boucle « pré-contrat puis revente un an plus tard » rapporte en médiane 56 000 € par joueur, jusqu'à 380 000 €.
5. **Pré-contrat, autre club → joueur du club joué** : à la clôture de certaines semaines (tirage déterministe graine + saison + semaine, chance 0,2, au plus 2 par saison), un club dans le besoin au poste approche un des 8 meilleurs joueurs en fin de contrat éligibles. Courrier « precontrat_approche » (lien « Proposer une prolongation » → fiche du joueur, onglet Contrat). Le manager a **14 jours** pour le prolonger (`extend_contract`, ou par l'agent) : l'autre club renonce. Sinon il signe : courrier « precontrat_signe », la presse en parle (fil des transferts), la prolongation et la mise en vente sont refusées (« A signé un pré-contrat avec Y : il part libre le 1er juillet. »), le directeur sportif ne le prolonge pas. Il reste **pleinement professionnel** jusqu'au 30 juin : aucune jauge n'est touchée. Au 1er juillet il rejoint le club, libre, sans indemnité.
6. **Ventes imposées** : la vente du président (reprise, `president-reprise.cjs`) et la vente pour rembourser le prêt de l'actionnaire (`club-owner.cjs`) suivent la règle commune (v2) : l'accord est conclu tout de suite (le joueur ne peut plus être vendu ailleurs) et exécuté au 1er juillet ; le remboursement du prêt se fait à l'exécution. Rien ne revient au budget de transferts, pas de conséquence de vestiaire. Le courrier du président le dit (« Nous sommes hors période des mutations… »). Cette règle vise le club joué ; les ventes du président d'un club géré ont lieu à la bascule et sont exécutées le jour même (§ 3 bis 5).
7. **Clubs gérés** : ils suivent exactement le même calendrier que le club joué (décision de Léo du 19/11/2026, § 3 bis).

## 3 bis. Clubs gérés au même calendrier (v2)

1. **Achats entre clubs gérés** (`club-transfers.cjs`, `club-directions.cjs`) : ils **concluent toute l'année** et le joueur arrive au **1er juillet** (bascule), comme pour le club joué. Tours de marché : semaines 0 (fin août) et 13 (novembre) comme avant, un tour toutes les 4 semaines de janvier à avril, puis **un tour par semaine pendant la période des mutations** (1er mai – 30 juin, temps fort) et **deux tours la dernière semaine** (celle dont la date + 7 jours dépasse le 30 juin : « dernière semaine du mercato »). Bornes par saison inchangées : 3 achats et 3 ventes par club (accords conclus dans la saison), une transaction par club et par tour. **Hors période des mutations** (semaines 0 et 13, hiver), seule une part `participationHorsPeriode` des clubs gérés (10 %, tirage déterministe graine + saison + semaine + club) tient le tour ; pendant la période, tous : le gros des accords se conclut en mai-juin.
   - Club acheteur (réglage de la mesure du 20/11/2026) : il cherche à recruter selon le **même seuil qu'avant la v2** (effectif sous max(40, cible), plans offensifs jusqu'à cible + 2), lu sur l'**effectif projeté** (effectif actuel − départs conclus + arrivées conclues), et doit en plus avoir place et masse de la saison suivante. Raison : un tiers des contrats s'achève chaque saison et la plupart sont prolongés à la bascule ; la seule « place de la saison suivante » (contrats qui s'achèvent retirés) rendait presque tous les clubs acheteurs à chaque tour (≈ 80 accords par saison, surtout l'hiver, contre 16 à 40 avant la v2).
   - Accord conclu : le joueur est réservé (plus achetable, ni pré-contrat), annoncé dans les actualités ; il reste à son club jusqu'à la bascule. L'acheteur doit avoir la place et la masse salariale **de la saison suivante** (masse − salaires qui s'achèvent + accords en attente + nouveau salaire ≤ limite). Indemnité payée à l'exécution ; caisse ou place insuffisante à la bascule → l'accord tombe (actualité).
   - Le contrat signé court à partir de la saison suivante : échéance = saison + durée.
   - Les prêts de jeunes et leurs retours restent en début de saison (semaine 0) : ce ne sont pas des achats.
2. **Joueurs sans club** : inchangé, recrutements aux semaines 0 (fin août) et 13 (novembre), toutes deux avant le 31 décembre ; rien de janvier au 30 avril hors jokers médicaux.
3. **Jokers médicaux** : jusqu'au 31 mars (déjà en place), un par club et par saison.
4. **Pré-contrats entre clubs gérés** : du 1er janvier au 30 juin, à chaque clôture de semaine, des clubs gérés signent des joueurs **en fin de contrat** d'autres clubs gérés (contrat qui s'achève cette saison, au moins 2 saisons de carrière devant lui). Arrivée à la bascule de saison (« 1er juillet »), **sans indemnité**, avant le départ des joueurs libres et les prolongations automatiques des clubs gérés.
   - Acheteur : un club géré qui a un **besoin** au poste (même lecture des besoins que ses achats), de la place dans son effectif de la saison suivante et une masse salariale de la saison suivante sous sa limite : masse − salaires qui s'achèvent + nouveau salaire ≤ limite.
   - Cible : pas parmi les **5 meilleurs** de son club (ceux-là sont prolongés par leur club), pas prêté, pas déjà engagé (pré-contrat, accord, approche du club joué) ; même règle japonaise que les achats (JLO entre eux).
   - Salaire : ce que le joueur demande chez l'acheteur (même calcul que les achats) majoré de 5 %, durée 1 à 3 saisons selon l'âge.
   - Bornes : 2 pré-contrats signés par acheteur et 2 départs par vendeur et par saison ; au plus `parSemaine` signatures dans tout le Monde chaque semaine (tirage déterministe graine + saison + semaine).
   - Un joueur engagé ainsi ne peut plus être acheté (ni par un club géré ni par le club joué : « A signé un pré-contrat avec X pour la saison prochaine ») ni recevoir un pré-contrat du club joué.
   - À la bascule, si le joueur n'est plus à son club (vendu, retraite) ou si l'acheteur n'a plus de place, le pré-contrat tombe sans effet.
5. **Ventes du président d'un club géré** (`president-reprise.cjs`, `repriseBascule` appelé par `calIAExecuter` ; décision du 20/11/2026) : en v2, l'indemnité d'un achat n'est payée qu'à la bascule, c'est donc **à la bascule, après le paiement des indemnités**, que le président regarde la caisse. Chaque club géré acheteur qui a payé au moins une indemnité dans cette bascule est examiné une fois, avec sa caisse d'avant ses paiements de la bascule (même règle qu'avant la v2 : passage sous la réserve, club « Fragile », tempérament de 4 à 8 mois, au plus deux joueurs désignés, jamais une arrivée de la bascule). S'il intervient, il **tranche le jour même** : ses ventes sont **exécutées tout de suite** et prennent effet au **1er juillet** comme tous les transferts (le joueur vendu arrive chez son nouveau club pour la nouvelle saison, contrat au moins jusqu'à la saison suivante) ; l'intervention est close (« vendu », ou « abandon » faute d'acheteur). Raison : l'argent revient tout de suite dans la caisse, comme avant la v2 ; attendre trois semaines puis passer par un accord repousserait l'argent d'un an et le président ne servirait à rien. Les accords qui tombent ne déclenchent rien ; rien pendant un match ; le club joué n'est pas concerné (§ 3 règle 6). Réglage `calendrier: "semaines"` : inchangé (intervention à l'achat, vente à l'échéance de trois semaines).
6. **Joueurs de complément des clubs gérés** (plancher de 40, `professional-depth.cjs`) : gardés tant que la mesure multi-saisons (§ 3 quater) ne montre pas qu'ils peuvent s'en passer.

## 3 ter. Compensations d'agrément (v2)

Plus d'achats entre clubs de septembre à avril : l'hiver ne doit pas devenir vide, ni mai-juin noyer la Réception.

1. **Hiver vivant** : hors mai-juin, les **accords conclus** entre clubs gérés sont annoncés (« Bordeaux s'est mis d'accord avec Dax pour son talonneur : il arrivera le 1er juillet ») ; de janvier à avril s'y ajoutent les **rumeurs** de presse (un club géré qui suit un joueur en fin de contrat d'un autre club ; environ 70 % sont de vraies pistes, prioritaires la semaine suivante et presque toujours conclues par un pré-contrat ; les autres sont fausses : le club annoncé ne signe pas ce joueur cette saison et **dément** 2 à 4 semaines plus tard, « Bordeaux dément tout intérêt pour X (talonneur de Dax). », sauf si le joueur a quitté son club ; d'autres clubs peuvent toujours le signer) et les **pré-contrats** signés (« Bordeaux a signé le talonneur de Dax pour la saison prochaine »). Tout va dans les actualités et le fil des transferts, et dans un courrier hebdomadaire **« Échos du mercato »** (routine : jamais d'arrêt de Continuer), seulement les semaines où il y a quelque chose.
2. **Courriers de mai-juin regroupés** : pendant la période des mutations, les offres reçues pour les joueurs du club, les accords conclus par le club cette semaine et les principaux accords du Monde sont réunis dans **un seul courrier hebdomadaire « Point mercato »** (information : au plus l'arrêt d'info du jour) avec le lien « Ouvrir · Offres reçues ». Les courriers individuels « offre_transfert » ne sont plus déposés pendant la période (ils le restent hors période). Les courriers qui demandent une décision (approche d'un joueur en fin de contrat) restent individuels. Les arrivées et départs du 1er juillet sont annoncés à la bascule.
3. **Temps forts du mercato** :
   - **ouverture** (première semaine de la période) : courrier « Ouverture du mercato » + actualité (les clubs accélèrent et se font concurrence jusqu'au 30 juin ; tous les accords prennent effet le 1er juillet) ;
   - **dernière semaine** (avant le 30 juin) : courrier « Dernière semaine du mercato » + actualité, avec les plus gros transferts déjà conclus et le rappel que ce qui sera conclu d'ici le 30 juin prendra effet le 1er juillet ; les clubs gérés ont deux tours de marché (mesure : presque aucun accord cette semaine-là, la demande est épuisée début mai — le courrier ne parle donc pas de « rush ») ; **décision du 20/11/2026** : on assume une dernière semaine calme (la demande des clubs gérés est servie dès début mai) ; le courrier garde son texte de récapitulatif, sans rush ; `toursDerniereSemaine` reste à 2 (sans coût) ;
   - **bilan** (première semaine après le 30 juin) : actualité « Bilan du mercato » (nombre de transferts, les trois plus gros montants).

## 3 quater. Indemnités et effectif minimum (v2, décisions de Léo du 19/11/2026)

1. **Indemnité plafonnée aux salaires restants** (tous les clubs : achats du club joué, offres reçues par le club joué, achats entre clubs gérés) : indemnité ≤ salaire hebdomadaire × 52 × saisons de contrat restantes après l'arrivée (les salaires que l'acheteur reprend). Un joueur à qui il reste une saison après le 1er juillet coûte au plus un an de salaire ; un joueur en fin de contrat ne s'achète plus, il signe un pré-contrat sans indemnité. Effet réel mesuré (/balance-check du 20/11) : le plafond borne surtout les achats entre clubs gérés et les offres reçues par le club joué ; le prix demandé au club joué (≈ 29 × salaire × (saisons + 1) / 2) reste presque toujours en dessous, donc pas d'achat « pour presque rien ». **Règle LNR vérifiée sur le texte officiel (20/11/2026)** : LNR, Livre 4 « Régulation administrative et économique », saison 2025/2026 (version consolidée au 9 juillet 2025), article 4095.3 « Indemnisation » ([PDF](https://assets.lnr.fr/2/4/1/7/1/2/LIVRE-4_REGULATION-ADMINISTRATIVE-ET-ECONOMIQUE_2526_124d3643ef67cf4fd37f609401009ed5.pdf), p. 75-76 ; même règle en 2023-24 sous l'ancien article 41 bis). Ce n'est **pas un seuil mais une franchise** : en cas de mutation anticipée d'un joueur sous contrat entre clubs professionnels français, seule la part de l'indemnité **au-delà de la franchise** entre dans le salary cap du club d'arrivée, **la première saison** du nouveau contrat seulement (pas d'étalement). Franchise : au minimum 350 000 €, au maximum le total des salaires bruts que le club quitté aurait encore versés jusqu'au terme du contrat (hors primes autres qu'éthique et assiduité, hors droits d'image). Plafond du salary cap Top 14 : 10,7 M€ (art. 3.1, « jusqu'en 2026/2027 »). **Non utilisé dans le jeu à ce jour** : le moteur n'a pas de salary cap séparé de la limite de masse ; si on l'ajoute, la formule est `part comptée = max(0, indemnité − franchise)`, première saison seulement, avec une franchise comprise entre 350 000 € et les salaires restants (le texte lu ne détaille pas comment elle est fixée entre ces deux bornes : à confirmer avant toute règle). À noter : notre plafond d'indemnité (≤ salaires repris) rend cette part presque toujours nulle.
2. **Club joué : plus de plancher de 40 professionnels** ni de « joueurs de complément » signés automatiquement (les 40 étaient un choix technique, #502, pas une règle LNR). Seul garde-fou : si la feuille de 23 (premières lignes comprises) ne peut pas être remplie avant un match, des **espoirs montent pour ce match**, avec une **alerte avant** (la veille ou dès que l'effectif ne suffit plus).
3. **Clubs gérés** : plancher de 40 gardé ; la mesure compare avec et sans, la décision est notée en § 3 quinquies.
4. **Garde d'effectif du club joué vendeur** : le seuil de 37 professionnels est remplacé par « après le départ, les seuls professionnels permettent encore une feuille de 23 conforme, premières lignes comprises » (calculée sur une copie de l'effectif, blessures et suspensions ignorées) + deux joueurs par famille de postes. Raison : « Après ce départ, tu ne pourrais plus aligner une feuille de 23 complète (manque : …). » Clubs gérés vendeurs : 37 inchangé.
5. **Alerte et espoirs** : arrêt de Continuer « Effectif trop juste » (une fois par match et par manque dans les 7 jours qui précèdent, puis la veille) ; au coup d'envoi, si la feuille reste incomplète et que le manager n'a choisi ni des jeunes ni le match à 22, les meilleurs espoirs aptes montent pour ce match seulement (mécanisme existant des espoirs prêtés pour un match), courrier « Des espoirs montent pour le match ». Exception : quand « Jouer à 22 » est proposé (Nationale, pilier manquant), le choix reste au manager et un coup d'envoi sans réponse est refusé, sans rien écrire.

## 3 quinquies. Mesure multi-saisons et décisions (economy-designer, /balance-check, 20/11/2026)

Script reproductible : `scripts/mesure-mutations-clubs-geres.cjs --saisons 3` (carrière Monde world-champ, club 102, graine 4242, cadence hebdomadaire, ≈ 25 min). AVANT = `CD_CLUBS_GERES_CALENDRIER=semaines` sur `main` ; APRÈS = calendrier v2.

| Relevé (115 clubs gérés), saisons 1 / 2 / 3 | Avant (main) | Après (v2, retenu : masse corrigée) |
|---|---|---|
| Transferts entre clubs gérés | 16 / 27 / 40 achats (semaines 0 et 13) | 22 / 48 / 37 accords (hiver 6–14, mai-juin 20–34, pic la 1re semaine de mai), aucun tombé |
| Indemnité médiane | 250 / 220 / 170 k€ | 250 / 159 / 120 k€ (plafond aux salaires repris) |
| Pré-contrats entre clubs gérés / rumeurs | — | 39 / 25–27 par saison |
| Clubs au-dessus de la limite de masse (semaine 14), dont Pro D2 | 12 / 14 / 17 ; 1 / 2 / 3 | 18 / 16 / 17 ; 1 / 1 / 3 |
| Caisse médiane en fin de saison, clubs en négatif | 3,32 / 1,92 / 1,36 M€ ; 0 / 4 / 9 | 3,37 / 1,81 / 1,49 M€ ; 0 / 3 / 9 |
| Effectif médian ; niveau en saison 3 | 52 / 51 / 50 ; 78,3 | 51 / 50 / 50 ; 77,8 |

Premier essai (masse de la saison suivante qui retirait 100 % des contrats finissants) : 21 clubs au-dessus de la limite en saison 3, dont 6 en Pro D2 → corrigé (`clubsGeres.masse` : 20 % des fins de contrat comptées comme libérées, car 72–76 % sont prolongées ; filet à la bascule qui libère au plus 2 joueurs peu utiles). Rapport complet : `docs/balance/balance-check-calendrier-mutations-20261120.md`.

**Décisions.**
1. Équilibre sain : effectifs, niveaux et caisses des clubs gérés inchangés à quelques pour cent près ; le marché vit toute l'année avec un pic en mai-juin. Participation hors période réglée à 10 % des clubs par tour (`participationHorsPeriode`, essais à 0,2 et 0,5 trop chargés).
2. **Plancher de 40 des clubs gérés gardé** : sans lui, en fin de saison 3, des clubs de Nationale et de Champ descendent à 29–32 professionnels (4 clubs sous 37), sans gain d'économie mesurable.
3. À surveiller : rien de plus pour les rumeurs (corrigé le 20/11/2026 : 70 % de vraies pistes, démentis, `rumeurs.tauxRealisation` ; mesure 3 graines : 65 à 73 % des rumeurs suivies d'un pré-contrat, 7 à 11 démentis par saison, économie inchangée). Dernière semaine calme : assumée (§ 3 ter 3).
4. **Saison 1 : 18 clubs au-dessus de la limite contre 12 — cause trouvée (20/11/2026)**. Ce n'est pas la v2 qui fait monter les masses : 17 à 18 clubs gérés sont au-dessus de leur limite **dès la semaine 0**, dans les deux calendriers, de **2 à 63 € par semaine** (arrondi de la limite hebdomadaire `Math.round(limite annuelle / 52)` face aux salaires de départ). L'ancien tour immédiat de la semaine 13 faisait vendre 6 de ces clubs (stratégie « vente » : ventes immédiates de 110 000 à 1 030 000 €), d'où 12 ; en v2 ces ventes partent au 1er juillet, d'où 18. Mais 14 des 18 clubs étaient passés en stratégie « vente » pour ces quelques euros. **Correction** : la détresse « masse au-dessus de la limite » (`club-directions.cjs`, `scores`) ne compte qu'un dépassement de plus de **1 %** (au-delà de 3 %, détresse impérative, inchangé). Mesure (3 graines, 3 saisons + bascule de la saison 3) : accords entre clubs gérés 29 → 25 en saison 1 (ventes inutiles en moins), caisses, clubs en négatif et niveaux dans le bruit ; le compte brut « au-dessus de la limite » ne change pas (ces clubs restent quelques euros au-dessus sans vendre). À surveiller, déjà sur main : à la bascule de la saison 3, ce compte brut passe de 19 à 25-26 clubs. Test : `tests/club-directions.cjs` (40 € au-dessus : pas de vente ; 2 % : vente).
5. **Dépassements qui remontent à chaque bascule — cause trouvée et corrigée (20/11/2026)**. Relevé enrichi (> 1 % et > 3 % de la limite, par ligue, détail club par club avant/après chaque bascule) : les vrais dérapages (> 1 %) passent de **0** en début de saison 1 à **12** au début de la saison 2, **16,7** au début de la saison 3 et **19,3** après la bascule vers la saison 4 (main, 3 graines), surtout en Championship, Pro D2, Nationale et Japon D2. Sonde étape par étape de la bascule (`scripts/sonde-bascule-masse.cjs`) : la remise à niveau des contrats (`worldNewSeason`) ramène **tous** les clubs sous leur limite ; juste après, l'arrivée des espoirs fait bouger le niveau des clubs de ±2, et la limite, recalculée avec ce niveau (recettes réparties selon le **rang de niveau dans la ligue**), perd 25 à 30 % chez un club de Championship ou de Nationale : 13 clubs > 1 % d'un coup. Prolongations, arrivées du 1er juillet et `partFinsDeContratLiberee` pèsent peu (effacées par la remise à niveau qui suit). **Règle** : la limite de masse d'un club géré est celle du **budget voté au changement de saison** (niveau noté avec le budget, `S.clubBudget.clubs[id].base`) ; un changement de niveau en cours de saison ne la déplace plus, le budget suivant la recalcule. Saison 1, mode France et sauvegardes sans niveau noté : inchangés. Bascule rejouée : 13 → 1 club > 1 %. Mesure 3 graines avant/après : voir PR #1042 et § formules. Test : `tests/limite-masse-saison.cjs`.

### Formules v2

```
clubTientLeTour(c)        = jour ∈ période des mutations ou FNV(graine:saison:semaine:ia-tour:c) mod 1000 < participationHorsPeriode × 1000
chercheÀRecruter(c)       = placeEtMasseSaisonSuivante(c) et (effectifProjeté < max(40, cible) ou plan offensif et effectifProjeté < cible + 2)
effectifProjeté(c)        = effectif − départs conclus (accords, pré-contrats) + arrivées conclues
tourDeMarché(jour, semaine) = semaine ∈ semainesFixes
                            ou (jour ∈ hiver et (semaine − 1re semaine d'hiver) mod toutesLesSemaines = 0)
                            ou jour ∈ période des mutations          (toursParSemaine, toursDerniereSemaine si jour + 7 > fin)
plafondIndemnité(p)       = max(plancherIndemnite, salaire × 52 × (contractEnd − saison))   ex. 9 000 €/sem., 1 saison après l'arrivée → 468 000 €
masseSaisonSuivante(c)    = masse − Σ salaires qui s'achèvent + Σ accords et pré-contrats en attente + nouveau salaire ≤ limite
limite(c, saison)          = limite annuelle de nativeClubBudget.limites(forces, saison) / 52, forces au niveau noté à l'ouverture du budget de la saison (fixe toute la saison ; saison 1 : niveau courant)
préContratIA tiré         = FNV(graine:saison:semaine:pre-ia) ; au plus parSemaine signatures, parAcheteur / parVendeur par saison
salaire pré-contrat IA    = demande chez l'acheteur × majorationSalaire
```

### Réglages v2 (`calendrier-mutations.json`, bloc `clubsGeres`)

| Réglage | Valeur | Plage sûre | Effet |
|---|---|---|---|
| `calendrier` | `mutations` | `mutations` / `semaines` | nouveau calendrier ou ancien (achats immédiats aux semaines 0 et 13, indemnité non plafonnée) ; surcharge `CD_CLUBS_GERES_CALENDRIER` pour la mesure |
| `semainesFixes` | 0, 13 | — | tours d'automne |
| `hiver.periodes` / `toutesLesSemaines` | 01-01 – 04-30 / 4 | 2 – 8 | tours d'hiver |
| `toursParSemaine` / `toursDerniereSemaine` | 1 / 2 | 1 – 3 | intensité de mai-juin et de la dernière semaine |
| `participationHorsPeriode` | 0,1 | 0,05 – 0,5 | part des clubs gérés qui tiennent un tour hors mai-juin (semaines 0, 13 et hiver) ; plus haut = accords plus tôt dans la saison, moins de pic en mai-juin. Mesure 3 saisons (graine 4242) : 0,1 → 26 / 48 / 49 accords, 63 à 77 % en mai-juin ; 0,2 → 31 / 57 / 50, 40 à 74 % ; 0,5 → ≈ 60 % avant mai |
| `plancherIndemnite` | 10 000 € | 10 000 – 50 000 | indemnité minimale |
| `masse.partFinsDeContratLiberee` / `libererALaBascule` | 0,2 / oui | 0,1 – 0,5 (1 = ancien test) | part des salaires qui s'achèvent retirée de la masse de la saison suivante (mesure : 82 à 85 % prolongés à la bascule) ; après les prolongations, un acheteur que ses arrivées font passer au-dessus de sa limite libère au plus deux joueurs peu utiles, à hauteur du salaire de ses arrivées. Mesure 3 saisons (graine 4242) : 22 / 48 / 37 accords, 18 / 16 / 17 clubs au-dessus de la limite (Pro D2 : 1 / 1 / 3) |
| `actusParSemaine` | 4 | 2 – 8 | actualités d'accords par semaine (le fil des transferts les garde toutes) |
| `preContrats.parSemaine` / `parAcheteur` / `parVendeur` | 2 / 2 / 2 | 1 – 4 | ≈ 39 pré-contrats entre clubs gérés par saison |
| `preContrats.meilleursProteges` | 5 | 3 – 8 | meilleurs joueurs prolongés par leur club |
| `preContrats.majorationSalaire` | 1,05 | 1,0 – 1,2 | salaire chez le nouveau club |
| `rumeurs.parSemaine` / `fin` | 2 / 30 avril | 0 – 3 | presse de l'hiver |
| `rumeurs.tauxRealisation` | 0,7 | 0,5 – 0,9 | part des rumeurs qui sont de vraies pistes (tirage déterministe graine + saison + semaine + joueur) ; plus bas = presse moins fiable, plus de démentis ; 1 = ancien comportement (toutes confirmées) |
| `rumeurs.dementiSemaines` | 2 – 4 | 1 – 6 | délai (tiré à la création) entre une fausse rumeur et son démenti, actualité + ligne du mercato à la clôture de semaine |
| plancher des clubs gérés | 40 | — | `CD_PLANCHER_CLUBS_GERES=0` pour la mesure |

### Critères d'acceptation v2 (`tests/clubs-geres-mutations.cjs`, `tests/courrier-mercato.cjs`, `tests/effectif-sans-plancher.cjs`)

1. Carrière Monde world-champ : un accord entre clubs gérés conclu à l'automne laisse le joueur à son club jusqu'à la bascule, puis il arrive (indemnité payée à ce moment-là) ; aucun transfert immédiat en mai-juin ; deux tours la dernière semaine.
2. Pré-contrats entre clubs gérés à partir de janvier, exécutés à la bascule sans indemnité ; le joueur engagé est refusé au club joué avec la raison écrite ; rejeu identique.
3. Indemnité ≤ salaire × 52 × saisons restantes après l'arrivée ; joueur en fin de contrat : pas d'achat, pré-contrat seulement.
4. Achat ou vente du club joué à toute date : accord, effectif au 1er juillet.
5. Courriers : « Échos du mercato » en routine hors mai-juin ; « Point mercato » en information qui regroupe les offres de la semaine ; aucune offre individuelle pendant la période ; ouverture et dernière semaine une fois par saison.
6. Club joué : aucun joueur de complément à la création ni au changement de saison ; effectif trop juste → alerte avant le match, espoirs sur la feuille pour ce match seulement.
7. Godot 1280×720 : textes de période et d'arrivée au 1er juillet dans les ventes et le marché, Point mercato lisible en Réception.

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
| Club géré acheteur passé sous sa réserve en payant ses indemnités à la bascule | son président intervient une fois (caisse d'avant ses paiements de la bascule) et vend aussitôt les joueurs désignés, hors arrivées : départ au 1er juillet, argent dans la caisse le jour même ; sans acheteur, l'intervention est close en « abandon » (§ 3 bis 5) |
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
| `preContrats.maxParSaison` | 3 | 2 – 5 | pré-contrats signés par le club joué par saison (freine la boucle pré-contrat puis revente) |
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
6. Pré-contrat club joué → autre club : refusé avant janvier (raison), signé avec la prime seule (budget et caisse), arrivée à la bascule avec le nouveau contrat, sans indemnité ; le 4e pré-contrat de la saison est refusé (commande et `candidates[].preContract`, même raison, rien n'est écrit).
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
