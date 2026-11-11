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

## Ce que fait `native/engine/starting-salaries.cjs`

À la création d'une carrière seulement, quand `CD_SALAIRES_PAR_NIVEAU=1` :

1. chaque club reçoit une masse annuelle selon sa division et sa force
   (`base` du catalogue des clubs) : 9,9 M€ en moyenne en première division,
   3,2 M€ en deuxième, avec les écarts ci-dessus ;
2. la masse est répartie entre les joueurs selon leur niveau, avec une
   variation de ±6 % par joueur.

Les carrières existantes ne sont pas touchées. Sans la variable, le jeu est
inchangé.

| Mesure, club 29, graine 27 | Avant | Après |
| --- | --- | --- |
| Corrélation salaire et niveau, 1 596 joueurs | −0,01 | 0,88 |
| Toulouse : joueur noté 96 / noté 68, par semaine | 4 160 € / 8 780 € | 15 720 € / 3 760 € |
| Toulouse : indemnité du joueur noté 96 / noté 68 | 220 000 € / 300 000 € | 810 000 € / 130 000 € |
| Masse annuelle, première division | 12,3 M€ | 9,9 M€ (6,3 à 13,9) |
| Masse annuelle, deuxième division | 10,7 M€ | 3,2 M€ (1,4 à 4,9) |

## Ce qui bloque : les recettes

Les recettes du jeu ne sont pas réglées sur les salaires. Six semaines jouées
avec Valence (deuxième division, 2,3 M€ en caisse au départ) :

| | Avant | Après |
| --- | --- | --- |
| Trésorerie après six matchs | 3,52 M€ | 4,37 M€ |
| Gain cumulé (« Journée ») | +1,22 M€ | +2,07 M€ |

Même aujourd'hui, le club gagne environ 200 000 € par semaine, salaires
payés : près de 7 M€ sur une saison pour une caisse de 2,3 M€. Baisser les
salaires de deuxième division aggrave cet excédent. Activer ce module sans
régler les recettes rendrait tous les clubs riches.

Décision à prendre par Léo, avant toute activation :

- **Ajouter des charges de fonctionnement** (staff, déplacements, centre de
  formation, stade). Dans la réalité les joueurs pèsent environ un quart du
  budget d'un club. Recommandé : c'est aussi ce qui donne un sens aux
  projets d'infrastructure.
- Ou **baisser les recettes** pour qu'elles couvrent juste les salaires.

Non mesuré : une saison entière, l'intersaison, les prolongations, les clubs
gérés par le jeu, les offres aux joueurs libres.

## Tests

`node --test tests/starting-salaries.cjs` : 4 sur 4 (masses, répartition,
vrai moteur drapeau éteint puis allumé).
