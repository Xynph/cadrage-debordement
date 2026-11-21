# Reprise : lot phrases 3 (Club, Formation, Vestiaire > Entretiens)

Branche `claude/phrases-lot3`, worktree `E:\Cadrage-Debordement\worktrees\phrases-lot3`. Pas de PR.

## Fait
- `native/godot/ui/immersive08/pastilles_club.gd` (nouveau) : `pastille()`, `tuile()` (option `en_ligne`, `action` => vrai Button qui change d'ecran), `info()` (« i » / « ? » en infobulle), `poser()`, `poser_a_droite()`, `euros_courts()`, palette (VERT, ORANGE, ROUGE, BLEU, VIOLET, TURQUOISE).
- Club (club_canvas.gd) : vue d'ensemble (bandeau stade en 3 tuiles, pastille 1er bilan, jalon en pastille Sem. N, devis en tuile, textes d'aide retires, « changer d'onglet » retire), Infrastructures (tuiles, pastille « 1 par saison », « i »), Histoire (pastilles d'etats vides, « i » rangs) + performance_analysis_view.gd (titres avec « i », pastilles).
- Formation (academy_canvas.gd) : tuiles contrat (salaire / fin), pastilles pepite / a trancher / blessure, pied « 19 / 60 » + etoile + « i » + « ? ».
- Vestiaire > Entretiens (relationships_view.gd, carnet_skin.gd `chapter(..., bulle)`, locker_canvas.gd) : slogan retire, pastille de contexte (Fin 2027...), effets en mini-pastilles ▲/▼, tuiles satisf./condition/min, blessure en pastilles, regle de promesse en pastilles + « i », « Aucun engagement » / « Aucune decision ».
- Destinations (cliquables) : 1er bilan et jalon -> Direction ; devis -> Infrastructures ; « Tresorerie insuffisante » et tuile cout -> Finances ; tuiles stade -> Club > Le stade ; tuiles contrat Formation -> fiche du jeune ; « Aucun titre » -> Classements ; contexte / tuiles / blessure Vestiaire -> fiche joueur. Le reste est neutre non cliquable.
- visite.gd : ecrans de capture `club-infrastructures`, `club-histoire`, `vestiaire-entretiens`, `vestiaire-historique`.
- Tests : `tests/godot-phrases-lot3.gd/.cjs` (clique chaque tuile/pastille, imprime les destinations) PASS ; godot-club-da (mêmes 2 rouges « or » que main), godot-ecran-club (adapte, PASS), godot-formation-da PASS.

## Reste
- Relire les captures apres derniers correctifs (Histoire : titres avec « i » ; stade : « Voir le stade » a droite ; Vestiaire : sous-titre remonte) dans `E:\Cadrage-Debordement\temp\lots-phrases\lot3\`.
- Verifier `native-relationships-ui.cjs` (timeout meme sur main) : bouton cliquable >= 30 px de haut deja corrige.
- Vestiaire > Historique et Cette semaine : relire la capture.
- `git merge origin/main`, `git diff origin/main`, PR (titre FR, fin « 🤖 Generated with [Claude Code](https://claude.com/claude-code) »), `gh pr merge <n> --auto --squash`.
- Choix ouverts : pastilles d'etat vide neutres (gris) car sans destination ; pastilles ▲/▼ des effets de reponse colorees mais non cliquables.

## Commandes / pieges
- Captures : `powershell -NoProfile -ExecutionPolicy Bypass -File E:\Cadrage-Debordement\temp\lots-phrases\lot3-capt.ps1 -Sortie <dossier> -Ecrans club,club-infrastructures,...` (attend un Godot libre jusqu'a 3000 s).
- Tests via `E:\Cadrage-Debordement\temp\godot-slot.ps1 -Dossier <wt> -Commande "node tests/<suite>.cjs"`.
- Rouges deja presents sur main : godot-club-life-strategy, godot-academy-portraits, godot-club-da (2 « or »), native-relationships-ui (timeout).
- Piege : legacy_style recolore les controles ; les miens portent la meta `immersive_style_applied`. Pas de `Skin` comme nom de constante (masque une classe native).
- Worktree `E:\Cadrage-Debordement\worktrees\base-lot3` (main detache) cree pour comparer : a supprimer.
