# V12 — différenciation cadres, titulaires et profondeur (candidat isolé)

## Hypothèse et méthode

Suite aux **7 808 matchs de référence V12** et à la passation #73 commentaire 6699926844, les cinq départs de cadres n'abaissaient la note des titulaires que de −0,53. Le banc comblait presque intégralement les départs : la hiérarchie individuelle ne produisait pas une conséquence de management suffisante.

`tools/rugby-real-v12/depth.cjs` construit deux variantes **sur une copie du candidat V12 existant**, jamais sur le master, jamais par accumulation V6–V11. Il établit **une seule fois avant tout mouvement** quatre catégories : cinq joueurs les plus forts parmi les titulaires initiaux par club, dix autres titulaires, huit remplaçants et rotation restante. Les feuilles sont celles du vrai `buildSheet` natif ; le statut d'un joueur ne s'améliore pas artificiellement parce qu'un cadre part. Les statuts sont des **estimations de gameplay**, pas des titularisations historiques prétendument observées. Tous les clubs, y compris ceux à postes incomplets, sont classés ; seules les équipes à feuilles 15+8 entrent dans le banc de matchs.

| Tier initial | Douce (sur spécialités de poste) | Prononcée |
|---|---:|---:|
| Cinq cadres | +4 | +7 |
| Autres titulaires | +2 | +3 |
| Huit remplaçants | −3 | −5 |
| Rotation | −5 | −8 |

Seules les cinq spécialités primaires du poste (voir `review.cjs:ROLES`) changent, bornées à 20–97, suivies de la **même projection V12** vers 11 compétences. Aucun bonus au nom, club, championnat, promotion ni ancienneté. Identifiants, poste, club, année de naissance, `rating` hérité, potentiel, six traits cachés, master et sauvegardes intacts. Les spécialistes déjà à un plafond peuvent varier de moins que le modifier nominal.

Répartition réelle des 1 592 : **150 cadres, 293 autres titulaires, 239 remplaçants, 910 rotations** (cinq clubs ont une feuille initiale incomplète). Moyenne des capacités au poste pour la variante douce par rapport à V12 : **+2,75 cadres / +1,44 titulaires / −2,18 remplaçants / −3,60 rotation**. Variante prononcée : **+4,83 / +2,20 / −3,67 / −5,80**.

## Campagne GitHub réellement exécutée

[Actions V12, job `depth-native`](https://github.com/Xynph/cadrage-debordement/actions/runs/42358101167) : **SUCCESS**, 1 920 vrais matchs, trois variantes × cinq scénarios × 64 graines × deux domiciles, même `createRugbyMatch → advanceRugby → applyMatchInjuries`. Tous les IDs de recrutements/départs figés depuis V12 initiale ; aucun moteur parallèle. Le coefficient expérimental `0,008` est toujours remplacé **uniquement dans le harness** : pas de correction moteur activée.

| Scénario — taux de victoires de l'équipe citée | V12 initiale 0,008 | Variante douce | Prononcée |
|---|---:|---:|---:|
| Promu Provence Rugby contre Toulouse | 21,09 % | **23,44 %** | 26,56 % |
| Promu contre TOP 14 médian sans recrues | 22,66 % | **21,09 %** | 20,31 % |
| Même promu après 5 recrues | 32,03 % | **28,13 %** | 28,91 % |
| Relégué Clermont conservant cinq cadres | 75,78 % | **78,91 %** | 73,44 % |
| Même relégué perdant cinq cadres | 76,56 % | **72,66 %** | 67,97 % |

**Indicateur ciblé : effet des cinq départs** : V12 précédente **+0,78 point de victoire paradoxal** et +0,63 de marge ; variante douce **−6,25 points de victoire** et **−1,92 point de marge** ; variante prononcée **−5,47 points de victoire** et **−2,01 points de marge**. La baisse de la note des quinze titulaires passe de −0,53 à **−1,73 (douce)** ou −2,60 (prononcée), sans retirer de joueur sur la feuille 15+8. La moyenne du banc baisse de −1,00 à −1,00 (douce) ou −1,25 (prononcée).

**Effet des cinq recrues** contre TOP14 médian : V12 initiale +9,37 points de victoire, +3,44 de marge ; douce **+7,04 points**, **+2,93 de marge** ; prononcée **+8,60 points**, **+2,18 de marge**. La qualité des arrivants est conservée selon leur catégorie figée dans leur club d'origine ; il n'y a ni cadeau de statut « star » au club receveur ni avantage automatique de promotion. Ces mouvements restent des cas sportifs contrôlés, sans transactions ni salaires réalistes.

**Essais, discipline et fatigue (douce)** :
- Promu vs Toulouse : **1,65 / 2,74 essais**, **5,17 / 4,89 pénalités**, fatigue **23,71 / 21,58**. Référence V12 à coefficient identique : 1,59 / 2,76 essais ; 5,20 / 5,00 pénalités ; fatigue 23,78 / 21,66.
- Relégué conservé : **3,11 / 1,80 essais**, **4,70 / 5,46 pénalités**, fatigue 23,01 / 23,36. Après cinq départs : **2,93 / 1,80 essais**, **4,87 / 5,80 pénalités**, fatigue 22,87 / 23,40.
- Le JSON brut produit par `depth-campaign.cjs` conserve également jaunes, rouges, blessures, mètres, fatigues et intervalles par graine ; les chiffres publiés ne sont pas sélectionnés en occultant les autres indicateurs.

## Choix et limites

**Candidat retenu pour l'étape d'intégration : variante douce**, pas automatiquement la plus forte. Elle conserve le promu contre Toulouse sous la cible exploratoire 25 %, préserve un intérêt aux cinq recrues et rend les pertes de cadres pénalisantes. **Prononcée non retenue pour l'instant** : promu 26,56 % contre Toulouse, tandis que les fortes dégradations de rotation nécessitent davantage de simulations de saisons/fatigue. La douce n'est pas un succès universel : le relégué reste très dominant (78,91 %) ; les taux sont sensibles aux graines et la qualité de départ est déterminée par la projection V12. Aucune preuve de taux de maintien ou remontée réelle.

Points d'intégration à vérifier par l'intégrateur unique : `lnrGamePlayers` ne consomme pas encore les 36 attributs ; `tacticalEdge` reste à 0,004 dans le moteur ; `development.js` a déjà son vieillissement, ne pas appliquer V11 en doublon ; l'échelle `rating/skillBase/dev.potential` diffère de la capacité au poste V12 ; saison 2 LNR a le défaut 15 ans décrit en #373. Les classifications sont dérivées des feuilles d'un seul instant : leur activation demanderait une politique stable sur saisons/contrats, des échanges joueur multi-club, et la gestion des blessures/formation sans reranker automatiquement les anciens remplaçants. Les postes estimés et cinq effectifs incomplets restent non corrigés. Les valeurs ne sont pas des faits biographiques.

**Pas de push main, pas de fusion, pas de modification `dist/**`, master, données d'effectifs, calendrier, sauvegardes ou MATCH 3D.** Aucun test de carrière senior à deux divisions ni de cycles multi-saisons revendiqué.
