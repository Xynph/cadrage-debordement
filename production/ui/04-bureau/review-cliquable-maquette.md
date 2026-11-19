# Bureau (04) : relecture adverse, cliquabilité, petites fenêtres, fidélité à la maquette

Relu : `office_canvas.gd` (large, ≥ 1600 px), `office.gd` (étroit), `coach_canvas.gd` (colonne de Gabi), captures 1920 / 1280 / 2560x1800, maquette 04-bureau-1 + face-à-face de 04-bureau-3, fiche `design/ux/04-bureau.md`. Lecture seule, rien lancé. Les verdicts « d'après la capture » sont à confirmer au rendu.

## A. Cliquabilité (Bureau large)

| Élément | Effet du clic (code) | Verdict |
|---|---|---|
| « Préparer le match » | Préparation | OK |
| « Vérifier les 23 → » | Composition | OK |
| Blason / nom des deux clubs de l'affiche | fiche du club (`reading_overlay`) | OK (nom de club, pas de joueur) |
| Date de l'affiche | agenda du jour (entité `date`) | OK |
| Compte à rebours « SAMEDI, DANS 4 JOURS » | rien | OK (texte d'affiche, non souligné) |
| Face-à-face : noms des clubs (en-têtes), rang « 13e · 0 pts », V/N/D, « Bilan », « Différence de points » | rien | À CORRIGER : chiffres et noms qui ressemblent à des liens ; clic = fiche du club (noms), Classements (ligne « Classement »). Sinon, rendre nettement non cliquables |
| Vignette de stade / ville dans le bandeau (« STADE DU CLUB · … ») | `territory_art` ne branche aucun clic ; infobulle seulement | À CORRIGER : tuile légendée, a l'air ouvrable ; ouvrir l'écran Club ou retirer la légende de tuile |
| Priorités 1 à 3 (titre, détail, échéance « Aujourd'hui → ») | `open_priority` : écran concerné | OK sur la zone titre/détail |
| Grand chiffre « 1 / 2 / 3 » et liseré de couleur de la priorité | rien (la zone cliquable commence à x = 86, le chiffre est à x = 44) | À CORRIGER : étendre la zone à toute la ligne (x = 20) |
| Priorité « Jeune à examiner » (`youth_review`) | ouvre `youth_development_view` = AcceptDialog | BLOQUANT (voir B) |
| Priorité « presse » | `_show_press_inbox()` : non lu, à vérifier (fenêtre ?) | À VÉRIFIER |
| Nom de joueur dans le détail d'une priorité (« Arthur NORTH · Fin de contrat… ») | clic de la ligne : Effectif ; pas de mini-fiche au survol | À CORRIGER (règle noms de joueurs : fiche + mini-fiche) |
| « OBJECTIF DU CONSEIL : Top 10 · 13e · en retard » | rien (infobulle) | AVIS : lire comme un fait ; un clic vers Club / objectifs serait un plus |
| « Entraînement → » | `open_training` | OK |
| Compteurs « 38 disponibles » / « 2 blessés » | Effectif (blessés filtrés) | OK |
| Barres CONDITION / MORAL / CONFIANCE et « SEUIL 70 » | rien | AVIS : jauges, pas de lien ; « Confiance du conseil » pourrait mener au Club |
| « Voir 14 joueurs sous surveillance → », « 9 titulaires… sous 70 % → », « Consulter le groupe → » | Effectif surveillés / Composition / Effectif | OK |
| « ! Blessés : Kyle FAIRCLOUGH, Piers BICKERSTAFF » | fiche joueur + mini-fiche (`MiniFiche.lier`) | OK ; À CORRIGER : seulement 2 noms affichés (`slice(0, 2)`), les autres blessés sont omis sans « +n » cliquable |
| Joueur d'exemple « surveillé » (`OfficeWatchedPlayer_*`) | fiche via `_label_reading`, mais pas de `MiniFiche.lier` | BLOQUANT (règle mini-fiche, apparaît quand il y a des surveillés et aucun blessé) |
| Classement : ligne, rang, nom du club, pastilles de forme | fiche du club (le nôtre : écran Club) | OK |
| Classement : en-têtes RG, CLUB, J, DIFF., **PTS ▼**, V-N-D, FORME | rien | BLOQUANT : « PTS ▼ » est un indicateur de tri qui ne trie pas. Retirer la flèche (ou rendre les en-têtes actifs vers Classements, tri en place) |
| Légende de zones (★ ▲ ▼) | rien (infobulle) | OK (légende) |
| « Classement complet → » | Classements | OK |
| Courrier : ligne (catégorie + titre) | lettre dans Réception | OK ; À CORRIGER : noms de joueurs dans les titres (ex. « Piers BICKERSTAFF s'est blessé ») sans mini-fiche |
| Courrier : en-têtes SUJET / TITRE | rien | OK (en-têtes) |
| « Réception → » | Réception | OK |
| Profil à suivre : nom | fiche marché + mini-fiche | OK |
| Profil à suivre : portrait, prix, salaire, « Offre possible » | rien | À CORRIGER : portrait = clic fiche (comme le nom) |
| « Voir la fiche → » / « Ouvrir le recrutement → » | marché / Recrutement | OK |
| Panneau « RÉSULTATS · CINQ DERNIERS MATCHS » (venu de `office.gd`) | score → rencontre, blason et nom → club, tuile : rien | OK pour score/club ; la tuile bordée ne fait rien : À CORRIGER (ou retirer, voir C) |
| Prochains matchs : ligne | 1re : Préparation ; autres : agenda du jour, sinon Calendrier | OK |
| Prochains matchs : date, blason, nom du club | agenda du jour / fiche club | OK |
| « Tout le calendrier → » | Calendrier | OK |
| Gabi : lignes PROCHAIN MATCH / LE GROUPE / L'ALERTE / MON CONSEIL | rien (`MOUSE_FILTER_IGNORE`) | À CORRIGER : texte avec noms de joueurs (« Sutcliffe… pour Brooks ») non cliquable, sans mini-fiche ; au minimum, chaque ligne ouvre son écran (Préparation, Effectif, Composition) |
| Buste de Gabi | bulle d'avis (pas une fenêtre) | OK |
| « Suivre le conseil → » | `suivre_conseil` : écran / commande | OK, à vérifier qu'il ne passe pas par une fenêtre (non trouvé) |
| Carte « Premiers pas » : action, « Masquer » | action / masque en place | OK |
| États sans prochain match, live : bouton principal, « Revoir le match → » | action principale / Match | OK |

## A bis. Cliquabilité (Bureau étroit, `office.gd`, < 1600 px)

| Élément | Effet | Verdict |
|---|---|---|
| Tuile de priorité (encadrée, icône, échéance, détail) | seul le texte « 1. Titre → » est un bouton ; le reste de la tuile ne fait rien | BLOQUANT : une carte à cadre qui n'ouvre rien sur 2/3 de sa surface |
| « Mon carnet personnel » | `coach_notes_view` = AcceptDialog | BLOQUANT (B) |
| « Préparer la suite du club » | `manager_planning` = AcceptDialog | BLOQUANT (B) |
| « Entraînement » | `open_training` | OK (bouton encadré à convertir en lien) |
| « Dans ton bureau » : 3 événements | du texte, aucun clic | À CORRIGER : même effet que le grand (clic = lettre) |
| Tuiles « Prochains matchs » | date, blason, nom actifs ; la tuile encadrée ne fait rien | À CORRIGER |
| Classement : ligne | fiche du club | OK |
| « Voir cette piste », « Ouvrir le recrutement » | marché | OK (bouton encadré) |
| Compteurs disponibles / blessés | non cliquables (simples chiffres) | À CORRIGER (le grand les rend actifs) |
| Nom du joueur à suivre | pas de mini-fiche, pas de lien | BLOQUANT (nom de joueur) |

## B. Petites fenêtres

- BLOQUANT : priorité `youth_review` (les deux Bureaux) ouvre `ui/youth_development_view.gd`, un AcceptDialog. À remplacer par un écran (Formation, jeune sélectionné).
- BLOQUANT (étroit) : « Mon carnet personnel » → `coach_notes_view.gd` (AcceptDialog, contient aussi un ConfirmationDialog). Déjà retiré du large ; à retirer de l'étroit aussi (le carnet est celui de Gabi).
- BLOQUANT (étroit) : « Préparer la suite du club » → `manager_planning.gd` (AcceptDialog, `popup_centered_clamped`). Passer en écran ou en priorité, comme le prévoyait la fiche UX §9.
- À VÉRIFIER : priorité « presse » (`_show_press_inbox`) et `open_training` ; non lus ici.
- OK : la mini-fiche (`mini_fiche.gd`) est posée dans la coque, pas une fenêtre.

## C. Fidélité à la maquette (variante 1 + face-à-face de la 3 + Prochains matchs chez Gabi)

### BLOQUANT
1. **La page défile à 1920×1080 ; la maquette tient sans défiler.** Hauteurs du code (unités page, densité ≈ 0,73) : affiche 520 + priorités/groupe 440 + classement/courrier 340 + profil 140 + résultats 150, plus 4 écarts de 16, soit ≈ 1 500 unités ≈ 1 100 px sous l'en-tête. La maquette montre trois rangées (≈ 312 + 334 + 215 px) qui tiennent. Corrections attendues : affiche 520 → ≈ 430 (le corps est trop haut sous le bandeau) ; classement/courrier 340 → ≈ 295 avec **3 lignes** chacun (la maquette montre les voisines de notre club, pas 6 lignes ; le texte UX dit « 6 lignes », c'est lui qu'il faut corriger) ; en-tête de page à 53 px de titre à réduire au gabarit maquette (≈ 28 px). Le profil à suivre et le panneau de résultats ne figurent pas dans la maquette : les sortir du Bureau (le profil va à Recrutement, fiche UX §9) ou les mettre sous le pli sans empiéter sur les trois rangées.
2. Mêmes blocages que A / B : « PTS ▼ » sans effet, mini-fiche absente sur le joueur surveillé, AcceptDialog de la priorité jeune, deux fenêtres et tuiles inertes du Bureau étroit.
3. Données : rien d'inventé ni de figé trouvé dans le large (nom de club et de championnat tirés du modèle, face-à-face limité aux données connues). Réserve : la « catégorie » du courrier (Direction / Formation / Vie du club) est déduite de mots-clés du texte (`contrat`, `espoir`) ; une catégorie fausse est une donnée inventée. Utiliser la catégorie du message si elle existe, sinon ne pas afficher la colonne.

### À CORRIGER
- Titres en italique incliné : sur les captures, « LE BUREAU », les titres de cartes et les noms des clubs de l'affiche sortent droits et plus larges que la maquette (Barlow Condensed ExtraBold Italic, 10°). Vérifier que `ClubUI.italic` s'applique réellement au rendu.
- Densité FM : le rail de gauche (libellés ≈ 20 px, lignes hautes) et l'en-tête sont presque deux fois plus grands que dans la maquette (rail à ≈ 13 px, lignes de 34 px). À reprendre dans `shell.gd`.
- Courrier : la maquette a un compteur « 4 non lus », une colonne REÇU (heure) et des sujets Club / Médical / Presse ; le code n'a ni compteur ni heure.
- Panneau « Résultats · cinq derniers matchs » : cadre arrondi (rayon 8-10), fond et bordure hors jetons, `C.GOLD` pour les nuls (or interdit hors Continuer et héritage) ; absent de la maquette. Retirer, ou le réécrire en jetons plats.
- Pied de page : la capture affiche « Échap Retour », la fiche UX et la maquette « Échap Menu » (Échap ouvre le menu pause sur le Bureau).
- Étroit : cadres complets, rayons, icônes emoji dans les titres (▦ ♡ ♜ ✉ ⌕), boutons encadrés (« Entraînement », « Vérifier les 23 », « Classement complet », « Voir 14 joueurs… »), or pour les priorités importantes (`priority_color`), pas d'objectif du conseil, pas de face-à-face, pas de colonne de Gabi. Seul le style « lien » commun de `components.gd` (branche Réception) est à brancher une fois fusionné ; le critère « objectif du conseil lisible sans clic » n'est pas rempli à 1280.
- Face-à-face : la maquette a un fond de lignes plus lisible et centre les libellés ; le code les rend, mais « 5 derniers » n'affiche qu'une pastille par club en début de saison : acceptable, à signaler « 1 match joué ».
- Gabi : grand vide entre « Prochains matchs » et le buste à 1920/2560 ; la maquette le comble avec le buste plus haut.

### AVIS
- « Feuille complète » devrait rester un texte, mais gagnerait à devenir un lien vers Composition quand elle est incomplète (« à compléter, 2 postes » dans la maquette).
- 2560x1800 : le pied de page recouvre le bas du panneau de résultats (confirme qu'il faut le retirer ou le replier).
- Le bandeau d'affiche mélange photo voilée et vignette de stade à droite ; la maquette n'a que le bandeau voilé, plus sobre.
