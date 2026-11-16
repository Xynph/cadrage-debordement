# Prototype Godot natif — décision de plateforme Steam

Léo veut vendre Cadrage Débordement sur Steam, refuse une fenêtre Chrome/Edge et a choisi explicitement « Prototype Godot natif avant de poursuivre le portage ». Le prototype sert à juger un vrai rendu Windows et la réutilisation de la simulation, avant le portage complet et la carrière à trente clubs/deux divisions. L'objectif global Clubs & Territoires reste conservé ; cette étape le précède.

## Produit à réceptionner

Une application Godot Windows x64 autonome, sans navigateur, sans Godot/Node à installer chez le joueur. Fenêtre intitulée « Cadrage Débordement — Prototype Godot », ouvrant Bureau, Club, Effectif/Fiche joueur et Match. UI Godot native (Control/Theme), pas de WebView, pas de capture HTML utilisée comme interface. Anthracite, ivoire et accent du club ; DM Sans/Barlow locaux, photos réelles de l'atlas et blasons propres. Cibles1440×900 et1920×1080. Actions présentes réellement utilisables ; état de prototype explicite, aucune promesse de jeu commercial terminé.

Le Bureau montre la vraie situation, l'effectif, l'adversaire et des commandes bornées : entraînement, composition automatique, démarrage de match, validation de journée et sauvegarde. La fiche utilise les attributs/contrats/condition natifs. Le centre Club utilise les photos ville/stade et permet de consulter les trente territoires ; les seize clubs non encore instanciés par le moteur historique restent un catalogue explicitement distinct d'une carrière jouable. Aucune valeur sportive, finance, histoire ou capacité de stade inventée pour remplir l'écran.

La scène de match Godot reprend les positions/événements/statistiques du moteur réel. Terrain entier, caméras TV éloignée et tactique, trente joueurs selon les présences effectivement fournies, ballon, lumière/ombres et lisibilité des maillots. Réutiliser les modèles et animations déjà licenciés dans le dépôt ; ne pas relancer le chantier R&D d'animations. Rendu générique de prototype, sans annoncer la reconstruction3D des trente vrais stades.

## Architecture retenue pour l'épreuve

Godot4 stable pour fenêtre/UI/3D. Le moteur JavaScript existant est réutilisé dans un processus local Node embarqué, via un protocole JSON lignes privé sur les pipes du processus ; aucun serveur web, port réseau ou navigateur. C'est un pont de prototype, pas une décision définitive pour tous les composants du portage.

Le processus charge les mêmes modules sportifs et de sauvegarde de `dist/` en contexte headless contrôlé. Il ne dépend pas du harness de test en production, n'évalue aucune commande arbitraire reçue de l'UI et n'altère aucun `dist/lnr-*`. Démarrage historique fictif14 clubs pour prouver le raccord ; la future carrière30 complète conserve son plan distinct. Les libellés territoriaux de présentation n'écrasent pas les anciennes identités sauvegardées.

Le modèle de vue est versionné : `protocol:1`, `club`, `league`, `squad`, `next`, `history`, `messages`, `ledger`, `live`, `meta`. Joueurs : identité, poste, âge, note/potentiel natifs, condition/charge, contrat/salaire, minutes/statut, onze attributs et index de portrait stable. Match : minute/période, scores/essais, pause/fin, équipes, événements, statistiques et scène normalisée `CDMatch3DAdapter.normalize(matchScene(S.live))`. Les photos sont résolues par le catalogue indépendant `CDFranceClubs`.

Messages entrants : `{id,command,payload}` ; réponses : `{id,ok,model,error?}`. Commandes bornées `snapshot,new_career,train,auto_lineup,begin_match,tick,pause,delegate,finish_round,save,import,export,shutdown`. Chaque mutation suit les contrôles natifs, confirme l'écriture réelle avant réussite et remonte les erreurs. Chargement/écriture dans un profil **PrototypeGodot** séparé des carrières personnelles existantes, hors dossier exécutable, avec copie précédente et écritures atomiques. Pas de repli silencieux. Le pont Godot est non bloquant et termine son processus fils à la fermeture.

## Propriété des fichiers et réception

Parent DA : projet/scène principale, thème/composition, préparation des assets, crédits, packaging et réception visuelle. Producteur pont : worker Node, modèle et `engine_bridge.gd`, tests du protocole, sauvegardes et parité. Producteur3D : `match_view.gd`, consommant le modèle normalisé, sans écriture moteur. SDK Windows acquis séparément depuis les sources officielles. Aucun partage d'écriture des mêmes fichiers.

Contrôles : processus enfant sans Chrome/Edge, actions réelles, parité d'un match avec le moteur existant, sauvegarde/reprise et refus disque, fermeture propre, absence d'appel réseau du jeu, images et licences présentes, import Godot sans erreur, captures des quatre vues aux deux tailles, vraie réception de la fenêtre Windows et ZIP lancé depuis un autre dossier. Une revue indépendante reçoit l'ensemble avant annonce de livraison. Pas de compte Steam créé, pas d'achat, SDK Steamworks ou publication commerciale revendiquée.
