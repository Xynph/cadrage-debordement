# Compétition fictive jouable depuis l’atelier

## Conception et contraintes
Le moteur historique simule 14 clubs, 26 journées aller-retour et ses phases finales. Les autres tailles ne sont pas adaptées à ce moteur : leurs calendriers restent échangeables. Une compétition personnalisée de 14 clubs reprend effectifs, économie et règlement abstrait historiques ; seuls les noms des clubs, leurs abréviations et les paires du calendrier changent. Les couleurs, installations, budgets et niveaux initiaux restent ceux des quatorze emplacements fictifs.

La création exige une confirmation et le choix du club, refuse un match en cours et passe par la transaction atomique du worker. Elle n’édite aucune carrière en place : elle crée une nouvelle carrière qui remplace la carrière courante après l’avertissement explicite. Un marqueur `customCompetition` conserve nom, identités et calendrier. La validation refuse mode réel, identité divergente, calendrier différent ou incomplet et métadonnées inconnues. À la saison suivante, le calendrier personnalisé est réappliqué, sans changer les règles de phases finales. Les sauvegardes sans marqueur suivent exactement leurs validations antérieures.

Les packs d’identités réelles sont incompatibles avec cette compétition fictive. Les noms de carrière respectent les caractères autorisés par les sauvegardes ; les caractères de balisage réservés restent possibles dans un simple export mais empêchent son lancement jouable, avec explication.

## Plan
- [x] Ajouter tests de document14clubs, identités, calendrier et refus avant création.
- [x] Implémenter domaine strict et hook annuel ; raccorder validateur d’identité avec accord root.
- [x] Ajouter sélection du club, capacité jouable et confirmation dans l’atelier.
- [x] Réceptionner vrai worker : création, import/reprise, saison complète et saison2 ; ancienne carrière intacte après refus.
- [x] Réceptionner vrai Godot et documenter résultats/limites.


## Réception du lot

- Node22 : `tests/custom-competition.cjs` — **26 contrôles réussis** ; borne des noms80/81caractères, balisage réservé, document et état stricts, aucun effet avant confirmation.
- `tests/competition-editor.cjs` — **359 contrôles réussis**, formats2–32 conservés pour l’échange.
- Vrai worker intégré du coordinateur : `tests/custom-competition-worker.cjs` — **3 tests réussis** en45s. Création14clubs avec journées1/2 échangées, confirmation, refus de formats/noms/imports invalides, ancienne carrière inchangée, match en cours protégé,26journées =182rencontres régulières distinctes puis phases finales, saison2, import et reprise de processus exacts. Le test initial a nécessité les vraies promotions de couverture après blessures et la confirmation de saison suivante : aucun assouplissement des règles du jeu.
- Le premier test a été reçu à nouveau après le raccord titre/présentation du coordinateur : nom de compétition et nom personnalisé affiché identiques à la carrière.
- `tests/custom-competition-web.cjs` — **réussi** avec le harness web, sans domaine natif ni hook installé : saison complète, saison2, calendrier et noms conservés, sauvegarde/reprise ; ancienne fiction sans marqueur garde son calendrier historique. Le test a d’abord reproduit la réinitialisation du calendrier ; la correction core est limitée à l’affectation annuelle de `S.schedule` dans `dist/game.js`.
- Godot4.7.2 Linux headless, vrai main et worker intégrés sur staging jetable : **50 contrôles réussis**, rapport `/tmp/cd-calendar-ui-NLOem4/report.json`, journal `/tmp/deepen-editor-ui3.log`. Parcours réel Packs, génération/aperçu, erreurs et import malformé, export/réimport disque, modèle jouable14clubs, choix du4eclub, annulation conservant le brouillon et le disque, confirmation créant une carrière puis Bureau, nom visuel personnalisé et réimport de l’état. Géométrie1280×720 et1920×1080 conservée.
- La recette UI distingue l’état sauvegardé du champ `exportedAt`, qui avance légitimement après une commande d’import avec horloge réelle. Aucune date figée n’a été ajoutée au produit.
- Un P1 de projection a été reproduit : `model.club.name` était personnalisé mais `presentation.name` reprenait l’ancien emplacement. Le coordinateur a corrigé `native/engine/model.cjs` pour projeter le club personnalisé ; l’assertion du vrai helper visuel `G.club_name` passe ensuite.

## Interfaces et limites finales

Le coordinateur manifeste `customCompetition` dans `native-systems.cjs` et traite `new_career` avec `mode:'custom'` via `nativeSystems.domain('customCompetition').create(nativePayload)`. Il projette le nom de compétition et la présentation personnalisée sans modifier la carrière.

Seul le format14clubs aller-retour est lançable. Les budgets, effectifs, couleurs, règles historiques et phases finales sont conservés ; la création ne simule pas une nouvelle ligue officielle, ni promotions/relégations. Une nouvelle carrière remplace explicitement la carrière courante après confirmation ; l’utilisateur est invité à exporter l’ancienne pour la conserver. Les autres calendriers restent éditables et échangeables. Pas de validation Windows ni de CI complète revendiquée par ce sous-lot ; la réception commune appartient au coordinateur.
