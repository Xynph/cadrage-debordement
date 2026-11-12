# Graphique financier : ouvrir l’écriture représentée

Base : `8ad4b0239e70931f3d49672a2dc9b959fbb8e8f8` (lot commun #576).
Branche : `cloud/rg27-night-ledger-links-20261111`.

## Inventaire et choix

Le graphique existant affiche douze écritures au plus, de la plus ancienne
à gauche à la plus récente à droite. Ses barres montrent le montant des
opérations et sa ligne leur cumul net. Les libellés n° 1 à 12 suivent l’ordre
inverse, identique au journal : n° 1 est la plus récente.

Les reçus publiés par le moteur (`club-strategy.cjs`, fonction `receipt`, et
la projection `model.cjs`) conservent un titre et un montant. Ils ne possèdent
ni identifiant comptable stable ni date. Ce lot ne modifie pas ce format et
n’invente aucune date ou référence dans les écrans.

Chaque colonne du graphique reçoit un bouton transparent, accessible par Tab
puis Entrée/Espace, qui ouvre l’onglet Trésorerie à la page exacte du journal.
La ligne correspondante est surlignée avec les couleurs et composants existants,
et son libellé reçoit le focus. Le clic couvre la barre et le point de cumul
représentés dans cette même colonne ; le dessin et les calculs restent inchangés.

Le locator interne `ledger:<empreinte SHA256 de la projection ordonnée>:<index>`
distingue aussi deux écritures identiques dans le même journal. Il est limité
à cette projection de lecture. Une insertion, suppression, correction ou un
réordonnancement invalide le lien. Le contrôleur commun refuse alors l’ouverture,
sans choisir une autre occurrence. Aucun identifiant de métier n’est créé.

## Contrat et périmètre

- Cible commune : `{kind:"finance", id:locator}`.
- `FinanceCanvas.ledger_locator(entries,index)` produit le locator d’une
  écriture correctement projetée ; `ledger_index(app,locator)` le résout
  uniquement dans la projection courante.
- `target_available/open_target` conservent leurs anciens onglets et acceptent
  cette cible de lecture supplémentaire.
- Boutons : `FinanceChartOperation_0` à `_11`, métadonnées `entity_kind`,
  `entity_id`, `ledger_index`.
- Ligne : `FinanceLedgerSelection`, libellé focus `FinanceLedgerTarget` avec
  métadonnées `ledger_index` et copie de l’écriture déjà publiée.

Fichier produit unique : `native/godot/ui/immersive08/finance_canvas.gd`.
Fonctions touchées : nouvelles fonctions de lookup, `target_available`,
`open_target`, `_chart`, appels depuis `_summary` et `_cash`, et `_ledger`.
Les fonctions économiques et les fonctions de présentation réservées à #552
(`_weekly`, `_due`, `_footer`, `_season_budget`, `_budget`) restent intactes.

## Préparation historique de la recette (11 novembre 2026)

Statut de préparation conservé ci-dessous. La réception ultérieure de 40
contrôles sans échec est consignée dans l’[inventaire de nuit](night-links-inventory-20261112.md),
ligne « Barre ou point financier ». Cette note ne lui attribue pas de nouveau
SHA ni de nouvelle capture ; les fixtures d’empreinte restent synthétiques.

`tests/godot-finance-ledger-links.cjs` lance le vrai SDK et importe la carrière
S2 déjà conservée dans `tests/fixtures/roster-foundation-v1-s2.json.gz`, comme
la recette Gestion Carnet existante. Les cent écritures de cette sauvegarde
servent de source réelle, sans ajouter d’opérations synthétiques au worker.

Le scénario vérifie la dixième écriture au clavier (page 2), un clic sur la
première barre, un clic sur le deuxième point, le titre et montant exacts,
la restauration de l’onglet/focus au retour, et l’absence de commande sportive,
d’écriture de sauvegarde ou de consommation de RNG pendant la consultation.
Les checks d’empreinte et d’occurrences identiques utilisent séparément une
projection synthétique ; ils ne sont pas présentés comme des opérations réelles.
Les signaux de parole de Gabi doivent rester à zéro, audio Dummy.

Exécution graphique optionnelle avec `CD_LEDGER_GRAPHICS=1` et sortie
`CD_LEDGER_OUTPUT` pour une capture native 2560×1440 de la ligne de page 2.
Aucun résultat ni capture n’est revendiqué avant exécution. Le SDK attendra
la fin de la recette commune déjà en cours et prendra le verrou partagé.
