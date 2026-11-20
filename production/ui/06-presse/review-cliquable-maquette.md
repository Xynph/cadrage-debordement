# Relecture adverse : écran 06 Presse (cliquabilité, fenêtres, fidélité maquette)

Lecture seule : `ui/immersive08/press_canvas.gd` (+ `ui/press_view.gd` pour le repli), `entity_link.gd`, `mini_fiche.gd`, `components.gd`, `shell.gd`, captures v3 (1920) et v4 (1280). Le Godot n'a pas été lancé. La conférence « questions ouvertes » n'a jamais été capturée : jugée sur le code seul.

## A. Cliquabilité

| Élément (aspect) | Effet du clic (code) | Verdict |
|---|---|---|
| Onglets Journal / Conférence / Historique / Portraits | `_select` : change le contenu en place | OK |
| Liste déroulante de division (OptionButton) | change la division du Journal, remonte la page | OK (menu déroulant autorisé). Masquée hors Journal dans le code (`_mark_tabs`) ; les captures v3 1920 la montrent encore sur Conférence/Historique/Portraits, la v4 1280 non : probablement corrigé, à reconfirmer |
| « Voir le classement → » | `app._navigate("Classements")` | OK |
| Nom de club (résultats, score de la coupure, indispos, historique) | fiche du club via `Link.bind` ; club du manager = écran Club ; si non disponible = texte gris non souligné | OK |
| Score d'un résultat « 20 – 16 » (lien souligné au survol) | choisit la coupure de journal en place (`press_article`) | OK (agit en place ; la ligne choisie est marquée par fond + barre) |
| Nom de joueur (Indisponibilités) | fiche complète + mini-fiche au survol/touche I (Control, pas Window) ; non lié = texte plain | OK pour l'effectif ; AVIS : joueurs des autres clubs en texte plain (pas de fiche trouvée), cohérent mais Léo attend une fiche partout |
| Nom de journaliste (Conférence, Retour, Historique) | ouvre Portraits sur ce journaliste, en place | OK |
| Ligne de l'Historique (bouton pleine ligne) | affiche l'échange à droite | OK |
| Ligne de Portraits (bouton) | affiche le journaliste | OK |
| « Les trois derniers échanges » (liens multi-lignes) | bascule vers Historique sur cet échange | OK |
| « Historique → » / « Portraits → » (colonne gauche) | onglets 2 / 3 | OK |
| « Y aller » / « Envoyer l'adjoint » | commande `press_policy` ; coche + soulignement sur l'actif ; clic sur l'actif = rien | AVIS : l'option active a l'aspect d'un lien mais ne fait rien (état « choisi », marqué par la coche, acceptable) |
| « Préparer la conférence → » (invité) / « Ouvrir la Réception → » (non invité) | onglet Conférence / écran Réception | OK |
| « Consulter le compte rendu → » (barre tenue) | onglet Conférence | OK |
| « Revenir au courrier → », « Ouvrir l'invitation → » | Réception | OK |
| Réponses de conférence (5 tons par question) | sélection en place, coche + barre gauche | OK (non couleur seule) |
| « Publier mes réponses » | commande `press_conference` ; désactivé tant qu'une question est sans réponse, sans dire pourquoi | À CORRIGER (voir C-4) |
| « Laisser Gabi répondre → » | commande `press_delegate` directe, sans confirmation ni conséquence visible | À CORRIGER (voir C-5) |
| Tuiles de la barre « conférence tenue » (« 75 → 81 », +6) | inertes, aucun style de lien | AVIS : pas de faux lien, mais gros chiffres où l'on s'attend à un lien (Direction, Médias, Supporters, Pression) ; les relier à Club / Finances / Classements ou à l'explication serait plus riche |
| Jauges Médias / Supporters / Pression, gros compteurs « 4 questions / 1 brouillon » | inertes, sans style de lien | OK (non cliquables à l'œil) ; compteurs « en brouillon » non rafraîchis après un choix (seul le texte `draft_status` l'est) : AVIS |
| Titre « Question 01 », badge « HA », barre de relation, en-têtes de colonnes | inertes | OK |

