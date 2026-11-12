# Silence : audit ciblé des 21 nouvelles inscriptions SDK

Audit statique de la source commune `37e085b687b4e9a603085beaa50fecf9d6cace22`, limité aux 21 nouveaux wrappers listés dans sdk-common-final-registry-20261112.md. Aucun Godot, import ni collecte exécuté pour cet audit. Dummy désigne un pilote audio sans sortie ; sa présence ne prouve pas l’absence de demande de parole.

| Parcours réel (`tests/` + nom) | Dummy explicite | Mute avant première attente sur common37 | requested/started vérifiés | `_id` vérifié | Suite locale proposée |
|---|---|---|---|---|---|
| godot-entity-navigation | Oui | Non gd:38–41 | Non | Non | Coordination core |
| godot-navigation | Oui | Non gd:98–101 | Non | Non | Coordination core |
| godot-gestion-carnet | Oui | Non gd:65–67 | Non | Non | Coordination core |
| godot-management-reading-flow | Oui | Non gd:76–80 | Oui gd:177 | Non | Coordination core |
| godot-finance-ledger-links | Oui | Non gd:73–77 | Oui gd:117 | Oui | Nouveau candidat cdb80c78 : mute immédiat |
| godot-training-identity-links | Oui | Non gd:80–84 | Oui gd:134 | Oui | Nouveau candidat cdb80c78 : mute immédiat |
| godot-analysis-club-links | Oui | Non gd:80–84 | Oui gd:132 | Oui | Nouveau candidat cdb80c78 : mute immédiat |
| godot-reader-history | Oui | Tardif gd:60–62 | Oui gd:47 | Non | Nouveau candidat cdb80c78 : mute/branchements immédiats et `_id` final |
| godot-profile-reading | Oui | Tardif gd:46–48 | Oui gd:34 | Non | Nouveau candidat cdb80c78 : mute/branchements immédiats et `_id` final |
| rg27-night-navigation | Oui | Tardif gd:609–611 | Oui gd:596 | Non | Coordination core |
| godot-analysis-club-graphics | Oui | Tardif gd:92–94 | Oui gd:181 | Oui | Coordination core |

Dix wrappers utilisent uniquement composants/fakehosts sans client ni coach : godot-entity-projections, godot-management-reading-links, godot-prospect-profile, godot-relationships-memory, godot-staff-fictional-labels, godot-world-entity-targets, godot-national-reading-links, godot-observed-training-consequences, godot-effective-training-receipt et godot-office-entity-links. Les compteurs de parole runtime n’y sont pas applicables. Tous avaient Dummy explicite sauf godot-staff-fictional-labels ; cdb80c78 ajoute uniquement ce pilote à ce wrapper, sans lui attribuer une preuve runtime de silence.

## Anciennes preuves et nouveau candidat

Les reçus antérieurs restent valides pour leurs assertions fonctionnelles exécutées. Lorsqu’un branchement sur requested/started intervenait après l’attente initiale, les compteurs prouvaient uniquement l’intervalle observé ; l’absence de `_id` final ne permet pas d’étendre cette preuve au cycle initial. Aucun reçu antérieur n’est rétroactivement requalifié en preuve de silence strict dès la création du client.

Le commit QA `cdb80c788e13533531dfec2995bd9e7c9ca0f1e0`, basé sur followup `fe56e8d8`, corrige seulement les cinq scripts lecteurs réservés et le pilote du fakehost staff. Chacun des cinq clients mute speech immédiatement après root.add_child, branche les deux signaux avant toute attente, et vérifie les deux compteurs ainsi que `_id == 0` en fin de parcours. Les cinq scripts ne recréent pas de second client : aucune reprise client à préserver dans ce périmètre. Tous les contrôles fonctionnels existants sont conservés. Produit, moteur, transport, registre et budgets inchangés.

Le candidat n’a pas encore de réception SDK : vérifications réalisées ici limitées à `node --check tests/godot-staff-fictional-labels.cjs` et `git diff --check`. L’intégrateur doit qualifier les scripts assemblés ; les corrections des autres lecteurs restent dans leurs périmètres attribués. Aucune revendication de nouveau vert runtime n’est faite par ce document.
