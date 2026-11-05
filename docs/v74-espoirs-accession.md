# V74 — Reichel Espoirs Accession simulé 2026–2027

## Format vérifié et données

Références FFR :
- Présentation des compétitions et formats FFR 2026–2027 : https://www.ffr.fr/actualites/competitions-federales-tout-savoir-sur-la-saison-2026-2027
- Calendrier FFR des Espoirs : https://api.www.ffr.fr/wp-content/uploads/2026/05/presentation-calendriers-saison-2026-2027.pdf
- Référentiel Reichel Accession FFR (format et phase finale) : https://api.www.ffr.fr/wp-content/uploads/2025/07/2025-2026_presentation-des-competitions-federales-vf.pdf
- Contrôle des clubs et des deux poules 2026–2027 : https://www.rugbyamateur.fr/jeunes/reichel-espoirs-accession/calendrier-resultats

**20 centres** en **2 poules de 10** (poule 1 : Périgueux, Marcq-en-Barœul, Rennes, Suresnes, Massy, Soyaux-Angoulême, Mont-de-Marsan, Dax, Orléans, Montauban ; poule 2 : Bourgoin-Jallieu, Provence Rugby, Albi, Nice, Chambéry, Bourg-en-Bresse, Carcassonne, Narbonne, Béziers, Vienne). Les clubs sont des libellés publics optionnels en mode Rugby Réel, pas des licences de marques. Les jeunes, forces sportives, résultats, montées et calendriers *de matchs* sont entièrement **simulés** ; aucun effectif FFR officiel n'est revendiqué. Les noms fictifs s'appliquent au mode fictif.

Le championnat comprend 18 journées aller-retour, 180 matchs de phase régulière. Les quatre premiers de chacune des deux poules se qualifient : quarts (4 matchs), demi-finales (2), finale (1). **Deux finalistes sont éligibles à l'accession sportive**. La promotion/relegation effective avec les 24 identifiants/centres du module Élite V73 n'est **pas encore appliquée** : le lot suivant devra développer un transfert interdivisions compatible avec les listes FFR et les sauvegardes, sans créer de doublon.

## Fonctionnalités jouables

- Championnat indépendant V74 lancé en nouvelle carrière, et dans une ancienne sauvegarde à la prochaine journée.
- 20 centres et **22 joueurs fictifs par centre** (15 postes + 7 réservistes), sélection automatique d'un XV, rotation par poste et fatigue/récupération.
- Choix du **centre suivi** et du **plan** (équilibre, performance, formation accélérée, récupération) depuis Formation > Suivi et commandes. Le plan agit sur les sélections à chaque journée ; le centre suivi peut être changé. Aucune mutation dans l'interface consultative.
- Progression bornée par potentiel et minutes, classement bonus et différence de points, phase finale, champions, archive quatre saisons.
- Nouveau champ facultatif `v74Accession` dans la sauvegarde. Aucune modification de la structure de V73 ni de son championnat senior. Import/export et parties sans champ V74 testés.
- Rythme saisonnier abstrait aligné sur 26 tours seniors. Les matchs exacts et leurs dates ne reproduisent pas le calendrier officiel.

## Réception

Exécuter `node tests/v74-espoirs-accession.cjs` puis `node tests/v73-espoirs-league.cjs`, les 7 jobs JavaScript et les contrôles Chromium requis sur le HEAD PR exact. Vérifier simulation de 4 saisons, migration d'une ancienne sauvegarde, lecture seule de la Formation, coexistence V73, 20 centres / 180+7 matchs, absence de doublons. **Aucune fusion autorisée dans le rôle producteur**. L'absence d'exécution locale (clone GitHub inaccessible) n'est pas un succès de test.
