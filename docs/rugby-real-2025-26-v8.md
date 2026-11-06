# Rugby Réel — collecte effective 2025-2026 et candidats V8

Ce lot est **indépendant** des PR #363/#364/#366, ne modifie pas le master ni le jeu. Il conserve la date de carrière **01/07/2026**, les identifiants, les 36 notes actuelles, les six traits cachés et le potentiel.

## Données réellement recueillies

Le fichier \`data/scouting/performance-2025-26-v8.json\` contient des **lignes de classement** de la saison historique 2025-2026 extraites des pages LNR, **pas l'effectif complet de la compétition** :
- PRO D2 : 20 meilleurs réalisateurs + 20 meilleurs marqueurs d'essais + 20 meilleurs taux de transformation
- TOP 14 : 20 meilleurs réalisateurs + 20 meilleurs marqueurs d'essais

Les noms et valeurs sont conservés sous forme de petits relevés regroupés par **page**, sans dossier individuel de justificatifs. Les personnes qui apparaissent dans plusieurs classements sont dédupliquées par identifiant de profil LNR et saison. Ces valeurs sont des mesures publiées (points, essais, minutes, matches, taux de transformations et tentatives) et restent distinctes des notes de jeu.

## Rapprochement avec la base maîtresse

1. Harmoniser casse, accents et ponctuation des noms.
2. Ne rapprocher qu'un **nom réel unique** dans les 1 592 fiches. Les homonymes et identités absentes restent explicitement non rapprochés.
3. Conserver séparément club historique et club de début 2026-2027 : les mutations entre saisons sont possibles. La compétition de performance 2025-2026 n'est jamais attribuée par simple supposition à partir de celle de 2026-2027.
4. Ne pas considérer les 1 568 profils sans \`performance2025_2026\` comme statistiquement nuls. Les non classés dans les 20 premiers sont **inconnus**, pas mauvais.
5. Si la fiche a déjà des observations V4/V5, ne pas cumuler de corrections de note sur les mêmes données. Seuls les autres profils peuvent recevoir des propositions.

## Estimation de gameplay, non donnée réelle

Les essais/rencontre et les minutes de temps de jeu sont des **indicateurs indirects**, pas des mesures de vitesse, de précision technique ou de mental. Le calcul propose, avec limites modestes, +1 à +2 sur \`ballCarry\` et parfois +1 \`evasion\` pour les profils concernés, et +1 \`workRate\` au-dessus de 1 500 minutes (simple proxy de sélection). Une réussite d'au moins 82 % sur au moins 25 transformations tentées peut proposer +1 en \`goalAccuracy\` pour les buteurs des postes correspondants. Aucun malus pour une absence du classement. Pas de dégradation automatique de la PRO D2. Aucun bonus par seule appartenance TOP 14. Toutes les variations sont marquées \`gameplay-estimate\`, et **ne sont pas appliquées** dans le fichier maître.

Le programme vérifie que la moyenne des cinq spécialités de chaque poste garde l'avantage TOP 14, déjà démontré dans #366. Une inversion échoue immédiatement. Ce contrôle ne remplace pas une campagne de simulations et de recrutement.

## Exécuter
\`\`\`sh
node --test tests/rugby-real-2025-26-v8.cjs
node tools/rugby-real-2025-26-v8.cjs modding/data06/rugby-master-2026-2027.json data/scouting/performance-2025-26-v8.json /tmp/rugby-real-v8-candidates.json
\`\`\`

La sortie exploitable regroupe les 1592 joueurs, les observations associées et les \`changes\` candidats éventuels ; elle est déposée comme artefact Actions. Aucun \`dist/**\`, sauvegarde, calendrier, DATA maîtresse, finances, MATCH3D ou CI gate ne change.
