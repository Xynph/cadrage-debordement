# Réception visuelle réelle des LOD — 5 novembre 2026

## Provenance
- Workflow Chromium `42020901993`, HEAD `beb4a7ae1f5036cb6e2ebb97cda2d92f65d6b6c3`, terminé SUCCESS.
- Artefact `match3d-v24-lod-browser-report` ID `13412355198` : neuf JPEG (3 LOD × idle/passe/plaquage), rapport JSON ; téléchargés et inspectés manuellement.
- La CI établit le chargement offline, 53 os, quatre clips rugby supplémentaires et déformations finies, **pas** la qualité esthétique.

## Décision de réception : REFUSÉE pour intégration des 30 joueurs
- LOD0 : silhouette adulte habillée reconnaissable ; maillot bleu avec graphisme amont, short et bottines non qualifiées rugby.
- LOD1 : aspect encore reconnaissable, réduction et petits défauts observables.
- **LOD2 : défaut visible** aux épaules et sur le maillot (zones claires, surfaces trouées/déchirées), déjà dans la vue statique et aggravé pendant les poses de passe/plaquage.
- Les poses de passe et plaquage sont bien déclenchées, mais les bras restent trop écartés pour une animation rugby de production.
- Les captures correspondent à un joueur isolé, non à une réception TV/zoom des 30 joueurs ; aucun résultat FPS mesuré dans ce jalon.

## Action corrective en cours
- Ajuster les budgets LOD2 par composant pour privilégier les vêtements et préserver les bordures topologiques des vêtements lors de la simplification.
- Rejouer le même test Chromium et comparer réellement les neuf captures ; **ne pas déclarer corrigé sur le seul succès structurel**.
- Garder la PR #300 DRAFT ; pas de gate ni fusion. Raccorder au runtime seulement après résolution visuelle.

## Reconstruction corrective publiée, réception à refaire

Le constructeur a publié sur la branche PR #300 le rapport LOD2 corrigé : **2 549 triangles** au total, dont **1 469 corps, 534 T-shirt, 214 short et 332 chaussures**. Ancien maillot LOD2 : 91 triangles. Cette redistribution ne prouve pas que les surfaces trouées ont disparu. Les CI du commit automatique sont notées `action_required` : il faut une nouvelle exécution déclenchée normalement et les nouvelles captures avant validation visuelle.

## Jalon cinématique v24c — corrections des amplitudes

L'inspection des 9 captures Chromium précédentes refuse les manches/épaules trop ouvertes lors de passe et plaquage. Le présent changement réduit les rotations **uniquement dans les clips de présentation** (sans modifier les os, les GLB, le moteur, les sauvegardes ni le runtime de match). Les amplitudes de bras de passe et plaquage restent sous 1,05 rad dans les tests unitaires. Le résultat visuel demeure à vérifier via `MATCH 3D v24 - qualification LOD et gestes`; une CI verte n'est pas à elle seule une preuve d'absence d'intersection vêtement/peau. PR reste DRAFT.
