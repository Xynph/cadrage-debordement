# Plan Clubs & Territoires — fondations de direction artistique

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for the native UI implementation. Les recherches atlas/Windows et l'audit moteur sont indépendants, délégués selon dispatching-parallel-agents. Une revue fraîche reçoit la branche complète.

**Goal:** donner aux trente territoires une identité visuelle propre, un centre Club natif et un cadre de management anthracite/ivoire.

**Architecture:** catalogue pur `CDFranceClubs`, atlas local documenté, présentation native `CDArtDirector` après les décorateurs existants. Les données de l'écran proviennent de la carrière et de ses projections. Le moteur à deux divisions aura son plan détaillé séparé issu de l'audit avant écriture ; il demeure requis pour la livraison finale.

**Tech Stack:** JavaScript/CSS natifs, SVG propres, WebP locaux, node:test, Playwright ; lanceur Go existant pour la réception ultérieure.

**Spec:** `docs/superpowers/specs/2026-11-07-clubs-territoires-design.md`.

## Contraintes globales

Trente territoires du snapshot projet, noms anonymisés avec villes reconnaissables, anthracite/ivoire/couleur club, aucune écriture BDD réelle, joueurs/valeurs/trophées non inventés dans la présentation, ressources locales sourcées, anciens modes/sauvegardes préservés. Cibles1440×900 et1920×1080.

## Points de revue

Résolution des photos différente selon ancienne fiction et LNR ; contraste des accents sombre/clair ; absence de donnée jeune/résultat/trophée ; licence/image manquante ; changement de club ou import sans ancien contexte visuel persistant.

### 1. Catalogue et atlas

Créer `dist/france-clubs.js`, `tests/france-clubs.cjs` ; intégrer les soixante images et leur manifeste dans `dist/assets/club-atlas/`, crédits dans `docs/club-atlas-credits.md`.

Interface : `CDFranceClubs.clubs` immuable, `get(idOrSlug)`, `division(key)`, `forCareer(state,clubId)`. Pour les anciens modes, résolution du territoire par table explicite ; aucune mutation de carrière. Photos `assets/club-atlas/<slug>-city.webp` et `...-stadium.webp`.

- [ ] RED :30identités distinctes, partitions14/16, aucun nom officiel exact, ID/slug stable, correspondances fiction/LNR, invariance des entrées.
- [ ] Exécuter les tests rouges, implémenter le catalogue pur, vérifier le vert.
- [ ] Intégrer les fichiers acquis indépendamment, vérifier signature/dimensions/licence/source pour chaque élément ; aucun fichier de peau FM ni exécutable de l'archive utilisateur.

### 2. Cadre et centre Club

Créer `dist/art-director.js/.css`, `tests/art-director.cjs`, `tests/art-director-browser.mjs` ; charger dans `dist/index.html`. Le contrôleur conserve ses états de consultation en mémoire, sans écriture de carrière ni RNG.

Interfaces : `CDArtDirector.clubModel(state,clubId,projections)` agrège uniquement les valeurs réelles ; `clubView(model)` produit du HTML échappé ; `openClub(id)` ouvre le centre natif ; `install(root)` raccorde rendu, navigation et couleur du club.

- [ ] RED : données absentes explicites, nom hostile échappé, invariants S/disque/RNG, clics vers pages réelles, navigation entre trente territoires, photos chargées et deux tailles PC.
- [ ] Implémenter cadre, centre Club, répertoire, hiérarchie Bureau/fiches et états vides ; garder les commandes natives et le match dédié.
- [ ] Capturer et inspecter les vues des deux couleurs et résolutions, corriger les défauts observés puis recevoir une revue indépendante.

### 3. Raccordement et livraison complète

Après le plan moteur : intégrer le nouveau mode sans altérer fiction/LNR, tests de sauvegardes renforcés et saisons natives avec accession. Après la réception de la branche : construire le ZIP de son SHA final, vérifier stockage et vraie fenêtre Windows, conserver les preuves et licences. Documentation et passation dans le même lot ; CI exacte puis gate et post-fusion. Ces tâches ne sont pas considérées terminées par la seule livraison graphique.
