# V4.8 Premium PC — pilotage et centres natifs

Date : 1er novembre 2026. Base GitHub : `main 25dadbe1dce21a3a1352c69af84258acf2e23309`. Branche : `integration/v48-premium-pc-20261101`.

## Diagnostic et périmètre

Le code et les tests V4.7.1 de `main` ainsi que le rapport de réception `docs/decision-studio-v47.md` ont été étudiés. Le dernier artefact de captures Chromium de référence est `premium-v4-browser-report` #13086282462, run #41312957377. Ce lot n'affirme **pas** avoir ouvert ni comparé visuellement l'intégralité des PNG de ce ZIP dans le présent environnement ; ses observations de base sont tirées du rapport Chromium V4.7.1 déjà publié et du DOM/CSS actuel. Le test Playwright V4.8 fournit une nouvelle série de 16 captures réelles à contrôler après exécution de la CI.

Problèmes ergonomiques ciblés :
- **Tableau de bord** : bandeau déjà photographique, mais plusieurs niveaux concurrents et KPI dont les libellés/nombres manquent de rythme ; décisions et rencontres sont encore peu différenciées.
- **Centres natifs** `.cd02`, `.cd03`, `.cd04` : en-têtes de préparation construits avec le même visuel, mais sans hiérarchie photographique/données homogène et avec des KPI plus discrets que les vues V4.7.
- **Navigation et intégrité** : garder les onglets et commandes toujours visibles, sans accordéon, sans scroll global réintroduit, sans modification de logique ou de sauvegarde.

## Livraison CSS

Dans `dist/premium-v4.css`, exclusivement au-dessus de 1200 px :
1. Tableau de bord : composition photographique et typographie de titre resserrée, vraie grille de quatre KPI aux valeurs tabulaires et avec des libellés plus lisibles ; cartes de décisions avec priorité des urgences, messages non lus et fixtures plus reconnaissables.
2. Centres natifs : en-têtes photographie/gradient, bordure cuivrée, typographie adaptée et KPI plus équilibrés sur les modules déjà présents. Les valeurs métiers sont conservées.
3. Focus clavier sur contrôles des centres ; prévention des débordements dans les surfaces de texte.

## Recette à vérifier

`tests/premium-v4-browser.py` ajoute **16 captures natives** : tableau de bord / équipe / tactiques / plans × Analyste / Tribune × 1440×900 / 1920×1080. Le navigateur recrée une carrière fictive, conserve les tests préexistants et réaffiche chaque écran : contrôles d'absence de dépassement horizontal, navigation native, KPI visibles, scène de tableau de bord, en-têtes éventuels et invariants `JSON.stringify(S)` + clé de stockage `bdt-v1` lors du `render()`.

Ces assertions vérifient la stabilité fonctionnelle en navigateur mais ne remplacent pas une inspection humaine des nouvelles images. Aucune donnée de championnat/trophée/budget n'est inventée. Les appels d'export/import ou des actions modifiant l'état ne sont pas déclenchés par le test visuel. Aucune validation Windows native, tactile ou lecteur d'écran revendiquée.

## Concurrence

La PR #187 LNR réserve `tests/lnr05-multiseason-strategies.cjs` et `.github/workflows/lnr05-evidence-browser.yml`. Aucun changement dans ces fichiers, dans DATA-06, Business, `dist/opposition.js`, moteur, sauvegardes, menu cinématique ou workflows CI. `DEVELOPPEMENT.md` n'est pas modifié afin de limiter les collisions ; passation publiée dans l'issue #73.

**Fusion interdite avant autorisation explicite.** Les conclusions de CI, l'examen des captures V4.8 et le statut exact de la PR doivent être consignés après exécution, sans anticiper les résultats.
