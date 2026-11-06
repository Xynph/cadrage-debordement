# Rugby Réel — attributs individuels, lot DATA V1 (laboratoire non jouable)

## Décision produit
La base existante de **1 592 joueurs / 30 clubs, saison de départ 2026-2027**, est considérée cohérente par le propriétaire. Aucun ID, nom, club, effectif, calendrier ou contrat n'est corrigé par ce chantier.

L'objectif est d'améliorer les notes des joueurs sans inventer de statistiques et sans créer une seconde source de vérité. Le seul point d'entrée est `tools/lnr-ratings-v1.cjs`; sa sortie est **candidate**, non raccordée au gameplay.

## Référence du moteur
Les clés `scrum`, `lineout`, `tackle`, `speed`, `pass`, `kick`, `goal`, `mental`, `discipline`, `stamina`, `power` sont celles de `dist/rugby.js`. Les pondérations varient selon le groupe de poste et reflètent les besoins d'une feuille de match. Les groupes larges de la LNR sont conservés, **pas de poste précis inventé**.

## Méthodologie en deux niveaux

1. **Prior faible, sans statistique individuelle :** points de référence TOP 14 74 / PRO D2 68, ajustement de maturité très limité seulement lorsqu'un millésime exploitable est déjà disponible, profil d'attributs selon la famille sportive. Il s'agit d'une *hypothèse de gameplay* non d'une note observée. Deux joueurs de même groupe, ligue et âge obtiennent la même note candidate : **aucun hash des noms/IDs n'est utilisé pour créer une hiérarchie imaginaire**.
2. **Statistiques datées et vérifiables :** des métriques 2025-2026 peuvent ajuster des qualités nommément liées, après au moins 240 minutes ; au maximum ±7 par attribut, avec URL, saison, date limite d'observation et traces. La méthode utilise encore des centres génériques et non des distributions vérifiées par poste : statut *provisoire*, jamais *homologué*.
3. **Pas de fuite temporelle :** les performances de 2026-2027, ou une date d'observation postérieure au 01/07/2026, sont rejetées ; les dates de naissance connues seulement par année produisent une estimation conservatrice ; l'âge reporté en octobre n'est pas réinterprété comme un fait de juillet.
4. **Pas de biais ethnique ou de morphologie simpliste :** nationalité, taille et masse ne servent pas à inférer vitesse, puissance, compétence ou prestige.

## Rugby 25
Rugby 25 reste un **repère éditorial de calibration** possible si les notes sont légalement consultables et leur méthode connue. Aucun tableau de notes protégé, aucun asset du jeu, aucune statistique non attribuée n'est copié. Une évaluation propre au jeu et indépendante des notes de l'éditeur est préférable.

## Commandes
```sh
node tools/lnr-ratings-v1.cjs
node --test tests/lnr-ratings-v1.cjs
```
Le premier exécute un **audit agrégé** sur les 1 592 fiches ; il n'enregistre aucun remplacement de rating. `build(players, evidenceById)` génère un objet JSON en mémoire ; toute intégration ultérieure nécessite **un nouveau lot**, des données sportives individuelles accessibles/licenciées et des campagnes de simulation.

## Critères de passage à V2
- Identifier des sources publiques, utilisables et reproductibles de statistiques individuelles clôturées avant juillet 2026 : minutes, plaquages, jeu au pied, buts, conquête, discipline, mètres/franchissements.
- Tester les distributions **par poste et championnat** avant tout ajustement. Ne pas interpréter la diversité des métadonnées comme une mesure de talent.
- Échantillon de revue manuelle stratifié : meilleurs joueurs, jeunes, titulaires de rotation, avants/arrières, TOP 14/PRO D2. Corriger les biais de championnat et les spécialistes (buteurs, talonneurs, piliers).
- Valider cohérence de `roleNote`, influence sur matchs, recrutements, carrières longues, sauvegardes ; tests sur vrai moteur et revue sportive.
- Un résultat `confidence=medium-provisional` **n'autorise pas** l'intégration, et `readyForGame` vaut toujours `false` en V1.

## Périmètre préservé
Aucune mutation de `dist/**`, `modding/data06/**`, `AGENTS.md`, `DEVELOPPEMENT.md`, des sauvegardes, calendriers, MATCH 3D, R&D/économie V2 ou de l'UI. La refonte graphique appartient à l'autre développeur. Branche indépendante ; pas de fusion producteur.
