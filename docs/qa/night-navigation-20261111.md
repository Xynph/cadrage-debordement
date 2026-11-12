# Recette des liens du carnet — nuit du 11 au 12 novembre 2026

Base de préparation : `6648cd6338e1eb62cc4a8c014b23dd3ec20ba174`.
Les reçus ciblés ci-dessous ont été exécutés sur le candidat commun ; leurs SHA
exacts et leurs limites sont détaillés dans les sections suivantes.
Ce document ne revendique ni recette Windows, ni campagne SDK globale verte.

## Contrat et périmètre

Le contrôleur ouvre une entité par `open_entity({kind,id,route?,section?})`.
La recette indépendante utilise le vrai worker, les contrôles rendus et les
identifiants de sa projection. Les données sportives ne sont jamais modifiées
pour fabriquer une rencontre historique ou une nation gérée.

| Cas | Preuve attendue | État |
| --- | --- | --- |
| France depuis une carrière gérant une autre nation | France affichée, mandat inchangé, aucun appel métier | Reçu `nation` 23/0 sur `8ad4b023` |
| Joueur du club | Même ID depuis clic et clavier, fiche complète | Reçu `reading` 133/0 sur `37ede657` |
| Joueur hors club | Dossier existant, informations limitées fidèles à la projection | Reçu `reading` 133/0 sur `37ede657` |
| Club adverse | Détail du bon club réutilisé | Reçu `reading` 133/0 sur `37ede657` |
| Rencontre historique | Vrai résultat du moteur et statistiques de son ID | Résultat reçu `guards` 103/0 sur `0d19ddfa` ; statistiques absentes de cette projection, non inventées |
| Aller-retour | Recherche, filtres, tri, défilement, sélection et brouillons restaurés | Reçus `reading`, `staff` 54/0 et `quote` 66/0 |
| Tri et glisser-déposer | Aucune ouverture accidentelle d’une fiche | Reçu `reading` 133/0 |
| Scène obligatoire | Refus propre sans changement de scène, commande ou sauvegarde | Reçu `guards` 103/0 |
| Consultation | Compteur de commandes, export sportif/RNG et octets de sauvegarde inchangés | Reçus sans mutation dans chaque groupe qualifié |
| Silence de Gabi | Audio Dummy, zéro demande et début de parole | 0/0 dans chaque groupe qualifié |
| Affichage | Captures natives 2560×1440 et contrôles aux tailles déjà prises en charge | Joueurs : cinq tailles ; staff : trois tailles, défaut visuel corrigé puis reçu |

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
| Rapport conservé | `OpenScoutReport` → `RecruitmentReport` → `Decisions.scout_report` | Le rapport possède son propre ID. État historique de cet inventaire initial : la cible `report` manquait. Elle est ensuite reçue 47/0 sur `d896d631` dans « Rapport réel archivé et retour au lecteur » ci-dessous ; ouvrir le joueur ne remplace pas l’archive datée. |
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

## Réception du correctif visuel staff

`staff` a reçu **54 contrôles, zéro échec** sur
`fbc642e1d3069895d5614caca433ab8f4c83bcf8` avec le correctif `885071b2`.
Les trois PNG natifs 2560×1440, 1920×1080 et 1280×720 ont été inspectés :
le nom, la fonction et l’âge sont désormais horizontaux et lisibles. Le test
exige une largeur réelle de texte et au plus trois lignes pour ce nom.

L’aller-retour vers le même profil conserve la recherche d’annuaire, le focus,
le curseur et la sélection de texte ; le vrai bouton de nom ouvre le bon
`staff_id`. Le reçu conserve l’état sportif, le hash de profil, ses seed et
horloge, avec zéro commande de consultation et zéro demande/début de parole.
Preuves : `/workspace/work/night-phase5-staff`.

Précision sur la réception `prospects` précédente : le champ `negotiation`
était vide après l’édition des deux montants. Elle recevait donc le brouillon
des conditions, pas encore la conservation d’un devis non vide émis par le
moteur. Un groupe `quote` séparé est préparé pour soumettre le vrai bouton
`InterclubNegotiate` avant sa baseline de consultation, conserver sa réponse
exacte et inspecter le dossier sans aucune clôture de transfert. Ce statut de
préparation est historique ; son résultat réel 66/0 sur
`dbe6a7e2` figure dans « Conservation d’un vrai devis non vide » ci-dessous.

## Conservation d’un vrai devis non vide

Le groupe `quote` a reçu **66 contrôles, zéro échec** sur
`dbe6a7e2b7bb22b0cb9d7d5f924e396f9cdd8e3f` : trois PNG natifs 2560×1440,
dont le devis avant inspection, le dossier du joueur et le devis au retour.
Les deux images de devis ont été inspectées visuellement.

La préparation utilise le vrai bouton `InterclubNegotiate` pour `lnr:9642` :
142 000 € d’indemnité, 8 700 €/semaine, réponse non vide et une offre recevable.
Le devis reçu porte l’empreinte
`43c2e4f063927421fc4c56396792c1f13e628223521ad5e4091cbc71fe8bdba1`.
Il ne s’agit pas d’une preuve de concurrence à plusieurs enchérisseurs.

