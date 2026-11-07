# Premium PC — reprise P3 du 7 novembre 2026

## Résultat

Même branche et PR #372, depuis le HEAD P2 `167b6723fd9d44286e16d974316748dacf221574`. Réservation #73 commentaire 6699868628. Atelier fictif isolé : Bureau, Effectif, Tactiques, Recrutement. Aucun changement du jeu de production.

- Stade photographique propre sans faux texte, 1672×941 ; recadrage supérieur vérifié pour conserver les têtes à 1920 et 1440.
- Neuf visages photographiques fictifs distincts en atlas 1254×1254 (418×418 par personne). Maximum dossier 390 px : aucune miniature 54×72 agrandie. Même indice dans liste et dossier.
- Attributs propres aux six joueurs sélectionnés ; état de recherche sans résultat avec remise à zéro et focus ; bouton Préparer la rencontre au clavier vers Tactiques et focus sur le n°10.
- Feuilles de styles partagées entre l'application et les stories via PremiumApp ; anciens assets P2 conservés.

## Vérifications exécutées

- TypeScript : PASS ; Vite : PASS sur la dernière modification CSS.
- Trois nouveaux parcours observés RED sur le code P2 (bouton inactif, absence d'état vide, mauvais portrait), puis GREEN 3/3.
- Exécution locale complète de 22 cas : **20 PASS, 2 échecs lors de la création du contexte navigateur**, avant l'exécution des tests de définition des images (`Browser.setDownloadBehavior: Failed to find browser context`). Ce n'est pas une suite complète verte.
- Reprise ciblée, séquentielle, avec le cadrage final : **6/6 PASS** (Bureau, Recrutement et définition/usage des photographies, chacun aux deux résolutions). Les deux tests non démarrés ci-dessus ont ainsi effectivement été exécutés avec succès.
- Huit vues PC capturées ; dimensions et absence de débordement global contrôlées dans les tests (1440×900 et 1920×1080). Inspection visuelle réelle des quatre pages et des variantes de taille. Cadrage du stade repris après première inspection.
- Storybook local : **non qualifié**, restriction de l'environnement `uv_interface_addresses` lors de l'import du serveur. Construction distante requise via le workflow existant.
- Revue indépendante du diff : aucun défaut Critical/Important ; remarque mineure suivie, fichier généré `tsconfig.app.tsbuildinfo` exclu de la publication.

Le Chromium système ne démarrait pas (socket Unix interdit), et le téléchargement officiel Playwright a fourni une archive invalide. La validation locale utilise un navigateur headless temporaire extérieur au dépôt ; aucun contournement, shim ou changement du workflow du projet. Le workflow GitHub utilise son Chromium officiel. **Réception CI du nouveau HEAD obligatoire ; résultats définitifs à consigner dans la PR et #73.**

## Empreintes des nouveaux assets

| Asset | Octets | SHA256 |
| --- | ---: | --- |
| players-atlas-p3.webp | 218006 | `2dfdca229c32a5d5bb604a33a629eb3670fcc1802b2df79f3d15f50755fadad5` |
| stadium-night-p3.webp | 218202 | `72f28c436287536c1cf1c20205d987f2f85b63993cc11ddacfae88e491162f21` |

## Limites conservées

Les statistiques sont des fixtures, les visages sont fictifs, aucun raccord moteur. Penpot ne répond plus car aucune instance n'est connectée : ses pré-maquettes P1 sont décrites par la passation 6698325202, pas synchronisées dans cette reprise. Variantes de composants, typographie finale et qualification accessibilité complète restent à réaliser. PR DRAFT ; pas de READY, gate ni fusion. Finances V2, DATA, MATCH 3D et sauvegardes préservés. Journal de reprise limité à ces documents pour préserver les réservations des autres chantiers.