Aucun « RIEN » sur un élément d'aspect cliquable : pas de BLOQUANT en A.

## B. Petites fenêtres

Aucun `Window`, `AcceptDialog`, `ConfirmationDialog` ni `PopupPanel` dans `press_canvas.gd` ni `press_view.gd`. La mini-fiche est un Control placé sur l'écran. Seul popup : la liste de la division (autorisé).
Infobulles système restantes : « notice » des conférences ordinaires et « raison » de la délégation (`tooltip_text`). Ce ne sont pas des fenêtres cliquables, mais l'information n'est lisible qu'à la souris (voir C-6).

Repli sous 1280×720 : `shell._dedicated_page` envoie « Presse » à l'ancien `PressViews.build` si la taille est < `RICH_MIN_SIZE` (1280×720). Cet ancien affichage garde l'or (`G.GOLD` sur « Pression », sur les questions), l'ancien style papier/boutons arrondis (`G.button`, `G.card`), aucun lien club/joueur/journaliste, des `tooltip_text` sur les réponses. Mais `project.godot` impose `window/size/min_width=1280` et `min_height=720`, et Presse figure dans `RICH_FROM_720P` : la capture v4 1280×720 montre bien la nouvelle vue. Donc inaccessible en usage normal : AVIS (pas BLOQUANT), à protéger ou supprimer (voir C-9).

## C. Fidélité à la maquette (variante 3 + barre « tenue » de la 2 + verdict de pression)

### BLOQUANT
Aucun.

