# Mission internationale — réception progressive

Échéance : 9 novembre 2026, 07 h 30 Europe/Paris. Stabilisation à 07 h 15.
Branche de travail : `feature/world-europe-20261109`, base `a7f5bbbe`.
Objectif persistant actif. Les états ci-dessous décrivent des preuves, pas des pourcentages.

## Sous-projet A — registre commun et identités privées

1. Préserver les 1 592 objets français de l’édition existante et leurs IDs.
2. Collecter tous les clubs anglais et URC, puis les invités européens.
3. Compiler une édition indépendante : 58 clubs, 56 clubs domestiques jouables.
4. Séparer les faits documentés des estimations de conception ; isoler les contradictions.
5. Vérifier doublons, postes, qualifications, niveaux, potentiels et rattachements de médias.
6. Produire le pack privé avec les mêmes IDs ; ne jamais écrire ses noms dans les sauvegardes.

| Périmètre | Préparé / collecté | Intégré | Testé | Reste |
|---|---|---|---|---|
| France, 30 clubs | 1 592 profils et 428 staffs | Élite/Accession dans le Monde ; édition France conservée | Objets France identiques, saisons et accession jouées dans le moteur | Réception Windows 0.7 |
| Angleterre, 10 clubs | 637 joueurs, 98 staffs ; conflits documentés | PREM, calendrier et finales | Parcours natif, trois saisons initiales, calibrage budgétaire comparé | Réception Windows 0.7 |
| URC, 16 clubs | 888 joueurs, 258 staffs | URC, 144 dates publiées et phases finales | Feuilles, calendrier, match natif et saisons complètes | Réception Windows et texte détaillé 2026/27 |
| Invités, 2 clubs | 91 joueurs, 24 staffs | Cheetahs et Black Lion en Challenge | Rencontres, titre invité et qualification suivante exercés | Réception Windows 0.7 |
| Registre international | 3 208 joueurs, 808 staffs | Mode `world` additif | Saison 791 matchs et passage à la suivante ; import, reprise et refus de falsifications | Publication, CI et installation |

Les quantités de collecte sont des candidats à vérifier ; elles ne constituent pas un compte de photos affichées dans l’EXE. Les fichiers sources et les médias privés restent sous `E:/Cadrage-Debordement/artefacts/database-europe-20261108` et `references/database-europe-20261108`.

## Sous-projet B — compétitions et carrière

1. Écrire et vérifier les règles par compétition, avec leur édition exacte.
2. Générer quatre calendriers domestiques et les deux coupes dans une seule saison.
3. Utiliser le moteur rugby existant pour les matches humains et IA.
4. Recevoir phases finales, promotions françaises, qualifications européennes annuelles et intersaison.
5. Vérifier les départages, la progression des joueurs et les comptes séparés par compétition.

Le module pur vérifie les formats 14/26, 16/30, 10/18 et URC 16/18, dont les 9 réceptions/9 déplacements URC. Les textes LNR, PREM et EPCR 2026/27 sont référencés. Les dates, le format et les priorités européennes URC sont confirmés par leurs sources ; les détails encore issus du règlement 2025/26 restent signalés. Les dates générées sont marquées comme calendrier de jeu. Les 318 rencontres sourcées comprennent 90 PREM, 144 URC et 84 de poules européennes. Une rencontre PREM a été déplacée d’un jour pour la cadence de simulation ; sa date publiée est conservée en référence.

Une saison complète et son intersaison sont reçues dans le moteur. La première campagne longue en PREM a parcouru 2 373 matchs en trois saisons. Elle a mis en évidence les départs liés à la trésorerie avant le financement annuel. Les salaires fictifs PREM ont été recalibrés ; la comparaison de la première saison passe de six à deux clubs en trésorerie négative sans modifier ses 791 scores. L’allocation d’intersaison est disponible avant les renouvellements des clubs IA et n’est versée qu’une fois.

## Sous-projet C — sauvegardes, packs et Windows

1. Garder les modes historiques 14/30, marqueurs et limites inchangés.
2. Valider strictement la nouvelle édition, ses identités, résultats et contextes de match.
3. Mesurer les sauvegardes initiales, après saison et après intersaison ; adapter seulement les bornes de la nouvelle édition si nécessaire.
4. Refuser les packs d’une autre édition sans mutation ; tester changement de pack et reprise.
5. Construire et recevoir un vrai export Windows hors ligne, avec captures 1440p et replis.
6. Passer la chaîne PR, CI, gate officiel et validation post-fusion avant installation.

La sauvegarde de fin de première saison dépasse légèrement 8 Mio. La limite monde de 16 Mio est reçue par le moteur, avec limites historiques de 8 Mio conservées. Le pack international complet comporte 58 logos, 3 103 portraits officiels et 105 illustrations de joueurs, 678 portraits officiels et 130 illustrations de staff. Son installation et le changement de présentation sans changement de progression sont reçus sur profil jetable. La réception de l'EXE et l'installation utilisateur restent des étapes séparées.

## Coordination et critères de réception

Un producteur écrit un chemin à la fois. Le parent est l’intégrateur Git unique. Les réservations et le contrat UI sont publiés dans l’issue 73. L’autre conversation conserve l’exclusivité de la refonte immersive des écrans ; ce lot lui fournit des catalogues, compétitions et calendriers dynamiques.

Chaque lot doit distinguer : préparé, intégré dans le code, testé dans le moteur, reçu dans l’EXE exporté, publié et installé. À l’échéance, seul le statut effectivement prouvé sera rapporté.
