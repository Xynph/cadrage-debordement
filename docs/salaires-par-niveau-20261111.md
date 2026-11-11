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

## Ce qui bloque : les recettes et les charges

Mesuré avec la première version du module : un club de deuxième division
gagne déjà environ 200 000 € par semaine, salaires payés, et davantage avec
des salaires réalistes. Le jeu ne compte que les joueurs comme charge.

Budget d'un vrai club, 2024-2025 : les joueurs pèsent 27 % des charges en
première division et 28 % en deuxième ; s'y ajoutent staff, administratifs,
cotisations (15 à 18 %), achats et services. Recettes moyennes : 33 M€ et
10,7 M€. C'est ce modèle qu'il faut reproduire avant d'activer le module.

Non mesuré : une saison entière, l'intersaison, les prolongations, les
offres d'un club pour attirer un joueur.

## Tests

`node --test tests/starting-salaries.cjs` : 7 sur 7 (référence, politique
des clubs, variété, contrats espoirs, application unique, vrai moteur drapeau
éteint puis allumé).
