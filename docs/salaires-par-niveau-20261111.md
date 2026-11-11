# Salaires de départ liés au niveau

Relevé du 11 novembre 2026 sur `fe79c365` (#539). Suite du constat P1 de
`docs/audit-priorites-cloud-20261111.md` (#549). **Éteint par défaut** : ce
chantier n'est pas prêt à être activé, voir « Ce qui bloque ».

## Le défaut

Le salaire de départ d'un joueur sort d'une empreinte de son identifiant
(`dist/lnr-career.js:54`). Il ne dépend ni de son niveau ni de son club, et
l'indemnité de transfert en découle.

## Les masses salariales du jeu sont fictives

Le jeu paie 34 semaines par saison.

| | Jeu aujourd'hui | Réel, 2024-2025 |
| --- | --- | --- |
| Première division, moyenne par club | 12,3 M€ (11,2 à 14,2) | 9,9 M€, écart de 1 à 2,2 |
| Deuxième division, moyenne par club | 10,7 M€ (8,1 à 13,3) | 3,2 M€, écart de 1 à 3,4 |
| Ce qui fait varier la masse d'un club | Le nombre de joueurs (corrélation 0,97) | — |

Source des chiffres réels : rapport 2026 sur l'économie des clubs de Top 14
et de Pro D2, première moitié lue. Décision de Léo : fictives, donc à adapter.

## Ce que fait `native/engine/starting-salaries.cjs` (version 2)

Décision de Léo du 11 novembre : pas de barème unique. C'est un jeu, il faut
des joueurs sous-payés et des joueurs surpayés, et des clubs qui ne paient
pas tous pareil. Les salaires se paient sur l'année entière.

À la création d'une carrière seulement, quand `CD_SALAIRES_PAR_NIVEAU=1`, le
salaire annuel d'un joueur est une valeur de référence selon son niveau,
multipliée par quatre facteurs :

| Facteur | Effet | D'où il vient |
| --- | --- | --- |
| Poste | 0,84 (talonneur, ailier) à 1,14 (deuxième ligne) | Salaires réels par poste, 2023-2024 |
| Politique du club | 0,8 à 1,3 : un club fort paie plus, chaque club a son tempérament | Choix de jeu |
| Âge | 0,62 à 21 ans, 1,04 de 26 à 30 ans, 1,12 de 31 à 33 ans | Choix de jeu |
| Histoire du joueur | 0,55 à 1,8 : bien ou mal négocié, signé avant de progresser ou de décliner | Choix de jeu |

Référence : 26 000 € à 60 de niveau, 78 000 € à 70, 155 000 € à 75,
255 000 € à 80, 520 000 € à 90. Plancher 14 000 €, plafond 800 000 €.

| Mesure, graine 27 | Avant | Après |
| --- | --- | --- |
| Lien entre salaire et niveau, 1 596 joueurs | −0,01 | 0,84 en première division, 0,78 en deuxième |
| Joueurs de niveau 75 (73 joueurs) | — | de 59 000 à 283 000 € |
| Masse annuelle, première division | 12,3 M€ sur 34 semaines | 8,9 M€ (7,1 à 12,5) ; réel 9,9 |
| Masse annuelle, deuxième division | 10,7 M€ sur 34 semaines | 3,0 M€ (2,2 à 4,4) ; réel 3,2 |
| Salaire moyen, première division | — | 155 000 € ; réel 259 000 € sur des effectifs plus courts |
| Moins de 60 000 € en première division | — | 19 % ; réel 27 % |
| Plus de 480 000 € en première division | — | 3,6 % ; réel 4 % |

### Version 3 : les contrats espoirs

La version 2 donnait 155 000 € de salaire moyen en première division contre
259 000 € dans la réalité. Cause : chaque club de première division compte
dans le jeu une vingtaine de joueurs de 21 ans ou moins, notés 70 en
moyenne, payés comme des professionnels installés. Le chiffre réel porte sur
520 professionnels, soit 37 par club.

Correction : dans chaque club, hors des 34 meilleurs, un joueur de 22 ans ou
moins a un contrat espoir (18 000 à 46 000 € en première division, 14 000 à
30 000 € en deuxième). La référence des professionnels est relevée de 20 %.

| Mesure, graine 27 | Version 3 | Réel |
| --- | --- | --- |
| Première division, masse moyenne | 10,0 M€ (8,2 à 13,3) | 9,9 M€ |
| Première division, moyenne des 37 mieux payés par club | 242 000 € | 259 000 € |
| Première division, les autres (21 par club) | 52 000 € | — |
| Deuxième division, masse moyenne | 3,5 M€ (2,6 à 5,2) | 3,2 M€ |
| Deuxième division, moyenne des 34 mieux payés par club | 90 000 € | — |

Le moteur compte encore les salaires à la semaine et n'en paie que 34 par
saison : le module écrit l'année divisée par 52. **Le paiement sur 52
semaines reste à faire dans le moteur**, avec le budget.

## Budget du club : `native/engine/club-budget.cjs`

Pour les carrières créées avec ces salaires (marque `startingSalaries`), le
calcul hebdomadaire des finances suit les comptes réels 2024-2025. Les autres
carrières gardent l'ancien calcul.

| | Première division | Deuxième division |
| --- | --- | --- |
| Recettes annuelles visées, moyenne | 33 M€ | 10,7 M€ |
| Partenaires / ligue / billetterie / boutique / divers | 45 / 19 / 16 / 8 / 12 % | 48 / 22 / 8 / 4 / 18 % |
| Salaires des joueurs | dus sur 52 semaines, payés sur les semaines de compétition | idem |
| Cotisations | 40 % des salaires | idem |
| Staff et fonctionnement | 58 % des recettes | idem |

Un club moyen qui paie la masse moyenne de sa division finit la saison près
de l'équilibre (test : à moins de 8 % des recettes).

### Une saison jouée, Valence (deuxième division), graine 27

| Trésorerie | Ancienne économie | Nouvelle économie |
| --- | --- | --- |
| Départ | 2,30 M€ | 2,30 M€ |
| Après 17 matchs | 7,00 M€ | 2,77 M€ |
| Après 31 matchs | 6,63 M€ | 2,37 M€ |

Le versement de 2,5 M€ de fin de saison, identique pour tous les clubs,
n'est pas compté ici : la simulation s'arrête avant l'intersaison.

### Trois problèmes ouverts

1. **Les clubs gérés par le jeu s'enrichissent** avec la nouvelle économie :
   Toulouse finit à 10,7 M€ en caisse contre 5,1 M€, Montauban à 12,5 M€
   contre 4,7 M€. Leur trésorerie suit un autre calcul, que je n'ai pas
   identifié. À régler avant toute activation.
2. **Plus de billetterie en seconde moitié de saison**, dans les deux
   économies : après le 17e match, la trésorerie ne monte plus les semaines
   de réception. Soit un défaut du jeu, soit un artefact de ma sonde. À
   confirmer.
3. La prévision « salaires de la saison » de l'écran Finances multiplie
   encore par 34 semaines.

### Comment les vrais clubs vivent, et ce qu'il faut au jeu

En 2024-2025, 9 clubs de première division sur 14 et 14 de deuxième sur 16
sont en déficit d'exploitation (63 M€ au total). Les actionnaires couvrent :
prêts abandonnés, augmentations de capital. Seuls 7 clubs sur 30
s'autofinancent. Un jeu où tous les clubs perdent de l'argent serait pénible
(remarque de Léo). Propositions, non codées :

1. un club moyen à l'équilibre par défaut (fait) ;
2. un soutien du propriétaire annoncé en début de saison, variable selon le
   club (mécène, entreprise, association), à la place du versement uniforme
   de 2,5 M€ ; au-delà de l'enveloppe : pression, vente forcée, renvoi ;
3. des recettes liées au terrain : prime de classement, phases finales,
   affluence selon les résultats ;
4. les leviers du manager (ventes, partenaires, infrastructures) ;
5. les deux règles de la ligue comme contraintes : plafond salarial et 52 %
   des recettes au plus pour les joueurs.

Non mesuré : l'intersaison, les prolongations, les offres d'un club pour
attirer un joueur, la première division jouée par le manager.

## Tests

`node --test tests/starting-salaries.cjs` : 11 sur 11 avec `tests/club-budget.cjs` (référence, politique
des clubs, variété, contrats espoirs, application unique, vrai moteur drapeau
éteint puis allumé).
