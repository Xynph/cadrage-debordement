# Liens de consultation : compétitions, rencontres, calendrier et finances

Base de travail : `6648cd6338e1eb62cc4a8c014b23dd3ec20ba174`, lot commun #572.
Branche : `cloud/rg27-night-world-links-20261111`. Dépend de `entity_link.gd`
et du contrat commun `navigation_controller.open_entity` fourni séparément.

## Inventaire et raccord

| Information | Existant constaté | Raccord de ce lot | Limite |
| --- | --- | --- | --- |
| Club du classement | Bouton de ligne ouvrant un dialogue local | Identifiant stable et garde commune ; même dialogue réutilisé depuis tout écran | Catalogue ne fournit que l’identité et les faits publics |
| Clubs du prochain match | Noms et blasons statiques | Nom et blason ouvrent le détail précis | Aucune préparation ni prise de poste déclenchée |
| Rencontre du calendrier tabulaire | Ligne ouvrant le dialogue local | ID exact, score conservé ; adversaire et compétition ont leur destination propre | ID absent/ambigu refusé |
| Rencontre historique conservée | Dialogue résultat, pas d’accès commun | `history.fixtureId` et `pair` résolus ; statistiques conservées présentées | Pas de reconstruction des anciennes saisons absentes ou des statistiques manquantes |
| Date publiée d’une rencontre | Texte | Calendrier ciblé sur date validée, filtre et vue conservés | Une ancienne rencontre sans date ne reçoit pas de date inventée |
| Rencontre du détail journalier | Score et adversaire statiques | Score→rencontre ; nom et blason→club | Les jours de grille restent des sélecteurs de date |
| Compétition des rencontres | Libellé | Classement de `league.id` correspondant | Pas de lien si cette compétition ne possède aucun classement publié |
| Tuiles Trésorerie/Masse salariale/Marge | Valeurs statiques | Onglets Trésorerie/Salaires/Budget | Aucun montant ou moteur économique modifié |
| Noms des joueurs dans les salaires | Nom statique, bouton Voir le contrat | Nom et action ouvrent la fiche, section contrat | Tri et molette restent distincts |
| Courrier de changement de date | Actions de décision et contexte générique du prochain match | Contexte→sa `fixtureId`, sinon sa `toDate` exacte | Décisions de recalage inchangées |
| Courrier d’échéance | Fiche joueur ouverte directement | Même cible joueur/section contrat et garde commune | Courriers historiques sans identifiants restent des listes filtrées, pas de noms inférés |
| Presse | Invitation ouverte depuis son courrier exact | Aucun changement | Pas de route générique vers la presse |
| Séances futures publiées | Détail descriptif du programme | Inchangé | Pas de détail autonome par ID stable disponible ; ouvrir l’entraînement courant ferait viser une autre séance |
| Barres et points financiers | Journal et graphique de douze écritures | Inchangé | Écritures sans identifiant stable ; préciser un contrat d’identité avant un lien commun par opération |

## Invariants

`target_available` inspecte uniquement le modèle publié et le catalogue.
`open_target` n’émet aucune commande et ne modifie que l’état de lecture.
Les cibles absentes ou ambiguës sont refusées. Les dialogues réutilisent les
fiches CompetitionCanvas et conservent l’écran appelant, plutôt que de changer
son filtre de classement. Les nouveaux boutons utilisent les composants et le
focus existants. Aucune nouvelle palette, police, charte ou donnée réelle.

Les statistiques montrées viennent exclusivement du résultat conservé ; aucune
prédiction, attribution causale ou valeur cachée n’est créée.

## Collision arbitrée avec Claude

Le diff de `origin/claude/salaires-par-niveau-20261111` sur `finance_canvas.gd`
touche `_weekly`, `_due`, `_footer`, `_season_budget`, `_budget`. Ce lot n’écrit
que les nouvelles fonctions de cible et `_metrics`, `_wages`, `_open_player`.
Les montants, légendes, budgets et calculs de Claude doivent être conservés
intégralement. L’intégrateur a confirmé ce partage de fonctions le 11 novembre.
Aucun moteur de calendrier/économie, fichier d’animation, ZIP ou Windows modifié.

