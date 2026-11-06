# Rugby Réel — V10 : montée TOP14 difficile, descente PRO D2 favorable

## Décision game design : écart de niveau **accentué**
La demande n'est pas de donner des statistiques artificielles à un joueur parce que son club change de division. **Un promu monte avec son effectif de PRO D2** : il affronte des effectifs TOP 14 plus forts et doit recruter intelligemment. **Un relégué conserve les compétences acquises en TOP 14**, sans malus automatique : s'il garde ses cadres, il est compétitif pour une remontée rapide. Les finances, départs de joueurs, blessures, fatigue, forme et autres mécaniques continuent de compter, sans garantie de descente ni de remontée.

À qualité et poste comparables, le TOP14 doit dominer en moyenne, **mais des stars de Pro D2 peuvent dépasser des remplaçants de Top14**. Les notes sont fixées à la date initiale **01/07/2026**, et un joueur ne reçoit **jamais** un bonus instantané de division lors d'une montée.

## Mesure existante et cible candidate
En V7, les 11 familles de poste avaient un écart TOP14 - PROD2 de **3,53 à 5,71 points** sur cinq compétences prioritaires. Nous testons une **cible de design à +7 points par poste** sur ce même score (pas une estimation historique de vérité). Pour la cohorte TOP14 initiale uniquement, proposer un ajustement modéré (cap de +5 par compétence) vers cette cible, sans retirer de points aux joueurs PRO D2. Les rôles qui n'atteignent pas +7 malgré le plafond restent signalés. Une telle hausse pourrait être trop forte pour le gameplay ; **ceci est un réglage candidat, pas une règle validée**.

## Scénarios de test à valider dans le moteur réel
1. Même groupe de joueurs de PRO D2 promu sans recrutement : mesurer ses résultats contre les formations de TOP14 ; la montée doit faire chuter sensiblement son taux de victoire à cause de l'opposition.
2. Même groupe TOP14 relégué avec effectif constant : mesurer son taux de victoire contre les équipes PRO D2 ; il doit avoir une vraie avance moyenne.
3. Variantes avec 2 à 5 recrues qualitatives, départ de 2 à 5 cadres, budget, blessés et usure : éviter la descente automatique et la remontée garantie.
4. Vérifier différences saison 1 puis saison 2, recrutements réalistes, objectifs de direction, sauvegardes, cohérence des classements.
5. **Ne pas afficher de pourcentages de victoires non mesurés par le moteur de match.** Les moyennes de notes de l'audit sont seulement des proxys de force sportive.

## Données et collecte
Les PR #368 et #370 ont fourni de vrais relevés LNR saison 2025-2026 (classements joueurs et temps de jeu), à conserver comme données observées. Les détails plaquages, mêlées et temps de jeu PRO D2 ne sont pas librement disponibles dans les pages publiques examinées. La V10 n'invente aucune statistique et ne prétend pas augmenter la collecte au-delà de la V9. **Il est interdit d'empiler automatiquement V6 + V8 + V9 + V10 : toutes les corrections doivent être consolidées par identité/attribut sur une seule version de calibration**, avec préférence aux observations et sans double comptage.

## Commandes
\`\`\`sh
node --test tests/rugby-real-promotion-tier-v10.cjs
node tools/rugby-real-promotion-tier-v10.cjs modding/data06/rugby-master-2026-2027.json /tmp/rugby-real-v10-candidates.json
\`\`\`

Le rapport contient les 1592 IDs, les cinq notes proposées par poste le cas échéant, les écarts par ligue avant/après et l'effet qualitatif attendu pour la montée/descente. Candidats JSON externes non chargés par le jeu ; aucune modification des joueurs, effectifs, sauvegardes, calendrier, MATCH3D ou moteur. L'intégration est un chantier distinct à valider par simulations sur le vrai moteur, pas par la seule réussite des tests du proxy.
