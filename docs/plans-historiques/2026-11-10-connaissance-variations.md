# Connaissance des joueurs et variation des carrières

Base : lot polyvalence b3d8757, PR529, reçu sur vraies carrières. Demande et calibration approuvées par Léo le10 novembre2026. Cible2560×1440, interface dense ; pas d’étiquette « estimé » ni de nouveau chiffre précis caché dans un autre menu.

## Règles de visibilité

- Club entraîné : niveau actuel exact ; potentiel sur5 valeurs possibles (max−min=4).
- Autre club, avant observation : niveau et potentiel inconnus.
- Première observation : niveau sur9 valeurs possibles ; potentiel sur11.
- Observation approfondie : niveau et potentiel sur5 valeurs possibles.
- Le niveau extérieur reste une fourchette jusqu’au recrutement ; le potentiel reste toujours une fourchette.
- Fourchettes asymétriques, gelées entre événements, approfondissement contenu dans l’ancien intervalle quand les qualités n’ont pas changé ; jamais un simple affichage vrai±constante permettant de retrouver la valeur par moyenne.
- Consultation, découverte et shortlist ne constituent pas une observation. Mission réelle terminée ou rencontre réellement suivie avec participation effective : première observation. Deux événements distincts : approfondie. Les matchs AI mondiaux non suivis ne donnent aucune connaissance gratuite.

## Moteur de connaissance

Module canonique player-knowledge.cjs : manifeste optionnel versionné strict, tuples compacts bornés, conservation des connaissances acquises, validation avant import, aucun effet RNG ni mutation pendant une lecture. Le niveau source est rating et le potentiel global source dev.potential. Les nombres exacts restent internes à la simulation/sauvegarde restaurable ; la projection finale masque les données après tous les enrichissements, y compris rapports et extras de commandes.

API UI : knowledge.owned/stage, rating exact seulement pour owned ; ratingRange et potentialRange objets {min,max} ; potential numérique retiré pour tous. Qualités et positionRatings extérieurs non divulgués avant les observations appropriées. Les exports fichiers restent intégraux, sans aperçu JSON brut dans les vues de jeu.

Commande d’observation ciblée par ID, y compris joueur sous contrat : frais standard5 000€, file partagée de4 missions, deux cycles hebdomadaires de travail ; pas de promesse de deux jours calendaires. Confirmation et contexte club/saison/date, aucun débit en double. Le niveau de recruteur ne doit modifier le délai que si cette propriété existe réellement dans le jeu.

## Variation de nouvelle carrière

Module career-variation.cjs : delta global déterministe par graine+identifiant, concentré sur faibles écarts ; niveau actuel±3, potentiel±5. Un même delta potentiel cohérent pour les deux références de potentiel dans leurs bornes respectives. Le potentiel varie toujours ; seul le niveau possède une case, cochée par défaut à la création.

S.careerVariation={version:1,seed:uint32,varyCurrent:bool}. Tirage uniquement à la création après calibrations et création des pools, avant sauvegarde finale. Qualités réellement modifiées, notes, baselines et projections cohérentes. Identifiants, postes et profils conservés. Même graine/mêmejoueur → même variation quel que soit le club choisi. Chargement/reprise/export ne rejouent rien. Ancienne carrière sans manifeste inchangée. Validations de référence connaissent le delta canonique et refusent des métadonnées falsifiées.

## Répartition et réception

- Sauvegardes : politique de connaissance, événements, manifeste, observation ciblée, masquage final et tests stricts.
- Internationaux : variation, génération/validation/sauvegarde et case de création.
- Bureau : helpers d’affichage stricts,22 vues, fourchettes, tris/filtres à partir des bornes visibles, bouton Observer et export sans aperçu brut.
- Root : résolution des accroches worker/validateurs, revue indépendante, réception native et graphique cumulative, captures réelles et PR empilée. Aucune fusion main dans cette phase.

Tester avant livraison : anciennes sauvegardes, graine fixe/deux graines/case off, bornes/attributs, premières observations et approfondissement, gel/recrutement/départ, plafond de connaissances sans blocage de match, budget/file/annulation/requête périmée, absence de fuite structurée ou dans les infobulles, tri et défilement, sauvegarde/reprise/état/RNG et captures1440.
