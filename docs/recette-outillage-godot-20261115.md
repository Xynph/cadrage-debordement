# Recette locale du pont et de la boucle courte — 15 novembre 2026

## Ce qui a été exécuté

- Linux, Node 24.22.1, Godot officiel 4.7.2 dont l'archive correspond au
  SHA-256 de `ci/godot-sdk.json`. Pont MIT Fulviuus 2.0.2 à la révision
  `8f9760caca300680bfffe564faf98c17b38a8e59`, installé et compilé hors dépôt.
- `install.cjs` exécuté sur cette installation épinglée : version, licence,
  révision et absence de modifications vérifiées, `npm ci` puis build réussis.
- `stdio.cjs` lancé par le client officiel MCP SDK : préparation d'une copie
  vide, staging officiel, import Godot, initialisation du protocole, liste des
  **28 outils** et appel réel `godot_project_info` réussis. Tous les journaux de
  préparation restent sur stderr. Aucun agent ou modèle supplémentaire lancé.
- `serve.cjs` lancé sur `127.0.0.1`, puis client HTTP local : lancement du jeu,
  arbre de scène, création `world-champ`, attente du modèle `meta.mode=world`,
  `waiting=false`, aucune erreur de connexion ou de commande.
- Captures PNG réellement observées : Réception à **1920×1080**, Bureau à
  **1600×900 et 1280×720**. Rendu OpenGL par llvmpipe sur Xvfb ; aucun test de
  performance GPU déduit de ces images. Le jeu maximise sa fenêtre : la taille
  du viewport a été imposée puis vérifiée dans le jeu.
- Contrôles négatifs : erreur de compilation GDScript remontée avec code
  non nul ; URL non locale refusée ; dossier public et dossier externe sans
  marqueur refusés ; fichier préexistant laissé intact ; réponses JSON/SSE
  décodées et réponse vide refusée.
- Les moniteurs `Performance` de l'exemple profil ont retourné des nombres :
  FPS, temps de traitement et de physique, mémoire, nœuds et appels de dessin.
  Ce sont des observations ponctuelles de l'interface, pas un profil CPU.

## Application au développement

La première capture a révélé un conseil Réception annonçant cinq messages,
alors que la liste agrégée en montrait neuf. La correction appartient à #739 :
conseil sans compteur partiel, puis 172 contrôles Gabi verts.

Le cas Monde du chorégraphe à 44′ a été capturé et rejoué sans reconstruire la
carrière. #738 corrige l'avancée du passeur ; #740 ajoute les contraintes de
ruck et la régression dans les deux sens. Les contrôles physiques restent
identiques. Le parcours natif complet et la CI gardent la preuve finale ; le
rejeu court ne les remplace pas.

## Limites constatées

- Les fichiers de configuration ne rechargent pas une connexion Codex/Claude
  déjà ouverte. Le protocole STDIO et le client HTTP sont éprouvés ; la
  découverte native par l'application est à vérifier à la réouverture d'un
  projet de confiance. Aucune configuration globale n'a été écrite.
- Un retour `<null>` peut masquer une erreur GDScript d'exécution. Lire les
  journaux et vérifier l'état final. Le contrôle de compilation seul ne suffit
  pas. Un rechargement annoncé n'a pas actualisé le conseil préchargé : pour
  la recette finale, redémarrer le jeu.
- À 1280×720, le bandeau Gabi disparaît dans la disposition compacte. C'est un
  défaut d'interface à traiter dans le chantier de consolidation correspondant,
  pas une preuve que le personnage est absent de la carrière.
- Windows, macOS, pilote GPU matériel, son et lecteur d'écran non vérifiés.
  L'environnement signale l'absence de `libspeechd` et de réglage VSync ; ces
  avertissements ne sont pas transformés en validation de ces fonctions.
- Aucun gain global de vitesse, aucune qualité d'équilibrage et aucun contenu
  X inaccessible ne sont revendiqués. Pas de nouvelle suite longue, de budget
  CI modifié ni de service payant utilisé.

Modèle et effort effectifs non exposés par le runtime. Recommandation
GPT‑6.1 Sol : élevé pour conception/diagnostic, moyen pour recette et suivi.
