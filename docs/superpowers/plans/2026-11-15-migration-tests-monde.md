# Migration des recettes vers la carrière Monde

Exécution native dans la session courante, sans sous-agent. Décision explicite de Léo le 15/11 : migrer avant fusion, sans réduction de couverture ni nouvelle quarantaine. Ce document est le plan d'application de cette décision et d'AGENTS.md.

Objectif : toutes les recettes sélectionnées créent seulement world-champ ; les scénarios, assertions et contrôles de persistance restent couverts.
Architecture : réutiliser la VM native par le harnais commun, conserver le rendu HTML réel pour les recettes de présentation, préparer explicitement la semaine du match et les situations contrôlées. Les reprises rechargent un état Monde complet. Ne pas fabriquer un ancien effectif étiqueté Monde.
Technologies : Node 22 en CI, Node 24 local ; Godot 4.7.2 pour les recettes graphiques.

## Contraintes et points de revue

- Garder toutes les suites déjà sélectionnées ; aucun ajout de drapeau d'exclusion.
- Aucun retrait d'assertion pour obtenir du vert : traduire les constantes du calendrier/effectif en invariants exacts Monde.
- Refuser l'ancien démarrage avant mutation et avant consommation du RNG.
- Les interfaces HTML, les reprises et les défauts de stockage doivent rester vérifiés par leurs vrais chemins.
- Un seul Godot local à la fois ; données nominatives privées ; aucune dépense ou modification serveur GitHub.
- Mesurer durée et mémoire des suites migrées, adapter leurs budgets et poids avec provenance explicite.
- CI complète seulement après audit des appels hérités ; branche à jour sur main et Validation CI verte avant gate.

## Tâches

- [x] 1. Harnais commun : `tests/harness.cjs`, test `tests/harness-monde-compat.cjs`. Constater l'absence d'API Monde sans créer d'ancienne carrière (rouge), ajouter la vraie création native, vérifier version 5 / 116 clubs / refus atomiques / HTML réel (vert). Tester reprise et RNG. Commit ciblé.
- [ ] 2. Match : migrer les scénarios sélectionnés de règles, conquête, discipline, substitutions, préparation et présentation. `toMatch()` prépare le premier match réel ; aucun contournement des gardes de match. Chaque assertion initiale doit garder un équivalent documenté. Exécuter seulement les suites auditées Monde. Commit par groupe vert.
- [ ] 3. Gestion : économie, contrats, vente, développement, staff, délégation. Fixer les conditions utiles du cas dans une carrière Monde ; utiliser le nombre initial réel et vérifier les variations exactes. Contrôler refus, reprise, rollback et absence de double paiement. Commit par groupe vert.
- [ ] 4. Saisons et compétitions : remplacer les hypothèses 14 clubs / 26 journées par les calendriers et éligibilités du Monde complet ; conserver les contrôles de fin de saison, total des scores, changements de club, promotion/relégation et import hostile. Les formats historiques de fichier restent des entrées de parseur, pas des carrières anciennes lancées. Commit par groupe vert.
- [ ] 5. Interface et stockage : menus, préférences, centres, offline. Le harnais conserve le vrai code de rendu ; les chemins qui proposaient un ancien démarrage doivent rejoindre la carrière Monde. Vérifier les mêmes erreurs, effets et actions. Commit par groupe vert.
- [ ] 6. Rejeux et Godot : migrer les producteurs de gestes et les captures encore héritées ; régénérer les fixtures en Monde avec leurs contrôles de fidélité. Un seul Godot, staging officiel, pas de ressources de débogage dans le jeu livré. Commit ciblé.
- [ ] 7. Garde et couverture : `ci/legacy-modes.cjs`, `tests/ci-modes-monde.cjs`. Ajouter les régressions des appels implicites et imports indirects sans exclure de suite supplémentaire. Comparer la sélection avant/après et inventorier les assertions. Mesurer les poids et budgets des suites devenues longues. Commit ciblé.
- [ ] 8. Intégration : revue propre du diff, noms privés, suite complète Monde, PR française/passation et CI jusqu'au vert ; réception de main, puis actualisation et livraison de #739/#740/#741 selon dépendances. Aucun ancien run annulé ne sert de preuve conforme.

## Registre de progression

Les journaux détaillés restent dans le dossier de travail externe. Chaque groupe terminé ajoute ici son commit et ses tests verts. Les tâches non cochées sont encore ouvertes.
- Début : 131 suites sélectionnées chargent directement le vieux harnais ; 121 contiennent un démarrage numérique candidat. Inventaire statique, pas couverture d'exécution.
- Régression du harnais : rouge observé avant toute création (API start absente). Développement en cours.

- Harnais : régression rouge avant création observée, puis verte (World complet, refus atomiques et HTML). Second rouge/vert sur le garde natif avant toute ancienne fabrique. Discipline : tous les contrôles de pénalité, récidive, sauvegarde/import et migration de champ facultatif passent en Monde ; ajout de toMatch explicite, aucune assertion retirée.

- Première ligne : suite complète verte en Monde, 146,0 s, pic RSS observé 3 510 444 Kio (Node 24 local). Aucune assertion retirée ; préparation réelle du premier match réutilisée par copies indépendantes et reprise exacte contrôlée. Budget/poids à intégrer à la tâche 7 avant CI.

- Matchs, avant optimisation de sérialisation : tirs au but verts (32,0 s), côtés de touche verts (376,5 s, 205 scènes), géométrie de touche verte (579,8 s), passes en jeu vertes côté JS (71,7 s ; sous-test SDK non exécuté, recette Godot à faire). Tous les scénarios/graines/assertions conservés. Profil CPU de 10 s : 87,5 % des échantillons dans nativeSaveText, appelé par presentationTick.

- Sérialisation : la VM de test expose maintenant le mécanisme différé déjà utilisé par le worker. Régression rouge puis verte : match Monde complet de 197 étapes, état/save/RNG strictement identiques ; 83 sérialisations immédiates contre 1 différée. Les tests de stockage habituels restent immédiats. Mesures après optimisation : touches côtés 147,2 s (205 scènes identiques), géométrie 202,3 s, passes JS 37,0 s ; première ligne 169,1 s (pas de gain revendiqué sur cette suite). Les nouvelles mesures sous charge et leurs limites sont publiées dans `ci/monde-migration-mesures-20261115.json`. Budgets et mémoire adaptés, rejeu des shards vert (estimation 17–18 min). Garde de conservation des 553 suites initiales verte, aucune nouvelle exclusion.
- Confidentialité : les dates complètes encore présentes dans les sources/compilés publics ont été retirées en gardant les âges et années utiles. Comparaison stricte : 1 592 profils français et 3 208 profils du registre identiques hors birthDate. Les quatre originaux étrangers/fixture sont archivés par SHA-256 dans la PR privée Xynph/rugby-reel-donnees#16, en brouillon. La source française originale y existait déjà. Aucun historique réécrit. Nouvelle garde des bases et de la fixture compressée verte ; compilation commune/registre vérifiée. Le contrôle des noms n’équivaut pas à ce contrôle des dates.
- Années/âges : ancienne recette migrée Monde (2 tests verts), calcul des bornes avant/à/après le 1er juillet sur dates inventées, 3 âges de référence sans date complète, sauvegarde/reprise et consultation sans mutation. Catalogue pur : 2 tests verts. Les anciennes créations LNR restantes doivent encore être migrées ; aucune CI complète relancée et aucune PR annoncée PRÊTE.
