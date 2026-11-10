# Scènes contextuelles natives — Implementation Plan

> For agentic workers: use the task briefs in `.superpowers/contextual-scenes/briefs/`. Parallel independent file ownership follows the user's explicit delegation preference.

**Goal:** Raccorder les décors validés et les causeries au vrai moteur de carrière.
**Architecture:** Deux domaines natifs persistants possèdent les causeries et les invitations. Une coque Godot contextuelle remplace la gestion pendant le match, réutilise le vrai rendu et les commandes existantes. Les vues restent sans effet tant qu'une décision n'est pas confirmée.
**Tech Stack:** Node/VM, GDScript Godot 4.6+, ressources locales gratuites.
**Spec:** `docs/superpowers/specs/2026-11-10-contextual-scenes.json` + demandes utilisateur : six déclarations simples et directes, ton intrinsèque, portraits et logo du club actif.

## Global Constraints

- XV adulte, saison simulée 2026–2027 ; aucune nouvelle loi sportive.
- Six déclarations contextuelles, originales, courtes et simples ; aucune commande de ton.
- Phases fondées sur `atHalftime(l)`/`live.finished`, pas minute 40/80.
- Mutations et reçus atomiques dans le worker ; lecture/snapshot purs, import ancien compatible.
- Identité et portraits du pack actif prioritaires, aucun OL/nom du jeu dans les lieux du club.
- Pas de menu de gestion pendant les séquences match ; aucune visite ne donne un bonus.
- Pas de push main ; nouvelle PR et CI exactes. Données réelles non modifiées.

## Review Focus

1. Reprise pendant chaque phase sans rejouer les effets.
2. Délégation auto compatible, aucun blocage de la boucle.
3. Valider le résultat et Continuer ne contournent pas le débrief.
4. Invitation expirée/participant parti/changement de club refusés.
5. Logos et portraits manquants : repli neutre explicite, aucune identité étrangère.

## Tasks

- [ ] 1. Banque et sélection : produire `dist/native-scene-dialogues.js`, sélecteur pur six choix et tests ; pas de mutation.
- [ ] 2. Domaine `match-talks.cjs` : phases persistantes, décision/skip/continue, délégation, reprise, rollback ; tests vrai worker après raccordement.
- [ ] 3. Domaine `scene-invitations.cjs` : courrier typé, joueurs/staff/réunions, fenêtres et reçus ; commandes contextuelles et tests.
- [ ] 4. Décors natifs sous `ui/contextual/rooms/` : charger identité réelle, supprimer les CLI/UI de démonstration, maintenir provenance.
- [ ] 5. Interface native sous `ui/contextual/` : causeries plein écran six choix, portraits, destinataires, match vivant, bureau et entraînement ; réutiliser G.portrait et le vrai match_view.
- [ ] 6. Raccordements parent : manifest/worker/main, points d'entrée courriers/entraînement, paquet natif et migration ; vérifications ciblées puis revue indépendante.
- [ ] 7. Captures réelles depuis carrière temporaire, tests de reprise/refus, PR prête avec état CI et passation.

## Coordination et arbitrages

Main vérifié `978803ba727e51c5af23f458868c6d56cc878966`. Nouveaux composants possédés par cette branche. Les anciens écrans de gestion restent disponibles ; les salles 3D ne reçoivent pas de route permanente. Les raccordements nouveaux à main/worker/manifest sont additifs et séparés des changements de Réception 516/520 et attente 498. Comparer leurs patches avant les écritures concernées ; ne pas réécrire leurs interfaces.
