# Séance publiée : programme du jour et retour de lecture

Produit et test exacts : `aa8caaf523f96f4da0ac389c20f99ceb17037b6f`.
Le parcours graphique X11 reçoit **132 contrôles, zéro échec, wrapper 0**, sous-test
TAP 50309,563883 ms et total TAP 50359,099146 ms. La base documentaire 3fc15483
n’est pas un nouveau SHA de recette. [Preuves filtrées, manifeste et provenance](evidence/night-calendar-session-reading-20261112/manifest.json).

## Destination et portée

Un ID de séance unique et daté dans la projection courante ouvre le programme
de son jour exact. L’ID réel reçu est
`weekly:1:0:league:0:13:2026-09-08:team:1`, sélection 8 septembre alors que le
présent reste 7 septembre 2026. Le créneau « Ateliers par poste» et ses consignes
connues sont une **séance publiée au planning**, pas un compte rendu de séance
exécutée, une commande train ou une preuve de progression/fatigue appliquée.

Les IDs absents/inconnus/ambigus et dates manquantes ou invalides sont refusés
sans mutation ; les éléments non résolvables restent des libellés simples.
Les libellés facultatifs vides/blancs ont un nom visible et accessible utile,
sans afficher l’ID technique. Ouvrir à nouveau la même cible ne crée ni entrée
supplémentaire ni dialogue dupliqué. Une sélection manuelle d’un autre jour
invalide l’ancienne cible ; l’origine tableau est ensuite restaurée par Back.

## Vrai parcours, préparation et invariants

La première presse passe par le courrier persistant exact
`press-v1:1:0:0` puis InboxOpenPressInvitation. Le rendez-vous réellement actif
refuse la navigation séance avant sa résolution publique. Cette préparation
se termine **avant la baseline** ; le footer visible « Conférence tenue · Moral
collectif 75→76» appartient à cette préparation, jamais à la consultation de séance.

Les événements clavier et souris du script sont injectés dans le viewport SDK.
Le rendu X11 ne les transforme pas en événements OS XTest. Ce reçu n’est pas la
recette native 59/0 précédente et n’en reprend pas la portée.

Les diagnostics filtrés conservent les états de lecture observés :

| Aller-retour | Scroll CalendarProgramScroll avant/après | Filtre et focus restitués |
| --- | ---: | --- |
| Clavier | 12/12 px | matches ; CalendarWeekSessionLink de l’ID exact |
| Souris | 123/123 px | matches ; même lien exact |

Modèle intégral, octets de sauvegarde, bridge_next_id, last_command, absence
d’attente et timer arrêté sont **assertés inchangés par le test reçu**. Le
rapport ne sérialise pas de paire de hashes sportifs avant/après : aucune
empreinte de baseline n’est inventée ici. Les hashes du manifeste portent sur
les pièces de preuve et les sources de code. Parole réellement sérialisée :
requested 0, started 0, id 0, UI et assets chargés avec audio Dummy et mute précoce.

## Revue visuelle : une capture, trois tailles contrôlées

[PNG original session-1440.png](evidence/night-calendar-session-reading-20261112/images/session-1440.png) :
**2560×1440 réels**, sans retouche. Le nom de fichier ne signifie pas une largeur
1440. La sélection Mardi 8 est distincte d’Aujourd’hui Lundi 7 ; titre, créneau,
consignes, programme hebdomadaire et prochain match sont lisibles, sans collision
évidente. Le texte publié reste hiérarchisé dans les composants existants.

1280×720, 1920×1080 et 2560×1440 sont contrôlés par les assertions de visibilité
du lien sur les deux axes. **Une seule image est capturée**, à 2560×1440, avant
les diagnostics du filtre matches et avant les projections synthétiques. Le
PNG ne prouve ni les positions 12/123 ni trois captures distinctes.

Cas passé, collision d’IDs assainis, date malformée/dupliquée/manquante et captions
vides/blanches : **projections synthétiques isolées**, jamais capturées, envoyées
au worker ou persistées. Le second créneau réel du même jour était absent dans
ce profil : son cas multiple reste donc synthétique, sans donnée inventée.

## Historique rouge et régressions séparés

Les extraits numérotés conservent les scopes suivants, sans captures rouges :

- RED attendu 42/3 : produit c517b064, test 11534446 ; absence d’adaptateur et ID
  indisponible, avant implantation.
- Premier essai nommé «green-first» : erreurs de propriétés month/selected du
  harness et timeout 90 s, sans rapport final ; le nom du fichier n’est pas un
  verdict vert et aucun nombre final de contrôles n’est fabriqué.
- Caption/Back 100/5 sur f571a161 : origine tableau, restauration et libellés
  vides/blancs non reçus à ce stade. Les erreurs gardent leur résultat propre.

Sur le même AA8, les trois wrappers de régression sont distincts : Agenda 61/0,
Entity-navigation 51/0 et Navigation 156/0. Leurs logs et résultats sont conservés
séparément avec leurs durées ; ils ne s’ajoutent pas à 132 comme des variantes
de cette nouvelle séance. Les mesures vocales de la séance sont celles du
rapport 132/0 ; aucune valeur manquante n’est déduite pour une autre suite.

