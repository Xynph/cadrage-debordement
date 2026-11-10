# Tactique : aptitude au maillot et affectations directes

Base reçue : `d175323`. Conception approuvée par l'intégrateur : conserver les
trois colonnes de la Tactique existante (XV, identité, banc et joueur).

La note est la projection `positionRatings[str(positionNumber)]` du joueur
consulté au poste choisi. La condition reste une donnée distincte ; l'interface
n'invente aucun second malus. `selection.slots[].eligibleIds` est la seule
autorité d'affectation, notamment pour les qualifications de première ligne.

Un onglet Effectif dans la carte Banc permet de consulter tous les joueurs,
y compris les absents de la feuille à 23. Choisir un candidat montre sa note
au numéro actif ; une action explicite l'affecte. Le banc conserve huit places
et les opérations par clic et clavier. Aucun nouvel écran n'est créé.

Le glisser-déposer utilise une seule commande `set_lineup`, comme le choix
classique. Le moteur décide l'échange ou le refus. Une source périmée, étrangère
au club, une cible non éligible, un match engagé ou une commande en attente
ne permet aucune affectation. Annuler un glisser ne modifie rien.

Approches : modifier les positions localement aurait contourné les validations ;
une nouvelle page aurait cassé le cadre demandé. L'approche retenue étend les
boutons et les données de la page actuelle avec un module de sélection dédié.

## Plan d'implémentation

- [ ] Banc de réception sur la vraie application et scénarios de refus avant
  l'implémentation ; vérifier les échecs attendus.
- [ ] Module dédié : lecture stricte des notes/projections, contrôle des sources
  et cibles, classes de boutons glissables et aperçu de déplacement.
- [ ] Raccord de la page existante : maillots, banc, liste Effectif à en-têtes
  fixes et carte du candidat contextualisée au numéro choisi.
- [ ] Réception : même joueur à son poste puis au n°10, clic/clavier, affectation
  réelle, échange, refus première ligne, annulation et absence de doublons.
- [ ] Capture réelle 2560×1440 sur cache privé, preuves et passation GitHub.

## Risques à vérifier

Une note absente doit rester « — » ; elle ne doit pas devenir la note du poste
principal. Les notes à zéro doivent rester visibles. Un ID obsolète ou inconnu
doit être refusé sans commande. Les consultations et annulations conservent
l'export et le profil. Le défilement de l'effectif reste dans sa carte. La
projection du banc doit fournir son numéro d'aptitude : aucun numéro16–23
n'est interprété comme un poste de terrain.
