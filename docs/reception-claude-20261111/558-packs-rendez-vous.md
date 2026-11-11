# Réception PR558 — accès aux packs pendant un rendez-vous

Candidat `dd094c17c0b36480742b8f15b26f463fbb45e456`, base main `96f537040bf9f2e37bf10b0a9b09518b732244a2`. Description et commentaires lus : aucun commentaire. Patch des trois fichiers appliqué sans conflit dans une copie jetable de main96. Blob produit testé `native/engine/club-meetings.cjs` : `804393acba4d4511701f05a3139b96b485a375db`, identique au candidat. Aucun fichier produit ni garde modifiés dans la branche de réception ; aucune écriture GitHub par le récepteur.

Léo a autorisé les packs pendant les rendez-vous : cette réception ne remet pas cette autorisation en question et ne demande pas de nouvelle confirmation.

## Lecture et périmètre du déverrouillage

`native/engine/club-meetings.cjs:24` ajoute exactement `pack_inspect`, `pack_install`, `pack_select` à la classification passive, employée par l’observateur `:118` et la garde `:174`. L’observateur ne ferme, ne consomme et ne décale donc pas un rendez-vous après sélection du pack. Les branches autorisant les vraies décisions de presse/médical/direction restent identiques. Le texte de refus `:26` conserve un vocabulaire du club et renvoie au courrier en Réception ; aucun avertissement sur une identité fictive n’est ajouté à l’écran.

Les commandes `pack_inspect/install` et `pack_select` de création passaient déjà avant la garde du worker. Le nouveau cas utile est la sélection pour la carrière, qui demeure soumise dans `worker.cjs` au scope `career`, au pack installé et à la compatibilité avec la base courante. Le retour à la base est bien autorisé pour une carrière dont le pack est absent.

Comparaison indépendante des gardes avant/après, dans le contexte de rendez-vous initial issu du test existant :46 commandes comparées ; les seules trois acceptations supplémentaires sont les commandes packs ci-dessus. Appels `observe` de ces trois commandes : état du rendez-vous strictement inchangé. Cette comparaison porte sur les gardes réelles, sans modifier le code du candidat.

## Tests API exécutés

- `tests/native-club-meetings-packs.cjs` officiel : **PASS** sur main96 + patch, avec profil jetable, analyse/installation, scopes création/carrière, pack→base, redémarrage, import sur poste sans pack, rendez-vous toujours présent, huit commandes sportives refusées, état exporté identique hors référence du pack, RNG durable conservé.
- Complément indépendant : **PASS** (rc0), exécuté après le test officiel, sans concurrence avec un autre test de réception. Il remplace la sélection du même pack après publication par une véritable bascule vers la base, vérifie encore l’état archivé et le RNG, ajoute quatre refus de fonctions non déverrouillées, un scope invalide, un pack absent et une invitation de conférence forgée. [Patch documentaire reproductible](../qa/pr558-packs-api-complement.patch.md), à appliquer seulement au test officiel dans une copie jetable du candidat.

Le test officiel `:59`–`:60` réapplique le pack déjà actif après la conférence ; à lui seul, ce passage ne prouve pas la bascule après publication. Le complément couvre ce point sans changer le produit.

## Conférence, brouillon et citations

La vue Godot existante `press_view.gd:135` réserve les choix à l’invitation ouverte depuis Réception. Son brouillon `:191` est indexé par invitation/contexte et conserve les réponses sélectionnées par IDs encore autorisés. Le test confirme que les IDs de questions/réponses sont inchangés par le pack ; ces mécanismes n’ont pas de delta dans558. L’API presse conserve sa validation d’invitation et des couples question/réponse. Ceci est une lecture du code/UI et une preuve API ; aucune interaction Godot visuelle n’est revendiquée.

La conservation des textes enregistrés et celle de leur présentation doivent rester distinguées. La description et `docs/packs-pendant-un-rendez-vous.md:28` reconnaissent que les noms contenus dans des citations affichées peuvent être substitués. Leur affirmation selon laquelle figer les textes obligerait à bloquer `pack_select` est incorrecte : préserver les champs de citation lors de la projection est une autre solution, déjà demandée dans la réception553. Corriger cette explication sans rétablir le blocage des packs.558 ne modifie pas la projection globale à l’origine de cette limite et ne démontre pas sa résolution ; ne pas présenter le présent reçu comme une réception « citations affichées mot pour mot ».

## Verdict et limites

**Verdict : reçu sur le déverrouillage autorisé et la conservation du rendez-vous/état enregistré.** Head dd094 confirmé inchangé à14:58UTC. Explication documentaire à corriger ; limite de projection des citations suivie séparément avec553, sans refuser l’accès aux packs.

Pas de SDK/Godot, Windows, test de rendu ou CI complète exécutés par cette réception. Pas de modification des commandes candidates de carnet, négociation ou académie ; leur éventuel déverrouillage reste un autre sujet.

Reproduction du complément :

```bash
repro_root=$(mktemp -d /tmp/rg27-pr558-packs.XXXXXX)
repro_patch="$(pwd)/docs/qa/pr558-packs-api-complement.patch.md"
git archive dd094c17c0b36480742b8f15b26f463fbb45e456 | tar -x -C "$repro_root"
(cd "$repro_root" && git apply "$repro_patch")
(cd "$repro_root" && /workspace/.cloud-setup/tools/node-v22.23.4-linux-x64/bin/node tests/native-club-meetings-packs.cjs)
```
