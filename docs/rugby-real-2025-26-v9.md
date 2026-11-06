# Rugby Réel — extension DATA V9 : avants, participation, discipline (2025-2026)

Objectif : compléter la collecte V8 par des données du **TOP 14 et de PRO D2 avant le 1er juillet 2026**, sans toucher aux 1592 fiches ni aux 36 attributs du fichier maître.

## Mesures réellement collectées
- 20 premiers joueurs du classement LNR **temps de jeu TOP 14** : minutes, matches.
- 20 premiers joueurs du classement LNR **nombre de cartons TOP 14** : cartons jaune/orange/rouge, matchs, minutes.
- 20 premiers joueurs du classement LNR **nombre de cartons PRO D2** : idem.

Le classement de temps de jeu PRO D2 est référencé dans les statistiques officielles, mais sa page ne retourne pas de tableau exploitable sans connexion dans les essais réalisés. Les listes individuelles de plaquages, rucks, touches et mêlées ne sont pas librement accessibles dans les pages consultées. **Aucune de ces performances n'est fabriquée**. Le jeu bénéficie de la donnée disponible pour des avants et joueurs moins présents dans les classements d'essais, mais la couverture est limitée aux top-20 publiés.

Les 60 lignes sont regroupées par page dans \`data/scouting/performance-2025-26-v9.json\`. Le champ \`v8KnownKeys\` liste uniquement les identifiants LNR déjà présents dans la collecte V8, permettant de distinguer les joueurs déjà vus ; pas de duplication des 100 lignes de V8.

## Rapprochement et règles de gameplay
- Associer au fichier maître par **nom réel unique normalisé**, pas par position dans les listes ; conserver le club historique publié, même si le joueur a changé de club.
- Une ligne de classement avec carton est une observation de discipline, **pas une preuve de mauvaise technique, ni de niveau mental** ; aucun bonus ou malus de \`discipline\` attribué automatiquement.
- Si un joueur **nouveau par rapport à V8**, sans performance individuelle déjà exploitée dans V4/V5, dispose de >=1800 minutes et >=20 matches joués en 2025-2026, suggérer **+1 en \`workRate\`** en tant qu'**estimation de gameplay sur la participation** ; cela ne constitue pas une mesure directe de ses capacités physiques ni de sa valeur rugbystique.
- Joueurs absents des TOP20 : inconnus, pas nuls. Joueurs PRO D2 jamais diminués mécaniquement.
- Conserver le **TOP 14 supérieur en moyenne** sur les cinq spécialités de chaque poste, sans déclarer qu'un joueur PRO D2 est forcément moins bon qu'un joueur TOP14.

Le résultat \`candidates\` couvre les 1592 IDs, avec champ \`changes\` vide par défaut. Il ne remplace pas les notes existantes ni les traits cachés et potentiels, et reste non jouable tant qu'un raccordement séparé n'a pas été testé.

## Exécution
\`\`\`sh
node --test tests/rugby-real-2025-26-v9.cjs
node tools/rugby-real-2025-26-v9.cjs modding/data06/rugby-master-2026-2027.json data/scouting/performance-2025-26-v9.json /tmp/rugby-real-v9-candidates.json
\`\`\`
Un workflow GitHub Actions dédié valide 1592 fiches, la déduplication, le non-double-comptage, la stabilité de la BDD maître et la hiérarchie sportive, puis archive le JSON candidat hors du dépôt principal.
