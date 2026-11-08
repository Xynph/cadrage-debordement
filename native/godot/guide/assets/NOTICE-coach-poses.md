# Coach — déclinaisons originales v5

Création raster originale générée le 8 novembre 2026 avec image_gen intégré, à partir des deux références du personnage fournies par le projet. Personnage fictif d’ancien entraîneur du Sud-Ouest, chaleureux, franc et exigeant. Aucun visage, voix ou nom de personnalité réelle utilisé.

Livrable conseillé : **coach-atlas-16-anthracite.png**, PNG original de l’outil, opaque, 1254 × 1254, 4 colonnes × 4 lignes, 16 vues. SHA256 : B4CB6B58401615C825B712A1C768535F53D84F59EBE73F60EB2BB5219B36F716.

Le fond anthracite a été demandé après défauts du détourage transparent. Il reste légèrement variable autour de #242329 et n’est pas un aplat exact. Carte des cellules et coordonnées UV dans manifest-16.json. Utiliser les UV fractionnaires (cellules de 313,5 pixels).

coach-atlas-16.png et coach-atlas-16-generation-contours.png sont le dernier rendu transparent ORIGINAL, non retouché, à ne pas privilégier à cause des liserés rouges visibles. La première génération est conservée dans coach-atlas-16-generation-initiale.png. Prompts exacts conservés : prompt.txt, prompt-correction.txt, prompt-contours.txt, prompt-anthracite.txt.

Une tentative technique de neutralisation par code a été abandonnée et annulée après instruction du parent. Les PNG livrés ici sont des copies binaires exactes des sorties image_gen. Les essais et preuves annulés sont isolés dans artefacts/session-staff-gameplay-20261108/obsolete-neutralisation-non-livrable ; ils ne constituent ni des livrables ni des preuves du dernier PNG.

Références : native/godot/guide/assets/coach-sprites.png et direction-artistique/personnages/ancien-coach-v4/coach-carnet-reference-rugby.png. La v4 n’a pas été modifiée. Aucun sponsor ni logo ajouté.

Cet asset est une illustration raster ; ce n’est pas un modèle 3D, un rig ou une voix. Les 16 vues permettent des changements de pose et d’expression, pas une animation faciale continue.


Copie embarquée dans le projet : `coach-poses.png`, carte `coach-poses-manifest.json`. Le PNG reste inchangé ; `coach_matte.gdshader` masque le fond anthracite uniquement au rendu, sans création d’une image retouchée.
