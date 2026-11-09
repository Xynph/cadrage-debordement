# Intégration jeunesse et détection — 9 novembre 2026

Cet assemblage part de la tête GitHub vérifiée de la PR423, `9011537bccfe196d4ef66db63416e10168366a82`, dans un worktree distinct. Il ne modifie ni la branche de la PR423, ni la CI, ni les bancs multigraines gelés. Il réunit les lots producteurs : détection `6349f84`, progression `014aa19` + tests `edda604` + objectifs `7d00c3`, raccord `88dd1fb` et interface `f46370bd`. Les dépendances ne sont pas ajoutées deux fois.

## Correction de raccord

Un jeune recruté après activation n’avait pas encore de référence persistée. Observer seulement après sa première séance enregistrait sa progression comme nouvelle référence et masquait le premier gain. Le vrai worker a reproduit le défaut : référence XP 0,077 au lieu de 0 après signature réelle et entraînement normal.

Les six opérations déjà observées sont maintenant mesurées avant et après, autour des wrappers existants. L’observation préalable amorce les nouveaux entrants à leur valeur actuelle, sans inventer leur passé, donner des XP ni modifier le RNG. Elle conserve également une référence avant promotion, mobilité ou année pour un entrant qui n’aurait pas encore été observé. La lecture, l’import et la validation n’observent jamais. Les résultats natifs et leurs marqueurs de hooks restent conservés.

Le nouveau test reproduit la signature publique, constate l’absence de passé, vérifie la référence pré-séance et le gain réel, puis la reprise exacte. L’activation du suivi reste explicite sur anciennes et nouvelles carrières.

## Provenance commune

Le seul changement du compilé commun est l’empreinte de `dist/development.js` :

- avant : `bbc0fff77539b89859bde7c31f03b16cac8401d19aafde959b907800b7036087` ;
- après : `892a1cee8bac6d24bff54ec2a704afdbbe3772c491f9ee9533331d48645fe601`.

La comparaison profonde des trente clubs et des 1 592 profils, tous champs compris, est strictement identique avant/après compilation. Tous les autres champs du compilé hors `sources` sont identiques. L’empreinte JSON de `clubs` reste `30dade30128ed2134955705f0f914e0b3768006cd670af9f3c5fbb7c14285ffa`. Le compilateur et son mode `--check` passent. Aucun âge, nom, contrat, niveau ou salaire de ces profils n’est recalculé.

## Réceptions exécutées

Sous Node22.23.4, les 35 tests ciblés passent en 70,5 s : raccord vrai worker, domaines jeunesse et détection, systèmes et décisions, développement, spécialisation V29 et parcours V72. Zéro test ignoré. Ils couvrent les budgets, profils annuels, anciens états, absence de migration cachée, frontières de club/focus, activation, suivi idempotent, missions et recrutement réels, refus disque, import et reprise.

Le staging officiel passe avec ses contrôles de registres, 74/74 bulles enregistrées, 60 photos, 30 territoires, portraits et modèle CC0. L’import des ressources est exécuté avec Godot4.7.2. La recette du vrai client Godot sous Linux sans fenêtre passe : **242 contrôles, zéro échec**, zéro test ignoré, sans erreur de script ou de chargement.

Le profil S2 issu de la saison réelle du raccord `88dd1fb` se réouvre sur cet assemblage : export public et octets privés exactement conservés. Le jeune `youth-0-1-1` conserve ses 1 125 minutes et son niveau général66, et les nouveaux objectifs d’intégration reconnaissent les 240 nouvelles minutes depuis sa référence. Cette reprise ne rejoue pas une saison et ne remplace pas le reçu historique des 34 semaines, 433 résultats, une transition et deux reprises exactes. Les hooks après opération de ce reçu restent identiques ; l’amorçage avant opération est qualifié par le nouveau test ciblé.

## Limites et preuves

Ce lot n’affirme ni succès de CI complète, ni validation Windows ou d’un paquet exporté. L’intégrateur reçoit l’arbre, la revue indépendante et les contrôles serveur avant publication/fusion. Les estimations de potentiel au poste ne sont pas des plafonds privés révélés ni des garanties de progression. Les raisons d’observation désignent le point de mesure, pas une preuve de causalité.

Les preuves de travail sont conservées hors dépôt sous `/workspace/work/youth-scout-integration-*.log`, `/workspace/work/youth-scout-common-rebuild-receipt.json`, `/workspace/work/youth-scout-integration-prior-profile-receipt.json` et les journaux rouge/vert de l’entrant. Aucune campagne longue supplémentaire n’a été lancée et aucun budget supplémentaire de croissance n’a été attribué.
