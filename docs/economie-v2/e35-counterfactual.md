# Économie V2 E3.5 — contrefactuels natifs de progression sportive

## Distinction obligatoire des résultats

Cette PR R&D est empilée sur #356, sans modification d'un fichier existant. Les campagnes natives à 15 saisons E3.4 servent de **contrôle de non-régression** et de parité de sauvegarde ; **elles ne constituent pas des campagnes contrefactuelles de résultats sportifs**. Les contrefactuels sont des micro-expériences natives réalisées séparément sur copies jetables.

1. **Preuve de dépense** : l'investissement dans les installations n'est enregistré que lorsque `worldUpgradeFacility()` retourne effectivement vrai ; débit natif exact du devis, événement `worldManagement.upgrades` avec précision **saison uniquement**, registre borné. Formation : le choix 0/4 000/12 000 ne débite rien ; seul `careerAcademyTraining()` payé débite et inscrit une période `season:economy.week`.
2. **Entrée de progression** : `worldFacilityTraining()` injecte une quantité basée sur niveau et `ageGrowth` pour les moins de 23 ans non blessés ; `careerAcademyTraining()` applique l'entrée 0,055 ou 0,15 fois `ageGrowth` après débit. Ces valeurs **ne sont pas** des hausses de note garanties.
3. **Progrès réellement mesurés** : une paire témoin/intervention est clonée du même document natif avec état RNG identique. Une invocation native de formation par bras, puis lecture des `rating` et `dev.xp` de la même cohorte (ID stable). Les différences de niveau et d'XP sont observées, non déduites des coefficients de règles. Les plafonds de potentiel peuvent réinitialiser l'XP ; le delta d'XP peut être nul ou négatif même si la règle accorde une entrée.
4. **Résultats sportifs et classement** : `matchResultDelta=null`, `leaguePositionDelta=null`, `seasonLongEffect=null`. Aucun match n'est comparé dans ce micro-test ; aucun gain de victoire, performance, recette ou place au classement ne doit être inféré de l'XP.
5. **Couverture** : six configurations profil × graine, chacune E3.4 : 15 saisons natives, 435 tours, trois imports, parité état/checksum. Pour chaque configuration, trois paires tests natives (installations, formation 4 000 et formation 12 000), avec vérification des originaux inchangés et RNG apparié. Les échecs d'exécution sont des observations, jamais des engagements ou des dettes fictives.

## Réserves
Les deux bras font chacun une invocation directe des fonctions natives dans une copie identique de la même semaine : ce protocole isole les **effets immédiats** sur XP et note, pas les écarts de carrière après 15 saisons, ni une comparaison appariée des résultats de match. Une différence de financement future modifierait aussi la stratégie, les choix et parfois l'aléatoire ; ne pas extrapoler un effet causal à long terme. Les historiques du jeu sont bornés et les dates restent aussi précises que les données natives.

## Périmètre
Cinq chemins nouveaux seulement. Pas de modification `dist/`, ancien module E1–E3.4, format de sauvegarde, PRODUCTEUR, MATCH 3D (en pause), DATA/LNR, release gate ou `main`. Aucun READY, /cd-check, /cd-merge, fusion. CI et artefacts sur HEAD exact requis pour qualifier les six campagnes.
