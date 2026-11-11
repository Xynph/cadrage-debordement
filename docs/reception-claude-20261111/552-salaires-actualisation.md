# PR 552 — nouveau head a25d3066, défaut de reprise conservé

Contrôle du 11 novembre 2026 à 15:50 UTC : le head de la PR est maintenant
`a25d3066a02da68fcc19818ff6fd7c92e5043ac2`, après `73b28ef3`.
La branche calendrier attendue n'est toujours pas publiée à ce contrôle.

Le delta de cinq fichiers ajoute l'application du salaire de la règle aux
renforts et joueurs de complément d'effectif, ainsi que leurs prévisions.
Il ne déplace pas l'installation des hooks budgétaires avant le premier
`snapshot`. Aucun changement de production n'est apporté par cette réception.

**Verdict maintenu : à corriger pour la première projection de reprise.**
La sonde indépendante de reprise a été exécutée sur une copie `git archive`
de ce head avec Node 22.23.4 Linux, graine 27, horloge 1794178800000,
nouvelle carrière commune club 29, puis fermeture et réouverture sans drapeau.
Le tout premier snapshot donne encore :

| Champ | Création ON | Première reprise |
| --- | ---: | ---: |
| Plancher salarial exposé | 270 € | absent |
| Recettes hebdomadaires prévues | 222 300 € | 160 000 € |
| Charges hebdomadaires prévues | 258 900 € | 50 670 € |
| Trésorerie prévue en fin de saison | 2 449 900 € | 6 017 220 € |
| Budget de saison | présent | absent |

La marque sauvegardée reste version 3 / 52 semaines. Voir
[la sortie de la sonde](../qa/experimental-flags-20261111/resume-projection-a25d3066.json)
et [son pilote](../qa/experimental-flags-20261111/resume-probe.cjs).
Ce résultat reproduit exactement le défaut déjà signalé, sans mutation
intermédiaire du nouveau bridge.

Les **deux tests nouveaux** ont été exécutés séparément : **2/2 PASS,
aucun saut, 2,902 s**. Ils couvrent renforts promus et ajout de joueurs pour
revenir à 40 professionnels, avec/sans marque. [Journal ciblé](../qa/experimental-flags-20261111/552-a25-targeted.tap).
Commande : `node --test --test-name-pattern='renfort promu|joueurs ajoutés' tests/club-budget.cjs`.

Les 53 tests du head précédent ne sont pas revendiqués comme une nouvelle
exécution de 55 tests. La comparaison d'exports OFF octet pour octet reste
elle aussi une preuve historique de `73b28ef3` contre son parent, sans nouvelle
qualification OFF de ce delta ni qualification contre main96. Aucun Godot,
rendu, Windows ni lot complet n'a été rejoué pour cette actualisation.
