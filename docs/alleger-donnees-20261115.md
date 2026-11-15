# Poids des données d'une carrière Monde (15/11/2026)

Suite de [la fluidité des commandes](fluidite-commandes-20261114.md). Carrière `world-champ`, club 102, graine 827381,
avance rapide du harnais (`tests/monde-harness.cjs`), Node 22, `--max-old-space-size=2000`. Machine de 8 Go partagée
avec d'autres simulations (charge 4 à 5) : les durées absolues sont pessimistes et bruitées ; les tailles sont exactes.

Outil : `node --max-old-space-size=2000 scripts/mesure-poids-donnees.cjs [saisons] [sortie.json]`
(`CD_MESURE_CHECKPOINT=préfixe` garde l'état à chaque fin de saison, `CD_MESURE_REPRISE=fichier` repart d'un état gardé).

## 1. Mesure : ce qui grossit

| Moment | Sauvegarde (texte de S) | Modèle de l'interface | Agents libres (`economy.freeAgents`) | Même liste dans `S.market` | `dev` des joueurs pros | Académies IA (`aiRoster`) |
|---|---:|---:|---:|---:|---:|---:|
| Création | 19,4 Mo | 12,6 Mo | 27 joueurs | 0,02 Mo | 0,79 Mo | 3,85 Mo |
| Fin de saison 1 | 24,5 Mo | 12,6 Mo | — | — | 1,49 Mo | 4,36 Mo |
| Saison 2, semaine 4 | 26,6 Mo | 15,0 Mo | 858 joueurs, 1,41 Mo | 1,41 Mo | 1,83 Mo | 5,09 Mo |
| Fin de saison 2 | 28,1 Mo | 16,9 Mo | 1,38 Mo | 1,38 Mo | 1,81 Mo | 5,17 Mo |
| Saison 3, semaine 4 | 30,2 Mo | 16,3 Mo | 1 714 joueurs, 3,05 Mo | 3,05 Mo | 2,16 Mo | 5,40 Mo |

Croissance : **+3,6 Mo de sauvegarde par saison**, dont :

- **Vivier des agents libres sans fin** (≈ +850 joueurs par intersaison, aucun ne sort du vivier) : +1,6 Mo par saison,
  **écrit deux fois** (`S.market` est, joueur pour joueur, identique à `S.economy.freeAgents` : 1 714 sur 1 714 à
  la saison 3). C'est la seule croissance réellement sans borne ; elle coûte aussi au modèle (liste `market` 0,02 →
  1,7 Mo, repérage des régénérés 0,6 → 1,05 Mo) et au temps de projection (demande salariale de chaque agent libre :
  `regenScouting` 26 → 231 ms, `managerCareer` 5 → 171 ms par réponse à la saison 3).
- **Historique de progression par joueur** (`dev.history`, ~75 octets par joueur et par saison) : +0,35 Mo par saison,
  borné par la durée de carrière (retraites), affiché sur la fiche joueur.
- **Académies IA** : +0,3 à 0,5 Mo par saison (7 475 jeunes à la saison 2).
- Archives annuelles (notes de match passées, `history` vidé à chaque saison, presse, staff) : < 0,1 Mo par saison.

Modèle de l'interface : le marché entre clubs (4 à 5 Mo), la carrière du staff et les équipes du staff (2,5 Mo chacune) et
le carnet (1,5 Mo) font l'essentiel ; ils dépendent du nombre de joueurs du monde, pas du nombre de saisons.

Temps (harnais, machine chargée, sans mémoire) : `next_season` 8,6 s (saison 1 → 2) puis 9,6 s (2 → 3) ; une décision
(`auto_lineup`) 3,2 s puis 3,9 s.

Constat important : **le transfert vers Godot est déjà différentiel** (`model-delta.cjs`) : une décision envoie quelques
Ko, pas 13 Mo. Le coût est dans le moteur : reconstruction du modèle (~0,7 à 1,5 s) et parcours de connaissance
(~0,3 à 1 s) à chaque réponse, alors que les gros domaines ne changent pas.

## 2. Correction livrée : mémoire des projections par domaine (moteur)

- `nativeSystems.projectText(sections)` (`native/engine/native-systems.cjs`) : chaque domaine lourd sans état transitoire
  (marché entre clubs, carrière du manager, repérage, soutien du club, carrière et emploi du staff, tutorat, carnet,
  développement des jeunes, monde du club, analyse de performance) mémorise son texte projeté et les **sections de premier
  niveau de S qu'il a lues** (relevées par un mandataire posé sur `S` le temps du calcul ; une énumération des clés de S
  le rend dépendant de tout). Si ces sections ont exactement le même texte, le domaine reprend son texte précédent.
