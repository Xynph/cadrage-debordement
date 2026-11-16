# Bureau de référence Premium PC — 7 novembre 2026

## Intention et mandat

Réduire l'écart entre les concepts graphiques et le jeu natif dans `dist/`. Audit de toutes les vues, carrière neuve et carrière avancée par les mécanismes natifs, puis réalisation du Bureau. Léo autorise l'exécution autonome et l'intégration ordinaire ; la validation esthétique de ce Bureau précède l'extension aux autres écrans.

## Diagnostic directeur

La baseline main `0aa3a63` passe 315 assertions Chromium. Le Bureau répète deux fois la préparation du prochain match, utilise des chiffres serif et des libellés minuscules, masque les priorités et les messages dans Dossiers, et emploie un graphique de résultats trop peu explicite. Les grandes bannières prennent une place excessive dans les vues métier. Les autres vues et leurs parcours sont conservés dans ce lot.

## Approches examinées

1. Recolorer les cartes : faible risque mais ne résout ni la hiérarchie ni l'accès aux décisions.
2. Réécrire le jeu dans l'atelier React : rupture des raccordements natifs et hors demande.
3. **Choix d'implémentation : recomposer la vue d'ensemble dans la présentation native existante.** Une seule scène photographique pour le match, typographie expressive pour les titres, sans serif pour les textes et chiffres, composants de navigation et graphiques réels. Sous-pages Calendrier et Dossiers préservées.

## Composition

En-tête de Bureau compact. Grille de deux rangées : prochain match photographique sur deux colonnes et état du groupe à droite ; décisions, résultats/classement, journal du club en dessous. Vert profond, cuivre et ivoire ; polices et images locales déjà qualifiées. Portraits uniquement fictifs, stables par identifiant ; monogrammes en LNR.

Le match présente adversaire, lieu, rangs/points présents, préparation de la feuille et accès au centre natif. Le groupe présente condition, effectif et indisponibilités, plus les joueurs à examiner. Décisions issues de `officeDecisions()`, messages issus de `S.manager.inbox`. Aucun historique reconstruit. Saison terminée et données absentes explicitement traitées.

## Interactions

- Les décisions ouvrent le bon écran et le bon onglet (contrats, ventes, feuille ou disponibilité).
- Les portraits ouvrent les vrais dossiers.
- Les valeurs des graphiques sont visibles au survol, au focus et au clic.
- Le journal ouvre une fenêtre de lecture avec fermeture au clavier, marquage lu natif et accès au dossier concerné.
- Calendrier, Dossiers et commandes existantes restent accessibles, y compris après rafraîchissement.

## Contraintes globales

PC uniquement : 1920 × 1080 et 1440 × 900. Aucun défilement vertical global ; défilement local des panneaux si nécessaire. Aucun changement moteur, lois, coefficients, économie métier, format de sauvegarde, DATA/LNR, MATCH3D, auto-release ou gate. Préserver intégralement le match dédié #380. La consultation ne consomme aucun RNG et n'écrit pas dans la carrière ni dans son stockage. Échappement des libellés et validation des destinations.

## Réception

Tests purs pour les données manquantes et l'échappement ; parcours Chromium Windows sur le vrai jeu, deux tailles, thèmes sombre/clair, carrière neuve/avancée et LNR. Vérifier clics, navigation, fenêtres, nombres, géométrie et invariants. Capturer et inspecter les vues. Revue indépendante avant publication qualifiée. CI de la tête exacte, gate officiel et CI après fusion ; ne pas annoncer des résultats futurs.
