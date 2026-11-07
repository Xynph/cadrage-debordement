# Refonte native Premium — direction et plan, 7 novembre 2026

## Demande et direction

Léo demande de reprendre en profondeur tous les écrans du vrai jeu et d'y intégrer images, graphiques, police expressive et boutons fonctionnels. Références relues : quatre concepts IA Bureau/Effectif/Tactiques/Recrutement de la conversation. La petite amélioration du prototype P3 est jugée insuffisante.

Choix d'implémentation : une couche native de présentation, alimentée par les données existantes, préservant les nœuds et gestionnaires des commandes. La réécriture React complète ferait perdre les raccords existants ; une simple recoloration du prototype ne satisferait pas l'intégration demandée. Le nouveau module est chargé par dist/index.html, sans modifier game.js ou les modules métier.

Direction : vert forêt profond, cuivre lumineux, ivoire ; vrais titres serif italiques Cormorant Garamond et libellés Barlow Condensed, polices locales sous OFL. Photos rugby spécifiques aux espaces : match, groupe, préparation, prospection, relève, direction ; blasons vectoriels originaux pour les clubs fictifs. Visages décoratifs clairement fictifs, jamais présentés comme photos de joueurs réels LNR. Aucun chiffre peint dans les images.

## Périmètre

Menu et sélection de club ; les 14 routes dashboard/team/tactics/plans/staff/recruitment/match/league/history/market/formation/finance/saves/help, leurs sous-pages et fiches. PC 1920×1080 et 1440×900 ; défilement local, focus et contraste ; reduced-motion. Le direct garde ses commandes et surfaces de terrain intactes.

Graphiques : données enregistrées du club (condition, répartition du groupe, classement, résultats et profils documentés), pas de performances ou prévisions inventées. Les graphiques financiers existants restent les projections/historiques qu'ils annoncent. Commandes par nav et contrôles métier natifs ; aucune action figurative présentée comme active.

## Étapes et contrats

- [x] Capturer la baseline native et cartographier tous les conteneurs et sous-pages.
- [x] Produire des photographies propres, exporter WebP et embarquer les polices avec licences. Aucun chargement réseau à l'exécution.
- [x] Écrire les tests du manifeste, des graphiques sans mutation/NaN et de l'échappement ; observer leur échec, puis implémenter le module de présentation.
- [x] Appliquer la composition globale et les vues contextuelles, portraits, blasons, statistiques et graphiques. Conserver le HTML natif et les événements.
- [x] Exécuter les parcours des 14 routes et des sous-pages aux deux tailles ; vérifier sauvegarde/RNG invariants, recherche, fiche joueur, filtres financiers, menu et commandes. Inspecter les captures puis corriger.
- [ ] Revue indépendante, PR vers main avec tous les assets, CI exacte, réception réelle ; gate officiel si éligible. Aucun résultat futur anticipé.

Nouveaux fichiers : dist/premium-editorial.js et .css, dist/assets/editorial/**, dist/fonts/editorial/** ; tests/premium-editorial.cjs et premium-editorial-browser.mjs, workflow dédié. Réservation #73 6700207680. Base main 512e296467985d95284e1c3c3959b23e569019d2.

## Points de revue

Tout bouton existant doit rester accessible ; les sous-pages et fenêtres doivent rester dans le viewport ; longs noms/valeurs absentes ne doivent pas casser le rendu ; aucune photo fictive associée à l'identité réelle d'un joueur ; aucun changement de carrière, RNG, stockage ou règles pour une simple consultation. Tester les vrais parcours, y compris un nouveau rendu après action et les graphiques au clavier.

## État des outils

Penpot sans instance connectée au prévol : aucune écriture native revendiquée. Les références visuelles sont disponibles et l'intégration se poursuit directement dans le jeu. GitHub reste la référence du code et des preuves.


## Réalisation et preuves locales

Les 14 routes natives reçoivent la nouvelle composition, les photographies contextuelles, les titres expressifs et les surfaces de lecture. Huit images originales IA sont embarquées en WebP : six scènes rugby et deux atlas totalisant 32 portraits fictifs. Images et polices ajoutées occupent environ 1,4 Mio. Les portraits se basent sur un identifiant immuable : les 30 joueurs du groupe initial ont chacun un visage distinct ; les autres identités peuvent réutiliser ce jeu fini d'illustrations. Aucun portrait fictif n'est injecté sur les joueurs du mod LNR.

Le tableau d'effectif garde recherche, tris et colonnes natifs ; la fiche conserve tous ses onglets. Un terrain affiche les quinze titulaires réellement sélectionnés, et chacun ouvre son dossier. Les indicateurs du bureau, le classement, les courbes et répartitions utilisent les données disponibles. Le marché conserve ensemble ses onglets métier et leurs résultats. Les longs contenus restent dans des zones défilantes locales.

Parcours Chromium local : 307 contrôles réussis, 28 captures principales aux deux résolutions, plus menu, fiche joueur, finances claires et sauvegardes pendant match en pause. Vérification JSON de carrière et sauvegarde disque avant/après consultation, aucune erreur JS ni ressource manquante. Huit tests purs de présentation réussis ; 18 tests de régression ciblés sauvegardes/carrière/finances/présentation réussis avant les corrections de revue, puis nouvelle exécution ciblée après corrections. Captures inspectées réellement, y compris les quatorze vues principales. Le workflow dédié joint les captures et le rapport d'exécution sur le SHA publié.

Revue indépendante : quatre problèmes importants corrigés, puis vérifiés par parcours natifs — sauvegardes pendant match en pause, portraits auparavant indexés par ordre de groupe, onglets Mercato séparés de leurs résultats, contraste du cuivre en thème Tribune. Les listes de sous-pages exposent maintenant un rôle tablist et les commandes clavier. Les tests V4 conservent leurs contrôles et accèdent désormais aux véritables sous-pages avant mesure, avec les nouvelles scènes photographiques.

Limites : qualification Chromium Linux PC ; aucune certification Windows revendiquée. Penpot reste déconnecté. Les chiffres sportifs absents ne sont pas remplacés par des simulations. Aucun changement moteur, RNG, schéma de sauvegarde, DATA/LNR, MATCH 3D ou économie métier.
