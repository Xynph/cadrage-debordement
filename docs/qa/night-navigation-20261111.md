# Recette des liens du carnet — nuit du 11 au 12 novembre 2026

Base de préparation : `6648cd6338e1eb62cc4a8c014b23dd3ec20ba174`.
Les résultats ci-dessous seront renseignés après exécution sur le candidat commun.
Ce document ne revendique ni recette Windows, ni campagne SDK globale verte.

## Contrat et périmètre

Le contrôleur ouvre une entité par `open_entity({kind,id,route?,section?})`.
La recette indépendante utilise le vrai worker, les contrôles rendus et les
identifiants de sa projection. Les données sportives ne sont jamais modifiées
pour fabriquer une rencontre historique ou une nation gérée.

| Cas | Preuve attendue | État |
| --- | --- | --- |
| France depuis une carrière gérant une autre nation | France affichée, mandat inchangé, aucun appel métier | À exécuter |
| Joueur du club | Même ID depuis clic et clavier, fiche complète | À exécuter |
| Joueur hors club | Dossier existant, informations limitées fidèles à la projection | À exécuter |
| Club adverse | Détail du bon club réutilisé | À exécuter |
| Rencontre historique | Vrai résultat du moteur et statistiques de son ID | À exécuter |
| Aller-retour | Recherche, filtres, tri, défilement, sélection et brouillons restaurés | À exécuter |
| Tri et glisser-déposer | Aucune ouverture accidentelle d’une fiche | À exécuter |
| Scène obligatoire | Refus propre sans changement de scène, commande ou sauvegarde | À exécuter |
| Consultation | Compteur de commandes, export sportif/RNG et octets de sauvegarde inchangés | À exécuter |
| Silence de Gabi | Audio Dummy, zéro demande et début de parole | À exécuter |
| Affichage | Captures natives 2560×1440 et contrôles aux tailles déjà prises en charge | À exécuter |

## Exécution ciblée

Chaque lancement Godot acquiert le verrou partagé
`/workspace/work/rg27-godot.lock`. Les groupes `reading`, `nation` et `guards`
s’exécutent séparément avec un profil jetable. Le délai enfant reste 180 secondes.
`provenance.json` conserve le SHA Git et les empreintes des sources du candidat ;
`report.json`, `godot.log` et `engine.log` consignent les résultats réels.

```sh
flock /workspace/work/rg27-godot.lock env CD_GODOT_EXECUTABLE=/chemin/godot \
  CD_NIGHT_NAV_CASE=reading CD_NIGHT_NAV_OUTPUT=/chemin/preuves \
  node --test tests/rg27-night-navigation.cjs
```

Pour les captures, ajouter `CD_NIGHT_NAV_GRAPHICS=1` et utiliser le vrai serveur
d’affichage disponible. Un lancement headless ne constitue pas une capture.

## Réserves à maintenir

- La réussite d’un groupe ciblé ne vaut pas validation de la campagne complète.
- Les identités sont recherchées par identifiant, jamais par homonyme.
- Une projection limitée n’autorise pas à retrouver un joueur caché dans les données internes.
- Les sujets moteurs, économie, calendriers et 3D réservés à Claude ne sont pas corrigés ici.

## Inventaire ciblé complémentaire : recrutement et promesses

Constat source sur la base de préparation, avant les nouveaux liens communs.
Cet inventaire ne prétend pas avoir reçu graphiquement ces fenêtres.

