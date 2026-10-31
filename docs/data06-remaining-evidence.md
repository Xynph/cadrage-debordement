# DATA-06 — complément individuel des 378 identifiants restants

## Résultat observé le 31 octobre 2026

Les 378 identifiants laissés dans `remainingIds` par la PR #155 ont tous été retrouvés dans les 30 effectifs officiels LNR, puis leurs **378 fiches individuelles** ont été ouvertes dans le navigateur cloud. La collecte s'est terminée à `2026-10-31T21:50:29.139Z`. Aucun accès à un compte ou statistique réservée, aucune photo, aucun appel Firecrawl.

Le navigateur connecté n'était pas accessible dans cette session. Le navigateur cloud a permis de lire ItsRugby (Clermont et fiche Harry Plummer), mais aucun alias n'a été déduit pour résoudre les divergences de noms ItsRugby/LNR. Le complément exploitable vient exclusivement des profils officiels LNR par leurs identifiants exacts. Les observations ItsRugby et leurs conflits restent intacts.

| Champ du complément | Fiches |
| --- | ---: |
| Identité LNR vérifiée par ID, URL, nom et club | 378 |
| Poste publié (groupe parfois général) | 378 |
| Âge publié | 378 |
| Pays/nationalité tel qu'affiché par LNR | 378 |
| Taille et poids publiés | 214 |
| Mensurations absentes, laissées nulles | 164 |
| Poids supérieur à 145 kg signalé pour revue | 3 |

Les trois poids à examiner sont `lnr:340` (148 kg), `lnr:1009` (156 kg) et `lnr:13764` (148 kg). Ils sont conservés comme observations littérales avec `qualityFlags`, sans correction arbitraire ni activation automatique dans le jeu. Les libellés pays sont conservés sans inférer une nationalité juridique, une sélection ou un statut JIFF (exemples source : « Samoa occidental », « Grande-Bretagne », « Autriche »).

**Couverture préparée après #155 + ce complément : 1 592/1 592 profils partiellement enrichis**, contre 1 214 auparavant. Aucun identifiant sans complément personnel ne reste dans le périmètre exact des 378. Cela ne signifie ni biographies complètes, ni données intégrées dans une carrière. La couverture de chaque champ reste incomplète. Naissance exacte, JIFF, qualification précise de première ligne, contrats, salaires, finances et notes restent inconnus dans ce complément. L'appartenance au 1er juillet 2026 n'est pas prouvée.

## Preuves et intégrité

- `modding/data06/remaining-lnr-raw-01.txt` à `03.txt` : 3 lots de 126 observations, format `ID|club affiché|poste|[taille|poids|]âge|pays affiché`. Les séparateurs remplacent les sauts de ligne du bloc rendu `.player-infos__wrapper`, sans reformuler les valeurs.
- `remaining-lnr-profiles-2026-10-31.json` : 378 fiches normalisées avec nom exact, URL individuelle, date, texte du bloc source, champs numériques, inconnues et drapeaux de revue.
- Le navigateur a calculé le SHA256 de l'ensemble trié numériquement des tuples `{id,url,name,club}` réellement observés : `79184e3ec813e867fc802b7c7233c055acb1b8497e145b7b87899051e1bf4287`. Les noms des en-têtes sont exactement les noms du catalogue en majuscules ; les URLs individuelles et URLs de club sont identiques aux références attendues. Cette concordance a été vérifiée localement avant reconstruction des tuples dans le JSON. Aucun nom ou URL n'est reconstruit sur une correspondance approximative.
- Le SHA256 de la concaténation des trois lots bruts, sauts de ligne inclus, est `df405275851f7fa24366c561e7c926862d4010e76d5073d43ce381215a844431` (21 154 octets). Il concorde avec le calcul effectué dans le navigateur. Ces empreintes contrôlent le transfert et la reproductibilité ; elles ne sont pas une signature de LNR.
- Les 240 profils précédents, le catalogue et les captures/rapports #155 sont conservés. Le complément n'écrit dans aucun de ces fichiers.

## Reproduction et tests

```sh
node tools/data06-remaining-evidence.cjs
node --test tests/data06-remaining-evidence.cjs tests/data06-itsrugby-browser.cjs tests/data06-itsrugby-bulk.test.cjs tests/data06-all-players.cjs
```

Le normaliseur est **entièrement hors réseau**, pas un nouvel extracteur concurrent. Il refuse un transfert altéré, une identité ou URL différente, une divergence de club, une couverture de base modifiée, les doublons et les valeurs mal formées. Il dépend du rapport #155 et du catalogue existant ; une évolution de ces références exige une réévaluation explicite, pas une acceptation silencieuse.

Les **21 tests ciblés** ont réellement réussi sur Node 24.22.1, dont les 6 nouveaux tests du complément, les 10 contrôles de collecte/rapprochement ItsRugby et les 5 contrôles du catalogue. Le test de non-régression reproduit le rapport #155 et vérifie les empreintes des quinze fichiers contenant les 240 profils antérieurs. Un premier contrôle local avait détecté des fins de fichiers altérées par la copie locale des sources ; les octets GitHub exacts ont été restaurés, puis les 21 tests ont réussi sans modifier le dépôt source. Zéro appel réseau pendant le normaliseur ; aucun crédit Firecrawl utilisé. La suite complète du jeu n'a pas été exécutée localement dans cette copie partielle ; la CI GitHub complète sur la tête publiée reste obligatoire.

## Réception par l'intégrateur unique

Base réévaluée : `main 2cd33852e055a4393558c331e2ec2d3ecbd4c5eb` après #154. Dépendance de données : #155, tête `afab8680b23cd6087f415ad34291107ca075189d`, dont la CI Tests JavaScript et Validation CI a été contrôlée réussie (run 41243909097). Les six fichiers propres à #155 hors journal sont repris par leurs blobs exacts afin de permettre la CI du supplément sur le main actuel ; la PR doit être reçue après #155, en évitant toute double importation. La PR producteur ne fusionne rien dans main.

Réception : appliquer les 378 observations uniquement aux IDs absents du complément #155 ; conserver provenance, inconnues, groupes de postes et drapeaux de revue. Ne pas transformer âge en date de naissance, pays affiché en JIFF, ni club observé en octobre en appartenance au départ de carrière. Contrôler la CI exacte de la PR, puis réaliser séparément le raccordement au catalogue jouable et ses validations. Le producteur n'a modifié ni `dist/**`, ni moteur, ni sauvegarde, ni périmètre UI.
