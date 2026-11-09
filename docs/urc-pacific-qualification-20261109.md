# Qualification Cloud — frontières URC / Pacifique

## Trou couvert

Le test `tests/srp-world-calendar.cjs` vérifie un calendrier initial Pacifique dans une VM avec effectifs synthétiques ; il ne passe pas par le worker public, son profil disque et sa reprise. `tests/world-worker.cjs` couvre la reprise PREM/URC de l'édition Monde v1. Le nouveau `tests/urc-pacific-rules-boundary.cjs` relie ces preuves pour le mode `world-pacific` v2 : la carrière jetable utilise le catalogue anonymisé versionné, une graine fixe et aucune ressource personnelle ou pack privé.

Le test ne réimplémente ni le calendrier ni la simulation. Il crée une carrière par `createBridge`, exporte et réimporte par les commandes publiques, ferme le worker et reprend le même profil avec une graine proposée différente. Une véritable journée mondiale est ensuite simulée deux fois depuis le même checkpoint privé : l'état de carrière, les résultats des matchs et le profil complet (curseur RNG et horloge inclus) doivent être identiques. La seconde reprise utilise encore une autre graine proposée. Le test vérifie que la journée consomme effectivement le hasard ; un entraînement seul ne le faisait pas et a été écarté comme preuve insuffisante.

Le checkpoint est restauré uniquement dans le répertoire temporaire créé par la suite, après fermeture du worker. Les profils utilisateurs et les fichiers de l'application ne sont jamais utilisés pour cette restauration. Les verrous sont libérés et le répertoire temporaire supprimé même en cas d'échec.

## Assertions de frontière

- Le calendrier Pacifique conserve ses 80 identités, dix clubs et 16 rencontres par club. La première saison jouée reste 2027 dans la carrière mondiale 2026–2027.
- Aucun club Pacifique ne participe aux poules ou rencontres des deux Coupes d'Europe, avant et après import et reprise avec continuation.
- Les lectures `snapshot` ne modifient aucun octet du profil. Une commande d'avance de préparation avec semaine périmée est refusée sans modifier ce profil.
- La projection URC initiale conserve les égalités comme non résolues. Elle ne déduit aucun départage disciplinaire de données non disponibles.
- Le calendrier 2027 peut être confirmé sans que les règles détaillées de match le soient : la référence détaillée Pacifique reste explicitement 2026. Appeler le barème sans opter pour cette politique est refusé.
- Le calendrier généré 2028 demande une politique explicite et ne reprend ni le statut officiel ni les heures UTC publiées du calendrier 2027.

## Éditions et sources vérifiées le 9 novembre 2026

La [page officielle URC](https://www.unitedrugby.com/about/competition-rules/) est accessible mais mélange encore la finale 2021/22, une date limite du 21 mars 2022 et les qualifications 2024/25. Elle ne fournit donc pas la preuve d'un règlement consolidé 2026/27. Le moteur conserve son repli explicite [URC 2025/26](https://d19fc3vd0ojo3m.cloudfront.net/irfu/wp-content/uploads/2025/09/26090041/001.-Championship-Rules-25_26__CLEAN.pdf) et corrobore séparément le format 2026/27. Aucune contrainte d'inscription de ces anciennes éditions n'est ajoutée par ce lot.

L'[annonce officielle du 1 juillet 2026](https://super.rugby/superrugby/news/expanded-season-and-high-stakes-finals-series-confirmed-for-2027/) confirme le format Pacifique 2027 : dix équipes, 17 tours, 16 matchs, top six, éliminations 3–6 et 4–5, puis demi-finales réattribuées selon les seeds. La [page détaillée](https://super.rugby/superrugby/about-super-rugby/tournament-format/) décrit expressément 2026 : le barème, les départages et les périodes supplémentaires restent des références provisoires pour 2027. Voir aussi [le périmètre Pacifique existant](super-rugby-pacific-2027.md).

## Validation et limites

Commande :

```bash
node --test tests/urc-pacific-rules-boundary.cjs
```

Sous Linux et Node 22.23.4 : **deux tests réussis, zéro échec, zéro ignoré**, environ dix secondes. Les suites existantes `world-competitions`, `world-urc-shootout-v5` et `srp-world-calendar` ont également passé leurs 28 tests pendant l'audit initial. La CI découvre automatiquement le nouveau fichier `.cjs` ; aucun changement de répartition, délai ou gate n'est nécessaire dans ce lot.

Cette preuve couvre une création, un import, une reprise et une journée de continuation de l'édition Pacifique. Elle n'est ni une campagne de saison complète, ni une validation d'un match Pacifique en point en or, ni une réception Windows. Elle n'établit pas les règles détaillées URC 2026/27 ou Pacifique 2027 qui n'ont pas été retrouvées. Aucun code de production, format de sauvegarde, profil réglementaire ou jeu de données n'est modifié.
