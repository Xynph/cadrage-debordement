# PR 573 — calendrier : à corriger pour réception

**Verdict : À CORRIGER**, au SHA exact
`d88dc4db7a87a165a1bbfc25ed269f4008a47d6b`.
L’alternance et la compatibilité fonctionnelle contrôlées passent, mais la suite
`france-saves` annoncée verte échoue deux fois sur la limite VM existante de 15 s,
dont une fois seule. Le même fichier, inchangé, passe sur `main 96f5370`.
Aucune limite n’a été augmentée et aucun fichier de production n’a été édité.

La [description et les fichiers](../qa/reception-claude-573-20261111/pr-573-metadata.json)
ont été lus ; à la dernière lecture, la tête est toujours celle ci-dessus,
sans commentaire, revue ni commentaire de code. Fetch et archive isolés dans
`/tmp/rg27-review-573-git` et `/tmp/rg27-review-573-source` ; branche commune
inchangée. [Provenance](../qa/reception-claude-573-20261111/review-provenance.json),
[SHA des 13 fichiers reçus](../qa/reception-claude-573-20261111/reviewed-files-sha256.json).

## Résultats observés — Linux, Node 22.23.4, sans Godot

| Réception | Résultat | Preuve |
| --- | --- | --- |
| 13 fichiers Node annoncés, concurrence plafonnée à 2 | 29 tests verts, 1 rouge ; 180,561 s | [Log complet](../qa/reception-claude-573-20261111/targeted-node-suites.log), [reçu](../qa/reception-claude-573-20261111/targeted-node-suites-result.json) |
| `france-saves` candidat, rejoué seul | Échec à 110,106 s : VM 15 s, ligne 13:387 | [Log](../qa/reception-claude-573-20261111/france-saves-isolated.log), [reçu](../qa/reception-claude-573-20261111/france-saves-isolated-result.json) |
| Même `france-saves`, main 96 vérifié par root | PASS en 110,304 s, mêmes limites | [Log](../qa/reception-claude-573-20261111/rg27-france-saves-main96.log), [reçu root](../qa/reception-claude-573-20261111/rg27-france-saves-main96.json) |
| Compilation Base commune, Monde, staff, `--check` | 3/3 vert | [Reçus](../qa/reception-claude-573-20261111/builder-checks-result.json) |
| Sonde indépendante, ancien profil96 réellement avancé | 35 assertions vertes en 36,261 s | [Résultat](../qa/reception-claude-573-20261111/independent-probe-result.json), [log](../qa/reception-claude-573-20261111/independent-probe.log), [script exécuté](../qa/reception-claude-573-20261111/independent-probe.cjs) |

Le blocage solo précis est `good(b,'finish_round')` après la simulation déléguée
et une publication disque volontairement refusée ; ce n’est pas l’import de fin
de saison. Le batch avait aussi rencontré VM 15 s dans la projection du worker.
La cause de performance n’a pas été isolée et la charge CPU peut peser sur cette
limite : ces reçus ne prouvent pas à eux seuls une erreur d’algorithme sportif.
Ils empêchent néanmoins de recevoir sans réserve la recette annoncée verte.
Prochaine étape producteur : rendre cette séquence recevable avec les limites
existantes, puis relivrer son SHA ; aucun troisième replay n’a été ajouté ici.

## Ce qui est établi fonctionnellement

Les 6 nouveaux tests passent : unicité par journée, multiplicité des adversaires,
retour inversé en miroir lorsqu’applicable, équilibre, séries de réceptions et
déplacements, déterminisme et empreintes des anciens générateurs. Les voisins
calendrier/courrier/planification, atelier, cadence France, Japon et reprise LNR
passent ; seul `france-saves` bloque la réception.

La sonde crée avec le moteur96 une carrière France à J1, avec 15 résultats déjà
joués. Le nouveau moteur reprend et importe son état complet sans le réécrire,
conserve les octets lus, les résultats acquis et le RNG à l’import. Deux copies
issues du même checkpoint donnent exactement le même état et RNG après le même
entraînement. Un calendrier altéré à checksum valide est refusé sans changer
l’état ni le profil. Les 1592 profils sportifs de la Base commune régénérée sont
strictement identiques ; ses métadonnées de source suivent le changement de
`game.js`. [Périmètre du checksum de cette fixture](../qa/reception-claude-573-20261111/checksum-probe-scope.json).

Le choix de compatibilité est conforme à la portée acceptée par Léo : saisons
anciennes relues telles quelles, nouveau générateur pour les suivantes. Les
nouveaux résultats d’une saison nouvellement générée ne sont pas supposés
identiques après changement des affiches ; les résultats déjà acquis sont bien
préservés dans la sonde. La transition complète d’un ancien Monde ou centre de
formation n’a pas été rejouée indépendamment : leur lecture et les empreintes de
compatibilité sont couvertes, pas une preuve exhaustive de migration.

Les références rugby et données ont été consultées : le plafond de 2 rencontres
consécutives est un choix de calendrier simulé, pas une loi World Rugby. Le
retour en miroir reste une abstraction déclarée ; 4 clubs peuvent produire une
série de 3, et les calendriers publiés reconduits gardent leurs séries réelles.
Aucune conformité exhaustive LNR 2026–2027, exécution Windows ou lecture Godot
n’est revendiquée. [Synthèse machine avec limites](../qa/reception-claude-573-20261111/final-review-result.json).
