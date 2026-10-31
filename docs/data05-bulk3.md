# DATA-05 — Lot 3, 31 octobre 2026

**90 fiches individuelles LNR supplémentaires** aux 150 fiches uniques des PR #126/#127, soit **240 joueurs uniques consultés**. Sources individuelles, groupes de postes, âges et nationalités : 90/90. Taille/poids : 81/90, sinon null. **Aucune date de naissance exacte** ou appartenance au 1er juillet 2026 n'est démontrée par ces fiches d'octobre.

Source de sélection : indices 3 à 7 de chaque club dans `modding/data05-bulk2/selection.json`, cette PR couvre les 90 derniers sur 150 (le lot de 60 de PR #127 couvre les premiers). Cinq JSON indépendants, 18 joueurs par fichier.

**Staffs officiellement sourcés :** 23 membres (coachs et fonctions d'appui) présentés par le Stade Français Paris le **31 août 2026**, source https://www.stade.fr/equipe-premiere/actualites/decouvrez-le-staff-sportif-26-27/ . Aucun n'est automatiquement réputé présent au 1er juillet.

Aviron Bayonnais : Jean Monribot (touche/conquête) et Abdellatif Boutaty (intendance) annoncés à compter du **5 janvier 2026**, source https://www.abrugby.fr/news/articles/05-01-2026_communique-officiel ; la présence continue au 1er juillet doit cependant être revalidée. Andrea Moretti annoncé le **19 mars 2026** pour la saison suivante, source https://www.abrugby.fr/news/articles/19-03-2026_andrea-moretti-rejoint-l-aviron-bayonnais ; **date d'effet exacte inconnue**, ne pas supposer le 1er juillet.

Cette PR ajoute **26 enregistrements de staff sur 2 clubs**, mais avec les deux clubs des PR #123/#126, on compte **au moins 4 clubs distincts couverts** par des preuves nominatives : Clermont, UBB, Stade Français, Bayonne. Pas 30 clubs complets.

**Transferts :** aucun mouvement de joueur daté au 01/07/2026 nouvellement confirmé dans ce cycle ; la réconciliation chronologique reste non résolue et les champs de début de carrière ne doivent pas être alimentés à partir de listes d'octobre.

Contrôle sur les JSON réellement relus via GitHub : 90 identifiants uniques, 18 clubs, 81/90 profils avec âge/taille/poids. Test de régression dans `tests/data05-bulk3.cjs`, à faire exécuter par CI et éventuellement en local après accès au dépôt. Aucun dist/** ou sauvegarde modifié.