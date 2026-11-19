# Relecture adverse — Réception (cliquabilité et fidélité à la maquette)

Phase 4 /team-ui, rôles ux-designer puis art-director. Lecture seule : code de `reception_canvas.gd` (branche claude/da-reception-20261119), captures `reception-1920.png` et `reception-1280.png`, maquette `05-reception-1.png` + filtre « Sujet » de `05-reception-3.png`, charte §3, §4.2, §7. Rien n'a été lancé ; les effets de clic sont lus dans le code (pas observés dans Godot).

Lecture de la règle de Léo : tout ce qui a l'air cliquable doit s'ouvrir ou agir, sinon il doit être visiblement inerte.

## A. Cliquabilité

Fenêtres : aucun `Window`, `AcceptDialog`, `Popup` ou `PopupPanel` créé par l'écran. Seul le menu `OptionButton` « Sujet » ouvre un `PopupMenu` natif (exception « menu déroulant » admise). La mini-fiche joueur est un calque de la coque (`MiniFiche`), pas une fenêtre. Tous les liens passent par `navigation_controller.open_entity` avec `source_window = null`.

| Élément (capture) | Effet du clic (code) | Verdict |
| --- | --- | --- |
| Titre « Réception. » | Label `D.text`, `mouse_filter` IGNORE : RIEN. Non souligné, non coloré : ne ressemble pas à un lien | OK (inerte, lisible comme tel) |
| Surtitre « LE COURRIER DE TA CARRIÈRE » | Label inerte | OK |
| « 57 non lus · 13 à faire · 2 urgences » | Label inerte, petit, gris. Mais redondant avec les puces « Non lus 57 » et « À faire 13 » juste dessous, qui sont actives : un joueur qui clique le nombre du titre ne gagne rien | OK mais fragile (voir B-5) |
| Puce « Tous » | Agit en place : dossier Tous, filtre all, redessine | OK |
| Puce « Non lus 57 » | Agit en place : dossier 1 (non lus) | OK |
| Puce « À faire 13 » | Agit en place : filtre `todo`, désélectionne le courrier | OK |
| Menu « Sujet ▾ » | `OptionButton` : ouvre un menu natif (exception admise), filtre par sujet, favoris, archives, en attente, infos | OK sur l'effet ; skin à corriger (B-6) |
| En-tête de jour « À TRAITER EN PRIORITÉ », « HIER », « JEU. 24 SEPT. » | `MarginContainer` + label, IGNORE : RIEN, mais ce sont de petits titres de section sans affordance | OK |
| Ligne de liste (icône, « SERVICE · expéditeur », objet, heure, étiquette) | Bouton entier : sélectionne, marque lu (hors dossier Non lus), redessine. Tous les enfants sont IGNORE (`D.rect`, `D.text`, `C.icon`) : aucune zone morte à l'intérieur de la ligne | OK |
| Pastille ovale non lu | Décor IGNORE, clic = clic de ligne | OK |
| Icône de service | Décor IGNORE, info-bulle seulement, clic = clic de ligne | OK |
| Étoile favori dans la ligne | Décor IGNORE, clic = clic de ligne | OK |
| Étiquette « URGENT / À FAIRE · avant le … » (encadrée) | Décor IGNORE, clic = clic de ligne. Cadre complet, donc a l'air d'un bouton alors qu'il ne fait que sélectionner la ligne | À CORRIGER léger (B-14) |
| Badge « ×N » (courriers regroupés) | Décor IGNORE, clic = clic de ligne (ouvre le premier courrier du lot) | OK, à surveiller (AVIS A1) |
| Entête de fil « ▾ Titre · N courriers » | Agit en place : déplie / replie | OK |
| Barre de défilement de la liste | Natif | OK |
| « Sélections » (grand texte, en-tête de la lettre) | `D.text`, IGNORE : RIEN. Gras ivoire 23 px, même poids que les noms-liens ailleurs | OK mais redondant (B-9) |
| « Sélections · lun. 21 sept., 07:48 » | Label inerte | OK |
| « Favori ☆ » | Agit en place (marque tous les membres, redessine) | OK |
| « Lu ✉ » / « Non lu » | Agit en place | OK |
| « Archiver ✓ » | Agit en place, redessine le dossier | OK |
| Titre de la lettre « Retour des internationaux : 1 joueur » | `C.wrap` label IGNORE : RIEN. Non souligné | OK |
| Lien « Shaun BOWKER » (souligné, brun d'encre) | `meta_clicked` : `open_related` puis `open_entity(player)` : fiche joueur dans Effectif (ou marché si absent de l'effectif). Lien rendu seulement si `Link.available` (pas de lien mort). Survol : mini-fiche dans la coque | OK |
| Bouton « Voir l'effectif → » | `_open_international` : `_navigate("Effectif")` (liste générale, pas la fiche de Bowker). Mémorise la ligne pour le retour | OK ; destination générique (AVIS A2) |
| « Courrier suivant non lu → » (pied) | `_open_next`. **Désactivé** quand `next_unread` rend le courrier déjà ouvert. À l'ouverture de l'écran le premier courrier est sélectionné sans être marqué lu (point doré présent dans la capture) : `next_unread` rend donc ce même courrier et le bouton est grisé alors que 57 courriers sont non lus | **À CORRIGER** : étiquette qui promet une action, état grisé incohérent (B-2) |
| « EXPÉDITEUR / SERVICE / REÇU / ÉTAT » + valeurs | Labels `D.text`, IGNORE : RIEN, aucune affordance (petites capitales grises, valeurs ivoire) | OK (inerte et lisible comme tel) |
| Barre « CONCERNÉ » : nom du joueur lié | `Link.name_link` : bouton plat qui ouvre la fiche. **Au repos il est identique à un texte** (ivoire gras, soulignement or seulement au survol). Si la destination manque, retombe sur un label strictement identique : le joueur ne peut pas distinguer lien et texte | **À CORRIGER** (B-3) |
| Barre « CONCERNÉ » : club « Nom · 3e » | Idem : fiche du club, même absence d'affordance au repos | À CORRIGER (B-3) |
| Barre « CONCERNÉ » : joueurs en fin de contrat (puces) | Idem, fiche joueur + mini-fiche | À CORRIGER (B-3) |
| Tableau d'infirmerie (courrier médical) : noms des joueurs, lignes | `C.label` IGNORE ; la ligne porte `set_meta("player_id")` mais aucun signal : **RIEN**. Un tableau de joueurs avec noms en gras ivoire invite au clic | **BLOQUANT** (B-1) |
| « BILAN DE L'INFIRMERIE », en-têtes de colonnes | Labels inertes | OK |
| Pièces liées : « Rencontre · adversaire », « Calendrier · date » | `Link.button` : ouvre la rencontre ou la date | OK (mais bouton encadré, B-7) |
| Pièces liées : « Dossier de préparation · … » | `_open_related` : `_navigate("Préparation")` | OK |
| « PRIORITÉS DE LA SEMAINE » (3 boutons) | `_navigate(route)` ou `open_training` | OK |
| Cartes de réponse A/B/C | Un clic CHOISIT (état en place, rien ne part). Carte indisponible : désactivée avec raison affichée | OK |
| « Choisis une réponse » (désactivé) | Désactivé tant qu'aucune carte n'est choisie, texte explicatif à côté | OK |
| « Envoyer la réponse X » | Commande moteur `club_mail_reply` | OK |
| « Annuler » | Efface le choix en place | OK |
| « Ouvrir · Écran » (courrier du club) | `ClubMail.open_screen` : route ciblée. Un écran inconnu retombe sur « Bureau » sans le dire | OK (AVIS A3) |
| « Ouvrir la conférence / Consulter le compte rendu » | `_open_press_invitation` ; désactivé avec raison en info-bulle | OK |
| Bascule « envoyer Gabi aux conférences ordinaires » | Commande `press_policy`, bascule en place, légende mise à jour | OK (AVIS A4) |
| « Ouvrir l'entretien / l'invitation » | `contextual_director.open_invitation` ; désactivé avec info-bulle si rendez-vous obligatoire | OK |
| « Recaler / Conserver la préparation » | Commande `calendar_mail_decide` | OK |
| « OUVRIR LA CONFÉRENCE DE PRESSE » (notice de blocage) | `_open_press_conference` | OK |
| Fond de la lettre (papier), zone vide sous « Voir l'effectif » | Panneaux inertes, pas d'affordance | OK |
| Sidebar badge « 57 » et fil d'Ariane « Réception / Courrier » | Hors de ce fichier (coque). Non vérifiés ici ; le fil d'Ariane a l'air de segments cliquables | À VÉRIFIER dans `shell.gd` |

