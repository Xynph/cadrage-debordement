# Atelier de calendrier fictif — 9 novembre 2026

## Intention et conception
Depuis la page Packs, créer un calendrier tous contre tous (2–32 clubs), en aller simple ou aller-retour, le modifier en JSON, le contrôler et l'échanger localement. Un nombre impair de clubs produit des journées de repos. Identifiants stables distincts des noms affichés ; aucune identité ou compétition officielle n'est réécrite.

L'alternative d'étendre les packs d'identités est écartée : leur contrat actuel ne transporte pas de calendrier. Le module pur propose génération et validation ; une commande worker consultative hors transaction retourne le document vérifié. L'interface conserve son brouillon et ses erreurs. Export JSON dans un fichier choisi explicitement, remplacement atomique existant ; import limité à 1 Mio. Le document ne lance pas encore une carrière personnalisée : cette limite est annoncée dans l'interface et dans l'export.

## Plan
- [x] Tester couverture complète des paires, alternance aller-retour, repos, conflits, entrées malformées et absence de mutation.
- [x] Implémenter module pur et projection bornée, sans état ni hasard.
- [x] Brancher atelier Godot depuis Packs : édition des clubs, génération, import/export et aperçu.
- [x] Vérifier Node et chargement réel Godot ; transmettre hooks worker au coordinateur.

## Vérifications
- Node22 : `node tests/competition-editor.cjs` — **359 contrôles réussis** sur 2–32 clubs pairs et impairs, aller simple et retour, erreurs et absence de mutation.
- Vrai worker raccordé du coordinateur : `node --test tests/competition-editor-worker.cjs` — **2 tests réussis**, avant création et pendant une carrière ; export, disque, RNG/horloge et reprise inchangés.
- Godot4.7.2 Linux headless : script `tests/godot-competition-editor.gd` reçu sur staging jetable avec le vrai main et le vrai worker du coordinateur — **31 contrôles réussis**, 1280×720 et 1920×1080 ; génération, aperçu, refus conservé, import JSON malformé, correction, export atomique puis réimport disque.
- Runner reproductible : `CD_GODOT_EXECUTABLE=/chemin/godot node --test tests/godot-competition-editor.cjs` après staging habituel. Avant intégration, `CD_EDITOR_PROJECT_BASE` et `CD_EDITOR_WORKER` permettent de prendre les hooks du coordinateur.
- Premier harness de recette : profil placé par erreur dans son applicationRoot, justement refusé. Le runner corrigé place le profil à côté de l’application jetable. Le premier test UI a trouvé un vrai défaut d’invalidation : le setter TextEdit.text n’émet pas text_changed. La validation et l’import invalident maintenant explicitement l’ancien export ; une régression réelle couvre l’import malformé.
- L’ordre JSON est canonicalisé pour conserver un export stable après passage par les dictionnaires Godot. Aucun changement de sauvegarde ou de règle rugby. Pas de réception Windows ni de CI complète revendiquée dans ce lot.

## Raccord coordinateur
`worker.cjs` requiert `competition-editor.cjs`, autorise `competition_editor_preview`, puis traite cette commande avant l’exigence de carrière et avant toute transaction : `const model=snapshot(); model.competitionEditor=competitionEditor.project(payload); return {id,ok:true,model};`.
`main.gd` préserve le dialogue `CompetitionEditorDialog` sur succès et refus, comme EPCR. Les signaux bridge y appellent `_on_model` et `_on_failure`. Aucun domaine natif ni champ de sauvegarde à ajouter. Le bouton se trouve dans `pack_views.gd`.

## Limites
Le calendrier est une ressource de préparation et d’échange locale, pas une nouvelle compétition jouable. Aucun barème, classement, promotion/relégation, effectif ou rencontre d’une carrière n’est modifié. La création de carrière à partir de ce format nécessite un chantier ultérieur contrôlé.
