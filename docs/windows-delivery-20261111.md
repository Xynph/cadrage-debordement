# Livraison Windows du 11 novembre 2026 — réception en cours

La construction et la recette sont désormais pilotées par Cloud, conformément à
la demande de Léo. **Ce document ne déclare pas encore un nouveau paquet reçu sous
Windows.** Les anciens reçus PC de #543 portent sur leur ZIP et leur SHA propres.

## Parcours reproductible

Le workflow `windows-release.yml` emploie un runner standard `windows-2022` dans
le dépôt public. Une PR du même dépôt portant l'étiquette `windows-receipt` reçoit
une qualification ciblée, sans publication. Le déclenchement manuel depuis `main`
exige le SHA complet de ce même commit ; il conserve les résultats dans une
Release brouillon. La campagne globale JavaScript reste pilotée uniquement par
#539, puis vérifiée de nouveau sur le commit effectivement fusionné.

1. `prepare-windows-toolchain.py` vérifie les tailles, SHA256, sommes officielles
   Godot/Node et notices des versions épinglées dans `windows-toolchain.json`.
   Aucun installateur ou cache partagé n'est employé. Mesa est réservé à la copie
   de recette ; ses notices Mesa et LLVM doivent être réellement présentes. Le premier runner
   Windows a confirmé que l’archive binaire ne les fournit pas : elles sont donc
   téléchargées séparément, hachées et attribuées aux sources immuables Mesa 26.2.6
   et LLVM 23.1.4 (version confirmée par les informations MSVC du distributeur).
2. `build-godot-prototype.py` exporte avec le SDK officiel Godot 4.7.2 et Node
   22.23.4. Il refuse un checkout modifié ou un SHA différent. Le manifeste garde
   l'empreinte et la taille de chaque fichier, plus `sourceCommit` et `sourceTree`.
   Les ressources PE gratuites sont activées ; l'EXE demeure non signé.
3. `windows-receipt.ps1` contrôle et extrait le ZIP dans un chemin contenant des
   espaces, puis lance cet EXE réel. Son environnement exclut les jetons GitHub et
   le Node de l'hôte. CIM doit observer son enfant `runtime/node.exe` exact et son
   arrêt. Les profils sont jetables, extérieurs au dossier du jeu.
4. Le pilote embarqué fait la recette fraîche jusqu'en saison 2 avec les vrais
   matchs, rendez-vous, sauvegardes et déclarations. Ce processus est headless :
   il ne constitue pas une preuve graphique.
5. Le même EXE charge le profil existant par `windows-resume.gd`. Avant mutation,
   état exporté, déclarations, octets du profil et RNG durable sont comparés.
   Une première commande `save`, explicitement déclarée, contrôle ensuite le
   curseur RNG restauré ; son horloge est consignée séparément. Les rendez-vous
   suivants sont traités par les commandes publiques.
6. Cette reprise emploie le rendu Windows OpenGL avec Mesa logiciel dans la seule
   copie QA. Elle produit des PNG réels en 2560 × 1440, dont les pixels, dimensions
   et empreintes sont vérifiés. L'absence d'image ou un repli headless est un échec.
   Les DLL ajoutées sont hachées et ne remplacent aucun fichier du manifeste.
7. Les conférences obligatoires passent par leur courrier réel tout en conservant
   la sélection de réponses à impact minimal du précédent pilote. Les textes
   offerts sont comparés aux archives durables, puis à nouveau après relance.
   Les deux processus doivent constater Gabi silencieux, sans lecteur vocal,
   avec les compteurs de parole à zéro. La reprise relève le pilote audio Dummy.
   Le ZIP d'origine et chaque fichier du jeu sont revérifiés après exécution.

## Conservation et publication

Les assets GitHub Releases contiennent le ZIP reçu, son SHA256, `delivery.json`
et une archive des rapports, journaux, notices et captures effectivement produits.
Les profils jetables, téléchargements SDK et copies QA sont exclus de cette archive.
Un échec peut produire un brouillon de diagnostic, sans ZIP présenté comme livré.

La nouvelle chaîne n'utilise ni `upload-artifact`, ni cache Actions, ni LFS, ni
Packages, ni runner élargi. Le dépôt doit rester public pour ces jobs. La limite
de chaque asset Release est vérifiée à moins de 2 Gio. Budget externe demandé :
0 €. La publication finale du brouillon attend le gate officiel, les sept jobs
complets de la CI du main exact, puis la lecture des nouveaux reçus et images.

## Vérifications locales du candidat

La revue indépendante a corrigé le chemin de l’EXE relocalisé utilisé par la
publication et renforcé les preuves de saison et de citations. Après ces reprises :
28 tests Node de l’outillage sont verts (dont les wrappers de 12 cas Python outils
et 7 cas Python publication), sans skip ; les parseurs Python, PowerShell 7 et
Godot 4.7.2 passent. La sonde réelle de courrier/presse Godot Linux termine avec
34 contrôles sans échec et trois déclarations durables littérales. Elle ne joue
pas de saison complète et ne constitue pas une recette Windows.

