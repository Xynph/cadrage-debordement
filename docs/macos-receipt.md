# Oval Legacy 27 sur Mac

Le constructeur `ci/build-macos.py` exporte une application autonome par
architecture : Apple Silicon (`arm64`, macOS 13+) et Intel (`x86_64`, macOS 12+).
Godot 4.7.2 et Node 22.23.4 sont téléchargés depuis leurs distributions
officielles, avec vérification SHA-256. Le runtime Node est livré dans
`Contents/Helpers/node`, le moteur et ses seuls modules actifs dans
`Contents/Resources/engine`. Aucun Node ou Godot à installer chez le joueur.
Les notices Godot, Node, polices, voix et ressources tierces accompagnent le jeu.

Les carrières normales restent dans
`~/Library/Application Support/CadrageDebordement/PrototypeGodot`, hors de
l’application. Les erreurs de sauvegarde du moteur restent visibles.
L’application de recette utilise exclusivement un profil jetable explicite.

## Recette publique

L’étiquette `macos-receipt` d’une PR interne lance uniquement les runners
**GitHub hébergés** `macos-15` (Apple Silicon) et `macos-15-intel` (Intel).
Retirer puis remettre cette étiquette après un changement pour recevoir le
nouveau HEAD. Le workflow reste séparé des contrôles généraux de fusion ;
une PR en brouillon peut recevoir cette qualification dédiée. Aucun runner
auto-hébergé ni workflow PC n’est utilisé.

Chaque job contrôle l’architecture réelle, exporte le bundle, le signe ad hoc,
fabrique un ZIP puis réextrait ce ZIP. Tous les fichiers sont comparés au
manifeste, la signature est vérifiée et le vrai exécutable exporté est lancé
avec une fenêtre native. Le pilote QA est embarqué, dormant jusqu’à un
`override.cfg` ajouté et haché dans une copie jetable, resignée pour cet essai.
Le ZIP téléchargeable reste inchangé, sans override.

La recette crée une carrière `world-champ`, traite les rendez-vous initiaux
par les commandes réelles, puis ouvre le sélecteur du gestionnaire de packs.
Elle analyse, installe et sélectionne un ZIP entièrement fictif comprenant
dix journalistes et quatre rédactions. Elle contrôle les noms projetés et
l’invariance de la simulation, sauvegarde, ferme le worker proprement et
relance l’application dans un nouveau processus. L’état exporté et les
identités de presse doivent être identiques après reprise. Les captures
proviennent du viewport natif ; le rapport refuse un affichage headless.

Après réussite, le ZIP du jeu et les preuves sont conservés en artefacts
Actions par architecture et commit pour trois jours, si le quota de stockage
le permet. L’état de cet archivage est distinct du verdict de recette et
figure dans le résumé du job. Aucun cache ni droit d’écriture de dépôt.
Les journaux publics ne contiennent que la base du jeu
et le pack fictif. Aucun jeton du dépôt privé n’est demandé par ce workflow.

## ZIP exact privé

Le même récepteur accepte `--pack /chemin/archive.zip
--expected-pack-sha256 <empreinte indépendante>`. Il ne réécrit, ne convertit
et ne reconditionne jamais ce ZIP. Il contrôle son empreinte avant et après,
les noms des journalistes et des rédactions contre son manifeste original,
puis la persistance après redémarrage. Une exécution Actions utilisant cet
argument exige une vérification API que le dépôt d’exécution est privé.

Cette étape doit suivre la réussite du pack fictif public, sur un Mac privé
autorisé ou un runner GitHub macOS d’un dépôt privé autorisé. Les règles et le
budget du dépôt privé s’appliquent : aucune CI privée ne doit être lancée tant
que son interdiction existante des minutes facturables n’a pas été levée.
Ne jamais fournir le ZIP réel, un profil dérivé, des captures ou des journaux
de cette recette à un workflow public, une Release publique ou son brouillon.
Le workflow public n’accepte aucun chemin de pack en entrée.

## Distribution

La signature ad hoc suffit à la recette locale des runners. Ce résultat ne
constitue pas une notarisation Apple et ne prouve pas l’ouverture sans
avertissement d’un téléchargement soumis à Gatekeeper. Pour une distribution
publique fluide, il reste à signer avec un Developer ID, notariser et tester
un téléchargement soumis à quarantaine. Ne pas désactiver Gatekeeper.
La recette ciblée ne prouve pas une saison complète ni la qualité des matchs 3D.

Modèle et effort réels non exposés par le runtime de préparation. Aucun
sous-agent utilisé. Effort recommandé GPT-6.1 Sol : élevé pour les corrections
et la recette privée, moyen pour la reprise documentaire.
