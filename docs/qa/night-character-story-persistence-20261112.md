# Histoire d’un personnage : mémoire et échéances publiques

Scénarios uniquement, base `9563792e28cbb0dd134b6b78e24ab4c88ce08d51`.
Exécution Node `v22.23.4`, source du runner
`fe0bc57874f729c2a6e62630bcbf913f627231c6` ; rejeu transactionnel source
`21f02bec` (SHA complet dans le manifeste). Aucun produit, moteur, coefficient,
calendrier, économie ou état sportif n’a été modifié. Aucun Godot/import exécuté.

## Même point de départ, deux choix défendables

Carrière publique fiction, club 13, seed initiale 427, horloge 1794434400000.
Maxime Durand, `p13-21-1794434400000`, troisième ligne, trait « Exigeant »,
est concerné par l’événement public :

> Une echeance contractuelle pese sur le groupe
>
> Son contrat arrive a echeance cette saison.

La préparation commune utilise seulement les commandes normales : conversation
`clarifier`, duo avec un pilier titulaire existant, promesse de rotation de
80 minutes sur trois matchs. Ces décisions ne prélèvent ni trésorerie ni salaire ;
la conversation passe la confiance 72 → 73, le duo fait passer la condition
99 → 97 et son lien de 0 → 18. La promesse ne donne aucun gain immédiat de
satisfaction. Les répétitions dans la même semaine sont refusées sans mutation.

Le checkpoint copie le **dossier de profil complet**, pas seulement un export :

- SHA-256 profil `fb5846456c48c15d1b168e371a7012d4424fa01a3563d20d63dcb0cdee67abc7` ;
- RNG `3668155195`, horloge `1794434400000` ;
- satisfaction 65, leadership courant 79, zéro minute jouée.

Les deux branches utilisent la même sélection qualifiée à ses postes principaux,
le même partenaire et la même politique de suivi : rassurer à la semaine suivante
et écouter l’autre événement hebdomadaire disponible. Les gardes presse et médicales
sont traitées par les APIs publiques. Aucun recrutement, édition de blessure ou
promotion n’a été nécessaire.

| Observation | Écouter sans nouvelle obligation | Responsabiliser avec engagement de rôle |
|---|---:|---:|
| Satisfaction immédiatement après choix | 69 (+4) | 67 (+2) |
| Moral immédiatement après choix | 78 (+1) | 79 (+2) |
| Coût direct du choix / salaire supplémentaire | 0 / 0 | 0 / 0 |
| Après première journée enregistrée, satisfaction | 69 | 67 |
| Après deuxième journée enregistrée, satisfaction | 70 | 71 |
| Engagement de rôle en semaine 3 | Aucun | Honoré, 60 min requises, 168 observées |
| Après suivi avant troisième match, satisfaction / moral | 71 / 76 | 72 / 78 |
| Confiance finale observée | 73 | 73 |
| Trésorerie depuis checkpoint / salaire supplémentaire | +136 910 / 0 | +136 910 / 0 |

Les recettes et dépenses hebdomadaires expliquent le mouvement de trésorerie dans
le journal des commandes ; ce montant n’est pas présenté comme un bénéfice de la
conversation. Les deux matchs enregistrés donnent ici les mêmes scores (3–37,
0–22), minutes (83, 85) et RNG après chaque journée. Cette paire ne démontre
aucune supériorité sportive d’un choix. Le journal conserve chaque `requestId`,
payload accepté/refusé et coût réellement observé.

## Ce qui persiste, ce qui se répète

Le trait reste « Exigeant ». Le leadership courant passe 79 → 80, alors que
l’entrée historique conserve bien son leadership 79, son titre, son contexte,
son trait et le choix initial, mot pour mot. Le duo reste à 18 sans nouvelle
intervention. Le dialogue initial « clarifier » reste dans l’historique ;
un redémarrage réel après la première journée conserve exactement profil,
export-state, RNG et horloge dans les deux branches.

