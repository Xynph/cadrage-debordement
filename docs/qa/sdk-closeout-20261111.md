# Clôture des corrections et recettes Godot

Candidat proposé : `ce76163160649f55228e59c647863017c4ed41e7`,
[PR brouillon #572](https://github.com/Xynph/cadrage-debordement/pull/572),
après [#566](https://github.com/Xynph/cadrage-debordement/pull/566).
**Les 35 suites demandées sont qualifiées**, avec une campagne complète puis
la reprise de son seul test corrigé. Le [reçu détaillé](sdk-closeout-20261111.json)
associe chaque cas à son commit, son run et son job réels : 48 invocations,
47 couples suite/cas distincts, le guide layout/native étant exécuté deux fois.

## Résultats et provenance

La [campagne complète 3018188](https://github.com/Xynph/cadrage-debordement/actions/runs/43084818218)
a reçu **47/48 invocations SDK**. Son unique échec était le test Carnet,
pas les 34 autres suites. Cette campagne reste rouge et son
[reçu complet](sdk-final-3018188-20261111.json) conserve ce résultat.

Le dernier test a été corrigé puis reçu localement : **3767 contrôles, zéro
échec**, sous la borne de 180 s. Les deux causes sont établies : numéro de poste
JSON converti en `0.0` au lieu de `0`, et sélection d'anciens boutons Banc/Stats
cachés. Le test utilise maintenant les vrais boutons visibles du direct,
vérifie l'ouverture effective du tiroir, puis effectue le remplacement autorisé.
Il ne modifie pas le jeu et ne retire aucun contrôle métier.

La [reprise GitHub 43089109020](https://github.com/Xynph/cadrage-debordement/actions/runs/43089109020)
est **SUCCESS**, avec **3773 contrôles / 0 échec en 79,307 s**. Elle exécute
seulement Carnet/default sur `ce76163` ; son
[journal et résultat lus indépendamment](sdk-final-ce76163-job-130761166993.json)
restent séparés du reçu local de 3767 contrôles. Le scope ciblé doit être demandé
explicitement ; une suite ou un cas inconnu est refusé avant installation.
Les événements normaux et le scope complet conservent tous les groupes et P1.
Les limites SDK de 180 s et VM de 15 s ne changent pas.

La réutilisation est vérifiée par contenu : **83 des 85 fichiers source du
reçu complet sont identiques**, seuls le GD Carnet et le workflow de sélection
changent. Un diff de tout `native/` et `dist/` entre les deux têtes est vide.
Il ne s'agit donc pas d'une deuxième campagne globale verte sur le nouveau
SHA, mais d'une campagne globale suivie de la reprise de son seul test corrigé,
avec provenance conservée pour chaque cas.

L'inventaire a également été comparé à la demande initiale : 26 suites de la
classification sur main96 et 9 wrappers de préchargement, soit exactement
**35 suites distinctes**, sans omission ni ajout substitué. Les matrices
découpées conservent tous leurs cas.

## Géométrie et comportement corrigés

P1 sur `3018188` : **4342 contrôles / 0 échec**, complément **1660 / 0**,
contrats **3/3**. Tailles : 1280×720, 1366×768, 1440×900, 1920×1080 et témoin
2560×1440. Les correctifs portent sur les contrats, le calendrier mensuel,
les entrées contextuelles, le Bureau et les copies de sécurité.

La régression de molette découverte pendant ces recettes est corrigée : les
listes intérieures consomment leurs événements aux deux bornes ; la page et
les en-têtes ne bougent plus. Les **604 contrôles Fatigue** passent aussi en
CI, dont les 24 nouvelles assertions de bornes. Le nouveau delta de production
par rapport au premier candidat vert `d83a817` est limité à trois lignes dans
`native/godot/ui/contextual/director.gd`.

Les [mesures, captures et états non couverts](sdk-final-3018188-20261111.md)
restent explicités. Les masques de certains boutons sur les écrans réservés
et les dialogues conditionnels non ouverts ne sont pas déclarés corrigés.

## Réceptions et limites restantes

Les [verdicts Claude](../reception-claude-20261111/INDEX.md) sont consignés :
#555 et #558 reçues ; #550 et #554 reçues comme expériences OFF par défaut ;
**#552, #553 et #573 à corriger**, avec reproductions. #573, publiée pendant
la clôture, passe ses contrôles fonctionnels mais échoue au test de sauvegarde
`france-saves` sur la limite VM de 15 s, deux fois dont un replay isolé. Le même
fichier inchangé passe sur main96 en 110,304 s ; aucun délai n'est augmenté.
Aucun correctif des sujets réservés à Claude n'a été repris dans cette tranche.

Les 625 suites Node déjà reçues sur `d83a817` gardent leur reçu propre : aucun
nouveau code moteur JavaScript ne justifie leur répétition. Linux/Godot réel,
X11/Mesa pour les cas graphiques, audio Dummy, profils jetables et Gabi
silencieux ; aucune nouvelle recette native Windows ni nouveau ZIP revendiqué.
Les drapeaux Windows et la fixture historique authentique manquante gardent
leurs limites documentées. Aucun changement de style ou des paramètres GitHub.

`main` reste `96f537040bf9f2e37bf10b0a9b09518b732244a2`. Aucune fusion n'est
effectuée, conformément à la restriction de cette tranche. L'intégration des
brouillons reste conditionnée à l'accord explicite de Léo.
