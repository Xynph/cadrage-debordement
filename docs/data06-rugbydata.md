# DATA-06 — Rugby Data, collecte partielle arrêtée pour préserver le quota

Le 31 octobre 2026, lecture HTTP publique de 30 effectifs 2026-2027 Rugby Data : **1493 lignes, 1472 identifiants source distincts**. Table explicite des clubs ; saison 27 = 2026-2027 observée dans le sélecteur du site. Robots.txt répondait 200 avec Allow: / ; cela ne constitue pas une licence de réutilisation. Aucun compte, image ou service payant utilisé.

**1159 identités LNR retenues** par nom complet exactement normalisé, club associé explicitement et unicité globale. 334 lignes sont exclues du rapprochement automatique (noms non concordants, clubs ou doublons), soit 433 IDs LNR sans correspondance retenue avec cette source. Aucun alias inventé.

La collecte individuelle a été volontairement interrompue à la demande de Léo pour préserver le quota : **689 fiches individuelles valides, 107 erreurs HTTP 503 et 363 profils non tentés**. Aucun travail de collecte ne continue en arrière-plan. Les snapshots marqués snapshotComplete signifient que le lot partiel est figé et tous les statuts sont comptabilisés ; pausedForQuota=true et attempted=false distinguent explicitement les requêtes non réalisées.

| Champ retenu dans le complément | Joueurs |
| --- | ---: |
| Date de naissance exacte | 689 |
| JIFF explicitement publié, Oui ou Non | 1159 |
| Poste(s) publié(s) | 1158 |
| Clubs formateurs publiés | 686 |
| Meilleur pied publié | 183 |
| Année annoncée de fin de contrat | 981 |

**903 IDs restent sans date de naissance dans ce complément** : 107 échecs, 363 non tentés et 433 identités non raccordées. Ne pas additionner ce lot aux 1592 identités déjà préparées comme s'il s'agissait de nouveaux joueurs.

## Contradictions et contrats

966 écarts de champs sont isolés dans conflicts. Les tailles et poids connus restent prioritaires : comparaison aux valeurs du catalogue main, puis aux observations préparées #155 et #158, conservées dans un snapshot séparé avec leur provenance et empreintes. Le complément retient seulement 787 tailles et 459 poids après neutralisation des contradictions ; les valeurs brutes restent dans les captures. Aucun remplacement du catalogue ou des fichiers précédents.

Les dates « Début/Fin de contrat » affichées dans un effectif de saison restent dans seasonContractStartAsPublished / seasonContractEndAsPublished. L'année de fin annoncée est séparée. Aucun 30 juin n'est déduit d'une année ; contractEnd reste null. Les chronologies, y compris futures, sont conservées comme déclarations du site, sans certifier leur exactitude juridique ni les appliquer au jeu.

Les champs viennent d'un annuaire secondaire. Dates impossibles/futures refusées ; aucune incohérence âge/naissance détectée sur les 689 fiches lues. JIFF, contrats et situations au départ d'une carrière restent à recouper si nécessaire avec les sources officielles. Salaire, budget, qualification réglementaire de première ligne, notes et club au 01/07/2026 ne sont pas inventés. validAtCareerStart=null.

## Fichiers et vérification

- rugbydata-rosters-2026-10-31.json : champs des cartes par club, URLs, dates, SHA256 du HTML.
- rugbydata-profiles-01.json à 04.json : champs individuels publiés et statuts d'échec/non-tentative ; pas de biographies copiées.
- rugbydata-collection-manifest-2026-10-31.json : périmètre, découverte des clubs, saison, clôture partielle et bilan.
- rugbydata-comparison-baseline-2026-10-31.json : mensurations antérieures avec provenance ; aucune modification des sources #155/#158.
- rugbydata-enrichment-2026-10-31.json : observations normalisées, sources par champ, conflits et revue.
- tools/data06-rugbydata.cjs : normaliseur hors réseau, sans nouveau collecteur concurrent ni écriture dans le jeu.

Reproduction : `node tools/data06-rugbydata.cjs`.
Tests réels : `node --test tests/data06-rugbydata.cjs tests/data06-all-players.cjs` : **14/14 réussis**. Identités, doublons, dates, inconnues, contrats annuels, conservation des mensurations précédentes, comptabilité du lot partiel, absence de réseau et JSON reproductible contrôlés. Revue indépendante du normaliseur effectuée ; naissance future détectée par la revue puis rejet corrigé et testé. La suite complète du jeu n'a pas été exécutée localement dans la copie partielle ; CI de la tête publiée à vérifier.

Base main d6032ccf (#157). Producteur : PR indépendante, aucune fusion, aucun dist, moteur, sauvegarde ou périmètre UI modifié. Les observations préparées ne sont pas une intégration jouable. Reprise prioritaire : 107 échecs temporaires puis 363 fiches non tentées ; les 433 identités non raccordées nécessitent des preuves supplémentaires et non des alias supposés.
