# V11 — Équilibrage sportif dans le moteur natif

Spécification : demande Work de Léo du 07/11/2026. Base main 3014774ab4ca13d1d325756ed89f2bb029b1b99c.

- [ ] Consolider depuis le master immuable, sans empiler V6/V8/V9/V10. Barème sur 11 familles, 36 attributs conservés, traits cachés et potentiel inchangés. Export candidat explicite par ID et ancien/nouveau ; application sur copies avec contrôle des préconditions.
- [ ] Créer un adaptateur candidat documenté 36 attributs → 11 compétences natives, sans toucher au moteur ni à la production. Comparer compétences historiques / projection baseline / projection consolidée. Aucune formule de résultat parallèle.
- [ ] Exécuter createRugbyMatch → advanceRugby et rugbySimulate, contrôles de déterminisme, domicile alterné, blessures et fatigue réinitialisées entre matchs indépendants. Conserver les graines et métriques détaillées.
- [ ] Tester divisions, niveau faible/moyen/fort, promu à 0/2/3/5 recrues, relégué à 0/5 départs, fatigue et tactiques. Les étiquettes champion/promu/relégué désignent des scénarios contrôlés sur effectifs existants, pas des résultats historiques.
- [ ] Collecter les données publiques 2025-26 centrales au-delà des 20 lignes rendues, avec saison et périmètre. Rejeter les pages courantes et archives authentifiées. Les statistiques n'engendrent pas mécaniquement une note technique.
- [ ] Vérifier les mécanismes de management/sauvegarde/saison existants ; ne pas prétendre tester deux divisions seniors si le jeu ne les implémente pas. Tester plusieurs saisons natives et leur reprise, documenter la proposition de raccordement réservée.
- [ ] Publier une seule PR DRAFT indépendante, CI native dédiée + CI générale, passation #73 avec HEAD exact et limites.

Choix d'implémentation : CommonJS/Node 22, harness existant. Tests ciblés puis campagne déterministe, sans dépendance externe. Les seuils sportifs sont des cibles de game design exploratoires, non des statistiques historiques. Les sorties doivent signaler des cibles manquées ; aucun test ne doit imposer un taux de victoire artificiel.

Revue : vérifier absence d'effet de l'étiquette division sur le moteur, cohérence de la projection des 36 attributs, absence de doublons et de cumul de deltas, effets de banc et réinitialisation des états, intervalles d'incertitude et limites d'échantillonnage. Les chemins dist/** et modding/** restent en lecture seule.
