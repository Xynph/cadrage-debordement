# Reprise choisie : départ de la partie et date de reprise du club

Décisions de Léo du 13 novembre 2026 (14h42, précisées à 14h44 et 14h45). Module moteur :
`native/engine/reprise.cjs` (domaine `reprise` de `native-systems.cjs`). Interface Godot :
`native/godot/ui/reprise_view.gd` (onglet Dossier de la Préparation), choix du départ dans
`ui/entry_screens.gd`, statut « Congés » dans l’Effectif (`ui/squad_views.gd`). Tests :
`tests/world-reprise.cjs` (carrières Monde uniquement). Mesure : `tools/reprise-mesure.cjs`.

## 1. Départ de la partie (création de carrière)

| Choix | Date de départ | Ce que le manager vit |
| --- | --- | --- |
| Reprise des premiers clubs (défaut) | lundi 13 juillet 2026 | toute la préparation : date de reprise, jeunes convoqués, amicaux |
| Reprise de ton club | date du club (réelle pour l’Élite 2026, sinon habituelle) | la date est fixée ; le groupe et les jeunes restent à décider jusqu’à la reprise |
| Veille de la 1re journée | veille du premier match officiel | préparation gérée par le staff (date habituelle, jeunes proposés), simulée |

L’écran de création envoie toujours `start` (défaut : `premiers-clubs`). Une commande
`new_career` **sans** `start` (outils, tests hérités, intégrations) ouvre la carrière comme
avant, le 17 août, sans préparation choisie ni effet de reprise : les séquences figées des
autres suites restent identiques.

Entre le départ et l’ouverture du calendrier du moteur (lundi 17 août 2026, semaine 0), la
carrière vit dans une **préparation d’avant-saison** : `meta.calendarToday` affiche la date de
juillet-août, « Jour suivant » avance d’un jour (`advance_day`), et `reprise_advance`
(`until` : `semaine`, `reprise`, `saison`) avance plus vite. Jouer, finir une semaine,
s’entraîner ou changer de saison sont refusés pendant cette période. À l’ouverture, le plan de
toute la planète est figé et chaque club reçoit ses effets à la semaine de sa première
rencontre officielle. Le départ « Veille » enchaîne les semaines sans match du club jusqu’à la
première rencontre (et, en calendrier jour par jour, jusqu’à la veille).

## 2. Dates de reprise

