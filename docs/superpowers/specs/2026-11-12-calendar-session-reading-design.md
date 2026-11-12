# Consulter une séance publiée par son identifiant

## Intention et choix de l’intégrateur

La demande utilisateur prévoit « Séance → entraînement concerné », une consultation sans commande et un retour qui conserve le contexte. Le calendrier projette déjà des séances identifiées et un programme du jour détaillé. L’autorisation permanente de travailler sans questions s’applique à ce petit adaptateur.

Approche retenue : réutiliser le programme du jour, sélectionner la date de la séance publique exacte et focaliser sa carte. Une route vers les réglages de la semaine courante ne cible pas le créneau demandé. Un nouveau compte rendu historique demanderait des champs et un écran qui n’existent pas ; il reste hors périmètre.

## Contrat

- Cible commune `kind=session`, `id` égal à l’identifiant projeté, route de consultation Calendrier.
- Une seule séance correspondante dans `model.calendarPlanning.sessions`, avec ID non vide et date ISO valide. ID inconnu, ambigu, absent ou séance mal datée : refus sans navigation.
- Lecture du programme existant, filtre `all` pour rendre la séance visible, date sélectionnée exacte et focus sur le bouton de la séance dans le détail du jour.
- Capturer l’origine avant mutation puis définir `calendar_table=false` : depuis la vue tableau, le programme ne serait sinon pas construit. Back restaure cette valeur d’origine.
- Noms de contrôles déterministes avec préfixes distincts grille/semaine/détail et hash interne de l’ID pour éviter les collisions de noms assainis. Ni ID ni hash affiché au joueur.
- Chaque bouton porte `entity_kind=session`, `entity_id=<ID brut projeté>`. Noms : `CalendarSessionGridLink_`, `CalendarWeekSessionLink_` ou `CalendarSessionDetail_`, suivis du SHA256 de l’ID. `Competition.session_focus_name(id)` fournit le nom du détail ; le test observe l’ID et le focus, sans utiliser ce helper pour calculer son attente.
- Les libellés de séance de la grille et du contexte hebdomadaire deviennent des liens seulement si la cible existe. Les données sans destination valide restent des libellés.
- Un clic répété sur la même destination ne crée pas de dialogue ni d’entrée d’historique supplémentaire. Back restitue mois, date, filtre, vue, scroll et focus de départ.
- Le choix non appliqué d’une semaine type reste un brouillon UI lors de l’ouverture d’une séance et du retour. Restituer ses identifiants publics ne déclenche ni signal d’application ni commande. Un modèle supprimé, déjà actif ou associé à un autre prochain match invalide ce brouillon ; une nouvelle carrière le réinitialise.
- Deux séances du même jour restent distinctes par ID. Une sélection manuelle d’un autre jour invalide la cible séance active ; les gardes s’appliquent même à une cible déjà ouverte.
- Les gardes communes restent applicables. Aucun appel métier, sauvegarde sportive, RNG ou horloge modifié pendant la consultation.
- Une date passée décrit un créneau passé ; elle ne prouve ni séance exécutée, ni charge, ni progression. Aucune donnée cachée ni estimation nouvelle.

## Réutilisation et limites

`competition_canvas.gd` valide la projection et ouvre le calendrier ; `month_calendar.gd` garde son programme et ses styles ; `navigation_controller.gd` reste la propriété de navigation_core. Aucun moteur, calendrier produit, donnée ou rendu 3D réservé à Claude n’est modifié. La tête `76077ed3` et ses campagnes restent figées.

La recette utilise une vraie carrière Common 0 et ses créneaux publiés. Les cas mal formés utilisent une copie de projection isolée explicitement signalée. Elle vérifie clic, clavier, garde obligatoire réelle, retour avec contexte et invariance du profil/modèle/bridge/RNG/horloge. Audio Dummy, mute précoce et demandes/démarrages/identifiant vocal nuls. Captures réelles 2560×1440 et contrôles des tailles prises en charge ; aucune recette Windows.
