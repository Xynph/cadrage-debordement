# P4 — recherche de fixtures historiques, sans implémentation

Inspection en lecture seule le 11 novembre 2026. Aucune nouvelle fixture créée, aucun moteur modifié et aucun Godot exécuté. Ce rapport ne transforme pas une simulation adaptée en preuve d’un ancien EXE livré.

## Éléments disponibles

La fixture `tests/fixtures/roster-foundation-v1-s2.json.gz` existe dans Git depuis `3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21` (#395). SHA256 gzip vérifié : `92374c5b242f003649feecf029f4d9d4863fc98a22b83016583ba996510f3e99` ; JSON décompressé : 3 722 104 octets. `docs/roster-foundation-lot2.md:29` atteste un véritable export saison2 du binairev1 livré ; le plan lot2 cite `E:/Cadrage-Debordement/artefacts/roster-lot2/v1-s2.json.gz`. `docs/roster-foundation-lot1.md:9` documente l’archive lot1 de179 314 998 octets et SHA256 `abb2fd61de7a16466321344f749f4c854f15270a2fb51764897f01f3daf7044b`. Cela constitue une provenance documentaire existante ; aucun reçu machine reliant directement cet export précis à ce ZIP précis n’a été retrouvé ici. Ne pas inventer cette chaîne manquante.

`tests/fixtures/france-long-career-s6.json.gz` est un checkpoint de campagne déterministe avec scénario/graine/intégrité. Il n’est pas identifié comme export d’un EXE Windows livré. Les reçus de progression (`docs/progression-baseline-receipts.json`) contiennent des empreintes de profils, pas les octets de sauvegardes récupérables.

L’API GitHub Releases renvoie une seule release : [Windows96f5370](https://github.com/Xynph/cadrage-debordement/releases/tag/windows-received-96f537040bf9-43014276463-1), publiée le11novembre à12:38UTC. Le bundle de preuves local correspondant a été ouvert en lecture : SHA256 `69e3f72faa085106046dc3e2cd81e50b5e4b8f43bec8cb0036783b1ac2c673f9`, égal au manifeste `delivery.json`. Ses39 fichiers sont rapports, journaux, captures et notices ; aucun `donnees.json`, export de carrière, objet `state`/`store` ou texte `bdt-v1` dans les rapports/journaux. Le ZIP du jeu possède227 entrées, sans sauvegarde nommée. Les rapports prouvent des comparaisons de profils et RNG, mais ne permettent pas de reconstituer leurs octets depuis leurs seules empreintes. Aucun ancien ZIP publié ni export historique Monde n’a été trouvé dans les Releases accessibles.

## Pourquoi la vraie fixturev1S2 ne remplace pas le reçu financier Monde

Métadonnées lues sans modification : 30 clubs, club29, saison2, round0, phase `league`, `franceMode.version=1`, absence de `worldMode`, `aiRosterVersion=1` et `aiRoster.version=1`.

- `native/engine/world-finance-flow-audit.cjs:16` exige une semaine ordinaire `worldMode.version===1`. Appel purement en mémoire de `reconcile` avec cette fixture et une copie dont seul le round avance : rejet exact `Audit limited to one ordinary world-v1 week, no interseason`.
- Le reçu d’ordre des opérations `:52` exige saison1 et rounds0–2, phasesleague, politique IA v1, ajouts `emergency`/`promote` sans frais et résidu nul. Saison2 est donc hors fenêtre même si un faux `worldMode` était ajouté ; cet ajout ne doit pas être fait.
- `tests/world-finance-flow-audit.cjs:47` attend58 clubs et le premier scénario57 IA, dont les ajouts ciblés `[14,25,27]`. La fixture France30 ne porte pas cette population ou cette couverture.
- `ci/world-finance-flow-audit.cjs:49` n’accepte que `seed`, `weeks`, `club`, `out`. `:62` crée systématiquement une nouvelle carrière Monde ; ni import de sauvegarde, ni chemin de fixture, ni profil existant ne sont des options prises en charge.

Substituer la fixture France30S2 supprimerait donc précisément les assertions que P4 doit préserver. Elle reste pertinente pour ses tests existants d’archives/compatibilité commune, pas pour démontrer ce reçu financier Monde.

## Proposition limitée, non appliquée

1. Conserver les assertions financières actuelles : population58/57, ajouts14/25/27, fenêtre saison1/rounds0–2, couverture IA v1/v2, résidus, replay de facturation, invariants RNG/sport et refus de double paiement.
2. Renommer de façon contrôlée les cas actuels dont le worker est réécrit : « simulation isolée de couverture v1/v2 », plutôt que « fixture historique ». Le scénario de production actuel avec indisponibilité importée reste identifié séparément. Ces noms sont proposés ici, aucun code changé.
3. Pour une véritable réception historique Monde, obtenir un export intact produit par un ZIP archivé effectivement livré, à58 clubs/Monde v1, saison1 dans la fenêtre0–2, avec les cas de couverture pertinents ; conserver ZIP SHA, source SHA, empreintes export et profil/RNG, commande publique et reçu de production. Réutiliser les fichiers attestés quand ils existent ; ne pas réétiqueter une création actuelle ni patcher une VM pour fabriquer la provenance.
4. Ensuite seulement, concevoir un mode d’import explicite du banc et sa comparaison de continuation, en gardant toutes les assertions de1. Le ZIP96 actuel peut devenir une référence réelle pour de futures migrations après capture par son EXE, mais ne remplace pas rétrospectivement une sauvegarde Monde v1 manquante.

**Blocage précis :** aucun export historique Monde compatible ni chaîne machine export→ZIP trouvés. La fixture historique commune disponible ne satisfait ni le mode, ni la population, ni la saison/fenêtre du reçu. P4 ne peut pas être déclaré reçu sur cette seule base.
