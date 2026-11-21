# État de reprise : Finances « Solde sur 12 mois » (branche claude/finances-solde-12-mois)

## Contexte
- Demande de Léo : remplacer, en bas de la Synthèse Finances, « Les 12 derniers mouvements » par « Solde sur 12 mois » :
  un point par mois (solde de fin de mois), courbe bien visible + barres de variation du mois (vert entrées / rouge sorties),
  mois en abscisse (« sept. », « oct. »…), mois en cours marqué, mois disponibles seulement (rien d'inventé),
  chaque point/barre cliquable (onglet Trésorerie, ou petite fenêtre visuelle des mouvements du mois si `petite_fenetre.gd` est fusionné), « i » à jour.
- Ajout validé par Léo (même PR) : sous la barre des 3 paliers du panneau « Verdict de la semaine », deux pastilles :
  marge hebdomadaire (« ▼ −15,6 k€ / sem. », rouge si négative, verte si positive → clic : onglet Budget) et autonomie de trésorerie
  (« tient N semaines », icône clock, couleur selon le palier → clic : onglet Trésorerie). Autonomie = trésorerie / perte hebdo, plafonnée aux semaines restantes de la saison.
- #1090 (phrases lot 2, auto-merge activée) n'était pas fusionnée : le Godot Finances (finance_canvas.gd, petites_pieces.gd) en dépend.
  Godot 4/5 était rouge sur #1090 au dernier contrôle (journal non lu : run 44894530309) : à regarder en premier.

## Fait (commité en wip, moteur seulement)
- native/engine/club-budget.cjs : `soldeReleve()` enregistre {date, saison, cash} par semaine jouée dans `S.cashHistory` (70 relevés max, dédoublonné par date).
- native/engine/world-career.cjs : appel de `soldeReleve()` après `worldWeeklyEconomy(results)` dans la clôture de semaine.
- native/engine/model.cjs : `finance.cashHistory` exposé au Godot.
- Le registre `S.ledger` n'a ni date ni mois et est limité à 100 lignes : le solde par mois ne peut pas en être déduit, d'où le nouvel historique.

## Reste à faire
1. Attendre/vérifier #1090 fusionnée, puis `git merge origin/main` dans cette branche (conflits possibles : aucun attendu côté moteur).
2. Vérifier côté moteur : tests JS touchant le modèle `finance` / sauvegardes (clés inconnues acceptées ?), `node tests/<suite>.cjs` ; une carrière Monde jouée doit remplir `cashHistory` (vérifier calendarToday).
3. finance_canvas.gd : agréger `finance.cashHistory` par mois (dernier relevé du mois = solde de fin de mois ; variation = solde − solde du mois précédent, rien pour le premier mois), remplacer `_chart` de la Synthèse (titre « Solde sur 12 mois », LedgerPlot adapté, mois en abscisse, mois en cours marqué, clic → onglet Trésorerie `_ouvrir_onglet(app,"cash")` ou filtre du mois). Garder l'onglet Trésorerie (`_cash`) qui réutilise `_chart` : ne casser ni lui ni les tests (`tests/godot-finances-ecran.gd` lit FinanceLedgerPlot / FinanceChartOperation_*, `tests/godot-finance-ledger-links.gd`).
4. Deux pastilles dans `_verdict_panneau` (Pieces.pastille avec action, voir petites_pieces.gd ; ajouter le clic dans le test PREFIXES de godot-finances-ecran.gd).
5. Adapter les suites qui lisaient « 12 derniers mouvements », capture 1920 dans E:\Cadrage-Debordement\temp\lots-phrases\finances-solde\ (la regarder), PR prête + `gh pr merge <n> --auto --squash`.

## Commandes utiles
- Préparer : `python scripts/build-godot-prototype.py --stage-only --node E:\Cadrage-Debordement\outils\node.exe` puis import `--headless --editor --import` (via godot-slot.ps1).
- Suites : godot-finances-ecran, godot-finance-ledger-links, godot-coherence-chiffres, godot-budget-transferts, godot-recrutement-da.
- Captures sans l'attente « un seul Godot » : copier scripts/ecrans-filmes.ps1 en retirant la ligne `Wait-GodotSeul` (jamais commiter la copie), `-Ecrans finances -Tailles 1920x1080 -SansPlanche -SansDirect`.

## Pièges
- Les ratés de largeur de texte : estimer avec C.BODY (DM Sans), pas C.font(600).
- Regex GDScript : doubler les antislashs ; ne pas utiliser sed sur des `\S`/`\d`.
- `git checkout -- native/godot/art/office_props/ballon.glb.import` avant commit ; jamais de git stash.
