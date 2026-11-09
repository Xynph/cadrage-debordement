# Progression des jeunes — contrat livré et vérification

Source fonctionnelle : `014aa19df07d91a2ea04725878388df1f0205eea`, depuis l'intégration `f55ca4a`. Le lot crée une factory native de suivi et trois affectations du budget XP existant. Son seul changement au moteur est le choix facultatif de la part V29 dans `growPlayer` ; aucune seconde boucle de croissance, prime ou minute n'est créée.

## Mesures vérifiées sous Node 22

- **Quinze tests nouveaux** : sept sur les choix, huit sur les observations. Le premier test a échoué avec 0,20 XP générale au lieu de 0,30, avant le hook d'intégration ; il passe avec 0,30 générale +0,10 ciblée pour le même budget de 0,40. Général : 0,40 +0 ; spécialiste : 0,20 +0,20. Les seuils V29 restent de 1 XP par point général et 0,5 par point ciblé, avec +4 par attribut et +8 au total.
- Choisir, consulter, réviser et observer ne donne aucun point ni argent. Une qualité inchangée conserve l'XP partielle ; changer de qualité suit l'annulation V29 déjà existante. Les points de qualité acquis restent conservés.
- Sans programme explicite, les mêmes appels produisent exactement les mêmes données et le même prochain tirage RNG. Les blessures bloquent toujours la séance, la charge freine l'apprentissage et le potentiel reste contraignant.
- Le potentiel public est l'estimation au poste déjà exposée par le modèle natif, calculée sur une copie. Un test a d'abord constaté la révélation du plafond brut 94 contre l'estimation publique 89 ; le DTO et les baselines utilisent désormais 89 avec `potentialBasis=role-estimate`.
- Baseline courante seulement, deltas exacts des onze qualités, minutes de carrière non remises à zéro au changement d'année, promotion du même ID, historique borné à six observations, refus des chiffres non finis, des références futures et des qualités hors poste.
- Un vrai profil de base commune est classé en progression annuelle. Le choix spécialisé y est refusé ; le choix d'intégration n'ajoute aucun point hebdomadaire, puis les vraies modifications annuelles deviennent observables. Les ratios XP ne s'appliquent pas à ce modèle.
- Un joueur transféré cesse d'apparaître dans les jeunes propres au club. Lors d'une mobilité du manager, un ancien plan n'est pas appliqué automatiquement dans le nouveau club.

Régressions exécutées : `v29-focused-development.cjs` (comparaison historique sur six saisons de développement), `v72-youth-pathways.cjs` et `development.cjs` (dix changements d'année du harness). Ce sont les suites courtes existantes ; aucun nouveau banc de dix saisons de matchs n'a été lancé ni aucune source du banc figé `2c96b06` modifiée.

## Raccord natif

Le backend enregistre le domaine `youthDevelopment`, crée l'alias `CDYouthDevelopment` vers la même instance et garde l'autorité de validation/persistance. `installHooks()` du module est volontairement inerte. Les observations sont appelées autour des événements existants : séance, enregistrement des minutes, vieillissement, nouvelle saison, promotion et mobilité. Pour un jeune recruté après activation, une observation avant sa première séance ou son premier match crée sa vraie référence avant la progression ; l'observation après l'événement conserve alors sa première variation réelle.

Les états anciens sans domaine restent inactifs. L'activation est explicite et ne reconstruit aucun passé ; la projection et la validation n'initialisent, ne récompensent et ne réparent rien. Les baselines ne contiennent ni nom copié ni portrait, seulement des identifiants, contextes numériques et énumérations. Les identités et images sont reprises depuis l'ID actuel.

Le raccord worker, les refus d'écriture, les imports et la réception Godot sont des vérifications d'intégration pilotées par leurs auteurs. Ce reçu décrit les tests du lot de progression, sans présenter leur statut comme une CI complète ou une réception Windows.

Les objectifs projetés distinguent effectivement les plans : +1 niveau général depuis la baseline, +1 qualité choisie, ou passage professionnel puis 240 nouvelles minutes depuis cette même baseline. Ils restent des repères sans récompense. Une projection sans baseline ne montre jamais « 0 minutes depuis la référence » ; elle demande de créer une vraie référence. Ces corrections de projection ont été testées rouge puis vert, sans modifier le budget ni la persistance.
