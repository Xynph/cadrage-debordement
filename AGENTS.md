# Cadrage Débordement

## Cycle de travail

GitHub est la référence pour le code et l’avancement. À chaque reprise,
vérifier le `main` de [Xynph/cadrage-debordement](https://github.com/Xynph/cadrage-debordement)
et les PR pertinentes avant de modifier une copie locale.

**Coordination Claude / Codex (obligatoire depuis le 12 novembre 2026, demande
de Léo)** : le ticket [#591](https://github.com/Xynph/cadrage-debordement/issues/591)
est le tableau commun des chantiers. Avant de commencer, le lire pour éviter
tout doublon ; en commençant, réserver le chantier (ligne du tableau et
commentaire `RÉSERVÉ`) ; signaler `PRÊT`, `FUSION EN COURS` et `FUSIONNÉ`, ainsi
que tout changement de données figées que les autres branches devront
régénérer. Les règles détaillées sont en tête du ticket.

Les producteurs travaillent sur des branches distinctes et des périmètres
compatibles. La description de la PR est la passation. Le
[cycle court](docs/developpement-parallele.md) précise quand signaler une
collision, quels tests consigner et comment préparer la reprise.

**Débit CI** ([détail](docs/ci-debit-20261112.md)) : ouvrir chaque PR en
brouillon et pousser librement (CI légère : classification et syntaxe, verdict
« Validation CI » volontairement rouge) ; passer la PR en prête quand elle est
prête, ce qui lance la batterie complète (7 runners). Ne pas « réparer » un
rouge de brouillon : il signifie seulement « batterie non lancée ».
Depuis le 13/11, les suites Godot ne tournent plus sur les PR (seulement après
fusion sur `main`) ; pour une recette Godot d'une PR prête, poser l'étiquette
`godot-sdk`. Une PR prête dont « Validation CI » est vert se fusionne sans attendre.

Léo a donné son accord de principe aux intégrations ordinaires le 2 novembre
2026. Un seul intégrateur arbitre et applique les protections serveur et le
[gate officiel déployé](docs/chat-release-gate.md), avec toute autorisation
qu’il exige. Aucun push direct sur `main`.

Le 11 novembre 2026, Léo a confirmé son autorisation permanente de fusionner
dans le périmètre demandé. Ne pas redemander cet accord déjà fourni : appliquer
le gate officiel, les protections serveur et la coordination des responsabilités.
Une réservation non résolue ou un contrôle rouge reste un blocage à traiter,
sans contourner les contrôles ni élargir le périmètre autorisé.

Expliquer brièvement chaque phase à Léo en français, puis avancer dans le
périmètre autorisé. Rendre le résultat, le lien de la PR et la prochaine étape
concrète.

## Registre partagé des ressources

À chaque reprise d’Oval Legacy, consulter le [registre des ressources utiles](docs/ressources-utiles.md)
avant une recherche ou une réutilisation d’assets, bibliothèques ou inspirations.
Y enregistrer les nouveaux liens utiles transmis par Léo ou retenus pendant le
travail : provenance, utilité, coût/licence, statut, date et preuve de vérification.
Mettre à jour les décisions sans prétendre avoir lu, essayé ou intégré un contenu
sur la seule présence de son URL. Ce registre partagé sert aux reprises PC et
Cloud ; les anciens chats ne constituent pas un inventaire exhaustif automatique.

## Collaboration et esprit critique

- Léo attend un partenaire critique pour tout Oval Legacy : ne pas approuver
  automatiquement ses propositions. En cas de désaccord, le dire clairement,
  expliquer pourquoi avec les conséquences concrètes pour le jeu, puis proposer
  la solution recommandée.
- Signaler spontanément les incohérences et les améliorations utiles, y compris
  quand une demande est techniquement réalisable mais dessert la lisibilité,
  le réalisme, l’équilibrage ou le plaisir de jeu. Ne pas dissimuler un désaccord
  derrière un simple « oui, mais » ou une exécution silencieusement différente.
- Distinguer ce qui existe et a été vérifié de ce qui est proposé ou reste à
  réaliser. Après discussion, les choix explicites de Léo priment ; avancer sans
  demandes répétées de confirmation.
- Dans chaque message adressé à Léo sur Oval Legacy, indiquer en français le
  niveau d’effort recommandé pour GPT‑6.1 Sol, adapté à la tâche ou à la prochaine
  étape, afin qu’il puisse l’ajuster. Réserver cette recommandation aux échanges
  sur Oval Legacy.

## Contraintes produit

- Avant de modifier un match, un effectif, la discipline ou une compétition,
  lire [les références du rugby](docs/rugby-rules-reference.md). Fixer la
  saison simulée et vérifier les lois officielles et les dispositions
  françaises applicables. Distinguer règles, abstractions volontaires et
  points non vérifiés. Écarter par défaut les variantes amateurs, jeunes et à
  sept du XV adulte d’élite. La réussite des tests ne suffit pas à établir
  la conformité aux règles.
- Avant d’intégrer des données réelles, consulter
  [les données du jeu](docs/donnees-du-jeu.md). Conserver la provenance des
  données et estimations dans les métadonnées et la documentation technique.
- Pour la version portable, lire [la documentation hors ligne](offline/README.md).
  Stocker les carrières hors du dossier de l’exécutable et rendre les erreurs
  d’écriture visibles, sans repli silencieux. Réserver la mention « testé sous
  Windows » à une exécution native vérifiée.

## Immersion et textes du jeu

Préférence explicite de Léo, 10 novembre 2026 : tout l’univers d’Oval Legacy
est présenté naturellement du point de vue du manager pour préserver
l’immersion : personnages, clubs, événements, finances, dialogues et écrans.
Ne pas afficher de badge ou d’avertissement « personnage fictif », « profil
généré par IA », « montant fictif » ou de rappels similaires sur le caractère
fictif du jeu. Montrer les informations utiles à la décision et employer le
vocabulaire du club. La provenance et les distinctions de sources restent
internes aux données et à la documentation technique, sans faux justificatif
de source affiché. Conserver les coûts, risques, inconnues et conditions
utiles, les erreurs réelles de sauvegarde ou de connexion, les réglages et
les crédits nécessaires. Cette règle concerne aussi les futurs contenus.
