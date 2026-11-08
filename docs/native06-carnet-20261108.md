# Carnet personnel du coach — natif0.6

Le carnet conserve une intention générale de carrière et des notes libres par joueur. Les notes appartiennent à cette carrière : elles suivent le coach après un changement de club et voyagent dans l'export/import. Une nouvelle carrière, même dans le même club, démarre sans les anciennes notes.

La fenêtre `coach_notes_view.gd` s'ouvre depuis les raccordements du Bureau et des fiches joueurs. Elle utilise un sélecteur de dossier et un éditeur borné, sans nouveau menu principal. **Enregistrer** est explicite ; **Annuler la saisie** restaure le texte enregistré sans commande. Un changement de dossier est bloqué tant que la saisie n'est pas enregistrée ou annulée. La suppression demande confirmation. Un refus du moteur laisse le brouillon dans la fenêtre ; seul un reçu correspondant à la commande et à son texte permet d'afficher le succès.

Les noms et postes sont résolus depuis le monde actuel, puis le pack d'identités sélectionné. Le texte personnel reste littéral, y compris les noms que le coach y a écrits. Aucun nom de pack n'est stocké séparément dans l'annotation. Un joueur sorti du monde reste accessible par sa note, avec la mention **Dossier indisponible** et sans identité inventée. Sa note peut toujours être modifiée ou supprimée.

## Limites et stockage

Le carnet accepte jusqu'à100notes, chacune de1à2000points Unicode. Le compteur suit ces points ; certains émojis composés peuvent en compter plusieurs. Les textes blancs seuls, les contrôles autres que LF/TAB et les surrogates isolés sont refusés. Le texte est affiché en clair, sans interprétation HTML ou BBCode.

Le domaine optionnel de sauvegarde est :

```js
coachNotebook: {
  version: 1,
  entries: [{target, textCodes, season, week, club}]
}
```

`target` désigne `career` ou un ID joueur stable. `textCodes` contient les points Unicode entiers. Les commandes reçoivent le texte brut et la projection le décode ; cet encodage permet d'utiliser les sauvegardes strictes existantes sans modifier leur validation générale. Chaque entier reste compté par `safeTree`.

Les maximums du carnet restent soumis aux plafonds globaux de la carrière, qui ne sont pas relevés. Une carrière proche de son budget peut donc refuser une note bien formée ; la transaction conserve alors la carrière, le RNG et le fichier antérieurs, et le brouillon reste visible. Une fixture historique de16923nœuds a accepté100notes de1000points ;100notes de2000points dépassaient son plafond de200000nœuds et ont été refusées. Une autre fixture à199926nœuds a aussi refusé atomiquement l'allongement d'une seule note. Ces mesures décrivent les fixtures testées, pas une capacité garantie pour toute carrière.

Les anciens imports sans carnet restent compatibles. Aucun carnet n'est créé par la simple consultation. Les annotations ne modifient ni joueurs, ni finances, ni règles sportives et ne consomment aucun hasard.

## Interface moteur

```js
coach_note_save({context: {season, week, club}, target, text})
coach_note_remove({context: {season, week, club}, target, confirmed: true})
```

Le contexte doit correspondre exactement à l'état courant. Une nouvelle note joueur exige un dossier existant ; une annotation déjà conservée reste éditable après sa disparition. Le schéma est fermé, unique par cible et strictement daté.

`clubLife.coachNotebook` fournit le contexte, les maximums, les cibles consultables et les entrées décodées. `meta.coachNote={command,target,context}` est le reçu de l'opération. La fenêtre vérifie aussi le texte retourné ou l'absence effective après suppression, et ignore les autres snapshots. Les signaux sont déconnectés à sa libération.

Les suites `native-coach-notes06*.cjs` couvrent le domaine, les vrais imports/transactions et un pack synthétique sans données privées. Les suites `godot-coach-notes06*.cjs/gd` vérifient le popup isolé puis l'application et le worker réels en mode headless, dont le refus disque et le réessai. La réception visuelle du véritable EXE et des boutons raccordés reste à effectuer par l'intégrateur.
