# V11 — Montée difficile, recrutement utile, vieillissement crédible

**Propositions hors production.** Base main `3014774ab4ca13d1d325756ed89f2bb029b1b99c`. PR producteur DRAFT, aucun master ni fichier `dist/**` modifié. Aucun changement jouable n'est activé par la fusion des seuls outils de ce lot.

## Constat essentiel

Le mode LNR de `main` utilise `lnrGamePlayers()` et `ensureSkills()` : il génère ses 11 compétences natives et ne lit pas les 36 attributs du master. Les 16 clubs PRO D2 sont consultables, les montées/descentes seniors ne sont pas implémentées (`world-career.js` le précise). Les résultats des expériences ci-dessous sont donc des confrontations contrôlées dans le **vrai moteur**, pas des probabilités de maintien sur une saison à deux divisions.

## Ce qui est livré

- Un barème unique recalculé depuis le master V3/V4/V5 immuable : 1 592 joueurs, 805 TOP14, 787 PRO D2, 11 familles, 36 attributs et six traits conservés. Ni potentiel, identité, effectif ni championnat de départ réécrit. Les propositions V6/V8/V9/V10 ne sont jamais additionnées.
- Cible exploratoire de sept points sur les cinq spécialités de chaque famille, ajustement borné à +5 et 97, modulé par le profil individuel. 3 860 ajustements candidats. Aucun abaissement PRO D2, aucune prime de réputation. Les joueurs de PRO D2 restent capables de dépasser des TOP14 à poste identique. Ce rattrapage de cohorte est une hypothèse d'équilibrage, pas une performance observée.
- Une projection explicite 36→11 compétences, sensible aux facettes techniques, mentales, physiques et spécialités. Touche adaptée au rôle talonneur/deuxième ligne ; les 36 facettes participent. Rating et skillBase restent identiques afin d'éviter un deuxième bonus général. Les traits cachés et le potentiel sont conservés mais ne sont pas soudainement branchés dans le match.
- Des matchs via `createRugbyMatch → advanceRugby → applyMatchInjuries`, avec test d'identité des sorties de `rugbySimulate`. Pas de moteur de résultats parallèle. IA classique des deux côtés, même moral, condition fraîche, 64 graines et les deux domiciles. Reset des deux effectifs entre chaque rencontre.
- Comparaison séparée des 11 notes héritées du master (hors jeu actuel), projection baseline, notes consolidées seules, puis notes consolidées avec réponse au niveau multipliée par deux. Cette dernière est une proposition en mémoire sur l'unique coefficient `(attack-defence)` de `tacticalEdge`, aucun fichier natif écrit. La météo, les choix tactiques, les fautes, blessures et remplacements restent natifs.
- Collecte centrale de **809 lignes** : 800 lignes officielles de classements saison 2025-26 (100 par page publique, huit pages), six lignes de carrière de joueurs peu documentés, trois observations de mi-saison. **426 joueurs rapprochés**, dont **304 supplémentaires** par rapport à V8/V9, **204 avants**, **59 joueurs de 23 ans ou moins**. Les 60 fiches carrière tentées n'ont fourni que six lignes utilisables ; absence = inconnu. Pas de contournement d'inscription ItsRugby ni de données 2026-27 injectées dans l'historique.
- Courbes d'âge candidates sur copies, avec progression dépendant de l'exposition et du potentiel, puis déclin surtout physique. Vitesse/explosivité, force/endurance, technique et lecture du jeu ont des trajectoires distinctes par famille. Recherche et limites : [age-research.md](age-research.md).
- Reproduction d'un défaut natif de sauvegarde LNR à la saison 2 (historique à 15 ans refusé). Une correction strictement limitée au cas LNR est préparée et testée en mémoire ; trois saisons et trois imports natifs sont validés avec cette proposition isolée. Voir `save-proposal.json` et `seasons.json`. **Le défaut reste présent dans main.**

## Méthode et limites à lire avec les chiffres

