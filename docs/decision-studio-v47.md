# V4.7 Premium PC — Mercato, Palmarès et Sauvegardes

**Date** : 1er novembre 2026. **Référence** : `main b53603ee20e73f68853b27bae7c8cb6701f52182`. Branche `integration/v47-premium-career-hub-20261101`. Périmètre : uniquement CSS de présentation, tests Chromium, documentation, 1440×900 et 1920×1080, thèmes Analyste/Tribune.

## Audit réellement exécuté

Archive de référence `premium-v4-browser-report` #13084600844, téléchargée et inspectée. La V4.7 a ensuite publié une première phase de collecte par Chromium sur la PR #182, artefact #13085215156, **12 captures d'avant changement** et `v47-dom-audit.json` inspectés. L'inventaire DOM de 1440×900 Analyste confirme :

- **Mercato** : environ 2 986 px de contenu dans `.main`, 4 indicateurs, 44 px de barre d'onglets, diagnostic de 661 px, neuf cartes de joueurs dans un marché de 1 181 px, puis autres panneaux. Priorité : lecture progressive et espace exploité en 1920.
- **Palmarès** : environ 744 px de contenu seulement, deux petits panneaux d'archives 222 et 125 px, sans résultats encore enregistrés. Priorité : occupation PC digne d'une carrière débutante sans inventer de titres ni d'événements.
- **Sauvegardes** : environ 893 px, export/import + secours/conseils en deux colonnes, quatre cartes, mais sans distinction forte de l'action principale et du filet de secours. Priorité : transparence des actions, sauvegarde native conservée.
- Baseline sans débordement horizontal aux deux résolutions et deux thèmes.

## Changements éditoriaux V4.7

1. **Mercato** : scène de recrutement graphique (sans fausses données), KPI typographiquement renforcés, onglets natifs cibles d'au moins 44 px, diagnostic principal mis en avant, grille de cartes joueurs en 3 colonnes à 1440 et 4 à 1920 avec respiration et priorité aux contrôles. Les filtres/contrats/transactions n'ont pas été modifiés.
2. **Palmarès** : nouvel en-tête de carrière, deux panneaux d'archives occupant les deux colonnes du PC, surfaces et marqueurs décoratifs, sans faux trophées. Les entrées futures demeurent nativement présentes.
3. **Sauvegardes** : export avant import et secours visuellement distincts, boutons natifs et états disabled conservés, zones de clic 44 px, focus clavier visible et conseils de conservation mieux mis en page. Les fonctions `exportCareer`, `openImportPicker`, `reviewBackup`, `exportBackup` ne sont pas appelées par les tests visuels et ne sont pas modifiées.

## Non-régression et limites

Le navigateur produit les 12 captures initiales et **12 captures après stylisation** (24 au total, sur les mêmes routes), contrôle l'existence des vrais filtres / liens / boutons, la géométrie, `JSON.stringify(S)` et le stockage `bdt-v1` avant/après chaque route, les écrans V4 antérieurs, la pause du match, les ressources HTTP et l'absence de débordement.

Aucun fichier `dist/saves.js`, moteur rugby, DATA-06, Business ou collecteur payé n'est touché. Les captures et tests ne certifient pas Windows natif, Safari ni lecteur d'écran. **Aucune fusion sans autorisation expresse.**
