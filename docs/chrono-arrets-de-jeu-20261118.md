# Chrono des arrêts de jeu (18/11/2026)

Carrière Monde uniquement. Rencontres créées avec `chronoVersion: 1` ; les matchs commencés avant gardent leurs règles.

## Constat

Dans le moteur complet, une action de jeu valait une minute de chrono quoi qu'il arrive. Une pénalité tentée au but
et un essai transformé ne consommaient qu'une minute avant l'action suivante (mesure de référence : 1 min 00 dans les
deux cas sur 600 matchs de Top 14). Mené de 8 en fin de match, prendre les trois points ne mangeait donc pas de temps à
l'adversaire, qui remarquait le plus souvent : taper au but ne valait pas mieux que la pénaltouche (bonus défensif
0,30 contre 0,32 à la 72e, 0,34 contre 0,31 à la 60e).

## Durées retenues (vérifiées le 18/11/2026, voir `docs/rugby-rules-reference.md`)

| Arrêt | Loi / règlement | Temps compté par le moteur |
| --- | --- | --- |
| Pénalité tentée au but | Loi 8.21 : 60 s ; Top 14 2026-2027 : 45 s | 10 s (annonce, ballon posé) + délai + 25 s (renvoi ou remise en jeu) : 80 s en Top 14, 95 s ailleurs |
| Essai et transformation | Loi 8.8c : 60 s (90 s jusqu'en 2024) ; Top 14 : 45 s | 15 s (essai accordé, buteur en place) + délai + 25 s (renvoi) : 85 s en Top 14, 100 s ailleurs |
| Pénaltouche | Loi 18.12 : alignement en 30 s | 30 s (coup de pied en touche, alignement formé) |
| Action de jeu | — | 45 s de match (calée : même nombre d'actions par match qu'avant) |

Les chiffres de la demande (60 s et 90 s, soit ≈ 2 min et 2 min 30) datent de 2023 : la transformation est passée à
60 s en 2025 et la LNR impose 45 s en Top 14 dès 2026-2027, la saison de la carrière. Pro D2 n'est pas vérifié et reste
à 60 s. Les mêlées et touches ordinaires restent comprises dans la durée moyenne d'une action.

## Fonctionnement

- Le chrono compte en secondes : chaque action dure `CHRONO.action` (45 s) et les arrêts y ajoutent leur temps
  (`CHRONO` dans `dist/matchflow.js`). Une minute de match compte zéro, une ou deux actions ; l'horloge affichée
  avance toujours d'une minute par minute (écran 2D et résultat inchangés dans leur forme).
- Le renvoi après des points (et le renvoi aux 22 après un tir manqué mort) se joue au début de l'action suivante, au
  moment dû. S'il tombe après la fin du temps réglementaire, la période se termine (loi 5) : une pénalité réussie à
  la 79e ne laisse plus de renvoi.
- Le staff (consigne « auto » du club du manager, IA experte) prend les trois points à partir de la 72e quand
  l'équipe est menée d'un peu plus que l'écart du bonus défensif (Top 14 : −6 à −8).
- Aucun tirage ajouté ; la séquence des tirages d'une action est celle d'avant.
- Statistiques : possession et territoire comptés par action (les pourcentages ne changent pas de sens) ; l'usage
  des plans (`planUsage.minutes`) compte les actions observées.

## Mesures

`node scripts/mesure-chrono-arrets.cjs` (en ligne : `bash ci/en-ligne.sh --ref <ref> --suites mesure-chrono-arrets`),
600 matchs de Top 14 (vrais effectifs), 4 × 200 matchs de styles (XV identiques), 2 × 150 matchs de courbe de niveau,
400 fins de match par consigne ; `bash ci/mesure-monde.sh` (10 saisons Monde, 14 250 matchs).

RESULTATS
