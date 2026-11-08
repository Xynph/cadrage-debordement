# Sauvegardes et délégation native — performances et compatibilité

## Problème et périmètre

La CI post-fusion de la PR397, main `6c38020a`, dépassait180s sur deux campagnes. Une première optimisation des accès globaux du validateur et du checksum passe les contrôles de parité, mais sa CI `42513824213` reste rouge : Academy-integrated-long passe164,11s, Support-season atteint encore180s. Aucun délai ou scénario n'est réduit.

Le profilage du vrai parcours Support isole ensuite `save()` : environ51% du coût. Une seule délégation construit88fois la représentation JSON de la carrière, soit293,8Mo, alors que la persistance disque et la réponse sont déjà transactionnelles par commande. Les optimisations supplémentaires des seuls helpers ou du JSON de la VM sont mesurées puis écartées, faute de gain substantiel.

## Comportement final

Les saves mémoire intermédiaires de la seule commande synchrone `delegate` sont différés. La validation finale, le dernier save, la persistance atomique, les limites, les formats et le rollback restent en place. Aucun effet de match, RNG, statistique ou règle de compétition n'est modifié.

Toute lecture inattendue du storage pendant cette tentative active une barrière privée. L'état S, le playback, le store, le RNG et l'horloge sont restaurés au contexte initial de la commande, puis la délégation historique est rejouée une seule fois avant toute persistance ou réponse. La détection reste active même si le core absorbe l'exception. Le save original et les indicateurs sont restaurés par un finally hôte, y compris après interruption VM.

La garantie porte sur les données JSON valides du protocole/import et sur le core chargé. Elle ne promet pas l'équivalence générale de fonctions JS arbitraires injectées dans S : le nombre et l'instant des appels `toJSON` changeraient. Ce contre-exemple est documenté hors contrat ; il n'est pas compté comme test réussi. Les contrôles d'import et l'allowlist restent stricts. Aucune migration de carrière n'est nécessaire.

## Mesures appariées reçues sous Windows

Archive de référence exacte : `f88e16fdbbffec38c1259f21a156ac6217374b12`. Chaque campagne d'origine garde34semaines,30rencontres,9reprises et ses projections pures ; plafond180s par exécution.

| Runtime | Référence | Candidat | Réduction observée |
|---|---:|---:|---:|
| Node22.23.4 | 123,486s | 64,347s | 47,9% |
| Node26.13.0 | 86,053s | 43,378s | 49,6% |

Chaque paire compare directement les403897679octets de ses265réponses JSON, sans normalisation. L'export3804713octets, le profil8655095octets, le seed et l'horloge sont aussi identiques. Les empreintes export/profil concordent entre les deux versions de Node. Les sources et le test d'origine sont empreintés avant/après. Les campagnes sont séquentielles ; la clôture de la campagne UI précédente a été vérifiée36,9s avant le lancement Node22. Ces temps locaux ne prédisent pas un temps garanti sur un runner Linux.

## Tests et revue

- `native-delegate-transaction06.cjs` :11cas appariés complets et vrai stdio, réussis sous Node22 puis26, sans skip. Les checkpoints sont préparés par de vraies commandes jusqu'à72min, afin de cibler les contrats sans rejouer onze matchs entiers ; les campagnes longues originales restent inchangées.
- Lectures après tick, mutation après save, lecture absorbée, autre clé, fautes de persistance réelles avec et sans repli, import invalide/prototype, texte `toJSON`, horloge dynamique, vraie interruption VM et reprise sont contrôlés. Réponses, exports et fichiers complets restent comparés.
- Le témoin historique capture verbatim le seul ancien bloc delegate, avec SHA et origine ; il fonctionne sans Git ni archive externe, dans des fixtures jetables. Aucun commutateur runtime de désactivation n'est ajouté.
- `godot-engine.cjs` conserve la compatibilité historique14clubs, délégation, RNG, refus disque, import/reprise et JSON-lines sous22/26.
- `native-save-hotpaths06.cjs` conserve205checksums, corpus hostile, messages, limites200000/400000/650000nœuds et ordre des contrôles, sous22/26.
- Revue indépendante du worker et du témoin final : aucun P1/P2 établi dans le contrat déclaré. Les premiers RED du harnais (timestamp numérique hors borne, préparation arrêtée avant72min) ont été corrigés dans les seules fixtures ; aucun validateur n'a été élargi.

Worker reçu : SHA-256 `ec18d95e6ae1ab7a176f5b520e7423c55407577a91d252bad64ac1ebb1403d44`. Témoin reçu : `37e11a1f3d91b7bbf1f381081e36f79b2da08327faeb00d270ac0c28cb1e84ee`.

## Réception restante

La nouvelle tête de la PR398 doit recevoir sa propre CI Linux, le gate officiel, puis les sept jobs post-fusion. La CI rouge de la première tête n'est pas effacée ni présentée comme un succès. Le prochain paquet Windows doit également intégrer cette tête et recevoir sa propre recette. Les preuves locales détaillées sont dans `E:/Cadrage-Debordement/artefacts/native06-20261108/perf-second/` et `revue-perf-delegate.md`.
