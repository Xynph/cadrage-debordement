# Réception UI-02C sur le main du 31 octobre 2026

- Main de base : `2fcd3adb09d010af734b58ff49bd0c50d21aba9c`.
- Source : PR #84, `0b5241bb86fa13f81f8f157f2ded6b9ee0f272f3`.
- Commit d'intégration testé : `e7e8bcf0f2f19ee295dfdc2abe64f34c9f93564a`.
- Arbre testé : `7257294294832bcc3dff8e6aa395d71b27d6e9b8`.

**85 suites JS réussies, 0 échec, 169,510 s**, sous Node 24.22.1 / Windows. Toutes les suites `tests/*.cjs` hors harness ont été exécutées individuellement avec délai maximal de 180 secondes par suite. Les sauvegardes et les trois suites UI02 sont incluses ; détails dans `tests-local.json`.

**91 contrôles navigateur réussis**, sans erreur JavaScript, sous Google Chrome Windows, largeurs 320, 390, 768, 1024 et 1440, thèmes Analyste et Tribune. Le test existant `tests/ui02-live-browser.py` a été exécuté avec son lancement adapté uniquement en mémoire : `pw.chromium.launch(headless=True, channel="chrome")`. Aucun fichier de test n'a été modifié. Le téléchargement du Chromium de Playwright a échoué sur la chaîne de certificats ; aucune vérification TLS n'a été désactivée. Détails dans `navigateur-windows.json`.

Recherche, tri, colonnes persistantes séparées de la carrière, comparaison, quatre onglets joueur, entraînement natif, feuille 15+8, sauvegarde/reprise et cockpit vérifiés. Captures `effectif.png` et `fiche-joueur-mobile.png` inspectées. Données de nouvelle carrière fictive, aucune sauvegarde personnelle utilisée.

Aucun correctif de code nécessaire constaté. Les correctifs économiques récents, les règles et le format de sauvegarde sont conservés. Le workflow UI02 est celui de la PR source, repris sans changement ; aucun workflow de main existant n'est modifié.

La publication de ce dossier et du journal après les tests ajoute uniquement de la documentation et des preuves. Elle ne constitue pas une nouvelle exécution de tests sur le SHA documentaire final.

**Limites :** tests locaux, pas la CI Chromium Linux ; aucune validation du lanceur portable ni exécution séparée des grandes campagnes spécialisées. La fusion exige la CI complète verte sur le dernier SHA ; ne pas contourner le quota GitHub épuisé. La PR #84 et les fondations #81/#83 ne doivent pas être intégrées deux fois. PR #75 intacte.
