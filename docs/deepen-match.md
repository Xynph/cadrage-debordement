# Lire les séquences tactiques et retrouver une action

## Conception
Le lecteur conserve un instantané local des faits et ne modifie jamais le match.
Ce lot ajoute une sélection directe dans le Journal, une chronologie filtrable et
un index de séquences délimitées uniquement par les changements de période ou de
plans présents dans les faits. Les scores au premier et dernier fait d'une
séquence ainsi que les catégories d'actions observées décrivent ce qui s'est
produit, sans attribuer de causalité aux consignes.

Les champs absents restent inconnus. Aucun temps réel, vitesse de déplacement,
plaquage ou trajet animé n'est déduit de la seule minute des faits. Le schéma
continue d'afficher exactement les coordonnées du ballon enregistrées.

## Plan
- Ajouter une recette rouge sur les contrôles manquants et les interfaces.
- Ajouter les index/segments/filtres et leur bilan factuel pur.
- Ouvrir la relecture depuis un fait précis au clavier ou à la souris.
- Vérifier le worker réel, les ticks concurrents, les changements de contexte,
  les données anciennes et les contrôles lisibles à720p/1080p.

## Livré
- Le libellé d'un fait du Journal ouvre directement son action, par clic ou
  Entrée/Espace. Le bouton général conserve l'ouverture au dernier fait.
- Trois index locaux se combinent : séquence de période/plans, catégorie de
  faits (dont Consignes) et chronologie. Le filtre de moments clés reste actif.
- La séquence est délimitée par les changements des plans complets des deux
  équipes ou de la période présents dans les métadonnées ; une zone sans plans
  reste une séquence inconnue. L'ordre enregistré est conservé, sans tri qui
  déplacerait deux faits de même minute.
- Le bilan affiche les plans, les scores au premier/dernier fait documenté et
  des comptages de faits. Il ne mesure ni une efficacité causale ni une durée
  d'animation. Le schéma reprend uniquement les coordonnées validées du ballon.
- « Voir le terrain » révèle le schéma. Le bilan est repliable et sa révélation
  attend la mise en page réelle. La fenêtre auxiliaire n'est pas exclusive :
  elle laisse les vraies erreurs du moteur s'afficher et ne suspend pas le direct.

## Vérifications exécutées
Godot4.7.2 Linux, Node22.23.4, sans changement du worker ou des règles.

- `tests/deepen-match.cjs` : **51 contrôles réussis** sur le client complet et
  le vrai worker. Création/import d'une fixture anonyme, clavier et clic souris,
  filtres et séquences, métadonnées absentes, coordonnées, ticks natifs pendant
  lecture, arrêt/reconnexion du processus, import et nouvelle carrière.
  Le modèle, l'horloge et les octets du profil restent inchangés pendant la
  consultation ; les ticks explicitement demandés par le test sont distingués.
  Preuves : `/tmp/cd-deepen-match-NI5HIt/`.
- Régression `godot-match-action-review.cjs` : **43 contrôles réussis**,
  `/tmp/cd-action-review-LNnNiR/`.
- Régression `godot-match-journal.cjs` : **297 contrôles réussis**, y compris
  quatre faits complets au720p et géométrie/clavier/import ;
  `/tmp/cd-match-journal-lN6foo/`.
- Capture du véritable lecteur isolé : **6 contrôles réussis** et six images
  index/terrain/bilan aux formats1280×720 et1920×1080,
  `/tmp/cd-deepen-match-a1YkbB/`. Index720p et bilan1080p inspectés : les
  contrôles et le bilan sont lisibles et le bouton de fermeture reste visible.
  Cette recette isole la fenêtre réelle et utilise les faits de la fixture ;
  elle ne prétend pas recevoir l'animation3D ou tout le client graphiquement.
- `git diff --check` et analyse syntaxique du runner Node réussis.

Le test d'absence des index a été observé rouge sur les deux fichiers de base
puis vert avec le lot. Deux problèmes supplémentaires ont été reçus rouges puis
corrigés : concurrence de dialogues exclusifs lors d'une vraie panne transport ;
bilan partiellement masqué par un défilement lancé avant sa mise en page.

La première tentative graphique du client3D complet sous llvmpipe a été arrêtée
avant conclusion, car trop coûteuse dans le contexte parallèle ; elle n'est pas
comptée comme réussite. La réception graphique isolée ci-dessus est terminée.
Aucune réception Windows ni plaquage animé n'est revendiqué.

## Reproduction
Après staging et import du projet Godot, sur un stockageXDG accessible :

```bash
CD_GODOT_EXE=<Godot4.7.2> node tests/deepen-match.cjs
```

Le runner signale explicitement unSKIP si aucun SDK n'est configuré. Avec
`CD_DEEPEN_MATCH_GRAPHICS=1` et un affichageX11, il reçoit le lecteur isolé et
capture index/terrain/bilan. Le pilote audioDummy est explicite ; aucune nouvelle
bibliothèque ou ressource payante n'a été ajoutée.

## Raccordement
Aucun raccord central. Seuls `match_action_review.gd` et `ui/match_journal.gd`
sont modifiés. Aucun champ de sauvegarde, commande du moteur, débit, tirage,
position3D ou ressourceGLB n'est ajouté ou réécrit.
