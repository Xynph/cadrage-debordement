# Écran dédié au match — 7 novembre 2026

## Comportement livré

Écran indépendant des menus, terrain entier 2D ou 3D, caméras TV large/tactique haute seulement. Score/chronomètre, statistiques permanentes à droite, huit portraits du banc conservés après entrée avec statut, commentaire en une ligne en bas. Les visages sont des illustrations fictives stables par identifiant ; aucune association de faux portrait aux joueurs LNR.

Tactique : composition, consignes générales, pénalités, quatre zones et phases arrêtées, brouillon confirmé ensemble. Remplacements : fenêtre directe, présélection par portrait ou joueur de votre équipe sur le terrain. Fenêtre ouverte : cadence de présentation réelle seconde par seconde, sans sauts de résumé et sans pause imposée par la consultation ; pause manuelle et pauses nécessaires restent prioritaires. Fermeture : mode et vitesses précédents retrouvés. Sélecteurs conservés pendant le rafraîchissement.

Remplacements confirmés en attente du prochain arrêt de jeu, annulation possible ; revalidation transactionnelle par projection avec `makeSub`, puis mêmes API de remplacement, aucune règle sportive ajoutée. Raccordement à `flowBeforeRestart` pour exécuter avant la reprise native, jamais en ballon vivant. File persistée hors carrière, empreinte saison/tour/équipes/feuilles initiales et rééligibilité à la restauration. Refus visible en cas d'indisponibilité ou erreur de stockage.

Match intégral / résumé long / temps forts ; vitesses des actions ×1/2/4/8/16 et entre-actions ×30/60/120/300. Paramètres toujours accessibles, mémorisés hors carrière, accès menu pause/sauvegardes. Résultat immédiat séparé : confirmation explicite, annulation invariante, simulation de tout le temps restant par `advanceRugby` et IA native appliquée au côté utilisateur via vue automatisée, sans blocage à mi-temps ni boucle de rendu. Validation de journée conservée.

Pauses impératives : mi-temps, nouveau rouge d'une équipe, blessure sur le terrain nécessitant une intervention. Conseils V61 natifs applicables au clic, état appliqué visible. Toutes les dernières actions sont drainées avant validation du résultat.

## Statistiques et limites précises

Comparatifs issus des compteurs existants : possession, occupation, essais, mêlées/touches conservées et tentées, tirs de pénalité, transformations, pénalités concédées, jaunes et rouges. Actions de progression, récupérations et jeux au pied issus des événements structurés, lorsque présents. Fenêtre détaillée : comparatifs, courbe de possession avec valeurs au survol, événements horodatés, minutes/condition et actions attribuées par joueur.

Pas de faux plaquages, mètres gagnés individuels ni défenseurs battus : ces compteurs ne sont pas collectés actuellement. La courbe commence à l'ouverture du suivi (pas de reconstruction d'historique absent). Les secondes règlent la présentation du moteur discret par minutes/séquences ; elles ne créent pas une simulation physique à la seconde. Les blessures du moteur actuel sont surtout calculées après le match ; le contrôleur ne crée aucun incident artificiel pour remplir l'interface. Les anciens matchs conservent leurs règles natives.

## Vérification

Plan et spécification validée : `docs/superpowers/specs/2026-11-07-dedicated-matchday-design.md` et `docs/superpowers/plans/2026-11-07-dedicated-matchday.md`.

Tests Node : préférences invalides, absence de fausses mesures, huit matchs appariés à mêmes graines (état carrière final strictement identique au moteur natif avec même gestion de l'adjoint), changements effectifs, exports/imports, secondes, pauses, file restaurée, dernière séquence à plusieurs événements et cinq vitesses linéaires. Régressions match-actions/cockpit/flow et sauvegardes exécutées.

Parcours Chromium : deux tailles PC et deux thèmes, géométrie, stats toujours visibles, contraste, ticker discret, six fenêtres, clics, clavier/focus, consultation sans RNG/mutation de carrière, remplacements réellement différés à une reprise native, annulation, plan détaillé groupé en temps réel, conseil applicable, confirmation, délégation, sortie vers le club, préférences restaurées et LNR sans faux portrait. Canvas 3D entier et 16:9. Captures supplémentaires à 62 minutes d'un match réellement joué.

Revue indépendante suivie de corrections : fin multi-événements, cadence linéaire, persistance de file, clic mini-terrain, anciens sélecteurs contournant la file ; contre-revue sans nouveau défaut important. Assertions historiques adaptées à l'écran validé, parcours et invariants conservés. CI exacte, artefacts et éventuelle fusion documentés dans #73 après réception ; aucun succès distant anticipé. Pas de certification Windows native.

## Périmètre

Contrôleur et shell dans `dist/premium-editorial.js/.css`, sans toucher `index.html` réservé au chantier LNR. Aucun fichier moteur, coefficient, schéma métier de sauvegarde, source MATCH3D, DATA/LNR, finance ou gate modifié. Les préférences et intentions en attente utilisent les clés `bdt-matchday-preferences` / `bdt-matchday-pending` de `gameStorage`.
