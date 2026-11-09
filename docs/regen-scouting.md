# Détection et recrutement des regens adultes

## Décision et périmètre

La cellule native réunit les candidats déjà produits par la population v2 : diplômés de centre (`academy`) et émergences du bassin des petits clubs (`small-club`). Ce bassin est une simulation abstraite ; aucun petit club réel ni compétition n’est inventé. Seuls les agents libres majeurs sont proposés. Les jeunes encore au centre restent dans Formation, dont les compétitions avancées sont actuellement indisponibles en Monde ; les promotions de base restent accessibles.

L’option retenue est une projection et une shortlist sur le moteur existant. Un second vivier, un nouveau moteur d’observation ou de contrats auraient doublonné les populations, frais et sauvegardes. Aucune donnée cachée, probabilité de progression ou qualification réglementaire n’est révélée. Les profils privés et les identités présentées restent séparés de la carrière.

## Moteurs réutilisés et contrat

- `managerPool()` fournit les agents libres ; la provenance provient uniquement de `player.population`, jamais du nom ou d’un score secret.
- `recruitmentEvidence()` fournit les intervalles non observés fondés sur le salaire, ou le rapport daté avec son incertitude et son vieillissement. Aucun niveau ou potentiel réel du candidat n’est ajouté.
- `recruitmentNeeds()` et `slotEligible()` relient les candidats aux besoins existants du club. Le tri est âge puis identifiant ; aucun classement secret des talents.
- `scout_mission` conserve ses critères, son coût unique de 5 000 € fictifs et deux journées de travail par mission active. Cette mission porte sur tous les agents libres répondant aux critères, pas exclusivement les regens. La projection ne commande aucune mission automatiquement.
- `recruit` conserve les demandes salariales, négociations, refus, prime et signature réelles. La population v2 alimente tout le marché adulte ; un candidat absent du marché ne reçoit pas une disponibilité mensongère.
- La nouvelle commande `regen_shortlist` attend `{playerId, watched:boolean, context:{season,week,club}}`. Elle donne la valeur souhaitée au suivi existant `manager.watch` (30 entrées), sans basculer un suivi déjà conforme. Aucun nouveau champ de sauvegarde n’est créé.

Le domaine `regenScouting` exporte `files:[]`, `commands:['regen_shortlist']`, `factory()`. Son `project(filters?)` renvoie `available`, `context`, `locked`, `candidates`, `shortlist`, `needs`, `missions`, `reportCount`, `shortlistLimit`, `missionCost`, `missionCommand`, `recruitCommand`, `notice`. Les filtres optionnels sont `family` (0–8), `minAge`/`maxAge` (18–60), `needsOnly` et `watchedOnly`. La vue native peut aussi filtrer ces lignes en mémoire. Les candidats portent une identité stable, origine explicite, intervalles observés, demande salariale, prime, durées et engagements salariaux connus ; ces engagements n’inventent pas de recettes futures. `shortlist` conserve les IDs suivis devenus indisponibles et permet de les retirer.

`validate(state)` n’ajoute aucune migration : les structures utilisées sont déjà contrôlées par `validateCareer/validateManager`. Le worker reste propriétaire des transactions disque, de l’import, du rollback, du RNG et de l’horloge. `installHooks()` est vide. Les consultations ne modifient aucun joueur, rapport, coût ou état persistant.

## Plan de réalisation autorisé

1. Écrire les tests avant le module : absence du domaine, projection sans information secrète, filtres, provenance et limites, suivi idempotent et refus.
2. Implémenter le domaine isolé ; ne modifier ni manifeste, ni worker, ni modèle partagé. Le raccordeur enregistre le domaine séparément.
3. Recevoir le vrai worker avec le même manifeste copié dans un dossier temporaire : observation payée une seule fois, rapport après deux journées, signature et prime réelles, réouverture/export exacts et rollback disque.
4. Exécuter les tests ciblés sous Node22, consigner les mesures puis committer les trois fichiers. Aucun coefficient économique, moteur de match, protocole multigraines, push ou fusion dans ce lot.

Risques à couvrir : candidat devenu indisponible, suivi partagé déjà rempli, contexte périmé, fin de saison/match, donnée non observée artificiellement modifiée, vieille carrière sans provenance et erreur de publication disque. Une shortlist n’est ni une réservation ni la preuve d’un potentiel futur.

## Réception ciblée

Tests rouges avant création du module (domaine absent), puis commande Node22 :

```sh
/workspace/.cloud-setup/tools/node22/bin/node --test tests/regen-scouting.cjs
```

Les huit tests passent sous Node22 en 15,8 s. Les deux suites existantes `tests/v30-recruitment-intelligence.cjs` et `tests/native-recruitment06.cjs` passent également (0,65 s). Les tests utilisent les vrais helpers du moteur, pas un modèle d’observation recopié. Le worker est copié temporairement pour enregistrer uniquement ce domaine, sans éditer le manifeste partagé. Les cas reçus couvrent mutation adversariale du talent non observé sans changement des lignes, diplômé du centre et provenance explicite, absence de provenance sur ancienne carrière, shortlist idempotente, filtres et refus, frais/rapport d’une mission existante, contrat signé avec prime exacte, rollback disque et réouverture/import/export inchangés. Les coordonnées de seed et d’horloge du profil privé restent égales après le suivi. Un test supplémentaire a reproduit la normalisation involontaire d’un profil hérité sans `skills` ; le diagnostic reçoit désormais une copie du club, et ce test passe sans mutation ni tirage.

Cette réception qualifie le domaine et son protocole. Le raccordement du manifeste et l’interface jouable relèvent du lot d’intégration ; aucun test Godot ni Windows n’est annoncé ici.
