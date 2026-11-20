# 09 Recrutement : relecture cliquabilité, petites fenêtres, maquette

Relecture adverse (ux-designer puis art-director), lecture seule. Branche `claude/da-recrutement-20261119`, commit 44ab8cb. Sources : `recruitment_canvas.gd`, `recruitment_pages.gd`, vues adoptées (`contract_negotiation.gd`, `player_sales_view.gd`, `interclub_market_view.gd`, `regen_scouting_view.gd`, `prospect_profile.gd`, `transfer_budget.gd`, `decision_views.gd`, `main.gd::confirm`), captures 1920 et 1280, maquette `09-recrutement-retouche.png`. Rien n'a été lancé : les sous-pages n'ont pas de capture, leur verdict visuel est lu dans le code.

## A. Cliquabilité

| Élément | Effet du clic (code) | Verdict |
|---|---|---|
| Titre « Recrutement », « Le prochain renfort » | rien, texte nu (non souligné) | OK |
| Période du marché (« Joueurs libres : ouvert jusqu'au… ») | rien ; infobulle seule | OK (ne paraît pas cliquable) |
| 3 tuiles budget (Alloué, Engagé, Restant) / Trésorerie | Finances (`Link.bind`) ; Restant a une infobulle de détail | OK |
| « Finances → » | Finances | OK |
| 3 cartes de besoin | `open_market_position` : filtre poste, onglet Recherche | À CORRIGER : carte à « 0 piste » = clic qui mène à une liste vide ; la carte 1 paraît sélectionnée alors que le filtre poste reste « Tous » (capture) |
| Onglets Besoins du club / Recherche | même liste complète (seule la mise au point change) | À CORRIGER : deux onglets identiques |
| Onglets Joueurs suivis n / Rapports n | changent la liste, `app._render` | OK |
| Sources Marché joueurs / Entre clubs / Relève | liste / sous-page `interclub` / sous-page `releve` | OK (voir C pour le cadre) |
| Liens Offres reçues, Lancer une mission, n fins de contrat | sous-page `offres` / `missions` / Effectif trié par échéance | OK |
| Recherche, 5 filtres (menus), Réinitialiser | agit en place | OK |
| « Comparer → » | `recruitment_comparison.gd` (écran Comparateur) ; deux pistes à choisir dedans | OK, à vérifier : ne doit pas s'ouvrir en fenêtre |
| En-têtes JOUEUR, POSTE, ÂGE, NIV., POT., INDEMNITÉ, SALAIRE, OBSERVATION | tri (flèche ↕) | OK |
| En-tête « ★ » | RIEN (texte gris, `D.text`) ; la fiche UX demande « suivies d'abord » | À CORRIGER : le rendre triable ou le retirer |
| En-têtes TOUCHE / MÊLÉE / GRATT. / PLAQ. / FIN CTR | texte sans flèche, pas de tri | AVIS : cohérent (aucune flèche), mais le tri serait utile |
| Étoile de ligne | `manager_recruitment_watch` en place | OK |
| Ligne entière | choisit la piste, met à jour « Ce que coûte l'offre » | OK |
| Portrait, drapeau | traversés par la ligne = choisit la piste | AVIS : un clic sur le portrait devrait ouvrir la fiche |
| Nom du joueur | fiche complète (`open_entity market`), survol = mini-fiche | OK |
| « i » après le nom | `MiniFiche.icone` (mini-fiche) | OK |
| Poste, club, âge, niveau, potentiel, indemnité, salaire | choisit la piste (ligne) | OK (aucun air de lien) |
| Observation « Rapport du jj/mm » | rapport (sous-page via `entity_available`) ; si la zone n'est pas disponible, RIEN | OK |
| Observation « Observé » sans rapport conservé | RIEN, mais écrit comme les liens de rapport | À CORRIGER : même style que le rapport cliquable ; distinguer ou ouvrir la fiche |
| « Non observé » | rien (gris) | OK |
| Action de ligne « Observer » | choisit la piste et donne le focus au lien « Observer → » du coût (pas de dépense) | OK, mais voir C |
| Action de ligne « Approcher » | sous-page `negociation` | OK |
| Action « En cours » | désactivée (grisée avec filet) | OK |
| Onglet Rapports : ligne, nom | rapport (`kind report`) | OK |
| Pied « n / 27 pistes · suivies », « ↑ Croissant » | texte ; « Croissant » inverse le tri | OK |
| Pied « I aperçu », « Échap menu » (touches) | texte, jamais cliquable | OK |
| Nom du joueur du coût | fiche + mini-fiche | OK |
| Barre budget et légende du coût | rien (graphique) | OK |
| « Approcher le joueur » / « Consulter la discussion » | sous-page `negociation` | OK |
| « Observer → » du coût | `observe_player` confirmed:true : dépense 5 000 € sur un clic | À CORRIGER : voir B (deux temps) |
| « Ouvrir la fiche → », « Lire le rapport complet → » | fiche / rapport | OK |
| « Suivre cette piste » | suit en place ; sans flèche, souligné au survol seulement | OK |
| Missions et échéances → (onglet Rapports) | sous-page `missions` | OK |
| Sous-pages : « ← Retour », Échap, « Valider », « Annuler » | `fermer` / ok.pressed du dialogue adopté | OK |
| Sous-page Relève / Marché entre clubs : nom ou portrait d'un joueur | `Prospect.inspection_button` : ouvre la fenêtre « Dossier » `ProspectProfile` (AcceptDialog) | BLOQUANT : voir B ; pas de mini-fiche au survol non plus |

## B. Petites fenêtres (règle n°2)

Fenêtres encore ouvertes par un clic, hors exceptions :

1. **Dossier** (`prospect_profile.gd`, AcceptDialog) depuis Relève et Marché entre clubs. BLOQUANT. Proposition : sous-page « Dossier du jeune / de la piste » empilée sous la sous-page (retour = la page d'origine, Échap, historique Précédent/Suivant), contenu de `ProspectProfile` adopté comme les autres vues ; mini-fiche au survol du nom via `MiniFiche` (`source` prospect).
2. **Vente d'un joueur** (`player_sales_view.gd::_confirm`, ConfirmationDialog 680×340, `app.add_child`). BLOQUANT. Proposition : confirmation en place dans la carte de l'offre. 1er clic « Accepter… » : la carte se déplie avec les lignes de `confirmation_lines` (caisse, effectif, budget, feuille, JIFF, conséquences) et deux liens : bouton ivoire plein « Vendre X » et lien « Annuler » (focus sur Annuler). 2e clic : `sale_answer confirmed:true`. Même mécanique que « Envoyer la réponse » de la Réception.
3. **Pré-contrat** (`interclub_market_view.gd::_confirm_precontract`, 620×260). BLOQUANT. Même mécanique, dans le panneau de l'offre : le bouton de pré-contrat devient la phrase de confirmation (« X rejoindra ton club le … pour n saisons, prime payée maintenant ») + « Signer le pré-contrat avec X » / « Annuler ».
4. **Enchère** (`_confirm_auction`, 600×180). BLOQUANT. Confirmation en place dans la zone de négociation (phrase « X remportera le joueur … définitive »), deux temps.
5. **Rallonge du conseil** (`transfer_budget.gd::confirm_extension`, 640×230, et le bouton `ContractTransferBudgetExtension` de la négociation). BLOQUANT. En place sous la phrase de refus : le lien « Demander n € au conseil » se transforme en « Confirmer la demande de n € » + « Annuler ». La réponse du conseil s'affiche dans la même page (le code rouvre déjà le devis avec la réponse).
6. **Création de mission** (`decision_views.gd:231`, `app.confirm`, ConfirmationDialog 650×180 : 5 000 € immédiats). BLOQUANT. Même mécanique, dans la sous-page « Besoins, missions et rapports », sous le bouton de lancement : « Lancer pour 5 000 € · rapport après deux journées » / « Annuler ».
7. **Signature du contrat** (négociation adoptée) : « Autoriser la signature si accord » est le bouton de la page, un seul clic engage la prime et le salaire. À CORRIGER : deux temps (récapitulatif et bouton « Envoyer l'offre » en 1er temps, confirmation en place ensuite), conforme à « un écran par offre ».
8. **Observer** (lien du coût) : un clic dépense 5 000 € sans fenêtre, frais écrits à côté. À CORRIGER : mettre le même deux temps, ou garder si Léo accepte la mention de frais comme confirmation (non décidé).
9. Aussi à ranger : `Cover.confirm` (`squad_views.gd:757`, remplacement de blessé) n'est pas sur cet écran, mais partage le même défaut.
10. Les mécanismes d'adoption (`Pages._adopter`) masquent les fenêtres, mais construisent encore des Window en mémoire et dépendent de `queue_free` d'une fenêtre : risque de fenêtre visible si une vue passe par `popup_centered` sans passer par `_derniere_fenetre` (c'est précisément le cas des confirmations ci-dessus, filles de `app`). À CORRIGER en fin de chantier : dès qu'une confirmation est en place, supprimer ces fenêtres filles.

Vue < 1280×720 : le shell bascule sur l'ancien écran (`RICH_MIN_SIZE`). Il garde petites fenêtres, boutons dorés et mini-fiche absente. À CORRIGER à terme ; AVIS si le jeu ne descend pas sous 1280×720 (à confirmer par Léo).

## C. Fidélité à la maquette

BLOQUANT
- Aucun hors des points B (Dossier, confirmations d'argent). Pas de club ou de championnat figé repéré : colonne Club omise sans donnée, attributs omis sans observation.

À CORRIGER
- **Besoins du club = Recherche** : maquette arrive filtrée sur le poste de priorité 1 (« Poste : Talonneur », 24 pistes). Ici tout le marché (27 pistes, piliers) avec la carte 1 surlignée sans filtre. Correction : l'onglet « Besoins du club » applique le poste du besoin choisi (priorité 1 par défaut) et le dit dans le filtre.
- **Cartes « À SURVEILLER » sans piste** (capture : Demi d'ouverture, 0 piste) : une carte morte à l'air cliquable. Correction : lien « Lancer une mission pour ce poste → » (`_staff(1, role)`) ou carte visiblement inactive.
- **Boutons encadrés en trop** (charte « aucun cadre complet ») : action de ligne « Observer / Approcher / En cours » (24 cadres à l'écran), sources « Entre clubs / Relève » et « Marché joueurs » ; champ de recherche. La maquette valide un cadre sur l'action de ligne et sur la source active, mais pas sur chaque ligne. Correction : liens texte ivoire + flèche pour les lignes (cadre seulement sur la ligne choisie si Léo le garde), sources en onglets soulignés. Le style « lien » commun de `components.gd` (branche Réception) est à utiliser quand il sera fusionné.
- **Deux boutons ivoire pleins** quand la ligne choisie est « Approcher » (ligne + « Approcher le joueur ») ; la maquette le montre aussi. Charte : un seul. Correction : la ligne choisie passe en lien appuyé.
- **Densité à 1280** : lignes et cellules à ≈ 9 à 10 px (capture 1280 ; 18 unités × 0,5), sous le plancher de 11 px de la fiche. Les boutons ont un plancher (`maxi(12, …)`), pas les `D.text` / `Kit.texte`. Correction : plancher commun pour le texte du tableau, filtres « Indemnité : Tout… » tronqués à 1280.
- **Pied** : il manque les raccourcis de la maquette (choisir, Entrée fiche, A approcher, Espace suivre, Maj Espace comparer) ; seuls « I » et « Échap » sont présents. Correction : les ajouter et les relier (ou ne pas les afficher).
- **Fil d'Ariane** : « Alder Fen XV / Recrutement » sans l'onglet courant (maquette : « / Besoins du club »).
- **Mini-fiche** : conforme à la maquette (survol), mais le bouton « Approcher le joueur · A » de la maquette n'est pas vérifié dans `mini_fiche.gd`.
- **Coût** : le lien « Suivre cette piste » passe à la 3e ligne et touche le bas du bloc à 1920 et 1280. Correction : élargir le bloc ou mettre les liens sur deux lignes sûres. Le « +187 200 € · +2,1 % » (part de la masse salariale) de la maquette est absent : ligne omise faute de donnée, acceptable.
- **Sous-pages adoptées** : elles gardent le style des anciennes fenêtres (cartes à rayon 6, cadres, or `C.GOLD` dans `contract_negotiation.gd` : « RECRUTEMENT », statut, prime), contraire à l'or réservé à Continuer et à l'héritage, et aux rayons 0. À CORRIGER (non vérifié par capture).
- **Coque à 1280** (hors écran, à signaler) : un filet rouge traverse « d'accessi… 13e » dans l'en-tête du rail ; le pied de la coque répète les raccourcis déjà dans la page.

AVIS
- Titre, tuiles de budget, cartes de besoin, barre de coût à légende en mots + hachure, « Hors budget » en mots et rouge : fidèles à la maquette.
- « Un écran par offre » : l'offre au joueur est bien une page. Pas de contradiction avec `decisions-leo-20261119.md` ; ce flux ne prévoit pas encore l'étape « offre au club vendeur » mais le point d'entrée est prêt. Les confirmations d'argent restantes (B) sont les seules entorses à « on confirme sur l'écran, jamais dans une petite fenêtre ».
- Le nom de club d'origine et le drapeau viennent des données ; rien d'inventé.
