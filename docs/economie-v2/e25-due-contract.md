# Économie V2 — E2.5 : contrat de paiement certain, version 1

**Module de recherche non activé** dist/economy-v2-due-contract.js ; ne pas charger dans la page de jeu ni écraser les sauvegardes existantes. E1, E2.1–E2.4 restent immuables dans la pile de PR.

## Contrainte : ne pas inventer de passif

Un salaire hebdomadaire ou une échéance contractuelle contractEnd, une offre de vente, une contre-offre ou une décision de budget ne constituent **pas automatiquement une dette exigible**. Seule l'attestation documentaire **explicitement fournie** par une future intégration (type autorisé, identifiant de pièce, montant entier positif, club, période d'attestation, échéance) permet d'enregistrer un objet. Le module ne vérifie pas la vérité externe de la pièce : un connecteur futur devra authentifier le document et garantir l'unicité de sa référence. Aucun mécanisme automatique dans le jeu ne crée une telle pièce.

Les champs de create sont {version:1, obligations:[], payments:[]}. register accepte un engagement explicitement attesté (pas forcément encore échu), mature marque seulement la dette arrivée à échéance, settle exige la référence explicite de paiement et une échéance passée, refuse tout remboursement duplicatif. Toutes les opérations sont immuables. Les contraintes validate rejettent doublons, modifications, incohérences entre état payé et justificatif et paiement anticipé.

**Important** : le registre ne débite pas la trésorerie du jeu et ne simule pas de virement bancaire. Il mémorise uniquement une attestation de règlement ; le futur raccordement devra lier atomiquement ce reçu à une écriture comptable E1 **sans jamais débiter deux fois**. Les références paymentId et receiptRef sont uniques pour chaque club. L'objet summary retourne les montants des pièces enregistrées et les valeurs du legacy **non mesurables** sous null.

## Compatibilité anciennes sauvegardes

legacyPreview(save.state) est strictement **lecture seule**. Il n'ajoute ni champ à l'ancienne sauvegarde, ni document, ni financement, ni compte fournisseur ; il rend le passif historique indisponible (null) et un registre de recherche vide à activation **non activée**. L'absence de facture constatée ne prouve jamais l'absence d'obligations dans les carrières historiques. Un format optionnel de sauvegarde et une migration volontaire ne sont **pas implémentés** à E2.5. Le JSON V1 est validable et sérialisable indépendamment.

## Tests

Tests métier, contrôles natifs des trois profils, stress : exigibilité/retard, dette de crise, reçu unique, rejeu identique, refus de détournement de justificatif, corruption JSON, contrôle d'immuabilité et parité sauvegarde. 3 profils × 2 graines × 15 saisons et trois imports/campagne, dont les quatre audits E2.1 à E2.4. Chaque job produit un JSON audit et exécute les tests E1 et l'ensemble de la pile. Les scénarios de facture E2.5 sont des **fixtures contrôlées explicitement construites**, jamais des données financières historiques du jeu.

**FEU VERT de développement** n'autorise pas activation des paiements ni fusion : gate, migration de sauvegardes et branchement réel E1 restent des étapes distinctes.