### Notes A (avis)
- A1. « ×N » : le clic n'ouvre que le premier courrier du lot. Prévoir un point d'accès aux autres (la lettre doit dire « 3 courriers regroupés » ou le fil doit se déplier), sinon un lot a l'air d'un seul courrier.
- A2. « Voir l'effectif » d'un retour d'international pourrait ouvrir directement la fiche du joueur nommé (le lien du texte le fait déjà).
- A3. `ClubMail.caption` renvoie « Ouvrir · Bureau » pour un `ecran` inconnu : un clic mène alors à un écran sans rapport. Journaliser ce cas.
- A4. La bascule de conférence change un réglage durable en un clic, sans état « actuel » lisible : la légende est une phrase d'action, pas un état.

## B. Fidélité à la maquette

### BLOQUANT
- B-1. Tableau d'infirmerie : noms de joueurs inertes (voir A). Correction : `Link.name_link` pour la colonne JOUEUR (même composant que « CONCERNÉ »), ligne entière active vers la fiche, mini-fiche au survol ; sinon colonne en gris et sans gras.
- B-2. Bouton « Courrier suivant non lu » grisé alors que des non lus existent (voir A). Correction : à l'ouverture de l'écran, marquer lu le courrier auto-sélectionné (ou faire pointer `next_unread` au-delà du courrier affiché), activer le bouton ; seulement quand il n'y a vraiment plus de non lu, afficher « Tout est lu » non encadré en gris.

