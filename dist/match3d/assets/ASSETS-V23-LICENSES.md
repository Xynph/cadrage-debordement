# MATCH 3D Premium lot 23 — licences et limite des ressources

## Actif embarqué
- Personnage Quaternius *Animated Men*, version GLB de `kendrekaran/striker-3d`, **CC0 1.0**, déjà intégré au lot 22.
- Source/notice complète : `QUATERNIUS-CC0-v22.md`.
- Le lot 23 ne télécharge aucune texture externe : motifs des maillots et trame du tissu générés localement par Canvas, matériaux PBR `MeshStandardMaterial`, cache partagé entre les 30 joueurs.
- Poses de bras/buste « passe », « protection » et « récupération » créées par code à partir des signaux purement visuels existants. **Ne pas appeler ces gestes des clips de motion capture rugby certifiés.**

## Candidats examinés, non intégrés
- [Innerscene — Male base mesh, CC0](https://www.innerscene.com/tools/library/3d-parts/male-base-mesh-3d-person-rigged-a-pose-380e6d89) : ~109 000 triangles, 163 os, modèle anatomique nu sans tenue ni animation. 30 exemplaires non qualifiés pour le budget GPU; intégration telle quelle inadaptée.
- [Ara 3D Gen](https://github.com/olatunde85/3d-gen) : code MIT, morphologies MakeHuman CC0 et exports d'animations; pipeline de génération externe (~420 MB de données initiales), licences spécifiques CMU et retargeting à vérifier. Aucun export complet rugbyman prêt à redistribuer testé ici.
- [Adobe Mixamo FAQ](https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400) : usage en jeux possible, mais la redistribution libre des personnages/animations comme **fichiers bruts** est interdite, donc non retenu pour le mod téléchargeable.
- [CharacterCreator](https://github.com/kblood/CharacterCreator) : anatomie détaillée via MakeHuman CC0, vêtements, animation ; pipeline Blender/MPFB plus exigeant, composants non intégrés ni évalués en jeu.

## Qualification produit
Le résultat du lot 23 est une **évolution textile PBR et poses dédiées sur le modèle stylisé existant**. Ce n'est ni du photoréalisme, ni une nouvelle capture 3D réaliste de rugbyman, ni une animation de plaquage réelle. Ne pas annoncer un saut graphique AAA sans preuves comparatives.