## Comparaison PC et Cloud

Les textes de presse `54bc63a` et `3b42dbf` sont identiques dans la version commune.
Le patch de recette `fa482c6` a le même patch-id que sa reprise `f000f95`.
Les corrections de `37969ce` et `0dad8da` ont été comparées fichier par fichier :
capture des sorties complètes sur disque, fixtures XP/variation/catalogue,
protection des rendez-vous et cas financiers historiques sont reçus en conservant
les contrôles Cloud plus étendus. Le cinquième cas financier utilise réellement
le worker V2 actuel ; les quatre premiers sont des scénarios historiques adaptés,
pas des fixtures attestées d'un ancien EXE livré.

L'enregistrement de l'ascendance Git de #543 conserve cette sélection commune ;
il ne réapplique pas les anciennes versions concurrentes des fichiers.

## Audit Claude et limites à conserver

Les 102 captures Linux de Claude concernent `3b42dbf2d3eda6450030a5161548ec768ff8bc47`,
avec éditeur Linux, X11 et Mesa llvmpipe. Leur branche de preuves orpheline
`claude/preuves-recette-linux-20261111` (`f4ad975a4b6f9d6be3956355b1c716a083949525`)
ne doit pas être fusionnée. Le classement des 105 suites a été lu ; leurs images
n'ont pas toutes été retéléchargées ou revérifiées par Cloud.

Sur le candidat commun, les reprises SDK ciblées déjà reçues sont Contextual
(875 contrôles), Pack UI (134) et Journal (315), sans échec en 1440p. Cela ne rend
pas vertes les 105 suites ni ne qualifie Windows. Parmi les autres échecs signalés,
les aides manquantes, assertions, erreurs de script et délais restent à distinguer
sur leur SHA. Une recette intégrée réussie ne démontre pas à elle seule que chaque
échec ciblé est une simple fixture obsolète. La CI JavaScript actuelle n'installe
pas Godot ; ses portions conditionnelles SDK ne constituent donc pas un reçu natif.

Les rapports de #549 sur les salaires/indemnités, journalistes réels, salaires
révélant indirectement le niveau des joueurs libres, précision des intervalles et
moment d'observation rejoignent le suivi après livraison. Les incohérences Bureau/
courrier, le doublon Tactique et la lisibilité signalés ne sont pas déclarés corrigés.

Le renommage #546 et le rendu Forward+ #545 restent séparés selon l'ordre convenu.
Le retrait des identités réelles sera une autre PR après fusion : le jeu n'est pas
déclaré déjà entièrement fictif. Le pack Rugby Réel du dépôt privé reste extérieur
à cette livraison ; aucun fichier de ce pack n'est ajouté aux assets publics.

## Premier essai Windows et reprise de la préparation

Le run ciblé [42981272829](https://github.com/Xynph/cadrage-debordement/actions/runs/42981272829)
sur `69de0f11cb134127006e59f41825cfaae9b85210` a reçu les distributions et leurs
sommes, puis s’est arrêté avant construction sur les notices Mesa/LLVM absentes.
L’inspection indépendante de l’archive officielle, dont le SHA256 est inchangé,
a confirmé 31 entrées et un unique readme de 93 octets, sans licence de composant.

La préparation reçoit maintenant séparément la page de licence et les six textes
SPDX de Mesa au commit miroir `8e87a503ebd91408c88596d1b9eeb5f4c0b2088d`
(tag upstream `mesa-26.2.6`), ainsi que la notice officielle LLVM du commit
`7a941dfb2877a0b8cf30323fefa85ad019e0b0f5` (`llvmorg-23.1.4`). Le buildinfo MSVC
épinglé du distributeur confirme LLVM 23.1.4. Chaque origine, taille et empreinte
est conservée ; ces textes ne sont pas présentés comme inclus dans l’archive.
Le contrôle négatif de notices demeure actif. Ce premier run n’a pas testé le jeu.

Le second essai [42982561270](https://github.com/Xynph/cadrage-debordement/actions/runs/42982561270)
sur `a1444274aa793230ec4b32dbe60d5872f12cf5b1` a reçu ces notices, puis a correctement
refusé la distribution MSVC sans `opengl32.dll`. L’avertissement du distributeur
annonçait ce défaut. La préparation emploie désormais l’archive **MinGW x64**
26.2.6, SHA256 `da0f71d9181b672c1918f3c342f11118c687f6059a46b16502845160733cc388`.
Son inventaire réel confirme `x64/opengl32.dll`, `x64/libgallium_wgl.dll` et le
format PE x64 des DLL de ce dossier. Son propre buildinfo MinGW confirme encore
LLVM 23.1.4. Le contrôle des DLL reste actif. Les deux premiers essais étaient des
échecs de préparation, sans lancement du jeu et sans campagne globale JavaScript.