### À CORRIGER
1. **Conférence ouverte : jamais capturée.** À capturer avant fusion (1920 et 1280), avec 4 questions : (a) hauteur réelle des réponses (boutons à `autowrap` multi-lignes avec `custom_minimum_size.y`, risque de texte tronqué ou chevauché) ; (b) lisibilité des cartes `RAISED` avec réponses `PANEL` (hiérarchie inversée : la réponse est plus sombre que sa carte) ; (c) Publier visible sans défilement excessif.
2. **Entrée rail sans courrier = détour.** Si la conférence est ouverte mais que le manager arrive par le rail, il ne voit pas « Préparer la conférence » ni les questions : « UNE CONFÉRENCE T'ATTEND » puis « Ouvrir la Réception → ». Aucun clic mort, mais la cible de la fiche UX (§6 : le bouton mène aux questions quand la conférence est ouverte) n'est pas tenue. Attendu : afficher les questions depuis Presse quelle que soit l'entrée (le brouillon et `invitationId` suffisent).
3. **Blocs de la maquette Journal absents** : tableaux de titres de presse (« Ce qu'on dit d'Alder Fen » avec journal/titre/ton, « Le reste de la division ») et « Prochaine journée » ; colonnes de corps d'article. Les titres de presse sont le cœur de l'onglet Journal (UX §5 « titres de presse »). Si la donnée n'existe pas côté moteur, omission acceptable (rien d'inventé) ; sinon les brancher. À l'inverse l'écran ajoute « Indisponibilités », absentes de la maquette : à garder si utile.
4. **« Publier mes réponses » désactivé sans explication.** Bouton désactivé (cadre complet fin + texte pâle) et muet. Attendu : une ligne visible « Il reste n question(s) sans réponse » à côté, et le style désactivé sans cadre complet (art bible : aucun cadre complet).
5. **« Laisser Gabi répondre → » sans garde-fou.** Une action lourde (Gabi répond à la place du manager) part au premier clic, sans conséquence affichée ; la raison d'indisponibilité n'est qu'en infobulle. Attendu : conséquence écrite en clair sous le lien, confirmation en ligne (pas de fenêtre).
6. **Infobulles porteuses d'information** : la « notice » des conférences ordinaires (ce que change « Envoyer l'adjoint ») n'est que dans un `tooltip_text`. Attendu : une ligne de texte visible sous le réglage (clavier/manette, S2/K1).
7. **Cause des indicateurs absente.** La maquette sous chaque jauge de « Ton image » donne la raison (« 2 après la défaite à Greycliff », « 3 · deux victoires… »). L'implémentation n'affiche que valeur + mot. Si le moteur ne la fournit pas : omission acceptable mais perte principale de la variante 3 (« Synthèse ») ; sinon la brancher.
8. **Carte « Gabi » du conseil de presse absente** (maquette : citation de Gabi sous la mémoire des échanges). La fiche UX (S2) exige le conseil en texte. Donnée à confirmer ; sinon omission.
9. **Ancien affichage jamais retiré** (`press_view.gd` : or, papier, arrondis). Inaccessible aujourd'hui (min 1280×720), mais un test doit l'attester (`PressCanvasTab0` présent à 1280×720) ou l'ancien build doit être réduit au minimum (texte neutre) pour ne pas ressortir si le seuil change.
10. **Portraits : colonne « RELATION » vide.** L'en-tête « Relation » est aligné à droite, mais les valeurs (+0, +1, −2, −5) sont collées au nom dans la même chaîne. Attendu : vraie colonne (valeur + mot), comme le reste des tableaux.
11. **Libellés incohérents** : la barre tenue dit « Direction », l'onglet Conférence (Retour) dit « Confiance » pour la même mesure (`trust`). Choisir un seul mot.
12. **Retour de la dernière conférence au-dessus des questions ouvertes** : `_outcome_block` n'est pas filtré par saison ni par état ; avec des questions à traiter il pousse les questions sous le pli. Attendu : le replier (ou le déplacer en bas) quand une conférence est ouverte.
13. **Journal 1920 : déséquilibre vertical.** La coupure s'arrête à mi-hauteur, laissant un grand vide sous elle pendant que la colonne de droite défile (scrollbar, indispos coupées). Attendu : remplir (titres de presse, point 3) ou aligner les hauteurs.
14. **Sous-titre « Troisième Mi-Temps. » en x fixe (660)** : flotte loin du titre à 1920 (≈ 290 px de vide) alors que la maquette le colle au titre. Le placer après le titre (ou dans la même ligne).

### AVIS
- Focus des réponses et du sélecteur : cadre complet de 2 px (`set_border_width_all(2)`), contraire à « aucun cadre complet » ; défendable pour l'accessibilité, à trancher avec la DA (souligné épais comme les liens ?).
- Tuiles de la barre « tenue » et compteurs de la salle de presse : inertes ; pistes de liens plus haut.
- Barre « conférence tenue » : vide entre le bouton et la fin de la barre (hauteur 196 pour ~120 de contenu), sensible à 1920.
- 1280×720 : textes de la colonne gauche et des tableaux collés au plancher 12 px (labels 16-17 u × 0,5) ; lisible mais serré ; en-tête du rail (« Division d'accession a… » barré par le filet) et « Sauvegarder / Ctrl S » qui déborde viennent de la coque, pas de Presse.
- Touches 1-4 pour les onglets : la maquette les affiche (« 1-4 Onglets ») ; la coque réserve 1-9 aux menus ; aucun badge de numéro sur les onglets. Écart assumé à documenter.
- Aucun nom ni donnée figée : titre de coupure, chapeau et classement dérivés du résultat réel ; repli « La Voix du club » si aucun journaliste ; « Troisième Mi-Temps. » est le nom de la rubrique (OK).
- Charte respectée sur le reste : rayons 0, pas d'ombre ni dégradé, un seul ivoire plein (cédé à « Publier mes réponses » dans l'onglet Conférence), or absent, pression en verdict à trois paliers avec icône + mot + valeur + légende des bornes.
