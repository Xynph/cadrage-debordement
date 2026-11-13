# Séance publiée — inscription SDK du 12 novembre 2026

Cette inscription part de `aa8caaf523f96f4da0ac389c20f99ceb17037b6f`. Elle ajoute **une seule suite et un seul cas** à [godot-sdk-followup.json](../../ci/godot-sdk-followup.json) : `tests/godot-calendar-session-links.cjs`, famille `portraits-staff`, cas explicite `default`, avec `CD_SESSION_LINKS_CAPTURE=1`. Le rendu utilise le Xvfb existant ; aucun nouveau job ou service n’est ajouté.

La recette consulte une séance publique par son ID exact, vérifie refus/gardes, focus, retour et absence de mutation. La spécification est [celle de la consultation de séance](../superpowers/specs/2026-11-12-calendar-session-reading-design.md). Le reçu graphique centralisé communiqué par root sur AA8 est **132 contrôles, zéro échec**, enfant terminé avec code 0, sous-test **50 309,563883 ms**, TAP **50 359,099146 ms**, parole demandes/débuts/identifiant **0/0/0**, un PNG réel **2560 × 1440** ; les préconditions de scroll du retour sont conservées (12 clavier / 123 souris). Cette inscription ne transforme pas ce reçu local en résultat CI.

## Limites réellement appliquées

Le wrapper conserve son enfant Godot à **90 000 ms**, audio **Dummy**. Le contrôleur SDK existant impose **180 000 ms** à chaque wrapper. Il ne consomme aucun champ de timeout par cas : la proposition initiale de budget parent 120 s a été retirée, sans champ ignoré ni modification du contrôleur. Les limites job **45 min**, VM **15 s**, les autres délais et sélecteurs restent inchangés.

| Famille | Wrappers | Exécutions followup | Enveloppe conservatrice | Marge sur 45 min |
| --- | ---: | ---: | ---: | ---: |
| portraits-staff | 15 | 21 | 44 min 44,022 s | 15,978 s |
| parcours | 18 | 21 | 43 min 23,432 s | 96,568 s |
| layouts | 13 | 22 | 43 min 22,874 s | 97,126 s |

Le calcul reprend le plan précédent (anciennes durées observées sur 7b23, 180 s par nouvelle exécution et 180 s de préparation) et ajoute **180 s**, pas 120 s, à portraits-staff : 2 504,022 + 180 = 2 684,022 s. Cette enveloppe n’est **pas une garantie de durée maximale** si les anciennes recettes dérivent jusqu’à leurs propres limites. Les 90 s enfant et le reçu local de 50,36 s sont distincts de cette réservation conservatrice.

Contexte mesuré, sans extrapolation de succès : le [SDK strict 7607](https://github.com/Xynph/cadrage-debordement/actions/runs/43138356742) a reçu portraits-staff en **828 s**, parcours en **1 400 s**, layouts en **765 s**, démarrages/fins de job compris, sur sa propre source sans ce cas. Ce ne sont ni les temps du futur HEAD ni une garantie de performance. Aucun déplacement d’anciennes suites n’est effectué. Déplacer une ou deux suites composantes actuellement réservées à 180 s vers parcours/layouts ferait dépasser 45 min à leur famille d’accueil selon le même calcul ; aucune redistribution opportuniste sur leurs seuls temps courts n’est proposée.

## Inventaire et vérification locale

Le followup contient **46 wrappers et 64 exécutions**. Avec les douze exécutions historiques : **76 exécutions, 57 suites distinctes et 75 couples suite/cas distincts**. L’unique doublon reste `tests/godot-guide-layout.cjs / layout-native`, présent deux fois historiquement. Les matrices P1 restent hors de ce décompte et obligatoires.

Les **six contrats Node existants** passent avant et après l’inscription avec Node **22.23.4**, sans Godot ni carrière. Ils contrôlent déjà unicité, groupes, fichiers, sélecteurs et règles de recettes existantes ; aucun test de format supplémentaire n’est ajouté. Une vérification locale distincte a confirmé les totaux, l’unicité de la nouvelle suite, sa seule famille et son unique sélecteur graphique. `node --check tests/godot-calendar-session-links.cjs` et `git diff --check` passent.

Hashes SHA-256 lus depuis les objets Git AA8 :

- wrapper : `78d4f161c32c68028941da764f365055dd2e8c3f8b781c03bfbf44734620b307` ;
- GD : `3fc6ae055bee08c10cf69d61298436c4c05a148b8651e32aba054cce14e51540` ;
- contrôleur inchangé : `8b7696517620c812777dd3c7072ecd359c7ba7e6105f0e0081a758721b862b6d`.

Aucun Godot, import, dispatch, relance, annulation ou push n’est effectué pour cette tâche. Root doit intégrer les revues/correctifs puis recevoir **une campagne SDK/JS commune du futur HEAD publié**, séparée des deux campagnes vertes de 7607. Les workflows, paramètres GitHub, budgets et règles de fusion restent inchangés ; aucune fusion Cloud avant 09 h Paris, passation à 08 h 30.
