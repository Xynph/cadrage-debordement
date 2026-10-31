# Diagnostic économique natif — lot indépendant pendant UI-02C

Base auditée : `e706d6ade5406b7f7c8e9e9c4cdaeaa9033c4807` (UI-01 intégrée). Tous les montants sont des euros fictifs de jeu, **pas les budgets réels des clubs**. Aucun coefficient ni fichier de production n'est modifié. Les recettes positives ne sont pas automatiquement un bug et une CI verte ne certifie pas l'équilibrage.

## Méthode et périmètre

Le banc réutilise `tests/harness.cjs` et `tests/career-resilience/native.cjs`. Il appelle les vrais `finishRound`, `advanceSeason`, `trainWeek`, opérations de recrutement, investissements et import/export. Aucun score ni classement n'est produit par V51 ou par un modèle économique de remplacement.

Pour chaque journée, l'observateur relève les écritures nouvelles du manager **avant leur éviction du registre borné à 100 lignes**. Pour les treize adversaires, il rapproche séparément la variation effective de trésorerie des partenaires, salaires courants, véritables scores et domiciles, entretien et primes de signature issues des rapports IA. Chaque transition annuelle distingue renouvellements, recrutements, apport, remboursement, conversion d'un déficit en dette et investissements. Tout résidu inexpliqué supérieur à 0,001 € fait échouer le diagnostic. Une étiquette de registre inconnue fait également échouer le test, au lieu d'être ignorée.

L'observateur n'intercepte ni ne remplace les fonctions métier. Son absence d'effet sur l'état complet et le flux aléatoire est confrontée à un témoin sur une vraie journée. Les sources et le SHA testé sont enregistrés dans les rapports. Les reprises passent par le parseur et la confirmation d'import natifs ; l'état RNG appartient seulement au banc de test, pas aux sauvegardes de production.

## Campagne exécutable

Trois politiques et deux graines (`827381`, `99173`), quinze saisons par combinaison :

- `reference` : club 0, trésorerie native, manager passif sans recrutement, prolongation, entraînement ou investissement volontaire.
- `modeste` : club 13, mêmes choix passifs, trésorerie native.
- `deficitFormation` : club 13, trésorerie initiale forcée à −250 000 € et ajustement déclaré ; choix du sponsor stable, séances natives de formation à 4 000 € lorsqu'elles sont financées, tentative d'investissement annuel si abordable. Pas de recrutement ou prolongation discrétionnaire de professionnels.

Ces politiques sont des **scénarios contrôlés**, pas un comportement représentatif de tous les joueurs. La comparaison déficit/formation combine plusieurs changements : elle ne mesure pas isolément un effet causal de l'investissement. Deux graines par profil ne constituent pas une calibration statistique exhaustive.

```sh
node tests/economy-audit.cjs
node ci/economy-audit.cjs reference 827381 15 economy-audit-report
node ci/economy-audit.cjs --aggregate economy-audit-input
```

La CI refuse une campagne incomplète, des combinaisons manquantes ou dupliquées, des empreintes de sources différentes et une synthèse incompatible avec les mesures détaillées. Les six campagnes, rapports par club/saison, écritures agrégées et reprises sont disponibles en artefacts. **Ne revendiquer 90 saisons qu'après lecture de leur verdict final.**

## Résultats préparatoires effectivement obtenus

Les vingt groupes courts de tests ont réussi localement sur les scripts natifs dont les blobs chargés ont été confrontés à `main`. Les essais locaux de trois saisons pour `reference` et `deficitFormation` ont rapproché tous les flux sans résidu. La CI sur le commit publié reste la référence de livraison du banc.

Exemple de mesure de la première saison `reference`, graine 827381 : trésorerie cumulée de 67 700 000 € à 113 668 925 €. Variation de 45 968 925 €, expliquée par 64 960 000 € de partenaires, 67 588 000 € de billetterie, 14 160 000 € de primes de victoire, −98 549 075 € de salaires et −2 190 000 € de signatures IA. Aucun apport annuel ne doit être ajouté à cette première saison : les apports surviennent entre deux saisons.

