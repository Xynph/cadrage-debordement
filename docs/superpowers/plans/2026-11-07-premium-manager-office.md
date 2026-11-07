# Bureau Premium PC — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Livrer un Bureau natif lisible, beau et actionnable à partir d'un audit illustré du vrai jeu.

**Architecture:** Composition en lecture seule dans `premium-editorial.js`, styles limités au Bureau dans `premium-editorial.css`. Données du snapshot et des API métier natives ; actions déléguées aux fonctions existantes.

**Tech Stack:** JavaScript natif, CSS Grid, polices et WebP locaux, Node test et Playwright/Chromium.

**Spec:** `docs/superpowers/specs/2026-11-07-premium-manager-office-design.md`

## Global Constraints

- PC uniquement : 1920 × 1080 et 1440 × 900.
- Aucun défilement vertical global ; défilement local des panneaux si nécessaire.
- Aucun changement moteur, lois, coefficients, économie métier, format de sauvegarde, DATA/LNR, MATCH3D, auto-release ou gate.
- Préserver intégralement le match dédié #380.
- La consultation ne consomme aucun RNG et n'écrit pas dans la carrière ni dans son stockage.

## Review Focus

- Fin de saison et adversaire absent : pas de faux match ni de commande indisponible.
- Noms longs, corps de messages et attributs HTML : textes échappés, lignes contenues.
- Carrière avancée : priorités, blessures, scores et messages réellement enregistrés.
- Navigation depuis un dossier joueur ou une sous-page mémorisée : destination correcte.
- Thème clair et clavier : contrastes, valeurs, focus et fermeture de fenêtre.

### Task 1: Composer le Bureau de référence

**Files:** `dist/premium-editorial.js`, `dist/premium-editorial.css`, `tests/premium-manager-office.cjs`.

**Interfaces:** `officeView(snapshot, details)` produit la composition ; `details` contient décisions, messages, sélection, mode LNR et état de la feuille. Ne modifie aucun objet fourni.

- [x] Écrire et observer rouges les tests de résultats absents, mode LNR, échappement et absence de mutation.
- [x] Implémenter `officeView` et l'intégrer à pilotage ; garder Calendrier et Dossiers.
- [x] Styles propres au Bureau, deux rangées, typographie lisible et panneau local.
- [x] Exécuter tests purs et capturer les deux tailles.

### Task 2: Raccorder les interactions réelles

**Files:** `dist/premium-editorial.js`, `tests/premium-manager-office-browser.mjs`.

**Interfaces:** attributs `data-ed-office-*` vers API natives ; messages dans fenêtre dialog ; graphiques `data-ed-info` déjà supportés.

- [x] Ajouter un parcours qui échoue avant les nouveaux raccords : contrats, feuille, portrait et détail de message.
- [x] Raccorder onglets métier et lecture de messages ; conserver focus et valeurs accessibles.
- [x] Vérifier les états neufs, avancés, LNR, saison terminée et noms longs sans mutation à la consultation.

### Task 3: Audit, preuves et livraison

**Files:** `docs/premium-manager-office-20261107.md`, `docs/premium-manager-office-captures/**`, `DEVELOPPEMENT.md`, tests ci-dessus.

- [x] Documenter les vues observées aux deux tailles, priorités et limites ; captures avant/après.
- [x] Exécuter les régressions éditoriales, match dédié, sauvegardes et tests ciblés métier.
- [x] Revue indépendante du diff et captures ; corriger les défauts importants.
- [ ] Publier PR et passation #73, réceptionner CI exacte, fusion officielle sérialisée puis CI du commit fusionné.
