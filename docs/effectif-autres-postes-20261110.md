# Effectif : poste principal et autres postes

UI du 10 novembre 2026, base `72ade90`, [PR #526](https://github.com/Xynph/cadrage-debordement/pull/526).

## Affichage et lecture

La colonne **Poste principal** garde exactement le texte `player.pos`. La colonne
**Autres** affiche les numéros de `secondaryPositions` fournis par le modèle.
Le nom de chaque poste est disponible au survol : l’interface réutilise les
étiquettes déjà projetées dans `selection.slots`. Le numéro principal, lorsqu’il
est fourni, figure seulement dans l’infobulle du poste principal.

Une liste absente ou vide donne un tiret neutre. Les numéros sont présentés dans
l’ordre numérique pour faciliter la lecture. Les doublons et valeurs hors du
format 1–15 sont écartés dans une copie locale. Aucune aptitude n’est recalculée
par l’interface. Un intervalle tel que `11–15` apparaît uniquement si tous les
numéros consécutifs sont présents ; `11·14·15` reste explicitement disjoint.

Les deux colonnes trient dans les deux sens. Autres utilise une comparaison
numérique des listes, jamais l’ordre alphabétique des chiffres. Les listes vides
restent en dernier dans les deux sens, les égalités restent ordonnées par ID.
L’en-tête actif et son focus restent visibles. Aucun nouveau qualificatif ou
texte de provenance mécanique n’est ajouté aux cellules ou infobulles.

La place est dégagée dans la colonne du nom : texte de 190 px, poste principal
à x325 sur 154 px, autres sur 76 px avant l’âge. Âge et toutes les colonnes suivantes
restent à leur emplacement. Note reste supprimée ; salaires à la centaine, années
civiles de fin de contrat, niveau vert et potentiel orange sont conservés.
La liste reste continue, sans pagination, dans son conteneur de défilement interne.

## Réceptions observées

Godot 4.7.2 Linux, Node 22.23.4 :

- **179 contrôles sans fenêtre** sur la projection ancienne sans ces champs :
  tirets neutres, géométrie, tri, affichage et conservation du profil.
- **105 contrôles de non-régression** du tri complet et défilement interne réussis.
- **180 contrôles sans fenêtre** avec la vraie API native du commit `c45557e` :
  carrière common créée par le moteur, **33 profils sur 40** avec autres postes.
- **186 contrôles graphiques X11**, exclusivement en 2560×1440, avec cette même
  projection native. Les 40 lignes et chaque position publiée sont vérifiées,
  puis le survol réel est capturé. Profil inchangé et aucune commande supplémentaire
  après création de la carrière.

La recette UI n’intègre pas les trois fichiers moteur dans cette branche : elle
utilise une copie QA du moteur de base, remplacée par `position-aptitudes.cjs`,
`worker.cjs` et `model.cjs` du commit `c45557e`. La [capsule d’empreintes API](effectif-autres-postes-20261110/backend-api.json)
identifie ces fichiers. **Il s’agit de la réception de l’API et de son affichage,
pas de la réception complète de l’éligibilité et des effets en match**, encore
traitée par le chantier moteur au moment de cette capture.

Les deux captures principales utilisent les données de cette vraie création de
carrière, sans modification des autres postes. Un troisième cas teste explicitement
la disposition de listes contrôlées ; cette image est marquée « CAS UI DE RECETTE ·
DONNÉES CONTRÔLÉES » et n’est pas présentée comme une sortie du calcul moteur.

[Effectif natif](effectif-autres-postes-20261110/effectif-postes-modele-reel-1440.png) ·
[Survol des noms](effectif-autres-postes-20261110/effectif-postes-survol-1440.png) ·
[Rapport graphique](effectif-autres-postes-20261110/report.json).

```sh
CD_GODOT_EXECUTABLE=/chemin/vers/Godot node --test tests/godot-squad-secondary.cjs
```

Pour exiger la projection native raccordée, définir `CD_SQUAD_SECONDARY_REQUIRE_MODEL=1`.
Pour les captures, définir `CD_SQUAD_SECONDARY_GRAPHICS=1` et
`CD_SQUAD_SECONDARY_OUTPUT=/tmp/oval-secondary-1440`. Le banc peut utiliser un moteur
QA explicite via `CD_SQUAD_SECONDARY_WORKER=/chemin/absolu/worker.cjs` ; ce sélecteur
n’existe que dans le test. Chaque exécution crée son profil hors de l’application.
Le serveur graphique privé :94 a été arrêté après réception.

## Intégration

Seul fichier de jeu modifié : `squad_canvas.gd`. Le principal `pos` et la famille
`fam`, les sauvegardes et les calculs de rôle ne sont pas modifiés dans ce lot.

Prochaine étape : intégrer avec le moteur complet puis rejouer le banc sur le
cumul et recevoir les actions de composition aux postes secondaires. Aucune
nouvelle validation Windows, CI supplémentaire ou fusion revendiquée ici.