Les étiquettes « champion PRO D2 » et « relégué » désignent respectivement le meilleur groupe PRO D2 et le groupe TOP14 le plus faible **selon la projection initiale du modèle**, pas les vainqueurs ou relégués historiques. Les mêmes clubs et les mêmes IDs de recrues/départs sont figés pour toutes les versions ; ils ne sont pas reclassés après calibration. Le recrutement privilégie les gains de couverture au poste, dans les trois premiers quartiles TOP14, et ne sélectionne pas cinq superstars. Les nouveaux joueurs complètent le banc plutôt que de supprimer leurs prédécesseurs. Salaires neutralisés pour l'expérience : aucune offre réellement acceptée, indemnité ou faisabilité budgétaire n'est revendiquée.

Les intervalles sont calculés par groupes de graines (domicile/extérieur corrélés). Les seuils sont des **cibles de game design exploratoires**, pas des fréquences historiques. Les tactiques IA peuvent changer après recrutement : c'est un effet réel du management dans le moteur, pas une preuve que chaque recrutement fera monter le taux de victoire sur 128 matchs. Les graines ont servi à l'exploration ; il ne s'agit pas d'une validation indépendante sur des adversaires inconnus. La proposition ×3 est rejetée comme trop sévère dans le scénario faible, et reste documentée comme exploration locale.

Les classements LNR et les lignes carrière ont des périmètres différents pouvant inclure des phases finales différentes. Aucune addition de leurs totaux ; les observations après 13 journées gardent leur date. Le volume de plaquages sans tentatives ne donne pas un taux de réussite. Les données nouvelles sont donc de l'information d'évaluation, pas des +1 mécaniques de technique, de défense ou d'endurance. Les postes restent largement estimés dans le master.

## Reproduire

```bash
node --test tests/rugby-real-native-v11.cjs
node tools/rugby-real-v11/export.cjs /tmp/v11-export
node tools/rugby-real-v11/campaign.cjs /tmp/v11-matches.json 64
node tools/rugby-real-v11/age-impact.cjs /tmp/v11-age.json 64
node tools/rugby-real-v11/seasons.cjs /tmp/v11-seasons.json
```

La CI dédiée exécute les quatre versions sur la vraie base et archive les matchs avec leurs graines, scores, essais, discipline, fatigue, blessures, mètres et feuilles initiales. Les sorties compactes conservées dans ce répertoire sont des mesures locales ; les artefacts de la CI prouvent l'exécution distante sur son HEAD exact. La collecte réseau est volontairement exclue des tests déterministes : `collect.py` et `collect-career.py` permettent un renouvellement explicite des données publiques.

## Passation à l'intégrateur

1. Examiner les mesures et les cibles manquées dans `measures.json` / `results.md`, pas seulement les moyennes d'attributs. Ne pas appliquer V10 en plus de V11.
2. Réserver le raccordement du master et de la projection pour les nouvelles carrières. Le mode LNR actuel n'importe ni ces attributs ni la PRO D2 jouable. La migration d'une carrière existante doit être une décision séparée, avec préservation de son ancien modèle.
3. Réserver `dist/tactical-plans.js` si la sensibilité ×2 est retenue. Conserver la version des matchs déjà sauvegardés et élargir les tests aux déséquilibres extrêmes avant activation. Aucun bonus automatique de division/promotion/relégation.
4. Réserver `dist/development.js` pour **remplacer** le vieillissement hérité plutôt que cumuler les progressions. Conserver le potentiel et les six traits, brancher entraînement/temps de jeu natifs, retraite et sauvegardes versionnées.
5. Réserver `dist/saves.js` pour la proposition d'âge LNR, avec les tests négatifs âge14/fictif15. La correction n'est pas livrée dans la production de cette PR.
6. Le véritable système senior TOP14/PROD2 de promotion-relégation reste à raccorder. Ne pas présenter les confrontations contrôlées ni les saisons à 14 comme un test naturel de maintien/remontée.

Aucun `/cd-check`, `/cd-merge`, READY, merge ou bypass n'a sa place dans ce cycle producteur.
