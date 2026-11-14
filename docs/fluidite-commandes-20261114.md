# Fluidité des commandes en carrière Monde (14/11/2026)

Objectif validé par Léo : « quasi pas de chargement sauf quand on change de jour ».

## Mesure

Outil : `CD_ENGINE_TIMING=1` (ou l'option `timing`) ajoute à chaque réponse du worker la durée de chaque phase.
Phases désormais détaillées : `garde`, `copie_annulation`, `commande` (calcul du moteur), `completion` (profondeur
d'effectif, attributs), `serialisation` (`save()` : texte de la carrière par sections), `validation_sauvegarde`
(validation stricte), `projection` (modèle de l'interface), `profil_texte` (texte du profil), `ecriture_fsync`
(fichier temporaire + fsync), `secours` (copie de secours par lien physique), `ecriture_disque` (renommages),
`connaissance` (portraits et frontière de connaissance), et `ecriture_precedente` (écriture différée de la décision
précédente quand la commande suivante arrive avant la fin). Côté Godot, `CD_GODOT_TIMING=1` imprime `CD_TIMING`
(moteur + transfert, lecture JSON, attente du fil principal, rendu de l'écran) ;
`tests/godot-fluidite-monde-mesure.gd` déroule un parcours Monde complet (écrans, fiche joueur, décisions,
match délégué, jours).

Carrière Monde (`world-champ`, club 102, départ « club »), jour de match, profil de 26 Mo. Machine de mesure :
2 cœurs partagés avec d'autres simulations, Node 22, `--max-old-space-size=1300`. Médianes de 3 sessions
(« avant ») et 2 sessions (« après » : une troisième a été tuée par manque de mémoire de la machine). Les valeurs
absolues sont pessimistes (machine chargée) ; les rapports avant/après sont la donnée utile.

| Temps ressenti (moteur + encodage de la réponse) | Avant | Après | Remarque |
|---|---:|---:|---|
| Changer un titulaire / « Suivre le conseil » (`set_lineup`) | 5,8 s | 2,1 s | écriture après la réponse |
| Composition automatique | 5,9 s | 3,6 s | idem |
| Consignes de jeu (1re décision après chargement) | 6,1 s | 3,6 s | idem |
| Réunion du club / conférence de presse / causerie | 5,6 / 6,7 / 5,6 s | 2,9 / 3,7 / 3,0 s | idem |
| Ouvrir un écran, une fiche joueur | 0 commande moteur | 0 commande moteur | rendu Godot seul |
| Relecture du modèle (`snapshot`) | 2,6 s | 2,2 s | modèle 18,7 → 13,2 Mo |
| Premier écran après chargement | 7,4 s | 6,0 s | idem |
| Déléguer un match | 6,9 s | 2,3 s | écriture après la réponse |
| Coup d'envoi / clôture du match | 7,8 / 6,3 s | 6,5 / 4,8 s | écrits avant la réponse |
| Passer un jour | 4,1 s | 3,6 s | écrit avant la réponse |
| Jour qui clôt la semaine | 14,4 s | 11,7 s | simulation de la journée : ~7 s |
| Une semaine (6 jours + clôture) | ~39 s | ~33 s | |

Écriture différée mesurée après la réponse : 2,0 à 3,0 s par décision (sérialisation, validation, écriture),
pendant que l'interface affiche déjà le résultat.

### Décomposition d'une action simple avant (`set_lineup`, médianes, ms)

| commande | completion | sérialisation | validation | projection | texte du profil | écriture + fsync | lien de secours | renommages | connaissance | encodage différentiel |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 232 | 80 | 339 | 1 358 | 1 959 | 117 | 338 | 2 | 15 | 993 | 206 |

Constat critique : depuis #669 et #672, l'écriture disque elle-même (texte du profil, fsync, lien de secours,
renommages ≈ 0,5 s) n'est plus le coût dominant. Le temps part dans la validation stricte de la carrière
(~1,4 s) et surtout dans la reconstruction complète du modèle de l'interface à chaque commande (projection
~2 s + connaissance ~1 s), alors que l'écran n'en change qu'une petite partie.

## Corrections

1. **Écriture différée des décisions courantes** (`deferredCommits`, activée par le worker du jeu ;
   `CD_ECRITURE_DIFFEREE=0` la coupe). Une commande qui n'avance pas le calendrier répond d'abord ; sa
   sérialisation, sa validation stricte et l'écriture atomique du profil suivent dès que la réponse est partie,
   et au plus tard avant la commande suivante, la fermeture ou « Sauvegarder ». Restent écrites **avant** leur
   réponse : avance d'un jour, clôture de semaine, coup d'envoi, préparation, nouvelle saison, création, import,
   restauration d'une copie, « Sauvegarder », packs, sélections nationales.
2. **Cibles du carnet personnel hors de la frontière de connaissance** : les ~5 000 joueurs du monde proposés
   comme cibles de note (identifiant, nom, poste) recevaient chacun fourchettes et fiches de recrutement inutiles à
   l'écran du carnet ; le modèle passe de 18,7 à 13,2 Mo (moins de parcours, d'encodage et de copie côté Godot).
   `CD_CARNET_CIBLES=complet` rétablit l'ancien modèle.

## Recette Windows du vrai EXE (run 43603330612) : cause et correction

- **Symptôme** : après 37 journées, `next_season` ne répond pas dans la borne de 20 s de `qa_runner.gd` (« Engine response is bounded »), d'où la cascade : saison 2 non atteinte, export non écrit, import non restauré.
- **Cause** : l'écriture différée d'une décision (sérialisation, validation stricte, écriture atomique) démarrait dès la réponse partie et bloquait le moteur d'un seul tenant. La commande suivante, envoyée aussitôt par l'interface, attendait la fin de cette écriture **puis** faisait son propre travail, qui réécrit de toute façon toute la carrière. En fin de saison (gros profil, disque Windows), écriture + nouvelle saison > 20 s.
- **Second défaut** : le pont Godot tuait le moteur 2 s après « shutdown » ; une décision encore en écriture (2 à 6 s) était alors perdue à chaque fermeture rapide.
- **Correction** : (1) l'écriture en attente se fait par étapes (sérialisation, validation, écriture) entre lesquelles la boucle stdio lit les commandes arrivées ; (2) une commande déjà écrite avant sa réponse (jour, coup d'envoi, clôture, nouvelle saison, préparations, « Sauvegarder ») reprend la décision à son compte : validée (y compris un jour de semaine) et écrite avec elle ; refusée, elle la laisse en mémoire et en attente ; (3) le pont Godot attend la réponse à « shutdown » jusqu'à 20 s, puis 2 s après elle, avant de tuer le moteur ; la fermeture du jeu et les recettes attendent ce même délai.

