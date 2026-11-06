# Rugby Réel 2026-2027 — audit indépendant des 36 attributs

## Périmètre
Audit **en lecture seule** de `modding/data06/rugby-master-2026-2027.json` : 1 592 joueurs attendus et 36 champs dans `attributesV2`. Aucune note, identité, effectif, calendrier, sauvegarde, interface ou moteur modifié. Ne pas fusionner cet audit avec l'ancienne PR #361 (11 attributs, annulée).

## Exécution
```sh
node tools/rugby-real-attributes36-audit.cjs > /tmp/rugby-real-attributes36-report.json
node --test tests/rugby-real-attributes36-audit.cjs
```
La sortie JSON contient les distributions par attribut (minimum, déciles, médiane, moyenne, dispersion), les groupes poste/championnat lorsque les métadonnées sont présentes sur la fiche, les vecteurs strictement identiques et les corrélations extrêmes (|r| ≥ 0,95). Les valeurs de notes sont des **estimations de gameplay**, non des statistiques observées.

## Contrôles et limites
- Schéma attendu : 1 592 fiches avec `attributesV2`, 36 clés, valeurs numériques de 20 à 97 et IDs sans doublons.
- Les formats de potentiel et traits cachés doivent être confrontés à la base réelle ; leur absence n'est pas remplacée par une valeur inventée.
- Une corrélation forte n'est pas, à elle seule, une erreur ; elle signale une revue rugby et statistique.
- La méthode n'établit pas la qualité réelle des joueurs. Pour recalibrer individuellement : observations et statistiques **datées avant le 1er juillet 2026**, pondérations par poste, incertitudes et revue manuelle stratifiée.
- Les notes de Rugby 25 ne sont pas copiées : aucun droit de réutilisation ni équivalence méthodologique supposés.
- Avant un futur raccordement au jeu, étudier séparément l'adaptateur des 36 attributs vers les 11 compétences du moteur, les écarts par poste, les tests sportifs et la compatibilité des sauvegardes.

## Gouvernance
PR DRAFT isolée ; seul l'intégrateur unique peut faire progresser le gate officiel. Aucune fusion ou bypass.
