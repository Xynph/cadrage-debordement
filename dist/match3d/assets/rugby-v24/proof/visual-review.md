# Inspection visuelle — joueur isolé, 5 novembre 2026

Les captures Chromium/SwiftShader 143 à 960 × 720 ont été réellement ouvertes et inspectées : face, dos, profil et course à t=0,25 s. Les JPEG correspondent aux captures du navigateur ; les sources GLB n’ont pas été modifiées. Ce document ne valide pas les trente joueurs ni la performance GPU native.

- Face/dos/profil : anatomie humaine reconnaissable, T-shirt, short et chaussures présents. Pas d’explosion de géométrie après correction. Les limites géométriques statiques mesurées font 1,738 m de hauteur et 1,130 m de largeur (bras de la géométrie de repos compris).
- Course : tenue et membres suivent le squelette. Une zone de peau traverse la chaussure du pied à droite de l’image. Correction des surfaces cachées/ajustement de la chaussure requise ; l’habillage n’est donc pas qualifié pour production.
- Les gestes sont les clips génériques upstream. Le T-shirt porte encore le graphisme source et les chaussures sont des bottines, pas des crampons rugby validés.
- Éclairage de qualification très clair ; la capture UI place le texte devant le haut du joueur. Pas une réception de la caméra du jeu.

## Cause et correction

L’assemblage initial lisait directement les tableaux d’entiers des morphs normalisés, sans décodage. En outre, GLTFLoader r149 écrit les valeurs sparse normalisées via des setters qui les renormalisent : les données étaient converties deux fois. L’aperçu restaure les composantes entières sparse depuis les buffers source, puis utilise les getters normalisés pour calculer les positions en Float32. Les bornes sont recalculées après application. Aucun changement du chargeur vendor ni du runtime du jeu.

Deux régressions Node reproduisent ces cas. Le test navigateur exige désormais des proportions humaines, en plus du rig et des coordonnées finies : ces derniers contrôles seuls avaient laissé passer une géométrie invalide.

Prochain jalon : corriger pénétrations et géométries cachées, qualifier des chaussures de rugby et produire les trois LOD. PR #300 reste DRAFT ; aucun gate ni fusion.
