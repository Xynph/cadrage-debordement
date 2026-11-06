# Économie V2 — E1 : noyau comptable autonome

**Statut expérimental, NON BRANCHÉ au jeu.** Référence `main` au démarrage : `bd89594a1f4303ba869fca0e82233c66c5bf7600`. Réservation #73 commentaire 6688814022.

## Les trois seuls fichiers E1

- `dist/economy-v2-core.js` : module indépendant, purement fonctionnel, CommonJS Node et navigateur (pas inclus dans index.html).
- `tests/economy-v2-core.cjs` : tests natifs node:test.
- `docs/economie-v2/e1-core.md` : spécification et limites.

**Aucun changement aux finances, matches, UI et sauvegardes actuels.** Aucun plancher salarial forcé ; aucun financement inventé pour normaliser la trésorerie.

## API et séparation des notions

| Fonction | Mouvement de cash | Résultat | Autre conséquence |
|---|---:|---:|---|
| `income` : recette encaissée | + | + produit | catégorie métier enregistrée |
| `payment` : charge payée | − | − charge | ne peut créer découvert caché |
| `injectCapital` : financement actionnaire | + | 0 | capitaux propres + |
| `drawLoan` : emprunt réel | + | 0 | dette + |
| `repayLoan` : nominal + intérêts | − | intérêts uniquement | dette − |
| `invest` : stade / immobilisation | − | 0 à l'achat | actif immobilisé + |
| `addCommitment` : échéance promise | 0 | 0 | engagement futur + |
| `settleCommitment` | − à échéance | − charge | promesse soldée une fois |
| `transfer` | somme ligue inchangée | comptabilité simplifiée | immobilisation chez acheteur, produit chez vendeur |

Les comptes de créances et dettes fournisseurs existent mais ne sont pas encore connectés à une gestion de facturation et de charges non décaissées. Les transferts seront affinés pour le calcul d'amortissements/indemnités à E2. Montants fictifs en euros entiers ; ne jamais présenter comme comptes de clubs réels.

### Invariants bloquants

1. **Double entrée** : total débits = total crédits, et bilan par club reconstitué à partir du journal.
2. **Traçabilité** : un identifiant d'événement unique par club ; replay identique idempotent, replay différent rejeté.
3. **Atomicité** : un batch en échec ne modifie pas les objets passés en entrée.
4. **Solvabilité explicite** : un paiement au-delà du cash est refusé ; dette ou capital doivent être enregistrés comme décisions visibles.
5. **Engagements** : pas de cash débité avant paiement, pas de double paie à la reprise, garde de dates `YYYY-MM`.
6. **Validation stricte** : identité, comptes, plafonds d'entiers, montants, événements, doublons et falsification du ledger contrôlés.
7. **Observabilité** : `snapshot(world,clubId,period?)` reconstruit un état à date ; `spendingRoom` indique ce qui est mobilisable après obligations futures et réserve, mais ne donne aucun droit supplémentaire.
8. **Non-régression** : le module n'est pas référencé dans `dist/index.html` ni `tests/harness.cjs` ; les sauvegardes métier continuent sur leur format historique.

## Préserver le plaisir de jouer

E1 n'introduit aucun nouveau malus. Plus tard, le moteur de décisions offrira une voie compréhensible pour sortir d'une tension : renégociation, cession, sponsoring, apport actionnaire, crédit, formation et adaptation sportive. L'automatisation d'opérations quotidiennes relèvera du mode Accompagné, sans modifier artificiellement les flux.

## Qualification de E1

Exécuter `node --check dist/economy-v2-core.js`, `node --check tests/economy-v2-core.cjs`, `node --test tests/economy-v2-core.cjs`. La PR DRAFT doit vérifier les tests GitHub sur son HEAD exact. Les 34 cas visent notamment opérations, soldes, contrôle d'intégrité, fonds propres, intérêts, immobilisations, transferts interclubs et sauvegarde JSON ; ne pas les confondre avec 15 saisons de gameplay.

## E2 — prochain chantier préparé, pas exécuté

1. Concevoir un **adaptateur legacy en lecture seule** et une ouverture de compte traçable, sans verser une seconde fois les revenus/dépenses actuels.
2. Faire tourner une comparaison de six campagnes × quinze saisons, avec trois imports par campagne. Le nouveau registre doit expliquer 100 % des variations de cash sans modifier `S`.
3. Reconstruire les séries vraiment disponibles pour le futur cockpit : trésorerie, résultats, engagements, salaires, dette, budget. Ne pas créer de fausses dates mensuelles si les 29 tours ne correspondent pas aux mois.
4. Écran PC consultatif premium, courbes et tableaux sourcés par le registre, tests Chromium 1920×1080 et 1440×900. La nouvelle logique économique ne sera activée qu'après qualification, migration sûre et décision de produit.