- Le texte des sections est celui de la sauvegarde : déjà calculé pour un jour (avant la projection), calculé par la
  projection pour une décision différée et **réutilisé par l'écriture différée** (`nativeSaveCurrent`) au lieu d'être
  recalculé. Il n'est réputé à jour que tant qu'aucune commande susceptible de modifier la carrière n'a commencé ;
  une carrière remplacée (annulation, import) n'est jamais reprise (identité de `S`).
- Connaissance (`projectKnowledge`, `native/engine/worker.cjs`) : la version vue par le joueur des gros domaines
  (portraits, fourchettes) est reprise quand leur texte projeté, la frontière de connaissance et le mode sont ceux de la
  réponse précédente ; ils sont mis de côté pendant le parcours du reste du modèle puis remis à leur place.
- Coupures : `CD_MEMO_DOMAINES=0` (ou `memoDomains:false`) rétablit l'ancien calcul ; `CD_VERIFIER_MEMO=1` (ou
  `verifyMemo:true`) recalcule chaque domaine repris et exige le même texte (projection et connaissance).

### Avant / après

| | Sans mémoire | Avec mémoire | Source |
|---|---:|---:|---|
| Calculs du marché entre clubs sur 17 réponses (création, décisions, 3 jours) | 17 | 1 | `tests/memo-projection-monde.cjs` |
| Décision (`auto_lineup`, saison 3, profil 30 Mo) : CPU de la réponse | 1,58 s | 1,43 s | 6 mesures de chaque, machine chargée |
| — temps de réponse (mur) | 3,5 s | 2,9 s | idem, bruité |
| — parcours de connaissance (mur) | ~1,0 s | ~0,5 s | idem |
| — écriture différée après la réponse (CPU) | 1,43 s | 1,08 s | idem |
| Jour (préparation de saison, carrière neuve) | 1,5 à 2,8 s | 1,3 à 1,9 s | test, 3 jours, bruité |
| Taille du modèle / de la sauvegarde | inchangées | inchangées | aucune donnée retirée |
| `next_season` | non mesuré avec mémoire | | tout change à l'intersaison : gain attendu nul |

Gain modeste mais sans risque d'affichage : le texte des sections (~170 à 380 ms pour 25 à 30 Mo) est désormais payé avant
la réponse d'une décision et économisé ensuite ; le temps de réponse gagne surtout sur les domaines et la connaissance.

## 3. Garanties

- **Modèles identiques octet pour octet** avec et sans mémoire, et profil écrit identique, sur la même graine
  (`tests/memo-projection-monde.cjs` : création, lectures, consignes, composition, fiche club, trois jours) ; chaque
  reprise y est aussi recalculée et comparée (`verifyMemo`), et le texte des sections relu y est contrôlé contre `S`
  (`verifyCleanCopy`).
- Aucune donnée de sauvegarde ni de modèle n'est retirée : rien à vérifier côté écrans au-delà de l'égalité des modèles ;
  anciennes sauvegardes inchangées (format identique).
- `tests/vitesse-commandes-monde.cjs` (écriture différée, coupure, échec, regroupement, worker stdio) et
  `tests/native-projection-cache.cjs` passent.
- Seuils larges de non-régression : modèle < 24 Mo, profil < 40 Mo, décision < 15 s, jour < 40 s.

## 4. Non fait (passation) : compacter la sauvegarde

Proposition, dans cet ordre :

1. **Écrire le vivier des agents libres une seule fois** : dans le texte du profil, remplacer `S.market` par une référence
   aux entrées identiques de `S.economy.freeAgents` (comme le fait déjà l'export réduit) et la redéplier en objets
   distincts au chargement. Gain : −1,4 Mo par saison écoulée. Difficulté : plusieurs invariants supposent aujourd'hui que
   `store['bdt-v1'] === JSON.stringify(S)` (sections de validation, copie d'annulation, encodage par sections) ; il faut
   que le texte compact ne serve qu'au fichier, et une ancienne version du jeu ne relira pas un profil compact.
2. **Décision de jeu à prendre par Léo** : borner le vivier des agents libres (retraite des agents libres de plus de N ans
   ou sans club depuis 2 saisons). C'est la seule croissance sans fin ; elle change les résultats (recrutements possibles),
   donc hors du périmètre « résultat strictement identique » de ce chantier.
3. `dev.history` au-delà de N saisons résumé (début, fin, minutes cumulées) : à faire seulement si la fiche joueur
   n'affiche pas le détail ancien.
4. Mémoriser aussi `nativeModel()` (liste `market` et demandes salariales des agents libres) et les équipes du staff
   (`staff.project`, Node), puis ne parcourir dans la validation stricte que les sections modifiées.