### À CORRIGER
- B-3. Noms-liens de « CONCERNÉ » sans affordance au repos et indiscernables du texte de repli. Correction : soulignement fin ivoire au repos pour les liens actifs (comme le lien de la lettre), texte non souligné en gris pour l'inerte.
- B-4. Titre d'écran. Maquette : « RÉCEPTION. » en capitales Barlow Condensed ExtraBold Italic, compteurs sur la même ligne, « ! 1 urgent » en rouge ; pas de surtitre. Code : « Réception. » en casse mixte, non italique, surtitre « LE COURRIER DE TA CARRIÈRE » en plus, compteurs sous le titre en gris uniforme. Correction : `.to_upper()` + police titre italique, compteurs à droite du titre, partie urgence en rouge alerte, supprimer le surtitre.
- B-5. Maquette : en haut à droite « 14 messages cette semaine · 86 archivés » et lien texte « Tout marquer comme lu → ». Absents ; `mark_all_read` existe mais aucun bouton ne l'appelle. Correction : ajouter le lien texte (ivoire + flèche, sans cadre) branché sur `mark_all_read` puis redessiner, et retirer la répétition des compteurs entre titre et puces, ou la rendre cliquable.
- B-6. Menu « Sujet » : l'`OptionButton` n'a aucun style propre ; la capture montre un fond bleu-vert hors palette, un double chevron (« Sujet ▾ » écrit dans le texte plus la flèche native). Maquette : « Sujet : tous ▾ » discret, bordure fine. Correction : styleboxes normal/hover/pressed/focus de la charte, rayon 0, texte « Sujet : tous » sans le ▾ du texte, thème du `PopupMenu` aux couleurs PANNEAU / IVOIRE.
- B-7. Boutons Favori / Lu / Archiver : `D.button` non primaire donne un cadre complet à bords arrondis (rayon 6, bordure FAINT). Maquette et charte §7 : liens texte ivoire avec petit symbole (☆ ✉ ✓), sans cadre, alignés à droite sur la ligne de l'expéditeur. Même défaut sur les pièces liées, « PRIORITÉS DE LA SEMAINE », « Conserver la préparation », bascule de conférence, « Courrier suivant non lu » (pied), et les 4 pastilles de réponse. Correction : un style « lien » commun (fond transparent, hover soulignement, flèche), appliqué à tout bouton non principal.
- B-8. « Voir l'effectif » : rempli de la couleur du club, bords arrondis. Charte §7 : un seul ivoire plein par écran pour l'action principale, encre sur ivoire, rayon 0, comme « Envoyer la réponse » (déjà correct dans `_send_row`). Correction : mêmes styleboxes que `_send_row` pour `InboxOpen*` primaire ; « Recaler la préparation » de même. L'or reste réservé à Continuer.
- B-9. En-tête de lettre. Maquette : petite ligne « CLUB · SERVICE · date » en capitales espacées, puis la lettre porte sa propre en-tête (« ALDER FEN XV · SERVICE », lieu et date) et une signature (nom + fonction). Code : nom d'expéditeur en gras 23 px, sous-ligne de service, et le pied répète EXPÉDITEUR / SERVICE / REÇU (sur la capture « Sélections » apparaît 3 fois). Correction : en-tête de la lettre selon la maquette, supprimer la répétition (garder ÉTAT et « Courrier suivant » en pied, une ligne comme la maquette), ajouter la signature.
- B-10. Titre de la lettre : maquette en capitales italiques condensées, code en casse mixte (italique correct). Correction : `.to_upper()` sur `InboxTitle`, soit « RETOUR DES INTERNATIONAUX : 1 JOUEUR ».
- B-11. Pied : maquette sur une ligne (« Expéditeur … Service … Reçu … État non lu → lu ») avec « Courrier suivant non lu → Espace » en lien texte à droite. Code : deux lignes (libellé gris + valeur), bouton encadré, et à 1280 px le bouton touche le bas du panneau (bord rogné). Correction : ligne unique, bouton sans cadre, marge basse.
- B-12. Cartes de réponse : cadre complet (bordure LINE, 2 px ivoire si choisie). Maquette : cartes sans cadre, la choisie marquée par un filet gauche et « ✓ CHOISIE » ; « RÉPONSE A · RECOMMANDÉE PAR GABI » absent, de même que le bloc Gabi (portrait + commentaire) sous les boutons. Correction : cartes sur fond PANNEAU sans bordure, filet gauche, libellé « RÉPONSE A/B/C » en capitales espacées ; remonter la recommandation de Gabi si la donnée existe, sinon le noter comme écart assumé à Léo.
- B-13. Puces de filtre : « Tous » rempli de la couleur du club (rouille). Maquette : bordure ivoire fine pour l'actif, rien d'autre. Correction : actif = bordure et texte ivoire, inactif = bordure FILET ; pas de remplissage club (réservé à la marque du club ailleurs).
- B-14. Étiquettes « URGENT / À FAIRE · avant … » dans la liste : encadrées en entier. Maquette : « ! URGENT » rouge souligné, « À FAIRE · AVANT LE 19/11 » sur fond plein sombre sans cadre. Correction : fond plein sombre (PANNEAU_2), texte capitales, plus de bordure ; urgent = texte rouge + soulignement.
- B-15. Liste : maquette à 3 lignes par courrier (« SERVICE Expéditeur » avec nom en casse normale, objet, étiquette) ; code met « SERVICE · expéditeur » en capitales grises 17 px, ce qui est plus dense mais écarte le nom de l'expéditeur de la lecture rapide (« Le médecin du club »). Correction : service en petites capitales, expéditeur en casse normale après un espace (pas de point médian).

### AVIS
- Bandeau latéral (coque, hors périmètre) : « Division d'accession anglaise · 13e » est barré à 1280 px et « Sauvegarder / Ctrl S » est rogné : à signaler à qui possède la coque.
- Ordre de la section « À TRAITER EN PRIORITÉ » : 07:48, 07:40, 07:44 (non chronologique) ; l'ordre est sans doute celui des priorités, mais ça se lit comme une erreur de tri. Afficher l'heure uniquement si l'ordre la suit, ou trier à l'intérieur de la section.
- Hauteur de ligne de liste avec étiquette (104) contre 80 sans : conforme à la maquette ; la capture 1920 laisse 3 lignes visibles par défaut à moins, rien à changer.
- À confirmer en jeu (non observable en lecture seule) : survol d'un lien de la lettre (mini-fiche) et menu « Sujet » ouvert.
