# Préparation : briefing avant le coup d’envoi — 10 novembre 2026

La page **Préparation → Dossier** garde le rapport de force, les observations
adverses et les accès aux consignes, à l’entraînement et au carnet de jeu. Elle
rassemble désormais les décisions à prendre dans la même vue : presse
obligatoire, feuille à compléter, situation du jour, absences internationales,
blessures et consignes. Les liens ouvrent les parcours existants ; ils ne
lancent aucune commande sportive à la consultation.

## Lecture dense à 2560×1440

- Repères en couleur et pictogrammes : feuille publiée, condition moyenne du
  XV disponible dans la projection, nombre de secteurs documentés.
- Jusqu’à cinq lignes de décision, avec motif et lien. Les urgences presse et
  feuille précèdent le jour du match puis les alertes d’effectif. Les autres
  repères restent consultables dans une fenêtre défilable.
- Tableau des résultats réellement observés, jalons journée/feuille/rencontre
  et schéma indicatif des quinze cases de la composition publiée. Le numéro
  ouvre la fiche du joueur effectivement affecté ; aucun joueur n’est ajouté.
- Portraits existants des joueurs adverses à surveiller, nom/poste/rôle ;
  pictogramme neutre si aucune identité exploitable n’est publiée.
- Images du club adverse lorsqu’il est identifié, avec distinction photo du
  pack, archive ou illustration IA. Les images remplissent les espaces où les
  résultats ou alertes ne sont pas encore disponibles, sans remplacer de
  données existantes.
- Corps courant 16–18 px, chiffres 18–21 px, titres de cartes 24–28 px et
  actions compactes. Les données utilisent les styles immersifs sans passer
  par le plafonnement des anciens composants G.

**Conseils détaillés** et **Adopter le plan proposé par le staff** restent des
accès directs. L’adoption conserve sa commande et ses gardes existantes ; elle
nécessite un clic explicite. Consulter le briefing n’adopte aucun plan.

## Informations connues et inconnues

L’adversaire annoncé au calendrier reste affiché même si son dossier n’est
pas encore publié. Notes, résultats récents et liste adverse sont signalés
comme indisponibles lorsqu’ils manquent. Une note absente ne produit pas une
barre à zéro. Les notes présentes restent celles du moteur de simulation,
sans nouvelle prédiction, règle ou bonus. Le schéma du XV est un repère de
lecture des affectations, pas une validation réglementaire supplémentaire.

Le match du jour n’est signalé qu’à partir de `calendarCadence.matchReady`.
La date seule ne débloque pas le coup d’envoi. La clôture sportive utilise
`meta.phase`, y compris lorsque des journées internationales restent à jouer.
Les ticks actualisent le libellé de retour au match sans reconstruire le
contrôle qui possède le focus.

## Recettes

Le banc dédié reçoit une vraie carrière puis des projections UI contrôlées :
presse avant le match, motif de feuille, disponibilité des données, maintien
du dossier, Entrée réelle sur les actions et le titulaire du schéma, bonne
fiche, absence de commande et empreinte sportive inchangée. Les captures
contrôlées ne constituent pas une simulation de plusieurs mois.

```sh
CD_GODOT_EXECUTABLE=/chemin/godot node --test tests/godot-preparation-briefing.cjs
```

Pour la réception X11, ajouter `CD_PREPARATION_BRIEFING_GRAPHICS=1` et
`CD_PREPARATION_BRIEFING_OUTPUT=/tmp/preuves-briefing`. Les deux captures sont
vérifiées à **2560×1440** : dossier réel puis adversaire connu sans dossier.
Le profil temporaire est créé hors du dossier de l’application. L’intégrateur
reçoit les captures sur le cumul. Aucune recette Windows n’est revendiquée.
