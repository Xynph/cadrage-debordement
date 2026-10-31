# DATA-06 — Lot de statistiques officielles d'effectif

Lot vérifié manuellement sur les pages publiques LNR de [Clermont](https://top14.lnr.fr/club/clermont/effectif-staff) et de [Provence Rugby](https://prod2.lnr.fr/club/provence-rugby/effectif-staff) au 31 octobre 2026. **46 entrées** comprenant poste affiché, matches, minutes et points, sans prétendre que ces totaux représentent toute la saison. Les chiffres étant susceptibles d'évoluer, chaque fiche conserve la page source ; cette livraison est un instantané, pas une photographie au 01/07/2026.

- `modding/data06/official-roster-batch.json` : 46 lignes de faits publics pour 2 clubs.
- `tools/data06-roster-batch.cjs` : rapprochement unique club+nom aux 1592 IDs connus, aucun rapprochement approximatif ni création de joueurs si doute.
- `tests/data06-roster-batch.cjs` : assertions de source, cohérence des stats, impossibilité de fausse association, test de bout en bout sur le catalogue.
- `node tools/data06-roster-batch.cjs` affiche les comptes de rapprochement. `node --test tests/data06-roster-batch.cjs` lance les tests.

Le lot ne calcule aucune note de talent, ni salaire ou budget et n'écrit aucune sauvegarde. Il est complémentaire aux PR #142/143/144. **Les 1352 profils non enrichis ne sont pas déclarés complets.** Les lignes déjà couvertes par les 240 profils ne doivent pas être comptées comme de nouveaux profils entièrement enrichis. Pour atteindre les 30 clubs, l'accès et la vérification des pages restantes doivent respecter les conditions des sites et les validations de provenance.