L’engagement de rôle demeure ouvert après une journée, puis est publiquement
`honored` en semaine 3 (`originWeek:1`, `dueWeek:3`, `resolvedWeek:3`). La promesse
de rotation reste une obligation distincte : `completed:2`, `minutes:168`.
Les semaines de l’économie et les tours sportifs sont consignés séparément.
Les événements suivants évitent les trois personnages récemment traités.

En revanche, rassurer le même joueur est de nouveau disponible chaque semaine :
deux répétitions hebdomadaires donnent chacune +1 de satisfaction observée,
et sont archivées. La seconde tentative dans la même semaine est refusée.
Cela montre une mémoire et un verrou, pas un dialogue narratif continuellement
renouvelé. Un seul personnage ne qualifie pas la variété globale des histoires
ni l’effet propre d’une personnalité sur les réponses.

## Troisième clôture refusée : limite réelle, transaction préservée

**Deux journées sont enregistrées par branche.** Le troisième match se termine
(6–15, 81 minutes pour ce joueur), mais `finish_round`, requestId 75 dans chaque
branche, répond exactement :

> Le fichier contient des données de carrière incohérentes.

Le runner termine sa collecte (`complete:true`) en conservant `recordedRounds:2`
et `blockedAt:finish_round_3`. Sa phase brute `after_round_3` désigne la lecture
après cette tentative refusée, et non une troisième journée enregistrée. La
promesse n’est donc jamais annoncée tenue ni son gain de satisfaction acquis.

Lecture du code réservé : `dist/economy.js` cumule les minutes réellement jouées
puis les écrit dans l’historique au troisième match ; `dist/saves.js` exige que
`h.minutes` reste au plus à 240. L’export public propre à ce joueur montre
168 + 81 = **249**. C’est une incompatibilité précise et une forte hypothèse de
cause ; le message reste générique et aucun moteur n’a été instrumenté pour
affirmer que ce contrôle particulier est son unique origine.

Le rejeu isolé du refus confirme l’égalité avant/après :

- profil `35e33b4909845d55978da41321e243ebbce0f5b8d103ed20c752e0034ce51e84` ;
- export-state `c1bbf507427ddaab81420b3f411588a32bc8ec1efed08700e04fe266ed83c8f4` ;
- RNG `4086047321`, horloge `1794434400000` ;
- promesse, minutes et match terminé inchangés.

Proposition réservée à Claude : vérifier et aligner la borne de validation des
minutes de promesse avec le maximum légal cumulé de trois matchs incluant les
arrêts de jeu et prolongations pris en charge. Ne pas tronquer le temps réellement
joué. Test ciblé à préparer dans ce périmètre : trois rencontres publiques avec
83 + 85 + 81 minutes doivent clôturer une promesse, puis sauvegarder, exporter et
redémarrer sans erreur, tout en gardant les rejets des valeurs réellement hors
bornes. Le présent runner reproduit le cas sans modifier une fixture sportive.

Autre question de design à arbitrer après correction : la promesse de rotation
et l’engagement de rôle utilisent les mêmes minutes avec deux échéances ; garder
visibles leurs origines et compteurs évite de les confondre. Aucun changement de
récompense ou de cumul n’est proposé comme vérité acquise ici.

## Reproduction et pièces légères

```sh
/workspace/work/tools/node-v22.23.4-linux-x64/bin/node tools/qa/character-story-persistence.cjs --output=/tmp/character-story-public.json
```

Sur un profil local déjà arrivé au refus (sans l’éditer) :

```sh
node tools/qa/character-promise-closure-replay.cjs /chemin/profil p13-21-1794434400000 /tmp/closure-replay.json
```

Les [cas publics](evidence/character-story-20261112/public-cases.json), le
[rejeu transactionnel](evidence/character-story-20261112/refusal-replay.json) et
le [manifeste](evidence/character-story-20261112/manifest.json) contiennent les
commandes, observations, refus et hashes. Aucun profil complet ni données
adverses cachées n’est publié. Durée non instrumentée ; aucune qualification
graphique, Windows ou CI globale n’est déduite de ce scénario Node.
