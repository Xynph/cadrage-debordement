# Relecture art-director : coque commune (Phase 4 de /team-ui)
> Date : 2026-11-19 · Posture adverse · Sources : captures 1920×1080 (`temp/da-coque/`), maquette `coque-retouchee-v2.png`, art bible §3, §4, §7, `visual-design.md`.

**Verdict : NEEDS REVISION** (1 bloquant, 5 à corriger). Le cadre tient la charte pour l'essentiel : fond `panneau`, rail 232, filet actif incliné, aplat or unique dans la coque, ✓ avec mot.

## BLOQUANT
1. **Médaillon de Gabi : cercle parfait + pastille ronde « E »** (barre haute, visible sur Effectif, Réception, Fiche du club, Sélections, Match). La charte §3B interdit le cercle parfait et la pastille ronde ; la fiche demande un ovale tracé 72×48 et plus aucune remarque dans la barre (G1 révisé). Correction : ovale tracé `ivoire-2` (masque ovale), supprimer la pastille « E » (ou la remplacer par un état écrit hors barre).

## À CORRIGER
2. **Or hors Continuer, dans le cadre visible** : écran Match, flèches « De face / Dans le dos » et cases de condition en `or` jaune, face à un Continuer `or` ; la charte réserve l'or à « 27 », Continuer et l'héritage. Correction : repasser ces tracés en `ivoire-2` / `club-trait` (écran à traiter à l'étape contenu, mais à lister comme dette de la coque).
3. **Bloc identité du rail : division tronquée « Division d'accession a… »** sur Réception, Fiche du club, Sélections, Match, Options (le rang « · 6e » disparaît), alors que la capture Effectif montre deux lignes complètes. Rendu incohérent d'un écran à l'autre ; la fiche interdit « … » avant 12 px puis 2 lignes. Correction : un seul calcul (2 lignes à 12 px) sur tous les écrans.
4. **Continuer lit « CONTINUER | Préparer »** : le libellé de droite remplace « Espace » ; la maquette validée porte « Espace ». Le bouton se contredit (continuer ou préparer ?) et la touche n'est plus dite. Correction : « Espace » au repos ; « ! » + raison seulement si bloqué, comme en §6 de la fiche.
5. **Deux lignes de sauvegarde** : « ✓ Sauvegardé sam. 26/09 » (rail, vert `v`) et « Sauvegarde automatique · chaque semaine · dernière le 26/09 » (pied de contenu, gris) sur chaque écran. Deux sources, deux couleurs, même information ; le pied sous le contenu retire de la hauteur utile. Correction : garder la ligne du rail, supprimer le pied sur les écrans à coque.
6. **Date sans journée** : « sam. 26 sept. » seul ; la maquette porte « · J9 » en Barlow Bold Italic. Le code sait extraire la journée (regex « Journée n ») mais elle n'apparaît pas. Correction : afficher « J2 » à côté de la date.

## AVIS
7. Pour « plus de couleurs sans casser la charte » (règle 4 de Léo) : la coque seule reste presque monochrome (ivoire, noir chaud, liseré de club, ✓ vert). Le gain de couleur vient des clubs et du contenu. Choix défendable ; si Léo veut plus, la voie propre est la couleur du club (liseré, plaque d'écusson, filet actif teinté `club-trait`), pas de nouvel aplat.
8. Pictogrammes du pied de rail : « Carrière » est un anneau quasi fermé (proche du cercle interdit) ; les 9 entrées n'ont pas de pictogramme alors que les 3 du pied en ont. À harmoniser lors de la création des pictos (extrémités coupées à 10°, trait 1,5 px).
9. Le code porte encore un bouton « +1 j » (`next_day`) que la fiche (Q3) a tranché de ne pas montrer ; absent des captures, mais à retirer pour éviter un second bouton concurrent de Continuer.
10. Le contour 1 px `ivoire-3` sur Menu, flèches, Recherche reste l'écart de charte §3C accepté par la maquette : à inscrire dans l'art bible (annoncé en §7 du traitement visuel, pas fait dans l'art bible actuel).