## Sécurité de la sauvegarde

- Remplacement atomique inchangé (fichier temporaire + fsync, copie de secours par lien physique ouvert en
  lecture-écriture pour Windows, renommages) : une coupure ne corrompt jamais le profil.
- Au pire, une coupure brutale perd **la dernière décision courante** (composition, consignes, réunion, causerie,
  match délégué…) dont l'écriture n'était pas terminée, soit les ~2 à 3 s qui suivent sa réponse ; jamais un
  changement de jour.
- Si l'écriture différée échoue (disque plein, fichier verrouillé), la décision est annulée en mémoire, comme
  avant, et la commande suivante est refusée avec la raison (« Votre dernière décision n'a pas pu être
  enregistrée… ») ; l'indicateur d'échec de sauvegarde reste visible. Aucun repli silencieux.

## Tests

`tests/vitesse-commandes-monde.cjs` : réponse sans sérialisation ni écriture puis profil écrit ; jour écrit avant
sa réponse ; mêmes modèles et même profil final avec et sans écriture différée ; coupure brutale (SIGKILL) ;
échec d'écriture annulé et signalé ; seuils larges (décision < 15 s, jour < 40 s, réglables par
`CD_SEUIL_DECISION_MS` et `CD_SEUIL_JOUR_MS`).

## Suite recommandée

Le gros gisement restant est la reconstruction du modèle complet à chaque commande : mémoriser la projection par
domaine (marché entre clubs 4,4 Mo, carrière du staff 2,5 Mo, équipes du staff 2,5 Mo) quand ses sections
sources n'ont pas changé, ou ne les envoyer qu'aux écrans qui les ouvrent. La validation stricte (~1,4 s) pourrait
ne reparcourir que les sections modifiées pour les domaines encore validés en entier.
