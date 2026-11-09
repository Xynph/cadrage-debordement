# Passation animation — Codex Cloud vers Codex PC

Passation du 9 novembre 2026, publiée avec l’accord explicite de Léo. Cette page prépare la reprise Windows ; elle ne constitue pas une recette Windows exécutée.

## Reprise exacte

- Dépôt : [Xynph/cadrage-debordement](https://github.com/Xynph/cadrage-debordement).
- PR technique : [#427](https://github.com/Xynph/cadrage-debordement/pull/427), ouverte et non fusionnée lors de la vérification.
- Commit technique : `534d0872561c65a1914362a8e6c10669f57108fa`.
- Branche technique : `feature/animation-pipeline-cloud-20261109`.
- Base main vérifiée pendant le chantier : `e38a79f3c5ea2f7d48a362a96091ba466f70399f`.
- [Diagnostic et réception Cloud](../animation-pipeline-cloud.md).
- [Commandes détaillées pour Windows](../animation-pipeline-windows.md).

Avant toute modification, lire AGENTS.md, DEVELOPPEMENT.md et les derniers commentaires de [coordination #73](https://github.com/Xynph/cadrage-debordement/issues/73). Recontrôler main, HEAD de la PR, autres chantiers et CI sur GitHub. Le dépôt actuel prévaut sur cet instantané. Réserver les chemins et utiliser une copie de travail isolée ; préserver l’installation jouée et les carrières personnelles.

## Point bloquant : CI rouge

La CI du dernier commit technique a échoué :

- [Run Tests JavaScript 42667256434](https://github.com/Xynph/cadrage-debordement/actions/runs/42667256434).
- `Suites 1/5`, job `129334274198` : `tests/native-academy-integrated-long.cjs` dépasse 180 secondes, code 124.
- Le log atteint saison 2 / semaine 34 avant terminaison ; aucune assertion échouée n’a été relevée avant ce délai.
- `Validation CI` échoue ensuite ; les cinq autres jobs sont réussis.

La cause précise de ce dépassement n’est pas établie. La suite d’académie n’a pas été modifiée par le lot animation. Ne pas attribuer automatiquement le dépassement à l’environnement ni le déclarer sans rapport avec la PR sans preuve.

Première priorité : diagnostiquer cette suite et coordonner toute correction avec le chantier #424, qui intervient sur des domaines de carrière et conserve ses propres réservations. Ne pas augmenter silencieusement les délais, retirer un test ou contourner le release gate. Aucune fusion avant CI et gate officiels valides sur le dernier HEAD.

L’ancienne CI verte du commit `bd7c6da` ne valide pas le commit `534d087`.

## Ce qui est réellement reçu dans Cloud

Six agents ont traité les causes, la locomotion, l’export, le skin et les normales/topologie, le lecteur et le lanceur, avec des revues croisées.

- Dix phases locales complètes réussies, aucun échec ni phase ignorée.
- Quatorze tests Node22, quatre gardes d’export et onze tests numériques réussis.
- Onze clips et 110 poses skinnées contrôlés.
- 1 854 faces orientées et leurs normales par coin conformes.
- Quatre petites influences conservées ; suppression du rebake pondéré compensée algébriquement.
- Quatre-vingt-un contrôles du vrai lecteur sur une copie chargeant le candidat exact, cache et empreinte vérifiés.
- Identités source/source reçues et témoins défectueux effectivement refusés.
- Source originale intacte ; aucun runtime, actif distribué, comportement sportif ou format de sauvegarde remplacé.

Les preuves et empreintes des outils sont versionnées dans `tools/animation-pipeline/corrected-results.json`. Le candidat reproductible, externe au jeu, a pour SHA256 :

`d9139eddc66f7c407107b4d68b3d1503ca07e4256432a9a9a1528fd0fe74afbb`

La source versionnée est `dist/match3d/assets/quaternius-rugby-athlete.glb`, SHA256 :

`7fd28255c484e19ba5086d9cf815128e21dfcb677d262a88b237a5f5af081c5f`

Le fichier sous `native/godot/assets/match3d/` est une copie de staging ignorée par Git. Ne pas confondre ce fichier, le candidat et la source canonique.

Les binaires candidats et tous les logs volumineux du workspace Cloud ne sont pas transférés par cette page : les scripts de régénération, paramètres, reçus et hashes sont dans la PR. Une nouvelle exécution peut produire une empreinte différente selon le build ; mesurer et comparer, sans injecter les valeurs historiques dans les résultats.

## Versions et dépendances

- Godot 4.7.2.
- Parcours A : reproduire le chemin reçu sous Blender 4.3.2.
- Parcours B : qualifier Blender 5.2 séparément. Le patch privé de conservation des poids est protégé par version et empreinte de fonction ; une implémentation non revue est volontairement refusée. Ne pas retirer le garde pour forcer l’exécution.
- Python externe : venv local avec `tools/animation-pipeline/requirements.txt` (NumPy2.3.5 et SciPy1.17.0 reçus).
- Blender utilise son NumPy embarqué ; aucun service Scenario, abonnement ou génération payante n’est nécessaire.

Le pipeline est un aller-retour avec préservation explicite d’attributs source : scales statiques, inversebinds, normales par coin et indice de face dégénérée perdue. Les positions et les rotations/translations animées ne sont pas recopiées depuis la source. Cela ne constitue pas une validation d’une modification artistique arbitraire.

## Travail à effectuer sur Codex PC

1. Recevoir l’état GitHub courant et diagnostiquer la CI rouge avant toute intégration.
2. Suivre la recette Windows depuis une copie isolée, avec un dossier de preuves neuf hors du dépôt.
3. Régénérer le candidat, exécuter le lanceur complet et vérifier que le lecteur charge exactement le fichier comparé.
4. Comparer original et candidat : trente joueurs, trois caméras, appuis, mains/ballon, pause/reprise, maillots et normales.
5. Mesurer chargement, mémoire et performances sur le PC ; conserver versions, réglages, captures et résultats.
6. Publier un bilan distinguant réussite, échec et non-exécution. Vérifier l’exécutable distribué séparément d’un lancement du projet source.

La conformité numérique échantillonnée n’est pas une preuve de fluidité, d’apparence Windows ou de performance GPU. Aucun nouveau mouvement de rugby, plaquage complet ou changement de Gabi n’est inclus dans ce lot.

## Message prêt à transmettre

> Reprends la PR #427 d’Oval Legacy 27 au commit technique 534d0872561c65a1914362a8e6c10669f57108fa. Lis cette passation, AGENTS.md et la coordination #73, puis vérifie GitHub. Première priorité : diagnostiquer le timeout de tests/native-academy-integrated-long.cjs dans le run42667256434, sans contourner les protections. Ensuite, suis docs/animation-pipeline-windows.md sur une copie isolée : reproduction Blender4.3.2/Godot4.7.2, candidat exact et contrôles complets, puis réception visuelle et performances Windows. Blender5.2 reste une qualification distincte. Préserve le profil personnel et publie les preuves et limites.

Effort GPT‑6.1 Sol conseillé : **Élevé** pour la réception PC ; **Très élevé** pour corriger le rig/skin si nécessaire ; **Moyen** pour rejouer une recette stabilisée.