| Information | Destination déjà présente | Limite ou lien manquant |
| --- | --- | --- |
| Piste du marché | Ligne `MarketPlayer_ID` → `_profile` dans `recruitment_canvas.gd` | La fiche existe ; le nom ou portrait d’une alerte doit cibler son ID. |
| Rapport conservé | `OpenScoutReport` → `RecruitmentReport` → `Decisions.scout_report` | Le rapport possède son propre ID. Le contrôleur commun ne propose pas encore de cible `report` ; ouvrir le joueur ne remplace pas l’archive datée. |
| Rapport d’un joueur parti | Même détail du rapport conservé, affichage `assessment` | `_market_player` peut être vide ; ne pas inventer une disponibilité actuelle ou un dossier joueur caché. |
| Besoin d’un poste | `RecruitmentNeeds` → « Voir les pistes » → filtre de poste | Navigation déjà réelle, sans démarrer de mission. |
| Relève, candidat projeté | Carte de `RegenScouting`, filtrable et paginée | Nom et portrait statiques ; aucune fiche distincte existante. Un candidat absent de `model.market` n’est pas une cible `market` valide. |
| Relève, archive de suivi absente | Placeholder et raison de `clubLife.regenScouting.shortlist` | ID seul : garder l’absence explicite, ne pas reconstruire une identité. |
| Joueur sous contrat d’un autre club | Carte projetée `InterclubMarket` | `_offer` prépare une négociation ; ce n’est pas une destination de consultation. Un détail limité peut être extrait de la carte projetée, sans charger le joueur interne. |
| Club vendeur | Détail club de `CompetitionCanvas` | Lier seulement le `clubId` projeté et connu du détail existant. |
| Promesse ou engagement | `Relations` → `management_ui.relationships.playerId` → `_player` | Les noms d’engagements, événements et historiques sont statiques ; la fiche d’un joueur toujours dans `squad` est une destination sûre. |
| Promesse archivée d’un joueur parti | Texte conservé dans `relationships` | `_name` indique « Joueur parti du club » ; aucune identité manquante ne doit être retrouvée par homonymie. |

Les actions « Observer », « Suivre », « Approcher », « Confier la mission » et
« Promettre » restent des décisions explicites. Elles ne constituent jamais
la destination d’un simple nom, portrait ou rapport.

Les drapeaux ne sont des liens que si leur pays possède une équipe projetée
dans `international.teams`. Dans une carrière `common` sans cette projection,
le drapeau visuel reste conservé sans destination inventée. La recette des
drapeaux utilise donc une vraie carrière de club `world-champ` ; France depuis
un autre mandat utilise une vraie carrière nationale anglaise.

## Première réception du candidat commun

SHA testé : `8ad4b0239e70931f3d49672a2dc9b959fbb8e8f8`, SDK Godot
`4.7.2.stable.official.ed1daf0bf`, Node 22.23.4, Xvfb 2560×1440,
OpenGL llvmpipe, audio Dummy et verrou partagé. Sources et empreintes dans
chaque `provenance.json`, résultats réels dans `report.json` et journaux.

| Groupe | Contrôles | Échecs | Résultat et limite |
| --- | --- | --- | --- |
| `reading` | 110 | 1 | Le test cherchait la ligne du joueur alors que sa recherche volontairement vide était encore active. Le reset et le tri ne sont accessibles qu’après ouverture du dialogue « Filtres & tri » ; la fixture est corrigée séparément. Aucun défaut produit déduit de cet échec. |
| `nation` | 23 | 0 | Vraie carrière nationale anglaise, consultation France, mandat anglais conservé, nation inconnue refusée sans modifier la consultation. |
| `guards` | 85 | 1 | Le test supposait la presse initiale déjà ouverte. La presse est volontairement invisible avant l’ouverture de son invitation exacte ; la fixture passe désormais par ce courrier. Les gardes causerie et match immersif, ainsi que le vrai résultat historique, passent. |

Cette réception n’est pas entièrement verte. Les corrections de fixture
nécessitent une reprise ciblée de `reading` et `guards`, sans rejouer la campagne
SDK complète ou remplacer le reçu déjà valide de `nation`.

Les trois groupes ont obtenu zéro demande et zéro début de parole. Chaque
parcours de consultation reçu conserve le compteur de commandes, les octets du
profil, ses seed/horloge persistés et l’état sportif exporté du vrai worker.

Douze PNG réels ont été obtenus dans
`/workspace/work/night-final-qa/{reading,nation,guards}` : fiche joueur aux cinq
dimensions prévues, dossier hors club non observé, staff, retour du graphique,
France depuis l’Angleterre, match en pause et résultat historique. Les images
fiche 1440p, fiche 720p, recrutement limité, France, graphique et historique
ont effectivement été inspectées visuellement.

La rencontre historique a été jouée via les commandes publiques :
Toulouse Capitole XV – Vannes Morbihan XV, `calendar-0`, 24–14 dans ce profil.
La projection de cette carrière `common` ne conserve pas de statistiques
détaillées pour cette rencontre ; le reçu prouve la bonne fiche et son résultat,
sans prétendre avoir reçu des statistiques historiques absentes.