Le rapport brut source contient 214685 octets de diagnostics avec répétitions
d’historique UI. Seul un **extrait JSON whitelist** est publié, clairement marqué
comme dérivé, avec taille/SHA256 du brut pour provenance. Aucun profil, guide
privé, export sportif complet ou gros blob history n’est copié. Les journaux
verts légers sont originaux ; les rouges sont des extraits numérotés.
`sha256sum --check SHA256SUMS` vérifie les pièces publiées.

Aucun SDK, import, capture ou input lancé pour cette documentation. Aucun
verdict SDK global, recette Windows ou interaction OS natif revendiqué.


## Reçu distinct b860 : 146/0 et brouillon de semaine type conservé

Cette section ajoute un reçu distinct ; le reçu AA8 **132/0**, ses sources et
ses preuves ci-dessus restent inchangés. La revue finale a ensuite ajouté le
cas d’un modèle de semaine choisi dans CalendarTemplate, **sans cliquer
Appliquer**, puis séance→Back.

Produit et test de ce reçu : `b860cf9557d8b308b9eb700772eba8b23d49378c` :
**146 contrôles, zéro échec, wrapper 0**, sous-test TAP 52181,631349 ms,
total TAP 52234,463087 ms, parole requested 0 / started 0 / id 0 sérialisée.
[Manifeste, diagnostics filtrés et provenance](evidence/night-calendar-session-draft-20261112/manifest.json)
· [PNG original](evidence/night-calendar-session-draft-20261112/images/session-1440.png).

Le modèle public réellement choisi est `standard`, pour la fixture de planning
`weekly:1:0:league:0:13`. Le test retrouve après Back le même ID dans le vrai
OptionButton, une sélection non vide et le bouton Appliquer actif, toujours
sans application. Les diagnostics enregistrent template_draft_source et
template_draft_back avec l’ID attendu ; l’extrait ne reconstruit pas un champ
UI absent. La validation de la sélection du contrôle et du bouton est une
assertion passée du test exact. La validité du brouillon est recontrôlée contre
la projection courante.

Le cas réel ne change ni entraînement ni profil. Les modèles supprimés, déjà
appliqués et prochaine fixture différente sont trois projections synthétiques
isolées, non capturées/persistées : le brouillon est alors invalidé plutôt que
réemployé pour un autre contexte. Cette couverture s’ajoute aux refus et cas
synthétiques du parcours décrit plus haut, sans nouvelle garantie causale.

Le seul PNG est 2560×1440 réels, inspecté et sans retouche. Il montre le programme
du 8 septembre avec le présent au 7 ; titre, créneau et consignes restent lisibles,
sans nouveau défaut visible. Il est pris **avant le tour du brouillon** et ne
prouve pas visuellement le choix restauré. Trois tailles sont contrôlées
(1280×720, 1920×1080, 2560×1440), pas trois captures. Le footer moral 75→76 reste
celui de la préparation de presse avant baseline, jamais un effet de consultation.

Modèle intégral, octets du profil, bridge/last_command et timer demeurent les
invariants assertés ; aucune paire de hashes sportifs non sérialisée n’est
inventée. Les événements restent des injections clavier/souris du viewport SDK
en rendu X11, sans nouvelle preuve OS native ou Windows. Le JSON brut de ce
passage contient 292606 octets de snapshots UI ; seuls résultats, lecture et
brouillons explicitement whitelistés sont publiés avec taille/hash du brut.

### Échecs conservés et régressions du même candidat

- `96a978d5a37308b8e804a4280b0e7db050cdfced` : **143/1**, perte exacte du
  brouillon lors de séance→Back. Sous-test 22212,897035 ms et total TAP 22287,859193 ms.
  Ce vrai échec de conservation n’est pas réduit à une erreur de préparation.
- `98c14027d025eb2fb3b6fbfedf21f3ef810392f2` : première tentative corrigée non
  qualifiée, erreurs d’inférence booléenne valid/selectable aux lignes 825/884,
  compilation échouée puis timeout enfant 90 s. Aucun rapport final ni compte
  de contrôles UI n’est fabriqué. Les extraits numérotés restent séparés du vert.

Sur le même b860, Agenda **61/0** (sous-test 16395,220622 / TAP 16443,108809 ms)
et Navigation **156/0** (sous-test 48575,619428 / TAP 48624,292127 ms) sont reçus
avec sortie 0 ; leurs logs légers originaux sont séparés. Navigation publie
requests/starts/id 0 ; aucune mesure vocale manquante n’est inventée pour Agenda.
Les trois anciennes régressions AA8 plus haut ne sont pas réattribuées à b860.
Ces reprises ne constituent pas une campagne SDK globale verte.

Les preuves du nouveau dossier passent SHA256SUMS ; aucun profil complet,
guide privé, export sportif, gros history blob ou image rouge n’est publié.
Documentation seulement : aucun SDK/worker/import/input/capture lancé par
l’agent pour ce complément. La revue finale globale garde sa portée propre.
