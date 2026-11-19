# Relecture accessibility-specialist : coque commune (Phase 4 de /team-ui)
> Date : 2026-11-19 · Posture adverse · Palier engagé : **Standard**, avec l'exception de densité de Léo (`design/accessibility-requirements.md` : corps ~13 px, jamais sous 11 px, échelle d'interface 90/100/115/130 % obligatoire, contrastes ≥ 4,5:1, couleur jamais seule).
> Sources : captures 1920×1080, fiche UX §12, `visual-design.md`, `shell.gd`. Pas de mesure de contraste au pixel sur capture : les ratios de la fiche viennent des jetons de l'art bible §4.3.

**Verdict : NEEDS REVISION** (0 bloquant, 5 à corriger). Points tenus : texte du rail 18 px réels, jetons de texte ≥ 7:1, états par mot ou forme (✓ + « Sauvegardé », entrée active = fond + filet + graisse, badge = chiffre), cibles ≥ 36 px, noms accessibles posés sur Continuer, Menu, Gabi.

## À CORRIGER
1. **T5 : info décisive tronquée** : « Division d'accession a… » (rang perdu) sur la plupart des écrans ; `OVERRUN_TRIM_ELLIPSIS` aussi sur le libellé et la raison de Continuer et les morceaux du fil. La fiche promet « jamais de … » et « raison non tronquée ». Correction : 2 lignes puis 12 px puis infobulle, partout ; test à 130 % avec un nom de club de 28 caractères et une raison de 22.
2. **K2 : focus clavier non prouvé** : aucune capture ne montre le contour 2 px `ivoire` sur un élément de la coque (rail, Menu, flèches, Recherche, Continuer). Le code le définit ; la preuve manque. Correction : une capture par famille d'élément, y compris sur Continuer `or` (décalage visible) et sur la ligne active du rail.
3. **C4 / D1 : désactivé sans forme** : la flèche Suivant grisée n'a que la teinte `ivoire-3` sur la capture Effectif ; la fiche prévoit une flèche barrée. Et sur les autres écrans les deux flèches sont identiques (état à vérifier). Correction : flèche barrée + infobulle « Pas de page suivante ».
4. **Médaillon : pastille « E » sans sens** : lettre blanche sur pastille ronde ; l'info n'a aucun mot ni nom accessible lisible (le nom du bouton ne la mentionne pas). Correction : supprimer ou la dire en toutes lettres dans le nom accessible et l'infobulle. De plus, sur Bureau et Options, il ne reste que la puce « F1 » (cible 27 px, sans portrait) : cible sous le seuil des boutons d'action de 28 px (K6) et peu explicite.
5. **E1 / E2 / T3 : aucune preuve à 1280×720, 115 %, 130 %** pour la coque ; la fiche §14 les exige et plusieurs textes de la coque sont à 12 px (touches « Ctrl S », « Échap », « F1 », « division · rang », ligne Sauvegardé). Sous 11-12 px réels = hors palier. Correction : capturer rail et barre à 1280×720 et à 130 % ; vérifier le plancher et l'absence de recouvrement (fil, Recherche, Continuer).

## AVIS
6. **Sauvegarde / Continuer / page changée** : les annonces prévues (fiche §12) dépendent des noms accessibles ; seuls Continuer et Gabi en ont dans le code lu. Hors palier engagé (lecteur d'écran) mais à garder comme ligne de conduite.
7. **Mouvement réduit (M1)** : le glissement du filet, la cascade des blocs et l'ovale de Continuer sont couverts sur le papier (fiche §10) ; aucun test n'est cité dans le diff pour le prouver. À ajouter au test de la coque.
8. **Daltonisme (D7)** : `v` (✓ Sauvegardé) reste le vert de la charte ; le mot suffit, le mode daltonien `#5AA9E6` n'est pas visible sur capture. À filmer.
9. **Espace** à deux sens (Continuer, et « message suivant » en Réception) : K4/K5, un raccourci ne doit pas changer de sens d'un écran à l'autre. Voir la relecture UX.
10. **Doublon de sauvegarde** (rail + pied) : lecture redondante pour qui navigue au clavier ; supprimer le pied (G4 resterait respecté par la ligne du rail).
11. Contraste `ivoire-3` pour le pied « Sauvegarde automatique… » (4,92:1 sur `panneau`, 5,24 sur `fond`) : conforme mais à la limite ; ne jamais le poser sur `panneau-3`.
