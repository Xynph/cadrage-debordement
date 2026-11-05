# V77 — La passerelle Espoirs vers les professionnels

## Valeur joueur
Depuis Formation, le manager choisit un Espoir de son propre centre et signe son premier contrat professionnel pour **1, 2 ou 3 saisons**. Le salaire hebdomadaire dépend du niveau, du potentiel et de la durée. L'opération crée une vraie entrée dans `clubs[club].players` et retire le même joueur de `development.academy` sans changer identité, poste, caractéristiques ou potentiel. Le joueur devient éligible aux compositions natives **XV + 8** (interface Effectif & 23) ; aucun titulaire n'est remplacé automatiquement.

## Règles
- Maximum **3 promotions par saison**, effectif professionnel limité à **42**, jeunes de 21 ans ou moins, sélection uniquement hors rencontre.
- Protection de la profondeur du centre : en cas de perte de la dernière couverture d'un poste ou d'un groupe de moins de 15, génération d'un remplaçant Espoir fictif, sans toucher aux fichiers V73-V76. Le nouveau joueur conserve la mécanique de progression standard.
- Sauvegarde atomique : échec de `save()` ou erreur de stockage => retour des deux effectifs, états V77, composition Espoirs, historique et flux d'informations à leurs valeurs précédentes.
- `v77Promotions` facultatif, versionné : promotions annuelles et 4 saisons d'historique. Réinitialisation au changement de saison par wrapping de `advanceSeason` ; les anciennes carrières sans cette clé restent prises en charge.
- Temps de jeu, forme et développement ne sont pas simulés par V77 : ils sont traités par `recordDevelopmentMatch` et `rollDevelopmentYear` existants, après intégration effective du joueur dans l'effectif professionnel. Les contrôles de la feuille à 23 restent ceux du moteur natif.
- Les prix et contrats sont **entièrement fictifs**, non des données LNR.

## Périmètre
`dist/espoirs-pro-v77.js` ; `tests/v77-espoirs-pro.cjs` ; `docs/v77-espoirs-pro.md` ; inclusion du script V77 juste après V76 dans `dist/index.html`.

Aucune modification MATCH 3D #300, R&D #315, DATA/LNR, calendrier officiel, moteur sportif, versions V73–V76, CI ni release gate. PR producteur : aucune fusion.

## Vérification
`node tests/v77-espoirs-pro.cjs`, suites JavaScript, Chromium et workflows de PR sur le HEAD exact. Les tests couvrent la transaction annulée, le transfert d'identité, la limite de trois joueurs, les contrats, le XV Espoirs complet, l'accès à l'effectif professionnel, les anciennes sauvegardes et cinq saisons.