- **Élite 2026** (réel) : dates publiées par la LNR, « Les infos sur la pré-saison des clubs du
  Top 14 » (https://top14.lnr.fr/actualite/les-infos-sur-la-pre-saison-des-clubs-du-top-14),
  rattachées aux identifiants de club 0 à 13 du registre Monde (noms réels : pack privé).
  13/07 : 5, 7, 9 ; 15/07 : 3, 12, 13 ; 16/07 : 6 ; 20/07 : 4 ; 22/07 : 1 ; 23/07 : 2 ;
  27/07 : 0, 11 ; 28/07 : 10 ; 03/08 : 8.
- **Autres championnats** (estimé, cohérent avec leur calendrier 2026-2027) : semaines de
  préparation habituelles avant le lundi de la 1re journée ; l’habitude de chaque club est
  fixe (empreinte de son identifiant).

| Championnat | 1re journée 2026-27 | Référence (effets nuls) | Habitude des clubs |
| --- | --- | --- | --- |
| Élite | 5 sept. | 6 sem. | réel en 2026, puis même écart |
| Accession | 5 sept. | 7 sem. | 6 à 8 sem. |
| Nationale | 21-22 août | 5 sem. | 5 à 6 sem. |
| Premiership | 25-27 sept. | 9 sem. | 9 à 10 sem. |
| Championship | 18-20 sept. | 8 sem. | 8 à 9 sem. |
| URC | 25-26 sept. | 9 sem. | 8 à 10 sem. |
| League One D1/D2 | 12-13 déc. | 12 sem. | 11 à 13 sem. |
| Super Rugby Pacific | 12-13 févr. 2027 | 13 sem. | 12 à 14 sem. |

- **Saisons suivantes** : même écart à la 1re journée ; **une semaine plus tard** pour un club
  qui a disputé une finale (championnat ou coupe d’Europe) la saison précédente. Avoir
  beaucoup d’internationaux ne décale pas la date (précision de Léo, 14h45).
- **Choix du manager** : les lundis de la référence + 3 à la référence − 3 semaines avant la
  1re journée, jamais avant le départ de la partie (Élite 2026 : 13/07, 20/07, 27/07, 03/08,
  10/08), plus la date habituelle du club. La décision reste ouverte tant que la date retenue
  n’est pas passée, et en fin de saison pour la saison suivante (stockée en semaines avant la
  1re journée).

## 3. Internationaux de la tournée d’été

Correction de Léo (14h44) : **pas d’effet de moral**. Les internationaux rejoignent le groupe
plus tard, quel que soit le lundi choisi.

- Joueurs retenus : pour chaque nation, les 32 meilleurs joueurs sélectionnés (sélection et
  nombre de sélections documentés dans `player-real-facts.json`), 34 ans au plus, sans
  blessure longue.
- Retour : dernier test de l’été (Nations Championship 2026 : 18/07 ; autres nations : 11/07),
  plus **trois semaines de congés** (estimation d’un repos réglementaire crédible), au lundi
  suivant : 10/08 ou 03/08 en 2026.
- Conséquences : groupe incomplet en début de préparation (« en congés · retour le … » dans la
  Préparation et l’Effectif) ; cohésion en deux temps (automatismes en retard tant que des
  cadres manquent) ; internationaux frais (aucune charge résiduelle) mais avec leur propre
  retard de condition s’ils ont moins de semaines de préparation que la référence.

## 4. Barème (modéré, déterministe)

`e` = semaines de préparation (du lundi de reprise au lundi de la 1re journée) − référence du
championnat ; positif = reprise tôt. Pour un international, `e` part de son retour.

| Levier existant | Reprise tôt (`e` > 0) | Reprise tard (`e` < 0) | Durée |
| --- | --- | --- | --- |
| Charge physique (`physicalLoad.fatigue`) | +5 par semaine, 15 au plus (moins reposés) | — | décroît avec l’entraînement |
| Condition (`condition`) | plafond −2 par semaine (6 au plus) à partir de la semaine 30 | plafond −3 par semaine (12 au plus) | fin de saison / 4 premières semaines, décroissant |
| Blessures (`injury`) | — | +0,4 % par semaine de retard (1,6 % au plus) par match de 80 min | 4 premières semaines, décroissant |
| Préparation collective (`collectivePreparation.power`) | +2 % par semaine (6 % au plus) | −4 % par semaine (12 % au plus) ; −10 % × part des 15 meilleurs absents | 4 premières semaines, décroissant |
| Cohésion du vestiaire (`v39.cohesion`, club du manager) | 65 + moitié du pourcentage d’automatismes | idem | début de saison |
| Moral (`S.morale`, `club.morale`) | −1 par semaine (−3 au plus) | +2 par semaine (+6 au plus) | début de saison |
| Matchs amicaux | une rencontre par tranche de deux semaines de préparation (1 à 4) | idem | avant la 1re journée |
| Jeunes du centre | Espoirs puis -18 de 17 ans ; 25 à 55 min par amical, progression `growPlayer` (×0,55 du barème des matchs de jeunes) | idem | avant la 1re journée |

Clubs de l’ordinateur : même barème, à leur date ; ils convoquent autant de jeunes que
d’internationaux en congés à leur reprise (2 à 8). Le club du manager convoque jusqu’à 8 jeunes ;
sans décision, la proposition du staff s’applique. Gabi conseille une date selon la part
d’internationaux et une éventuelle finale.

Aucun tirage `Math.random` : les blessures supplémentaires et les minutes des jeunes
viennent d’empreintes (saison, semaine, rencontre, joueur).

## 5. Mesure

Voir la section « Mesure » de la PR (tableau début de saison / fin de saison, reprise tôt
13/07 contre reprise tard 10/08, club 0, graine 27), reproduite ci-dessous.

<!-- MESURE -->

## 6. Limites

- Pas de matchs amicaux joués par le moteur de match : leur nombre et le temps de jeu des jeunes
  sont simulés et versés aux systèmes existants (minutes, progression), sans score ni note.
- Le centre de formation n’a pas de moral : l’effet « moral du jeune » se limite au temps de
  jeu et à la progression visibles dans le bilan de préparation.
- Internationaux : seuls les sélectionnés documentés sont pris en compte ; les absences en cours
  de saison (Rugby Championship, Coupe du monde) relèvent du mode sélection et ne sont pas
  modélisées ici en carrière de club.
- La cohésion du vestiaire (`v39.cohesion`) est un indicateur ; l’effet sportif des
  automatismes passe par la puissance de la préparation collective, faible par construction.
