# Rugby Réel — candidats V6, profils individuels différenciés par poste

## Objectif
À partir des 1 592 fiches déjà présentes dans la base maîtresse 2026-2027, produire un fichier de **propositions de recalibrage**, sans modifier ni les 36 attributs ni les 6 traits cachés, le potentiel, les identifiants ou les clubs. Aucun fichier de données maîtresses, moteur, sauvegarde ou calendrier ne change dans cette PR.

## Approche simplifiée
L'utilisateur privilégie la crédibilité sportive et ne demande pas 1 592 fiches sourcées individuellement. Les notes proposées restent donc **estimations de jeu**, pas statistiques réelles. Les performances 2025-2026 déjà contenues dans le modèle V4/V5 servent d'indicateur de couverture ; elles ne sont **pas ajoutées une deuxième fois** aux notes existantes.

Par groupe \`championnat + poste estimé\`, les quatre compétences principales sont comparées aux quartiles du groupe. Un attribut au-dessus du troisième quartile reçoit une **proposition** de +2, un attribut sous le premier quartile une **proposition** de -1, les autres restent inchangés. Maximum 4 modifications candidates par joueur, aucune donnée d'entrée modifiée, pas de changement de trait caché ou potentiel. Ce renforcement léger de profils préexistants n'est **pas** une évaluation de performances réellement observées ; il devra être revu avant toute application.

Les performances collectées ultérieurement devront être celles d'avant le 1er juillet 2026. Une source globale de collecte est suffisante pour le pilotage éditorial, mais toute valeur présentée comme réelle doit rester vérifiable. Ne pas recopier les notes propriétaires Rugby 25. Attention : les postes de gameplay sont estimés pour la majorité des joueurs et ne constituent pas une qualification réglementaire.

## Commandes
\`\`\`sh
node --test tests/rugby-real-role-calibration-v6.cjs
node tools/rugby-real-role-calibration-v6.cjs modding/data06/rugby-master-2026-2027.json /tmp/rugby-real-v6-candidates.json
\`\`\`
Sortie : candidats individuels ID + poste + attribut + valeur précédente + proposition + indicateur \`model-estimate\`. Par défaut, le CLI n'affiche qu'un résumé agrégé. Les suggestions sont **non jouables** et ne sont jamais chargées par le moteur sans décision et tests distincts.

## Suite
Évaluer distributions avant/après par famille de poste, revue de spécialistes, absence de survalorisation artificielle et impact du potentiel/âge. Compléter l'observation sportive 2025-2026 quand disponible (les 1 568 profils sans statistique individuelle renseignée restent des estimations) ; vérifier séparément la compatibilité 36→11 et les sauvegardes avant d'envisager une intégration.
