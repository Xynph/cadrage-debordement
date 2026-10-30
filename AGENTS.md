# Cadrage Débordement

Avant de modifier le comportement d’un match, d’un effectif, de la discipline ou
de la compétition, lire `docs/rugby-rules-reference.md`. Ce document conserve les
sources officielles, leurs dates d’application, les erreurs connues du moteur
et les vérifications restantes. Vérifier la loi exacte et la disposition de
compétition avant de coder. Le comportement actuel du jeu ou la réussite des
tests ne prouvent pas qu’une règle de rugby est correcte.

L’utilisateur souhaite une courte explication en français avant chaque phase de
travail. Poursuivre de manière autonome dans le périmètre demandé, sans lui
remettre systématiquement le jeu ni demander des confirmations répétées.
L’implémentation a été autorisée après l’audit des règles. Les évolutions et leurs
limites sont suivies dans les versions 7 à 16 du README.md. Terminer et publier
le lot autorisé, sans prétendre que toutes les règles du rugby sont implémentées.

Distinguer les lois, les dispositions françaises de compétition, les abstractions
volontaires et les détails non vérifiés. Fixer la saison simulée et l’édition des
règles avant d’appliquer une nouvelle loi. Ne jamais appliquer par défaut les
variantes amateurs, jeunes ou de rugby à sept au XV adulte d’élite.

Le dépôt GitHub `Xynph/cadrage-debordement` est la référence du projet. Vérifier
son état avant de modifier une copie locale et y enregistrer les évolutions.
Conserver la documentation et les explications destinées à Léo en français.
Avant d’intégrer des données réelles, consulter `docs/donnees-du-jeu.md` : la
trésorerie fictive actuelle ne doit pas être présentée comme un budget réel.

Pour la version portable, lire `offline/README.md`. Ne pas stocker les carrières
dans le dossier de l’exécutable et ne pas annoncer un test Windows natif si seul
le binaire croisé ou le lanceur Linux a été vérifié. Conserver les échecs
d’écriture visibles ; aucun repli silencieux vers un autre stockage.
