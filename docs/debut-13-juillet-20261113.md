# Début de carrière Monde : lundi 13 juillet 2026

Décision de Léo (13/11/2026) : une carrière Monde commence avec la **reprise des premiers clubs,
le lundi 13 juillet 2026**, et non plus le lundi 17 août 2026.

## Ce qui change

- `new_career` (mode `world-champ`, rôle club) crée `S.preseason = {version:1, today:'2026-07-13'}`
  (module `native/engine/avant-saison.cjs`, domaine `preseason`).
- Pendant l'avant-saison, `meta.calendarToday` vaut la date de l'avant-saison,
  `meta.calendarCadence` = `{matchReady:false, canAdvance:true, preseason:true}`,
  `meta.preseason` = `{today, opening}` et `meta.roundLabel` = « Avant-saison ».
- `advance_day` avance d'un jour ; `preseason_advance` (`until` : `semaine` ou `saison`) avance
  d'une semaine ou jusqu'à l'ouverture. Dans Godot, le bouton principal devient « Semaine suivante »
  pendant l'avant-saison (rien ne s'y joue encore).
- À l'ouverture (17 août 2026), `S.preseason` disparaît : le calendrier jour par jour du moteur
  reprend exactement comme avant.

## Pourquoi les calendriers ne sont pas décalés

Les semaines du moteur (`S.round`, `fixture.week`), les rencontres et leurs dates réelles ne
bougent pas : l'avant-saison est **devant** la semaine 0. Rien ne s'y simule (aucun tirage, aucune
écriture hors de `S.preseason`). Toute commande qui fait avancer le calendrier du moteur
(`finish_round`, `begin_match`, `train`, `next_season`, préparations sans match) ouvre d'abord
la semaine 0 : un outil ou un test qui enchaîne `new_career` puis `finish_round` obtient
exactement les mêmes séquences qu'avant (vérifié par `tests/world-debut-13-juillet.cjs`, état
complet identique). **Aucune séquence figée n'est donc régénérée** ; seule la date affichée à la
création change (13/07 au lieu de 17/08).

Les rôles de sélection (« Club et sélection », « Sélection seule ») gardent leur agenda
international existant, qui part de l'ouverture du calendrier.

## 1re journée de l'Élite 2026-2027

Calendrier LNR du dépôt (`native/engine/lnr-calendar-2026-27.json`, PDF officiel Top 14
2026-2027) : **samedi 5 septembre 2026** (J1, ex. rencontre 11819), comme dans le moteur.
Les 27-28 août correspondent à la 1re journée de l'Accession (Pro D2) dans ce fichier ;
le moteur Monde génère pour l'Accession un calendrier qui commence le 5 septembre (écart connu,
hors de ce changement).
