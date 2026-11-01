# DATA-06 — Index de conservation des preuves de la PR #160

**État au 1er novembre 2026.** Source historique : [PR #160](https://github.com/Xynph/cadrage-debordement/pull/160), HEAD `c6c19af169a5ecae3857382e71faf03b188ceacf`. Référence jouable : [PR #170](https://github.com/Xynph/cadrage-debordement/pull/170), main `3fc721360224f670c56af2db8d975384bd173d14`.

## Décision d'intégration

**Ne pas réimporter les effectifs ni les années depuis la PR #160.** Le catalogue existant contient 1 592 identifiants LNR uniques, 1 442 années rattachées à des recherches et 150 années fournies par l'utilisateur. Le dernier lot de 75 années documenté par #160 se retrouve à l'identique dans le catalogue déjà intégré (75/75, aucune divergence d'année). Les trois dates exactes de #165 et les 150 années de #166 figurent également déjà sur main.

L'archive de #160 reste consultable dans son historique Git ; il n'est pas nécessaire de copier ses instantanés volumineux dans la distribution du jeu. Les données de Rugby Data et des autres sites tiers ne sont **pas présumées librement redistribuables** : l'accès public et les directives robots ne valent pas licence. Préférer les métadonnées de provenance et liens sources aux reproductions intégrales.

## Inventaire différentiel (arbre Git)

Comparaison par chemins des arbres `c6c19af` et `3fc7213`, pour les chemins DATA-06 (`modding/data06/`, `docs/data06-*`, `tests/data06-*`, `tools/data06-*`) : **54 chemins dans #160, dont 15 fichiers au blob identique sur main et 39 chemins absents de main**. « Absent » signifie fichier documentaire non copié, **pas** joueur ou année manquante.

| Famille absente de main | Fichiers | Traitement |
| --- | ---: | --- |
| Notes de recherche `docs/data06-*` | 4 | Conserver la traçabilité via #160 et cet index |
| JSON d'années, correspondances, contrôles et provenance | 27 | Ne pas activer automatiquement ; comparer par ID LNR et statut avant usage |
| Instantanés bruts `rugbydata-enrichment`, `rosters` et `profiles-01..04` | 6 | Rester dans l'archive Git #160 ; ne pas recopier des profils tiers |
| Tests et collecteur de recherche | 5 | Archives d'outillage, pas nécessaires à l'exécution du mod |

**Remarque sur le décompte** : les familles ci-dessus peuvent se recouper selon la portée attribuée aux JSON ; ce tableau est une classification indicative, non une somme de fichiers disjoints. Le décompte de référence reste 39 chemins absents.

## Contrôles et limites de preuve

- `birthyears-final-gaps-2026-11-01.json` : 75 enregistrements ID LNR, **75 présents et années identiques** sur main. L'état historique 1 442/1 592 précède les 150 apports utilisateur.
- `rugbydata-birthyear-coverage-audit-2026-11-01.json` : instantané antérieur de **894 ID LNR liés** à **910 ID Rugby Data** avec année, et 698 manquants *dans ce sous-ensemble*. Ce n'est pas le nombre de manquants du jeu actuel.
- `rugbydata-prod2-lnr-birthyear-reconciliation-2026-10-31.json` : 148 correspondances LNR retenues sur 163 lignes, 15 non rapprochées, méthode nom complet normalisé et club ; ne jamais associer les 15 sans preuve supplémentaire.
- `rugbydata-six-club-birthyear-dedup-2026-11-01.json` : bilan historique 34 « new », 5 « already », 10 « hold ». Ces statuts doivent être replacés à la date de l'audit et ne signifient pas 34 années à importer aujourd'hui.
- `rugbydata-collection-manifest-2026-10-31.json` et `docs/data06-rugbydata.md` : collecte interrompue volontairement pour préserver le quota ; 689 fiches individuelles valides, 107 erreurs HTTP 503, 363 non tentées. Un snapshot fermé ne signifie pas collecte exhaustive.
- `docs/data06-birthyears-final-gaps.md` : 27 pages d'effectifs Espoirs reçues, 3 HTTP 429 ; correspondances saisonnières ne prouvent pas une appartenance au club au 01/07/2026.

## Conflits à conserver explicitement

Les divergences historiques de sources **Igor Gatteau**, **Lylian Zelioli** (`lnr:13497`) et **Dylan Idrissi** (`lnr:11779`) ne doivent pas être effacées au motif que des dates de référence sont chargées. Dans le dernier lot de #160, `lnr:13497` et `lnr:11779` sont signalés comme contradictions officielles persistantes. Les trois dates de #165 sont présentes dans le mode LNR ; ne pas les transformer en dates indépendamment confirmées par une autre source.

## Règles de réutilisation

1. Utiliser **l'ID LNR unique**, jamais l'ordre des tableaux ; exiger un lien d'identité auditable avant enrichissement.
2. Ne pas convertir une année seule en date exacte ni supposer l'affiliation au club au 01/07/2026.
3. Ne pas réimporter des valeurs déjà présentes ou écraser des dates connues avec un snapshot historique.
4. Vérifier droit de redistribution, statut de source, provenance et conflits **avant** tout nouveau fichier de données.
5. Ne pas faire dépendre le jeu ni les tests de CI des archives brutes de la PR #160.

## Limitation du présent audit

La comparaison **exhaustive des schémas et des enregistrements de chacun des 39 fichiers** ainsi que l'exécution locale des tests Node n'ont pas été réalisées : l'environnement local n'a pas accès au dépôt GitHub. Les conclusions factuelles ci-dessus reposent sur les arbres Git, le catalogue consolidé et l'examen ciblé des rapports. Cet index n'est **pas** une certification de licence, d'exhaustivité ou de qualité de tous les snapshots.
