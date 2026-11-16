# Coach guide — tutoriel natif parlé et animé

## Autorisation et intention

Objectif utilisateur autonome lu le 7 novembre 2026 : réaliser un premier tutoriel fonctionnel guidant choix du club, effectif, sélection, entraînement, tactique, premier match et lecture du résultat. Apparence originale validée par « nickel » : ancien avant chaleureux et un peu bourru, cheveux et barbe gris, carnet, pull bordeaux/polo ivoire, oreilles de taille naturelle au cartilage intérieur épaissi. Aucun portrait ou imitation vocale d'une personne réelle.

## Approche retenue par le développeur

Premier personnage 2D natif plutôt que vidéo ou personnage 3D : sprites d'expressions et gestes, parole et clignement animé, mouvement subtil. Atlas original 1536x1024 (3 colonnes, 2 rangées, cellules512x512) dans guide/assets/coach-sprites.png. Rangée1 repos/parole/clignement, rangée2 explication repos/explication parole/encouragement. Garder une silhouette stable et éviter un mouvement permanent excessif ; pas de simple image qui flotte présentée comme animation complète.

Voix provisoire issue des voix TTS du système Windows via Godot. La machine de réception possède notamment Microsoft Paul fr-FR ; ne pas imposer sa présence sur les autres PC. Choisir une voix française disponible, proposer voix et débit, rendre le mode texte clair si aucune voix disponible. Aucun téléchargement/service/API clé/coût. La voix définitive enregistrée reste hors de cette première version. Parole et bulle utilisent exactement la même chaîne, début/fin réels synchronisent l'animation, arrêt immédiat lors d'une fermeture, mute ou changement d'explication. Aucun doublon de parole à chaque snapshot/tick.

## Composants et interfaces

Créer un module indépendant native/godot/guide/**. Controller instanciable par le parent dans main : setup(app), refresh() après changement de route/modèle, ouverture explicite, fermeture/nettoyage. Il peut demander app._navigate(route) uniquement par action explicite du joueur. Aucune commande de carrière ni modification du modèle dans le guide. Le parent ajoute les accroches main/projet/settings après le lot DA ; ne pas éditer ces fichiers partagés maintenant.

Présenter des explications courtes par écran réel, avec étapes et progression. La visite complète compte quinze étapes, y compris recrutement et territoire ; les répliques de 30 à 55 mots indiquent quoi observer et un premier geste utile avec le ton chaleureux d'un ancien coach. Le joueur choisit visite guidée ou aide de l'écran ; boutons passer/suivant/précédent/réécouter/muet/désactiver/réduire. Ne jamais naviguer ou commencer un match automatiquement. En cours de commande ou match en direct, ne pas prendre le focus ni parler par-dessus ; garder une commande discrète pour réouvrir l'aide quand approprié. Ne pas voler les touches Escape/Entrée des dialogues existants.

Éviter une grande image encombrante : prévoir un mode compact et une zone d'accueil intégrable par le parent pour réserver l'espace quand l'aide est développée. Le panneau développé mesure 260 px par défaut avec portrait 128 px ; voix/débit/muet/passer/désactiver sont regroupés dans Options repliables. Le coach ne doit pas rendre inaccessibles la navigation, les confirmations ou les commandes du match. Les répliques décrivent le moteur existant et les données disponibles ; ne pas inventer des conseils sportifs chiffrés, budget réel ou causalités. Couvrir aussi packs/finances/calendrier/classements sans exiger un pack.

Progression et préférences hors sauvegarde sportive, fichier guide.json dans le profil explicite de l'app (E: à la réception). Lecture bornée avec validation, écriture atomique, erreurs visibles et aucun repli silencieux. Chargement corrompu ne doit ni effacer ni remplacer les données. Des identifiants d'étape stables évitent les reprises incohérentes. Les tests n'accèdent jamais au profil personnel.

## Vérifications

Tests ciblés rouges puis verts dans tests/godot-guide.cjs/.gd : vraies routes et modèle natif, contrôles interactifs, texte identique à la parole, lecture/relecture/mute/absence de voix, progression et restart, corruption/erreur d'écriture, invariance export/disque/RNG du moteur. Tester animation qui change réellement de frame et s'arrête correctement, nettoyage et fermeture. TTS vérifiable via signaux réels si la voix est disponible, sinon rapport honnête ; pas seulement un mock qui passe. Captures graphiques 1280/1440/1920 avec états compact/étendu et textes longs, inspecter clipping/alpha/focus.

Lancer l'import SDK des assets avant la réception si nécessaire. Pour les tests autonomes avant accroches parent, attacher explicitement le contrôleur à une vraie app dans la scène de test. L'actuelle réception générale n'active pas encore le guide par défaut. Le parent vérifie ensuite les accroches dans le vrai exécutable.

## Coordination et livraison

Branche feature/coach-guide-20261107, worktree E:/Cadrage-Debordement/worktrees/coach/cadrage-debordement base00b0902. Réservation #73 publiée par le parent. Chemins autorisés : native/godot/guide/**, tests/godot-guide.cjs/.gd, docs/coach-guide-20261107.md et ce plan. Exclure ui/**, main.gd, theme.gd, project.godot, moteur/BDD, sauvegardes, README/DEVELOPPEMENT et builder Python. Aucun push ni commentaire par le producteur.

Rapport .superpowers/sdd/2026-11-07-coach-guide/task-report.md, commit local Codex unique final, preuves, captures et limites. Le parent fera la revue, l'intégration des accroches TTS et l'éventuelle réception finale groupée. Ressource produite avec imagegen depuis le concept original ; la capture Google de référence anatomique privée ne doit pas être copiée dans le dépôt ou le jeu.
