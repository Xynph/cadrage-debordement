# Rugby Réel V7 — hiérarchie sportive TOP 14 / PRO D2

Le **TOP 14 est supérieur à la PRO D2 en moyenne**, mais un grand joueur de Pro D2 peut dépasser un remplaçant de Top 14. Ne jamais imposer un ordre fixe joueur par joueur ni confondre note de jeu et résultat mesuré.

## Objet du lot
Calculer à partir des **36 attributs V2 actuels** les niveaux de référence par poste (11 groupes) et championnat, puis proposer, seulement si nécessaire, un **bonus collectif conservateur** sur 5 attributs essentiels au TOP 14 afin d'approcher un écart de **3 points sur le score de spécialité**, à valider par simulations. Il ne s'agit pas d'une mesure scientifique de l'écart réel. Le résultat est un fichier candidat JSON séparé. Les profils PRO D2 ne sont jamais abaissés ; les joueurs TOP 14 déjà correctement meilleurs ne sont pas sur-améliorés. Une limite de +3 points par attribut évite des corrections brutales ; une cible non atteinte est explicitement indiquée au lieu de forcer des valeurs hors bornes.

Aucune réécriture du fichier maître, des effectifs, du potentiel, des 6 traits cachés, du calendrier, du moteur ou des sauvegardes. Les résultats 2026-2027 après le 1er juillet 2026 ne sont pas utilisés.

## Collecte statistique
La base DATA existante comprend déjà 24 joueurs avec une observation 2025-2026 et 1 568 sans performance individuelle enregistrée ; le lot V7 conserve ces états et produit le nombre réel observé directement depuis le master. **Aucune collecte additionnelle n'est revendiquée dans cette version.** Pour accroître cette couverture, importer les classements joueurs 2025-2026 (minutes, matchs, essais et jeu au pied lorsqu'ils existent) et faire correspondre le joueur sur identité et club de la saison mesurée, pas son club 2026-2027. Une statistique sans rattachement fiable reste non attribuée.

## Exécuter
\`\`\`sh
node --test tests/rugby-real-league-hierarchy-v7.cjs
node tools/rugby-real-league-hierarchy-v7.cjs modding/data06/rugby-master-2026-2027.json /tmp/rugby-real-v7-league-candidates.json
\`\`\`
Le workflow dédié teste le schéma, la hiérarchie, l'absence de changement PRO D2, le SHA256 du master et archive les candidats pour révision. L'outil ne produit que des propositions de notes et ne les charge pas dans le jeu.

**Revue avant toute application** : mesurer l'écart par poste, la dispersion interne et les exceptions individuelles, contrôler que le bonus ne double pas un différentiel déjà présent dans V2-V5, puis tester le comportement sportif, l'adaptateur 36→11 et la compatibilité de sauvegarde sur une PR distincte.