## Validation

Reçu local du 11 novembre, SDK Godot `4.7.2.stable.official.ed1daf0bf`,
audio `Dummy`, tête produit `6ec95c60540eca0dcabf25a248f02750e8c5d94f` :
`WORLD ENTITY TARGETS : 26 contrôles ; 0 échec(s)`, sortie 0.
Commande : `godot --headless --audio-driver Dummy --path native/godot --script ../../tests/godot-world-entity-targets.gd`
sous le verrou partagé `/workspace/work/rg27-godot.lock` ; garde externe 40 s.
Le helper commun `entity_link.gd` est repris de la branche navigation-core,
sans être dupliqué dans les commits de cette branche.

Les deux premières tentatives locales ont révélé des ressources `.ttf.import`
manquantes dans ce nouveau worktree (copier le cache `.godot` seul ne suffit
pas). Après reprise des cartes d’import générées par le SDK et du helper corrigé,
la troisième exécution ci-dessus compile les dépendances et réussit. Les anciens
échecs de chargement ne constituent pas un défaut produit corrigé ici.

Les 26 contrôles de lookup synthétiques vérifient identifiants absents/ambigus,
année bissextile, conservation modèle/commandes, nation sans club, onglets
financiers et rapport conservé après sortie du marché. Ils ne constituent pas
une recette d’une rencontre historique ni d’un rapport réellement générés ;
celles-ci sont réservées au harness fonctionnel commun. Aucune capture, recette
Windows ou CI complète n’est revendiquée par ce reçu.

Raccord financier vérifié par `git merge-file` entre la finance `origin/main`,
notre tête produit et `origin/claude/salaires-par-niveau-20261111` : sortie 0,
sans conflit. Le résultat contient les cibles de consultation, les liens de
salaires et la fonction `_season_budget` de Claude ; aucun moteur n’a été
exécuté ou modifié pour ce contrôle.

## Rapports et dossiers de recrutement

`Recruitment.target_available/open_target(app, report_id)` ouvre uniquement le
rapport conservé correspondant à `decisions.recruitment.reports[].id`, y compris
après le départ du joueur du marché. Les identifiants absents ou dupliqués sont
refusés. Le rapport garde ses faits et avis datés ; aucune évaluation actuelle
n’est substituée à son contenu. Un accès au dossier actuel n’apparaît que si
le `playerId` est toujours publié une fois dans le marché courant.

Les noms/portraits du marché ouvrent le dossier de recrutement ; ceux de
l’archive ouvrent le rapport complet exact. Le statut de rapport de la ligne
et sa source datée ouvrent également le rapport. La sélection locale de ligne,
le tri, le suivi, l’observation et les offres restent des gestes distincts.
Les candidats des fenêtres Relève et Marché entre clubs ne reçoivent aucun
lien vers un joueur absent de la projection marché. Le tableau actuel ne
présente pas de club employeur pour ses agents libres ; aucun club n’est inféré.

Contrôles stables : `MarketEntity_ID`, `MarketReportLink_ID`,
`RecruitmentPortraitLink`, `RecruitmentNameLink`, `RecruitmentSourceReport`,
`OpenScoutReport`. Dialogue `RecruitmentReport` avec `entity_kind=report` et
`entity_id=report.id`. Le lien optionnel vers le marché s’appelle
`ReportCurrentPlayer`.

## Revue des destinations absentes

La date lisible d’une fiche de rencontre reste un libellé lorsque sa valeur
brute ne passe pas la validation calendaire. Le bouton `FixtureCalendarDate`
n’existe que pour une vraie date ciblable. Une ligne tabulaire de rencontre
sans identifiant résoluble garde ses informations et ses liens internes valides,
mais n’expose plus d’action de ligne vers un détail absent/ambigu. Les autres
boutons de fiche (club, résultat archivé, compétition, calendrier journalier)
étaient déjà conditionnés par la disponibilité de leur destination. Le lien
optionnel d’un rapport vers le marché exige aussi explicitement un ID joueur
non vide. Aucune UI supplémentaire lancée pour cette revue ciblée.