Le profil sportif, l’état exporté, la seed et l’horloge sont strictement
identiques avant et après cette préparation réelle. La consultation du dossier
ne déclenche ensuite aucune commande, conserve exactement le devis non vide,
les montants, le joueur sélectionné, les champs, la recherche, la page, le
défilement, le focus et l’état du bouton de clôture. Aucun transfert n’est
confirmé. Les compteurs de parole restent à zéro.

Preuves : `/workspace/work/night-phase6-quote`, avec payload public exact,
empreintes de profil avant/après, `report.json` et `provenance.json`.


## Rapport réel archivé et retour au lecteur

Le groupe graphique `report` a reçu **47 contrôles, zéro échec** sur
`d896d631bd2ea141283c0e09609695a547a6b200`, en 60,417 secondes,
préparation comprise et sans relever le plafond global de 180 secondes.
La préparation distincte utilise 37 commandes publiques acceptées du vrai
worker : nouvelle carrière `common`, mission sur une famille publiée, progression
normale de deux semaines et rendez-vous réels. Elle conserve trois rapports
`report-11`, `report-10`, `report-9`, sans injection de profil ou de modèle.

Depuis le véritable onglet Rapports, Enter sur `MarketEntity_report-11` ouvre
le lecteur exact de Gabin Garcia, tandis que le panneau d’Alexandre reste derrière.
Les faits, estimations, limites et source datée affichés sont comparés aux chaînes
archivées exactes ; aucune donnée masquée supplémentaire n’est révélée. Le lien
vers le dossier actuel revient par Alt-gauche à la même instance du lecteur,
avec l’onglet « À vérifier » conservé. Les deux PNG natifs 2560×1440 sont inspectés :
identité, date et limites lisibles.

Après la baseline, aucune commande d’observation ou de recrutement n’est envoyée.
L’état sportif, le SHA-256 du profil, la seed et l’horloge persistées restent
identiques ; compteurs de parole à zéro. Empreinte du profil avant/après :
`016760df473facd2b7e389fb8454d8e2276489f1c0bbd4dc1d1ac7d4b27fffaa`.

Preuves originales : `/workspace/work/night-phase7-report`. Copies vérifiées,
préparation séparée, provenance exacte et PNG sans retouche :
[evidence/night-navigation-20261111](evidence/night-navigation-20261111/README.md).
Ces sept reçus ciblés portent sur leurs SHA respectifs et ne remplacent pas
une campagne SDK complète sur un même candidat.


## Complément phase 9 : contrats et fatigue

Sur common figé `096f3d8f6a879bc2e240e99b2184ab7f3d688182`, les journaux
graphiques reçus donnent contrats **270/0** (47,834 s) et fatigue **685/0**
(106,471 s). Ces preuves ont été assemblées sans relancer le SDK. Les wrappers
ne produisent pas de provenance.json ; le SHA est attribué par root et les
empreintes des scripts sur ce SHA sont conservées dans le manifeste.

Les captures contrats effectif, mensuelle, annuelle et nom long ont été inspectées :
unités explicites, colonnes lisibles, nom long tronqué sans élargissement. Ce nom
long est une substitution UI temporaire du test, pas un joueur réel. Les trois
captures fatigue ont été inspectées : carrière réelle et confirmation lisibles ;
la projection de recette avec blessure/suspension/sélection est synthétique, sans
écriture du profil moteur. Les 685 contrôles comprennent aussi des fixtures
isolées et ne constituent pas 685 interactions réelles. Les wrappers ne mesurent
pas les compteurs de parole/Gabi : aucune valeur 0/0 n’est annoncée pour ces cas.

[Journaux, manifeste et cinq PNG originaux sélectionnés](evidence/night-phase9-20261111/README.md).
Le parcours management graphique sera documenté séparément après réception.


## Parcours management réel : reçu final et historiques séparés

Le reçu graphique `management-reading-flow` sur
`d40311c053aba931756df212c2690adb04a76994` donne **61 contrôles, zéro échec**.
Les deux PNG originaux 2560×1440 sont inspectés : retour au vestiaire et à la
même fenêtre des décisions, noms et reçus lisibles. Le défilement de la liste
indépendante reste à 90 px, le reçu retrouve son défilement et son focus.
Les assertions vérifient profil/état sportif/RNG/horloge inchangés, reçus et
brouillon conservés, zéro commande de consultation et compteurs parole 0/0.

Les essais rouges restent distincts : préparation 25/1 sur d896d631 (onglet
Entretiens et duos non activé), scroll 60/1 sur d0aceccb, puis diagnostic des
noms de scroll 60/1 sur c657eee4. Leurs journaux sont conservés sans publier
leurs captures comme preuves qualifiées. Aucun SDK/import n’a été relancé.

[Deux PNG, provenance test/produit, journaux verts et rouges, manifeste](evidence/night-management-reading-20261111/README.md).
