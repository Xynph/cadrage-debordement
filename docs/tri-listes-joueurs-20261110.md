# Tris et défilement des tableaux de joueurs — 10 novembre 2026

Cible de réception : 2560 × 1440. Ce complément couvre les tableaux restants de l’Académie, l’effectif générique et le banc ; la réception couvre aussi le tableau financier fourni par l’intégrateur.

## Comportement

- Chaque en-tête de données de l’Académie et de l’effectif générique déclenche un tri croissant puis décroissant. La progression utilise la différence réellement affichée ; le temps de jeu utilise le parcours projeté quand il existe. La colonne # de l’Académie représente l’ordre de la source reçue, conservé indépendamment du tri.
- Les valeurs absentes restent à la fin dans les deux directions. Les égalités sont départagées par l’identifiant, de façon stable, y compris pour des identifiants différant par la casse. Le tri textuel suit la normalisation d’accents déjà utilisée par la recherche.
- Les listes complètes sont présentes dans leur propre ScrollContainer. La molette reste dans cette zone, y compris en bout de liste ; les filtres et en-têtes restent fixes. Aucune pagination ne coupe l’effectif.
- Le banc trie uniquement l’affichage. Les numéros 16 à 23, l’identifiant du bouton et le poste ouvert restent ceux de la feuille originale ; aucun joueur n’est réaffecté.
- Une fiche demandée par identifiant, notamment depuis Ctrl+K, est révélée dans le défilement continu. Le défilement volontaire et le dossier ouvert sont préservés au retour.

## Réception

Le nouveau banc `godot-player-table-order.cjs` réussit **119 contrôles**, avec une vraie carrière : comparateurs 9/80/100 et valeurs absentes, deux sens de chaque colonne, molette interne et cadre fixe, dernier joueur atteignable, vrai poste du banc après tri, absence de commande sportive et empreinte du profil inchangée. Il reçoit aussi les quatre colonnes du tableau financier : Joueur, Poste, Échéance, Salaire.

`godot-navigation.cjs` adapté au défilement continu réussit **133 contrôles**. L’ancien banc Gestion conserve ses vérifications métier, désormais adaptées à la liste continue : **225 assertions réussies**. Son wrapper reste rouge à cause d’un dialogue de prolongation initialement ouvert dans son ancien viewport de 1280 px, hors cible du présent lot ; l’erreur n’est pas filtrée. Sa boucle finale d’offres vérifie maintenant les bornes en 2560×1440. Les dialogues de négociation de la cible font l’objet d’un banc 1440 dédié chez l’intégrateur.

Les tests utilisent Node 22 et Godot 4.7.2, des profils temporaires extérieurs à l’application et un cache privé. Aucun moteur, règle du rugby, sélection sportive ou format de sauvegarde n’a été modifié par ce complément.