## Reprise ciblée des fixtures

| Candidat / groupe | Reçu | Limite |
| --- | --- | --- |
| `c9e7525a2b2daffb8b1b6f6cd7bab756d61d701b` · `reading` | 133 contrôles, 1 échec, 10 PNG | Tous les vrais clics, le tri, le glisser annulé et le retour du graphique défilé passent. L’échec restant venait du collecteur de texte du test : il ignorait `Window.title`, où le bon nom du club était affiché. L’ID du dialogue était correct. |
| `0d19ddfa21332c846b086b496ebb7f9a81f2fa4f` · `guards` | 103 contrôles, 0 échec, 2 PNG | Rendez-vous de presse ouvert par son courrier exact, causerie, match immersif et consultation du résultat historique reçus sans mutation. Les sources produit sont identiques à `c9e7525a` ; le commit supplémentaire corrige uniquement le nom d’une classe de test financier. |
| `b02452e7f905d43969ad7a564edc6de0b9d8da56` · amorce `reading` | Échec de parsing du test, aucun contrôle produit | Le nom de constante `Skin` masquait une classe native Godot. Corrigé en `GameSkin` dans le test ; le script complet corrigé a ensuite été vérifié par `--check-only` contre le projet commun importé. |

La correction du collecteur compare le titre à `GameSkin.club_name` afin de
respecter aussi le nom public d’un pack d’identité. Aucune modification produit
n’est ajoutée pour satisfaire artificiellement une assertion de test.

Les dossiers de cette reprise sont `night-final-qa-v2/{reading,guards}` et
`night-final-qa-v3/reading` pour l’amorce rejetée. Ils conservent leurs
`provenance.json` et journaux au lieu d’être écrasés par la prochaine réception.

## Réception des liens et brouillons sur `37ede657`

SHA complet : `37ede657c3085e67e3727817d8eb0e28ca70b3ae`.

| Groupe | Reçu réel | Périmètre |
| --- | --- | --- |
| `reading` | 133 contrôles, 0 échec, 10 PNG | Vrai clic sur nom d’effectif, drapeau au clavier, joueur non observé, staff par ID, club adverse et titre public, retour recherche/tri/scroll, vrai glisser annulé, graphique de charge puis retour sur son filtre et défilement non nul. Fiche aux cinq tailles demandées. |
| `prospects` | 70 contrôles, 0 échec, 2 PNG | Vrais catalogues de relève et interclubs, dossier enfant du bon ID/source, retour à la même fenêtre et au même focus, brouillon indemnité/salaire/joueur/devis conservé, double ouverture et confirmation de test refusées. |

Les deux groupes ont zéro commande déclenchée par leurs consultations, zéro
demande/début de parole, le même profil octet pour octet, les mêmes seed/horloge
persistés et le même état sportif exporté. Les journaux et PNG se trouvent dans
`/workspace/work/night-final-qa-v4/{reading,prospects}`. Les deux images de
prospects et celle du club adverse ont été effectivement inspectées.

La carrière `common`, club 0, a réellement projeté neuf candidats de relève et
1 422 candidats interclubs disponibles dans ce profil. Le test a donc activé le
vrai bouton `InterclubOffer`, puis modifié uniquement les champs du brouillon,
avant la consultation. Le repli par création publique d’une carrière `fiction`,
club 13, n’a pas été utilisé. Aucune disponibilité, économie ou identité n’a été
injectée dans le modèle.

La confirmation de refus des inspections est une fixture UI explicitement
isolée : un vrai composant `ConfirmationDialog` sans commande attachée. Elle ne
constitue pas une transaction ni un devis de négociation reçu du moteur.

**Réserve visuelle trouvée par inspection réelle :** la nouvelle fiche staff
sur ce SHA affichait le nom, la fonction et l’âge en colonne d’une lettre. Les
assertions d’identité et de lecture pure passaient, mais ce visuel n’est pas
qualifié. Le propriétaire a préparé le correctif `885071b2` (`G.fill(words)`).
Un groupe `staff` ciblé et une assertion de largeur/nombre de lignes ont été
ajoutés pour recevoir ce correctif sans répéter les parcours déjà reçus.
