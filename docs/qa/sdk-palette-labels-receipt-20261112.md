# Palette : libellés sans identifiants techniques

Le correctif `70fe4467`, reçu après cherry-pick sur **`b349979f37f3b24f269477cfe1d2e835865ad1c5`**, retire uniquement les suffixes `[ID]` des nouveaux résultats Staff, Sélection et Compétition. Les infobulles utilisent ces mêmes libellés. Le rôle humain reste affiché pour le staff ; `kind`, `id`, `route`, sélection, dispatch et gardes restent inchangés. La recherche continue de filtrer le texte affiché, sans présenter ces identifiants techniques.

Diff produit : un fichier `native/godot/ui/navigation_controller.gd`, trois lignes remplacées (3 insertions, 3 suppressions). L'ancien suffixe joueur, préexistant à ce lot, reste une dette explicitement hors de ce correctif.

Root a reçu staging et import officiels avec sortie 0, puis les deux recettes existantes sur le nouveau contrôleur :

| Recette | Contrôles / échecs | Sous-test TAP, ms exactes | TAP total, ms exactes | Enveloppe Node, ms | Sortie |
|---|---:|---:|---:|---:|---:|
| entity-navigation | 51 / 0 | 18453.568628 | 18522.984157 | 18599 | 0 |
| navigation | 156 / 0 | 48185.113641 | 48229.81974 | 48304 | 0 |

Les journaux ne contiennent aucun `ERROR:`, `SCRIPT ERROR` ou `Parse Error`. Preuves : [entity-navigation](receipts/palette-labels-20261112/entity-navigation.log), [navigation](receipts/palette-labels-20261112/navigation.log), [résultats et SHA-256 des sources/logs](receipts/palette-labels-20261112/receipt.json).

Ces reçus ciblés vérifient les parcours existants du contrôleur et des entités. Aucune nouvelle capture de la palette présentant les trois libellés n'a été réalisée ; aucune CI globale sur `b349979f` n'est revendiquée. La campagne globale sur `76077ed3` conserve son propre SHA et sa qualification distincte.

Documentation préparée dans un worktree isolé par lecture des reçus root ; aucun SDK/import supplémentaire ni modification de la branche closeout.
