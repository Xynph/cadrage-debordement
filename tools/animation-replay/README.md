# Ralenti tactique — Oval Legacy 27

Ouvrir `index.html` dans un navigateur. Les quatre fichiers de la page doivent rester dans le même dossier. La démo fonctionne hors ligne et n’utilise aucun compte ni sauvegarde.

Les boutons de phase et les touches fléchées permettent de parcourir les quatre arrêts sur image. Le bouton Lire enchaîne les phases. La préférence de mouvement réduit désactive leur interpolation.

Les positions, le porteur mis en avant, les commentaires et le score viennent du moteur fictif via le banc `tests/harness.cjs` et l’adaptateur du match. Le scénario de recette prépare une course près de la ligne, déclenche un essai, puis enregistre le renvoi et la réception. L’interface utilise des repères de présentation entre les instantanés.

```powershell
node tools/animation-replay/export-fixture.cjs --check
node tests/animation-replay.cjs
```

La vue applique une idée de Teardown. Un index de phase pilote les marqueurs, le commentaire et le score depuis la même source. La page utilise son propre rendu SVG. Le script `site-check` d’Open 3D Skills permet de capturer chaque phase via `?phase=1` à `?phase=4` et de contrôler la mise en page à plusieurs largeurs.
