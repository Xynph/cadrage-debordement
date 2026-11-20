# 16 Calendrier et classement : relecture adverse (cliquabilité, petites fenêtres, maquette)

Lecture seule, sans lancer Godot. Sources : captures `cap2\classements-1920.png` et `-1280.png`, `cap3\classements-rencontre-1920.png` et `classements-archives-1920.png` (le 1280 des sous-pages n'a pas été relu), code de `competition_canvas.gd`, `month_calendar.gd`, `standings_zones.gd`, `club_views.gd`, `navigation_controller.gd`, `main.gd`, maquette `16-calendrier-classement-1.png`, fiche `design/ux/16-calendrier-classement.md`. Aucune capture de la grille mensuelle n'existe : elle est jugée sur le code seul. Le comportement des clics est lu dans le code, pas observé.

## A. Cliquabilité

| Élément (apparence) | Effet du clic (code) | Verdict |
|---|---|---|
| Ligne de club du classement (toute la ligne, curseur main) | Fiche du club (écran) via `Link.bind` | OK |
| Écusson et nom du club dans la ligne | Idem (enfants non capteurs) | OK |
| Pastilles de forme V/N/D dans la ligne | `_recent_form` crée un `Control` nu : filtre souris par défaut = STOP, avec infobulle. Il avale le clic sur 180×26 px de la ligne et coupe aussi le survol de la ligne | **BLOQUANT** : une zone de ligne ne répond pas ; mettre `MOUSE_FILTER_IGNORE` (ou rendre la forme cliquable vers le club) |
| En-têtes #, CLUB, J, V, N, D, PF, PC, DIFF., BON., PTS | Tri en place (`_trier`), flèche sur la colonne active, infobulle « Trier par » | OK ; au repos rien ne dit qu'ils se trient (AVIS) |
| En-tête FORME | Texte simple, non cliquable, pas d'apparence de lien | OK |
| Menu de compétition « Accession anglaise · ma compétition ▾ » | Ouvre une liste dans la page (Mes compétitions / Autres) ; un choix recharge le classement | OK (exception autorisée) ; la liste ne se ferme ni au clic ailleurs ni à Échap (Échap quitte la page) : À CORRIGER |
| Liste « Poule » (`StandingsPoolChoice`), saut de saison des archives, modèle de semaine | `OptionButton` natif, menus déroulants | OK (exception « menus déroulants ») |
| Légende V / N / D, légende des zones | Texte et symboles, infobulle seulement, pas de style de lien | OK |
| Liseré et symbole de zone dans la ligne | Font partie de la ligne : ouvre le club | OK |
| « Ta place » : rang « 13e », points, ligne V·N·D, zone | Texte | OK |
| « Ta place » : trois tuiles d'écart (−5 sur le 1er…) | Fiche du club cité (`_entity_area`) | OK ; au repos aucune marque de lien, seul le survol change (AVIS) |
| Prochain rendez-vous : date « 26/09/2026 · 15:00 » | Ouvre le calendrier à ce jour (`CompetitionNextDateLink`) | Fonctionne mais invisible : texte nu, ni soulignement ni flèche : À CORRIGER |
| Plaque du club à domicile / à l'extérieur | Fiche du club | OK |
| « CONTRE », lieu « À domicile · Fenbank Ground », « 13e contre 1er · 5 pts d'écart » | Texte non cliquable, sans apparence de lien | OK |
| « Déjà joué cette saison : … » (lien souligné) | Sous-page de la rencontre (si l'id existe), sinon texte | OK |
| « PRÉPARER LE MATCH → » (ivoire plein) | Préparation ou Match en direct | OK, seul bouton plein de l'écran |
| « Dossier adverse → » | Fiche du club adverse | OK |
| Calendrier du club : ligne entière (J2, 26/09, Trentwood…) | Sous-page de la rencontre | OK |
| Calendrier du club : date | Calendrier à ce jour | OK mais invisible (zone plate au survol) |
| Calendrier du club : adversaire (écusson + nom) | Fiche du club | OK |
| Calendrier du club : « À jouer → » | Hors adversaire et date, c'est la ligne : ouvre la sous-page de la rencontre, pas la Préparation. La fiche (§3) disait « À jouer » → Préparation | À CORRIGER (la flèche promet l'action) |
| Calendrier du club : badge « D 20 – 46 » | Sous-page de la rencontre | OK |
| Calendrier du club : « — » des matchs futurs | Ligne, sous-page de la rencontre | OK |
| « Toute la saison → » | Calendrier (vue mensuelle) | OK |
| Derniers résultats : ligne, phase « Championnat », score | Sous-page de la rencontre | OK |
| Derniers résultats : club domicile / extérieur | Fiche du club | OK |
| Tuile « Meilleure attaque / défense » (écusson, nom) | Fiche du club (zone 16–1280 px, hors chiffre) | OK ; « Donnée à venir » sans club : texte |
| Gros chiffre « 47 » / « 8 » | Non cliquable, se lit comme une valeur | OK |
| Onglets Classements / Phases finales / Calendrier / Statistiques / Rivalités | Changent de contenu ou d'écran (Rivalités = route) | OK |
| « XV type → », « Archives des saisons → » | Écran XV type ; sous-page Archives | OK |
| Pastille « CONSULTATION » (championnat suivi de loin) | Rectangle encadré, majuscules, infobulle seulement : RIEN | À CORRIGER (a l'air d'un bouton ; en faire du texte sans cadre ou un lien vers Réglages) |
| Sous-page rencontre : « Club → », date « → voir dans le calendrier », « voir le classement → » | Fiche du club / calendrier à la date / classement de la compétition | OK |
| Sous-page rencontre : « PRÉPARER LE MATCH → » | Préparation (seulement si c'est le prochain match) | OK |
| Sous-page rencontre : « ← Retour au classement », flèche de la coque, Échap | Retour, historique Précédent/Suivant gérés (`navigation_controller`) | OK |
| Sous-page archives : lignes « Champion … : club », « Ton club actuel » | Texte nu ; aucun club ne s'ouvre | OK au sens strict (rien ne ressemble à un lien) ; AVIS : relier les clubs |
| Phases finales : cartes de matchs (rectangles à 5 px de rayon, bordés) | Texte, non cliquables ; ressemblent à des cartes de rencontre | À CORRIGER (ouvrir la rencontre) |
| Statistiques : tuiles « Matchs joués… » et « Notre club » | Texte | OK |
| Pagination « ← Précédent / Suivant → » (tableau, calendrier, phases) | Change la page en place | OK |
| Grille mensuelle : case d'un jour | Sélectionne le jour (programme à droite) ; flèches clavier | OK |
| Grille mensuelle : vignette de match (écusson, adversaire, score, lieu) | Filtre souris ignoré : sélectionne seulement le jour | À CORRIGER (la vignette la plus parlante n'ouvre ni rencontre ni club) |
| Grille mensuelle : nom d'une séance | Détail de la séance (`CalendarSessionGridLink_`) | OK |
| Grille mensuelle : bande d'absences, bandeaux « J−n » | Infobulle ; clic = sélection du jour | OK |
| Mois/Semaine, ‹ Aujourd'hui ›, Tableau, filtres | Agissent en place ou ouvrent la vue tableau | OK (mais voir C, boutons encadrés) |
| « Prochains rendez-vous publiés » : bouton « Voir » | Sélectionne la date | OK |
| Graphique « Séances publiées » (barres, chiffres) | Infobulle seulement | OK (AVIS : les barres ressemblent à des contrôles) |
| Détail du jour : blasons, score, nom d'adversaire | Fiche du club / sous-page de la rencontre | OK |
| Détail du jour : « Préparer ce match », « Entraînement de la semaine », « Consulter les disponibilités », « Appliquer » | Préparation / Entraînement / Sélections / applique le modèle en place | OK ; styles de bouton encadré (voir C) |

## B. Petites fenêtres

Aucun `Window`, `AcceptDialog`, `ConfirmationDialog` ni `PopupPanel` dans `competition_canvas.gd`, `month_calendar.gd`, `standings_zones.gd` ni dans le chemin d'archives de `club_views.gd` (la boîte `SeasonArchives` est retirée, remplacée par la sous-page). Rencontre et archives passent par `management_ui.competition_page`, avec historique (`navigation_controller`) et réinitialisation par le menu (`main.gd`). Clubs, dates et compétitions ouvrent des écrans.

Restent des menus déroulants autorisés : le sélecteur de compétition (liste dans la page), la liste de poule, le saut de saison des archives, le choix du modèle de semaine du calendrier. Aucun clic ne déclenche de fenêtre : B est propre.

À noter : le tableau n'a aucun nom de joueur, donc pas de mini-fiche à vérifier ; ce sera à contrôler le jour où meilleurs marqueurs et réalisateurs reviendront.

## C. Fidélité à la maquette (variante 1, plus écarts de la 2 et zones de la 3)

### BLOQUANT
1. Zone de forme sans réponse dans les lignes du classement : voir A (filtre souris STOP de `RecentForm`). À corriger avant livraison.

### À CORRIGER
1. **Page qui ne défile pas au-delà de 14 clubs** : `capacity := 16` plus pagination « Page 1 / 2 ». Léo veut une page qui défile : montrer toutes les lignes (le panneau et `content_bottom` suivent déjà le nombre de lignes). Idem pour le calendrier tableau (11 par page) et les phases finales (8 par page).
2. **Grille mensuelle non redessinée, incohérente avec la charte** (`month_calendar.gd`) :
   - cartes, vignettes, pastilles et boutons créés avec `C.box` en rayon 6 à 10 et bordure complète (la bascule `rayon_nul` n'est pas posée sur cet écran) : cadres complets et arrondis, interdits par la §3 ;
   - bandeau de tête : carte arrondie à fond teinté de l'accent du club et photo de stade à 21 % ; titre « Septembre 2026 » en casse mixte, droit, au lieu de Barlow Condensed ExtraBold Italic capitales inclinées ;
   - tous les boutons (Mois, Semaine, ‹, Aujourd'hui, ›, Tableau, cinq filtres, Voir, Préparer ce match, etc.) sont des boutons encadrés `C.button` : à passer en liens ivoire soulignés au survol ; « Préparer ce match » devrait être l'unique bouton ivoire plein ;
   - jour courant cerclé de vert (jeton V, qui veut dire victoire) ; icônes de séance en huit couleurs hors charte, dont deux ors (`e4bf82`, `efc76b`) alors que l'or est réservé à Continuer et à l'héritage ; encarts « AUJOURD'HUI » et « SÉLECTION » en pastilles pleines arrondies ;
   - textes que la fiche §8 demandait de retirer ou reformuler et qui sont toujours là : « Match à l'extérieur · aucune date de voyage distincte n'est publiée. » et « Comptage des créneaux, sans estimation de charge physique. » ;
   - cette vue n'a pas la rangée d'onglets Classements / Calendrier / Rivalités : on ne la quitte que par le rail ou le bouton « Tableau », contrairement à « une seule rangée d'onglets » (fiche §3).
   Pas de petite fenêtre, mais la grille mensuelle n'est ni cohérente avec la charte ni avec le reste de l'écran. À reprendre dans l'esprit de la page Classements (ou à marquer explicitement comme chantier suivant avec Léo).
3. **Cadre complet sur « notre ligne »** : la fiche demande « club-trait + marqueur incliné » ; le code ajoute en plus une bordure ivoire de 2 px complète (visible sur 1920 et 1280, ligne 13). Même chose pour la ligne « prochain match » du Calendrier du club (cadre ivoire), les étiquettes « À jouer » (`_box_tag`) et la pastille « CONSULTATION ». La maquette dessine bien un cadre, mais la charte l'interdit : garder trait + marqueur seuls.
4. **Plaque du prochain adversaire au 1280** : « TRENTWOOD ARCHERS » passe sur deux lignes et « TRENTWOOD » sort de la plaque au-dessus de « CONTRE » (`classements-1280.png`). Réduire la taille ou raccourcir (`fit_title`) pour que le nom reste dans la plaque.
5. **Forme V/N/D** : rectangles pleins avec lettre sombre ; la maquette montre des pastilles ovales (plein V, demi N, vide D). Lettre et forme portent le sens (bon pour la lisibilité), mais à rapprocher de la maquette et de la règle « forme du symbole » de la fiche §10.
6. **Date du prochain rendez-vous et date du Calendrier du club** : liens cachés (voir A). Donner l'apparence d'un lien (souligné fin ou flèche) ou ajouter « voir dans le calendrier → ».
7. **« À jouer → » du Calendrier du club** : mène à la rencontre et non à la Préparation ; soit mener à la Préparation pour le prochain match, soit retirer la flèche.
8. **Sous-page de la rencontre** (hors maquette, mais plus faible que le reste) : bloc étroit sur la moitié gauche, aucun écusson ni plaque, lignes de texte alternant gras et fin ; surtout des lignes de provenance (« Date publiée par la RFU », « Heure locale · Europe/London », « Horaire publié dans le centre de match RFU ») contraires à la règle d'immersion (provenance et sources restent internes). Retirer ces lignes, reprendre le gabarit « Prochain rendez-vous » (plaques, score, V/N/D en plus de la couleur du score).
9. **Sous-page des archives** : texte à 12 px dans un cadre de 1000 px de haut presque vide ; jargon « identités du pack actuel » ; polices héritées (DM Sans) hors charte ; relier les clubs cités à leur fiche quand des saisons existent.
10. **Onglets Phases finales et Statistiques** non redessinés : cartes à 5 et 6 px de rayon avec bordure complète (`D.rect(..., 5, C.LINE)`), panneaux imbriqués, texte de barrages du Japon et libellés « Barrage D1 », « Petite finale », « Barrages D1–D2 en deux manches » figés dans le code au lieu de venir des données de la compétition. Le brief dit qu'un nom de championnat figé est bloquant : ici c'est du code hérité, hors de l'écran de la maquette, donc classé à corriger, mais à ne pas laisser.
11. **Zones lues par la couleur seule dans la branche hors Monde** : `_ligne_classement` colore le liseré (vert, sable, rouge) sans symbole, et la légende du bas dit « Vert : 1–6, phase finale · Sable : 13, barrage d'accession · Rouge : 14, descente » (règles figées et couleur seule). Branche morte en carrière Monde ; la supprimer.
12. **Liste du sélecteur de compétition** : ne se ferme pas au clic ailleurs ni à Échap (Échap fait « retour »). Fermer au clic extérieur et à Échap d'abord (règle unique d'Échap).

### AVIS
1. « Journée N · Programme » et « Journée N · Résultats » de la maquette : le code propose « Derniers résultats » (cinq lignes, sans programme de la journée). L'omission du programme n'est pas dans la liste des omissions de la fiche ; à ajouter si la projection fournit les rencontres de tous les clubs, sinon à consigner.
2. Meilleurs marqueurs / réalisateurs, arbitre, bulle de Gabi, dernière confrontation hors saison : omis faute de donnée, conforme à la fiche (sauf la dernière confrontation, non listée). Acceptable.
3. Vert des zones « phase finale » : même vert que V (victoire) dans le même tableau ; symbole, liseré et mot évitent la couleur seule, mais les zones pourraient rester en ivoire/neutre pour garder V et D exclusifs. Même remarque pour le gris N réutilisé comme barrage.
4. « Ta place » ajoute un bloc « 13e 0 pts » plus gros que la maquette (la maquette ne montre que les trois écarts et une ligne à droite du titre) ; cohérent avec la fiche, pas gênant.
5. Les tuiles d'écart sont des plans pleins sans marque de lien au repos ; l'infobulle et le survol suffisent, mais une flèche réduirait le doute.
6. Textes de 14 à 17 px de conception : à 1280 les rangées de calendrier, tuiles d'écart et en-têtes tombent vers 8-10 px réels (visibles sur `classements-1280.png`). La fiche garantit 11 px minimum à 1080p seulement ; à confirmer si 1280 est dans le périmètre.
7. Quand une autre compétition est choisie, « Ta place », « Prochain rendez-vous » et « Calendrier du club » restent ceux du club : comportement correct, mais rien ne dit à l'écran que ces cartes ne suivent pas le menu.
8. Les en-têtes triables ne se distinguent des libellés qu'à la flèche de la colonne active et au survol.

## Données figées ou inventées
Aucun nom de club ni de championnat inventé dans le chemin Monde de la page Classements : noms, zones, légendes et libellés de ronde viennent du modèle. Les chaînes figées sont toutes dans des branches hors Monde ou hors maquette (point 10 et 11 de « À corriger »).
