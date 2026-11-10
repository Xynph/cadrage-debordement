# Anticiper les absences internationales — 10 novembre 2026

Le suivi est accessible par **Sélections → Disponibilités** et par la carte
**Préparer les absences** du calendrier mensuel du club. Il présente les joueurs
actuellement convoqués, leur pays, leur compétition, les dates inclusives de
mise à disposition et le retour au club prévu le lendemain. Chaque nom mène
à sa fiche ; **Adapter ma composition** ouvre la composition habituelle.

Trois repères résument les absents confirmés, le prochain retour et le nombre
de postes principaux concernés. Le détail des postes indique les joueurs
restant au club non blessés ou suspendus, les convoqués et l'effectif total.
Il s'agit d'un repère par poste principal : la polyvalence et la conformité de
la feuille ne sont pas déduites de ces compteurs. Les retours des sept derniers
jours sont consultables, sans assimiler un retour au club à une guérison.

Les fenêtres des 90 prochains jours apparaissent séparément. Leurs dates
proviennent de `windows(editions)` déjà utilisé par le moteur international,
sans nouvelle formule réglementaire ni modification du calendrier. Aucune
liste de futurs convoqués n'est prédite. Le parcours dans une compétition peut
prolonger la mise à disposition ; les retours sont donc présentés comme prévus.
Une carrière sélection seule conserve les fenêtres sans afficher un effectif
fictif de club.

## Mise en œuvre et compatibilité

`international-availability.cjs` construit une projection en lecture seule.
L'accrochage est limité à `international-native.cjs` et à un champ retourné par
`international-career.cjs::project`. Aucun champ de sauvegarde n'est ajouté,
aucune sélection n'est changée et aucune écriture/RNG n'est déclenchée par
l'ouverture ou la consultation de ces écrans. Les anciennes projections sans
`availability` gardent un message de repli. Les onglets historiques conservent
leurs trois premiers indices ; le nouvel onglet utilise la clé persistante
`international_section = availability`.

Le Bureau peut consommer `model.international.availability` : `clubManaged`,
`absentCount`, `nextReturn`, `positions`, `players`, `windows`, `returned` et
`horizonDate`. Les champs ne doivent jamais être réinjectés dans la carrière.

## Vérification

- Node 22.23.4 : 55/55 tests internationaux réussis, dont six nouveaux scénarios
  sur le dernier jour d'absence, le retour, les postes, les doublons, les fenêtres
  sans noms prédits, le mandat sélection seule et l'absence de mutation.
- Godot 4.7.2 sans fenêtre : 13 contrôles réussis, une vraie carrière Monde
  anglaise, le calendrier et le bon onglet, le lien vers la bonne fiche réelle,
  l'accès composition et l'empreinte sportive inchangée.
- Le banc commence par la projection du vrai moteur puis injecte explicitement
  une projection UI contrôlée pour recevoir les états absent/retour/poste exposé.
  Cette seconde image ne représente pas une avance réelle de plusieurs mois.
- Les captures Linux en 720p, 1080p et 1440p sont reçues par l'intégrateur sur le
  cumul. Aucune validation Windows ni conformité réglementaire nouvelle annoncée.

```sh
node --test tests/international-availability.cjs
CD_GODOT_EXECUTABLE=/chemin/vers/godot node --test tests/godot-international-availability.cjs
```

Pour le rendu X11, ajouter `CD_INTERNATIONAL_AVAILABILITY_GRAPHICS=1`,
`QA_RESOLUTION=1280x720` (ou `1920x1080`, `2560x1440`) et
`CD_INTERNATIONAL_AVAILABILITY_OUTPUT=/tmp/preuves`. Les profils sont toujours
créés séparément dans le dossier temporaire système, hors application. Le banc
vérifie les dimensions réelles de chaque capture.
