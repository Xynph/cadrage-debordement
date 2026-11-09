# Marché entre clubs — première tranche

## Conception
Le bureau permet de proposer une libération anticipée à un club concurrent pour un joueur majeur encore sous contrat. Le club vendeur peut refuser pour manque de profondeur ; le joueur et le vendeur ont chacun un seuil économique explicite. Les montants et accords sont des abstractions fictives de jeu, sans revendication de conformité à une fenêtre réglementaire réelle. L'ancien marché des agents libres et les ventes existantes restent disponibles.

Le contrat conserve son échéance ; le salaire proposé remplace le salaire courant. Le même objet joueur passe d'un effectif à l'autre et l'indemnité passe intégralement de l'acheteur au vendeur. Pas d'état ni migration de sauvegarde supplémentaire. La commande confirme un devis lié à saison/journée/club, salaire et échéance sources ; les refus ne modifient ni état ni hasard.

## Étapes
- Tests du domaine sur le vrai moteur : pureté de lecture, achat réel, refus et conservation de l'argent/des identités.
- Domaine interclubMarket et commande interclub_transfer, branchement réservé au root.
- Dialogue Godot filtrable depuis le recrutement, confirmation avant paiement.
- Réception worker avec export/reprise disque, limites et hooks documentés.

## Interface et réception
Ajouter dans le manifeste central `native/engine/native-systems.cjs` :
`interclubMarket:require('./interclub-market.cjs')`.
Aucun hook supplémentaire n'est requis ; les commandes du manifeste sont automatiquement transmises par le worker et la projection apparaît dans `model.clubLife.interclubMarket`. Le bouton de recrutement dans `squad_views.gd` ouvre le dialogue filtrable et paginé à douze profils. L'intégrateur doit embarquer le nouveau fichier `.cjs` dans le paquet moteur s'il existe une liste de fichiers fermée.

Huit tests marché couvrent lecture pure sans hasard, vraie transaction avec conservation de l'argent et des compétences, contrats et IDs, refus sans mutation, prêt, réserve de places, provision du nouveau salaire, deux achats successifs, rollback d'écriture disque, export/import et reprise du profil. Le vrai worker reçoit un manifeste temporaire incluant le domaine : cette fixture ne modifie pas le manifeste de production réservé au root. Réception supplémentaire du vrai worker Monde et validation des sauvegardes après achat.

Commandes réellement exécutées sous Node22.23.4 : `node --test tests/interclub-market.cjs tests/regen-scouting.cjs` (15/15 verts, dont sept recettes du marché et huit de détection existante). Godot4.7.2 Linux : import éditeur headless avec XDG dans `/tmp`, terminé sans SCRIPT ERROR, Parse Error ni ERROR. Aucun test Windows ou contrôle visuel interactif revendiqué.

Coût observé du domaine sur départ commun : 1 531 candidats, 321 932 octets JSON, 6,53 ms de moyenne sur vingt projections (mesure locale, non garantie matérielle). Les prêts sont collectés une seule fois par projection ; les pages sont filtrées côté dialogue. Aucun cache persistant ou coût de navigation.

## Limites explicites
- Première tranche : approche acheteur humain, accords immédiats, salaire demandé +5 % du contrat courant (minimum de recrutement : 1 000 €/semaine), même échéance. Les ventes humaines vers IA et la concurrence IA sur agents libres préexistent et restent inchangées.
- Pas de précontrat différé, d'offres IA concurrentes sur un joueur sous contrat, d'engagement réglementaire d'inscription ni de changement de fenêtre officielle.
- Le vendeur conserve 37 professionnels, deux joueurs de la famille et deux piliers du côté concerné. Les joueurs liés à un prêt sont exclus de cette tranche.
- Provision conservatrice de 400 000 € après indemnité et huit prochaines semaines du nouveau salaire (ou semaines restantes si moins de huit). Le plafond salarial des clubs IA n'est pas imposé au club humain : certains effectifs de départ le dépassent déjà ; les coefficients existants sont conservés.
- Aucun champ de sauvegarde nouveau. La simple consultation ne change pas une ancienne partie. Les validations et commits disque restent sous l'autorité du worker.

Recette UI Godot headless supplémentaire : `--script ../../tests/native-interclub-market.gd`, neuf contrôles réussis sur le dialogue réel (visibilité, pagination, indisponibilité, confirmation, commande/devis et recherche). Elle utilise un app contrôleur minimal et des données de test ; elle ne remplace pas une recette interactive du client complet.

Relecture indépendante : contrat source à salaire nul autorisé par le schéma. Le devis applique maintenant le minimum de recrutement de 1 000 €/semaine ; le test dédié vérifie la validité de la carrière avant et après achat.
