# Anomalies vues en capturant 67 écrans — `fe79c365`, 11 novembre 2026

Relevées en 1920×1080, éditeur Godot Linux, rendu logiciel, en parcourant le jeu par ses vrais boutons. Chaque point a été vu sur une capture ; les causes entre parenthèses « supposition » ne sont pas vérifiées. À rejouer sur `96f53704` avant correction.

| N° | Écran | Constat |
| --- | --- | --- |
| 1 | Observer la préparation (terrain d'entraînement 3D) | Dans le panneau de gauche, la ligne du joueur s'affiche un caractère par ligne ; le titre « Le retour du préparateur » est coupé. |
| 2 | Causeries de mi-temps et d'après-match | Le score de l'en-tête s'affiche en décimales : « 0.0 — 10.0 », « 3.0 — 13.0 ». |
| 3 | Page Match après un résultat validé | Affiche « Résultat validé » mais un score « – / – » et « En attente de rencontre ». |
| 4 | Fiche de la rencontre jouée | « Béziers — Valence · 13 - 3 · Victoire » alors que le direct donnait Béziers 3 – 13 Valence : le score suit notre club, pas l'ordre des équipes. |
| 5 | Classement et fiche de l'adversaire après le match | Classement à 0 point, « 0 V · 0 N · 0 D · Aucun résultat de la saison conservé » (mise à jour différée au jour suivant : supposition). |
| 6 | Direct | Deux boutons « TACTIQUE » dans la barre (le panneau et la caméra). Le direct démarre sans action explicite du joueur. |
| 7 | Vestiaire (causeries) | Noms tronqués ; grande surface blanche au premier plan à gauche (objet 3D trop près de la caméra : supposition). |
| 8 | Salle de presse 3D | Aucun journaliste dans la salle ; nom du club flou ou déformé sur le fond. |
| 9 | Entretiens en salle 3D | Bureau en partie caché sous le panneau de droite ; l'entretien individuel n'affiche pas de rôle sous le nom, l'entretien staff si. |
| 10 | Salle médicale 3D | Paraît inachevée : murs blancs surexposés, peu d'objets. |
| 11 | Export de carrière | Sélecteur de fichier natif de Godot, en anglais (« Path », « Favorites », « Recent », « Cancel », « Save »). |
| 12 | Journal du direct, Copies de sécurité, Sélections | Panneaux clairs dans une interface sombre ; pages Sélections dans un style plus ancien, petits caractères, beaucoup de vide. |
| 13 | Fiche d'un club adverse, fiche d'une rencontre à venir, dialogues de contrat | Dialogues en grande partie vides. |
| 14 | Réception en carrière « sélection seule » | Le bandeau « Les invitations du club » s'affiche quand même. |
| 15 | Première visite d'une page | La bulle du guide recouvre le contenu ; sur l'accueil, son texte est coupé avec une barre de défilement. |
| 16 | Menu « Votre carrière » | Affiche le chemin complet du profil sur le disque. |

Non atteints pendant la capture : direct à l'état « terminé » (le débrief prend le dessus), direct à la mi-temps (la causerie couvre la pause), conférence de presse d'après-match (aucune n'est apparue), feuille de match d'une sélection (pas de rencontre modifiable en début de mandat), notes individuelles après match (aucun écran trouvé).

Les 67 captures et leur manifeste ne sont pas dans le dépôt ; le PDF a été remis à Léo.
