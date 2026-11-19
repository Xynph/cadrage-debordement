# Rugby Legacy 27 (dépôt Cadrage Débordement)

## Cycle de travail

- GitHub fait référence : à chaque reprise, partir du `main` de
  [Xynph/cadrage-debordement](https://github.com/Xynph/cadrage-debordement) et des PR utiles.
- **Coordination Claude / Codex** : le ticket [#591](https://github.com/Xynph/cadrage-debordement/issues/591)
  est le tableau commun (règles en tête du ticket). Avant un chantier, vérifier
  l'absence de doublon ; le réserver (`RÉSERVÉ`) ; signaler `PRÊT`,
  `FUSION EN COURS`, `FUSIONNÉ` et tout changement de données figées à régénérer.
  Lire le tableau en tête du ticket, pas tout l'historique des commentaires.
- Les producteurs travaillent sur des branches distinctes et des périmètres
  compatibles ; la description de la PR est la passation
  ([cycle court](docs/developpement-parallele.md)).
- **CI** ([détail](docs/train-de-fusion.md#fusion-rapide)) : PR ouverte en brouillon (CI
  légère, « Validation CI » rouge exprès : ne pas le « réparer ») ; passée en
  prête, elle tourne en **mode rapide** (décision de Léo, 19/11/2026 : suites courtes
  et suites modifiées, ~10 min). Étiquette `batterie-complete` pour forcer la batterie
  complète. Jobs « Godot i/5 » bloquants quand le diff touche Godot, sautés sinon.
  La **batterie complète tourne chaque heure sur `main`** ; rouge après une relance :
  « MAIN ROUGE » sur #591 et retour arrière automatique si une seule PR est en cause.
  Main rouge : le corriger avant toute autre fusion. Recette SDK ciblée : étiquette
  `godot-sdk`.
- **PC de Léo indisponible** : tests lourds, suites Godot et captures se lancent en ligne via `bash ci/en-ligne.sh` ; en local seulement lecture, édition et contrôles légers (syntaxe, `node tests/<suite>.cjs` rapides sans Godot) ; résultats lisibles via la branche `resultats-en-ligne` (`runs/<run_id>/`, extraits par `ci/en-ligne.sh` dans `/tmp/en-ligne/<run_id>/`), l'artefact étant bloqué ; `--captures intro,fiche-club` limite les captures ; ne jamais créer de branche `tmp/` ailleurs : le workflow supprime seul `en-ligne/*` et `tmp/*` (`bash ci/en-ligne.sh --menage`).
- **Fusion rapide** (décision de Léo, 19/11/2026, voie par défaut) : PR prête puis
  fusion auto de GitHub en squash
  (`gh api -X PUT repos/Xynph/cadrage-debordement/pulls/<n>/ccr/auto_merge -f merge_method=squash`
  depuis Claude Code, sinon `gh pr merge <n> --auto --squash`) ; GitHub fusionne dès que
  le mode rapide est vert. Poster `FUSIONNÉ` sur #591. Ne pas surveiller la CI en boucle.
- **Train de fusion** (18/11/2026, facultatif) : étiquette `train` sur une PR en brouillon
  pour un lot à passer sur la batterie complète avant fusion
  ([détail](docs/train-de-fusion.md)). `train-echec` : lire le commentaire, corriger,
  reposer `train`.
- **Règles communes de fusion** : un seul intégrateur arbitre les collisions et les protections serveur ; le
  [gate officiel](docs/chat-release-gate.md) reste pour un lot sensible.
  Aucun push direct sur `main`, jamais de contournement d'un contrôle rouge ou
  d'une réservation non résolue. Si la CI est rouge, la PR attend : corriger.
- Expliquer chaque phase en une phrase, rendre le résultat, le lien de PR et
  la prochaine étape. Messages courts.
- **Réponses à Léo : courtes et côté jeu** (consigne permanente du 17/11/2026) :
  dire ce qui change à l'écran ou dans la partie, ce qui marche, ce qui reste à
  voir. Pas de noms de fichiers, fonctions, commits, runs ni chiffres de tests
  sauf demande ; le détail technique va dans la PR et sur #591.

- Évolution de gameplay ou d'interface : appliquer la
  [boucle courte](docs/developpement-jeu-boucle-courte.md) (décision de manager,
  reproduction Monde, rejeu ciblé, observation dans le vrai Godot, puis recette
  complète). [Pont local](tools/godot-agent/README.md) pour piloter et capturer ;
  voir `.agents/skills/rugby-legacy-boucle-courte/SKILL.md`. Un seul Godot à la fois.

## Kit Claude Code Game Studios

Rôles dans `.claude/agents/`, commandes dans `.claude/skills/` (Claude Code) et
`.agents/skills/` (Codex, qui lit d'abord `.agents/skills/ccgs-studio/SKILL.md`).
Ce fichier prime sur le kit. Mode autonome (`project.yaml`) : seules
suppressions, opérations destructives et dépenses demandent l'accord de Léo.
Toute commande ajoutée ou modifiée dans `.claude/skills/` l'est aussi dans
`.agents/skills/`.
Kit d'agents : CCGS seul (décision de Léo, 16/11/2026) ; ne pas utiliser ni
réinstaller Superpowers (ses plans passés sont dans `docs/plans-historiques/`).

## Modèles, effort et quota (règle permanente de Léo)

- Le modèle **et** l'effort de la session sont un plafond, sous-tâches comprises.
- Modèle léger pour le cadré et vérifiable (recherche, logs, tests,
  régénération, renommage, conflit simple) ; décisions et modifications
  importantes au modèle principal.
- Difficulté (conception, interface, moteur, économie, architecture, bug
  inexpliqué) : d'abord un moyen de vérifier, puis plus d'effort, puis seulement
  un modèle plus puissant, toujours sous le plafond.
- Pas de session parallèle supplémentaire sans accord de Léo.
- Lectures ciblées : `.ignore` exclut les grosses données des recherches ;
  ne pas lire `DEVELOPPEMENT.md` ni `README.md` en entier.
- Dans chaque compte rendu : modèle et effort réellement utilisés, et réglage
  recommandé pour la suite (Codex : effort GPT‑6.1 Sol ; Claude : modèle et
  effort Claude, voir `CLAUDE.md`). Ne pas inventer un réglage non exposé.

## Ressources

Avant toute recherche d'assets, bibliothèques ou inspirations, consulter le
[registre](docs/ressources-utiles.md) ; y consigner tout nouveau lien retenu
(provenance, utilité, coût/licence, statut, date, preuve). Ne pas prétendre
avoir lu ou intégré un contenu sur la seule présence de son URL.

## Esprit critique

Partenaire critique, pas approbateur : dire un désaccord clairement avec ses
conséquences pour le jeu et proposer la solution recommandée, puis la
corriger. Signaler les incohérences même quand la demande est faisable.
Distinguer vérifié, proposé et à faire. Les choix explicites de Léo priment.

## Contraintes produit

- Match, effectif, discipline, compétition : lire d'abord
  [les références du rugby](docs/rugby-rules-reference.md) ; fixer la saison,
  vérifier lois officielles et dispositions françaises ; XV adulte d'élite
  seulement ; des tests verts ne prouvent pas la conformité aux règles.
- Données réelles : lire [les données du jeu](docs/donnees-du-jeu.md) ; garder
  la provenance dans les métadonnées. Vrais noms, photos, logos : uniquement
  dans le dépôt privé `rugby-reel-donnees`.
- Version portable : [doc hors ligne](offline/README.md) ; carrières hors du
  dossier de l'exécutable ; erreurs d'écriture visibles. « Testé sous Windows »
  seulement après exécution native vérifiée.
- Mode Monde uniquement (décision de Léo, 13/11/2026) : aucun test dans l'ancien
  mode France ni les autres anciens modes ; tout nouveau test crée une carrière
  world-champ. Les tests encore marqués CD_MODES_HERITES sont exclus de la CI
  jusqu'à leur migration ou suppression.
- Cap : consolider (améliorer l'existant) plutôt qu'ajouter.

## Immersion (10/11/2026)

Tout est présenté du point de vue du manager, avec le vocabulaire du club.
Aucun badge ni rappel « fictif », « généré par IA », « montant fictif ». Garder
coûts, risques, inconnues, vraies erreurs de sauvegarde ou de connexion,
réglages et crédits. Provenance et sources restent internes aux données et à
la doc technique.
