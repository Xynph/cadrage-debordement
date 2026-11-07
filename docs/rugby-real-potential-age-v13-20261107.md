# BDD Rugby Réel — diagnostic des potentiels et maturité V13 (7 novembre 2026)

**Objet :** audit de l'échelle historique du potentiel, sans retoucher un joueur ni le modèle annuel du jeu. Référence : `main` `044e83d2a9f860d59c2aeac2a22df94235bf04c9` ; profils réels au départ fictif de carrière 2026-07-01. Les notes sont des estimations de gameplay, pas des statistiques officielles.

## Différence entre capacité et potentiel : problème de convention

Le candidat V12 d'origine signalait **520** profils `legacy-potential-scale-differs-from-role-ability`. L'analyse recoupe chaque ID candidat avec la **capacité active** de `dist/lnr-ratings-v12.js` (où les notes ont été adoucies pour la profondeur d'effectif), et avec la valeur du potentiel héritée. Sur 1 592 identifiants uniques :

| Diagnostic | Profils |
| --- | ---: |
| Alerte V12 d'origine | 520 |
| Potentiel hérité numérique inférieur à la capacité active | **393** |
| Parmi les 520 alertes | 328 |
| Sans alerte historique | **65** |
| Alertes V12 sans potentiel inférieur à l'actif | 192 |
| Potentiel égal à la capacité active | 84 |
| Potentiel supérieur à la capacité active | 1 115 |

Une capacité supérieure à un potentiel de **convention différente** n'est pas nécessairement une erreur de notes. Corriger 393 potentiels en les relevant mécaniquement rendrait artificiellement plus forte une partie de l'élite, détruirait des différences de vieillissement et pourrait affecter la sauvegarde. **Aucune correction automatique des 393 profils n'est autorisée par cette analyse.**

## Par poste

| Poste | Profils | Potentiel sous capacité | Alertes historiques |
| --- | ---: | ---: | ---: |
| Ailier | 129 | 60 | 68 |
| Arrière | 89 | 33 | 41 |
| Centre | 214 | 24 | 42 |
| Demi de mêlée | 111 | 32 | 37 |
| Demi d'ouverture | 119 | 36 | 46 |
| Deuxième ligne | 217 | 54 | 74 |
| Numéro 8 | 93 | 20 | 28 |
| Pilier droit | 126 | 31 | 47 |
| Pilier gauche | 145 | 14 | 28 |
| Talonneur | 135 | 27 | 41 |
| Troisième ligne | 214 | 62 | 68 |

Il faut traiter en priorité les situations où la capacité active est 10 à 19 points plus haute que le potentiel ancien et évaluer la projection effective vers `dev.potential` dans la carrière. Le fichier machine `data/scouting/audit-potential-v13-20261107.json` fournit une liste de **40 profils prioritaires**, triés par écart négatif, avec poste, division, note, potentiel, niveau de preuve et drapeau historique. Exemple `lnr:2450` (arrière TOP14), capacité 88, potentiel 69, différence −19 ; `lnr:2425` (troisième ligne TOP14) 89 contre 71, différence −18. Ces exemples sont des cas d'échelle à examiner, **pas** des joueurs auxquels appliquer une augmentation de potentiel automatique.

## Progression avec l'âge

Le fichier de production `dist/lnr-v11-aging.js` distingue onze postes, maturité de force plus tardive, vitesse/explosivité précoces et décisions/mental plus durables. Le nouveau test vérifie **pour les onze postes**, à conditions identiques, un joueur synthétique de 20 ans, puis une évaluation distincte à 38 ans : force non décroissante à 20 ans, vitesse en baisse à 38 ans, déclin physique plus rapide que les décisions, conservation du potentiel et idempotence sur la même saison. Les profils sont **des copies à 65 dans les 36 attributs**, potentiel 90 et professionnalisme 65 : ils isolent la courbe du modèle, sans prétendre décrire l'histoire observée d'un sportif. Ces tests n'introduisent aucun vieillissement dans le jeu.

La réception longue de la PR #383 (dix saisons, 1 820 matchs réguliers, 50 phases finales, dix réimports) est une preuve complémentaire de fonctionnement, **pas** une démonstration de vieillissement longitudinal individuel.

## Garde-fous et décision

- Intégrité et recoupement exhaustifs sur 1 592 identifiants, 36 attributs, 11 compétences ; décomptes de 393/328/65/192 et tri déterministe des 40 prioritaires, comparés au JSON versionné.
- Garder séparés les diagnostics de capacité, le potentiel hérité, l'âge et le niveau technique. Ne pas effacer l'expertise spécifique des joueurs d'une division inférieure.
- Avant tout véritable correctif métier, prouver sur une copie de carrière la projection de `potential` vers `dev.potential` et l'effet des changements sur les jeunes, vétérans, sauvegardes, valeur de recrutement et hiérarchie TOP14/PROD2.
- Aucun changement `dist/**`, master, identités, effectifs, club, calendrier, moteur, MATCH3D, UI, sauvegardes, fichiers PR #385 ni autres PR.
- **Lot livré seulement en DRAFT : diagnostics, données d'audit non appliquées et tests ; aucun changement réel des notes.**

Commande reproductible : `node --test tests/rugby-real-potential-age-v13-20261107.cjs`. La CI spécialisée sur le HEAD de PR fait autorité ; aucune CI générale en attente n'est déclarée verte.
