# Passation à Claude — arrêt demandé le 15 novembre 2026

Léo a demandé d'arrêter le développement et de transmettre la suite à Claude.
Les campagnes locales ont été arrêtées, les deux producteurs avertis, aucun
nouveau test ni aucune fusion ne doit être lancé par cette session.

## Le but du travail

Livrer la consolidation du jeu décrite dans les passations #737 et #736,
en commençant par le conseil précis de Gabi le jour de match et la stabilité
de `tests/native-club-support-ui.cjs` (#714, repris dans #739).

Le blocage découvert était plus large : 131 suites sélectionnées chargeaient
le vieux harnais Web, dont 121 avec un démarrage numérique candidat. Elles
pouvaient créer une ancienne carrière malgré la garde statique. Léo a choisi
explicitement leur migration vers le Monde avant fusion, sans perte de
couverture. Ce préalable est devenu le chantier #742. Il reste inachevé.
La majorité du temps est allée à cette infrastructure et à ses campagnes,
pas à de nouvelles améliorations visibles du jeu.

## Références et règles

Lire d'abord `AGENTS.md`, puis les deux passations du 15/11 :

- [Consolidation, PR #737](https://github.com/Xynph/cadrage-debordement/pull/737).
- [Monde/niveaux/formation, PR #736](https://github.com/Xynph/cadrage-debordement/pull/736).
- [Coordination #591](https://github.com/Xynph/cadrage-debordement/issues/591).
- Plan et registre détaillés : `docs/superpowers/plans/2026-11-15-migration-tests-monde.md`.

Carrières jouées : uniquement `world-champ`, v5, 116 clubs, 114 jouables ;
56/57 sont des invités. Les exercices purs de codecs/composants historiques
ne constituent pas des carrières anciennes lancées. Ne pas réduire les cas,
graines, années ou assertions, ni ajouter une exclusion pour obtenir du vert.
Les 553 suites sélectionnées au début sont conservées par une garde dédiée.

Coordination RÉSERVÉ / PRÊT / FUSION EN COURS / FUSIONNÉ ; un seul intégrateur.
Pas de push main, force-push, stash nu, dépense ni modification administrative.
Actualiser chaque PR sur main ; fusion seulement sans conflit, Validation CI
verte, gate officiel et reçu post-fusion du main exact. L'autorisation ordinaire
de fusion existe déjà ; ne pas la redemander.

Pas de noms/dates de naissance/portraits/logos réels ni Mixamo dans le dépôt
public. Les originaux restent dans `Xynph/rugby-reel-donnees`.

## Où reprendre

Main observé à l'arrêt : `b807b5c481a94fff4bee6fcd615b80fea37367a5`.
Le dépôt était encore public ; vérifier à nouveau avant toute CI.

- **#742**, brouillon, branche `codex/garde-monde-implicite-20261115` :
  dernier code reçu/poussé `0bf3127b04affdf53a2751677077dadc495737fa`.
  Aucune Validation CI complète verte et aucune fusion.
- **Branche de cette passation** : `codex/passation-claude-arret-20261115`.
  Elle part de ce même commit et conserve en plus les trois ports root en
  attente et le découpage V63.2. Ces ajouts sont des **WIP**, pas des verts.
  Aucune PR nouvelle n'est ouverte pour cette branche.
- Producteur gestion : `codex/migration-gestion-monde-20261115`.
  Snapshot d'arrêt `7158ba15a7910b0db4fdf7d567e1189422e6081b` :
  produits et recettes WIP, sauf sa copie World-career obsolète. **Ne pas
  fusionner toute cette branche aveuglément** : plusieurs commits ont déjà
  été repris dans #742 avec des SHA différents. Reprendre les fichiers/diffs
  manquants après comparaison.
- Producteur UI : `codex/migration-ui-sauvegardes-monde-20261115`.
  Snapshot `941c813d66618e8efbf5c47bf0b454ef6f3c433b` :
  dernier `tests/world-career.cjs` WIP.
- **#739** : Gabi/support, branche `claude/gabi-conseil-support-ui-20261114`,
  tête `2776933` ; recette ciblée faite, intégration bloquée par #742.
- **#740** : chorégraphe Monde, tête `4ea71` ; recette réelle de match faite,
  intégration bloquée.
- **#741** : outillage Godot, tête distante `73d268` ; correction locale
  `765afe7f` non poussée dans `/workspace/work/outillage-livraison`, à préserver.
- **#744** : optimisation des aptitudes, fermée comme proposition remplacée,
  **pas fusionnée**. Contenu repris dans #742 au `43528199`.
- **#743** : préparation CI sur PC personnel, autre réservation, brouillon
  `696940eb81e2d2a2f0984327a7424bfba82ba079`. Pas activée par ce chantier.
  Consulter ses échanges et #591 avant toute intervention sur la CI.

## Ce qui a été reçu

Les durées ci-dessous sont locales sous charge, pas des mesures GitHub.
Registre : `ci/monde-migration-mesures-20261115.json` ; chaque reçu précise sa
provenance et ses limites. Les signatures du fichier courant ne prouvent pas
que toutes ses dépendances étaient déjà présentes dans un ancien reçu.

- Harnais natif partagé : démarrage Monde, refus atomiques des anciens modes,
  HTML réel pour les écrans, reprise S/store/RNG stricte. Le mécanisme différé
  **réel** du worker garde la parité sur 215 étapes, 85 sérialisations contre 1.
  Le stockage ordinaire reste immédiat.
- 32 recettes UI/sauvegardes/physiques reçues : sauvegardes 804,13 s,
  résilience 656,50 s, essais visibles 990,76 s avec deux graines au vrai
  worker, préparation, touches, faits, tactique, carnet et oppositions.
- 26 recettes gestion reçues avant les deux reprises root supplémentaires :
  finances, contrats V31–V35, vente, staff, relations et juniors. Mentorat
  11/11 ; mercato réel semaine 13, 35 mouvements et indemnité de formation
  125000 exactement rapprochée. Économie transactionnelle 511,15 s.
- Reprises root supplémentaires : satisfaction V36 88,0 s ; relations V37
  109,4 s ; discipline 46,1 s ; producteur gestes 47,7 s, fixture entière de
  sept scènes identique. Node 22 ; commit `0bf3127b` et vrais poids/budgets.
- Rugby 840,0 s, temps forts 13/13 en 791,9 s, importance 384,5 s.
  Continuité : deux saisons pour chacun de deux clubs et cinq reprises par club.
- SDK Godot 4.7.2 réel sous Node 22 : gestes 2/2 et 129 contrôles,
  animation reproductible, passes 3/3, ambiance sonore 1/1 avec pilote Dummy.
  Pas de sous-test SDK ignoré dans ces reçus.
- Garde Monde 8/8. Confidentialité, compilation commune et registre vérifiés.

Correctif produit intégré `b122cdbb` : le passage saison 5 → 6 refusait
l'historique à 15 ans d'un espoir devenu professionnel. Le contrôle historique
ne dépend plus de son statut academy actuel, uniquement pour youth-* sous
politique 3. L'âge actuel professionnel et les autres minimums restent
inchangés. Régression complète verte après optimisation, 42,32 s ; vraie
transition Y5 → Y6 reçue avec le budget natif de 15 s inchangé. Ce reçu ciblé
ne remplace pas une campagne entière.

Optimisation intégrée `43528199` : cache limité à la sélection synchrone et
empreinte exacte entre appels. Lectures dev 2200 → 100 ; mêmes S/store/RNG,
feuille et vraie semaine de match. Une vraie première saison IA conserve aussi
le texte entier et le RNG avant/après dépendances. Les chronométrages de
sélection varient : **aucun gain général de saison ou de FPS démontré**.

## Campagnes interrompues et WIP

1. **V63.1, 12 années** : une première tentative avait joué et validé les
   12 années, mais son reçu global était rouge sur une assertion finale
   erronée du constructeur de reprise. La correction vise le vrai validateur.
   Nouvelle tentative arrêtée à la demande de Léo après **7 années validées**,
   pendant la huitième ; ce n'est pas un PASS12. Le journal est préservé,
   aucun checkpoint portable de la septième année n'est certifié.
2. **V63.2, 16 années/six reprises** : référence de six années reçue en
   1327,4 s. Découpage WIP en trois scénarios indépendants 6/5/5, mêmes
   graines/configurations/corps de simulation. Les deux suites cinq années
   **n'ont pas démarré** avant l'arrêt ; budgets/poids à recevoir avant
   intégration. Fichiers `tests/v63-2-stress-native*.cjs` et helper associé.
3. **World-career, dix années natives** : campagne fraîche arrêtée pendant
   la cinquième ; **quatre années complètes**, exports et transitions reçus.
   Dernier fichier chez le producteur UI, checkpoints annuels authentiques
   conservés localement. Pas de PASS10.
4. **AI-roster, douze années** : AI14 a joué trois années puis a refusé
   `next_season` par dépassement de 15000 ms, sans premier saveCheck faux.
   Rejeu de la seule commande depuis le vrai Y3 : succès, même limite native,
   18,46 s au total sur plusieurs appels VM, état/stockage exacts. Profil CPU
   conservé. Cause du dépassement encore à conclure ; ne pas confondre temps
   total du handle et temps d'un seul appel VM. Pas de PASS12.
   Profil préliminaire : nativeGestion environ 5,62 s inclusifs, projection
   environ 6,72 s, validation environ 2,30 s, GC environ 1,20 s propre ;
   temps recouvrants, à ne pas additionner. Aucune correction engagée après
   ce profil. Détails dans l'annexe gestion.
5. **Population douze années** : ancienne tentative arrêtée en rouge au
   passage 5 → 6 avant le correctif historique. Reprise complète non reçue.
6. **Prime champion/mobilité** : WIP gestion. Prime française de 1000000
   absente du chemin World : API pure partagée, reçu persistant et validation
   préparés, recette native encore rouge. Mobilité encore bornée par l'ancien
   catalogue : viser 114 clubs jouables, donc 113 autres postes ; invités
   56/57 refusés, capacité 339 candidatures. Ne pas annoncer ces produits reçus.
   Après toute modification de `dist/game.js`, régénérer officiellement common
   et vérifier les profils strictement identiques ; hash source actuellement
   périmé dans le snapshot gestion WIP.
7. Autres ports gestion non reçus : interclub, pilotage/projection manager,
   population, V27–V30, V38 et observation jeunes ; dernier inventaire dans
   le rapport d'arrêt gestion. La projection manager root est aussi WIP.

L'historique de retraites tronqué à 80 peut évincer les retraites du club
humain traité en premier : défaut reproductible distinct, encore non corrigé.

## Blocages CI et limites

La PR #742 est restée brouillon. Ses derniers runs légers sont terminés ;
le verdict rouge de brouillon ne vaut pas batterie fonctionnelle exécutée.
La batterie complète Node 22/Godot finale n'a pas été reçue, donc aucune fusion.

Les vrais poids Monde font dépasser le plafond historique de 20 minutes du
rejeu des shards. Sept contrôles purs actuels passent, `ci-shard-replay` reste
rouge. Les fichiers de garde purs exclus historiquement par leur commentaire
ne doivent pas servir à masquer ce rouge. Aucun seuil, profil historique,
poids ou contrôle abaissé. La proposition de rééquilibrage insuffisante a été
archivée, `ci/shard-tests.cjs` reste inchangé. Ne pas présenter ce point résolu.

Un quatrième créneau local temporaire a été utilisé pour de courtes recettes
et Godot pendant les trois campagnes ; le timeout annuel est apparu sous
charge, sans causalité établie. Retour ensuite à trois gros processus maximum.
Éviter de refaire de longues années pour diagnostiquer une seule commande :
conserver d'abord un checkpoint authentique et son RNG.

Captures manuelles : vraie ouverture World reçue, trois images et borne de
durée 30,5 s. Arrêt à minute précise corrigé/relu mais pas atteint dans ce
reçu ; film entracte seulement relu/compilé. Aucun film entier, encodage,
écoute humaine, fluidité GPU ou test Windows natif revendiqué.

Retrait des dates complètes à la tête publique seulement : originaux archivés
par SHA256 dans la PR privée rugby-reel-donnees#16, toujours brouillon.
1592 profils français et 3208 du registre identiques hors birthDate ; pas
de réécriture de l'historique Git ni purge des anciennes releases.

## Éléments locaux et reprise utile

Workspace root : `/workspace/work/garde-monde`. Deux autres worktrees :
`/workspace/work/migration-gestion`, `/workspace/work/migration-ui-sauvegardes`.
Rapports, logs, checkpoints et signatures :
`/workspace/work/migration-coordination/`, notamment les rapports d'arrêt
`gestion-arret-claude-20261115.md` et `ui-arret-claude-20261115.md`.
Copies publiées, sans données brutes :
`docs/passation-claude-arret-gestion-20261115.md` et
`docs/passation-claude-arret-ui-20261115.md`.
Les checkpoints et profils complets **ne sont pas publiés** ; ils sont utiles
uniquement si cette machine reste accessible. Les snapshots Git conservent
le code pour une reprise sur une autre machine.

Node 22 vérifié : `/workspace/work/node22/node-v22.23.5-linux-x64/bin/node`.
Godot : `/workspace/work/godot/Godot_v4.7.2-stable_linux.x86_64`.
Ne pas relancer `/workspace/work/run-world-batch.cjs` sans choisir les fichiers :
son ancien contrôleur enchaînait les campagnes et a été arrêté explicitement.
Les douze textures Gabi non suivies du worktree root sont des intermédiaires
d'import Godot ; ne pas les inclure avec un `git add .`.

Le harnais de compatibilité demande elite/accession détaillés plus le
championnat du manager ; tous les clubs restent simulés et toutes les phases
finales détaillées. Le harnais Monde natif existant garde tout détaillé.
Après une vraie commande `next_season`, régler les rendez-vous par les
commandes publiques, puis réarmer `h.deferSaves()` pour la saison suivante :
la commande matérialise et désarme le lot. Ne pas effacer les rendez-vous.

Recommandation de reprise : inventaire/diff des snapshots, diagnostic ciblé du
timeout et des rouges prime/mobilité, puis petites recettes restantes avant
une nouvelle décision sur les longues campagnes et la CI. Revenir ensuite à
#739/#740/#741 et aux priorités produit ; ne pas élargir encore ce préalable.

Décisions déjà obtenues : agents libres avec stockage canonique et sortie
progressive selon âge/niveau/potentiel/durée, historiques conservés ; jouer
à 22 autorisé partout. Japon/statuts, recalage fin V2 et écart moteur complet /
résultat rapide restent à traiter ensuite, dans l'ordre des passations.

Modèle/effort effectifs non exposés. Pour cette reprise technique,
recommandation GPT‑6.1 Sol : effort élevé.