## Constats confirmés et décisions à préparer

### 1. Prévision V41 : entretien absent — défaut reproductible

`dist/career-integration.js`, `careerBudgetModel`, ne reprend pas `worldUpkeep` dans `weeklyOtherCosts`. Après un investissement natif au niveau 3, la prévision omet 2 900 € par période, soit 34 800 € sur son horizon de douze périodes. Le groupe 16 reproduit cet écart en isolant les règlements sans billetterie ni victoire. **Son succès prouve la reproduction du défaut, pas que la prévision est correcte.**

Correction recommandée dans un chantier ultérieur : intégrer une seule fois l'entretien connu aux charges prévisionnelles, conserver séparément la formation et vérifier plusieurs niveaux ainsi que les anciennes carrières sans `worldVersion`. Pas de migration de sauvegarde nécessaire a priori ; à confirmer lors de la correction.

### 2. Fréquence et excédents structurels — mesure, pas doublon présumé

Le moteur courant règle partenaires et salaires sur 29 journées/tours, même lorsque le club ne dispute plus les phases finales. Il ne simule pas 52 semaines civiles. Les adversaires reçoivent 160 000 € par tour, 360 000 € lorsqu'ils sont premiers dans une paire et 80 000 € par victoire. Les 2,5 M€ d'apport sont alloués à chaque club lors de l'intersaison.

Dans les campagnes testées, vérifier les nombres d'occurrences et la somme des flux avant de conclure à un double versement. Un excédent peut provenir du barème, de l'apport récurrent et d'une politique passive limitant les dépenses. Ne pas remplacer arbitrairement 29 par 52 ni réduire les recettes sans scénario comparatif et objectif de gameplay explicite.

### 3. Terrain neutre et prime de champion — asymétries à arbitrer

L'interface décrit les demi-finales et la finale comme « Terrain neutre », mais `financeWeek` et `worldWeeklyEconomy` allouent une billetterie au club placé en premier dans la paire. Le rapport conserve chaque occurrence et son montant. Cette observation ne dicte pas la règle correcte : il faut décider si ces recettes sont partagées, attribuées ou absentes, puis harmoniser affichage et comptabilité.

`finishRound` attribue la prime de champion de 1 M€ uniquement si le champion est le club du manager. Le rapprochement des comptes des adversaires ne montre pas cette prime. À classer comme choix asymétrique à valider, pas comme une règle sportive officielle.

### 4. Dette et richesse nette

La remise à zéro d'une trésorerie IA négative augmente simultanément la dette : elle ne doit pas être comptée comme un revenu gratuit net. Le banc distingue cette conversion, les intérêts annuels de 4 % et le remboursement. Le cas négatif court vérifie une dette de départ de 200 000 €, une trésorerie de −500 000 €, puis 2 250 000 € de trésorerie et 478 000 € de dette après traitement natif.

## Tests de décisions réellement exécutables

Seuil d'investissement exact et refus à un euro près ; réserve d'entretien non prélevée en double ; répétition après import ; formation financée ou refusée ; sponsor signé une fois ; signature à trésorerie exacte ; transfert conservant les deux budgets et un seul propriétaire ; acheteur insuffisamment financé ; échec de stockage visible et dernier fichier conservé ; corruption rejetée ; refus des opérations en match. Les injections de panne et trésoreries artificielles sont confinées aux copies de test.

## Coordination et limites

Seuls six nouveaux fichiers sont publiés. Tous les fichiers `dist/`, le harness, les sauvegardes officielles, le journal partagé et les branches UI-02C restent intacts. Le journal de ce lot se trouve ici et dans #73 pour éviter une modification concurrente. La PR reste séparée et non fusionnée pendant le raccordement UI-02C. Aucune correction de gameplay n'est livrée par ce diagnostic.

Les classements et qualités moyennes proviennent du moteur, mais leur corrélation avec l'argent ne prouve pas une causalité. Les compteurs de rapprochements sont des groupes répétés, pas autant de suites indépendantes. Aucun test Windows natif ou visuel UI-02C n'est revendiqué.
