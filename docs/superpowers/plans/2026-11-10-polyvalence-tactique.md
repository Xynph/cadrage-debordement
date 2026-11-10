# Polyvalence et aptitude au poste — plan d’intégration

Base : d175323 (interface dense Cloud déjà reçue, capture Tactique existante). Cible : 2560×1440, saison simulée 2026–2027. Léo demande un vrai mécanisme de jeu : poste principal, autres postes en numéros, aucun marqueur d’estimation dans l’interface, forte baisse d’efficacité d’un pilier placé en 10. La note de poste est exclue de l’Effectif et contextualisée dans la Tactique existante. Les notes permanentes ne sont pas réécrites par une affectation.

## Contrat commun

Projection par joueur : `primaryPosition` (numéro 1–15), `secondaryPositions` (numéros maîtrisés, ordonnés), `positionRatings` (map des numéros vers aptitude). Les données sont dérivées déterministement des qualités, sans nouveau tirage RNG ni champ redondant persisté. Les postes 1, 2 et 3 gardent les qualifications existantes : une bonne note ne vaut jamais qualification de première ligne. Hors première ligne, un dépannage peut être permis même en dehors des postes secondaires maîtrisés, avec rendement fortement réduit.

Une fonction canonique doit servir les projections, la composition, le banc, les remplacements et les calculs effectifs du match au numéro occupé. Les identifiants, position/famille sources, profils et marqueurs de sauvegarde restent stables. La condition physique est un modificateur du rendement, pas de la maîtrise permanente d’un poste.

## Tâches indépendantes

1. Moteur/modèle : factory `native/engine/position-aptitudes.cjs`, branchements uniques après les hooks de compétition ; vérifier qualifications, famille du slot actif, cohortes internationales et sauvegardes. Réception pilier→10, centre→aile, deuxième ligne→8, banc/remplacement et état/RNG/export-reprise.
2. Effectif : `squad_canvas.gd`, Poste principal + Autres numérotés avec infobulle ; tri dans les deux sens, inconnus derniers, lecture seule, défilement interne. Utiliser le modèle sans formule UI.
3. Tactique : conserver les trois colonnes et le terrain. Ajouter une vue Effectif compacte dans la carte du banc ; drag/drop entre joueurs et maillots, alternative clic/clavier ; note liée au maillot choisi. Utiliser les commandes de composition validées par le moteur, sans affectation lors d’un abandon ou d’un dépôt refusé.
4. Intégrateur : revoir la cohérence des trois branches, recevoir sur vraie carrière, vérifier les sources de notes en match et en sélection, capturer les vues réelles, publier une PR empilée sur le lot d’interface #520. Aucune fusion de main dans cette phase.

## Vérifications d’intégration

- Le niveau permanent du joueur ne bouge pas quand on l’affecte à un autre poste.
- Un spécialiste au bon poste garde son rendement de référence ; un pilier au 10 subit une forte baisse réellement utilisée par le match.
- Poste secondaire maîtrisé et dépannage restent distincts dans le modèle ; seuls les postes maîtrisés sont listés dans Autres.
- Un joueur non qualifié ne devient pas première ligne grâce aux seuls attributs.
- Candidats, glisser-déposer, clavier, banc, remplacements et sélection internationale donnent le même verdict d’éligibilité.
- Un refus ne perd ni ne duplique les joueurs. Les échanges valident les deux affectations avant écriture.
- Pas de migration silencieuse, de mutation à la lecture, ni de dérive RNG ; import/export et reprise cohérents.
- Captures natives 1440p avec profils temporaires hors application et caches Godot distincts par branche.
