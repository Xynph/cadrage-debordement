# Relecture adverse — écran 12 Avant-match (cliquabilité, petites fenêtres, maquette)

Relecture en lecture seule (aucun Godot lancé) : code de `match_avant.gd`, `avant_match_pages.gd`, `espoir_appel.gd`, `delegation_dialog.gd`, `main.gd`, `shell.gd`, `navigation_controller.gd`, `raccourcis_clavier.gd`, `match_canvas.gd`, `match_screen.gd`, captures 1920 et 1280, maquette variante 1 + plaques de la variante 3. Sous-pages jugées sur le code seul.

## A. Cliquabilité

| Élément | Effet du clic (d'après le code) | Verdict |
| --- | --- | --- |
| « Menu » | `app.pause_menu` : AcceptDialog « Ta carrière » (exception « menu Échap ») | OK ; mais bouton encadré (voir C) |
| « JOUR DE MATCH » | texte, non cliquable, pas d'apparence de lien | OK |
| Statut de feuille (mot « Feuille à vérifier » + symbole) | mot = lien vers Composition ; symbole et détail « (12 avertissements) 23/23 condition moyenne » : rien | À CORRIGER : seul le mot est actif, le reste de la ligne a l'air du même élément (rendre toute la ligne cliquable) |
| Date du match | texte | OK |
| « Déléguer le match → » | sous-page « delegation » (plus de fenêtre) ; grisé si feuille bloquée, raison en infobulle + texte | OK |
| COUP D'ENVOI | lance le direct, ou sous-page « espoir » si feuille incomplète (écran 1920/1280) | OK |
| Plaque club (domicile / extérieur) | fiche du club (`open_entity`), repli Classements | OK |
| Écusson | dans la plaque : même clic | OK |
| Heure « 15:00 » et « coup d'envoi · date » | texte | OK |
| « Première confrontation » / « Confrontations : 1 V · 0 N · 3 D » | fiche du club adverse | OK |
| Ligne ciel/vent centrale (« Vent ») | Plan de jeu | OK ; l'icône n'apparaît pas sur les captures (À CORRIGER mineur) |
| Rang « 13e · 0 pts » (x2) | Classements | OK |
| Pastilles V / D / N (x2) | fiche du club du côté concerné, pas le match en question | À CORRIGER : la pastille d'un match précis doit ouvrir ce match (récit/résultat), pas la fiche du club ; à défaut, ne pas les rendre actives |
| Barres de condition 1 à 15 | `_ouvrir_joueur` = fiche complète ; survol/focus + touche I = mini-fiche (`MiniFiche.lier`, source « squad ») ; barre sans joueur : désactivée | OK ; voir risque « 1280 » en C |
| Ligne d'alerte « 12 titulaires sous 80 % : Darcy BROOKS (n° 13) à 65 %, Linden NORTH (n° 8) à 67 % » | RIEN : un seul Label, noms non cliquables, pas de mini-fiche | BLOQUANT (noms de joueurs) |
| Ligne « 2 blessés écartés · état du groupe » | texte ; le lien « État du groupe → » est dessous | À CORRIGER : en faire le lien (ou retirer le doublon) |
| « Vérifier la feuille → » / « État du groupe → » | Composition / Effectif | OK |
| « Condition des titulaires, repère à 80 % » | texte | OK |
| Météo (ligne « Vent · pelouse souple », jauge de vent, texte de vent) | RIEN (infobulle uniquement sur le conseil) | OK, rien n'a l'air cliquable ; le lien « Adapter le plan de jeu → » couvre |
| Conseil du staff « Du vent : tirs au but… » | RIEN (infobulle) | OK |
| Arbitre « Tom Hallworth » | RIEN (infobulle résumé) | AVIS : nom propre en gras ; pas de fiche d'arbitre dans le jeu à ouvrir |
| Lignes Rucks/Mêlée/Hors-jeu/Cartons + crans | RIEN (infobulle « n sur 5 ») | OK |
| « Adapter le plan de jeu → » | Plan de jeu | OK |
| Puce « PROBABLE », « Plan », « Point fort » | RIEN (infobulle sur le bloc) | OK |
| Joueurs à surveiller : nom (« Raymond HANCOCK ») | souligné comme lien ; `_ouvrir_joueur_adverse` ignore l'id et ouvre Préparation (onglet 0) ; mini-fiche source « market » | BLOQUANT : le clic sur un nom doit ouvrir la fiche complète du joueur ; la mini-fiche « market » est à vérifier pour un joueur hors marché (`trouver` peut rendre vide : aucune mini-fiche) |
| Pastille de numéro (10), (9) | RIEN | OK (non cliquable en apparence, mais ronde comme un bouton : AVIS) |
| Ligne « Mêlée 80 % contre 40 % ▲ +40 » | RIEN | OK |
| « Ouvrir la composition → » (plan adverse) | Plan de jeu ou Composition selon `plan.action` | OK |
| « Dossier adverse → » et « Rapport de force → » | tous deux `_ouvrir_preparation` (onglet 0) : même destination | À CORRIGER : deux liens, une seule page ; ouvrir le bon onglet de rapport de force ou fusionner |
| Tuile « Le mot de Gabi » : phrase, clés 1-2-3 | RIEN | OK (texte) |
| « Ouvrir le plan de jeu → » | Plan de jeu | OK (doublon avec « Adapter le plan de jeu », voir C) |
| « Préparer la causerie → » | Vestiaire | OK |
| Médaillon de Gabi | `installer_bandeau` : clic = avis de Gabi / aide | OK ; vide sur les captures (ovale sans visage, voir C) |
| Titres de tuile, légendes (« 23/23 · complète », « 1er · 5 pts », « 3 clés ») | RIEN | OK ; AVIS : « 1er · 5 pts » pourrait mener au classement |
| Pied : touches Entrée/Espace/Tab/Échap/F1 | RIEN (indicateurs) | OK |
| « aide » (pied) | `_open_coach` | OK |
| Ligne d'état (pied) | texte | OK |
| Sous-page Délégation : case « Confier aussi la composition », « DÉLÉGUER LE MATCH », « Annuler », « ← Retour à l'avant-match » | case : en place ; confirmer : `begin_match` puis `delegate` ; annuler/retour : ferme la sous-page | OK ; un seul bouton ivoire plein ; focus sur Annuler |
| Sous-page Feuille incomplète : radios « Appeler un espoir : nom, âge… » / « Jouer à 22 », « COUP D'ENVOI », « Annuler » | radios en place ; confirmer : `begin_match` ; annuler : ferme | OK pour les actions ; À CORRIGER : le nom du jeune n'est pas un lien (fiche/mini-fiche) ; cases à cocher de style Godot par défaut (non charte, minimum 560x36 non mis à l'échelle) |
| Précédent / Suivant | absents à l'écran (hors coque) ; seulement Alt+←/→ (navigation_controller) | À CORRIGER : aucune sortie visible vers l'écran d'où l'on vient (Échap ouvre le menu) ; ajouter un lien « ← Retour » discret dans le bandeau ou le pied, et l'indiquer dans le pied |

## B. Petites fenêtres

Hors exceptions autorisées, aucune ouverture par clic dans le parcours riche (>= 1280x720) :
- Menu : AcceptDialog « Ta carrière » = exception (menu Échap).
- Mini-fiche : Control flottant, pas une fenêtre. OK.
- Délégation et feuille incomplète : sous-pages, OK.

À traiter :
1. BLOQUANT : sous 1280x720 (`RICH_MIN_SIZE`), `avant_match_hors_coque` est faux et l'écran est `MatchCompact` (extends `match_screen.gd`) : son `_act` appelle encore `Espoir.ouvrir(app, true)` = ConfirmationDialog « Feuille incomplète » au clic sur le coup d'envoi (match_screen.gd:526). C'est la « ancienne fenêtre » qui survit dans le repli compact. Le repli doit utiliser la sous-page ou l'écran riche doit se réduire à toute taille.
2. À VÉRIFIER (même repli) : confirmer le chemin « Déléguer » avant le match dans `match_screen.gd` (`app.confirm(...)` sur « ADJOINT » = fenêtre de confirmation, ligne 165) ; si le bouton est actif avant le coup d'envoi en repli compact, c'est BLOQUANT aussi.
3. `Espoir.ouvrir(app, false)` reste utilisé par `squad_views.gd:677` (hors écran 12, noter pour l'écran Effectif).
4. Infobulles système (`tooltip_text`) sur liens, plaques, arbitre, plan adverse : fenêtres système non listées dans les exceptions (la mini-fiche les retire pour les noms de joueurs). AVIS : acceptable si Léo les tolère ; à confirmer.

## C. Fidélité à la maquette (variante 1 + plaques de la 3)

BLOQUANT
- (aucun de données inventées relevé : club, championnat, arbitre, météo viennent du modèle ; « Division d'accession anglaise », Fenbank Ground sont `next.label` et le lieu.) Les trois BLOQUANT de cliquabilité sont en A et B ci-dessus.

À CORRIGER
1. « Menu » est un bouton entièrement encadré (bordure 1 px complète, fond translucide) : cadre complet interdit, bouton secondaire à convertir en lien texte ivoire (style commun de `components.gd`) ; la maquette montre « ≡ Menu » avec pictogramme.
2. Gabi : le médaillon est un ovale vide sur les deux captures (pas de visage), alors que la maquette montre la photo de Gabi. Vide = on dirait un bug et un clic sur rien. Afficher le portrait ou le masquer ; vérifier que le clic ouvre bien l'avis.
3. 1280x720 : texte du vent coupé (« dans le nôtre après… » tronqué à 3 lignes) alors qu'il porte l'information du match ; lui laisser la place (supprimer la ligne redondante « Météo : Vent » / « Vent : Vent… »).
4. 1280x720 : barres de condition très petites (~20 px de large, ~30 px de haut) sur deux rangées, numéros décalés d'un étage ; l'icône « ! » disparaît en `etage` : le signal bas = couleur rouge de la valeur + trait pointillé, donc couleur seule. Garder le « ! » ou souligner la valeur.
5. Statut de feuille : un seul mot est cliquable (voir A).
6. Pastilles de forme : actives mais sans destination propre au match (voir A).
7. « Dossier adverse » et « Rapport de force » : même page (voir A).
8. Icône météo absente sur la ligne centrale (capture 1920/1280 : « Vent » seul) alors que la maquette porte une icône.
9. Pied : « Échap menu » alors que la maquette dit « Retour à la préparation » ; en cohérence avec la décision de Léo (Échap = menu) c'est voulu, mais il faut alors un retour visible (voir A, Précédent/Suivant).
10. Heure absente de la date en haut (maquette : « sam. 21 nov. 2026 · 14:12 ») ; ligne omise sans donnée = acceptable, à vérifier si `calendarToday` ne porte pas l'heure.

AVIS
- Plaques : pleine largeur (≈780 px chacune) et collées aux marges, nom 64 px, couleur club en aplat ; la variante 3 montre des plaques plus compactes autour de l'heure, sur la moitié de l'écran, avec le tunnel visible. Ici elles recouvrent la photo ; choix cohérent avec « l'affiche » mais très différent d'aspect ; à faire valider.
- Photo : pelouse de jour avec tribune sur les captures au lieu du tunnel pluvieux (la photo suit l'heure et la météo ; voulu, donc pas un écart).
- Un voile en dégradé vertical est posé sur la photo : la charte interdit le dégradé ; le voile de lisibilité est discutable, à garder si le texte l'exige.
- Les plaques et le bouton or ont un cadre complet ivoire au survol/focus (focus visible requis) ; le coup d'envoi apparaît ainsi cerclé sur les captures (focus à l'ouverture) : acceptable, à surveiller.
- « Ouvrir le plan de jeu » (Gabi) et « Adapter le plan de jeu » (conditions) mènent au même écran ; garder l'un des deux.
- Maquette : forme à droite des rangs avec point séparateur et « À surveiller » avec numéros ; l'implémentation affiche « Pas encore de statistiques cette saison : leur XV probable. » : c'est une phrase de donnée absente, correcte.
- Pastilles de numéro (10), (9) rondes comme des boutons sans l'être : arrondi contre la règle « rayons 0 » (la maquette le fait aussi).
- Le repli < 720p garde toute l'ancienne interface (voir B1) : ne pas le considérer comme « écran 12 » tant qu'il n'est pas converti.

## Liste fusionnée BLOQUANT / À CORRIGER

BLOQUANT
1. Noms de joueurs de la ligne d'alerte de « Ta feuille » : texte mort (rendre cliquables : fiche + mini-fiche).
2. Joueurs à surveiller : clic ouvre Préparation au lieu de la fiche du joueur ; vérifier la mini-fiche (source « market »).
3. Repli compact < 1280x720 : `Espoir.ouvrir` = ConfirmationDialog au coup d'envoi ; vérifier aussi la confirmation « ADJOINT » (fenêtre).

À CORRIGER
4. « Menu » encadré → lien texte (+ pictogramme).
5. Retour visible vers l'écran précédent (Précédent/Suivant absents hors coque).
6. Statut de feuille : toute la ligne cliquable, pas seulement le mot.
7. Pastilles V/D/N : destination = le match concerné, sinon inactives.
8. « Dossier adverse » / « Rapport de force » : même destination.
9. « État du groupe » : la phrase de blessés a l'air d'un lien ; la lier au lien ou la retirer.
10. Sous-page Feuille incomplète : nom du jeune non cliquable ; radios à restyler (charte, échelle).
11. Médaillon de Gabi vide sur les captures.
12. 1280 : vent tronqué, barres trop petites, signal « bas » à la couleur seule.
13. Icône météo manquante sur la ligne centrale ; heure absente à côté de la date.
