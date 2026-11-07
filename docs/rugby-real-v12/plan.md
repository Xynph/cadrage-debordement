# V12 — Revue exhaustive des notes Rugby Réel

Demande : revoir les notes des 1592 joueurs. Base 512e296467985d95284e1c3c3959b23e569019d2. PRODUCTEUR, aucun changement master/dist/saves/effectifs/IDs/calendrier, aucune fusion.

1. Reprendre la collecte centrale V11 au SHA b099230c66641f9af06f40101fb67162db40b4b9 ; ajouter taux de transformations avec tentatives publiques et distinctions 2025-26 officielles, en distinguant période sportive et date de connaissance. Aucun total de saison et de mi-saison additionné.
2. Revoir les 57 312 attributs : références explicites sur 11 postes, résidus individuels hérités pondérés, contraintes de cohérence, physique uniquement guidé par âge/mensurations disponibles, indications statistiques limitées à leurs domaines. Aucun hasard/hash/nom/réputation utilisé pour créer des notes.
3. Ne pas doubler les effets d'âge de V3 : résidualiser les anciens profils avec l'âge et les mensurations, puis appliquer une seule référence de maturité. Les courbes futures de V11 ne sont pas ajoutées au lancement.
4. Recalculer les 11 compétences projetées et une capacité au poste, dérivées des 36 notes. La note générale historique et le potentiel n'ont pas la même échelle ; les conserver et expliciter la comparaison. Potentiel et six traits intacts.
5. Livrer un candidat complet par ID, CSV avant/après, contrôles des extrêmes et distributions, leaders par poste, champs conservés/corrigés et limites de preuve. Sans données, une estimation reste une estimation ; ne pas prétendre avoir observé 1592 joueurs.
6. Tester intégrité, déterminisme, absence de biais nom/ordre, petites expositions, spécialistes, blessures/absence inconnues, PRO D2 stars, préservation potentiel/traits et bornes. Confronter au vrai moteur avec les mêmes équipes/graines/IDs de recrues.
7. Publier une PR DRAFT indépendante avec CI GitHub et passation #73. Le candidat remplace la proposition V11 sur les notes, ne s'y additionne pas. V11 reste utile pour les courbes futures et l'audit moteur.
