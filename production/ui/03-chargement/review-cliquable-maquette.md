# Auto-relecture : écran 03 Chargement (20/11/2026)

Maquettes : `03-chargement-1` (panneau, courts), `-2` (ovale du ballon, Continuer), `-3` (le stade, longs). Code : `ui/command_wait_overlay.gd`, `ui/continue_progress.gd`. Test : `tests/godot-chargement-da.cjs`. Captures : `temp/da-accueil-chargement/apercu-chargement-<variante>-<1920|1280>.png`.

## A. Cliquabilité

| Élément | Effet du clic | Verdict |
|---|---|---|
| Panneau : « Arrêter → » (après 20 s) | arrêt réel seulement si le contexte porte `cancellable` (signal `stop_requested`) ; sinon grisé, curseur normal, raison écrite dessous (« Arrêt impossible : … ») | OK (aucun faux bouton) |
| Panneau : cartes de date, barre, conseil | rien, et rien ne ressemble à un lien (texte et dessin plats) | OK |
| Stade : « Anecdote suivante → » | change la note affichée (aussi Entrée, annoncé « Entrée ») | OK |
| Stade : légende du lieu, logo, titre, barre en segments | rien, sans aspect de lien | OK |
| Ovale : « Arrêter → » | arrête au jour en cours (`stop_requested`, Échap pareil) | OK |
| Ovale : « Fermer → » (motif d'arrêt) | ferme l'écran tout de suite | OK |
| Ovale : liste des jours (✓ ▸ ·), cartes de date, anneau, « JOUR n SUR m » | rien ; lignes sans survol ni flèche, non cliquables d'apparence | OK (AVIS : un clic sur un jour pourrait ouvrir le calendrier, mais l'écran est bloquant pendant l'avance) |
| Nom de joueur | aucun nom de joueur dans ces écrans | sans objet |

## B. Petites fenêtres

Aucune `Window`, `AcceptDialog`, `PopupPanel` dans les deux scripts ni ouverte par un clic (le test balaie les `Window` visibles après chaque variante). Les infobulles sont des `tooltip_text` natifs.

## C. Fidélité à la maquette

BLOQUANT : aucun.

À CORRIGER (faits) :
- Panneau : conseil de Gabi sans portrait (ni avatar rond dans l'ovale) — le portrait de Gabi est un rendu 3D du guide, non réutilisable sans le médaillon ; le titre « LE CONSEIL DE GABI » et le liseré incliné portent la signature. Écart conservé (AVIS ci-dessous).
- Stade : le nom du club n'est pas encore lu à la création de carrière (le modèle n'existe pas avant la réponse du moteur) : la ligne « club · division · saison » et le lieu s'affichent pour tous les chargements une fois la carrière en mémoire, et sont omis à la toute première création. Jamais inventés.

AVIS :
- Aucun pourcentage ni étape réels n'existent hors Continuer : la barre du stade est indéterminée (bloc qui glisse, fixe en mouvements réduits) ; la maquette montre « Étape 3 sur 5 » et « 60 % » (exemples) : `set_progress(valeur, libellé)` est prêt pour le jour où le moteur en fournira.
- La maquette du stade montre une photo de stade ; la banque d'images (`chargement-0N`) tourne sur sa graine : le décor varie selon l'image tirée.
- Ovale : l'anneau est un peu plus petit que la maquette sur 1280×720 (≈ 330 px) pour garder les textes ≥ 12 px ; la liste est limitée à 4-5 lignes (fenêtre autour du jour en cours, plus l'arrêt prévu).
- Panneau : cartes de date et titre alignés comme la maquette ; la ligne « Échap : arrêter » n'existe pas (Échap n'arrête que Continuer).
- Couleurs : 100 % via `Charte` (contrôlé par le test sur les sources), or uniquement dans l'anneau de Continuer, aucun rayon, aucune ombre, aucun dégradé.
