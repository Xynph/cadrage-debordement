# Fatigue et rotation — lecture dense en 1440p

Dans **Entraînement → Fatigue**, un tableau compact regroupe l'effectif pour
préparer les plans individuels et la rotation. Il affiche au moins vingt
joueurs à 2560×1440, avec portraits, poste, minutes projetées, barres de condition
et charge, état de blessure, sélection, suspension connue et plan individuel.
Les lignes mesurent 29 px ; les données utilisent 18–20 px et les repères
16–17 px. Le tableau défile pour le reste de l'effectif.

Tous les en-têtes de données trient leur colonne : joueur, poste, condition,
charge, minutes, blessure, sélection, suspension et plan. Un premier clic
active l'ordre croissant **↑**, le suivant l'ordre décroissant **↓** ; **↕**
signale une colonne inactive. Les colonnes chiffrées utilisent les nombres
réels, les plans et statuts leur texte affiché. Les valeurs non renseignées
restent en fin de liste dans les deux sens ; les égalités sont départagées
par identifiant stable. Le filtre en cours et les actions attachées aux
identifiants des joueurs sont conservés.

Le tableau **Individuel** de l'Entraînement propose le même tri sur ses cinq
colonnes, avec son état de tri indépendant. Ses lignes mesurent 32 px. Les deux
listes contiennent tout l'effectif, sans pagination ni plafond : la molette
fait défiler uniquement les lignes dans leur zone interne. Les en-têtes,
filtres, distributions et panneaux restent fixes.

Les résumés sont cliquables et les filtres isolent les joueurs à ménager,
blessés, suspendus **connus**, en sélection ou tout l'effectif. Si un filtre ne
retient personne, l'écran le signale et conserve l'effectif complet comme
repère pour préparer les plans. Le filtre n'invente pas de cas ni de diagnostic.
La distribution de charge et la répartition avants/arrières comptent seulement
les valeurs présentes dans la projection ; aucun historique n'est reconstitué.

## Repères et limites

La surveillance réutilise directement `management_state.watch_reason` : charge
au moins 70 ou condition sous 80. Le compteur de vigilance de l'Entraînement
utilise désormais cette même fonction : il ne garde plus ses anciennes bornes
55/70. Un témoin vérifie qu'une charge de 55 seule n'est pas signalée et qu'une
condition de 75 l'est.

Les situations restent séparées : une convocation n'est pas une blessure, la
charge n'est pas un diagnostic, et la suspension n'est affichée comme connue
que si une valeur numérique existe dans la projection. Le modèle club actuel
ne publie pas de suspension : les lignes portent donc **Non renseignée** et le
résumé indique le nombre de données absentes. Le code ne transforme jamais
cette absence en zéro suspension.

Les convocations utilisent `international.availability.players` par identifiant
et leur retour confirmé apparaît dans l'infobulle. Sans projection
internationale, cette colonne reste **Non renseigné**. Les montants, règles de
récupération, blessures et indisponibilités du moteur ne sont pas modifiés.

## Régler un plan individuel

**Régler** ouvre un dialogue nommé pour le joueur. Choisir un plan ouvre une
confirmation rappelant son identité et que la séance n'est pas lancée. Seule
la confirmation envoie `set_player_load` avec l'identifiant exact du joueur et
le plan choisi. Annuler ne provoque aucune requête ni écriture sportive.

Les plans restent consultables pendant le match, après une séance effectuée
et en fin de saison, mais les boutons de modification sont désactivés avec
le motif. Le comportement de récupération des joueurs blessés reste celui du
moteur existant ; aucune nouvelle règle médicale n'est ajoutée.
L'action **Ouvrir la composition** permet de préparer ensuite le XV et le banc.

## Réception et captures

Avec Node 22 et Godot 4.7.2, après préparation et import des ressources :

```sh
CD_GODOT_EXECUTABLE=/chemin/Godot node --test tests/godot-fatigue-overview.cjs
```

Le banc utilise une vraie carrière jetable créée par le worker. Il vérifie les
identifiants, la consultation et l'annulation sans écriture, la confirmation
d'une unique commande sur le bon joueur, les plans des autres joueurs
inchangés, l'absence de séance implicite, les filtres et les bornes communes.
Il contrôle aussi qu'au moins vingt lignes restent visibles à la définition de
référence. Les profils sont toujours créés sous le répertoire temporaire
système, hors du dépôt et sans lire de carrière personnelle.
Le banc reçoit les deux sens de chaque colonne, les égalités, les inconnus,
l'ordre réellement rendu et l'absence de commandes pendant tous ces tris.
Il envoie également de vrais événements de molette, vérifie les positions
fixes des en-têtes et panneaux et la présence de tous les identifiants sans
pagination dans les deux listes.

Pour recevoir les captures sur le cumul, avec un écran X11 2560×1440 :

```sh
CD_GODOT_EXECUTABLE=/chemin/Godot \
CD_FATIGUE_GRAPHICS=1 CD_FATIGUE_OUTPUT=/tmp/oval-fatigue-images \
node --test tests/godot-fatigue-overview.cjs
```

Le banc produit une capture de confirmation, une capture de la vraie carrière
après réglage et une capture **de projection UI de recette** montrant les
catégories distinctes. Cette dernière modifie seulement les données affichées,
pas le profil du moteur, dont l'empreinte est vérifiée inchangée. Ce témoin
graphique ne prouve pas une blessure, une suspension ou une convocation
réellement survenue dans cette carrière. La recette ne revendique aucun test
Windows ni aucune autre définition d'écran.
