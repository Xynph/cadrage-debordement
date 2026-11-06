# Économie V2 — E2.3 : dette hors cash et cockpit PC consultatif

Statut : R&D non activée, PR DRAFT empilée #341 → #339 → #338 → #337. Aucun code de jeu ou sauvegarde modifié.

## Dette et intérêts

Les 14 clubs sont observés à chaque tour et intersaison. Le moteur courant fixe la dette dans `S.worldManagement.clubInfo[].debt`. Pour les **13 clubs IA**, `worldNewSeason` convertit un cash négatif en dette (sans masquer l'origine), puis `CDFinancialRecovery.annual` ajoute 4 % d'intérêts, avec remboursement éventuel jusqu'à 250 000 € selon la dette et la liquidité disponible. Le calcul de contrôle indépendant vérifie chaque dette de clôture avec tolérance strictement limitée à l'arithmétique flottante. Aucune modification de variable de jeu. Le club dirigé garde sa dette native inchangée à l'intersaison dans ce profil legacy. Les investissements d'installations restent des mutations cash et de niveaux ; aucune valeur d'immobilisation comptable n'est inventée.

## Engagements observables — limite explicite

Les salaires hebdomadaires, nombres de contrats à échéance, négociations en cours, choix sponsor et investissement académie sont capturés depuis le moteur. **Ce ne sont pas des dettes fournisseurs comptabilisées**. Les engagements non échus, les primes promises et les postes à payer de tous les clubs ne possèdent pas de journal complet daté permettant de les valoriser précisément : le champ `bookedPayable` est `null`, jamais forcé à zéro. Une comptabilité en droits constatés exhaustive reste ORANGE.

## Longues simulations et parité

6 campagnes (3 clubs × 2 graines) × 15 saisons × 29 tours, 14 transitions/campagne, 3 imports natifs/campagne. Cas de crise contrôlé : trésorerie IA négative + dette existante, vérification de la conversion, intérêts et remboursement par le moteur réel. Les états de sauvegarde et checksum sont comparés sans supposer que les horodatages `exportedAt` coïncident. JSON individuel par campagne : vraies séries annuelles `cash`, `debt`, salaires hebdomadaires et contrats échus, ainsi que composants de dette d'intersaison calculés à partir de la règle du moteur.

## Cockpit PC consultatif (non intégré au jeu)

Un HTML statique produit exclusivement à partir d'un **artefact JSON natif** de la CI ; 4 KPI (cash, dette, paie hebdomadaire, nombre de contrats expirants), graphiques de cash/dette sur 15 saisons, tableau de l'historique, sélecteur des 14 clubs, notes sur les limites et absence de faux flux mensuels. Test Chromium réel à 1920×1080 et 1440×900 avec captures PNG, vérification du sélecteur, graphiques, tableau et overflow horizontal. Les données ne sont ni un bilan réel LNR ni une migration de la carrière.

Aucun gate, aucune fusion, aucun chargement dans `dist/index.html`, aucune activation du noyau E1.
