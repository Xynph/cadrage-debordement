# Relecture ux-designer : coque commune (Phase 4 de /team-ui)
> Date : 2026-11-19 · Posture adverse · Sources : `design/ux/coque-commune.md`, captures 1920×1080 (tour des écrans), `shell.gd`, `main.gd`.

**Verdict : NEEDS REVISION** (2 bloquants, 6 à corriger). Réussi : rail pleine hauteur sans numéros, ordre exact des entrées, Précédent/Suivant et Menu dans la barre, Réglages et Sauvegarder dans le rail, plus de fenêtre pour Sauvegarder.

## BLOQUANT
1. **Réglages s'ouvre encore en petite fenêtre** : la capture « Options » montre la fenêtre « Paramètres » (croix de fermeture, onglets) posée sur le Bureau. `main.gd` garde `settings()` qui ouvre `preferences_dialog.open`, seul `settings_page()` va vers l'écran. Règle 2 de Léo et §7.2 de la fiche (« Réglages : écran dans la coque, n'est plus une fenêtre »). Correction : toute entrée en carrière (menu pause, raccourci, film des écrans) passe par `_navigate("Réglages")` ; la fenêtre reste réservée au hors-carrière.
2. **Espace a deux sens** : Réception affiche « Espace : message non lu suivant » en pied, alors que la coque donne Espace = Continuer (fiche §4, K4). Un joueur qui lit son courrier peut faire avancer le temps, ou ne pas obtenir l'avance voulue. Correction : retirer ce raccourci du contenu (autre touche, ex. J / K ou flèches) ; à vérifier au test de focus qui l'emporte.

## À CORRIGER
3. **« F1 » orphelin** : sur Bureau et Options le médaillon n'est pas dessiné et il reste une puce « F1 » seule dans la barre. Règle 1 : un libellé qui ressemble à un bouton sans rien à toucher. Sur les autres écrans, médaillon avec une pastille « E » inexpliquée (G1 supprime les remarques de la barre). Correction : médaillon toujours présent (ou « F1 » masqué avec lui), pastille retirée.
4. **Date sans journée** (« sam. 26 sept. » ; la fiche §5.3 et la maquette ont « · J9 »). La journée est l'info qui situe dans la saison. Correction : « J2 » collé à la date, même lien vers le Calendrier.
5. **Continuer** affiche « Préparer » à la place d'« Espace ». Le bouton ne dit plus ni la touche ni s'il est bloqué : §6 prévoit « Espace » au repos, « ! » + raison (≤ 22 car.) si bloqué. Le code ne met « ! » que si le bouton est désactivé, or un blocage ouvre l'écran fautif (donc actif) : le « ! » ne s'affichera jamais comme prévu. Correction : piloter le texte par l'état de blocage, pas par `disabled`.
6. **Identité du rail** : « Division d'accession a… » tronquée sur la plupart des écrans (rang perdu, donnée décisive) ; Effectif la montre en entier sur 2 lignes. Correction : mêmes règles partout (fiche §5.2 : 2 lignes puis 12 px puis infobulle).
7. **Précédent / Suivant** : les deux flèches sont de même teinte sur Bureau, Réception, Sélections (Suivant devrait être grisé tant qu'on n'a pas reculé). Seule la capture Effectif montre Suivant grisé. Vérifier que le tour des écrans n'efface pas l'historique ; ajouter la flèche barrée de §6.
8. **Doublon de sauvegarde** : « ✓ Sauvegardé » dans le rail et « Sauvegarde automatique · chaque semaine · dernière le 26/09 » en pied de chaque écran. Texte inerte (règle 1) et plus bas dans la page que la source de vérité. Correction : une seule ligne, dans le rail.

## AVIS
9. Le fil d'Ariane de Match dit « Tactique / Match » : le rail met Tactique en actif sur un écran d'avant-match ; peu clair pour qui vient de Continuer. Prévoir « Bureau / Match du jour » ou une entrée active cohérente.
10. `next_day` (« +1 j ») existe dans le code malgré Q3 ; absent à l'écran, à supprimer pour ne pas réapparaître.
11. Échec de sauvegarde (« ! Échec · Réessayer ») et Continuer en calcul non capturés : à filmer avant de passer le critère §14.
12. Le critère « chaque morceau du fil cliquable, dernier compris » n'est pas vérifiable sur capture ; le code connaît pourtant `text_overrun_behavior` en ellipse sur les morceaux : vérifier qu'un fil long garde ses derniers morceaux.
