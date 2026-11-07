# Coach natif — réception du 7 novembre 2026

Le module `native/godot/guide/` propose une visite guidée en quinze étapes stables et une aide de l'écran courant. L'accueil reste compact et silencieux jusqu'au choix explicite du joueur. Les pages couvrent choix du club, bureau, effectif, feuille, entraînement, tactique, match, résultat, calendrier, classements, finances, recrutement, territoire et packs. Les répliques courtes proposent une première lecture concrète avec le ton d'un ancien coach. Le guide ne commande jamais le moteur : il ne modifie ni sélection, entraînement, consignes, pack, sauvegarde sportive ou résultat. Le bouton Ouvrir utilise seulement la navigation de l'application, à la demande du joueur.

## Contrat d'intégration

Le parent conserve une seule instance hors de `root_content`, recréé à chaque navigation :

```gdscript
var coach: Control
var coach_reserved := 0.0

func setup_coach() -> void:
    coach = load("res://guide/coach_guide.gd").new()
    add_child(coach)
    coach.reserved_height_changed.connect(func(height: float):
        coach_reserved = height
        reserve_coach_space(height)
    )
    coach.setup(self)
```

Appeler `coach.refresh()` après tout changement de route ou réception de modèle, y compris les ticks. Le module évite de reparler sur un snapshot identique et surveille aussi les états attente/direct/dialogue entre ces appels. Appeler `coach.toggle()` pour l'action d'aide des paramètres, `coach.open_tour()` pour une visite et `coach.open_help()` pour l'écran courant. `close()` réduit le panneau et coupe la voix ; `destroy()` arrête la parole, libère les callbacks TTS et retire le module à la prochaine frame. Une fermeture de l'application doit appeler ce nettoyage avant d'arrêter le moteur.

La réservation émise vaut 80 px compact, 280 px développé et 360 px avec Options ouvertes ; elle vaut zéro quand la désactivation est enregistrée. Le panneau lui-même mesure 60, 260 ou 340 px, avec marges. Une erreur ajoute un bandeau indépendant des Options et 64 px réservés : elle reste visible lorsque les Options sont fermées ou le guide réduit. Si la désactivation échoue sur le disque, le coach se coupe pour la session mais conserve une barre compacte expliquant que ce réglage n'est pas enregistré et qu'il pourra revenir au prochain démarrage. La barre permet une réactivation explicite, sans modale ni répétition à chaque snapshot. Le parent doit réappliquer cette réservation après chaque reconstruction de la page, et rendre défilable le contenu qui ne tient plus. Modifier uniquement `root_content.offset_bottom` ne suffit pas sur les écrans dont les enfants imposent une hauteur minimale, notamment Match à 1280 × 800. Garder accessibles sidebar, confirmations et commandes de match est une condition de réception de l'intégration. L'ouverture ne vole pas le focus et n'intercepte ni Escape ni Entrée.

Pendant une commande, une fermeture, un direct non arrêté ou un dialogue de l'application, l'aide se réduit et la parole est coupée. Elle ne se rouvre pas automatiquement à la fin de cet état. Le joueur peut explicitement la consulter pendant la pause d'un match ou sur un résultat terminé.

## Voix et animation

Activer `audio/general/text_to_speech=true` dans le projet **avant** de démarrer Godot : l'activation à chaud ne suffit pas. Le lot module n'édite pas `project.godot` ; le parent ajoute ce réglage lors des accroches. `DisplayServer` fournit les voix françaises locales. Microsoft Paul est préféré s'il est présent sans préférence enregistrée ; sinon la première voix française disponible est choisie. Options permet de choisir une autre voix et un débit. Aucun téléchargement, réseau, clé API ou coût de service n'est nécessaire.

Le texte de la bulle est exactement la chaîne transmise à `tts_speak`. Réécouter redémarre cette explication ; Arrêter, Muet, fermeture ou changement de page coupent l'ancienne demande. Seuls les callbacks réels de début/fin activent et arrêtent le mouvement de bouche ; les anciens identifiants sont ignorés. Le portrait change réellement de frame, alterne les gestes d'explication et cligne au repos sans utiliser de nombre aléatoire. L'absence de voix française est indiquée par Mode texte, avec le détail dans Options. La voix définitive reste à produire ; la synthèse actuelle est un secours local provisoire.

## Progression indépendante

`guide.json` se trouve dans le même dossier explicite `PrototypeGodot` que le profil, à côté de `donnees.json`, jamais dans l'export de carrière ni dans le dossier du programme. Le module respecte `model.meta.dataDir` et la normalisation explicite du pont si le premier modèle n'est pas encore reçu. Le format version 1 contient seulement activation, muet, identifiant de voix, débit, étape et étapes parcourues. Le déploiement ne migre aucune carrière.

Lecture limitée à 64 Kio, validation des types/étapes/débit, fichier temporaire puis remplacement atomique. Une corruption conserve l'original et bloque toute réécriture du guide pour la session. Une erreur de disque reste affichée ; aucun second emplacement n'est essayé. Un profil corrompu laisse l'aide utilisable, avec la voix système si elle est disponible, mais sans enregistrer la progression. Les réglages et la désactivation peuvent rester locaux à la session ; l'erreur le précise. La correction explicite du fichier puis un redémarrage permettent de reprendre l'enregistrement.

## Réception reproductible

Charger `E:/Cadrage-Debordement/environnement.ps1`, définir `CD_GODOT_EXECUTABLE=CD_GODOT_EXE`, puis lancer `python scripts/build-godot-prototype.py --stage-only` et l'import SDK des ressources si nécessaire. `node tests/godot-guide.cjs` attache explicitement le module à la vraie scène native dans un projet temporaire qui active la TTS au démarrage. Le profil et les preuves restent temporaires sur E: ; aucun profil personnel n'est lu. Avec `CD_GUIDE_GRAPHICS=1`, la même recette ouvre Windows et teste la voix disponible ainsi que les captures aux tailles réelles 1280 × 800, 1440 × 900 et 1920 × 1080.

La recette vérifie contrôles interactifs, navigation explicite, snapshots sans répétition, export/RNG/octet de carrière invariants, progression/reprise, corruption/écriture refusée, vrai changement de frame et arrêt, attentes/dialogues/direct, désactivation et nettoyage. Les contrôles vocaux réels sont annoncés non exécutés en mode headless sans voix ; ils doivent être reçus dans Windows avant livraison. Le projet temporaire copie les petits fichiers et utilise des jonctions pour les dossiers, dont le cache `.godot` : ne pas lancer deux SDK simultanément sur ce même cache. Le réglage TTS existant est remplacé dans le projet privé sans dupliquer la section Audio. Les captures prouvent le module autonome ; la réception générale de l'exécutable après les accroches parent reste distincte.

`CD_GUIDE_CASE=write-error node tests/godot-guide.cjs` reçoit spécifiquement le refus d'écriture réel : erreur visible développé/compact/Options/désactivation, aucune modale répétée, utilisation toujours possible sur corruption et préservation du fichier comme de la carrière.
